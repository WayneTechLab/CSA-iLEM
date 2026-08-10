#!/usr/bin/env python3
"""Losslessly consolidate CSA-iEM repository copies into canonical folders.

This utility exists for the failure mode where a workspace transaction leaves
top-level ``*.csa-iem-stage-*`` directories or where Stage 1 project folders
remain split from their canonical GitHub-identity destination.

The merge is deliberately conservative:

* canonical content is create-only except for one reviewed, proof-gated active
  checkout policy that first snapshots the prior canonical path;
* source-only paths activate only from a verified current/descendant source or
  a narrowly reviewed current-authoritative policy;
* old, broken, compatibility, temporary, legacy, and identity-unverified data
  is represented below ``.csa-iem-recovery`` rather than activated;
* source Git refs and objects are imported under namespaced recovery refs;
* every regular file is checksum-compared, including metadata-matched files;
* a source is moved only into transaction-specific same-volume managed
  quarantine after every destination group and global precheck succeeds.

Run without ``--apply`` to write a preflight report. This recovery phase never
permanently deletes source data; ``--apply`` requires the exact confirmation
token printed by ``--help`` and can only retire receipt-bound sources to managed
``_temp``.
"""

from __future__ import annotations

import argparse
import atexit
import base64
import concurrent.futures
import ctypes
import ctypes.util
import dataclasses
import datetime as dt
import errno
import functools
import hashlib
import json
import os
import plistlib
import re
import shutil
import sqlite3
import stat
import subprocess
import sys
import tempfile
import threading
import traceback
import urllib.parse
from pathlib import Path, PurePosixPath
from typing import BinaryIO, Iterable, Iterator, Sequence


LAUNCH_CWD = Path(os.path.abspath(os.getcwd()))
CONFIRM_TOKEN = "DELETE-VERIFIED-DUPLICATES"
RECOVERY_DIR_NAME = ".csa-iem-recovery"
STAGE_SUFFIX_RE = re.compile(r"^(?P<base>.+)\.csa-iem-stage-[A-Za-z0-9-]+$")
REPORT_ROW_RE = re.compile(
    r"^\|\s*([^|]+?)\s*\|\s*`([^`]*)`\s*\|\s*`([^`]*)`\s*\|\s*`([^`]*)`\s*\|"
)
SAFE_REF_COMPONENT_RE = re.compile(r"[^A-Za-z0-9._/-]+")
FINDER_METADATA_NAMES = {".DS_Store"}
MAPPING_RETENTIONS = {"auto", "retain", "retire-to-managed-temp"}
SOURCE_POLICIES = {"auto", "current-authoritative", "evidence-only"}
CONFLICT_POLICIES = {"preserve-canonical", "source-wins-after-preserve"}
EVIDENCE_ONLY_GIT_FRAGMENT_KIND = "evidence-only-git-fragment"
OLD_SOURCE_KINDS = {
    "explicit-compat-source",
    "explicit-temp-source",
    "explicit-legacy-source",
    EVIDENCE_ONLY_GIT_FRAGMENT_KIND,
}
NEVER_RETIRE_SOURCE_KINDS = {"explicit-active-checkout-source"}
AUTO_RETIRE_SOURCE_KINDS = {
    "canonical-stage-duplicate",
    "managed-root-stage-copy",
    "runtime-mirror-copy",
    "runtime-runner-worktree",
    "stage1",
    "stage1-retired",
}
PROJECT_MARKERS = {
    ".git",
    "Cargo.toml",
    "Package.swift",
    "composer.json",
    "go.mod",
    "package.json",
    "pom.xml",
    "pyproject.toml",
    "setup.py",
}
EXACT_METADATA_FIELDS = (
    "mode",
    "uid",
    "gid",
    "flags",
    "xattrs-and-resource-fork",
    "acl-where-available",
    "mtime",
    "hardlink-topology",
)
RECORD_ONLY_METADATA_FIELDS = ("birthtime", "atime", "sparse-allocation")
DERIVATION_EXCEPTIONS = {
    (
        "waynetechlab/sfwa-wtl-template",
        "waynetechlab/wtl-computerx",
    )
}
NON_GIT_BOOTSTRAP_REPOSITORIES = {
    "waynetechlab/wayne-tech-lab-gen-prompt",
    "waynetechlab/swap-nakmoto-research",
    "waynetechlab/sst-browser",
    "waynetechlab/modern-destroy",
}
RUNNER_DRAIN_PROOF_KIND = "csa-iem-runner-drain-v1"
WORKSPACE_ROOT_PROOF_KIND = "csa-iem-workspace-root-v1"
WORKSPACE_ROOT_MANIFEST_KIND = "csa-iem-workspace-root-manifest-v1"
WORKSPACE_ROOT_PROOF_STATUS = "atomic-nonrepository-merge-complete"
WORKSPACE_DESTINATION_VARIANT_POLICY = "preserve-conflicts-never-overwrite"
RECEIPT_FORMAT = 3
REPRESENTATION_FORMAT = 1
FINAL_RECEIPT_STATUS = "finalized-after-destination-group-proof"
TREE_ALGORITHM = "csa-iem-stable-tree-sha256-v1"
VERIFICATION_CACHE_SIZE = 131_072
PERSISTENT_HASH_INDEX_FORMAT = 1
SHA256_RE = re.compile(r"[0-9a-f]{64}")
CRITICAL_RUNNER_FILES = {
    ".credentials",
    ".credentials_rsaparams",
    ".runner",
    ".env",
    "bin/Runner.Listener",
    "runsvc.sh",
}


class RecoveryError(RuntimeError):
    """A safety or verification condition prevented recovery."""


class MissingRepositoryError(RecoveryError):
    """A reviewed GitHub repository does not exist for the bound account."""


_PERSISTENT_HASH_INDEX: sqlite3.Connection | None = None
_PERSISTENT_HASH_INDEX_PATH: Path | None = None
_PERSISTENT_HASH_INDEX_TRANSACTION = "unbound"
_PERSISTENT_HASH_INDEX_EXCLUDED_ROOTS: tuple[Path, ...] = ()
_PERSISTENT_HASH_INDEX_LOCK = threading.RLock()
_PERSISTENT_HASH_INDEX_STATS = {
    "hits": 0,
    "misses": 0,
    "writes": 0,
    "errors": 0,
}


@dataclasses.dataclass(frozen=True)
class Mapping:
    source: Path
    destination: Path
    kind: str
    repository: str = ""
    retention: str = "auto"
    excluded_relative_paths: tuple[str, ...] = ()
    allow_identity_mismatch: bool = False
    rearm_repository: str = ""
    source_policy: str = "auto"
    github_account: str = ""
    conflict_policy: str = "preserve-canonical"
    recovery_only_paths: tuple[str, ...] = ()
    legacy_repository: str = ""
    mapping_sha256: str = ""


@dataclasses.dataclass(frozen=True)
class ExactMetadata:
    mode: int
    uid: int
    gid: int
    flags: int
    mtime_ns: int
    xattrs: tuple[tuple[str, str], ...]
    acl_digest: str


@dataclasses.dataclass(frozen=True)
class RecordOnlyMetadata:
    birthtime_ns: int
    atime_ns: int
    allocated_bytes: int
    logical_bytes: int


@dataclasses.dataclass(frozen=True)
class GitComponentSnapshot:
    kind: str
    source_role: str
    source_path: str
    snapshot_relative: str
    digest: str


@dataclasses.dataclass
class GitEvidence:
    source_git: bool = False
    destination_git: bool = False
    source_head: str = ""
    destination_head: str = ""
    source_branch: str = ""
    destination_branch: str = ""
    history_relation: str = "not-applicable"
    source_commit_time: int = 0
    destination_commit_time: int = 0
    staged_paths: int = 0
    unstaged_paths: int = 0
    untracked_paths: int = 0
    conflicted_paths: int = 0
    source_refs: dict[str, str] = dataclasses.field(default_factory=dict)
    protected_oids: set[str] = dataclasses.field(default_factory=set)
    namespace: str = ""
    source_remote: str = ""
    destination_remote: str = ""
    source_fsck_clean: bool = True
    source_fsck_error: str = ""
    fragment_snapshot: str = ""
    fragment_digest: str = ""
    fragment_source_path: str = ""
    full_snapshot: str = ""
    full_snapshot_digest: str = ""
    unreachable_oids: set[str] = dataclasses.field(default_factory=set)
    unreachable_snapshot: str = ""
    component_snapshots: list[GitComponentSnapshot] = dataclasses.field(default_factory=list)
    source_common_git_dir: str = ""
    source_worktree_git_dir: str = ""
    source_fsck_invocations: int = 0
    git_history_imported: bool = False
    pointer_only_evidence: bool = False
    final_group_fsck_verified: bool = False


@dataclasses.dataclass
class TreeStats:
    directories: int = 0
    files: int = 0
    symlinks: int = 0
    bytes: int = 0
    identical: int = 0
    added: int = 0
    conflicts: int = 0
    metadata_conflicts: int = 0
    oldest_mtime_ns: int = 0
    newest_mtime_ns: int = 0
    root_digest: str = ""
    manifest_digest: str = ""
    manifest_entries: int = 0
    verified_metadata_fields: tuple[str, ...] = EXACT_METADATA_FIELDS
    record_only_metadata_fields: tuple[str, ...] = RECORD_ONLY_METADATA_FIELDS


@dataclasses.dataclass
class ProcessResult:
    mapping: Mapping
    status: str
    detail: str
    variant_root: str = ""
    tree: TreeStats | None = None
    git: GitEvidence | None = None


@dataclasses.dataclass
class FastAudit:
    equivalent: bool
    difference_count: int
    differences: list[str]
    raw_output_digest: str


@dataclasses.dataclass
class PreparedMapping:
    mapping: Mapping
    source_id: str
    tree: TreeStats
    git: GitEvidence
    activation_allowed: bool
    activation_reason: str
    variant_relative: str
    prior_recovery_snapshot_relative: str = ""
    prior_recovery_digest: str = ""
    evidence_only_fragment: bool = False
    pre_promotion_relative: str = ""
    pre_promotion_digest: str = ""
    source_device: int = 0
    source_inode: int = 0
    source_tree_digest: str = ""
    source_git_components: list[dict[str, object]] = dataclasses.field(default_factory=list)
    source_git_components_digest: str = ""
    source_git_state: str = ""
    representation_proof: str = ""
    representation_proof_sha256: str = ""
    representation_status: str = ""


@dataclasses.dataclass
class DestinationGroupResult:
    destination: Path
    prepared: list[PreparedMapping]
    status: str
    detail: str
    original_backup: str = ""
    group_receipt: str = ""
    group_receipt_sha256: str = ""
    live_repository: LiveRepository | None = None


@dataclasses.dataclass
class RetirementMove:
    source: Path
    target: Path
    kind: str
    source_ids: list[str]
    device: int = 0
    inode: int = 0
    status: str = "planned"


@dataclasses.dataclass(frozen=True)
class LiveRepository:
    requested: str
    full_name: str
    database_id: str
    node_id: str
    default_branch: str
    remote_head: str
    clone_url: str
    authenticated_login: str
    is_empty: bool = False
    private: bool = False
    archived: bool = False
    role: str = "repository"
    parent_full_name: str = ""
    remote_refs_digest: str = ""


@dataclasses.dataclass(frozen=True)
class RunnerDrainRootProof:
    cleanup_root: Path
    source_runtime_root: Path
    canonical_runtime_root: Path
    root_device: int
    root_inode: int
    runtime_device: int
    runtime_inode: int
    services: tuple[dict[str, object], ...]
    service_set_sha256: str
    critical_hashes: dict[str, dict[str, str]]
    process_reference_count_before: int
    process_reference_sha256_before: str


@dataclasses.dataclass(frozen=True)
class RunnerDrainProof:
    receipt: Path
    receipt_sha256: str
    recovery_transaction: str
    drain_transaction: str
    source_map_sha256: str
    github_accounts_sha256: str
    repository_identities_sha256: str
    managed_evidence_volume: dict[str, object]
    roots: tuple[RunnerDrainRootProof, ...]


@dataclasses.dataclass(frozen=True)
class RunnerDrainRequirement:
    cleanup_root: Path
    source_runtime_root: Path
    canonical_runtime_root: Path


@dataclasses.dataclass(frozen=True)
class WorkspaceRootRequirement:
    cleanup_root: Path
    canonical_root: Path
    requires_runner_drain: bool


@dataclasses.dataclass(frozen=True)
class WorkspaceRootProofReference:
    path: Path
    sha256: str
    cleanup_root: str
    manifest_sha256: str
    journal: Path


@dataclasses.dataclass
class WorkspaceRootSwapState:
    proofs: tuple[WorkspaceRootProofReference, ...]
    transaction: str
    managed_root: Path
    rollback_root: Path
    sibling_transaction_root: Path
    journal: Path
    managed_volume: VolumeIdentity | None = None
    rolled_back: bool = False


@dataclasses.dataclass(frozen=True)
class ContractBindings:
    source_map_path: Path
    source_map_sha256: str
    github_accounts: dict[str, str]
    github_accounts_sha256: str
    repository_identities: dict[str, dict[str, str]]
    repository_identities_sha256: str
    mapping_sha256_by_source: dict[str, str]
    runner_drain_requirements: tuple[RunnerDrainRequirement, ...]
    workspace_root_requirements: tuple[WorkspaceRootRequirement, ...]
    workspace_root_proof_contract: str


@dataclasses.dataclass(frozen=True)
class VolumeIdentity:
    device_number: int
    volume_uuid: str
    device_identifier: str
    mount_point: str
    filesystem: str


def utc_transaction_id() -> str:
    now = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"{now}-{os.getpid()}"


def canonical(path: Path) -> Path:
    return Path(os.path.realpath(os.path.abspath(os.fspath(path))))


def nearest_existing_path(path: Path) -> Path:
    candidate = Path(os.path.abspath(path))
    while not os.path.lexists(candidate):
        if candidate.parent == candidate:
            raise RecoveryError(f"No existing ancestor was found for {path}")
        candidate = candidate.parent
    return candidate


def volume_identity(path: Path) -> VolumeIdentity:
    existing = nearest_existing_path(path)
    device_number = int(existing.stat().st_dev)
    if sys.platform != "darwin":
        return VolumeIdentity(device_number, "", "", display_path(existing.anchor), "")
    diskutil = "/usr/sbin/diskutil"
    # ``diskutil info`` accepts a disk identifier or a mount point, but not a
    # deep project directory. Resolve the exact backing device first so every
    # canonical/recovery subdirectory receives the same volume identity.
    df = run_command(["df", "-P", existing], check=False)
    if df.returncode != 0:
        diagnostics = (df.stdout + df.stderr).decode("utf-8", "replace").strip()
        raise RecoveryError(f"Could not identify mounted volume for {existing}: {diagnostics}")
    lines = df.stdout.decode("utf-8", "replace").splitlines()
    match = re.match(r"^(\S+)\s+\d+\s+\d+\s+\d+\s+\d+%\s+.+$", lines[-1]) if len(lines) >= 2 else None
    if match is None:
        raise RecoveryError(f"Could not parse backing device for {existing}")
    result = run_command([diskutil, "info", "-plist", match.group(1)], check=False)
    if result.returncode != 0:
        diagnostics = (result.stdout + result.stderr).decode("utf-8", "replace").strip()
        raise RecoveryError(f"Could not resolve volume identity for {existing}: {diagnostics}")
    try:
        payload = plistlib.loads(result.stdout)
    except Exception as error:
        raise RecoveryError(f"Volume identity response was invalid for {existing}") from error
    volume_uuid = str(payload.get("VolumeUUID", ""))
    device_identifier = str(payload.get("DeviceIdentifier", ""))
    mount_point = str(payload.get("MountPoint", ""))
    filesystem = str(payload.get("FilesystemType", payload.get("Type (Bundle)", "")))
    if not volume_uuid or not device_identifier or not mount_point:
        raise RecoveryError(f"Volume identity is incomplete for {existing}")
    return VolumeIdentity(
        device_number=device_number,
        volume_uuid=volume_uuid,
        device_identifier=device_identifier,
        mount_point=mount_point,
        filesystem=filesystem,
    )


def revalidate_volume_identity(expected: VolumeIdentity, path: Path) -> None:
    current = volume_identity(path)
    if current != expected:
        raise RecoveryError(
            f"Volume identity changed for {path}: "
            f"expected={dataclasses.asdict(expected)}, actual={dataclasses.asdict(current)}"
        )


def contract_volume_identity(path: Path) -> dict[str, object]:
    """Volume identity compatible with the local-cleanup runner receipt."""
    path = Path(os.path.abspath(path))
    metadata = path.stat()
    result: dict[str, object] = {"device": metadata.st_dev, "path": display_path(path)}
    df = run_command(["df", "-P", path], check=False)
    if df.returncode != 0:
        raise RecoveryError(f"Could not identify mounted volume for {path}")
    lines = df.stdout.decode("utf-8", "replace").splitlines()
    if len(lines) < 2:
        raise RecoveryError(f"df returned no mounted volume for {path}")
    match = re.match(r"^(\S+)\s+\d+\s+\d+\s+\d+\s+\d+%\s+(.+)$", lines[-1])
    if match is None:
        raise RecoveryError(f"Could not parse mounted volume identity for {path}")
    result["deviceNode"] = match.group(1)
    result["mountPoint"] = match.group(2)
    if sys.platform == "darwin" and Path("/usr/sbin/diskutil").is_file():
        disk = run_command(
            ["/usr/sbin/diskutil", "info", "-plist", str(result["deviceNode"])],
            check=False,
        )
        if disk.returncode != 0:
            raise RecoveryError(f"diskutil could not identify volume for {path}")
        try:
            payload = plistlib.loads(disk.stdout)
        except plistlib.InvalidFileException as error:
            raise RecoveryError(f"diskutil returned invalid volume metadata for {path}") from error
        for source_key, target_key in (
            ("VolumeUUID", "volumeUUID"),
            ("DeviceIdentifier", "deviceIdentifier"),
            ("MountPoint", "diskutilMountPoint"),
            ("VolumeName", "volumeName"),
            ("FilesystemType", "filesystemType"),
            ("FilesystemName", "filesystemName"),
            ("FilesystemUserVisibleName", "filesystemUserVisibleName"),
            ("BusProtocol", "busProtocol"),
            ("Internal", "internal"),
            ("RemovableMedia", "removableMedia"),
            ("RemovableMediaOrExternalDevice", "externalDevice"),
            ("SolidState", "solidState"),
            ("Writable", "writable"),
            ("WritableVolume", "writableVolume"),
            ("ReadOnlyVolume", "readOnlyVolume"),
            ("GlobalPermissionsEnabled", "ownersEnabled"),
            ("CaseSensitive", "caseSensitive"),
        ):
            result[target_key] = payload.get(source_key, "")
        if result.get("caseSensitive") == "":
            result["caseSensitive"] = "case-sensitive" in str(
                result.get("filesystemName", "")
            ).casefold()
        mount = run_command(["/sbin/mount"], check=False)
        if mount.returncode != 0:
            raise RecoveryError(f"Could not inspect mount flags for {path}")
        mount_point = str(result.get("diskutilMountPoint", ""))
        matching_lines = [
            line
            for line in mount.stdout.decode("utf-8", "replace").splitlines()
            if f" on {mount_point} (" in line
        ]
        if len(matching_lines) != 1:
            raise RecoveryError(f"Could not bind exact mount flags for {mount_point}")
        flags_match = re.search(r"\((.*)\)\s*$", matching_lines[0])
        if flags_match is None:
            raise RecoveryError(f"Could not parse mount flags for {mount_point}")
        result["mountFlags"] = sorted(
            value.strip()
            for value in flags_match.group(1).split(",")
            if value.strip()
        )
    required = ["device", "deviceNode", "mountPoint"]
    if sys.platform == "darwin":
        required.extend(
            [
                "volumeUUID",
                "deviceIdentifier",
                "diskutilMountPoint",
                "filesystemType",
                "filesystemName",
                "filesystemUserVisibleName",
                "busProtocol",
                "mountFlags",
            ]
        )
    missing = [
        key
        for key in required
        if result.get(key) is None or result.get(key) == "" or result.get(key) == []
    ]
    if missing:
        raise RecoveryError(f"Managed evidence volume identity is incomplete: {missing}")
    if result.get("writable") is False or result.get("readOnlyVolume") is True:
        raise RecoveryError(f"Managed evidence volume is not writable: {path}")
    return result


def same_contract_volume_identity(
    expected: dict[str, object], current: dict[str, object]
) -> bool:
    keys = {
        "device",
        "deviceNode",
        "mountPoint",
        "volumeUUID",
        "deviceIdentifier",
        "diskutilMountPoint",
        "filesystemType",
        "filesystemName",
        "filesystemUserVisibleName",
        "busProtocol",
        "internal",
        "removableMedia",
        "externalDevice",
        "solidState",
        "writable",
        "writableVolume",
        "readOnlyVolume",
        "ownersEnabled",
        "caseSensitive",
        "mountFlags",
    }
    return all(
        expected.get(key) == current.get(key)
        for key in keys
        if key in expected or key in current
    )


def require_no_symlink_components(path: Path, root: Path, label: str) -> None:
    path = Path(os.path.abspath(path))
    root = Path(os.path.abspath(root))
    if not lexical_path_within(path, root):
        raise RecoveryError(f"{label} is outside {root}: {path}")
    current = root
    if current.is_symlink():
        raise RecoveryError(f"{label} root is a symlink: {current}")
    for part in path.relative_to(root).parts:
        current = current / part
        if current.is_symlink():
            raise RecoveryError(f"{label} traverses a symlink: {current}")


def path_within(path: Path, root: Path) -> bool:
    try:
        return os.path.commonpath([os.path.abspath(path), os.path.abspath(root)]) == os.path.abspath(root)
    except ValueError:
        return False


_PROTECTED_MUTATION_ROOTS: tuple[Path, ...] = ()


def configure_protected_mutation_roots(paths: Sequence[Path]) -> None:
    """Install immutable checkout boundaries for every destructive primitive."""
    global _PROTECTED_MUTATION_ROOTS
    normalized: list[Path] = []
    for value in paths:
        path = Path(os.path.abspath(value))
        if path.is_symlink() or not path.is_dir():
            raise RecoveryError(f"Protected checkout is not a real directory: {path}")
        if path not in normalized:
            normalized.append(path)
    _PROTECTED_MUTATION_ROOTS = tuple(normalized)


def require_unprotected_mutation(path: Path, operation: str) -> None:
    candidate = Path(os.path.abspath(path))
    for protected in _PROTECTED_MUTATION_ROOTS:
        if path_within(candidate, protected) or path_within(protected, candidate):
            raise RecoveryError(
                f"Refused {operation} touching protected active checkout: "
                f"{candidate} / {protected}"
            )


def guarded_replace(source: Path, destination: Path) -> None:
    require_unprotected_mutation(source, "rename source")
    require_unprotected_mutation(destination, "rename destination")
    os.replace(source, destination)


def guarded_unlink(path: Path) -> None:
    require_unprotected_mutation(path, "unlink")
    path.unlink()


def guarded_rmtree(path: Path) -> None:
    require_unprotected_mutation(path, "recursive deletion")
    shutil.rmtree(path)


def display_path(path: Path | str) -> str:
    return os.fsdecode(os.fspath(path))


def stable_json_bytes(value: object) -> bytes:
    """Canonical JSON used by the Stage 3 cleanup contract."""
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def contract_digest(value: object) -> str:
    return sha256_bytes(stable_json_bytes(value))


def require_sha256(value: object, label: str) -> str:
    if not isinstance(value, str) or SHA256_RE.fullmatch(value) is None:
        raise RecoveryError(f"{label} is not a lowercase SHA-256 digest")
    return value


def safe_transaction_id(value: object, label: str) -> str:
    if (
        not isinstance(value, str)
        or not value
        or len(value) > 200
        or re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", value) is None
    ):
        raise RecoveryError(f"{label} is not a safe transaction identifier")
    return value


def run_command(
    arguments: Sequence[str | os.PathLike[str]],
    *,
    check: bool = True,
    input_bytes: bytes | None = None,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[bytes]:
    command = [os.fspath(value) for value in arguments]
    result = subprocess.run(
        command,
        cwd=os.fspath(cwd) if cwd else None,
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env=env,
    )
    if check and result.returncode != 0:
        output = (result.stdout + result.stderr).decode("utf-8", "replace").strip()
        raise RecoveryError(f"Command failed ({result.returncode}): {' '.join(command)}\n{output}")
    return result


def command_text(
    arguments: Sequence[str | os.PathLike[str]], *, check: bool = True, cwd: Path | None = None
) -> str:
    result = run_command(arguments, check=check, cwd=cwd)
    return result.stdout.decode("utf-8", "surrogateescape").strip()


def normalize_remote(value: str) -> str:
    remote = value.strip()
    if not remote:
        return ""
    scp_match = re.fullmatch(r"git@([^:]+):(.+)", remote, flags=re.IGNORECASE)
    if scp_match:
        host = scp_match.group(1).lower()
        repository_path = scp_match.group(2)
    else:
        candidate = remote if "://" in remote else f"https://{remote}"
        parsed = urllib.parse.urlparse(candidate)
        host = (parsed.hostname or "").lower()
        repository_path = parsed.path
    if host not in {"github.com", "www.github.com"}:
        return ""
    components = [part for part in repository_path.strip("/").split("/") if part]
    if len(components) != 2:
        return ""
    owner, repository = components
    if repository.lower().endswith(".git"):
        repository = repository[:-4]
    if not owner or not repository:
        return ""
    return f"{owner.lower()}/{repository.lower()}"


def github_cli_path() -> str:
    candidate = shutil.which("gh")
    if not candidate:
        raise RecoveryError("Authenticated GitHub verification requires the gh CLI")
    return candidate


def github_token_for_account(account_login: str) -> str:
    gh = github_cli_path()
    result = run_command(
        [
            gh,
            "auth",
            "token",
            "--hostname",
            "github.com",
            "--user",
            account_login,
        ],
        check=False,
    )
    token = result.stdout.decode("utf-8", "strict").strip()
    if result.returncode != 0 or not token:
        diagnostics = result.stderr.decode("utf-8", "replace").strip()
        raise RecoveryError(
            f"Could not obtain an in-memory token for bound GitHub account "
            f"{account_login}: {diagnostics}"
        )
    return token


def gh_token_environment(account_login: str) -> tuple[dict[str, str], str]:
    token = github_token_for_account(account_login)
    environment = dict(os.environ)
    environment["GH_TOKEN"] = token
    environment["GH_HOST"] = "github.com"
    return environment, token


def run_token_scoped_git(
    account_login: str,
    arguments: Sequence[str | os.PathLike[str]],
    *,
    cwd: Path | None = None,
) -> subprocess.CompletedProcess[bytes]:
    """Run Git with an in-memory account token and a token-free askpass file."""
    environment, _token = gh_token_environment(account_login)
    with tempfile.TemporaryDirectory(prefix="csa-iem-git-auth-") as temporary_text:
        temporary = Path(temporary_text)
        askpass = temporary / "askpass.sh"
        askpass.write_text(
            "#!/bin/sh\n"
            "case \"$1\" in\n"
            "  *Username*) printf '%s\\n' 'x-access-token' ;;\n"
            "  *) printf '%s\\n' \"$GH_TOKEN\" ;;\n"
            "esac\n",
            encoding="utf-8",
        )
        os.chmod(askpass, 0o700)
        environment["GIT_ASKPASS"] = display_path(askpass)
        environment["GIT_TERMINAL_PROMPT"] = "0"
        return run_command(arguments, check=False, cwd=cwd, env=environment)


def exact_wiki_child(repository: str) -> tuple[str, str] | None:
    components = repository.split("/")
    if len(components) != 2:
        return None
    owner, name = components
    if not name.endswith(".wiki") or len(name) <= len(".wiki"):
        return None
    base_name = name[: -len(".wiki")]
    if not re.fullmatch(r"[A-Za-z0-9._-]+", base_name):
        return None
    return owner, base_name


def live_repository(
    repository: str,
    account_login: str,
    *,
    allow_empty: bool = False,
    allow_archived: bool = False,
    repository_identities: dict[str, dict[str, str]] | None = None,
) -> LiveRepository:
    """Resolve an authoritative GitHub identity through the active gh session."""
    if exact_wiki_child(repository) is not None:
        raise RecoveryError("Wiki child repositories require live_wiki_repository verification")
    normalized = normalize_remote(f"https://github.com/{repository}")
    if not normalized:
        raise RecoveryError(f"Invalid reviewed GitHub repository: {repository}")
    gh = github_cli_path()
    environment, token = gh_token_environment(account_login)
    user_result = run_command([gh, "api", "user"], check=False, env=environment)
    if user_result.returncode != 0:
        diagnostics = (user_result.stdout + user_result.stderr).decode(
            "utf-8", "replace"
        ).replace(token, "<redacted>").strip()
        raise RecoveryError(f"GitHub bound-account verification failed: {diagnostics}")
    try:
        authenticated_login = str(json.loads(user_result.stdout).get("login", ""))
    except (json.JSONDecodeError, AttributeError) as error:
        raise RecoveryError("GitHub authenticated-user response was not valid JSON") from error
    if not authenticated_login:
        raise RecoveryError("GitHub authenticated-user response had no login")
    if authenticated_login.casefold() != account_login.casefold():
        raise RecoveryError(
            f"GitHub account mismatch: authenticated {authenticated_login}, "
            f"required bound account {account_login}"
        )
    repo_result = run_command(
        [gh, "api", f"repos/{repository}"],
        check=False,
        env=environment,
    )
    if repo_result.returncode != 0:
        diagnostics = (repo_result.stdout + repo_result.stderr).decode(
            "utf-8", "replace"
        ).replace(token, "<redacted>").strip()
        if "HTTP 404" in diagnostics or "Not Found" in diagnostics:
            raise MissingRepositoryError(
                f"GitHub repository is missing for bound account {account_login}: {repository}"
            )
        raise RecoveryError(f"GitHub repository lookup failed for {repository}: {diagnostics}")
    try:
        payload = json.loads(repo_result.stdout)
    except json.JSONDecodeError as error:
        raise RecoveryError(f"GitHub repository response was not valid JSON: {repository}") from error
    if not isinstance(payload, dict):
        raise RecoveryError(f"GitHub repository response was not an object: {repository}")
    full_name = str(payload.get("full_name", ""))
    database_id = str(payload.get("id", ""))
    node_id = str(payload.get("node_id", ""))
    default_branch = str(payload.get("default_branch", ""))
    clone_url = str(payload.get("clone_url", ""))
    private = bool(payload.get("private", False))
    if normalize_remote(f"https://github.com/{full_name}") != normalized:
        raise RecoveryError(
            f"GitHub canonical identity mismatch: requested {repository}, live {full_name or 'missing'}"
        )
    if not default_branch or not clone_url:
        raise RecoveryError(f"GitHub repository lacks clone/default-branch metadata: {full_name}")
    if bool(payload.get("archived", False)) and not allow_archived:
        raise RecoveryError(f"GitHub repository is archived: {full_name}")
    expected_ids = (repository_identities or {}).get(normalized, {})
    if expected_ids.get("databaseID") and database_id != expected_ids["databaseID"]:
        raise RecoveryError(
            f"GitHub repository database ID mismatch for {full_name}: "
            f"{database_id} != {expected_ids['databaseID']}"
        )
    if expected_ids.get("nodeID") and node_id != expected_ids["nodeID"]:
        raise RecoveryError(
            f"GitHub repository node ID mismatch for {full_name}: "
            f"{node_id} != {expected_ids['nodeID']}"
        )
    commit_result = run_command(
        [gh, "api", f"repos/{full_name}/commits/{default_branch}"],
        check=False,
        env=environment,
    )
    is_empty = False
    if commit_result.returncode != 0:
        diagnostics = (commit_result.stdout + commit_result.stderr).decode(
            "utf-8", "replace"
        ).replace(token, "<redacted>").strip()
        if allow_empty and ("409" in diagnostics or "empty" in diagnostics.casefold()):
            remote_head = ""
            is_empty = True
        else:
            raise RecoveryError(
                f"GitHub default-branch lookup failed for {full_name}: {diagnostics}"
            )
    else:
        try:
            commit_payload = json.loads(commit_result.stdout)
            remote_head = str(commit_payload.get("sha", ""))
        except (json.JSONDecodeError, AttributeError) as error:
            raise RecoveryError(f"GitHub default-branch response was invalid: {full_name}") from error
        if not re.fullmatch(r"[0-9a-fA-F]{40,64}", remote_head):
            raise RecoveryError(f"GitHub default branch has no valid remote HEAD: {full_name}")
    return LiveRepository(
        requested=repository,
        full_name=full_name,
        database_id=database_id,
        node_id=node_id,
        default_branch=default_branch,
        remote_head=remote_head.lower(),
        clone_url=clone_url,
        authenticated_login=authenticated_login,
        is_empty=is_empty,
        private=private,
        archived=bool(payload.get("archived", False)),
    )


def live_wiki_repository(
    repository: str,
    account_login: str,
    repository_identities: dict[str, dict[str, str]],
) -> LiveRepository:
    wiki_parts = exact_wiki_child(repository)
    if wiki_parts is None:
        raise RecoveryError(f"Not an exact GitHub Wiki child identity: {repository}")
    owner, base_name = wiki_parts
    parent_requested = f"{owner}/{base_name}"
    parent = live_repository(
        parent_requested,
        account_login,
        repository_identities=repository_identities,
    )
    wiki_full_name = f"{parent.full_name}.wiki"
    wiki_url = f"https://github.com/{wiki_full_name}.git"
    result = run_token_scoped_git(
        account_login,
        ["git", "ls-remote", "--symref", wiki_url],
    )
    if result.returncode != 0:
        _environment, token = gh_token_environment(account_login)
        diagnostics = (result.stdout + result.stderr).decode(
            "utf-8", "replace"
        ).replace(token, "<redacted>").strip()
        raise RecoveryError(
            f"GitHub Wiki is missing, disabled, or inaccessible: {wiki_full_name}: {diagnostics}"
        )
    output = result.stdout.decode("utf-8", "surrogateescape")
    default_branch = ""
    head = ""
    refs: list[tuple[str, str]] = []
    for line in output.splitlines():
        if line.startswith("ref: ") and line.endswith("\tHEAD"):
            ref_name = line[len("ref: ") :].split("\t", 1)[0]
            if ref_name.startswith("refs/heads/"):
                default_branch = ref_name.removeprefix("refs/heads/")
            continue
        if "\t" not in line:
            continue
        object_id, ref_name = line.split("\t", 1)
        if re.fullmatch(r"[0-9a-fA-F]{40,64}", object_id):
            refs.append((ref_name, object_id.lower()))
            if ref_name == "HEAD":
                head = object_id.lower()
    if not default_branch or not head or not refs:
        raise RecoveryError(f"GitHub Wiki has no verifiable HEAD/branch refs: {wiki_full_name}")
    if not any(ref == f"refs/heads/{default_branch}" and oid == head for ref, oid in refs):
        raise RecoveryError(f"GitHub Wiki HEAD does not match its default branch: {wiki_full_name}")
    refs_payload = "\n".join(f"{ref}\t{oid}" for ref, oid in sorted(refs)) + "\n"
    return LiveRepository(
        requested=repository,
        full_name=wiki_full_name,
        database_id=parent.database_id,
        node_id=parent.node_id,
        default_branch=default_branch,
        remote_head=head,
        clone_url=wiki_url,
        authenticated_login=parent.authenticated_login,
        is_empty=False,
        private=parent.private,
        archived=parent.archived,
        role="wiki-child",
        parent_full_name=parent.full_name,
        remote_refs_digest=hashlib.sha256(refs_payload.encode("utf-8")).hexdigest(),
    )


def resolve_live_repository(
    repository: str,
    account_login: str,
    repository_identities: dict[str, dict[str, str]],
    *,
    allow_empty: bool = False,
    allow_archived: bool = False,
) -> LiveRepository:
    if exact_wiki_child(repository) is not None:
        return live_wiki_repository(repository, account_login, repository_identities)
    return live_repository(
        repository,
        account_login,
        allow_empty=allow_empty,
        allow_archived=allow_archived,
        repository_identities=repository_identities,
    )


def exact_derivation_exception(mapping: Mapping, target_repository: str) -> bool:
    if not (
        mapping.allow_identity_mismatch
        and mapping.source_policy == "current-authoritative"
        and mapping.rearm_repository
    ):
        return False
    source_identity = normalize_remote(git_remote(mapping.source))
    target_identity = normalize_remote(f"https://github.com/{target_repository}")
    rearm_identity = normalize_remote(f"https://github.com/{mapping.rearm_repository}")
    return (
        (source_identity, target_identity) in DERIVATION_EXCEPTIONS
        and rearm_identity == target_identity
    )


def exact_non_git_bootstrap(mapping: Mapping, target_repository: str) -> bool:
    target_identity = normalize_remote(f"https://github.com/{target_repository}")
    if (
        target_identity not in NON_GIT_BOOTSTRAP_REPOSITORIES
        or mapping.source_policy != "current-authoritative"
        or not mapping.kind.startswith("explicit-transfer")
        or mapping.retention != "retain"
        or resolve_git_dir(mapping.source) is not None
        or os.path.lexists(mapping.source / ".git")
    ):
        return False
    try:
        if target_identity == "waynetechlab/wayne-tech-lab-gen-prompt":
            package = json.loads(
                (mapping.source / "package.json").read_text(encoding="utf-8")
            )
            readme = (mapping.source / "README.md").read_text(
                encoding="utf-8", errors="replace"
            ).casefold()
            return (
                str(package.get("name", "")).casefold()
                == "wayne-tech-lab-gen-prompt"
                and "wayne" in readme
                and "prompt" in readme
            )
        if target_identity == "waynetechlab/sst-browser":
            package_swift = (mapping.source / "Package.swift").read_text(
                encoding="utf-8", errors="replace"
            )
            readme = (mapping.source / "README.md").read_text(
                encoding="utf-8", errors="replace"
            )
            return 'name: "SST-Browser"' in package_swift and "Super Secure Tab Browser" in readme
        if target_identity == "waynetechlab/modern-destroy":
            package_swift = (mapping.source / "Package.swift").read_text(
                encoding="utf-8", errors="replace"
            )
            readme = (mapping.source / "README.md").read_text(
                encoding="utf-8", errors="replace"
            )
            return 'name: "ModernDestroy"' in package_swift and "# Modern Destroy" in readme
        if target_identity == "waynetechlab/swap-nakmoto-research":
            roadmap = (
                mapping.source
                / "docs"
                / "roadmap"
                / "swap-nakamoto-comprehensive-10k-roadmap.md"
            ).read_text(encoding="utf-8", errors="replace")
            plan = (
                mapping.source
                / ".SYSTEMX"
                / "plans"
                / "MP7-2026-SN-20K-AGENTIC-CRYPTOVERSE.md"
            ).read_text(encoding="utf-8", errors="replace")
            return "Swap Nakamoto" in roadmap and bool(plan.strip())
    except (OSError, json.JSONDecodeError, AttributeError):
        return False
    return False


def authorized_empty_repository_creation(
    mappings: Sequence[Mapping],
    target_repository: str,
) -> bool:
    current_sources = [
        mapping
        for mapping in mappings
        if exact_derivation_exception(mapping, target_repository)
        or exact_non_git_bootstrap(mapping, target_repository)
    ]
    return len(current_sources) == 1


def create_exact_private_empty_repository(
    repository: str,
    account_login: str,
    repository_identities: dict[str, dict[str, str]],
) -> LiveRepository:
    owner, name = repository.split("/", 1)
    environment, token = gh_token_environment(account_login)
    gh = github_cli_path()
    endpoint = "user/repos" if owner.casefold() == account_login.casefold() else f"orgs/{owner}/repos"
    result = run_command(
        [
            gh,
            "api",
            "--method",
            "POST",
            endpoint,
            "-f",
            f"name={name}",
            "-F",
            "private=true",
            "-F",
            "auto_init=false",
        ],
        check=False,
        env=environment,
    )
    if result.returncode != 0:
        diagnostics = (result.stdout + result.stderr).decode(
            "utf-8", "replace"
        ).replace(token, "<redacted>").strip()
        raise RecoveryError(f"Exact private repository creation failed for {repository}: {diagnostics}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RecoveryError(f"Repository creation response was invalid: {repository}") from error
    if (
        str(payload.get("full_name", "")) != repository
        or not bool(payload.get("private", False))
    ):
        raise RecoveryError(
            f"Repository creation identity/privacy proof failed: {payload.get('full_name')}"
        )
    verified = live_repository(
        repository,
        account_login,
        allow_empty=True,
        repository_identities=repository_identities,
    )
    if not verified.private or not verified.is_empty:
        raise RecoveryError(f"New repository is not verified private and empty: {repository}")
    return verified


def parse_key_value_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        contents = path.read_text(encoding="utf-8", errors="surrogateescape")
    except OSError as error:
        raise RecoveryError(f"Could not read receipt {path}: {error}") from error
    for line in contents.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value
    return values


def parse_stage2_report(path: Path) -> list[tuple[Path, Path, str]]:
    rows: list[tuple[Path, Path, str]] = []
    try:
        lines = path.read_text(encoding="utf-8", errors="surrogateescape").splitlines()
    except OSError as error:
        raise RecoveryError(f"Could not read Stage 2 report {path}: {error}") from error
    for line in lines:
        match = REPORT_ROW_RE.match(line)
        if not match:
            continue
        _state, repository, source, destination = match.groups()
        rows.append((Path(source), Path(destination), repository))
    return rows


def load_contract_bindings(mapping_paths: Sequence[Path]) -> ContractBindings:
    """Load the one reviewed source map exactly as the cleanup consumer hashes it.

    Recovery receipts are deletion authorization.  Combining independently
    hashed maps would make their mapping/account/identity bindings ambiguous,
    so apply-compatible plans deliberately require one format-1 source map.
    """
    if len(mapping_paths) != 1:
        raise RecoveryError(
            "Final recovery/cleanup receipts require exactly one reviewed --mapping-file"
        )
    path = Path(os.path.abspath(mapping_paths[0]))
    if path.is_symlink() or not path.is_file():
        raise RecoveryError(f"Reviewed mapping file is not an ordinary file: {path}")
    raw = path.read_bytes()
    try:
        payload = json.loads(raw.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError) as error:
        raise RecoveryError(f"Reviewed mapping file is invalid JSON: {path}") from error
    if not isinstance(payload, dict) or payload.get("format") != 1:
        raise RecoveryError(f"Reviewed mapping file must use format 1: {path}")

    accounts_value = payload.get("githubAccounts")
    if not isinstance(accounts_value, dict):
        raise RecoveryError("Reviewed mapping file lacks githubAccounts")
    github_accounts: dict[str, str] = {}
    for owner, login in accounts_value.items():
        if (
            not isinstance(owner, str)
            or not isinstance(login, str)
            or re.fullmatch(r"[A-Za-z0-9_.-]+", owner) is None
            or re.fullmatch(r"[A-Za-z0-9_.-]+", login) is None
        ):
            raise RecoveryError(f"Unsafe reviewed GitHub account binding: {owner!r}")
        if owner in github_accounts:
            raise RecoveryError(f"Duplicate reviewed GitHub owner binding: {owner}")
        github_accounts[owner] = login

    identities_value = payload.get("repositoryIdentities")
    if not isinstance(identities_value, dict):
        raise RecoveryError("Reviewed mapping file lacks repositoryIdentities")
    repository_identities: dict[str, dict[str, str]] = {}
    for repository, raw_identity in identities_value.items():
        if (
            not isinstance(repository, str)
            or re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository) is None
            or not isinstance(raw_identity, dict)
            or not raw_identity
            or set(raw_identity) - {"databaseID", "nodeID"}
        ):
            raise RecoveryError(f"Unsafe reviewed repository identity: {repository!r}")
        normalized: dict[str, str] = {}
        for key, value in raw_identity.items():
            rendered = str(value)
            if not rendered:
                raise RecoveryError(f"Empty reviewed {key} for {repository}")
            if key == "databaseID" and not rendered.isdigit():
                raise RecoveryError(f"Reviewed databaseID is not decimal for {repository}")
            if key == "nodeID" and re.fullmatch(r"[A-Za-z0-9_-]+", rendered) is None:
                raise RecoveryError(f"Reviewed nodeID is unsafe for {repository}")
            normalized[key] = rendered
        repository_identities[repository] = normalized

    rows = payload.get("mappings")
    if not isinstance(rows, list) or not rows:
        raise RecoveryError("Reviewed mapping file lacks a non-empty mappings array")
    mapping_sha256_by_source: dict[str, str] = {}
    for index, row in enumerate(rows, 1):
        if not isinstance(row, dict) or not isinstance(row.get("source"), str):
            raise RecoveryError(f"Reviewed mapping row {index} lacks an exact source")
        source = display_path(Path(os.path.abspath(os.path.expanduser(row["source"]))))
        if source in mapping_sha256_by_source:
            raise RecoveryError(f"Reviewed source appears more than once: {source}")
        mapping_sha256_by_source[source] = contract_digest(row)

    cleanup_rows = payload.get("localCleanupRoots")
    if not isinstance(cleanup_rows, list):
        raise RecoveryError("Reviewed mapping file lacks localCleanupRoots")
    runner_requirements: list[RunnerDrainRequirement] = []
    workspace_requirements: list[WorkspaceRootRequirement] = []
    seen_cleanup_roots: set[str] = set()
    for index, row in enumerate(cleanup_rows, 1):
        if not isinstance(row, dict):
            continue
        cleanup_value = row.get("path")
        if not isinstance(cleanup_value, str) or not os.path.isabs(cleanup_value):
            raise RecoveryError(f"Cleanup row {index} lacks an absolute path")
        cleanup_root = Path(os.path.abspath(cleanup_value))
        links = row.get("replacementLinks")
        if not isinstance(links, list):
            links = []
        root_targets: list[Path] = []
        for raw_link in links:
            if not isinstance(raw_link, dict):
                continue
            link_path = raw_link.get("path")
            target = raw_link.get("target")
            if (
                isinstance(link_path, str)
                and isinstance(target, str)
                and os.path.isabs(link_path)
                and os.path.isabs(target)
                and Path(os.path.abspath(link_path)) == cleanup_root
            ):
                root_targets.append(Path(os.path.abspath(target)))
        requires_drain = row.get("requiresProcessDrain") is True
        if len(root_targets) == 1:
            workspace_requirements.append(
                WorkspaceRootRequirement(
                    cleanup_root=cleanup_root,
                    canonical_root=root_targets[0],
                    requires_runner_drain=requires_drain,
                )
            )
        elif requires_drain:
            raise RecoveryError(
                f"Process-drain cleanup root needs one exact root replacement target: "
                f"{cleanup_root} -> {root_targets}"
            )
        else:
            continue
        if not requires_drain:
            continue
        cleanup_key = display_path(cleanup_root)
        if cleanup_key in seen_cleanup_roots:
            raise RecoveryError(f"Duplicate process-drain cleanup root: {cleanup_root}")
        seen_cleanup_roots.add(cleanup_key)
        runner_requirements.append(
            RunnerDrainRequirement(
                cleanup_root=cleanup_root,
                source_runtime_root=cleanup_root / "Runtime",
                canonical_runtime_root=root_targets[0] / "Runtime",
            )
        )

    return ContractBindings(
        source_map_path=path,
        source_map_sha256=sha256_bytes(raw),
        github_accounts=github_accounts,
        github_accounts_sha256=contract_digest(github_accounts),
        repository_identities=repository_identities,
        repository_identities_sha256=contract_digest(repository_identities),
        mapping_sha256_by_source=mapping_sha256_by_source,
        runner_drain_requirements=tuple(
            sorted(
                runner_requirements,
                key=lambda value: os.fsencode(display_path(value.cleanup_root)),
            )
        ),
        workspace_root_requirements=tuple(
            sorted(
                workspace_requirements,
                key=lambda value: os.fsencode(display_path(value.cleanup_root)),
            )
        ),
        workspace_root_proof_contract=str(
            payload.get("workspaceRootProofContract", "")
        ),
    )


def parse_explicit_mapping_file(
    path: Path,
    canonical_root: Path,
    canonical_repos_root: Path,
) -> tuple[
    list[Mapping],
    list[str],
    dict[str, str],
    dict[str, dict[str, str]],
]:
    """Read an auditable source-to-canonical mapping without path guessing."""
    errors: list[str] = []
    mappings: list[Mapping] = []
    github_accounts: dict[str, str] = {}
    repository_identities: dict[str, dict[str, str]] = {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [], [f"Could not read explicit mapping file {path}: {error}"], {}, {}
    if not isinstance(payload, dict) or payload.get("format") != 1:
        return [], [f"Explicit mapping file must use format 1: {path}"], {}, {}
    rows = payload.get("mappings")
    if not isinstance(rows, list):
        return [], [f"Explicit mapping file has no mappings array: {path}"], {}, {}

    accounts_value = payload.get("githubAccounts")
    if not isinstance(accounts_value, dict):
        errors.append(f"Explicit mapping file has no githubAccounts object: {path}")
    else:
        for owner, login in accounts_value.items():
            if not isinstance(owner, str) or not re.fullmatch(r"[A-Za-z0-9-]+", owner):
                errors.append(f"Unsafe GitHub owner in githubAccounts: {owner!r}")
                continue
            if not isinstance(login, str) or not re.fullmatch(r"[A-Za-z0-9-]+", login):
                errors.append(f"Unsafe GitHub login for owner {owner}: {login!r}")
                continue
            key = owner.casefold()
            if key in github_accounts and github_accounts[key] != login:
                errors.append(f"Conflicting account binding for GitHub owner {owner}")
                continue
            github_accounts[key] = login

    identities_value = payload.get("repositoryIdentities", {})
    if not isinstance(identities_value, dict):
        errors.append(f"repositoryIdentities must be an object: {path}")
    else:
        for repository_name, identity_value in identities_value.items():
            normalized_identity = (
                normalize_remote(f"https://github.com/{repository_name}")
                if isinstance(repository_name, str)
                else ""
            )
            if not normalized_identity or not isinstance(identity_value, dict):
                errors.append(f"Invalid repositoryIdentities row: {repository_name!r}")
                continue
            database_value = identity_value.get("databaseID", "")
            node_value = identity_value.get("nodeID", "")
            database_id = str(database_value) if database_value != "" else ""
            node_id = str(node_value) if node_value != "" else ""
            if database_id and not re.fullmatch(r"[0-9]+", database_id):
                errors.append(f"Invalid decimal databaseID for {repository_name}: {database_value!r}")
                continue
            if node_id and not re.fullmatch(r"[A-Za-z0-9_-]+", node_id):
                errors.append(f"Invalid GraphQL nodeID for {repository_name}: {node_value!r}")
                continue
            if not database_id and not node_id:
                errors.append(f"Repository identity has neither databaseID nor nodeID: {repository_name}")
                continue
            repository_identities[normalized_identity] = {
                **({"databaseID": database_id} if database_id else {}),
                **({"nodeID": node_id} if node_id else {}),
            }

    for index, row in enumerate(rows, 1):
        label = f"{path} mapping {index}"
        if not isinstance(row, dict):
            errors.append(f"{label} is not an object")
            continue
        source_value = row.get("source")
        destination_name = row.get("destinationName")
        destination_owner = row.get("destinationOwner", canonical_root.name)
        if not isinstance(source_value, str) or not source_value.strip():
            errors.append(f"{label} has no source")
            continue
        if not isinstance(destination_name, str) or not destination_name.strip():
            errors.append(f"{label} has no destinationName")
            continue
        destination_name = destination_name.strip()
        if not isinstance(destination_owner, str) or not destination_owner.strip():
            errors.append(f"{label} has no destinationOwner")
            continue
        destination_owner = destination_owner.strip()
        if (
            destination_name in {".", ".."}
            or "/" in destination_name
            or "\x00" in destination_name
        ):
            errors.append(f"{label} has an unsafe destinationName: {destination_name!r}")
            continue
        if (
            destination_owner in {".", ".."}
            or "/" in destination_owner
            or "\x00" in destination_owner
        ):
            errors.append(f"{label} has an unsafe destinationOwner: {destination_owner!r}")
            continue

        retention = row.get("retention", "retain")
        if retention not in MAPPING_RETENTIONS:
            errors.append(f"{label} has an unsupported retention policy: {retention!r}")
            continue
        kind_value = row.get("kind", "explicit-source")
        if not isinstance(kind_value, str) or not re.fullmatch(r"[A-Za-z0-9._-]+", kind_value):
            errors.append(f"{label} has an unsafe kind: {kind_value!r}")
            continue
        repository = row.get("repository", "")
        if not isinstance(repository, str):
            errors.append(f"{label} repository must be a string")
            continue
        if repository and not normalize_remote(f"https://github.com/{repository}"):
            errors.append(f"{label} has an invalid GitHub repository: {repository!r}")
            continue
        legacy_repository = row.get("legacyRepository", "")
        if not isinstance(legacy_repository, str):
            errors.append(f"{label} legacyRepository must be a string")
            continue
        if legacy_repository and re.fullmatch(
            r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", legacy_repository
        ) is None:
            errors.append(
                f"{label} has an invalid legacyRepository: {legacy_repository!r}"
            )
            continue
        rearm_repository = row.get("rearmRepository", "")
        if not isinstance(rearm_repository, str):
            errors.append(f"{label} rearmRepository must be a string")
            continue
        if rearm_repository and not normalize_remote(f"https://github.com/{rearm_repository}"):
            errors.append(f"{label} has an invalid rearmRepository: {rearm_repository!r}")
            continue
        allow_identity_mismatch = row.get("allowIdentityMismatch", False)
        if not isinstance(allow_identity_mismatch, bool):
            errors.append(f"{label} allowIdentityMismatch must be true or false")
            continue
        source_policy = row.get("sourcePolicy", "auto")
        if source_policy not in SOURCE_POLICIES:
            errors.append(f"{label} has an unsupported sourcePolicy: {source_policy!r}")
            continue
        github_account = row.get("githubAccount", "")
        if not isinstance(github_account, str) or (
            github_account and not re.fullmatch(r"[A-Za-z0-9-]+", github_account)
        ):
            errors.append(f"{label} githubAccount must be a GitHub login")
            continue
        conflict_policy = row.get("conflictPolicy", "preserve-canonical")
        if conflict_policy not in CONFLICT_POLICIES:
            errors.append(f"{label} has an unsupported conflictPolicy: {conflict_policy!r}")
            continue
        if kind_value == EVIDENCE_ONLY_GIT_FRAGMENT_KIND and source_policy == "current-authoritative":
            errors.append(
                f"{label} cannot make an evidence-only Git fragment current-authoritative"
            )
            continue
        if legacy_repository:
            legacy_identity = normalize_remote(
                f"https://github.com/{legacy_repository}"
            )
            target_identity = normalize_remote(f"https://github.com/{repository}")
            if not repository or not legacy_identity or legacy_identity == target_identity:
                errors.append(
                    f"{label} legacyRepository requires a different exact target repository"
                )
                continue
            if (
                source_policy != "evidence-only"
                or conflict_policy != "preserve-canonical"
                or allow_identity_mismatch
                or rearm_repository
            ):
                errors.append(
                    f"{label} legacyRepository requires sourcePolicy=evidence-only, "
                    "conflictPolicy=preserve-canonical, allowIdentityMismatch=false, "
                    "and no rearmRepository"
                )
                continue

        exclusions_value = row.get("exclude", [])
        if not isinstance(exclusions_value, list) or not all(
            isinstance(value, str) for value in exclusions_value
        ):
            errors.append(f"{label} exclude must be an array of relative paths")
            continue
        exclusions: list[str] = []
        unsafe_exclusion = False
        for value in exclusions_value:
            relative = PurePosixPath(value.strip().rstrip("/"))
            if (
                not value.strip()
                or relative.is_absolute()
                or relative in {PurePosixPath("."), PurePosixPath("..")}
                or ".." in relative.parts
                or "\x00" in value
            ):
                errors.append(f"{label} has an unsafe excluded path: {value!r}")
                unsafe_exclusion = True
                break
            exclusions.append(relative.as_posix())
        if unsafe_exclusion:
            continue

        recovery_only_value = row.get("recoveryOnlyPaths", [])
        if not isinstance(recovery_only_value, list) or not all(
            isinstance(value, str) for value in recovery_only_value
        ):
            errors.append(f"{label} recoveryOnlyPaths must be an array of relative paths")
            continue
        recovery_only: list[str] = []
        unsafe_recovery = False
        for value in recovery_only_value:
            relative = PurePosixPath(value.strip().rstrip("/"))
            if (
                not value.strip()
                or relative.is_absolute()
                or relative in {PurePosixPath("."), PurePosixPath("..")}
                or ".." in relative.parts
                or "\x00" in value
            ):
                errors.append(f"{label} has an unsafe recovery-only path: {value!r}")
                unsafe_recovery = True
                break
            recovery_only.append(relative.as_posix())
        if unsafe_recovery:
            continue
        if any(
            relative_path_is_excluded(recovery_path, exclusions)
            or relative_path_is_excluded(excluded_path, recovery_only)
            for recovery_path in recovery_only
            for excluded_path in exclusions
        ):
            errors.append(f"{label} exclude and recoveryOnlyPaths overlap")
            continue

        source = Path(os.path.abspath(os.path.expanduser(source_value)))
        mappings.append(
            Mapping(
                source=source,
                destination=canonical_repos_root / destination_owner / destination_name,
                kind=kind_value,
                repository=repository,
                retention=retention,
                excluded_relative_paths=tuple(sorted(set(exclusions))),
                allow_identity_mismatch=allow_identity_mismatch,
                rearm_repository=rearm_repository,
                source_policy=source_policy,
                github_account=github_account,
                conflict_policy=conflict_policy,
                recovery_only_paths=tuple(sorted(set(recovery_only))),
                legacy_repository=legacy_repository,
                mapping_sha256=contract_digest(row),
            )
        )

    mapped_owners = {
        mapping.destination.parent.name.casefold(): mapping.destination.parent.name
        for mapping in mappings
    }
    for owner_key, owner_name in mapped_owners.items():
        if owner_key not in github_accounts:
            errors.append(f"Mapped GitHub owner has no githubAccounts binding: {owner_name}")
    rebound: list[Mapping] = []
    for mapping in mappings:
        bound_account = github_accounts.get(mapping.destination.parent.name.casefold(), "")
        if mapping.github_account and mapping.github_account != bound_account:
            errors.append(
                f"Mapping account conflicts with top-level githubAccounts for {mapping.source}: "
                f"{mapping.github_account} != {bound_account}"
            )
        rebound.append(dataclasses.replace(mapping, github_account=bound_account))
    return rebound, errors, github_accounts, repository_identities


def git_output(path: Path, arguments: Sequence[str], *, check: bool = False) -> str:
    result = run_command(["git", "-C", path, *arguments], check=check)
    return result.stdout.decode("utf-8", "surrogateescape").strip()


def resolve_git_dir(path: Path) -> Path | None:
    """Resolve Git only when *path itself* is the worktree root.

    ``git -C`` normally walks through parents.  Recovery sources are directory
    roots, so accepting a parent repository would silently turn a reviewed
    non-Git source into a Git source with the parent's identity and history.
    Bare/raw administration trees are handled only by the dedicated evidence
    path and therefore intentionally return ``None`` here.
    """
    if not path.is_dir() or path.is_symlink():
        return None
    top_level = run_command(
        ["git", "-C", path, "rev-parse", "--show-toplevel"],
        check=False,
    )
    if top_level.returncode != 0:
        return None
    top_value = top_level.stdout.decode("utf-8", "surrogateescape").strip()
    if not top_value:
        return None
    try:
        if canonical(Path(top_value)) != canonical(path):
            return None
    except OSError:
        return None
    result = run_command(["git", "-C", path, "rev-parse", "--absolute-git-dir"], check=False)
    if result.returncode != 0:
        return None
    value = result.stdout.decode("utf-8", "surrogateescape").strip()
    return Path(value) if value else None


def raw_git_administration_tree(path: Path) -> bool:
    """Recognize a detached/raw Git administration tree, not a worktree."""
    if not path.is_dir() or os.path.lexists(path / ".git"):
        return False
    names = {entry.name for entry in os.scandir(path)}
    required_anchor = "HEAD" in names
    administration_markers = len(names & {"config", "index", "objects", "refs", "hooks"})
    return required_anchor and administration_markers >= 2


def existing_physical_path(path: Path) -> Path | None:
    """Return the exact on-disk spelling for an existing final path component."""
    if not os.path.lexists(path):
        return None
    parent = path.parent
    try:
        target_stat = path.stat(follow_symlinks=False)
        for entry in os.scandir(parent):
            candidate = Path(entry.path)
            try:
                candidate_stat = candidate.stat(follow_symlinks=False)
            except OSError:
                continue
            if (candidate_stat.st_dev, candidate_stat.st_ino) == (
                target_stat.st_dev,
                target_stat.st_ino,
            ):
                return candidate
    except OSError as error:
        raise RecoveryError(f"Could not resolve physical path spelling for {path}: {error}") from error
    raise RecoveryError(f"Existing path was not found in its parent directory: {path}")


def same_inode(path_a: Path, path_b: Path) -> bool:
    try:
        stat_a = path_a.stat(follow_symlinks=False)
        stat_b = path_b.stat(follow_symlinks=False)
    except OSError:
        return False
    return (stat_a.st_dev, stat_a.st_ino) == (stat_b.st_dev, stat_b.st_ino)


def is_case_only_canonical_recase(mapping: Mapping) -> bool:
    if (
        not mapping.source.is_dir()
        or mapping.source.parent != mapping.destination.parent
        or mapping.source.name.casefold() != mapping.destination.name.casefold()
        or mapping.source.name == mapping.destination.name
    ):
        return False
    physical_destination = existing_physical_path(mapping.destination)
    if physical_destination is None:
        return True
    return same_inode(mapping.source, physical_destination) and (
        physical_destination.name != mapping.destination.name
    )


def git_remote(path: Path) -> str:
    return git_output(path, ["config", "--get", "remote.origin.url"])


def mapping_key(mapping: Mapping) -> tuple[str, str]:
    return (display_path(mapping.source), display_path(mapping.destination))


def discover_mappings(
    canonical_root: Path,
    canonical_repos_root: Path,
    managed_root: Path,
    stage1_root: Path,
    report_paths: Sequence[Path],
    additional_workspace_roots: Sequence[Path],
    explicit_mapping_paths: Sequence[Path],
) -> tuple[
    list[Mapping],
    list[str],
    dict[str, str],
    dict[str, dict[str, str]],
]:
    mappings: dict[str, Mapping] = {}
    errors: list[str] = []
    owner_account_bindings: dict[str, str] = {}
    repository_identities: dict[str, dict[str, str]] = {}

    canonical_by_identity: dict[str, list[Path]] = {}
    canonical_by_name: dict[tuple[str, str], Path] = {}
    canonical_owner_by_fold: dict[str, Path] = {}
    for owner_root in sorted(canonical_repos_root.iterdir(), key=lambda item: os.fsencode(item.name)):
        if not owner_root.is_dir() or owner_root.is_symlink():
            continue
        canonical_owner_by_fold[owner_root.name.casefold()] = owner_root
        for destination in sorted(owner_root.iterdir(), key=lambda item: os.fsencode(item.name)):
            if (
                not destination.is_dir()
                or destination.is_symlink()
                or STAGE_SUFFIX_RE.match(destination.name)
            ):
                continue
            canonical_by_name[(owner_root.name.casefold(), destination.name.casefold())] = destination
            identity = normalize_remote(git_remote(destination))
            if identity:
                canonical_by_identity.setdefault(identity, []).append(destination)

    # Old transaction folders are mechanically tied to the canonical basename.
    for owner_root in sorted(canonical_repos_root.iterdir(), key=lambda item: os.fsencode(item.name)):
        if not owner_root.is_dir() or owner_root.is_symlink():
            continue
        for source in sorted(owner_root.iterdir(), key=lambda item: os.fsencode(item.name)):
            if not source.is_dir() or source.is_symlink():
                continue
            match = STAGE_SUFFIX_RE.match(source.name)
            if not match:
                continue
            destination = owner_root / match.group("base")
            repository = normalize_remote(git_remote(source))
            mapping = Mapping(source, destination, "canonical-stage-duplicate", repository)
            mappings[display_path(source)] = mapping

    planned_destination_by_identity: dict[str, Path] = {}
    planned_identity_by_name: dict[tuple[str, str], str] = {}

    def register_managed_source(source: Path, kind: str) -> None:
        if not source.is_dir() or source.is_symlink():
            return
        source_identity = normalize_remote(git_remote(source))
        candidates = canonical_by_identity.get(source_identity, []) if source_identity else []
        if len(candidates) == 1:
            destination = candidates[0]
        elif len(candidates) > 1:
            joined = ", ".join(display_path(path) for path in candidates)
            errors.append(f"Ambiguous canonical identity {source_identity} for {source}: {joined}")
            return
        else:
            destination = (
                planned_destination_by_identity.get(source_identity)
                if source_identity
                else None
            )
            if destination is None:
                identity_owner = source_identity.split("/", 1)[0] if source_identity else ""
                destination = canonical_by_name.get(
                    (identity_owner.casefold(), source.name.casefold())
                )
            if destination is None:
                if not source_identity:
                    errors.append(
                        f"No canonical identity destination was found for managed source {source}"
                    )
                    return
                identity_owner, identity_repository = source_identity.split("/", 1)
                name_key = (identity_owner.casefold(), identity_repository.casefold())
                conflicting_identity = planned_identity_by_name.get(name_key)
                if conflicting_identity and conflicting_identity != source_identity:
                    errors.append(
                        f"Two repository identities would create the same canonical name {source.name}: "
                        f"{conflicting_identity} and {source_identity}"
                    )
                    return
                owner_root = canonical_owner_by_fold.get(identity_owner.casefold())
                if owner_root is None:
                    owner_root = canonical_repos_root / identity_owner
                destination = owner_root / source.name
                planned_destination_by_identity[source_identity] = destination
                planned_identity_by_name[name_key] = source_identity
            destination_identity = normalize_remote(git_remote(destination))
            if destination.exists() and source_identity and not destination_identity:
                errors.append(
                    f"Existing canonical name has no verifiable identity for managed source {source}: "
                    f"{destination}"
                )
                return
            if source_identity and destination_identity and source_identity != destination_identity:
                errors.append(
                    f"Managed source name fallback has a different identity: "
                    f"{source_identity} != {destination_identity} for {source}"
                )
                return
            if source_identity:
                planned_destination_by_identity.setdefault(source_identity, destination)
        mappings[display_path(source)] = Mapping(
            source,
            destination,
            kind,
            source_identity,
        )

    # A failed whole-workspace promotion can leave Code/Import/Runtime roots
    # beside their canonical roots. Treat every staged Repos/<owner>
    # project as a contributing source and map by GitHub identity, never by a
    # lossy UUID-suffixed destination name.
    for staged_root in sorted(managed_root.glob("*.csa-iem-stage-*")):
        repos_root = staged_root / "Repos"
        if not repos_root.is_dir() or repos_root.is_symlink():
            continue
        for owner_root in sorted(repos_root.iterdir(), key=lambda item: os.fsencode(item.name)):
            if not owner_root.is_dir() or owner_root.is_symlink():
                continue
            for source in sorted(owner_root.iterdir(), key=lambda item: os.fsencode(item.name)):
                register_managed_source(source, "managed-root-stage-copy")

    # Runtime mirrors and runner worktrees are also repository copies. They
    # must contribute local files/refs before being retired so the Code tree is
    # the only active project location.
    runtime_repos_root = managed_root / "Runtime" / "Repos"
    if runtime_repos_root.is_dir() and not runtime_repos_root.is_symlink():
        for owner_root in sorted(runtime_repos_root.iterdir(), key=lambda item: os.fsencode(item.name)):
            if not owner_root.is_dir() or owner_root.is_symlink():
                continue
            for source in sorted(owner_root.iterdir(), key=lambda item: os.fsencode(item.name)):
                register_managed_source(source, "runtime-mirror-copy")

    runners_root = managed_root / "Runtime" / "Runners"
    if runners_root.is_dir() and not runners_root.is_symlink():
        for dot_git in sorted(runners_root.glob("*/*/_work/*/*/.git")):
            register_managed_source(dot_git.parent, "runtime-runner-worktree")

    for workspace_root in additional_workspace_roots:
        for repos_root in (
            workspace_root / "Code" / "Repos",
            workspace_root / "Import" / "Repos",
            workspace_root / "Runtime" / "Repos",
        ):
            if not repos_root.is_dir() or repos_root.is_symlink():
                continue
            for owner_root in sorted(repos_root.iterdir(), key=lambda item: os.fsencode(item.name)):
                if not owner_root.is_dir() or owner_root.is_symlink():
                    continue
                for source in sorted(owner_root.iterdir(), key=lambda item: os.fsencode(item.name)):
                    register_managed_source(source, "external-workspace-copy")
        external_runners = workspace_root / "Runtime" / "Runners"
        if external_runners.is_dir() and not external_runners.is_symlink():
            for dot_git in sorted(external_runners.glob("*/*/_work/*/*/.git")):
                register_managed_source(dot_git.parent, "external-workspace-copy")

    receipt_root = managed_root / "Runtime" / "Receipts" / "Stage2"
    if receipt_root.is_dir():
        for receipt in sorted(receipt_root.rglob("*.receipt")):
            values = parse_key_value_file(receipt)
            source_value = values.get("current_source", "")
            destination_value = values.get("destination", "")
            if not source_value or not destination_value:
                continue
            source = Path(source_value)
            destination = Path(destination_value)
            if not source.is_dir() or not path_within(source, stage1_root):
                continue
            mapping = Mapping(source, destination, "stage1-retired", values.get("repository", ""))
            mappings[display_path(source)] = mapping

    all_reports = list(report_paths)
    reports_root = managed_root / "Runtime" / "Reports" / "Stage2"
    if reports_root.is_dir():
        all_reports.extend(sorted(reports_root.glob("stage2-*.md"), reverse=True))
    seen_reports: set[str] = set()
    for report in all_reports:
        report_string = display_path(report)
        if report_string in seen_reports or not report.is_file():
            continue
        seen_reports.add(report_string)
        for source, destination, repository in parse_stage2_report(report):
            if not source.is_dir() or not path_within(source, stage1_root):
                continue
            key = display_path(source)
            mappings.setdefault(key, Mapping(source, destination, "stage1", repository))

    expected_sources: list[Path] = []
    if stage1_root.is_dir():
        expected_sources.extend(
            path
            for path in stage1_root.iterdir()
            if path.name != "_temp" and path.is_dir() and not path.is_symlink()
        )
        completed = stage1_root / "_temp" / "Stage2-Completed"
        if completed.is_dir():
            for transaction in completed.iterdir():
                if not transaction.is_dir():
                    continue
                expected_sources.extend(
                    path for path in transaction.iterdir() if path.is_dir() and not path.is_symlink()
                )
    # Explicit mappings are reviewed source-to-destination decisions for
    # legacy, local-only, linked-worktree, and differently named copies. They
    # take precedence over an automatic identity/name guess for the same exact
    # source. The map is the reviewed decision for historical paths that were
    # renamed, copied, or moved through a partial Stage 2 transaction.
    for mapping_path in explicit_mapping_paths:
        (
            explicit_mappings,
            explicit_errors,
            explicit_accounts,
            explicit_identities,
        ) = parse_explicit_mapping_file(
            mapping_path,
            canonical_root,
            canonical_repos_root,
        )
        errors.extend(explicit_errors)
        for owner, login in explicit_accounts.items():
            existing_login = owner_account_bindings.get(owner)
            if existing_login and existing_login != login:
                errors.append(
                    f"Conflicting githubAccounts binding for {owner}: {existing_login} / {login}"
                )
            else:
                owner_account_bindings[owner] = login
        for repository_identity, identity in explicit_identities.items():
            existing_identity = repository_identities.get(repository_identity)
            if existing_identity and existing_identity != identity:
                errors.append(
                    f"Conflicting repositoryIdentities row for {repository_identity}"
                )
            else:
                repository_identities[repository_identity] = identity
        for explicit in explicit_mappings:
            key = display_path(explicit.source)
            mappings[key] = explicit

    # Evaluate Stage 1 coverage after the reviewed map has replaced any
    # automatic row. A review-authorized redirect is sufficient coverage; an
    # unbound source remains a hard stop.
    for source in expected_sources:
        if display_path(source) not in mappings:
            errors.append(f"No Stage 2 identity mapping was found for {source}")

    rebound_mappings: list[Mapping] = []
    for mapping in mappings.values():
        owner_key = mapping.destination.parent.name.casefold()
        account = owner_account_bindings.get(owner_key, "")
        if not account:
            errors.append(
                f"Mapped owner has no reviewed githubAccounts binding: "
                f"{mapping.destination.parent.name} for {mapping.source}"
            )
        if mapping.github_account and account and mapping.github_account != account:
            errors.append(
                f"Mapping account conflicts with reviewed owner binding for {mapping.source}: "
                f"{mapping.github_account} != {account}"
            )
        rebound_mappings.append(dataclasses.replace(mapping, github_account=account))

    ordered = sorted(
        rebound_mappings,
        key=lambda item: (
            0 if item.kind == "canonical-stage-duplicate" else 1,
            os.fsencode(display_path(item.destination)),
            os.fsencode(display_path(item.source)),
        ),
    )
    return ordered, errors, owner_account_bindings, repository_identities


def validate_mapping(
    mapping: Mapping,
    canonical_root: Path,
    canonical_repos_root: Path,
    managed_root: Path,
    stage1_root: Path,
    additional_workspace_roots: Sequence[Path],
) -> list[str]:
    errors: list[str] = []
    source = mapping.source
    destination = mapping.destination
    if not source.is_dir() or source.is_symlink():
        errors.append(f"Source is not a real directory: {source}")
    if mapping.retention not in MAPPING_RETENTIONS:
        errors.append(f"Unsupported retention policy for {source}: {mapping.retention}")
    if mapping.source_policy not in SOURCE_POLICIES:
        errors.append(f"Unsupported source policy for {source}: {mapping.source_policy}")
    if mapping.conflict_policy not in CONFLICT_POLICIES:
        errors.append(f"Unsupported conflict policy for {source}: {mapping.conflict_policy}")
    if mapping.conflict_policy == "source-wins-after-preserve" and not (
        mapping.kind == "explicit-active-checkout-source"
        and mapping.source_policy == "current-authoritative"
        and mapping.retention == "retain"
        and not mapping.allow_identity_mismatch
    ):
        errors.append(
            f"source-wins-after-preserve is restricted to a retained, exact-identity "
            f"current active checkout: {source}"
        )
    if mapping.kind.startswith("explicit-") and len(source.parts) < 4:
        errors.append(f"Explicit source boundary is too broad: {source}")
    destination_parts: tuple[str, ...] = ()
    if path_within(destination, canonical_repos_root):
        try:
            destination_parts = destination.relative_to(canonical_repos_root).parts
        except ValueError:
            destination_parts = ()
    if len(destination_parts) != 2:
        errors.append(f"Destination is outside the canonical owner/repository layout: {destination}")
    case_only_recase = is_case_only_canonical_recase(mapping) if source.is_dir() else False
    source_destination_same_inode = (
        destination.exists() and source.exists() and same_inode(source, destination)
    )
    if source_destination_same_inode and not case_only_recase:
        errors.append(
            f"Source and destination resolve to the same inode without an exact case-only recase: "
            f"{source} -> {destination}"
        )
    elif not case_only_recase and (
        source == destination
        or path_within(destination, source)
        or path_within(source, destination)
    ):
        errors.append(f"Source/destination containment is unsafe: {source} -> {destination}")
    if mapping.kind == "canonical-stage-duplicate" and source.parent != canonical_root:
        errors.append(f"Unexpected stage-duplicate boundary: {source}")
    if mapping.kind.startswith("stage1") and not path_within(source, stage1_root):
        errors.append(f"Unexpected Stage 1 boundary: {source}")
    if mapping.kind == "managed-root-stage-copy":
        if not path_within(source, managed_root):
            errors.append(f"Managed staging source is outside the managed root: {source}")
        else:
            relative_parts = source.relative_to(managed_root).parts
            if not relative_parts or not STAGE_SUFFIX_RE.match(relative_parts[0]):
                errors.append(f"Unexpected managed staging source boundary: {source}")
    if mapping.kind == "runtime-mirror-copy":
        runtime_repos_root = managed_root / "Runtime" / "Repos"
        relative_parts = (
            source.relative_to(runtime_repos_root).parts
            if path_within(source, runtime_repos_root)
            else ()
        )
        if len(relative_parts) != 2:
            errors.append(f"Unexpected Runtime mirror boundary: {source}")
    if mapping.kind == "runtime-runner-worktree":
        runners_root = managed_root / "Runtime" / "Runners"
        relative_parts = (
            source.relative_to(runners_root).parts
            if path_within(source, runners_root)
            else ()
        )
        if len(relative_parts) != 5 or relative_parts[2] != "_work":
            errors.append(f"Unexpected Runtime runner worktree boundary: {source}")
    if mapping.kind == "external-workspace-copy":
        if not any(path_within(source, root) and source != root for root in additional_workspace_roots):
            errors.append(f"External workspace source is outside every approved root: {source}")
    if destination.exists() and (not destination.is_dir() or destination.is_symlink()):
        errors.append(f"Canonical destination is not a real directory: {destination}")

    for relative in mapping.excluded_relative_paths:
        excluded = source / relative
        if not os.path.lexists(excluded):
            errors.append(f"Reviewed excluded path does not exist: {excluded}")
    for relative in mapping.recovery_only_paths:
        recovery_only = source / relative
        if not os.path.lexists(recovery_only):
            errors.append(f"Reviewed recovery-only path does not exist: {recovery_only}")
        if relative_path_is_excluded(relative, mapping.excluded_relative_paths):
            errors.append(f"Recovery-only path overlaps an excluded path: {recovery_only}")

    raw_fragment = raw_git_administration_tree(source) if source.is_dir() else False
    if raw_fragment and mapping.kind != EVIDENCE_ONLY_GIT_FRAGMENT_KIND:
        errors.append(
            f"Raw Git administration tree requires kind {EVIDENCE_ONLY_GIT_FRAGMENT_KIND}: {source}"
        )
    if mapping.kind == EVIDENCE_ONLY_GIT_FRAGMENT_KIND and not raw_fragment:
        errors.append(f"Evidence-only Git fragment source is not a raw Git administration tree: {source}")
    if mapping.kind == EVIDENCE_ONLY_GIT_FRAGMENT_KIND and mapping.source_policy == "current-authoritative":
        errors.append(f"Git fragment cannot be current-authoritative: {source}")

    source_remote = (
        normalize_remote(git_remote(source))
        if source.is_dir() and not raw_fragment
        else ""
    )
    destination_remote = normalize_remote(git_remote(destination)) if destination.is_dir() else ""
    expected_remote = (
        normalize_remote(f"https://github.com/{mapping.repository}")
        if mapping.repository
        else ""
    )
    legacy_remote = (
        normalize_remote(f"https://github.com/{mapping.legacy_repository}")
        if mapping.legacy_repository
        else ""
    )
    legacy_policy_valid = bool(
        legacy_remote
        and expected_remote
        and legacy_remote != expected_remote
        and mapping.source_policy == "evidence-only"
        and mapping.conflict_policy == "preserve-canonical"
        and not mapping.allow_identity_mismatch
        and not mapping.rearm_repository
    )
    legacy_identity_match = bool(
        legacy_policy_valid
        and legacy_remote
        and source_remote
        and source_remote == legacy_remote
    )
    if mapping.legacy_repository:
        if not legacy_policy_valid:
            errors.append(
                f"Unsafe legacyRepository policy for {source}: "
                f"{mapping.legacy_repository} -> {mapping.repository}"
            )
        if not legacy_identity_match:
            errors.append(
                f"Legacy source identity does not match its reviewed legacyRepository: "
                f"{source_remote or 'unverified'} != {legacy_remote or 'invalid'} for {source}"
            )
    layout_remote = (
        f"{destination_parts[0].casefold()}/{destination_parts[1].casefold()}"
        if len(destination_parts) == 2
        else ""
    )
    if expected_remote and layout_remote and expected_remote != layout_remote:
        errors.append(
            f"Reviewed repository does not match canonical owner/name layout for {source}: "
            f"{expected_remote} != {layout_remote}"
        )
    if (
        source_remote
        and destination_remote
        and source_remote != destination_remote
        and not mapping.allow_identity_mismatch
        and not legacy_identity_match
    ):
        errors.append(
            f"Git identity mismatch for {source}: {source_remote} != {destination_remote}"
        )
    if expected_remote and destination_remote and expected_remote != destination_remote:
        errors.append(
            f"Canonical destination identity does not match reviewed repository for {source}: "
            f"{destination_remote} != {expected_remote}"
        )
    if (
        expected_remote
        and source_remote
        and expected_remote != source_remote
        and not mapping.allow_identity_mismatch
        and not legacy_identity_match
    ):
        errors.append(
            f"Source identity does not match reviewed repository for {source}: "
            f"{source_remote} != {expected_remote}"
        )
    target_repository = mapping.rearm_repository or mapping.repository
    derivation_exception = (
        exact_derivation_exception(mapping, target_repository)
        if target_repository and source.is_dir()
        else False
    )
    non_git_bootstrap = (
        exact_non_git_bootstrap(mapping, target_repository)
        if target_repository and source.is_dir()
        else False
    )
    if mapping.allow_identity_mismatch and not derivation_exception:
        errors.append(
            f"Generic identity mismatch is prohibited; no exact derivation exception matched: {source}"
        )
    if mapping.source_policy == "current-authoritative" and not (
        derivation_exception
        or non_git_bootstrap
        or (source_remote and source_remote == expected_remote)
    ):
        errors.append(
            f"Current-authoritative source lacks an exact identity/bootstrap proof: "
            f"{source_remote or 'unverified'} != {expected_remote or 'missing-review'} for {source}"
        )
    if mapping.rearm_repository:
        rearm_identity = normalize_remote(f"https://github.com/{mapping.rearm_repository}")
        reviewed_identity = (
            normalize_remote(f"https://github.com/{mapping.repository}")
            if mapping.repository
            else rearm_identity
        )
        if rearm_identity != reviewed_identity:
            errors.append(
                f"Re-arm identity does not match reviewed repository for {source}: "
                f"{rearm_identity} != {reviewed_identity}"
            )
    return errors


def validate_canonical_identity_groups(canonical_repos_root: Path) -> list[str]:
    groups: dict[str, list[Path]] = {}
    for owner_root in canonical_repos_root.iterdir():
        if not owner_root.is_dir() or owner_root.is_symlink():
            continue
        for path in owner_root.iterdir():
            if not path.is_dir() or path.is_symlink() or STAGE_SUFFIX_RE.match(path.name):
                continue
            remote = normalize_remote(git_remote(path))
            if remote:
                groups.setdefault(remote, []).append(path)
    errors: list[str] = []
    for remote, paths in sorted(groups.items()):
        if len(paths) > 1:
            joined = ", ".join(display_path(path) for path in paths)
            errors.append(f"Multiple canonical folders already claim {remote}: {joined}")
    return errors


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".partial")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    guarded_replace(temporary, path)


def fsync_directory(path: Path) -> None:
    descriptor = os.open(path, os.O_RDONLY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def write_fsynced_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".partial")
    payload = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")
    with temporary.open("wb") as handle:
        handle.write(payload)
        handle.flush()
        os.fsync(handle.fileno())
    guarded_replace(temporary, path)
    fsync_directory(path.parent)


def mapping_to_json(mapping: Mapping) -> dict[str, object]:
    return {
        "source": display_path(mapping.source),
        "destination": display_path(mapping.destination),
        "kind": mapping.kind,
        "repository": mapping.repository,
        "retention": mapping.retention,
        "excludedRelativePaths": list(mapping.excluded_relative_paths),
        "allowIdentityMismatch": mapping.allow_identity_mismatch,
        "rearmRepository": mapping.rearm_repository,
        "sourcePolicy": mapping.source_policy,
        "githubAccount": mapping.github_account,
        "conflictPolicy": mapping.conflict_policy,
        "recoveryOnlyPaths": list(mapping.recovery_only_paths),
        "legacyRepository": mapping.legacy_repository,
    }


def write_preflight_report(
    report_dir: Path,
    transaction: str,
    mappings: Sequence[Mapping],
    errors: Sequence[str],
    canonical_root: Path,
    stage1_root: Path,
    owner_account_bindings: dict[str, str],
    repository_identities: dict[str, dict[str, str]],
    live_repositories: dict[str, LiveRepository],
    pending_repository_creations: Sequence[str],
    runtime_roots_requiring_drain: Sequence[Path],
    runner_drain_proofs: dict[str, RunnerDrainProof],
) -> Path:
    report_dir.mkdir(parents=True, exist_ok=True)
    plan_path = report_dir / "plan.json"
    write_json(
        plan_path,
        {
            "format": 1,
            "transaction": transaction,
            "canonicalRoot": display_path(canonical_root),
            "stage1Root": display_path(stage1_root),
            "mappingCount": len(mappings),
            "errors": list(errors),
            "githubAccounts": dict(sorted(owner_account_bindings.items())),
            "repositoryIdentities": dict(sorted(repository_identities.items())),
            "liveRepositories": {
                key: dataclasses.asdict(value)
                for key, value in sorted(live_repositories.items())
            },
            "pendingPrivateEmptyRepositoryCreations": sorted(pending_repository_creations),
            "runtimeRootsRequiringDrain": [
                display_path(path) for path in runtime_roots_requiring_drain
            ],
            "runnerDrainProofs": {
                key: runner_drain_proof_to_json(value)
                for key, value in sorted(runner_drain_proofs.items())
            },
            "mappings": [mapping_to_json(mapping) for mapping in mappings],
        },
    )
    duplicate_count = sum(mapping.kind == "canonical-stage-duplicate" for mapping in mappings)
    managed_stage_count = sum(mapping.kind == "managed-root-stage-copy" for mapping in mappings)
    runtime_mirror_count = sum(mapping.kind == "runtime-mirror-copy" for mapping in mappings)
    runner_count = sum(mapping.kind == "runtime-runner-worktree" for mapping in mappings)
    external_count = sum(mapping.kind == "external-workspace-copy" for mapping in mappings)
    stage1_count = sum(mapping.kind.startswith("stage1") for mapping in mappings)
    lines = [
        "# CSA-iEM Repository Consolidation Preflight",
        "",
        f"- Transaction: `{transaction}`",
        f"- Canonical root: `{canonical_root}`",
        f"- Stage 1 root: `{stage1_root}`",
        f"- Canonical staging duplicates: **{duplicate_count}**",
        f"- Managed-root staging copies: **{managed_stage_count}**",
        f"- Active Runtime repository mirrors: **{runtime_mirror_count}**",
        f"- Active Runtime runner worktrees: **{runner_count}**",
        f"- Protected external workspace copies: **{external_count}**",
        f"- Stage 1/retired project copies: **{stage1_count}**",
        f"- Total source copies: **{len(mappings)}**",
        f"- Blocking errors: **{len(errors)}**",
        f"- Reviewed private empty repositories pending creation on apply: **{len(pending_repository_creations)}**",
        f"- Runtime roots requiring exact runner drain proof: **{len(runtime_roots_requiring_drain)}**",
        f"- Valid transaction-bound runner drain proofs: **{len(runner_drain_proofs)}**",
        "",
        "| Kind | Source | Canonical destination | Destination state |",
        "|---|---|---|---|",
    ]
    for mapping in mappings:
        destination_state = "existing" if mapping.destination.is_dir() else "create"
        lines.append(
            f"| {mapping.kind} | `{mapping.source}` | `{mapping.destination}` | {destination_state} |"
        )
    if errors:
        lines.extend(["", "## Blocking errors", ""])
        lines.extend(f"- {error}" for error in errors)
    lines.extend(
        [
            "",
            "## Lossless merge invariant",
            "",
            "Canonical paths are create-only unless a reviewed active checkout passes the exact identity, strict Git, descendant-history, and source-wins preservation gates. Source-only paths activate only from a verified current/descendant or narrowly reviewed current-authoritative source; every other unmatched path is represented under `.csa-iem-recovery`. Every source entry and Git component is fully revalidated after assembly and promotion. Retirement is a reversible, journaled move into same-volume managed `_temp`; this phase performs no permanent deletion.",
            "",
        ]
    )
    report_path = report_dir / "preflight.md"
    report_path.write_text("\n".join(lines), encoding="utf-8")
    return report_path


def lstat_or_none(path: Path) -> os.stat_result | None:
    try:
        return path.lstat()
    except FileNotFoundError:
        return None


def file_kind(file_stat: os.stat_result) -> str:
    mode = file_stat.st_mode
    if stat.S_ISREG(mode):
        return "file"
    if stat.S_ISDIR(mode):
        return "directory"
    if stat.S_ISLNK(mode):
        return "symlink"
    return "special"


def verification_stat_key(file_stat: os.stat_result) -> tuple[int, ...]:
    """Return the mutation-sensitive identity used by verification caches.

    Content, ACL, and extended-attribute cache entries are reusable only while
    the same filesystem object retains its size, ownership, mode, flags, link
    count, mtime, and ctime.  The caller re-lstats around every cache lookup,
    so a changed object always falls back to a fresh read or fails closed.
    """
    return (
        int(file_stat.st_dev),
        int(file_stat.st_ino),
        int(file_stat.st_mode),
        int(file_stat.st_nlink),
        int(file_stat.st_uid),
        int(file_stat.st_gid),
        int(file_stat.st_size),
        int(file_stat.st_mtime_ns),
        int(file_stat.st_ctime_ns),
        int(getattr(file_stat, "st_flags", 0)),
    )


def verification_cache_path(path: Path) -> str:
    return os.path.abspath(os.fspath(path))


def close_persistent_hash_index() -> None:
    global _PERSISTENT_HASH_INDEX
    with _PERSISTENT_HASH_INDEX_LOCK:
        connection = _PERSISTENT_HASH_INDEX
        _PERSISTENT_HASH_INDEX = None
        if connection is None:
            return
        try:
            connection.commit()
            connection.close()
        except sqlite3.Error:
            _PERSISTENT_HASH_INDEX_STATS["errors"] += 1


def configure_persistent_hash_index(
    path: Path,
    transaction: str,
    *,
    excluded_roots: Sequence[Path] = (),
) -> None:
    """Open the cross-transaction stat-bound SHA-256 index.

    A cached checksum is reusable only for the same absolute path and complete
    mutation-sensitive stat key. Callers still lstat before and after lookup.
    Cache failure is an optimization failure, never verification success.
    """
    global _PERSISTENT_HASH_INDEX, _PERSISTENT_HASH_INDEX_PATH
    global _PERSISTENT_HASH_INDEX_TRANSACTION
    global _PERSISTENT_HASH_INDEX_EXCLUDED_ROOTS
    index_path = Path(os.path.abspath(path))
    index_path.parent.mkdir(parents=True, exist_ok=True)
    if index_path.parent.is_symlink():
        raise RecoveryError(f"Hash-index parent is a symlink: {index_path.parent}")
    with _PERSISTENT_HASH_INDEX_LOCK:
        close_persistent_hash_index()
        try:
            connection = sqlite3.connect(
                index_path,
                timeout=30.0,
                check_same_thread=False,
            )
            connection.execute("PRAGMA journal_mode=WAL")
            connection.execute("PRAGMA synchronous=FULL")
            connection.execute("PRAGMA temp_store=MEMORY")
            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS stable_hash_v1 (
                    path TEXT NOT NULL,
                    stat_key TEXT NOT NULL,
                    sha256 TEXT NOT NULL,
                    last_seen_transaction TEXT NOT NULL,
                    PRIMARY KEY (path, stat_key)
                )
                """
            )
            connection.execute(
                "CREATE INDEX IF NOT EXISTS stable_hash_v1_path ON stable_hash_v1(path)"
            )
            connection.commit()
        except sqlite3.Error as error:
            _PERSISTENT_HASH_INDEX_STATS["errors"] += 1
            raise RecoveryError(f"Could not open persistent checksum index {index_path}: {error}") from error
        _PERSISTENT_HASH_INDEX = connection
        _PERSISTENT_HASH_INDEX_PATH = index_path
        _PERSISTENT_HASH_INDEX_TRANSACTION = transaction
        _PERSISTENT_HASH_INDEX_EXCLUDED_ROOTS = tuple(
            Path(os.path.abspath(root)) for root in excluded_roots
        )


def persistent_hash_index_key(expected_stat_key: tuple[int, ...]) -> str:
    return json.dumps(expected_stat_key, separators=(",", ":"))


def persistent_hash_lookup(
    path_text: str,
    expected_stat_key: tuple[int, ...],
) -> str | None:
    path = Path(path_text)
    if any(lexical_path_within(path, root) for root in _PERSISTENT_HASH_INDEX_EXCLUDED_ROOTS):
        _PERSISTENT_HASH_INDEX_STATS["misses"] += 1
        return None
    with _PERSISTENT_HASH_INDEX_LOCK:
        connection = _PERSISTENT_HASH_INDEX
        if connection is None:
            _PERSISTENT_HASH_INDEX_STATS["misses"] += 1
            return None
        try:
            row = connection.execute(
                "SELECT sha256 FROM stable_hash_v1 WHERE path = ? AND stat_key = ?",
                (path_text, persistent_hash_index_key(expected_stat_key)),
            ).fetchone()
        except sqlite3.Error:
            _PERSISTENT_HASH_INDEX_STATS["errors"] += 1
            _PERSISTENT_HASH_INDEX_STATS["misses"] += 1
            return None
        if row is None or not isinstance(row[0], str) or not SHA256_RE.fullmatch(row[0]):
            _PERSISTENT_HASH_INDEX_STATS["misses"] += 1
            return None
        _PERSISTENT_HASH_INDEX_STATS["hits"] += 1
        return row[0]


def persistent_hash_store(
    path_text: str,
    expected_stat_key: tuple[int, ...],
    digest: str,
    transaction: str,
) -> None:
    if not SHA256_RE.fullmatch(digest):
        raise RecoveryError(f"Refused invalid SHA-256 cache value for {path_text}")
    path = Path(path_text)
    if any(lexical_path_within(path, root) for root in _PERSISTENT_HASH_INDEX_EXCLUDED_ROOTS):
        return
    with _PERSISTENT_HASH_INDEX_LOCK:
        connection = _PERSISTENT_HASH_INDEX
        if connection is None:
            return
        try:
            stat_key = persistent_hash_index_key(expected_stat_key)
            connection.execute(
                "DELETE FROM stable_hash_v1 WHERE path = ? AND stat_key <> ?",
                (path_text, stat_key),
            )
            connection.execute(
                """
                INSERT OR REPLACE INTO stable_hash_v1
                    (path, stat_key, sha256, last_seen_transaction)
                VALUES (?, ?, ?, ?)
                """,
                (path_text, stat_key, digest, transaction),
            )
            _PERSISTENT_HASH_INDEX_STATS["writes"] += 1
            if _PERSISTENT_HASH_INDEX_STATS["writes"] % 512 == 0:
                connection.commit()
        except sqlite3.Error:
            _PERSISTENT_HASH_INDEX_STATS["errors"] += 1


def persistent_hash_index_report() -> dict[str, object]:
    with _PERSISTENT_HASH_INDEX_LOCK:
        connection = _PERSISTENT_HASH_INDEX
        entry_count = 0
        if connection is not None:
            try:
                connection.commit()
                row = connection.execute(
                    "SELECT COUNT(*) FROM stable_hash_v1"
                ).fetchone()
                entry_count = int(row[0]) if row else 0
            except (sqlite3.Error, TypeError, ValueError):
                _PERSISTENT_HASH_INDEX_STATS["errors"] += 1
        return {
            "format": PERSISTENT_HASH_INDEX_FORMAT,
            "path": display_path(_PERSISTENT_HASH_INDEX_PATH)
            if _PERSISTENT_HASH_INDEX_PATH
            else "",
            "entryCount": entry_count,
            **_PERSISTENT_HASH_INDEX_STATS,
        }


atexit.register(close_persistent_hash_index)


@functools.lru_cache(maxsize=VERIFICATION_CACHE_SIZE)
def _stable_file_hash_cached(
    path_text: str,
    expected_stat_key: tuple[int, ...],
) -> str:
    path = Path(path_text)
    before = path.lstat()
    if verification_stat_key(before) != expected_stat_key:
        raise RecoveryError(f"File changed before checksum cache read: {path}")
    if not stat.S_ISREG(before.st_mode):
        raise RecoveryError(f"Expected regular file while hashing: {path}")
    indexed_digest = persistent_hash_lookup(path_text, expected_stat_key)
    if indexed_digest is not None:
        after_index = path.lstat()
        if verification_stat_key(after_index) != expected_stat_key:
            raise RecoveryError(f"File changed during persistent checksum lookup: {path}")
        return indexed_digest
    digest = hashlib.sha256()
    with path.open("rb", buffering=1024 * 1024) as handle:
        while True:
            block = handle.read(4 * 1024 * 1024)
            if not block:
                break
            digest.update(block)
    after = path.lstat()
    if verification_stat_key(after) != expected_stat_key:
        raise RecoveryError(f"File changed while being checksum-audited: {path}")
    value = digest.hexdigest()
    persistent_hash_store(
        path_text,
        expected_stat_key,
        value,
        _PERSISTENT_HASH_INDEX_TRANSACTION,
    )
    return value


def stable_file_hash(path: Path) -> tuple[str, os.stat_result]:
    before = path.lstat()
    expected_stat_key = verification_stat_key(before)
    digest = _stable_file_hash_cached(
        verification_cache_path(path),
        expected_stat_key,
    )
    after = path.lstat()
    if verification_stat_key(after) != expected_stat_key:
        raise RecoveryError(f"File changed during checksum cache lookup: {path}")
    return digest, after


def xattr_signature(path: Path) -> tuple[tuple[str, str], ...]:
    if not hasattr(os, "listxattr"):
        return ()
    try:
        names = os.listxattr(path, follow_symlinks=False)
    except NotImplementedError:
        return ()
    except OSError as error:
        raise RecoveryError(f"Could not enumerate extended attributes for {path}: {error}") from error
    values: list[tuple[str, str]] = []
    for name in sorted(names, key=os.fsencode):
        try:
            value = os.getxattr(path, name, follow_symlinks=False)
        except NotImplementedError:
            continue
        except OSError as error:
            raise RecoveryError(f"Could not read extended attribute {name!r} for {path}: {error}") from error
        encoded_name = base64.b64encode(os.fsencode(name)).decode("ascii")
        values.append((encoded_name, hashlib.sha256(value).hexdigest()))
    return tuple(values)


@functools.lru_cache(maxsize=1)
def acl_library() -> ctypes.CDLL:
    library_name = ctypes.util.find_library("System")
    if not library_name:
        raise RecoveryError("Could not locate the macOS ACL library")
    library = ctypes.CDLL(library_name, use_errno=True)
    for function_name in ("acl_get_file", "acl_get_link_np"):
        function = getattr(library, function_name)
        function.argtypes = [ctypes.c_char_p, ctypes.c_int]
        function.restype = ctypes.c_void_p
    library.acl_free.argtypes = [ctypes.c_void_p]
    library.acl_free.restype = ctypes.c_int
    return library


def has_extended_acl(path: Path) -> bool:
    """Probe ACL presence natively; preserve the existing ls-based digest."""
    if sys.platform != "darwin":
        return False
    mode = path.lstat().st_mode
    library = acl_library()
    getter = library.acl_get_link_np if stat.S_ISLNK(mode) else library.acl_get_file
    ctypes.set_errno(0)
    acl = getter(os.fsencode(path), 0x00000100)  # ACL_TYPE_EXTENDED
    if acl:
        library.acl_free(acl)
        return True
    error_number = ctypes.get_errno()
    no_acl_errors = {
        errno.ENOENT,
        getattr(errno, "ENODATA", errno.ENOENT),
        errno.ENOTSUP,
        errno.EOPNOTSUPP,
    }
    if error_number in no_acl_errors:
        return False
    raise RecoveryError(f"Could not probe ACL metadata for {path}: errno {error_number}")


def acl_signature(path: Path) -> str:
    """Return a stable digest of a macOS extended ACL, when the OS exposes it.

    Python's standard library has no portable ACL API. On macOS, ``ls -lde``
    prints numbered ACL entries after its ordinary stat row. Only those ACL
    rows are hashed, so path names, timestamps, and localized ownership text
    cannot contaminate the proof. Failure to inspect ACLs is fatal: cleanup
    must not claim ACL preservation when it could not measure it.
    """
    if sys.platform != "darwin":
        return "not-available-on-platform"
    if not has_extended_acl(path):
        return hashlib.sha256(b"").hexdigest()
    result = run_command(
        ["/bin/ls", "-lde", "--", path],
        check=False,
    )
    if result.returncode != 0:
        diagnostics = (result.stdout + result.stderr).decode("utf-8", "replace").strip()
        raise RecoveryError(f"Could not inspect ACL for {path}: {diagnostics}")
    acl_rows: list[bytes] = []
    for line in result.stdout.splitlines()[1:]:
        stripped = line.strip()
        if re.match(rb"^[0-9]+:\s", stripped):
            acl_rows.append(stripped)
    payload = b"\n".join(acl_rows)
    return hashlib.sha256(payload).hexdigest()


@functools.lru_cache(maxsize=VERIFICATION_CACHE_SIZE)
def _metadata_signature_cached(
    path_text: str,
    expected_stat_key: tuple[int, ...],
    expected_xattrs: tuple[tuple[str, str], ...],
) -> ExactMetadata:
    path = Path(path_text)
    before = path.lstat()
    if verification_stat_key(before) != expected_stat_key:
        raise RecoveryError(f"Path changed before metadata cache read: {path}")
    observed_xattrs = xattr_signature(path)
    if observed_xattrs != expected_xattrs:
        raise RecoveryError(f"Extended attributes changed before metadata cache read: {path}")
    result = ExactMetadata(
        mode=stat.S_IMODE(before.st_mode),
        uid=int(before.st_uid),
        gid=int(before.st_gid),
        flags=int(getattr(before, "st_flags", 0)),
        mtime_ns=int(before.st_mtime_ns),
        xattrs=observed_xattrs,
        acl_digest=acl_signature(path),
    )
    after = path.lstat()
    if verification_stat_key(after) != expected_stat_key:
        raise RecoveryError(f"Path changed while metadata was being verified: {path}")
    return result


def metadata_signature(path: Path, file_stat: os.stat_result) -> ExactMetadata:
    expected_stat_key = verification_stat_key(file_stat)
    current = path.lstat()
    if verification_stat_key(current) != expected_stat_key:
        raise RecoveryError(f"Path changed before metadata verification: {path}")
    # APFS security provenance can appear without a reliable stat-key change.
    # Bind the cache key to a freshly read xattr signature so a later source
    # cannot reuse metadata measured before provenance changed.
    current_xattrs = xattr_signature(path)
    result = _metadata_signature_cached(
        verification_cache_path(path),
        expected_stat_key,
        current_xattrs,
    )
    after = path.lstat()
    if verification_stat_key(after) != expected_stat_key:
        raise RecoveryError(f"Path changed during metadata cache lookup: {path}")
    return result


def clear_verification_caches() -> None:
    """Bound cache lifetime to one destination/global verification phase."""
    _stable_file_hash_cached.cache_clear()
    _metadata_signature_cached.cache_clear()


def record_only_metadata(file_stat: os.stat_result) -> RecordOnlyMetadata:
    birthtime = getattr(file_stat, "st_birthtime", 0.0)
    birthtime_ns = int(round(float(birthtime) * 1_000_000_000)) if birthtime else 0
    allocated_bytes = int(getattr(file_stat, "st_blocks", 0)) * 512
    return RecordOnlyMetadata(
        birthtime_ns=birthtime_ns,
        atime_ns=int(file_stat.st_atime_ns),
        allocated_bytes=allocated_bytes,
        logical_bytes=int(file_stat.st_size),
    )


def contract_acl_digest(path: Path) -> str:
    """ACL digest byte-compatible with repo-consolidation-local-cleanup.py."""
    if sys.platform != "darwin":
        return ""
    if not has_extended_acl(path):
        return sha256_bytes(b"")
    result = run_command(["/bin/ls", "-lde", path], check=False)
    if result.returncode != 0:
        raise RecoveryError(f"Could not read ACL metadata for {path}")
    lines = result.stdout.decode("utf-8", "surrogateescape").splitlines()[1:]
    return sha256_bytes("\n".join(lines).encode("utf-8", "surrogateescape"))


def contract_xattr_digests(path: Path) -> dict[str, str]:
    """No-follow xattr digest map compatible with the cleanup verifier."""
    if hasattr(os, "listxattr") and hasattr(os, "getxattr"):
        try:
            names = os.listxattr(path, follow_symlinks=False)
        except OSError as error:
            if error.errno in {errno.ENOTSUP, errno.EOPNOTSUPP}:
                return {}
            raise RecoveryError(
                f"Could not enumerate extended attributes for {path}: {error}"
            ) from error
        values: dict[str, str] = {}
        for name in sorted(names, key=os.fsencode):
            try:
                payload = os.getxattr(path, name, follow_symlinks=False)
            except OSError as error:
                raise RecoveryError(
                    f"Could not read extended attribute {name!r} from {path}: {error}"
                ) from error
            values[name] = sha256_bytes(payload)
        return values
    if sys.platform != "darwin" or not Path("/usr/bin/xattr").is_file():
        raise RecoveryError(f"No no-follow extended-attribute reader is available for {path}")
    symlink_option = ["-s"] if stat.S_ISLNK(path.lstat().st_mode) else []
    listing = run_command(["/usr/bin/xattr", *symlink_option, path], check=False)
    if listing.returncode != 0:
        raise RecoveryError(f"Could not enumerate extended attributes for {path}")
    names = [
        line
        for line in listing.stdout.decode("utf-8", "surrogateescape").splitlines()
        if line
    ]
    values: dict[str, str] = {}
    for name in sorted(names, key=os.fsencode):
        read = run_command(
            ["/usr/bin/xattr", *symlink_option, "-p", "-x", name, path],
            check=False,
        )
        if read.returncode != 0:
            raise RecoveryError(f"Could not read extended attribute {name!r} from {path}")
        try:
            payload = bytes.fromhex("".join(read.stdout.decode("ascii").split()))
        except (UnicodeError, ValueError) as error:
            raise RecoveryError(
                f"Could not decode extended attribute {name!r} from {path}"
            ) from error
        values[name] = sha256_bytes(payload)
    return values


def contract_stable_fingerprint(path: Path) -> dict[str, object]:
    metadata = path.lstat()
    mode = metadata.st_mode
    if stat.S_ISREG(mode):
        object_type = "file"
        payload_digest, after_hash = stable_file_hash(path)
        metadata = after_hash
    elif stat.S_ISDIR(mode):
        object_type = "directory"
        payload_digest = ""
    elif stat.S_ISLNK(mode):
        object_type = "symlink"
        payload_digest = sha256_bytes(os.fsencode(os.readlink(path)))
    elif stat.S_ISSOCK(mode):
        object_type = "socket"
        payload_digest = ""
    elif stat.S_ISFIFO(mode):
        object_type = "fifo"
        payload_digest = ""
    elif stat.S_ISCHR(mode) or stat.S_ISBLK(mode):
        object_type = "device"
        payload_digest = ""
    else:
        object_type = "special"
        payload_digest = ""
    exact_size = metadata.st_size if object_type in {"file", "symlink"} else 0
    xattrs = contract_xattr_digests(path)
    acl = contract_acl_digest(path)
    final_metadata = path.lstat()
    metadata_fields = (
        "st_dev",
        "st_ino",
        "st_size",
        "st_mtime_ns",
        "st_ctime_ns",
        "st_mode",
    )
    if any(
        getattr(metadata, field) != getattr(final_metadata, field)
        for field in metadata_fields
    ):
        raise RecoveryError(f"Filesystem metadata changed during fingerprint capture: {path}")
    return {
        "type": object_type,
        "mode": stat.S_IMODE(mode),
        "uid": metadata.st_uid,
        "gid": metadata.st_gid,
        "flags": int(getattr(metadata, "st_flags", 0)),
        "size": exact_size,
        "modifiedTimeNs": metadata.st_mtime_ns,
        "payloadSHA256": payload_digest,
        "xattrs": xattrs,
        "aclSHA256": acl,
    }


def contract_is_fsmonitor_socket(path: Path) -> bool:
    return path.name in {
        "fsmonitor--daemon.ipc",
        "fsmonitor.sock",
        "fsmonitor.socket",
    } and any(part == ".git" or part == "worktrees" for part in path.parts)


def contract_scan_tree(
    path: Path,
    *,
    exclude_top_git: bool,
    excluded_relative_paths: Sequence[str] = (),
) -> tuple[list[dict[str, object]], str, list[str]]:
    records: list[dict[str, object]] = []
    ephemeral: list[str] = []
    hardlink_members: dict[tuple[int, int], list[str]] = {}
    stack: list[tuple[Path, str]] = [(path, ".")]
    while stack:
        current, relative = stack.pop()
        mode = current.lstat().st_mode
        if stat.S_ISSOCK(mode) and contract_is_fsmonitor_socket(current):
            ephemeral.append(relative)
            continue
        if stat.S_ISSOCK(mode) or stat.S_ISFIFO(mode) or stat.S_ISCHR(mode) or stat.S_ISBLK(mode):
            raise RecoveryError(f"Special file cannot enter a stable source digest: {current}")
        records.append(
            {
                "relativePath": relative,
                "fingerprint": contract_stable_fingerprint(current),
                "hardlinkGroup": "",
            }
        )
        current_stat = current.lstat()
        if stat.S_ISREG(current_stat.st_mode) and current_stat.st_nlink > 1:
            hardlink_members.setdefault(
                (current_stat.st_dev, current_stat.st_ino), []
            ).append(relative)
        if stat.S_ISDIR(mode) and not stat.S_ISLNK(mode):
            entries = list(os.scandir(current))
            for entry in sorted(
                entries,
                key=lambda value: os.fsencode(value.name),
                reverse=True,
            ):
                if exclude_top_git and relative == "." and entry.name == ".git":
                    continue
                child_relative = entry.name if relative == "." else f"{relative}/{entry.name}"
                if relative_path_is_excluded(child_relative, excluded_relative_paths):
                    continue
                stack.append((Path(entry.path), child_relative))
    records.sort(key=lambda value: os.fsencode(str(value["relativePath"])))
    record_index = {str(record["relativePath"]): record for record in records}
    for members in hardlink_members.values():
        if len(members) < 2:
            continue
        group = contract_digest(sorted(members))
        for relative in members:
            record_index[relative]["hardlinkGroup"] = group
    digest = contract_digest({"algorithm": TREE_ALGORITHM, "entries": records})
    return records, digest, sorted(ephemeral)


def contract_parse_git_pointer(path: Path) -> tuple[str, Path | None]:
    try:
        mode = path.lstat().st_mode
    except OSError:
        return "absent", None
    if stat.S_ISDIR(mode) and not stat.S_ISLNK(mode):
        return "directory", path
    if not stat.S_ISREG(mode) or stat.S_ISLNK(mode):
        return "unsupported", None
    try:
        content = path.read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError):
        return "unreadable-pointer", None
    match = re.fullmatch(r"gitdir:\s*(.+)", content)
    if match is None:
        return "broken-pointer", None
    candidate = Path(match.group(1))
    if not candidate.is_absolute():
        candidate = path.parent / candidate
    candidate = Path(os.path.abspath(candidate))
    if candidate.is_dir() and not candidate.is_symlink():
        return "linked-pointer", candidate
    return "broken-pointer", candidate


def contract_git_component_paths(
    source: Path,
    *,
    logical_source: Path | None = None,
) -> tuple[list[dict[str, object]], str]:
    dot_git = source / ".git"
    state, git_dir = contract_parse_git_pointer(dot_git)
    if state == "absent":
        return [], "absent"
    components: list[tuple[str, Path]] = [("git-entry", dot_git)]
    git_state = "directory"
    if state in {"broken-pointer", "unreadable-pointer", "unsupported"}:
        git_state = "broken"
    elif state == "linked-pointer":
        git_state = "linked"
    if git_dir is not None and git_dir.exists():
        components.append(("git-dir", git_dir))
        common_dir = git_dir
        commondir_file = git_dir / "commondir"
        if commondir_file.is_file() and not commondir_file.is_symlink():
            value = commondir_file.read_text(encoding="utf-8").strip()
            common_dir = Path(
                os.path.abspath(value if os.path.isabs(value) else git_dir / value)
            )
            components.append(("common-git-dir", common_dir))
        alternates = common_dir / "objects" / "info" / "alternates"
        if alternates.is_file() and not alternates.is_symlink():
            for line in alternates.read_text(encoding="utf-8").splitlines():
                if line.strip():
                    target = Path(line.strip())
                    if not target.is_absolute():
                        target = alternates.parent / target
                    components.append(
                        ("alternate-object-dir", Path(os.path.abspath(target)))
                    )
        lfs = common_dir / "lfs"
        if lfs.exists():
            components.append(("lfs-storage", lfs))
    unique: list[dict[str, object]] = []
    seen: set[tuple[str, str]] = set()
    for role, component in components:
        key = (role, display_path(component))
        if key in seen:
            continue
        seen.add(key)
        if not os.path.lexists(component):
            raise RecoveryError(f"Git component is missing: {role}: {component}")
        records, digest, ephemeral = contract_scan_tree(
            component, exclude_top_git=False
        )
        identity = component.lstat()
        logical_component = component
        if logical_source is not None and (
            component == source or lexical_path_within(component, source)
        ):
            logical_component = logical_source / component.relative_to(source)
        unique.append(
            {
                "role": role,
                "path": display_path(logical_component),
                "device": identity.st_dev,
                "inode": identity.st_ino,
                "treeDigest": digest,
                "entryCount": len(records),
                "ephemeralFsmonitorSockets": ephemeral,
            }
        )
    return unique, git_state


def record_tree_mtime(stats_result: TreeStats, file_stat: os.stat_result) -> None:
    value = int(file_stat.st_mtime_ns)
    if stats_result.oldest_mtime_ns == 0 or value < stats_result.oldest_mtime_ns:
        stats_result.oldest_mtime_ns = value
    if value > stats_result.newest_mtime_ns:
        stats_result.newest_mtime_ns = value


def update_root_digest(
    digest: "hashlib._Hash",
    relative: str,
    kind: str,
    source_stat: os.stat_result,
    content_identity: str,
    metadata: ExactMetadata,
    hardlink_group: str = "",
) -> None:
    relative_bytes = os.fsencode(relative)
    digest.update(len(relative_bytes).to_bytes(8, "big"))
    digest.update(relative_bytes)
    # Directory st_size is an allocation/implementation detail and can differ
    # after an otherwise exact APFS copy.  Directory membership is proved by
    # the sorted recursive manifest; do not overclaim reproducible directory
    # allocation as exact metadata.
    logical_size = 0 if kind == "directory" else source_stat.st_size
    for value in (
        kind,
        str(logical_size),
        str(metadata.mtime_ns),
        str(metadata.mode),
        str(metadata.uid),
        str(metadata.gid),
        str(metadata.flags),
        metadata.acl_digest,
        hardlink_group,
        content_identity,
    ):
        encoded = value.encode("utf-8", "surrogateescape")
        digest.update(len(encoded).to_bytes(8, "big"))
        digest.update(encoded)
    for name, value_hash in metadata.xattrs:
        encoded_name = name.encode("ascii")
        digest.update(len(encoded_name).to_bytes(8, "big"))
        digest.update(encoded_name)
        encoded_hash = value_hash.encode("ascii")
        digest.update(len(encoded_hash).to_bytes(8, "big"))
        digest.update(encoded_hash)


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def remove_recovery_target(path: Path, root: Path) -> None:
    if not path_within(path, root) or path == root:
        raise RecoveryError(f"Refused to replace a path outside the recovery variant root: {path}")
    if path.is_symlink() or path.is_file():
        guarded_unlink(path)
    elif path.is_dir():
        guarded_rmtree(path)


def copy_exact(source: Path, destination: Path, allowed_root: Path) -> None:
    if not path_within(destination, allowed_root):
        raise RecoveryError(f"Copy destination is outside its approved root: {destination}")
    ensure_parent(destination)
    if destination.exists() or destination.is_symlink():
        raise RecoveryError(f"Create-only recovery destination already exists: {destination}")
    source_stat = source.lstat()
    if stat.S_ISLNK(source_stat.st_mode):
        # ``ditto`` dereferences an individually copied link on macOS. A
        # recovery representation must preserve the link text itself (not the
        # target file), particularly for npm's relative ``.bin`` links.
        os.symlink(os.readlink(source), destination)
        try:
            if hasattr(os, "lchown"):
                os.lchown(destination, source_stat.st_uid, source_stat.st_gid)
            os.utime(
                destination,
                ns=(source_stat.st_atime_ns, source_stat.st_mtime_ns),
                follow_symlinks=False,
            )
            if hasattr(os, "listxattr") and hasattr(os, "getxattr") and hasattr(os, "setxattr"):
                for name in os.listxattr(source, follow_symlinks=False):
                    os.setxattr(
                        destination,
                        name,
                        os.getxattr(source, name, follow_symlinks=False),
                        follow_symlinks=False,
                    )
            elif sys.platform == "darwin" and Path("/usr/bin/xattr").is_file():
                # This bundled Python omits the os xattr APIs.  ``-s`` keeps
                # the operation on the symlink rather than its target, and
                # ``-x`` makes each value lossless across binary attributes.
                listed = run_command(["/usr/bin/xattr", "-s", source], check=False)
                if listed.returncode != 0:
                    raise RecoveryError(f"Could not enumerate symlink extended attributes for {source}")
                for name in sorted(
                    (line for line in listed.stdout.decode("utf-8", "surrogateescape").splitlines() if line),
                    key=os.fsencode,
                ):
                    read = run_command(
                        ["/usr/bin/xattr", "-s", "-p", "-x", name, source], check=False
                    )
                    if read.returncode != 0:
                        raise RecoveryError(
                            f"Could not read symlink extended attribute {name!r} for {source}"
                        )
                    encoded = "".join(read.stdout.decode("ascii").split())
                    written = run_command(
                        ["/usr/bin/xattr", "-s", "-w", "-x", name, encoded, destination], check=False
                    )
                    if written.returncode != 0:
                        raise RecoveryError(
                            f"Could not write symlink extended attribute {name!r} for {destination}"
                        )
            else:
                raise RecoveryError(f"No no-follow extended-attribute writer is available for {source}")
        except (NotImplementedError, OSError) as error:
            raise RecoveryError(
                f"Could not preserve symlink metadata {source} -> {destination}: {error}"
            ) from error
        return
    result = run_command(["/usr/bin/ditto", source, destination], check=False)
    if result.returncode != 0:
        output = (result.stdout + result.stderr).decode("utf-8", "replace").strip()
        raise RecoveryError(f"ditto failed for {source} -> {destination}: {output}")


def verify_exact_path_snapshot(source: Path, snapshot: Path) -> str:
    """Verify one copied file, symlink, or directory without exclusions."""
    source_stat = source.lstat()
    snapshot_stat = snapshot.lstat()
    source_kind = file_kind(source_stat)
    snapshot_kind = file_kind(snapshot_stat)
    if source_kind != snapshot_kind:
        raise RecoveryError(
            f"Snapshot type mismatch: {source} ({source_kind}) != {snapshot} ({snapshot_kind})"
        )
    if source_kind == "directory":
        source_manifest = count_source_tree(source, excluded_top_level=set(), include_root=True)
        snapshot_manifest = count_source_tree(snapshot, excluded_top_level=set(), include_root=True)
        if dataclasses.asdict(source_manifest) != dataclasses.asdict(snapshot_manifest):
            differing_fields = {
                field.name: (
                    getattr(source_manifest, field.name),
                    getattr(snapshot_manifest, field.name),
                )
                for field in dataclasses.fields(TreeStats)
                if getattr(source_manifest, field.name)
                != getattr(snapshot_manifest, field.name)
            }
            source_entries = {
                relative: (path, entry_stat)
                for relative, path, entry_stat in iter_source_entries(
                    source,
                    excluded_top_level=set(),
                )
            }
            snapshot_entries = {
                relative: (path, entry_stat)
                for relative, path, entry_stat in iter_source_entries(
                    snapshot,
                    excluded_top_level=set(),
                )
            }
            entry_differences: list[str] = []
            for relative in sorted(
                source_entries.keys() | snapshot_entries.keys(),
                key=os.fsencode,
            ):
                if relative not in source_entries or relative not in snapshot_entries:
                    entry_differences.append(f"{relative}:path-set")
                    continue
                source_path, source_entry_stat = source_entries[relative]
                snapshot_path, snapshot_entry_stat = snapshot_entries[relative]
                source_entry_kind = file_kind(source_entry_stat)
                snapshot_entry_kind = file_kind(snapshot_entry_stat)
                reasons: list[str] = []
                if source_entry_kind != snapshot_entry_kind:
                    reasons.append("type")
                elif metadata_signature(
                    source_path, source_entry_stat
                ) != metadata_signature(snapshot_path, snapshot_entry_stat):
                    reasons.append("metadata")
                if source_entry_kind == snapshot_entry_kind == "file":
                    source_hash, _ = stable_file_hash(source_path)
                    snapshot_hash, _ = stable_file_hash(snapshot_path)
                    if source_hash != snapshot_hash:
                        reasons.append("content")
                elif source_entry_kind == snapshot_entry_kind == "symlink":
                    if os.readlink(source_path) != os.readlink(snapshot_path):
                        reasons.append("link-target")
                if reasons:
                    entry_differences.append(f"{relative}:{','.join(reasons)}")
                if len(entry_differences) >= 20:
                    break
            raise RecoveryError(
                f"Directory snapshot checksum/metadata mismatch: {source} -> {snapshot}; "
                f"fields={differing_fields}; entries={entry_differences}"
            )
        return source_manifest.root_digest
    source_metadata = metadata_signature(source, source_stat)
    snapshot_metadata = metadata_signature(snapshot, snapshot_stat)
    if source_metadata != snapshot_metadata or source_stat.st_mtime_ns != snapshot_stat.st_mtime_ns:
        raise RecoveryError(f"Snapshot metadata mismatch: {source} -> {snapshot}")
    if source_kind == "file":
        source_hash, _ = stable_file_hash(source)
        snapshot_hash, _ = stable_file_hash(snapshot)
        if source_hash != snapshot_hash:
            raise RecoveryError(f"Snapshot checksum mismatch: {source} -> {snapshot}")
        return source_hash
    if source_kind == "symlink":
        if os.readlink(source) != os.readlink(snapshot):
            raise RecoveryError(f"Snapshot symlink target mismatch: {source} -> {snapshot}")
        return hashlib.sha256(os.fsencode(os.readlink(source))).hexdigest()
    raise RecoveryError(f"Unsupported special filesystem object; source retained: {source}")


def copy_exact_verified(source: Path, snapshot: Path, allowed_root: Path) -> str:
    copy_exact(source, snapshot, allowed_root)
    if source.is_dir() and not source.is_symlink():
        # ``ditto`` can leave the copied directory root with a destination-side
        # mtime/xattr update even when every child is exact. Reapply and verify
        # the source root metadata after all copy-created children exist.
        apply_directory_metadata(source, snapshot)
    return verify_exact_path_snapshot(source, snapshot)


def rsync_exclusion_arguments(excluded_relative_paths: Sequence[str]) -> list[str]:
    return [f"--exclude=/{relative.rstrip('/')}" for relative in excluded_relative_paths]


def relative_path_is_excluded(relative: str, excluded_relative_paths: Sequence[str]) -> bool:
    return any(
        relative == excluded or relative.startswith(excluded.rstrip("/") + "/")
        for excluded in excluded_relative_paths
    )


def add_missing_paths(
    source: Path,
    destination: Path,
    excluded_relative_paths: Sequence[str] = (),
    recovery_only_paths: Sequence[str] = (),
) -> None:
    arguments = [
        "/usr/bin/rsync",
        "-a",
        "--ignore-existing",
        "--exclude=.git/",
        f"--exclude={RECOVERY_DIR_NAME}/",
        *rsync_exclusion_arguments(excluded_relative_paths),
        *rsync_exclusion_arguments(recovery_only_paths),
        f"{source}/",
        f"{destination}/",
    ]
    # This is only a fast-path accelerator. macOS openrsync can fail while
    # touching an already-present read-only path even with --ignore-existing.
    # Any partial/missing paths are handled by the checksum-driven Python merge
    # immediately afterward, so an rsync error must never bypass verification
    # or prevent a safe lossless fallback.
    run_command(arguments, check=False)


def rsync_item_is_significant(item: str) -> bool:
    """Return true when an itemized rsync row is more than timestamp drift."""
    if not item:
        return False
    if item.startswith("*") or item[0] in (">", "c", "h"):
        return True
    if item[0] != ".":
        return False
    # openrsync reports identical bytes with normalized mtimes as `.f..T....`
    # (or `.d..t....`). Timestamp-only rows are not transfer requirements.
    for index, character in enumerate(item[2:], start=2):
        if character == ".":
            continue
        if index == 4 and character in ("t", "T"):
            continue
        return True
    return False


def fast_checksum_audit(
    source: Path,
    destination: Path,
    evidence_path: Path,
    excluded_relative_paths: Sequence[str] = (),
    recovery_only_paths: Sequence[str] = (),
) -> FastAudit:
    """Deep-audit source against destination using native openrsync.

    `-c` reads and checksums every regular file. Ownership is intentionally
    ignored because copies can cross accounts; permissions, file type, symlink
    target, size, and content remain significant. Extended attributes and file
    flags are checked in a separate metadata walk because macOS openrsync 2.6.9
    can synthesize disappearing AppleDouble `._*` paths when `-E` is combined
    with a dry run. Pure mtime normalization is not significant.
    """
    result = run_command(
        [
            "/usr/bin/rsync",
            "-acin",
            "--no-owner",
            "--no-group",
            "--exclude=.git/",
            f"--exclude={RECOVERY_DIR_NAME}/",
            *rsync_exclusion_arguments(excluded_relative_paths),
            *rsync_exclusion_arguments(recovery_only_paths),
            "--out-format=%i\t%n",
            f"{source}/",
            f"{destination}/",
        ],
        check=False,
    )
    raw = result.stdout + result.stderr
    evidence_path.parent.mkdir(parents=True, exist_ok=True)
    evidence_path.write_bytes(raw)
    differences: list[str] = []
    for raw_line in result.stdout.decode("utf-8", "surrogateescape").splitlines():
        if "\t" not in raw_line:
            continue
        item, relative = raw_line.split("\t", 1)
        if rsync_item_is_significant(item):
            differences.append(f"{item}\t{relative}")
    if result.returncode != 0:
        diagnostics = raw.decode("utf-8", "replace").strip()
        raise RecoveryError(
            f"Native fast checksum audit failed for {source} ({result.returncode}): {diagnostics}"
        )
    if not differences:
        for relative, source_path, source_stat in iter_source_entries(
            source,
            excluded_relative_paths=excluded_relative_paths,
        ):
            destination_path = destination / relative
            destination_stat = lstat_or_none(destination_path)
            if destination_stat is None or file_kind(destination_stat) != file_kind(source_stat):
                differences.append(f"metadata-missing-or-type\t{relative}")
                continue
            if metadata_signature(source_path, source_stat) != metadata_signature(
                destination_path, destination_stat
            ):
                differences.append(f"metadata\t{relative}")
            if len(differences) >= 200:
                break
    evidence_payload = raw
    if differences:
        evidence_payload += (
            "\n# significant differences\n" + "\n".join(differences) + "\n"
        ).encode("utf-8", "surrogateescape")
        evidence_path.write_bytes(evidence_payload)
    return FastAudit(
        equivalent=not differences,
        difference_count=len(differences),
        differences=differences[:200],
        raw_output_digest=hashlib.sha256(evidence_payload).hexdigest(),
    )


def hardlink_groups_for_tree(
    source: Path,
    *,
    excluded_top_level: set[str] | None = None,
    excluded_relative_paths: Sequence[str] = (),
) -> dict[str, str]:
    """Map source paths to deterministic hardlink-group IDs.

    Device and inode numbers are intentionally not persisted as the group ID;
    those values change after a verified copy. The sorted member path set is
    the stable topology identity that the representative tree must reproduce.
    """
    members: dict[tuple[int, int], list[str]] = {}
    for relative, _path, entry_stat in iter_source_entries(
        source,
        excluded_top_level=excluded_top_level,
        excluded_relative_paths=excluded_relative_paths,
    ):
        if stat.S_ISREG(entry_stat.st_mode) and entry_stat.st_nlink > 1:
            members.setdefault((entry_stat.st_dev, entry_stat.st_ino), []).append(relative)
    result: dict[str, str] = {}
    for paths in members.values():
        if len(paths) < 2:
            continue
        ordered = sorted(paths, key=os.fsencode)
        payload = b"\0".join(os.fsencode(value) for value in ordered)
        group_id = hashlib.sha256(payload).hexdigest()
        for relative in ordered:
            result[relative] = group_id
    return result


def count_source_tree(
    source: Path,
    *,
    excluded_top_level: set[str] | None = None,
    excluded_relative_paths: Sequence[str] = (),
    include_root: bool = True,
) -> TreeStats:
    """Return a deterministic checksum and metadata manifest for one tree.

    Fast mode uses native rsync to compare source and destination bytes, but a
    deletion-capable decision must also prove that the source did not change
    between the first pass and quarantine.  A constant marker cannot provide
    that proof, so this digest includes every path, type, file checksum,
    symlink target, mode, owner/group IDs, flags, mtime, ACL, extended
    attributes/resource forks, and hardlink topology. Birthtime, atime, and
    sparse allocation are deliberately recorded by the path manifest as
    record-only properties because copying them exactly is not always safe.
    """
    result = TreeStats()
    root_digest = hashlib.sha256()
    root_stat = source.lstat()
    if not stat.S_ISDIR(root_stat.st_mode):
        raise RecoveryError(f"Expected a source directory: {source}")
    if include_root:
        record_tree_mtime(result, root_stat)
        update_root_digest(
            root_digest,
            ".",
            "directory",
            root_stat,
            "directory",
            metadata_signature(source, root_stat),
        )
    hardlink_groups = hardlink_groups_for_tree(
        source,
        excluded_top_level=excluded_top_level,
        excluded_relative_paths=excluded_relative_paths,
    )
    for relative, path, entry_stat in iter_source_entries(
        source,
        excluded_top_level=excluded_top_level,
        excluded_relative_paths=excluded_relative_paths,
    ):
        record_tree_mtime(result, entry_stat)
        kind = file_kind(entry_stat)
        metadata = metadata_signature(path, entry_stat)
        if kind == "directory":
            result.directories += 1
            content_identity = "directory"
        elif kind == "file":
            result.files += 1
            result.bytes += entry_stat.st_size
            content_identity, entry_stat = stable_file_hash(path)
            metadata = metadata_signature(path, entry_stat)
        elif kind == "symlink":
            result.symlinks += 1
            try:
                content_identity = f"symlink:{os.readlink(path)}"
            except OSError as error:
                raise RecoveryError(f"Could not read symlink {path}: {error}") from error
        else:
            raise RecoveryError(f"Unsupported special filesystem object; source retained: {path}")
        update_root_digest(
            root_digest,
            relative,
            kind,
            entry_stat,
            content_identity,
            metadata,
            hardlink_groups.get(relative, ""),
        )
    result.identical = result.directories + result.files + result.symlinks
    result.root_digest = root_digest.hexdigest()
    return result


def iter_source_entries(
    root: Path,
    *,
    excluded_top_level: set[str] | None = None,
    excluded_relative_paths: Sequence[str] = (),
) -> Iterator[tuple[str, Path, os.stat_result]]:
    excluded = {".git", RECOVERY_DIR_NAME} if excluded_top_level is None else excluded_top_level
    stack: list[tuple[str, Path]] = [("", root)]
    while stack:
        relative_parent, directory = stack.pop()
        try:
            entries = sorted(os.scandir(directory), key=lambda entry: os.fsencode(entry.name), reverse=True)
        except OSError as error:
            raise RecoveryError(f"Could not enumerate {directory}: {error}") from error
        child_directories: list[tuple[str, Path]] = []
        for entry in reversed(entries):
            if not relative_parent and entry.name in excluded:
                continue
            relative = f"{relative_parent}/{entry.name}" if relative_parent else entry.name
            if relative_path_is_excluded(relative, excluded_relative_paths):
                continue
            path = Path(entry.path)
            try:
                entry_stat = path.lstat()
            except OSError as error:
                raise RecoveryError(f"Could not inspect {path}: {error}") from error
            yield relative, path, entry_stat
            if stat.S_ISDIR(entry_stat.st_mode):
                child_directories.append((relative, path))
        for child in reversed(child_directories):
            stack.append(child)


def append_conflict_record(
    handle: BinaryIO,
    *,
    relative: str,
    kind: str,
    reason: str,
    source_identity: str,
    representative: Path,
) -> None:
    record = {
        "relativePath": relative,
        "kind": kind,
        "reason": reason,
        "sourceIdentity": source_identity,
        "representative": display_path(representative),
    }
    handle.write((json.dumps(record, sort_keys=True) + "\n").encode("utf-8", "surrogateescape"))


def apply_directory_metadata(source: Path, destination: Path) -> None:
    """Apply reproducible directory metadata and fail if any exact field differs."""
    try:
        shutil.copystat(source, destination, follow_symlinks=False)
    except OSError as error:
        raise RecoveryError(
            f"Could not preserve directory metadata: {source} -> {destination}: {error}"
        ) from error
    source_stat = source.lstat()
    destination_stat = destination.lstat()
    if (source_stat.st_uid, source_stat.st_gid) != (
        destination_stat.st_uid,
        destination_stat.st_gid,
    ):
        try:
            os.chown(
                destination,
                source_stat.st_uid,
                source_stat.st_gid,
                follow_symlinks=False,
            )
        except OSError as error:
            raise RecoveryError(
                f"Could not preserve directory owner/group: {source} -> {destination}: {error}"
            ) from error
        destination_stat = destination.lstat()
    source_metadata = metadata_signature(source, source_stat)
    destination_metadata = metadata_signature(destination, destination_stat)
    if source_metadata != destination_metadata:
        raise RecoveryError(
            f"Directory metadata is not exactly represented: {source} -> {destination}"
        )


def ensure_exact_recovery_copy(source: Path, destination: Path, allowed_root: Path) -> None:
    """Create a recovery copy, or verify an existing create-only copy exactly."""
    if os.path.lexists(destination):
        verify_exact_path_snapshot(source, destination)
        return
    copy_exact(source, destination, allowed_root)
    verify_exact_path_snapshot(source, destination)


def source_wins_replace_in_staging(
    source_path: Path,
    active_path: Path,
    destination_root: Path,
    pre_promotion_root: Path,
    relative: str,
) -> str:
    """Preserve a canonical staging path, then install the reviewed source path."""
    if not lexical_path_within(active_path, destination_root) or active_path == destination_root:
        raise RecoveryError(f"source-wins target escaped destination staging: {active_path}")
    active_stat = active_path.lstat()
    source_stat = source_path.lstat()
    if stat.S_ISDIR(active_stat.st_mode) and not stat.S_ISDIR(source_stat.st_mode):
        try:
            if any(os.scandir(active_path)):
                raise RecoveryError(
                    f"source-wins cannot remove a non-empty destination directory: {active_path}"
                )
        except OSError as error:
            raise RecoveryError(f"Could not inspect source-wins directory {active_path}: {error}") from error
    preserved = pre_promotion_root / relative
    if os.path.lexists(preserved):
        raise RecoveryError(f"Create-only pre-promotion evidence collision: {preserved}")
    digest = copy_exact_verified(active_path, preserved, pre_promotion_root)
    remove_recovery_target(active_path, destination_root)
    copy_exact(source_path, active_path, destination_root)
    verify_exact_path_snapshot(source_path, active_path)
    if verify_exact_path_snapshot(preserved, preserved) != digest:
        raise RecoveryError(f"Pre-promotion evidence changed after source-wins install: {preserved}")
    return digest


def manifest_record_bytes(
    *,
    relative: str,
    source_path: Path,
    representative: Path,
    source_stat: os.stat_result,
    hardlink_group: str,
) -> bytes:
    representative_stat = representative.lstat()
    source_kind = file_kind(source_stat)
    representative_kind = file_kind(representative_stat)
    if source_kind != representative_kind:
        raise RecoveryError(
            f"Manifest representative type mismatch: {source_path} -> {representative}"
        )
    source_identity = source_kind
    representative_identity = representative_kind
    if source_kind == "file":
        source_identity, source_stat = stable_file_hash(source_path)
        representative_identity, representative_stat = stable_file_hash(representative)
    elif source_kind == "symlink":
        source_identity = f"symlink:{os.readlink(source_path)}"
        representative_identity = f"symlink:{os.readlink(representative)}"
    elif source_kind != "directory":
        raise RecoveryError(f"Unsupported manifest object: {source_path}")
    if source_identity != representative_identity:
        raise RecoveryError(
            f"Manifest representative content mismatch: {source_path} -> {representative}"
        )
    source_exact = metadata_signature(source_path, source_stat)
    representative_exact = metadata_signature(representative, representative_stat)
    if source_exact != representative_exact:
        raise RecoveryError(
            f"Manifest representative metadata mismatch: {source_path} -> {representative}"
        )
    record = {
        "relativePath": relative,
        "kind": source_kind,
        "source": display_path(source_path),
        "representative": display_path(representative),
        "contentIdentity": source_identity,
        "hardlinkGroup": hardlink_group,
        "verifiedExact": dataclasses.asdict(source_exact),
        "recordOnlySource": dataclasses.asdict(record_only_metadata(source_stat)),
        "recordOnlyRepresentative": dataclasses.asdict(record_only_metadata(representative_stat)),
        "verifiedMetadataFields": list(EXACT_METADATA_FIELDS),
        "recordOnlyMetadataFields": list(RECORD_ONLY_METADATA_FIELDS),
        "recordOnlyClaim": "recorded-not-claimed-exact",
    }
    return (json.dumps(record, sort_keys=True) + "\n").encode(
        "utf-8", "surrogateescape"
    )


def write_exact_snapshot_manifest(
    source: Path,
    snapshot: Path,
    manifest_path: Path,
    *,
    excluded_top_level: set[str] | None = None,
    excluded_relative_paths: Sequence[str] = (),
) -> TreeStats:
    tree = count_source_tree(
        source,
        excluded_top_level=excluded_top_level,
        excluded_relative_paths=excluded_relative_paths,
        include_root=True,
    )
    hardlinks = hardlink_groups_for_tree(
        source,
        excluded_top_level=excluded_top_level,
        excluded_relative_paths=excluded_relative_paths,
    )
    digest = hashlib.sha256()
    entries = 0
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    with manifest_path.open("wb") as handle:
        root_row = manifest_record_bytes(
            relative=".",
            source_path=source,
            representative=snapshot,
            source_stat=source.lstat(),
            hardlink_group="",
        )
        handle.write(root_row)
        digest.update(root_row)
        entries += 1
        for relative, source_path, source_stat in iter_source_entries(
            source,
            excluded_top_level=excluded_top_level,
            excluded_relative_paths=excluded_relative_paths,
        ):
            representative = snapshot / relative
            row = manifest_record_bytes(
                relative=relative,
                source_path=source_path,
                representative=representative,
                source_stat=source_stat,
                hardlink_group=hardlinks.get(relative, ""),
            )
            handle.write(row)
            digest.update(row)
            entries += 1
    tree.manifest_digest = digest.hexdigest()
    tree.manifest_entries = entries
    return tree


def tree_merge_or_verify(
    source: Path,
    destination: Path,
    variant_root: Path,
    conflict_manifest: Path,
    *,
    merge: bool,
    excluded_relative_paths: Sequence[str] = (),
    activate_source_only: bool = True,
    manifest_path: Path | None = None,
    conflict_policy: str = "preserve-canonical",
    recovery_only_paths: Sequence[str] = (),
    pre_promotion_root: Path | None = None,
    preserve_canonical_directory_children: bool = False,
) -> TreeStats:
    if merge and not destination.exists():
        destination.mkdir(parents=True, exist_ok=False)
    if not destination.is_dir():
        raise RecoveryError(f"Canonical destination is unavailable: {destination}")
    if conflict_policy not in CONFLICT_POLICIES:
        raise RecoveryError(f"Unsupported conflict policy: {conflict_policy}")
    if conflict_policy == "source-wins-after-preserve" and pre_promotion_root is None:
        raise RecoveryError("source-wins-after-preserve requires a pre-promotion evidence root")

    if merge:
        variant_root.mkdir(parents=True, exist_ok=True)
    conflict_manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest_mode = "wb"
    stats_result = TreeStats()
    root_digest = hashlib.sha256()
    hardlink_groups = hardlink_groups_for_tree(
        source,
        excluded_relative_paths=excluded_relative_paths,
    )
    group_first_representative: dict[str, Path] = {}
    group_representatives: dict[str, list[Path]] = {}
    representatives: dict[str, Path] = {}
    directory_repairs: list[tuple[Path, Path]] = []

    forced_variant_prefixes: list[str] = []

    def forced_variant(relative: str) -> bool:
        return any(relative == prefix or relative.startswith(prefix + "/") for prefix in forced_variant_prefixes)

    source_root_stat = source.lstat()
    destination_root_stat = destination.lstat()
    source_root_metadata = metadata_signature(source, source_root_stat)
    destination_root_metadata = metadata_signature(destination, destination_root_stat)
    if source_root_metadata == destination_root_metadata:
        root_representative = destination
    else:
        if not merge and not variant_root.is_dir():
            raise RecoveryError(f"Source root metadata is not represented: {source}")
        if merge and not variant_root.exists():
            variant_root.mkdir(parents=True, exist_ok=False)
        if not variant_root.is_dir() or variant_root.is_symlink():
            raise RecoveryError(f"Invalid source-root metadata representative: {variant_root}")
        variant_root_stat = variant_root.lstat()
        if (
            not merge
            and metadata_signature(variant_root, variant_root_stat)
            != source_root_metadata
        ):
            raise RecoveryError(f"Source root metadata variant is not preserved: {source}")
        root_representative = variant_root
        directory_repairs.append((source, variant_root))
    representatives["."] = root_representative
    record_tree_mtime(stats_result, source_root_stat)
    update_root_digest(
        root_digest,
        ".",
        "directory",
        source_root_stat,
        "directory",
        source_root_metadata,
    )

    with conflict_manifest.open(manifest_mode) as conflict_handle:
        for relative, source_path, source_stat in iter_source_entries(
            source,
            excluded_relative_paths=excluded_relative_paths,
        ):
            record_tree_mtime(stats_result, source_stat)
            kind = file_kind(source_stat)
            source_metadata = metadata_signature(source_path, source_stat)
            destination_path = destination / relative
            variant_path = variant_root / relative
            route_variant = forced_variant(relative)
            recovery_only = relative_path_is_excluded(relative, recovery_only_paths)
            if recovery_only:
                route_variant = True
            hardlink_group = hardlink_groups.get(relative, "")
            if hardlink_group:
                if conflict_policy == "source-wins-after-preserve" and not recovery_only:
                    raise RecoveryError(
                        f"source-wins hardlink topology requires explicit manual handling: {source_path}"
                    )
                route_variant = True

            destination_stat = lstat_or_none(destination_path)
            destination_exact = False
            if destination_stat is not None and file_kind(destination_stat) == kind:
                if kind == "directory":
                    destination_exact = (
                        metadata_signature(destination_path, destination_stat) == source_metadata
                    )
                elif kind == "file" and destination_stat.st_size == source_stat.st_size:
                    source_hash_probe, source_stable_probe = stable_file_hash(source_path)
                    destination_hash_probe, destination_stable_probe = stable_file_hash(destination_path)
                    source_stat = source_stable_probe
                    source_metadata = metadata_signature(source_path, source_stat)
                    destination_exact = (
                        source_hash_probe == destination_hash_probe
                        and metadata_signature(destination_path, destination_stable_probe)
                        == source_metadata
                    )
                elif kind == "symlink":
                    destination_exact = (
                        os.readlink(destination_path) == os.readlink(source_path)
                        and metadata_signature(destination_path, destination_stat) == source_metadata
                    )

            if not route_variant and not activate_source_only and not destination_exact:
                route_variant = True
            primary_path = variant_path if route_variant else destination_path
            primary_stat = lstat_or_none(primary_path)
            content_identity = ""
            representative: Path | None = None
            reason = ""

            if kind == "directory":
                stats_result.directories += 1
                if primary_stat is None:
                    if not merge:
                        raise RecoveryError(f"Directory is not represented: {source_path}")
                    primary_path.mkdir(parents=True, exist_ok=True)
                    stats_result.added += 1
                    primary_stat = primary_path.lstat()
                    directory_repairs.append((source_path, primary_path))
                    representative = primary_path
                    if route_variant and not activate_source_only:
                        reason = "source-only-routed-to-recovery"
                elif not stat.S_ISDIR(primary_stat.st_mode):
                    if (
                        merge
                        and conflict_policy == "source-wins-after-preserve"
                        and not route_variant
                    ):
                        source_wins_replace_in_staging(
                            source_path,
                            destination_path,
                            destination,
                            pre_promotion_root,
                            relative,
                        )
                        primary_path = destination_path
                        primary_stat = primary_path.lstat()
                        representative = primary_path
                        stats_result.conflicts += 1
                        reason = "source-wins-after-canonical-preserve"
                        content_identity = "directory"
                        forced_variant_prefixes = [
                            prefix for prefix in forced_variant_prefixes if prefix != relative
                        ]
                        directory_repairs.append((source_path, primary_path))
                        representatives[relative] = representative
                        update_root_digest(
                            root_digest,
                            relative,
                            kind,
                            source_stat,
                            content_identity,
                            source_metadata,
                            hardlink_group,
                        )
                        append_conflict_record(
                            conflict_handle,
                            relative=relative,
                            kind=kind,
                            reason=reason,
                            source_identity=content_identity,
                            representative=representative,
                        )
                        continue
                    if not route_variant:
                        forced_variant_prefixes.append(relative)
                        primary_path = variant_path
                        primary_stat = lstat_or_none(primary_path)
                    if primary_stat is None:
                        if not merge:
                            raise RecoveryError(f"Directory type conflict is not preserved: {source_path}")
                        primary_path.mkdir(parents=True, exist_ok=True)
                        primary_stat = primary_path.lstat()
                        directory_repairs.append((source_path, primary_path))
                    if not stat.S_ISDIR(primary_stat.st_mode):
                        raise RecoveryError(f"Directory conflict target is invalid: {primary_path}")
                    stats_result.conflicts += 1
                    representative = primary_path
                    reason = "type-conflict"
                else:
                    if metadata_signature(primary_path, primary_stat) == source_metadata:
                        representative = primary_path
                        stats_result.identical += 1
                    elif primary_path == destination_path:
                        if not merge:
                            variant_stat = lstat_or_none(variant_path)
                            if (
                                variant_stat is None
                                or not stat.S_ISDIR(variant_stat.st_mode)
                                or metadata_signature(variant_path, variant_stat)
                                != source_metadata
                            ):
                                raise RecoveryError(
                                    f"Directory metadata conflict is not preserved: {source_path}"
                                )
                            primary_path = variant_path
                            representative = primary_path
                            stats_result.metadata_conflicts += 1
                            if (
                                conflict_policy != "source-wins-after-preserve"
                                and not preserve_canonical_directory_children
                            ):
                                forced_variant_prefixes.append(relative)
                            reason = (
                                "directory-metadata-preserved-without-blocking-source-wins-children"
                                if conflict_policy == "source-wins-after-preserve"
                                and not recovery_only
                                else "directory-metadata-conflict"
                            )
                            content_identity = "directory"
                            if reason:
                                append_conflict_record(
                                    conflict_handle,
                                    relative=relative,
                                    kind=kind,
                                    reason=reason,
                                    source_identity=content_identity,
                                    representative=representative,
                                )
                            representatives[relative] = representative
                            update_root_digest(
                                root_digest,
                                relative,
                                kind,
                                source_stat,
                                content_identity,
                                source_metadata,
                                hardlink_group,
                            )
                            continue
                        if conflict_policy == "source-wins-after-preserve" and not recovery_only:
                            primary_path = variant_path
                            if os.path.lexists(primary_path):
                                if not primary_path.is_dir() or primary_path.is_symlink():
                                    raise RecoveryError(
                                        f"Directory metadata variant collision: {primary_path}"
                                    )
                            else:
                                primary_path.mkdir(parents=True, exist_ok=False)
                            representative = primary_path
                            directory_repairs.append((source_path, primary_path))
                            stats_result.metadata_conflicts += 1
                            reason = "directory-metadata-preserved-without-blocking-source-wins-children"
                        else:
                            if not preserve_canonical_directory_children:
                                forced_variant_prefixes.append(relative)
                            primary_path = variant_path
                            if os.path.lexists(primary_path):
                                if not primary_path.is_dir() or primary_path.is_symlink():
                                    raise RecoveryError(
                                        f"Directory metadata variant collision: {primary_path}"
                                    )
                            else:
                                primary_path.mkdir(parents=True, exist_ok=False)
                            representative = primary_path
                            directory_repairs.append((source_path, primary_path))
                            stats_result.metadata_conflicts += 1
                            reason = "directory-metadata-conflict"
                    else:
                        if not merge:
                            raise RecoveryError(
                                f"Directory metadata variant is not preserved: {source_path}"
                            )
                        representative = primary_path
                        directory_repairs.append((source_path, primary_path))
                content_identity = "directory"

            elif kind == "file":
                stats_result.files += 1
                stats_result.bytes += source_stat.st_size
                source_hash, stable_stat = stable_file_hash(source_path)
                source_stat = stable_stat
                content_identity = source_hash
                source_metadata = metadata_signature(source_path, source_stat)

                content_matches = False
                metadata_matches = False
                if primary_stat is not None and stat.S_ISREG(primary_stat.st_mode):
                    if primary_stat.st_size == source_stat.st_size:
                        primary_hash, primary_stable = stable_file_hash(primary_path)
                        content_matches = primary_hash == source_hash
                        metadata_matches = metadata_signature(primary_path, primary_stable) == source_metadata
                if content_matches and metadata_matches:
                    representative = primary_path
                    stats_result.identical += 1
                elif content_matches and not metadata_matches:
                    if (
                        merge
                        and conflict_policy == "source-wins-after-preserve"
                        and not route_variant
                    ):
                        source_wins_replace_in_staging(
                            source_path,
                            destination_path,
                            destination,
                            pre_promotion_root,
                            relative,
                        )
                        representative = destination_path
                        reason = "source-wins-metadata-after-canonical-preserve"
                    elif not route_variant:
                        variant_stat = lstat_or_none(variant_path)
                        variant_matches = False
                        if variant_stat is not None and stat.S_ISREG(variant_stat.st_mode):
                            variant_hash, variant_stable = stable_file_hash(variant_path)
                            variant_matches = (
                                variant_hash == source_hash
                                and metadata_signature(variant_path, variant_stable) == source_metadata
                            )
                        if not variant_matches:
                            if not merge:
                                raise RecoveryError(f"File metadata variant is not preserved: {source_path}")
                            copy_exact(source_path, variant_path, variant_root)
                        representative = variant_path
                    else:
                        if not merge:
                            raise RecoveryError(f"Variant metadata is not preserved: {source_path}")
                        copy_exact(source_path, primary_path, variant_root)
                        representative = primary_path
                    stats_result.metadata_conflicts += 1
                    if not reason:
                        reason = "metadata-conflict"
                elif primary_stat is None:
                    if not merge:
                        raise RecoveryError(f"File is not represented: {source_path}")
                    if hardlink_group and hardlink_group in group_first_representative:
                        ensure_parent(primary_path)
                        os.link(group_first_representative[hardlink_group], primary_path)
                    else:
                        allowed_root = variant_root if route_variant else destination
                        copy_exact(source_path, primary_path, allowed_root)
                    representative = primary_path
                    stats_result.added += 1
                    if route_variant and not activate_source_only:
                        reason = "source-only-routed-to-recovery"
                else:
                    conflict_path = primary_path if route_variant else variant_path
                    conflict_stat = lstat_or_none(conflict_path)
                    conflict_matches = False
                    if conflict_stat is not None and stat.S_ISREG(conflict_stat.st_mode):
                        conflict_hash, conflict_stable = stable_file_hash(conflict_path)
                        conflict_matches = (
                            conflict_hash == source_hash
                            and metadata_signature(conflict_path, conflict_stable) == source_metadata
                        )
                    if (
                        merge
                        and conflict_policy == "source-wins-after-preserve"
                        and not route_variant
                    ):
                        source_wins_replace_in_staging(
                            source_path,
                            destination_path,
                            destination,
                            pre_promotion_root,
                            relative,
                        )
                        conflict_path = destination_path
                        conflict_matches = True
                        reason = "source-wins-content-after-canonical-preserve"
                    if not conflict_matches:
                        if not merge:
                            raise RecoveryError(f"Conflicting file is not preserved: {source_path}")
                        if hardlink_group and hardlink_group in group_first_representative:
                            ensure_parent(conflict_path)
                            os.link(group_first_representative[hardlink_group], conflict_path)
                        else:
                            copy_exact(source_path, conflict_path, variant_root)
                    representative = conflict_path
                    stats_result.conflicts += 1
                    if not reason:
                        reason = "content-or-type-conflict"

                representative_hash, representative_stat = stable_file_hash(representative)
                if representative_hash != source_hash:
                    raise RecoveryError(f"Representative checksum mismatch: {source_path} -> {representative}")
                if metadata_signature(representative, representative_stat) != source_metadata:
                    raise RecoveryError(f"Representative metadata mismatch: {source_path} -> {representative}")
                if hardlink_group:
                    group_first_representative.setdefault(hardlink_group, representative)
                    group_representatives.setdefault(hardlink_group, []).append(representative)

            elif kind == "symlink":
                stats_result.symlinks += 1
                try:
                    source_target = os.readlink(source_path)
                except OSError as error:
                    raise RecoveryError(f"Could not read symlink {source_path}: {error}") from error
                content_identity = f"symlink:{source_target}"
                target_matches = False
                metadata_matches = False
                if primary_stat is not None and stat.S_ISLNK(primary_stat.st_mode):
                    target_matches = os.readlink(primary_path) == source_target
                    metadata_matches = metadata_signature(primary_path, primary_stat) == source_metadata
                if target_matches and metadata_matches:
                    representative = primary_path
                    stats_result.identical += 1
                elif primary_stat is None:
                    if not merge:
                        raise RecoveryError(f"Symlink is not represented: {source_path}")
                    allowed_root = variant_root if route_variant else destination
                    copy_exact(source_path, primary_path, allowed_root)
                    representative = primary_path
                    stats_result.added += 1
                    if route_variant and not activate_source_only:
                        reason = "source-only-routed-to-recovery"
                else:
                    conflict_path = primary_path if route_variant else variant_path
                    conflict_stat = lstat_or_none(conflict_path)
                    conflict_matches = (
                        conflict_stat is not None
                        and stat.S_ISLNK(conflict_stat.st_mode)
                        and os.readlink(conflict_path) == source_target
                        and metadata_signature(conflict_path, conflict_stat) == source_metadata
                    )
                    if (
                        merge
                        and conflict_policy == "source-wins-after-preserve"
                        and not route_variant
                    ):
                        source_wins_replace_in_staging(
                            source_path,
                            destination_path,
                            destination,
                            pre_promotion_root,
                            relative,
                        )
                        conflict_path = destination_path
                        conflict_matches = True
                        reason = "source-wins-symlink-after-canonical-preserve"
                    if not conflict_matches:
                        if not merge:
                            raise RecoveryError(f"Conflicting symlink is not preserved: {source_path}")
                        copy_exact(source_path, conflict_path, variant_root)
                    representative = conflict_path
                    stats_result.conflicts += 1
                    if not reason:
                        reason = "symlink-or-type-conflict"
                representative_stat = representative.lstat()
                if not stat.S_ISLNK(representative_stat.st_mode) or os.readlink(representative) != source_target:
                    raise RecoveryError(f"Representative symlink mismatch: {source_path} -> {representative}")

            else:
                raise RecoveryError(f"Unsupported special filesystem object; source retained: {source_path}")

            if recovery_only and representative is not None:
                reason = "reviewed-recovery-only-path"
            if reason and representative is not None:
                append_conflict_record(
                    conflict_handle,
                    relative=relative,
                    kind=kind,
                    reason=reason,
                    source_identity=content_identity,
                    representative=representative,
                )
            if representative is None:
                raise RecoveryError(f"No representative was selected for {source_path}")
            representatives[relative] = representative
            update_root_digest(
                root_digest,
                relative,
                kind,
                source_stat,
                content_identity,
                source_metadata,
                hardlink_group,
            )

    if merge:
        for directory_source, directory_representative in sorted(
            directory_repairs,
            key=lambda item: len(item[1].parts),
            reverse=True,
        ):
            apply_directory_metadata(directory_source, directory_representative)

    for group_id, paths in group_representatives.items():
        identities = {
            (path.lstat().st_dev, path.lstat().st_ino)
            for path in paths
        }
        expected_count = sum(1 for value in hardlink_groups.values() if value == group_id)
        if len(paths) != expected_count or len(identities) != 1:
            raise RecoveryError(
                f"Hardlink topology is not exactly represented for source group {group_id}"
            )

    if manifest_path is not None:
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_hasher = hashlib.sha256()
        manifest_entries = 0
        with manifest_path.open("wb") as manifest_handle:
            root_row = manifest_record_bytes(
                relative=".",
                source_path=source,
                representative=representatives["."],
                source_stat=source_root_stat,
                hardlink_group="",
            )
            manifest_handle.write(root_row)
            manifest_hasher.update(root_row)
            manifest_entries += 1
            for relative, source_path, source_stat in iter_source_entries(
                source,
                excluded_relative_paths=excluded_relative_paths,
            ):
                row = manifest_record_bytes(
                    relative=relative,
                    source_path=source_path,
                    representative=representatives[relative],
                    source_stat=source_stat,
                    hardlink_group=hardlink_groups.get(relative, ""),
                )
                manifest_handle.write(row)
                manifest_hasher.update(row)
                manifest_entries += 1
        stats_result.manifest_digest = manifest_hasher.hexdigest()
        stats_result.manifest_entries = manifest_entries
    stats_result.root_digest = root_digest.hexdigest()
    return stats_result


def safe_ref_component(value: str) -> str:
    cleaned = SAFE_REF_COMPONENT_RE.sub("-", value).strip("./-")
    cleaned = re.sub(r"/+", "/", cleaned)
    return cleaned or "source"


def collect_git_refs(worktree: Path) -> dict[str, str]:
    output = git_output(worktree, ["for-each-ref", "--format=%(objectname)\t%(refname)"])
    refs: dict[str, str] = {}
    for line in output.splitlines():
        if "\t" not in line:
            continue
        object_id, ref_name = line.split("\t", 1)
        if re.fullmatch(r"[0-9a-fA-F]{40,64}", object_id) and ref_name.startswith("refs/"):
            refs[ref_name] = object_id.lower()
    return refs


def git_commit_time(worktree: Path, object_id: str) -> int:
    if not object_id:
        return 0
    value = git_output(worktree, ["show", "-s", "--format=%ct", object_id])
    return int(value) if value.isdigit() else 0


def classify_git_history(
    source: Path,
    destination: Path,
    source_head: str,
    destination_head: str,
) -> str:
    if not source_head and not destination_head:
        return "both-unborn"
    if not source_head:
        return "source-unborn"
    if not destination_head:
        return "destination-unborn"
    if source_head == destination_head:
        return "same-commit"
    source_ancestor = run_command(
        ["git", "-C", destination, "merge-base", "--is-ancestor", source_head, destination_head],
        check=False,
    ).returncode == 0
    if source_ancestor:
        return "source-ancestor-of-destination"
    destination_ancestor = run_command(
        ["git", "-C", destination, "merge-base", "--is-ancestor", destination_head, source_head],
        check=False,
    ).returncode == 0
    if destination_ancestor:
        return "source-descendant-of-destination"
    merge_base = run_command(
        ["git", "-C", destination, "merge-base", source_head, destination_head],
        check=False,
    )
    return "diverged" if merge_base.returncode == 0 else "unrelated-histories"


def git_worktree_state_counts(worktree: Path) -> tuple[int, int, int, int]:
    output = git_output(worktree, ["status", "--porcelain=v2", "--untracked-files=all"])
    staged = 0
    unstaged = 0
    untracked = 0
    conflicted = 0
    for line in output.splitlines():
        if line.startswith("? "):
            untracked += 1
            continue
        if line.startswith("u "):
            conflicted += 1
            continue
        if not line.startswith(("1 ", "2 ")):
            continue
        fields = line.split(" ", 3)
        xy = fields[1] if len(fields) > 1 else ".."
        if len(xy) >= 1 and xy[0] not in {".", " "}:
            staged += 1
        if len(xy) >= 2 and xy[1] not in {".", " "}:
            unstaged += 1
    return staged, unstaged, untracked, conflicted


def is_finder_metadata_name(name: str) -> bool:
    return name in FINDER_METADATA_NAMES or name.startswith("._")


def is_ignorable_git_finder_error(line: str) -> bool:
    """Recognize Git fsck errors caused only by Finder sidecars in refs."""
    if not line.startswith("error: refs/"):
        return False
    ref_name = line[len("error: refs/") :].split(":", 1)[0]
    return is_finder_metadata_name(Path(ref_name).name) and (
        "badRefName" in line or "badRefContent" in line
    )


def collect_unreachable_git_objects(worktree: Path) -> set[str]:
    """Run the one permitted source strict fsck and collect unreachable OIDs."""
    result = run_command(
        [
            "git",
            "-C",
            worktree,
            "fsck",
            "--full",
            "--strict",
            "--unreachable",
            "--no-reflogs",
        ],
        check=False,
    )
    combined = (result.stdout + result.stderr).decode("utf-8", "replace")
    serious: list[str] = []
    for line in combined.splitlines():
        is_serious = line.startswith(
            (
                "error:",
                "fatal:",
                "broken link from ",
                "missing ",
                "failed to ",
                "bad sha1 file:",
                "index CRC mismatch",
                "pack checksum mismatch",
            )
        )
        if not is_serious:
            continue
        if "HEAD points to an unborn branch" in line or is_ignorable_git_finder_error(line):
            continue
        serious.append(line)
    if result.returncode != 0 and not serious:
        serious = [
            line
            for line in combined.splitlines()
            if line.strip() and not is_ignorable_git_finder_error(line)
        ][:8]
    if result.returncode != 0 and serious:
        raise RecoveryError(f"Source Git object database failed fsck for {worktree}: {'; '.join(serious[:8])}")
    object_ids: set[str] = set()
    for line in combined.splitlines():
        match = re.search(r"\b(?:unreachable|dangling)\s+\w+\s+([0-9a-fA-F]{40,64})\b", line)
        if match:
            object_ids.add(match.group(1).lower())
    return object_ids


def atomic_copy_missing_file(source: Path, destination: Path) -> bool:
    """Install one immutable Git/LFS object without touching an existing file.

    Git object files are content addressed and may intentionally be read-only.
    macOS openrsync attempts metadata operations against an already-present
    read-only object even with ``--ignore-existing``. Prefer a same-volume hard
    link, and otherwise copy to a sibling temporary file before an atomic link.
    The final hard-link operation is create-only, so canonical data is never
    replaced if another writer wins the race.
    """
    source_stat = source.stat(follow_symlinks=False)
    if not stat.S_ISREG(source_stat.st_mode):
        raise RecoveryError(f"Unexpected non-regular Git storage entry: {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    if os.path.lexists(destination):
        destination_stat = destination.stat(follow_symlinks=False)
        if not stat.S_ISREG(destination_stat.st_mode):
            raise RecoveryError(f"Canonical Git storage path is not a regular file: {destination}")
        source_hash, _ = stable_file_hash(source)
        destination_hash, _ = stable_file_hash(destination)
        if source_hash != destination_hash:
            raise RecoveryError(
                f"Content-addressed Git/LFS storage collision: {source} != {destination}"
            )
        return False

    try:
        os.link(source, destination, follow_symlinks=False)
        return True
    except FileExistsError:
        source_hash, _ = stable_file_hash(source)
        destination_hash, _ = stable_file_hash(destination)
        if source_hash != destination_hash:
            raise RecoveryError(
                f"Content-addressed Git/LFS storage race collision: {source} != {destination}"
            )
        return False
    except OSError as error:
        if error.errno not in (errno.EXDEV, errno.EPERM, errno.EACCES, errno.ENOTSUP):
            raise RecoveryError(f"Could not preserve Git object {source}: {error}") from error

    temporary_fd, temporary_name = tempfile.mkstemp(
        prefix=f".{destination.name}.csa-iem-copy-",
        dir=destination.parent,
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(temporary_fd, "wb", closefd=True) as output_handle:
            with source.open("rb", buffering=0) as input_handle:
                shutil.copyfileobj(input_handle, output_handle, length=8 * 1024 * 1024)
            output_handle.flush()
            os.fsync(output_handle.fileno())
        os.chmod(temporary, stat.S_IMODE(source_stat.st_mode), follow_symlinks=False)
        try:
            os.link(temporary, destination, follow_symlinks=False)
        except FileExistsError:
            temporary_hash, _ = stable_file_hash(temporary)
            destination_hash, _ = stable_file_hash(destination)
            if temporary_hash != destination_hash:
                raise RecoveryError(
                    f"Content-addressed Git/LFS storage race collision: {source} != {destination}"
                )
            return False
        return True
    finally:
        try:
            guarded_unlink(temporary)
        except FileNotFoundError:
            pass


def copy_missing_git_storage(
    source_root: Path,
    destination_root: Path,
    *,
    excluded_top_level: set[str] | None = None,
) -> int:
    """Copy only missing immutable files from a Git object storage tree."""
    excluded = excluded_top_level or set()
    copied = 0
    destination_root.mkdir(parents=True, exist_ok=True)
    for current_text, directory_names, file_names in os.walk(source_root, followlinks=False):
        current = Path(current_text)
        relative_directory = current.relative_to(source_root)
        if relative_directory == Path("."):
            directory_names[:] = [name for name in directory_names if name not in excluded]
        for directory_name in list(directory_names):
            directory_path = current / directory_name
            if directory_path.is_symlink():
                raise RecoveryError(f"Unexpected symlink in Git storage: {directory_path}")
        for file_name in file_names:
            # Finder metadata is not part of Git's content-addressed object
            # store and can make refs invalid. It is preserved separately as
            # recovery evidence instead of installing it into active .git.
            if is_finder_metadata_name(file_name):
                continue
            # A multi-pack-index is a derived cache tied to the exact pack set
            # of one object directory. Installing a source MIDX into a
            # destination with a different pack set can make every object look
            # unreadable. Pack, index, reverse-index, and loose object files
            # remain copied; Git can regenerate the MIDX safely if desired.
            if relative_directory == Path("pack") and (
                file_name == "multi-pack-index" or file_name.startswith("multi-pack-index-")
            ):
                continue
            source_file = current / file_name
            destination_file = destination_root / relative_directory / file_name
            if atomic_copy_missing_file(source_file, destination_file):
                copied += 1
    return copied


def git_storage_files(
    root: Path,
    *,
    excluded_top_level: set[str] | None = None,
) -> dict[str, Path]:
    excluded = excluded_top_level or set()
    files: dict[str, Path] = {}
    for current_text, directory_names, file_names in os.walk(root, followlinks=False):
        current = Path(current_text)
        relative_directory = current.relative_to(root)
        if relative_directory == Path("."):
            directory_names[:] = [name for name in directory_names if name not in excluded]
        for directory_name in list(directory_names):
            if (current / directory_name).is_symlink():
                raise RecoveryError(f"Unexpected symlink in Git storage: {current / directory_name}")
        for file_name in file_names:
            if is_finder_metadata_name(file_name):
                continue
            if relative_directory == Path("pack") and (
                file_name == "multi-pack-index" or file_name.startswith("multi-pack-index-")
            ):
                continue
            path = current / file_name
            file_stat = path.stat(follow_symlinks=False)
            if not stat.S_ISREG(file_stat.st_mode):
                raise RecoveryError(f"Unexpected non-regular Git storage entry: {path}")
            files[(relative_directory / file_name).as_posix()] = path
    return files


def verify_git_storage_snapshot(
    source_root: Path,
    snapshot_root: Path,
    *,
    excluded_top_level: set[str] | None = None,
) -> int:
    source_files = git_storage_files(source_root, excluded_top_level=excluded_top_level)
    snapshot_files = git_storage_files(snapshot_root)
    if source_files.keys() != snapshot_files.keys():
        missing = sorted(source_files.keys() - snapshot_files.keys())[:8]
        extra = sorted(snapshot_files.keys() - source_files.keys())[:8]
        raise RecoveryError(
            f"Git object snapshot file set mismatch; missing={missing}, extra={extra}"
        )
    for relative, source_file in source_files.items():
        snapshot_file = snapshot_files[relative]
        try:
            same_file = os.path.samefile(source_file, snapshot_file)
        except OSError:
            same_file = False
        if same_file:
            continue
        source_hash, _source_stat = stable_file_hash(source_file)
        snapshot_hash, _snapshot_stat = stable_file_hash(snapshot_file)
        if source_hash != snapshot_hash:
            raise RecoveryError(f"Git object snapshot checksum mismatch: {source_file}")
    return len(source_files)


def verify_git_storage_superset(source_root: Path, destination_root: Path) -> int:
    """Prove every immutable source Git/LFS storage file exists byte-for-byte."""
    source_files = git_storage_files(source_root)
    destination_files = git_storage_files(destination_root)
    missing = sorted(source_files.keys() - destination_files.keys())
    if missing:
        raise RecoveryError(f"Canonical Git/LFS storage is missing source files: {missing[:8]}")
    for relative, source_file in source_files.items():
        destination_file = destination_files[relative]
        try:
            same_file = os.path.samefile(source_file, destination_file)
        except OSError:
            same_file = False
        if same_file:
            continue
        source_hash, _ = stable_file_hash(source_file)
        destination_hash, _ = stable_file_hash(destination_file)
        if source_hash != destination_hash:
            raise RecoveryError(
                f"Canonical Git/LFS storage checksum mismatch: {source_file} -> {destination_file}"
            )
    return len(source_files)


def preserve_git_finder_metadata(source_git_dir: Path, evidence_dir: Path) -> int:
    """Preserve Finder artifacts from .git without activating invalid refs."""
    target_root = evidence_dir / "finder-metadata"
    copied = 0
    for current_text, _directory_names, file_names in os.walk(source_git_dir, followlinks=False):
        current = Path(current_text)
        for file_name in file_names:
            if not is_finder_metadata_name(file_name):
                continue
            source_file = current / file_name
            relative = source_file.relative_to(source_git_dir)
            destination_file = target_root / relative
            copy_exact(source_file, destination_file, target_root)
            copied += 1
    return copied


def preserve_prior_recovery_tree(
    source: Path,
    destination: Path,
    transaction: str,
    source_id: str,
) -> tuple[str, str]:
    """Preserve a source's prior recovery evidence before excluding it from merge."""
    source_recovery = source / RECOVERY_DIR_NAME
    if not os.path.lexists(source_recovery):
        return "", ""
    snapshot_parent = (
        destination
        / RECOVERY_DIR_NAME
        / "prior-recovery"
        / safe_ref_component(transaction)
        / source_id
    )
    snapshot = snapshot_parent / "source-recovery"
    if os.path.lexists(snapshot):
        raise RecoveryError(f"Prior recovery snapshot already exists: {snapshot}")
    digest = copy_exact_verified(source_recovery, snapshot, snapshot_parent)
    return display_path(snapshot), digest


def resolve_git_common_dir(source: Path, source_git_dir: Path) -> Path:
    result = run_command(
        ["git", "-C", source, "rev-parse", "--path-format=absolute", "--git-common-dir"],
        check=False,
    )
    if result.returncode == 0:
        value = result.stdout.decode("utf-8", "surrogateescape").strip()
        if value:
            return Path(value) if Path(value).is_absolute() else canonical(source / value)
    result = run_command(["git", "-C", source, "rev-parse", "--git-common-dir"], check=False)
    value = result.stdout.decode("utf-8", "surrogateescape").strip()
    if not value:
        return source_git_dir
    return Path(value) if Path(value).is_absolute() else canonical(source / value)


def preserve_full_git_snapshot(
    source: Path,
    source_git_dir: Path,
    destination: Path,
    transaction: str,
    source_id: str,
    evidence_dir: Path,
) -> tuple[Path, str, list[GitComponentSnapshot]]:
    """Preserve exact local Git state, including common dirs and alternates."""
    snapshot_root = (
        destination
        / RECOVERY_DIR_NAME
        / "git-snapshots"
        / safe_ref_component(transaction)
        / source_id
    )
    if snapshot_root.exists() or snapshot_root.is_symlink():
        raise RecoveryError(f"Full Git snapshot already exists: {snapshot_root}")
    snapshot_root.mkdir(parents=True, exist_ok=False)

    snapshots: list[GitComponentSnapshot] = []

    def record_component(
        kind: str,
        source_role: str,
        source_path: Path,
        snapshot_path: Path,
        digest: str,
    ) -> None:
        snapshots.append(
            GitComponentSnapshot(
                kind=kind,
                source_role=source_role,
                source_path=display_path(source_path),
                snapshot_relative=(snapshot_path.relative_to(destination)).as_posix(),
                digest=digest,
            )
        )

    resolved_snapshot = snapshot_root / "resolved-git-dir"
    resolved_digest = copy_exact_verified(source_git_dir, resolved_snapshot, snapshot_root)
    record_component(
        "resolved-git-dir",
        "worktree-git-dir",
        source_git_dir,
        resolved_snapshot,
        resolved_digest,
    )

    dot_git_entry = source / ".git"
    if os.path.lexists(dot_git_entry) and canonical(dot_git_entry) != canonical(source_git_dir):
        dot_git_snapshot = snapshot_root / "worktree-dot-git"
        dot_git_digest = copy_exact_verified(dot_git_entry, dot_git_snapshot, snapshot_root)
        record_component(
            "worktree-dot-git",
            "worktree-dot-git",
            dot_git_entry,
            dot_git_snapshot,
            dot_git_digest,
        )

    common_dir = resolve_git_common_dir(source, source_git_dir)
    if canonical(common_dir) != canonical(source_git_dir):
        common_snapshot = snapshot_root / "common-git-dir"
        common_digest = copy_exact_verified(common_dir, common_snapshot, snapshot_root)
        record_component(
            "common-git-dir",
            "common-git-dir",
            common_dir,
            common_snapshot,
            common_digest,
        )
    else:
        common_snapshot = resolved_snapshot
        common_digest = resolved_digest
        record_component(
            "common-git-dir",
            "common-git-dir",
            common_dir,
            common_snapshot,
            common_digest,
        )

    alternates_path = common_dir / "objects" / "info" / "alternates"
    if alternates_path.is_file():
        lines = alternates_path.read_text(encoding="utf-8", errors="surrogateescape").splitlines()
        for index, raw_path in enumerate(lines):
            if not raw_path.strip():
                continue
            alternate = Path(raw_path.strip())
            if not alternate.is_absolute():
                alternate = canonical(common_dir / "objects" / alternate)
            if not alternate.is_dir():
                raise RecoveryError(f"Git alternate object directory is unavailable: {alternate}")
            alternate_snapshot = snapshot_root / "alternates" / f"{index:04d}" / "objects"
            alternate_snapshot.parent.mkdir(parents=True, exist_ok=True)
            alternate_digest = copy_exact_verified(alternate, alternate_snapshot, snapshot_root)
            record_component(
                "alternate-objects",
                f"alternate-objects:{index}",
                alternate,
                alternate_snapshot,
                alternate_digest,
            )

    lfs_source = common_dir / "lfs" / "objects"
    if lfs_source.is_dir():
        lfs_snapshot = common_snapshot / "lfs" / "objects"
        lfs_digest = verify_exact_path_snapshot(lfs_source, lfs_snapshot)
        record_component(
            "lfs-objects",
            "common-lfs-objects",
            lfs_source,
            lfs_snapshot,
            lfs_digest,
        )

    write_json(
        evidence_dir / "full-git-snapshot.json",
        {"snapshots": [dataclasses.asdict(snapshot) for snapshot in snapshots]},
    )
    snapshot_digest = count_source_tree(
        snapshot_root,
        excluded_top_level=set(),
        include_root=True,
    ).root_digest
    return snapshot_root, snapshot_digest, snapshots


def preserve_broken_git_fragment(
    source_git_dir: Path,
    destination: Path,
    transaction: str,
    source_id: str,
    evidence_dir: Path,
) -> tuple[Path, str]:
    """Store a byte-exact broken/incomplete .git tree outside active Git state."""
    fragment_parent = (
        destination
        / RECOVERY_DIR_NAME
        / "git-fragments"
        / safe_ref_component(transaction)
        / source_id
    )
    snapshot = fragment_parent / "git-dir"
    if snapshot.exists() or snapshot.is_symlink():
        raise RecoveryError(f"Broken Git fragment snapshot already exists: {snapshot}")
    snapshot_digest = copy_exact_verified(source_git_dir, snapshot, fragment_parent)
    stats_result = count_source_tree(source_git_dir, excluded_top_level=set(), include_root=True)
    write_json(
        evidence_dir / "broken-git-fragment.json",
        {
            "sourceGitDir": display_path(source_git_dir),
            "snapshot": display_path(snapshot),
            "tree": dataclasses.asdict(stats_result),
        },
    )
    return snapshot, snapshot_digest


def preserve_evidence_only_git_fragment(
    source: Path,
    destination: Path,
    transaction: str,
    source_id: str,
    evidence_dir: Path,
) -> tuple[GitEvidence, TreeStats, str]:
    """Snapshot a raw Git administration tree without activating any entry."""
    if not raw_git_administration_tree(source):
        raise RecoveryError(f"Not a raw Git administration tree: {source}")
    fragment_parent = (
        destination
        / RECOVERY_DIR_NAME
        / "git-fragments"
        / safe_ref_component(transaction)
        / source_id
    )
    snapshot = fragment_parent / "raw-administration-tree"
    digest = copy_exact_verified(source, snapshot, fragment_parent)
    relative_snapshot = snapshot.relative_to(destination).as_posix()
    evidence = GitEvidence(
        source_git=True,
        destination_git=resolve_git_dir(destination) is not None,
        source_fsck_clean=False,
        fragment_snapshot=display_path(snapshot),
        fragment_digest=digest,
        fragment_source_path=display_path(source),
        full_snapshot=display_path(snapshot),
        full_snapshot_digest=digest,
        pointer_only_evidence=True,
        git_history_imported=False,
        source_fsck_invocations=1,
        component_snapshots=[
            GitComponentSnapshot(
                kind="raw-git-administration-tree",
                source_role="raw-git-fragment",
                source_path=display_path(source),
                snapshot_relative=relative_snapshot,
                digest=digest,
            )
        ],
    )
    fsck = run_command(
        [
            "git",
            f"--git-dir={source}",
            "fsck",
            "--full",
            "--strict",
            "--unreachable",
            "--no-reflogs",
        ],
        check=False,
    )
    diagnostics = (fsck.stdout + fsck.stderr).decode("utf-8", "replace").strip()
    if fsck.returncode == 0:
        evidence.source_fsck_clean = True
    else:
        evidence.source_fsck_error = diagnostics[:8000]
    if verify_exact_path_snapshot(source, snapshot) != digest:
        raise RecoveryError(f"Raw Git fragment changed during its one fsck: {source}")
    tree = write_exact_snapshot_manifest(
        source,
        snapshot,
        evidence_dir / "filesystem-manifest.jsonl",
        excluded_top_level=set(),
    )
    write_json(
        evidence_dir / "evidence-only-git-fragment.json",
        {
            "source": display_path(source),
            "snapshot": display_path(snapshot),
            "digest": digest,
            "sourceFsckClean": evidence.source_fsck_clean,
            "sourceFsckError": evidence.source_fsck_error,
            "activation": "prohibited",
            "tree": dataclasses.asdict(tree),
        },
    )
    return evidence, tree, relative_snapshot


def delete_ref_namespace(worktree: Path, namespace: str) -> None:
    """Remove only refs created by the current recovery source transaction."""
    output = git_output(worktree, ["for-each-ref", "--format=%(refname)", namespace])
    refs = [line for line in output.splitlines() if line == namespace or line.startswith(namespace + "/")]
    if not refs:
        return
    commands = "".join(f"delete {ref_name}\n" for ref_name in refs)
    run_command(
        ["git", "-C", worktree, "update-ref", "--stdin"],
        input_bytes=commands.encode("ascii"),
    )


def current_git_component_paths(
    source: Path,
    evidence: GitEvidence,
) -> dict[str, Path]:
    paths: dict[str, Path] = {}
    if any(
        snapshot.source_role == "raw-git-fragment"
        for snapshot in evidence.component_snapshots
    ):
        paths["raw-git-fragment"] = source
        return paths
    source_git_dir = resolve_git_dir(source)
    if source_git_dir is not None:
        paths["worktree-git-dir"] = source_git_dir
        common_dir = resolve_git_common_dir(source, source_git_dir)
        paths["common-git-dir"] = common_dir
        lfs = common_dir / "lfs" / "objects"
        if lfs.is_dir():
            paths["common-lfs-objects"] = lfs
        alternates_path = common_dir / "objects" / "info" / "alternates"
        if alternates_path.is_file():
            lines = alternates_path.read_text(
                encoding="utf-8", errors="surrogateescape"
            ).splitlines()
            for index, raw_path in enumerate(lines):
                if not raw_path.strip():
                    continue
                alternate = Path(raw_path.strip())
                if not alternate.is_absolute():
                    alternate = canonical(common_dir / "objects" / alternate)
                paths[f"alternate-objects:{index}"] = alternate
    dot_git = source / ".git"
    if os.path.lexists(dot_git) and (
        source_git_dir is None or canonical(dot_git) != canonical(source_git_dir)
    ):
        paths["worktree-dot-git"] = dot_git
    return paths


def verify_source_git_unchanged(
    source: Path,
    evidence: GitEvidence,
    destination: Path,
) -> None:
    """Revalidate captured Git bytes without running a second source fsck."""
    if not evidence.source_git:
        return
    current_components = current_git_component_paths(source, evidence)
    expected_roles = {snapshot.source_role for snapshot in evidence.component_snapshots}
    if set(current_components) != expected_roles:
        raise RecoveryError(
            f"Source Git component set changed during recovery: {source}; "
            f"expected={sorted(expected_roles)}, actual={sorted(current_components)}"
        )
    for component in evidence.component_snapshots:
        source_component = current_components.get(component.source_role)
        if source_component is None or not os.path.lexists(source_component):
            raise RecoveryError(
                f"Source Git component disappeared during recovery: {component.source_role} for {source}"
            )
        snapshot = destination / component.snapshot_relative
        digest = verify_exact_path_snapshot(source_component, snapshot)
        if digest != component.digest:
            raise RecoveryError(
                f"Source Git component changed during recovery: {component.source_role} for {source}"
            )
    if not evidence.source_fsck_clean:
        return
    source_head = git_output(source, ["rev-parse", "HEAD"])
    if not re.fullmatch(r"[0-9a-fA-F]{40,64}", source_head):
        source_head = ""
    source_refs = collect_git_refs(source)
    if source_head != evidence.source_head:
        raise RecoveryError(f"Source Git HEAD changed during recovery: {source}")
    if source_refs != evidence.source_refs:
        raise RecoveryError(f"Source Git refs changed during recovery: {source}")


def write_git_state_evidence(source: Path, evidence_dir: Path, canonical_git_state: Path) -> None:
    evidence_dir.mkdir(parents=True, exist_ok=True)
    commands: list[tuple[str, list[str], bool]] = [
        ("status.txt", ["status", "--porcelain=v2", "--branch", "--untracked-files=all"], False),
        ("refs.txt", ["for-each-ref", "--format=%(objectname) %(refname)"], False),
        ("config.txt", ["config", "--list", "--show-origin"], False),
        ("reflog.txt", ["reflog", "show", "--all", "--date=iso", "--format=%H %gd %gs"], False),
        ("staged.patch", ["diff", "--cached", "--binary", "--no-ext-diff"], True),
        ("unstaged.patch", ["diff", "--binary", "--no-ext-diff"], True),
    ]
    for filename, arguments, copy_to_canonical in commands:
        result = run_command(["git", "-C", source, *arguments], check=False)
        payload = result.stdout
        if result.stderr:
            payload += b"\n# stderr\n" + result.stderr
        if not payload.strip() and filename.endswith(".patch"):
            continue
        (evidence_dir / filename).write_bytes(payload)
        if copy_to_canonical and payload.strip():
            canonical_git_state.mkdir(parents=True, exist_ok=True)
            (canonical_git_state / filename).write_bytes(payload)


def ensure_recovery_excluded(destination: Path) -> None:
    git_dir = resolve_git_dir(destination)
    if git_dir is None:
        return
    exclude_path = Path(git_output(destination, ["rev-parse", "--git-path", "info/exclude"], check=True))
    if not exclude_path.is_absolute():
        exclude_path = destination / exclude_path
    exclude_path.parent.mkdir(parents=True, exist_ok=True)
    existing = exclude_path.read_text(encoding="utf-8", errors="surrogateescape") if exclude_path.exists() else ""
    entry = f"/{RECOVERY_DIR_NAME}/"
    if entry not in existing.splitlines():
        separator = "" if not existing or existing.endswith("\n") else "\n"
        with exclude_path.open("a", encoding="utf-8") as handle:
            handle.write(separator + entry + "\n")


def rearm_destination_remote(destination: Path, repository: str) -> str:
    """Point one reviewed canonical repository at its intended GitHub identity."""
    expected_identity = normalize_remote(f"https://github.com/{repository}")
    if not expected_identity:
        raise RecoveryError(f"Invalid reviewed GitHub repository: {repository}")
    if resolve_git_dir(destination) is None:
        initialized = run_command(
            ["git", "-C", destination, "init", "-b", "main"],
            check=False,
        )
        if initialized.returncode != 0:
            run_command(["git", "-C", destination, "init"])
            run_command(["git", "-C", destination, "symbolic-ref", "HEAD", "refs/heads/main"])
    remote_url = f"https://github.com/{repository}.git"
    remotes = set(git_output(destination, ["remote"]).splitlines())
    if "origin" in remotes:
        run_command(["git", "-C", destination, "remote", "set-url", "origin", remote_url])
    else:
        run_command(["git", "-C", destination, "remote", "add", "origin", remote_url])
    actual_identity = normalize_remote(git_remote(destination))
    if actual_identity != expected_identity:
        raise RecoveryError(
            f"Canonical remote re-arm verification failed: {actual_identity} != {expected_identity}"
        )
    ensure_recovery_excluded(destination)
    return actual_identity


def import_and_verify_git(
    source: Path,
    destination: Path,
    transaction: str,
    source_id: str,
    evidence_dir: Path,
    *,
    preserve_full_snapshot: bool = True,
    allow_identity_mismatch: bool = False,
    expected_legacy_repository: str = "",
) -> GitEvidence:
    del preserve_full_snapshot  # Every Git source is now snapshotted; callers cannot weaken this.
    source_git_dir = resolve_git_dir(source)
    destination_git_dir = resolve_git_dir(destination)
    source_dot_git = source / ".git"
    source_has_git_entry = os.path.lexists(source_dot_git)
    evidence = GitEvidence(
        source_git=source_git_dir is not None or source_has_git_entry,
        destination_git=destination_git_dir is not None,
        source_remote=normalize_remote(git_remote(source)) if source_git_dir is not None else "",
        destination_remote=normalize_remote(git_remote(destination)) if destination_git_dir is not None else "",
    )
    if source_git_dir is None:
        if source_has_git_entry:
            fragment_parent = (
                destination
                / RECOVERY_DIR_NAME
                / "git-fragments"
                / safe_ref_component(transaction)
                / source_id
            )
            fragment_parent.mkdir(parents=True, exist_ok=True)
            snapshot = fragment_parent / "git-entry"
            digest = copy_exact_verified(source_dot_git, snapshot, fragment_parent)
            evidence.source_fsck_clean = False
            evidence.source_fsck_error = "The source .git entry could not be resolved as a repository."
            evidence.fragment_snapshot = display_path(snapshot)
            evidence.fragment_digest = digest
            evidence.fragment_source_path = display_path(source_dot_git)
            evidence.pointer_only_evidence = True
            evidence.component_snapshots.append(
                GitComponentSnapshot(
                    kind="unresolved-worktree-dot-git",
                    source_role="worktree-dot-git",
                    source_path=display_path(source_dot_git),
                    snapshot_relative=snapshot.relative_to(destination).as_posix(),
                    digest=digest,
                )
            )
            write_json(
                evidence_dir / "unresolved-git-entry.json",
                {
                    "sourceGitEntry": display_path(source_dot_git),
                    "snapshot": display_path(snapshot),
                    "digest": digest,
                },
            )
            ensure_recovery_excluded(destination)
        return evidence
    if destination_git_dir is None:
        raise RecoveryError(f"Source is Git but canonical destination is not: {source} -> {destination}")
    legacy_identity = (
        normalize_remote(f"https://github.com/{expected_legacy_repository}")
        if expected_legacy_repository
        else ""
    )
    if legacy_identity and evidence.source_remote != legacy_identity:
        raise RecoveryError(
            f"Legacy Git identity changed during assembly: "
            f"{evidence.source_remote or 'unverified'} != {legacy_identity}"
        )
    if (
        evidence.source_remote
        and evidence.destination_remote
        and evidence.source_remote != evidence.destination_remote
        and not allow_identity_mismatch
        and not legacy_identity
    ):
        raise RecoveryError(
            f"Git identity mismatch: {evidence.source_remote} != {evidence.destination_remote}"
        )

    source_common_dir = resolve_git_common_dir(source, source_git_dir)
    evidence.source_worktree_git_dir = display_path(source_git_dir)
    evidence.source_common_git_dir = display_path(source_common_dir)

    # Perform every source query that can refresh the linked-worktree index
    # before snapshot capture. After the snapshot, the only whole-source Git
    # command permitted is the one strict fsck below.
    source_head = git_output(source, ["rev-parse", "HEAD"])
    if not re.fullmatch(r"[0-9a-fA-F]{40,64}", source_head):
        # `git rev-parse HEAD` can print the literal token HEAD while returning
        # failure for a valid but unborn repository. It is not an object ID.
        source_head = ""
    source_refs = collect_git_refs(source)
    evidence.source_head = source_head
    evidence.source_refs = source_refs
    destination_head = git_output(destination, ["rev-parse", "HEAD"])
    if not re.fullmatch(r"[0-9a-fA-F]{40,64}", destination_head):
        destination_head = ""
    evidence.destination_head = destination_head
    evidence.source_branch = git_output(source, ["symbolic-ref", "--short", "-q", "HEAD"])
    evidence.destination_branch = git_output(
        destination,
        ["symbolic-ref", "--short", "-q", "HEAD"],
    )
    evidence.source_commit_time = git_commit_time(source, source_head)
    evidence.destination_commit_time = git_commit_time(destination, destination_head)
    (
        evidence.staged_paths,
        evidence.unstaged_paths,
        evidence.untracked_paths,
        evidence.conflicted_paths,
    ) = git_worktree_state_counts(source)
    write_git_state_evidence(
        source,
        evidence_dir,
        destination
        / RECOVERY_DIR_NAME
        / "git-state"
        / safe_ref_component(transaction)
        / source_id,
    )

    # Capture every Git component after all index-refreshing reads and before
    # the one permitted source fsck. Final checks rehash these snapshots
    # byte-for-byte and never run a second source fsck.
    full_snapshot, full_snapshot_digest, component_snapshots = preserve_full_git_snapshot(
        source,
        source_git_dir,
        destination,
        transaction,
        source_id,
        evidence_dir,
    )
    evidence.full_snapshot = display_path(full_snapshot)
    evidence.full_snapshot_digest = full_snapshot_digest
    evidence.component_snapshots = component_snapshots
    preserve_git_finder_metadata(source_common_dir, evidence_dir)

    evidence.source_fsck_invocations = 1
    try:
        unreachable = collect_unreachable_git_objects(source)
    except RecoveryError as error:
        # A damaged source Git database must not poison the active canonical
        # repository. Preserve it byte-for-byte as an isolated fragment while
        # the ordinary working tree is merged and verified separately.
        evidence.source_fsck_clean = False
        evidence.source_fsck_error = str(error)
        evidence.fragment_snapshot = display_path(full_snapshot)
        evidence.fragment_digest = full_snapshot_digest
        evidence.fragment_source_path = display_path(source_git_dir)
        evidence.pointer_only_evidence = True
        ensure_recovery_excluded(destination)
        return evidence
    evidence.unreachable_oids = set(unreachable)
    if source_head:
        evidence.protected_oids.add(source_head.lower())
    evidence.protected_oids.update(source_refs.values())

    namespace = f"refs/csa-iem/recovery/{safe_ref_component(transaction)}/{safe_ref_component(source_id)}"
    evidence.namespace = namespace

    source_objects = source_common_dir / "objects"
    destination_objects = destination_git_dir / "objects"
    if source_objects.is_dir():
        # The objects/info tree contains derived commit-graph and alternates
        # metadata. Import immutable loose/packed objects only; destination
        # fsck and cat-file checks below prove every protected source object.
        copy_missing_git_storage(
            source_objects,
            destination_objects,
            excluded_top_level={"info"},
        )

    alternates_path = source_common_dir / "objects" / "info" / "alternates"
    if alternates_path.is_file():
        for raw_path in alternates_path.read_text(
            encoding="utf-8", errors="surrogateescape"
        ).splitlines():
            if not raw_path.strip():
                continue
            alternate = Path(raw_path.strip())
            if not alternate.is_absolute():
                alternate = canonical(source_common_dir / "objects" / alternate)
            if not alternate.is_dir():
                raise RecoveryError(f"Git alternate object directory is unavailable: {alternate}")
            copy_missing_git_storage(
                alternate,
                destination_objects,
                excluded_top_level={"info"},
            )

    source_lfs = source_common_dir / "lfs" / "objects"
    destination_lfs = destination_git_dir / "lfs" / "objects"
    if source_lfs.is_dir():
        copy_missing_git_storage(source_lfs, destination_lfs)
        verify_git_storage_superset(source_lfs, destination_lfs)

    update_lines: list[str] = []
    if source_head:
        update_lines.append(f"create {namespace}/HEAD {source_head}")
    for ref_name, object_id in sorted(source_refs.items()):
        suffix = safe_ref_component(ref_name.removeprefix("refs/"))
        update_lines.append(f"create {namespace}/refs/{suffix} {object_id}")
    try:
        if update_lines:
            run_command(
                ["git", "-C", destination, "update-ref", "--stdin"],
                input_bytes=("\n".join(update_lines) + "\n").encode("ascii"),
            )

        evidence.history_relation = classify_git_history(
            source,
            destination,
            source_head,
            destination_head,
        )

        for object_id in sorted(evidence.protected_oids | evidence.unreachable_oids):
            result = run_command(["git", "-C", destination, "cat-file", "-e", f"{object_id}^{{object}}"], check=False)
            if result.returncode != 0:
                raise RecoveryError(f"Canonical Git database is missing source object {object_id}: {destination}")
    except Exception:
        # Never leave a failed source's generated recovery refs active.
        delete_ref_namespace(destination, namespace)
        raise

    evidence.git_history_imported = True
    ensure_recovery_excluded(destination)
    return evidence


def verify_git_evidence(destination: Path, evidence: GitEvidence) -> None:
    """Verify every source-protected object without repeating a full fsck.

    The caller immediately follows this object-specific check with
    ``verify_canonical_git_independence``, which performs the single strict
    whole-database fsck required for the pass.
    """
    if not evidence.source_git:
        return
    if not evidence.git_history_imported:
        if not evidence.pointer_only_evidence:
            raise RecoveryError("Git source has neither imported history nor pointer-only evidence")
        return
    if resolve_git_dir(destination) is None:
        raise RecoveryError(f"Canonical Git repository disappeared: {destination}")
    for object_id in sorted(evidence.protected_oids | evidence.unreachable_oids):
        result = run_command(["git", "-C", destination, "cat-file", "-e", f"{object_id}^{{object}}"], check=False)
        if result.returncode != 0:
            raise RecoveryError(f"Canonical Git verification lost source object {object_id}: {destination}")


def verify_canonical_git_independence(destination: Path) -> str:
    """Require a self-contained canonical Git database before source retirement."""
    dot_git = destination / ".git"
    if not dot_git.is_dir() or dot_git.is_symlink():
        raise RecoveryError(f"Canonical .git must be a real directory: {dot_git}")
    git_dir = resolve_git_dir(destination)
    if git_dir is None or not path_within(canonical(git_dir), canonical(destination)):
        raise RecoveryError(f"Canonical Git directory depends on an external path: {destination}")
    common_dir = resolve_git_common_dir(destination, git_dir)
    if canonical(common_dir) != canonical(git_dir):
        raise RecoveryError(f"Canonical Git repository is a linked worktree: {destination}")
    commondir = git_dir / "commondir"
    if commondir.exists() or commondir.is_symlink():
        raise RecoveryError(f"Canonical Git repository retains commondir metadata: {commondir}")
    alternates = git_dir / "objects" / "info" / "alternates"
    if alternates.is_file() and alternates.read_text(
        encoding="utf-8", errors="surrogateescape"
    ).strip():
        raise RecoveryError(f"Canonical Git repository depends on alternate objects: {alternates}")
    result = run_command(
        [
            "git",
            "-C",
            destination,
            "-c",
            "core.multiPackIndex=false",
            "fsck",
            "--full",
            "--strict",
            "--unreachable",
            "--no-reflogs",
        ],
        check=False,
    )
    if result.returncode != 0:
        output = (result.stdout + result.stderr).decode("utf-8", "replace").strip()
        raise RecoveryError(f"Canonical independent Git fsck failed for {destination}: {output}")
    return sha256_bytes(result.stdout + result.stderr)


def source_id_for(mapping: Mapping) -> str:
    label = safe_ref_component(mapping.source.name)[:60]
    digest = hashlib.sha256(os.fsencode(display_path(mapping.source))).hexdigest()[:12]
    return f"{label}-{digest}"


def copy_new_canonical(
    source: Path,
    destination: Path,
    staging_root: Path,
    excluded_relative_paths: Sequence[str] = (),
) -> None:
    stage = staging_root / destination.parent.name / destination.name
    if stage.exists() or stage.is_symlink():
        remove_recovery_target(stage, staging_root)
    stage.parent.mkdir(parents=True, exist_ok=True)
    if not excluded_relative_paths:
        copy_exact(source, stage, staging_root)
    else:
        stage.mkdir(parents=True, exist_ok=False)
        try:
            shutil.copystat(source, stage, follow_symlinks=False)
        except OSError:
            pass
        for relative, source_path, source_stat in iter_source_entries(
            source,
            excluded_top_level={RECOVERY_DIR_NAME},
            excluded_relative_paths=excluded_relative_paths,
        ):
            destination_path = stage / relative
            kind = file_kind(source_stat)
            if kind == "directory":
                destination_path.mkdir(parents=True, exist_ok=False)
                try:
                    shutil.copystat(source_path, destination_path, follow_symlinks=False)
                except OSError:
                    pass
            elif kind in {"file", "symlink"}:
                copy_exact(source_path, destination_path, stage)
            else:
                raise RecoveryError(
                    f"Unsupported special filesystem object; source retained: {source_path}"
                )
    if destination.exists() or destination.is_symlink():
        raise RecoveryError(f"Canonical destination appeared during staging: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    guarded_replace(stage, destination)


def move_to_quarantine(source: Path, quarantine_root: Path, source_id: str) -> Path:
    quarantine_root.mkdir(parents=True, exist_ok=True)
    if source.stat().st_dev != quarantine_root.stat().st_dev:
        raise RecoveryError(f"Quarantine is not on the same filesystem as source: {source}")
    quarantine = quarantine_root / source_id
    if quarantine.exists() or quarantine.is_symlink():
        raise RecoveryError(f"Quarantine target already exists: {quarantine}")
    guarded_replace(source, quarantine)
    return quarantine


def delete_verified_quarantine(quarantine: Path, quarantine_root: Path) -> None:
    if not path_within(quarantine, quarantine_root) or quarantine == quarantine_root:
        raise RecoveryError(f"Refused to delete outside the transaction quarantine: {quarantine}")
    if quarantine.is_symlink() or not quarantine.is_dir():
        raise RecoveryError(f"Unexpected quarantine object: {quarantine}")
    guarded_rmtree(quarantine)


def group_key_for_destination(destination: Path) -> str:
    payload = os.fsencode(display_path(destination.parent)) + b"\0" + os.fsencode(
        destination.name.casefold()
    )
    return hashlib.sha256(payload).hexdigest()[:20]


def repository_for_group(mappings: Sequence[Mapping], destination: Path) -> str:
    reviewed = {
        normalize_remote(f"https://github.com/{mapping.repository}")
        for mapping in mappings
        if mapping.repository
    }
    reviewed.discard("")
    destination_identity = normalize_remote(git_remote(destination)) if destination.is_dir() else ""
    if destination_identity:
        reviewed.add(destination_identity)
    if len(reviewed) != 1:
        raise RecoveryError(
            f"Destination group lacks one reviewed GitHub identity: {destination}; "
            f"identities={sorted(reviewed)}"
        )
    return next(iter(reviewed))


def account_for_repository_group(
    mappings: Sequence[Mapping],
    repository: str,
    owner_account_bindings: dict[str, str],
) -> str:
    owner = repository.split("/", 1)[0]
    reviewed_accounts = {
        mapping.github_account
        for mapping in mappings
        if mapping.github_account
    }
    configured = owner_account_bindings.get(owner.casefold(), "")
    if configured:
        reviewed_accounts.add(configured)
    if len(reviewed_accounts) != 1:
        raise RecoveryError(
            f"GitHub owner {owner} requires exactly one reviewed account binding; "
            f"found={sorted(reviewed_accounts)}"
        )
    return next(iter(reviewed_accounts))


def prepare_destination_stage(
    mappings: Sequence[Mapping],
    destination: Path,
    live: LiveRepository,
    transaction_temp: Path,
) -> tuple[Path, Path | None]:
    stage_root = transaction_temp / "destination-staging"
    stage = stage_root / live.full_name
    if os.path.lexists(stage):
        raise RecoveryError(f"Destination staging path already exists: {stage}")
    stage.parent.mkdir(parents=True, exist_ok=True)
    if stage.parent.stat().st_dev != nearest_existing_path(destination.parent).stat().st_dev:
        raise RecoveryError(f"Destination staging is not on the canonical filesystem: {stage}")

    remote_seed = transaction_temp / "live-remotes" / f"{live.full_name}.git"
    if os.path.lexists(remote_seed):
        raise RecoveryError(f"Authenticated live-repository seed already exists: {remote_seed}")
    remote_seed.parent.mkdir(parents=True, exist_ok=True)
    environment, token = gh_token_environment(live.authenticated_login)
    if live.role == "wiki-child":
        clone_seed = run_token_scoped_git(
            live.authenticated_login,
            ["git", "clone", "--mirror", live.clone_url, remote_seed],
        )
    else:
        gh = github_cli_path()
        clone_seed = run_command(
            [gh, "repo", "clone", live.full_name, remote_seed, "--", "--mirror"],
            check=False,
            env=environment,
        )
    if clone_seed.returncode != 0:
        diagnostics = (clone_seed.stdout + clone_seed.stderr).decode(
            "utf-8", "replace"
        ).replace(token, "<redacted>").strip()
        raise RecoveryError(
            f"Authenticated live-repository mirror failed for {live.full_name}: {diagnostics}"
        )
    if live.remote_head:
        seed_head = command_text(
            ["git", "--git-dir", remote_seed, "rev-parse", f"refs/heads/{live.default_branch}"],
            check=True,
        )
        if seed_head.lower() != live.remote_head:
            raise RecoveryError(
                f"Authenticated repository mirror HEAD mismatch: {seed_head} != {live.remote_head}"
            )

    physical_existing = existing_physical_path(destination)
    if physical_existing is None:
        recase_sources = [
            mapping.source
            for mapping in mappings
            if is_case_only_canonical_recase(mapping)
        ]
        if len(recase_sources) > 1:
            raise RecoveryError(
                f"Multiple case-only canonical sources target {destination}: {recase_sources}"
            )
        if recase_sources:
            physical_existing = recase_sources[0]
    if physical_existing is not None:
        if not physical_existing.is_dir() or physical_existing.is_symlink():
            raise RecoveryError(f"Canonical destination is not a real directory: {physical_existing}")
        copy_exact(physical_existing, stage, stage_root)
        if resolve_git_dir(stage) is None:
            raise RecoveryError(
                f"Existing canonical destination is not a Git repository: {physical_existing}"
            )
        run_command(
            [
                "git",
                "-C",
                stage,
                "fetch",
                "--force",
                remote_seed,
                f"refs/heads/{live.default_branch}:refs/remotes/origin/{live.default_branch}",
            ]
        ) if live.remote_head else None
        run_command(["git", "-C", stage, "remote", "set-url", "origin", live.clone_url])
    else:
        clone = run_command(
            [
                "git",
                "clone",
                "--no-checkout",
                "--origin",
                "origin",
                remote_seed,
                stage,
            ],
            check=False,
        )
        if clone.returncode != 0:
            diagnostics = (clone.stdout + clone.stderr).decode("utf-8", "replace").strip()
            raise RecoveryError(f"Local staging clone failed for {live.full_name}: {diagnostics}")
        run_command(["git", "-C", stage, "remote", "set-url", "origin", live.clone_url])
        if live.remote_head:
            run_command(
                [
                    "git",
                    "-C",
                    stage,
                    "checkout",
                    "--force",
                    "-B",
                    live.default_branch,
                    f"origin/{live.default_branch}",
                ]
            )
        else:
            run_command(
                [
                    "git",
                    "-C",
                    stage,
                    "symbolic-ref",
                    "HEAD",
                    f"refs/heads/{live.default_branch}",
                ]
            )
    if live.remote_head:
        remote_ref = git_output(stage, ["rev-parse", f"refs/remotes/origin/{live.default_branch}"])
        if remote_ref.lower() != live.remote_head:
            raise RecoveryError(
                f"Staged remote HEAD mismatch for {live.full_name}: {remote_ref} != {live.remote_head}"
            )
    actual_identity = normalize_remote(git_remote(stage))
    expected_identity = normalize_remote(f"https://github.com/{live.full_name}")
    if actual_identity != expected_identity:
        raise RecoveryError(
            f"Staged origin identity mismatch: {actual_identity} != {expected_identity}"
        )
    return stage, physical_existing


def activation_decision(
    mapping: Mapping,
    evidence: GitEvidence,
    live: LiveRepository,
) -> tuple[bool, str]:
    if live.archived:
        return False, "archived-github-repository-evidence-only"
    if mapping.legacy_repository:
        return False, "reviewed-legacy-identity-migration-evidence-only"
    if mapping.kind == EVIDENCE_ONLY_GIT_FRAGMENT_KIND:
        return False, "raw-git-fragment-evidence-only"
    if mapping.source_policy == "evidence-only":
        return False, "reviewed-evidence-only-policy"
    if mapping.kind in OLD_SOURCE_KINDS and mapping.source_policy != "current-authoritative":
        return False, "old-source-class-defaults-to-recovery"
    expected_identity = normalize_remote(f"https://github.com/{live.full_name}")
    identity_verified = evidence.source_remote == expected_identity
    if mapping.allow_identity_mismatch:
        identity_verified = False
    if mapping.source_policy == "current-authoritative":
        if exact_derivation_exception(mapping, live.full_name):
            if not evidence.source_fsck_clean or not evidence.git_history_imported:
                raise RecoveryError(
                    f"Reviewed derivation source failed Git preservation proof: {mapping.source}"
                )
            return True, "reviewed-exact-derived-product-exception"
        if exact_non_git_bootstrap(mapping, live.full_name):
            return True, "reviewed-exact-non-git-bootstrap-exception"
        if not evidence.source_fsck_clean or not identity_verified:
            raise RecoveryError(
                f"Current-authoritative source failed Git/identity proof: {mapping.source}"
            )
        return True, "reviewed-current-authoritative"
    if not evidence.source_git:
        return False, "non-git-source-cannot-activate-missing-paths"
    if not evidence.source_fsck_clean or not evidence.git_history_imported:
        return False, "broken-or-pointer-only-git-source"
    if not identity_verified:
        return False, "source-github-identity-unverified"
    if evidence.history_relation in {"same-commit", "source-descendant-of-destination"}:
        return True, f"verified-{evidence.history_relation}"
    return False, f"history-{evidence.history_relation}-routes-to-recovery"


def validate_source_wins_runtime(
    mapping: Mapping,
    evidence: GitEvidence,
    destination_stage: Path,
    live: LiveRepository,
) -> None:
    if mapping.conflict_policy != "source-wins-after-preserve":
        return
    expected_identity = normalize_remote(f"https://github.com/{live.full_name}")
    if not (
        mapping.kind == "explicit-active-checkout-source"
        and mapping.source_policy == "current-authoritative"
        and mapping.retention == "retain"
        and not mapping.allow_identity_mismatch
        and evidence.source_remote == expected_identity
        and evidence.source_fsck_clean
        and evidence.git_history_imported
        and evidence.history_relation in {"same-commit", "source-descendant-of-destination"}
        and evidence.source_head
        and live.remote_head
    ):
        raise RecoveryError(
            f"source-wins runtime identity/history gate failed for {mapping.source}"
        )
    live_ancestor = run_command(
        [
            "git",
            "-C",
            destination_stage,
            "merge-base",
            "--is-ancestor",
            live.remote_head,
            evidence.source_head,
        ],
        check=False,
    )
    if live_ancestor.returncode != 0:
        raise RecoveryError(
            f"Active checkout HEAD is not a descendant of live remote history: "
            f"{evidence.source_head} / {live.remote_head}"
        )


def git_receipt_payload(evidence: GitEvidence) -> dict[str, object]:
    return {
        "sourceGit": evidence.source_git,
        "destinationGit": evidence.destination_git,
        "sourceHead": evidence.source_head,
        "destinationHead": evidence.destination_head,
        "sourceBranch": evidence.source_branch,
        "destinationBranch": evidence.destination_branch,
        "historyRelation": evidence.history_relation,
        "sourceCommitTime": evidence.source_commit_time,
        "destinationCommitTime": evidence.destination_commit_time,
        "stagedPathCount": evidence.staged_paths,
        "unstagedPathCount": evidence.unstaged_paths,
        "untrackedPathCount": evidence.untracked_paths,
        "conflictedPathCount": evidence.conflicted_paths,
        "sourceRefCount": len(evidence.source_refs),
        "protectedObjectCount": len(evidence.protected_oids),
        "unreachableObjectCount": len(evidence.unreachable_oids),
        "namespace": evidence.namespace,
        "sourceRemote": evidence.source_remote,
        "destinationRemote": evidence.destination_remote,
        "sourceFsckClean": evidence.source_fsck_clean,
        "sourceFsckError": evidence.source_fsck_error,
        "sourceFsckInvocations": evidence.source_fsck_invocations,
        "gitHistoryImported": evidence.git_history_imported,
        "pointerOnlyEvidence": evidence.pointer_only_evidence,
        "finalGroupFsckVerified": evidence.final_group_fsck_verified,
        "fragmentSnapshot": evidence.fragment_snapshot,
        "fragmentDigest": evidence.fragment_digest,
        "fullSnapshot": evidence.full_snapshot,
        "fullSnapshotDigest": evidence.full_snapshot_digest,
        "sourceWorktreeGitDir": evidence.source_worktree_git_dir,
        "sourceCommonGitDir": evidence.source_common_git_dir,
        "componentSnapshots": [
            dataclasses.asdict(snapshot) for snapshot in evidence.component_snapshots
        ],
    }


def load_manifest_representatives(manifest_path: Path) -> dict[str, Path]:
    representatives: dict[str, Path] = {}
    try:
        lines = manifest_path.read_text(
            encoding="utf-8", errors="surrogateescape"
        ).splitlines()
    except OSError as error:
        raise RecoveryError(f"Could not read final representation manifest {manifest_path}") from error
    for line_number, line in enumerate(lines, 1):
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as error:
            raise RecoveryError(
                f"Invalid final representation manifest row {manifest_path}:{line_number}"
            ) from error
        relative = row.get("relativePath") if isinstance(row, dict) else None
        representative = row.get("representative") if isinstance(row, dict) else None
        if not isinstance(relative, str) or not isinstance(representative, str):
            raise RecoveryError(
                f"Incomplete final representation manifest row {manifest_path}:{line_number}"
            )
        if relative in representatives:
            raise RecoveryError(f"Duplicate final manifest path {relative!r}: {manifest_path}")
        representatives[relative] = Path(os.path.abspath(representative))
    return representatives


def component_representation_path(
    component_path: Path,
    *,
    source_candidate: Path,
    logical_source: Path,
    destination: Path,
    snapshots: Sequence[GitComponentSnapshot],
) -> Path:
    candidates: list[tuple[int, Path]] = []
    for snapshot in snapshots:
        snapshot_source = Path(os.path.abspath(snapshot.source_path))
        if source_candidate != logical_source and (
            snapshot_source == logical_source
            or lexical_path_within(snapshot_source, logical_source)
        ):
            snapshot_source = source_candidate / snapshot_source.relative_to(logical_source)
        if component_path == snapshot_source:
            relative = Path()
        elif lexical_path_within(component_path, snapshot_source):
            relative = component_path.relative_to(snapshot_source)
        else:
            continue
        representation = destination / snapshot.snapshot_relative / relative
        candidates.append((len(snapshot_source.parts), representation))
    if not candidates:
        raise RecoveryError(
            f"No byte-exact Git snapshot represents component {component_path}"
        )
    return max(candidates, key=lambda value: value[0])[1]


def build_contract_representation_proof(
    item: PreparedMapping,
    *,
    source_candidate: Path,
    destination: Path,
    report_dir: Path,
    transaction: str,
    bindings: ContractBindings,
) -> Path:
    """Emit the exact proof consumed by repo-consolidation-local-cleanup.py."""
    if not item.mapping.mapping_sha256:
        raise RecoveryError(
            f"Cannot finalize an unbound mapping representation: {item.mapping.source}"
        )
    manifest_path = (
        report_dir
        / "sources"
        / item.source_id
        / "filesystem-manifest-final.jsonl"
    )
    representatives = load_manifest_representatives(manifest_path)
    source_records, source_tree_digest, ephemeral = contract_scan_tree(
        source_candidate,
        exclude_top_git=True,
        excluded_relative_paths=item.mapping.excluded_relative_paths,
    )
    proof_entries: list[dict[str, object]] = []
    source_semantic_to_rep_inode: dict[str, tuple[int, int]] = {}
    rep_inode_to_source_semantic: dict[tuple[int, int], str] = {}
    for source_row in source_records:
        relative = str(source_row["relativePath"])
        representative = representatives.get(relative)
        if relative == RECOVERY_DIR_NAME or relative.startswith(RECOVERY_DIR_NAME + "/"):
            if not item.prior_recovery_snapshot_relative:
                raise RecoveryError(
                    f"Source prior recovery data has no preserved representative: "
                    f"{item.mapping.source}:{relative}"
                )
            suffix = (
                Path()
                if relative == RECOVERY_DIR_NAME
                else Path(relative).relative_to(RECOVERY_DIR_NAME)
            )
            representative = (
                destination / item.prior_recovery_snapshot_relative / suffix
            )
        if representative is None:
            raise RecoveryError(
                f"Final manifest omits source path required by cleanup proof: "
                f"{item.mapping.source}:{relative}"
            )
        if not os.path.lexists(representative):
            raise RecoveryError(f"Source representative disappeared: {representative}")
        representation_fingerprint = contract_stable_fingerprint(representative)
        source_fingerprint = source_row["fingerprint"]
        source_representation_path = (
            source_candidate
            if relative == "."
            else source_candidate / Path(relative)
        )
        variant_root = destination / item.variant_relative
        if (
            representation_fingerprint != source_fingerprint
            and source_fingerprint.get("type") == "directory"
            and representative.is_dir()
            and not representative.is_symlink()
            and (
                representative == variant_root
                or lexical_path_within(representative, variant_root)
            )
        ):
            # Some security provenance xattrs can be cleared after an exact
            # directory variant is populated or promoted. Restore the reviewed
            # source directory metadata on the isolated variant, then require
            # the cleanup-contract fingerprint to match exactly.
            apply_directory_metadata(source_representation_path, representative)
            representation_fingerprint = contract_stable_fingerprint(representative)
        if representation_fingerprint != source_fingerprint:
            raise RecoveryError(
                f"Cleanup-contract fingerprint mismatch: "
                f"{item.mapping.source}:{relative} -> {representative}"
            )
        if source_fingerprint.get("type") == "file":
            semantic = str(source_row.get("hardlinkGroup") or f"unique:{relative}")
            rep_stat = representative.lstat()
            inode = (rep_stat.st_dev, rep_stat.st_ino)
            if source_semantic_to_rep_inode.setdefault(semantic, inode) != inode:
                raise RecoveryError(
                    f"Cleanup-contract hardlink group split: {item.mapping.source}:{relative}"
                )
            if rep_inode_to_source_semantic.setdefault(inode, semantic) != semantic:
                raise RecoveryError(
                    f"Cleanup-contract independent files collapsed: {item.mapping.source}:{relative}"
                )
        proof_entries.append(
            {
                "relativePath": relative,
                "sourceFingerprint": source_fingerprint,
                "sourceHardlinkGroup": source_row.get("hardlinkGroup", ""),
                "representationPath": display_path(representative),
                "representationFingerprint": representation_fingerprint,
            }
        )

    components, git_state = contract_git_component_paths(
        source_candidate,
        logical_source=item.mapping.source,
    )
    proof_components: list[dict[str, object]] = []
    for component in components:
        logical_component = Path(str(component["path"]))
        physical_component = logical_component
        if logical_component == item.mapping.source or lexical_path_within(
            logical_component, item.mapping.source
        ):
            physical_component = source_candidate / logical_component.relative_to(
                item.mapping.source
            )
        representation = component_representation_path(
            physical_component,
            source_candidate=source_candidate,
            logical_source=item.mapping.source,
            destination=destination,
            snapshots=item.git.component_snapshots,
        )
        _records, representation_digest, representation_sockets = contract_scan_tree(
            representation,
            exclude_top_git=False,
        )
        if representation_sockets:
            raise RecoveryError(
                f"Git evidence contains ephemeral fsmonitor sockets: {representation}"
            )
        if representation_digest != component["treeDigest"]:
            raise RecoveryError(
                f"Git component evidence differs from source: {logical_component}"
            )
        proof_components.append(
            {
                **component,
                "representationPath": display_path(representation),
                "representationTreeDigest": representation_digest,
            }
        )

    if git_state == "absent":
        git_evidence_status = "no-git-entry"
    elif git_state == "broken":
        git_evidence_status = "broken-git-evidence-complete"
    elif git_state == "linked":
        git_evidence_status = (
            "history-imported-complete"
            if item.git.git_history_imported
            else "pointer-only-evidence-complete"
        )
    elif git_state == "directory":
        if not item.git.git_history_imported:
            raise RecoveryError(
                "Cleanup contract cannot authorize a directory-form .git whose history "
                f"was not imported: {item.mapping.source}"
            )
        git_evidence_status = "history-imported-complete"
    else:
        raise RecoveryError(f"Unsupported cleanup-contract Git state: {git_state}")

    if git_state == "broken":
        representation_status = "broken-git-evidence-complete"
    elif git_state == "linked" and not item.git.git_history_imported:
        representation_status = "pointer-only-evidence-complete"
    elif item.activation_allowed:
        representation_status = "canonical-and-evidence-complete"
    else:
        representation_status = "evidence-only-complete"

    proof_path = (
        report_dir / "proofs" / "representations" / f"{item.source_id}.json"
    )
    write_fsynced_json(
        proof_path,
        {
            "format": REPRESENTATION_FORMAT,
            "status": representation_status,
            "transaction": transaction,
            "sourceMapSHA256": bindings.source_map_sha256,
            "mappingSHA256": item.mapping.mapping_sha256,
            "source": display_path(item.mapping.source),
            "destination": display_path(destination),
            "sourceTreeDigest": source_tree_digest,
            "ephemeralFsmonitorSockets": ephemeral,
            "entries": proof_entries,
            "gitEvidenceStatus": git_evidence_status,
            "gitComponents": proof_components,
        },
    )
    proof_digest, _proof_stat = stable_file_hash(proof_path)
    item.source_tree_digest = source_tree_digest
    item.source_git_components = components
    item.source_git_components_digest = contract_digest(components)
    item.source_git_state = git_state
    item.representation_proof = display_path(proof_path)
    item.representation_proof_sha256 = proof_digest
    item.representation_status = representation_status
    return proof_path


def finalize_destination_group_receipts(
    prepared: Sequence[PreparedMapping],
    *,
    final_dir: Path,
    partial_dir: Path,
    destination: Path,
    live: LiveRepository,
    transaction: str,
    group_key: str,
    journal_path: Path,
    bindings: ContractBindings,
    strict_fsck_digest: str,
) -> Path:
    """Publish the exact destination-group proof consumed by local cleanup."""
    if os.path.lexists(final_dir) or os.path.lexists(partial_dir):
        raise RecoveryError(f"Destination-group receipt already exists: {final_dir}")
    partial_dir.mkdir(parents=False, exist_ok=False)
    repositories = {item.mapping.repository for item in prepared}
    if len(repositories) != 1:
        raise RecoveryError(f"Destination group has multiple reviewed identities: {repositories}")
    repository = next(iter(repositories))
    owner = destination.parent.name
    account = bindings.github_accounts.get(owner)
    if account is None or account != live.authenticated_login:
        raise RecoveryError(
            f"Destination group account binding mismatch: {owner} -> {account!r} / "
            f"{live.authenticated_login!r}"
        )
    if live.full_name != repository:
        raise RecoveryError(
            f"Destination group live identity differs from source map: {live.full_name} != {repository}"
        )
    if not live.node_id or not live.database_id or not live.database_id.isdigit():
        raise RecoveryError(f"Destination group lacks authoritative GitHub IDs: {repository}")
    reviewed_identity = bindings.repository_identities.get(repository, {})
    for key, expected in reviewed_identity.items():
        actual = live.node_id if key == "nodeID" else live.database_id
        if actual != expected:
            raise RecoveryError(
                f"Destination group reviewed {key} mismatch: {actual} != {expected}"
            )
    account_binding_digest = contract_digest({"owner": owner, "account": account})
    repository_binding_digest = contract_digest(
        {"repository": repository, "reviewedIdentity": reviewed_identity}
    )
    group_receipt = {
        "format": 1,
        "status": "complete",
        "transaction": transaction,
        "sourceMapSHA256": bindings.source_map_sha256,
        "githubAccountsSHA256": bindings.github_accounts_sha256,
        "repositoryIdentitiesSHA256": bindings.repository_identities_sha256,
        "group": group_key,
        "destination": display_path(destination),
        "repository": repository,
        "authenticatedLogin": account,
        "githubAccountBindingSHA256": account_binding_digest,
        "repositoryIdentityBindingSHA256": repository_binding_digest,
        "nodeID": live.node_id,
        "databaseID": live.database_id,
        "strictFsck": {
            "status": "clean",
            "mode": "full-strict",
            "outputSHA256": strict_fsck_digest,
        },
        "sourceIds": [item.source_id for item in prepared],
        "repositoryRole": live.role,
        "parentRepository": live.parent_full_name,
        "remoteRefsDigest": live.remote_refs_digest,
        "promotionJournal": display_path(journal_path),
    }
    receipt_path = partial_dir / "group.json"
    write_fsynced_json(receipt_path, group_receipt)
    fsync_directory(partial_dir)
    guarded_replace(partial_dir, final_dir)
    fsync_directory(final_dir.parent)
    return final_dir / receipt_path.name


def quarantine_failed_receipt_lane(
    candidate: Path,
    *,
    failure_root: Path,
    label: str,
) -> None:
    """Remove a rolled-back receipt from the final lane without deleting it."""
    if not os.path.lexists(candidate):
        return
    failure_root.mkdir(parents=True, exist_ok=True)
    target = failure_root / label
    if os.path.lexists(target):
        raise RecoveryError(f"Failed-receipt quarantine target exists: {target}")
    guarded_replace(candidate, target)
    fsync_directory(candidate.parent)
    fsync_directory(failure_root)


def git_evidence_checkpoint_payload(evidence: GitEvidence) -> dict[str, object]:
    payload = dataclasses.asdict(evidence)
    for field_name in ("protected_oids", "unreachable_oids"):
        payload[field_name] = sorted(payload[field_name])
    return payload


def prepared_mapping_checkpoint_payload(item: PreparedMapping) -> dict[str, object]:
    return {
        "source": display_path(item.mapping.source),
        "mappingSHA256": item.mapping.mapping_sha256,
        "sourceId": item.source_id,
        "tree": dataclasses.asdict(item.tree),
        "git": git_evidence_checkpoint_payload(item.git),
        "activationAllowed": item.activation_allowed,
        "activationReason": item.activation_reason,
        "variantRelative": item.variant_relative,
        "priorRecoverySnapshotRelative": item.prior_recovery_snapshot_relative,
        "priorRecoveryDigest": item.prior_recovery_digest,
        "evidenceOnlyFragment": item.evidence_only_fragment,
        "prePromotionRelative": item.pre_promotion_relative,
        "prePromotionDigest": item.pre_promotion_digest,
        "sourceDevice": item.source_device,
        "sourceInode": item.source_inode,
        "sourceTreeDigest": item.source_tree_digest,
        "sourceGitComponents": item.source_git_components,
        "sourceGitComponentsDigest": item.source_git_components_digest,
        "sourceGitState": item.source_git_state,
        "representationProof": item.representation_proof,
        "representationProofSHA256": item.representation_proof_sha256,
        "representationStatus": item.representation_status,
    }


def destination_group_checkpoint_path(report_dir: Path, destination: Path) -> Path:
    return (
        report_dir
        / "checkpoints"
        / "destination-groups"
        / f"{group_key_for_destination(destination)}.json"
    )


def write_destination_group_checkpoint(
    result: DestinationGroupResult,
    *,
    report_dir: Path,
    transaction: str,
    plan_sha256: str,
    bindings: ContractBindings,
) -> Path:
    if result.live_repository is None or not result.group_receipt_sha256:
        raise RecoveryError(
            f"Cannot checkpoint an incomplete destination group: {result.destination}"
        )
    checkpoint_path = destination_group_checkpoint_path(report_dir, result.destination)
    if os.path.lexists(checkpoint_path):
        raise RecoveryError(f"Destination-group checkpoint already exists: {checkpoint_path}")
    write_fsynced_json(
        checkpoint_path,
        {
            "format": 1,
            "status": "destination-group-final",
            "transaction": transaction,
            "planSha256": plan_sha256,
            "sourceMapSHA256": bindings.source_map_sha256,
            "githubAccountsSHA256": bindings.github_accounts_sha256,
            "repositoryIdentitiesSHA256": bindings.repository_identities_sha256,
            "group": group_key_for_destination(result.destination),
            "destination": display_path(result.destination),
            "liveRepository": dataclasses.asdict(result.live_repository),
            "originalBackup": result.original_backup,
            "groupReceipt": result.group_receipt,
            "groupReceiptSHA256": result.group_receipt_sha256,
            "prepared": [
                prepared_mapping_checkpoint_payload(item) for item in result.prepared
            ],
        },
    )
    return checkpoint_path


def process_destination_group(
    mappings: Sequence[Mapping],
    *,
    destination: Path,
    live: LiveRepository,
    transaction: str,
    transaction_temp: Path,
    report_dir: Path,
    plan_sha256: str,
    fast_mode: bool,
    bindings: ContractBindings,
    owner_account_bindings: dict[str, str],
    repository_identities: dict[str, dict[str, str]],
    runner_drain_proofs: dict[str, RunnerDrainProof],
) -> DestinationGroupResult:
    group_sources = [mapping.source for mapping in mappings]
    revalidate_runtime_roots_for_sources(group_sources, runner_drain_proofs)
    destination_volume = volume_identity(destination.parent)
    stage, physical_existing = prepare_destination_stage(
        mappings,
        destination,
        live,
        transaction_temp,
    )
    revalidate_volume_identity(destination_volume, stage.parent)
    prepared: list[PreparedMapping] = []
    group_key = group_key_for_destination(destination)
    if sum(mapping.conflict_policy == "source-wins-after-preserve" for mapping in mappings) > 1:
        raise RecoveryError(f"Destination group has multiple source-wins mappings: {destination}")
    for mapping in mappings:
        revalidate_runtime_roots_for_sources([mapping.source], runner_drain_proofs)
        source = mapping.source
        source_stat = source.lstat()
        source_id = source_id_for(mapping)
        source_report = report_dir / "sources" / source_id
        evidence_dir = source_report / "git"
        variant_relative = (
            Path(RECOVERY_DIR_NAME)
            / "variants"
            / transaction
            / source_id
            / "files"
        ).as_posix()
        variant_root = stage / variant_relative
        pre_promotion_relative = (
            Path(RECOVERY_DIR_NAME)
            / "pre-promotion"
            / transaction
            / source_id
            / "paths"
        ).as_posix()
        pre_promotion_root = stage / pre_promotion_relative
        print(f"ASSEMBLE | {mapping.kind} | {source} -> {destination}", flush=True)

        prior_snapshot_relative = ""
        prior_digest = ""
        if mapping.kind == EVIDENCE_ONLY_GIT_FRAGMENT_KIND:
            git_evidence, first_stats, _fragment_relative = preserve_evidence_only_git_fragment(
                source,
                stage,
                transaction,
                source_id,
                evidence_dir,
            )
            activation_allowed = False
            activation_reason = "raw-git-fragment-evidence-only"
            evidence_only_fragment = True
        else:
            prior_snapshot, prior_digest = preserve_prior_recovery_tree(
                source,
                stage,
                transaction,
                source_id,
            )
            if prior_snapshot:
                prior_snapshot_relative = Path(prior_snapshot).relative_to(stage).as_posix()
            git_evidence = import_and_verify_git(
                source,
                stage,
                transaction,
                source_id,
                evidence_dir,
                allow_identity_mismatch=mapping.allow_identity_mismatch,
                expected_legacy_repository=mapping.legacy_repository,
            )
            activation_allowed, activation_reason = activation_decision(
                mapping,
                git_evidence,
                live,
            )
            validate_source_wins_runtime(mapping, git_evidence, stage, live)
            if exact_derivation_exception(mapping, live.full_name):
                if not live.is_empty:
                    raise RecoveryError(
                        f"Derived-product exception may seed only a verified empty repository: {live.full_name}"
                    )
                if not git_evidence.source_head:
                    raise RecoveryError(
                        f"Derived product source has no preserved Git HEAD: {source}"
                    )
                run_command(
                    [
                        "git",
                        "-C",
                        stage,
                        "update-ref",
                        f"refs/heads/{live.default_branch}",
                        git_evidence.source_head,
                    ]
                )
                run_command(
                    [
                        "git",
                        "-C",
                        stage,
                        "symbolic-ref",
                        "HEAD",
                        f"refs/heads/{live.default_branch}",
                    ]
                )
            if fast_mode and activation_allowed:
                add_missing_paths(
                    source,
                    stage,
                    mapping.excluded_relative_paths,
                    mapping.recovery_only_paths,
                )
                fast_audit = fast_checksum_audit(
                    source,
                    stage,
                    source_report / "fast-mode-planning-audit.txt",
                    mapping.excluded_relative_paths,
                    mapping.recovery_only_paths,
                )
                write_json(source_report / "fast-mode-plan.json", dataclasses.asdict(fast_audit))
            first_stats = tree_merge_or_verify(
                source,
                stage,
                variant_root,
                source_report / "conflicts-assembly.jsonl",
                merge=True,
                excluded_relative_paths=mapping.excluded_relative_paths,
                activate_source_only=activation_allowed,
                manifest_path=source_report / "filesystem-manifest-assembly.jsonl",
                conflict_policy=mapping.conflict_policy,
                recovery_only_paths=mapping.recovery_only_paths,
                pre_promotion_root=pre_promotion_root,
            )
            if mapping.conflict_policy == "source-wins-after-preserve":
                prior_head = git_evidence.destination_head
                if prior_head:
                    prior_ref = (
                        f"refs/csa-iem/pre-promotion/{safe_ref_component(transaction)}/"
                        f"{safe_ref_component(source_id)}/canonical-HEAD"
                    )
                    run_command(
                        ["git", "-C", stage, "update-ref", "--no-deref", prior_ref, prior_head, ""]
                    )
                branch_name = git_evidence.source_branch or live.default_branch
                run_command(
                    [
                        "git",
                        "-C",
                        stage,
                        "update-ref",
                        f"refs/heads/{branch_name}",
                        git_evidence.source_head,
                    ]
                )
                run_command(
                    [
                        "git",
                        "-C",
                        stage,
                        "symbolic-ref",
                        "HEAD",
                        f"refs/heads/{branch_name}",
                    ]
                )
            evidence_only_fragment = False

        pre_promotion_digest = ""
        if pre_promotion_root.is_dir():
            pre_promotion_digest = count_source_tree(
                pre_promotion_root,
                excluded_top_level=set(),
                include_root=True,
            ).root_digest

        prepared_mapping = PreparedMapping(
            mapping=mapping,
            source_id=source_id,
            tree=first_stats,
            git=git_evidence,
            activation_allowed=activation_allowed,
            activation_reason=activation_reason,
            variant_relative=variant_relative,
            prior_recovery_snapshot_relative=prior_snapshot_relative,
            prior_recovery_digest=prior_digest,
            evidence_only_fragment=evidence_only_fragment,
            pre_promotion_relative=pre_promotion_relative if pre_promotion_digest else "",
            pre_promotion_digest=pre_promotion_digest,
            source_device=source_stat.st_dev,
            source_inode=source_stat.st_ino,
        )
        prepared.append(prepared_mapping)
        pending = {
            "format": 3,
            "transaction": transaction,
            "planSha256": plan_sha256,
            "status": "destination-group-pending",
            "group": group_key,
            "source": display_path(source),
            "destination": display_path(destination),
            "sourceDevice": source_stat.st_dev,
            "sourceInode": source_stat.st_ino,
            "sourceTreeDigest": first_stats.root_digest,
            "sourceManifestDigest": first_stats.manifest_digest,
            "activationAllowed": activation_allowed,
            "activationReason": activation_reason,
            "deletionEligible": False,
        }
        write_fsynced_json(report_dir / "pending-receipts" / f"{source_id}.json", pending)

    # Mandatory final source/component/manifest read. Fast mode only planned
    # the assembly; it never substitutes for this full proof.
    revalidate_runtime_roots_for_sources(group_sources, runner_drain_proofs)
    for item in prepared:
        revalidate_runtime_roots_for_sources(
            [item.mapping.source], runner_drain_proofs
        )
        source = item.mapping.source
        source_report = report_dir / "sources" / item.source_id
        if item.evidence_only_fragment:
            snapshot = stage / item.git.component_snapshots[0].snapshot_relative
            second_stats = write_exact_snapshot_manifest(
                source,
                snapshot,
                source_report / "filesystem-manifest-pre-promotion.jsonl",
                excluded_top_level=set(),
            )
        else:
            second_stats = tree_merge_or_verify(
                source,
                stage,
                stage / item.variant_relative,
                source_report / "conflicts-pre-promotion.jsonl",
                merge=False,
                excluded_relative_paths=item.mapping.excluded_relative_paths,
                activate_source_only=item.activation_allowed,
                manifest_path=source_report / "filesystem-manifest-pre-promotion.jsonl",
                conflict_policy=item.mapping.conflict_policy,
                recovery_only_paths=item.mapping.recovery_only_paths,
                pre_promotion_root=stage / item.pre_promotion_relative
                if item.pre_promotion_relative
                else stage / RECOVERY_DIR_NAME / "unused-pre-promotion-proof",
            )
            if item.prior_recovery_snapshot_relative:
                digest = verify_exact_path_snapshot(
                    source / RECOVERY_DIR_NAME,
                    stage / item.prior_recovery_snapshot_relative,
                )
                if digest != item.prior_recovery_digest:
                    raise RecoveryError(f"Prior recovery evidence changed: {source}")
        if second_stats.root_digest != item.tree.root_digest:
            raise RecoveryError(f"Source changed during destination assembly: {source}")
        verify_source_git_unchanged(source, item.git, stage)
        verify_git_evidence(stage, item.git)
        if item.pre_promotion_relative:
            digest = count_source_tree(
                stage / item.pre_promotion_relative,
                excluded_top_level=set(),
                include_root=True,
            ).root_digest
            if digest != item.pre_promotion_digest:
                raise RecoveryError(f"Pre-promotion evidence changed: {source}")

    rollback_root = transaction_temp / "canonical-rollback" / live.full_name.rsplit("/", 1)[0]
    rollback_root.mkdir(parents=True, exist_ok=True)
    backup: Path | None = None
    if physical_existing is not None:
        backup = rollback_root / physical_existing.name
        if os.path.lexists(backup):
            raise RecoveryError(f"Canonical rollback target already exists: {backup}")
    failed_stage = transaction_temp / "failed-promotions" / live.full_name
    physical_source_ids: set[str] = set()
    if physical_existing is not None:
        physical_source_ids = {
            item.source_id
            for item in prepared
            if same_inode(item.mapping.source, physical_existing)
        }
    final_parent = report_dir / "receipts" / "destination-groups"
    final_parent.mkdir(parents=True, exist_ok=True)
    final_dir = final_parent / group_key
    partial_dir = final_parent / f".{group_key}.partial"
    if os.path.lexists(final_dir) or os.path.lexists(partial_dir):
        raise RecoveryError(f"Destination-group receipt already exists: {final_dir}")
    failed_receipt_root = report_dir / "failed-receipts" / "destination-groups" / group_key
    journal_path = report_dir / "destination-journals" / f"{group_key}.json"
    journal: dict[str, object] = {
        "format": 1,
        "transaction": transaction,
        "group": group_key,
        "destination": display_path(destination),
        "physicalOriginal": display_path(physical_existing) if physical_existing else "",
        "staging": display_path(stage),
        "rollback": display_path(backup) if backup else "",
        "status": "promotion-pending",
        "volumeIdentity": dataclasses.asdict(destination_volume),
    }
    write_fsynced_json(journal_path, journal)
    promoted = False
    group_receipt_path: Path | None = None
    try:
        revalidate_volume_identity(destination_volume, destination.parent)
        revalidate_volume_identity(destination_volume, stage.parent)
        if physical_existing is not None and backup is not None:
            guarded_replace(physical_existing, backup)
            fsync_directory(physical_existing.parent)
            journal["status"] = "original-moved-to-rollback"
            write_fsynced_json(journal_path, journal)
        destination.parent.mkdir(parents=True, exist_ok=True)
        guarded_replace(stage, destination)
        fsync_directory(destination.parent)
        promoted = True
        physical_promoted = existing_physical_path(destination)
        if physical_promoted is None or physical_promoted.name != destination.name:
            raise RecoveryError(
                f"Canonical physical case verification failed: wanted {destination.name}, "
                f"found {physical_promoted.name if physical_promoted else 'missing'}"
            )
        journal["status"] = "promoted-final-proof-pending"
        journal["promotedDevice"] = physical_promoted.lstat().st_dev
        journal["promotedInode"] = physical_promoted.lstat().st_ino
        write_fsynced_json(journal_path, journal)

        for item in prepared:
            source_candidate = item.mapping.source
            if item.source_id in physical_source_ids:
                if backup is None or not os.path.lexists(backup):
                    raise RecoveryError(
                        f"Case-only canonical source rollback copy is unavailable: {item.mapping.source}"
                    )
                source_candidate = backup
            source_report = report_dir / "sources" / item.source_id
            if item.evidence_only_fragment:
                snapshot = destination / item.git.component_snapshots[0].snapshot_relative
                final_stats = write_exact_snapshot_manifest(
                    source_candidate,
                    snapshot,
                    source_report / "filesystem-manifest-final.jsonl",
                    excluded_top_level=set(),
                )
            else:
                final_stats = tree_merge_or_verify(
                    source_candidate,
                    destination,
                    destination / item.variant_relative,
                    source_report / "conflicts-final.jsonl",
                    merge=False,
                    excluded_relative_paths=item.mapping.excluded_relative_paths,
                    activate_source_only=item.activation_allowed,
                    manifest_path=source_report / "filesystem-manifest-final.jsonl",
                    conflict_policy=item.mapping.conflict_policy,
                    recovery_only_paths=item.mapping.recovery_only_paths,
                    pre_promotion_root=destination / item.pre_promotion_relative
                    if item.pre_promotion_relative
                    else destination / RECOVERY_DIR_NAME / "unused-pre-promotion-proof",
                )
            if final_stats.root_digest != item.tree.root_digest:
                raise RecoveryError(
                    f"Final canonical manifest lost source representation: {item.mapping.source}"
                )
            verify_source_git_unchanged(source_candidate, item.git, destination)
            verify_git_evidence(destination, item.git)
            if item.pre_promotion_relative:
                digest = count_source_tree(
                    destination / item.pre_promotion_relative,
                    excluded_top_level=set(),
                    include_root=True,
                ).root_digest
                if digest != item.pre_promotion_digest:
                    raise RecoveryError(
                        f"Promoted pre-promotion evidence changed: {item.mapping.source}"
                    )

            if item.mapping.mapping_sha256:
                build_contract_representation_proof(
                    item,
                    source_candidate=source_candidate,
                    destination=destination,
                    report_dir=report_dir,
                    transaction=transaction,
                    bindings=bindings,
                )

        strict_fsck_digest = verify_canonical_git_independence(destination)
        for item in prepared:
            item.git.final_group_fsck_verified = True
        if live.remote_head:
            remote_ref = git_output(
                destination,
                ["rev-parse", f"refs/remotes/origin/{live.default_branch}"],
            )
            if remote_ref.lower() != live.remote_head:
                raise RecoveryError(
                    f"Promoted canonical remote HEAD changed: {remote_ref} != {live.remote_head}"
                )
        journal["status"] = "destination-proof-final-receipt-pending"
        journal["finalStrictFsckCount"] = 1
        write_fsynced_json(journal_path, journal)
        group_receipt_path = finalize_destination_group_receipts(
            prepared,
            final_dir=final_dir,
            partial_dir=partial_dir,
            destination=destination,
            live=live,
            transaction=transaction,
            group_key=group_key,
            journal_path=journal_path,
            bindings=bindings,
            strict_fsck_digest=strict_fsck_digest,
        )
        journal["status"] = "destination-group-final"
        journal["groupReceipt"] = display_path(group_receipt_path)
        write_fsynced_json(journal_path, journal)
    except Exception:
        rollback_errors: list[str] = []
        for candidate, label in ((final_dir, "final"), (partial_dir, "partial")):
            try:
                quarantine_failed_receipt_lane(
                    candidate,
                    failure_root=failed_receipt_root,
                    label=label,
                )
            except Exception as error:
                rollback_errors.append(f"receipt quarantine failed for {candidate}: {error}")
        try:
            if promoted and os.path.lexists(destination):
                failed_stage.parent.mkdir(parents=True, exist_ok=True)
                if os.path.lexists(failed_stage):
                    raise RecoveryError(f"Failed-promotion retention target exists: {failed_stage}")
                guarded_replace(destination, failed_stage)
                fsync_directory(destination.parent)
        except Exception as error:
            rollback_errors.append(f"promoted-stage retention failed: {error}")
        try:
            if backup is not None and os.path.lexists(backup):
                if physical_existing is None:
                    raise RecoveryError("Rollback source path is unavailable")
                guarded_replace(backup, physical_existing)
                fsync_directory(physical_existing.parent)
        except Exception as error:
            rollback_errors.append(f"canonical rollback failed: {error}")
        journal["status"] = "promotion-rolled-back" if not rollback_errors else "rollback-failed"
        journal["rollbackErrors"] = rollback_errors
        write_fsynced_json(journal_path, journal)
        if rollback_errors:
            raise RecoveryError("; ".join(rollback_errors))
        raise
    if group_receipt_path is None:
        raise RecoveryError(f"Destination-group receipt did not finalize: {destination}")
    group_receipt_sha256, _group_receipt_stat = stable_file_hash(group_receipt_path)
    result = DestinationGroupResult(
        destination=destination,
        prepared=prepared,
        status="completed",
        detail="Destination group assembled, atomically promoted, and finalized.",
        original_backup=display_path(backup) if backup else "",
        group_receipt=display_path(group_receipt_path),
        group_receipt_sha256=group_receipt_sha256,
        live_repository=live,
    )
    write_destination_group_checkpoint(
        result,
        report_dir=report_dir,
        transaction=transaction,
        plan_sha256=plan_sha256,
        bindings=bindings,
    )
    return result


def require_checkpoint_object(value: object, label: str) -> dict[str, object]:
    if not isinstance(value, dict):
        raise RecoveryError(f"Resume checkpoint {label} is not an object")
    return value


def load_checkpoint_tree(value: object) -> TreeStats:
    payload = require_checkpoint_object(value, "tree")
    normalized = dict(payload)
    for field_name in ("verified_metadata_fields", "record_only_metadata_fields"):
        field_value = normalized.get(field_name)
        if not isinstance(field_value, list) or not all(
            isinstance(item, str) for item in field_value
        ):
            raise RecoveryError(f"Resume checkpoint tree has invalid {field_name}")
        normalized[field_name] = tuple(field_value)
    try:
        return TreeStats(**normalized)
    except (TypeError, ValueError) as error:
        raise RecoveryError(f"Resume checkpoint tree is invalid: {error}") from error


def load_checkpoint_git(value: object) -> GitEvidence:
    payload = require_checkpoint_object(value, "git")
    normalized = dict(payload)
    for field_name in ("protected_oids", "unreachable_oids"):
        field_value = normalized.get(field_name)
        if not isinstance(field_value, list) or not all(
            isinstance(item, str) for item in field_value
        ):
            raise RecoveryError(f"Resume checkpoint Git evidence has invalid {field_name}")
        normalized[field_name] = set(field_value)
    snapshots = normalized.get("component_snapshots")
    if not isinstance(snapshots, list):
        raise RecoveryError("Resume checkpoint Git component snapshots are invalid")
    try:
        normalized["component_snapshots"] = [
            GitComponentSnapshot(**require_checkpoint_object(item, "Git component"))
            for item in snapshots
        ]
        return GitEvidence(**normalized)
    except (TypeError, ValueError) as error:
        raise RecoveryError(f"Resume checkpoint Git evidence is invalid: {error}") from error


def load_checkpoint_prepared_mapping(
    value: object,
    *,
    mapping_by_source: dict[str, Mapping],
) -> PreparedMapping:
    payload = require_checkpoint_object(value, "prepared mapping")
    source = payload.get("source")
    mapping_digest = payload.get("mappingSHA256")
    if not isinstance(source, str) or source not in mapping_by_source:
        raise RecoveryError(f"Resume checkpoint source is outside the current plan: {source!r}")
    mapping = mapping_by_source[source]
    if not isinstance(mapping_digest, str) or mapping_digest != mapping.mapping_sha256:
        raise RecoveryError(f"Resume checkpoint mapping digest changed: {source}")

    def text_field(name: str) -> str:
        value_at_name = payload.get(name)
        if not isinstance(value_at_name, str):
            raise RecoveryError(f"Resume checkpoint field {name} is invalid: {source}")
        return value_at_name

    def bool_field(name: str) -> bool:
        value_at_name = payload.get(name)
        if not isinstance(value_at_name, bool):
            raise RecoveryError(f"Resume checkpoint field {name} is invalid: {source}")
        return value_at_name

    def int_field(name: str) -> int:
        value_at_name = payload.get(name)
        if not isinstance(value_at_name, int) or isinstance(value_at_name, bool):
            raise RecoveryError(f"Resume checkpoint field {name} is invalid: {source}")
        return value_at_name

    source_components = payload.get("sourceGitComponents")
    if not isinstance(source_components, list) or not all(
        isinstance(item, dict) for item in source_components
    ):
        raise RecoveryError(f"Resume checkpoint Git components are invalid: {source}")
    item = PreparedMapping(
        mapping=mapping,
        source_id=text_field("sourceId"),
        tree=load_checkpoint_tree(payload.get("tree")),
        git=load_checkpoint_git(payload.get("git")),
        activation_allowed=bool_field("activationAllowed"),
        activation_reason=text_field("activationReason"),
        variant_relative=text_field("variantRelative"),
        prior_recovery_snapshot_relative=text_field("priorRecoverySnapshotRelative"),
        prior_recovery_digest=text_field("priorRecoveryDigest"),
        evidence_only_fragment=bool_field("evidenceOnlyFragment"),
        pre_promotion_relative=text_field("prePromotionRelative"),
        pre_promotion_digest=text_field("prePromotionDigest"),
        source_device=int_field("sourceDevice"),
        source_inode=int_field("sourceInode"),
        source_tree_digest=text_field("sourceTreeDigest"),
        source_git_components=list(source_components),
        source_git_components_digest=text_field("sourceGitComponentsDigest"),
        source_git_state=text_field("sourceGitState"),
        representation_proof=text_field("representationProof"),
        representation_proof_sha256=text_field("representationProofSHA256"),
        representation_status=text_field("representationStatus"),
    )
    if item.source_id != source_id_for(mapping):
        raise RecoveryError(f"Resume checkpoint source ID changed: {source}")
    return item


def checkpoint_source_candidate(item: PreparedMapping, original_backup: Path | None) -> Path:
    if original_backup is not None and os.path.lexists(original_backup):
        backup_stat = original_backup.lstat()
        if (backup_stat.st_dev, backup_stat.st_ino) == (
            item.source_device,
            item.source_inode,
        ):
            return original_backup
    if not os.path.lexists(item.mapping.source):
        raise RecoveryError(f"Resume source is unavailable: {item.mapping.source}")
    source_stat = item.mapping.source.lstat()
    if (source_stat.st_dev, source_stat.st_ino) != (
        item.source_device,
        item.source_inode,
    ):
        raise RecoveryError(f"Resume source identity changed: {item.mapping.source}")
    return item.mapping.source


def resume_destination_group(
    mappings: Sequence[Mapping],
    *,
    destination: Path,
    live: LiveRepository,
    transaction: str,
    report_dir: Path,
    plan_sha256: str,
    bindings: ContractBindings,
    runner_drain_proofs: dict[str, RunnerDrainProof],
) -> DestinationGroupResult | None:
    """Resume only a finalized group after re-proving every destructive gate.

    Partial staging is intentionally not resumed.  A checkpoint becomes usable
    only after canonical promotion, full representation proof, strict Git fsck,
    and final receipt publication have all completed.
    """
    checkpoint_path = destination_group_checkpoint_path(report_dir, destination)
    if not checkpoint_path.is_file():
        return None
    try:
        payload = json.loads(checkpoint_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise RecoveryError(f"Could not read resume checkpoint {checkpoint_path}: {error}") from error
    checkpoint = require_checkpoint_object(payload, "root")
    expected_scalars = {
        "format": 1,
        "status": "destination-group-final",
        "transaction": transaction,
        "planSha256": plan_sha256,
        "sourceMapSHA256": bindings.source_map_sha256,
        "githubAccountsSHA256": bindings.github_accounts_sha256,
        "repositoryIdentitiesSHA256": bindings.repository_identities_sha256,
        "group": group_key_for_destination(destination),
        "destination": display_path(destination),
    }
    for field_name, expected in expected_scalars.items():
        if checkpoint.get(field_name) != expected:
            raise RecoveryError(
                f"Resume checkpoint {field_name} changed for {destination}"
            )
    if checkpoint.get("liveRepository") != dataclasses.asdict(live):
        raise RecoveryError(f"Resume checkpoint live GitHub identity changed: {destination}")
    prepared_payload = checkpoint.get("prepared")
    if not isinstance(prepared_payload, list):
        raise RecoveryError(f"Resume checkpoint prepared set is invalid: {destination}")
    mapping_by_source = {display_path(mapping.source): mapping for mapping in mappings}
    if len(mapping_by_source) != len(mappings):
        raise RecoveryError(f"Current destination group repeats a source: {destination}")
    prepared = [
        load_checkpoint_prepared_mapping(item, mapping_by_source=mapping_by_source)
        for item in prepared_payload
    ]
    if {display_path(item.mapping.source) for item in prepared} != set(mapping_by_source):
        raise RecoveryError(f"Resume checkpoint source set changed: {destination}")

    original_backup_text = checkpoint.get("originalBackup")
    if not isinstance(original_backup_text, str):
        raise RecoveryError(f"Resume checkpoint backup path is invalid: {destination}")
    original_backup = Path(original_backup_text) if original_backup_text else None
    revalidate_runtime_roots_for_sources(
        [item.mapping.source for item in prepared], runner_drain_proofs
    )
    for item in prepared:
        source_candidate = checkpoint_source_candidate(item, original_backup)
        source_report = report_dir / "sources" / item.source_id
        resume_report = report_dir / "resume-checks" / item.source_id
        if item.evidence_only_fragment:
            if not item.git.component_snapshots:
                raise RecoveryError(f"Resume Git fragment snapshot is missing: {item.mapping.source}")
            stats_result = write_exact_snapshot_manifest(
                source_candidate,
                destination / item.git.component_snapshots[0].snapshot_relative,
                resume_report / "filesystem-manifest.jsonl",
                excluded_top_level=set(),
            )
        else:
            stats_result = tree_merge_or_verify(
                source_candidate,
                destination,
                destination / item.variant_relative,
                resume_report / "conflicts.jsonl",
                merge=False,
                excluded_relative_paths=item.mapping.excluded_relative_paths,
                activate_source_only=item.activation_allowed,
                manifest_path=resume_report / "filesystem-manifest.jsonl",
                conflict_policy=item.mapping.conflict_policy,
                recovery_only_paths=item.mapping.recovery_only_paths,
                pre_promotion_root=(
                    destination / item.pre_promotion_relative
                    if item.pre_promotion_relative
                    else destination / RECOVERY_DIR_NAME / "unused-pre-promotion-proof"
                ),
            )
        if stats_result.root_digest != item.tree.root_digest:
            raise RecoveryError(f"Resume source representation changed: {item.mapping.source}")
        verify_source_git_unchanged(source_candidate, item.git, destination)
        verify_git_evidence(destination, item.git)
        proof_path = Path(item.representation_proof)
        if not proof_path.is_file() or stable_file_hash(proof_path)[0] != item.representation_proof_sha256:
            raise RecoveryError(f"Resume representation proof changed: {item.mapping.source}")
        if item.pre_promotion_relative:
            digest = count_source_tree(
                destination / item.pre_promotion_relative,
                excluded_top_level=set(),
                include_root=True,
            ).root_digest
            if digest != item.pre_promotion_digest:
                raise RecoveryError(f"Resume pre-promotion evidence changed: {item.mapping.source}")

    strict_fsck_digest = verify_canonical_git_independence(destination)
    if live.remote_head:
        remote_ref = git_output(
            destination,
            ["rev-parse", f"refs/remotes/origin/{live.default_branch}"],
        )
        if remote_ref.lower() != live.remote_head:
            raise RecoveryError(f"Resume canonical remote HEAD changed: {destination}")
    group_receipt_text = checkpoint.get("groupReceipt")
    group_receipt_sha256 = checkpoint.get("groupReceiptSHA256")
    if not isinstance(group_receipt_text, str) or not isinstance(group_receipt_sha256, str):
        raise RecoveryError(f"Resume destination receipt binding is invalid: {destination}")
    group_receipt = Path(group_receipt_text)
    expected_receipt = (
        report_dir
        / "receipts"
        / "destination-groups"
        / group_key_for_destination(destination)
        / "group.json"
    )
    if group_receipt != expected_receipt or not group_receipt.is_file():
        raise RecoveryError(f"Resume destination receipt path changed: {destination}")
    if stable_file_hash(group_receipt)[0] != group_receipt_sha256:
        raise RecoveryError(f"Resume destination receipt changed: {destination}")
    receipt_payload = require_checkpoint_object(
        json.loads(group_receipt.read_text(encoding="utf-8")),
        "destination receipt",
    )
    if (
        receipt_payload.get("transaction") != transaction
        or receipt_payload.get("sourceMapSHA256") != bindings.source_map_sha256
        or receipt_payload.get("destination") != display_path(destination)
        or receipt_payload.get("repository") != live.full_name
        or receipt_payload.get("sourceIds") != [item.source_id for item in prepared]
        or receipt_payload.get("strictFsck", {}).get("outputSHA256") != strict_fsck_digest
    ):
        raise RecoveryError(f"Resume destination receipt contract changed: {destination}")
    return DestinationGroupResult(
        destination=destination,
        prepared=prepared,
        status="completed-resumed-and-reverified",
        detail="Finalized destination group resumed after full checkpoint revalidation.",
        original_backup=original_backup_text,
        group_receipt=group_receipt_text,
        group_receipt_sha256=group_receipt_sha256,
        live_repository=live,
    )


def copy_and_verify_stage1_evidence(stage1_root: Path, evidence_root: Path) -> None:
    if not stage1_root.is_dir():
        return
    if evidence_root.exists() or evidence_root.is_symlink():
        raise RecoveryError(f"Stage 1 evidence destination already exists: {evidence_root}")
    digest = copy_exact_verified(stage1_root, evidence_root, evidence_root.parent)
    write_json(
        evidence_root.parent / "stage1-root-evidence.json",
        {
            "source": display_path(stage1_root),
            "snapshot": display_path(evidence_root),
            "digest": digest,
            "contentVerification": "full-checksum-and-metadata",
        },
    )


def cleanup_stage1_root(stage1_root: Path, managed_root: Path, report_dir: Path) -> None:
    if not stage1_root.is_dir():
        return
    remaining_projects = [
        path for path in stage1_root.iterdir() if path.name != "_temp" and path.is_dir() and not path.is_symlink()
    ]
    completed = stage1_root / "_temp" / "Stage2-Completed"
    if completed.is_dir():
        for transaction in completed.iterdir():
            if transaction.is_dir():
                remaining_projects.extend(path for path in transaction.iterdir() if path.is_dir())
    if remaining_projects:
        joined = ", ".join(display_path(path) for path in remaining_projects[:20])
        raise RecoveryError(f"Stage 1 still contains project folders; root retained: {joined}")

    evidence_root = report_dir / "stage1-root-evidence"
    copy_and_verify_stage1_evidence(stage1_root, evidence_root)
    cleanup_quarantine_root = managed_root / "_temp" / "Repo-Consolidation" / report_dir.name / "stage1-root"
    cleanup_quarantine_root.parent.mkdir(parents=True, exist_ok=True)
    if cleanup_quarantine_root.exists():
        raise RecoveryError(f"Stage 1 cleanup quarantine already exists: {cleanup_quarantine_root}")
    if stage1_root.stat().st_dev != cleanup_quarantine_root.parent.stat().st_dev:
        raise RecoveryError("Stage 1 root and cleanup quarantine are not on the same filesystem.")
    guarded_replace(stage1_root, cleanup_quarantine_root)
    try:
        verify_exact_path_snapshot(cleanup_quarantine_root, evidence_root)
        guarded_rmtree(cleanup_quarantine_root)
    except Exception:
        if not stage1_root.exists() and cleanup_quarantine_root.exists():
            guarded_replace(cleanup_quarantine_root, stage1_root)
        raise


def cleanup_compatibility_links(compat_root: Path, stage1_root: Path, report_dir: Path) -> int:
    if not compat_root.is_dir():
        return 0
    removed: list[dict[str, str]] = []
    for path in sorted(compat_root.iterdir(), key=lambda item: os.fsencode(item.name)):
        if not path.is_symlink():
            continue
        target_text = os.readlink(path)
        target = Path(target_text)
        if not target.is_absolute():
            target = path.parent / target
        normalized_target = Path(os.path.abspath(target))
        if not path_within(normalized_target, stage1_root):
            continue
        removed.append({"path": display_path(path), "target": target_text})
        guarded_unlink(path)
    write_json(report_dir / "removed-compatibility-links.json", removed)
    return len(removed)


def retire_compatibility_project_roots(
    compat_root: Path,
    managed_root: Path,
    transaction: str,
    report_dir: Path,
    mappings: Sequence[Mapping],
) -> list[dict[str, object]]:
    """Move fully mapped compatibility-root projects into managed _temp."""
    if not compat_root.is_dir() or compat_root.is_symlink():
        raise RecoveryError(f"Compatibility root is not a real directory: {compat_root}")
    compat_mappings = [
        mapping
        for mapping in mappings
        if mapping.kind == "explicit-compat-source" and path_within(mapping.source, compat_root)
    ]
    mapped_top_roots: set[Path] = set()
    for mapping in compat_mappings:
        relative = mapping.source.relative_to(compat_root)
        if not relative.parts or relative.parts[0] == "_temp":
            raise RecoveryError(f"Invalid compatibility project source: {mapping.source}")
        mapped_top_roots.add(compat_root / relative.parts[0])

    actual_directories = {
        path
        for path in compat_root.iterdir()
        if path.name != "_temp" and path.is_dir() and not path.is_symlink()
    }
    unaccounted = sorted(
        display_path(path) for path in actual_directories - mapped_top_roots
    )
    missing = sorted(
        display_path(path) for path in mapped_top_roots - actual_directories
    )
    if unaccounted or missing:
        raise RecoveryError(
            f"Compatibility project-root accounting failed; unaccounted={unaccounted[:20]}, "
            f"missing={missing[:20]}"
        )

    unexpected_files = [
        path
        for path in compat_root.iterdir()
        if path.name not in {"_temp", ".DS_Store"}
        and path not in actual_directories
    ]
    if unexpected_files:
        raise RecoveryError(
            "Compatibility root contains unaccounted non-project entries: "
            + ", ".join(display_path(path) for path in unexpected_files[:20])
        )

    target_root = managed_root / "_temp" / "Compatibility-Projects" / transaction
    target_root.mkdir(parents=True, exist_ok=True)
    for source in mapped_top_roots:
        target = target_root / source.name
        if target.exists() or target.is_symlink():
            raise RecoveryError(f"Compatibility retirement target already exists: {target}")
        if source.stat().st_dev != target_root.stat().st_dev:
            raise RecoveryError(f"Compatibility source is not on managed _temp filesystem: {source}")
    finder_metadata = compat_root / ".DS_Store"
    metadata_target = target_root / "root-metadata" / ".DS_Store"
    if finder_metadata.is_file() and not finder_metadata.is_symlink() and (
        metadata_target.exists() or metadata_target.is_symlink()
    ):
        raise RecoveryError(f"Compatibility metadata target already exists: {metadata_target}")

    records: list[dict[str, object]] = []
    journal_path = report_dir / "compatibility-project-retirement.json"
    for source in sorted(mapped_top_roots, key=lambda item: os.fsencode(item.name)):
        target = target_root / source.name
        source_stat = source.stat()
        record: dict[str, object] = {
            "source": display_path(source),
            "destination": display_path(target),
            "device": source_stat.st_dev,
            "inode": source_stat.st_ino,
            "status": "retire-pending",
        }
        records.append(record)
        write_json(journal_path, {"transaction": transaction, "roots": records})
        guarded_replace(source, target)
        target_stat = target.stat()
        if (target_stat.st_dev, target_stat.st_ino) != (source_stat.st_dev, source_stat.st_ino):
            raise RecoveryError(f"Compatibility root rename identity changed: {source} -> {target}")
        record["status"] = "retired-to-managed-temp"
        write_json(journal_path, {"transaction": transaction, "roots": records})

    if finder_metadata.is_file() and not finder_metadata.is_symlink():
        metadata_root = target_root / "root-metadata"
        metadata_root.mkdir(parents=True, exist_ok=True)
        guarded_replace(finder_metadata, metadata_target)
    remaining = [path for path in compat_root.iterdir() if path.name != "_temp"]
    if remaining:
        raise RecoveryError(
            "Compatibility root did not finish with only _temp: "
            + ", ".join(display_path(path) for path in remaining[:20])
        )
    return records


def retire_managed_stage_roots(
    managed_root: Path,
    transaction: str,
    report_dir: Path,
    mappings: Sequence[Mapping],
) -> list[dict[str, object]]:
    """Move fully-accounted whole-root staging trees into managed _temp."""
    mapped_sources = {
        canonical(mapping.source)
        for mapping in mappings
        if mapping.kind == "managed-root-stage-copy"
    }
    destination_root = managed_root / "_temp" / "Managed-Root-Stages" / transaction
    destination_root.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    journal_path = report_dir / "managed-root-stage-retirement.json"

    for staged_root in sorted(managed_root.glob("*.csa-iem-stage-*")):
        if not staged_root.is_dir() or staged_root.is_symlink():
            raise RecoveryError(f"Managed staging artifact is not a real directory: {staged_root}")
        repos_root = staged_root / "Repos"
        projects = [
            project
            for owner_root in repos_root.iterdir()
            if owner_root.is_dir() and not owner_root.is_symlink()
            for project in owner_root.iterdir()
            if project.is_dir() and not project.is_symlink()
        ] if repos_root.is_dir() and not repos_root.is_symlink() else []
        unaccounted = sorted(
            display_path(path) for path in projects if canonical(path) not in mapped_sources
        )
        if unaccounted:
            raise RecoveryError(
                f"Managed staging root contains unaccounted project sources: {unaccounted[:20]}"
            )
        target = destination_root / staged_root.name
        if target.exists() or target.is_symlink():
            raise RecoveryError(f"Managed staging retirement target already exists: {target}")
        source_stat = staged_root.stat()
        if source_stat.st_dev != destination_root.stat().st_dev:
            raise RecoveryError(f"Managed staging root is not on the _temp filesystem: {staged_root}")
        record: dict[str, object] = {
            "source": display_path(staged_root),
            "destination": display_path(target),
            "projectCount": len(projects),
            "device": source_stat.st_dev,
            "inode": source_stat.st_ino,
            "status": "retire-pending",
        }
        records.append(record)
        write_json(journal_path, {"transaction": transaction, "roots": records})
        guarded_replace(staged_root, target)
        target_stat = target.stat()
        if (target_stat.st_dev, target_stat.st_ino) != (source_stat.st_dev, source_stat.st_ino):
            raise RecoveryError(f"Managed staging root rename identity changed: {staged_root} -> {target}")
        record["status"] = "retired-to-managed-temp"
        write_json(journal_path, {"transaction": transaction, "roots": records})
    return records


def retire_runtime_repo_mirrors(
    managed_root: Path,
    transaction: str,
    report_dir: Path,
    mappings: Sequence[Mapping],
) -> dict[str, object] | None:
    source_root = managed_root / "Runtime" / "Repos"
    if not source_root.is_dir() or source_root.is_symlink():
        return None
    owner_roots = [
        path for path in source_root.iterdir() if path.is_dir() and not path.is_symlink()
    ]
    projects = [
        project
        for owner_root in owner_roots
        for project in owner_root.iterdir()
        if project.is_dir() and not project.is_symlink()
    ]
    if not projects:
        return None
    mapped_sources = {
        canonical(mapping.source)
        for mapping in mappings
        if mapping.kind == "runtime-mirror-copy"
    }
    unaccounted = sorted(
        display_path(path) for path in projects if canonical(path) not in mapped_sources
    )
    if unaccounted:
        raise RecoveryError(f"Runtime mirror root contains unaccounted projects: {unaccounted[:20]}")
    target_parent = managed_root / "_temp" / "Runtime-Repo-Mirrors" / transaction
    target_parent.mkdir(parents=True, exist_ok=True)
    target = target_parent / "Repos"
    if target.exists() or target.is_symlink():
        raise RecoveryError(f"Runtime mirror retirement target already exists: {target}")
    source_stat = source_root.stat()
    if source_stat.st_dev != target_parent.stat().st_dev:
        raise RecoveryError("Runtime mirror root and managed _temp are on different filesystems.")
    record: dict[str, object] = {
        "source": display_path(source_root),
        "destination": display_path(target),
        "projectCount": len(projects),
        "device": source_stat.st_dev,
        "inode": source_stat.st_ino,
        "status": "retire-pending",
    }
    journal_path = report_dir / "runtime-mirror-retirement.json"
    write_json(journal_path, record)
    guarded_replace(source_root, target)
    target_stat = target.stat()
    if (target_stat.st_dev, target_stat.st_ino) != (source_stat.st_dev, source_stat.st_ino):
        raise RecoveryError(f"Runtime mirror rename identity changed: {source_root} -> {target}")
    source_root.mkdir(parents=True, exist_ok=True)
    for owner_name in sorted((path.name for path in owner_roots), key=os.fsencode):
        (source_root / owner_name).mkdir(parents=False, exist_ok=False)
    record["status"] = "retired-to-managed-temp"
    write_json(journal_path, record)
    return record


def volume_runner_processes(managed_root: Path) -> list[str]:
    result = run_command(["ps", "-axo", "pid=,command="], check=True)
    root_text = display_path(managed_root / "Runtime" / "Runners")
    active: list[str] = []
    for line in result.stdout.decode("utf-8", "replace").splitlines():
        if root_text in line and re.search(r"Runner\.(?:Listener|Worker)|/run\.sh", line):
            active.append(line.strip())
    return active


def retire_runtime_runner_worktrees(
    managed_root: Path,
    transaction: str,
    report_dir: Path,
    mappings: Sequence[Mapping],
) -> list[dict[str, object]]:
    runner_mappings = [
        mapping for mapping in mappings if mapping.kind == "runtime-runner-worktree"
    ]
    if not runner_mappings:
        return []
    active = volume_runner_processes(managed_root)
    if active:
        raise RecoveryError(
            "Runtime runner worktrees are active and cannot be retired safely: "
            + "; ".join(active[:10])
        )
    mapped_sources = {canonical(mapping.source) for mapping in runner_mappings}
    work_roots: dict[Path, list[Path]] = {}
    for mapping in runner_mappings:
        work_root = mapping.source.parents[1]
        work_roots.setdefault(work_root, []).append(mapping.source)
    destination_root = managed_root / "_temp" / "Runner-Worktrees" / transaction
    destination_root.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    journal_path = report_dir / "runtime-runner-retirement.json"
    for work_root in sorted(work_roots, key=lambda item: os.fsencode(display_path(item))):
        discovered = {
            canonical(dot_git.parent) for dot_git in work_root.glob("*/*/.git")
        }
        unaccounted = sorted(display_path(path) for path in discovered - mapped_sources)
        if unaccounted:
            raise RecoveryError(
                f"Runner _work root contains unaccounted repositories: {unaccounted[:20]}"
            )
        runner_name = work_root.parent.name
        target_parent = destination_root / runner_name
        target_parent.mkdir(parents=True, exist_ok=True)
        target = target_parent / "_work"
        if target.exists() or target.is_symlink():
            raise RecoveryError(f"Runner worktree retirement target already exists: {target}")
        source_stat = work_root.stat()
        if source_stat.st_dev != target_parent.stat().st_dev:
            raise RecoveryError(f"Runner _work root is not on managed _temp: {work_root}")
        record: dict[str, object] = {
            "source": display_path(work_root),
            "destination": display_path(target),
            "repositoryCount": len(discovered),
            "device": source_stat.st_dev,
            "inode": source_stat.st_ino,
            "status": "retire-pending",
        }
        records.append(record)
        write_json(journal_path, {"transaction": transaction, "workRoots": records})
        guarded_replace(work_root, target)
        target_stat = target.stat()
        if (target_stat.st_dev, target_stat.st_ino) != (source_stat.st_dev, source_stat.st_ino):
            raise RecoveryError(f"Runner _work rename identity changed: {work_root} -> {target}")
        work_root.mkdir(parents=True, exist_ok=True)
        os.chmod(work_root, stat.S_IMODE(source_stat.st_mode), follow_symlinks=False)
        record["status"] = "retired-to-managed-temp"
        write_json(journal_path, {"transaction": transaction, "workRoots": records})
    return records


def lexical_path_within(path: Path, root: Path) -> bool:
    try:
        return os.path.commonpath(
            [os.path.abspath(path), os.path.abspath(root)]
        ) == os.path.abspath(root)
    except ValueError:
        return False


def logical_case_recase(mapping: Mapping) -> bool:
    return (
        mapping.source.parent == mapping.destination.parent
        and mapping.source.name.casefold() == mapping.destination.name.casefold()
        and mapping.source.name != mapping.destination.name
    )


def mapping_retirement_authorized(mapping: Mapping) -> bool:
    """Return whether this recovery transaction may move the source to _temp."""
    if mapping.retention == "retain":
        return False
    if mapping.kind in NEVER_RETIRE_SOURCE_KINDS or logical_case_recase(mapping):
        return False
    return (
        mapping.retention == "retire-to-managed-temp"
        or mapping.kind in AUTO_RETIRE_SOURCE_KINDS
    )


def inventory_retirement_root(
    root: Path,
    mapped_items: Sequence[PreparedMapping],
    manifest_path: Path,
) -> dict[str, object]:
    """Recursively account for projects and non-project data before a root move."""
    mapped_sources = [
        item.mapping.source
        for item in mapped_items
        if lexical_path_within(item.mapping.source, root)
    ]
    if not mapped_sources:
        raise RecoveryError(f"Retirement root contains no finalized mapped source: {root}")

    def source_cover(path: Path) -> tuple[str, Path | None]:
        for mapped_source in mapped_sources:
            if path == mapped_source:
                return "mapped-project-manifest", mapped_source
            if lexical_path_within(path, mapped_source):
                return "mapped-project-content", mapped_source
            if lexical_path_within(mapped_source, path):
                return "mapped-project-container", mapped_source
        return "whole-root-evidence-only", None

    blockers: list[str] = []
    records = 0
    project_candidates = 0
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    with manifest_path.open("wb") as handle:
        stack = [root]
        while stack:
            directory = stack.pop()
            classification, covered_source = source_cover(directory)
            try:
                entries = sorted(
                    os.scandir(directory),
                    key=lambda entry: os.fsencode(entry.name),
                    reverse=True,
                )
            except OSError as error:
                raise RecoveryError(f"Could not inventory retirement root {directory}: {error}") from error
            names = {entry.name for entry in entries}
            marker_names = sorted(names & PROJECT_MARKERS)
            if marker_names:
                project_candidates += 1
                if classification == "whole-root-evidence-only":
                    blockers.append(
                        f"Unmapped project marker(s) {marker_names} at {directory}"
                    )
            directory_stat = directory.lstat()
            row = {
                "path": display_path(directory),
                "relativePath": "." if directory == root else directory.relative_to(root).as_posix(),
                "kind": "directory",
                "classification": classification,
                "coveredSource": display_path(covered_source) if covered_source else "",
                "projectMarkers": marker_names,
                "device": directory_stat.st_dev,
                "inode": directory_stat.st_ino,
                "mode": stat.S_IMODE(directory_stat.st_mode),
                "size": directory_stat.st_size,
                "mtimeNs": directory_stat.st_mtime_ns,
            }
            handle.write((json.dumps(row, sort_keys=True) + "\n").encode("utf-8"))
            records += 1
            if classification == "mapped-project-manifest":
                continue
            for entry in entries:
                path = Path(entry.path)
                entry_stat = path.lstat()
                kind = file_kind(entry_stat)
                child_classification, child_source = source_cover(path)
                if kind == "special":
                    blockers.append(f"Special filesystem object in retirement root: {path}")
                record = {
                    "path": display_path(path),
                    "relativePath": path.relative_to(root).as_posix(),
                    "kind": kind,
                    "classification": child_classification,
                    "coveredSource": display_path(child_source) if child_source else "",
                    "device": entry_stat.st_dev,
                    "inode": entry_stat.st_ino,
                    "mode": stat.S_IMODE(entry_stat.st_mode),
                    "size": entry_stat.st_size,
                    "mtimeNs": entry_stat.st_mtime_ns,
                }
                if kind == "symlink":
                    record["linkTarget"] = os.readlink(path)
                handle.write((json.dumps(record, sort_keys=True) + "\n").encode("utf-8"))
                records += 1
                if kind == "directory":
                    stack.append(path)
        handle.flush()
        os.fsync(handle.fileno())
    if blockers:
        raise RecoveryError(
            f"Retirement inventory failed for {root}: " + "; ".join(blockers[:20])
        )
    return {
        "root": display_path(root),
        "recordCount": records,
        "projectCandidateCount": project_candidates,
        "mappedSourceCount": len(mapped_sources),
        "manifest": display_path(manifest_path),
        "status": "fully-accounted",
    }


def process_blockers_for_retirement(
    roots: Sequence[Path],
    *,
    ignore_current_process_tree: bool = False,
) -> list[str]:
    roots = [Path(os.path.abspath(root)) for root in roots]
    blockers: list[str] = []
    protected_runtime_paths = {
        "helper": Path(os.path.abspath(__file__)),
        "cwd": Path(os.path.abspath(os.getcwd())),
    }
    for label, protected in protected_runtime_paths.items():
        for root in roots:
            if lexical_path_within(protected, root):
                blockers.append(f"{label} is inside retirement root {root}: {protected}")

    ps_result = run_command(["ps", "-axo", "pid=,ppid=,command="], check=True)
    process_rows: list[tuple[str, str, str]] = []
    child_pids: dict[str, list[str]] = {}
    for line in ps_result.stdout.decode("utf-8", "replace").splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        fields = stripped.split(None, 2)
        if len(fields) < 3:
            continue
        pid_text, parent_pid, command = fields
        process_rows.append((pid_text, parent_pid, command))
        child_pids.setdefault(parent_pid, []).append(pid_text)

    ignored_pids = {str(os.getpid())}
    if ignore_current_process_tree:
        pending = [str(os.getpid())]
        while pending:
            parent_pid = pending.pop()
            for child_pid in child_pids.get(parent_pid, []):
                if child_pid not in ignored_pids:
                    ignored_pids.add(child_pid)
                    pending.append(child_pid)

    for pid_text, _parent_pid, command in process_rows:
        if pid_text in ignored_pids:
            continue
        for root in roots:
            if display_path(root) in command:
                blockers.append(
                    f"process command references retirement root: {pid_text} {command}"
                )
                break

    lsof = shutil.which("lsof") or "/usr/sbin/lsof"
    if not os.path.exists(lsof):
        blockers.append("lsof is unavailable; open-file retirement proof cannot run")
        return blockers
    lsof_result = run_command([lsof, "-n", "-P", "-Fpcn"], check=False)
    if lsof_result.returncode not in {0, 1}:
        diagnostics = (lsof_result.stdout + lsof_result.stderr).decode(
            "utf-8", "replace"
        ).strip()
        blockers.append(f"lsof open-file inventory failed: {diagnostics}")
        return blockers
    current_pid = ""
    current_command = ""
    for raw_line in lsof_result.stdout.decode("utf-8", "surrogateescape").splitlines():
        if not raw_line:
            continue
        prefix, value = raw_line[0], raw_line[1:]
        if prefix == "p":
            current_pid = value
        elif prefix == "c":
            current_command = value
        elif prefix == "n" and current_pid not in ignored_pids:
            candidate = Path(value)
            if not candidate.is_absolute():
                continue
            for root in roots:
                if lexical_path_within(candidate, root):
                    blockers.append(
                        f"open path blocks retirement: pid={current_pid} "
                        f"command={current_command} path={candidate} root={root}"
                    )
                    break
    return blockers


def runtime_roots_for_mappings(
    mappings: Sequence[Mapping],
    managed_root: Path,
    additional_workspace_roots: Sequence[Path],
    reviewed_requirements: Sequence[RunnerDrainRequirement],
) -> list[Path]:
    del mappings  # Mapping discovery controls revalidation frequency, not proof authority.
    allowed_cleanup_roots = {
        display_path(Path(os.path.abspath(root))) for root in additional_workspace_roots
    }
    expected_canonical_runtime = Path(os.path.abspath(managed_root / "Runtime"))
    required: list[Path] = []
    for requirement in reviewed_requirements:
        if requirement.source_runtime_root != requirement.cleanup_root / "Runtime":
            raise RecoveryError(
                f"Reviewed source Runtime is not the exact cleanupRoot child: {requirement}"
            )
        if requirement.canonical_runtime_root != expected_canonical_runtime:
            raise RecoveryError(
                f"Reviewed canonical Runtime differs from this managed root: "
                f"{requirement.canonical_runtime_root} != {expected_canonical_runtime}"
            )
        if display_path(requirement.cleanup_root) not in allowed_cleanup_roots:
            raise RecoveryError(
                f"Process-drain cleanup root was not supplied as an exact additional workspace: "
                f"{requirement.cleanup_root}"
            )
        if requirement.cleanup_root.is_symlink() or not requirement.cleanup_root.is_dir():
            raise RecoveryError(
                f"Process-drain cleanup root is not a real directory: {requirement.cleanup_root}"
            )
        if (
            requirement.source_runtime_root.is_symlink()
            or not requirement.source_runtime_root.is_dir()
        ):
            raise RecoveryError(
                f"Runtime source root is not a real directory: {requirement.source_runtime_root}"
            )
        required.append(requirement.source_runtime_root)
    return sorted(set(required), key=lambda path: os.fsencode(display_path(path)))


def runner_drain_proof_to_json(proof: RunnerDrainProof) -> dict[str, object]:
    return {
        "receipt": display_path(proof.receipt),
        "receiptSha256": proof.receipt_sha256,
        "proofKind": RUNNER_DRAIN_PROOF_KIND,
        "recoveryTransaction": proof.recovery_transaction,
        "drainTransaction": proof.drain_transaction,
        "sourceMapSHA256": proof.source_map_sha256,
        "githubAccountsSHA256": proof.github_accounts_sha256,
        "repositoryIdentitiesSHA256": proof.repository_identities_sha256,
        "rootCount": len(proof.roots),
        "roots": [
            {
                "cleanupRoot": display_path(root.cleanup_root),
                "sourceRuntimeRoot": display_path(root.source_runtime_root),
                "canonicalRuntimeRoot": display_path(root.canonical_runtime_root),
                "serviceCount": len(root.services),
                "serviceSetSHA256": root.service_set_sha256,
            }
            for root in proof.roots
        ],
    }


def _absolute_receipt_path(value: object, label: str) -> Path:
    if not isinstance(value, str) or not os.path.isabs(value) or "\x00" in value:
        raise RecoveryError(f"{label} is not an absolute path")
    return Path(os.path.abspath(value))


def _required_integer(value: object, label: str, *, minimum: int = 0) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value < minimum:
        raise RecoveryError(f"{label} is not an integer >= {minimum}")
    return value


def _validate_runner_service_rows(
    raw_services: object,
    *,
    cleanup_root: Path,
) -> tuple[dict[str, object], ...]:
    if not isinstance(raw_services, list) or not raw_services:
        raise RecoveryError(f"Runner receipt has no exact service set: {cleanup_root}")
    services: list[dict[str, object]] = []
    labels: set[str] = set()
    plist_paths: set[str] = set()
    expected_keys = {
        "label",
        "plist",
        "plistSHA256",
        "loaded",
        "listenerActive",
        "disabled",
        "capturedLaunchPID",
        "workerActive",
    }
    for index, raw in enumerate(raw_services):
        if not isinstance(raw, dict):
            raise RecoveryError(f"Runner service {index} is not an object")
        if set(raw) != expected_keys:
            raise RecoveryError(
                f"Runner service {index} field set differs: {sorted(set(raw) ^ expected_keys)}"
            )
        label = raw.get("label")
        plist_value = raw.get("plist")
        digest = raw.get("plistSHA256")
        if (
            not isinstance(label, str)
            or not label
            or "\x00" in label
            or "\n" in label
            or label in labels
        ):
            raise RecoveryError(f"Runner service {index} has an invalid/duplicate label")
        labels.add(label)
        plist_path = _absolute_receipt_path(plist_value, f"runner service {label} plist")
        plist_key = display_path(plist_path)
        if plist_key in plist_paths:
            raise RecoveryError(f"Runner services repeat plist path: {plist_path}")
        plist_paths.add(plist_key)
        require_sha256(digest, f"runner service {label} plistSHA256")
        for field in ("loaded", "listenerActive", "disabled", "workerActive"):
            if not isinstance(raw.get(field), bool):
                raise RecoveryError(f"Runner service {label} {field} is not Boolean")
        captured_pid = raw.get("capturedLaunchPID")
        if raw.get("loaded") is True and captured_pid is not None:
            _required_integer(
                captured_pid, f"runner service {label} capturedLaunchPID", minimum=2
            )
        elif captured_pid is not None:
            raise RecoveryError(
                f"Unloaded runner service must have capturedLaunchPID=null: {label}"
            )
        if raw.get("listenerActive") is True and raw.get("loaded") is not True:
            raise RecoveryError(f"Runner listener cannot be active while service is unloaded: {label}")
        if raw.get("listenerActive") is True and captured_pid is None:
            raise RecoveryError(f"Active runner listener has no captured launch PID: {label}")
        if raw.get("workerActive") is not False:
            raise RecoveryError(
                f"Runner receipt captured an active Worker job and is not safe to consume: {label}"
            )
        if plist_path.is_symlink() or not plist_path.is_file():
            raise RecoveryError(f"Runner launch-agent plist is not ordinary: {plist_path}")
        current_digest, _plist_stat = stable_file_hash(plist_path)
        if current_digest != digest:
            raise RecoveryError(f"Runner launch-agent plist changed: {plist_path}")
        services.append(dict(raw))
    return tuple(services)


def _validate_runner_critical_hashes(
    value: object,
    *,
    cleanup_root: Path,
) -> dict[str, dict[str, str]]:
    if not isinstance(value, dict) or not value:
        raise RecoveryError(f"Runner receipt lacks critical hashes: {cleanup_root}")
    normalized: dict[str, dict[str, str]] = {}
    for relative, hashes in value.items():
        if not isinstance(relative, str):
            raise RecoveryError("Runner critical-hash relative path is not a string")
        relative_path = PurePosixPath(relative)
        if (
            relative_path.is_absolute()
            or relative_path in {PurePosixPath("."), PurePosixPath("..")}
            or any(part in {"", ".", ".."} for part in relative.split("/"))
            or len(relative_path.parts) < 4
            or relative_path.parts[:2] != ("Runtime", "Runners")
            or not isinstance(hashes, dict)
            or not hashes
        ):
            raise RecoveryError(f"Runner critical-hash row is unsafe: {relative!r}")
        if set(hashes) != CRITICAL_RUNNER_FILES:
            raise RecoveryError(
                f"Runner critical-hash file set differs for {relative}: "
                f"{sorted(set(hashes) ^ CRITICAL_RUNNER_FILES)}"
            )
        normalized_hashes: dict[str, str] = {}
        for relative_file, digest in hashes.items():
            if not isinstance(relative_file, str):
                raise RecoveryError(f"Runner critical filename is invalid: {relative_file!r}")
            critical_path = PurePosixPath(relative_file)
            if (
                critical_path.is_absolute()
                or critical_path in {PurePosixPath("."), PurePosixPath("..")}
                or any(part in {"", ".", ".."} for part in relative_file.split("/"))
                or relative_file not in CRITICAL_RUNNER_FILES
            ):
                raise RecoveryError(f"Runner critical filename is unsafe: {relative_file!r}")
            normalized_hashes[relative_file] = require_sha256(
                digest, f"runner critical hash {relative}/{relative_file}"
            )
        normalized[relative] = normalized_hashes
    return normalized


def parse_runner_drain_receipts(
    receipt_paths: Sequence[Path],
    *,
    transaction: str,
    required_runtime_roots: Sequence[Path],
    canonical_runtime_root: Path,
    managed_root: Path,
    source_map_sha256: str,
    github_accounts_sha256: str,
    repository_identities_sha256: str,
) -> tuple[dict[str, RunnerDrainProof], list[str]]:
    """Parse the exact local-cleanup runner-drain contract without signaling anything."""
    errors: list[str] = []
    proofs: dict[str, RunnerDrainProof] = {}
    required_by_path = {
        display_path(Path(os.path.abspath(root))): Path(os.path.abspath(root))
        for root in required_runtime_roots
    }
    canonical_runtime_root = Path(os.path.abspath(canonical_runtime_root))
    managed_root = Path(os.path.abspath(managed_root))
    if not required_by_path:
        if receipt_paths:
            errors.append("Runner-drain receipt supplied but this plan has no Runtime source root")
        return {}, errors
    if len(receipt_paths) != 1:
        return {}, [
            "Exactly one transaction-bound runner-drain receipt must cover every required Runtime root"
        ]
    for raw_receipt in receipt_paths:
        receipt = Path(os.path.abspath(raw_receipt))
        label = display_path(receipt)
        try:
            receipt_stat = receipt.lstat()
            if not stat.S_ISREG(receipt_stat.st_mode) or receipt.is_symlink():
                raise RecoveryError("receipt is not a regular non-symlink file")
            if receipt_stat.st_uid != os.getuid():
                raise RecoveryError(
                    f"receipt owner UID {receipt_stat.st_uid} does not match current UID {os.getuid()}"
                )
            if stat.S_IMODE(receipt_stat.st_mode) & 0o022:
                raise RecoveryError("receipt is group/world writable")
            raw = receipt.read_bytes()
            stable_digest, stable_stat = stable_file_hash(receipt)
            if (
                stable_stat.st_dev != receipt_stat.st_dev
                or stable_stat.st_ino != receipt_stat.st_ino
            ):
                raise RecoveryError("receipt identity changed while reading")
            payload = json.loads(raw.decode("utf-8"))
            if not isinstance(payload, dict):
                raise RecoveryError("receipt root is not an object")
            if payload.get("format") != 1 or payload.get("proofKind") != RUNNER_DRAIN_PROOF_KIND:
                raise RecoveryError("unsupported runner-drain receipt format/proofKind")
            if payload.get("status") != "quiesced":
                raise RecoveryError("status is not exactly 'quiesced'")
            if payload.get("transaction") != transaction or payload.get("recoveryTransaction") != transaction:
                raise RecoveryError("runner receipt is bound to a different recovery transaction")
            drain_transaction = safe_transaction_id(
                payload.get("drainTransaction"), "runner receipt drainTransaction"
            )
            expected_receipt = (
                managed_root
                / "_temp"
                / "RepoConsolidation"
                / "RunnerDrain"
                / drain_transaction
                / "runner-drain-receipt.json"
            )
            if receipt != expected_receipt:
                raise RecoveryError(
                    f"Runner receipt is not at its exact durable transaction path: "
                    f"{receipt} != {expected_receipt}"
                )
            require_no_symlink_components(
                receipt, managed_root / "_temp", "runner-drain receipt"
            )
            if payload.get("sourceMapSHA256") != source_map_sha256:
                raise RecoveryError("runner receipt is bound to a different source map")
            if payload.get("githubAccountsSHA256") != github_accounts_sha256:
                raise RecoveryError("runner receipt is bound to different GitHub accounts")
            if payload.get("repositoryIdentitiesSHA256") != repository_identities_sha256:
                raise RecoveryError("runner receipt is bound to different repository identities")
            if payload.get("credentialsSerialized") is not False:
                raise RecoveryError("runner receipt must explicitly state credentialsSerialized=false")
            managed_volume = payload.get("managedEvidenceVolume")
            if not isinstance(managed_volume, dict) or not managed_volume:
                raise RecoveryError("runner receipt lacks managedEvidenceVolume")
            current_managed_volume = contract_volume_identity(managed_root / "_temp")
            if not same_contract_volume_identity(managed_volume, current_managed_volume):
                raise RecoveryError("runner receipt managedEvidenceVolume changed")
            roots_value = payload.get("roots")
            if (
                not isinstance(roots_value, list)
                or payload.get("rootCount") != len(roots_value)
                or len(roots_value) != len(required_by_path)
            ):
                raise RecoveryError("runner receipt root count differs from the exact Runtime plan")

            parsed_roots: list[RunnerDrainRootProof] = []
            seen_runtime_roots: set[str] = set()
            for root_index, root_value in enumerate(roots_value):
                if not isinstance(root_value, dict):
                    raise RecoveryError(f"runner receipt root {root_index} is not an object")
                cleanup_root = _absolute_receipt_path(
                    root_value.get("cleanupRoot"), f"runner root {root_index} cleanupRoot"
                )
                source_runtime_root = _absolute_receipt_path(
                    root_value.get("sourceRuntimeRoot"),
                    f"runner root {root_index} sourceRuntimeRoot",
                )
                receipt_canonical_runtime = _absolute_receipt_path(
                    root_value.get("canonicalRuntimeRoot"),
                    f"runner root {root_index} canonicalRuntimeRoot",
                )
                if source_runtime_root != cleanup_root / "Runtime":
                    raise RecoveryError(
                        f"Runner sourceRuntimeRoot is not the exact Runtime child of cleanupRoot: "
                        f"{cleanup_root} -> {source_runtime_root}"
                    )
                runtime_key = display_path(source_runtime_root)
                if runtime_key not in required_by_path:
                    raise RecoveryError(
                        f"Runner sourceRuntimeRoot is not required by this plan: {source_runtime_root}"
                    )
                if runtime_key in seen_runtime_roots:
                    raise RecoveryError(f"Duplicate runner root row: {source_runtime_root}")
                seen_runtime_roots.add(runtime_key)
                if receipt_canonical_runtime != canonical_runtime_root:
                    raise RecoveryError(
                        f"Runner canonicalRuntimeRoot mismatch: {receipt_canonical_runtime} "
                        f"!= {canonical_runtime_root}"
                    )
                if lexical_path_within(receipt, source_runtime_root):
                    raise RecoveryError("runner receipt is stored inside the Runtime tree it protects")
                if cleanup_root.is_symlink() or not cleanup_root.is_dir():
                    raise RecoveryError(f"Runner cleanupRoot is not a real directory: {cleanup_root}")
                if source_runtime_root.is_symlink() or not source_runtime_root.is_dir():
                    raise RecoveryError(
                        f"Runner sourceRuntimeRoot is not a real directory: {source_runtime_root}"
                    )
                root_identity = root_value.get("rootIdentity")
                runtime_identity = root_value.get("sourceRuntimeIdentity")
                if not isinstance(root_identity, dict) or not isinstance(runtime_identity, dict):
                    raise RecoveryError("Runner receipt lacks root/source Runtime identities")
                root_device = _required_integer(root_identity.get("device"), "root device")
                root_inode = _required_integer(root_identity.get("inode"), "root inode", minimum=1)
                runtime_device = _required_integer(runtime_identity.get("device"), "Runtime device")
                runtime_inode = _required_integer(runtime_identity.get("inode"), "Runtime inode", minimum=1)
                root_stat = cleanup_root.lstat()
                runtime_stat = source_runtime_root.lstat()
                if (root_stat.st_dev, root_stat.st_ino) != (root_device, root_inode):
                    raise RecoveryError(f"Runner cleanupRoot identity changed: {cleanup_root}")
                if (runtime_stat.st_dev, runtime_stat.st_ino) != (runtime_device, runtime_inode):
                    raise RecoveryError(f"Runner sourceRuntimeRoot identity changed: {source_runtime_root}")

                services = _validate_runner_service_rows(
                    root_value.get("services"), cleanup_root=cleanup_root
                )
                service_digest = require_sha256(
                    root_value.get("serviceSetSHA256"), "runner serviceSetSHA256"
                )
                if contract_digest(list(services)) != service_digest:
                    raise RecoveryError(f"Runner service-set digest mismatch: {cleanup_root}")
                expected_counts = {
                    "serviceCount": len(services),
                    "loadedCount": sum(bool(service["loaded"]) for service in services),
                    "notLoadedCount": sum(not bool(service["loaded"]) for service in services),
                    "listenerActiveCount": sum(
                        bool(service["listenerActive"]) for service in services
                    ),
                    "workerActiveCount": 0,
                }
                for field, expected in expected_counts.items():
                    if root_value.get(field) != expected:
                        raise RecoveryError(f"Runner receipt {field} mismatch: {cleanup_root}")
                critical_hashes = _validate_runner_critical_hashes(
                    root_value.get("criticalHashes"), cleanup_root=cleanup_root
                )
                pre_reference_count = _required_integer(
                    root_value.get("processReferenceCount"),
                    "runner pre-drain processReferenceCount",
                )
                pre_reference_digest = require_sha256(
                    root_value.get("processReferenceSHA256"),
                    "runner pre-drain processReferenceSHA256",
                )
                after = root_value.get("afterDrain")
                expected_loaded = [
                    {"label": str(service["label"]), "loaded": False}
                    for service in services
                ]
                if (
                    not isinstance(after, dict)
                    or after.get("launchctlLoaded") != expected_loaded
                    or after.get("allCapturedServicesUnloaded") is not True
                    or after.get("allCapturedServicesDisabled") is not True
                    or after.get("listenerActiveCount") != 0
                    or after.get("workerActiveCount") != 0
                    or after.get("referenceRoot") != display_path(source_runtime_root)
                    or after.get("processReferenceCount") != 0
                    or after.get("processReferenceSHA256") != contract_digest([])
                    or after.get("cwdExecutableOpenFileReferencesAbsent") is not True
                    or after.get("cleanupRootProcessReferenceCount") != 0
                ):
                    raise RecoveryError(
                        f"Runner receipt after-drain proof is incomplete: {cleanup_root}"
                    )
                parsed_roots.append(
                    RunnerDrainRootProof(
                        cleanup_root=cleanup_root,
                        source_runtime_root=source_runtime_root,
                        canonical_runtime_root=receipt_canonical_runtime,
                        root_device=root_device,
                        root_inode=root_inode,
                        runtime_device=runtime_device,
                        runtime_inode=runtime_inode,
                        services=services,
                        service_set_sha256=service_digest,
                        critical_hashes=critical_hashes,
                        process_reference_count_before=pre_reference_count,
                        process_reference_sha256_before=pre_reference_digest,
                    )
                )
            if seen_runtime_roots != set(required_by_path):
                raise RecoveryError("Runner receipt does not cover the exact required Runtime set")

            proof = RunnerDrainProof(
                receipt=receipt,
                receipt_sha256=stable_digest,
                recovery_transaction=transaction,
                drain_transaction=drain_transaction,
                source_map_sha256=source_map_sha256,
                github_accounts_sha256=github_accounts_sha256,
                repository_identities_sha256=repository_identities_sha256,
                managed_evidence_volume=dict(managed_volume),
                roots=tuple(
                    sorted(
                        parsed_roots,
                        key=lambda value: os.fsencode(display_path(value.source_runtime_root)),
                    )
                ),
            )
            for root in proof.roots:
                proofs[display_path(root.source_runtime_root)] = proof
        except Exception as error:
            errors.append(f"Invalid runner-drain receipt {label}: {error}")

    for runtime_key in required_by_path:
        if runtime_key not in proofs:
            errors.append(
                f"Runtime source requires a transaction-bound runner-drain receipt: {runtime_key}"
            )
    return proofs, errors


def flatten_plist_strings(value: object) -> Iterator[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from flatten_plist_strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from flatten_plist_strings(child)


def discover_runner_launch_agents(cleanup_root: Path) -> dict[str, tuple[Path, str]]:
    """Discover the complete exact LaunchAgent set that references cleanupRoot."""
    values: dict[str, tuple[Path, str]] = {}
    launch_agents = Path.home() / "Library" / "LaunchAgents"
    if not launch_agents.is_dir() or launch_agents.is_symlink():
        raise RecoveryError(f"LaunchAgents directory is unavailable: {launch_agents}")
    for plist_path in sorted(
        launch_agents.glob("*.plist"), key=lambda path: os.fsencode(display_path(path))
    ):
        try:
            with plist_path.open("rb") as handle:
                payload = plistlib.load(handle)
        except (OSError, plistlib.InvalidFileException):
            continue
        references = [
            Path(os.path.abspath(value))
            for value in flatten_plist_strings(payload)
            if value.startswith("/")
        ]
        if not any(
            reference == cleanup_root
            or lexical_path_within(reference, cleanup_root)
            for reference in references
        ):
            continue
        label = payload.get("Label") if isinstance(payload, dict) else None
        if not isinstance(label, str) or not label or label in values:
            raise RecoveryError(
                f"Runner LaunchAgent identity is missing or duplicated under {cleanup_root}"
            )
        if plist_path.is_symlink() or not plist_path.is_file():
            raise RecoveryError(f"Runner LaunchAgent plist is not ordinary: {plist_path}")
        digest, _plist_stat = stable_file_hash(plist_path)
        values[label] = (Path(os.path.abspath(plist_path)), digest)
    return values


def revalidate_runner_drain_proof(proof: RunnerDrainProof) -> None:
    """Read-only proof that every exact drained root remains quiesced."""
    current_digest, _receipt_stat = stable_file_hash(proof.receipt)
    if current_digest != proof.receipt_sha256:
        raise RecoveryError(f"Runner-drain receipt changed: {proof.receipt}")
    if not proof.roots:
        raise RecoveryError("Runner-drain proof has no roots")
    managed_root = proof.roots[0].canonical_runtime_root.parent
    expected_receipt = (
        managed_root
        / "_temp"
        / "RepoConsolidation"
        / "RunnerDrain"
        / proof.drain_transaction
        / "runner-drain-receipt.json"
    )
    if proof.receipt != expected_receipt:
        raise RecoveryError(f"Runner-drain receipt moved: {proof.receipt}")
    require_no_symlink_components(
        proof.receipt, managed_root / "_temp", "runner-drain receipt"
    )
    current_volume = contract_volume_identity(managed_root / "_temp")
    if not same_contract_volume_identity(proof.managed_evidence_volume, current_volume):
        raise RecoveryError("Managed evidence volume changed since runner drain")

    launchctl = shutil.which("launchctl") or "/bin/launchctl"
    if not os.path.exists(launchctl):
        raise RecoveryError("launchctl is unavailable for exact runner-drain revalidation")
    domain = f"gui/{os.getuid()}"
    disabled_result = run_command([launchctl, "print-disabled", domain], check=False)
    if disabled_result.returncode != 0:
        raise RecoveryError("Could not revalidate launch-agent disabled state")
    disabled_output = disabled_result.stdout.decode("utf-8", "replace")
    disabled_labels = {
        label: value in {"true", "disabled"}
        for label, value in re.findall(
            r'"([^"\\]+)"\s*=>\s*(true|false|enabled|disabled)', disabled_output
        )
    }
    for root in proof.roots:
        if root.cleanup_root.is_symlink() or not root.cleanup_root.is_dir():
            raise RecoveryError(f"Runner cleanupRoot changed: {root.cleanup_root}")
        if root.source_runtime_root.is_symlink() or not root.source_runtime_root.is_dir():
            raise RecoveryError(f"Runner sourceRuntimeRoot changed: {root.source_runtime_root}")
        root_stat = root.cleanup_root.lstat()
        runtime_stat = root.source_runtime_root.lstat()
        if (root_stat.st_dev, root_stat.st_ino) != (root.root_device, root.root_inode):
            raise RecoveryError(f"Runner cleanupRoot identity changed: {root.cleanup_root}")
        if (runtime_stat.st_dev, runtime_stat.st_ino) != (
            root.runtime_device,
            root.runtime_inode,
        ):
            raise RecoveryError(f"Runner sourceRuntimeRoot identity changed: {root.source_runtime_root}")
        expected_agents = {
            str(service["label"]): (
                Path(os.path.abspath(str(service["plist"]))),
                str(service["plistSHA256"]),
            )
            for service in root.services
        }
        discovered_agents = discover_runner_launch_agents(root.cleanup_root)
        if discovered_agents != expected_agents:
            raise RecoveryError(
                f"Runner LaunchAgent set changed for {root.cleanup_root}: "
                f"expected={sorted(expected_agents)}, current={sorted(discovered_agents)}"
            )
        for service in root.services:
            label = str(service["label"])
            plist_path = Path(str(service["plist"]))
            if plist_path.is_symlink() or not plist_path.is_file():
                raise RecoveryError(f"Runner launch-agent plist changed: {plist_path}")
            plist_digest, _plist_stat = stable_file_hash(plist_path)
            if plist_digest != service["plistSHA256"]:
                raise RecoveryError(f"Runner launch-agent plist hash changed: {plist_path}")
            result = run_command([launchctl, "print", f"{domain}/{label}"], check=False)
            if result.returncode == 0:
                raise RecoveryError(
                    f"Drained launch agent is loaded again: {label} for {root.cleanup_root}"
                )
            if disabled_labels.get(label, False) is not True:
                raise RecoveryError(
                    f"Drained launch agent is no longer restart-disabled: {label}"
                )
        runtime_blockers = process_blockers_for_retirement(
            [root.source_runtime_root, root.cleanup_root],
            ignore_current_process_tree=True,
        )
        if runtime_blockers:
            raise RecoveryError(
                f"Runner root is not quiesced before Runtime read: {root.cleanup_root}: "
                + "; ".join(runtime_blockers[:20])
            )
        for relative, hashes in root.critical_hashes.items():
            for relative_file, expected_digest in hashes.items():
                critical_path = root.cleanup_root / relative / relative_file
                if critical_path.is_symlink() or not critical_path.is_file():
                    raise RecoveryError(f"Runner critical file changed: {critical_path}")
                actual_digest, _critical_stat = stable_file_hash(critical_path)
                if actual_digest != expected_digest:
                    raise RecoveryError(f"Runner critical file hash changed: {critical_path}")
        runtime_blockers = process_blockers_for_retirement(
            [root.source_runtime_root, root.cleanup_root],
            ignore_current_process_tree=True,
        )
        if runtime_blockers:
            raise RecoveryError(
                f"Runner root is not quiesced after Runtime read: {root.cleanup_root}: "
                + "; ".join(runtime_blockers[:20])
            )


def revalidate_runtime_roots_for_sources(
    sources: Sequence[Path],
    proofs: dict[str, RunnerDrainProof],
) -> None:
    relevant: dict[str, RunnerDrainProof] = {}
    for runtime_key, proof in proofs.items():
        if any(lexical_path_within(source, Path(runtime_key)) for source in sources):
            relevant[proof.receipt_sha256] = proof
    for receipt_digest in sorted(relevant):
        revalidate_runner_drain_proof(relevant[receipt_digest])


def retirement_candidate_for_mapping(
    item: PreparedMapping,
    moves: Sequence[RetirementMove],
) -> Path:
    for move in moves:
        if item.mapping.source == move.source:
            return move.target
        if lexical_path_within(item.mapping.source, move.source):
            return move.target / item.mapping.source.relative_to(move.source)
    return item.mapping.source


def finalize_source_retirement_receipts(
    all_items: Sequence[PreparedMapping],
    moves: Sequence[RetirementMove],
    group_results: Sequence[DestinationGroupResult],
    *,
    receipt_root: Path,
    partial_receipts: Path,
    transaction: str,
    journal_path: Path,
    managed_volume: VolumeIdentity,
    bindings: ContractBindings,
    runner_drain_proofs: dict[str, RunnerDrainProof],
    runtime_final_proof: Path | None,
    runtime_final_proof_sha256: str,
    workspace_root_proofs: Sequence[WorkspaceRootProofReference],
) -> list[Path]:
    """Atomically publish one cleanup-compatible final receipt per map row."""
    if os.path.lexists(receipt_root) or os.path.lexists(partial_receipts):
        raise RecoveryError(f"Source-retirement receipt lane already exists: {receipt_root}")
    partial_receipts.mkdir(parents=True, exist_ok=False)
    mapped_items = [item for item in all_items if item.mapping.mapping_sha256]
    by_source: dict[str, PreparedMapping] = {}
    for item in mapped_items:
        source_key = display_path(item.mapping.source)
        if source_key in by_source:
            raise RecoveryError(f"More than one prepared mapping claims source {source_key}")
        by_source[source_key] = item
    expected_sources = set(bindings.mapping_sha256_by_source)
    if set(by_source) != expected_sources:
        missing = sorted(expected_sources - set(by_source), key=os.fsencode)
        extra = sorted(set(by_source) - expected_sources, key=os.fsencode)
        raise RecoveryError(
            "Final receipt set does not match the exact source map: "
            f"missing={missing[:20]}, extra={extra[:20]}"
        )

    receipt_paths: list[Path] = []
    for source_key in sorted(by_source, key=os.fsencode):
        item = by_source[source_key]
        candidate = retirement_candidate_for_mapping(item, moves)
        moved_source = candidate != item.mapping.source
        deletion_eligible = mapping_retirement_authorized(item.mapping)
        if (
            not item.source_tree_digest
            or not item.source_git_components_digest
            or not item.source_git_state
            or not item.representation_proof
            or not item.representation_proof_sha256
            or not item.representation_status
        ):
            raise RecoveryError(
                f"Mapping lacks its final representation proof: {item.mapping.source}"
            )
        group = next(
            (value for value in group_results if item in value.prepared),
            None,
        )
        if (
            group is None
            or group.live_repository is None
            or not group.group_receipt
            or not group.group_receipt_sha256
        ):
            raise RecoveryError(
                f"Mapping lacks a final destination-group proof: {item.mapping.source}"
            )
        live = group.live_repository
        owner = item.mapping.destination.parent.name
        name = item.mapping.destination.name
        repository = item.mapping.repository
        account = bindings.github_accounts.get(owner)
        if account is None or account != live.authenticated_login:
            raise RecoveryError(
                f"Final receipt account binding mismatch: {owner} -> {account!r}"
            )
        if live.full_name != repository:
            raise RecoveryError(
                f"Final receipt repository mismatch: {live.full_name} != {repository}"
            )
        reviewed_identity = bindings.repository_identities.get(repository, {})
        account_binding_digest = contract_digest({"owner": owner, "account": account})
        repository_binding_digest = contract_digest(
            {"repository": repository, "reviewedIdentity": reviewed_identity}
        )
        receipt = {
            "format": RECEIPT_FORMAT,
            "transaction": transaction,
            "sourceMapSHA256": bindings.source_map_sha256,
            "githubAccountsSHA256": bindings.github_accounts_sha256,
            "repositoryIdentitiesSHA256": bindings.repository_identities_sha256,
            "mappingSHA256": item.mapping.mapping_sha256,
            "status": FINAL_RECEIPT_STATUS,
            "deletionEligible": deletion_eligible,
            "source": display_path(item.mapping.source),
            "sourceIdentity": {
                "path": display_path(item.mapping.source),
                "device": item.source_device,
                "inode": item.source_inode,
                "treeDigest": item.source_tree_digest,
                "gitComponentsDigest": item.source_git_components_digest,
                "gitComponents": item.source_git_components,
                "gitState": item.source_git_state,
                "legacyRepository": item.mapping.legacy_repository,
                "targetRepository": item.mapping.repository,
            },
            "authenticatedLogin": account,
            "githubAccountBindingSHA256": account_binding_digest,
            "repositoryIdentityBindingSHA256": repository_binding_digest,
            "destinationIdentity": {
                "path": display_path(item.mapping.destination),
                "owner": owner,
                "name": name,
                "repository": repository,
                "authenticatedLogin": account,
                "nodeID": live.node_id,
                "databaseID": live.database_id,
            },
            "representationProof": {
                "status": item.representation_status,
                "path": item.representation_proof,
                "sha256": item.representation_proof_sha256,
            },
            "destinationGroupProof": {
                "path": group.group_receipt,
                "sha256": group.group_receipt_sha256,
            },
            "recoveryRetirementStatus": (
                "retired-to-managed-temp-verified"
                if moved_source
                else (
                    "retained-for-stage3"
                    if deletion_eligible
                    else "retained-protected-not-deletion-eligible"
                )
            ),
            "retiredPath": display_path(candidate) if moved_source else "",
            "managedVolumeIdentity": dataclasses.asdict(managed_volume),
            "runnerDrainProofs": {
                key: runner_drain_proof_to_json(value)
                for key, value in sorted(runner_drain_proofs.items())
            },
            "runtimeFinalProof": display_path(runtime_final_proof)
            if runtime_final_proof
            else "",
            "runtimeFinalProofSha256": runtime_final_proof_sha256,
            "workspaceRootProofs": [
                {
                    "proofKind": WORKSPACE_ROOT_PROOF_KIND,
                    "path": display_path(reference.path),
                    "sha256": reference.sha256,
                    "cleanupRoot": reference.cleanup_root,
                    "manifestSHA256": reference.manifest_sha256,
                }
                for reference in workspace_root_proofs
            ],
            "permanentDeletionPerformed": False,
        }
        receipt_path = partial_receipts / f"{item.source_id}.json"
        write_fsynced_json(receipt_path, receipt)
        receipt_paths.append(receipt_path)
    fsync_directory(partial_receipts)
    guarded_replace(partial_receipts, receipt_root)
    fsync_directory(receipt_root.parent)
    return [receipt_root / path.name for path in receipt_paths]


def minimal_safe_relative_paths(values: Iterable[str]) -> tuple[str, ...]:
    """Normalize a path set without allowing a broad or traversing exclusion."""
    ordered: list[str] = []
    for raw in sorted(set(values), key=lambda value: (len(PurePosixPath(value).parts), os.fsencode(value))):
        relative = PurePosixPath(raw)
        if (
            not raw
            or relative.is_absolute()
            or relative in {PurePosixPath("."), PurePosixPath("..")}
            or ".." in relative.parts
            or any(part in {"", "."} for part in relative.parts)
        ):
            raise RecoveryError(f"Unsafe workspace-relative path: {raw!r}")
        normalized = relative.as_posix()
        if any(relative_path_is_excluded(normalized, (parent,)) for parent in ordered):
            continue
        ordered.append(normalized)
    return tuple(sorted(ordered, key=os.fsencode))


def destination_group_for_item(
    item: PreparedMapping,
    group_results: Sequence[DestinationGroupResult],
) -> DestinationGroupResult:
    matches = [group for group in group_results if item in group.prepared]
    if len(matches) != 1:
        raise RecoveryError(
            f"Workspace lane must belong to exactly one destination group: "
            f"{item.mapping.source}; matches={len(matches)}"
        )
    group = matches[0]
    if (
        not item.git.final_group_fsck_verified
        or not group.group_receipt
        or not group.group_receipt_sha256
    ):
        raise RecoveryError(
            f"Workspace lane lacks a finalized destination-group proof: "
            f"{item.mapping.source}"
        )
    group_path = Path(group.group_receipt)
    actual_group_sha256, _group_stat = stable_file_hash(group_path)
    if actual_group_sha256 != group.group_receipt_sha256:
        raise RecoveryError(
            f"Workspace lane destination-group proof changed: {group_path}"
        )
    return group


def workspace_mapping_coverage(
    requirement: WorkspaceRootRequirement,
    all_items: Sequence[PreparedMapping],
    group_results: Sequence[DestinationGroupResult],
    report_dir: Path,
) -> tuple[tuple[str, ...], list[dict[str, object]]]:
    """Bind every excluded project lane to its exact final mapping proof."""
    relative_paths: list[str] = []
    rows: list[dict[str, object]] = []
    for item in sorted(
        all_items,
        key=lambda value: os.fsencode(display_path(value.mapping.source)),
    ):
        source = Path(os.path.abspath(item.mapping.source))
        if source == requirement.cleanup_root:
            raise RecoveryError(
                "A whole-workspace proof cannot hide an exact root mapping; "
                f"use one representation contract, not both: {source}"
            )
        if not lexical_path_within(source, requirement.cleanup_root):
            continue
        relative = source.relative_to(requirement.cleanup_root).as_posix()
        relative_paths.append(relative)
        group = destination_group_for_item(item, group_results)
        source_manifest = (
            report_dir / "sources" / item.source_id / "filesystem-manifest-final.jsonl"
        )
        if not source_manifest.is_file():
            raise RecoveryError(
                f"Workspace project lane lacks its final source manifest: {source_manifest}"
            )
        source_manifest_sha256, _manifest_stat = stable_file_hash(source_manifest)
        representation: dict[str, str] = {}
        if item.mapping.mapping_sha256:
            if not item.representation_proof or not item.representation_proof_sha256:
                raise RecoveryError(
                    f"Reviewed workspace lane lacks its representation proof: {source}"
                )
            representation_path = Path(item.representation_proof)
            representation_sha256, _representation_stat = stable_file_hash(
                representation_path
            )
            if representation_sha256 != item.representation_proof_sha256:
                raise RecoveryError(
                    f"Workspace lane representation proof changed: {representation_path}"
                )
            representation = {
                "path": display_path(representation_path),
                "sha256": representation_sha256,
            }
        rows.append(
            {
                "sourceId": item.source_id,
                "source": display_path(source),
                "relativePath": relative,
                "mappingSHA256": item.mapping.mapping_sha256,
                "sourceTreeDigest": item.tree.root_digest,
                "sourceManifest": {
                    "path": display_path(source_manifest),
                    "sha256": source_manifest_sha256,
                },
                "sourceGitComponentsDigest": item.source_git_components_digest,
                "destination": display_path(item.mapping.destination),
                "destinationGroupProof": {
                    "path": group.group_receipt,
                    "sha256": group.group_receipt_sha256,
                },
                "representationProof": representation,
                "status": "excluded-project-lane-exactly-mapped-and-finalized",
            }
        )
    return minimal_safe_relative_paths(relative_paths), rows


def workspace_unreviewed_project_paths(
    source_snapshot: Path,
    *,
    mapped_exclusions: Sequence[str],
) -> tuple[str, ...]:
    """Route unreviewed nested project/Git roots to recovery, never active data."""
    candidates: list[str] = []
    stack: list[tuple[Path, str]] = [(source_snapshot, ".")]
    while stack:
        directory, relative = stack.pop()
        if relative != "." and relative_path_is_excluded(relative, mapped_exclusions):
            continue
        try:
            entries = sorted(
                os.scandir(directory),
                key=lambda entry: os.fsencode(entry.name),
                reverse=True,
            )
        except OSError as error:
            raise RecoveryError(
                f"Could not classify workspace project lanes in {directory}: {error}"
            ) from error
        names = {entry.name for entry in entries}
        bare_git = {"HEAD", "objects", "refs"}.issubset(names)
        markers = sorted(names & PROJECT_MARKERS, key=os.fsencode)
        if relative == "." and (".git" in names or bare_git):
            raise RecoveryError(
                f"Additional workspace root is itself an unreviewed Git repository: "
                f"{source_snapshot}"
            )
        if relative != "." and (markers or bare_git):
            candidates.append(relative)
            continue
        for entry in entries:
            if relative == "." and entry.name == RECOVERY_DIR_NAME:
                continue
            if not entry.is_dir(follow_symlinks=False):
                continue
            child_relative = (
                entry.name if relative == "." else f"{relative}/{entry.name}"
            )
            if relative_path_is_excluded(child_relative, mapped_exclusions):
                continue
            stack.append((Path(entry.path), child_relative))
    return minimal_safe_relative_paths(candidates)


def workspace_runner_proof(
    requirement: WorkspaceRootRequirement,
    runner_drain_proofs: dict[str, RunnerDrainProof],
) -> RunnerDrainProof | None:
    if not requirement.requires_runner_drain:
        return None
    runtime_key = display_path(requirement.cleanup_root / "Runtime")
    proof = runner_drain_proofs.get(runtime_key)
    if proof is None:
        raise RecoveryError(
            f"Whole-workspace read lacks its exact Runner drain proof: {runtime_key}"
        )
    matching_roots = [
        root
        for root in proof.roots
        if root.cleanup_root == requirement.cleanup_root
        and root.source_runtime_root == requirement.cleanup_root / "Runtime"
        and root.canonical_runtime_root == requirement.canonical_root / "Runtime"
    ]
    if len(matching_roots) != 1:
        raise RecoveryError(
            f"Runner drain proof does not bind the exact workspace root triple: "
            f"{requirement.cleanup_root}"
        )
    revalidate_runner_drain_proof(proof)
    return proof


def translate_managed_reference(
    path: Path,
    *,
    managed_root: Path,
    staged_managed_root: Path,
) -> Path:
    if not lexical_path_within(path, managed_root):
        raise RecoveryError(f"Workspace proof reference escaped managed root: {path}")
    return staged_managed_root / path.relative_to(managed_root)


def verify_workspace_mapping_references(
    rows: Sequence[dict[str, object]],
    *,
    managed_root: Path,
    staged_managed_root: Path | None = None,
) -> None:
    for row in rows:
        for field in ("sourceManifest", "destinationGroupProof", "representationProof"):
            reference = row.get(field)
            if not isinstance(reference, dict) or not reference:
                continue
            raw_path = reference.get("path")
            expected_sha256 = reference.get("sha256")
            if not isinstance(raw_path, str) or not isinstance(expected_sha256, str):
                raise RecoveryError(
                    f"Malformed workspace project proof reference: {field}: {reference!r}"
                )
            path = Path(raw_path)
            if staged_managed_root is not None:
                path = translate_managed_reference(
                    path,
                    managed_root=managed_root,
                    staged_managed_root=staged_managed_root,
                )
            actual_sha256, _stat_result = stable_file_hash(path)
            if actual_sha256 != expected_sha256:
                raise RecoveryError(
                    f"Workspace project proof reference changed: {path}"
                )


def verify_exact_tree_subset(source: Path, destination: Path) -> str:
    """Prove every pre-existing path survived; destination additions are allowed."""
    source_hardlinks = hardlink_groups_for_tree(source, excluded_top_level=set())
    destination_groups: dict[str, list[Path]] = {}
    entries: list[tuple[str, Path, os.stat_result]] = [
        (".", source, source.lstat()),
        *iter_source_entries(source, excluded_top_level=set()),
    ]
    for relative, source_path, source_stat in entries:
        destination_path = destination if relative == "." else destination / relative
        destination_stat = lstat_or_none(destination_path)
        if destination_stat is None or file_kind(destination_stat) != file_kind(source_stat):
            raise RecoveryError(
                f"Managed-root promotion lost a prior path: {source_path} -> {destination_path}"
            )
        kind = file_kind(source_stat)
        if metadata_signature(source_path, source_stat) != metadata_signature(
            destination_path, destination_stat
        ):
            raise RecoveryError(
                f"Managed-root promotion changed prior metadata: {destination_path}"
            )
        if kind == "file" and stable_file_hash(source_path)[0] != stable_file_hash(destination_path)[0]:
            raise RecoveryError(
                f"Managed-root promotion changed prior bytes: {destination_path}"
            )
        if kind == "symlink" and os.readlink(source_path) != os.readlink(destination_path):
            raise RecoveryError(
                f"Managed-root promotion changed a prior symlink: {destination_path}"
            )
        group = source_hardlinks.get(relative, "")
        if group:
            destination_groups.setdefault(group, []).append(destination_path)
    for group, paths in destination_groups.items():
        identities = {(path.lstat().st_dev, path.lstat().st_ino) for path in paths}
        expected = sum(value == group for value in source_hardlinks.values())
        if len(paths) != expected or len(identities) != 1:
            raise RecoveryError(
                f"Managed-root promotion changed prior hardlink topology: {group}"
            )
    return count_source_tree(
        source, excluded_top_level=set(), include_root=True
    ).root_digest


def build_workspace_consumer_manifest(
    requirement: WorkspaceRootRequirement,
    row: dict[str, object],
    *,
    managed_root: Path,
    report_dir: Path,
    transaction: str,
    bindings: ContractBindings,
    all_items: Sequence[PreparedMapping],
) -> tuple[Path, str, dict[str, object], list[str], list[str]]:
    source = requirement.cleanup_root
    snapshot = managed_root / str(row["snapshotRelative"])
    records, tree_digest, ephemeral = contract_scan_tree(
        source, exclude_top_git=False
    )
    if tree_digest != row["snapshotTreeDigest"]:
        raise RecoveryError(f"Workspace source changed before final manifest: {source}")
    ordinary_path = (
        report_dir
        / "workspace-roots"
        / str(row["sourceId"])
        / "ordinary-manifest-final.jsonl"
    )
    ordinary: dict[str, str] = {}
    with ordinary_path.open("rb") as handle:
        for raw_line in handle:
            value = json.loads(raw_line)
            ordinary[str(value["relativePath"])] = str(value["representative"])
    exclusions = tuple(row["mappedExclusions"])
    evidence_prefixes = tuple(row["recoveryOnlyProjectPaths"])
    hardlink_evidence = {
        str(record["hardlinkGroup"])
        for record in records
        if record.get("hardlinkGroup")
    }
    entries: list[dict[str, object]] = []
    variants: list[str] = []
    evidence_only: list[str] = []
    for record in records:
        relative = str(record["relativePath"])
        under_project = any(
            relative == value or relative.startswith(value + "/")
            for value in exclusions
        )
        force_evidence = bool(record.get("hardlinkGroup") in hardlink_evidence) or (
            relative != "."
            and (
                relative_path_is_excluded(relative, evidence_prefixes)
                or relative_path_is_excluded(relative, (RECOVERY_DIR_NAME,))
            )
        )
        if under_project:
            coverage = "separate-project-proof"
            representation = snapshot if relative == "." else snapshot / relative
        elif force_evidence:
            coverage = "managed-evidence-only"
            representation = snapshot if relative == "." else snapshot / relative
            evidence_only.append(relative)
        else:
            raw_representation = ordinary.get(relative)
            if not raw_representation:
                raise RecoveryError(
                    f"Workspace ordinary manifest omitted {source}:{relative}"
                )
            representation = Path(raw_representation)
            canonical_path = managed_root if relative == "." else managed_root / relative
            if representation == canonical_path:
                coverage = "canonical-nonrepository"
            else:
                coverage = "canonical-preserved-variant"
                variants.append(relative)
        representation_fingerprint = contract_stable_fingerprint(representation)
        if representation_fingerprint != record["fingerprint"]:
            raise RecoveryError(
                f"Workspace representation fingerprint differs: {source}:{relative}"
            )
        entries.append(
            {
                "relativePath": relative,
                "sourceFingerprint": record["fingerprint"],
                "sourceHardlinkGroup": record.get("hardlinkGroup", ""),
                "representationPath": display_path(representation),
                "representationFingerprint": representation_fingerprint,
                "coverageKind": coverage,
            }
        )

    git_roots: list[dict[str, object]] = []
    git_relative_paths: set[str] = set()
    for record in records:
        relative = str(record["relativePath"])
        if relative == ".":
            continue
        parts = PurePosixPath(relative).parts
        if parts and parts[-1] == ".git" and ".git" not in parts[:-1]:
            parent = PurePosixPath(*parts[:-1])
            git_relative_paths.add("." if not parent.parts else parent.as_posix())
    for project_relative in sorted(git_relative_paths, key=os.fsencode):
        project = source if project_relative == "." else source / project_relative
        components, git_state = contract_git_component_paths(
            project, logical_source=project
        )
        item = next(
            (candidate for candidate in all_items if candidate.mapping.source == project),
            None,
        )
        proof_components: list[dict[str, object]] = []
        for component in components:
            source_component = Path(str(component["path"]))
            representation: Path | None = None
            if source_component == source or lexical_path_within(source_component, source):
                representation = snapshot / source_component.relative_to(source)
            elif item is not None:
                for captured in item.git.component_snapshots:
                    if (
                        captured.source_role == component["role"]
                        and captured.source_path == display_path(source_component)
                    ):
                        representation = (
                            item.mapping.destination / captured.snapshot_relative
                        )
                        break
            if representation is None:
                raise RecoveryError(
                    f"Workspace linked Git component lacks durable evidence: {source_component}"
                )
            _representation_rows, representation_digest, representation_sockets = (
                contract_scan_tree(representation, exclude_top_git=False)
            )
            if representation_sockets or representation_digest != component["treeDigest"]:
                raise RecoveryError(
                    f"Workspace Git component representation changed: {representation}"
                )
            proof_components.append(
                {
                    **component,
                    "representationPath": display_path(representation),
                    "representationTreeDigest": representation_digest,
                }
            )
        if git_state == "broken":
            evidence_status = "broken-git-evidence-complete"
        elif item is not None and item.git.git_history_imported:
            evidence_status = "history-imported-complete"
        elif item is not None and item.git.pointer_only_evidence:
            evidence_status = "pointer-only-evidence-complete"
        else:
            raise RecoveryError(
                f"Workspace Git root lacks imported/pointer evidence: {project}"
            )
        source_components = [
            {
                key: component[key]
                for key in (
                    "role",
                    "path",
                    "device",
                    "inode",
                    "treeDigest",
                    "entryCount",
                    "ephemeralFsmonitorSockets",
                )
            }
            for component in proof_components
        ]
        git_roots.append(
            {
                "projectRelativePath": project_relative,
                "gitState": git_state,
                "evidenceStatus": evidence_status,
                "componentsDigest": contract_digest(source_components),
                "components": proof_components,
            }
        )
    manifest_path = (
        report_dir
        / "workspace-roots"
        / str(row["sourceId"])
        / "workspace-root-manifest.json"
    )
    manifest = {
        "format": 1,
        "manifestKind": WORKSPACE_ROOT_MANIFEST_KIND,
        "transaction": transaction,
        "sourceMapSHA256": bindings.source_map_sha256,
        "githubAccountsSHA256": bindings.github_accounts_sha256,
        "repositoryIdentitiesSHA256": bindings.repository_identities_sha256,
        "cleanupRoot": display_path(source),
        "canonicalRoot": display_path(managed_root),
        "treeAlgorithm": TREE_ALGORITHM,
        "sourceTreeDigest": tree_digest,
        "entryCount": len(entries),
        "ephemeralFsmonitorSockets": ephemeral,
        "entries": entries,
        "gitRoots": git_roots,
    }
    write_fsynced_json(manifest_path, manifest)
    return (
        manifest_path,
        stable_file_hash(manifest_path)[0],
        manifest,
        sorted(variants, key=os.fsencode),
        sorted(evidence_only, key=os.fsencode),
    )


def rollback_workspace_root_swap(
    state: WorkspaceRootSwapState,
    *,
    reason: str,
) -> None:
    if state.rolled_back:
        return
    managed_root = state.managed_root
    emergency = state.sibling_transaction_root
    emergency.mkdir(parents=True, exist_ok=True)
    hold = emergency / "rollback-managed-root"
    failed = emergency / "failed-promoted-managed-root"
    if os.path.lexists(hold) or os.path.lexists(failed):
        raise RecoveryError(f"Workspace rollback lane is not empty: {emergency}")
    rollback_root = state.rollback_root
    if not os.path.lexists(rollback_root):
        raise RecoveryError(f"Workspace rollback source is missing: {rollback_root}")
    guarded_replace(rollback_root, hold)
    fsync_directory(hold.parent)
    guarded_replace(managed_root, failed)
    fsync_directory(managed_root.parent)
    guarded_replace(hold, managed_root)
    fsync_directory(managed_root.parent)
    failed_target = (
        managed_root
        / "_temp"
        / "Repo-Consolidation"
        / state.transaction
        / "workspace-root-failed-promotion"
    )
    failed_target.parent.mkdir(parents=True, exist_ok=True)
    if os.path.lexists(failed_target):
        raise RecoveryError(
            f"Workspace failed-promotion quarantine exists: {failed_target}"
        )
    guarded_replace(failed, failed_target)
    fsync_directory(failed_target.parent)
    rollback_report = (
        managed_root
        / "Runtime"
        / "Reports"
        / "RepoConsolidation"
        / state.transaction
        / "workspace-root-rollback.json"
    )
    write_fsynced_json(
        rollback_report,
        {
            "format": 1,
            "transaction": state.transaction,
            "status": "rolled-back",
            "reason": reason,
            "failedPromotion": display_path(failed_target),
            "originalManagedRootRestored": display_path(managed_root),
        },
    )
    state.rolled_back = True


def assemble_and_promote_workspace_roots(
    requirements: Sequence[WorkspaceRootRequirement],
    all_items: Sequence[PreparedMapping],
    group_results: Sequence[DestinationGroupResult],
    *,
    managed_root: Path,
    report_dir: Path,
    transaction: str,
    plan_sha256: str,
    bindings: ContractBindings,
    runner_drain_proofs: dict[str, RunnerDrainProof],
) -> WorkspaceRootSwapState | None:
    """Atomically merge/prove complete additional workspaces into managed root."""
    if not requirements:
        return None
    if bindings.workspace_root_proof_contract != WORKSPACE_ROOT_PROOF_KIND:
        raise RecoveryError(
            f"Source map does not authorize {WORKSPACE_ROOT_PROOF_KIND}"
        )
    ordered = sorted(
        requirements,
        key=lambda value: os.fsencode(display_path(value.cleanup_root)),
    )
    for requirement in ordered:
        if requirement.canonical_root != managed_root:
            raise RecoveryError(
                f"Workspace targets another managed root: {requirement}"
            )
        if (
            requirement.cleanup_root == managed_root
            or lexical_path_within(requirement.cleanup_root, managed_root)
            or lexical_path_within(managed_root, requirement.cleanup_root)
        ):
            raise RecoveryError(
                f"Workspace/managed-root containment is unsafe: "
                f"{requirement.cleanup_root} / {managed_root}"
            )
        if not requirement.cleanup_root.is_dir() or requirement.cleanup_root.is_symlink():
            raise RecoveryError(
                f"Workspace cleanup root is unavailable: {requirement.cleanup_root}"
            )
        workspace_runner_proof(requirement, runner_drain_proofs)

    blockers = process_blockers_for_retirement(
        [managed_root, *(value.cleanup_root for value in ordered)]
    )
    if blockers:
        raise RecoveryError(
            "Whole-workspace process precheck failed: " + "; ".join(blockers[:20])
        )
    managed_volume = volume_identity(managed_root)
    sibling_root = managed_root.parent / (
        f".{managed_root.name}.csa-iem-workspace-{safe_ref_component(transaction)}"
    )
    if os.path.lexists(sibling_root):
        raise RecoveryError(f"Workspace transaction lane exists: {sibling_root}")
    sibling_root.mkdir(parents=False, exist_ok=False)
    revalidate_volume_identity(managed_volume, sibling_root)
    staged_managed = sibling_root / "staged-managed-root"
    rollback_root = sibling_root / "managed-root-before-promotion"
    journal_path = sibling_root / "workspace-root-swap-journal.json"
    journal: dict[str, object] = {
        "format": 1,
        "transaction": transaction,
        "status": "staging",
        "managedRoot": display_path(managed_root),
        "stagedManagedRoot": display_path(staged_managed),
        "rollbackRoot": display_path(rollback_root),
        "managedVolumeIdentity": dataclasses.asdict(managed_volume),
    }
    write_fsynced_json(journal_path, journal)
    promoted = False
    state: WorkspaceRootSwapState | None = None
    try:
        prior_managed_digest = copy_exact_verified(
            managed_root, staged_managed, sibling_root
        )
        staged_report = staged_managed / report_dir.relative_to(managed_root)
        root_rows: list[dict[str, object]] = []
        for requirement in ordered:
            mapped_exclusions, mapping_rows = workspace_mapping_coverage(
                requirement, all_items, group_results, report_dir
            )
            verify_workspace_mapping_references(
                mapping_rows,
                managed_root=managed_root,
                staged_managed_root=staged_managed,
            )
            source_key = display_path(requirement.cleanup_root)
            source_id = hashlib.sha256(os.fsencode(source_key)).hexdigest()[:20]
            source_stat = requirement.cleanup_root.lstat()
            evidence_parent = (
                staged_managed
                / "_temp"
                / "Repo-Consolidation"
                / transaction
                / "workspace-root-evidence"
                / source_id
            )
            evidence_root = evidence_parent / "source-workspace"
            if os.path.lexists(evidence_root):
                raise RecoveryError(
                    f"Workspace evidence destination exists: {evidence_root}"
                )
            snapshot_digest = copy_exact_verified(
                requirement.cleanup_root, evidence_root, evidence_parent
            )
            recovery_only_paths = workspace_unreviewed_project_paths(
                evidence_root, mapped_exclusions=mapped_exclusions
            )
            source_report = staged_report / "workspace-roots" / source_id
            variant_root = (
                staged_managed
                / RECOVERY_DIR_NAME
                / "workspace-variants"
                / transaction
                / source_id
                / "files"
            )
            stage_stats = tree_merge_or_verify(
                evidence_root,
                staged_managed,
                variant_root,
                source_report / "conflicts-assembly.jsonl",
                merge=True,
                excluded_relative_paths=mapped_exclusions,
                activate_source_only=True,
                manifest_path=source_report / "ordinary-manifest-assembly.jsonl",
                recovery_only_paths=recovery_only_paths,
                preserve_canonical_directory_children=True,
            )
            second_stats = tree_merge_or_verify(
                evidence_root,
                staged_managed,
                variant_root,
                source_report / "conflicts-pre-promotion.jsonl",
                merge=False,
                excluded_relative_paths=mapped_exclusions,
                activate_source_only=True,
                manifest_path=source_report / "ordinary-manifest-pre-promotion.jsonl",
                recovery_only_paths=recovery_only_paths,
                preserve_canonical_directory_children=True,
            )
            if second_stats.root_digest != stage_stats.root_digest:
                raise RecoveryError(
                    f"Workspace representation changed during staging: {requirement.cleanup_root}"
                )
            if verify_exact_path_snapshot(requirement.cleanup_root, evidence_root) != snapshot_digest:
                raise RecoveryError(
                    f"Workspace source changed during snapshot capture: {requirement.cleanup_root}"
                )
            workspace_runner_proof(requirement, runner_drain_proofs)
            root_rows.append(
                {
                    "cleanupRoot": source_key,
                    "canonicalRoot": display_path(managed_root),
                    "sourceDevice": source_stat.st_dev,
                    "sourceInode": source_stat.st_ino,
                    "sourceId": source_id,
                    "snapshotRelative": evidence_root.relative_to(staged_managed).as_posix(),
                    "snapshotTreeDigest": snapshot_digest,
                    "ordinaryTreeDigest": stage_stats.root_digest,
                    "mappedExclusions": list(mapped_exclusions),
                    "recoveryOnlyProjectPaths": list(recovery_only_paths),
                    "mappedProjectLanes": mapping_rows,
                }
            )

        blockers = process_blockers_for_retirement(
            [managed_root, *(value.cleanup_root for value in ordered)]
        )
        if blockers:
            raise RecoveryError(
                "Whole-workspace promotion precheck failed: " + "; ".join(blockers[:20])
            )
        revalidate_volume_identity(managed_volume, managed_root)
        revalidate_volume_identity(managed_volume, staged_managed)
        journal["status"] = "promotion-pending"
        write_fsynced_json(journal_path, journal)
        guarded_replace(managed_root, rollback_root)
        fsync_directory(managed_root.parent)
        try:
            guarded_replace(staged_managed, managed_root)
            fsync_directory(managed_root.parent)
            promoted = True
        except Exception:
            guarded_replace(rollback_root, managed_root)
            fsync_directory(managed_root.parent)
            raise

        final_rows: list[dict[str, object]] = []
        for row, requirement in zip(root_rows, ordered, strict=True):
            workspace_runner_proof(requirement, runner_drain_proofs)
            evidence_root = managed_root / str(row["snapshotRelative"])
            source_report = report_dir / "workspace-roots" / str(row["sourceId"])
            snapshot_manifest = source_report / "source-snapshot-final.jsonl"
            snapshot_stats = write_exact_snapshot_manifest(
                requirement.cleanup_root,
                evidence_root,
                snapshot_manifest,
                excluded_top_level=set(),
            )
            if snapshot_stats.root_digest != row["snapshotTreeDigest"]:
                raise RecoveryError(
                    f"Final workspace snapshot changed: {requirement.cleanup_root}"
                )
            variant_root = (
                managed_root
                / RECOVERY_DIR_NAME
                / "workspace-variants"
                / transaction
                / str(row["sourceId"])
                / "files"
            )
            final_stats = tree_merge_or_verify(
                evidence_root,
                managed_root,
                variant_root,
                source_report / "conflicts-final.jsonl",
                merge=False,
                excluded_relative_paths=tuple(row["mappedExclusions"]),
                activate_source_only=True,
                manifest_path=source_report / "ordinary-manifest-final.jsonl",
                recovery_only_paths=tuple(row["recoveryOnlyProjectPaths"]),
                preserve_canonical_directory_children=True,
            )
            if final_stats.root_digest != row["ordinaryTreeDigest"]:
                raise RecoveryError(
                    f"Final workspace ordinary representation changed: {requirement.cleanup_root}"
                )
            verify_workspace_mapping_references(
                row["mappedProjectLanes"], managed_root=managed_root
            )
            if (
                requirement.cleanup_root.lstat().st_dev != row["sourceDevice"]
                or requirement.cleanup_root.lstat().st_ino != row["sourceInode"]
            ):
                raise RecoveryError(
                    f"Workspace source identity changed: {requirement.cleanup_root}"
                )
            workspace_runner_proof(requirement, runner_drain_proofs)
            final_rows.append(
                {
                    **row,
                    "snapshotManifest": display_path(snapshot_manifest),
                    "snapshotManifestSHA256": stable_file_hash(snapshot_manifest)[0],
                    "snapshotEntryCount": snapshot_stats.manifest_entries,
                    "ordinaryManifest": display_path(
                        source_report / "ordinary-manifest-final.jsonl"
                    ),
                    "ordinaryManifestSHA256": stable_file_hash(
                        source_report / "ordinary-manifest-final.jsonl"
                    )[0],
                    "ordinaryEntryCount": final_stats.manifest_entries,
                    "status": "every-entry-snapshot-and-nonrepository-representation-verified",
                }
            )

        preserved_prior_digest = verify_exact_tree_subset(rollback_root, managed_root)
        if preserved_prior_digest != prior_managed_digest:
            raise RecoveryError("Prior managed-root digest changed during promotion")
        rollback_quarantine = (
            managed_root
            / "_temp"
            / "Repo-Consolidation"
            / transaction
            / "workspace-root-rollback"
            / "managed-root-before-promotion"
        )
        rollback_quarantine.parent.mkdir(parents=True, exist_ok=True)
        if os.path.lexists(rollback_quarantine):
            raise RecoveryError(
                f"Workspace rollback quarantine exists: {rollback_quarantine}"
            )
        guarded_replace(rollback_root, rollback_quarantine)
        fsync_directory(rollback_quarantine.parent)
        final_journal = report_dir / "workspace-root-swap-journal.json"
        journal.update(
            {
                "status": "promoted-and-proved",
                "priorManagedRootDigest": prior_managed_digest,
                "priorManagedRootQuarantine": display_path(rollback_quarantine),
            }
        )
        write_fsynced_json(journal_path, journal)
        guarded_replace(journal_path, final_journal)
        fsync_directory(final_journal.parent)
        proof_references: list[WorkspaceRootProofReference] = []
        for row, requirement in zip(final_rows, ordered, strict=True):
            (
                manifest_path,
                manifest_sha256,
                manifest,
                variants,
                evidence_only,
            ) = build_workspace_consumer_manifest(
                requirement,
                row,
                managed_root=managed_root,
                report_dir=report_dir,
                transaction=transaction,
                bindings=bindings,
                all_items=all_items,
            )
            runner = workspace_runner_proof(requirement, runner_drain_proofs)
            if runner is None:
                raise RecoveryError(
                    f"Consumer-compatible workspace proof requires runner drain: "
                    f"{requirement.cleanup_root}"
                )
            proof_path = (
                report_dir
                / "workspace-roots"
                / str(row["sourceId"])
                / "workspace-root-proof.json"
            )
            proof_payload = {
                "format": 1,
                "proofKind": WORKSPACE_ROOT_PROOF_KIND,
                "status": WORKSPACE_ROOT_PROOF_STATUS,
                "transaction": transaction,
                "sourceMapSHA256": bindings.source_map_sha256,
                "githubAccountsSHA256": bindings.github_accounts_sha256,
                "repositoryIdentitiesSHA256": bindings.repository_identities_sha256,
                "cleanupRoot": display_path(requirement.cleanup_root),
                "canonicalRoot": display_path(managed_root),
                "sourceIdentity": {
                    "path": display_path(requirement.cleanup_root),
                    "device": row["sourceDevice"],
                    "inode": row["sourceInode"],
                    "treeAlgorithm": TREE_ALGORITHM,
                    "treeDigest": manifest["sourceTreeDigest"],
                    "entryCount": manifest["entryCount"],
                    "ephemeralFsmonitorSockets": manifest[
                        "ephemeralFsmonitorSockets"
                    ],
                    "gitRootCount": len(manifest["gitRoots"]),
                },
                "manifest": {
                    "format": 1,
                    "path": display_path(manifest_path.relative_to(report_dir)),
                    "sha256": manifest_sha256,
                    "entryCount": manifest["entryCount"],
                    "treeDigest": manifest["sourceTreeDigest"],
                    "gitRootCount": len(manifest["gitRoots"]),
                },
                "projectLaneExclusions": sorted(
                    row["mappedExclusions"], key=os.fsencode
                ),
                "destinationVariantRelativePaths": variants,
                "evidenceOnlyRelativePaths": evidence_only,
                "destinationVariantPolicy": WORKSPACE_DESTINATION_VARIANT_POLICY,
                "runnerDrainBinding": {
                    "proofKind": RUNNER_DRAIN_PROOF_KIND,
                    "drainTransaction": runner.drain_transaction,
                    "receiptSHA256": runner.receipt_sha256,
                    "cleanupRoot": display_path(requirement.cleanup_root),
                    "sourceRuntimeRoot": display_path(
                        requirement.cleanup_root / "Runtime"
                    ),
                    "canonicalRuntimeRoot": display_path(managed_root / "Runtime"),
                },
                "managedVolumeIdentity": contract_volume_identity(
                    managed_root / "_temp"
                ),
            }
            write_fsynced_json(proof_path, proof_payload)
            proof_references.append(
                WorkspaceRootProofReference(
                    path=proof_path,
                    sha256=stable_file_hash(proof_path)[0],
                    cleanup_root=display_path(requirement.cleanup_root),
                    manifest_sha256=manifest_sha256,
                    journal=final_journal,
                )
            )
        state = WorkspaceRootSwapState(
            proofs=tuple(proof_references),
            transaction=transaction,
            managed_root=managed_root,
            rollback_root=rollback_quarantine,
            sibling_transaction_root=sibling_root,
            journal=final_journal,
            managed_volume=managed_volume,
        )
        return state
    except Exception as error:
        if promoted:
            if state is None:
                rollback_candidate = rollback_root
                quarantined_candidate = (
                    managed_root
                    / "_temp"
                    / "Repo-Consolidation"
                    / transaction
                    / "workspace-root-rollback"
                    / "managed-root-before-promotion"
                )
                if os.path.lexists(quarantined_candidate):
                    rollback_candidate = quarantined_candidate
                state = WorkspaceRootSwapState(
                    proofs=(),
                    transaction=transaction,
                    managed_root=managed_root,
                    rollback_root=rollback_candidate,
                    sibling_transaction_root=sibling_root,
                    journal=journal_path,
                    managed_volume=managed_volume,
                )
            try:
                rollback_workspace_root_swap(state, reason=str(error))
            except Exception as rollback_error:
                raise RecoveryError(
                    f"{error}; workspace-root rollback failed: {rollback_error}"
                ) from error
        raise


def verify_runtime_sources_before_retirement(
    all_items: Sequence[PreparedMapping],
    *,
    runner_drain_proofs: dict[str, RunnerDrainProof],
    group_results: Sequence[DestinationGroupResult],
    transaction_temp: Path,
    bindings: ContractBindings,
    report_dir: Path,
    transaction: str,
    plan_sha256: str,
) -> tuple[Path | None, str]:
    unique_proofs = {
        proof.receipt_sha256: proof for proof in runner_drain_proofs.values()
    }
    roots_by_source: dict[str, tuple[RunnerDrainProof, RunnerDrainRootProof]] = {}
    for proof in unique_proofs.values():
        for root in proof.roots:
            key = display_path(root.source_runtime_root)
            if key in roots_by_source:
                raise RecoveryError(f"Duplicate whole-Runtime proof root: {key}")
            roots_by_source[key] = (proof, root)
    if not roots_by_source:
        return None, ""
    records: list[dict[str, object]] = []
    for root_key in sorted(roots_by_source, key=os.fsencode):
        proof, root = roots_by_source[root_key]
        revalidate_runner_drain_proof(proof)
        runtime_items = [
            item
            for item in all_items
            if lexical_path_within(item.mapping.source, root.source_runtime_root)
        ]
        for item in runtime_items:
            if not item.git.final_group_fsck_verified:
                raise RecoveryError(
                    f"Runtime mapping lacks a destination-group final fsck: {item.mapping.source}"
                )
            group = next(
                (candidate for candidate in group_results if item in candidate.prepared),
                None,
            )
            if group is None or not group.group_receipt_sha256:
                raise RecoveryError(
                    f"Runtime mapping lacks a destination-group proof: {item.mapping.source}"
                )

        source_records_before, source_digest_before, source_sockets_before = (
            contract_scan_tree(root.source_runtime_root, exclude_top_git=False)
        )
        if source_sockets_before:
            raise RecoveryError(
                f"Drained Runtime still contains fsmonitor sockets: {root.source_runtime_root}"
            )
        evidence_parent = (
            transaction_temp
            / "runtime-whole-root-evidence"
            / hashlib.sha256(os.fsencode(root_key)).hexdigest()[:16]
        )
        evidence_root = evidence_parent / "source-runtime"
        if os.path.lexists(evidence_root):
            raise RecoveryError(f"Whole-Runtime evidence already exists: {evidence_root}")
        evidence_digest_internal = copy_exact_verified(
            root.source_runtime_root,
            evidence_root,
            evidence_parent,
        )
        evidence_records, evidence_digest, evidence_sockets = contract_scan_tree(
            evidence_root, exclude_top_git=False
        )
        if evidence_sockets:
            raise RecoveryError(
                f"Whole-Runtime evidence contains fsmonitor sockets: {evidence_root}"
            )
        source_records_after, source_digest_after, source_sockets_after = (
            contract_scan_tree(root.source_runtime_root, exclude_top_git=False)
        )
        if source_sockets_after:
            raise RecoveryError(
                f"Runtime acquired fsmonitor sockets during capture: {root.source_runtime_root}"
            )
        if (
            source_digest_before != source_digest_after
            or source_digest_after != evidence_digest
            or source_records_before != source_records_after
            or source_records_after != evidence_records
        ):
            raise RecoveryError(
                f"Whole-Runtime source changed or was not represented exactly: "
                f"{root.source_runtime_root}"
            )
        revalidate_runner_drain_proof(proof)

        canonical_exclusions: tuple[str, ...] = ()
        if lexical_path_within(report_dir, root.canonical_runtime_root):
            canonical_exclusions = (
                report_dir.relative_to(root.canonical_runtime_root).as_posix(),
            )
        canonical_records, canonical_digest, canonical_sockets = contract_scan_tree(
            root.canonical_runtime_root,
            exclude_top_git=False,
            excluded_relative_paths=canonical_exclusions,
        )
        if canonical_sockets:
            raise RecoveryError(
                f"Canonical Runtime contains active fsmonitor sockets: "
                f"{root.canonical_runtime_root}"
            )
        owner_lanes: set[str] = set()
        for row in source_records_after:
            relative = str(row["relativePath"])
            if relative == ".":
                continue
            parts = PurePosixPath(relative).parts
            for index in range(len(parts) - 1):
                if parts[index] in {"Repos", "Runners"}:
                    owner_lanes.add("/".join(parts[: index + 2]))
                    break
        records.append(
            {
                "cleanupRoot": display_path(root.cleanup_root),
                "sourceRuntimeRoot": root_key,
                "canonicalRuntimeRoot": display_path(root.canonical_runtime_root),
                "runnerDrainReceipt": display_path(proof.receipt),
                "runnerDrainReceiptSHA256": proof.receipt_sha256,
                "sourceTreeAlgorithm": TREE_ALGORITHM,
                "sourceTreeDigest": source_digest_after,
                "sourceEntryCount": len(source_records_after),
                "evidencePath": display_path(evidence_root),
                "evidenceTreeDigest": evidence_digest,
                "evidenceEntryCount": len(evidence_records),
                "internalCopyProofDigest": evidence_digest_internal,
                "canonicalTreeDigest": canonical_digest,
                "canonicalEntryCount": len(canonical_records),
                "canonicalExcludedTransactionPaths": list(canonical_exclusions),
                "ownerLanes": sorted(owner_lanes, key=os.fsencode),
                "mappedSourceIds": [item.source_id for item in runtime_items],
                "destinationGroupProofSHA256s": sorted(
                    {
                        group.group_receipt_sha256
                        for group in group_results
                        if any(item in group.prepared for item in runtime_items)
                    }
                ),
                "classification": "every-entry-byte-exact-managed-evidence",
                "status": "source-and-managed-evidence-exact-canonical-runtime-verified",
            }
        )
    proof_path = report_dir / "runtime-final-canonical-proof.json"
    write_fsynced_json(
        proof_path,
        {
            "format": 1,
            "transaction": transaction,
            "planSha256": plan_sha256,
            "sourceMapSHA256": bindings.source_map_sha256,
            "githubAccountsSHA256": bindings.github_accounts_sha256,
            "repositoryIdentitiesSHA256": bindings.repository_identities_sha256,
            "status": "all-runtime-roots-quiesced-evidence-exact-canonical-verified",
            "runnerDrainProofs": {
                key: runner_drain_proof_to_json(value)
                for key, value in sorted(runner_drain_proofs.items())
            },
            "rootCount": len(records),
            "roots": records,
        },
    )
    proof_sha256, _proof_stat = stable_file_hash(proof_path)
    return proof_path, proof_sha256


def execute_global_retirement(
    group_results: Sequence[DestinationGroupResult],
    *,
    managed_root: Path,
    stage1_root: Path,
    compat_root: Path | None,
    retire_compat_projects: bool,
    transaction: str,
    transaction_temp: Path,
    report_dir: Path,
    plan_sha256: str,
    bindings: ContractBindings,
    owner_account_bindings: dict[str, str],
    repository_identities: dict[str, dict[str, str]],
    runner_drain_proofs: dict[str, RunnerDrainProof],
    workspace_root_requirements: Sequence[WorkspaceRootRequirement],
) -> list[RetirementMove]:
    clear_verification_caches()
    all_items = [item for group in group_results for item in group.prepared]
    revalidate_runtime_roots_for_sources(
        [item.mapping.source for item in all_items], runner_drain_proofs
    )
    runtime_final_proof: Path | None = None
    runtime_final_proof_sha256 = ""
    workspace_swap_state: WorkspaceRootSwapState | None = None
    workspace_cleanup_roots = [
        requirement.cleanup_root for requirement in workspace_root_requirements
    ]
    by_source = {display_path(item.mapping.source): item for item in all_items}
    broad_roots: list[tuple[Path, str]] = []
    for staged_root in sorted(managed_root.glob("*.csa-iem-stage-*")):
        if staged_root.is_dir() and not staged_root.is_symlink():
            broad_roots.append((staged_root, "managed-root-stage"))
    runtime_repos = managed_root / "Runtime" / "Repos"
    if runtime_repos.is_dir() and not runtime_repos.is_symlink():
        broad_roots.append((runtime_repos, "runtime-repositories"))
    for item in all_items:
        if item.mapping.kind == "runtime-runner-worktree":
            work_root = item.mapping.source.parents[1]
            if work_root.is_dir() and not work_root.is_symlink():
                broad_roots.append((work_root, "runtime-runner-worktree-root"))
    if stage1_root.is_dir() and not stage1_root.is_symlink():
        broad_roots.append((stage1_root, "stage1-root"))
    if retire_compat_projects and compat_root and compat_root.is_dir() and not compat_root.is_symlink():
        top_roots = {
            compat_root / item.mapping.source.relative_to(compat_root).parts[0]
            for item in all_items
            if item.mapping.kind == "explicit-compat-source"
            and lexical_path_within(item.mapping.source, compat_root)
            and item.mapping.source != compat_root
        }
        broad_roots.extend((root, "compatibility-project-root") for root in top_roots if root.is_dir())

    unique_broad: list[tuple[Path, str]] = []
    for root, kind in sorted(
        {(Path(os.path.abspath(root)), kind) for root, kind in broad_roots},
        key=lambda item: len(item[0].parts),
    ):
        if any(lexical_path_within(root, existing) for existing, _kind in unique_broad):
            continue
        if any(lexical_path_within(root, cleanup_root) for cleanup_root in workspace_cleanup_roots):
            continue
        unique_broad.append((root, kind))

    retirement_root = transaction_temp / "source-retirement"
    moves: list[RetirementMove] = []
    inventories: list[dict[str, object]] = []
    for root, kind in unique_broad:
        covered_items = [
            item for item in all_items if lexical_path_within(item.mapping.source, root)
        ]
        ineligible = [
            item.mapping.source
            for item in covered_items
            if not mapping_retirement_authorized(item.mapping)
        ]
        if ineligible:
            raise RecoveryError(
                f"Whole-root retirement would move retained source(s) under {root}: "
                + ", ".join(display_path(path) for path in ineligible[:20])
            )
        inventory = inventory_retirement_root(
            root,
            covered_items,
            report_dir / "retirement-inventories" / f"{safe_ref_component(root.name)}-{hashlib.sha256(os.fsencode(display_path(root))).hexdigest()[:12]}.jsonl",
        )
        inventories.append(inventory)
        target = retirement_root / kind / f"{safe_ref_component(root.name)}-{hashlib.sha256(os.fsencode(display_path(root))).hexdigest()[:12]}"
        moves.append(
            RetirementMove(
                source=root,
                target=target,
                kind=kind,
                source_ids=[item.source_id for item in covered_items],
            )
        )

    for item in all_items:
        mapping = item.mapping
        if not mapping_retirement_authorized(mapping):
            continue
        if any(
            lexical_path_within(mapping.source, cleanup_root)
            for cleanup_root in workspace_cleanup_roots
        ):
            continue
        if any(lexical_path_within(mapping.source, move.source) for move in moves):
            continue
        if not os.path.lexists(mapping.source):
            raise RecoveryError(f"Retirement source disappeared before preflight: {mapping.source}")
        target = retirement_root / "individual-sources" / item.source_id / mapping.source.name
        moves.append(
            RetirementMove(
                source=mapping.source,
                target=target,
                kind="individual-reviewed-source",
                source_ids=[item.source_id],
            )
        )

    if compat_root and compat_root.is_dir():
        for link in sorted(compat_root.iterdir(), key=lambda item: os.fsencode(item.name)):
            if not link.is_symlink():
                continue
            target_text = os.readlink(link)
            resolved = Path(target_text)
            if not resolved.is_absolute():
                resolved = link.parent / resolved
            if lexical_path_within(Path(os.path.abspath(resolved)), stage1_root):
                moves.append(
                    RetirementMove(
                        source=link,
                        target=retirement_root / "compatibility-links" / link.name,
                        kind="compatibility-link",
                        source_ids=[],
                    )
                )

    source_roots = [move.source for move in moves]
    for index, left in enumerate(source_roots):
        for right in source_roots[index + 1 :]:
            if lexical_path_within(left, right) or lexical_path_within(right, left):
                raise RecoveryError(f"Retirement move roots overlap: {left} / {right}")
    blockers = process_blockers_for_retirement(
        [*source_roots, managed_root, *workspace_cleanup_roots]
    )
    if blockers:
        raise RecoveryError("Global retirement process preflight failed: " + "; ".join(blockers[:20]))

    managed_volume = volume_identity(managed_root)
    for move in moves:
        if not os.path.lexists(move.source):
            raise RecoveryError(f"Retirement source is unavailable: {move.source}")
        if os.path.lexists(move.target):
            raise RecoveryError(f"Retirement target already exists: {move.target}")
        move.target.parent.mkdir(parents=True, exist_ok=True)
        revalidate_volume_identity(managed_volume, move.target.parent)
        source_volume = volume_identity(move.source)
        if source_volume != managed_volume:
            raise RecoveryError(
                f"Retirement source is not on the managed volume: {move.source}; "
                f"source={dataclasses.asdict(source_volume)}, managed={dataclasses.asdict(managed_volume)}"
            )
        source_stat = move.source.lstat()
        move.device = source_stat.st_dev
        move.inode = source_stat.st_ino

    journal_path = report_dir / "source-retirement-journal.json"
    journal: dict[str, object] = {
        "format": 2,
        "transaction": transaction,
        "planSha256": plan_sha256,
        "status": "prechecked",
        "managedVolumeIdentity": dataclasses.asdict(managed_volume),
        "inventories": inventories,
        "runnerDrainProofs": {
            key: runner_drain_proof_to_json(value)
            for key, value in sorted(runner_drain_proofs.items())
        },
        "runtimeFinalProof": display_path(runtime_final_proof)
        if runtime_final_proof
        else "",
        "runtimeFinalProofSha256": runtime_final_proof_sha256,
        "moves": [dataclasses.asdict(move) for move in moves],
    }
    write_fsynced_json(journal_path, journal)
    receipt_root = report_dir / "receipts" / "source-retirement"
    partial_receipts = receipt_root.with_name(".source-retirement.partial")
    if os.path.lexists(receipt_root) or os.path.lexists(partial_receipts):
        raise RecoveryError(f"Source-retirement receipt lane already exists: {receipt_root}")
    transaction_success = report_dir / "transaction-success.json"
    if os.path.lexists(transaction_success):
        raise RecoveryError(f"Transaction-success receipt already exists: {transaction_success}")
    failed_receipt_root = report_dir / "failed-receipts" / "source-retirement"
    moved: list[RetirementMove] = []
    try:
        revalidate_volume_identity(managed_volume, managed_root)
        revalidate_runtime_roots_for_sources(
            [item.mapping.source for item in all_items], runner_drain_proofs
        )
        for move in moves:
            revalidate_runtime_roots_for_sources([move.source], runner_drain_proofs)
            revalidate_volume_identity(managed_volume, move.source)
            revalidate_volume_identity(managed_volume, move.target.parent)
            guarded_replace(move.source, move.target)
            fsync_directory(move.source.parent)
            fsync_directory(move.target.parent)
            target_stat = move.target.lstat()
            if (target_stat.st_dev, target_stat.st_ino) != (move.device, move.inode):
                raise RecoveryError(f"Retirement rename identity changed: {move.source} -> {move.target}")
            move.status = "moved-final-verification-pending"
            moved.append(move)
            journal["moves"] = [dataclasses.asdict(value) for value in moves]
            write_fsynced_json(journal_path, journal)

        for item in all_items:
            candidate = retirement_candidate_for_mapping(item, moves)
            if candidate == item.mapping.source:
                continue
            source_report = report_dir / "sources" / item.source_id
            if item.evidence_only_fragment:
                snapshot = item.mapping.destination / item.git.component_snapshots[0].snapshot_relative
                stats_result = write_exact_snapshot_manifest(
                    candidate,
                    snapshot,
                    source_report / "filesystem-manifest-retirement.jsonl",
                    excluded_top_level=set(),
                )
            else:
                stats_result = tree_merge_or_verify(
                    candidate,
                    item.mapping.destination,
                    item.mapping.destination / item.variant_relative,
                    source_report / "conflicts-retirement.jsonl",
                    merge=False,
                    excluded_relative_paths=item.mapping.excluded_relative_paths,
                    activate_source_only=item.activation_allowed,
                    manifest_path=source_report / "filesystem-manifest-retirement.jsonl",
                    conflict_policy=item.mapping.conflict_policy,
                    recovery_only_paths=item.mapping.recovery_only_paths,
                    pre_promotion_root=item.mapping.destination / item.pre_promotion_relative
                    if item.pre_promotion_relative
                    else item.mapping.destination / RECOVERY_DIR_NAME / "unused-pre-promotion-proof",
                )
            if stats_result.root_digest != item.tree.root_digest:
                raise RecoveryError(f"Retired source verification changed: {item.mapping.source}")
            verify_source_git_unchanged(candidate, item.git, item.mapping.destination)
            verify_git_evidence(item.mapping.destination, item.git)

        workspace_swap_state = assemble_and_promote_workspace_roots(
            workspace_root_requirements,
            all_items,
            group_results,
            managed_root=managed_root,
            report_dir=report_dir,
            transaction=transaction,
            plan_sha256=plan_sha256,
            bindings=bindings,
            runner_drain_proofs=runner_drain_proofs,
        )
        runtime_final_proof, runtime_final_proof_sha256 = (
            verify_runtime_sources_before_retirement(
                all_items,
                runner_drain_proofs=runner_drain_proofs,
                group_results=group_results,
                transaction_temp=transaction_temp,
                bindings=bindings,
                report_dir=report_dir,
                transaction=transaction,
                plan_sha256=plan_sha256,
            )
        )
        for move in moves:
            move.status = "retired-to-managed-temp-verified"
        journal["status"] = "global-retirement-proof-final-receipt-pending"
        journal["moves"] = [dataclasses.asdict(value) for value in moves]
        write_fsynced_json(journal_path, journal)
        final_receipts = finalize_source_retirement_receipts(
            all_items,
            moves,
            group_results,
            receipt_root=receipt_root,
            partial_receipts=partial_receipts,
            transaction=transaction,
            journal_path=journal_path,
            managed_volume=managed_volume,
            bindings=bindings,
            runner_drain_proofs=runner_drain_proofs,
            runtime_final_proof=runtime_final_proof,
            runtime_final_proof_sha256=runtime_final_proof_sha256,
            workspace_root_proofs=(
                list(workspace_swap_state.proofs) if workspace_swap_state else []
            ),
        )
        journal["status"] = "global-retirement-final"
        journal["finalMappingReceipts"] = [display_path(path) for path in final_receipts]
        write_fsynced_json(journal_path, journal)
        receipt_set_rows = [
            {
                "path": display_path(path.relative_to(report_dir)),
                "sha256": stable_file_hash(path)[0],
            }
            for path in sorted(final_receipts, key=lambda value: os.fsencode(display_path(value)))
        ]
        unique_runner_proofs = {
            proof.receipt_sha256: proof for proof in runner_drain_proofs.values()
        }
        if len(unique_runner_proofs) > 1:
            raise RecoveryError("Final marker cannot bind more than one runner-drain receipt")
        if workspace_root_requirements and workspace_swap_state is None:
            raise RecoveryError(
                "Final marker cannot omit the required whole-workspace proof"
            )
        workspace_proof_rows = sorted(
            [
                {
                    "cleanupRoot": reference.cleanup_root,
                    "path": display_path(reference.path.relative_to(report_dir)),
                    "sha256": reference.sha256,
                    "manifestSHA256": reference.manifest_sha256,
                }
                for reference in (
                    workspace_swap_state.proofs if workspace_swap_state else ()
                )
            ],
            key=lambda value: (
                os.fsencode(value["cleanupRoot"]),
                os.fsencode(value["path"]),
            ),
        )
        if len(workspace_proof_rows) != len(workspace_root_requirements):
            raise RecoveryError(
                "Final marker workspace-root proof count differs from required roots"
            )
        marker: dict[str, object] = {
            "format": 1,
            "status": "complete",
            "transaction": transaction,
            "sourceMapSHA256": bindings.source_map_sha256,
            "githubAccountsSHA256": bindings.github_accounts_sha256,
            "repositoryIdentitiesSHA256": bindings.repository_identities_sha256,
            "receiptFiles": [row["path"] for row in receipt_set_rows],
            "mappingCount": len(bindings.mapping_sha256_by_source),
            "receiptCount": len(final_receipts),
            "receiptSetSHA256": contract_digest(receipt_set_rows),
            "destinationGroupProofSHA256s": sorted(
                {group.group_receipt_sha256 for group in group_results}
            ),
            "workspaceRootProofKind": WORKSPACE_ROOT_PROOF_KIND,
            "workspaceRootProofs": workspace_proof_rows,
            "workspaceRootProofCount": len(workspace_proof_rows),
            "workspaceRootProofSetSHA256": contract_digest(workspace_proof_rows),
            "runtimeFinalProof": display_path(runtime_final_proof)
            if runtime_final_proof
            else "",
            "runtimeFinalProofSha256": runtime_final_proof_sha256,
            "permanentDeletionPerformed": False,
        }
        if unique_runner_proofs:
            proof = next(iter(unique_runner_proofs.values()))
            marker.update(
                {
                    "runnerDrainProofKind": RUNNER_DRAIN_PROOF_KIND,
                    "runnerDrainTransaction": proof.drain_transaction,
                    "runnerDrainReceiptSHA256": proof.receipt_sha256,
                    "runnerDrainRootCount": len(proof.roots),
                }
            )
        write_fsynced_json(
            transaction_success,
            marker,
        )
    except Exception as error:
        rollback_errors: list[str] = []
        if workspace_swap_state is not None and not workspace_swap_state.rolled_back:
            try:
                rollback_workspace_root_swap(
                    workspace_swap_state,
                    reason=f"global retirement failed after workspace promotion: {error}",
                )
            except Exception as workspace_rollback_error:
                rollback_errors.append(
                    f"workspace-root rollback failed: {workspace_rollback_error}"
                )
        for candidate, label in (
            (transaction_success, "transaction-success.json"),
            (receipt_root, "final"),
            (partial_receipts, "partial"),
        ):
            try:
                quarantine_failed_receipt_lane(
                    candidate,
                    failure_root=failed_receipt_root,
                    label=label,
                )
            except Exception as receipt_error:
                rollback_errors.append(
                    f"retirement receipt quarantine failed for {candidate}: {receipt_error}"
                )
        for move in reversed(moved):
            try:
                if os.path.lexists(move.target) and not os.path.lexists(move.source):
                    move.source.parent.mkdir(parents=True, exist_ok=True)
                    guarded_replace(move.target, move.source)
                    fsync_directory(move.source.parent)
                    fsync_directory(move.target.parent)
                move.status = "rolled-back"
            except Exception as rollback:
                move.status = "rollback-failed"
                rollback_errors.append(f"{move.target} -> {move.source}: {rollback}")
        journal["status"] = "rolled-back" if not rollback_errors else "rollback-failed"
        journal["error"] = str(error)
        journal["rollbackErrors"] = rollback_errors
        journal["moves"] = [dataclasses.asdict(value) for value in moves]
        write_fsynced_json(journal_path, journal)
        if rollback_errors:
            raise RecoveryError(f"{error}; retirement rollback failed: {rollback_errors}") from error
        raise
    return moves


def audit_final_state(
    canonical_root: Path,
    canonical_repos_root: Path,
    managed_root: Path,
    stage1_root: Path,
    compat_root: Path | None,
) -> dict[str, object]:
    stage_duplicates = sorted(
        display_path(path)
        for owner_root in canonical_repos_root.iterdir()
        if owner_root.is_dir() and not owner_root.is_symlink()
        for path in owner_root.iterdir()
        if path.is_dir() and not path.is_symlink() and STAGE_SUFFIX_RE.match(path.name)
    )
    canonical_directories = sorted(
        display_path(path)
        for owner_root in canonical_repos_root.iterdir()
        if owner_root.is_dir() and not owner_root.is_symlink()
        for path in owner_root.iterdir()
        if path.is_dir() and not path.is_symlink() and not STAGE_SUFFIX_RE.match(path.name)
    )
    identity_errors = validate_canonical_identity_groups(canonical_repos_root)
    managed_stage_artifacts = sorted(
        display_path(path)
        for path in managed_root.iterdir()
        if (path.is_dir() or path.is_symlink()) and STAGE_SUFFIX_RE.match(path.name)
    )
    runtime_mirrors = sorted(
        display_path(path)
        for owner_root in (managed_root / "Runtime" / "Repos").iterdir()
        if owner_root.is_dir() and not owner_root.is_symlink()
        for path in owner_root.iterdir()
        if path.is_dir() and not path.is_symlink()
    ) if (managed_root / "Runtime" / "Repos").is_dir() else []
    runner_worktrees = sorted(
        display_path(dot_git.parent)
        for owner_root in (managed_root / "Runtime" / "Runners").iterdir()
        if owner_root.is_dir() and not owner_root.is_symlink()
        for dot_git in owner_root.glob("*/_work/*/*/.git")
    ) if (managed_root / "Runtime" / "Runners").is_dir() else []
    compatibility_entries = sorted(
        display_path(path)
        for path in compat_root.iterdir()
        if path.name != "_temp"
    ) if compat_root and compat_root.is_dir() else []
    return {
        "canonicalDirectoryCount": len(canonical_directories),
        "canonicalDirectories": canonical_directories,
        "stageDuplicateCount": len(stage_duplicates),
        "stageDuplicates": stage_duplicates,
        "identityErrors": identity_errors,
        "managedStageArtifactCount": len(managed_stage_artifacts),
        "managedStageArtifacts": managed_stage_artifacts,
        "runtimeMirrorCount": len(runtime_mirrors),
        "runtimeMirrors": runtime_mirrors,
        "runtimeRunnerWorktreeCount": len(runner_worktrees),
        "runtimeRunnerWorktrees": runner_worktrees,
        "compatibilityEntryCount": len(compatibility_entries),
        "compatibilityEntries": compatibility_entries,
        "stage1RootExists": os.path.lexists(stage1_root),
    }


def write_final_report(
    report_dir: Path,
    transaction: str,
    results: Sequence[ProcessResult],
    failures: Sequence[ProcessResult],
    audit: dict[str, object],
    compatibility_links_removed: int,
) -> Path:
    completed = sum(result.status == "completed" for result in results)
    conflict_files = sum((result.tree.conflicts if result.tree else 0) for result in results)
    metadata_conflicts = sum((result.tree.metadata_conflicts if result.tree else 0) for result in results)
    added = sum((result.tree.added if result.tree else 0) for result in results)
    files = sum((result.tree.files if result.tree else 0) for result in results)
    byte_count = sum((result.tree.bytes if result.tree else 0) for result in results)
    lines = [
        "# CSA-iEM Repository Consolidation Final Report",
        "",
        f"- Transaction: `{transaction}`",
        f"- Source copies completed: **{completed}**",
        f"- Source copies failed/retained: **{len(failures)}**",
        f"- Deep-audited regular files: **{files}**",
        f"- Deep-audited bytes: **{byte_count}**",
        f"- Source entries newly represented in active or recovery trees: **{added}**",
        f"- Content/type conflicts preserved: **{conflict_files}**",
        f"- Metadata conflicts preserved: **{metadata_conflicts}**",
        f"- Compatibility links retired to managed temp: **{compatibility_links_removed}**",
        f"- Canonical project folders: **{audit['canonicalDirectoryCount']}**",
        f"- Remaining `.csa-iem-stage-*` folders: **{audit['stageDuplicateCount']}**",
        f"- Remaining managed-root staging artifacts: **{audit['managedStageArtifactCount']}**",
        f"- Remaining active Runtime repository mirrors: **{audit['runtimeMirrorCount']}**",
        f"- Remaining active Runtime runner worktrees: **{audit['runtimeRunnerWorktreeCount']}**",
        f"- Remaining compatibility-root entries outside `_temp`: **{audit['compatibilityEntryCount']}**",
        f"- Stage 1 root still exists: **{audit['stage1RootExists']}**",
        "",
        "| Status | Kind | Source | Canonical destination | Git relation | Detail |",
        "|---|---|---|---|---|---|",
    ]
    for result in [*results, *failures]:
        lines.append(
            f"| {result.status} | {result.mapping.kind} | `{result.mapping.source}` | "
            f"`{result.mapping.destination}` | "
            f"{result.git.history_relation if result.git else 'not-applicable'} | "
            f"{result.detail.replace('|', '/')} |"
        )
    if audit["identityErrors"]:
        lines.extend(["", "## Canonical identity errors", ""])
        lines.extend(f"- {error}" for error in audit["identityErrors"])
    lines.append("")
    report_path = report_dir / "final.md"
    report_path.write_text("\n".join(lines), encoding="utf-8")
    write_json(report_dir / "final-audit.json", audit)
    return report_path


def self_test_require(condition: bool, message: str) -> None:
    if not condition:
        raise RecoveryError(f"self-test failed: {message}")


def run_self_test() -> int:
    """Exercise safety invariants only inside one disposable fixture tree."""
    with tempfile.TemporaryDirectory(prefix="csa-iem-recovery-self-test-") as temporary:
        fixture = Path(temporary)

        # Persistent checksum indexes may skip a repeat file read only while
        # the complete mutation-sensitive stat identity is unchanged.
        configure_persistent_hash_index(
            fixture / "indexes" / "stable-hash-v1.sqlite3",
            "fixture-transaction",
        )
        indexed_file = fixture / "indexed.bin"
        indexed_file.write_bytes(b"first-index-value")
        first_digest, _first_stat = stable_file_hash(indexed_file)
        clear_verification_caches()
        hits_before = _PERSISTENT_HASH_INDEX_STATS["hits"]
        repeated_digest, _repeated_stat = stable_file_hash(indexed_file)
        self_test_require(
            repeated_digest == first_digest
            and _PERSISTENT_HASH_INDEX_STATS["hits"] == hits_before + 1,
            "persistent checksum index did not serve an unchanged stat-bound file",
        )
        indexed_file.write_bytes(b"other-index-value")
        clear_verification_caches()
        changed_digest, _changed_stat = stable_file_hash(indexed_file)
        self_test_require(
            changed_digest != first_digest,
            "persistent checksum index reused a digest after file mutation",
        )
        close_persistent_hash_index()

        # A nested non-Git folder must not inherit a parent repository identity.
        parent_repository = fixture / "parent-repository"
        parent_repository.mkdir()
        run_command(["git", "-C", parent_repository, "init", "-q"])
        nested_non_git = parent_repository / "non-git-project"
        nested_non_git.mkdir()
        self_test_require(
            resolve_git_dir(nested_non_git) is None,
            "nested non-Git source inherited its parent Git repository",
        )

        # Fail-closed routing: no old source-only or conflicting bytes activate.
        old_source = fixture / "old-source"
        old_destination = fixture / "old-destination"
        old_source.mkdir()
        old_destination.mkdir()
        (old_source / "source-only.txt").write_bytes(b"old-only\n")
        (old_source / "conflict.txt").write_bytes(b"old-source\n")
        (old_source / "recovery-only").mkdir()
        (old_source / "recovery-only" / "secret.txt").write_bytes(b"evidence\n")
        (old_destination / "conflict.txt").write_bytes(b"canonical\n")
        old_variant = (
            old_destination / RECOVERY_DIR_NAME / "variants" / "fixture-old" / "files"
        )
        old_stats = tree_merge_or_verify(
            old_source,
            old_destination,
            old_variant,
            fixture / "old-conflicts.jsonl",
            merge=True,
            activate_source_only=False,
            recovery_only_paths=("recovery-only",),
            manifest_path=fixture / "old-manifest.jsonl",
        )
        self_test_require(
            not os.path.lexists(old_destination / "source-only.txt"),
            "evidence-only source activated a source-only path",
        )
        self_test_require(
            (old_variant / "source-only.txt").read_bytes() == b"old-only\n",
            "source-only evidence variant is missing",
        )
        self_test_require(
            (old_destination / "conflict.txt").read_bytes() == b"canonical\n",
            "evidence-only source overwrote canonical content",
        )
        self_test_require(
            (old_variant / "conflict.txt").read_bytes() == b"old-source\n",
            "conflicting old source was not preserved",
        )
        old_verify = tree_merge_or_verify(
            old_source,
            old_destination,
            old_variant,
            fixture / "old-conflicts-verify.jsonl",
            merge=False,
            activate_source_only=False,
            recovery_only_paths=("recovery-only",),
            manifest_path=fixture / "old-manifest-verify.jsonl",
        )
        self_test_require(
            old_verify.root_digest == old_stats.root_digest,
            "old-source final representation digest changed",
        )

        # Reviewed source-wins must first preserve prior canonical bytes, while
        # recoveryOnlyPaths remain evidence-only even under source-wins.
        active_source = fixture / "active-source"
        active_destination = fixture / "active-destination"
        active_source.mkdir()
        active_destination.mkdir()
        (active_source / "tracked.txt").write_bytes(b"reviewed-current\n")
        (active_source / "private-artifact.txt").write_bytes(b"recovery-only\n")
        (active_destination / "tracked.txt").write_bytes(b"prior-canonical\n")
        active_variant = (
            active_destination / RECOVERY_DIR_NAME / "variants" / "fixture-active" / "files"
        )
        pre_promotion = (
            active_destination / RECOVERY_DIR_NAME / "pre-promotion" / "fixture-active"
        )
        tree_merge_or_verify(
            active_source,
            active_destination,
            active_variant,
            fixture / "active-conflicts.jsonl",
            merge=True,
            activate_source_only=True,
            conflict_policy="source-wins-after-preserve",
            recovery_only_paths=("private-artifact.txt",),
            pre_promotion_root=pre_promotion,
            manifest_path=fixture / "active-manifest.jsonl",
        )
        self_test_require(
            (active_destination / "tracked.txt").read_bytes() == b"reviewed-current\n",
            "source-wins did not install reviewed source bytes",
        )
        self_test_require(
            (pre_promotion / "tracked.txt").read_bytes() == b"prior-canonical\n",
            "source-wins did not preserve prior canonical bytes",
        )
        self_test_require(
            not os.path.lexists(active_destination / "private-artifact.txt"),
            "recoveryOnlyPath activated under source-wins",
        )
        self_test_require(
            (active_variant / "private-artifact.txt").read_bytes() == b"recovery-only\n",
            "recoveryOnlyPath evidence is missing",
        )

        # Hardlink topology must be represented as hardlinks in recovery.
        hardlink_source = fixture / "hardlink-source"
        hardlink_destination = fixture / "hardlink-destination"
        hardlink_source.mkdir()
        hardlink_destination.mkdir()
        (hardlink_source / "first.bin").write_bytes(b"hardlink-content")
        os.link(hardlink_source / "first.bin", hardlink_source / "second.bin")
        hardlink_variant = (
            hardlink_destination / RECOVERY_DIR_NAME / "variants" / "fixture-hardlink" / "files"
        )
        tree_merge_or_verify(
            hardlink_source,
            hardlink_destination,
            hardlink_variant,
            fixture / "hardlink-conflicts.jsonl",
            merge=True,
            activate_source_only=False,
            manifest_path=fixture / "hardlink-manifest.jsonl",
        )
        first_stat = (hardlink_variant / "first.bin").stat()
        second_stat = (hardlink_variant / "second.bin").stat()
        self_test_require(
            (first_stat.st_dev, first_stat.st_ino)
            == (second_stat.st_dev, second_stat.st_ino),
            "hardlink topology was flattened",
        )

        # Raw Git administration data is snapshotted under recovery and never
        # copied into the active worktree root.
        raw_git = fixture / "raw-git-fragment"
        raw_destination = fixture / "raw-destination"
        raw_destination.mkdir()
        run_command(["git", "init", "--bare", "-q", raw_git])
        run_command(["git", "-C", raw_destination, "init", "-q"])
        raw_evidence, _raw_tree, raw_relative = preserve_evidence_only_git_fragment(
            raw_git,
            raw_destination,
            "fixture-transaction",
            "fixture-raw",
            fixture / "raw-report",
        )
        self_test_require(
            raw_evidence.source_fsck_invocations == 1,
            "raw Git fragment did not run exactly one source fsck",
        )
        self_test_require(
            raw_evidence.pointer_only_evidence and not raw_evidence.git_history_imported,
            "raw Git fragment was treated as imported history",
        )
        self_test_require(
            not os.path.lexists(raw_destination / "HEAD"),
            "raw Git HEAD activated in project root",
        )
        self_test_require(
            (raw_destination / raw_relative / "HEAD").is_file(),
            "raw Git evidence snapshot is missing",
        )
        verify_source_git_unchanged(raw_git, raw_evidence, raw_destination)

        # Linked-worktree evidence must include the .git pointer, worktree Git
        # directory, and common Git directory, then import history once.
        common_repository = fixture / "linked-common"
        common_repository.mkdir()
        run_command(["git", "-C", common_repository, "init", "-q", "-b", "main"])
        run_command(["git", "-C", common_repository, "config", "user.name", "Fixture"])
        run_command(
            ["git", "-C", common_repository, "config", "user.email", "fixture@example.invalid"]
        )
        (common_repository / "tracked.txt").write_bytes(b"base\n")
        run_command(["git", "-C", common_repository, "add", "tracked.txt"])
        run_command(["git", "-C", common_repository, "commit", "-q", "-m", "fixture"])
        linked_worktree = fixture / "linked-worktree"
        run_command(
            [
                "git",
                "-C",
                common_repository,
                "worktree",
                "add",
                "-q",
                "-b",
                "fixture-linked",
                linked_worktree,
            ]
        )
        (linked_worktree / "tracked.txt").write_bytes(b"dirty-linked-worktree\n")
        (linked_worktree / "untracked.txt").write_bytes(b"untracked\n")
        linked_destination = fixture / "linked-destination"
        run_command(["git", "clone", "-q", common_repository, linked_destination])
        linked_evidence = import_and_verify_git(
            linked_worktree,
            linked_destination,
            "fixture-transaction",
            "fixture-linked",
            fixture / "linked-report",
        )
        roles = {snapshot.source_role for snapshot in linked_evidence.component_snapshots}
        self_test_require(
            {"worktree-dot-git", "worktree-git-dir", "common-git-dir"}.issubset(roles),
            f"linked worktree components are incomplete: {sorted(roles)}",
        )
        self_test_require(
            linked_evidence.source_fsck_invocations == 1
            and linked_evidence.git_history_imported
            and not linked_evidence.pointer_only_evidence,
            "linked worktree Git history proof is incorrect",
        )
        verify_source_git_unchanged(
            linked_worktree,
            linked_evidence,
            linked_destination,
        )
        verify_git_evidence(linked_destination, linked_evidence)
        verify_canonical_git_independence(linked_destination)

        # Runner-drain proof parser binds cleanupRoot -> its exact Runtime
        # child -> the exact canonical Runtime.  Live launchctl/process checks
        # are normal-preflight checks and intentionally are not fabricated.
        cleanup_root = fixture / "workspace"
        runtime_root = cleanup_root / "Runtime"
        runtime_root.mkdir(parents=True)
        managed_fixture_root = fixture / "managed"
        canonical_runtime_root = managed_fixture_root / "Runtime"
        canonical_runtime_root.mkdir(parents=True)
        launch_agents = fixture / "LaunchAgents"
        launch_agents.mkdir()
        runner_plist = launch_agents / "fixture.runner.plist"
        runner_plist.write_bytes(b"fixture-plist\n")
        runner_plist_digest, _runner_plist_stat = stable_file_hash(runner_plist)
        critical_root = runtime_root / "Runners" / "Fixture" / "runner-1"
        critical_root.mkdir(parents=True)
        fixture_critical_hashes: dict[str, str] = {}
        for relative_file in sorted(CRITICAL_RUNNER_FILES):
            critical_file = critical_root / relative_file
            critical_file.parent.mkdir(parents=True, exist_ok=True)
            critical_file.write_bytes(f"fixture-{relative_file}\n".encode("utf-8"))
            fixture_critical_hashes[relative_file] = stable_file_hash(critical_file)[0]
        cleanup_stat = cleanup_root.lstat()
        runtime_stat = runtime_root.lstat()
        source_map_digest = "1" * 64
        account_digest = "2" * 64
        identity_digest = "3" * 64
        services = [
            {
                "label": "com.example.fixture-runner",
                "plist": display_path(runner_plist),
                "plistSHA256": runner_plist_digest,
                "loaded": True,
                "listenerActive": True,
                "disabled": False,
                "capturedLaunchPID": 12345,
                "workerActive": False,
            }
        ]
        drain_receipt = (
            managed_fixture_root
            / "_temp"
            / "RepoConsolidation"
            / "RunnerDrain"
            / "fixture-drain"
            / "runner-drain-receipt.json"
        )
        drain_receipt.parent.mkdir(parents=True)
        managed_volume_fixture = contract_volume_identity(managed_fixture_root / "_temp")
        drain_receipt.write_text(
            json.dumps(
                {
                    "format": 1,
                    "proofKind": RUNNER_DRAIN_PROOF_KIND,
                    "status": "quiesced",
                    "transaction": "fixture-transaction",
                    "recoveryTransaction": "fixture-transaction",
                    "drainTransaction": "fixture-drain",
                    "sourceMapSHA256": source_map_digest,
                    "githubAccountsSHA256": account_digest,
                    "repositoryIdentitiesSHA256": identity_digest,
                    "managedEvidenceVolume": managed_volume_fixture,
                    "rootCount": 1,
                    "roots": [
                        {
                            "cleanupRoot": display_path(cleanup_root),
                            "sourceRuntimeRoot": display_path(runtime_root),
                            "canonicalRuntimeRoot": display_path(canonical_runtime_root),
                            "rootIdentity": {
                                "device": cleanup_stat.st_dev,
                                "inode": cleanup_stat.st_ino,
                            },
                            "sourceRuntimeIdentity": {
                                "device": runtime_stat.st_dev,
                                "inode": runtime_stat.st_ino,
                            },
                            "services": services,
                            "serviceCount": 1,
                            "loadedCount": 1,
                            "notLoadedCount": 0,
                            "listenerActiveCount": 1,
                            "workerActiveCount": 0,
                            "criticalHashes": {
                                "Runtime/Runners/Fixture/runner-1": fixture_critical_hashes
                            },
                            "serviceSetSHA256": contract_digest(services),
                            "processReferenceCount": 0,
                            "processReferenceSHA256": contract_digest([]),
                            "afterDrain": {
                                "launchctlLoaded": [
                                    {"label": "com.example.fixture-runner", "loaded": False}
                                ],
                                "allCapturedServicesUnloaded": True,
                                "allCapturedServicesDisabled": True,
                                "listenerActiveCount": 0,
                                "workerActiveCount": 0,
                                "referenceRoot": display_path(runtime_root),
                                "processReferenceCount": 0,
                                "processReferenceSHA256": contract_digest([]),
                                "cwdExecutableOpenFileReferencesAbsent": True,
                                "cleanupRootProcessReferenceCount": 0,
                            },
                        }
                    ],
                    "credentialsSerialized": False,
                },
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )
        drain_receipt.chmod(0o600)
        parsed_proofs, proof_errors = parse_runner_drain_receipts(
            [drain_receipt],
            transaction="fixture-transaction",
            required_runtime_roots=[runtime_root],
            canonical_runtime_root=canonical_runtime_root,
            managed_root=managed_fixture_root,
            source_map_sha256=source_map_digest,
            github_accounts_sha256=account_digest,
            repository_identities_sha256=identity_digest,
        )
        self_test_require(not proof_errors and len(parsed_proofs) == 1, "runner-drain proof did not parse")
        parsed_root = parsed_proofs[display_path(runtime_root)].roots[0]
        self_test_require(
            parsed_root.cleanup_root == cleanup_root
            and parsed_root.source_runtime_root == cleanup_root / "Runtime"
            and parsed_root.canonical_runtime_root == canonical_runtime_root,
            "runner-drain cleanupRoot/Runtime/canonical binding changed",
        )
        _wrong_proofs, wrong_errors = parse_runner_drain_receipts(
            [drain_receipt],
            transaction="different-transaction",
            required_runtime_roots=[runtime_root],
            canonical_runtime_root=canonical_runtime_root,
            managed_root=managed_fixture_root,
            source_map_sha256=source_map_digest,
            github_accounts_sha256=account_digest,
            repository_identities_sha256=identity_digest,
        )
        self_test_require(bool(wrong_errors), "runner-drain transaction mismatch was accepted")

        # Receipt rollback preserves, but removes, a failed receipt from its
        # authoritative final lane.
        receipt_lane = fixture / "receipts" / "final"
        receipt_lane.mkdir(parents=True)
        (receipt_lane / "receipt.json").write_text("{}\n", encoding="utf-8")
        failed_receipts = fixture / "failed-receipts"
        quarantine_failed_receipt_lane(
            receipt_lane,
            failure_root=failed_receipts,
            label="final",
        )
        self_test_require(
            not os.path.lexists(receipt_lane)
            and (failed_receipts / "final" / "receipt.json").is_file(),
            "failed final receipt was not quarantined",
        )

        self_test_require(
            mapping_retirement_authorized(
                Mapping(
                    fixture / "legacy",
                    fixture / "destination",
                    "explicit-legacy-source",
                    retention="retire-to-managed-temp",
                )
            ),
            "reviewed legacy retirement was not authorized",
        )
        self_test_require(
            not mapping_retirement_authorized(
                Mapping(
                    fixture / "active",
                    fixture / "destination",
                    "explicit-active-checkout-source",
                    retention="retain",
                )
            ),
            "active checkout retirement was authorized",
        )

        # Multi-owner Runtime lanes must validate and audit recursively. This
        # fixture protects both the primary owner and DARQ-Labs-LLC from any
        # reintroduction of a single-owner path assumption.
        multi_managed = fixture / "multi-owner-managed"
        multi_repos = multi_managed / "Code" / "Repos"
        wayne_canonical = multi_repos / "WayneTechLab"
        darq_canonical = multi_repos / "DARQ-Labs-LLC"
        wayne_canonical.mkdir(parents=True)
        darq_canonical.mkdir(parents=True)
        wayne_runtime = multi_managed / "Runtime" / "Repos" / "WayneTechLab" / "Alpha"
        darq_runtime = (
            multi_managed
            / "Runtime"
            / "Repos"
            / "DARQ-Labs-LLC"
            / "DarkLabResearch"
        )
        wayne_runtime.mkdir(parents=True)
        darq_runtime.mkdir(parents=True)
        wayne_runner = (
            multi_managed
            / "Runtime"
            / "Runners"
            / "WayneTechLab"
            / "runner-wayne"
            / "_work"
            / "WayneTechLab"
            / "Alpha"
        )
        darq_runner = (
            multi_managed
            / "Runtime"
            / "Runners"
            / "DARQ-Labs-LLC"
            / "runner-darq"
            / "_work"
            / "DARQ-Labs-LLC"
            / "DarkLabResearch"
        )
        (wayne_runner / ".git").mkdir(parents=True)
        (darq_runner / ".git").mkdir(parents=True)
        stage1_fixture = fixture / "multi-stage1"
        stage1_fixture.mkdir()
        for runtime_mapping in (
            Mapping(
                wayne_runtime,
                wayne_canonical / "Alpha",
                "runtime-mirror-copy",
            ),
            Mapping(
                darq_runtime,
                darq_canonical / "DarkLabResearch",
                "runtime-mirror-copy",
            ),
            Mapping(
                wayne_runner,
                wayne_canonical / "Alpha",
                "runtime-runner-worktree",
            ),
            Mapping(
                darq_runner,
                darq_canonical / "DarkLabResearch",
                "runtime-runner-worktree",
            ),
        ):
            boundary_errors = validate_mapping(
                runtime_mapping,
                wayne_canonical,
                multi_repos,
                multi_managed,
                stage1_fixture,
                (),
            )
            self_test_require(
                not [error for error in boundary_errors if "Runtime" in error],
                f"multi-owner Runtime mapping was rejected: {boundary_errors}",
            )
        multi_audit = audit_final_state(
            wayne_canonical,
            multi_repos,
            multi_managed,
            stage1_fixture,
            None,
        )
        self_test_require(
            multi_audit["runtimeMirrorCount"] == 2,
            "multi-owner Runtime mirror audit missed an owner lane",
        )
        self_test_require(
            multi_audit["runtimeRunnerWorktreeCount"] == 2,
            "multi-owner runner audit missed an owner lane",
        )

    print("SELF-TEST PASS | isolated fixture safety invariants", flush=True)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Losslessly merge duplicate CSA-iEM project folders into one canonical folder per repository.",
        epilog=f"Permanent cleanup requires: --apply --confirm-token {CONFIRM_TOKEN}",
    )
    parser.add_argument("--canonical-root", type=Path, required=True)
    parser.add_argument("--managed-root", type=Path, required=True)
    parser.add_argument("--stage1-root", type=Path, required=True)
    parser.add_argument("--compat-root", type=Path)
    parser.add_argument("--stage2-report", type=Path, action="append", default=[])
    parser.add_argument(
        "--mapping-file",
        type=Path,
        action="append",
        default=[],
        help="Format-1 JSON file containing reviewed source-to-canonical mappings.",
    )
    parser.add_argument(
        "--additional-workspace-root",
        type=Path,
        action="append",
        default=[],
        help="Additional protected CSA-iEM workspace whose Code/Import/Runtime/runner copies must be merged but retained.",
    )
    parser.add_argument(
        "--protected-checkout",
        type=Path,
        action="append",
        default=[],
        help=(
            "Immutable active checkout boundary. Any rename, replacement, unlink, or "
            "recursive deletion touching this path or an ancestor/descendant fails closed."
        ),
    )
    parser.add_argument(
        "--github-owner-account",
        action="append",
        default=[],
        metavar="OWNER=LOGIN",
        help="Reviewed owner-to-gh-account binding; must agree with mapping-file githubAccounts.",
    )
    parser.add_argument(
        "--runner-drain-receipt",
        type=Path,
        action="append",
        default=[],
        help=(
            "Transaction-bound csa-iem-runner-drain-v1 JSON proof for one Runtime root. "
            "Required before any apply reads a managed/additional Runtime source; the helper "
            "only revalidates and never signals processes."
        ),
    )
    parser.add_argument(
        "--only-source",
        type=Path,
        help="Process one exact discovered source path as a canary; global Stage 1 cleanup is skipped.",
    )
    parser.add_argument("--transaction-id", default="")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument(
        "--resume",
        action="store_true",
        help=(
            "Resume the exact --transaction-id from finalized destination-group "
            "checkpoints. Every resumed group is fully reverified; partial staging "
            "and transactions that entered global retirement remain blocked."
        ),
    )
    parser.add_argument("--confirm-token", default="")
    parser.add_argument(
        "--retire-compat-projects",
        action="store_true",
        help="After every explicit compatibility source verifies, move its top-level project root into managed _temp.",
    )
    parser.add_argument(
        "--no-fast-mode",
        action="store_true",
        help="Disable the native deep-checksum fast path and use the per-file verifier for every source.",
    )
    parser.add_argument(
        "--group-workers",
        type=int,
        default=1,
        metavar="N",
        help=(
            "Process disjoint destination-repository groups concurrently. "
            "Default: 1. Maximum: 2. Promotion receipts remain group-isolated; "
            "global retirement and cleanup remain coordinator-only."
        ),
    )
    return parser


def parse_owner_account_overrides(values: Sequence[str]) -> tuple[dict[str, str], list[str]]:
    bindings: dict[str, str] = {}
    errors: list[str] = []
    for value in values:
        owner, separator, login = value.partition("=")
        if (
            not separator
            or not re.fullmatch(r"[A-Za-z0-9-]+", owner)
            or not re.fullmatch(r"[A-Za-z0-9-]+", login)
        ):
            errors.append(f"Invalid --github-owner-account binding: {value!r}")
            continue
        key = owner.casefold()
        if key in bindings and bindings[key] != login:
            errors.append(f"Conflicting CLI account bindings for owner {owner}")
            continue
        bindings[key] = login
    return bindings, errors


def group_mappings_by_destination(
    mappings: Sequence[Mapping],
) -> list[tuple[Path, list[Mapping]]]:
    groups: dict[tuple[str, str, str], list[Mapping]] = {}
    destinations: dict[tuple[str, str, str], Path] = {}
    for mapping in mappings:
        key = (
            display_path(mapping.destination.parent.parent),
            mapping.destination.parent.name.casefold(),
            mapping.destination.name.casefold(),
        )
        groups.setdefault(key, []).append(mapping)
        destinations.setdefault(key, mapping.destination)
    return [
        (destinations[key], sorted(groups[key], key=lambda item: os.fsencode(display_path(item.source))))
        for key in sorted(groups, key=lambda value: tuple(os.fsencode(part) for part in value))
    ]


def plan_parallel_group_isolation(
    groups: Sequence[tuple[Path, Sequence[Mapping]]],
) -> tuple[list[str], dict[int, int], list[str]]:
    """Build serial conflict components for a bounded repository worker pool.

    Each group already has a unique transaction stage, rollback, receipt, and
    checkpoint lane. Reviewed groups whose source trees, physical roots, Git
    common directories, or cross-group destinations overlap are joined into a
    shared serial component. Unrelated components may still run concurrently.
    Duplicate destination/report lanes remain hard isolation errors.
    """
    errors: list[str] = []
    conflict_reasons: list[str] = []
    parents = list(range(len(groups)))

    def find(group_index: int) -> int:
        while parents[group_index] != group_index:
            parents[group_index] = parents[parents[group_index]]
            group_index = parents[group_index]
        return group_index

    def union(left_group: int, right_group: int, reason: str) -> None:
        left_root = find(left_group)
        right_root = find(right_group)
        if left_root != right_root:
            parents[right_root] = left_root
        if len(conflict_reasons) < 20:
            conflict_reasons.append(reason)

    destination_keys: dict[str, Path] = {}
    group_keys: dict[str, Path] = {}
    source_ids: dict[str, tuple[int, Path]] = {}
    source_paths: dict[str, tuple[int, Path]] = {}
    physical_sources: dict[tuple[int, int], tuple[int, Path]] = {}
    git_common_dirs: dict[str, tuple[int, Path]] = {}
    indexed_sources: list[tuple[int, Path]] = []

    for group_index, (destination, group) in enumerate(groups):
        destination_key = os.path.normcase(os.path.abspath(destination))
        previous_destination = destination_keys.get(destination_key)
        if previous_destination is not None:
            errors.append(
                f"duplicate canonical destination {destination} and {previous_destination}"
            )
        destination_keys[destination_key] = destination

        group_key = group_key_for_destination(destination)
        previous_group = group_keys.get(group_key)
        if previous_group is not None:
            errors.append(
                f"duplicate destination-group lane {group_key}: "
                f"{destination} and {previous_group}"
            )
        group_keys[group_key] = destination

        for mapping in group:
            source_key = os.path.normcase(os.path.abspath(mapping.source))
            previous_source = source_paths.get(source_key)
            if previous_source is not None and previous_source[0] != group_index:
                union(
                    previous_source[0],
                    group_index,
                    f"shared source serialized: {mapping.source}",
                )
            source_paths[source_key] = (group_index, mapping.source)
            indexed_sources.append((group_index, mapping.source))

            source_stat = mapping.source.lstat()
            physical_key = (int(source_stat.st_dev), int(source_stat.st_ino))
            previous_physical = physical_sources.get(physical_key)
            if previous_physical is not None and previous_physical[0] != group_index:
                union(
                    previous_physical[0],
                    group_index,
                    f"shared physical source serialized: "
                    f"{mapping.source} and {previous_physical[1]}",
                )
            physical_sources[physical_key] = (group_index, mapping.source)

            source_git_dir = resolve_git_dir(mapping.source)
            if source_git_dir is not None:
                common_dir = resolve_git_common_dir(mapping.source, source_git_dir)
                common_key = os.path.normcase(os.path.realpath(common_dir))
                previous_common = git_common_dirs.get(common_key)
                if previous_common is not None and previous_common[0] != group_index:
                    union(
                        previous_common[0],
                        group_index,
                        f"shared Git common directory serialized: "
                        f"{mapping.source} and {previous_common[1]}",
                    )
                git_common_dirs[common_key] = (group_index, mapping.source)

            source_id = source_id_for(mapping)
            previous_source_id = source_ids.get(source_id)
            if previous_source_id is not None and previous_source_id[0] != group_index:
                errors.append(
                    f"source report lane belongs to multiple groups: {source_id}"
                )
            source_ids[source_id] = (group_index, mapping.source)

    for left_index, (left_group, left_source) in enumerate(indexed_sources):
        left_destination = groups[left_group][0]
        for right_group, right_source in indexed_sources[left_index + 1 :]:
            if left_group == right_group:
                continue
            if path_within(left_source, right_source) or path_within(right_source, left_source):
                union(
                    left_group,
                    right_group,
                    f"overlapping source trees serialized: {left_source} and {right_source}",
                )
            right_destination = groups[right_group][0]
            if path_within(left_source, right_destination) or path_within(
                right_destination, left_source
            ):
                union(
                    left_group,
                    right_group,
                    f"cross-group source/destination overlap serialized: "
                    f"{left_source} and {right_destination}",
                )
            if path_within(right_source, left_destination) or path_within(
                left_destination, right_source
            ):
                union(
                    left_group,
                    right_group,
                    f"cross-group source/destination overlap serialized: "
                    f"{right_source} and {left_destination}",
                )
    component_by_group = {
        group_index: find(group_index) for group_index in range(len(groups))
    }
    return errors, component_by_group, conflict_reasons


def execute_destination_group(
    destination: Path,
    group: Sequence[Mapping],
    *,
    resume: bool,
    live_repositories: dict[str, LiveRepository],
    transaction: str,
    transaction_temp: Path,
    report_dir: Path,
    plan_sha256: str,
    fast_mode: bool,
    bindings: ContractBindings,
    owner_account_bindings: dict[str, str],
    repository_identities: dict[str, dict[str, str]],
    runner_drain_proofs: dict[str, RunnerDrainProof],
) -> DestinationGroupResult:
    repository = repository_for_group(group, destination)
    live = live_repositories.get(normalize_remote(f"https://github.com/{repository}"))
    if live is None:
        raise RecoveryError(f"No finalized live identity for destination group {repository}")

    if resume:
        resumed = resume_destination_group(
            group,
            destination=destination,
            live=live,
            transaction=transaction,
            report_dir=report_dir,
            plan_sha256=plan_sha256,
            bindings=bindings,
            runner_drain_proofs=runner_drain_proofs,
        )
        if resumed is not None:
            return resumed

    return process_destination_group(
        group,
        destination=destination,
        live=live,
        transaction=transaction,
        transaction_temp=transaction_temp,
        report_dir=report_dir,
        plan_sha256=plan_sha256,
        fast_mode=fast_mode,
        bindings=bindings,
        owner_account_bindings=owner_account_bindings,
        repository_identities=repository_identities,
        runner_drain_proofs=runner_drain_proofs,
    )


def main(argv: Sequence[str] | None = None) -> int:
    if argv is not None and list(argv) == ["--self-test"]:
        return run_self_test()
    if argv is None and sys.argv[1:] == ["--self-test"]:
        return run_self_test()
    args = build_parser().parse_args(argv)
    if args.resume and (not args.apply or not args.transaction_id):
        raise RecoveryError("--resume requires --apply and an exact --transaction-id")
    if not 1 <= args.group_workers <= 2:
        raise RecoveryError("--group-workers must be 1 or 2")
    protected_checkouts = [Path(os.path.abspath(path)) for path in args.protected_checkout]
    if (LAUNCH_CWD / ".git").exists() and LAUNCH_CWD not in protected_checkouts:
        protected_checkouts.append(LAUNCH_CWD)
    configure_protected_mutation_roots(protected_checkouts)
    canonical_root = canonical(args.canonical_root)
    canonical_repos_root = canonical_root.parent
    managed_root = canonical(args.managed_root)
    stage1_root = Path(os.path.abspath(args.stage1_root))
    compat_root = Path(os.path.abspath(args.compat_root)) if args.compat_root else None
    additional_workspace_roots = [canonical(path) for path in args.additional_workspace_root]
    transaction = args.transaction_id or utc_transaction_id()

    if not canonical_root.is_dir():
        raise RecoveryError(f"Canonical root was not found: {canonical_root}")
    if not managed_root.is_dir():
        raise RecoveryError(f"Managed root was not found: {managed_root}")
    if not path_within(canonical_root, managed_root):
        raise RecoveryError(f"Canonical root is outside the managed root: {canonical_root}")
    expected_repos_root = canonical(managed_root / "Code" / "Repos")
    if canonical_repos_root != expected_repos_root:
        raise RecoveryError(
            f"Canonical owner root must be directly below {expected_repos_root}: {canonical_root}"
        )
    for workspace_root in additional_workspace_roots:
        if not workspace_root.is_dir() or workspace_root.is_symlink():
            raise RecoveryError(f"Additional workspace root is not a real directory: {workspace_root}")
        if workspace_root == managed_root or path_within(canonical_root, workspace_root):
            raise RecoveryError(
                f"Additional workspace root overlaps the canonical managed workspace: {workspace_root}"
            )

    report_dir = managed_root / "Runtime" / "Reports" / "RepoConsolidation" / transaction
    report_dir.mkdir(parents=True, exist_ok=True)
    checksum_index = (
        managed_root
        / "Runtime"
        / "Indexes"
        / "RepoConsolidation"
        / "stable-hash-v1.sqlite3"
    )
    configure_persistent_hash_index(
        checksum_index,
        transaction,
        excluded_roots=(managed_root / "_temp" / "Repo-Consolidation",),
    )
    print(
        f"CHECKSUM INDEX | format={PERSISTENT_HASH_INDEX_FORMAT} | {checksum_index}",
        flush=True,
    )
    contract_bindings: ContractBindings | None = None
    contract_errors: list[str] = []
    workspace_requirements_for_run: list[WorkspaceRootRequirement] = []
    try:
        contract_bindings = load_contract_bindings(
            [Path(os.path.abspath(path)) for path in args.mapping_file]
        )
    except Exception as error:
        contract_errors.append(str(error))
    (
        mappings,
        discovery_errors,
        owner_account_bindings,
        repository_identities,
    ) = discover_mappings(
        canonical_root,
        canonical_repos_root,
        managed_root,
        stage1_root,
        args.stage2_report,
        additional_workspace_roots,
        [Path(os.path.abspath(path)) for path in args.mapping_file],
    )
    discovery_errors.extend(contract_errors)
    if contract_bindings is not None:
        expected_accounts = {
            owner.casefold(): login
            for owner, login in contract_bindings.github_accounts.items()
        }
        if owner_account_bindings != expected_accounts:
            discovery_errors.append(
                "Discovered GitHub account bindings differ from the exact source-map contract"
            )
        expected_identities = {
            normalize_remote(f"https://github.com/{repository}"): identity
            for repository, identity in contract_bindings.repository_identities.items()
        }
        if repository_identities != expected_identities:
            discovery_errors.append(
                "Discovered repository identities differ from the exact source-map contract"
            )
        requirements_by_root = {
            display_path(requirement.cleanup_root): requirement
            for requirement in contract_bindings.workspace_root_requirements
        }
        for workspace_root in additional_workspace_roots:
            requirement = requirements_by_root.get(display_path(workspace_root))
            if requirement is None:
                discovery_errors.append(
                    f"Additional workspace lacks an exact source-map root replacement: {workspace_root}"
                )
                continue
            if requirement.canonical_root != managed_root:
                discovery_errors.append(
                    f"Additional workspace root targets a different managed root: "
                    f"{workspace_root} -> {requirement.canonical_root} / {managed_root}"
                )
                continue
            workspace_requirements_for_run.append(requirement)
        if additional_workspace_roots and (
            contract_bindings.workspace_root_proof_contract
            != WORKSPACE_ROOT_PROOF_KIND
        ):
            discovery_errors.append(
                "Whole-workspace retirement is blocked until the reviewed source map and "
                f"cleanup consumer declare {WORKSPACE_ROOT_PROOF_KIND}"
            )
    cli_bindings, cli_binding_errors = parse_owner_account_overrides(
        args.github_owner_account
    )
    discovery_errors.extend(cli_binding_errors)
    for owner, login in cli_bindings.items():
        existing = owner_account_bindings.get(owner)
        if existing and existing != login:
            discovery_errors.append(
                f"CLI GitHub account binding conflicts with mapping plan for {owner}: "
                f"{existing} != {login}"
            )
        else:
            owner_account_bindings[owner] = login
    mappings = [
        dataclasses.replace(
            mapping,
            github_account=owner_account_bindings.get(
                mapping.destination.parent.name.casefold(), ""
            ),
        )
        for mapping in mappings
    ]
    for mapping in mappings:
        for protected in protected_checkouts:
            if (
                path_within(mapping.source, protected)
                or path_within(protected, mapping.source)
                or path_within(mapping.destination, protected)
                or path_within(protected, mapping.destination)
            ):
                discovery_errors.append(
                    f"Protected active checkout appears in the consolidation plan: "
                    f"{protected} / {mapping.source} -> {mapping.destination}"
                )
    scoped_run = args.only_source is not None
    if args.only_source is not None:
        selected_source = Path(os.path.abspath(args.only_source))
        mappings = [mapping for mapping in mappings if mapping.source == selected_source]
        if not mappings:
            discovery_errors.append(f"The requested canary source was not discovered: {selected_source}")
    validation_errors = list(discovery_errors)

    live_repositories: dict[str, LiveRepository] = {}
    pending_creations: dict[str, tuple[list[Mapping], str]] = {}
    canonicalized_mappings: list[Mapping] = []
    for original_destination, group in group_mappings_by_destination(mappings):
        try:
            repository = repository_for_group(group, original_destination)
            account = account_for_repository_group(
                group,
                repository,
                owner_account_bindings,
            )
            # GitHub correctly returns 409 for an existing, empty repository's
            # branch lookup. Empty repositories are safe inputs: the merger
            # creates an exact local stage and activates data only through the
            # existing identity/history policy. Missing-repository creation is
            # still restricted to the reviewed bootstrap/derivation contract.
            allow_empty = True
            # Archived repositories are preserved read-only. They may be
            # assembled only when no source is authorized to become active or
            # re-arm the remote; all bytes and Git objects remain represented
            # in the canonical recovery evidence lane.
            allow_archived = all(
                mapping.source_policy != "current-authoritative"
                and not mapping.rearm_repository
                and mapping.conflict_policy == "preserve-canonical"
                for mapping in group
            )
            try:
                live = resolve_live_repository(
                    repository,
                    account,
                    repository_identities,
                    allow_empty=allow_empty,
                    allow_archived=allow_archived,
                )
            except MissingRepositoryError:
                if exact_wiki_child(repository) is not None or not allow_empty:
                    raise
                pending_creations[repository] = (list(group), account)
                live = None
            if live is not None:
                live_key = normalize_remote(f"https://github.com/{live.full_name}")
                live_repositories[live_key] = live
                live_owner, live_name = live.full_name.split("/", 1)
                desired_destination = canonical_repos_root / live_owner / live_name
            else:
                requested_owner, requested_name = repository.split("/", 1)
                desired_destination = canonical_repos_root / requested_owner / requested_name
            expected_layout_identity = normalize_remote(
                f"https://github.com/{desired_destination.parent.name}/{desired_destination.name}"
            )
            for mapping in group:
                mapped_layout_identity = normalize_remote(
                    f"https://github.com/{mapping.destination.parent.name}/{mapping.destination.name}"
                )
                if mapped_layout_identity != expected_layout_identity:
                    raise RecoveryError(
                        f"Live identity would redirect a reviewed destination: "
                        f"{mapping.destination} -> {desired_destination}"
                    )
                canonicalized_mappings.append(
                    dataclasses.replace(
                        mapping,
                        destination=desired_destination,
                        repository=(live.full_name if live is not None else repository),
                        github_account=account,
                    )
                )
        except Exception as error:
            validation_errors.append(str(error))
    mappings = sorted(
        canonicalized_mappings,
        key=lambda item: (
            os.fsencode(display_path(item.destination)),
            os.fsencode(display_path(item.source)),
        ),
    )

    if contract_bindings is not None:
        mapped_contract_sources: set[str] = set()
        for mapping in mappings:
            source_key = display_path(mapping.source)
            expected_digest = contract_bindings.mapping_sha256_by_source.get(source_key)
            if expected_digest is None:
                continue
            mapped_contract_sources.add(source_key)
            if mapping.mapping_sha256 != expected_digest:
                validation_errors.append(
                    f"Mapping digest differs from the exact source-map row: {mapping.source}"
                )
        missing_contract_sources = sorted(
            set(contract_bindings.mapping_sha256_by_source) - mapped_contract_sources,
            key=os.fsencode,
        )
        if missing_contract_sources:
            validation_errors.append(
                f"Recovery plan omitted {len(missing_contract_sources)} exact source-map mapping(s): "
                + ", ".join(missing_contract_sources[:20])
            )

    for mapping in mappings:
        validation_errors.extend(
            validate_mapping(
                mapping,
                canonical_root,
                canonical_repos_root,
                managed_root,
                stage1_root,
                additional_workspace_roots,
            )
        )
    validation_errors.extend(validate_canonical_identity_groups(canonical_repos_root))
    try:
        runtime_roots_requiring_drain = runtime_roots_for_mappings(
            mappings,
            managed_root,
            additional_workspace_roots,
            contract_bindings.runner_drain_requirements
            if contract_bindings is not None
            else (),
        )
    except Exception as error:
        runtime_roots_requiring_drain = []
        validation_errors.append(str(error))
    if contract_bindings is None:
        runner_drain_proofs = {}
        runner_drain_errors = [
            "Runner-drain proof cannot be bound until the exact source-map contract loads"
        ] if runtime_roots_requiring_drain else []
    else:
        runner_drain_proofs, runner_drain_errors = parse_runner_drain_receipts(
            [Path(os.path.abspath(path)) for path in args.runner_drain_receipt],
            transaction=transaction,
            required_runtime_roots=runtime_roots_requiring_drain,
            canonical_runtime_root=managed_root / "Runtime",
            managed_root=managed_root,
            source_map_sha256=contract_bindings.source_map_sha256,
            github_accounts_sha256=contract_bindings.github_accounts_sha256,
            repository_identities_sha256=contract_bindings.repository_identities_sha256,
        )
    validation_errors.extend(runner_drain_errors)
    for proof in runner_drain_proofs.values():
        try:
            revalidate_runner_drain_proof(proof)
        except Exception as error:
            validation_errors.append(str(error))
    preflight_report = write_preflight_report(
        report_dir,
        transaction,
        mappings,
        validation_errors,
        canonical_root,
        stage1_root,
        owner_account_bindings,
        repository_identities,
        live_repositories,
        sorted(pending_creations),
        runtime_roots_requiring_drain,
        runner_drain_proofs,
    )
    plan_path = report_dir / "plan.json"
    plan_sha256, _plan_stat = stable_file_hash(plan_path)
    print(
        f"PREFLIGHT | sources={len(mappings)} blockers={len(validation_errors)} | {preflight_report}",
        flush=True,
    )
    if validation_errors:
        for error in validation_errors:
            print(f"BLOCKED | {error}", file=sys.stderr, flush=True)
        return 2
    if not args.apply:
        return 0
    if args.confirm_token != CONFIRM_TOKEN:
        raise RecoveryError(f"Apply requires --confirm-token {CONFIRM_TOKEN}")
    if contract_bindings is None:
        raise RecoveryError("Apply cannot continue without exact source-map contract bindings")

    transaction_temp = managed_root / "_temp" / "Repo-Consolidation" / transaction
    if args.resume:
        retirement_boundaries = (
            report_dir / "source-retirement-journal.json",
            report_dir / "receipts" / "source-retirement",
            report_dir / "transaction-success.json",
            report_dir / "workspace-root-swap-journal.json",
        )
        started = [path for path in retirement_boundaries if os.path.lexists(path)]
        if started:
            raise RecoveryError(
                "Resume is limited to finalized destination-group checkpoints before "
                "global retirement; found="
                + ", ".join(display_path(path) for path in started)
            )
        checkpoint_root = report_dir / "checkpoints" / "destination-groups"
        if not checkpoint_root.is_dir() or not any(checkpoint_root.glob("*.json")):
            raise RecoveryError(
                "Resume requires at least one finalized destination-group checkpoint; "
                "partial staging remains preserved and blocked"
            )
    elif transaction_temp.exists() and any(transaction_temp.iterdir()):
        raise RecoveryError(f"Transaction temp is not empty: {transaction_temp}")
    transaction_temp.mkdir(parents=True, exist_ok=True)
    revalidate_runtime_roots_for_sources(
        [mapping.source for mapping in mappings], runner_drain_proofs
    )

    # Repository creation is intentionally delayed until every non-creation
    # preflight blocker is clear and the complete plan has been hashed.
    for repository, (group, account) in sorted(pending_creations.items()):
        live = create_exact_private_empty_repository(
            repository,
            account,
            repository_identities,
        )
        live_repositories[
            normalize_remote(f"https://github.com/{live.full_name}")
        ] = live

    group_results: list[DestinationGroupResult] = []
    completed: list[ProcessResult] = []
    failures: list[ProcessResult] = []
    groups = group_mappings_by_destination(mappings)
    requested_group_workers = min(args.group_workers, max(1, len(groups)))
    component_by_group = {group_index: group_index for group_index in range(len(groups))}
    conflict_locks: dict[int, threading.Lock] = {}
    if requested_group_workers > 1:
        isolation_errors, component_by_group, conflict_reasons = plan_parallel_group_isolation(
            groups
        )
        if isolation_errors:
            requested_group_workers = 1
            print(
                "GROUP WORKERS | downgraded-to=1 | "
                f"reason={isolation_errors[0]}",
                flush=True,
            )
        else:
            component_sizes: dict[int, int] = {}
            for component in component_by_group.values():
                component_sizes[component] = component_sizes.get(component, 0) + 1
            conflict_locks = {
                component: threading.Lock()
                for component, size in component_sizes.items()
                if size > 1
            }
            if conflict_reasons:
                print(
                    f"GROUP WORKERS | serialized-components={len(conflict_locks)} | "
                    f"first={conflict_reasons[0]}",
                    flush=True,
                )
    print(
        f"GROUP WORKERS | active={requested_group_workers} | "
        "retirement=coordinator-only",
        flush=True,
    )

    def record_group_failure(
        destination: Path,
        group: Sequence[Mapping],
        error: BaseException,
    ) -> None:
        traceback_path = (
            report_dir
            / "failures"
            / f"group-{group_key_for_destination(destination)}.txt"
        )
        traceback_path.parent.mkdir(parents=True, exist_ok=True)
        traceback_path.write_text(
            "".join(traceback.format_exception(type(error), error, error.__traceback__)),
            encoding="utf-8",
        )
        for mapping in group:
            failures.append(ProcessResult(mapping, "failed-source-retained", str(error)))
        print(f"FAILED GROUP | {destination} | {error}", file=sys.stderr, flush=True)

    def record_group_success(result: DestinationGroupResult) -> None:
        group_results.append(result)
        for item in result.prepared:
            completed.append(
                ProcessResult(
                    mapping=item.mapping,
                    status="completed",
                    detail=result.detail,
                    variant_root=display_path(
                        item.mapping.destination / item.variant_relative
                    ),
                    tree=item.tree,
                    git=item.git,
                )
            )

    def execute_scheduled_group(
        group_index: int,
        destination: Path,
        group: Sequence[Mapping],
    ) -> DestinationGroupResult:
        def execute() -> DestinationGroupResult:
            return execute_destination_group(
                destination,
                group,
                resume=args.resume,
                live_repositories=live_repositories,
                transaction=transaction,
                transaction_temp=transaction_temp,
                report_dir=report_dir,
                plan_sha256=plan_sha256,
                fast_mode=not args.no_fast_mode,
                bindings=contract_bindings,
                owner_account_bindings=owner_account_bindings,
                repository_identities=repository_identities,
                runner_drain_proofs=runner_drain_proofs,
            )

        conflict_lock = conflict_locks.get(component_by_group[group_index])
        if conflict_lock is None:
            return execute()
        with conflict_lock:
            return execute()

    clear_verification_caches()
    if requested_group_workers == 1:
        for index, (destination, group) in enumerate(groups, 1):
            print(
                f"GROUP | {index}/{len(groups)} | "
                f"{destination.parent.name}/{destination.name} sources={len(group)}",
                flush=True,
            )
            clear_verification_caches()
            try:
                record_group_success(
                    execute_scheduled_group(
                        index - 1,
                        destination,
                        group,
                    )
                )
            except Exception as error:
                record_group_failure(destination, group, error)
                break
    else:
        indexed_results: dict[int, DestinationGroupResult] = {}
        future_groups: dict[
            concurrent.futures.Future[DestinationGroupResult],
            tuple[int, Path, Sequence[Mapping]],
        ] = {}
        with concurrent.futures.ThreadPoolExecutor(
            max_workers=requested_group_workers,
            thread_name_prefix="repo-group",
        ) as executor:
            for index, (destination, group) in enumerate(groups, 1):
                print(
                    f"GROUP QUEUED | {index}/{len(groups)} | "
                    f"{destination.parent.name}/{destination.name} sources={len(group)}",
                    flush=True,
                )
                future = executor.submit(
                    execute_scheduled_group,
                    index - 1,
                    destination,
                    group,
                )
                future_groups[future] = (index, destination, group)

            for future in concurrent.futures.as_completed(future_groups):
                index, destination, group = future_groups[future]
                try:
                    result = future.result()
                    indexed_results[index] = result
                    print(
                        f"GROUP COMPLETE | {index}/{len(groups)} | "
                        f"{destination.parent.name}/{destination.name}",
                        flush=True,
                    )
                except Exception as error:
                    record_group_failure(destination, group, error)

        for index in sorted(indexed_results):
            record_group_success(indexed_results[index])

    compatibility_links_removed = 0
    if not failures and not scoped_run:
        try:
            if len(group_results) != len(groups):
                raise RecoveryError(
                    "Global retirement blocked: not every destination group finalized"
                )
            for result in group_results:
                if (
                    result.status != "completed"
                    or result.live_repository is None
                    or not result.group_receipt
                    or not result.group_receipt_sha256
                ):
                    raise RecoveryError(
                        f"Global retirement blocked by incomplete group: {result.destination}"
                    )
                receipt_path = Path(result.group_receipt)
                if (
                    not receipt_path.is_file()
                    or stable_file_hash(receipt_path)[0] != result.group_receipt_sha256
                ):
                    raise RecoveryError(
                        f"Global retirement blocked by changed receipt: {receipt_path}"
                    )
            retirement_moves = execute_global_retirement(
                group_results,
                managed_root=managed_root,
                stage1_root=stage1_root,
                compat_root=compat_root,
                retire_compat_projects=args.retire_compat_projects,
                transaction=transaction,
                transaction_temp=transaction_temp,
                report_dir=report_dir,
                plan_sha256=plan_sha256,
                bindings=contract_bindings,
                owner_account_bindings=owner_account_bindings,
                repository_identities=repository_identities,
                runner_drain_proofs=runner_drain_proofs,
                workspace_root_requirements=workspace_requirements_for_run,
            )
            compatibility_links_removed = sum(
                move.kind == "compatibility-link" for move in retirement_moves
            )
        except Exception as error:
            traceback_path = report_dir / "failures" / "global-retirement.txt"
            traceback_path.parent.mkdir(parents=True, exist_ok=True)
            traceback_path.write_text(traceback.format_exc(), encoding="utf-8")
            if mappings:
                failures.append(
                    ProcessResult(
                        mappings[0],
                        "failed-sources-retained",
                        f"Global retirement blocked before completion: {error}",
                    )
                )
            print(f"FAILED RETIREMENT | {error}", file=sys.stderr, flush=True)

    audit = audit_final_state(
        canonical_root,
        canonical_repos_root,
        managed_root,
        stage1_root,
        compat_root,
    )
    final_report = write_final_report(
        report_dir,
        transaction,
        completed,
        failures,
        audit,
        compatibility_links_removed,
    )
    checksum_index_report = persistent_hash_index_report()
    write_fsynced_json(report_dir / "checksum-index.json", checksum_index_report)
    print(
        f"FINAL | completed={len(completed)} failed={len(failures)} "
        f"stage_duplicates={audit['stageDuplicateCount']} stage1_exists={audit['stage1RootExists']} "
        f"hash_hits={checksum_index_report['hits']} "
        f"hash_misses={checksum_index_report['misses']} "
        f"| {final_report}",
        flush=True,
    )
    if scoped_run:
        return 1 if failures else 0
    return (
        1
        if failures
        or audit["stageDuplicateCount"]
        or audit["identityErrors"]
        or audit["managedStageArtifactCount"]
        or audit["runtimeMirrorCount"]
        or audit["runtimeRunnerWorktreeCount"]
        or (args.retire_compat_projects and audit["compatibilityEntryCount"])
        or audit["stage1RootExists"]
        else 0
    )


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RecoveryError as error:
        print(f"ERROR | {error}", file=sys.stderr)
        raise SystemExit(2)

#!/usr/bin/env python3
"""Fail-closed, receipt-bound retirement of local CSA-iEM source roots.

This helper never merges repositories.  It consumes the final, transaction-
bound proof produced by ``repo-consolidation-recovery.py`` and performs two
separate operations:

* ``--drain-runners-before-merge`` captures the exact launch-agent/listener
  pre-state, prevents restart, drains only that set, proves the exact Runtime
  roots quiesced, and writes a durable ``csa-iem-runner-drain-v1`` receipt.
* ``--restore-runners-after-merge`` requires the final recovery marker to bind
  that drain receipt and every final mapping proof, then restores only the
  prior loaded set from canonical Runtime paths. ``--abort-runner-drain`` is a
  separately authorized source-state rollback when no success marker exists.
* ``--apply`` copies every authorized local root to durable managed ``_temp``
  evidence, drains only the exact runner services that were loaded, moves all
  roots by same-volume rename into reversible local quarantine, installs and
  verifies compatibility layouts, and restores the prior runner state.
* ``--delete-local-quarantine`` is a later, independently authorized phase. It
  revalidates the external volume, evidence, canonical representations, GitHub
  identity, strict Git fsck proof, compatibility layouts, and process safety
  immediately before each irreversible deletion.
* ``--delete-external-temp`` is a final, independently authorized phase.  It
  requires the completed recovery marker and the completed local-quarantine
  deletion audit, reruns the canonical/representation audit, and deletes only
  exact receipt-linked recovery-retirement and local-evidence payloads.  It
  never sweeps ``_temp`` and never targets reports, receipts, archives,
  canonical repositories, runner-continuity evidence, or unrelated/failed
  transactions.

With no mutation mode selected (or with ``--preflight-only``), all checks are
read-only and the complete blocker summary is emitted to stdout.  There is no
ZIP path in this utility.  Canonical repositories and durable proof records are
never deletion targets.
"""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import dataclasses
import errno
import functools
import hashlib
import json
import os
import plistlib
import re
import runpy
import shlex
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path, PurePosixPath
from typing import Iterable, Iterator, Mapping as TypingMapping, Sequence


CAPTURED_USER_HOME = Path.home().expanduser().resolve(strict=True)
APPLY_TOKEN = "RETIRE-VERIFIED-LOCAL-SOURCES"
DELETE_TOKEN = "DELETE-VERIFIED-LOCAL-QUARANTINE"
EXTERNAL_TEMP_DELETE_TOKEN = "DELETE-VERIFIED-EXTERNAL-TEMP-PAYLOADS"
RUNNER_DRAIN_TOKEN = "DRAIN-EXACT-RUNNERS-BEFORE-MERGE"
RUNNER_RESTORE_TOKEN = "RESTORE-EXACT-RUNNERS-AFTER-VERIFIED-MERGE"
RUNNER_ABORT_TOKEN = "ABORT-EXACT-RUNNER-DRAIN"
RUNNER_DRAIN_PROOF_KIND = "csa-iem-runner-drain-v1"
WORKSPACE_ROOT_PROOF_KIND = "csa-iem-workspace-root-v1"
WORKSPACE_ROOT_MANIFEST_KIND = "csa-iem-workspace-root-manifest-v1"
WORKSPACE_ROOT_PROOF_STATUS = "atomic-nonrepository-merge-complete"
WORKSPACE_DESTINATION_VARIANT_POLICY = "preserve-conflicts-never-overwrite"
WORKSPACE_COVERAGE_KINDS = {
    "canonical-nonrepository",
    "canonical-preserved-variant",
    "separate-project-proof",
    "managed-evidence-only",
}
TREE_ALGORITHM = "csa-iem-stable-tree-sha256-v1"
RECEIPT_FORMAT = 3
REPRESENTATION_FORMAT = 1
SUCCESS_MARKER = "transaction-success.json"
SYSTEM_MANAGED_RECORD_ONLY_XATTRS = frozenset({"com.apple.provenance"})
CRITICAL_RUNNER_FILES = (
    ".credentials",
    ".credentials_rsaparams",
    ".runner",
    ".env",
    "bin/Runner.Listener",
    "runsvc.sh",
)
FINAL_RECEIPT_STATUS = "finalized-after-destination-group-proof"
REPRESENTATION_STATUSES = {
    "canonical-and-evidence-complete",
    "evidence-only-complete",
    "pointer-only-evidence-complete",
    "broken-git-evidence-complete",
}
GIT_EVIDENCE_STATUSES = {
    "history-imported-complete",
    "pointer-only-evidence-complete",
    "broken-git-evidence-complete",
    "no-git-entry",
}
INVENTORY_DECISIONS = {"evidence-only", "protected"}
PROJECT_MARKERS = {
    "Package.swift",
    "Cargo.toml",
    "go.mod",
    "package.json",
    "pyproject.toml",
    "requirements.txt",
    "firebase.json",
    "Gemfile",
    "Podfile",
    "composer.json",
    "pom.xml",
    "build.gradle",
    "build.gradle.kts",
    ".project",
}
RUNNER_PROCESS_NAMES = {
    "Runner.Listener",
    "Runner.Worker",
    "RunnerService",
    "runsvc.sh",
    "run-helper.sh",
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
REPOSITORY_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
ACTIVE_CHECKOUT = Path(__file__).absolute().parent
LAUNCH_CWD = Path(os.path.abspath(os.getcwd()))
RECOVERY_TEMP_AUXILIARY_PAYLOADS = frozenset({"destination-staging", "live-remotes"})


class CleanupError(RuntimeError):
    """A fail-closed cleanup validation or execution error."""


def user_home_boundary() -> Path:
    if not CAPTURED_USER_HOME.is_absolute():
        raise CleanupError(f"Captured user home is not absolute: {CAPTURED_USER_HOME}")
    try:
        mode = os.lstat(CAPTURED_USER_HOME).st_mode
    except OSError as error:
        raise CleanupError(f"Captured user home is unavailable: {CAPTURED_USER_HOME}: {error}") from error
    if stat.S_ISLNK(mode) or not stat.S_ISDIR(mode):
        raise CleanupError(f"Captured user home is not a real directory: {CAPTURED_USER_HOME}")
    return CAPTURED_USER_HOME


@dataclasses.dataclass(frozen=True)
class CleanupLink:
    path: Path
    target: Path


@dataclasses.dataclass(frozen=True)
class OverlayOverride:
    relative_path: PurePosixPath
    target: Path


@dataclasses.dataclass(frozen=True)
class CleanupOverlay:
    path: Path
    base_target: Path
    overrides: tuple[OverlayOverride, ...]


@dataclasses.dataclass(frozen=True)
class InventoryDecision:
    path: Path
    disposition: str
    evidence_status: str = ""


@dataclasses.dataclass(frozen=True)
class CleanupRoot:
    path: Path
    links: tuple[CleanupLink, ...]
    overlays: tuple[CleanupOverlay, ...]
    decisions: tuple[InventoryDecision, ...]
    origin: str
    retirement_group: str = ""
    requires_process_drain: bool = False


@dataclasses.dataclass(frozen=True)
class MappingRow:
    raw: dict[str, object]
    source: Path
    destination: Path
    destination_owner: str
    destination_name: str
    repository: str
    kind: str
    digest: str


@dataclasses.dataclass(frozen=True)
class MappingOverlap:
    parent: Path
    child: Path
    relative_child: str
    declared_exclusion: str
    resolved: bool


@dataclasses.dataclass(frozen=True)
class CleanupPlan:
    path: Path
    source_map_sha256: str
    mappings: tuple[MappingRow, ...]
    roots: tuple[CleanupRoot, ...]
    overlaps: tuple[MappingOverlap, ...]
    github_accounts: dict[str, str]
    github_accounts_sha256: str
    repository_identities: dict[str, dict[str, str]]
    repository_identities_sha256: str


@dataclasses.dataclass
class InventoryResult:
    root: Path
    entry_count: int = 0
    logical_bytes: int = 0
    allocated_bytes: int = 0
    git_roots: list[dict[str, object]] = dataclasses.field(default_factory=list)
    project_markers: list[str] = dataclasses.field(default_factory=list)
    owner_lanes: list[str] = dataclasses.field(default_factory=list)
    uncovered: list[str] = dataclasses.field(default_factory=list)
    uncovered_count: int = 0
    special_files: list[dict[str, str]] = dataclasses.field(default_factory=list)
    fsmonitor_sockets: list[str] = dataclasses.field(default_factory=list)
    errors: list[str] = dataclasses.field(default_factory=list)


@dataclasses.dataclass(frozen=True)
class ProcessInfo:
    pid: int
    ppid: int
    command: str


@dataclasses.dataclass(frozen=True)
class ProcessReference:
    pid: int
    command_name: str
    kind: str
    path: str


@dataclasses.dataclass(frozen=True)
class RunnerService:
    label: str
    plist: Path
    loaded: bool
    launch_pid: int | None
    listener_active: bool
    disabled: bool = False
    plist_sha256: str = ""
    worker_active: bool = False


@dataclasses.dataclass
class RunnerState:
    root: Path
    services: list[RunnerService]
    runner_pids: set[int]
    critical_hashes: dict[str, dict[str, str]]
    canonical_root: Path
    blockers: list[str]
    drained: bool = False


@dataclasses.dataclass(frozen=True)
class ReceiptBinding:
    mapping: MappingRow
    receipt_path: Path
    receipt: dict[str, object]
    representation_path: Path
    representation_sha256: str
    group_proof_path: Path
    group_proof_sha256: str
    github_account: str
    github_account_binding_sha256: str
    reviewed_repository_identity: dict[str, str]


@dataclasses.dataclass(frozen=True)
class WorkspaceRootBinding:
    root: CleanupRoot
    canonical_root: Path
    proof_path: Path
    proof_sha256: str
    proof: dict[str, object]
    manifest_path: Path
    manifest_sha256: str
    manifest: dict[str, object]
    entries: dict[str, dict[str, object]]


@dataclasses.dataclass
class PreflightResult:
    plan: CleanupPlan
    roots: tuple[CleanupRoot, ...]
    inventories: dict[str, InventoryResult]
    bindings: dict[str, ReceiptBinding]
    workspace_bindings: dict[str, WorkspaceRootBinding]
    runner_states: dict[str, RunnerState]
    process_references: dict[str, list[ProcessReference]]
    recovery_transaction: str
    success_marker: dict[str, object]
    volume_identity: dict[str, object]
    errors: list[str]
    warnings: list[str]


def absolute(value: str | Path) -> Path:
    return Path(os.path.abspath(os.path.expanduser(os.fspath(value))))


def display(path: str | Path) -> str:
    return os.fsdecode(os.fspath(path))


def within(path: str | Path, root: str | Path) -> bool:
    """Lexical containment check that never follows a symlink."""
    try:
        return os.path.commonpath([display(absolute(path)), display(absolute(root))]) == display(
            absolute(root)
        )
    except ValueError:
        return False


_PROTECTED_MUTATION_ROOTS: tuple[Path, ...] = ()


def configure_protected_mutation_roots(paths: Sequence[Path]) -> None:
    global _PROTECTED_MUTATION_ROOTS
    normalized: list[Path] = []
    for value in paths:
        path = absolute(value)
        if path.is_symlink() or not path.is_dir():
            raise CleanupError(f"Protected checkout is not a real directory: {path}")
        if path not in normalized:
            normalized.append(path)
    _PROTECTED_MUTATION_ROOTS = tuple(normalized)


def require_unprotected_mutation(path: Path, operation: str) -> None:
    candidate = absolute(path)
    for protected in _PROTECTED_MUTATION_ROOTS:
        if within(candidate, protected) or within(protected, candidate):
            raise CleanupError(
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


def guarded_rmdir(path: Path) -> None:
    require_unprotected_mutation(path, "directory removal")
    path.rmdir()


def guarded_rmtree(path: Path) -> None:
    require_unprotected_mutation(path, "recursive deletion")
    shutil.rmtree(path)


def stable_json(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode(
        "utf-8"
    )


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode):
            raise CleanupError(f"SHA-256 input is not an ordinary file: {path}")
        while True:
            block = os.read(descriptor, 1024 * 1024)
            if not block:
                break
            digest.update(block)
        after = os.fstat(descriptor)
    finally:
        os.close(descriptor)
    stable_fields = ("st_dev", "st_ino", "st_size", "st_mtime_ns", "st_ctime_ns", "st_mode")
    if any(getattr(before, field) != getattr(after, field) for field in stable_fields):
        raise CleanupError(f"File changed while it was being hashed: {path}")
    return digest.hexdigest()


def require_sha256(value: object, label: str) -> str:
    if not isinstance(value, str) or SHA256_RE.fullmatch(value) is None:
        raise CleanupError(f"{label} must be a lowercase SHA-256 digest.")
    return value


def fsync_directory(path: Path) -> None:
    descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def fsync_regular_file(path: Path) -> None:
    descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def secure_mkdirs(path: Path, base: Path, *, mode: int = 0o700) -> None:
    """Create directory components without ever following an existing symlink."""
    path = absolute(path)
    base = absolute(base)
    if not within(path, base):
        raise CleanupError(f"Refused to create directory outside secure base {base}: {path}")
    base_mode = os.lstat(base).st_mode
    if stat.S_ISLNK(base_mode) or not stat.S_ISDIR(base_mode):
        raise CleanupError(f"Secure directory base is not a real directory: {base}")
    current = base
    for part in path.relative_to(base).parts:
        current = current / part
        if os.path.lexists(current):
            current_mode = os.lstat(current).st_mode
            if stat.S_ISLNK(current_mode) or not stat.S_ISDIR(current_mode):
                raise CleanupError(f"Secure directory path contains a non-directory/symlink: {current}")
            continue
        os.mkdir(current, mode=mode)
        fsync_directory(current.parent)


def write_json(path: Path, value: object) -> None:
    """Durably replace a JSON file and fsync its parent directory."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + f".partial-{os.getpid()}")
    payload = json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
    except Exception:
        try:
            guarded_unlink(temporary)
        except OSError:
            pass
        raise
    guarded_replace(temporary, path)
    fsync_directory(path.parent)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + f".partial-{os.getpid()}")
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(value)
            handle.flush()
            os.fsync(handle.fileno())
    except Exception:
        try:
            guarded_unlink(temporary)
        except OSError:
            pass
        raise
    guarded_replace(temporary, path)
    fsync_directory(path.parent)


def identifier(path: Path) -> str:
    label = "".join(character if character.isalnum() or character in "._-" else "-" for character in path.name)
    digest = sha256_bytes(os.fsencode(display(path)))[:12]
    return f"{label.strip('.-') or 'source'}-{digest}"


def validate_transaction_id(value: str, label: str) -> str:
    if (
        not value
        or len(value) > 128
        or value in {".", ".."}
        or re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", value) is None
    ):
        raise CleanupError(f"{label} must be one safe path component.")
    return value


def load_json(path: Path, label: str) -> dict[str, object]:
    descriptor = -1
    try:
        descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode):
            raise CleanupError(f"{label} is not an ordinary file: {path}")
        chunks: list[bytes] = []
        while True:
            block = os.read(descriptor, 1024 * 1024)
            if not block:
                break
            chunks.append(block)
        after = os.fstat(descriptor)
        stable_fields = (
            "st_dev",
            "st_ino",
            "st_size",
            "st_mtime_ns",
            "st_ctime_ns",
            "st_mode",
        )
        if any(getattr(before, field) != getattr(after, field) for field in stable_fields):
            raise CleanupError(f"{label} changed while it was being read: {path}")
        value = json.loads(b"".join(chunks).decode("utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise CleanupError(f"Could not read {label} {path}: {error}") from error
    finally:
        if descriptor >= 0:
            os.close(descriptor)
    if not isinstance(value, dict):
        raise CleanupError(f"{label} must contain a JSON object: {path}")
    return value


def require_owned_nonwritable_regular(path: Path, label: str) -> os.stat_result:
    try:
        metadata = os.lstat(path)
    except OSError as error:
        raise CleanupError(f"{label} is unavailable: {path}: {error}") from error
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISREG(metadata.st_mode):
        raise CleanupError(f"{label} is not an ordinary non-symlink file: {path}")
    if metadata.st_uid != os.getuid():
        raise CleanupError(f"{label} is not owned by the current user: {path}")
    if stat.S_IMODE(metadata.st_mode) & 0o022:
        raise CleanupError(f"{label} is group/world writable: {path}")
    return metadata


def read_stable_regular_bytes(path: Path, label: str) -> bytes:
    require_owned_nonwritable_regular(path, label)
    descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    try:
        before = os.fstat(descriptor)
        chunks: list[bytes] = []
        while True:
            block = os.read(descriptor, 1024 * 1024)
            if not block:
                break
            chunks.append(block)
        after = os.fstat(descriptor)
    finally:
        os.close(descriptor)
    stable_fields = (
        "st_dev",
        "st_ino",
        "st_size",
        "st_mtime_ns",
        "st_ctime_ns",
        "st_mode",
    )
    if any(getattr(before, field) != getattr(after, field) for field in stable_fields):
        raise CleanupError(f"{label} changed while it was being read: {path}")
    return b"".join(chunks)


def safe_relative_path(value: object, label: str) -> PurePosixPath:
    if not isinstance(value, str) or not value or "\\" in value:
        raise CleanupError(f"{label} must be a non-empty POSIX relative path.")
    relative = PurePosixPath(value)
    if relative.is_absolute() or any(part in {"", ".", ".."} for part in relative.parts):
        raise CleanupError(f"{label} contains traversal or an empty component: {value!r}")
    return relative


def ensure_exact_case_real_path(path: Path, base: Path, label: str) -> None:
    """Require an existing, exact-case path with no symlink in any component."""
    path = absolute(path)
    base = absolute(base)
    if not within(path, base):
        raise CleanupError(f"{label} is outside {base}: {path}")
    try:
        base_stat = os.lstat(base)
    except OSError as error:
        raise CleanupError(f"{label} base is unavailable: {base}: {error}") from error
    if stat.S_ISLNK(base_stat.st_mode) or not stat.S_ISDIR(base_stat.st_mode):
        raise CleanupError(f"{label} base must be a real directory: {base}")
    current = base
    for part in path.relative_to(base).parts:
        try:
            names = os.listdir(current)
        except OSError as error:
            raise CleanupError(f"Could not inspect {label} parent {current}: {error}") from error
        if part not in names:
            case_matches = [name for name in names if name.casefold() == part.casefold()]
            detail = f"; case candidates={case_matches!r}" if case_matches else ""
            raise CleanupError(f"{label} does not exist with exact case: {current / part}{detail}")
        current = current / part
        entry = os.lstat(current)
        if stat.S_ISLNK(entry.st_mode):
            raise CleanupError(f"{label} may not traverse a symlink: {current}")
    if not path.is_dir():
        raise CleanupError(f"{label} must be a real directory: {path}")


def ensure_no_symlink_components(path: Path, root: Path, label: str) -> None:
    if not within(path, root):
        raise CleanupError(f"{label} is outside {root}: {path}")
    current = root
    try:
        root_mode = os.lstat(root).st_mode
    except OSError as error:
        raise CleanupError(f"{label} root is unavailable: {root}: {error}") from error
    if stat.S_ISLNK(root_mode) or not stat.S_ISDIR(root_mode):
        raise CleanupError(f"{label} root is not a real directory: {root}")
    for part in path.relative_to(root).parts:
        current = current / part
        try:
            mode = os.lstat(current).st_mode
        except OSError as error:
            raise CleanupError(f"{label} path is unavailable: {current}: {error}") from error
        if stat.S_ISLNK(mode):
            raise CleanupError(f"{label} may not traverse a symlink: {current}")


def ensure_no_symlink_parent_components(path: Path, root: Path, label: str) -> None:
    if path == root:
        return
    ensure_no_symlink_components(path.parent, root, label)


def ensure_exact_case_entry_path(path: Path, root: Path, label: str) -> None:
    """Require exact case and real parents while allowing a symlink only at the leaf."""
    path = absolute(path)
    root = absolute(root)
    if not within(path, root):
        raise CleanupError(f"{label} is outside {root}: {path}")
    try:
        root_mode = os.lstat(root).st_mode
    except OSError as error:
        raise CleanupError(f"{label} root is unavailable: {root}: {error}") from error
    if stat.S_ISLNK(root_mode) or not stat.S_ISDIR(root_mode):
        raise CleanupError(f"{label} root is not a real directory: {root}")
    current = root
    parts = path.relative_to(root).parts
    for index, part in enumerate(parts):
        try:
            names = os.listdir(current)
        except OSError as error:
            raise CleanupError(f"Could not inspect {label} parent {current}: {error}") from error
        if part not in names:
            case_matches = [name for name in names if name.casefold() == part.casefold()]
            detail = f"; case candidates={case_matches!r}" if case_matches else ""
            raise CleanupError(f"{label} does not exist with exact case: {current / part}{detail}")
        current = current / part
        mode = os.lstat(current).st_mode
        if index < len(parts) - 1 and stat.S_ISLNK(mode):
            raise CleanupError(f"{label} may not traverse a symlink parent: {current}")


def repository_from_row(row: dict[str, object], owner: str, name: str) -> str:
    repository = row.get("repository")
    if repository in (None, ""):
        repository = f"{owner}/{name}"
    if not isinstance(repository, str) or REPOSITORY_RE.fullmatch(repository) is None:
        raise CleanupError(f"Invalid repository identity for mapping {row!r}")
    if repository != f"{owner}/{name}":
        raise CleanupError(
            f"Mapping repository identity must exactly match owner/name: {repository} != {owner}/{name}"
        )
    return repository


def parse_mapping_rows(rows: object, repos_root: Path) -> tuple[MappingRow, ...]:
    if not isinstance(rows, list):
        raise CleanupError("Cleanup mapping plan has no mappings array.")
    mappings: list[MappingRow] = []
    seen_sources: set[str] = set()
    for index, raw in enumerate(rows, start=1):
        if not isinstance(raw, dict):
            raise CleanupError(f"Mapping {index} is not an object.")
        source_value = raw.get("source")
        owner = raw.get("destinationOwner")
        name = raw.get("destinationName")
        kind = raw.get("kind")
        if not all(isinstance(value, str) and value for value in (source_value, owner, name, kind)):
            raise CleanupError(f"Mapping {index} lacks source, destinationOwner, destinationName, or kind.")
        if "/" in owner or owner in {".", ".."} or "/" in name or name in {".", ".."}:
            raise CleanupError(f"Mapping {index} has an unsafe destination owner/name.")
        source = absolute(source_value)
        destination = repos_root / owner / name
        repository = repository_from_row(raw, owner, name)
        excluded_relative = raw.get("excludedRelativePaths")
        excluded_alias = raw.get("exclude")
        if excluded_relative is not None and excluded_alias is not None and excluded_relative != excluded_alias:
            raise CleanupError(f"Mapping {index} has conflicting exclude/excludedRelativePaths values.")
        excluded = excluded_relative if excluded_relative is not None else excluded_alias
        if excluded is None:
            excluded = []
        if not isinstance(excluded, list) or any(
            not isinstance(value, str)
            or not value
            or value.startswith("/")
            or "\\" in value
            or any(part in {"", ".", ".."} for part in PurePosixPath(value).parts)
            for value in excluded
        ):
            raise CleanupError(f"Mapping {index} has unsafe excludedRelativePaths.")
        key = display(source)
        if key in seen_sources:
            raise CleanupError(f"Source appears in more than one mapping: {source}")
        seen_sources.add(key)
        mappings.append(
            MappingRow(
                raw=dict(raw),
                source=source,
                destination=destination,
                destination_owner=owner,
                destination_name=name,
                repository=repository,
                kind=kind,
                digest=sha256_bytes(stable_json(raw)),
            )
        )
    return tuple(mappings)


def mapping_exclusions(mapping: MappingRow) -> tuple[str, ...]:
    raw = mapping.raw.get("excludedRelativePaths")
    if raw is None:
        raw = mapping.raw.get("exclude", [])
    assert isinstance(raw, list)
    return tuple(str(value).rstrip("/") for value in raw)


def relative_is_excluded(relative: str, exclusions: Sequence[str]) -> bool:
    if relative == ".":
        return False
    return any(relative == value or relative.startswith(value + "/") for value in exclusions)


def mapping_overlaps(mappings: Sequence[MappingRow]) -> tuple[MappingOverlap, ...]:
    overlaps: list[MappingOverlap] = []
    for parent in mappings:
        for child in mappings:
            if parent is child or not within(child.source, parent.source) or child.source == parent.source:
                continue
            relative = child.source.relative_to(parent.source).as_posix()
            declared = next(
                (
                    value
                    for value in mapping_exclusions(parent)
                    if relative == value or relative.startswith(value + "/")
                ),
                "",
            )
            overlaps.append(
                MappingOverlap(parent.source, child.source, relative, declared, bool(declared))
            )
    return tuple(
        sorted(overlaps, key=lambda value: (os.fsencode(display(value.parent)), os.fsencode(display(value.child))))
    )


def parse_cleanup_links(root: Path, value: object) -> tuple[CleanupLink, ...]:
    if value is None:
        return ()
    if not isinstance(value, list):
        raise CleanupError(f"replacementLinks must be an array for {root}")
    links: list[CleanupLink] = []
    for raw in value:
        if not isinstance(raw, dict) or not isinstance(raw.get("path"), str) or not isinstance(
            raw.get("target"), str
        ):
            raise CleanupError(f"Invalid replacement link for {root}: {raw!r}")
        links.append(CleanupLink(absolute(raw["path"]), absolute(raw["target"])))
    return tuple(links)


def parse_cleanup_overlays(root: Path, value: object) -> tuple[CleanupOverlay, ...]:
    if value is None:
        return ()
    if not isinstance(value, list):
        raise CleanupError(f"replacementOverlays must be an array for {root}")
    overlays: list[CleanupOverlay] = []
    for overlay_index, raw in enumerate(value, start=1):
        if (
            not isinstance(raw, dict)
            or not isinstance(raw.get("path"), str)
            or not isinstance(raw.get("baseTarget"), str)
            or not isinstance(raw.get("overrides"), list)
            or not raw["overrides"]
        ):
            raise CleanupError(f"Invalid replacement overlay {overlay_index} for {root}: {raw!r}")
        overrides: list[OverlayOverride] = []
        for override_index, override in enumerate(raw["overrides"], start=1):
            if not isinstance(override, dict) or not isinstance(override.get("target"), str):
                raise CleanupError(
                    f"Invalid overlay override {overlay_index}.{override_index} for {root}: {override!r}"
                )
            overrides.append(
                OverlayOverride(
                    safe_relative_path(
                        override.get("relativePath"),
                        f"overlay override {overlay_index}.{override_index}",
                    ),
                    absolute(override["target"]),
                )
            )
        overlays.append(
            CleanupOverlay(absolute(raw["path"]), absolute(raw["baseTarget"]), tuple(overrides))
        )
    return tuple(overlays)


def parse_inventory_decisions(root: Path, value: object) -> tuple[InventoryDecision, ...]:
    if value is None:
        return ()
    if not isinstance(value, list):
        raise CleanupError(f"inventoryDecisions must be an array for {root}")
    decisions: list[InventoryDecision] = []
    for raw in value:
        if not isinstance(raw, dict) or not isinstance(raw.get("relativePath"), str):
            raise CleanupError(f"Invalid inventory decision for {root}: {raw!r}")
        disposition = raw.get("disposition")
        if disposition not in INVENTORY_DECISIONS:
            raise CleanupError(f"Invalid inventory disposition for {root}: {disposition!r}")
        relative = safe_relative_path(raw["relativePath"], "inventory decision")
        evidence_status = raw.get("evidenceStatus", "")
        if not isinstance(evidence_status, str):
            raise CleanupError(f"Invalid inventory evidenceStatus for {root}: {evidence_status!r}")
        if evidence_status and evidence_status not in GIT_EVIDENCE_STATUSES:
            raise CleanupError(f"Unsupported inventory evidenceStatus for {root}: {evidence_status!r}")
        decisions.append(
            InventoryDecision(root.joinpath(*relative.parts), str(disposition), evidence_status)
        )
    return tuple(decisions)


def load_plan(path: Path, repos_root: Path) -> CleanupPlan:
    try:
        raw_bytes = read_stable_regular_bytes(path, "cleanup mapping plan")
        payload = json.loads(raw_bytes.decode("utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise CleanupError(f"Could not read mapping plan {path}: {error}") from error
    if not isinstance(payload, dict) or payload.get("format") != 1:
        raise CleanupError("Cleanup mapping plan requires format 1.")
    mappings = parse_mapping_rows(payload.get("mappings"), repos_root)
    github_accounts_value = payload.get("githubAccounts")
    if not isinstance(github_accounts_value, dict):
        raise CleanupError("Cleanup mapping plan requires a reviewed githubAccounts object.")
    github_accounts: dict[str, str] = {}
    for owner, account in github_accounts_value.items():
        if (
            not isinstance(owner, str)
            or not isinstance(account, str)
            or not owner
            or not account
            or re.fullmatch(r"[A-Za-z0-9_.-]+", owner) is None
            or re.fullmatch(r"[A-Za-z0-9_.-]+", account) is None
        ):
            raise CleanupError(f"Invalid reviewed GitHub owner/account binding: {owner!r}: {account!r}")
        github_accounts[owner] = account
    github_accounts_sha256 = sha256_bytes(stable_json(github_accounts))
    repository_identities_value = payload.get("repositoryIdentities")
    if not isinstance(repository_identities_value, dict):
        raise CleanupError("Cleanup mapping plan requires a reviewed repositoryIdentities object.")
    repository_identities: dict[str, dict[str, str]] = {}
    mapped_repositories = {mapping.repository for mapping in mappings}
    for repository, identity_value in repository_identities_value.items():
        if (
            not isinstance(repository, str)
            or REPOSITORY_RE.fullmatch(repository) is None
            or not isinstance(identity_value, dict)
            or not identity_value
            or set(identity_value) - {"databaseID", "nodeID"}
        ):
            raise CleanupError(f"Invalid reviewed repository identity: {repository!r}: {identity_value!r}")
        normalized: dict[str, str] = {}
        for key, value in identity_value.items():
            if not isinstance(value, (str, int)) or not str(value):
                raise CleanupError(f"Invalid reviewed {key} for {repository}: {value!r}")
            if key == "databaseID" and not str(value).isdigit():
                raise CleanupError(f"Reviewed databaseID must be decimal for {repository}: {value!r}")
            normalized[key] = str(value)
        case_matches = [value for value in mapped_repositories if value.casefold() == repository.casefold()]
        if repository not in mapped_repositories:
            detail = f"; mapped case variants={case_matches!r}" if case_matches else ""
            raise CleanupError(f"Reviewed repository identity is not an exact mapped repository: {repository}{detail}")
        repository_identities[repository] = normalized
    repository_identities_sha256 = sha256_bytes(stable_json(repository_identities))
    overlaps = mapping_overlaps(mappings)
    overlap_index = {(display(value.parent), display(value.child)): value for value in overlaps}
    local_rows = payload.get("localCleanupRoots")
    if not isinstance(local_rows, list):
        raise CleanupError("Cleanup mapping plan requires localCleanupRoots.")

    roots: list[CleanupRoot] = []
    if payload.get("retireTransferOriginals") is True:
        transfer_rows = [mapping for mapping in mappings if mapping.kind == "explicit-transfer-original"]
        transfer_sources = [mapping.source for mapping in transfer_rows]
        for mapping in transfer_rows:
            parents = [other for other in transfer_sources if mapping.source != other and within(mapping.source, other)]
            if parents and all(
                overlap_index.get((display(parent), display(mapping.source)), MappingOverlap(parent, mapping.source, "", "", False)).resolved
                for parent in parents
            ):
                # The broader root is the only rename target, but the child
                # mapping remains in plan.mappings and therefore retains its
                # own receipt, repository identity, Git, and representation proof.
                continue
            roots.append(
                CleanupRoot(
                    mapping.source,
                    (CleanupLink(mapping.source, mapping.destination),),
                    (),
                    (),
                    "transfer-original",
                )
            )

    for raw in local_rows:
        if not isinstance(raw, dict) or not isinstance(raw.get("path"), str):
            raise CleanupError(f"Invalid local cleanup row: {raw!r}")
        root = absolute(raw["path"])
        links = parse_cleanup_links(root, raw.get("replacementLinks"))
        overlays = parse_cleanup_overlays(root, raw.get("replacementOverlays"))
        if not links and not overlays:
            raise CleanupError(f"Cleanup root has neither replacementLinks nor replacementOverlays: {root}")
        group = raw.get("retirementGroup", "")
        drain = raw.get("requiresProcessDrain", False)
        if not isinstance(group, str) or not isinstance(drain, bool):
            raise CleanupError(f"Invalid cleanup controls for {root}")
        roots.append(
            CleanupRoot(
                root,
                links,
                overlays,
                parse_inventory_decisions(root, raw.get("inventoryDecisions")),
                "authorized-local-root",
                group,
                drain,
            )
        )
    zero_mapping_roots = [
        item
        for item in roots
        if not any(
            mapping.source == item.path or within(mapping.source, item.path)
            for mapping in mappings
        )
    ]
    if zero_mapping_roots and payload.get("workspaceRootProofContract") != WORKSPACE_ROOT_PROOF_KIND:
        raise CleanupError(
            "Cleanup mapping plan has zero-mapping workspace root(s) but does not declare exact "
            f"workspaceRootProofContract={WORKSPACE_ROOT_PROOF_KIND}: "
            + ", ".join(display(item.path) for item in zero_mapping_roots)
        )
    return CleanupPlan(
        path,
        sha256_bytes(raw_bytes),
        mappings,
        tuple(roots),
        overlaps,
        github_accounts,
        github_accounts_sha256,
        repository_identities,
        repository_identities_sha256,
    )


def validate_override_set(overlay: CleanupOverlay) -> list[str]:
    errors: list[str] = []
    paths = [override.relative_path for override in overlay.overrides]
    if len(set(paths)) != len(paths):
        errors.append(f"Overlay has duplicate override paths: {overlay.path}")
    for index, left in enumerate(paths):
        for right in paths[index + 1 :]:
            left_parts = left.parts
            right_parts = right.parts
            if left_parts == right_parts[: len(left_parts)] or right_parts == left_parts[: len(right_parts)]:
                errors.append(
                    f"Overlay override paths collide as parent/child: {overlay.path}: {left} / {right}"
                )
    return errors


def validate_roots(roots: Sequence[CleanupRoot], managed_root: Path, *, source_required: bool) -> list[str]:
    errors: list[str] = []
    seen_roots: set[str] = set()
    code_repos = managed_root / "Code" / "Repos"
    try:
        ensure_exact_case_real_path(code_repos, managed_root, "managed canonical Code/Repos")
    except CleanupError as error:
        errors.append(str(error))
    for item in roots:
        key = display(item.path)
        if key in seen_roots:
            errors.append(f"Duplicate cleanup root: {item.path}")
        seen_roots.add(key)
        if item.path == ACTIVE_CHECKOUT or within(ACTIVE_CHECKOUT, item.path):
            errors.append(
                f"Protected active checkout may not be a cleanup root or lie below one: "
                f"{ACTIVE_CHECKOUT} / {item.path}"
            )
        if source_required:
            try:
                mode = os.lstat(item.path).st_mode
            except OSError:
                mode = 0
            if not stat.S_ISDIR(mode) or stat.S_ISLNK(mode):
                errors.append(f"Cleanup root is not a real directory: {item.path}")
        home = user_home_boundary()
        if item.path == home or not within(item.path, home):
            errors.append(f"Cleanup root is outside the approved user boundary: {item.path}")
        elif source_required:
            try:
                ensure_exact_case_real_path(item.path, home, "cleanup root")
            except CleanupError as error:
                errors.append(str(error))

        layout_paths: list[Path] = []
        for link in item.links:
            layout_paths.append(link.path)
            if link.path != item.path and not within(link.path, item.path):
                errors.append(f"Replacement link is outside cleanup root: {link.path}")
            if not within(link.target, managed_root):
                errors.append(f"Replacement target is outside managed root: {link.target}")
            try:
                ensure_exact_case_real_path(link.target, managed_root, "replacement link target")
            except CleanupError as error:
                errors.append(str(error))

        for overlay in item.overlays:
            layout_paths.append(overlay.path)
            if overlay.path != item.path and not within(overlay.path, item.path):
                errors.append(f"Replacement overlay is outside cleanup root: {overlay.path}")
            if source_required:
                try:
                    ensure_no_symlink_components(overlay.path, item.path, "existing overlay source path")
                    overlay_mode = os.lstat(overlay.path).st_mode
                    if not stat.S_ISDIR(overlay_mode):
                        raise CleanupError(f"Existing overlay source path is not a directory: {overlay.path}")
                except (CleanupError, OSError) as error:
                    errors.append(str(error))
            for target_label, target in [("overlay baseTarget", overlay.base_target)] + [
                (f"overlay override {override.relative_path}", override.target)
                for override in overlay.overrides
            ]:
                if not within(target, code_repos):
                    errors.append(f"{target_label} is outside managed canonical Code/Repos: {target}")
                    continue
                try:
                    ensure_exact_case_real_path(target, code_repos, target_label)
                except CleanupError as error:
                    errors.append(str(error))
            errors.extend(validate_override_set(overlay))
            for override in overlay.overrides:
                current = overlay.base_target
                for part in override.relative_path.parts:
                    try:
                        names = os.listdir(current)
                    except OSError as error:
                        errors.append(f"Could not inspect overlay base path {current}: {error}")
                        break
                    if part not in names:
                        errors.append(
                            f"Overlay base path lacks exact-case component {part!r}: "
                            f"{overlay.base_target / Path(*override.relative_path.parts)}"
                        )
                        break
                    current = current / part
                    try:
                        component = os.lstat(current)
                    except OSError as error:
                        errors.append(f"Could not lstat overlay base component {current}: {error}")
                        break
                    if stat.S_ISLNK(component.st_mode):
                        errors.append(f"Overlay base path may not follow symlink component: {current}")
                        break

        if len(set(layout_paths)) != len(layout_paths):
            errors.append(f"Replacement layout paths collide for {item.path}")
        for index, left in enumerate(layout_paths):
            for right in layout_paths[index + 1 :]:
                if within(left, right) or within(right, left):
                    errors.append(f"Replacement layout paths overlap for {item.path}: {left} / {right}")
        for decision in item.decisions:
            if not within(decision.path, item.path) or decision.path == item.path:
                errors.append(f"Inventory decision is outside or equal to cleanup root: {decision.path}")

    for index, left in enumerate(roots):
        for right in roots[index + 1 :]:
            if within(left.path, right.path) or within(right.path, left.path):
                errors.append(f"Cleanup roots overlap: {left.path} / {right.path}")
    return errors


def create_symlink_checked(path: Path, target: Path) -> None:
    if os.path.lexists(path):
        raise CleanupError(f"Compatibility path unexpectedly exists: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    os.symlink(display(target), display(path))
    link_stat = os.lstat(path)
    if not stat.S_ISLNK(link_stat.st_mode) or os.readlink(path) != display(target):
        raise CleanupError(f"Compatibility symlink verification failed: {path}")


def _build_overlay_level(
    output: Path,
    base: Path,
    overrides: Sequence[tuple[tuple[str, ...], Path]],
) -> None:
    output.mkdir(mode=0o700)
    base_names = os.listdir(base)
    if len(base_names) != len(set(base_names)):
        raise CleanupError(f"Overlay base has duplicate names: {base}")
    grouped: dict[str, list[tuple[tuple[str, ...], Path]]] = {}
    for parts, target in overrides:
        if not parts:
            raise CleanupError(f"Overlay override unexpectedly ended above leaf: {output}")
        grouped.setdefault(parts[0], []).append((parts[1:], target))
    unknown = sorted(set(grouped) - set(base_names))
    if unknown:
        raise CleanupError(f"Overlay overrides do not exist in base {base} with exact case: {unknown}")

    for name in sorted(base_names, key=os.fsencode):
        base_child = base / name
        output_child = output / name
        selected = grouped.get(name)
        if not selected:
            create_symlink_checked(output_child, base_child)
            continue
        leaves = [(rest, target) for rest, target in selected if not rest]
        descendants = [(rest, target) for rest, target in selected if rest]
        if leaves and descendants:
            raise CleanupError(f"Overlay leaf/descendant collision at {base_child}")
        if len(leaves) > 1:
            raise CleanupError(f"Overlay has duplicate leaf at {base_child}")
        if leaves:
            create_symlink_checked(output_child, leaves[0][1])
            continue
        base_stat = os.lstat(base_child)
        if stat.S_ISLNK(base_stat.st_mode) or not stat.S_ISDIR(base_stat.st_mode):
            raise CleanupError(f"Overlay ancestor must be a real base directory: {base_child}")
        _build_overlay_level(output_child, base_child, descendants)


def build_overlay(output: Path, overlay: CleanupOverlay) -> None:
    tuples = [((tuple(override.relative_path.parts)), override.target) for override in overlay.overrides]
    _build_overlay_level(output, overlay.base_target, tuples)


def build_compatibility_staging(item: CleanupRoot, staging: Path) -> None:
    """Build an entire root replacement off-path without touching the source."""
    if os.path.lexists(staging):
        raise CleanupError(f"Compatibility staging path already exists: {staging}")
    root_links = [link for link in item.links if link.path == item.path]
    if root_links:
        if len(root_links) != 1 or len(item.links) != 1 or item.overlays:
            raise CleanupError(f"A root symlink cannot be combined with nested layouts: {item.path}")
        create_symlink_checked(staging, root_links[0].target)
        return

    root_overlays = [overlay for overlay in item.overlays if overlay.path == item.path]
    if root_overlays:
        if len(root_overlays) != 1 or item.links or len(item.overlays) != 1:
            raise CleanupError(f"A root overlay cannot be combined with nested layouts: {item.path}")
        build_overlay(staging, root_overlays[0])
        fsync_tree(staging)
        return

    staging.mkdir(mode=0o700)
    for link in item.links:
        relative = link.path.relative_to(item.path)
        create_symlink_checked(staging / relative, link.target)
    for overlay in item.overlays:
        relative = overlay.path.relative_to(item.path)
        destination = staging / relative
        if os.path.lexists(destination):
            raise CleanupError(f"Overlay collides with another compatibility path: {overlay.path}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        build_overlay(destination, overlay)
    fsync_tree(staging)


def verify_overlay(path: Path, overlay: CleanupOverlay) -> None:
    root_stat = os.lstat(path)
    if stat.S_ISLNK(root_stat.st_mode) or not stat.S_ISDIR(root_stat.st_mode):
        raise CleanupError(f"Overlay root is not a real directory: {path}")
    expected_overrides = {tuple(item.relative_path.parts): item.target for item in overlay.overrides}

    def verify_level(actual: Path, base: Path, prefix: tuple[str, ...]) -> None:
        actual_names = os.listdir(actual)
        base_names = os.listdir(base)
        if actual_names != base_names and set(actual_names) != set(base_names):
            raise CleanupError(f"Overlay names differ from base: {actual} / {base}")
        for name in base_names:
            current = prefix + (name,)
            exact = expected_overrides.get(current)
            descendants = [key for key in expected_overrides if key[: len(current)] == current]
            actual_child = actual / name
            if exact is not None:
                if not actual_child.is_symlink() or os.readlink(actual_child) != display(exact):
                    raise CleanupError(f"Overlay override does not resolve exactly: {actual_child}")
            elif descendants:
                child_stat = os.lstat(actual_child)
                if stat.S_ISLNK(child_stat.st_mode) or not stat.S_ISDIR(child_stat.st_mode):
                    raise CleanupError(f"Overlay override ancestor is not materialized: {actual_child}")
                verify_level(actual_child, base / name, current)
            else:
                expected = base / name
                if not actual_child.is_symlink() or os.readlink(actual_child) != display(expected):
                    raise CleanupError(f"Overlay base child does not resolve exactly: {actual_child}")

    verify_level(path, overlay.base_target, ())


def verify_compatibility_layout(item: CleanupRoot) -> None:
    root_links = [link for link in item.links if link.path == item.path]
    if root_links:
        link = root_links[0]
        if not link.path.is_symlink() or os.readlink(link.path) != display(link.target):
            raise CleanupError(f"Root compatibility link changed: {link.path}")
        return
    root_stat = os.lstat(item.path)
    if stat.S_ISLNK(root_stat.st_mode) or not stat.S_ISDIR(root_stat.st_mode):
        raise CleanupError(f"Compatibility root is not a real directory: {item.path}")
    for link in item.links:
        if not link.path.is_symlink() or os.readlink(link.path) != display(link.target):
            raise CleanupError(f"Nested compatibility link changed: {link.path}")
    for overlay in item.overlays:
        verify_overlay(overlay.path, overlay)


def remove_path_without_following(path: Path) -> None:
    if not os.path.lexists(path):
        return
    mode = os.lstat(path).st_mode
    if stat.S_ISLNK(mode) or not stat.S_ISDIR(mode):
        guarded_unlink(path)
    else:
        guarded_rmtree(path)


def fsync_tree(root: Path) -> None:
    """Fsync every ordinary file and directory without following symlinks."""
    directories: list[Path] = []
    root_mode = os.lstat(root).st_mode
    if stat.S_ISLNK(root_mode):
        fsync_directory(root.parent)
        return
    for current, directory_names, file_names in os.walk(root, topdown=True, followlinks=False):
        current_path = Path(current)
        directories.append(current_path)
        directory_names[:] = [
            name for name in directory_names if not stat.S_ISLNK(os.lstat(current_path / name).st_mode)
        ]
        for name in file_names:
            path = current_path / name
            mode = os.lstat(path).st_mode
            if stat.S_ISREG(mode):
                fsync_regular_file(path)
    for directory in reversed(directories):
        fsync_directory(directory)
    fsync_directory(root.parent)


def run_command(arguments: Sequence[str | Path], *, timeout: float = 120.0) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [display(argument) for argument in arguments],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
    )


def process_table() -> dict[int, ProcessInfo]:
    result = run_command(["ps", "-axo", "pid=,ppid=,command="], timeout=30)
    if result.returncode != 0:
        raise CleanupError(f"Could not inspect process table: {result.stderr.decode('utf-8', 'replace').strip()}")
    values: dict[int, ProcessInfo] = {}
    for line in result.stdout.decode("utf-8", "replace").splitlines():
        match = re.match(r"^\s*(\d+)\s+(\d+)\s+(.*)$", line)
        if match:
            pid, ppid, command = match.groups()
            values[int(pid)] = ProcessInfo(int(pid), int(ppid), command)
    return values


def process_descendants(table: TypingMapping[int, ProcessInfo], roots: Iterable[int]) -> set[int]:
    descendants = set(roots)
    changed = True
    while changed:
        changed = False
        for pid, info in table.items():
            if info.ppid in descendants and pid not in descendants:
                descendants.add(pid)
                changed = True
    return descendants


def lsof_records(arguments: Sequence[str | Path]) -> list[tuple[int, str, str, str]]:
    result = run_command(["lsof", "-nP", "-Fpcfn", *arguments], timeout=180)
    if result.returncode not in {0, 1}:
        raise CleanupError(f"lsof failed: {result.stderr.decode('utf-8', 'replace').strip()}")
    records: list[tuple[int, str, str, str]] = []
    pid = -1
    command = ""
    descriptor = ""
    for raw in result.stdout.decode("utf-8", "replace").splitlines():
        if not raw:
            continue
        code, value = raw[0], raw[1:]
        if code == "p":
            try:
                pid = int(value)
            except ValueError:
                pid = -1
        elif code == "c":
            command = value
        elif code == "f":
            descriptor = value
        elif code == "n" and pid >= 0:
            records.append((pid, command, descriptor, value))
    return records


def command_argument_paths(info: ProcessInfo) -> Iterator[Path]:
    try:
        tokens = shlex.split(info.command)
    except ValueError:
        tokens = info.command.split()
    for token in tokens:
        if token.startswith("/"):
            yield absolute(token)


def process_references(root: Path, table: TypingMapping[int, ProcessInfo]) -> list[ProcessReference]:
    values: dict[tuple[int, str, str], ProcessReference] = {}
    # ``lsof +D`` recursively walks every directory before returning. The old
    # CSA-iEM Runtime can be very large, so that traversal delays a safety
    # gate without inspecting a broader process set. A normal global lsof
    # snapshot includes cwd, executable text, and every open descriptor; we
    # retain only descriptors that resolve within this exact approved root.
    for pid, command, descriptor, name in lsof_records([]):
        candidate = absolute(name) if name.startswith("/") else None
        if candidate is not None and within(candidate, root):
            kind = "cwd" if descriptor == "cwd" else "executable" if descriptor == "txt" else "open-file"
            values[(pid, kind, display(candidate))] = ProcessReference(pid, command, kind, display(candidate))
    for pid, info in table.items():
        for candidate in command_argument_paths(info):
            if within(candidate, root):
                key = (pid, "command-argument", display(candidate))
                values[key] = ProcessReference(pid, Path(info.command.split()[0]).name, "command-argument", display(candidate))
    return sorted(values.values(), key=lambda value: (value.pid, value.kind, value.path))


def component_process_references(
    path: Path,
    table: TypingMapping[int, ProcessInfo],
) -> list[ProcessReference]:
    if path.is_dir() and not path.is_symlink():
        return process_references(path, table)
    values: list[ProcessReference] = []
    for pid, command, descriptor, name in lsof_records([path]):
        if name == display(path):
            kind = "executable" if descriptor == "txt" else "open-file"
            values.append(ProcessReference(pid, command, kind, name))
    return values


def cleanup_git_component_paths(result: PreflightResult) -> list[Path]:
    paths: set[Path] = set()
    for binding in result.bindings.values():
        if not any(
            binding.mapping.source == root.path or within(binding.mapping.source, root.path)
            for root in result.roots
        ):
            continue
        identity = require_identity_object(binding.receipt, "sourceIdentity", "receipt")
        components = identity.get("gitComponents", [])
        if not isinstance(components, list):
            continue
        for component in components:
            if isinstance(component, dict) and isinstance(component.get("path"), str):
                paths.add(absolute(component["path"]))
    for workspace_binding in result.workspace_bindings.values():
        git_roots = workspace_binding.manifest.get("gitRoots", [])
        if not isinstance(git_roots, list):
            continue
        for git_root in git_roots:
            if not isinstance(git_root, dict) or not isinstance(git_root.get("components"), list):
                continue
            for component in git_root["components"]:
                if isinstance(component, dict) and isinstance(component.get("path"), str):
                    paths.add(absolute(component["path"]))
    return sorted(paths, key=lambda path: os.fsencode(display(path)))


def git_component_process_blockers(
    result: PreflightResult,
    table: TypingMapping[int, ProcessInfo],
    *,
    allow_fsmonitor: bool,
) -> tuple[list[str], list[str]]:
    blockers: list[str] = []
    warnings: list[str] = []
    for path in cleanup_git_component_paths(result):
        if not os.path.lexists(path):
            blockers.append(f"Receipt-bound Git component disappeared before process audit: {path}")
            continue
        references = component_process_references(path, table)
        for reference in references:
            info = table.get(reference.pid)
            command = info.command if info else reference.command_name
            if allow_fsmonitor and "fsmonitor--daemon" in command:
                warnings.append(
                    f"Git fsmonitor process requires explicit stop: pid={reference.pid} component={path}"
                )
            else:
                blockers.append(
                    f"Active process references receipt-bound Git component: "
                    f"pid={reference.pid} {reference.command_name} {reference.kind} {reference.path}"
                )
    return blockers, warnings


def parent_process_chain(table: TypingMapping[int, ProcessInfo]) -> set[int]:
    values: set[int] = set()
    pid = os.getpid()
    while pid > 0 and pid not in values:
        values.add(pid)
        info = table.get(pid)
        if info is None:
            break
        pid = info.ppid
    return values


def process_cwds() -> dict[int, Path]:
    values: dict[int, Path] = {}
    for pid, _command, descriptor, name in lsof_records(["-d", "cwd"]):
        if descriptor == "cwd" and name.startswith("/"):
            values[pid] = absolute(name)
    return values


def execution_path_blockers(root: Path, table: TypingMapping[int, ProcessInfo]) -> list[str]:
    blockers: list[str] = []
    protected: list[tuple[str, Path]] = [
        ("cleanup helper", absolute(__file__)),
        ("current working directory", absolute(Path.cwd())),
        ("Python executable", absolute(sys.executable)),
    ]
    if sys.argv and sys.argv[0]:
        protected.append(("executing script", absolute(sys.argv[0])))
    cwds = process_cwds()
    for pid in sorted(parent_process_chain(table)):
        cwd = cwds.get(pid)
        if cwd is not None:
            protected.append((f"parent-process cwd pid={pid}", cwd))
        info = table.get(pid)
        if info:
            for path in command_argument_paths(info):
                protected.append((f"executing process argument pid={pid}", path))
    for label, path in protected:
        if path == root or within(path, root):
            blockers.append(f"Cleanup root contains {label}: {path}")
    return sorted(set(blockers))


def flatten_plist_strings(value: object) -> Iterator[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from flatten_plist_strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from flatten_plist_strings(child)


def launchctl_service(label: str) -> tuple[bool, int | None]:
    domain = f"gui/{os.getuid()}/{label}"
    result = run_command(["launchctl", "print", domain], timeout=30)
    if result.returncode != 0:
        return False, None
    match = re.search(r"^\s*pid\s*=\s*(\d+)\s*$", result.stdout.decode("utf-8", "replace"), re.MULTILINE)
    return True, int(match.group(1)) if match else None


def launchctl_disabled_states() -> dict[str, bool]:
    domain = f"gui/{os.getuid()}"
    result = run_command(["launchctl", "print-disabled", domain], timeout=30)
    if result.returncode != 0:
        raise CleanupError("Could not capture launch-agent disabled/enabled state.")
    output = result.stdout.decode("utf-8", "replace")
    values: dict[str, bool] = {}
    for label, state_value in re.findall(
        r'"([^"\\]+)"\s*=>\s*(true|false|enabled|disabled)', output
    ):
        values[label] = state_value in {"true", "disabled"}
    return values


def set_launchctl_disabled(label: str, disabled: bool) -> None:
    action = "disable" if disabled else "enable"
    target = f"gui/{os.getuid()}/{label}"
    result = run_command(["launchctl", action, target], timeout=30)
    if result.returncode != 0:
        raise CleanupError(f"Could not {action} exact runner service {label}.")


def service_listener_active(service: RunnerService, table: TypingMapping[int, ProcessInfo]) -> bool:
    loaded, pid = launchctl_service(service.label)
    if not loaded or pid is None:
        return False
    descendants = process_descendants(table, [pid])
    return any(
        process_pid in descendants
        and "Runner.Listener" in info.command
        for process_pid, info in table.items()
    )


def service_worker_active(service: RunnerService, table: TypingMapping[int, ProcessInfo]) -> bool:
    loaded, pid = launchctl_service(service.label)
    if not loaded or pid is None:
        return False
    descendants = process_descendants(table, [pid])
    return any(
        process_pid in descendants and "Runner.Worker" in info.command
        for process_pid, info in table.items()
    )


def root_link_target(item: CleanupRoot) -> Path | None:
    links = [link for link in item.links if link.path == item.path]
    return links[0].target if len(links) == 1 else None


def source_runner_critical_hashes(
    root: Path,
    *,
    relative_base: Path | None = None,
) -> tuple[dict[str, dict[str, str]], list[str]]:
    values: dict[str, dict[str, str]] = {}
    blockers: list[str] = []
    for runner_config in sorted(root.rglob(".runner"), key=lambda path: os.fsencode(display(path))):
        if runner_config.is_symlink() or not runner_config.is_file():
            blockers.append(f"Runner config is not an ordinary file: {runner_config}")
            continue
        runner = runner_config.parent
        relative = runner.relative_to(relative_base or root)
        hashes: dict[str, str] = {}
        for relative_file in CRITICAL_RUNNER_FILES:
            source_file = runner / relative_file
            if not source_file.is_file() or source_file.is_symlink():
                blockers.append(f"Runner critical file is missing or not ordinary: {source_file}")
                continue
            hashes[relative_file] = sha256_file(source_file)
        values[display(relative)] = hashes
    if not values:
        blockers.append(f"No runner configurations were found under process-drain root: {root}")
    return values, blockers


def runner_critical_hashes(root: Path, canonical_root: Path) -> tuple[dict[str, dict[str, str]], list[str]]:
    values, blockers = source_runner_critical_hashes(root)
    for relative, hashes in values.items():
        canonical = canonical_root / relative
        for relative_file, source_digest in hashes.items():
            canonical_file = canonical / relative_file
            if not canonical_file.is_file() or canonical_file.is_symlink():
                blockers.append(f"Canonical runner critical file is missing or not ordinary: {canonical_file}")
                continue
            if sha256_file(canonical_file) != source_digest:
                blockers.append(f"Runner critical hash differs: {relative}/{relative_file}")
    return values, blockers


def capture_runner_state(
    item: CleanupRoot,
    table: TypingMapping[int, ProcessInfo],
    *,
    require_canonical_hash_match: bool = True,
    capture_critical_hashes: bool = True,
) -> RunnerState:
    canonical = root_link_target(item)
    blockers: list[str] = []
    if canonical is None:
        return RunnerState(item.path, [], set(), {}, item.path, [f"Runner root lacks a single root link: {item.path}"])
    services: list[RunnerService] = []
    try:
        disabled_states = launchctl_disabled_states()
    except CleanupError as error:
        disabled_states = {}
        blockers.append(str(error))
    launch_agents = user_home_boundary() / "Library" / "LaunchAgents"
    for plist_path in sorted(launch_agents.glob("*.plist"), key=lambda path: os.fsencode(display(path))):
        try:
            with plist_path.open("rb") as handle:
                payload = plistlib.load(handle)
        except (OSError, plistlib.InvalidFileException):
            continue
        strings = list(flatten_plist_strings(payload))
        referenced = [absolute(value) for value in strings if value.startswith("/")]
        if not any(path == item.path or within(path, item.path) for path in referenced):
            continue
        label = payload.get("Label") if isinstance(payload, dict) else None
        if not isinstance(label, str) or not label:
            blockers.append(f"Runner launch agent has no Label: {plist_path}")
            continue
        loaded, launch_pid = launchctl_service(label)
        services.append(
            RunnerService(
                label,
                plist_path,
                loaded,
                launch_pid,
                False,
                disabled_states.get(label, False),
                sha256_file(plist_path),
            )
        )
    if not services:
        blockers.append(f"No runner launch agents reference process-drain root: {item.path}")

    roots = [service.launch_pid for service in services if service.loaded and service.launch_pid]
    runner_pids = process_descendants(table, [pid for pid in roots if pid is not None])
    updated: list[RunnerService] = []
    for service in services:
        descendants = process_descendants(table, [service.launch_pid]) if service.launch_pid else set()
        listener_active = any(
            "Runner.Listener" in info.command
            for pid, info in table.items()
            if pid in descendants
        )
        worker_active = any(
            "Runner.Worker" in info.command
            for pid, info in table.items()
            if pid in descendants
        )
        updated.append(
            dataclasses.replace(
                service,
                listener_active=listener_active,
                worker_active=worker_active,
            )
        )

    for pid in runner_pids:
        info = table.get(pid)
        if info is None:
            continue
        executable = Path(info.command.split()[0]).name if info.command else ""
        if not any(name in info.command or name == executable for name in RUNNER_PROCESS_NAMES):
            blockers.append(f"Unexpected process is descended from runner service pid={pid}: {executable}")
    if len({service.label for service in services}) != len(services):
        blockers.append(f"Runner launch-agent labels are not unique: {item.path}")
    if len({display(service.plist) for service in services}) != len(services):
        blockers.append(f"Runner launch-agent plist paths are not unique: {item.path}")
    if not capture_critical_hashes:
        critical, critical_errors = {}, []
    else:
        critical, critical_errors = (
            runner_critical_hashes(item.path, canonical)
            if require_canonical_hash_match
            else source_runner_critical_hashes(item.path)
        )
    blockers.extend(critical_errors)
    return RunnerState(item.path, updated, runner_pids, critical, canonical, blockers)


def verify_runner_hashes(state: RunnerState, *, root: Path | None = None) -> list[str]:
    errors: list[str] = []
    selected_root = root or state.root
    for relative, expected in state.critical_hashes.items():
        runner = selected_root / relative
        for relative_file, digest in expected.items():
            path = runner / relative_file
            if not path.is_file() or path.is_symlink() or sha256_file(path) != digest:
                errors.append(f"Restored runner critical file differs: {relative}/{relative_file}")
    return errors


def drain_runner_state(state: RunnerState) -> None:
    if state.blockers:
        raise CleanupError("Runner state has blockers: " + "; ".join(state.blockers))
    domain = f"gui/{os.getuid()}"
    changed = False
    try:
        # Disable the exact discovered set before bootout so KeepAlive or an
        # external bootstrap cannot restart a service during the merge window.
        current_disabled = launchctl_disabled_states()
        for service in state.services:
            if current_disabled.get(service.label, False) is not True:
                set_launchctl_disabled(service.label, True)
                changed = True
        for service in state.services:
            if not service.loaded:
                continue
            result = run_command(["launchctl", "bootout", f"{domain}/{service.label}"], timeout=60)
            if result.returncode != 0:
                raise CleanupError(f"Could not boot out exact runner service {service.label}.")
            changed = True

        # launchd may acknowledge a bootout before an idle Listener process
        # has exited. The service is already disabled and has no active Worker
        # job, so request a graceful stop only for exact Runner processes whose
        # executable or command arguments resolve inside this approved source
        # root. Never signal an unrelated process and never escalate to KILL.
        table_after_bootout = process_table()
        exact_runtime_pids = sorted(
            {reference.pid for reference in process_references(state.root, table_after_bootout)}
        )
        # A listener is launched through ``runsvc.sh`` and a node shim, so a
        # graceful stop must include the exact service wrapper/process tree as
        # well as the Listener binary. The root-path predicate is intentionally
        # stronger than process-name matching and excludes Codex itself. This
        # also covers the runner shell wrapper and node shim, whose command
        # line can be relative even while their cwd/executable is exact.
        for pid in exact_runtime_pids:
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                continue
            except PermissionError as error:
                raise CleanupError(f"Could not stop exact runner process pid={pid}: {error}") from error
        state.drained = changed
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            loaded = [service.label for service in state.services if launchctl_service(service.label)[0]]
            disabled = launchctl_disabled_states()
            table = process_table()
            runner_processes = [
                info.pid
                for info in table.values()
                if any(name in info.command for name in ("Runner.Listener", "Runner.Worker"))
                and any(path == state.root or within(path, state.root) for path in command_argument_paths(info))
            ]
            if loaded or runner_processes or not all(
                disabled.get(service.label, False) for service in state.services
            ):
                time.sleep(0.5)
                continue
            references = process_references(state.root, table)
            if (
                not references
            ):
                state.drained = True
                return
            time.sleep(0.5)
        loaded = [service.label for service in state.services if launchctl_service(service.label)[0]]
        disabled = launchctl_disabled_states()
        table = process_table()
        references = process_references(state.root, table)
        runner_processes = [
            info.pid
            for info in table.values()
            if any(name in info.command for name in ("Runner.Listener", "Runner.Worker"))
            and any(path == state.root or within(path, state.root) for path in command_argument_paths(info))
        ]
        enabled = [service.label for service in state.services if not disabled.get(service.label, False)]
        raise CleanupError(
            f"Runner services or references did not drain completely for {state.root}: "
            f"loaded={loaded[:8]} enabled={enabled[:8]} runnerPids={runner_processes[:20]} "
            f"referencePids={sorted({reference.pid for reference in references})[:30]}"
        )
    except Exception as error:
        rollback_error = ""
        if changed:
            state.drained = True
            try:
                restore_runner_state(state)
            except Exception as restore_error:
                rollback_error = f"; exact runner rollback failed: {restore_error}"
        raise CleanupError(f"Runner drain failed for {state.root}: {error}{rollback_error}") from error


def restore_runner_state(
    state: RunnerState,
    *,
    bootstrap_plists: TypingMapping[str, Path] | None = None,
    hash_root: Path | None = None,
) -> None:
    if not state.drained:
        return
    domain = f"gui/{os.getuid()}"
    # A previously loaded-but-disabled service must be temporarily enabled to
    # bootstrap, then returned to its exact prior disabled state.
    for service in state.services:
        if service.loaded:
            set_launchctl_disabled(service.label, False)
        else:
            set_launchctl_disabled(service.label, service.disabled)
    for service in state.services:
        if service.loaded:
            bootstrap_plist = (bootstrap_plists or {}).get(service.label, service.plist)
            result = run_command(["launchctl", "bootstrap", domain, bootstrap_plist], timeout=60)
            if result.returncode != 0 and not launchctl_service(service.label)[0]:
                raise CleanupError(f"Could not restore exact runner service {service.label}.")
        elif launchctl_service(service.label)[0]:
            raise CleanupError(f"Previously-unloaded runner service became loaded: {service.label}")
    for service in state.services:
        set_launchctl_disabled(service.label, service.disabled)
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        all_loaded = all(launchctl_service(service.label)[0] == service.loaded for service in state.services)
        disabled = launchctl_disabled_states()
        disabled_ok = all(disabled.get(service.label, False) == service.disabled for service in state.services)
        table = process_table()
        listeners_ok = all(
            service_listener_active(service, table) == service.listener_active
            for service in state.services
        )
        workers_ok = all(
            service_worker_active(service, table) == service.worker_active
            for service in state.services
        )
        hash_errors = verify_runner_hashes(state, root=hash_root)
        if all_loaded and disabled_ok and listeners_ok and workers_ok and not hash_errors:
            state.drained = False
            return
        time.sleep(0.5)
    raise CleanupError(f"Runner service continuity verification failed for {state.root}")


def runner_state_snapshot(state: RunnerState) -> dict[str, object]:
    """Return a credential-free, hash-only description of the exact runner state."""
    return {
        "root": display(state.root),
        "canonicalRoot": display(state.canonical_root),
        "services": [
            {
                "label": service.label,
                "plist": display(service.plist),
                "plistSHA256": service.plist_sha256,
                "loaded": service.loaded,
                "listenerActive": service.listener_active,
                "disabled": service.disabled,
                "capturedLaunchPID": service.launch_pid,
                "workerActive": service.worker_active,
            }
            for service in state.services
        ],
        "serviceCount": len(state.services),
        "loadedCount": sum(service.loaded for service in state.services),
        "notLoadedCount": sum(not service.loaded for service in state.services),
        "listenerActiveCount": sum(service.listener_active for service in state.services),
        "workerActiveCount": sum(service.worker_active for service in state.services),
        "criticalHashes": state.critical_hashes,
    }


def verify_recorded_runner_state(
    item: CleanupRoot,
    snapshot: dict[str, object],
    table: TypingMapping[int, ProcessInfo],
    *,
    verify_source_runtime_hashes: bool = False,
) -> list[str]:
    errors: list[str] = []
    if snapshot.get("root") != display(item.path):
        return [f"Runner snapshot root mismatch: {item.path}"]
    services = snapshot.get("services")
    if not isinstance(services, list):
        return [f"Runner snapshot lacks services: {item.path}"]
    expected_labels: set[str] = set()
    disabled_states = launchctl_disabled_states()
    for raw in services:
        if not isinstance(raw, dict) or not isinstance(raw.get("label"), str):
            errors.append(f"Runner snapshot has an invalid service: {item.path}")
            continue
        label = str(raw["label"])
        expected_labels.add(label)
        loaded, pid = launchctl_service(label)
        if loaded != raw.get("loaded"):
            errors.append(f"Runner loaded state changed: {label}")
            continue
        if disabled_states.get(label, False) != raw.get("disabled"):
            errors.append(f"Runner disabled state changed: {label}")
        service = RunnerService(
            label,
            absolute(str(raw.get("plist", "/invalid"))),
            bool(raw.get("loaded")),
            pid,
            bool(raw.get("listenerActive")),
            bool(raw.get("disabled")),
            str(raw.get("plistSHA256", "")),
            bool(raw.get("workerActive")),
        )
        if service_listener_active(service, table) != raw.get("listenerActive"):
            errors.append(f"Runner listener state changed: {label}")
        if service_worker_active(service, table) != raw.get("workerActive"):
            errors.append(f"Runner worker state changed: {label}")

    # Discover every launch agent still pointing at this old compatibility path;
    # an unrecorded service would violate the exact-loaded-set contract.
    discovered_labels: set[str] = set()
    launch_agents = user_home_boundary() / "Library" / "LaunchAgents"
    for plist_path in launch_agents.glob("*.plist"):
        try:
            with plist_path.open("rb") as handle:
                payload = plistlib.load(handle)
        except (OSError, plistlib.InvalidFileException):
            continue
        references = [absolute(value) for value in flatten_plist_strings(payload) if value.startswith("/")]
        if not any(path == item.path or within(path, item.path) for path in references):
            continue
        label = payload.get("Label") if isinstance(payload, dict) else None
        if isinstance(label, str):
            discovered_labels.add(label)
    if discovered_labels != expected_labels:
        errors.append(
            f"Runner launch-agent set changed for {item.path}: "
            f"expected={sorted(expected_labels)}, current={sorted(discovered_labels)}"
        )

    critical = snapshot.get("criticalHashes")
    if not isinstance(critical, dict):
        errors.append(f"Runner snapshot lacks critical hashes: {item.path}")
    elif verify_source_runtime_hashes:
        # The old workspace Runtime is read only while the exact service set is
        # quiesced.  Post-restore checks validate canonical Runtime hashes via
        # verify_runner_hashes instead of traversing the active old source.
        for relative, hashes in critical.items():
            if not isinstance(relative, str) or not isinstance(hashes, dict):
                errors.append(f"Runner snapshot critical-hash entry is invalid: {item.path}")
                continue
            for relative_file, expected_digest in hashes.items():
                if not isinstance(relative_file, str) or not isinstance(expected_digest, str):
                    errors.append(f"Runner snapshot critical hash is invalid: {relative}")
                    continue
                path = item.path / relative / relative_file
                if not path.is_file() or path.is_symlink() or sha256_file(path) != expected_digest:
                    errors.append(f"Runner critical file changed: {relative}/{relative_file}")
    return errors


def runner_drain_items(plan: CleanupPlan) -> tuple[CleanupRoot, ...]:
    return tuple(item for item in plan.roots if item.requires_process_drain)


def runner_phase_directory(managed_root: Path, transaction: str) -> Path:
    validate_transaction_id(transaction, "runner drain transaction")
    return managed_root / "_temp" / "RepoConsolidation" / "RunnerDrain" / transaction


def runner_drain_receipt_path(managed_root: Path, transaction: str) -> Path:
    return runner_phase_directory(managed_root, transaction) / "runner-drain-receipt.json"


def runner_service_set_sha256(snapshot: dict[str, object]) -> str:
    services = snapshot.get("services")
    if not isinstance(services, list):
        raise CleanupError("Runner snapshot lacks an exact services array.")
    return sha256_bytes(stable_json(services))


def runner_reference_digest(references: Sequence[ProcessReference]) -> str:
    # Command arguments can contain secrets. Bind only pid, reference kind,
    # and the referenced path; never serialize full process commands.
    return sha256_bytes(
        stable_json(
            [
                {"pid": value.pid, "kind": value.kind, "path": value.path}
                for value in references
            ]
        )
    )


def exact_runner_runtime_roots(state: RunnerState) -> tuple[Path, Path]:
    source_runtime = state.root / "Runtime"
    canonical_runtime = state.canonical_root / "Runtime"
    for label, path in (
        ("source Runtime root", source_runtime),
        ("canonical Runtime root", canonical_runtime),
    ):
        try:
            mode = os.lstat(path).st_mode
        except OSError as error:
            raise CleanupError(f"{label} is unavailable: {path}: {error}") from error
        if stat.S_ISLNK(mode) or not stat.S_ISDIR(mode):
            raise CleanupError(f"{label} is not a real directory: {path}")
    return source_runtime, canonical_runtime


def validate_runner_plist_runtime_bindings(state: RunnerState) -> list[str]:
    errors: list[str] = []
    source_runtime, _canonical_runtime = exact_runner_runtime_roots(state)
    for service in state.services:
        try:
            with service.plist.open("rb") as handle:
                payload = plistlib.load(handle)
        except (OSError, plistlib.InvalidFileException) as error:
            errors.append(f"Could not validate runner plist Runtime binding: {service.label}: {error}")
            continue
        root_references = [
            absolute(value)
            for value in flatten_plist_strings(payload)
            if value.startswith("/")
            and (absolute(value) == state.root or within(absolute(value), state.root))
        ]
        if not root_references:
            errors.append(f"Runner plist has no exact cleanup-root reference: {service.label}")
        elif any(
            reference != source_runtime and not within(reference, source_runtime)
            for reference in root_references
        ):
            errors.append(
                f"Runner plist references cleanup-root data outside exact Runtime child: {service.label}"
            )
    return errors


def validate_runner_process_ownership(
    state: RunnerState,
    references: Sequence[ProcessReference],
    table: TypingMapping[int, ProcessInfo],
) -> list[str]:
    errors: list[str] = []
    unexpected = [reference for reference in references if reference.pid not in state.runner_pids]
    if unexpected:
        errors.append(
            f"Non-runner processes reference runner drain root {state.root}: "
            + "; ".join(
                f"pid={value.pid} {value.kind} {value.path}" for value in unexpected[:20]
            )
        )
    for pid in sorted(state.runner_pids):
        info = table.get(pid)
        if info is None:
            errors.append(f"Runner descendant disappeared during capture: pid={pid}")
            continue
        if not any(name in info.command for name in RUNNER_PROCESS_NAMES):
            errors.append(f"Unexpected active job/process beneath runner service: pid={pid}")
    for service in state.services:
        if service.worker_active:
            errors.append(
                f"Active Runner.Worker job blocks safe pre-merge drain: {service.label}"
            )
    return errors


def build_runner_drain_preflight(
    plan: CleanupPlan,
    managed_root: Path,
    transaction: str,
    recovery_transaction: str,
) -> tuple[list[RunnerState], dict[str, object], list[str], list[str]]:
    validate_transaction_id(transaction, "--transaction-id")
    validate_transaction_id(recovery_transaction, "--recovery-transaction-id")
    errors: list[str] = []
    warnings: list[str] = []
    states: list[RunnerState] = []
    try:
        revalidate_plan_file(plan)
        validate_existing_managed_directory(managed_root / "_temp", managed_root, "managed _temp root")
        volume = volume_identity(managed_root / "_temp", require_external_fields=True)
    except (CleanupError, OSError) as error:
        errors.append(str(error))
        volume = {}
    items = runner_drain_items(plan)
    if not items:
        errors.append("Source map has no requiresProcessDrain cleanup root.")
    try:
        table = process_table()
    except CleanupError as error:
        errors.append(str(error))
        table = {}
    for item in items:
        try:
            root_stat = os.lstat(item.path)
            if stat.S_ISLNK(root_stat.st_mode) or not stat.S_ISDIR(root_stat.st_mode):
                raise CleanupError(f"Runner drain root is not a real directory: {item.path}")
            home = user_home_boundary()
            if item.path == home or not within(item.path, home):
                raise CleanupError(f"Runner drain root is outside the approved user boundary: {item.path}")
            ensure_exact_case_real_path(item.path, home, "runner drain cleanup root")
            canonical = root_link_target(item)
            if canonical is None or not within(canonical, managed_root):
                raise CleanupError(f"Runner drain root lacks one managed canonical root link: {item.path}")
            ensure_exact_case_real_path(canonical, managed_root, "canonical runner root")
            errors.extend(execution_path_blockers(item.path, table))
            state = capture_runner_state(
                item,
                table,
                require_canonical_hash_match=False,
                capture_critical_hashes=False,
            )
            states.append(state)
            errors.extend(state.blockers)
            errors.extend(validate_runner_plist_runtime_bindings(state))
            references = process_references(item.path, table)
            errors.extend(validate_runner_process_ownership(state, references, table))
            warnings.append(
                f"Runner drain capture {item.path}: services={len(state.services)} "
                f"loaded={sum(value.loaded for value in state.services)} "
                f"not-loaded={sum(not value.loaded for value in state.services)} "
                f"listeners={sum(value.listener_active for value in state.services)}"
            )
        except (CleanupError, OSError) as error:
            errors.append(str(error))
    return states, volume, sorted(set(errors)), sorted(set(warnings))


def runner_drain_snapshot(
    state: RunnerState,
    references: Sequence[ProcessReference],
) -> dict[str, object]:
    snapshot = runner_state_snapshot(state)
    snapshot.pop("root", None)
    snapshot.pop("canonicalRoot", None)
    source_runtime, canonical_runtime = exact_runner_runtime_roots(state)
    identity = os.lstat(state.root)
    runtime_identity = os.lstat(source_runtime)
    snapshot["cleanupRoot"] = display(state.root)
    snapshot["sourceRuntimeRoot"] = display(source_runtime)
    snapshot["canonicalRuntimeRoot"] = display(canonical_runtime)
    snapshot["rootIdentity"] = {"device": identity.st_dev, "inode": identity.st_ino}
    snapshot["sourceRuntimeIdentity"] = {
        "device": runtime_identity.st_dev,
        "inode": runtime_identity.st_ino,
    }
    snapshot["serviceSetSHA256"] = runner_service_set_sha256(snapshot)
    snapshot["processReferenceCount"] = len(references)
    snapshot["processReferenceSHA256"] = runner_reference_digest(references)
    return snapshot


def execute_runner_drain(
    plan: CleanupPlan,
    managed_root: Path,
    transaction: str,
    recovery_transaction: str,
    states: Sequence[RunnerState],
    volume: dict[str, object],
) -> tuple[Path, str]:
    fresh_states, fresh_volume, fresh_errors, _fresh_warnings = build_runner_drain_preflight(
        plan,
        managed_root,
        transaction,
        recovery_transaction,
    )
    if fresh_errors:
        raise CleanupError("Runner drain state changed after preflight: " + "; ".join(fresh_errors))
    states = fresh_states
    volume = fresh_volume
    if not states:
        raise CleanupError("Runner drain has no captured state.")
    phase_dir = runner_phase_directory(managed_root, transaction)
    receipt_path = runner_drain_receipt_path(managed_root, transaction)
    if os.path.lexists(phase_dir):
        raise CleanupError(f"Runner drain transaction path already exists: {phase_dir}")
    secure_mkdirs(phase_dir, managed_root / "_temp")
    pre_drain_table = process_table()
    pre_drain_references = [
        process_references(state.root, pre_drain_table) for state in states
    ]
    drained: list[RunnerState] = []
    try:
        write_json(
            phase_dir / "runner-drain-journal.json",
            {
                "format": 1,
                "status": "prechecked",
                "transaction": transaction,
                "recoveryTransaction": recovery_transaction,
                "sourceMapSHA256": plan.source_map_sha256,
                "githubAccountsSHA256": plan.github_accounts_sha256,
                "repositoryIdentitiesSHA256": plan.repository_identities_sha256,
                "managedEvidenceVolume": volume,
                "roots": [
                    {
                        "cleanupRoot": display(state.root),
                        "sourceRuntimeRoot": display(state.root / "Runtime"),
                        "canonicalRuntimeRoot": display(state.canonical_root / "Runtime"),
                        "services": runner_state_snapshot(state)["services"],
                    }
                    for state in states
                ],
            },
        )
        for state in states:
            drain_runner_state(state)
            drained.append(state)
        # Runtime content is first read and hashed only after the exact runner
        # set is disabled, unloaded, and has no remaining process references.
        for state in states:
            source_runtime, _canonical_runtime = exact_runner_runtime_roots(state)
            critical, critical_errors = source_runner_critical_hashes(
                source_runtime,
                relative_base=state.root,
            )
            if critical_errors:
                raise CleanupError("; ".join(critical_errors))
            state.critical_hashes = critical
        snapshots = [
            runner_drain_snapshot(state, references)
            for state, references in zip(states, pre_drain_references)
        ]
        current_volume = volume_identity(managed_root / "_temp", require_external_fields=True)
        if not same_volume_identity(volume, current_volume):
            raise CleanupError("Managed volume identity changed during runner drain.")
        table = process_table()
        for state in states:
            references = process_references(state.root, table)
            if references:
                raise CleanupError(
                    f"Runner root still has cwd/open-file/executable references after drain: {state.root}"
                )
            if any(launchctl_service(service.label)[0] for service in state.services):
                raise CleanupError(f"A captured runner service restarted after drain: {state.root}")
        after_table = process_table()
        receipt_roots: list[dict[str, object]] = []
        for snapshot, state in zip(snapshots, states):
            loaded_rows = [
                {"label": service.label, "loaded": launchctl_service(service.label)[0]}
                for service in state.services
            ]
            disabled_states = launchctl_disabled_states()
            after_references = process_references(state.root, after_table)
            source_runtime, _canonical_runtime = exact_runner_runtime_roots(state)
            runtime_references = process_references(source_runtime, after_table)
            listener_count = sum(service_listener_active(service, after_table) for service in state.services)
            worker_count = sum(service_worker_active(service, after_table) for service in state.services)
            if (
                any(row["loaded"] for row in loaded_rows)
                or any(not disabled_states.get(service.label, False) for service in state.services)
                or after_references
                or runtime_references
                or listener_count
                or worker_count
            ):
                raise CleanupError(f"Exact after-drain state changed before receipt: {state.root}")
            receipt_roots.append(
                {
                    **snapshot,
                    "afterDrain": {
                        "launchctlLoaded": loaded_rows,
                        "allCapturedServicesUnloaded": True,
                        "allCapturedServicesDisabled": True,
                        "listenerActiveCount": listener_count,
                        "workerActiveCount": worker_count,
                        "referenceRoot": display(source_runtime),
                        "processReferenceCount": len(runtime_references),
                        "processReferenceSHA256": runner_reference_digest(runtime_references),
                        "cwdExecutableOpenFileReferencesAbsent": True,
                        "cleanupRootProcessReferenceCount": len(after_references),
                    },
                }
            )
        receipt = {
            "format": 1,
            "proofKind": RUNNER_DRAIN_PROOF_KIND,
            "status": "quiesced",
            "transaction": recovery_transaction,
            "recoveryTransaction": recovery_transaction,
            "drainTransaction": transaction,
            "sourceMapSHA256": plan.source_map_sha256,
            "githubAccountsSHA256": plan.github_accounts_sha256,
            "repositoryIdentitiesSHA256": plan.repository_identities_sha256,
            "managedEvidenceVolume": volume,
            "rootCount": len(receipt_roots),
            "roots": receipt_roots,
            "credentialsSerialized": False,
        }
        write_json(receipt_path, receipt)
        receipt_sha = sha256_file(receipt_path)
        write_json(
            phase_dir / "runner-drain-journal.json",
            {
                **receipt,
                "status": "runner-drain-receipt-durable",
                "runnerDrainReceiptSHA256": receipt_sha,
            },
        )
        fsync_tree(phase_dir)
        return receipt_path, receipt_sha
    except Exception as error:
        invalidation_error = ""
        if os.path.lexists(receipt_path):
            failed_receipt = phase_dir / "failed-runner-drain-receipt.json"
            try:
                guarded_replace(receipt_path, failed_receipt)
                fsync_directory(phase_dir)
            except OSError as receipt_error:
                invalidation_error = str(receipt_error)
        restore_errors: list[str] = []
        if not invalidation_error:
            for state in reversed(drained):
                try:
                    restore_runner_state(state)
                except Exception as restore_error:
                    restore_errors.append(str(restore_error))
        else:
            restore_errors.append(
                "Runner state intentionally remained drained because its authoritative proof "
                f"could not be invalidated: {invalidation_error}"
            )
        try:
            write_json(
                phase_dir / "runner-drain-journal.json",
                {
                    "format": 1,
                    "status": "failed-restored" if not restore_errors else "failed-restore-incomplete",
                    "transaction": transaction,
                    "recoveryTransaction": recovery_transaction,
                    "sourceMapSHA256": plan.source_map_sha256,
                    "errors": [str(error), *restore_errors],
                },
            )
        except OSError:
            pass
        detail = f"; restore errors: {restore_errors}" if restore_errors else ""
        raise CleanupError(f"Pre-merge runner drain failed: {error}{detail}") from error


def discover_runner_launch_agents(root: Path) -> dict[str, tuple[Path, str]]:
    values: dict[str, tuple[Path, str]] = {}
    launch_agents = user_home_boundary() / "Library" / "LaunchAgents"
    for plist_path in sorted(launch_agents.glob("*.plist"), key=lambda path: os.fsencode(display(path))):
        try:
            with plist_path.open("rb") as handle:
                payload = plistlib.load(handle)
        except (OSError, plistlib.InvalidFileException):
            continue
        references = [absolute(value) for value in flatten_plist_strings(payload) if value.startswith("/")]
        if not any(path == root or within(path, root) for path in references):
            continue
        label = payload.get("Label") if isinstance(payload, dict) else None
        if not isinstance(label, str) or not label or label in values:
            raise CleanupError(f"Runner launch-agent identity is missing or duplicated under {root}.")
        if plist_path.is_symlink() or not plist_path.is_file():
            raise CleanupError(f"Runner launch-agent plist is not an ordinary file: {plist_path}")
        values[label] = (plist_path, sha256_file(plist_path))
    return values


def state_from_runner_snapshot(item: CleanupRoot, raw: dict[str, object]) -> RunnerState:
    canonical = root_link_target(item)
    source_runtime = item.path / "Runtime"
    canonical_runtime = canonical / "Runtime" if canonical is not None else None
    if raw.get("cleanupRoot") != display(item.path):
        raise CleanupError(f"Runner drain receipt cleanupRoot mismatch: {item.path}")
    if raw.get("sourceRuntimeRoot") != display(source_runtime):
        raise CleanupError(f"Runner drain receipt sourceRuntimeRoot mismatch: {item.path}")
    if canonical is None or raw.get("canonicalRuntimeRoot") != display(canonical_runtime):
        raise CleanupError(f"Runner drain receipt canonical root mismatch: {item.path}")
    services_raw = raw.get("services")
    if not isinstance(services_raw, list) or not services_raw:
        raise CleanupError(f"Runner drain receipt has no exact service set: {item.path}")
    if runner_service_set_sha256(raw) != raw.get("serviceSetSHA256"):
        raise CleanupError(f"Runner drain receipt service-set digest mismatch: {item.path}")
    discovered = discover_runner_launch_agents(item.path)
    services: list[RunnerService] = []
    for service_raw in services_raw:
        if not isinstance(service_raw, dict):
            raise CleanupError(f"Runner drain receipt contains an invalid service: {item.path}")
        label = service_raw.get("label")
        plist_value = service_raw.get("plist")
        plist_digest = service_raw.get("plistSHA256")
        if (
            not isinstance(label, str)
            or not isinstance(plist_value, str)
            or not isinstance(plist_digest, str)
            or SHA256_RE.fullmatch(plist_digest) is None
            or not isinstance(service_raw.get("loaded"), bool)
            or not isinstance(service_raw.get("listenerActive"), bool)
            or not isinstance(service_raw.get("workerActive"), bool)
            or not isinstance(service_raw.get("disabled"), bool)
        ):
            raise CleanupError(f"Runner drain receipt service fields are invalid: {item.path}")
        plist_path = absolute(plist_value)
        if discovered.get(label) != (plist_path, plist_digest):
            raise CleanupError(f"Runner launch-agent path/hash changed since drain: {label}")
        captured_pid = service_raw.get("capturedLaunchPID")
        if captured_pid is not None and not isinstance(captured_pid, int):
            raise CleanupError(f"Runner drain receipt captured PID is invalid: {label}")
        services.append(
            RunnerService(
                label,
                plist_path,
                service_raw["loaded"],
                captured_pid,
                service_raw["listenerActive"],
                service_raw["disabled"],
                plist_digest,
                service_raw["workerActive"],
            )
        )
    if set(discovered) != {service.label for service in services}:
        raise CleanupError(f"Runner launch-agent set changed since drain: {item.path}")
    if any(service.worker_active for service in services):
        raise CleanupError(f"Runner drain receipt captured an active Worker job: {item.path}")
    expected_counts = {
        "serviceCount": len(services),
        "loadedCount": sum(service.loaded for service in services),
        "notLoadedCount": sum(not service.loaded for service in services),
        "listenerActiveCount": sum(service.listener_active for service in services),
        "workerActiveCount": sum(service.worker_active for service in services),
    }
    for key, expected in expected_counts.items():
        if raw.get(key) != expected:
            raise CleanupError(f"Runner drain receipt {key} mismatch: {item.path}")
    critical = raw.get("criticalHashes")
    if not isinstance(critical, dict) or not critical:
        raise CleanupError(f"Runner drain receipt lacks critical hashes: {item.path}")
    normalized: dict[str, dict[str, str]] = {}
    for relative, hashes in critical.items():
        if not isinstance(relative, str) or not isinstance(hashes, dict):
            raise CleanupError(f"Runner drain receipt critical hash row is invalid: {item.path}")
        normalized_hashes: dict[str, str] = {}
        for relative_file, digest in hashes.items():
            if (
                relative_file not in CRITICAL_RUNNER_FILES
                or not isinstance(digest, str)
                or SHA256_RE.fullmatch(digest) is None
            ):
                raise CleanupError(f"Runner drain receipt critical hash is invalid: {item.path}")
            normalized_hashes[str(relative_file)] = digest
        normalized[relative] = normalized_hashes
    state = RunnerState(item.path, services, set(), normalized, canonical, [], drained=True)
    return state


def load_runner_drain_receipt(
    plan: CleanupPlan,
    managed_root: Path,
    transaction: str,
    recovery_transaction: str,
) -> tuple[dict[str, object], list[RunnerState], str, list[str]]:
    errors: list[str] = []
    path = runner_drain_receipt_path(managed_root, transaction)
    try:
        ensure_no_symlink_components(path, managed_root / "_temp", "runner drain receipt")
        require_owned_nonwritable_regular(path, "runner drain receipt")
        receipt_sha = sha256_file(path)
        receipt = load_json(path, "runner drain receipt")
    except (CleanupError, OSError) as error:
        return {}, [], "", [str(error)]
    if (
        receipt.get("format") != 1
        or receipt.get("proofKind") != RUNNER_DRAIN_PROOF_KIND
        or receipt.get("status") != "quiesced"
        or receipt.get("transaction") != recovery_transaction
        or receipt.get("recoveryTransaction") != recovery_transaction
        or receipt.get("drainTransaction") != transaction
        or receipt.get("sourceMapSHA256") != plan.source_map_sha256
        or receipt.get("githubAccountsSHA256") != plan.github_accounts_sha256
        or receipt.get("repositoryIdentitiesSHA256") != plan.repository_identities_sha256
        or receipt.get("credentialsSerialized") is not False
    ):
        errors.append("Runner drain receipt identity/status binding is invalid.")
    expected_volume = receipt.get("managedEvidenceVolume")
    if not isinstance(expected_volume, dict):
        errors.append("Runner drain receipt lacks managed volume identity.")
    else:
        try:
            current_volume = volume_identity(managed_root / "_temp", require_external_fields=True)
            if not same_volume_identity(expected_volume, current_volume):
                errors.append("Managed volume identity changed since runner drain.")
        except CleanupError as error:
            errors.append(str(error))
    roots_raw = receipt.get("roots")
    items = runner_drain_items(plan)
    if not isinstance(roots_raw, list) or receipt.get("rootCount") != len(items) or len(roots_raw or []) != len(items):
        errors.append("Runner drain receipt root count differs from the source map.")
        roots_raw = []
    rows_by_root = {
        str(value.get("cleanupRoot")): value
        for value in roots_raw
        if isinstance(value, dict) and isinstance(value.get("cleanupRoot"), str)
    }
    states: list[RunnerState] = []
    disabled = {}
    try:
        disabled = launchctl_disabled_states()
    except CleanupError as error:
        errors.append(str(error))
    table: dict[int, ProcessInfo] = {}
    try:
        table = process_table()
    except CleanupError as error:
        errors.append(str(error))
    for item in items:
        raw = rows_by_root.get(display(item.path))
        if raw is None:
            errors.append(f"Runner drain receipt lacks exact root: {item.path}")
            continue
        try:
            identity = raw.get("rootIdentity")
            runtime_identity = raw.get("sourceRuntimeIdentity")
            current = os.lstat(item.path)
            current_runtime = os.lstat(item.path / "Runtime")
            if (
                not isinstance(identity, dict)
                or (current.st_dev, current.st_ino) != (identity.get("device"), identity.get("inode"))
            ):
                raise CleanupError(f"Runner drain source root identity changed: {item.path}")
            if (
                not isinstance(runtime_identity, dict)
                or (current_runtime.st_dev, current_runtime.st_ino)
                != (runtime_identity.get("device"), runtime_identity.get("inode"))
            ):
                raise CleanupError(f"Runner drain source Runtime identity changed: {item.path / 'Runtime'}")
            state = state_from_runner_snapshot(item, raw)
            states.append(state)
            after_drain = raw.get("afterDrain")
            expected_loaded = [
                {"label": service.label, "loaded": False} for service in state.services
            ]
            if (
                not isinstance(after_drain, dict)
                or after_drain.get("launchctlLoaded") != expected_loaded
                or after_drain.get("allCapturedServicesUnloaded") is not True
                or after_drain.get("allCapturedServicesDisabled") is not True
                or after_drain.get("listenerActiveCount") != 0
                or after_drain.get("workerActiveCount") != 0
                or after_drain.get("referenceRoot") != display(item.path / "Runtime")
                or after_drain.get("processReferenceCount") != 0
                or after_drain.get("processReferenceSHA256") != runner_reference_digest([])
                or after_drain.get("cwdExecutableOpenFileReferencesAbsent") is not True
                or after_drain.get("cleanupRootProcessReferenceCount") != 0
            ):
                raise CleanupError(f"Runner drain receipt after-drain proof is incomplete: {item.path}")
            quiescence_errors: list[str] = []
            for service in state.services:
                if launchctl_service(service.label)[0]:
                    quiescence_errors.append(
                        f"Runner service restarted during merge window: {service.label}"
                    )
                if disabled.get(service.label, False) is not True:
                    quiescence_errors.append(
                        f"Runner restart prevention changed during merge window: {service.label}"
                    )
            references = process_references(item.path, table)
            if references:
                quiescence_errors.append(
                    f"Runner source has active references during merge window: {item.path}"
                )
            if quiescence_errors:
                raise CleanupError("; ".join(quiescence_errors))
            # Read Runtime only after live quiescence has been re-established.
            source_hash_errors = verify_runner_hashes(state, root=item.path)
            errors.extend(source_hash_errors)
        except (CleanupError, OSError) as error:
            errors.append(str(error))
    return receipt, states, receipt_sha, sorted(set(errors))


def canonicalize_runner_plist_value(value: object, source_root: Path, canonical_root: Path) -> tuple[object, int]:
    if isinstance(value, str) and value.startswith("/"):
        candidate = absolute(value)
        if candidate == source_root or within(candidate, source_root):
            relative = candidate.relative_to(source_root)
            replacement = canonical_root / relative
            return display(replacement), 1
        return value, 0
    if isinstance(value, list):
        output: list[object] = []
        replacements = 0
        for child in value:
            transformed, count = canonicalize_runner_plist_value(child, source_root, canonical_root)
            output.append(transformed)
            replacements += count
        return output, replacements
    if isinstance(value, dict):
        output_dict: dict[object, object] = {}
        replacements = 0
        for key, child in value.items():
            transformed, count = canonicalize_runner_plist_value(child, source_root, canonical_root)
            output_dict[key] = transformed
            replacements += count
        return output_dict, replacements
    return value, 0


def canonical_runner_plist_payload(state: RunnerState, service: RunnerService) -> dict[str, object]:
    if sha256_file(service.plist) != service.plist_sha256:
        raise CleanupError(f"Runner launch-agent plist changed after drain: {service.label}")
    try:
        with service.plist.open("rb") as handle:
            raw = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException) as error:
        raise CleanupError(f"Could not parse runner launch-agent plist: {service.label}") from error
    if not isinstance(raw, dict) or raw.get("Label") != service.label:
        raise CleanupError(f"Runner launch-agent label changed after drain: {service.label}")
    transformed, replacements = canonicalize_runner_plist_value(raw, state.root, state.canonical_root)
    if not isinstance(transformed, dict) or replacements < 1:
        raise CleanupError(f"Runner launch-agent has no canonicalizable runtime path: {service.label}")
    for value in flatten_plist_strings(transformed):
        if not value.startswith("/"):
            continue
        candidate = absolute(value)
        if candidate == state.canonical_root or within(candidate, state.canonical_root):
            if not os.path.lexists(candidate):
                raise CleanupError(f"Canonical runner launch path is missing for {service.label}: {candidate}")
    return transformed


def write_canonical_bootstrap_plists(state: RunnerState, directory: Path) -> dict[str, Path]:
    output: dict[str, Path] = {}
    for index, service in enumerate(state.services):
        if not service.loaded:
            continue
        payload = canonical_runner_plist_payload(state, service)
        path = directory / f"runner-{index:04d}.plist"
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        try:
            with os.fdopen(descriptor, "wb") as handle:
                plistlib.dump(payload, handle, fmt=plistlib.FMT_BINARY, sort_keys=True)
                handle.flush()
                os.fsync(handle.fileno())
        except Exception:
            try:
                guarded_unlink(path)
            except OSError:
                pass
            raise
        output[service.label] = path
    fsync_directory(directory)
    return output


def build_runner_restore_preflight(
    plan: CleanupPlan,
    managed_root: Path,
    merge_report_dir: Path,
    transaction: str,
    recovery_transaction: str,
) -> tuple[list[RunnerState], dict[str, object], str, list[str], list[str]]:
    receipt, states, drain_sha, errors = load_runner_drain_receipt(
        plan, managed_root, transaction, recovery_transaction
    )
    warnings: list[str] = []
    marker: dict[str, object] = {}
    if errors:
        return states, marker, drain_sha, sorted(set(errors)), warnings
    try:
        marker, receipt_paths = load_success_marker(merge_report_dir, recovery_transaction, plan)
        if marker.get("runnerDrainTransaction") != transaction:
            errors.append("Recovery success marker is bound to a different runner drain transaction.")
        if marker.get("runnerDrainReceiptSHA256") != drain_sha:
            errors.append("Recovery success marker is not bound to the exact runner drain receipt.")
        bindings, binding_errors = load_receipt_bindings(
            plan,
            merge_report_dir,
            managed_root,
            recovery_transaction,
            marker,
            receipt_paths,
        )
        errors.extend(binding_errors)
        workspace_bindings, workspace_errors = load_workspace_root_bindings(
            plan,
            merge_report_dir,
            managed_root,
            recovery_transaction,
            marker,
        )
        errors.extend(workspace_errors)
        gh_cache: dict[str, dict[str, str]] = {}
        fsck_cache: dict[str, str] = {}
        for binding in bindings.values():
            verify_representation_binding(binding, managed_root, merge_report_dir)
            verify_destination_binding(binding, gh_cache, fsck_cache)
        if not workspace_errors:
            for workspace_binding in workspace_bindings.values():
                verify_workspace_root_binding(
                    workspace_binding,
                    managed_root,
                    merge_report_dir,
                    fsmonitor_stopped=True,
                    cleanup_roots=plan.roots,
                )
                warnings.append(
                    f"Whole-workspace proof verified while runner drain remained quiesced: "
                    f"{workspace_binding.root.path}"
                )
    except (CleanupError, OSError) as error:
        errors.append(str(error))
    for state in states:
        try:
            ensure_exact_case_real_path(state.canonical_root, managed_root, "verified canonical runner root")
            _source_runtime, canonical_runtime = exact_runner_runtime_roots(state)
            canonical_runner_set = {
                display(path.parent.relative_to(state.canonical_root))
                for path in canonical_runtime.rglob(".runner")
                if path.is_file() and not path.is_symlink()
            }
            if canonical_runner_set != set(state.critical_hashes):
                raise CleanupError(
                    f"Canonical runner install set differs from drained source: {state.canonical_root}"
                )
            critical_errors = verify_runner_hashes(state, root=state.canonical_root)
            if critical_errors:
                raise CleanupError("; ".join(critical_errors))
            for service in state.services:
                canonical_runner_plist_payload(state, service)
            warnings.append(
                f"Runner restore proof {state.root}: loaded={sum(value.loaded for value in state.services)} "
                f"not-loaded={sum(not value.loaded for value in state.services)} "
                f"listeners={sum(value.listener_active for value in state.services)}"
            )
        except (CleanupError, OSError) as error:
            errors.append(str(error))
    if not receipt:
        errors.append("Runner drain receipt was not loaded.")
    return states, marker, drain_sha, sorted(set(errors)), sorted(set(warnings))


def verify_canonical_runner_processes(state: RunnerState) -> list[str]:
    errors: list[str] = []
    table = process_table()
    source_references = process_references(state.root, table)
    if source_references:
        errors.append(f"Restored runner still references old source runtime: {state.root}")
    for service in state.services:
        loaded, pid = launchctl_service(service.label)
        if loaded != service.loaded:
            errors.append(f"Restored runner loaded state differs: {service.label}")
            continue
        if not service.loaded or pid is None:
            continue
        descendants = process_descendants(table, [pid])
        for process_pid in descendants:
            info = table.get(process_pid)
            if info is None or not any(name in info.command for name in RUNNER_PROCESS_NAMES):
                continue
            command_paths = list(command_argument_paths(info))
            if any(path == state.root or within(path, state.root) for path in command_paths):
                errors.append(f"Runner command still uses old source runtime: {service.label}")
            if not any(
                path == state.canonical_root or within(path, state.canonical_root)
                for path in command_paths
            ):
                errors.append(f"Runner command is not bound to canonical runtime: {service.label}")
    return errors


def execute_runner_restore(
    plan: CleanupPlan,
    managed_root: Path,
    merge_report_dir: Path,
    transaction: str,
    recovery_transaction: str,
    states: Sequence[RunnerState],
    marker: dict[str, object],
    drain_sha: str,
) -> Path:
    fresh_states, fresh_marker, fresh_drain_sha, fresh_errors, _fresh_warnings = (
        build_runner_restore_preflight(
            plan,
            managed_root,
            merge_report_dir,
            transaction,
            recovery_transaction,
        )
    )
    if fresh_errors:
        raise CleanupError(
            "Runner restore proof changed after preflight: " + "; ".join(fresh_errors)
        )
    states = fresh_states
    marker = fresh_marker
    drain_sha = fresh_drain_sha
    if marker.get("runnerDrainReceiptSHA256") != drain_sha:
        raise CleanupError("Runner restore lost its recovery-marker drain binding.")
    attempted: list[RunnerState] = []
    restore_receipt_path = runner_phase_directory(managed_root, transaction) / "runner-restore-receipt.json"
    try:
        with tempfile.TemporaryDirectory(prefix="csa-iem-runner-bootstrap-") as temp_value:
            temporary_root = Path(temp_value)
            for index, state in enumerate(states):
                state_dir = temporary_root / f"root-{index:03d}"
                state_dir.mkdir(mode=0o700)
                bootstrap_plists = write_canonical_bootstrap_plists(state, state_dir)
                attempted.append(state)
                restore_runner_state(
                    state,
                    bootstrap_plists=bootstrap_plists,
                    hash_root=state.canonical_root,
                )
        errors: list[str] = []
        for state in states:
            errors.extend(verify_canonical_runner_processes(state))
            errors.extend(verify_runner_hashes(state, root=state.canonical_root))
        if errors:
            raise CleanupError("; ".join(errors))
        path = restore_receipt_path
        if os.path.lexists(path):
            raise CleanupError(f"Runner restore receipt already exists: {path}")
        write_json(
            path,
            {
                "format": 1,
                "status": "runner-restore-complete-from-canonical",
                "transaction": transaction,
                "recoveryTransaction": recovery_transaction,
                "sourceMapSHA256": plan.source_map_sha256,
                "githubAccountsSHA256": plan.github_accounts_sha256,
                "repositoryIdentitiesSHA256": plan.repository_identities_sha256,
                "runnerDrainProofKind": RUNNER_DRAIN_PROOF_KIND,
                "runnerDrainReceiptSHA256": drain_sha,
                "recoverySuccessMarkerSHA256": sha256_file(merge_report_dir / SUCCESS_MARKER),
                "rootCount": len(states),
                "roots": [runner_state_snapshot(state) for state in states],
                "credentialsSerialized": False,
            },
        )
        fsync_tree(path.parent)
        return path
    except Exception as error:
        invalidation_error = ""
        if os.path.lexists(restore_receipt_path):
            try:
                guarded_replace(
                    restore_receipt_path,
                    restore_receipt_path.with_name("failed-runner-restore-receipt.json"),
                )
                fsync_directory(restore_receipt_path.parent)
            except OSError as receipt_error:
                invalidation_error = str(receipt_error)
        drain_errors: list[str] = []
        if not invalidation_error:
            for state in reversed(attempted):
                try:
                    drain_runner_state(state)
                except Exception as drain_error:
                    drain_errors.append(str(drain_error))
        else:
            drain_errors.append(
                "Runner state intentionally remained restored because its receipt could not "
                f"be invalidated: {invalidation_error}"
            )
        detail = f"; re-drain errors: {drain_errors}" if drain_errors else ""
        raise CleanupError(f"Canonical runner restore failed and remained/re-entered drain: {error}{detail}") from error


def execute_runner_abort(
    plan: CleanupPlan,
    managed_root: Path,
    merge_report_dir: Path,
    transaction: str,
    recovery_transaction: str,
    states: Sequence[RunnerState],
    drain_sha: str,
) -> Path:
    _receipt, fresh_states, fresh_drain_sha, fresh_errors = load_runner_drain_receipt(
        plan,
        managed_root,
        transaction,
        recovery_transaction,
    )
    if fresh_errors:
        raise CleanupError(
            "Runner abort state changed after preflight: " + "; ".join(fresh_errors)
        )
    states = fresh_states
    drain_sha = fresh_drain_sha
    if os.path.lexists(merge_report_dir / SUCCESS_MARKER):
        raise CleanupError("A recovery success marker exists; use verified canonical runner restore, not abort.")
    attempted: list[RunnerState] = []
    abort_receipt_path = runner_phase_directory(managed_root, transaction) / "runner-abort-receipt.json"
    try:
        for state in states:
            attempted.append(state)
            restore_runner_state(state, hash_root=state.root)
        path = abort_receipt_path
        if os.path.lexists(path):
            raise CleanupError(f"Runner abort receipt already exists: {path}")
        write_json(
            path,
            {
                "format": 1,
                "status": "runner-drain-aborted-source-restored",
                "transaction": transaction,
                "recoveryTransaction": recovery_transaction,
                "runnerDrainReceiptSHA256": drain_sha,
                "rootCount": len(states),
                "roots": [runner_state_snapshot(state) for state in states],
                "credentialsSerialized": False,
            },
        )
        fsync_tree(path.parent)
        return path
    except Exception as error:
        invalidation_error = ""
        if os.path.lexists(abort_receipt_path):
            try:
                guarded_replace(
                    abort_receipt_path,
                    abort_receipt_path.with_name("failed-runner-abort-receipt.json"),
                )
                fsync_directory(abort_receipt_path.parent)
            except OSError as receipt_error:
                invalidation_error = str(receipt_error)
        drain_errors: list[str] = []
        if not invalidation_error:
            for state in reversed(attempted):
                try:
                    drain_runner_state(state)
                except Exception as drain_error:
                    drain_errors.append(str(drain_error))
        else:
            drain_errors.append(
                "Runner state intentionally remained restored because its abort receipt could "
                f"not be invalidated: {invalidation_error}"
            )
        detail = f"; re-drain errors: {drain_errors}" if drain_errors else ""
        raise CleanupError(f"Runner drain abort failed: {error}{detail}") from error


def validate_completed_runner_restore(
    plan: CleanupPlan,
    managed_root: Path,
    merge_report_dir: Path,
    recovery_transaction: str,
    success_marker: dict[str, object],
) -> list[str]:
    """Bind normal retirement to the exact phased drain/restore continuity proof."""
    errors: list[str] = []
    transaction = success_marker.get("runnerDrainTransaction")
    expected_drain_sha = success_marker.get("runnerDrainReceiptSHA256")
    if not isinstance(transaction, str) or not isinstance(expected_drain_sha, str):
        return ["Recovery success marker lacks exact runner drain continuity fields."]
    drain_path = runner_drain_receipt_path(managed_root, transaction)
    restore_path = runner_phase_directory(managed_root, transaction) / "runner-restore-receipt.json"
    try:
        ensure_no_symlink_components(drain_path, managed_root / "_temp", "runner drain receipt")
        ensure_no_symlink_components(restore_path, managed_root / "_temp", "runner restore receipt")
        if drain_path.is_symlink() or not drain_path.is_file():
            raise CleanupError(f"Runner drain receipt is missing/not ordinary: {drain_path}")
        if restore_path.is_symlink() or not restore_path.is_file():
            raise CleanupError(f"Runner restore receipt is missing/not ordinary: {restore_path}")
        require_owned_nonwritable_regular(drain_path, "runner drain receipt")
        require_owned_nonwritable_regular(restore_path, "runner restore receipt")
        if sha256_file(drain_path) != expected_drain_sha:
            raise CleanupError("Runner drain receipt differs from the recovery success marker.")
        drain = load_json(drain_path, "runner drain receipt")
        if (
            drain.get("format") != 1
            or drain.get("proofKind") != RUNNER_DRAIN_PROOF_KIND
            or drain.get("status") != "quiesced"
            or drain.get("transaction") != recovery_transaction
            or drain.get("recoveryTransaction") != recovery_transaction
            or drain.get("drainTransaction") != transaction
            or drain.get("sourceMapSHA256") != plan.source_map_sha256
            or drain.get("githubAccountsSHA256") != plan.github_accounts_sha256
            or drain.get("repositoryIdentitiesSHA256") != plan.repository_identities_sha256
            or drain.get("credentialsSerialized") is not False
        ):
            raise CleanupError("Runner drain receipt continuity binding is invalid.")
        rows = drain.get("roots")
        items = runner_drain_items(plan)
        if not isinstance(rows, list) or drain.get("rootCount") != len(items) or len(rows) != len(items):
            raise CleanupError("Runner drain receipt continuity root count changed.")
        rows_by_root = {
            str(row.get("cleanupRoot")): row
            for row in rows
            if isinstance(row, dict) and isinstance(row.get("cleanupRoot"), str)
        }
        states: list[RunnerState] = []
        for item in items:
            row = rows_by_root.get(display(item.path))
            if row is None:
                raise CleanupError(f"Runner drain receipt lost cleanupRoot: {item.path}")
            root_identity = row.get("rootIdentity")
            runtime_identity = row.get("sourceRuntimeIdentity")
            root_stat = os.lstat(item.path)
            runtime_stat = os.lstat(item.path / "Runtime")
            if (
                not isinstance(root_identity, dict)
                or (root_stat.st_dev, root_stat.st_ino)
                != (root_identity.get("device"), root_identity.get("inode"))
                or not isinstance(runtime_identity, dict)
                or (runtime_stat.st_dev, runtime_stat.st_ino)
                != (runtime_identity.get("device"), runtime_identity.get("inode"))
            ):
                raise CleanupError(f"Runner source identity changed after canonical restore: {item.path}")
            state = state_from_runner_snapshot(item, row)
            after = row.get("afterDrain")
            if (
                not isinstance(after, dict)
                or after.get("launchctlLoaded")
                != [{"label": service.label, "loaded": False} for service in state.services]
                or after.get("allCapturedServicesUnloaded") is not True
                or after.get("allCapturedServicesDisabled") is not True
                or after.get("listenerActiveCount") != 0
                or after.get("workerActiveCount") != 0
                or after.get("referenceRoot") != display(item.path / "Runtime")
                or after.get("processReferenceCount") != 0
                or after.get("processReferenceSHA256") != runner_reference_digest([])
                or after.get("cwdExecutableOpenFileReferencesAbsent") is not True
                or after.get("cleanupRootProcessReferenceCount") != 0
            ):
                raise CleanupError(f"Runner after-drain proof changed: {item.path}")
            states.append(state)

        restore = load_json(restore_path, "runner restore receipt")
        expected_restore_roots = [runner_state_snapshot(state) for state in states]
        if (
            restore.get("format") != 1
            or restore.get("status") != "runner-restore-complete-from-canonical"
            or restore.get("transaction") != transaction
            or restore.get("recoveryTransaction") != recovery_transaction
            or restore.get("sourceMapSHA256") != plan.source_map_sha256
            or restore.get("githubAccountsSHA256") != plan.github_accounts_sha256
            or restore.get("repositoryIdentitiesSHA256") != plan.repository_identities_sha256
            or restore.get("runnerDrainProofKind") != RUNNER_DRAIN_PROOF_KIND
            or restore.get("runnerDrainReceiptSHA256") != expected_drain_sha
            or restore.get("recoverySuccessMarkerSHA256")
            != sha256_file(merge_report_dir / SUCCESS_MARKER)
            or restore.get("rootCount") != len(states)
            or restore.get("roots") != expected_restore_roots
            or restore.get("credentialsSerialized") is not False
        ):
            raise CleanupError("Runner restore receipt continuity binding is invalid.")
        table = process_table()
        for item, state, snapshot in zip(items, states, expected_restore_roots):
            errors.extend(verify_recorded_runner_state(item, snapshot, table))
            errors.extend(verify_canonical_runner_processes(state))
            errors.extend(verify_runner_hashes(state, root=state.canonical_root))
    except (CleanupError, OSError) as error:
        errors.append(str(error))
    return sorted(set(errors))


def parse_git_pointer(path: Path) -> tuple[str, Path | None]:
    try:
        mode = os.lstat(path).st_mode
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
    if not match:
        return "broken-pointer", None
    candidate = Path(match.group(1))
    if not candidate.is_absolute():
        candidate = path.parent / candidate
    candidate = absolute(candidate)
    if candidate.is_dir() and not candidate.is_symlink():
        return "linked-pointer", candidate
    return "broken-pointer", candidate


def is_fsmonitor_socket(path: Path) -> bool:
    name = path.name
    if name not in {"fsmonitor--daemon.ipc", "fsmonitor.sock", "fsmonitor.socket"}:
        return False
    return any(part == ".git" or part == "worktrees" for part in path.parts)


def decision_for(path: Path, decisions: Sequence[InventoryDecision]) -> InventoryDecision | None:
    candidates = [decision for decision in decisions if path == decision.path or within(path, decision.path)]
    return max(candidates, key=lambda value: len(value.path.parts), default=None)


def mapping_covers_path(mapping: MappingRow, path: Path) -> bool:
    if path == mapping.source:
        return True
    if not within(path, mapping.source):
        return False
    relative = path.relative_to(mapping.source).as_posix()
    return not relative_is_excluded(relative, mapping_exclusions(mapping))


def inventory_root(
    item: CleanupRoot,
    mappings: Sequence[MappingRow],
    *,
    workspace_coverage: set[str] | None = None,
    workspace_git_roots: set[str] | None = None,
) -> InventoryResult:
    result = InventoryResult(item.path)
    workspace_coverage = workspace_coverage or set()
    workspace_git_roots = workspace_git_roots or set()
    covered_mappings = [
        mapping for mapping in mappings if mapping.source == item.path or within(mapping.source, item.path)
    ]
    covered = [mapping.source for mapping in covered_mappings]
    covered_set = {display(path) for path in covered}
    for decision in item.decisions:
        if decision.disposition == "protected" and os.path.lexists(decision.path):
            result.errors.append(
                f"Protected inventory path remains inside cleanup root and blocks retirement: {decision.path}"
            )

    def is_covered(path: Path) -> bool:
        if decision_for(path, item.decisions) is not None:
            return True
        try:
            relative = "." if path == item.path else path.relative_to(item.path).as_posix()
        except ValueError:
            relative = ""
        if relative in workspace_coverage:
            return True
        return any(mapping_covers_path(mapping, path) for mapping in covered_mappings)

    def is_structural_parent(path: Path) -> bool:
        return any(source != path and within(source, path) for source in covered)

    try:
        root_stat = os.lstat(item.path)
    except OSError as error:
        result.errors.append(f"Could not lstat cleanup root {item.path}: {error}")
        return result
    if not stat.S_ISDIR(root_stat.st_mode) or stat.S_ISLNK(root_stat.st_mode):
        result.errors.append(f"Cleanup root is not a real directory: {item.path}")
        return result

    stack = [item.path]
    while stack:
        current = stack.pop()
        try:
            entries = list(os.scandir(current))
        except OSError as error:
            result.errors.append(f"Could not inventory {current}: {error}")
            continue
        names = {entry.name for entry in entries}
        if ".git" in names:
            git_entry = current / ".git"
            state, target = parse_git_pointer(git_entry)
            result.git_roots.append(
                {"project": display(current), "gitEntry": display(git_entry), "state": state, "target": display(target) if target else ""}
            )
            decision = decision_for(current, item.decisions)
            current_relative = "." if current == item.path else current.relative_to(item.path).as_posix()
            workspace_git_covered = current_relative in workspace_git_roots
            if display(current) not in covered_set and decision is None and not workspace_git_covered:
                result.errors.append(f"Nested Git root lacks an exact mapping or explicit decision: {current}")
            elif display(current) not in covered_set and decision is not None and not workspace_git_covered:
                required_status = (
                    "broken-git-evidence-complete"
                    if state in {"broken-pointer", "unreadable-pointer", "unsupported"}
                    else "pointer-only-evidence-complete"
                    if state == "linked-pointer"
                    else "history-imported-complete"
                )
                if decision.disposition != "evidence-only" or decision.evidence_status != required_status:
                    result.errors.append(
                        f"Unmapped Git root needs explicit evidence-only status {required_status}: {current}"
                    )
        markers = sorted(name for name in names if name in PROJECT_MARKERS or name.endswith(".xcodeproj"))
        for marker in markers:
            marker_path = current / marker
            result.project_markers.append(display(marker_path))
            if not is_covered(marker_path):
                result.errors.append(f"Project marker is not mapped/evidence-only/protected: {marker_path}")

        try:
            relative_parts = current.relative_to(item.path).parts
        except ValueError:
            relative_parts = ()
        for lane_index in range(max(0, len(relative_parts) - 2)):
            if (
                relative_parts[lane_index] in {"Code", "Import", "Runtime"}
                and lane_index + 1 < len(relative_parts)
                and relative_parts[lane_index + 1] == "Repos"
            ):
                owner_lane = item.path.joinpath(*relative_parts[: lane_index + 3])
                lane_text = display(owner_lane)
                if lane_text not in result.owner_lanes:
                    result.owner_lanes.append(lane_text)

        for entry in sorted(entries, key=lambda value: os.fsencode(value.name), reverse=True):
            path = Path(entry.path)
            result.entry_count += 1
            try:
                entry_stat = os.lstat(path)
                mode = entry_stat.st_mode
            except OSError as error:
                result.errors.append(f"Could not lstat inventory entry {path}: {error}")
                continue
            if stat.S_ISREG(mode):
                result.logical_bytes += entry_stat.st_size
                result.allocated_bytes += int(getattr(entry_stat, "st_blocks", 0)) * 512
            if entry_stat.st_dev != root_stat.st_dev:
                result.errors.append(
                    f"Nested filesystem/mount boundary blocks whole-root retirement: {path}"
                )
            if stat.S_ISSOCK(mode):
                if is_fsmonitor_socket(path):
                    result.fsmonitor_sockets.append(display(path))
                    result.special_files.append({"path": display(path), "type": "git-fsmonitor-socket"})
                else:
                    result.special_files.append({"path": display(path), "type": "unknown-socket"})
                    result.errors.append(f"Unknown Unix socket blocks retirement: {path}")
            elif stat.S_ISFIFO(mode):
                result.special_files.append({"path": display(path), "type": "fifo"})
                result.errors.append(f"FIFO blocks retirement: {path}")
            elif stat.S_ISCHR(mode) or stat.S_ISBLK(mode):
                result.special_files.append({"path": display(path), "type": "device"})
                result.errors.append(f"Device node blocks retirement: {path}")
            elif not (
                stat.S_ISDIR(mode) or stat.S_ISREG(mode) or stat.S_ISLNK(mode) or stat.S_ISSOCK(mode)
            ):
                result.special_files.append({"path": display(path), "type": "unknown-special"})
                result.errors.append(f"Unknown special file blocks retirement: {path}")

            if not is_covered(path) and not is_structural_parent(path):
                result.uncovered_count += 1
                if len(result.uncovered) < 100:
                    result.uncovered.append(display(path))
            if stat.S_ISDIR(mode) and not stat.S_ISLNK(mode):
                stack.append(path)

    if not covered and not workspace_coverage:
        result.errors.append(f"No mapped source is covered by cleanup root: {item.path}")
    if result.uncovered_count:
        result.errors.append(
            f"Cleanup root has {result.uncovered_count} ordinary/nonproject entries without a mapping or explicit decision: "
            + ", ".join(result.uncovered[:20])
        )
    return result


def destructive_tree_blockers(root: Path) -> list[str]:
    """Recheck mount boundaries and special files immediately before deletion."""
    blockers: list[str] = []
    root_stat = os.lstat(root)
    stack = [root]
    while stack:
        current = stack.pop()
        for entry in os.scandir(current):
            path = Path(entry.path)
            metadata = os.lstat(path)
            mode = metadata.st_mode
            if metadata.st_dev != root_stat.st_dev:
                blockers.append(f"Nested filesystem/mount boundary: {path}")
                continue
            if stat.S_ISSOCK(mode) or stat.S_ISFIFO(mode) or stat.S_ISCHR(mode) or stat.S_ISBLK(mode):
                blockers.append(f"Special file appeared in deletion target: {path}")
            elif stat.S_ISDIR(mode) and not stat.S_ISLNK(mode):
                stack.append(path)
    return blockers


@functools.lru_cache(maxsize=1)
def acl_library() -> ctypes.CDLL:
    library_name = ctypes.util.find_library("System")
    if not library_name:
        raise CleanupError("Could not locate the macOS ACL library.")
    library = ctypes.CDLL(library_name, use_errno=True)
    for function_name in ("acl_get_file", "acl_get_link_np"):
        function = getattr(library, function_name)
        function.argtypes = [ctypes.c_char_p, ctypes.c_int]
        function.restype = ctypes.c_void_p
    library.acl_free.argtypes = [ctypes.c_void_p]
    library.acl_free.restype = ctypes.c_int
    return library


def has_extended_acl(path: Path) -> bool:
    """Avoid a process spawn for the ordinary no-ACL case."""
    if sys.platform != "darwin":
        return False
    mode = os.lstat(path).st_mode
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
    raise CleanupError(f"Could not probe ACL metadata for {path}: errno {error_number}")


def acl_digest(path: Path) -> str:
    if sys.platform != "darwin":
        return ""
    if not has_extended_acl(path):
        return sha256_bytes(b"")
    result = run_command(["/bin/ls", "-lde", path], timeout=30)
    if result.returncode != 0:
        raise CleanupError(f"Could not read ACL metadata for {path}")
    lines = result.stdout.decode("utf-8", "surrogateescape").splitlines()[1:]
    return sha256_bytes("\n".join(lines).encode("utf-8", "surrogateescape"))


def xattr_digests(path: Path) -> dict[str, str]:
    if hasattr(os, "listxattr") and hasattr(os, "getxattr"):
        try:
            names = os.listxattr(path, follow_symlinks=False)
        except OSError as error:
            if error.errno in {errno.ENOTSUP, errno.EOPNOTSUPP}:
                return {}
            raise CleanupError(f"Could not enumerate extended attributes for {path}: {error}") from error
        values: dict[str, str] = {}
        for name in sorted(names, key=os.fsencode):
            if os.fsdecode(name) in SYSTEM_MANAGED_RECORD_ONLY_XATTRS:
                continue
            try:
                payload = os.getxattr(path, name, follow_symlinks=False)
            except OSError as error:
                raise CleanupError(
                    f"Could not read extended attribute {name!r} from {path}: {error}"
                ) from error
            values[name] = sha256_bytes(payload)
        return values

    # Apple's system Python builds do not consistently expose os.listxattr.
    # Use the native tool in no-follow (-s) mode for symlinks and hash decoded
    # attribute bytes; never log an attribute value.
    if sys.platform != "darwin" or not Path("/usr/bin/xattr").is_file():
        raise CleanupError(f"No no-follow extended-attribute reader is available for {path}")
    symlink_option = ["-s"] if stat.S_ISLNK(os.lstat(path).st_mode) else []
    listing = run_command(["/usr/bin/xattr", *symlink_option, path], timeout=30)
    if listing.returncode != 0:
        raise CleanupError(f"Could not enumerate extended attributes for {path}")
    names = [line for line in listing.stdout.decode("utf-8", "surrogateescape").splitlines() if line]
    values = {}
    for name in sorted(names, key=os.fsencode):
        if os.fsdecode(name) in SYSTEM_MANAGED_RECORD_ONLY_XATTRS:
            continue
        read = run_command(
            ["/usr/bin/xattr", *symlink_option, "-p", "-x", name, path],
            timeout=30,
        )
        if read.returncode != 0:
            raise CleanupError(f"Could not read extended attribute {name!r} from {path}")
        try:
            payload = bytes.fromhex("".join(read.stdout.decode("ascii").split()))
        except (UnicodeError, ValueError) as error:
            raise CleanupError(f"Could not decode extended attribute {name!r} from {path}") from error
        values[name] = sha256_bytes(payload)
    return values


def stable_fingerprint(path: Path) -> dict[str, object]:
    metadata = os.lstat(path)
    mode = metadata.st_mode
    if stat.S_ISREG(mode):
        object_type = "file"
        payload_digest = sha256_file(path)
        after_hash = os.lstat(path)
        fields = ("st_dev", "st_ino", "st_size", "st_mtime_ns", "st_ctime_ns", "st_mode")
        if any(getattr(metadata, field) != getattr(after_hash, field) for field in fields):
            raise CleanupError(f"File changed during stable fingerprint capture: {path}")
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
    xattrs = xattr_digests(path)
    acl = acl_digest(path)
    final_metadata = os.lstat(path)
    metadata_fields = ("st_dev", "st_ino", "st_size", "st_mtime_ns", "st_ctime_ns", "st_mode")
    if any(getattr(metadata, field) != getattr(final_metadata, field) for field in metadata_fields):
        raise CleanupError(f"Filesystem metadata changed during fingerprint capture: {path}")
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


def scan_tree(
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
        mode = os.lstat(current).st_mode
        if stat.S_ISSOCK(mode) and is_fsmonitor_socket(current):
            ephemeral.append(relative)
            continue
        if stat.S_ISSOCK(mode) or stat.S_ISFIFO(mode) or stat.S_ISCHR(mode) or stat.S_ISBLK(mode):
            raise CleanupError(f"Special file cannot enter a stable source digest: {current}")
        records.append(
            {
                "relativePath": relative,
                "fingerprint": stable_fingerprint(current),
                "hardlinkGroup": "",
            }
        )
        current_stat = os.lstat(current)
        if stat.S_ISREG(current_stat.st_mode) and current_stat.st_nlink > 1:
            hardlink_members.setdefault((current_stat.st_dev, current_stat.st_ino), []).append(relative)
        if stat.S_ISDIR(mode) and not stat.S_ISLNK(mode):
            entries = list(os.scandir(current))
            for entry in sorted(entries, key=lambda value: os.fsencode(value.name), reverse=True):
                if exclude_top_git and relative == "." and entry.name == ".git":
                    continue
                child_relative = entry.name if relative == "." else f"{relative}/{entry.name}"
                if relative_is_excluded(child_relative, excluded_relative_paths):
                    continue
                stack.append((Path(entry.path), child_relative))
    records.sort(key=lambda value: os.fsencode(str(value["relativePath"])))
    record_index = {str(record["relativePath"]): record for record in records}
    for members in hardlink_members.values():
        if len(members) < 2:
            continue
        group = sha256_bytes(stable_json(sorted(members)))
        for relative in members:
            record_index[relative]["hardlinkGroup"] = group
    digest = sha256_bytes(stable_json({"algorithm": TREE_ALGORITHM, "entries": records}))
    return records, digest, sorted(ephemeral)


def git_component_paths(
    source: Path,
    *,
    logical_source: Path | None = None,
) -> tuple[list[dict[str, object]], str]:
    dot_git = source / ".git"
    state, git_dir = parse_git_pointer(dot_git)
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
            common_dir = absolute(value if os.path.isabs(value) else git_dir / value)
            components.append(("common-git-dir", common_dir))
        alternates = common_dir / "objects" / "info" / "alternates"
        if alternates.is_file() and not alternates.is_symlink():
            for line in alternates.read_text(encoding="utf-8").splitlines():
                if line.strip():
                    target = Path(line.strip())
                    if not target.is_absolute():
                        target = alternates.parent / target
                    components.append(("alternate-object-dir", absolute(target)))
        lfs = common_dir / "lfs"
        if lfs.exists():
            components.append(("lfs-storage", lfs))
    unique: list[dict[str, object]] = []
    seen: set[tuple[str, str]] = set()
    for role, component in components:
        key = (role, display(component))
        if key in seen:
            continue
        seen.add(key)
        if not os.path.lexists(component):
            raise CleanupError(f"Git component is missing: {role}: {component}")
        records, digest, ephemeral = scan_tree(component, exclude_top_git=False)
        identity = os.lstat(component)
        logical_component = component
        if logical_source is not None and (component == source or within(component, source)):
            logical_component = logical_source / component.relative_to(source)
        unique.append(
            {
                "role": role,
                "path": display(logical_component),
                "device": identity.st_dev,
                "inode": identity.st_ino,
                "treeDigest": digest,
                "entryCount": len(records),
                "ephemeralFsmonitorSockets": ephemeral,
            }
        )
    return unique, git_state


def component_set_digest(components: Sequence[dict[str, object]]) -> str:
    return sha256_bytes(stable_json(list(components)))


def resolve_proof_path(value: object, report_dir: Path, managed_root: Path, label: str) -> Path:
    if not isinstance(value, str) or not value:
        raise CleanupError(f"{label} path is missing.")
    path = absolute(value if os.path.isabs(value) else report_dir / value)
    if within(path, report_dir):
        allowed_base = report_dir
    elif within(path, managed_root):
        allowed_base = managed_root
    else:
        raise CleanupError(f"{label} is outside the recovery report and managed root: {path}")
    ensure_no_symlink_components(path, allowed_base, label)
    require_owned_nonwritable_regular(path, label)
    if os.stat(path).st_dev != os.stat(managed_root).st_dev:
        raise CleanupError(f"{label} crosses a nested filesystem boundary: {path}")
    return path


def receipt_set_sha256(paths: Sequence[Path], report_dir: Path) -> str:
    entries = [
        {"path": display(path.relative_to(report_dir)), "sha256": sha256_file(path)}
        for path in sorted(paths, key=lambda value: os.fsencode(display(value)))
    ]
    return sha256_bytes(stable_json(entries))


def workspace_proof_required_roots(plan: CleanupPlan) -> tuple[CleanupRoot, ...]:
    """Return the exact roots that cannot be retired by mapping receipts alone."""
    return tuple(item for item in plan.roots if not mappings_for_root(plan, item))


def workspace_reference_set_sha256(references: Sequence[dict[str, str]]) -> str:
    normalized = sorted(
        references,
        key=lambda value: (
            os.fsencode(value["cleanupRoot"]),
            os.fsencode(value["path"]),
        ),
    )
    return sha256_bytes(stable_json(normalized))


def load_success_marker(
    report_dir: Path,
    recovery_transaction: str,
    plan: CleanupPlan,
) -> tuple[dict[str, object], list[Path]]:
    marker_path = report_dir / SUCCESS_MARKER
    ensure_no_symlink_components(marker_path, report_dir, "recovery transaction success marker")
    require_owned_nonwritable_regular(marker_path, "recovery transaction success marker")
    marker = load_json(marker_path, "recovery transaction success marker")
    if marker.get("format") != 1 or marker.get("status") != "complete":
        raise CleanupError(f"Recovery transaction success marker is not final: {marker_path}")
    if marker.get("transaction") != recovery_transaction:
        raise CleanupError("Recovery success marker transaction does not match --recovery-transaction-id.")
    if marker.get("sourceMapSHA256") != plan.source_map_sha256:
        raise CleanupError("Recovery success marker is bound to a different source map.")
    if marker.get("githubAccountsSHA256") != plan.github_accounts_sha256:
        raise CleanupError("Recovery success marker is bound to different GitHub account bindings.")
    if marker.get("repositoryIdentitiesSHA256") != plan.repository_identities_sha256:
        raise CleanupError("Recovery success marker is bound to different reviewed repository identities.")
    drain_roots = [root for root in plan.roots if root.requires_process_drain]
    if drain_roots:
        if marker.get("runnerDrainProofKind") != RUNNER_DRAIN_PROOF_KIND:
            raise CleanupError("Recovery success marker has the wrong runner drain proof kind.")
        require_sha256(
            marker.get("runnerDrainReceiptSHA256"),
            "success marker runnerDrainReceiptSHA256",
        )
        runner_transaction = marker.get("runnerDrainTransaction")
        if not isinstance(runner_transaction, str):
            raise CleanupError("Recovery success marker lacks runnerDrainTransaction.")
        validate_transaction_id(runner_transaction, "success marker runnerDrainTransaction")
        if marker.get("runnerDrainRootCount") != len(drain_roots):
            raise CleanupError("Recovery success marker runner drain root count differs from the plan.")
    required_workspace_roots = workspace_proof_required_roots(plan)
    if marker.get("workspaceRootProofKind") != WORKSPACE_ROOT_PROOF_KIND:
        raise CleanupError("Recovery success marker has the wrong workspace-root proof kind.")
    workspace_values = marker.get("workspaceRootProofs")
    if not isinstance(workspace_values, list):
        raise CleanupError("Recovery success marker lacks an explicit workspaceRootProofs array.")
    if (
        marker.get("workspaceRootProofCount") != len(required_workspace_roots)
        or len(workspace_values) != len(required_workspace_roots)
    ):
        raise CleanupError(
            "Recovery success marker workspace-root proof count differs from the zero-mapping cleanup roots."
        )
    required_workspace_paths = {display(item.path) for item in required_workspace_roots}
    normalized_workspace_references: list[dict[str, str]] = []
    seen_workspace_roots: set[str] = set()
    seen_workspace_paths: set[str] = set()
    seen_workspace_digests: set[str] = set()
    for raw in workspace_values:
        if not isinstance(raw, dict) or set(raw) != {
            "cleanupRoot",
            "path",
            "sha256",
            "manifestSHA256",
        }:
            raise CleanupError("Recovery success marker has an invalid workspaceRootProofs entry schema.")
        cleanup_root = raw.get("cleanupRoot")
        if not isinstance(cleanup_root, str) or cleanup_root not in required_workspace_paths:
            raise CleanupError(
                f"Recovery success marker references an unexpected workspace cleanup root: {cleanup_root!r}"
            )
        proof_path = resolve_proof_path(
            raw.get("path"), report_dir, report_dir, "workspace-root proof"
        )
        # Workspace proof and manifest files are recovery evidence.  They must
        # live on the durable recovery-report volume, never at a local source or
        # an arbitrary canonical path.  The loader below re-resolves them with
        # the actual managed root and rehashes both files.
        if not within(proof_path, report_dir):
            raise CleanupError(f"Workspace-root proof is outside the recovery report: {proof_path}")
        proof_digest = require_sha256(raw.get("sha256"), "workspace-root proof sha256")
        manifest_digest = require_sha256(
            raw.get("manifestSHA256"), "workspace-root manifest sha256"
        )
        if sha256_file(proof_path) != proof_digest:
            raise CleanupError(f"Workspace-root proof digest changed: {proof_path}")
        normalized_path = display(proof_path.relative_to(report_dir))
        if cleanup_root in seen_workspace_roots:
            raise CleanupError(f"Workspace-root proof repeats cleanup root: {cleanup_root}")
        if normalized_path in seen_workspace_paths:
            raise CleanupError(f"Workspace-root proof repeats proof path: {proof_path}")
        if proof_digest in seen_workspace_digests:
            raise CleanupError(f"Workspace-root proof digest is reused by more than one root: {proof_digest}")
        seen_workspace_roots.add(cleanup_root)
        seen_workspace_paths.add(normalized_path)
        seen_workspace_digests.add(proof_digest)
        normalized_workspace_references.append(
            {
                "cleanupRoot": cleanup_root,
                "path": normalized_path,
                "sha256": proof_digest,
                "manifestSHA256": manifest_digest,
            }
        )
    if seen_workspace_roots != required_workspace_paths:
        raise CleanupError("Recovery success marker does not bind the exact workspace cleanup-root set.")
    expected_workspace_set = require_sha256(
        marker.get("workspaceRootProofSetSHA256"),
        "success marker workspaceRootProofSetSHA256",
    )
    if workspace_reference_set_sha256(normalized_workspace_references) != expected_workspace_set:
        raise CleanupError("Recovery workspace-root proof reference set changed after finalization.")
    receipt_root = report_dir / "receipts"
    receipt_values = marker.get("receiptFiles")
    if not isinstance(receipt_values, list) or not receipt_values:
        raise CleanupError("Recovery success marker lacks an explicit non-empty receiptFiles list.")
    receipts: list[Path] = []
    seen_receipts: set[str] = set()
    for value in receipt_values:
        if not isinstance(value, str) or not value:
            raise CleanupError("Recovery success marker contains an invalid receiptFiles entry.")
        path = absolute(value if os.path.isabs(value) else report_dir / value)
        if not within(path, receipt_root) or not path.is_file() or path.is_symlink():
            raise CleanupError(f"Recovery success marker references an unsafe receipt file: {path}")
        ensure_no_symlink_components(path, receipt_root, "recovery receipt")
        require_owned_nonwritable_regular(path, "recovery receipt")
        key = display(path)
        if key in seen_receipts:
            raise CleanupError(f"Recovery success marker repeats a receipt file: {path}")
        seen_receipts.add(key)
        receipts.append(path)
    receipts.sort(key=lambda path: os.fsencode(display(path)))
    if marker.get("mappingCount") != len(plan.mappings) or marker.get("receiptCount") != len(receipts):
        raise CleanupError("Recovery success marker mapping/receipt counts do not match the exact plan.")
    expected_set = require_sha256(marker.get("receiptSetSHA256"), "success marker receiptSetSHA256")
    actual_set = receipt_set_sha256(receipts, report_dir)
    if expected_set != actual_set:
        raise CleanupError("Recovery receipt set changed after the final transaction marker.")
    failures = list((report_dir / "failures").glob("*")) if (report_dir / "failures").is_dir() else []
    if failures:
        raise CleanupError(f"Recovery transaction contains {len(failures)} failure record(s).")
    return marker, receipts


def require_identity_object(receipt: dict[str, object], key: str, label: str) -> dict[str, object]:
    value = receipt.get(key)
    if not isinstance(value, dict):
        raise CleanupError(f"{label} lacks {key}.")
    return value


def mapping_is_retained(mapping: MappingRow) -> bool:
    return mapping.raw.get("retention") == "retain"


def validate_receipt_retirement_contract(
    mapping: MappingRow,
    receipt: dict[str, object],
    path: Path,
) -> None:
    """Validate whether recovery retained or moved the exact mapped source."""
    status = receipt.get("recoveryRetirementStatus")
    retired_path = receipt.get("retiredPath")
    if not isinstance(retired_path, str):
        raise CleanupError(f"Receipt retiredPath is not a string: {path}")
    if status == "retired-to-managed-temp-verified":
        if mapping_is_retained(mapping):
            raise CleanupError(f"Recovery retired a mapping marked retain: {mapping.source}")
        if not retired_path:
            raise CleanupError(f"Recovery-retired receipt lacks retiredPath: {path}")
        if receipt.get("deletionEligible") is not True:
            raise CleanupError(f"Recovery-retired receipt is not deletion eligible: {path}")
        return
    if status == "retained-for-stage3":
        if retired_path:
            raise CleanupError(f"Retained receipt unexpectedly names retiredPath: {path}")
        if not mapping_is_retained(mapping) and receipt.get("deletionEligible") is not True:
            raise CleanupError(f"Stage 3 source receipt is not deletion eligible: {path}")
        return
    raise CleanupError(f"Receipt has unsupported recovery retirement status: {path}: {status!r}")


def validate_group_proof(
    reference: dict[str, object],
    mapping: MappingRow,
    report_dir: Path,
    managed_root: Path,
    recovery_transaction: str,
    plan: CleanupPlan,
    success_marker: dict[str, object],
    github_account: str,
    account_binding_sha256: str,
    reviewed_repository_identity: TypingMapping[str, str],
) -> tuple[Path, str]:
    path = resolve_proof_path(reference.get("path"), report_dir, managed_root, "destination group proof")
    expected_digest = require_sha256(reference.get("sha256"), "destination group proof reference sha256")
    if sha256_file(path) != expected_digest:
        raise CleanupError(f"Destination group proof digest changed: {path}")
    accepted = success_marker.get("destinationGroupProofSHA256s")
    if not isinstance(accepted, list) or expected_digest not in accepted:
        raise CleanupError(f"Destination group proof is not bound by the final success marker: {path}")
    proof = load_json(path, "destination group proof")
    if (
        proof.get("format") != 1
        or proof.get("status") != "complete"
        or proof.get("transaction") != recovery_transaction
        or proof.get("sourceMapSHA256") != plan.source_map_sha256
        or proof.get("githubAccountsSHA256") != plan.github_accounts_sha256
        or proof.get("repositoryIdentitiesSHA256") != plan.repository_identities_sha256
        or proof.get("destination") != display(mapping.destination)
        or proof.get("repository") != mapping.repository
        or proof.get("authenticatedLogin") != github_account
        or proof.get("githubAccountBindingSHA256") != account_binding_sha256
        or proof.get("repositoryIdentityBindingSHA256")
        != repository_identity_binding_sha256(mapping.repository, reviewed_repository_identity)
    ):
        raise CleanupError(f"Destination group proof identity/status mismatch: {path}")
    for key in ("nodeID", "databaseID"):
        if not isinstance(proof.get(key), str) or not proof.get(key):
            raise CleanupError(f"Destination group proof lacks {key}: {path}")
    for key, expected in reviewed_repository_identity.items():
        if proof.get(key) != expected:
            raise CleanupError(f"Destination group proof reviewed {key} mismatch: {path}")
    strict = proof.get("strictFsck")
    if not isinstance(strict, dict) or strict.get("status") != "clean" or strict.get("mode") != "full-strict":
        raise CleanupError(f"Destination group proof lacks a clean full-strict fsck result: {path}")
    return path, expected_digest


def load_receipt_bindings(
    plan: CleanupPlan,
    report_dir: Path,
    managed_root: Path,
    recovery_transaction: str,
    success_marker: dict[str, object],
    receipt_paths: Sequence[Path],
) -> tuple[dict[str, ReceiptBinding], list[str]]:
    mappings = {display(mapping.source): mapping for mapping in plan.mappings}
    bindings: dict[str, ReceiptBinding] = {}
    errors: list[str] = []
    for path in receipt_paths:
        try:
            receipt = load_json(path, "recovery receipt")
            source_value = receipt.get("source")
            if not isinstance(source_value, str):
                raise CleanupError(f"Receipt has no source: {path}")
            source = display(absolute(source_value))
            mapping = mappings.get(source)
            if mapping is None:
                raise CleanupError(f"Receipt source is not in the exact source map: {source}")
            if source in bindings:
                raise CleanupError(f"More than one receipt exists for source: {source}")
            if receipt.get("format") != RECEIPT_FORMAT:
                raise CleanupError(f"Receipt must use format {RECEIPT_FORMAT}: {path}")
            if receipt.get("transaction") != recovery_transaction:
                raise CleanupError(f"Receipt transaction mismatch: {path}")
            if receipt.get("sourceMapSHA256") != plan.source_map_sha256:
                raise CleanupError(f"Receipt source-map digest mismatch: {path}")
            if receipt.get("githubAccountsSHA256") != plan.github_accounts_sha256:
                raise CleanupError(f"Receipt GitHub-account map digest mismatch: {path}")
            if receipt.get("repositoryIdentitiesSHA256") != plan.repository_identities_sha256:
                raise CleanupError(f"Receipt repository-identity map digest mismatch: {path}")
            if receipt.get("mappingSHA256") != mapping.digest:
                raise CleanupError(f"Receipt mapping digest mismatch: {path}")
            if receipt.get("status") != FINAL_RECEIPT_STATUS:
                raise CleanupError(f"Receipt is not final: {path}")
            validate_receipt_retirement_contract(mapping, receipt, path)

            source_identity = require_identity_object(receipt, "sourceIdentity", "receipt")
            if source_identity.get("path") != source:
                raise CleanupError(f"Receipt source identity path mismatch: {path}")
            for key in ("device", "inode"):
                if not isinstance(source_identity.get(key), int):
                    raise CleanupError(f"Receipt source identity lacks integer {key}: {path}")
            require_sha256(source_identity.get("treeDigest"), f"receipt {path.name} source treeDigest")
            require_sha256(
                source_identity.get("gitComponentsDigest"),
                f"receipt {path.name} gitComponentsDigest",
            )
            git_components = source_identity.get("gitComponents")
            if not isinstance(git_components, list):
                raise CleanupError(f"Receipt source identity lacks gitComponents array: {path}")
            if component_set_digest(git_components) != source_identity.get("gitComponentsDigest"):
                raise CleanupError(f"Receipt Git component list digest mismatch: {path}")
            if source_identity.get("gitState") not in {"absent", "directory", "linked", "broken"}:
                raise CleanupError(f"Receipt source identity has invalid gitState: {path}")

            destination = require_identity_object(receipt, "destinationIdentity", "receipt")
            github_account = plan.github_accounts.get(mapping.destination_owner)
            if github_account is None:
                raise CleanupError(
                    f"Destination owner has no reviewed GitHub account binding: {mapping.destination_owner}"
                )
            account_binding_digest = github_account_binding_sha256(
                mapping.destination_owner,
                github_account,
            )
            reviewed_repository_identity = plan.repository_identities.get(mapping.repository, {})
            repository_binding_digest = repository_identity_binding_sha256(
                mapping.repository,
                reviewed_repository_identity,
            )
            if (
                receipt.get("authenticatedLogin") != github_account
                or receipt.get("githubAccountBindingSHA256") != account_binding_digest
                or receipt.get("repositoryIdentityBindingSHA256") != repository_binding_digest
            ):
                raise CleanupError(f"Receipt reviewed account/repository binding mismatch: {path}")
            expected_destination = {
                "path": display(mapping.destination),
                "owner": mapping.destination_owner,
                "name": mapping.destination_name,
                "repository": mapping.repository,
            }
            for key, expected in expected_destination.items():
                if destination.get(key) != expected:
                    raise CleanupError(f"Receipt destination {key} mismatch: {path}")
            if destination.get("authenticatedLogin") != github_account:
                raise CleanupError(f"Receipt destination authenticated login mismatch: {path}")
            for key in ("nodeID", "databaseID"):
                if not isinstance(destination.get(key), str) or not destination.get(key):
                    raise CleanupError(f"Receipt destination lacks authoritative {key}: {path}")
            for key, expected in reviewed_repository_identity.items():
                if destination.get(key) != expected:
                    raise CleanupError(f"Receipt destination reviewed {key} mismatch: {path}")

            representation = require_identity_object(receipt, "representationProof", "receipt")
            if representation.get("status") not in REPRESENTATION_STATUSES:
                raise CleanupError(f"Receipt representation proof status is not accepted: {path}")
            representation_path = resolve_proof_path(
                representation.get("path"), report_dir, managed_root, "representation proof"
            )
            representation_digest = require_sha256(
                representation.get("sha256"), "representation proof reference sha256"
            )
            if sha256_file(representation_path) != representation_digest:
                raise CleanupError(f"Representation proof digest changed: {representation_path}")

            group_reference = require_identity_object(receipt, "destinationGroupProof", "receipt")
            group_path, group_digest = validate_group_proof(
                group_reference,
                mapping,
                report_dir,
                managed_root,
                recovery_transaction,
                plan,
                success_marker,
                github_account,
                account_binding_digest,
                reviewed_repository_identity,
            )
            bindings[source] = ReceiptBinding(
                mapping,
                path,
                receipt,
                representation_path,
                representation_digest,
                group_path,
                group_digest,
                github_account,
                account_binding_digest,
                dict(reviewed_repository_identity),
            )
        except CleanupError as error:
            errors.append(str(error))
    missing_sources = sorted(set(mappings) - set(bindings), key=os.fsencode)
    if missing_sources:
        errors.append(
            f"Final recovery transaction lacks {len(missing_sources)} exact mapping receipt(s): "
            + ", ".join(missing_sources[:20])
        )
    accepted_group_digests = success_marker.get("destinationGroupProofSHA256s")
    if (
        not isinstance(accepted_group_digests, list)
        or not accepted_group_digests
        or any(
            not isinstance(value, str) or SHA256_RE.fullmatch(value) is None
            for value in accepted_group_digests
        )
        or len(accepted_group_digests) != len(set(accepted_group_digests))
    ):
        errors.append("Final success marker has an invalid/duplicate destination group proof set.")
    else:
        bound_group_digests = {binding.group_proof_sha256 for binding in bindings.values()}
        if set(accepted_group_digests) != bound_group_digests:
            errors.append(
                "Final success marker destination group proof set is not exactly the receipt-bound set."
            )
    return bindings, errors


def receipt_bound_source_path(
    binding: ReceiptBinding,
    managed_root: Path,
) -> Path:
    """Resolve the exact live or recovery-retired source authorized by a final receipt."""
    mapping = binding.mapping
    receipt = binding.receipt
    status = receipt.get("recoveryRetirementStatus")
    retired_value = receipt.get("retiredPath")
    if status == "retained-for-stage3":
        if not os.path.lexists(mapping.source):
            raise CleanupError(f"Receipt-retained source is missing: {mapping.source}")
        ensure_exact_case_real_path(mapping.source, Path("/"), "receipt-retained mapped source")
        if mapping.source == ACTIVE_CHECKOUT:
            ensure_exact_case_real_path(ACTIVE_CHECKOUT, Path("/"), "protected active checkout")
        return mapping.source
    if status != "retired-to-managed-temp-verified" or not isinstance(retired_value, str):
        raise CleanupError(f"Receipt lacks a supported exact source location: {binding.receipt_path}")
    if os.path.lexists(mapping.source):
        raise CleanupError(
            f"Recovery receipt says source was retired but the original path still exists: {mapping.source}"
        )
    retired = absolute(retired_value)
    transaction = receipt.get("transaction")
    if not isinstance(transaction, str):
        raise CleanupError(f"Recovery-retired receipt lacks transaction: {binding.receipt_path}")
    validate_transaction_id(transaction, "recovery receipt transaction")
    retirement_root = (
        managed_root / "_temp" / "Repo-Consolidation" / transaction / "source-retirement"
    )
    if retired == retirement_root or not within(retired, retirement_root):
        raise CleanupError(f"Recovery retiredPath escapes exact transaction retirement root: {retired}")
    ensure_exact_case_entry_path(retired, retirement_root, "receipt-bound recovery-retired source")
    identity = os.lstat(retired)
    source_identity = require_identity_object(receipt, "sourceIdentity", "receipt")
    if (identity.st_dev, identity.st_ino) != (
        source_identity.get("device"),
        source_identity.get("inode"),
    ):
        raise CleanupError(f"Recovery-retired source identity changed: {retired}")
    expected_volume = receipt.get("managedVolumeIdentity")
    if not isinstance(expected_volume, dict):
        raise CleanupError(f"Recovery-retired receipt lacks managed volume identity: {binding.receipt_path}")
    current_volume = volume_identity(retired, require_external_fields=True)
    if not same_volume_identity(expected_volume, current_volume):
        raise CleanupError(f"Recovery-retired source volume identity changed: {retired}")
    return retired


def exact_safe_relative_list(value: object, label: str) -> list[str]:
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        raise CleanupError(f"{label} must be an array of relative paths.")
    normalized: list[str] = []
    for item in value:
        if item == ".":
            normalized.append(item)
        else:
            safe_relative_path(item, label)
            normalized.append(item)
    if normalized != sorted(normalized, key=os.fsencode) or len(normalized) != len(set(normalized)):
        raise CleanupError(f"{label} must be exact, unique, and bytewise sorted.")
    return normalized


def load_workspace_manifest_entries(
    manifest: dict[str, object],
    label: str,
) -> dict[str, dict[str, object]]:
    rows = manifest.get("entries")
    if not isinstance(rows, list) or not rows:
        raise CleanupError(f"{label} lacks a non-empty entries array.")
    expected_keys = {
        "relativePath",
        "sourceFingerprint",
        "sourceHardlinkGroup",
        "representationPath",
        "representationFingerprint",
        "coverageKind",
    }
    result: dict[str, dict[str, object]] = {}
    ordered: list[str] = []
    for raw in rows:
        if not isinstance(raw, dict) or set(raw) != expected_keys:
            raise CleanupError(f"{label} contains an entry with an invalid exact schema.")
        relative = raw.get("relativePath")
        if not isinstance(relative, str):
            raise CleanupError(f"{label} contains an entry without relativePath.")
        if relative != ".":
            safe_relative_path(relative, f"{label} entry")
        if relative in result:
            raise CleanupError(f"{label} contains duplicate relative path {relative!r}.")
        if not isinstance(raw.get("sourceFingerprint"), dict) or not isinstance(
            raw.get("representationFingerprint"), dict
        ):
            raise CleanupError(f"{label} entry fingerprints are invalid: {relative}")
        hardlink_group = raw.get("sourceHardlinkGroup")
        if not isinstance(hardlink_group, str) or (
            hardlink_group and SHA256_RE.fullmatch(hardlink_group) is None
        ):
            raise CleanupError(f"{label} entry hardlink group is invalid: {relative}")
        representation = raw.get("representationPath")
        if not isinstance(representation, str) or not os.path.isabs(representation):
            raise CleanupError(f"{label} entry representation path is not absolute: {relative}")
        if raw.get("coverageKind") not in WORKSPACE_COVERAGE_KINDS:
            raise CleanupError(f"{label} entry coverage kind is invalid: {relative}")
        result[relative] = raw
        ordered.append(relative)
    if ordered != sorted(ordered, key=os.fsencode) or "." not in result:
        raise CleanupError(f"{label} entries must include '.' and be bytewise sorted.")
    return result


def load_workspace_git_root_rows(
    manifest: dict[str, object],
    label: str,
) -> dict[str, dict[str, object]]:
    rows = manifest.get("gitRoots")
    if not isinstance(rows, list):
        raise CleanupError(f"{label} lacks gitRoots array.")
    result: dict[str, dict[str, object]] = {}
    ordered: list[str] = []
    row_keys = {
        "projectRelativePath",
        "gitState",
        "evidenceStatus",
        "componentsDigest",
        "components",
    }
    component_keys = {
        "role",
        "path",
        "device",
        "inode",
        "treeDigest",
        "entryCount",
        "ephemeralFsmonitorSockets",
        "representationPath",
        "representationTreeDigest",
    }
    for raw in rows:
        if not isinstance(raw, dict) or set(raw) != row_keys:
            raise CleanupError(f"{label} has a Git root with an invalid exact schema.")
        relative = raw.get("projectRelativePath")
        if not isinstance(relative, str):
            raise CleanupError(f"{label} has a Git root without projectRelativePath.")
        if relative != ".":
            safe_relative_path(relative, f"{label} Git root")
        if relative in result:
            raise CleanupError(f"{label} repeats Git root {relative!r}.")
        state = raw.get("gitState")
        evidence_status = raw.get("evidenceStatus")
        required_status = {
            "directory": "history-imported-complete",
            "linked": None,
            "broken": "broken-git-evidence-complete",
        }.get(state)
        if state not in {"directory", "linked", "broken"}:
            raise CleanupError(f"{label} Git root state is invalid: {relative}")
        if required_status is not None and evidence_status != required_status:
            raise CleanupError(f"{label} Git root evidence status is invalid: {relative}")
        if state == "linked" and evidence_status not in {
            "history-imported-complete",
            "pointer-only-evidence-complete",
        }:
            raise CleanupError(f"{label} linked Git root lacks explicit accepted evidence: {relative}")
        components = raw.get("components")
        if not isinstance(components, list) or not components:
            raise CleanupError(f"{label} Git root lacks component coverage: {relative}")
        source_components: list[dict[str, object]] = []
        component_identities: set[tuple[str, str]] = set()
        for component in components:
            if not isinstance(component, dict) or set(component) != component_keys:
                raise CleanupError(f"{label} Git component has an invalid exact schema: {relative}")
            role = component.get("role")
            path = component.get("path")
            if not isinstance(role, str) or not role or not isinstance(path, str) or not os.path.isabs(path):
                raise CleanupError(f"{label} Git component role/path is invalid: {relative}")
            identity = (role, path)
            if identity in component_identities:
                raise CleanupError(f"{label} repeats Git component {identity!r}.")
            component_identities.add(identity)
            if not isinstance(component.get("device"), int) or not isinstance(component.get("inode"), int):
                raise CleanupError(f"{label} Git component identity is invalid: {identity!r}")
            require_sha256(component.get("treeDigest"), f"{label} Git component treeDigest")
            require_sha256(
                component.get("representationTreeDigest"),
                f"{label} Git component representationTreeDigest",
            )
            if not isinstance(component.get("entryCount"), int) or component["entryCount"] < 1:
                raise CleanupError(f"{label} Git component entryCount is invalid: {identity!r}")
            exact_safe_relative_list(
                component.get("ephemeralFsmonitorSockets"),
                f"{label} Git component fsmonitor sockets",
            )
            representation_path = component.get("representationPath")
            if not isinstance(representation_path, str) or not os.path.isabs(representation_path):
                raise CleanupError(f"{label} Git component representation is invalid: {identity!r}")
            source_components.append(
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
            )
        if component_set_digest(source_components) != require_sha256(
            raw.get("componentsDigest"), f"{label} Git componentsDigest"
        ):
            raise CleanupError(f"{label} Git component-set digest differs: {relative}")
        result[relative] = raw
        ordered.append(relative)
    if ordered != sorted(ordered, key=os.fsencode):
        raise CleanupError(f"{label} Git roots must be bytewise sorted.")
    return result


def load_workspace_root_bindings(
    plan: CleanupPlan,
    report_dir: Path,
    managed_root: Path,
    recovery_transaction: str,
    success_marker: dict[str, object],
) -> tuple[dict[str, WorkspaceRootBinding], list[str]]:
    required_roots = workspace_proof_required_roots(plan)
    roots_by_path = {display(item.path): item for item in required_roots}
    references = success_marker.get("workspaceRootProofs")
    if not isinstance(references, list):
        return {}, ["Final success marker lacks workspaceRootProofs array."]
    bindings: dict[str, WorkspaceRootBinding] = {}
    errors: list[str] = []
    for reference in references:
        try:
            if not isinstance(reference, dict):
                raise CleanupError("Workspace-root proof reference is not an object.")
            cleanup_root = reference.get("cleanupRoot")
            if not isinstance(cleanup_root, str) or cleanup_root not in roots_by_path:
                raise CleanupError(f"Workspace-root proof has an unexpected cleanup root: {cleanup_root!r}")
            item = roots_by_path[cleanup_root]
            if not item.requires_process_drain:
                raise CleanupError(
                    f"Whole-workspace proof root must require exact runner drain: {item.path}"
                )
            canonical_root = root_link_target(item)
            if canonical_root is None:
                raise CleanupError(
                    f"Whole-workspace proof root requires one exact root replacement link: {item.path}"
                )
            ensure_exact_case_real_path(canonical_root, managed_root, "canonical whole-workspace root")
            proof_path = resolve_proof_path(
                reference.get("path"), report_dir, managed_root, "workspace-root proof"
            )
            if not within(proof_path, report_dir):
                raise CleanupError(f"Workspace-root proof is outside the recovery report: {proof_path}")
            proof_sha = require_sha256(reference.get("sha256"), "workspace-root proof sha256")
            if sha256_file(proof_path) != proof_sha:
                raise CleanupError(f"Workspace-root proof digest changed: {proof_path}")
            proof = load_json(proof_path, "workspace-root proof")
            proof_keys = {
                "format",
                "proofKind",
                "status",
                "transaction",
                "sourceMapSHA256",
                "githubAccountsSHA256",
                "repositoryIdentitiesSHA256",
                "cleanupRoot",
                "canonicalRoot",
                "sourceIdentity",
                "manifest",
                "projectLaneExclusions",
                "destinationVariantRelativePaths",
                "evidenceOnlyRelativePaths",
                "destinationVariantPolicy",
                "runnerDrainBinding",
                "managedVolumeIdentity",
            }
            if set(proof) != proof_keys:
                raise CleanupError(f"Workspace-root proof has an invalid exact schema: {proof_path}")
            if (
                proof.get("format") != 1
                or proof.get("proofKind") != WORKSPACE_ROOT_PROOF_KIND
                or proof.get("status") != WORKSPACE_ROOT_PROOF_STATUS
                or proof.get("transaction") != recovery_transaction
                or proof.get("sourceMapSHA256") != plan.source_map_sha256
                or proof.get("githubAccountsSHA256") != plan.github_accounts_sha256
                or proof.get("repositoryIdentitiesSHA256") != plan.repository_identities_sha256
                or proof.get("cleanupRoot") != cleanup_root
                or proof.get("canonicalRoot") != display(canonical_root)
                or proof.get("destinationVariantPolicy") != WORKSPACE_DESTINATION_VARIANT_POLICY
            ):
                raise CleanupError(f"Workspace-root proof identity/status binding is invalid: {proof_path}")
            expected_volume = proof.get("managedVolumeIdentity")
            if not isinstance(expected_volume, dict):
                raise CleanupError(f"Workspace-root proof lacks managed volume identity: {proof_path}")
            current_volume = volume_identity(managed_root / "_temp", require_external_fields=True)
            if not same_volume_identity(expected_volume, current_volume):
                raise CleanupError(
                    f"Workspace-root proof canonical volume identity changed: {proof_path}"
                )
            source_identity = require_identity_object(proof, "sourceIdentity", "workspace-root proof")
            if set(source_identity) != {
                "path",
                "device",
                "inode",
                "treeAlgorithm",
                "treeDigest",
                "entryCount",
                "ephemeralFsmonitorSockets",
                "gitRootCount",
            }:
                raise CleanupError(f"Workspace-root proof sourceIdentity schema is invalid: {proof_path}")
            if (
                source_identity.get("path") != cleanup_root
                or not isinstance(source_identity.get("device"), int)
                or not isinstance(source_identity.get("inode"), int)
                or source_identity.get("treeAlgorithm") != TREE_ALGORITHM
                or not isinstance(source_identity.get("entryCount"), int)
                or source_identity["entryCount"] < 1
                or not isinstance(source_identity.get("gitRootCount"), int)
                or source_identity["gitRootCount"] < 0
            ):
                raise CleanupError(f"Workspace-root proof source identity is invalid: {proof_path}")
            source_tree_digest = require_sha256(
                source_identity.get("treeDigest"), "workspace-root source treeDigest"
            )
            source_sockets = exact_safe_relative_list(
                source_identity.get("ephemeralFsmonitorSockets"),
                "workspace-root source fsmonitor sockets",
            )
            runner_binding = proof.get("runnerDrainBinding")
            expected_runner_binding = {
                "proofKind": RUNNER_DRAIN_PROOF_KIND,
                "drainTransaction": success_marker.get("runnerDrainTransaction"),
                "receiptSHA256": success_marker.get("runnerDrainReceiptSHA256"),
                "cleanupRoot": cleanup_root,
                "sourceRuntimeRoot": display(item.path / "Runtime"),
                "canonicalRuntimeRoot": display(canonical_root / "Runtime"),
            }
            if runner_binding != expected_runner_binding:
                raise CleanupError(f"Workspace-root proof runner drain binding is invalid: {proof_path}")
            manifest_reference = proof.get("manifest")
            if not isinstance(manifest_reference, dict) or set(manifest_reference) != {
                "format",
                "path",
                "sha256",
                "entryCount",
                "treeDigest",
                "gitRootCount",
            }:
                raise CleanupError(f"Workspace-root manifest reference schema is invalid: {proof_path}")
            manifest_sha = require_sha256(
                manifest_reference.get("sha256"), "workspace-root manifest sha256"
            )
            if manifest_sha != reference.get("manifestSHA256"):
                raise CleanupError(f"Workspace-root manifest digest is not bound by success marker: {proof_path}")
            manifest_path = resolve_proof_path(
                manifest_reference.get("path"), report_dir, managed_root, "workspace-root manifest"
            )
            if not within(manifest_path, report_dir):
                raise CleanupError(f"Workspace-root manifest is outside the recovery report: {manifest_path}")
            if sha256_file(manifest_path) != manifest_sha:
                raise CleanupError(f"Workspace-root manifest digest changed: {manifest_path}")
            manifest = load_json(manifest_path, "workspace-root manifest")
            manifest_keys = {
                "format",
                "manifestKind",
                "transaction",
                "sourceMapSHA256",
                "githubAccountsSHA256",
                "repositoryIdentitiesSHA256",
                "cleanupRoot",
                "canonicalRoot",
                "treeAlgorithm",
                "sourceTreeDigest",
                "entryCount",
                "ephemeralFsmonitorSockets",
                "entries",
                "gitRoots",
            }
            if set(manifest) != manifest_keys:
                raise CleanupError(f"Workspace-root manifest has an invalid exact schema: {manifest_path}")
            if (
                manifest.get("format") != 1
                or manifest.get("manifestKind") != WORKSPACE_ROOT_MANIFEST_KIND
                or manifest.get("transaction") != recovery_transaction
                or manifest.get("sourceMapSHA256") != plan.source_map_sha256
                or manifest.get("githubAccountsSHA256") != plan.github_accounts_sha256
                or manifest.get("repositoryIdentitiesSHA256") != plan.repository_identities_sha256
                or manifest.get("cleanupRoot") != cleanup_root
                or manifest.get("canonicalRoot") != display(canonical_root)
                or manifest.get("treeAlgorithm") != TREE_ALGORITHM
                or manifest.get("sourceTreeDigest") != source_tree_digest
                or manifest.get("entryCount") != source_identity.get("entryCount")
                or manifest.get("ephemeralFsmonitorSockets") != source_sockets
            ):
                raise CleanupError(f"Workspace-root manifest identity binding is invalid: {manifest_path}")
            entries = load_workspace_manifest_entries(manifest, "workspace-root manifest")
            git_roots = load_workspace_git_root_rows(manifest, "workspace-root manifest")
            if (
                len(entries) != source_identity.get("entryCount")
                or len(git_roots) != source_identity.get("gitRootCount")
                or manifest_reference.get("format") != 1
                or manifest_reference.get("entryCount") != len(entries)
                or manifest_reference.get("treeDigest") != source_tree_digest
                or manifest_reference.get("gitRootCount") != len(git_roots)
            ):
                raise CleanupError(f"Workspace-root manifest counts/digest differ from proof: {manifest_path}")
            exact_safe_relative_list(
                proof.get("projectLaneExclusions"), "workspace-root project lane exclusions"
            )
            exact_safe_relative_list(
                proof.get("destinationVariantRelativePaths"),
                "workspace-root destination variants",
            )
            exact_safe_relative_list(
                proof.get("evidenceOnlyRelativePaths"), "workspace-root evidence-only paths"
            )
            bindings[cleanup_root] = WorkspaceRootBinding(
                item,
                canonical_root,
                proof_path,
                proof_sha,
                proof,
                manifest_path,
                manifest_sha,
                manifest,
                entries,
            )
        except (CleanupError, OSError) as error:
            errors.append(str(error))
    missing = sorted(set(roots_by_path) - set(bindings), key=os.fsencode)
    if missing:
        errors.append(
            f"Final recovery transaction lacks {len(missing)} exact workspace-root proof(s): "
            + ", ".join(missing)
        )
    if set(bindings) - set(roots_by_path):
        errors.append("Final recovery transaction has an extra workspace-root proof.")
    return bindings, sorted(set(errors))


def github_account_binding_sha256(owner: str, account: str) -> str:
    return sha256_bytes(stable_json({"owner": owner, "account": account}))


def repository_identity_binding_sha256(
    repository: str,
    reviewed_identity: TypingMapping[str, str],
) -> str:
    return sha256_bytes(
        stable_json({"repository": repository, "reviewedIdentity": dict(reviewed_identity)})
    )


def github_token_for_account(account: str) -> str:
    environment = os.environ.copy()
    for name in ("GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN"):
        environment.pop(name, None)
    result = subprocess.run(
        ["gh", "auth", "token", "--hostname", "github.com", "--user", account],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=30,
        check=False,
        env=environment,
    )
    if result.returncode != 0:
        # stderr is intentionally not surfaced because auth helpers must never
        # create a path for a token or credential fragment to enter logs.
        raise CleanupError(f"Could not obtain an in-memory GitHub token for reviewed account {account}.")
    try:
        token = result.stdout.decode("utf-8").strip()
    except UnicodeError as error:
        raise CleanupError(f"GitHub token for reviewed account {account} was not valid UTF-8.") from error
    if not token or any(character.isspace() for character in token):
        raise CleanupError(f"GitHub returned an invalid token shape for reviewed account {account}.")
    return token


def github_api(arguments: Sequence[str], token: str, *, account: str) -> dict[str, object]:
    environment = os.environ.copy()
    for name in ("GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN"):
        environment.pop(name, None)
    environment["GH_TOKEN"] = token
    result = subprocess.run(
        ["gh", *arguments],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=60,
        check=False,
        env=environment,
    )
    if result.returncode != 0:
        raise CleanupError(f"GitHub API verification failed under reviewed account {account}.")
    try:
        payload = json.loads(result.stdout.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError) as error:
        raise CleanupError(f"GitHub API returned invalid JSON under reviewed account {account}.") from error
    if not isinstance(payload, dict):
        raise CleanupError(f"GitHub API returned a non-object under reviewed account {account}.")
    return payload


def gh_repository_identity(repository: str, account: str) -> dict[str, str]:
    token = github_token_for_account(account)
    user = github_api(["api", "user"], token, account=account)
    authenticated_login = user.get("login")
    if authenticated_login != account:
        raise CleanupError(
            f"Reviewed GitHub account binding mismatch: expected {account}, authenticated as {authenticated_login!r}."
        )
    payload = github_api(["api", f"repos/{repository}"], token, account=account)
    if payload.get("full_name") != repository:
        raise CleanupError(
            f"GitHub returned a different exact-case repository identity: "
            f"expected {repository}, received {payload.get('full_name')!r}."
        )
    if payload.get("archived") is True:
        raise CleanupError(f"GitHub repository is archived: {repository}")
    node_id = payload.get("node_id")
    database_id = payload.get("id")
    if not isinstance(node_id, str) or not node_id or not isinstance(database_id, int):
        raise CleanupError(f"GitHub repository lacks authoritative node/database IDs: {repository}")
    return {
        "repository": repository,
        "authenticatedLogin": account,
        "nodeID": node_id,
        "databaseID": str(database_id),
    }


def github_remote_repository(destination: Path) -> str:
    result = run_command(["git", "-C", destination, "remote", "get-url", "origin"], timeout=30)
    if result.returncode != 0:
        raise CleanupError(f"Canonical repository has no readable origin: {destination}")
    value = result.stdout.decode("utf-8", "replace").strip()
    match = re.fullmatch(
        r"(?:https?://github\.com/|ssh://git@github\.com/|git@github\.com:)"
        r"([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+(?:\.git)?)",
        value,
    )
    if not match:
        raise CleanupError(f"Canonical origin is not a GitHub repository: {destination}: {value}")
    name = match.group(2)
    if name.endswith(".git"):
        name = name[:-4]
    return f"{match.group(1)}/{name}"


def strict_fsck(destination: Path) -> str:
    result = run_command(
        ["git", "-C", destination, "fsck", "--full", "--strict", "--unreachable", "--no-reflogs"],
        timeout=1800,
    )
    output = result.stdout + result.stderr
    if result.returncode != 0:
        raise CleanupError(
            f"Fresh canonical strict fsck failed for {destination}: "
            + output.decode("utf-8", "replace")[:2000]
        )
    return sha256_bytes(output)


def representation_entries(proof: dict[str, object], label: str) -> dict[str, dict[str, object]]:
    rows = proof.get("entries")
    if not isinstance(rows, list):
        raise CleanupError(f"{label} lacks entries array.")
    values: dict[str, dict[str, object]] = {}
    for raw in rows:
        if not isinstance(raw, dict) or not isinstance(raw.get("relativePath"), str):
            raise CleanupError(f"{label} contains an invalid entry.")
        relative = raw["relativePath"]
        if relative in values:
            raise CleanupError(f"{label} contains duplicate path {relative!r}.")
        if relative != ".":
            safe_relative_path(relative, f"{label} entry")
        values[relative] = raw
    return values


def verify_receipt_git_components(
    source: Path,
    logical_source: Path,
    expected_components: Sequence[object],
    *,
    allow_stopped_fsmonitor: bool,
    container_source: Path | None = None,
    logical_container: Path | None = None,
) -> list[dict[str, object]]:
    current: list[dict[str, object]] = []
    for raw in expected_components:
        if not isinstance(raw, dict):
            raise CleanupError(f"Receipt has a non-object Git component: {logical_source}")
        role = raw.get("role")
        path_value = raw.get("path")
        if not isinstance(role, str) or not role or not isinstance(path_value, str):
            raise CleanupError(f"Receipt Git component lacks role/path: {logical_source}")
        logical_component = absolute(path_value)
        candidate = logical_component
        if (
            container_source is not None
            and logical_container is not None
            and (logical_component == logical_container or within(logical_component, logical_container))
        ):
            candidate = container_source / logical_component.relative_to(logical_container)
        elif logical_component == logical_source or within(logical_component, logical_source):
            candidate = source / logical_component.relative_to(logical_source)
        if not os.path.lexists(candidate):
            raise CleanupError(f"Receipt-bound Git component is missing: {role}: {candidate}")
        metadata = os.lstat(candidate)
        if (metadata.st_dev, metadata.st_ino) != (raw.get("device"), raw.get("inode")):
            raise CleanupError(f"Receipt-bound Git component device/inode changed: {role}: {candidate}")
        records, digest, ephemeral = scan_tree(candidate, exclude_top_git=False)
        component = {
            "role": role,
            "path": display(logical_component),
            "device": metadata.st_dev,
            "inode": metadata.st_ino,
            "treeDigest": digest,
            "entryCount": len(records),
            "ephemeralFsmonitorSockets": ephemeral,
        }
        comparable_component = dict(component)
        comparable_raw = dict(raw)
        if allow_stopped_fsmonitor:
            expected_sockets = comparable_raw.pop("ephemeralFsmonitorSockets", [])
            comparable_component.pop("ephemeralFsmonitorSockets", [])
            if not isinstance(expected_sockets, list):
                raise CleanupError(f"Receipt fsmonitor socket classification is invalid: {role}: {candidate}")
        if comparable_component != comparable_raw:
            raise CleanupError(f"Receipt-bound Git component digest/metadata changed: {role}: {candidate}")
        current.append(component)
    return current


def verify_representation_binding(
    binding: ReceiptBinding,
    managed_root: Path,
    report_dir: Path,
    *,
    source_override: Path | None = None,
    fsmonitor_stopped: bool = False,
) -> None:
    mapping = binding.mapping
    source = source_override or mapping.source
    original_source = display(mapping.source)
    identity_stat = os.lstat(source)
    source_identity = require_identity_object(binding.receipt, "sourceIdentity", "receipt")
    if (identity_stat.st_dev, identity_stat.st_ino) != (
        source_identity["device"],
        source_identity["inode"],
    ):
        raise CleanupError(f"Live source device/inode differs from receipt: {original_source}")

    proof = load_json(binding.representation_path, "representation proof")
    if (
        proof.get("format") != REPRESENTATION_FORMAT
        or proof.get("status") not in REPRESENTATION_STATUSES
        or proof.get("transaction") != binding.receipt.get("transaction")
        or proof.get("sourceMapSHA256") != binding.receipt.get("sourceMapSHA256")
        or proof.get("mappingSHA256") != mapping.digest
        or proof.get("source") != original_source
        or proof.get("destination") != display(mapping.destination)
    ):
        raise CleanupError(f"Representation proof identity/status mismatch: {binding.representation_path}")

    current_records, tree_digest, ephemeral = scan_tree(
        source,
        exclude_top_git=True,
        excluded_relative_paths=mapping_exclusions(mapping),
    )
    if tree_digest != source_identity.get("treeDigest") or tree_digest != proof.get("sourceTreeDigest"):
        raise CleanupError(f"Fresh source tree digest differs from receipt/proof: {original_source}")
    expected_ephemeral = proof.get("ephemeralFsmonitorSockets", [])
    if not isinstance(expected_ephemeral, list) or sorted(expected_ephemeral) != ephemeral:
        raise CleanupError(f"Fsmonitor socket classification changed: {original_source}")
    proof_entries = representation_entries(proof, "representation proof")
    current = {str(row["relativePath"]): row for row in current_records}
    if set(current) != set(proof_entries):
        missing = sorted(set(current) - set(proof_entries))[:10]
        extra = sorted(set(proof_entries) - set(current))[:10]
        raise CleanupError(
            f"Representation coverage is incomplete for {original_source}; missing={missing}, extra={extra}"
        )
    source_semantic_to_rep_inode: dict[str, tuple[int, int]] = {}
    rep_inode_to_source_semantic: dict[tuple[int, int], str] = {}
    for relative, source_row in current.items():
        proof_row = proof_entries[relative]
        if proof_row.get("sourceFingerprint") != source_row["fingerprint"]:
            raise CleanupError(f"Representation source fingerprint changed: {original_source}:{relative}")
        representation_value = proof_row.get("representationPath")
        if not isinstance(representation_value, str) or not representation_value:
            raise CleanupError(f"Representation path is absent: {original_source}:{relative}")
        representation_path = absolute(representation_value)
        if not (
            within(representation_path, mapping.destination)
            or within(representation_path, managed_root)
            or within(representation_path, report_dir)
        ):
            raise CleanupError(f"Representation escapes canonical/evidence roots: {representation_path}")
        if not os.path.lexists(representation_path):
            raise CleanupError(f"Representation path is missing: {representation_path}")
        if within(representation_path, mapping.destination):
            representation_base = mapping.destination
        elif within(representation_path, report_dir):
            representation_base = report_dir
        else:
            representation_base = managed_root
        ensure_no_symlink_parent_components(
            representation_path,
            representation_base,
            "source representation",
        )
        if os.lstat(representation_path).st_dev != os.stat(managed_root).st_dev:
            raise CleanupError(f"Source representation crosses a nested filesystem: {representation_path}")
        actual = stable_fingerprint(representation_path)
        if actual != proof_row.get("representationFingerprint"):
            raise CleanupError(f"Live representation fingerprint changed: {representation_path}")
        if actual != source_row["fingerprint"]:
            raise CleanupError(
                f"Source data/metadata is not exactly represented at canonical/evidence path: "
                f"{original_source}:{relative} -> {representation_path}"
            )
        if proof_row.get("sourceHardlinkGroup", "") != source_row.get("hardlinkGroup", ""):
            raise CleanupError(f"Hardlink topology proof changed: {original_source}:{relative}")
        if source_row["fingerprint"].get("type") == "file":
            source_semantic = str(source_row.get("hardlinkGroup") or f"unique:{relative}")
            representation_stat = os.lstat(representation_path)
            representation_inode = (representation_stat.st_dev, representation_stat.st_ino)
            prior_inode = source_semantic_to_rep_inode.setdefault(source_semantic, representation_inode)
            if prior_inode != representation_inode:
                raise CleanupError(f"A source hardlink group was split in its representation: {original_source}")
            prior_semantic = rep_inode_to_source_semantic.setdefault(representation_inode, source_semantic)
            if prior_semantic != source_semantic:
                raise CleanupError(f"Independent source files were collapsed into one hardlink: {original_source}")

    expected_components = source_identity.get("gitComponents")
    assert isinstance(expected_components, list)
    components = verify_receipt_git_components(
        source,
        mapping.source,
        expected_components,
        allow_stopped_fsmonitor=fsmonitor_stopped,
    )
    components_digest = component_set_digest(components)
    if components_digest != source_identity.get("gitComponentsDigest"):
        raise CleanupError(f"Fresh Git component digest differs from receipt: {original_source}")
    evidence_status = proof.get("gitEvidenceStatus")
    if evidence_status not in GIT_EVIDENCE_STATUSES:
        raise CleanupError(f"Git evidence status is not explicitly accepted: {original_source}")
    git_state = source_identity.get("gitState")
    if source_override is None:
        discovered_components, discovered_state = git_component_paths(
            source,
            logical_source=mapping.source,
        )
        if discovered_components != components or discovered_state != git_state:
            raise CleanupError(f"Receipt omitted or changed a live Git component: {original_source}")
    if git_state == "absent" and evidence_status != "no-git-entry":
        raise CleanupError(f"A source without .git requires no-git-entry evidence status: {original_source}")
    if git_state == "broken" and evidence_status != "broken-git-evidence-complete":
        raise CleanupError(
            f"Broken Git source needs broken-git-evidence-complete status: {original_source}"
        )
    if git_state == "linked" and evidence_status not in {
        "history-imported-complete",
        "pointer-only-evidence-complete",
    }:
        raise CleanupError(
            f"Linked worktree needs imported-history or explicit pointer-only evidence: {original_source}"
        )
    if git_state == "directory" and evidence_status != "history-imported-complete":
        raise CleanupError(f"Ordinary Git source requires imported-history evidence: {original_source}")
    proof_components = proof.get("gitComponents")
    if not isinstance(proof_components, list) or len(proof_components) != len(components):
        raise CleanupError(f"Git representation component coverage is incomplete: {original_source}")
    component_index = {
        (value.get("role"), value.get("path")): value
        for value in proof_components
        if isinstance(value, dict)
    }
    for component in components:
        key = (component["role"], component["path"])
        proof_component = component_index.get(key)
        if proof_component is None or proof_component.get("treeDigest") != component["treeDigest"]:
            raise CleanupError(f"Git component is not bound in representation proof: {key}")
        representation_value = proof_component.get("representationPath")
        if not isinstance(representation_value, str):
            raise CleanupError(f"Git component has no evidence representation: {key}")
        representation_path = absolute(representation_value)
        if not within(representation_path, managed_root) and not within(representation_path, report_dir):
            raise CleanupError(f"Git component evidence escapes managed/report roots: {representation_path}")
        representation_base = report_dir if within(representation_path, report_dir) else managed_root
        ensure_no_symlink_parent_components(
            representation_path,
            representation_base,
            "Git component evidence",
        )
        if os.lstat(representation_path).st_dev != os.stat(managed_root).st_dev:
            raise CleanupError(f"Git component evidence crosses a nested filesystem: {representation_path}")
        _records, representation_digest, sockets = scan_tree(representation_path, exclude_top_git=False)
        if sockets:
            raise CleanupError(f"Git evidence contains an ephemeral socket: {representation_path}")
        if representation_digest != component["treeDigest"] or representation_digest != proof_component.get(
            "representationTreeDigest"
        ):
            raise CleanupError(f"Git component evidence digest differs: {key}")


def declared_git_state(dot_git: Path) -> str:
    try:
        mode = os.lstat(dot_git).st_mode
    except OSError as error:
        raise CleanupError(f"Workspace Git entry disappeared: {dot_git}: {error}") from error
    if stat.S_ISDIR(mode) and not stat.S_ISLNK(mode):
        return "directory"
    if stat.S_ISREG(mode) and not stat.S_ISLNK(mode):
        try:
            content = dot_git.read_text(encoding="utf-8").strip()
        except (OSError, UnicodeError):
            return "broken"
        return "linked" if re.fullmatch(r"gitdir:\s*(.+)", content) else "broken"
    return "broken"


def workspace_git_relative_paths(records: Sequence[dict[str, object]]) -> set[str]:
    roots: set[str] = set()
    for row in records:
        relative = row.get("relativePath")
        if not isinstance(relative, str) or relative == ".":
            continue
        parts = PurePosixPath(relative).parts
        if not parts or parts[-1] != ".git" or ".git" in parts[:-1]:
            continue
        parent = PurePosixPath(*parts[:-1])
        roots.add("." if not parent.parts else parent.as_posix())
    return roots


def relative_within(relative: str, parent: str) -> bool:
    if parent == ".":
        return True
    return relative == parent or relative.startswith(parent + "/")


def verify_workspace_root_binding(
    binding: WorkspaceRootBinding,
    managed_root: Path,
    report_dir: Path,
    *,
    source_override: Path | None = None,
    fsmonitor_stopped: bool = False,
    cleanup_roots: Sequence[CleanupRoot] = (),
) -> None:
    """Freshly prove every workspace entry and Git component is represented."""
    item = binding.root
    source = source_override or item.path
    logical_source = item.path
    if sha256_file(binding.proof_path) != binding.proof_sha256:
        raise CleanupError(f"Workspace-root proof changed: {binding.proof_path}")
    if sha256_file(binding.manifest_path) != binding.manifest_sha256:
        raise CleanupError(f"Workspace-root manifest changed: {binding.manifest_path}")
    proof = load_json(binding.proof_path, "workspace-root proof")
    manifest = load_json(binding.manifest_path, "workspace-root manifest")
    if proof != binding.proof or manifest != binding.manifest:
        raise CleanupError(f"Workspace-root proof/manifest content changed: {logical_source}")
    expected_volume = proof.get("managedVolumeIdentity")
    if not isinstance(expected_volume, dict):
        raise CleanupError(f"Workspace-root proof lost managed volume identity: {logical_source}")
    current_volume = volume_identity(managed_root / "_temp", require_external_fields=True)
    if not same_volume_identity(expected_volume, current_volume):
        raise CleanupError(f"Workspace-root canonical volume identity changed: {logical_source}")
    ensure_exact_case_real_path(binding.canonical_root, managed_root, "canonical whole-workspace root")
    try:
        source_mode = os.lstat(source).st_mode
    except OSError as error:
        raise CleanupError(f"Workspace source is unavailable: {source}: {error}") from error
    if stat.S_ISLNK(source_mode) or not stat.S_ISDIR(source_mode):
        raise CleanupError(f"Workspace source is not a real directory: {source}")
    source_identity = require_identity_object(proof, "sourceIdentity", "workspace-root proof")
    source_stat = os.lstat(source)
    if (source_stat.st_dev, source_stat.st_ino) != (
        source_identity.get("device"),
        source_identity.get("inode"),
    ):
        raise CleanupError(f"Workspace source device/inode changed: {logical_source}")

    records, tree_digest, ephemeral = scan_tree(source, exclude_top_git=False)
    if (
        tree_digest != source_identity.get("treeDigest")
        or tree_digest != manifest.get("sourceTreeDigest")
        or len(records) != source_identity.get("entryCount")
        or len(records) != manifest.get("entryCount")
    ):
        raise CleanupError(f"Workspace source tree/entry count drifted: {logical_source}")
    expected_ephemeral = source_identity.get("ephemeralFsmonitorSockets")
    if not isinstance(expected_ephemeral, list):
        raise CleanupError(f"Workspace fsmonitor socket proof is invalid: {logical_source}")
    if fsmonitor_stopped:
        if not set(ephemeral).issubset(set(expected_ephemeral)):
            raise CleanupError(f"New workspace fsmonitor socket appeared after stop: {logical_source}")
    elif ephemeral != expected_ephemeral:
        raise CleanupError(f"Workspace fsmonitor socket classification changed: {logical_source}")

    entries = load_workspace_manifest_entries(manifest, "workspace-root manifest")
    current = {str(row["relativePath"]): row for row in records}
    if set(current) != set(entries):
        missing = sorted(set(current) - set(entries), key=os.fsencode)[:20]
        extra = sorted(set(entries) - set(current), key=os.fsencode)[:20]
        raise CleanupError(
            f"Workspace manifest is not complete for {logical_source}; missing={missing}, extra={extra}"
        )
    exclusions = exact_safe_relative_list(
        proof.get("projectLaneExclusions"), "workspace-root project lane exclusions"
    )
    if "." in exclusions:
        raise CleanupError(f"Workspace project-lane exclusions may not exclude the whole root: {logical_source}")
    variants = set(
        exact_safe_relative_list(
            proof.get("destinationVariantRelativePaths"),
            "workspace-root destination variants",
        )
    )
    evidence_only = set(
        exact_safe_relative_list(
            proof.get("evidenceOnlyRelativePaths"), "workspace-root evidence-only paths"
        )
    )
    for relative in (*exclusions, *variants, *evidence_only):
        if relative not in entries:
            raise CleanupError(f"Workspace proof classification path is absent from manifest: {relative}")
    actual_variants = {
        relative
        for relative, row in entries.items()
        if row.get("coverageKind") == "canonical-preserved-variant"
    }
    actual_evidence = {
        relative
        for relative, row in entries.items()
        if row.get("coverageKind") == "managed-evidence-only"
    }
    if actual_variants != variants or actual_evidence != evidence_only:
        raise CleanupError(f"Workspace variant/evidence classifications are not exact: {logical_source}")
    for exclusion in exclusions:
        if entries[exclusion].get("coverageKind") != "separate-project-proof":
            raise CleanupError(f"Excluded project lane lacks a separate root proof row: {exclusion}")

    source_semantic_to_rep_inode: dict[str, tuple[int, int]] = {}
    rep_inode_to_source_semantic: dict[tuple[int, int], str] = {}
    representation_path_semantics: dict[str, str] = {}
    quarantine_base = user_home_boundary() / ".csa-iem-quarantine"
    managed_temp = managed_root / "_temp"
    for relative, source_row in current.items():
        proof_row = entries[relative]
        if proof_row.get("sourceFingerprint") != source_row.get("fingerprint"):
            raise CleanupError(f"Workspace source fingerprint changed: {logical_source}:{relative}")
        if proof_row.get("sourceHardlinkGroup") != source_row.get("hardlinkGroup", ""):
            raise CleanupError(f"Workspace hardlink proof changed: {logical_source}:{relative}")
        coverage_kind = str(proof_row.get("coverageKind"))
        under_project_exclusion = any(relative_within(relative, value) for value in exclusions)
        if coverage_kind == "separate-project-proof" and not under_project_exclusion:
            raise CleanupError(f"Workspace separate-project row is outside a declared exclusion: {relative}")
        if under_project_exclusion and coverage_kind not in {
            "separate-project-proof",
            "managed-evidence-only",
        }:
            raise CleanupError(f"Excluded project-lane entry lacks project/evidence proof: {relative}")
        if coverage_kind == "canonical-nonrepository" and under_project_exclusion:
            raise CleanupError(f"Excluded project data was mislabeled nonrepository: {relative}")
        representation_path = absolute(str(proof_row.get("representationPath")))
        if any(
            representation_path == root.path or within(representation_path, root.path)
            for root in cleanup_roots
        ):
            raise CleanupError(f"Workspace representation points into a cleanup source: {representation_path}")
        if within(representation_path, quarantine_base):
            raise CleanupError(f"Workspace representation points into local quarantine: {representation_path}")
        in_canonical = within(representation_path, binding.canonical_root)
        in_report = within(representation_path, report_dir)
        in_temp = within(representation_path, managed_temp)
        if coverage_kind in {"canonical-nonrepository", "canonical-preserved-variant"}:
            if not in_canonical:
                raise CleanupError(f"Canonical workspace representation is outside canonical root: {representation_path}")
            representation_base = binding.canonical_root
        elif coverage_kind == "managed-evidence-only":
            if not (in_report or in_temp):
                raise CleanupError(f"Workspace evidence-only representation is not durable evidence: {representation_path}")
            representation_base = report_dir if in_report else managed_temp
        else:
            if not (in_canonical or in_report or in_temp):
                raise CleanupError(f"Workspace project representation escapes managed evidence: {representation_path}")
            representation_base = (
                binding.canonical_root if in_canonical else report_dir if in_report else managed_temp
            )
        if not os.path.lexists(representation_path):
            raise CleanupError(f"Workspace representation is missing: {representation_path}")
        ensure_exact_case_entry_path(
            representation_path,
            representation_base,
            "workspace source representation",
        )
        if os.lstat(representation_path).st_dev != os.stat(managed_root).st_dev:
            raise CleanupError(f"Workspace representation crosses the managed volume: {representation_path}")
        actual = stable_fingerprint(representation_path)
        if (
            actual != proof_row.get("representationFingerprint")
            or actual != source_row.get("fingerprint")
        ):
            raise CleanupError(
                f"Workspace content/metadata is not exactly represented: "
                f"{logical_source}:{relative} -> {representation_path}"
            )
        if source_row["fingerprint"].get("type") == "file":
            semantic = str(source_row.get("hardlinkGroup") or f"unique:{relative}")
            representation_stat = os.lstat(representation_path)
            representation_inode = (representation_stat.st_dev, representation_stat.st_ino)
            prior_inode = source_semantic_to_rep_inode.setdefault(semantic, representation_inode)
            if prior_inode != representation_inode:
                raise CleanupError(f"Workspace source hardlink group was split: {logical_source}")
            prior_semantic = rep_inode_to_source_semantic.setdefault(representation_inode, semantic)
            if prior_semantic != semantic:
                raise CleanupError(f"Independent workspace files were collapsed into one hardlink: {logical_source}")
            path_key = display(representation_path)
            prior_path_semantic = representation_path_semantics.setdefault(path_key, semantic)
            if prior_path_semantic != semantic:
                raise CleanupError(f"Independent workspace entries reuse one representation path: {path_key}")

    git_rows = load_workspace_git_root_rows(manifest, "workspace-root manifest")
    current_git_roots = workspace_git_relative_paths(records)
    if current_git_roots != set(git_rows):
        raise CleanupError(
            f"Workspace nested Git-root coverage changed: expected={sorted(git_rows)}, "
            f"current={sorted(current_git_roots)}"
        )
    if len(git_rows) != source_identity.get("gitRootCount"):
        raise CleanupError(f"Workspace nested Git-root count changed: {logical_source}")
    for project_relative, git_row in git_rows.items():
        relative_parts = () if project_relative == "." else PurePosixPath(project_relative).parts
        actual_project = source.joinpath(*relative_parts)
        logical_project = logical_source.joinpath(*relative_parts)
        declared_state = declared_git_state(actual_project / ".git")
        if declared_state != git_row.get("gitState"):
            raise CleanupError(f"Workspace Git pointer state changed: {logical_project}")
        raw_components = git_row.get("components")
        assert isinstance(raw_components, list)
        expected_source_components = [
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
            for component in raw_components
            if isinstance(component, dict)
        ]
        components = verify_receipt_git_components(
            actual_project,
            logical_project,
            expected_source_components,
            allow_stopped_fsmonitor=fsmonitor_stopped,
            container_source=source,
            logical_container=logical_source,
        )
        if component_set_digest(components) != git_row.get("componentsDigest"):
            raise CleanupError(f"Workspace Git component set changed: {logical_project}")
        if source_override is None:
            discovered_components, discovered_state = git_component_paths(
                actual_project,
                logical_source=logical_project,
            )
            normalized_state = "broken" if discovered_state == "broken" else discovered_state
            if normalized_state != git_row.get("gitState") or discovered_components != components:
                raise CleanupError(f"Workspace proof omitted or changed a live Git component: {logical_project}")
        for component, current_component in zip(raw_components, components):
            assert isinstance(component, dict)
            representation_path = absolute(str(component.get("representationPath")))
            if not (
                within(representation_path, binding.canonical_root)
                or within(representation_path, report_dir)
                or within(representation_path, managed_temp)
            ):
                raise CleanupError(f"Workspace Git component evidence escapes managed roots: {representation_path}")
            if any(
                representation_path == root.path or within(representation_path, root.path)
                for root in cleanup_roots
            ) or within(representation_path, quarantine_base):
                raise CleanupError(f"Workspace Git component evidence points into retired local data: {representation_path}")
            representation_base = (
                binding.canonical_root
                if within(representation_path, binding.canonical_root)
                else report_dir
                if within(representation_path, report_dir)
                else managed_temp
            )
            ensure_exact_case_entry_path(
                representation_path,
                representation_base,
                "workspace Git component representation",
            )
            if os.lstat(representation_path).st_dev != os.stat(managed_root).st_dev:
                raise CleanupError(f"Workspace Git evidence crosses managed volume: {representation_path}")
            _rows, representation_digest, representation_sockets = scan_tree(
                representation_path,
                exclude_top_git=False,
            )
            if representation_sockets:
                raise CleanupError(f"Workspace Git evidence contains ephemeral socket: {representation_path}")
            if (
                representation_digest != current_component.get("treeDigest")
                or representation_digest != component.get("representationTreeDigest")
            ):
                raise CleanupError(f"Workspace Git component representation changed: {representation_path}")


def verify_destination_binding(
    binding: ReceiptBinding,
    gh_cache: dict[str, dict[str, str]],
    fsck_cache: dict[str, str],
) -> None:
    mapping = binding.mapping
    ensure_exact_case_real_path(mapping.destination, mapping.destination.parents[1], "canonical destination")
    remote = github_remote_repository(mapping.destination)
    if remote != mapping.repository:
        raise CleanupError(
            f"Canonical origin identity differs with exact case: {mapping.destination}: {remote} != {mapping.repository}"
        )
    cache_key = f"{binding.github_account}:{mapping.repository}"
    if cache_key not in gh_cache:
        gh_cache[cache_key] = gh_repository_identity(mapping.repository, binding.github_account)
    identity = gh_cache[cache_key]
    destination_identity = require_identity_object(binding.receipt, "destinationIdentity", "receipt")
    group_proof = load_json(binding.group_proof_path, "destination group proof")
    if identity.get("authenticatedLogin") != binding.github_account:
        raise CleanupError(f"Fresh authenticated GitHub login changed: {mapping.repository}")
    for key in ("nodeID", "databaseID"):
        for claimed in (destination_identity.get(key), group_proof.get(key)):
            if claimed != identity[key]:
                raise CleanupError(f"Authoritative GitHub {key} mismatch: {mapping.repository}")
        reviewed = binding.reviewed_repository_identity.get(key)
        if reviewed is not None and identity[key] != reviewed:
            raise CleanupError(f"Fresh GitHub {key} differs from reviewed map identity: {mapping.repository}")
    destination_key = display(mapping.destination)
    if destination_key not in fsck_cache:
        fsck_cache[destination_key] = strict_fsck(mapping.destination)


def volume_identity(path: Path, *, require_external_fields: bool) -> dict[str, object]:
    path = absolute(path)
    metadata = os.stat(path)
    result: dict[str, object] = {"device": metadata.st_dev, "path": display(path)}
    df = run_command(["df", "-P", path], timeout=30)
    if df.returncode != 0:
        raise CleanupError(f"Could not identify mounted volume for {path}")
    lines = df.stdout.decode("utf-8", "replace").splitlines()
    if len(lines) < 2:
        raise CleanupError(f"df returned no mounted volume for {path}")
    df_match = re.match(r"^(\S+)\s+\d+\s+\d+\s+\d+\s+\d+%\s+(.+)$", lines[-1])
    if df_match is None:
        raise CleanupError(f"Could not parse mounted volume identity for {path}")
    result["deviceNode"] = df_match.group(1)
    result["mountPoint"] = df_match.group(2)
    if sys.platform == "darwin" and shutil.which("diskutil"):
        disk = run_command(["diskutil", "info", "-plist", str(result["deviceNode"])], timeout=30)
        if disk.returncode != 0:
            raise CleanupError(f"diskutil could not identify volume for {path}")
        try:
            payload = plistlib.loads(disk.stdout)
        except plistlib.InvalidFileException as error:
            raise CleanupError(f"diskutil returned invalid volume metadata for {path}") from error
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
            personality = str(result.get("filesystemName", ""))
            result["caseSensitive"] = "case-sensitive" in personality.casefold()
        mount = run_command(["/sbin/mount"], timeout=30)
        if mount.returncode != 0:
            raise CleanupError(f"Could not inspect mount flags for {path}")
        mount_point = str(result.get("diskutilMountPoint", ""))
        matching_lines = [
            line
            for line in mount.stdout.decode("utf-8", "replace").splitlines()
            if f" on {mount_point} (" in line
        ]
        if len(matching_lines) != 1:
            raise CleanupError(f"Could not bind an exact mount-flags record for {mount_point}")
        flags_match = re.search(r"\((.*)\)\s*$", matching_lines[0])
        if flags_match is None:
            raise CleanupError(f"Could not parse mount flags for {mount_point}")
        result["mountFlags"] = sorted(
            flag.strip() for flag in flags_match.group(1).split(",") if flag.strip()
        )
    if require_external_fields:
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
            raise CleanupError(f"Managed evidence volume identity is incomplete ({missing}): {path}")
        if sys.platform == "darwin":
            if absolute(str(result["mountPoint"])) != absolute(str(result["diskutilMountPoint"])):
                raise CleanupError(f"df/diskutil mount identity differs for managed evidence: {path}")
            expected_device_node = f"/dev/{result['deviceIdentifier']}"
            if result.get("deviceNode") != expected_device_node:
                raise CleanupError(f"df/diskutil device identity differs for managed evidence: {path}")
            if not (
                result.get("internal") is False
                or result.get("externalDevice") is True
                or result.get("removableMedia") is True
            ):
                raise CleanupError(f"Managed evidence volume is not proven external: {path}")
        if result.get("writable") is False or result.get("readOnlyVolume") is True:
            raise CleanupError(f"Managed evidence volume is not writable: {path}")
    return result


def same_volume_identity(expected: dict[str, object], current: dict[str, object]) -> bool:
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
    return all(expected.get(key) == current.get(key) for key in keys if key in expected or key in current)


def mappings_for_root(plan: CleanupPlan, root: CleanupRoot) -> list[MappingRow]:
    return [mapping for mapping in plan.mappings if mapping.source == root.path or within(mapping.source, root.path)]


def revalidate_plan_file(plan: CleanupPlan) -> None:
    require_owned_nonwritable_regular(plan.path, "cleanup mapping plan")
    if sha256_file(plan.path) != plan.source_map_sha256:
        raise CleanupError(f"Source map changed after it was bound into the transaction: {plan.path}")


def validate_existing_managed_directory(path: Path, managed_root: Path, label: str) -> None:
    if not within(path, managed_root):
        raise CleanupError(f"{label} is outside managed root: {path}")
    ensure_no_symlink_components(path, managed_root, label)
    mode = os.lstat(path).st_mode
    if stat.S_ISLNK(mode) or not stat.S_ISDIR(mode):
        raise CleanupError(f"{label} is not a real directory: {path}")


def build_preflight(
    plan: CleanupPlan,
    managed_root: Path,
    merge_report_dir: Path,
    recovery_transaction: str,
) -> PreflightResult:
    errors = validate_roots(plan.roots, managed_root, source_required=True)
    try:
        revalidate_plan_file(plan)
        validate_existing_managed_directory(
            merge_report_dir,
            managed_root,
            "recovery merge report directory",
        )
    except CleanupError as error:
        errors.append(str(error))

    warnings: list[str] = []
    for overlap in plan.overlaps:
        if overlap.resolved:
            warnings.append(
                f"Declared nested mapping coverage: one root transaction for {overlap.parent}; "
                f"child {overlap.child} remains a separate receipt/proof obligation via exclusion "
                f"{overlap.declared_exclusion!r}."
            )
        else:
            errors.append(
                f"Undeclared nested mapping overlap blocks cleanup: {overlap.parent} / {overlap.child}; "
                f"parent must explicitly exclude {overlap.relative_child!r}."
            )
    inventories: dict[str, InventoryResult] = {}
    runner_states: dict[str, RunnerState] = {}
    process_map: dict[str, list[ProcessReference]] = {}
    bindings: dict[str, ReceiptBinding] = {}
    workspace_bindings: dict[str, WorkspaceRootBinding] = {}
    success_marker: dict[str, object] = {}
    table: dict[int, ProcessInfo] = {}
    try:
        table = process_table()
    except CleanupError as error:
        errors.append(str(error))

    try:
        success_marker, receipt_paths = load_success_marker(
            merge_report_dir, recovery_transaction, plan
        )
        bindings, receipt_errors = load_receipt_bindings(
            plan,
            merge_report_dir,
            managed_root,
            recovery_transaction,
            success_marker,
            receipt_paths,
        )
        errors.extend(receipt_errors)
        workspace_bindings, workspace_errors = load_workspace_root_bindings(
            plan,
            merge_report_dir,
            managed_root,
            recovery_transaction,
            success_marker,
        )
        errors.extend(workspace_errors)
    except CleanupError as error:
        errors.append(str(error))

    recovery_retired_count = 0
    for mapping in plan.mappings:
        binding = bindings.get(display(mapping.source))
        if binding is None:
            continue
        try:
            receipt_source = receipt_bound_source_path(binding, managed_root)
            if receipt_source != mapping.source:
                recovery_retired_count += 1
                verify_representation_binding(
                    binding,
                    managed_root,
                    merge_report_dir,
                    source_override=receipt_source,
                    fsmonitor_stopped=True,
                )
        except (CleanupError, OSError) as error:
            errors.append(str(error))
    if recovery_retired_count:
        warnings.append(
            f"Validated {recovery_retired_count} recovery-retired mapping source(s) through "
            "their exact final receipts and managed transaction quarantine paths."
        )

    if success_marker and runner_drain_items(plan):
        errors.extend(
            validate_completed_runner_restore(
                plan,
                managed_root,
                merge_report_dir,
                recovery_transaction,
                success_marker,
            )
        )

    gh_cache: dict[str, dict[str, str]] = {}
    fsck_cache: dict[str, str] = {}
    for item in plan.roots:
        key = display(item.path)
        workspace_binding = workspace_bindings.get(key)
        if workspace_binding is None:
            inventory = inventory_root(item, plan.mappings)
        else:
            # Do not recursively read the old Runtime while its exact restored
            # runner set may be active.  Apply performs a second exact drain,
            # then verifies the complete manifest and inventories the root
            # before any evidence copy or rename.
            inventory = InventoryResult(item.path)
            warnings.append(
                f"Whole-workspace live scan deferred until exact apply-time runner drain: {item.path}"
            )
        inventories[key] = inventory
        errors.extend(inventory.errors)
        if table:
            errors.extend(execution_path_blockers(item.path, table))
            state: RunnerState | None = None
            if item.requires_process_drain:
                state = capture_runner_state(item, table, capture_critical_hashes=False)
                runner_states[key] = state
                errors.extend(state.blockers)
            try:
                references = process_references(item.path, table)
            except CleanupError as error:
                errors.append(str(error))
                references = []
            process_map[key] = references
            allowed = state.runner_pids if state else set()
            unexpected = [reference for reference in references if reference.pid not in allowed]
            if unexpected:
                errors.append(
                    f"Active process cwd/open-file/executable references block {item.path}: "
                    + "; ".join(
                        f"pid={value.pid} {value.command_name} {value.kind} {value.path}"
                        for value in unexpected[:20]
                    )
                )
            if state and references:
                warnings.append(
                    f"Runner drain required for {item.path}: loaded="
                    f"{sum(service.loaded for service in state.services)} references={len(references)}"
                )

        root_mappings = mappings_for_root(plan, item)
        if not root_mappings:
            if workspace_binding is None:
                errors.append(
                    f"No exact source-map mapping or final workspace-root proof covers cleanup root: {item.path}"
                )
            if not item.requires_process_drain:
                errors.append(
                    f"Zero-mapping whole-workspace retirement requires exact process drain: {item.path}"
                )
        for mapping in root_mappings:
            if mapping.destination_owner not in plan.github_accounts:
                errors.append(
                    f"Destination owner has no reviewed GitHub account binding: "
                    f"{mapping.destination_owner} ({mapping.repository})"
                )
            binding = bindings.get(display(mapping.source))
            if binding is None:
                errors.append(f"Cleanup source lacks a final transaction-bound receipt: {mapping.source}")
                continue
            try:
                verify_representation_binding(binding, managed_root, merge_report_dir)
                verify_destination_binding(binding, gh_cache, fsck_cache)
            except (CleanupError, OSError) as error:
                errors.append(str(error))

    if table and (bindings or workspace_bindings):
        try:
            component_blockers, component_warnings = git_component_process_blockers(
                PreflightResult(
                    plan,
                    plan.roots,
                    inventories,
                    bindings,
                    workspace_bindings,
                    runner_states,
                    process_map,
                    recovery_transaction,
                    success_marker,
                    {},
                    [],
                    [],
                ),
                table,
                allow_fsmonitor=True,
            )
            errors.extend(component_blockers)
            warnings.extend(component_warnings)
        except CleanupError as error:
            errors.append(str(error))

    try:
        volume = volume_identity(managed_root / "_temp", require_external_fields=True)
        required = sum(value.allocated_bytes for value in inventories.values())
        free = shutil.disk_usage(managed_root / "_temp").free
        volume["freeBytesObserved"] = free
        volume["evidenceAllocatedBytesRequired"] = required
        deferred_roots = sorted(workspace_bindings, key=os.fsencode)
        volume["evidenceAllocatedBytesDeferredRoots"] = deferred_roots
        if deferred_roots:
            warnings.append(
                "Evidence free-space requirement for whole-workspace root(s) will be measured after exact runner drain: "
                + ", ".join(deferred_roots)
            )
        if free < required + max(10 * 1024**3, required // 20):
            errors.append(
                f"Managed evidence volume lacks safe free-space margin: "
                f"required={required} free={free}"
            )
    except (CleanupError, OSError) as error:
        errors.append(str(error))
        volume = {}
    return PreflightResult(
        plan,
        plan.roots,
        inventories,
        bindings,
        workspace_bindings,
        runner_states,
        process_map,
        recovery_transaction,
        success_marker,
        volume,
        sorted(set(errors)),
        sorted(set(warnings)),
    )


def preflight_payload(result: PreflightResult) -> dict[str, object]:
    return {
        "format": 2,
        "mode": "read-only-preflight",
        "recoveryTransaction": result.recovery_transaction,
        "sourceMapSHA256": result.plan.source_map_sha256,
        "githubAccountsSHA256": result.plan.github_accounts_sha256,
        "repositoryIdentitiesSHA256": result.plan.repository_identities_sha256,
        "rootCount": len(result.roots),
        "receiptBindingCount": len(result.bindings),
        "workspaceRootProofKind": WORKSPACE_ROOT_PROOF_KIND,
        "workspaceRootProofCount": len(result.workspace_bindings),
        "blockers": result.errors,
        "warnings": result.warnings,
        "mappingOverlaps": [
            {
                "parent": display(overlap.parent),
                "child": display(overlap.child),
                "relativeChild": overlap.relative_child,
                "declaredExclusion": overlap.declared_exclusion,
                "resolvedAsSingleRootTransaction": overlap.resolved,
                "childReceiptStillRequired": True,
            }
            for overlap in result.plan.overlaps
        ],
        "volumeIdentity": result.volume_identity,
        "roots": [
            {
                "path": display(item.path),
                "origin": item.origin,
                "requiresProcessDrain": item.requires_process_drain,
                "mappedSourceCount": len(mappings_for_root(result.plan, item)),
                "workspaceRootProof": (
                    {
                        "bound": True,
                        "proofPath": display(result.workspace_bindings[display(item.path)].proof_path),
                        "proofSHA256": result.workspace_bindings[display(item.path)].proof_sha256,
                        "manifestPath": display(result.workspace_bindings[display(item.path)].manifest_path),
                        "manifestSHA256": result.workspace_bindings[display(item.path)].manifest_sha256,
                        "liveVerification": "deferred-until-exact-apply-runner-drain",
                    }
                    if display(item.path) in result.workspace_bindings
                    else {"bound": False, "liveVerification": "not-applicable"}
                ),
                "inventory": {
                    "entryCount": result.inventories[display(item.path)].entry_count,
                    "logicalBytes": result.inventories[display(item.path)].logical_bytes,
                    "allocatedBytes": result.inventories[display(item.path)].allocated_bytes,
                    "gitRoots": result.inventories[display(item.path)].git_roots,
                    "projectMarkerCount": len(result.inventories[display(item.path)].project_markers),
                    "ownerLanes": result.inventories[display(item.path)].owner_lanes,
                    "uncoveredCount": result.inventories[display(item.path)].uncovered_count,
                    "uncoveredSamples": result.inventories[display(item.path)].uncovered,
                    "specialFiles": result.inventories[display(item.path)].special_files,
                    "fsmonitorSockets": result.inventories[display(item.path)].fsmonitor_sockets,
                },
                "replacementLinks": [
                    {"path": display(link.path), "target": display(link.target)} for link in item.links
                ],
                "replacementOverlays": [
                    {
                        "path": display(overlay.path),
                        "baseTarget": display(overlay.base_target),
                        "overrides": [
                            {"relativePath": display(override.relative_path), "target": display(override.target)}
                            for override in overlay.overrides
                        ],
                    }
                    for overlay in item.overlays
                ],
            }
            for item in result.roots
        ],
    }


def stop_fsmonitor_sockets(result: PreflightResult) -> list[Path]:
    repos: list[Path] = []
    sockets: list[Path] = []
    for inventory in result.inventories.values():
        for socket_path in inventory.fsmonitor_sockets:
            path = Path(socket_path)
            sockets.append(path)
            current = path.parent
            while current != inventory.root.parent:
                if (current / ".git").exists():
                    repos.append(current)
                    break
                current = current.parent
    for binding in result.bindings.values():
        if not any(
            binding.mapping.source == root.path or within(binding.mapping.source, root.path)
            for root in result.roots
        ):
            continue
        source_identity = require_identity_object(binding.receipt, "sourceIdentity", "receipt")
        components = source_identity.get("gitComponents", [])
        if not isinstance(components, list):
            continue
        binding_has_socket = False
        for component in components:
            if not isinstance(component, dict) or not isinstance(component.get("path"), str):
                continue
            component_root = Path(component["path"])
            ephemeral = component.get("ephemeralFsmonitorSockets", [])
            if not isinstance(ephemeral, list):
                continue
            for relative in ephemeral:
                if not isinstance(relative, str):
                    continue
                socket_path = component_root if relative == "." else component_root / relative
                sockets.append(socket_path)
                binding_has_socket = True
        if binding_has_socket:
            repos.append(binding.mapping.source)
    for workspace_binding in result.workspace_bindings.values():
        git_roots = workspace_binding.manifest.get("gitRoots", [])
        if not isinstance(git_roots, list):
            continue
        for git_root in git_roots:
            if not isinstance(git_root, dict):
                continue
            project_relative = git_root.get("projectRelativePath")
            components = git_root.get("components")
            if not isinstance(project_relative, str) or not isinstance(components, list):
                continue
            project = workspace_binding.root.path
            if project_relative != ".":
                project = project.joinpath(*PurePosixPath(project_relative).parts)
            project_has_socket = False
            for component in components:
                if not isinstance(component, dict) or not isinstance(component.get("path"), str):
                    continue
                component_root = Path(component["path"])
                ephemeral = component.get("ephemeralFsmonitorSockets", [])
                if not isinstance(ephemeral, list):
                    continue
                for relative in ephemeral:
                    if not isinstance(relative, str):
                        continue
                    socket_path = component_root if relative == "." else component_root / relative
                    sockets.append(socket_path)
                    project_has_socket = True
            if project_has_socket:
                repos.append(project)
    unique = sorted(set(repos), key=lambda path: os.fsencode(display(path)))
    for repo in unique:
        command = run_command(["git", "-C", repo, "fsmonitor--daemon", "stop"], timeout=60)
        if command.returncode != 0:
            raise CleanupError(f"Could not stop Git fsmonitor for {repo}")
    deadline = time.monotonic() + 10
    sockets = sorted(set(sockets), key=lambda path: os.fsencode(display(path)))
    while time.monotonic() < deadline and any(os.path.lexists(path) for path in sockets):
        time.sleep(0.2)
    remaining = [path for path in sockets if os.path.lexists(path)]
    if remaining:
        raise CleanupError("Git fsmonitor sockets remained after stop: " + ", ".join(map(display, remaining)))
    return unique


def restart_fsmonitor(repos: Sequence[Path]) -> list[str]:
    errors: list[str] = []
    for repo in repos:
        if not repo.exists():
            continue
        result = run_command(["git", "-C", repo, "fsmonitor--daemon", "start"], timeout=60)
        if result.returncode != 0:
            errors.append(f"Could not restart Git fsmonitor for {repo}")
    return errors


def rollback_roots(
    moved: Sequence[tuple[CleanupRoot, Path]],
    staging_paths: Sequence[Path],
) -> list[str]:
    errors: list[str] = []
    for item, quarantine in reversed(moved):
        try:
            verify_compatibility_layout(item)
            remove_path_without_following(item.path)
            fsync_directory(item.path.parent)
        except (CleanupError, OSError) as error:
            errors.append(
                f"Could not safely verify/remove compatibility layout for {item.path}: {error}"
            )
            continue
        try:
            if os.path.lexists(item.path):
                errors.append(f"Could not restore {item.path}: compatibility path still exists")
            elif quarantine.exists() and not quarantine.is_symlink():
                guarded_replace(quarantine, item.path)
                fsync_directory(item.path.parent)
                fsync_directory(quarantine.parent)
            else:
                errors.append(f"Could not restore {item.path}: quarantine is missing")
        except OSError as error:
            errors.append(f"Could not restore {item.path}: {error}")
    for path in staging_paths:
        try:
            remove_path_without_following(path)
        except OSError as error:
            errors.append(f"Could not remove compatibility staging {path}: {error}")
    return errors


def workspace_record_bindings(
    records: Sequence[dict[str, object]],
) -> list[dict[str, object]]:
    rows = [
        {
            "cleanupRoot": str(record.get("source")),
            **dict(record["workspaceRootProof"]),
        }
        for record in records
        if isinstance(record.get("workspaceRootProof"), dict)
    ]
    rows.sort(key=lambda value: os.fsencode(str(value["cleanupRoot"])))
    return rows


def journal_payload(
    transaction: str,
    recovery_transaction: str,
    plan: CleanupPlan,
    volume: dict[str, object],
    records: Sequence[dict[str, object]],
    status: str,
) -> dict[str, object]:
    workspace_rows = workspace_record_bindings(records)
    return {
        "format": 2,
        "transaction": transaction,
        "recoveryTransaction": recovery_transaction,
        "sourceMapSHA256": plan.source_map_sha256,
        "githubAccountsSHA256": plan.github_accounts_sha256,
        "repositoryIdentitiesSHA256": plan.repository_identities_sha256,
        "status": status,
        "managedEvidenceVolume": volume,
        "workspaceRootProofKind": WORKSPACE_ROOT_PROOF_KIND,
        "workspaceRootProofCount": len(workspace_rows),
        "workspaceRootProofBindingsSHA256": sha256_bytes(stable_json(workspace_rows)),
        "roots": list(records),
    }


def execute_retirement(
    result: PreflightResult,
    managed_root: Path,
    merge_report_dir: Path,
    report_dir: Path,
    transaction: str,
) -> None:
    if result.errors:
        raise CleanupError("Apply was called with preflight blockers.")
    fresh_result = build_preflight(
        result.plan,
        managed_root,
        merge_report_dir,
        result.recovery_transaction,
    )
    if fresh_result.errors:
        raise CleanupError(
            "Cleanup state changed after preflight: " + "; ".join(fresh_result.errors)
        )
    result = fresh_result
    helper = Path(__file__).with_name("repo-consolidation-recovery.py")
    core = runpy.run_path(display(helper), run_name="repo_consolidation_recovery_core")
    copy_verified = core.get("copy_exact_verified")
    verify_snapshot = core.get("verify_exact_path_snapshot")
    if not callable(copy_verified) or not callable(verify_snapshot):
        raise CleanupError("Recovery helper does not expose exact copy/verify functions.")

    evidence_root = managed_root / "_temp" / "Local-Source-Evidence" / transaction
    home = user_home_boundary()
    quarantine_root = home / ".csa-iem-quarantine" / transaction
    if os.path.lexists(evidence_root) or os.path.lexists(quarantine_root) or os.path.lexists(report_dir):
        raise CleanupError("Cleanup transaction output already exists; refusing to resume ambiguously.")
    # Precheck all destinations and same-volume requirements before any process or source mutation.
    quarantine_parent = quarantine_root.parent
    if not result.roots:
        raise CleanupError("Cleanup transaction has no roots.")
    home_device = os.stat(home).st_dev
    for item in result.roots:
        if os.stat(item.path).st_dev != home_device:
            raise CleanupError(f"Cleanup roots span filesystems and cannot share atomic quarantine: {item.path}")
        if os.path.lexists(quarantine_root / identifier(item.path)):
            raise CleanupError(f"Quarantine collision for {item.path}")

    secure_mkdirs(quarantine_parent, home, mode=0o700)
    if os.stat(quarantine_parent).st_dev != home_device:
        raise CleanupError("Local quarantine parent is not on the captured home filesystem.")
    secure_mkdirs(report_dir, managed_root, mode=0o700)
    secure_mkdirs(evidence_root, managed_root, mode=0o700)
    secure_mkdirs(quarantine_root, home, mode=0o700)
    for directory in (report_dir, evidence_root, quarantine_root):
        os.chmod(directory, 0o700)
        fsync_directory(directory)
        fsync_directory(directory.parent)
    journal = report_dir / "local-cleanup-journal.json"
    records: list[dict[str, object]] = []
    for item in result.roots:
        source_stat = os.lstat(item.path)
        workspace_binding = result.workspace_bindings.get(display(item.path))
        records.append(
            {
                "source": display(item.path),
                "device": source_stat.st_dev,
                "inode": source_stat.st_ino,
                "evidence": display(evidence_root / identifier(item.path) / "source"),
                "quarantine": display(quarantine_root / identifier(item.path)),
                "compatibilityStaging": display(quarantine_root / (identifier(item.path) + ".compat")),
                "status": "prechecked",
                "receiptSources": [display(mapping.source) for mapping in mappings_for_root(result.plan, item)],
                "workspaceRootProof": (
                    {
                        "proofKind": WORKSPACE_ROOT_PROOF_KIND,
                        "proofSHA256": workspace_binding.proof_sha256,
                        "manifestSHA256": workspace_binding.manifest_sha256,
                        "sourceTreeDigest": workspace_binding.proof["sourceIdentity"]["treeDigest"],
                        "entryCount": workspace_binding.proof["sourceIdentity"]["entryCount"],
                    }
                    if workspace_binding is not None
                    else None
                ),
            }
        )
    write_json(
        journal,
        journal_payload(
            transaction,
            result.recovery_transaction,
            result.plan,
            result.volume_identity,
            records,
            "prechecked",
        ),
    )

    runner_states = list(result.runner_states.values())
    moved: list[tuple[CleanupRoot, Path]] = []
    staging_paths: list[Path] = []
    fsmonitor_repos: list[Path] = []
    try:
        revalidate_plan_file(result.plan)
        fsmonitor_repos = stop_fsmonitor_sockets(result)
        for state in runner_states:
            drain_runner_state(state)

        # No process, cwd, executable, or open-file reference may remain after the exact drain.
        table = process_table()
        for item in result.roots:
            references = process_references(item.path, table)
            if references:
                raise CleanupError(
                    f"Process references remain after runner drain for {item.path}: "
                    + "; ".join(f"pid={value.pid} {value.kind} {value.path}" for value in references[:20])
                )
        component_blockers, _component_warnings = git_component_process_blockers(
            result,
            table,
            allow_fsmonitor=False,
        )
        if component_blockers:
            raise CleanupError("; ".join(component_blockers[:20]))

        # Runtime and the complete workspace are read only after the exact
        # runner set is quiesced.  This is an all-roots precondition: no
        # evidence copy or rename begins until every workspace proof and every
        # nested inventory entry has been freshly verified.
        for state in runner_states:
            critical, critical_errors = runner_critical_hashes(state.root, state.canonical_root)
            if critical_errors:
                raise CleanupError("; ".join(critical_errors))
            state.critical_hashes = critical
        for key, workspace_binding in result.workspace_bindings.items():
            verify_workspace_root_binding(
                workspace_binding,
                managed_root,
                merge_report_dir,
                fsmonitor_stopped=True,
                cleanup_roots=result.roots,
            )
            git_roots = load_workspace_git_root_rows(
                workspace_binding.manifest,
                "workspace-root manifest",
            )
            inventory = inventory_root(
                workspace_binding.root,
                result.plan.mappings,
                workspace_coverage=set(workspace_binding.entries),
                workspace_git_roots=set(git_roots),
            )
            result.inventories[key] = inventory
            if inventory.errors:
                raise CleanupError("; ".join(inventory.errors[:20]))
        required = sum(value.allocated_bytes for value in result.inventories.values())
        free = shutil.disk_usage(managed_root / "_temp").free
        if free < required + max(10 * 1024**3, required // 20):
            raise CleanupError(
                f"Managed evidence volume lacks safe free-space margin after quiesced inventory: "
                f"required={required} free={free}"
            )
        result.volume_identity["freeBytesObservedAfterRunnerDrain"] = free
        result.volume_identity["evidenceAllocatedBytesRequired"] = required
        result.volume_identity["evidenceAllocatedBytesDeferredRoots"] = []

        # Copy and fsync every evidence tree, then build every compatibility layout, before moving any root.
        for item, record in zip(result.roots, records):
            evidence = Path(str(record["evidence"]))
            digest = copy_verified(item.path, evidence, evidence.parent)
            fsync_tree(evidence)
            verified = verify_snapshot(item.path, evidence)
            if verified != digest:
                raise CleanupError(f"Managed evidence verification differs for {item.path}")
            record["evidenceDigest"] = digest
            record["status"] = "evidence-durable"
            write_json(
                journal,
                journal_payload(
                    transaction,
                    result.recovery_transaction,
                    result.plan,
                    result.volume_identity,
                    records,
                    "evidence-copy",
                ),
            )
            staging = Path(str(record["compatibilityStaging"]))
            build_compatibility_staging(item, staging)
            staging_paths.append(staging)

        current_volume = volume_identity(managed_root / "_temp", require_external_fields=True)
        if not same_volume_identity(result.volume_identity, current_volume):
            raise CleanupError("Managed evidence volume identity changed after evidence fsync.")

        # Reverify source-to-canonical/evidence immediately before the first rename.
        revalidate_plan_file(result.plan)
        gh_cache: dict[str, dict[str, str]] = {}
        fsck_cache: dict[str, str] = {}
        for binding in result.bindings.values():
            verify_representation_binding(
                binding,
                managed_root,
                merge_report_dir,
                fsmonitor_stopped=True,
            )
            verify_destination_binding(binding, gh_cache, fsck_cache)
        for workspace_binding in result.workspace_bindings.values():
            verify_workspace_root_binding(
                workspace_binding,
                managed_root,
                merge_report_dir,
                fsmonitor_stopped=True,
                cleanup_roots=result.roots,
            )

        for item, record in zip(result.roots, records):
            quarantine = Path(str(record["quarantine"]))
            staging = Path(str(record["compatibilityStaging"]))
            source_stat = os.lstat(item.path)
            if (source_stat.st_dev, source_stat.st_ino) != (record["device"], record["inode"]):
                raise CleanupError(f"Cleanup root identity changed before quarantine: {item.path}")
            guarded_replace(item.path, quarantine)
            fsync_directory(item.path.parent)
            fsync_directory(quarantine.parent)
            moved.append((item, quarantine))
            moved_stat = os.lstat(quarantine)
            if (moved_stat.st_dev, moved_stat.st_ino) != (record["device"], record["inode"]):
                raise CleanupError(f"Same-volume quarantine changed source identity: {item.path}")
            guarded_replace(staging, item.path)
            fsync_directory(item.path.parent)
            fsync_directory(staging.parent)
            verify_compatibility_layout(item)
            workspace_binding = result.workspace_bindings.get(display(item.path))
            if workspace_binding is not None:
                verify_workspace_root_binding(
                    workspace_binding,
                    managed_root,
                    merge_report_dir,
                    source_override=quarantine,
                    fsmonitor_stopped=True,
                    cleanup_roots=result.roots,
                )
            evidence = Path(str(record["evidence"]))
            if verify_snapshot(quarantine, evidence) != record["evidenceDigest"]:
                raise CleanupError(f"Quarantine/evidence digest changed after compatibility activation: {item.path}")
            record["status"] = "quarantined-compatible-verified"
            write_json(
                journal,
                journal_payload(
                    transaction,
                    result.recovery_transaction,
                    result.plan,
                    result.volume_identity,
                    records,
                    "quarantine-progress",
                ),
            )

        for item, record in zip(result.roots, records):
            verify_compatibility_layout(item)
            quarantine = Path(str(record["quarantine"]))
            evidence = Path(str(record["evidence"]))
            if verify_snapshot(quarantine, evidence) != record["evidenceDigest"]:
                raise CleanupError(f"Final local quarantine/evidence verification changed: {item.path}")
            workspace_binding = result.workspace_bindings.get(display(item.path))
            if workspace_binding is not None:
                verify_workspace_root_binding(
                    workspace_binding,
                    managed_root,
                    merge_report_dir,
                    source_override=quarantine,
                    fsmonitor_stopped=True,
                    cleanup_roots=result.roots,
                )
            record["status"] = "quarantine-retained-evidence-durable"

        current_volume = volume_identity(managed_root / "_temp", require_external_fields=True)
        if not same_volume_identity(result.volume_identity, current_volume):
            raise CleanupError("Managed evidence volume identity changed before transaction finalization.")
        fsmonitor_errors = restart_fsmonitor(fsmonitor_repos)
        if fsmonitor_errors:
            raise CleanupError("; ".join(fsmonitor_errors))
        for state in reversed(runner_states):
            restore_runner_state(state)
        runner_snapshot_values = [runner_state_snapshot(state) for state in runner_states]
        final_table = process_table()
        for item in result.roots:
            if not item.requires_process_drain:
                continue
            state = result.runner_states[display(item.path)]
            runner_errors = verify_recorded_runner_state(item, runner_state_snapshot(state), final_table)
            runner_errors.extend(verify_runner_hashes(state, root=state.canonical_root))
            if runner_errors:
                raise CleanupError("Runner post-restore verification failed: " + "; ".join(runner_errors))

        completed_journal = journal_payload(
            transaction,
            result.recovery_transaction,
            result.plan,
            result.volume_identity,
            records,
            "complete-quarantine-retained",
        )
        write_json(
            journal,
            completed_journal,
        )
        final = {
            "format": 2,
            "status": "complete-quarantine-retained",
            "transaction": transaction,
            "recoveryTransaction": result.recovery_transaction,
            "sourceMapSHA256": result.plan.source_map_sha256,
            "githubAccountsSHA256": result.plan.github_accounts_sha256,
            "repositoryIdentitiesSHA256": result.plan.repository_identities_sha256,
            "managedEvidenceRoot": display(evidence_root),
            "managedEvidenceVolume": result.volume_identity,
            "workspaceRootProofKind": WORKSPACE_ROOT_PROOF_KIND,
            "workspaceRootProofCount": len(result.workspace_bindings),
            "workspaceRootProofSetSHA256": result.success_marker.get(
                "workspaceRootProofSetSHA256"
            ),
            "workspaceRootProofs": result.success_marker.get("workspaceRootProofs"),
            "workspaceRootProofBindingsSHA256": completed_journal[
                "workspaceRootProofBindingsSHA256"
            ],
            "runnerStateRestored": True,
            "runnerSnapshots": runner_snapshot_values,
            "localQuarantineDeleted": False,
            "roots": records,
        }
        write_json(report_dir / "final-audit.json", final)
        write_text(
            report_dir / "final.md",
            "# CSA-iEM Local Source Retirement\n\n"
            f"- Transaction: `{transaction}`\n"
            f"- Recovery transaction: `{result.recovery_transaction}`\n"
            f"- Roots quarantined: **{len(records)}**\n"
            f"- Managed evidence: `{evidence_root}`\n"
            "- Local quarantine deleted: **no**\n"
            "- Runner state restored: **yes**\n",
        )
    except Exception as error:
        # If services were already restored when a late check failed, drain the
        # same exact set again before removing compatibility paths.  Never
        # change a path beneath a live runner.
        runner_drain_errors: list[str] = []
        for state in runner_states:
            try:
                drain_runner_state(state)
            except Exception as drain_error:
                runner_drain_errors.append(str(drain_error))
        rollback_errors = (
            rollback_roots(moved, staging_paths)
            if not runner_drain_errors
            else ["Rollback was withheld because exact runner drain could not be re-established."]
        )
        runner_errors: list[str] = []
        for state in reversed(runner_states):
            try:
                restore_runner_state(state)
            except Exception as runner_error:  # preserve the primary failure and report both
                runner_errors.append(str(runner_error))
        fsmonitor_errors = restart_fsmonitor(fsmonitor_repos)
        failure = {
            "error": str(error),
            "runnerDrainErrors": runner_drain_errors,
            "rollbackErrors": rollback_errors,
            "runnerRestoreErrors": runner_errors,
            "fsmonitorRestoreErrors": fsmonitor_errors,
        }
        try:
            write_json(
                journal,
                {
                    **journal_payload(
                        transaction,
                        result.recovery_transaction,
                        result.plan,
                        result.volume_identity,
                        records,
                        "rolled-back" if not rollback_errors and not runner_errors else "rollback-incomplete",
                    ),
                    "failure": failure,
                },
            )
        except OSError:
            pass
        details = runner_drain_errors + rollback_errors + runner_errors + fsmonitor_errors
        if details:
            raise CleanupError(f"Retirement failed: {error}; recovery errors: {'; '.join(details)}") from error
        raise CleanupError(f"Retirement failed and was rolled back: {error}") from error


def quarantine_source_path(record: dict[str, object], mapping: MappingRow) -> Path:
    source_root = absolute(str(record["source"]))
    quarantine = absolute(str(record["quarantine"]))
    try:
        relative = mapping.source.relative_to(source_root)
    except ValueError as error:
        raise CleanupError(f"Receipt source is not inside its recorded cleanup root: {mapping.source}") from error
    return quarantine / relative


def evidence_source_path(record: dict[str, object], mapping: MappingRow) -> Path:
    source_root = absolute(str(record["source"]))
    evidence = absolute(str(record["evidence"]))
    try:
        relative = mapping.source.relative_to(source_root)
    except ValueError as error:
        raise CleanupError(f"Receipt source is not inside its evidence cleanup root: {mapping.source}") from error
    return evidence / relative


def load_completed_retirement(
    report_dir: Path,
    transaction: str,
    recovery_transaction: str,
    plan: CleanupPlan,
    *,
    quarantine_deleted: bool = False,
) -> dict[str, object]:
    final = load_json(report_dir / "final-audit.json", "local retirement final audit")
    expected_status = (
        "complete-quarantine-deleted-evidence-retained"
        if quarantine_deleted
        else "complete-quarantine-retained"
    )
    if (
        final.get("format") != 2
        or final.get("status") != expected_status
        or final.get("transaction") != transaction
        or final.get("recoveryTransaction") != recovery_transaction
        or final.get("sourceMapSHA256") != plan.source_map_sha256
        or final.get("githubAccountsSHA256") != plan.github_accounts_sha256
        or final.get("repositoryIdentitiesSHA256") != plan.repository_identities_sha256
        or final.get("runnerStateRestored") is not True
        or final.get("localQuarantineDeleted") is not quarantine_deleted
    ):
        raise CleanupError("Local retirement final audit is not eligible for permanent deletion.")
    if not isinstance(final.get("roots"), list) or not final["roots"]:
        raise CleanupError("Local retirement final audit has no quarantined roots.")
    records = [record for record in final["roots"] if isinstance(record, dict)]
    if len(records) != len(final["roots"]):
        raise CleanupError("Local retirement final audit contains a non-object root record.")
    expected_roots = {display(item.path) for item in plan.roots}
    recorded_roots = [record.get("source") for record in records]
    if (
        any(not isinstance(value, str) for value in recorded_roots)
        or len(recorded_roots) != len(set(recorded_roots))
        or set(recorded_roots) != expected_roots
    ):
        raise CleanupError("Local retirement final audit root set is not exact.")
    required_workspace_roots = {
        display(item.path) for item in workspace_proof_required_roots(plan)
    }
    workspace_rows = workspace_record_bindings(records)
    if (
        final.get("workspaceRootProofKind") != WORKSPACE_ROOT_PROOF_KIND
        or final.get("workspaceRootProofCount") != len(required_workspace_roots)
        or len(workspace_rows) != len(required_workspace_roots)
        or {str(row.get("cleanupRoot")) for row in workspace_rows} != required_workspace_roots
        or final.get("workspaceRootProofBindingsSHA256")
        != sha256_bytes(stable_json(workspace_rows))
    ):
        raise CleanupError("Local retirement final audit workspace-root proof binding is incomplete.")
    require_sha256(
        final.get("workspaceRootProofSetSHA256"),
        "local retirement workspaceRootProofSetSHA256",
    )
    references = final.get("workspaceRootProofs")
    if not isinstance(references, list) or len(references) != len(required_workspace_roots):
        raise CleanupError("Local retirement final audit lacks the exact workspace-root proof references.")
    for row in workspace_rows:
        if (
            row.get("proofKind") != WORKSPACE_ROOT_PROOF_KIND
            or SHA256_RE.fullmatch(str(row.get("proofSHA256"))) is None
            or SHA256_RE.fullmatch(str(row.get("manifestSHA256"))) is None
            or SHA256_RE.fullmatch(str(row.get("sourceTreeDigest"))) is None
            or not isinstance(row.get("entryCount"), int)
            or row["entryCount"] < 1
        ):
            raise CleanupError("Local retirement final audit has an invalid workspace-root record.")
    return final


def deletion_preflight(
    plan: CleanupPlan,
    managed_root: Path,
    merge_report_dir: Path,
    report_dir: Path,
    transaction: str,
    recovery_transaction: str,
) -> tuple[dict[str, object] | None, list[str]]:
    errors = validate_roots(plan.roots, managed_root, source_required=False)
    try:
        revalidate_plan_file(plan)
        validate_existing_managed_directory(
            merge_report_dir,
            managed_root,
            "recovery merge report directory",
        )
        validate_existing_managed_directory(
            report_dir,
            managed_root,
            "local cleanup report directory",
        )
    except CleanupError as error:
        errors.append(str(error))
    for overlap in plan.overlaps:
        if not overlap.resolved:
            errors.append(
                f"Undeclared nested mapping overlap still blocks deletion: "
                f"{overlap.parent} / {overlap.child}"
            )
    try:
        final = load_completed_retirement(
            report_dir, transaction, recovery_transaction, plan
        )
    except CleanupError as error:
        return None, errors + [str(error)]
    try:
        marker, receipt_paths = load_success_marker(
            merge_report_dir, recovery_transaction, plan
        )
        bindings, receipt_errors = load_receipt_bindings(
            plan,
            merge_report_dir,
            managed_root,
            recovery_transaction,
            marker,
            receipt_paths,
        )
        errors.extend(receipt_errors)
        workspace_bindings, workspace_errors = load_workspace_root_bindings(
            plan,
            merge_report_dir,
            managed_root,
            recovery_transaction,
            marker,
        )
        errors.extend(workspace_errors)
        if (
            final.get("workspaceRootProofSetSHA256")
            != marker.get("workspaceRootProofSetSHA256")
            or final.get("workspaceRootProofs") != marker.get("workspaceRootProofs")
        ):
            errors.append(
                "Local retirement audit workspace-root proof set differs from recovery final marker."
            )
    except CleanupError as error:
        errors.append(str(error))
        return final, sorted(set(errors))
    expected_volume = final.get("managedEvidenceVolume")
    if not isinstance(expected_volume, dict):
        errors.append("Retirement audit lacks managed evidence volume identity.")
    else:
        try:
            current_volume = volume_identity(managed_root / "_temp", require_external_fields=True)
            if not same_volume_identity(expected_volume, current_volume):
                errors.append("Managed evidence volume identity changed since retirement.")
        except CleanupError as error:
            errors.append(str(error))

    record_by_source = {
        str(record.get("source")): record for record in final["roots"] if isinstance(record, dict)
    }
    runner_snapshot_rows = final.get("runnerSnapshots", [])
    if not isinstance(runner_snapshot_rows, list):
        errors.append("Retirement audit runnerSnapshots is invalid.")
        runner_snapshot_rows = []
    runner_snapshots = {
        str(snapshot.get("root")): snapshot
        for snapshot in runner_snapshot_rows
        if isinstance(snapshot, dict) and isinstance(snapshot.get("root"), str)
    }
    table = process_table()
    gh_cache: dict[str, dict[str, str]] = {}
    fsck_cache: dict[str, str] = {}
    for item in plan.roots:
        record = record_by_source.get(display(item.path))
        if record is None:
            errors.append(f"Retirement audit lacks cleanup root: {item.path}")
            continue
        try:
            verify_compatibility_layout(item)
        except (CleanupError, OSError) as error:
            errors.append(str(error))
        if item.requires_process_drain:
            snapshot = runner_snapshots.get(display(item.path))
            if snapshot is None:
                errors.append(f"Retirement audit lacks runner continuity snapshot: {item.path}")
            else:
                errors.extend(verify_recorded_runner_state(item, snapshot, table))
                try:
                    snapshot_state = state_from_runner_snapshot(item, snapshot)
                    errors.extend(
                        verify_runner_hashes(snapshot_state, root=snapshot_state.canonical_root)
                    )
                except CleanupError as error:
                    errors.append(str(error))
        quarantine = absolute(str(record.get("quarantine", "")))
        evidence = absolute(str(record.get("evidence", "")))
        if not quarantine.is_dir() or quarantine.is_symlink():
            errors.append(f"Local quarantine is missing/not real: {quarantine}")
            continue
        try:
            errors.extend(destructive_tree_blockers(quarantine))
        except OSError as error:
            errors.append(f"Could not re-inventory local quarantine {quarantine}: {error}")
        current = os.lstat(quarantine)
        if (current.st_dev, current.st_ino) != (record.get("device"), record.get("inode")):
            errors.append(f"Local quarantine device/inode changed: {quarantine}")
        try:
            refs = process_references(quarantine, table)
            if refs:
                errors.append(
                    f"Processes still reference local quarantine {quarantine}: "
                    + "; ".join(f"pid={value.pid} {value.kind} {value.path}" for value in refs[:20])
                )
        except CleanupError as error:
            errors.append(str(error))
        if not evidence.is_dir() or evidence.is_symlink():
            errors.append(f"Managed evidence is missing/not real: {evidence}")
        workspace_binding = workspace_bindings.get(display(item.path))
        if not mappings_for_root(plan, item) and workspace_binding is None:
            errors.append(f"Deletion root lacks its final workspace-root proof: {item.path}")
        if workspace_binding is not None:
            try:
                verify_workspace_root_binding(
                    workspace_binding,
                    managed_root,
                    merge_report_dir,
                    source_override=quarantine,
                    fsmonitor_stopped=True,
                    cleanup_roots=plan.roots,
                )
            except (CleanupError, OSError) as error:
                errors.append(str(error))
        for mapping in mappings_for_root(plan, item):
            binding = bindings.get(display(mapping.source))
            if binding is None:
                errors.append(f"Deletion source lacks final receipt: {mapping.source}")
                continue
            try:
                verify_representation_binding(
                    binding,
                    managed_root,
                    merge_report_dir,
                    source_override=quarantine_source_path(record, mapping),
                    fsmonitor_stopped=True,
                )
                verify_destination_binding(binding, gh_cache, fsck_cache)
            except (CleanupError, OSError) as error:
                errors.append(str(error))
    return final, sorted(set(errors))


def execute_deletion(
    plan: CleanupPlan,
    managed_root: Path,
    merge_report_dir: Path,
    report_dir: Path,
    transaction: str,
    recovery_transaction: str,
    final: dict[str, object],
) -> None:
    fresh_final, fresh_errors = deletion_preflight(
        plan,
        managed_root,
        merge_report_dir,
        report_dir,
        transaction,
        recovery_transaction,
    )
    if fresh_errors or fresh_final is None:
        raise CleanupError(
            "Permanent-deletion state changed after preflight: " + "; ".join(fresh_errors)
        )
    final = fresh_final
    marker, receipt_paths = load_success_marker(
        merge_report_dir, recovery_transaction, plan
    )
    bindings, receipt_errors = load_receipt_bindings(
        plan,
        merge_report_dir,
        managed_root,
        recovery_transaction,
        marker,
        receipt_paths,
    )
    if receipt_errors:
        raise CleanupError("Receipt bindings changed before deletion: " + "; ".join(receipt_errors))
    workspace_bindings, workspace_errors = load_workspace_root_bindings(
        plan,
        merge_report_dir,
        managed_root,
        recovery_transaction,
        marker,
    )
    if workspace_errors:
        raise CleanupError(
            "Workspace-root bindings changed before deletion: " + "; ".join(workspace_errors)
        )
    expected_volume = final["managedEvidenceVolume"]
    records = [dict(record) for record in final["roots"] if isinstance(record, dict)]
    record_by_source = {str(record["source"]): record for record in records}
    runner_snapshots = {
        str(snapshot.get("root")): snapshot
        for snapshot in final.get("runnerSnapshots", [])
        if isinstance(snapshot, dict) and isinstance(snapshot.get("root"), str)
    }
    deletion_journal = report_dir / "local-quarantine-deletion-journal.json"
    write_json(
        deletion_journal,
        {
            "format": 1,
            "status": "prechecked",
            "transaction": transaction,
            "recoveryTransaction": recovery_transaction,
            "sourceMapSHA256": plan.source_map_sha256,
            "githubAccountsSHA256": plan.github_accounts_sha256,
            "repositoryIdentitiesSHA256": plan.repository_identities_sha256,
            "workspaceRootProofKind": WORKSPACE_ROOT_PROOF_KIND,
            "workspaceRootProofSetSHA256": marker.get("workspaceRootProofSetSHA256"),
            "roots": records,
        },
    )
    _execute_local_quarantine_deletion_body(
        plan,
        managed_root,
        merge_report_dir,
        report_dir,
        transaction,
        recovery_transaction,
        final,
        marker,
        bindings,
        workspace_bindings,
        expected_volume,
        records,
        record_by_source,
        runner_snapshots,
        deletion_journal,
    )


def protected_representation_paths(
    bindings: TypingMapping[str, ReceiptBinding],
    workspace_bindings: TypingMapping[str, WorkspaceRootBinding],
) -> set[Path]:
    """Return every live path that final proof still uses as data evidence."""
    protected: set[Path] = set()
    for binding in bindings.values():
        proof = load_json(binding.representation_path, "representation proof")
        for row in representation_entries(proof, "representation proof").values():
            value = row.get("representationPath")
            if isinstance(value, str) and value:
                protected.add(absolute(value))
        components = proof.get("gitComponents", [])
        if isinstance(components, list):
            for row in components:
                if not isinstance(row, dict):
                    continue
                value = row.get("representationPath")
                if isinstance(value, str) and value:
                    protected.add(absolute(value))
    for binding in workspace_bindings.values():
        for row in binding.entries.values():
            value = row.get("representationPath")
            if isinstance(value, str) and value:
                protected.add(absolute(value))
        git_roots = binding.manifest.get("gitRoots", [])
        if not isinstance(git_roots, list):
            continue
        for git_root in git_roots:
            if not isinstance(git_root, dict):
                continue
            components = git_root.get("components", [])
            if not isinstance(components, list):
                continue
            for component in components:
                if not isinstance(component, dict):
                    continue
                value = component.get("representationPath")
                if isinstance(value, str) and value:
                    protected.add(absolute(value))
    return protected


def minimal_external_temp_targets(
    candidates: Sequence[tuple[Path, str]],
) -> list[tuple[Path, list[str]]]:
    grouped: dict[Path, set[str]] = {}
    for path, kind in candidates:
        grouped.setdefault(absolute(path), set()).add(kind)
    selected: list[tuple[Path, list[str]]] = []
    for path in sorted(grouped, key=lambda value: (len(value.parts), os.fsencode(display(value)))):
        parent = next((row for row in selected if within(path, row[0])), None)
        if parent is not None:
            parent[1].extend(sorted(grouped[path]))
            parent[1][:] = sorted(set(parent[1]))
            continue
        selected.append((path, sorted(grouped[path])))
    return selected


def external_temp_cleanup_preflight(
    plan: CleanupPlan,
    managed_root: Path,
    merge_report_dir: Path,
    report_dir: Path,
    transaction: str,
    recovery_transaction: str,
) -> tuple[dict[str, object], list[str], list[str]]:
    """Build an exact receipt-linked external-temp deletion allowlist."""
    errors = validate_roots(plan.roots, managed_root, source_required=False)
    warnings: list[str] = []
    payload: dict[str, object] = {
        "format": 1,
        "mode": "read-only-external-temp-cleanup-preflight",
        "transaction": transaction,
        "recoveryTransaction": recovery_transaction,
        "sourceMapSHA256": plan.source_map_sha256,
        "githubAccountsSHA256": plan.github_accounts_sha256,
        "repositoryIdentitiesSHA256": plan.repository_identities_sha256,
        "targets": [],
    }
    try:
        revalidate_plan_file(plan)
        ensure_exact_case_real_path(ACTIVE_CHECKOUT, Path("/"), "protected active checkout")
        validate_existing_managed_directory(
            merge_report_dir, managed_root, "recovery merge report directory"
        )
        validate_existing_managed_directory(
            report_dir, managed_root, "local cleanup report directory"
        )
        marker, receipt_paths = load_success_marker(
            merge_report_dir, recovery_transaction, plan
        )
        bindings, receipt_errors = load_receipt_bindings(
            plan,
            merge_report_dir,
            managed_root,
            recovery_transaction,
            marker,
            receipt_paths,
        )
        errors.extend(receipt_errors)
        workspace_bindings, workspace_errors = load_workspace_root_bindings(
            plan,
            merge_report_dir,
            managed_root,
            recovery_transaction,
            marker,
        )
        errors.extend(workspace_errors)
        final = load_completed_retirement(
            report_dir,
            transaction,
            recovery_transaction,
            plan,
            quarantine_deleted=True,
        )
    except (CleanupError, OSError) as error:
        errors.append(str(error))
        payload["blockers"] = sorted(set(errors))
        payload["warnings"] = warnings
        return payload, sorted(set(errors)), warnings

    expected_volume = final.get("managedEvidenceVolume")
    try:
        current_volume = volume_identity(managed_root / "_temp", require_external_fields=True)
        if not isinstance(expected_volume, dict) or not same_volume_identity(
            expected_volume, current_volume
        ):
            errors.append("Managed external volume differs from the completed local audit.")
    except CleanupError as error:
        current_volume = {}
        errors.append(str(error))
    payload["managedEvidenceVolume"] = current_volume
    if (
        final.get("workspaceRootProofSetSHA256") != marker.get("workspaceRootProofSetSHA256")
        or final.get("workspaceRootProofs") != marker.get("workspaceRootProofs")
    ):
        errors.append("Final local audit is not bound to the recovery workspace-proof set.")

    records = [dict(row) for row in final.get("roots", []) if isinstance(row, dict)]
    record_by_root = {str(row.get("source")): row for row in records}
    runner_rows = final.get("runnerSnapshots", [])
    runner_snapshots = {
        str(row.get("root")): row
        for row in runner_rows
        if isinstance(row, dict) and isinstance(row.get("root"), str)
    } if isinstance(runner_rows, list) else {}
    local_mapping_sources: dict[str, Path] = {}
    candidates: list[tuple[Path, str]] = []
    table: dict[int, ProcessInfo] = {}
    try:
        table = process_table()
    except CleanupError as error:
        errors.append(str(error))

    for item in plan.roots:
        record = record_by_root.get(display(item.path))
        if record is None:
            errors.append(f"Final local audit lacks cleanup root: {item.path}")
            continue
        evidence = absolute(str(record.get("evidence", "")))
        evidence_root = managed_root / "_temp" / "Local-Source-Evidence" / transaction
        try:
            if evidence == evidence_root or not within(evidence, evidence_root):
                raise CleanupError(f"Local evidence escapes exact cleanup transaction: {evidence}")
            ensure_exact_case_real_path(evidence, evidence_root, "receipt-bound local evidence")
            candidates.append((evidence, "local-source-evidence"))
            verify_compatibility_layout(item)
            workspace_binding = workspace_bindings.get(display(item.path))
            if not mappings_for_root(plan, item):
                if workspace_binding is None:
                    raise CleanupError(f"Final audit lacks workspace-root proof: {item.path}")
                verify_workspace_root_binding(
                    workspace_binding,
                    managed_root,
                    merge_report_dir,
                    source_override=evidence,
                    fsmonitor_stopped=True,
                    cleanup_roots=plan.roots,
                )
            for mapping in mappings_for_root(plan, item):
                local_mapping_sources[display(mapping.source)] = evidence_source_path(record, mapping)
            if item.requires_process_drain:
                snapshot = runner_snapshots.get(display(item.path))
                if snapshot is None:
                    raise CleanupError(f"Final audit lacks runner continuity snapshot: {item.path}")
                runner_errors = verify_recorded_runner_state(item, snapshot, table)
                state = state_from_runner_snapshot(item, snapshot)
                runner_errors.extend(verify_runner_hashes(state, root=state.canonical_root))
                if runner_errors:
                    raise CleanupError("Runner continuity changed: " + "; ".join(runner_errors))
        except (CleanupError, OSError) as error:
            errors.append(str(error))

    gh_cache: dict[str, dict[str, str]] = {}
    fsck_cache: dict[str, str] = {}
    for source_key, binding in bindings.items():
        try:
            source = local_mapping_sources.get(source_key)
            if source is None:
                source = receipt_bound_source_path(binding, managed_root)
                if source != binding.mapping.source:
                    candidates.append((source, "recovery-source-retirement"))
            verify_representation_binding(
                binding,
                managed_root,
                merge_report_dir,
                source_override=source,
                fsmonitor_stopped=True,
            )
            verify_destination_binding(binding, gh_cache, fsck_cache)
        except (CleanupError, OSError) as error:
            errors.append(str(error))

    recovery_temp = managed_root / "_temp" / "Repo-Consolidation" / recovery_transaction
    try:
        ensure_exact_case_real_path(recovery_temp, managed_root / "_temp", "recovery transaction temp")
        for child in sorted(recovery_temp.iterdir(), key=lambda value: os.fsencode(value.name)):
            if child.name in RECOVERY_TEMP_AUXILIARY_PAYLOADS:
                if child.is_symlink() or not child.is_dir():
                    errors.append(f"Recovery auxiliary payload is not a real directory: {child}")
                else:
                    candidates.append((child, f"recovery-{child.name}"))
            elif child.name != "source-retirement":
                warnings.append(f"Protected/unallowlisted recovery temp payload retained: {child}")
    except (CleanupError, OSError) as error:
        errors.append(str(error))

    proof_paths = protected_representation_paths(bindings, workspace_bindings)
    protected_roots = (
        managed_root / "Code" / "Repos",
        managed_root / "Runtime" / "Reports",
        managed_root / "Runtime" / "Receipts",
        managed_root / "Runtime" / "Archives",
        managed_root / "Archives",
        managed_root / "_temp" / "RepoConsolidation" / "RunnerDrain",
        managed_root / "_temp" / "RepoConsolidation" / "RunnerRestore",
        merge_report_dir,
        report_dir,
        ACTIVE_CHECKOUT,
    )
    target_rows: list[dict[str, object]] = []
    for target, kinds in minimal_external_temp_targets(candidates):
        try:
            if target == managed_root / "_temp" or not within(target, managed_root / "_temp"):
                raise CleanupError(f"External cleanup target escapes managed _temp: {target}")
            if any(
                target == protected
                or within(target, protected)
                or within(protected, target)
                for protected in protected_roots
            ):
                raise CleanupError(f"External cleanup target overlaps a protected root: {target}")
            represented = [path for path in proof_paths if path == target or within(path, target)]
            if represented:
                raise CleanupError(
                    f"External cleanup target still contains live representation evidence: {target}: "
                    + ", ".join(display(path) for path in sorted(represented, key=lambda p: os.fsencode(display(p)))[:10])
                )
            ensure_exact_case_real_path(target, managed_root / "_temp", "external temp cleanup target")
            blockers = destructive_tree_blockers(target)
            if blockers:
                raise CleanupError(
                    f"External temp target contains unsafe mount/special entries: {target}: "
                    + "; ".join(blockers[:20])
                )
            if table:
                references = process_references(target, table)
                if references:
                    raise CleanupError(
                        f"Processes reference external temp target {target}: "
                        + "; ".join(
                            f"pid={row.pid} {row.kind} {row.path}" for row in references[:20]
                        )
                    )
            identity = os.lstat(target)
            target_rows.append(
                {
                    "path": display(target),
                    "kinds": kinds,
                    "device": identity.st_dev,
                    "inode": identity.st_ino,
                }
            )
        except (CleanupError, OSError) as error:
            errors.append(str(error))
    if not target_rows:
        errors.append("No exact receipt-linked external temp payload is eligible for deletion.")
    payload.update(
        {
            "recoverySuccessMarkerSHA256": sha256_file(merge_report_dir / SUCCESS_MARKER),
            "localFinalAuditSHA256": sha256_file(report_dir / "final-audit.json"),
            "receiptBindingCount": len(bindings),
            "workspaceRootProofCount": len(workspace_bindings),
            "targetCount": len(target_rows),
            "targets": target_rows,
            "blockers": sorted(set(errors)),
            "warnings": sorted(set(warnings)),
        }
    )
    return payload, sorted(set(errors)), sorted(set(warnings))


def prune_empty_external_temp_parents(path: Path, managed_root: Path) -> None:
    stop_roots = {
        managed_root / "_temp",
        managed_root / "_temp" / "Repo-Consolidation",
        managed_root / "_temp" / "Local-Source-Evidence",
    }
    current = path.parent
    while within(current, managed_root / "_temp") and current not in stop_roots:
        try:
            guarded_rmdir(current)
            fsync_directory(current.parent)
        except OSError:
            break
        current = current.parent


def execute_external_temp_cleanup(
    plan: CleanupPlan,
    managed_root: Path,
    merge_report_dir: Path,
    report_dir: Path,
    transaction: str,
    recovery_transaction: str,
) -> Path:
    payload, errors, _warnings = external_temp_cleanup_preflight(
        plan,
        managed_root,
        merge_report_dir,
        report_dir,
        transaction,
        recovery_transaction,
    )
    if errors:
        raise CleanupError("External temp cleanup state changed: " + "; ".join(errors))
    journal_path = report_dir / "external-temp-cleanup-journal.json"
    final_path = report_dir / "external-temp-cleanup-final.json"
    if os.path.lexists(journal_path) or os.path.lexists(final_path):
        raise CleanupError("External temp cleanup receipt already exists; refusing ambiguous resume.")
    rows = [dict(row) for row in payload["targets"] if isinstance(row, dict)]
    write_json(journal_path, {**payload, "status": "prechecked"})
    expected_volume = payload.get("managedEvidenceVolume")
    deleted: list[dict[str, object]] = []
    for row in rows:
        target = absolute(str(row["path"]))
        revalidate_plan_file(plan)
        current_volume = volume_identity(managed_root / "_temp", require_external_fields=True)
        if not isinstance(expected_volume, dict) or not same_volume_identity(
            expected_volume, current_volume
        ):
            raise CleanupError(f"Managed external volume changed before deletion: {target}")
        ensure_exact_case_real_path(target, managed_root / "_temp", "external temp cleanup target")
        identity = os.lstat(target)
        if (identity.st_dev, identity.st_ino) != (row.get("device"), row.get("inode")):
            raise CleanupError(f"External temp target identity changed before deletion: {target}")
        blockers = destructive_tree_blockers(target)
        if blockers:
            raise CleanupError(f"External temp target became unsafe before deletion: {target}")
        references = process_references(target, process_table())
        if references:
            raise CleanupError(f"Process references appeared before external temp deletion: {target}")
        guarded_rmtree(target)
        fsync_directory(target.parent)
        deleted_row = {**row, "status": "deleted"}
        deleted.append(deleted_row)
        write_json(
            journal_path,
            {**payload, "status": "deletion-progress", "deleted": deleted},
        )
        prune_empty_external_temp_parents(target, managed_root)
    final_payload = {
        **payload,
        "status": "complete-receipt-linked-external-temp-deleted",
        "deleted": deleted,
        "deletedCount": len(deleted),
        "protectedEvidenceRetained": True,
    }
    write_json(final_path, final_payload)
    write_json(journal_path, {**final_payload, "status": "complete"})
    return final_path


def _execute_local_quarantine_deletion_body(
    plan: CleanupPlan,
    managed_root: Path,
    merge_report_dir: Path,
    report_dir: Path,
    transaction: str,
    recovery_transaction: str,
    final: dict[str, object],
    marker: dict[str, object],
    bindings: TypingMapping[str, ReceiptBinding],
    workspace_bindings: TypingMapping[str, WorkspaceRootBinding],
    expected_volume: dict[str, object],
    records: list[dict[str, object]],
    record_by_source: TypingMapping[str, dict[str, object]],
    runner_snapshots: TypingMapping[str, dict[str, object]],
    deletion_journal: Path,
) -> None:
    for item in plan.roots:
        record = record_by_source[display(item.path)]
        quarantine = absolute(str(record["quarantine"]))
        evidence = absolute(str(record["evidence"]))
        current_volume = volume_identity(managed_root / "_temp", require_external_fields=True)
        if not same_volume_identity(expected_volume, current_volume):
            raise CleanupError(f"Managed evidence volume changed immediately before deletion: {quarantine}")
        revalidate_plan_file(plan)
        blockers = destructive_tree_blockers(quarantine)
        if blockers:
            raise CleanupError(
                f"Local quarantine gained unsafe mount/special entries before deletion: {quarantine}: "
                + "; ".join(blockers[:20])
            )
        fsync_tree(evidence)
        helper = Path(__file__).with_name("repo-consolidation-recovery.py")
        core = runpy.run_path(display(helper), run_name="repo_consolidation_recovery_delete_core")
        verify_snapshot = core.get("verify_exact_path_snapshot")
        if not callable(verify_snapshot):
            raise CleanupError("Recovery helper does not expose exact snapshot verification.")
        if verify_snapshot(quarantine, evidence) != record.get("evidenceDigest"):
            raise CleanupError(f"Managed evidence rehash changed immediately before deletion: {quarantine}")
        workspace_binding = workspace_bindings.get(display(item.path))
        if not mappings_for_root(plan, item) and workspace_binding is None:
            raise CleanupError(f"Deletion root lost its workspace-root proof: {item.path}")
        if workspace_binding is not None:
            fsync_regular_file(workspace_binding.proof_path)
            fsync_regular_file(workspace_binding.manifest_path)
            fsync_directory(workspace_binding.proof_path.parent)
            fsync_directory(workspace_binding.manifest_path.parent)
            verify_workspace_root_binding(
                workspace_binding,
                managed_root,
                merge_report_dir,
                source_override=quarantine,
                fsmonitor_stopped=True,
                cleanup_roots=plan.roots,
            )

        gh_cache: dict[str, dict[str, str]] = {}
        fsck_cache: dict[str, str] = {}
        for mapping in mappings_for_root(plan, item):
            binding = bindings[display(mapping.source)]
            verify_representation_binding(
                binding,
                managed_root,
                merge_report_dir,
                source_override=quarantine_source_path(record, mapping),
                fsmonitor_stopped=True,
            )
            verify_destination_binding(binding, gh_cache, fsck_cache)
        verify_compatibility_layout(item)
        if item.requires_process_drain:
            snapshot = runner_snapshots.get(display(item.path))
            if snapshot is None:
                raise CleanupError(f"Runner continuity snapshot disappeared before deletion: {item.path}")
            runner_errors = verify_recorded_runner_state(item, snapshot, process_table())
            try:
                snapshot_state = state_from_runner_snapshot(item, snapshot)
                runner_errors.extend(
                    verify_runner_hashes(snapshot_state, root=snapshot_state.canonical_root)
                )
            except CleanupError as error:
                runner_errors.append(str(error))
            if runner_errors:
                raise CleanupError(
                    f"Runner state changed immediately before deletion of {quarantine}: "
                    + "; ".join(runner_errors)
                )
        references = process_references(quarantine, process_table())
        if references:
            raise CleanupError(f"Process references appeared immediately before deletion: {quarantine}")
        quarantine_root = user_home_boundary() / ".csa-iem-quarantine" / transaction
        if not within(quarantine, quarantine_root) or quarantine == quarantine_root:
            raise CleanupError(f"Refused to delete outside exact local transaction quarantine: {quarantine}")
        current = os.lstat(quarantine)
        if (current.st_dev, current.st_ino) != (record["device"], record["inode"]):
            raise CleanupError(f"Quarantine identity changed immediately before deletion: {quarantine}")
        # Close the verification-to-delete window with a second evidence
        # rehash/fsync and a final live volume identity check. No receipt or
        # earlier mount observation alone can authorize this rmtree.
        fsync_tree(evidence)
        if verify_snapshot(quarantine, evidence) != record.get("evidenceDigest"):
            raise CleanupError(f"Managed evidence changed at the deletion boundary: {quarantine}")
        final_references = process_references(quarantine, process_table())
        if final_references:
            raise CleanupError(
                f"Process references appeared at the deletion boundary: {quarantine}"
            )
        final_identity = os.lstat(quarantine)
        if (final_identity.st_dev, final_identity.st_ino) != (record["device"], record["inode"]):
            raise CleanupError(f"Quarantine identity changed at the deletion boundary: {quarantine}")
        final_volume = volume_identity(managed_root / "_temp", require_external_fields=True)
        if not same_volume_identity(expected_volume, final_volume):
            raise CleanupError(
                f"Managed evidence volume changed at the deletion boundary: {quarantine}"
            )
        if workspace_binding is not None:
            verify_workspace_root_binding(
                workspace_binding,
                managed_root,
                merge_report_dir,
                source_override=quarantine,
                fsmonitor_stopped=True,
                cleanup_roots=plan.roots,
            )
        closing_references = process_references(quarantine, process_table())
        if closing_references:
            raise CleanupError(
                f"Process references appeared after final representation verification: {quarantine}"
            )
        closing_identity = os.lstat(quarantine)
        if (closing_identity.st_dev, closing_identity.st_ino) != (
            record["device"],
            record["inode"],
        ):
            raise CleanupError(
                f"Quarantine identity changed after final representation verification: {quarantine}"
            )
        closing_volume = volume_identity(managed_root / "_temp", require_external_fields=True)
        if not same_volume_identity(expected_volume, closing_volume):
            raise CleanupError(
                f"Managed evidence volume changed after final representation verification: {quarantine}"
            )
        guarded_rmtree(quarantine)
        fsync_directory(quarantine.parent)
        record["status"] = "local-quarantine-deleted-evidence-retained"
        write_json(
            deletion_journal,
            {
                "format": 1,
                "status": "deletion-progress",
                "transaction": transaction,
                "recoveryTransaction": recovery_transaction,
                "sourceMapSHA256": plan.source_map_sha256,
                "githubAccountsSHA256": plan.github_accounts_sha256,
                "repositoryIdentitiesSHA256": plan.repository_identities_sha256,
                "workspaceRootProofKind": WORKSPACE_ROOT_PROOF_KIND,
                "workspaceRootProofSetSHA256": marker.get("workspaceRootProofSetSHA256"),
                "roots": records,
            },
        )

    quarantine_root = user_home_boundary() / ".csa-iem-quarantine" / transaction
    try:
        guarded_rmdir(quarantine_root)
        fsync_directory(quarantine_root.parent)
    except OSError:
        pass
    final["status"] = "complete-quarantine-deleted-evidence-retained"
    final["localQuarantineDeleted"] = True
    final["roots"] = records
    write_json(report_dir / "final-audit.json", final)
    write_json(
        deletion_journal,
        {
            "format": 1,
            "status": "complete",
            "transaction": transaction,
            "recoveryTransaction": recovery_transaction,
            "sourceMapSHA256": plan.source_map_sha256,
            "githubAccountsSHA256": plan.github_accounts_sha256,
            "repositoryIdentitiesSHA256": plan.repository_identities_sha256,
            "workspaceRootProofKind": WORKSPACE_ROOT_PROOF_KIND,
            "workspaceRootProofSetSHA256": marker.get("workspaceRootProofSetSHA256"),
            "roots": records,
        },
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Retire only transaction-bound, freshly verified local project roots."
    )
    parser.add_argument("--mapping-file", type=Path, required=True)
    parser.add_argument("--merge-report-dir", type=Path, required=True)
    parser.add_argument("--managed-root", type=Path, required=True)
    parser.add_argument("--transaction-id", required=True, help="New local cleanup transaction ID")
    parser.add_argument(
        "--recovery-transaction-id",
        required=True,
        help="Exact completed recovery transaction consumed by this cleanup",
    )
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--preflight-only", action="store_true")
    modes.add_argument("--preflight-runner-drain", action="store_true")
    modes.add_argument("--drain-runners-before-merge", action="store_true")
    modes.add_argument("--preflight-runner-restore", action="store_true")
    modes.add_argument("--restore-runners-after-merge", action="store_true")
    modes.add_argument("--abort-runner-drain", action="store_true")
    modes.add_argument("--apply", action="store_true")
    modes.add_argument("--preflight-delete", action="store_true")
    modes.add_argument("--delete-local-quarantine", action="store_true")
    modes.add_argument("--preflight-external-temp-cleanup", action="store_true")
    modes.add_argument("--delete-external-temp", action="store_true")
    parser.add_argument("--confirm-token", default="")
    parser.add_argument("--delete-token", default="")
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
    return parser


def emit_preflight(payload: dict[str, object]) -> None:
    blockers = payload.get("blockers", [])
    print(
        f"PREFLIGHT | roots={payload.get('rootCount', 0)} "
        f"receipts={payload.get('receiptBindingCount', 0)} blockers={len(blockers)}",
        flush=True,
    )
    print(json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False), flush=True)


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    protected_checkouts = [absolute(path) for path in args.protected_checkout]
    for implicit in (ACTIVE_CHECKOUT, LAUNCH_CWD):
        if (implicit / ".git").exists() and implicit not in protected_checkouts:
            protected_checkouts.append(implicit)
    configure_protected_mutation_roots(protected_checkouts)
    validate_transaction_id(args.transaction_id, "--transaction-id")
    validate_transaction_id(args.recovery_transaction_id, "--recovery-transaction-id")
    managed_root = absolute(args.managed_root)
    merge_report_dir = absolute(args.merge_report_dir)
    plan = load_plan(absolute(args.mapping_file), managed_root / "Code" / "Repos")
    report_dir = (
        managed_root
        / "Runtime"
        / "Reports"
        / "RepoConsolidation"
        / "LocalCleanup"
        / args.transaction_id
    )

    if args.preflight_runner_drain or args.drain_runners_before_merge:
        states, volume, errors, warnings = build_runner_drain_preflight(
            plan,
            managed_root,
            args.transaction_id,
            args.recovery_transaction_id,
        )
        payload = {
            "format": 1,
            "mode": "read-only-pre-merge-runner-drain-preflight",
            "transaction": args.transaction_id,
            "recoveryTransaction": args.recovery_transaction_id,
            "sourceMapSHA256": plan.source_map_sha256,
            "githubAccountsSHA256": plan.github_accounts_sha256,
            "repositoryIdentitiesSHA256": plan.repository_identities_sha256,
            "rootCount": len(states),
            "receiptBindingCount": 0,
            "managedEvidenceVolume": volume,
            "runnerDrainReceipt": display(
                runner_drain_receipt_path(managed_root, args.transaction_id)
            ),
            "roots": [runner_state_snapshot(state) for state in states],
            "blockers": errors,
            "warnings": warnings,
        }
        emit_preflight(payload)
        if errors:
            return 2
        if args.preflight_runner_drain:
            return 0
        if args.confirm_token != RUNNER_DRAIN_TOKEN:
            raise CleanupError(
                f"Pre-merge runner drain requires --confirm-token {RUNNER_DRAIN_TOKEN}"
            )
        if args.delete_token:
            raise CleanupError("--delete-token is not accepted for runner drain.")
        receipt, receipt_sha = execute_runner_drain(
            plan,
            managed_root,
            args.transaction_id,
            args.recovery_transaction_id,
            states,
            volume,
        )
        print(
            f"RUNNER DRAINED | receipt={receipt} | sha256={receipt_sha} | "
            "bind both transaction and digest in the recovery success marker",
            flush=True,
        )
        return 0

    if args.preflight_runner_restore or args.restore_runners_after_merge:
        states, marker, drain_sha, errors, warnings = build_runner_restore_preflight(
            plan,
            managed_root,
            merge_report_dir,
            args.transaction_id,
            args.recovery_transaction_id,
        )
        payload = {
            "format": 1,
            "mode": "read-only-post-verification-runner-restore-preflight",
            "transaction": args.transaction_id,
            "recoveryTransaction": args.recovery_transaction_id,
            "sourceMapSHA256": plan.source_map_sha256,
            "rootCount": len(states),
            "receiptBindingCount": marker.get("receiptCount", 0),
            "runnerDrainReceiptSHA256": drain_sha,
            "roots": [runner_state_snapshot(state) for state in states],
            "blockers": errors,
            "warnings": warnings,
        }
        emit_preflight(payload)
        if errors:
            return 2
        if args.preflight_runner_restore:
            return 0
        if args.confirm_token != RUNNER_RESTORE_TOKEN:
            raise CleanupError(
                f"Canonical runner restore requires --confirm-token {RUNNER_RESTORE_TOKEN}"
            )
        if args.delete_token:
            raise CleanupError("--delete-token is not accepted for runner restore.")
        restore_receipt = execute_runner_restore(
            plan,
            managed_root,
            merge_report_dir,
            args.transaction_id,
            args.recovery_transaction_id,
            states,
            marker,
            drain_sha,
        )
        print(f"RUNNER RESTORED FROM CANONICAL | receipt={restore_receipt}", flush=True)
        return 0

    if args.abort_runner_drain:
        _receipt, states, drain_sha, errors = load_runner_drain_receipt(
            plan,
            managed_root,
            args.transaction_id,
            args.recovery_transaction_id,
        )
        if os.path.lexists(merge_report_dir / SUCCESS_MARKER):
            errors.append(
                "Recovery success marker exists; abort is blocked in favor of verified canonical restore."
            )
        payload = {
            "format": 1,
            "mode": "runner-drain-abort-preflight",
            "transaction": args.transaction_id,
            "recoveryTransaction": args.recovery_transaction_id,
            "sourceMapSHA256": plan.source_map_sha256,
            "rootCount": len(states),
            "receiptBindingCount": 0,
            "runnerDrainReceiptSHA256": drain_sha,
            "blockers": sorted(set(errors)),
            "warnings": [],
        }
        emit_preflight(payload)
        if errors:
            return 2
        if args.confirm_token != RUNNER_ABORT_TOKEN:
            raise CleanupError(
                f"Runner drain abort requires --confirm-token {RUNNER_ABORT_TOKEN}"
            )
        if args.delete_token:
            raise CleanupError("--delete-token is not accepted for runner drain abort.")
        abort_receipt = execute_runner_abort(
            plan,
            managed_root,
            merge_report_dir,
            args.transaction_id,
            args.recovery_transaction_id,
            states,
            drain_sha,
        )
        print(f"RUNNER DRAIN ABORTED | source state restored | receipt={abort_receipt}", flush=True)
        return 0

    if args.preflight_external_temp_cleanup or args.delete_external_temp:
        payload, errors, _warnings = external_temp_cleanup_preflight(
            plan,
            managed_root,
            merge_report_dir,
            report_dir,
            args.transaction_id,
            args.recovery_transaction_id,
        )
        emit_preflight(payload)
        if errors:
            return 2
        if args.preflight_external_temp_cleanup:
            return 0
        if args.delete_token != EXTERNAL_TEMP_DELETE_TOKEN:
            raise CleanupError(
                f"External temp deletion requires --delete-token {EXTERNAL_TEMP_DELETE_TOKEN}"
            )
        if args.confirm_token:
            raise CleanupError("--confirm-token is not accepted for external temp deletion.")
        final_path = execute_external_temp_cleanup(
            plan,
            managed_root,
            merge_report_dir,
            report_dir,
            args.transaction_id,
            args.recovery_transaction_id,
        )
        print(f"FINAL | receipt-linked external temp payloads deleted | {final_path}")
        return 0

    if args.preflight_delete or args.delete_local_quarantine:
        final, errors = deletion_preflight(
            plan,
            managed_root,
            merge_report_dir,
            report_dir,
            args.transaction_id,
            args.recovery_transaction_id,
        )
        payload = {
            "format": 2,
            "mode": "read-only-deletion-preflight",
            "rootCount": len(plan.roots),
            "receiptBindingCount": 0,
            "transaction": args.transaction_id,
            "recoveryTransaction": args.recovery_transaction_id,
            "sourceMapSHA256": plan.source_map_sha256,
            "githubAccountsSHA256": plan.github_accounts_sha256,
            "repositoryIdentitiesSHA256": plan.repository_identities_sha256,
            "blockers": errors,
            "warnings": [],
        }
        emit_preflight(payload)
        if errors:
            return 2
        if args.preflight_delete:
            return 0
        if args.delete_token != DELETE_TOKEN:
            raise CleanupError(f"Permanent deletion requires --delete-token {DELETE_TOKEN}")
        if args.confirm_token:
            raise CleanupError("--confirm-token is not accepted in the separate permanent-deletion phase.")
        assert final is not None
        execute_deletion(
            plan,
            managed_root,
            merge_report_dir,
            report_dir,
            args.transaction_id,
            args.recovery_transaction_id,
            final,
        )
        print(f"FINAL | local quarantine deleted; managed evidence retained | {report_dir / 'final-audit.json'}")
        return 0

    result = build_preflight(
        plan,
        managed_root,
        merge_report_dir,
        args.recovery_transaction_id,
    )
    payload = preflight_payload(result)
    emit_preflight(payload)
    if result.errors:
        return 2
    if not args.apply:
        return 0
    if args.confirm_token != APPLY_TOKEN:
        raise CleanupError(f"Apply requires --confirm-token {APPLY_TOKEN}")
    if args.delete_token:
        raise CleanupError("--delete-token is not accepted during reversible retirement.")
    execute_retirement(
        result,
        managed_root,
        merge_report_dir,
        report_dir,
        args.transaction_id,
    )
    print(f"FINAL | roots={len(result.roots)} | quarantine retained | {report_dir / 'final.md'}", flush=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (CleanupError, OSError, subprocess.TimeoutExpired) as error:
        print(f"ERROR | {error}", file=sys.stderr)
        raise SystemExit(2)

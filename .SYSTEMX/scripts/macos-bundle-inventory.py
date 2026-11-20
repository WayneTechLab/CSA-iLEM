#!/usr/bin/env python3
"""Read-only SHA-256 inventory of every file and directory in a macOS app.

The digest includes relative paths, entry types, permission bits, file sizes,
and full file-content hashes. Symlinks, special files, unreadable entries, and
files that change during reading fail closed. Record the digest from a
separately reviewed build before using the public release packaging script.
"""

import argparse
import hashlib
import json
import os
import stat
import sys
from pathlib import Path


def inventory(root):
    if not root.is_dir() or root.is_symlink():
        raise ValueError("App must be a real directory, not a symlink")

    entries = []

    def traversal_error(error):
        raise error

    for base, directories, files in os.walk(root, followlinks=False, onerror=traversal_error):
        directories.sort(key=os.fsencode)
        files.sort(key=os.fsencode)
        for name in directories + files:
            path = Path(base) / name
            before = path.lstat()
            mode = before.st_mode
            if stat.S_ISLNK(mode):
                raise ValueError("Symlink in app bundle: " + str(path))
            if stat.S_ISDIR(mode):
                entry_type = "D"
                size = 0
                file_hash = ""
            elif stat.S_ISREG(mode):
                entry_type = "F"
                digest = hashlib.sha256()
                flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
                with os.fdopen(os.open(path, flags), "rb") as handle:
                    opened = os.fstat(handle.fileno())
                    if not stat.S_ISREG(opened.st_mode) or opened.st_ino != before.st_ino:
                        raise ValueError("File changed during inventory: " + str(path))
                    while True:
                        chunk = handle.read(1024 * 1024)
                        if not chunk:
                            break
                        digest.update(chunk)
                    after = os.fstat(handle.fileno())
                if (opened.st_size, opened.st_mtime_ns, opened.st_mode) != (
                    after.st_size, after.st_mtime_ns, after.st_mode
                ):
                    raise ValueError("File changed during inventory: " + str(path))
                size = after.st_size
                file_hash = digest.hexdigest()
            else:
                raise ValueError("Special file in app bundle: " + str(path))

            relative = path.relative_to(root).as_posix()
            entries.append((relative, entry_type, stat.S_IMODE(mode), size, file_hash))

    entries.sort(key=lambda entry: os.fsencode(entry[0]))
    digest = hashlib.sha256(b"CSA-IEM-BUNDLE-INVENTORY-v1\0")
    for relative, entry_type, mode, size, file_hash in entries:
        for field in (entry_type.encode(), os.fsencode(relative), str(mode).encode(),
                      str(size).encode(), file_hash.encode()):
            digest.update(len(field).to_bytes(8, "big"))
            digest.update(field)
    return entries, digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path, help="Existing .app bundle to inspect")
    parser.add_argument("--list", action="store_true", help="Print per-entry JSON before the digest")
    args = parser.parse_args()
    try:
        entries, digest = inventory(args.app)
    except (OSError, ValueError) as error:
        print("BLOCKED: bundle inventory failed: " + str(error), file=sys.stderr)
        return 1
    if args.list:
        for relative, entry_type, mode, size, file_hash in entries:
            print(json.dumps({"path": relative, "type": entry_type, "mode": oct(mode),
                              "size": size, "sha256": file_hash}, sort_keys=True))
        print("BUNDLE_INVENTORY_SHA256=" + digest)
    else:
        print(digest)
    return 0


if __name__ == "__main__":
    sys.exit(main())

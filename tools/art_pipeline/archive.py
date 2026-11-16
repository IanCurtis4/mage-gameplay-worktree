"""Hash-checked archive of staged art plus a versioned index (contract C5).

Copies batches from a staging art folder to the durable archive that lives outside Git, checks
every copy by SHA256 and writes an index that is small enough to commit: relative path, SHA256,
size, `selected` flag and where the copy sits in the archive.

Safety rules, enforced in code and covered by tests:
  * the source is only ever opened for reading, never deleted, moved or touched;
  * an archived file is never overwritten: identical bytes are "already_archived", different
    bytes are "refused_overwrite" and reported (exit code 1);
  * a copy is verified by hash right after writing; a failed copy is removed (it was ours);
  * the index never changes the SHA256 of a path it already lists (reported as a conflict).

    python tools/art_pipeline/archive.py copy --source <repo>/.tools/.../assets/art \
        --archive <repo>/.tools/art_archive/e08 --batch e08_codex_1120 --batch e08_codex_1121 \
        --index docs/art/archive/e08_staging_1119_1124.json [--dry-run]
    python tools/art_pipeline/archive.py verify --archive <...>/art_archive/e08 --index <index.json>
"""
from __future__ import annotations

import argparse
import fnmatch
import os
import shutil
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "art_pipeline"

from .common import PipelineError, emit_json, load_json, posix, sha256_file, today, write_json_atomic  # noqa: E402
from .provenance import load_provenance  # noqa: E402

INDEX_SCHEMA = "ragrpg_art_archive_index_v1"
DEFAULT_EXCLUDE = ("*.import", "*.uid", "*.tmp", "*.part", "Thumbs.db", ".DS_Store")


def collect_files(source_root, batches, include=("*",), exclude=DEFAULT_EXCLUDE):
    """Sorted POSIX paths (relative to source_root) of the files under the given batch folders."""
    source_root = Path(source_root)
    found = []
    for batch in batches:
        folder = source_root / batch
        if not folder.is_dir():
            raise PipelineError("batch folder not found: %s" % folder)
        for path in sorted(folder.rglob("*")):
            if not path.is_file():
                continue
            name = path.name
            if any(fnmatch.fnmatch(name, pattern) for pattern in exclude):
                continue
            if not any(fnmatch.fnmatch(name, pattern) for pattern in include):
                continue
            found.append(posix(path.relative_to(source_root)))
    return found


class _SelectedLookup:
    """`selected` flag of a file from the provenance.json found at or above its folder."""

    def __init__(self, source_root):
        self.source_root = Path(source_root).resolve()
        self.cache = {}

    def _table(self, folder):
        if folder not in self.cache:
            table = {}
            candidate = folder / "provenance.json"
            if candidate.is_file():
                try:
                    for record in load_provenance(candidate).records:
                        previous = table.get(record["sha256"])
                        if previous is not True:
                            table[record["sha256"]] = record["selected"]
                except (PipelineError, ValueError, KeyError):
                    table = {}
            self.cache[folder] = table
        return self.cache[folder]

    def lookup(self, relative, sha256):
        folder = (self.source_root / relative).parent
        while True:
            table = self._table(folder)
            if sha256 in table:
                return table[sha256]
            if folder == self.source_root or self.source_root not in folder.parents:
                return None
            folder = folder.parent


def _copy_exclusive(source, destination, expected_sha):
    """Create `destination` (must not exist) with the bytes of `source`; verify; return the size."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    with open(source, "rb") as reader:
        with open(destination, "xb") as writer:  # 'x' refuses an existing file: no overwrite, ever
            shutil.copyfileobj(reader, writer, 1 << 20)
    try:
        if sha256_file(destination) != expected_sha:
            raise PipelineError("copy of %s did not match its SHA256" % source)
        shutil.copystat(source, destination)
    except BaseException:
        if destination.exists():
            os.remove(destination)  # a file this call just created
        raise
    return destination.stat().st_size


def archive_batches(source_root, archive_root, batches, index_path=None, dry_run=False,
                    include=("*",), exclude=DEFAULT_EXCLUDE, source_label=None, archive_label=None):
    """Copy the batches and update the index. Returns a report dict (see keys below)."""
    source_root, archive_root = Path(source_root), Path(archive_root)
    if not source_root.is_dir():
        raise PipelineError("source root not found: %s" % source_root)
    if source_root.resolve() == archive_root.resolve() or source_root.resolve() in archive_root.resolve().parents:
        raise PipelineError("the archive must live outside the source folder")
    relatives = collect_files(source_root, batches, include, exclude)
    selected_lookup = _SelectedLookup(source_root)
    report = {"files": len(relatives), "copied": 0, "already_archived": 0, "refused_overwrite": [], "errors": [],
              "bytes_copied": 0, "dry_run": dry_run, "index_conflicts": []}
    entries = {}
    for relative in relatives:
        source = source_root / relative
        destination = archive_root / relative
        try:
            digest = sha256_file(source)
            size = source.stat().st_size
            if destination.exists():
                if sha256_file(destination) == digest:
                    report["already_archived"] += 1
                else:
                    report["refused_overwrite"].append({"path": relative, "source_sha256": digest,
                                                        "archived_sha256": sha256_file(destination)})
                    continue
            elif dry_run:
                report["copied"] += 1
                report["bytes_copied"] += size
            else:
                report["bytes_copied"] += _copy_exclusive(source, destination, digest)
                report["copied"] += 1
                if sha256_file(source) != digest:
                    raise PipelineError("the source changed while it was being copied: %s" % relative)
            entries[relative] = {
                "path": relative, "sha256": digest, "size": size,
                "type": "png" if relative.lower().endswith(".png") else "metadata",
                "selected": selected_lookup.lookup(relative, digest),
                "archived_path": relative,
            }
        except (PipelineError, OSError) as error:
            report["errors"].append({"path": relative, "error": str(error)})
    if index_path and not dry_run:
        report["index_conflicts"] = _write_index(Path(index_path), entries, source_label, archive_label, batches)
    report["entries_indexed"] = len(entries)
    report["ok"] = not (report["refused_overwrite"] or report["errors"] or report["index_conflicts"])
    return report


def _write_index(index_path, new_entries, source_label, archive_label, batches):
    if index_path.exists():
        document = load_json(index_path)
        if document.get("schema") != INDEX_SCHEMA:
            raise PipelineError("%s is not an %s file" % (index_path, INDEX_SCHEMA))
    else:
        document = {"schema": INDEX_SCHEMA, "created": today(), "entries": []}
    merged = {entry["path"]: entry for entry in document["entries"]}
    conflicts = []
    for path, entry in new_entries.items():
        old = merged.get(path)
        if old is not None and old["sha256"] != entry["sha256"]:
            conflicts.append({"path": path, "indexed_sha256": old["sha256"], "source_sha256": entry["sha256"]})
            continue
        merged[path] = entry
    document["updated"] = today()
    if source_label:
        document["source_root_hint"] = source_label
    if archive_label:
        document["archive_root_hint"] = archive_label
    document["batches"] = sorted(set(document.get("batches", [])) | set(batches))
    document["entries"] = [merged[key] for key in sorted(merged)]
    document["totals"] = {
        "entries": len(document["entries"]),
        "png": sum(1 for e in document["entries"] if e["type"] == "png"),
        "selected": sum(1 for e in document["entries"] if e["selected"] is True),
        "bytes": sum(e["size"] for e in document["entries"]),
    }
    write_json_atomic(index_path, document)
    return conflicts


def verify_archive(archive_root, index_path, source_root=None):
    """Re-hash every archived file listed in the index (and the source when given). Read-only."""
    document = load_json(index_path)
    if document.get("schema") != INDEX_SCHEMA:
        raise PipelineError("%s is not an %s file" % (index_path, INDEX_SCHEMA))
    problems = []
    for entry in document["entries"]:
        copy = Path(archive_root) / entry["archived_path"]
        if not copy.is_file():
            problems.append({"path": entry["path"], "problem": "missing_in_archive"})
        elif sha256_file(copy) != entry["sha256"]:
            problems.append({"path": entry["path"], "problem": "archive_sha256_mismatch"})
        if source_root is not None:
            origin = Path(source_root) / entry["path"]
            if not origin.is_file():
                problems.append({"path": entry["path"], "problem": "missing_in_source"})
            elif sha256_file(origin) != entry["sha256"]:
                problems.append({"path": entry["path"], "problem": "source_sha256_mismatch"})
    return {"checked": len(document["entries"]), "problems": problems, "ok": not problems}


def main(argv=None):
    parser = argparse.ArgumentParser(description="Archive staged art with hash checks and a versioned index.")
    sub = parser.add_subparsers(dest="command", required=True)
    copy = sub.add_parser("copy")
    copy.add_argument("--source", required=True, help="staging art folder (the one that holds e08_codex_*/)")
    copy.add_argument("--archive", required=True, help="durable archive folder, outside Git")
    copy.add_argument("--batch", action="append", required=True, help="batch folder name; repeat for several")
    copy.add_argument("--index", help="versioned index JSON to create or merge into")
    copy.add_argument("--include", action="append", help="file name pattern to include (default: everything)")
    copy.add_argument("--exclude", action="append", help="extra file name pattern to skip")
    copy.add_argument("--source-label", help="text stored as source_root_hint (default: the source path)")
    copy.add_argument("--archive-label", help="text stored as archive_root_hint (default: the archive path)")
    copy.add_argument("--dry-run", action="store_true")
    verify = sub.add_parser("verify")
    verify.add_argument("--archive", required=True)
    verify.add_argument("--index", required=True)
    verify.add_argument("--source", help="also compare the staging files")
    args = parser.parse_args(argv)
    try:
        if args.command == "copy":
            report = archive_batches(
                args.source, args.archive, args.batch, args.index, args.dry_run,
                tuple(args.include or ("*",)), DEFAULT_EXCLUDE + tuple(args.exclude or ()),
                args.source_label or posix(Path(args.source).resolve()),
                args.archive_label or posix(Path(args.archive).resolve()))
        else:
            report = verify_archive(args.archive, args.index, args.source)
        emit_json(report)
        return 0 if report["ok"] else 1
    except PipelineError as error:
        sys.stderr.write("error: %s\n" % error)
        return 2


if __name__ == "__main__":
    sys.exit(main())

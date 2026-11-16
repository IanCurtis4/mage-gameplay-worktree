"""`ragrpg_art_provenance_v2` records and a reader for the E08 v1 records (contract C5).

v1 (Codex rounds 1114-1123): a bare JSON list, one record per PNG with `path`, `sha256`,
`width`, `height`, `generator` (string), `request`, `prompt`, usually `references` and
`selected`, sometimes `idle_height_px` and `crop_overrides`. Round 1116 has no `selected`;
1114/1115 store paths relative to the batch folder. The reader accepts all of that and returns
v2-shaped dicts in memory; it never writes to a v1 file.

v2 (any generator): `{"schema": "ragrpg_art_provenance_v2", "path_base": ..., "records": [...]}`.
`path_base` is "project" (paths relative to the folder holding project.godot) or "store"
(relative to the folder of the provenance file, for work outside a project, e.g. D:/ComfyUI/out).

    python tools/art_pipeline/provenance.py show  path/provenance.json        # normalised v2 view
    python tools/art_pipeline/provenance.py check path/provenance.json        # hashes of the files
    python tools/art_pipeline/provenance.py upgrade old.json new_v2.json      # v1 -> v2 copy
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "art_pipeline"

from .common import (PipelineError, emit_json, find_project_root, load_json, png_size, posix,  # noqa: E402
                     sha256_file, write_json_atomic)

SCHEMA_V2 = "ragrpg_art_provenance_v2"
KINDS = ("character_view", "creature_view", "equipment_row", "vfx_source", "icon_source", "icon", "other")
HOSTS = ("local", "cloud", "manual")
REVIEW_STATUSES = ("pending", "approved", "rejected", "needs_changes", "legacy")
PATH_BASES = ("project", "store")
REQUIRED = ("path", "sha256", "width", "height", "kind", "generator", "request", "prompt", "refs", "post",
            "selected", "review", "terms")
KIND_BY_FOLDER = {"characters": "character_view", "creatures": "creature_view", "equipment": "equipment_row",
                  "vfx": "vfx_source"}


# --------------------------------------------------------------------------------------- records
def new_record(path, sha256, width, height, kind, generator_name, request="", prompt="", *, model=None,
               host="local", version=None, negative_prompt=None, seed=None, params=None, refs=None, post=None,
               selected=None, review_status="pending", review_date=None, review_notes="", terms=None,
               measurements=None):
    """A complete v2 record. Optional fields are present with null/empty values, never missing."""
    record = {
        "path": posix(path), "sha256": sha256, "width": int(width), "height": int(height), "kind": kind,
        "generator": {"name": generator_name, "model": model, "host": host, "version": version},
        "request": request, "prompt": prompt, "negative_prompt": negative_prompt, "seed": seed,
        "params": dict(params or {}),
        "refs": [dict(ref) for ref in (refs or [])],
        "post": [dict(step) for step in (post or [])],
        "selected": selected,
        "review": {"status": review_status, "date": review_date, "notes": review_notes},
        "terms": terms,
        "measurements": dict(measurements or {}),
    }
    problems = validate_record(record)
    if problems:
        raise PipelineError("invalid record: " + "; ".join(problems))
    return record


def validate_record(record):
    """Problems (strings) found in a v2 record; empty when valid."""
    problems = []
    for key in REQUIRED:
        if key not in record:
            problems.append("missing %s" % key)
    if problems:
        return problems
    sha = record["sha256"]
    if not (isinstance(sha, str) and len(sha) == 64 and all(c in "0123456789abcdef" for c in sha)):
        problems.append("sha256 must be 64 lowercase hex digits")
    if record["kind"] not in KINDS:
        problems.append("kind must be one of %s" % ", ".join(KINDS))
    generator = record["generator"]
    if not isinstance(generator, dict) or not generator.get("name"):
        problems.append("generator.name is required")
    elif generator.get("host") not in HOSTS:
        problems.append("generator.host must be one of %s" % ", ".join(HOSTS))
    if record["selected"] not in (True, False, None):
        problems.append("selected must be true, false or null")
    review = record["review"]
    if not isinstance(review, dict) or review.get("status") not in REVIEW_STATUSES:
        problems.append("review.status must be one of %s" % ", ".join(REVIEW_STATUSES))
    for index, ref in enumerate(record["refs"]):
        if not (isinstance(ref, dict) and ref.get("path") and ref.get("sha256")):
            problems.append("refs[%d] needs path and sha256" % index)
    for index, step in enumerate(record["post"]):
        for key in ("tool", "version", "params", "input_sha256", "output_sha256"):
            if key not in step:
                problems.append("post[%d] missing %s" % (index, key))
    if not isinstance(record["width"], int) or not isinstance(record["height"], int):
        problems.append("width and height must be integers")
    return problems


def upgrade_v1(record, source_path=None):
    """Convert one v1 record to a v2-shaped dict. Pure; the v1 record is not modified.

    Facts v1 did not record stay null: model, host precision, version, negative prompt, seed,
    review and terms. `selected` is None when v1 never recorded it (round 1116). Extras
    (`idle_height_px`, `crop_overrides`) move to `legacy` and `measurements`.
    """
    generator_name = record.get("generator") or "unknown"
    legacy = {"schema": "v1", "selected_recorded": "selected" in record}
    kind = "other"
    if source_path is not None:
        parts = Path(source_path).parts
        for part in parts:
            if part in KIND_BY_FOLDER:
                kind = KIND_BY_FOLDER[part]
                legacy["kind_inferred_from"] = part
    measurements = {}
    if "idle_height_px" in record:
        measurements["idle_height_px"] = list(record["idle_height_px"])
    if "crop_overrides" in record:
        legacy["crop_overrides"] = [dict(item) for item in record["crop_overrides"]]
    extras = sorted(set(record) - {"path", "sha256", "width", "height", "generator", "request", "prompt",
                                   "references", "selected", "idle_height_px", "crop_overrides"})
    if extras:
        legacy["unmapped_v1_keys"] = {key: record[key] for key in extras}
    return {
        "path": posix(record["path"]), "sha256": record["sha256"], "width": record["width"], "height": record["height"],
        "kind": kind,
        "generator": {"name": generator_name, "model": None,
                      "host": "cloud" if "codex" in generator_name.lower() else "manual", "version": None},
        "request": record.get("request", ""), "prompt": record.get("prompt", ""),
        "negative_prompt": None, "seed": None, "params": {},
        "refs": [{"path": posix(ref["path"]), "sha256": ref["sha256"]} for ref in record.get("references", [])],
        "post": [],
        "selected": record.get("selected"),
        "review": {"status": "legacy", "date": None, "notes": "v1 record; no separate review was written"},
        "terms": None,
        "measurements": measurements,
        "legacy": legacy,
    }


# ------------------------------------------------------------------------------------- the file
class ProvenanceFile:
    """A provenance file in memory: `records` are v2-shaped regardless of the on-disk version."""

    def __init__(self, path, version, records, path_base):
        self.path = Path(path)
        self.version = version
        self.records = records
        self.path_base = path_base

    def selected(self):
        return [record for record in self.records if record["selected"] is True]

    def has_selection_info(self):
        return any(record["selected"] is not None for record in self.records)

    def find(self, name_or_sha):
        return [r for r in self.records if r["sha256"] == name_or_sha or Path(r["path"]).name == name_or_sha]

    # --- path resolution
    def candidates(self, record, search_roots=()):
        relative = Path(record["path"])
        found = []
        if self.version == 2 and self.path_base == "store":
            found.append((self.path.parent / relative, "store"))
        else:
            project = find_project_root(self.path.parent)
            if project is not None:
                found.append((project / relative, "project"))
        for root in search_roots:
            found.append((Path(root) / relative, "search_root"))
        if self.version == 1:  # 1114/1115 keep paths relative to the batch folder, 1116+ to the project
            found.append((self.path.parent.parent / relative, "batch_folder"))
            found.append((self.path.parent / relative.name, "provenance_folder"))
        return found

    def resolve(self, record, search_roots=()):
        """(Path, how) of the first existing candidate file, else (None, None)."""
        for candidate, how in self.candidates(record, search_roots):
            if candidate.is_file():
                return candidate, how
        return None, None

    def check(self, search_roots=(), records=None):
        """Verify the files on disk. One result per record: ok, missing, sha_mismatch or size_mismatch."""
        results = []
        for record in records if records is not None else self.records:
            located, how = self.resolve(record, search_roots)
            item = {"path": record["path"], "sha256": record["sha256"], "selected": record["selected"]}
            if located is None:
                item["status"] = "missing"
            else:
                actual = sha256_file(located)
                size = png_size(located) if located.suffix.lower() == ".png" else None
                item["resolved"] = posix(located)
                item["resolved_via"] = how
                if actual != record["sha256"]:
                    item.update(status="sha_mismatch", actual_sha256=actual)
                elif size is not None and tuple(size) != (record["width"], record["height"]):
                    item.update(status="size_mismatch", actual_size=list(size))
                else:
                    item["status"] = "ok"
            results.append(item)
        return results

    def as_v2_document(self):
        return {"schema": SCHEMA_V2, "path_base": self.path_base if self.version == 2 else "project",
                "records": self.records}


def load_provenance(path):
    """Read a v1 or v2 provenance file. Never modifies it."""
    path = Path(path)
    data = load_json(path)
    if isinstance(data, list):
        return ProvenanceFile(path, 1, [upgrade_v1(item, path) for item in data], "project")
    if isinstance(data, dict) and data.get("schema") == SCHEMA_V2:
        base = data.get("path_base", "project")
        if base not in PATH_BASES:
            raise PipelineError("path_base must be project or store: %s" % path)
        records = data.get("records", [])
        for index, record in enumerate(records):
            problems = validate_record(record)
            if problems:
                raise PipelineError("%s record %d: %s" % (path, index, "; ".join(problems)))
        return ProvenanceFile(path, 2, records, base)
    raise PipelineError("unrecognised provenance format (neither a v1 list nor %s): %s" % (SCHEMA_V2, path))


def default_path_base(output_file, store_path):
    """'project' when both files sit inside one project, else 'store'."""
    project = find_project_root(Path(store_path).parent)
    if project is not None and project in Path(output_file).resolve().parents:
        return "project", project
    return "store", Path(store_path).resolve().parent


def append_record(store_path, record, replace=False, path_base=None):
    """Add a v2 record to a v2 store, creating it when absent.

    Returns "added", "unchanged" or "replaced". Refuses to touch a v1 file and refuses to change
    an existing record for the same (path, sha256) unless `replace` is true.
    """
    store_path = Path(store_path)
    problems = validate_record(record)
    if problems:
        raise PipelineError("invalid record: " + "; ".join(problems))
    if store_path.exists():
        raw = load_json(store_path)
        if isinstance(raw, list):
            raise PipelineError("%s is a v1 provenance list and is never rewritten; use a v2 store, "
                                "e.g. %s" % (store_path, store_path.with_name("provenance_v2.json")))
        if not (isinstance(raw, dict) and raw.get("schema") == SCHEMA_V2):
            raise PipelineError("%s is not a %s store" % (store_path, SCHEMA_V2))
        document = raw
    else:
        document = {"schema": SCHEMA_V2, "path_base": path_base or "project", "records": []}
    status = "added"
    for index, existing in enumerate(document["records"]):
        if existing["path"] == record["path"] and existing["sha256"] == record["sha256"]:
            if existing == record:
                return "unchanged"
            if not replace:
                raise PipelineError("a different record already exists for %s (%s...); pass replace to overwrite it"
                                    % (record["path"], record["sha256"][:12]))
            document["records"][index] = record
            status = "replaced"
            break
    else:
        document["records"].append(record)
    write_json_atomic(store_path, document)
    return status


# ------------------------------------------------------------------------------------------ CLI
def main(argv=None):
    parser = argparse.ArgumentParser(description="Read, check and upgrade art provenance files (v1 and v2).")
    sub = parser.add_subparsers(dest="command", required=True)
    show = sub.add_parser("show", help="print the normalised v2 view as JSON")
    show.add_argument("file")
    check = sub.add_parser("check", help="verify that every record's file exists with the recorded SHA256/size")
    check.add_argument("file")
    check.add_argument("--root", action="append", default=[], help="extra folder to resolve record paths against")
    check.add_argument("--selected-only", action="store_true")
    upgrade = sub.add_parser("upgrade", help="write a v2 copy of a v1 file at a NEW path")
    upgrade.add_argument("file")
    upgrade.add_argument("out")
    args = parser.parse_args(argv)
    try:
        provenance = load_provenance(args.file)
        if args.command == "show":
            emit_json(provenance.as_v2_document())
            return 0
        if args.command == "check":
            records = provenance.selected() if args.selected_only else None
            results = provenance.check(args.root, records)
            bad = [r for r in results if r["status"] != "ok"]
            emit_json({"file": posix(args.file), "version": provenance.version,
                                         "checked": len(results), "problems": len(bad), "results": results})
            return 1 if bad else 0
        if Path(args.out).resolve() == Path(args.file).resolve() or Path(args.out).exists():
            raise PipelineError("upgrade writes a new file and never overwrites: %s" % args.out)
        write_json_atomic(args.out, provenance.as_v2_document())
        return 0
    except PipelineError as error:
        sys.stderr.write("error: %s\n" % error)
        return 2


if __name__ == "__main__":
    sys.exit(main())

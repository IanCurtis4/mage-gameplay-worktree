"""`selection.json`: which version of each view or sheet is the chosen one (contract C5).

One file per batch or class, normally next to the images. Each slot (a view such as `south`, or
a sheet such as `weapons_h1`) points to one file by relative path *and* SHA256, so a packager
that reads it cannot silently pick up a different file. Packagers only ever read it:

    from art_pipeline.selection import load_selection     # tools/ on sys.path
    selection = load_selection("assets/art/e08_codex_1123/characters/sp_ac/selection.json")
    south = selection.resolve("south")                    # absolute Path; SHA256 verified

Commands:
    selection.py derive path/provenance.json [--out selection.json] [--scope ...] [--latest-if-unrecorded]
    selection.py show   selection.json
    selection.py check  selection.json                    # files exist and hashes match
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "art_pipeline"

from .common import PipelineError, dumps_json, emit_json, load_json, posix, sha256_file, today, write_json_atomic  # noqa: E402
from .provenance import load_provenance  # noqa: E402

SCHEMA = "ragrpg_art_selection_v1"
VERSION_SUFFIX = re.compile(r"_v(\d+)$")


def slot_name(filename):
    """south_v2.png -> south ; weapons_h1_v2.png -> weapons_h1 ; east.png -> east."""
    return VERSION_SUFFIX.sub("", Path(filename).stem)


def version_number(filename):
    match = VERSION_SUFFIX.search(Path(filename).stem)
    return int(match.group(1)) if match else 1


class Selection:
    def __init__(self, path, scope, items, notes="", updated=None):
        self.path = Path(path)
        self.scope = scope
        self.items = items
        self.notes = notes
        self.updated = updated

    def slots(self):
        return list(self.items)

    def get(self, slot):
        if slot not in self.items:
            raise PipelineError("slot %r is not in %s (has: %s)" % (slot, self.path, ", ".join(self.items)))
        return self.items[slot]

    def resolve(self, slot, verify=True):
        """Absolute path of the chosen file; raises PipelineError if it is missing or its hash differs."""
        item = self.get(slot)
        target = (self.path.parent / item["path"]).resolve()
        if not target.is_file():
            raise PipelineError("selected file for %r is missing: %s" % (slot, target))
        if verify:
            actual = sha256_file(target)
            if actual != item["sha256"]:
                raise PipelineError("selected file for %r changed: expected %s..., found %s..."
                                    % (slot, item["sha256"][:12], actual[:12]))
        return target

    def resolve_all(self, verify=True):
        return {slot: self.resolve(slot, verify) for slot in self.items}

    def to_dict(self):
        document = {"schema": SCHEMA, "scope": self.scope, "updated": self.updated or today(),
                    "selections": self.items}
        if self.notes:
            document["notes"] = self.notes
        return document


def load_selection(path):
    path = Path(path)
    data = load_json(path)
    if not (isinstance(data, dict) and data.get("schema") == SCHEMA):
        raise PipelineError("not a %s file: %s" % (SCHEMA, path))
    items = data.get("selections")
    if not isinstance(items, dict) or not items:
        raise PipelineError("selection has no slots: %s" % path)
    for slot, item in items.items():
        if not (isinstance(item, dict) and item.get("path") and len(item.get("sha256", "")) == 64):
            raise PipelineError("slot %r needs path and a 64-digit sha256 in %s" % (slot, path))
    return Selection(path, data.get("scope", ""), items, data.get("notes", ""), data.get("updated"))


def save_selection(path, scope, items, notes="", replace=False):
    path = Path(path)
    selection = Selection(path, scope, items, notes)
    if path.exists() and not replace:
        existing = load_selection(path)
        if existing.items != items:
            raise PipelineError("%s already holds a different selection; pass replace to overwrite it" % path)
        return "unchanged"
    write_json_atomic(path, selection.to_dict())
    return "written"


def derive_from_provenance(provenance, selection_dir, latest_if_unrecorded=False, search_roots=()):
    """Build slot items from the `selected: true` flags of a provenance file (v1 or v2).

    Returns (items, report). report lists conflicts (two selected for one slot, an error for the
    caller), slots with versions but none selected, files that could not be located, and whether
    the file carried any selection information at all (round 1116 did not).
    """
    selection_dir = Path(selection_dir).resolve()
    by_slot = {}
    for record in provenance.records:
        by_slot.setdefault(slot_name(record["path"]), []).append(record)
    items, report = {}, {"conflicts": [], "unselected_slots": [], "unresolved": [], "inferred": [],
                         "has_selection_info": provenance.has_selection_info()}
    for slot, records in sorted(by_slot.items()):
        chosen = [r for r in records if r["selected"] is True]
        if len(chosen) > 1:
            report["conflicts"].append({"slot": slot, "files": [r["path"] for r in chosen]})
            continue
        inferred = False
        if not chosen:
            if latest_if_unrecorded and not provenance.has_selection_info():
                chosen = [max(records, key=lambda r: version_number(r["path"]))]
                inferred = True
            else:
                report["unselected_slots"].append({"slot": slot, "versions": [Path(r["path"]).name for r in records]})
                continue
        record = chosen[0]
        located, _how = provenance.resolve(record, search_roots)
        if located is None:
            report["unresolved"].append(record["path"])
            continue
        try:
            relative = os.path.relpath(located.resolve(), selection_dir)
        except ValueError as error:  # another drive on Windows
            raise PipelineError("cannot express %s relative to %s: %s" % (located, selection_dir, error)) from error
        item = {"path": posix(relative), "sha256": record["sha256"]}
        if inferred:
            item["inferred"] = "latest version; the source provenance has no selected flag"
            report["inferred"].append(slot)
        items[slot] = item
    return items, report


def main(argv=None):
    parser = argparse.ArgumentParser(description="Derive, show and check selection.json files.")
    sub = parser.add_subparsers(dest="command", required=True)
    derive = sub.add_parser("derive", help="build selection.json from the selected flags of a provenance file")
    derive.add_argument("provenance")
    derive.add_argument("--out", help="selection.json to write (default: print to stdout)")
    derive.add_argument("--scope", help="label, e.g. e08_codex_1123/characters/sp_ac (default: provenance folder)")
    derive.add_argument("--latest-if-unrecorded", action="store_true",
                        help="when the provenance never recorded `selected` (round 1116) take the highest _vN")
    derive.add_argument("--root", action="append", default=[], help="extra folder to resolve record paths against")
    derive.add_argument("--replace", action="store_true")
    show = sub.add_parser("show")
    show.add_argument("file")
    check = sub.add_parser("check")
    check.add_argument("file")
    args = parser.parse_args(argv)
    try:
        if args.command == "derive":
            provenance = load_provenance(args.provenance)
            out_dir = Path(args.out).parent if args.out else Path(args.provenance).parent
            items, report = derive_from_provenance(provenance, out_dir, args.latest_if_unrecorded, args.root)
            scope = args.scope or posix(Path(args.provenance).resolve().parent.name)
            if report["conflicts"]:
                sys.stderr.write(dumps_json({"error": "two selected files for one slot", **report}))
                return 1
            if args.out:
                status = save_selection(args.out, scope, items, replace=args.replace)
                emit_json({"out": posix(args.out), "status": status, "slots": list(items), **report})
            else:
                emit_json({"selection": Selection(out_dir, scope, items).to_dict(), "report": report})
            return 1 if (report["unselected_slots"] or report["unresolved"]) else 0
        selection = load_selection(args.file)
        if args.command == "show":
            emit_json(selection.to_dict())
            return 0
        problems = []
        for slot in selection.slots():
            try:
                selection.resolve(slot)
            except PipelineError as error:
                problems.append({"slot": slot, "problem": str(error)})
        emit_json({"file": posix(args.file), "slots": len(selection.items), "problems": problems})
        return 1 if problems else 0
    except PipelineError as error:
        sys.stderr.write("error: %s\n" % error)
        return 2


if __name__ == "__main__":
    sys.exit(main())

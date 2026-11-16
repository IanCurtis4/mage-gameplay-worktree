"""Append a `ragrpg_art_provenance_v2` record for one generated file (contract C5).

Any generator (Codex, ComfyUI, Hugging Face, fal, a web page, a hand drawing) or its wrapper
script calls this after writing a PNG. The tool hashes the file, reads its size from the PNG
header, hashes every reference and adds one record to a v2 store, by default
`provenance.json` next to the file. It never rewrites a v1 list: for a folder that already has a
v1 `provenance.json` use `--store provenance_v2.json`.

    python tools/art_pipeline/record_generation.py out/east_v2.png --kind character_view \
        --generator ComfyUI --model qwen-image-edit-2511-Q4_K_M.gguf --host local \
        --request "mg_dr / east" --prompt-file prompt.txt --seed 31 --param steps=4 \
        --ref refs/mg_ac_east.png --ref refs/mg_dr_south.png --review-status pending

    # the logs written by D:/ComfyUI/ragrpg/{qedit,faledit,hfedit}.py are understood directly:
    python tools/art_pipeline/record_generation.py D:/ComfyUI/ragrpg/out/1124/x_s31.png \
        --from-comfy-log D:/ComfyUI/ragrpg/out/1124/x_log.json --store D:/ComfyUI/ragrpg/out/1124/provenance.json

From Python (tools/ on sys.path): `from art_pipeline.record_generation import record_file`.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "art_pipeline"

from .common import PipelineError, emit_json, find_project_root, load_json, png_size, posix, sha256_file  # noqa: E402
from .provenance import (HOSTS, KIND_BY_FOLDER, KINDS, REVIEW_STATUSES, append_record,  # noqa: E402
                         default_path_base, new_record)


def _relative(path, base_dir):
    """POSIX path of `path` under `base_dir`, or None when it is outside."""
    try:
        return posix(Path(path).resolve().relative_to(Path(base_dir).resolve()))
    except ValueError:
        return None


def infer_kind(path):
    for part in Path(path).resolve().parts:
        if part in KIND_BY_FOLDER:
            return KIND_BY_FOLDER[part]
    return "other"


def _parse_value(text):
    try:
        return json.loads(text)
    except ValueError:
        return text


def _json_arg(value):
    """A JSON file path or an inline JSON object/array."""
    value = value.strip()
    if value.startswith("{") or value.startswith("["):
        return json.loads(value)
    return load_json(value)


def comfy_log_fields(log_path, output_file):
    """Map a qedit/faledit/hfedit `<name>_log.json` to record fields for `output_file`."""
    log = load_json(log_path)
    job = log.get("job", {})
    match = re.search(r"_s(\d+)(?:_raw)?\.png$", Path(output_file).name)
    seed = int(match.group(1)) if match else None
    runs = log.get("runs", [])
    run = next((item for item in runs if item.get("seed") == seed), runs[0] if len(runs) == 1 else {})
    params = {key: run[key] for key in ("steps", "guidance", "seconds", "size", "est_usd") if key in run}
    for key in ("clip", "vae", "lora"):
        if key in log:
            params[key] = log[key]
    for key in ("size", "ref_size", "denoise", "steps", "guidance", "acceleration", "mask", "bg", "mode"):
        if key in job and key not in params:
            params[key] = job[key]
    if "unet" in log:
        fields = {"generator": "ComfyUI", "model": log["unet"], "host": "local"}
    elif "fal" in str(log.get("backend", "")).lower():
        fields = {"generator": "fal.ai", "model": str(log["backend"]).replace("fal.ai ", ""), "host": "cloud"}
    else:
        fields = {"generator": "Hugging Face Space", "model": log.get("backend"), "host": "cloud"}
    fields.update(request=job.get("name", ""), prompt=run.get("prompt", job.get("prompt", "")),
                  negative_prompt=job.get("negative") or None, seed=seed if seed is not None else run.get("seed"),
                  params=params)
    # The edit target is image 1 and the refs follow, in the order they were sent to the model.
    refs = [ref.get("path") if isinstance(ref, dict) else ref for ref in job.get("refs", [])]  # tile jobs use dicts
    fields["ref_paths"] = [p for p in [job.get("sheet"), *refs] if p]
    raw = Path(output_file).with_name(Path(output_file).stem + "_raw.png")
    fields["raw_path"] = str(raw) if raw.is_file() and raw != Path(output_file) else None
    fields["post_params"] = {"bg": job.get("bg"), "mask": job.get("mask"),
                             "note": "chroma key and masked composite done by the generator script"}
    return fields


def record_file(file, *, kind=None, generator, model=None, host="local", generator_version=None, request="",
                prompt="", negative_prompt=None, seed=None, params=None, refs=(), post=(), selected=None,
                review_status="pending", review_date=None, review_notes="", terms=None, measurements=None,
                store=None, root=None, replace=False, allow_missing_ref=False, dry_run=False):
    """Hash `file`, build the v2 record, append it to the store. Returns {"status", "store", "record"}."""
    file = Path(file)
    if not file.is_file():
        raise PipelineError("file not found: %s" % file)
    width, height = png_size(file)
    digest = sha256_file(file)
    store = Path(store) if store else file.with_name("provenance.json")
    if root is not None:
        path_base, base_dir = "project", Path(root)
    elif store.exists():
        existing = load_json(store)
        path_base = existing.get("path_base", "project") if isinstance(existing, dict) else "project"
        base_dir = (find_project_root(store.parent) or store.parent) if path_base == "project" else store.parent
    else:
        path_base, base_dir = default_path_base(file, store)
    relative = _relative(file, base_dir)
    if relative is None:
        raise PipelineError("%s is outside %s; put --store in a folder above the file, or pass --root" % (file, base_dir))
    ref_records = []
    for ref in refs:
        ref_path = Path(ref)
        ref_relative = _relative(ref_path, base_dir) or posix(ref_path)
        if ref_path.is_file():
            ref_records.append({"path": ref_relative, "sha256": sha256_file(ref_path)})
        elif allow_missing_ref:
            ref_records.append({"path": ref_relative, "sha256": "unavailable"})
        else:
            raise PipelineError("reference not found (use --allow-missing-ref to record it anyway): %s" % ref)
    record = new_record(
        relative, digest, width, height, kind or infer_kind(file), generator, request, prompt, model=model, host=host,
        version=generator_version, negative_prompt=negative_prompt, seed=seed, params=params, refs=ref_records,
        post=list(post), selected=selected, review_status=review_status, review_date=review_date,
        review_notes=review_notes, terms=terms, measurements=measurements)
    if dry_run:
        return {"status": "dry_run", "store": posix(store), "record": record}
    status = append_record(store, record, replace=replace, path_base=path_base)
    return {"status": status, "store": posix(store), "record": record}


def build_parser():
    parser = argparse.ArgumentParser(description="Append a ragrpg_art_provenance_v2 record for a generated file.")
    parser.add_argument("file")
    parser.add_argument("--kind", choices=KINDS, help="default: inferred from the folder name, else 'other'")
    parser.add_argument("--generator", help="generator name, e.g. 'ComfyUI', 'Gemini Nano Banana', 'hand drawn'")
    parser.add_argument("--model")
    parser.add_argument("--host", choices=HOSTS, help="local, cloud or manual (default: local; from the log with --from-comfy-log)")
    parser.add_argument("--generator-version")
    parser.add_argument("--request", default="", help="what was asked for, e.g. 'mg_dr / east'")
    parser.add_argument("--prompt", help="the exact prompt")
    parser.add_argument("--prompt-file", help="read the exact prompt from this UTF-8 file")
    parser.add_argument("--negative-prompt")
    parser.add_argument("--seed", type=int)
    parser.add_argument("--param", action="append", default=[], metavar="KEY=VALUE",
                        help="generator parameter; VALUE is parsed as JSON when possible (repeatable)")
    parser.add_argument("--params-json", help="JSON file or inline object with generator parameters")
    parser.add_argument("--ref", action="append", default=[], help="reference image sent to the generator (repeatable, in order)")
    parser.add_argument("--allow-missing-ref", action="store_true")
    parser.add_argument("--post", action="append", default=[], metavar="JSON",
                        help="post step {tool,version,params,input_sha256,output_sha256}: JSON file or inline (repeatable)")
    parser.add_argument("--measure", action="append", default=[], metavar="KEY=VALUE",
                        help="measurement such as idle_height_px=[289,288,282,290] (repeatable)")
    parser.add_argument("--selected", dest="selected", action="store_true", default=None)
    parser.add_argument("--not-selected", dest="selected", action="store_false")
    parser.add_argument("--review-status", choices=[s for s in REVIEW_STATUSES if s != "legacy"], default="pending")
    parser.add_argument("--review-date")
    parser.add_argument("--review-notes", default="")
    parser.add_argument("--terms", help="terms-of-use note for the generator/model (licence, plan, commercial use)")
    parser.add_argument("--store", help="v2 provenance file (default: provenance.json next to the file)")
    parser.add_argument("--root", help="project root the recorded paths are relative to")
    parser.add_argument("--replace", action="store_true", help="replace a different record for the same file+hash")
    parser.add_argument("--from-comfy-log", help="fill the fields from a qedit/faledit/hfedit <name>_log.json")
    parser.add_argument("--dry-run", action="store_true", help="print the record without writing")
    return parser


def _kv(items):
    out = {}
    for item in items:
        if "=" not in item:
            raise PipelineError("expected KEY=VALUE, got %r" % item)
        key, value = item.split("=", 1)
        out[key] = _parse_value(value)
    return out


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        fields = {"generator": args.generator, "model": args.model, "host": args.host, "request": args.request,
                  "prompt": args.prompt, "negative_prompt": args.negative_prompt, "seed": args.seed,
                  "params": {}, "ref_paths": [], "raw_path": None, "post_params": None}
        if args.from_comfy_log:
            for key, value in comfy_log_fields(args.from_comfy_log, args.file).items():
                fields[key] = value
            if args.generator:
                fields["generator"] = args.generator
            if args.host:
                fields["host"] = args.host
            if args.model:
                fields["model"] = args.model
        if args.prompt_file:
            fields["prompt"] = Path(args.prompt_file).read_text(encoding="utf-8").rstrip("\n")
        fields["host"] = fields["host"] or "local"
        if not fields["generator"]:
            raise PipelineError("--generator is required (or --from-comfy-log)")
        if fields["prompt"] is None:
            raise PipelineError("give the exact prompt with --prompt or --prompt-file (use '' for hand-made art)")
        params = dict(fields["params"])
        if args.params_json:
            params.update(_json_arg(args.params_json))
        params.update(_kv(args.param))
        post = [_json_arg(item) for item in args.post]
        if fields["raw_path"]:
            post.insert(0, {"tool": "generator script post-processing", "version": "unversioned",
                            "params": fields["post_params"], "input_sha256": sha256_file(fields["raw_path"]),
                            "output_sha256": sha256_file(args.file)})
        result = record_file(
            args.file, kind=args.kind, generator=fields["generator"], model=fields["model"], host=fields["host"],
            generator_version=args.generator_version, request=fields["request"], prompt=fields["prompt"],
            negative_prompt=fields["negative_prompt"], seed=fields["seed"], params=params,
            refs=list(fields["ref_paths"]) + args.ref, post=post, selected=args.selected,
            review_status=args.review_status, review_date=args.review_date, review_notes=args.review_notes,
            terms=args.terms, measurements=_kv(args.measure), store=args.store, root=args.root,
            replace=args.replace, allow_missing_ref=args.allow_missing_ref or bool(args.from_comfy_log),
            dry_run=args.dry_run)
        emit_json({"status": result["status"], "store": result["store"],
                                     "path": result["record"]["path"], "sha256": result["record"]["sha256"]})
        return 0
    except (PipelineError, ValueError, OSError) as error:
        sys.stderr.write("error: %s\n" % error)
        return 2


if __name__ == "__main__":
    sys.exit(main())

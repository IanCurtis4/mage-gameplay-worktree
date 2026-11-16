"""Standard-library helpers shared by the art pipeline."""
from __future__ import annotations

import datetime
import hashlib
import json
import os
import struct
import tempfile
from pathlib import Path

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class PipelineError(Exception):
    """A refusal or failure the CLI reports as a clean message, not a traceback."""


def sha256_file(path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def png_size(path):
    """(width, height) read from the IHDR chunk; no image library needed."""
    with open(path, "rb") as handle:
        head = handle.read(24)
    if len(head) < 24 or head[:8] != PNG_SIGNATURE or head[12:16] != b"IHDR":
        raise PipelineError("not a PNG file: %s" % path)
    return struct.unpack(">II", head[16:24])


def posix(path) -> str:
    return str(path).replace("\\", "/")


def today() -> str:
    return datetime.date.today().isoformat()


def find_project_root(start):
    """Nearest ancestor (or the folder itself) holding project.godot; None if there is none."""
    current = Path(start).resolve()
    if current.is_file():
        current = current.parent
    for candidate in (current, *current.parents):
        if (candidate / "project.godot").is_file():
            return candidate
    return None


def load_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def dumps_json(data) -> str:
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def emit_json(data) -> None:
    """Print JSON to stdout as UTF-8 bytes whatever the console code page is (Windows pipes use cp1252)."""
    import sys
    sys.stdout.flush()
    sys.stdout.buffer.write(dumps_json(data).encode("utf-8"))
    sys.stdout.buffer.flush()


def write_json_atomic(path, data) -> None:
    """Write a JSON file through a temp file in the same folder, so a crash never leaves half a file."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, temp_name = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(handle, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(dumps_json(data))
        os.replace(temp_name, path)
    except BaseException:
        if os.path.exists(temp_name):
            os.remove(temp_name)
        raise


def tool_stamp(name: str) -> dict:
    from . import VERSION
    return {"name": name, "version": VERSION}

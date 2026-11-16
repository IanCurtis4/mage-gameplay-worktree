"""Pillow and numpy access for the image tools.

`python -I` ignores the per-user site-packages, which is where Pillow and numpy live on the
development machine. This module appends that single folder (never the working directory or
PYTHONPATH) when the first import fails, so `python -I -m unittest` still runs the image tests.
"""
from __future__ import annotations

import os
import site
import sys

from .common import PipelineError


def _import():
    import numpy  # noqa: F401
    from PIL import Image  # noqa: F401


try:
    _import()
except ImportError:
    user_packages = site.getusersitepackages()
    if os.path.isdir(user_packages) and user_packages not in sys.path:
        sys.path.append(user_packages)
    try:
        _import()
    except ImportError as error:
        raise PipelineError("Pillow and numpy are required for the image tools (%s)" % error) from error

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

Image.MAX_IMAGE_PIXELS = 64_000_000  # sheets are a few megapixels; refuse decompression bombs

# Alpha above this counts as content. Same value as tools/prepare_e08_equipment_icons.py and as
# the v1 provenance `crop_overrides.alpha_threshold`; below it is the faint "veil" some
# generators leave over the background (E08 1121 notes).
ALPHA_THRESHOLD = 16


def load_rgba(path):
    """Return (pixels HxWx4 uint8, info dict with the original mode)."""
    with Image.open(path) as image:
        info = {"mode": image.mode, "format": image.format, "size": image.size}
        has_alpha = image.mode in ("RGBA", "LA", "PA") or "transparency" in image.info
        rgba = image.convert("RGBA")
    info["has_alpha"] = bool(has_alpha)
    return np.array(rgba, dtype=np.uint8), info


def save_png(pixels, path) -> None:
    from pathlib import Path
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(pixels, "RGBA").save(str(path), format="PNG")


def parse_color(text):
    """'#FF00FF' or 'FF00FF' or 'r,g,b' -> (r, g, b)."""
    value = text.strip()
    if "," in value:
        parts = [int(part) for part in value.split(",")]
    else:
        value = value.lstrip("#")
        if len(value) != 6:
            raise PipelineError("colour must be #RRGGBB or r,g,b: %r" % text)
        parts = [int(value[i:i + 2], 16) for i in (0, 2, 4)]
    if len(parts) != 3 or any(not 0 <= part <= 255 for part in parts):
        raise PipelineError("colour must be #RRGGBB or r,g,b: %r" % text)
    return tuple(parts)


def color_hex(color) -> str:
    return "#%02X%02X%02X" % tuple(color)

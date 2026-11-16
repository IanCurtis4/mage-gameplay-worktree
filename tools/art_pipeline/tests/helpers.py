"""Synthetic sheets and small utilities shared by the tests."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import _bootstrap  # noqa: F401  (sets sys.path)
from art_pipeline.imaging import Image, np  # noqa: E402


class TempCase(unittest.TestCase):
    """A fresh temporary folder per test, removed afterwards."""

    def setUp(self):
        self._temp = tempfile.TemporaryDirectory(prefix="art_pipeline_test_")
        self.addCleanup(self._temp.cleanup)
        self.tmp = Path(self._temp.name)

    def run_cli(self, script, *args):
        """Run tools/art_pipeline/<script>.py with `python -I`; returns (code, stdout, stderr)."""
        command = [sys.executable, "-I", str(_bootstrap.PIPELINE / script), *map(str, args)]
        done = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace")
        return done.returncode, done.stdout, done.stderr


def save(array, path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(array, "RGBA").save(str(path))
    return path


def view_sheet(path, size=400, idle_height=60, fig_width=30, bg=None, empty_cells=(), overflow=None,
               body=(200, 60, 60), outline=(20, 10, 25)):
    """A 4x4 sheet: one bottom-anchored rectangle per cell, row 0 `idle_height` tall.

    `bg` is None for real alpha or an (r, g, b) key colour painted everywhere (opaque sheet).
    `overflow` maps a cell index to the number of px its figure extends past the cell's right edge.
    """
    cell = size // 4
    pixels = np.zeros((size, size, 4), dtype=np.uint8)
    for index in range(16):
        if index in empty_cells:
            continue
        row, col = divmod(index, 4)
        height = idle_height if row == 0 else max(10, idle_height - 10)
        x0 = col * cell + (cell - fig_width) // 2
        y1 = (row + 1) * cell - 14
        x1 = x0 + fig_width
        if overflow and index in overflow:
            x1 = (col + 1) * cell + overflow[index]
        pixels[y1 - height:y1, x0:x1] = body + (255,)
        pixels[y1 - height:y1, x0:x0 + 2] = outline + (255,)
    if bg is not None:
        flat = np.zeros_like(pixels)
        flat[:, :] = tuple(bg) + (255,)
        mask = pixels[:, :, 3] > 0
        flat[mask] = pixels[mask]
        pixels = flat
    return save(pixels, path)


def tiny_png(path, seed):
    """An 8x8 RGBA PNG whose bytes (and so SHA256) differ for every `seed`."""
    pixels = np.zeros((8, 8, 4), dtype=np.uint8)
    pixels[:, :, 3] = 255
    pixels[0, 0, :3] = (seed % 256, (seed // 256) % 256, 7)
    pixels[2:6, 2:6, :3] = (40 + seed % 100, 90, 120)
    return save(pixels, path)


def equipment_sheet(path, widths=(60, 80, 50), gap=30, height=50, size=(500, 120), touching=False):
    pixels = np.zeros((size[1], size[0], 4), dtype=np.uint8)
    x = 20
    for width in widths:
        pixels[30:30 + height, x:x + width] = (180, 180, 190, 255)
        x += width + (0 if touching else gap)
    return save(pixels, path)


def v1_record(path, sha, **extra):
    record = {"path": path, "sha256": sha, "width": 10, "height": 10, "generator": "Codex built-in imagegen",
              "request": "x / south", "prompt": "p"}
    record.update(extra)
    return record


def write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=1), encoding="utf-8")
    return path


def file_state(path):
    stat = os.stat(path)
    return stat.st_size, stat.st_mtime_ns

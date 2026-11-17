"""Geometry shared by the validator and the normaliser: the ragrpg_source_sheet_v1 layouts.

Cells follow the packager rule of tools/prepare_e08_directional_art.py: the sheet is divided
into equal cells with round(col * width / cols), so the same arithmetic is used here.
"""
from __future__ import annotations

from .imaging import ALPHA_THRESHOLD, np

SCHEMA = "ragrpg_source_sheet_v1"
DIRECTIONS = ("south", "east", "west", "north")
GRID_KINDS = ("character_view", "creature_view", "vfx_source")
KINDS = GRID_KINDS + ("equipment_row", "icon_source")
GRID = (4, 4)
# Rows of a view sheet: 4 idle, 4 walk, 4 action, 2 hurt + 2 death.
POSE_ROWS = ("idle", "walk", "action", "hurt_death")
IDLE_ROW = 0
ICON_MIN_SIDE = 128


def cell_regions(width, height, cols=GRID[0], rows=GRID[1]):
    """[(x0, y0, x1, y1)] per cell, row-major, identical to the packager's crop box."""
    regions = []
    for row in range(rows):
        for col in range(cols):
            regions.append((round(col * width / cols), round(row * height / rows),
                            round((col + 1) * width / cols), round((row + 1) * height / rows)))
    return regions


def row_bounds(width, cols, row, overrides=None):
    """Vertical cell boundaries of one row: cols + 1 x values, with v1 `crop_overrides` applied.

    An override is {"row": 4, "boundary_after_column": 3, "x_px": 813} (1-based row/column, the
    shape the E08 provenance records use) and moves that boundary for that row only.
    """
    bounds = [round(col * width / cols) for col in range(cols + 1)]
    for override in overrides or ():
        if int(override["row"]) == row + 1:
            bounds[int(override["boundary_after_column"])] = int(override["x_px"])
    return bounds


def content_mask(alpha, threshold=ALPHA_THRESHOLD):
    return alpha > threshold


def mask_bbox(mask):
    """(x0, y0, x1, y1) with exclusive max, or None when the mask is empty."""
    rows = np.flatnonzero(mask.any(axis=1))
    if rows.size == 0:
        return None
    cols = np.flatnonzero(mask.any(axis=0))
    return int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1


def cell_boxes(mask, cols=GRID[0], rows=GRID[1], overrides=None):
    """Per cell: region and the content bbox in sheet coordinates (None when empty)."""
    height, width = mask.shape
    cells = []
    for row in range(rows):
        bounds = row_bounds(width, cols, row, overrides)
        y0, y1 = round(row * height / rows), round((row + 1) * height / rows)
        for col in range(cols):
            x0, x1 = bounds[col], bounds[col + 1]
            local = mask_bbox(mask[y0:y1, x0:x1])
            bbox = None if local is None else (local[0] + x0, local[1] + y0, local[2] + x0, local[3] + y0)
            cells.append({"index": row * cols + col, "row": row, "col": col,
                          "region": (x0, y0, x1, y1), "bbox": bbox})
    return cells


def idle_heights(cells, cols=GRID[0]):
    """Bbox heights of the idle row (row 0), skipping empty cells."""
    return [cell["bbox"][3] - cell["bbox"][1] for cell in cells[:cols] if cell["bbox"] is not None]


def idle_height(cells, cols=GRID[0]):
    """Median idle body height, the same statistic the directional packager uses."""
    heights = idle_heights(cells, cols)
    return float(np.median(heights)) if heights else None


def empty_run_at(is_empty, position):
    """Length of the run of True values in `is_empty` that contains `position` (0 if not empty)."""
    if position < 0 or position >= len(is_empty) or not is_empty[position]:
        return 0
    start = position
    while start > 0 and is_empty[start - 1]:
        start -= 1
    end = position
    while end + 1 < len(is_empty) and is_empty[end + 1]:
        end += 1
    return end - start + 1


def nearest_empty_run(is_empty, position, search):
    """(start, end) of the empty run nearest to `position` within `search` px, else None."""
    best = None
    x = max(0, position - search)
    limit = min(len(is_empty), position + search + 1)
    while x < limit:
        if is_empty[x]:
            start = x
            while x + 1 < len(is_empty) and is_empty[x + 1]:
                x += 1
            run = (start, x + 1)
            distance = 0 if run[0] <= position < run[1] else min(abs(run[0] - position), abs(run[1] - 1 - position))
            if best is None or distance < best[0]:
                best = (distance, run)
        x += 1
    return None if best is None else best[1]


def suggest_row_boundary(mask, cols, rows, row, boundary_after, overrides=None):
    """The x where the row could be cut instead of the blocked boundary (centre of the nearest
    transparent column band inside that row), as a v1 `crop_overrides` entry; None if none exists."""
    height, width = mask.shape
    y0, y1 = round(row * height / rows), round((row + 1) * height / rows)
    empty_columns = ~mask[y0:y1].any(axis=0)
    bounds = row_bounds(width, cols, row, overrides)
    run = nearest_empty_run(empty_columns, bounds[boundary_after], max(8, width // (cols * 2)))
    if run is None:
        return None
    return {"row": row + 1, "boundary_after_column": boundary_after, "x_px": (run[0] + run[1]) // 2}


def gutter_bands(mask, cols=GRID[0], rows=GRID[1], overrides=None):
    """Width of the transparent band at every internal cell boundary, measured per row/column.

    A vertical boundary is checked inside each row (so a wide sprite in another row does not
    matter) and a horizontal boundary inside each column. Returns
    {"vertical": [[w per boundary] per row], "horizontal": [[w per boundary] per column]}.
    0 means content sits on the boundary.
    """
    height, width = mask.shape
    vertical = []
    for row in range(rows):
        y0, y1 = round(row * height / rows), round((row + 1) * height / rows)
        empty_columns = ~mask[y0:y1].any(axis=0)
        bounds = row_bounds(width, cols, row, overrides)
        vertical.append([empty_run_at(empty_columns, bounds[k]) for k in range(1, cols)])
    horizontal = []
    for col in range(cols):
        x0, x1 = round(col * width / cols), round((col + 1) * width / cols)
        empty_rows = ~mask[:, x0:x1].any(axis=1)
        horizontal.append([empty_run_at(empty_rows, round(k * height / rows)) for k in range(1, rows)])
    return {"vertical": vertical, "horizontal": horizontal}


def veil_pixels(alpha, mask, threshold=ALPHA_THRESHOLD, radius=2):
    """Faint pixels (0 < alpha <= threshold) farther than `radius` px from any content pixel."""
    faint = (alpha > 0) & (alpha <= threshold)
    if not faint.any():
        return 0
    near = mask.copy()
    for _ in range(radius):
        grown = near.copy()
        grown[1:, :] |= near[:-1, :]
        grown[:-1, :] |= near[1:, :]
        grown[:, 1:] |= near[:, :-1]
        grown[:, :-1] |= near[:, 1:]
        near = grown
    return int((faint & ~near).sum())


def column_segments(mask, min_gap=1):
    """Runs of non-empty columns; runs separated by fewer than `min_gap` empty columns merge."""
    occupied = mask.any(axis=0)
    segments = []
    start = None
    gap = 0
    last = None
    for x, filled in enumerate(occupied):
        if filled:
            if start is None:
                start = x
            elif gap >= min_gap:
                segments.append((start, last + 1))
                start = x
            gap = 0
            last = x
        elif start is not None:
            gap += 1
    if start is not None:
        segments.append((start, last + 1))
    return segments

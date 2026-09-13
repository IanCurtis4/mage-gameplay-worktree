"""Prepare user-authorized generated sheets; never overwrite the source images.

Python + Pillow + numpy, offline. Removes connected neutral checkerboard areas,
preserves colored sprites/eye highlights, aligns feet, and shares one scale/palette
across each actor's 32 frames. Output is an actual 256x512 RGBA atlas.
"""
from collections import deque
from pathlib import Path
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/art/animation_sources'
DEST = ROOT / 'assets/art/animations'
CELL = 64
PIVOT = (32, 58)


def remove_matte(image):
    pixels = np.array(image.convert('RGBA')).copy()
    if pixels[:, :, 3].min() < 32:
        pixels[:, :, 3] = np.where(pixels[:, :, 3] >= 128, 255, 0)
        return Image.fromarray(pixels)
    rgb = pixels[:, :, :3].astype(np.int16)
    candidate = (rgb.min(axis=2) >= 172) & (rgb.max(axis=2) - rgb.min(axis=2) <= 16)
    h, w = candidate.shape
    visited = np.zeros((h, w), bool)
    for sy, sx in np.argwhere(candidate):
        if visited[sy, sx]:
            continue
        pending = deque([(int(sy), int(sx))])
        visited[sy, sx] = True
        component = []
        border = False
        low, high = 255, 0
        while pending:
            y, x = pending.popleft()
            component.append((y, x))
            shade = int(rgb[y, x, 0])
            low, high = min(low, shade), max(high, shade)
            border |= x == 0 or y == 0 or x == w - 1 or y == h - 1
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and candidate[ny, nx] and not visited[ny, nx]:
                    visited[ny, nx] = True
                    pending.append((ny, nx))
        # Interior bow/staff loops can enclose checkerboard. A flat white eye
        # highlight is not a two-tone checkerboard component and is preserved.
        if border or (len(component) > 80 and low < 220 and high > 235):
            ys, xs = zip(*component)
            pixels[ys, xs, 3] = 0
    return Image.fromarray(pixels)


def keep_character(frame):
    """Discard disconnected fragments spilling in from a neighbor's weapon/effect."""
    data = np.array(frame)
    mask = Image.fromarray(np.where(data[:, :, 3] > 128, 255, 0).astype(np.uint8))
    connected = mask.filter(ImageFilter.MaxFilter(3))
    ys, xs = np.where(np.array(connected) == 255)
    if not len(xs):
        return frame
    center = np.argmin((xs - frame.width * 0.5) ** 2 + (ys - frame.height * 0.55) ** 2)
    ImageDraw.floodfill(connected, (int(xs[center]), int(ys[center])), 128)
    data[:, :, 3] = np.where(np.array(connected) == 128, data[:, :, 3], 0)
    return Image.fromarray(data)


def foot_anchor(frame, box):
    data = np.array(frame)
    x0, y0, x1, y1 = box
    start = round(y1 - (y1 - y0) * 0.18)
    patch = data[start:y1, x0:x1]
    rgb = patch[:, :, :3].astype(float)
    boots = (patch[:, :, 3] > 128) & (rgb[:, :, 0] > rgb[:, :, 2] * 1.20) & (rgb[:, :, 0] > 35)
    ys, xs = np.where(boots)
    anchor_x = float(np.median(xs) + x0) if len(xs) > 16 else (x0 + x1) / 2
    return anchor_x, y1


def prepare(name):
    frames, bounds, anchors, source_sizes = [], [], [], []
    for suffix in ('', '_extra'):
        source_path = SOURCE / f'{name}{suffix}.png'
        if not source_path.exists():
            continue
        original = Image.open(source_path).convert('RGBA')
        source_sizes.append(original.size)
        for row in range(4):
            for col in range(4):
                region = (round(col * original.width / 4), round(row * original.height / 4),
                          round((col + 1) * original.width / 4), round((row + 1) * original.height / 4))
                frame = keep_character(remove_matte(original.crop(region)))
                box = frame.getchannel('A').getbbox()
                if not box:
                    raise ValueError(f'{name} frame {row * 4 + col} is empty')
                frames.append(frame)
                bounds.append(box)
                anchors.append(((box[0] + box[2]) / 2, box[3]) if suffix and row == 3 else foot_anchor(frame, box))
    if name == 'swordsman' and len(frames) == 32:
        # Generator turned the first rear windup toward the viewer. Start that
        # sequence from the approved rear idle instead of flashing a front face.
        frames[20], bounds[20], anchors[20] = frames[16].copy(), bounds[16], anchors[16]
    # Uniform scale avoids breathing/weapon poses pumping the body size.
    scale = 50.0 / float(np.median([b[3] - b[1] for b in bounds[:4]]))
    for box in bounds:
        scale = min(scale, 58.0 / (box[2] - box[0]), 56.0 / (box[3] - box[1]))
    atlas = Image.new('RGBA', (CELL * 4, CELL * (len(frames) // 4)))
    for index, (frame, box, anchor) in enumerate(zip(frames, bounds, anchors)):
        anchor = (max(box[2] - 29.0 / scale, min(anchor[0], box[0] + 29.0 / scale)), anchor[1])
        cropped = frame.crop(box)
        size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
        reduced = cropped.resize(size, Image.Resampling.LANCZOS)
        channels = np.array(reduced)
        channels[:, :, 3] = np.where(channels[:, :, 3] >= 128, 255, 0)
        reduced = Image.fromarray(channels)
        offset = (PIVOT[0] - round((anchor[0] - box[0]) * scale), PIVOT[1] - size[1])
        atlas.alpha_composite(reduced, (index % 4 * CELL + offset[0], index // 4 * CELL + offset[1]))
    atlas = atlas.quantize(colors=48, method=Image.Quantize.FASTOCTREE,
                           dither=Image.Dither.NONE).convert('RGBA')
    atlas.save(DEST / f'{name}.png')
    frame_boxes = []
    for index in range(len(frames)):
        box = (index % 4 * CELL, index // 4 * CELL, (index % 4 + 1) * CELL, (index // 4 + 1) * CELL)
        frame_boxes.append(atlas.crop(box).getchannel('A').getbbox())
    return {'source_sizes': source_sizes, 'atlas_size': atlas.size, 'cell_size': CELL,
            'pivot': PIVOT, 'scale': scale, 'frame_bounds': frame_boxes,
            'colors': len(atlas.getcolors(65536)), 'frames': len(frames)}


if __name__ == '__main__':
    DEST.mkdir(parents=True, exist_ok=True)
    report = {name: prepare(name) for name in ('swordsman', 'mage', 'warrior', 'archer')}
    (DEST / 'preparation_report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: {k: v for k, v in value.items() if k != 'frame_bounds'}
                      for key, value in report.items()}, indent=2))

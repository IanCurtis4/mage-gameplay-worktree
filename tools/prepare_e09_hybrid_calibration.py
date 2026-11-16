#!/usr/bin/env python3
"""E09 T7: author the 64-pose directional calibration of a hybrid body (offline, mechanical + reviewed).

For each of the 64 cells of `body.png` the tool finds the head (top row, centre) and proposes the two
palms from skin-coloured components, then writes `calibration.json` in the schema of the E08 classes
(`ragrpg_directional_animation_v2`: ground, main/off/arms slots with finger crops and per-weapon
overrides, head anchor). Hand-corrections that the review of the enlarged cells asked for live in
`calibration_authoring.json` next to the atlas; the tool never guesses a value that file overrides.

    python tools/prepare_e09_hybrid_calibration.py <kind> propose            # print summary, no write
    python tools/prepare_e09_hybrid_calibration.py <kind> overlay out.png    # enlarged cells with markers
    python tools/prepare_e09_hybrid_calibration.py <kind> write              # write calibration.json

`write` needs the packed atlas (`tools/prepare_e08_directional_art.py <kind> --atlas-only` first); the
packer then binds the manifest to the hash recorded here.
"""
from pathlib import Path
import hashlib
import json
import sys

sys.dont_write_bytecode = True
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/art/e08_characters/directional'
KINDS = ('paladin', 'thaumaturge', 'duelist', 'arcane_blade')
DIRECTIONS = ('south', 'north', 'east', 'west')
WEAPONS = ('sword', 'axe', 'staff', 'bow', 'shield', 'prismatic_focus', 'wooden_beads')
HALF_PI = 1.5707963267948966
ATTACK_LEGACY = {'sword': [-0.35, -0.85, 0.75, 0.22], 'axe': [-0.35, -0.85, 0.75, 0.22],
                 'staff': [0.10, 0.26, 0.28, 0.12], 'bow': [0.08, 0.05, 0.12, 0.14]}


def rgba_hash(image):
    data = bytearray(image.convert('RGBA').tobytes())
    for offset in range(0, len(data), 4):
        if data[offset + 3] == 0:
            data[offset:offset + 3] = bytes(3)
    return hashlib.sha256(data).hexdigest()


def cell_of(atlas, index):
    x, y = (index % 4) * 64, (index // 4) * 64
    return atlas[y:y + 64, x:x + 64]


def skin_mask(cell):
    rgb = cell[:, :, :3].astype(np.int16)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    return (cell[:, :, 3] > 128) & (r >= 170) & (r - g >= 22) & (r - g <= 60) & (g - b >= 10) & (g - b <= 31) & (r - b >= 40)


def components(mask):
    height, width = mask.shape
    seen = np.zeros_like(mask, bool)
    found = []
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or seen[y, x]:
                continue
            stack, pixels = [(y, x)], []
            seen[y, x] = True
            while stack:
                cy, cx = stack.pop()
                pixels.append((cy, cx))
                for ny in (cy - 1, cy, cy + 1):
                    for nx in (cx - 1, cx, cx + 1):
                        if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            stack.append((ny, nx))
            ys = [p[0] for p in pixels]
            xs = [p[1] for p in pixels]
            found.append({'area': len(pixels), 'cx': float(np.mean(xs)), 'cy': float(np.mean(ys)),
                          'box': (min(xs), min(ys), max(xs), max(ys)), 'pixels': pixels})
    return found


def merge_close(comps, gap=2):
    """Fingers and thumbs often split a hand into pieces: merge components whose boxes are <= gap apart."""
    groups = [dict(c) for c in comps]
    changed = True
    while changed:
        changed = False
        for i in range(len(groups)):
            for j in range(i + 1, len(groups)):
                a, b = groups[i]['box'], groups[j]['box']
                if a[0] - gap <= b[2] and b[0] - gap <= a[2] and a[1] - gap <= b[3] and b[1] - gap <= a[3]:
                    pixels = groups[i]['pixels'] + groups[j]['pixels']
                    ys = [q[0] for q in pixels]
                    xs = [q[1] for q in pixels]
                    groups[i] = {'area': len(pixels), 'cx': float(np.mean(xs)), 'cy': float(np.mean(ys)),
                                 'box': (min(xs), min(ys), max(xs), max(ys)), 'pixels': pixels}
                    del groups[j]
                    changed = True
                    break
            if changed:
                break
    return groups


def head_measure(cell):
    """Head top (first row with a run >= 4 px near the topmost opaque column mass) and centre column."""
    alpha = cell[:, :, 3] > 64
    rows = np.where(alpha.any(axis=1))[0]
    top = int(rows[0])
    centres = []
    for row in range(top + 2, top + 8):
        cols = np.where(alpha[row])[0]
        if len(cols):
            centres.append((cols[0] + cols[-1] + 1) / 2.0)
    return top, float(np.median(centres)) if centres else 32.0


def classify(cell, index, hints):
    """Return the two proposed palms (image-left, image-right) and the head anchor of a living pose."""
    top, centre = head_measure(cell)
    comps = [c for c in components(skin_mask(cell)) if c['area'] >= 2]
    # the face: skin component(s) near the head centre in the head rows
    hands = [c for c in comps if not (c['cy'] < top + 16 and abs(c['cx'] - centre) < 9)]
    hands.sort(key=lambda c: -c['area'])
    return top, centre, hands


def propose(atlas, hints):
    frames = []
    report = []
    for index in range(64):
        cell = cell_of(atlas, index)
        alpha = cell[:, :, 3] > 64
        rows = np.where(alpha.any(axis=1))[0]
        ground = int(rows[-1])
        top, centre = head_measure(cell)
        living = index % 16 < 14
        override = hints.get('frames', {}).get(str(index), {})
        pair = []
        if living:
            hands = merge_close([c for c in components(skin_mask(cell)) if c['area'] >= 2 and c['cy'] < ground - 9 and not (c['cy'] < top + 24 and abs(c['cx'] - centre) < 12)])
            hands.sort(key=lambda c: -c['area'])
            if index // 16 in (0, 1):  # south/north: one palm on each side of the body axis
                lefts = [c for c in hands if c['cx'] < centre - 3]
                rights = [c for c in hands if c['cx'] > centre + 3]
                pair = [lefts[0] if lefts else None, rights[0] if rights else None]
            else:  # east/west: [near, far]; the near hand is the larger skin patch, the far one may be hidden
                pair = hands[:2] + [None] * (2 - len(hands[:2]))
        report.append({'index': index, 'ground': ground, 'top': top, 'centre': centre, 'hands': [(round(c['cx'], 1), round(c['cy'], 1), c['area']) if c else None for c in pair]})
        frames.append({'ground': ground, 'top': top, 'centre': centre, 'pair': pair, 'override': override})
    return frames, report


def snap(cell, point, radius=2):
    """Move a point to the nearest opaque pixel (never leave a grip on transparency)."""
    x, y = int(round(point[0])), int(round(point[1]))
    best = None
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            px, py = x + dx, y + dy
            if 0 <= px < 64 and 0 <= py < 64 and cell[py, px, 3] > 128:
                d = dx * dx + dy * dy
                if best is None or d < best[0]:
                    best = (d, px, py)
    return (best[1], best[2]) if best else (x, y)


def torso_front(cell, near, facing):
    """Fallback for a hidden far hand: a body pixel just inside the front edge of the torso at the palm height."""
    x, y = int(round(near[0])), int(round(near[1])) - 2
    edge = x
    for step in range(0, 24):
        px = x + facing * step
        if 0 <= px < 64 and cell[y, px, 3] > 128:
            edge = px
    return (edge - facing * 2, y)


def finger_crop(cell, point):
    x, y = point
    x0 = min(max(x - 1, 0), 61)
    y0 = min(max(y - 1, 0), 61)
    return [x0, y0, 3, 3]


def overrides_for(direction, pose, flip_west):
    """Per-weapon angle at this pose; attack row follows the legacy swing, idle/walk rest angles."""
    result = {}
    sign = -1.0 if flip_west else 1.0
    attack = 8 <= pose <= 11
    for weapon in WEAPONS:
        if weapon == 'wooden_beads':
            result[weapon] = 0.0
        elif attack and weapon in ATTACK_LEGACY:
            result[weapon] = round(sign * ATTACK_LEGACY[weapon][pose - 8], 3)
        else:
            profile = {'sword': 0.20, 'axe': 0.22, 'staff': 0.30, 'bow': 0.65, 'shield': 0.0, 'prismatic_focus': -0.10}[weapon]
            result[weapon] = round(sign * profile, 3)
    return result


def build(kind, write=False, overlay=None):
    folder = BASE / kind
    atlas_image = Image.open(folder / 'body.png').convert('RGBA')
    atlas = np.array(atlas_image)
    hints_path = folder / 'calibration_authoring.json'
    hints = json.loads(hints_path.read_text(encoding='utf-8')) if hints_path.exists() else {}
    frames, report = propose(atlas, hints)
    out = []
    marks = {}
    for index, f in enumerate(frames):
        direction = DIRECTIONS[index // 16]
        pose = index % 16
        cell = cell_of(atlas, index)
        override = f['override']
        living = pose < 14
        west = direction == 'west'
        head_c = override.get('head', [round(f['centre']), f['top'] + 8])
        head = {'point': [int(head_c[0]), int(head_c[1])], 'angle': float(override.get('head_angle', 0.0)), 'depth': 1, 'flip': False, 'visible': True}
        slots = {}
        if living:
            pair = f['pair']
            guess = [(c['cx'], c['cy']) if c else None for c in pair]
            left = override.get('left', guess[0] if len(guess) > 0 and guess[0] else (f['centre'] - 10, f['top'] + 30))
            right = override.get('right', guess[1] if len(guess) > 1 and guess[1] else (f['centre'] + 10, f['top'] + 30))
            left, right = snap(cell, left), snap(cell, right)
            # anatomical right hand = main: south -> image left, north -> image right, east -> near, west -> far
            if direction == 'south':
                main, off = left, right
            elif direction == 'north':
                main, off = right, left
            else:
                near_guess = pair[0]
                far_guess = pair[1]
                facing = 1 if direction == 'east' else -1
                near = override.get('near', (near_guess['cx'], near_guess['cy']) if near_guess else (f['centre'] + facing * 2, f['top'] + 30))
                if 'far' in override:
                    far = override['far']
                elif far_guess:
                    far = (far_guess['cx'], far_guess['cy'])
                else:
                    far = torso_front(cell, near, facing)
                near, far = snap(cell, near), snap(cell, far)
                main, off = (near, far) if direction == 'east' else (far, near)
            default_depth = {'south': (1, 1), 'north': (0, 0)}.get(direction, None)
            if default_depth is None:
                main_depth, off_depth = (1, 0) if direction == 'east' else (0, 1)
            else:
                main_depth, off_depth = default_depth
            main_depth = int(override.get('main_depth', main_depth))
            off_depth = int(override.get('off_depth', off_depth))
            marks[index] = {'main': main, 'off': off}
            for name, point, depth in (('main_hand', main, main_depth), ('off_hand', off, off_depth)):
                slots[name] = {'point': list(point), 'fingers': finger_crop(cell, point), 'angle': 0.0, 'depth': depth, 'flip': west,
                               'angle_overrides': overrides_for(direction, pose, west)}
            slots['arms'] = {'point': list(main), 'fingers': [main[0], main[1], 1, 1], 'angle': 0.0, 'depth': main_depth, 'flip': west}
        else:
            ground = f['ground']
            alpha = cell[:, :, 3] > 64
            cols = np.where(alpha.any(axis=0))[0]
            lo, hi = int(cols[0]), int(cols[-1])
            span = hi - lo
            left_x = int(override.get('drop_left', lo + span * 0.3))
            right_x = int(override.get('drop_right', lo + span * 0.7))
            y = ground - 2
            both = {w: HALF_PI for w in WEAPONS}
            both['wooden_beads'] = 0.0
            main_x, off_x = (left_x, right_x) if direction in ('south', 'east') else (right_x, left_x) if direction == 'north' else (left_x, right_x)
            for name, x in (('main_hand', main_x), ('off_hand', off_x)):
                slots[name] = {'point': [x, y], 'fingers': [x - 1, y - 1, 3, 3], 'angle': 0.0, 'depth': 0, 'flip': west,
                               'angle_overrides': dict(both), 'depth_overrides': {}}
            slots['arms'] = {'point': [main_x, y], 'fingers': [main_x, y, 1, 1], 'angle': 0.0, 'depth': 0, 'flip': west,
                             'angle_overrides': dict(both), 'depth_overrides': {}}
            head['depth'] = 1
        out.append({'ground_y': f['ground'], 'slots': slots, 'head': head})
    return out, report, marks, atlas_image


def overlay_sheet(atlas_image, frames, marks, path, zoom=8, box=(8, 6, 56, 60)):
    """Enlarged, cropped cells with a coordinate grid (ticks every 4 px, labels every 8) and the proposed points."""
    colors = {'main': (255, 40, 40, 255), 'off': (40, 120, 255, 255), 'head': (40, 255, 60, 255)}
    bw, bh = box[2] - box[0], box[3] - box[1]
    for direction in range(4):
        sheet = Image.new('RGBA', (4 * bw * zoom, 4 * bh * zoom), (70, 100, 60, 255))
        draw = ImageDraw.Draw(sheet)
        for local in range(16):
            index = direction * 16 + local
            cell = atlas_image.crop(((index % 4) * 64, (index // 4) * 64, (index % 4) * 64 + 64, (index // 4) * 64 + 64))
            tile = Image.new('RGBA', (64, 64), (70, 100, 60, 255))
            tile.alpha_composite(cell)
            big = tile.crop(box).resize((bw * zoom, bh * zoom), Image.NEAREST)
            ox, oy = (local % 4) * bw * zoom, (local // 4) * bh * zoom
            sheet.alpha_composite(big, (ox, oy))
            for gx in range(box[0], box[2], 4):
                X = ox + (gx - box[0]) * zoom
                draw.line([X, oy, X, oy + (6 if gx % 8 else 12)], fill=(255, 255, 0, 255))
                if gx % 8 == 0:
                    draw.text((X + 2, oy + 12), str(gx), fill=(255, 255, 0, 255))
            for gy in range(box[1], box[3], 4):
                Y = oy + (gy - box[1]) * zoom
                draw.line([ox, Y, ox + (6 if gy % 8 else 12), Y], fill=(255, 255, 0, 255))
                if gy % 8 == 0:
                    draw.text((ox + 14, Y - 5), str(gy), fill=(255, 255, 0, 255))
            f = frames[index]
            for name, key in (('main_hand', 'main'), ('off_hand', 'off')):
                p = f['slots'][name]['point']
                X, Y = ox + (p[0] - box[0]) * zoom, oy + (p[1] - box[1]) * zoom
                draw.rectangle([X, Y, X + zoom - 1, Y + zoom - 1], outline=colors[key], width=2)
            h = f['head']['point']
            X, Y = ox + (h[0] - box[0]) * zoom, oy + (h[1] - box[1]) * zoom
            draw.rectangle([X, Y, X + zoom - 1, Y + zoom - 1], outline=colors['head'], width=2)
            draw.text((ox + bw * zoom - 24, oy + bh * zoom - 14), str(index), fill=(255, 255, 255, 255))
        sheet.save(str(path).replace('.png', '_%s.png' % DIRECTIONS[direction]))


def main():
    kind, command = sys.argv[1], sys.argv[2]
    if kind not in KINDS:
        raise SystemExit('kind must be one of %s' % (KINDS,))
    frames, report, marks, atlas_image = build(kind)
    if command == 'propose':
        for r in report:
            print(json.dumps(r))
    elif command == 'overlay':
        overlay_sheet(atlas_image, frames, marks, sys.argv[3])
    elif command == 'write':
        folder = BASE / kind
        data = {'actor_kind': kind, 'authored_rgba_sha256': rgba_hash(atlas_image),
                'author': 'Terra (E09 T7): skin-component palm proposal plus reviewed corrections; native inspection recorded in delivery.md',
                'notes': {'order': 'south,north,east,west; idle4 walk4 action4 hurt2 death2',
                          'main_hand': 'anatomical right: S left, N right, E near, W far',
                          'tool': 'tools/prepare_e09_hybrid_calibration.py with calibration_authoring.json'},
                'frames': frames}
        (folder / 'calibration.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
        print('wrote', folder / 'calibration.json', data['authored_rgba_sha256'])


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""E08 P7-C6 head-fit data tool (mechanical, no generative art).

Measures, per class / direction / pose, the head of the atlas the renderer really
draws when a head piece is equipped (bare_head.png when declared, otherwise
weaponless.png), and, per head piece / view, the painted piece bounds. Writes
scripts/actors/equipment_head_fit_data.gd (a GDScript const so it is exported with the other
scripts; *.json outside the export include filter would be dropped), consumed by EquipmentHeadVisual.

  python tools/prepare_e08_head_fit.py write
  python tools/prepare_e08_head_fit.py sheet <kind> <piece> <out.png> [poses]

The fitting formula lives in scripts/actors/equipment_head_visual.gd (fit()); the
preview below mirrors it so contact sheets can be judged before native capture."""
import json, sys, math
import numpy as np
from PIL import Image

KINDS = ['archer', 'berserker', 'defender', 'elementalist', 'geometer', 'hunter', 'mage', 'sentinel', 'spiritualist', 'swordsman',
         'arcane_blade', 'duelist', 'paladin', 'thaumaturge']  # E09 T7: the four hybrid bodies
BASE = 'assets/art/e08_characters/directional/'
HEAD = 'assets/art/equipment/headgear/'
OUT = 'scripts/actors/equipment_head_fit_data.gd'
# mode: cover = seated over the crown (hair top hidden); band = rests on the hairline.
# width_k: piece width / measured head width.  drop: where the piece's painted top lands,
# measured from the head top in head widths (negative = above the hair).  vk: vertical vs horizontal scale.
PIECES = {
    'class_set_archer_head': {'mode': 'cover', 'width_k': 1.14, 'drop': -0.06, 'vk': 0.9},
    'class_set_berserker_head': {'mode': 'cover', 'width_k': 1.14, 'drop': -0.2, 'vk': 1.25},
    'class_set_defender_head': {'mode': 'cover', 'width_k': 1.1, 'drop': -0.1, 'vk': 0.72},
    'class_set_elementalist_head': {'mode': 'band', 'width_k': 1.06, 'drop': 0.08, 'vk': 1.0},
    'class_set_hunter_head': {'mode': 'cover', 'width_k': 1.14, 'drop': -0.12, 'vk': 0.9},
    'class_set_mage_head': {'mode': 'cover', 'width_k': 1.12, 'drop': -0.02, 'vk': 0.9},
    'class_set_mg_ar_head': {'mode': 'band', 'width_k': 1.08, 'drop': 0.2, 'vk': 1.0},
    'class_set_sentinel_head': {'mode': 'cover', 'width_k': 1.25, 'drop': -0.02, 'vk': 0.9},
    'class_set_spiritualist_head': {'mode': 'cover', 'width_k': 1.12, 'drop': -0.02, 'vk': 0.9},
    'class_set_swordsman_head': {'mode': 'cover', 'width_k': 1.14, 'drop': -0.14, 'vk': 1.15},
    'pilot_head': {'mode': 'cover', 'width_k': 1.1, 'drop': -0.02, 'vk': 0.9},
    'shared_set_high_head': {'mode': 'band', 'width_k': 1.08, 'drop': 0.2, 'vk': 1.0},
    'shared_set_low_head': {'mode': 'cover', 'width_k': 1.14, 'drop': -0.02, 'vk': 0.9},
    'shared_set_mid_head': {'mode': 'cover', 'width_k': 1.1, 'drop': 0.0, 'vk': 1.0},
}


def atlas(kind):
    p = json.load(open(BASE + kind + '/presentation.json'))
    name = 'bare_head.png' if 'bare_head' in p else 'weaponless.png'
    return p, np.array(Image.open(BASE + kind + '/' + name).convert('RGBA'))


def runs_for(c, ax, ay):
    runs = {}
    for r in range(0, min(64, ay + 14)):
        cols = np.where(c[r])[0]
        if len(cols) == 0:
            continue
        near = cols[np.argmin(abs(cols - ax))]
        if abs(near - ax) > 12:
            continue
        a = b = near
        while a > 0 and c[r, a - 1]:
            a -= 1
        while b < 63 and c[r, b + 1]:
            b += 1
        if b - a + 1 >= 4:
            runs[r] = (a, b)
    return runs


def measure(kind):
    p, im = atlas(kind)
    raw = []
    for f in range(64):
        cx, cy = (f % 4) * 64, (f // 4) * 64
        c = im[cy:cy + 64, cx:cx + 64, 3] > 64
        ax, ay = p['frames'][f]['head']['point']
        runs = runs_for(c, ax, ay)
        top = min(runs) if runs else ay - 8
        raw.append((runs, top))
    dirs = []
    for d in range(4):
        ws = []
        for pose in range(14):
            runs, top = raw[d * 16 + pose]
            ws += [b - a + 1 for r, (a, b) in runs.items() if top + 3 <= r <= top + 9]
        w = float(np.median(ws))
        cs = []
        for pose in range(14):
            runs, top = raw[d * 16 + pose]
            cs += [(a + b + 1) / 2 for r, (a, b) in runs.items() if top + 3 <= r <= top + 9 and abs((b - a + 1) - w) <= 2]
        dirs.append((w, float(np.median(cs))))
    frames = []
    for f in range(64):
        d = f // 16
        w, cdir = dirs[d]
        runs, top = raw[f]
        cs = [(a + b + 1) / 2 for r, (a, b) in runs.items() if top + 2 <= r <= top + 6 and abs((b - a + 1) - w) <= 3]
        c = float(np.median(cs)) if len(cs) >= 2 else cdir
        # a raised hand/arm can merge with the crown run: the head never leaves +-5 px of its direction centre
        c = round(min(max(c, cdir - 5), cdir + 5) * 2) / 2
        # second pass: head top = first row with a >=4 px opaque run within +-12 px of the head centre
        # (the same rule tests/e08_equipment_art_test.gd applies independently to the drawn pixels)
        cx0, cy0 = (f % 4) * 64, (f // 4) * 64
        cell = im[cy0:cy0 + 64, cx0:cx0 + 64, 3] > 64
        lo, hi = max(0, int(c) - 12), min(64, int(c) + 13)
        top = None
        for r in range(50):
            run = 0
            for col in range(lo, hi):
                run = run + 1 if cell[r, col] else 0
                if run >= 4:
                    top = r
                    break
            if top is not None:
                break
        if top is None:
            top = raw[f][1]
        frames.append([c, int(top), w])
    offs = []
    for d in range(4):
        pts = [(frames[d * 16 + q][0] - p['frames'][d * 16 + q]['head']['point'][0],
                frames[d * 16 + q][1] - p['frames'][d * 16 + q]['head']['point'][1]) for q in range(4)]
        offs.append([float(np.median([x for x, _ in pts])), float(np.median([y for _, y in pts]))])
    return {'frames': frames, 'rotated_offset': offs, 'source': 'bare_head.png' if 'bare_head' in p else 'weaponless.png'}


def piece_views(pid):
    im = np.array(Image.open(HEAD + pid + '.png').convert('RGBA'))[:, :, 3] > 64
    out = []
    for v in range(4):
        c = im[:, v * 96:v * 96 + 96]
        ys = np.where(c.any(1))[0]
        y0 = ys[0]
        lim = int(y0 + 0.6 * (ys[-1] + 1 - y0))
        xs2 = np.where(c[y0:lim].any(0))[0]
        full = np.array(Image.open(HEAD + pid + '.png').convert('RGBA'))[:, v * 96:v * 96 + 96, 3] > 0
        fy = np.where(full.any(1))[0]
        fx = np.where(full.any(0))[0]
        out.append({'bx0': fx[0] / 4.0, 'bx1': (fx[-1] + 1) / 4.0, 'by0': fy[0] / 4.0, 'by1': (fy[-1] + 1) / 4.0, 'cx': round((xs2[0] + xs2[-1] + 1) / 8.0, 3), 'y0': round(y0 / 4.0, 3),
                    'w': round((xs2[-1] + 1 - xs2[0]) / 4.0, 3), 'h': round((ys[-1] + 1 - y0) / 4.0, 3)})
    return out


def build():
    data = {'format': 'ragrpg_head_fit_v1', 'cell': 24, 'classes': {}, 'pieces': {}}
    for k in KINDS:
        data['classes'][k] = measure(k)
    for pid, prm in PIECES.items():
        e = dict(prm)
        e['views'] = piece_views(pid)
        data['pieces'][pid] = e
    return data


def fit(data, kind, pid, frame, authored):
    """Mirror of EquipmentHeadVisual.fit(): (head top centre, angle, sx, sy, view, drop px)."""
    cl = data['classes'][kind]
    pc = data['pieces'][pid]
    d = frame // 16
    c, t, w = cl['frames'][frame]
    ang = authored['angle']
    ax, ay = authored['point']
    if frame % 16 >= 14:
        ox, oy = cl['rotated_offset'][d]
        ca, sa = math.cos(ang), math.sin(ang)
        c, t = ax + ox * ca - oy * sa, ay + ox * sa + oy * ca
    v = pc['views'][d]
    s = pc['width_k'] * w / v['w']
    return (c, t), ang, s, s * pc['vk'], v, pc['drop'] * w


def sheet(kind, pid, out, poses):
    data = build()
    p, im = atlas(kind)
    hat = Image.open(HEAD + pid + '.png').convert('RGBA')
    Z = 6
    sh = Image.new('RGBA', (64 * Z * len(poses), 64 * Z * 4), (90, 130, 60, 255))
    for d in range(4):
        for k, pose in enumerate(poses):
            f = d * 16 + pose
            cx, cy = (f % 4) * 64, (f // 4) * 64
            cell = Image.fromarray(im[cy:cy + 64, cx:cx + 64])
            big = Image.new('RGBA', (64 * Z, 64 * Z), (90, 130, 60, 255))
            big.alpha_composite(cell.resize((64 * Z, 64 * Z), Image.NEAREST))
            (hx, ht), ang, sx, sy, v, drop = fit(data, kind, pid, f, p['frames'][f]['head'])
            piece = hat.crop((d * 96, 0, d * 96 + 96, 96))
            tw, th = int(24 * sx * Z), int(24 * sy * Z)
            pr = piece.resize((max(1, tw), max(1, th)), Image.LANCZOS)
            ox, oy = v['cx'] * sx * Z, v['y0'] * sy * Z
            layer = Image.new('RGBA', (64 * Z * 2, 64 * Z * 2), (0, 0, 0, 0))
            px, py = int(hx * Z - ox) + 64 * Z // 2, int((ht + drop) * Z - oy) + 64 * Z // 2
            layer.alpha_composite(pr, (px, py))
            if ang:
                layer = layer.rotate(-math.degrees(ang), center=(hx * Z + 64 * Z // 2, (ht + drop) * Z + 64 * Z // 2), resample=Image.BICUBIC)
            layer = layer.crop((64 * Z // 2, 64 * Z // 2, 64 * Z // 2 + 64 * Z, 64 * Z // 2 + 64 * Z))
            big.alpha_composite(layer)
            sh.alpha_composite(big, (k * 64 * Z, d * 64 * Z))
    sh.save(out)


if __name__ == '__main__':
    if sys.argv[1] == 'write':
        text = json.dumps(build(), separators=(',', ':'))
        header = '\n'.join(['class_name EquipmentHeadFitData', 'extends RefCounted',
                            '## Generated by tools/prepare_e08_head_fit.py; do not edit by hand.', 'const DATA := '])
        open(OUT, 'w', encoding='utf8', newline='\n').write(header + text + '\n')
        print('wrote', OUT)
    elif sys.argv[1] == 'sheet':
        poses = [int(x) for x in (sys.argv[5] if len(sys.argv) > 5 else '0,4,8,12').split(',')]
        sheet(sys.argv[2], sys.argv[3], sys.argv[4], poses)

"""Mechanical packing of generated Spiritualist sources; never synthesizes art/rigs."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import sys
sys.dont_write_bytecode = True
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/art/e08_characters/directional/spiritualist'
SOURCES = ['south_source_v3.png', 'north_source_v1.png', 'east_source_v2.png', 'west_source_v2.png']
# Imagegen fixed the extra arm only in this cell; preserve the other 63 source cells.
OVERRIDES = {(2, 6): 'east_source_v3.png'}


def build_atlas():
    spec = importlib.util.spec_from_file_location('animation_pipeline', ROOT / 'tools/prepare_animation_assets.py')
    pipeline = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pipeline)
    frames, boxes, records = [], [], []
    for direction, source_name in enumerate(SOURCES):
        for pose in range(16):
            selected = OVERRIDES.get((direction, pose), source_name)
            source = Image.open(DEST / selected).convert('RGBA')
            row, col = divmod(pose, 4)
            region = (round(col * source.width / 4), round(row * source.height / 4),
                      round((col + 1) * source.width / 4), round((row + 1) * source.height / 4))
            frame = pipeline.keep_character(pipeline.remove_matte(source.crop(region)))
            box = frame.getchannel('A').getbbox()
            if not box:
                raise ValueError(f'Empty source cell: {selected}/{pose}')
            frames.append(frame)
            boxes.append(box)
            records.append({'source': selected, 'pose': pose, 'source_region': list(region), 'source_bounds': list(box)})
    scale = 50.0 / float(np.median([b[3] - b[1] for b in boxes[:4]]))
    for box in boxes:
        scale = min(scale, 58.0 / (box[2] - box[0]), 56.0 / (box[3] - box[1]))
    atlas = Image.new('RGBA', (256, 1024))
    for index, (frame, box) in enumerate(zip(frames, boxes)):
        crop = frame.crop(box)
        size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
        reduced = crop.resize(size, Image.Resampling.LANCZOS)
        pixels = np.array(reduced)
        pixels[:, :, 3] = np.where(pixels[:, :, 3] >= 128, 255, 0)
        pixels[pixels[:, :, 3] == 0, :3] = 0
        reduced = Image.fromarray(pixels)
        # Do not snap to the lowest boot: the lifted/leading foot alternates in profile.
        # Keep the authored cell support centered and align its ground vertically.
        offset = (32 - size[0] // 2, 58 - size[1])
        atlas.alpha_composite(reduced, ((index % 4) * 64 + offset[0], (index // 4) * 64 + offset[1]))
        records[index].update({'size': list(size), 'offset': list(offset),
                               'x_delta_from_preliminary_bbox_center': offset[0] - (32 - size[0] // 2)})
    return atlas, {'scale': scale, 'frames': records}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--atlas-only', action='store_true', help='Explicit authorship stage; no presentation manifest is written.')
    args = parser.parse_args()
    calibration = None
    if not args.atlas_only:
        path = DEST / 'calibration.json'
        if not path.is_file():
            raise SystemExit(f'Missing authored calibration: {path}. No atlas or manifest written.')
        calibration = json.loads(path.read_text(encoding='utf-8'))
        if calibration.get('actor_kind') != 'spiritualist' or len(calibration.get('frames', [])) != 64:
            raise SystemExit('Invalid authored calibration: expected spiritualist and 64 frames.')
    atlas, report = build_atlas()
    if calibration is not None:
        for index, frame in enumerate(calibration['frames']):
            tile = atlas.crop((index % 4 * 64, index // 4 * 64, index % 4 * 64 + 64, index // 4 * 64 + 64))
            if tile.getchannel('A').getbbox()[3] - 1 != frame['ground_y']:
                raise SystemExit(f'Authored calibration no longer matches pixels: ground {index}')
    canonical = bytearray(atlas.convert('RGBA').tobytes())
    for pixel in range(0, len(canonical), 4):
        if canonical[pixel + 3] == 0:
            canonical[pixel:pixel + 3] = bytes(3)
    if calibration is not None and hashlib.sha256(canonical).hexdigest() != calibration.get('authored_rgba_sha256'):
        raise SystemExit('Authored calibration no longer matches the reviewed raster hash.')
    atlas.save(DEST / 'body.png')
    atlas.save(DEST / 'weaponless.png')
    rgba = np.array(atlas.convert('RGBA'))
    rgba[rgba[:, :, 3] == 0, :3] = 0
    digest = hashlib.sha256(rgba.tobytes()).hexdigest()
    if calibration is not None:
        base = 'res://assets/art/e08_characters/directional/spiritualist/'
        manifest = {'format': 'ragrpg_directional_animation_v2', 'actor_kind': 'spiritualist', 'pivot': [32, 58],
                    'body': {'path': base + 'body.png', 'rgba_sha256': digest},
                    'weaponless': {'path': base + 'weaponless.png', 'rgba_sha256': digest}, 'frames': calibration['frames']}
        (DEST / 'presentation.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + chr(10), encoding='utf-8')
    report.update({'rgba_sha256': digest, 'mode': 'atlas_only_not_calibrated' if args.atlas_only else 'authored_unit'})
    print(json.dumps(report))


if __name__ == '__main__':
    main()

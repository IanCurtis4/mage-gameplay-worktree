#!/usr/bin/env python3
"""E10a T8: author the 64-pose directional calibration of the Acolyte family bodies (offline, mechanical + reviewed).

Thin wrapper over `tools/prepare_e09_hybrid_calibration.py` (same detector, same schema, same overlay sheets):
it only widens the identity list to `acolyte`, `priest` and `cultist` and stamps the E10a author line. The
hand-corrections that review of the enlarged cells asked for live in `calibration_authoring.json` next to
each atlas; the tool never guesses a value that file overrides.

    python tools/prepare_e10a_family_calibration.py <kind> propose            # print summary, no write
    python tools/prepare_e10a_family_calibration.py <kind> overlay out.png    # enlarged cells with markers
    python tools/prepare_e10a_family_calibration.py <kind> write              # write calibration.json
    python tools/prepare_e10a_family_calibration.py <kind> provenance         # write provenance.json (v2, body + weaponless)

`write` needs the packed atlas (`tools/prepare_e08_directional_art.py <kind> --atlas-only` first); the
packer then binds the manifest to the hash recorded here.
"""
from pathlib import Path
import importlib.util
import json
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location('e09_hybrid_calibration', HERE / 'prepare_e09_hybrid_calibration.py')
base = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(base)

KINDS = ('acolyte', 'priest', 'cultist')


def skin_mask(cell):
    """Pinker than the E09 mask: the cream robes of this family (r-g ~ 20, g-b ~ 12) fell inside the E09 thresholds.

    Measured on the Acolyte: palms r-g 40-56 and g-b 21-27; cream robe r-g 20 and g-b 12; sleeve shadow r-g 25.
    """
    np = base.np
    rgb = cell[:, :, :3].astype(np.int16)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    return (cell[:, :, 3] > 128) & (r >= 200) & (r - g >= 34) & (r - g <= 62) & (g - b >= 16) & (g - b <= 34)


base.skin_mask = skin_mask


SOURCES = {  # kind -> (batch folder in assets/art, native view sheet names are read from the batch selection.json)
    'acolyte': 'e08_codex_1116/characters/acolyte',
    'priest': 'e08_codex_1118/characters/priest',
    'cultist': 'e08_codex_1118/characters/cultist',
}
# The Acolyte sheets differ in scale (east 0.87, west 0.84, north 1.12 of the south idle height): the pipeline's
# normalize_scale step brought them to the south height before packing (nearest, no smoothing); steps recorded below.
NORMALIZED = {'acolyte': {'north': 'north_normalized.png', 'east': 'east_normalized.png', 'west': 'west_normalized.png'}}


def build_provenance(kind):
    import hashlib
    root = base.ROOT
    folder = base.BASE / kind
    packer_spec = importlib.util.spec_from_file_location('directional_packer', HERE / 'prepare_e08_directional_art.py')
    packer = importlib.util.module_from_spec(packer_spec)
    packer_spec.loader.exec_module(packer)
    recipe = json.loads((folder / 'source_recipe.json').read_text(encoding='utf-8'))
    atlas, report = packer.build_unit(folder, recipe)
    selection_rel = 'assets/art/%s/selection.json' % SOURCES[kind]
    selection = json.loads((root / selection_rel).read_text(encoding='utf-8'))['selections']
    sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
    refs, posts = [], []
    for view in ('south', 'north', 'east', 'west'):
        entry = selection[view]
        source_path = 'assets/art/%s/%s' % (SOURCES[kind], entry['path'])
        refs.append({'path': source_path, 'sha256': entry['sha256']})
        used, used_sha = source_path, entry['sha256']
        if view in NORMALIZED.get(kind, {}):
            used = 'assets/art/e08_characters/directional/%s/%s' % (kind, NORMALIZED[kind][view])
            used_sha = sha(root / used)
            posts.append({'tool': 'art_pipeline.normalize_scale', 'version': '1.0.0',
                          'params': {'view': view, 'reference_view': 'south', 'filter': 'nearest', 'smoothing': False},
                          'input_sha256': entry['sha256'], 'output_sha256': used_sha})
        posts.append({'tool': 'tools/prepare_e08_directional_art.py', 'version': 'e10a-t8',
                      'params': {'actor_kind': kind, 'view': view, 'source': used, 'target_height': recipe['target_height'],
                                 'scale': report['scale'], 'grid': [4, 4], 'native_cells': False, 'selection': selection_rel},
                      'input_sha256': used_sha, 'output_sha256': sha(folder / 'body.png')})
    records = []
    for name in ('body.png', 'weaponless.png'):
        records.append({
            'path': 'assets/art/e08_characters/directional/%s/%s' % (kind, name), 'sha256': sha(folder / name),
            'width': atlas.width, 'height': atlas.height, 'kind': 'other',
            'generator': {'name': 'ragrpg directional packer (derived from Codex sheets)', 'model': None, 'host': 'local', 'version': 'e10a-t8'},
            'request': '%s directional atlas V2, 64 poses, derived from the selected views; no new generation' % kind,
            'prompt': '', 'negative_prompt': None, 'seed': None,
            'params': {'scale': report['scale'], 'cell': 64, 'atlas': '256x1024'},
            'refs': refs, 'post': posts, 'selected': True,
            'review': {'status': 'pending', 'date': '2026-11-18',
                       'notes': 'Technical native capture by Terra (E10a T8, docs/epics/e10a/t8_delivery.md); product acceptance belongs to the user.'},
            'terms': 'Derived from the Codex built-in imagegen sheets of assets/art/%s (terms and exact prompts in that provenance.json).' % SOURCES[kind],
            'measurements': {'rgba_sha256': report['rgba_sha256']}})
    return {'schema': 'ragrpg_art_provenance_v2', 'path_base': 'project', 'records': records}


def apply_main_hand_angles(kind, frames):
    """`main_hand_angle` in calibration_authoring.json: {direction: radians} added to the main-hand slot angle of the living poses.

    The three family props are not in the directional weapon keys, so they get no per-weapon override: their angle is
    the profile angle plus this slot angle. The scepter (profile 0.2) leaned onto the face in the south and east views;
    the Priest, its typical bearer, leans it away from the head with this slot angle.
    """
    path = base.BASE / kind / 'calibration_authoring.json'
    hints = json.loads(path.read_text(encoding='utf-8')) if path.exists() else {}
    for direction, angle in hints.get('main_hand_angle', {}).items():
        first = base.DIRECTIONS.index(direction) * 16
        for pose in range(14):
            frames[first + pose]['slots']['main_hand']['angle'] = float(angle)


def main():
    kind, command = sys.argv[1], sys.argv[2]
    if kind not in KINDS:
        raise SystemExit('kind must be one of %s' % (KINDS,))
    frames, report, marks, atlas_image = base.build(kind)
    apply_main_hand_angles(kind, frames)
    if command == 'propose':
        for r in report:
            print(json.dumps(r))
    elif command == 'overlay':
        base.overlay_sheet(atlas_image, frames, marks, sys.argv[3], box=(8, 4, 56, 60))  # y ticks start at 4: labels every 8 px on both axes
    elif command == 'provenance':
        data = build_provenance(kind)
        (base.BASE / kind / 'provenance.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
        print('wrote provenance.json for', kind)
    elif command == 'write':
        folder = base.BASE / kind
        data = {'actor_kind': kind, 'authored_rgba_sha256': base.rgba_hash(atlas_image),
                'author': 'Terra (E10a T8): skin-component palm proposal plus reviewed corrections; native inspection recorded in delivery.md',
                'notes': {'order': 'south,north,east,west; idle4 walk4 action4 hurt2 death2',
                          'main_hand': 'anatomical right: S left, N right, E near, W far',
                          'tool': 'tools/prepare_e10a_family_calibration.py with calibration_authoring.json'},
                'frames': frames}
        (folder / 'calibration.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
        print('wrote', folder / 'calibration.json', data['authored_rgba_sha256'])


if __name__ == '__main__':
    main()

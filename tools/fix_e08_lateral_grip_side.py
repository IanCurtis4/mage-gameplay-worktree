"""Correct the lateral weapon hand of the directional player rigs.

Several rigs kept ``main_hand`` on the same screen side in both profile views.
In one view that is the far/back hand: bows were drawn behind the body with the
arrow crossing it, swords swung away from the target and the Berserker strike
landed with an empty fist. The audited plan below swaps the authored
``main_hand``/``off_hand`` palms (point, fingers, depth, angles and overrides
travel with their palm) only in the listed poses of the inverted view. ``arms``
keeps its authored offset from the main palm. Pixels, S/N, deaths, heads and
the correct view are untouched. Casters (mage, elementalist, spiritualist,
geometer) keep their authored staff hand: the other palm performs the cast.

Usage: python tools/fix_e08_lateral_grip_side.py [--check]
"""
import copy
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
EAST, WEST = 2, 3
LIVING_POSES = tuple(range(0, 14))
# kind: (inverted profile view, poses to correct, action poses that must lead)
PLAN = {
    'archer': (WEST, LIVING_POSES, (8, 9, 10)),
    'swordsman': (WEST, LIVING_POSES, (8, 9, 10)),
    'defender': (WEST, LIVING_POSES, (8, 9, 10)),
    'sentinel': (EAST, LIVING_POSES, (8, 9, 10)),
    'hunter': (EAST, LIVING_POSES, (8, 9, 10)),
    # Windup stays raised behind, as the authored W swing; only the impact moves.
    'berserker': (EAST, (10,), (10,)),
}


def leads(frames, view, poses):
    """True when every listed main_hand palm is on the target side."""
    sign = 1 if view == EAST else -1
    for pose in poses:
        slots = frames[view * 16 + pose]['slots']
        if sign * (slots['main_hand']['point'][0] - slots['off_hand']['point'][0]) <= 0:
            return False
    return True


def swap_frame(frame):
    slots = frame['slots']
    old_main, old_off, old_arms = slots['main_hand'], slots['off_hand'], slots['arms']
    new_main, new_off = copy.deepcopy(old_off), copy.deepcopy(old_main)
    arms = copy.deepcopy(old_arms)
    dx = old_arms['point'][0] - old_main['point'][0]
    dy = old_arms['point'][1] - old_main['point'][1]
    point = [new_main['point'][0] + dx, new_main['point'][1] + dy]
    shift = [point[0] - old_arms['point'][0], point[1] - old_arms['point'][1]]
    attributes = [key for key in old_arms if key not in ('point', 'fingers')]
    if all(old_arms.get(key) == old_main.get(key) for key in attributes):
        for key in attributes:
            if key in new_main:
                arms[key] = copy.deepcopy(new_main[key])
    arms['point'] = point
    fingers = old_arms['fingers']
    arms['fingers'] = [fingers[0] + shift[0], fingers[1] + shift[1], fingers[2], fingers[3]]
    slots['main_hand'], slots['off_hand'], slots['arms'] = new_main, new_off, arms


def corrected(kind, frames):
    """Returns frames with the audited inverted poses corrected."""
    view, poses, strike = PLAN[kind]
    other = EAST if view == WEST else WEST
    if not leads(frames, other, strike):
        raise SystemExit('Reference view does not lead; refusing: ' + kind)
    if any(leads(frames, view, (pose,)) for pose in strike):
        raise SystemExit('Inverted view already leads (already corrected?): ' + kind)
    result = copy.deepcopy(frames)
    for pose in poses:
        swap_frame(result[view * 16 + pose])
    if not (leads(result, EAST, strike) and leads(result, WEST, strike)):
        raise SystemExit('Swap did not produce a leading weapon hand: ' + kind)
    return result


def load(path):
    raw = path.read_bytes()
    text = raw.decode('utf-8')
    return json.loads(text.replace('\r\n', '\n')), b'\r\n' in raw, text.isascii()


def dump(path, data, crlf, ascii_only):
    text = json.dumps(data, indent=2, ensure_ascii=ascii_only) + '\n'
    if crlf:
        text = text.replace('\n', '\r\n')
    path.write_bytes(text.encode('utf-8'))


def main():
    check_only = '--check' in sys.argv[1:]
    report = {}
    for kind, (view, poses, _strike) in PLAN.items():
        stage = ROOT / 'assets/art/e08_characters/directional' / kind
        paths = [stage / 'calibration.json', stage / 'presentation.json',
                 ROOT / 'assets/art/animations/directional' / kind / 'presentation.json']
        documents = [load(path) for path in paths]
        reference = documents[0][0]['frames']
        if any(document[0]['frames'] != reference for document in documents[1:]):
            raise SystemExit('Calibration and manifests disagree before correction: ' + kind)
        frames = corrected(kind, reference)
        report[kind] = {'view': 'east' if view == EAST else 'west', 'frames': [view * 16 + pose for pose in poses]}
        if check_only:
            continue
        for path, (data, crlf, ascii_only) in zip(paths, documents):
            data['frames'] = frames
            if path.name == 'calibration.json':
                data['sol_lateral_grip_side'] = {
                    'view': report[kind]['view'],
                    'frames': report[kind]['frames'],
                    'change': 'main_hand/off_hand authored palms swapped with their fingers/depth/angles; arms keeps its offset from main',
                    'reason': 'weapon hand must lead toward the target in both profile views; pixels, S/N, deaths and heads unchanged',
                    'tool': 'tools/fix_e08_lateral_grip_side.py',
                }
            dump(path, data, crlf, ascii_only)
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()

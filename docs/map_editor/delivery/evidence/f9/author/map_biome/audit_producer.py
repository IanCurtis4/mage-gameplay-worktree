"""Read-only consolidation of the frozen producer validation, before content authoring."""
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[7]
HERE = Path(__file__).resolve().parent
FIXTURE = ROOT / '.godot/verification/e07_f1/fixture_project'
EVIDENCE = ROOT / 'docs/map_editor/delivery/evidence/f9/luna/map_biome'
HEAD = '4e3a3788878c7520552c7815d0c2915301857f5f'
ENGINE = ROOT.parent / 'godot/Godot_v4.7.2-stable_win64.exe'
ENGINE_SHA = 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def load(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def validate_inputs(rows):
    mismatches = []
    for row in rows:
        actual = sha(ROOT / row['path'])
        mirror = sha(FIXTURE / row['path'])
        if actual != row['sha256'].lower() or mirror != actual:
            mismatches.append(row['path'])
    return {'count': len(rows), 'mismatches': mismatches}

actual_head = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
assert actual_head == HEAD
assert sha(ENGINE) == ENGINE_SHA
receipts = []
completion_paths = None
for directory, expected in [('model_01', 15), ('native_01', 13), ('borders', 93), ('borders_native', 32), ('gameplay_native', 52)]:
    path = EVIDENCE / directory / 'runs.json'
    run = load(path)
    assert run['ok'] and run['exit_code'] == 0 and not run['timed_out'] and not run['aborted']
    assert run['head_before'] == HEAD and run['head_after'] == HEAD
    assert Path(run['fixture']).resolve() == FIXTURE.resolve()
    assert run['engine_sha256'].lower() == ENGINE_SHA
    assert run['result']['ok'] and run['result']['count'] == expected
    assert len(run['result']['checks']) == expected and all(c['ok'] for c in run['result']['checks'])
    inputs = validate_inputs(run['inputs'])
    assert inputs['count'] == 2045 and not inputs['mismatches']
    text = '\n'.join(p.read_text(encoding='utf-8-sig', errors='replace') for p in path.parent.glob('*.log'))
    assert not re.search(r'SCRIPT ERROR:|Parse Error:|(?m:^ERROR:)', text)
    receipts.append({'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path), 'checks': expected, 'inputs': inputs})
    completion_paths = {r['path'] for r in run['inputs']}

path = EVIDENCE / 'context_02/manifest.json'
context = load(path)
assert context['head_before'] == HEAD and context['head_after'] == HEAD
assert Path(context['fixture']).resolve() == FIXTURE.resolve()
assert context['engine_sha256'].lower() == ENGINE_SHA
assert [(r['name'], r.get('result', {}).get('count') if r.get('result') else None) for r in context['runs']] == [('import', None), ('candidate', 53), ('population', 91), ('patrol', 58), ('exchange', 113)]
assert all(r['ok'] and r['exit_code'] == 0 and not r['aborted'] and not r['timed_out'] for r in context['runs'])
inputs = validate_inputs(context['inputs'])
assert inputs['count'] == 2039 and not inputs['mismatches']
excluded = sorted(completion_paths - {r['path'] for r in context['inputs']})
assert len(excluded) == 6 and all(p.startswith('assets/art/map_authoring/props/') and p.endswith('.import') for p in excluded)
receipts.append({'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path), 'checks': 315, 'inputs': inputs})

imports = []
for item in sorted((ROOT / 'assets/art/map_authoring').rglob('*.png.import')):
    relative = item.relative_to(ROOT)
    if relative.as_posix().startswith('assets/art/map_authoring/props/') or item.stem in ['grass_tile.png', 'earth_tile.png', 'sand_tile.png', 'cliff_tile.png']:
        imports.append({'path': relative.as_posix(), 'source': sha(item), 'fixture': sha(FIXTURE / relative)})
assert len(imports) == 10 and all(r['source'] == r['fixture'] for r in imports)
assert sha(ROOT / 'data/map_authoring/sanctuary_woods.map.json') == '6b8d52095b0d98ba4a436fd5b192ff732b98a8f5da02855646e7e21b9792bb4f'
result = {'ok': True, 'scope': 'producer validation before AX forest-border content mutation; execution supervision by Luna and semantic consolidation by Sol, not independent semantic audit', 'head': HEAD, 'engine_sha256': ENGINE_SHA, 'fixture': str(FIXTURE), 'receipts': receipts, 'completion_only_imports': excluded, 'additional_import_audit': imports, 'invalid_attempt': 'luna/map_biome/context used literalF1; interrupted, excluded from all PASS counts; preserved'}
(HERE / 'producer_audit.json').write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps({'ok': True, 'receipts': len(receipts), 'mismatches': 0, 'imports': len(imports)}))

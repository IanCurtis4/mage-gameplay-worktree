"""Read-only check that Terra changed only the authorized map borders through AX."""
import hashlib
import json
import struct
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
TERRA = ROOT / 'docs/map_editor/delivery/evidence/f9/terra/area_forest_borders'
SOURCE = 'data/map_authoring/sanctuary_woods.map.json'
HEAD = '4e3a3788878c7520552c7815d0c2915301857f5f'
BEFORE = '6b8d52095b0d98ba4a436fd5b192ff732b98a8f5da02855646e7e21b9792bb4f'
AFTER = '8e3f1c3c47709d204eeaf3061e3d98beabb0dfa987ed09ff24ad2ec79e6a631f'
PACKAGE = '098aa6b630015504ec47abfa45257fb0c7b571efabad590016dcc34acfc71fdc'
def sha(raw): return hashlib.sha256(raw).hexdigest()
old_bytes = subprocess.check_output(['git', '-C', str(ROOT), 'show', HEAD + ':' + SOURCE])
new_bytes = (ROOT / SOURCE).read_bytes()
assert sha(old_bytes) == BEFORE and sha(new_bytes) == AFTER and len(new_bytes) == 45615
assert sha((ROOT / (SOURCE + '.bak')).read_bytes()) == BEFORE
old = json.loads(old_bytes)
new = json.loads(new_bytes)
borders = new.pop('borders')
old.pop('borders', None)
assert old == new
assert borders == {'version': 1, 'decorations': True, 'instances': [{'instance_id': 'clearing', 'profile_id': 'forest_rootbank_v1'}, {'instance_id': 'overpass', 'profile_id': 'forest_rootbank_v1'}], 'transitions': []}
assert len(new['pieces']) == 2 and len(new['instances']) == 2 and len(new['links']) == 1
assert sum(len(p['source']['placements']) for p in new['pieces']) == 47
pieces = []
for name, expected in [('clearing', '150509026fddc323396d20fdd015fee47c1dacb47685c1f326842b77260484ab'), ('overpass', '1501a98d8e201ce10017c0f410d137da5bad0c21fbd97039c9e52a9d693341c9')]:
    relative = 'data/map_authoring/sanctuary_woods_' + name + '.source.json'
    assert sha((ROOT / relative).read_bytes()) == expected
    pieces.append({'path': relative, 'sha256': expected})
receipts = []
for filename, count in [('borders_execution.json', 4), ('reopen_execution.json', 2)]:
    raw = (TERRA / filename).read_bytes()
    receipt = json.loads(raw)
    assert receipt['head'] == HEAD and receipt['ok'] and receipt['exit'] == 0 and not receipt['errors_in_log']
    assert receipt['completed'] == count and receipt['requested'] == count
    if count == 4:
        assert [a['id'] for a in receipt['actions']] == ['map/document/open', 'map/borders/apply_batch', 'map/compile_map', 'map/document/save']
        assert receipt['actions'][1]['result']['command_count'] == 2
        assert receipt['actions'][2]['result']['output_hash'] == PACKAGE
    else:
        assert receipt['matches'] and receipt['compile_hash'] == PACKAGE and receipt['byte_sha256'] == AFTER
    receipts.append({'path': (TERRA / filename).relative_to(ROOT).as_posix(), 'sha256': sha(raw), 'actions': count})
image = (TERRA / 'borders.png').read_bytes()
assert image[:8] == b'\x89PNG\r\n\x1a\n'
result = {'ok': True, 'head': HEAD, 'file_sha256_before': BEFORE, 'file_sha256_after': AFTER, 'bytes_after': len(new_bytes), 'only_borders_changed': True, 'piece_sources': pieces, 'pieces': 2, 'instances': 2, 'links': 1, 'props': 47, 'receipts': receipts, 'native_capture': {'path': (TERRA / 'borders.png').relative_to(ROOT).as_posix(), 'sha256': sha(image), 'dimensions': list(struct.unpack('>II', image[16:24])), 'sol_visual_inspection': 'forest border dressing visible; composition and props preserved; AX controls occupy upper canvas; full UX and App gameplay remain pending'}}
(HERE / 'content_audit.json').write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps({'ok': True, 'only_borders_changed': True, 'props': 47, 'actions': [4, 2]}))

consumer_path = ROOT / 'docs/map_editor/delivery/evidence/f9/luna/map_biome/forest_consumer/forest_consumer.manifest.json'
consumer = json.loads(consumer_path.read_bytes())
assert consumer['ok'] and consumer['exit_code'] == 0 and not consumer['timed_out'] and not consumer['generic_errors']
assert consumer['head_before'] == HEAD and consumer['head_after'] == HEAD and consumer['inputs_unchanged']
assert consumer['map_source_bytes_sha256_before'] == AFTER and consumer['map_source_bytes_sha256_after'] == AFTER
assert consumer['primary_input_count'] == 2046 and len(consumer['inputs']) == 2046
assert consumer['result']['ok'] and consumer['result']['count'] == 12
assert len(consumer['result']['checks']) == 12 and all(c['ok'] for c in consumer['result']['checks'])
fixture = ROOT / '.godot/verification/e07_f1/fixture_project'
assert Path(consumer['fixture']).resolve() == fixture.resolve()
for row in consumer['inputs']:
    actual = sha((ROOT / row['path']).read_bytes())
    assert actual == row['sha256'] == row['fixture_sha256'] == sha((fixture / row['path']).read_bytes()), row['path']
assert len(consumer['terrain_imports']) == 10
for row in consumer['terrain_imports']:
    assert sha((ROOT / row['path']).read_bytes()) == row['source_sha256'] == row['fixture_sha256'] == sha((fixture / row['path']).read_bytes())
metrics = consumer['result']['metrics']
assert metrics['runtime_biome'] == 'forest' and metrics['authoring_biome'] == 'forest'
assert metrics['map_package_hash'] == PACKAGE and metrics['map_source_hash'] == '8a9051f8a416a58890365e1b262cea309053ff52c5ce20725d0598ef7875ed55'
assert metrics['stage_surface_count'] == 84 and metrics['stage_connection_count'] == 131 and metrics['border_span_count'] == 35 and metrics['total_piece_placements'] == 47
closure = {'ok': True, 'scope': 'Sol consolidation of Luna execution and actual current inputs; no independent semantic audit', 'consumer_receipt': consumer_path.relative_to(ROOT).as_posix(), 'consumer_receipt_sha256': sha(consumer_path.read_bytes()), 'head': HEAD, 'checks': 12, 'primary_inputs': 2046, 'dependency_imports': 10, 'mismatches': 0, 'metrics': metrics, 'limits': 'map-only candidate and real-body support access; authored entrance marker fits at [160,0,640], actual provisional preview spawn position was not recorded; no App/walking/combat/FPS proof for the Bosque'}
(HERE / 'consumer_audit.json').write_text(json.dumps(closure, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps({'consumer_ok': True, 'checks': 12, 'inputs': 2046, 'mismatches': 0}))

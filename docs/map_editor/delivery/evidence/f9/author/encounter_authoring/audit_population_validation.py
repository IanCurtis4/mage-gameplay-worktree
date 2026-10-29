"""Check execution receipts against the exact source, fixture and Git bytes."""
import argparse, hashlib, json, subprocess
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
FIXTURE=ROOT/'.godot/verification/e07_f1/fixture_project'
LUNA=ROOT/'docs/map_editor/delivery/evidence/f9/luna/encounter_authoring'
ENGINE=ROOT.parent/'godot/Godot_v4.7.2-stable_win64.exe'
ENGINE_SHA='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
parser=argparse.ArgumentParser()
parser.add_argument('--head',required=True)
parser.add_argument('--measure',required=True)
parser.add_argument('--output',required=True)
args=parser.parse_args()
assert len(args.head)==40 and args.measure.isalnum() and args.output.isalnum()
output=HERE/('population_audit_'+args.output+'.json')
assert not output.exists()
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def head(): return subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()
def primary_paths(props):
    paths=set()
    for directory in ['scripts','scenes','data','assets','resources','content','addons/ragrpg_map_editor','tests','tools']:
        for p in (ROOT/directory).rglob('*'):
            if not p.is_file(): continue
            rel=p.relative_to(ROOT).as_posix()
            if p.name.endswith('.import') and not (props and rel.startswith('assets/art/map_authoring/props/')): continue
            paths.add(rel)
    return paths
def audit_inputs(rows,props):
    assert len({r['path'] for r in rows})==len(rows)
    assert {r['path'] for r in rows}==primary_paths(props)
    for r in rows:
        assert sha(ROOT/r['path'])==r['sha256'].lower()==sha(FIXTURE/r['path']),r['path']
    return len(rows)
assert head()==args.head and sha(ENGINE)==ENGINE_SHA
direct_path=LUNA/'population_reachability_03/runs.json'; direct=read(direct_path)
assert direct['ok'] and direct['exit_code']==0 and not direct['timed_out'] and not direct['aborted']
assert direct['head_before']==direct['head_after']==args.head and direct['engine_sha256'].lower()==ENGINE_SHA
assert Path(direct['fixture']).resolve()==FIXTURE.resolve()
assert direct['result']['ok'] and direct['result']['checks']==27 and len(direct['result']['details'])==27 and not direct['result']['failed'] and all(c['ok'] for c in direct['result']['details'])
direct_count=audit_inputs(direct['inputs'],True)
context_path=LUNA/'population_context_01/manifest.json'; context=read(context_path)
assert context['head_before']==context['head_after']==args.head and context['engine_sha256'].lower()==ENGINE_SHA
assert Path(context['fixture']).resolve()==FIXTURE.resolve()
assert [(r['name'],r['result']['count'] if r.get('result') else None) for r in context['runs']]==[('import',None),('candidate',53),('population',91),('patrol',58),('exchange',113)]
assert all(r['ok'] and r['exit_code']==0 and not r['timed_out'] and not r['aborted'] for r in context['runs'])
context_count=audit_inputs(context['inputs'],False)
verify=LUNA/'population_verify_01'
plan=read(verify/'plan.json')
rows=[json.loads(line) for line in (verify/'checks.jsonl').read_text(encoding='utf-8-sig').splitlines() if line.strip()]
executed=[r for r in rows if r.get('name') in ['editor_import','e07_f5_population_test']]
assert plan['source_commit']==args.head and plan['selected_steps']==2 and plan['total_steps']==299
assert len(executed)==2 and all(not r['failed'] and r['exit_code']==0 and not r['timed_out'] for r in executed)
measure_path=HERE/('population_measure_'+args.measure)
measure=read(measure_path/'receipt.json'); result=read(measure_path/'result.json')
assert measure['head']==measure['head_after']==args.head and measure['engine_sha256']==ENGINE_SHA and measure['exit_code']==0 and not measure['timed_out']
assert measure['compiler_sha256']==sha(ROOT/'scripts/map_authoring/population/population_compiler.gd')
assert measure['draft_sha256']==sha(ROOT/'docs/map_editor/delivery/evidence/f9/terra/area_encounters/population_draft_01.json')=='4d64d6ffbce706a2917b2a1ad436decfd362b96575a7a4b4bbd001ededdb7cb1'
assert result['ok'] and result['no_mutation'] and result['slots']==7
assert sorted(r['quantity'] for r in result['metrics'])==[1,3,3]
for path in [ROOT/'assets/art/map_authoring/props']:
    for p in path.glob('*.png.import'): assert sha(p)==sha(FIXTURE/p.relative_to(ROOT))
for rel in ['scripts/map_authoring/population/population_compiler.gd','scripts/map_authoring/context/population_context.gd','scripts/map_authoring/exchange/exchange.gd','tests/map_editor_population_reachability_test.gd','tests/map_editor_population_reachability_test.gd.uid','tools/map_editor_completion/run.ps1']:
    blob=subprocess.check_output(['git','-C',str(ROOT),'show',args.head+':'+rel])
    # Source text may use CRLF; compare Git's canonical text representation.
    assert blob.replace(b'\r\n',b'\n')==(ROOT/rel).read_bytes().replace(b'\r\n',b'\n'),rel
assert head()==args.head
record={'ok':True,'head':args.head,'role':'Luna execution supervision; Sol semantic and byte consolidation, not independent semantic audit','directed_checks':27,'completion_inputs':direct_count,'context_inputs':context_count,'context_checks':315,'verify_selected':2,'verify_catalog':299,'measure_seconds':measure['elapsed_seconds'],'measure_slots':7,'measure_quotas':[3,3,1],'mismatches':0,'receipts':[{'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)} for p in [direct_path,context_path,measure_path/'receipt.json',measure_path/'result.json']],'limits':'instrumented actual draft generation only; no AX apply/compiled final population/patrol product yet, no in-game FPS or full F9 completion'}
output.write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(record,ensure_ascii=True))

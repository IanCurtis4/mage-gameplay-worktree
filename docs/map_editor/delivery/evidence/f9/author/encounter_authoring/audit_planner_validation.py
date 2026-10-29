"""Consolidate canonical admission tests and the exact full forest compile."""
import argparse, hashlib, json, re, subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
FIXTURE=ROOT/'.godot/verification/e07_f1/fixture_project'
LUNA=ROOT/'docs/map_editor/delivery/evidence/f9/luna/encounter_authoring'
ENGINE_SHA='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
parser=argparse.ArgumentParser()
parser.add_argument('--head',required=True)
parser.add_argument('--compile',required=True)
parser.add_argument('--output',required=True)
args=parser.parse_args()
assert len(args.head)==40 and args.compile.isalnum() and args.output.isalnum()
output=HERE/('planner_audit_'+args.output+'.json'); assert not output.exists()
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def head(): return subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()
def paths(props):
    result=set()
    for folder in ['scripts','scenes','data','assets','resources','content','addons/ragrpg_map_editor','tests','tools']:
        for p in (ROOT/folder).rglob('*'):
            if not p.is_file(): continue
            rel=p.relative_to(ROOT).as_posix()
            if p.name.endswith('.import') and not (props and rel.startswith('assets/art/map_authoring/props/')): continue
            result.add(rel)
    return result
def audit_rows(rows,props):
    assert len({r['path'] for r in rows})==len(rows) and {r['path'] for r in rows}==paths(props)
    for r in rows: assert sha(ROOT/r['path'])==r['sha256'].lower()==sha(FIXTURE/r['path']),r['path']
    return len(rows)
assert head()==args.head
receipts=[]; completion_count=0
for folder,count in [('planner_model_01',20),('planner_gameplay_native_01',52)]:
    p=LUNA/folder/'runs.json'; data=read(p)
    assert data['head_before']==data['head_after']==args.head and data['engine_sha256'].lower()==ENGINE_SHA and Path(data['fixture']).resolve()==FIXTURE.resolve()
    assert data['ok'] and data['exit_code']==0 and not data['timed_out'] and not data['aborted']
    assert data['result']['ok'] and data['result']['count']==count and len(data['result']['checks'])==count and all(r['ok'] for r in data['result']['checks'])
    completion_count=audit_rows(data['inputs'],True)
    receipts.append({'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p),'checks':count})
p=LUNA/'planner_context_01/manifest.json'; data=read(p)
assert data['head_before']==data['head_after']==args.head and data['engine_sha256'].lower()==ENGINE_SHA and Path(data['fixture']).resolve()==FIXTURE.resolve()
assert [(r['name'],r['result']['count'] if r.get('result') else None) for r in data['runs']]==[('import',None),('candidate',53),('population',91),('patrol',58),('exchange',113)]
assert all(r['ok'] and r['exit_code']==0 and not r['timed_out'] and not r['aborted'] for r in data['runs'])
context_count=audit_rows(data['inputs'],False)
historical=read(LUNA/'population_context_01/manifest.json')
old_hash=next(r for r in historical['runs'] if r['name']=='population')['result']['package_hash']
small_hash=next(r for r in data['runs'] if r['name']=='population')['result']['package_hash']
assert old_hash==small_hash=='8c7defe83fdb8c153848c01dfcbe3ab6d4d0af3877fe60b6de2f850d7a0ea5d1'
receipts.append({'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p),'checks':315})
verify=LUNA/'planner_verify_01'; plan=read(verify/'plan.json')
rows=[json.loads(s) for s in (verify/'checks.jsonl').read_text(encoding='utf-8-sig').splitlines() if s.strip()]
names={'editor_import','e07_f0_consumer_test','e07_f5_population_test','e07_f5_campaign_test','e07_f5_recovery_test','e07_f3_snapshot_test'}
assert plan['source_commit']==args.head and plan['selected_steps']==6 and plan['total_steps']==299
assert {r['name'] for r in rows}==names and len(rows)==6 and all(r['exit_code']==0 and not r['failed'] and not r['timed_out'] for r in rows)
compiled=HERE/('population_compile_'+args.compile)
run=read(compiled/'receipt.json'); result=read(compiled/'result.json')
assert run['head']==run['head_after']==args.head and run['exit_code']==0 and not run['timed_out'] and run['engine_sha256']==ENGINE_SHA
assert run['compiler_sha256']==sha(ROOT/'scripts/map_authoring/population/population_compiler.gd')
assert result['ok'] and result['no_mutation'] and result['slots']==7 and len(result['output_hash'])==64
for name in ['engine.log','stdout.log','stderr.log']:
    assert not re.search(r'SCRIPT ERROR:|Parse Error:|(?m:^ERROR:)',(compiled/name).read_text(encoding='utf-8',errors='replace')),name
source=ROOT/'data/map_authoring/sanctuary_woods.population.json'
assert sha(source)==run['draft_sha256']=='3debc7674a1770702639e8bb33b1e6598c52929e9230395ccfbf505c1ed04889'
blob=subprocess.check_output(['git','-C',str(ROOT),'show',args.head+':data/map_authoring/sanctuary_woods.population.json']); assert blob==source.read_bytes()
for rel in ['scripts/core/expedition/population/population_planner.gd','scripts/map_authoring/population/population_compiler.gd','tests/map_editor_population_planner_batch_test.gd','tests/map_editor_population_planner_batch_test.gd.uid','tools/map_editor_completion/run.ps1']:
    blob=subprocess.check_output(['git','-C',str(ROOT),'show',args.head+':'+rel]); assert blob.replace(b'\r\n',b'\n')==(ROOT/rel).read_bytes().replace(b'\r\n',b'\n'),rel
assert head()==args.head
record={'ok':True,'head':args.head,'role':'Luna execution supervision; Sol semantic/byte consolidation, not independent semantic audit','directed':20,'gameplay_fixture':52,'context':315,'verify_selected':6,'verify_catalog':299,'completion_inputs':completion_count,'context_inputs':context_count,'mismatches':0,'compile_seconds':run['elapsed_seconds'],'population_source_sha256':sha(source),'compiled_hash':result['output_hash'],'slots':7,'receipts':receipts,'limits':'instrumented complete forest compile, not yet real AX rerun or patrol; no Bosque App/live movement/combat/FPS, no full F9 completion; native editor worker180 remains a measured obligation'}
output.write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(record,ensure_ascii=True))

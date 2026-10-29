"""Actual AX client: preview, confirmed apply, compile, save and new-process reopen.

Run only after the frozen Luna batch has explicitly released the fixture.
Uses Luna's disposable canonical fixtures, never a product-source replacement.
"""
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[7]
HERE = Path(__file__).resolve().parent / 'cli_01'
FIXTURE = ROOT / '.godot/verification/e07_f1/fixture_project'
ENGINE = ROOT.parent / 'godot/Godot_v4.7.2-stable_win64.exe'
MODEL = ROOT / 'docs/map_editor/delivery/evidence/f9/luna/encounter_authoring/model_02/runs.json'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def head(): return subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()
def stamp(value): return dt.datetime.fromisoformat(value.replace('Z','+00:00')).timestamp()
def inputs():
    rows=[]
    for name in ['scripts','scenes','resources','content','data','assets','addons/ragrpg_map_editor','tests','tools']:
        for path in sorted((ROOT/name).rglob('*')):
            if not path.is_file(): continue
            relative=path.relative_to(ROOT).as_posix()
            if path.name.endswith('.import') and not relative.startswith('assets/art/map_authoring/props/'): continue
            rows.append({'path':relative,'sha256':sha(path),'fixture_sha256':sha(FIXTURE/relative)})
    assert all(r['sha256']==r['fixture_sha256'] for r in rows)
    return rows
def action(screen, suffix, parameters=None): return {'screen':screen,'id':screen+'/'+suffix,'parameters':parameters or {}}

assert sha(ENGINE)=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
model=read(MODEL)
assert model['ok'] and model['result']['count']==27 and model['head_before']==model['head_after']==head()
matches=[p for p in (FIXTURE/'.godot/f9_encounter_authoring').glob('*/population.json') if stamp(model['started_utc'])-2 <= p.stat().st_mtime <= stamp(model['finished_utc'])+2 and (p.parent/'patrol.json').is_file()]
assert len(matches)==1, 'Ambiguous disposable model fixture; do not guess a source.'
population_path=matches[0]; patrol_path=population_path.parent/'patrol.json'
original_files={str(p):sha(p) for p in [population_path,patrol_path]}
HERE.mkdir()
initial_inputs=inputs(); initial_head=head(); runs=[]
profile=FIXTURE/'.godot/discardable_profile'
env=os.environ.copy(); env.update(APPDATA=str(profile/'Roaming'),LOCALAPPDATA=str(profile/'Local'))

def run(name, actions, native=False, expected_ok=True):
    request=HERE/(name+'.request.json'); result=HERE/(name+'.result.json')
    request.write_text(json.dumps({'ax_version':1,'actions':actions},indent=2,ensure_ascii=False),encoding='utf-8')
    argv=[str(ENGINE),'--path',str(FIXTURE)]
    argv+=['--rendering-method','gl_compatibility'] if native else ['--headless']
    argv+=['--log-file',str(HERE/(name+'.engine.log')),'--script','res://scripts/map_authoring/agent/ax_session.gd','--','--ax-request='+str(request),'--ax-result='+str(result)]
    if native: argv+=['--ax-capture='+str(HERE/(name+'.png'))]
    start=time.monotonic()
    process=subprocess.run(argv,cwd=FIXTURE,env=env,capture_output=True,timeout=300)
    (HERE/(name+'.stdout.log')).write_bytes(process.stdout); (HERE/(name+'.stderr.log')).write_bytes(process.stderr)
    output=read(result)
    logs=process.stdout.decode('utf-8',errors='replace')+process.stderr.decode('utf-8',errors='replace')+(HERE/(name+'.engine.log')).read_text(encoding='utf-8',errors='replace')
    errors=bool(re.search(r'SCRIPT ERROR:|Parse Error:|(?m:^ERROR:)',logs))
    ok=process.returncode==(0 if expected_ok else 1) and output['ok']==expected_ok and not errors
    runs.append({'name':name,'arguments':argv,'exit_code':process.returncode,'ok':ok,'generic_errors':errors,'seconds':round(time.monotonic()-start,3),'completed':output['completed_actions'],'requested':output['requested_actions'],'request_sha256':sha(request),'result_sha256':sha(result)})
    (HERE/'runs.json').write_text(json.dumps(runs,indent=2,ensure_ascii=False),encoding='utf-8')
    assert ok, name
    if expected_ok: assert output['completed_actions']==len(actions) and all(r['result']['ok'] for r in output['actions'])
    return output

preview=run('preview',[action('population','document/open',{'path':str(population_path),'confirm_discard':True}),action('population','plan/preview')])
signature=preview['actions'][-1]['result']['proposal_hash']; base=preview['population_snapshot']['source_hash']
outputs={}
for name,native in [('headless',False),('native',True)]:
    pop_out=HERE/(name+'.population.json'); patrol_out=HERE/(name+'.patrol.json')
    point=read(patrol_path)['patrols'][0]['waypoints'][1]
    params=dict(point,patrol_id=read(patrol_path)['patrols'][0]['patrol_id']); params['wait_seconds']=1.75
    actions=[action('population','document/open',{'path':str(population_path),'confirm_discard':True}),action('population','catalog/options'),action('population','map/query'),action('population','plan/preview'),action('population','plan/apply',{'expected_source_hash':base,'proposal_hash':signature,'confirm_apply':True}),action('population','compile'),action('population','document/save',{'path':str(pop_out)}),action('patrol','document/open',{'path':str(patrol_path),'confirm_discard':True}),action('patrol','map/query'),action('patrol','waypoint/upsert',params),action('patrol','compile'),action('patrol','document/save',{'path':str(patrol_out)})]
    result=run(name,actions,native)
    assert next(p for p in read(patrol_out)['patrols'][0]['waypoints'] if p['point_id']==point['point_id'])['wait_seconds']==1.75
    outputs[name]={'population_source':result['population_snapshot']['source_hash'],'patrol_source':result['patrol_snapshot']['source_hash'],'population_package':result['actions'][5]['result']['output_hash'],'patrol_package':result['actions'][10]['result']['output_hash'],'population_bytes':sha(pop_out),'patrol_bytes':sha(patrol_out)}
assert outputs['headless']==outputs['native']
reopen=run('reopen',[action('population','document/open',{'path':str(HERE/'native.population.json'),'confirm_discard':True}),action('population','compile'),action('patrol','document/open',{'path':str(HERE/'native.patrol.json'),'confirm_discard':True}),action('patrol','compile')])
assert reopen['population_snapshot']['source_hash']==outputs['native']['population_source'] and reopen['patrol_snapshot']['source_hash']==outputs['native']['patrol_source']
assert reopen['actions'][1]['result']['output_hash']==outputs['native']['population_package'] and reopen['actions'][3]['result']['output_hash']==outputs['native']['patrol_package']
brush=read(population_path)['brushes'][0]; spec=brush['species'][0]
rejected_path=HERE/'must_not_exist.population.json'
slot={'slot_id':'forbidden_generated','brush_id':brush['brush_id'],'surface_id':brush['surface_id'],'position_xyz':brush['center_xyz'],'species_id':spec['species_id'],'category':spec['category'],'origin_id':spec['origin_id'],'fixed':False,'site_id':''}
rejected=run('rejected',[action('population','document/open',{'path':str(population_path),'confirm_discard':True}),action('population','slot/upsert',slot),action('population','document/save',{'path':str(rejected_path)})],expected_ok=False)
assert rejected['completed_actions']==2 and rejected['actions'][-1]['result']['code']=='slot_fixed_required' and rejected['actions'][-1]['input_hash']==rejected['actions'][-1]['output_hash'] and not rejected_path.exists()
final_inputs=inputs()
assert initial_inputs==final_inputs and head()==initial_head and all(sha(Path(p))==digest for p,digest in original_files.items())
manifest={'ok':True,'head_before':initial_head,'head_after':head(),'scope':'real AX client in headless/native processes; canonical preview/apply/compile/save/reopen and stop-on-error using disposable fixtures, no Bosque product source or App gameplay','engine_sha256':sha(ENGINE),'fixture':str(FIXTURE),'environment':{'APPDATA':env['APPDATA'],'LOCALAPPDATA':env['LOCALAPPDATA']},'inputs':initial_inputs,'inputs_unchanged':True,'model_fixture_files':original_files,'equivalence':outputs,'runs':runs}
(HERE/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps({'ok':True,'head':initial_head,'inputs':len(initial_inputs),'runs':len(runs),'equivalence':outputs},ensure_ascii=False))

"""Replay map actions through the real editor client in separate processes."""
from pathlib import Path
import hashlib,json,os,re,subprocess,time
root=Path('C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5')
folder=Path(__file__).resolve().parent
fixture=root/'.godot/verification/e07_f1/fixture_project'
engine=root.parent/'godot/Godot_v4.7.2-stable_win64.exe'
model=json.loads((folder.parent/'model_03/runs.json').read_text(encoding='utf-8-sig'))
assert model['ok'], 'Model suite must pass before client replay'
sources=Path(model['result']['work_dir'])
head=subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()
env=os.environ.copy();env['APPDATA']=str(fixture/'.godot/discardable_profile/Roaming');env['LOCALAPPDATA']=str(fixture/'.godot/discardable_profile/Local')
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def inputs():
    values={}
    for name in ['scripts','scenes','data','assets','resources','content','addons/ragrpg_map_editor','tests','tools']:
        for p in (root/name).rglob('*'):
            if p.is_file() and (not p.name.endswith('.import') or p.relative_to(root).as_posix().startswith('assets/art/map_authoring/props/')):
                rel=p.relative_to(root).as_posix(); values[rel]=digest(p)
                assert values[rel]==digest(fixture/rel),rel
    return values
before=inputs()
def action(screen,id,parameters):return {'screen':screen,'id':id,'parameters':parameters}
def run(name,actions,native=False,expected=True):
    request=folder/(name+'.request.json');output=folder/(name+'.result.json')
    assert not output.exists() and not request.exists()
    request.write_text(json.dumps({'ax_version':1,'actions':actions},ensure_ascii=False,indent=2),encoding='utf-8')
    argv=[str(engine),'--path',str(fixture)]+(['--rendering-method','gl_compatibility'] if native else ['--headless'])+['--script','res://scripts/map_authoring/agent/ax_session.gd','--','--ax-request='+str(request),'--ax-result='+str(output)]
    if native:argv.append('--ax-capture='+str(folder/(name+'.png')))
    start=time.monotonic();proc=subprocess.run(argv,env=env,cwd=fixture,capture_output=True,timeout=300)
    (folder/(name+'.stdout.log')).write_bytes(proc.stdout);(folder/(name+'.stderr.log')).write_bytes(proc.stderr)
    result=json.loads(output.read_text(encoding='utf-8')) if output.exists() else {}
    text=(proc.stdout+proc.stderr).decode('utf-8',errors='replace')
    errors=bool(re.search(r'SCRIPT ERROR|Parse Error|(?m:^ERROR:)',text))
    (folder/(name+'.invocation.json')).write_text(json.dumps({'argv':argv,'head':head,'APPDATA':env['APPDATA'],'LOCALAPPDATA':env['LOCALAPPDATA'],'exit_code':proc.returncode,'elapsed_seconds':time.monotonic()-start,'generic_errors':errors},ensure_ascii=False,indent=2),encoding='utf-8')
    assert proc.returncode==(0 if expected else 1) and result.get('ok') is expected and not errors,(name,proc.returncode,text[-2000:])
    return result
results={}
for name,native in [('headless',False),('native',True)]:
    destination=folder/(name+'.map.json')
    recipe=[action('map','map/document/new',{'document_id':'ax_client_map','name':'Mapa de teste AX','confirm_discard':True}),action('map','map/piece/add',{'path':str(sources/'room_left.source.json'),'instance_id':'left','position_xz':[0,0],'rotation_quarters':0}),action('map','map/piece/add',{'path':str(sources/'room_right.source.json'),'instance_id':'right','position_xz':[100,0],'rotation_quarters':0}),action('map','map/link/upsert',{'link_id':'door','a_instance':'left','a_connector':'east','b_instance':'right','b_connector':'west'}),action('map','map/mode/set',{'mode':'manual'}),action('map','map/context/set',{'biome_id':'forest','instance_id':'','rules':[],'reason':''}),action('map','map/instance/select',{'instance_id':'right'}),action('map','map/compile_map',{}),action('piece','piece/document/name',{'name':'Peça auxiliar'}),action('map','map/document/save',{'path':str(destination)})]
    result=run(name,recipe,native)
    assert result['completed_actions']==len(recipe)==10
    snapshot=result['map_snapshot'];h=snapshot['source_hash']; source=snapshot['source']
    assert len(source['instances'])==2 and len(source['links'])==1 and source['context']['biome_id']=='forest'
    assert snapshot['state']['source_path']==str(destination).replace('\\','/') or Path(snapshot['state']['source_path'])==destination
    assert not snapshot['state']['dirty'] and snapshot['state']['selected_instance']=='right'
    assert h!=result['source_hash'] and result['snapshot']['source']['name']=='Peça auxiliar'
    previous=None
    for row in result['actions']:
        if row['screen']=='map':
            if previous is not None:assert row['input_hash']==previous
            assert row['input_hash'] and row['output_hash'];previous=row['output_hash']
    compile_hash=next(row['result']['output_hash'] for row in result['actions'] if row['id']=='map/compile_map')
    results[name]={'source_hash':h,'compile_hash':compile_hash,'file_sha256':digest(destination)}
assert results['headless']==results['native'],results
reopen=run('reopen',[action('map','map/document/open',{'path':str(folder/'native.map.json'),'confirm_discard':True}),action('map','map/compile_map',{})])
assert reopen['completed_actions']==2 and reopen['map_snapshot']['source_hash']==results['native']['source_hash'] and not reopen['map_snapshot']['state']['dirty']
negative=run('negative',[action('map','map/document/open',{'path':str(folder/'native.map.json'),'confirm_discard':True}),action('map','map/instance/transform',{'instance_id':'right','position_xz':[100,0],'rotation_quarters':0.5}),action('map','map/document/name',{'name':'Must not run'})],expected=False)
assert negative['completed_actions']==2 and negative['map_snapshot']['source_hash']==results['native']['source_hash'] and negative['actions'][-1]['result']['code']=='transform_unsupported'
after=inputs();assert before==after and subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()==head
summary={'ok':True,'head':head,'results':results,'reopen':True,'negative_stops_batch':True,'primary_count':len(before),'inputs_before':before,'inputs_unchanged':True}
(folder/'summary.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps({k:v for k,v in summary.items() if k!='inputs_before'},ensure_ascii=False))

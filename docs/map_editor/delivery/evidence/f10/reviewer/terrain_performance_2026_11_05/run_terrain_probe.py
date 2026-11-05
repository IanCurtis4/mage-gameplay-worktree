import json,os,subprocess,sys,time
from pathlib import Path
base=Path(__file__).resolve().parents[2]
evidence=base/'.tools/map-editor-m5/.godot/verification/terrain_performance_2026_11_05'/sys.argv[1]
evidence.mkdir(parents=True,exist_ok=False)
env=os.environ.copy();env['APPDATA']=str(evidence/'profile');env['LOCALAPPDATA']=env['APPDATA'];env['TERRAIN_EVIDENCE']=str(evidence)
engine=base/'.tools/godot/Godot_v4.7.2-stable_win64.exe'
args=[str(engine)]
if len(sys.argv)>2 and sys.argv[2]=='fixture': args+=['--path',str(base/'.tools/map-editor-m5/.godot/verification/e07_f1/fixture_project')]
elif len(sys.argv)<=2 or sys.argv[2]=='pack':args+=['--main-pack',str(base/'.tools/playtest_f10/minimap_c9a3673f/RagRPG-F10-Q5-Mapa.pck')]
else:args+=['--main-pack',str(Path(sys.argv[2]).resolve())]
probe=sys.argv[3] if len(sys.argv)>3 else 'terrain_perf_probe.gd'
marker=sys.argv[4] if len(sys.argv)>4 else 'TERRAIN_PERF_RESULT'
args+=['--rendering-method','gl_compatibility','--log-file',str(evidence/'engine.log'),'--script',str(Path(__file__).with_name(probe))]
start=time.time()
with (evidence/'output.log').open('w',encoding='utf-8') as out:
 p=subprocess.Popen(args,env=env,stdout=out,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
 try:code=p.wait(timeout=420)
 except subprocess.TimeoutExpired:p.kill();p.wait();raise
data=(evidence/'output.log').read_text(encoding='utf-8')
result=[json.loads(line.split(marker+' ',1)[1]) for line in data.splitlines() if line.startswith(marker+' ')]
ok=code==0 and len(result)==1 and result[0]['ok'] and not any(x in data for x in ('SCRIPT ERROR','Parse Error','ERROR:'))
(evidence/'result.json').write_text(json.dumps({'ok':ok,'exit_code':code,'seconds':time.time()-start,'arguments':args,'result':result},indent=2),encoding='utf-8')
print(json.dumps({'ok':ok,'evidence':str(evidence),'result':result},ensure_ascii=False))
sys.exit(0 if ok else 1)

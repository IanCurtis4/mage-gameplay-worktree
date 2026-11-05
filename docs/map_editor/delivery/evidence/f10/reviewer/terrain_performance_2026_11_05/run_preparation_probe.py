import json,os,subprocess,time
from pathlib import Path
base=Path(__file__).resolve().parents[2]
root=base/'.tools/map-editor-m5/.godot/verification/terrain_performance_2026_11_05'
results=[]
for mode in ['serial','parallel']:
 d=root/('preparation_'+mode+'_01');d.mkdir(parents=True,exist_ok=False)
 env=os.environ.copy();env['APPDATA']=str(d/'profile');env['LOCALAPPDATA']=env['APPDATA'];env['PREPARATION_MODE']=mode
 args=[str(base/'.tools/godot/Godot_v4.7.2-stable_win64.exe'),'--headless','--main-pack',str(base/'.tools/playtest_f10/minimap_c9a3673f/RagRPG-F10-Q5-Mapa.pck'),'--script',str(Path(__file__).with_name('preparation_lanes_probe.gd'))]
 start=time.time()
 with (d/'output.log').open('w',encoding='utf-8') as out:
  p=subprocess.Popen(args,env=env,stdout=out,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
  try:code=p.wait(timeout=300)
  except subprocess.TimeoutExpired:p.kill();p.wait();raise
 data=(d/'output.log').read_text(encoding='utf-8')
 marker=[json.loads(x.split('PREPARATION_LANES_RESULT ',1)[1]) for x in data.splitlines() if x.startswith('PREPARATION_LANES_RESULT ')]
 ok=code==0 and len(marker)==1 and marker[0]['ok'] and not any(x in data for x in ('SCRIPT ERROR','Parse Error','ERROR:'))
 receipt={'ok':ok,'exit_code':code,'arguments':args,'wall_seconds':time.time()-start,'result':marker}
 (d/'result.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8');results.append(receipt)
 print(json.dumps(receipt),flush=True)
 if not ok:raise SystemExit(1)
assert results[0]['result'][0]['manifest_digest']==results[1]['result'][0]['manifest_digest']
assert results[0]['result'][0]['rules_digest']==results[1]['result'][0]['rules_digest']
print('PREPARATION_LANES_MATCH')

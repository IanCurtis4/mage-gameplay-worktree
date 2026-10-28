import hashlib,json,os,pathlib,subprocess,sys,time
root=pathlib.Path(sys.argv[1]); evidence=pathlib.Path(sys.argv[2]); fixture=pathlib.Path(sys.argv[3]); exe=pathlib.Path(sys.argv[4])
args=[str(exe),'--path',str(fixture),'--headless','--log-file',str(evidence/'source_consumer.engine.log'),'--script','res://.godot/f9_terra_source_consumer_test_02.gd']
env=os.environ.copy(); profile=fixture/'.godot'/'discardable_profile'; env['APPDATA']=str(profile/'Roaming');env['LOCALAPPDATA']=str(profile/'Local')
sources=[root/'data/map_authoring/sanctuary_woods_clearing.source.json',root/'data/map_authoring/sanctuary_woods_overpass.source.json'];source_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
start=time.time()
try:
 p=subprocess.run(args,cwd=fixture,env=env,capture_output=True,text=True,timeout=300); code=p.returncode;out=p.stdout;err=p.stderr;timeout=False
except subprocess.TimeoutExpired as exc:
 code=None;out=exc.stdout.decode(errors='replace') if isinstance(exc.stdout,bytes) else (exc.stdout or '');err=exc.stderr.decode(errors='replace') if isinstance(exc.stderr,bytes) else (exc.stderr or '');timeout=True
(evidence/'source_consumer.stdout.log').write_text(out,encoding='utf-8');(evidence/'source_consumer.stderr.log').write_text(err,encoding='utf-8')
marker=next((line[len('F9_TERRA_SOURCE_CONSUMER_RESULT '):] for line in out.splitlines() if line.startswith('F9_TERRA_SOURCE_CONSUMER_RESULT ')),None);result=json.loads(marker) if marker else None
meta={'head_expected':'0acc94ef6530d560eb1695de699b40b53dd8cdb2','executable':str(exe),'arguments':args[1:],'working_directory':str(fixture),'environment':{'APPDATA':env['APPDATA'],'LOCALAPPDATA':env['LOCALAPPDATA']},'exit_code':code,'timed_out':timeout,'elapsed_seconds':round(time.time()-start,3),'source_file_sha256':source_hashes,'result':result}
(evidence/'source_consumer.invocation.json').write_text(json.dumps(meta,indent=2,ensure_ascii=False),encoding='utf-8'); print(json.dumps(meta,ensure_ascii=False));print(out)
if err: print(err,file=sys.stderr)

"""Synchronous transport wrapper for a single passive editor AX recipe."""
import argparse, hashlib, json, os, re, subprocess, sys, time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[7]
FIXTURE=ROOT/'.godot/verification/e07_f1/fixture_project'
ENGINE=ROOT.parent/'godot/Godot_v4.7.2-stable_win64.exe'
parser=argparse.ArgumentParser()
parser.add_argument('--request',type=Path,required=True)
parser.add_argument('--result',type=Path,required=True)
parser.add_argument('--receipt',type=Path,required=True)
parser.add_argument('--capture',type=Path)
parser.add_argument('--native',action='store_true')
args=parser.parse_args()
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def head(): return subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()
request=args.request.resolve(); result=args.result.resolve(); receipt=args.receipt.resolve()
assert request.is_file() and not result.exists() and not receipt.exists()
assert len({request,result,receipt})==3
if args.capture: assert not args.capture.exists()
assert sha(ENGINE)=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
for path in [result,receipt]: path.parent.mkdir(parents=True,exist_ok=True)
engine_log=receipt.with_suffix('.engine.log')
stdout_path=receipt.with_suffix('.stdout.log'); stderr_path=receipt.with_suffix('.stderr.log')
assert not any(path.exists() for path in [engine_log,stdout_path,stderr_path])
protected=['data/map_authoring/sanctuary_woods.map.json','data/map_authoring/sanctuary_woods_clearing.source.json','data/map_authoring/sanctuary_woods_overpass.source.json']
protected_before={p:sha(ROOT/p) for p in protected}
assert protected_before[protected[0]]=='8e3f1c3c47709d204eeaf3061e3d98beabb0dfa987ed09ff24ad2ec79e6a631f'
before=head()
profile=FIXTURE/'.godot/discardable_profile'
env=os.environ.copy(); env.update(APPDATA=str(profile/'Roaming'),LOCALAPPDATA=str(profile/'Local'))
argv=[str(ENGINE),'--path',str(FIXTURE)]
argv+=['--rendering-method','gl_compatibility'] if args.native or args.capture else ['--headless']
argv+=['--log-file',str(engine_log),'--script','res://scripts/map_authoring/agent/ax_session.gd','--','--ax-request='+str(request),'--ax-result='+str(result)]
if args.capture: argv+=['--ax-capture='+str(args.capture.resolve())]
started=time.monotonic(); timed_out=False
try:
    process=subprocess.run(argv,cwd=FIXTURE,env=env,capture_output=True,timeout=360)
    code,stdout,stderr=process.returncode,process.stdout,process.stderr
except subprocess.TimeoutExpired as error:
    code,stdout,stderr,timed_out=None,error.stdout or b'',error.stderr or b'',True
stdout_path.write_bytes(stdout); stderr_path.write_bytes(stderr)
response=json.loads(result.read_text(encoding='utf-8-sig')) if result.is_file() else None
log=engine_log.read_text(encoding='utf-8',errors='replace') if engine_log.exists() else ''
generic_errors=bool(re.search(r'SCRIPT ERROR:|Parse Error:|(?m:^ERROR:)',stdout.decode('utf-8',errors='replace')+stderr.decode('utf-8',errors='replace')+log))
after=head(); protected_after={p:sha(ROOT/p) for p in protected}
record={'head_before':before,'head_after':after,'engine_sha256':sha(ENGINE),'fixture':str(FIXTURE),'arguments':argv,'environment':{'APPDATA':env['APPDATA'],'LOCALAPPDATA':env['LOCALAPPDATA']},'request_sha256':sha(request),'exit_code':code,'timed_out':timed_out,'elapsed_seconds':round(time.monotonic()-started,3),'generic_errors':generic_errors,'response_ok':response.get('ok',False) if response else False,'response_code':response.get('code','missing_result') if response else 'missing_result','completed':response.get('completed_actions',0) if response else 0,'requested':response.get('requested_actions',0) if response else 0,'protected_before':protected_before,'protected_after':protected_after,'protected_unchanged':protected_before==protected_after,'result_sha256':sha(result) if result.exists() else None}
record['ok']=code==0 and not timed_out and not generic_errors and record['response_ok'] and before==after and record['protected_unchanged']
receipt.write_text(json.dumps(record,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps({key:value for key,value in record.items() if key not in ['arguments','protected_before','protected_after']},ensure_ascii=True))
sys.exit(0 if record['ok'] else 1)

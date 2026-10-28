import json, os, pathlib, subprocess, sys, time, hashlib
root = pathlib.Path(sys.argv[1])
evidence = pathlib.Path(sys.argv[2])
fixture = pathlib.Path(sys.argv[3])
exe = pathlib.Path(sys.argv[4])
old_request = root / 'docs/map_editor/delivery/evidence/f9/luna/ax_authoring/cli/positive_native_02.request.json'
request_path = evidence / 'positive_native_04.request.json'
result_path = evidence / 'positive_native_04.result.json'
capture_path = evidence / 'positive_native_04_capture.png'
save_path = evidence / 'native_saved_piece_04.json'
request = json.loads(old_request.read_text(encoding='utf-8'))
request['actions'][-1]['parameters']['path'] = str(save_path)
request_path.write_text(json.dumps(request, ensure_ascii=False, indent=2), encoding='utf-8')
args = [str(exe), '--path', str(fixture), '--rendering-method', 'gl_compatibility', '--script', 'res://scripts/map_authoring/agent/ax_session.gd', '--', '--ax-request=' + str(request_path), '--ax-result=' + str(result_path), '--ax-capture=' + str(capture_path)]
env = os.environ.copy()
profile = fixture / '.godot' / 'discardable_profile'
env['APPDATA'] = str(profile / 'Roaming')
env['LOCALAPPDATA'] = str(profile / 'Local')
started = time.time()
try:
    proc = subprocess.run(args, cwd=fixture, env=env, capture_output=True, text=True, timeout=300)
    timed_out = False
    stdout, stderr, code = proc.stdout, proc.stderr, proc.returncode
except subprocess.TimeoutExpired as exc:
    timed_out = True
    stdout = exc.stdout.decode(errors='replace') if isinstance(exc.stdout, bytes) else (exc.stdout or '')
    stderr = exc.stderr.decode(errors='replace') if isinstance(exc.stderr, bytes) else (exc.stderr or '')
    code = None
(evidence / 'positive_native_04.stdout.log').write_text(stdout, encoding='utf-8')
(evidence / 'positive_native_04.stderr.log').write_text(stderr, encoding='utf-8')
meta = {'executable':str(exe),'arguments':args[1:],'working_directory':str(fixture),'environment':{'APPDATA':env['APPDATA'],'LOCALAPPDATA':env['LOCALAPPDATA']},'exit_code':code,'timed_out':timed_out,'elapsed_seconds':round(time.time()-started,3),'result_exists':result_path.exists(),'capture_exists':capture_path.exists(),'saved_source_exists':save_path.exists(),'request_sha256':hashlib.sha256(request_path.read_bytes()).hexdigest()}
(evidence / 'positive_native_04.invocation.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
print(json.dumps(meta))
print(stdout)
if stderr: print(stderr,file=sys.stderr)

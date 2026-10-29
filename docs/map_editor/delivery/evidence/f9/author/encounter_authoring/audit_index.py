"""Check exact index bytes of staged evidence and encounter tests."""
import hashlib, json, subprocess
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
output = HERE / 'index_byte_audit.json'
relative_output = output.relative_to(ROOT).as_posix()
paths = subprocess.check_output(['git','-C',str(ROOT),'diff','--cached','--name-only','-z']).decode('utf-8').split('\0')
paths = [p for p in paths if p and p != relative_output and (p.startswith('docs/map_editor/delivery/evidence/f9/') or p.startswith('tests/map_editor_encounter_authoring'))]
rows = []
for p in paths:
    raw = (ROOT/p).read_bytes()
    staged = subprocess.check_output(['git','-C',str(ROOT),'show',':'+p])
    rows.append({'path':p,'sha256':hashlib.sha256(raw).hexdigest(),'index_sha256':hashlib.sha256(staged).hexdigest(),'equal':raw == staged})
assert all(r['equal'] for r in rows)
output.write_text(json.dumps({'ok':True,'scope':'staged raw evidence and encounter tests; excludes this generated receipt to avoid self-reference','count':len(rows),'rows':rows},indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps({'ok':True,'count':len(rows),'mismatches':0}))

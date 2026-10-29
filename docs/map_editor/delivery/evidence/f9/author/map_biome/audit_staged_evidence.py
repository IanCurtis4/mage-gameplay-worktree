"""Verify exact raw evidence and map bytes in the Git index before committing."""
import hashlib
import json
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
paths = subprocess.check_output(['git', '-C', str(ROOT), 'diff', '--cached', '--name-only', '-z']).decode('utf-8').split('\0')
paths = sorted({p for p in paths if p.startswith('docs/map_editor/delivery/evidence/f9/') and p != (HERE / 'staged_evidence_byte_audit.json').relative_to(ROOT).as_posix()})
paths.append('data/map_authoring/sanctuary_woods.map.json')
rows = []
for path in paths:
    raw = (ROOT / path).read_bytes()
    blob = subprocess.check_output(['git', '-C', str(ROOT), 'show', ':' + path])
    rows.append({'path': path, 'worktree_sha256': hashlib.sha256(raw).hexdigest(), 'git_index_sha256': hashlib.sha256(blob).hexdigest(), 'equal': raw == blob})
assert all(r['equal'] for r in rows)
output = {'ok': True, 'scope': 'staged raw evidence plus final map source; excludes this generated receipt to avoid self-reference; prose docs outside raw evidence may use Git text normalization', 'count': len(rows), 'rows': rows}
(HERE / 'staged_evidence_byte_audit.json').write_text(json.dumps(output, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps({'ok': True, 'count': len(rows), 'mismatches': 0}))

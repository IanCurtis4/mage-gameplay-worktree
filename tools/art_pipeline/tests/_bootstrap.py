"""Put tools/ on sys.path so `import art_pipeline` works under `python -I` (which ignores cwd)."""
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[2]
REPO = TOOLS.parent
PIPELINE = TOOLS / "art_pipeline"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

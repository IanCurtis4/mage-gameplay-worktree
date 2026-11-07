"""Prepare the P4 Spiritualist candidate in evidence; never overwrite runtime atlases."""
from pathlib import Path
from PIL import Image
import importlib.util
import json
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/art/e08_characters/spiritualist_source.png'
OUTPUT = ROOT / 'docs/epics/e08_evidence/p4/spiritualist_candidate.png'

def main() -> None:
    source = Image.open(SOURCE).convert('RGBA')
    if source.height != 2 * source.width:
        raise ValueError('Expected a four-column, eight-row source sheet')
    with tempfile.TemporaryDirectory(prefix='ragrpg_p4_') as temp:
        stage = Path(temp)
        for half, suffix in ((0, ''), (1, '_extra')):
            source.crop((0, half * source.height // 2, source.width, (half + 1) * source.height // 2)).save(stage / f'spiritualist_candidate{suffix}.png')
        spec = importlib.util.spec_from_file_location('animation_pipeline', ROOT / 'tools/prepare_animation_assets.py')
        if spec is None or spec.loader is None:
            raise RuntimeError('Cannot load existing animation pipeline')
        pipeline = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(pipeline)
        pipeline.SOURCE = stage
        pipeline.DEST = stage
        report = pipeline.prepare('spiritualist_candidate')
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_bytes((stage / 'spiritualist_candidate.png').read_bytes())
    print(json.dumps(report, ensure_ascii=False))

if __name__ == '__main__':
    main()

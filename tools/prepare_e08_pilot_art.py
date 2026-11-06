"""Prepare E08 forest variants with the existing 32-frame animation pipeline."""
from pathlib import Path
import hashlib, importlib.util, json
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / 'assets/art/e08_pilot'
DEST = ROOT / 'assets/art/animations'
class SourceMap:
    def __truediv__(self, name):
        return SOURCES / name.replace('e08_', '').replace('_extra.png', '_extra_source.png').replace('forest_wolf.png','forest_wolf_source.png').replace('forest_boar.png','forest_boar_source.png')

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    spec = importlib.util.spec_from_file_location('e08_shared_animation', ROOT / 'tools/prepare_animation_assets.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    module.SOURCE = SourceMap(); module.DEST = DEST
    report_path = DEST / 'preparation_report.json'
    report = json.loads(report_path.read_text(encoding='utf-8'))
    provenance = {'tool':'imagegen built-in; four original generated sheets, see recipes.md','reference':'assets/art/animation_sources/fixes_mobs/animal_companion{,_extra}.png; layout/style reference only','pipeline':'tools/prepare_animation_assets.py through tools/prepare_e08_pilot_art.py','sources':{},'atlases':{}}
    for name in ('e08_forest_wolf','e08_forest_boar'):
        entries = [module.SOURCE / (name+'.png'),module.SOURCE / (name+'_extra.png')]
        before = {str(p.relative_to(ROOT)).replace('\\','/'):digest(p) for p in entries}
        prepared = module.prepare(name)
        atlas = DEST / (name+'.png')
        image = Image.open(atlas).convert('RGBA')
        frames = [image.crop(((i%4)*64,(i//4)*64,(i%4+1)*64,(i//4+1)*64)) for i in range(32)]
        assert image.size == (256,512) and all(f.getchannel('A').getbbox() for f in frames)
        assert len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames}) == 32
        assert before == {str(p.relative_to(ROOT)).replace('\\','/'):digest(p) for p in entries}
        report[name] = prepared
        provenance['sources'].update(before)
        provenance['atlases'][str(atlas.relative_to(ROOT)).replace('\\','/')] = {'sha256':digest(atlas),'frames':32,'cell':[64,64],'pivot':[32,58],'bounds':prepared['frame_bounds']}
    report_path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    (SOURCES/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(provenance['atlases'],indent=2))
if __name__ == '__main__': main()

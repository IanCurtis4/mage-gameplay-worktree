"""Pack an authorized directional art recipe; source images/rigs remain authored data."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import sys
sys.dont_write_bytecode = True
from PIL import Image
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = ('south', 'north', 'east', 'west')
KINDS = ('swordsman','archer','mage','berserker','defender','hunter','sentinel','elementalist','spiritualist','geometer',
         'paladin','thaumaturge','duelist','arcane_blade',
         'acolyte','priest','cultist')
sys.path.insert(0, str(ROOT / 'tools'))
from art_pipeline.selection import load_selection  # E09: chosen source versions come from selection.json


def checked_path(folder, name, selection=None):
    if name.startswith('@'):
        # '@south' = the slot chosen by the recipe's selection.json; resolve() verifies the SHA256
        if selection is None:
            raise ValueError('Source %s needs a recipe-level selection' % name)
        path = Path(selection.resolve(name[1:])).resolve()
    else:
        path = (ROOT / name[6:]).resolve() if name.startswith('res://') else (folder / name).resolve()
    if ROOT.resolve() not in path.parents or path.suffix.lower() != '.png':
        raise ValueError('Source PNG must be inside the project')
    return path


def selection_path(name):
    path = (ROOT / name[6:]).resolve() if name.startswith('res://') else (ROOT / name).resolve()
    if ROOT.resolve() not in path.parents or path.suffix.lower() != '.json':
        raise ValueError('Selection must be a project JSON file')
    return path


def build_unit(folder, recipe):
    spec = importlib.util.spec_from_file_location('animation_pipeline', ROOT / 'tools/prepare_animation_assets.py')
    pipeline = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pipeline)
    cells, records, generated_boxes = [], [], []
    selection = load_selection(selection_path(recipe['selection'])) if recipe.get('selection') else None
    for direction in DIRECTIONS:
        view = recipe['views'][direction]
        native = bool(view.get('native_cells', False))
        indices = view.get('indices', list(range(16)))
        if len(indices) != 16:
            raise ValueError('Each view must map exactly sixteen poses')
        grid = view.get('grid', [4,4])
        if grid[0] != 4 or grid[1] not in (4,8):
            raise ValueError('Only the declared source grids are supported')
        for pose, source_index in enumerate(indices):
            selected = view.get('overrides', {}).get(str(pose), view['source'])
            source_path = checked_path(folder, selected, selection)
            image = Image.open(source_path).convert('RGBA')
            row, col = divmod(source_index, 4)
            if row >= grid[1] or source_index < 0:
                raise ValueError('Source pose outside declared grid')
            region = (round(col*image.width/4),round(row*image.height/grid[1]),
                      round((col+1)*image.width/4),round((row+1)*image.height/grid[1]))
            cell = image.crop(region)
            if native:
                if cell.size != (64,64):
                    raise ValueError('Native cells must already be64x64; no resampling')
            else:
                cell = pipeline.keep_character(pipeline.remove_matte(cell))
            box = cell.getchannel('A').getbbox()
            if not box:
                raise ValueError('Empty source pose')
            if not native:
                generated_boxes.append(box)
            cells.append((cell,box,native))
            record = {'direction':direction,'pose':pose,'source':str(source_path.relative_to(ROOT)),
                      'source_index':source_index,'native_cells':native}
            if selection is not None:
                record['source_sha256'] = hashlib.sha256(source_path.read_bytes()).hexdigest()
            records.append(record)
    if generated_boxes:
        idle = [cells[i][1] for d in range(4) for i in range(d*16,d*16+4) if not cells[i][2]]
        scale = float(recipe.get('target_height',50)) / float(np.median([b[3]-b[1] for b in idle[:4]]))
        for box in generated_boxes:
            scale = min(scale,58.0/(box[2]-box[0]),56.0/(box[3]-box[1]))
    else:
        scale = 1.0
    atlas = Image.new('RGBA',(256,1024))
    for index,(cell,box,native) in enumerate(cells):
        if native:
            atlas.alpha_composite(cell,((index%4)*64,(index//4)*64))
            continue
        crop = cell.crop(box)
        size = (max(1,round(crop.width*scale)),max(1,round(crop.height*scale)))
        reduced = crop.resize(size,Image.Resampling.LANCZOS)
        data = np.array(reduced)
        data[:,:,3] = np.where(data[:,:,3]>=128,255,0)
        data[data[:,:,3]==0,:3] = 0
        atlas.alpha_composite(Image.fromarray(data),((index%4)*64+32-size[0]//2,(index//4)*64+58-size[1]))
    pixels = bytearray(atlas.tobytes())
    for offset in range(0,len(pixels),4):
        if pixels[offset+3]==0:
            pixels[offset:offset+3] = bytes(3)
    digest = hashlib.sha256(pixels).hexdigest()
    return atlas, {'scale':scale,'rgba_sha256':digest,'frames':records}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('actor_kind',choices=KINDS)
    parser.add_argument('--atlas-only',action='store_true',help='Authorship only; does not emit a manifest')
    args = parser.parse_args()
    folder = ROOT / 'assets/art/e08_characters/directional' / args.actor_kind
    recipe = json.loads((folder/'source_recipe.json').read_text(encoding='utf-8'))
    if recipe.get('actor_kind') != args.actor_kind:
        raise SystemExit('Recipe kind mismatch')
    calibration = None
    if not args.atlas_only:
        calibration = json.loads((folder/'calibration.json').read_text(encoding='utf-8'))
        if calibration.get('actor_kind') != args.actor_kind or len(calibration.get('frames',[]))!=64:
            raise SystemExit('Authored calibration must bind this identity and64poses')
    atlas, report = build_unit(folder,recipe)
    if calibration is not None:
        if calibration.get('authored_rgba_sha256') != report['rgba_sha256']:
            raise SystemExit('Calibration raster hash no longer matches; re-author before packing')
        for index,frame in enumerate(calibration['frames']):
            tile = atlas.crop((index%4*64,index//4*64,index%4*64+64,index//4*64+64))
            if frame['ground_y'] != tile.getchannel('A').getbbox()[3]-1:
                raise SystemExit(f'Authored ground no longer matches pose{index}')
    atlas.save(folder/'body.png')
    atlas.save(folder/'weaponless.png')
    if calibration is not None:
        base = 'res://assets/art/e08_characters/directional/'+args.actor_kind+'/'
        manifest = {'format':'ragrpg_directional_animation_v2','actor_kind':args.actor_kind,'pivot':[32,58],
                    'body':{'path':base+'body.png','rgba_sha256':report['rgba_sha256']},
                    'weaponless':{'path':base+'weaponless.png','rgba_sha256':report['rgba_sha256']},'frames':calibration['frames']}
        for key, name in (('bare_head', 'bare_head.png'), ('npc_body', 'npc_body.png')):
            # optional hand-authored variants kept next to the atlas (same canonical RGBA hash rule as the body):
            # bare_head = hair-free head source; npc_body = the NPC body the manifest points to (Archer)
            variant_path = folder/name
            if not variant_path.exists():
                continue
            variant = bytearray(Image.open(variant_path).convert('RGBA').tobytes())
            for offset in range(0,len(variant),4):
                if variant[offset+3]==0:
                    variant[offset:offset+3] = bytes(3)
            entry = {'path':base+name,'rgba_sha256':hashlib.sha256(variant).hexdigest()}
            if key == 'npc_body':
                manifest['body'] = entry
            else:
                manifest[key] = entry
        (folder/'presentation.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+chr(10),encoding='utf-8')
    report['mode'] = 'atlas_only_not_calibrated' if args.atlas_only else 'authored_unit'
    print(json.dumps(report))


if __name__=='__main__':
    main()

"""Rebuild Spiritualist bitmaps from preserved imagegen sources (Pillow).

Presentation only. Local cleanup/cropping was explicitly authorized by user.
Run from any directory: python tools/prepare_spiritualist_art.py
"""
from pathlib import Path
from collections import deque
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/art'


def cell(image, x, y, cols, rows):
    return image.crop((round(x * image.width / cols), round(y * image.height / rows),
                       round((x + 1) * image.width / cols), round((y + 1) * image.height / rows)))


def clean_character(im):
    im = im.copy()
    alpha = im.getchannel('A')
    mask = alpha.point(lambda a: 255 if a >= 70 else 0)
    pixels = mask.load()
    visited = set()
    clusters = []
    for y in range(im.height):
        for x in range(im.width):
            if not pixels[x, y] or (x, y) in visited:
                continue
            queue = deque([(x, y)])
            visited.add((x, y))
            component = []
            while queue:
                p = queue.popleft()
                component.append(p)
                for q in ((p[0]-1,p[1]),(p[0]+1,p[1]),(p[0],p[1]-1),(p[0],p[1]+1)):
                    if 0 <= q[0] < im.width and 0 <= q[1] < im.height and q not in visited and pixels[q]:
                        visited.add(q)
                        queue.append(q)
            clusters.append(component)
    assert clusters, 'Empty generated pose'
    primary = max(clusters, key=len)
    px = [p[0] for p in primary]
    py = [p[1] for p in primary]
    primary_bounds = (min(px)-10, min(py)-10, max(px)+10, max(py)+10)
    threshold = max(80, int(len(primary) * .008))
    for component in clusters:
        near_body = any(primary_bounds[0] <= p[0] <= primary_bounds[2] and primary_bounds[1] <= p[1] <= primary_bounds[3] for p in component)
        if len(component) < threshold or not near_body:
            for p in component:
                pixels[p] = 0
    # Preserve source opacity where retained, remove only dust.
    alpha.putdata([a if m else 0 for a, m in zip(alpha.getdata(), mask.getdata())])
    im.putalpha(alpha)
    return im.crop(im.getbbox())


def build():
    source = Image.open(ART / 'animation_sources/spiritualist_source.png').convert('RGBA')
    # Imagegen spacing is not exactly uniform: locate the eight occupied bands
    # before cropping, so boots never leak into the following animation row.
    alpha = source.getchannel('A')
    bands = []
    start = last = None
    for y in range(source.height):
        occupied = sum(alpha.getpixel((x,y)) > 100 for x in range(source.width)) > 25
        if occupied:
            if start is None:
                start = y
            last = y
        elif start is not None and y-last > 12:
            bands.append((start,last+1))
            start = None
    if start is not None:
        bands.append((start,last+1))
    assert len(bands) == 8, 'Review source spacing before processing'
    row_edges = [0] + [(bands[i][1]+bands[i+1][0])//2 for i in range(7)] + [source.height]
    # Generated rear-cast row starts with two front-facing poses: replace them
    # with genuine rear idle/raised/release/recovery poses; never show a face
    # while the gameplay facing is rear. Keep all originals for audit.
    order = list(range(32))
    order[20:24] = [16, 22, 23, 17]
    poses = [clean_character(source.crop((round(i%4*source.width/4), row_edges[i//4], round((i%4+1)*source.width/4), row_edges[i//4+1]))) for i in order]
    scale = min(min(56 / p.width, 54 / p.height) for p in poses)
    atlas = Image.new('RGBA', (256, 512))
    for index, pose in enumerate(poses):
        pose = pose.resize((max(1, round(pose.width * scale)), max(1, round(pose.height * scale))), Image.Resampling.NEAREST)
        feet = []
        if index < 28:
            for y in range(max(0, pose.height - 6), pose.height):
                for x in range(pose.width):
                    r,g,b,a = pose.getpixel((x,y))
                    if a > 128 and r > 36 and r > b * 1.2:
                        feet.append(x)
        foot_x = sorted(feet)[len(feet)//2] if feet else pose.width // 2
        left = max(2, min(32 - foot_x, 62 - pose.width))
        atlas.alpha_composite(pose, (index % 4 * 64 + left, index // 4 * 64 + 59 - pose.height))
    atlas.save(ART / 'animations/spiritualist.png')

    effects = Image.open(ART / 'animation_sources/spiritualist_vfx_source.png').convert('RGBA')
    vfx = Image.new('RGBA', (384,384))
    names = ['soul_wisp', 'curse_sigil', 'spectral_burst', 'ritual_halo']
    metadata = {'cell': [96,96], 'columns': 4, 'rows': {}}
    for row, name in enumerate(names):
        frames = [cell(effects, x, row, 4, 4) for x in range(4)]
        boxes = [f.getchannel('A').point(lambda a: 255 if a >= 8 else 0).getbbox() for f in frames]
        assert all(boxes)
        bounds = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
        factor = min(84/(bounds[2]-bounds[0]), 80/(bounds[3]-bounds[1]))
        size = (round((bounds[2]-bounds[0])*factor), round((bounds[3]-bounds[1])*factor))
        offset = ((96-size[0])//2, (96-size[1])//2)
        strip = Image.new('RGBA',(384,96))
        for i, frame in enumerate(frames):
            pose = frame.crop(bounds).resize(size, Image.Resampling.NEAREST)
            strip.alpha_composite(pose,(i*96+offset[0],offset[1]))
        vfx.alpha_composite(strip,(0,row*96))
        strip.save(ART / ('vfx/spiritualist_' + name + '.png'))
        # Halo origin is its ground ellipse, not the top of its rising wisps.
        pivot = [48, round((180-bounds[1])*factor+offset[1])] if row == 3 else [48,48]
        metadata['rows'][name] = {'row':row,'pivot':pivot,'frames':4}
    vfx.save(ART / 'vfx/spiritualist_effects.png')
    (ART / 'vfx/spiritualist_effects.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')

    preview = Image.new('RGB',(1210,1570),'#202b30')
    preview.paste(atlas.resize((768,1536),Image.Resampling.NEAREST),(10,25),atlas.resize((768,1536),Image.Resampling.NEAREST))
    draw = ImageDraw.Draw(preview)
    draw.text((12,5),'ESPIRITUALISTA - 32 poses / 64 px',fill='white')
    for row,name in enumerate(names):
        strip = vfx.crop((0,row*96,384,(row+1)*96))
        draw.text((795,30+row*200),name,fill='white')
        preview.paste(strip,(795,55+row*200),strip)
    (ROOT/'docs/art').mkdir(parents=True,exist_ok=True)
    preview.save(ROOT/'docs/art/spiritualist_assets.png')
    # Side-by-side animation proof: front/back walking, front/back cast and VFX.
    animation_frames = []
    for tick in range(16):
        canvas = Image.new('RGB',(900,250),'#263139' if tick < 8 else '#b5b5a2')
        label = ImageDraw.Draw(canvas)
        for column,(name,start_frame) in enumerate([('Walk front',4),('Walk rear',12),('Cast front',8),('Cast rear',20)]):
            frame = cell(atlas,(start_frame+tick%4)%4,(start_frame+tick%4)//4,4,8).resize((128,128),Image.Resampling.NEAREST)
            canvas.paste(frame,(column*145+8,45),frame)
            label.text((column*145+8,15),name,fill='#ffffff' if tick<8 else '#20202a')
        for row in range(4):
            effect = cell(vfx,tick%4,row,4,4)
            canvas.paste(effect,(605+row%2*140,20+row//2*110),effect)
        animation_frames.append(canvas)
    animation_frames[0].save(ROOT/'docs/art/spiritualist_animation_preview.gif',save_all=True,append_images=animation_frames[1:],duration=160,loop=0,disposal=2)

    # Validate produced asset contracts independently of Godot import.
    assert atlas.size == (256,512) and atlas.getchannel('A').getextrema() == (0,255)
    for i in range(32):
        frame = cell(atlas,i%4,i//4,4,8)
        bbox = frame.getbbox()
        assert bbox and bbox[3] == 59 and bbox[0] > 0 and bbox[2] < 64
    for row in range(4):
        frames = [cell(vfx,x,row,4,4) for x in range(4)]
        assert len({f.tobytes() for f in frames}) == 4
        assert all(f.getbbox() and f.getchannel('A').getextrema()[0] == 0 for f in frames)
    assert len({poses[i].tobytes() for i in range(4,8)}) == 4
    assert len({poses[i].tobytes() for i in range(12,16)}) == 4
    print('PASS: 32 aligned poses, 4 distinct front/rear walk frames, 16 animated VFX frames with alpha. Scale:',scale)


if __name__ == '__main__':
    build()

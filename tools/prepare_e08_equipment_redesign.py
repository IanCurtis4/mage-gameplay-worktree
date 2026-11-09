from PIL import Image, ImageDraw
from pathlib import Path
import json, hashlib, sys
P=Path('assets/art/e08_equipment_redesign')
rows={
'heads_basic_source_v1.png':[None,'class_set_archer_head',None,'class_set_defender_head'],
'heads_basic_source_v3.png':[None,None,'class_set_mage_head',None],
'heads_sets_a_source_v1.png':['class_set_berserker_head','class_set_elementalist_head','class_set_spiritualist_head',None],
'heads_sets_a_source_v2.png':[None,None,None,'class_set_sentinel_head'],
'heads_sets_b_source_v1.png':['class_set_hunter_head','class_set_mg_ar_head',None,'shared_set_mid_head'],
'heads_sets_b_source_v2.png':[None,None,'shared_set_low_head',None],
'heads_examples_source_v1.png':['shared_set_high_head','apple_arrow_study','eggshell_study'],
'heads_sets_c_source_v2.png':['class_set_swordsman_head'],
'heads_basic_source_v2.png':['pilot_head']}
def normalize_invisible(im):
    data=bytearray(im.tobytes())
    for i in range(0,len(data),4):
        if data[i+3]==0: data[i:i+3]=b'\0\0\0'
    return Image.frombytes('RGBA',im.size,bytes(data))
def visible_bbox(im):
    return im.getchannel('A').point(lambda x: 255 if x>=32 else 0).getbbox()
def fit(im, size):
    box=visible_bbox(im)
    if box is None: raise ValueError('empty')
    # Preserve anti-aliased pixels immediately around the measured artwork.
    l,t,r,b=box; box=(max(0,l-3),max(0,t-3),min(im.width,r+3),min(im.height,b+3))
    im=im.crop(box); im.thumbnail(size,Image.Resampling.LANCZOS)
    return im
# --- P7-C8: Codex redraws of two head pieces (post-closure revision, same ids/paths) -------------------
# python tools/prepare_e08_equipment_redesign.py p7_head_art
# Sources: 2172x724 transparent RGBA, four views side by side in the same order as the 384x96 sheets
# (S,N,E,W; the E/W mapping was checked against the previous sheets' gem/buckle side). Each view is cropped by its
# alpha bbox (alpha>=32 +3 px margin), ALL views of one piece share one scale (so the 4 views keep their relative
# size; the widest view fills 76 px = 19 logical px), the result is placed like the old pipeline (x centred,
# bottom at y=68 of the 96x96 cell), and RGB under alpha 0 is alpha-bleeded (nearest opaque colour, 4 px).
P7_STAGING = P/'p7_head_fit_staging'
P7_PIECES = {'class_set_elementalist_head': 'class_set_elementalist_head_source_v1.png',
             'class_set_hunter_head': 'class_set_hunter_head_source_v1.png'}
P7_OUT = Path('assets/art/equipment/headgear')
P7_MAX_W = 76
def alpha_bleed(im, radius=4):
    import numpy as np
    a = np.array(im); rgb = a[:, :, :3].copy(); alpha = a[:, :, 3]
    known = alpha > 0
    for _ in range(radius):
        newrgb = rgb.copy(); newknown = known.copy()
        for dy, dx in ((-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)):
            sh_known = np.roll(known, (dy, dx), (0, 1)); sh_rgb = np.roll(rgb, (dy, dx), (0, 1))
            take = ~newknown & sh_known
            newrgb[take] = sh_rgb[take]; newknown |= take
        rgb, known = newrgb, newknown
    out = np.zeros_like(a); out[:, :, :3] = np.where(known[:, :, None], rgb, 0); out[:, :, 3] = alpha
    return Image.fromarray(out, 'RGBA')
def p7_pack(piece):
    src = Image.open(P7_STAGING/P7_PIECES[piece]).convert('RGBA')
    vw = src.width // 4
    crops = []
    for v in range(4):
        view = alpha_bleed(src.crop((v*vw, 0, (v+1)*vw, src.height)))
        box = visible_bbox(view)
        l, t, r, b = box; box = (max(0, l-3), max(0, t-3), min(view.width, r+3), min(view.height, b+3))
        crops.append(view.crop(box))
    scale = P7_MAX_W / max(c.width for c in crops)
    atlas = Image.new('RGBA', (384, 96)); boxes = []
    for v, c in enumerate(crops):
        o = c.resize((max(1, round(c.width*scale)), max(1, round(c.height*scale))), Image.Resampling.LANCZOS)
        x = v*96 + (96-o.width)//2; y = 68 - o.height
        atlas.alpha_composite(o, (x, y)); boxes.append([x-v*96, y, x-v*96+o.width, y+o.height])
    atlas = alpha_bleed(atlas); atlas.save(P7_OUT/(piece+'.png'))
    print(piece, 'scale %.4f' % scale, boxes)
if len(sys.argv) > 1 and sys.argv[1] == 'p7_head_art':
    for piece in P7_PIECES: p7_pack(piece)
    sys.exit(0)
ranges={
'heads_basic_source_v1.png':([0,254,500,765,1024],[0,400,760,1110,1536]),
'heads_sets_a_source_v1.png':([0,244,449,709,1024],[0,390,770,1150,1536]),
'heads_sets_b_source_v1.png':([0,266,458,737,1024],[0,400,770,1140,1536]),
'heads_examples_source_v1.png':([0,282,677,1024],[0,400,780,1155,1536]),
'heads_sets_c_source_v2.png':([0,724],[0,520,1005,1590,2172]),
'heads_basic_source_v2.png':([0,724],[0,540,1070,1600,2172])}
ranges['heads_basic_source_v3.png']=ranges['heads_basic_source_v1.png']
ranges['heads_sets_a_source_v2.png']=ranges['heads_sets_a_source_v1.png']
ranges['heads_sets_b_source_v2.png']=ranges['heads_sets_b_source_v1.png']
entries={}
for source,names in rows.items():
    src=Image.open(P/source).convert('RGBA')
    for row,name in enumerate(names):
        if name is None: continue
        atlas=Image.new('RGBA',(384,96))
        boxes=[]
        for col in range(4):
            ys,xs=ranges[source]; x0=xs[col]; x1=xs[col+1]; y0=ys[row]; y1=ys[row+1]
            obj=fit(src.crop((x0,y0,x1,y1)),(76,64))
            x=col*96+(96-obj.width)//2; y=68-obj.height
            atlas.alpha_composite(obj,(x,y)); boxes.append([x-col*96,y,x-col*96+obj.width,y+obj.height])
        atlas=normalize_invisible(atlas); atlas.save(P/(name+'.png'))
        entries[name]={'file':name+'.png','views':['S','N','E','W'],'logical_cell':[24,24],'anchor':[12,13],'bbox_4x':boxes,'status':'staging_unverified'}
weapon_specs={'sword':([16,32],[8,25]),'axe':([20,32],[10,25]),'staff':([16,40],[7,30]),'bow':([20,34],[14,17]),'shield':([20,26],[10,13]),'prismatic_focus':([14,20],[7,16]),'wooden_beads':([12,12],[6,5])}
src=Image.open(P/'weapons_source_v1.png').convert('RGBA')
edges=[0,285,625,930,1255,1620,1870,2172]
for i,(name,(size,grip)) in enumerate(weapon_specs.items()):
    canvas=Image.new('RGBA',(size[0]*4,size[1]*4)); obj=fit(src.crop((edges[i],0,edges[i+1],src.height)),(canvas.width-4,canvas.height-4)); obj=obj.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if name=='bow' else obj; canvas.alpha_composite(obj,((canvas.width-obj.width)//2+({'axe':9,'bow':10}.get(name,0)),(canvas.height-obj.height)//2)); canvas=normalize_invisible(canvas); canvas.save(P/(name+'.png'))
    entries[name]={'file':name+'.png','logical_size':size,'grip':grip,'bbox_4x':visible_bbox(canvas),'status':'grip_unverified'}
(P/'presentation.json').write_text(json.dumps({'stage_only':True,'entries':entries},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
# Contact sheet shows every extracted sprite on light and dark, 1x and 4x.
heads=list(entries)[:16]; weapons=list(weapon_specs)
out=Image.new('RGB',(1152, (len(heads)+len(weapons))*106+1480),'white'); d=ImageDraw.Draw(out)
for i,name in enumerate(heads+weapons):
    y=i*106; d.text((4,y+3),name,fill='black'); im=Image.open(P/(name+'.png')).convert('RGBA')
    if name in heads: tiles=[im.crop((j*96,0,(j+1)*96,96)) for j in range(4)]
    else: tiles=[im]
    for j,tile in enumerate(tiles):
        for k,bg in enumerate(((238,235,225),(35,40,49))):
            x=220+j*220+k*105; d.rectangle((x,y,x+99,y+99),fill=bg)
            out.paste(tile,(x+(100-tile.width)//2,y+(100-tile.height)//2),tile)
    tiny=im.resize((max(1,im.width//4),max(1,im.height//4)),Image.Resampling.LANCZOS)
    out.paste(tiny,(1050,y+36),tiny)
# Mechanical comparison against four authored idle poses; no claim of native fit.
body=Image.open('assets/art/e08_characters/directional/spiritualist/body.png').convert('RGBA')
poses=json.loads(Path('assets/art/e08_characters/directional/spiritualist/presentation.json').read_text(encoding='utf-8'))['frames']
helmet=Image.open(P/'pilot_head.png').convert('RGBA'); base=(len(heads)+len(weapons))*106
d.text((5,base+3),'Espiritualista: sem elmo / elmo proposto, 4x e 1x',fill='black')
for j,frame in enumerate((0,16,32,48)):
    cell=body.crop(((frame%4)*64,(frame//4)*64,(frame%4+1)*64,(frame//4+1)*64))
    head=helmet.crop((j*96,0,(j+1)*96,96)).resize((24,24),Image.Resampling.LANCZOS)
    pt=poses[frame]['head']['point']; dressed=cell.copy(); dressed.alpha_composite(head,(pt[0]-12,pt[1]-13))
    for k,im in enumerate((cell,dressed)):
        x=10+j*280; y=base+28+k*275; tile=im.resize((256,256),Image.Resampling.NEAREST); out.paste(tile,(x,y),tile); out.paste(im,(x+205,y+200),im)
for row,name in enumerate(('class_set_mage_head','class_set_sentinel_head','shared_set_low_head')):
    y=base+590+row*170; d.text((5,y),name+' — Espiritualista equipada 2x / 1x',fill='black')
    h=Image.open(P/(name+'.png')).convert('RGBA')
    for j,frame in enumerate((0,16,32,48)):
        cell=body.crop(((frame%4)*64,(frame//4)*64,(frame%4+1)*64,(frame//4+1)*64))
        head=h.crop((j*96,0,(j+1)*96,96)).resize((24,24),Image.Resampling.LANCZOS); pt=poses[frame]['head']['point']; cell.alpha_composite(head,(pt[0]-12,pt[1]-13))
        tile=cell.resize((128,128),Image.Resampling.NEAREST); x=10+j*280; out.paste(tile,(x,y+22),tile); out.paste(cell,(x+145,y+54),cell)
mage=Image.open('assets/art/e08_characters/directional/mage/body.png').convert('RGBA')
mage_poses=json.loads(Path('assets/art/e08_characters/directional/mage/presentation.json').read_text(encoding='utf-8'))['frames']
for row,name in enumerate(('pilot_head','class_set_mage_head')):
    y=base+1100+row*170; d.text((5,y),name+' — Mago equipado 2x / 1x',fill='black'); h=Image.open(P/(name+'.png')).convert('RGBA')
    for j,frame in enumerate((0,16,32,48)):
        cell=mage.crop(((frame%4)*64,(frame//4)*64,(frame%4+1)*64,(frame//4+1)*64))
        head=h.crop((j*96,0,(j+1)*96,96)).resize((24,24),Image.Resampling.LANCZOS); pt=mage_poses[frame]['head']['point']; cell.alpha_composite(head,(pt[0]-12,pt[1]-13))
        tile=cell.resize((128,128),Image.Resampling.NEAREST); x=10+j*280; out.paste(tile,(x,y+22),tile); out.paste(cell,(x+145,y+54),cell)
out.save(P/'contact_sheet.png')


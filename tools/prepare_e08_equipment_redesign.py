from PIL import Image, ImageDraw
from pathlib import Path
import json, hashlib
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


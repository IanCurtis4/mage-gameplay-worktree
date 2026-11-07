"""Deterministic geometric TEST fixture. No production artwork is generated."""
from pathlib import Path
from PIL import Image, ImageDraw
import json, hashlib
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'tests/fixtures/e08_directional'
def main():
    DEST.mkdir(parents=True,exist_ok=True)
    records={}
    for name,base in [('body',(150,110,210)),('weaponless',(90,150,210))]:
        im=Image.new('RGBA',(256,1024))
        for i in range(64):
            tile=Image.new('RGBA',(64,64)); draw=ImageDraw.Draw(tile)
            direction,pose=divmod(i,16)
            color=[(50,120,180),(100,160,90),(190,130,50),(170,80,150)][direction]
            draw.rectangle((20,16,44,51),fill=(*color,255))
            draw.rectangle((22,52,29,57),fill=(*base,255));draw.rectangle((35,52,42,57),fill=(*base,255))
            draw.rectangle((22,31,26,37),fill=(240,195,150,255));draw.rectangle((38,31,42,37),fill=(240,195,150,255))
            # Explicit asymmetric view marker and per-pose bit code.
            draw.rectangle((21+direction*4,19,23+direction*4,23),fill=(250,240,120,255))
            for bit in range(4):
                if pose & (1<<bit):draw.rectangle((22+bit*5,44,24+bit*5,46),fill=(235,220,240,255))
            im.paste(tile,((i%4)*64,(i//4)*64))
        im.save(DEST/f'{name}.png')
        records[name]={'path':f'res://tests/fixtures/e08_directional/{name}.png','rgba_sha256':hashlib.sha256(im.tobytes()).hexdigest()}
    frames=[]
    for i in range(64):
        frame={'ground_y':57,'slots':{},'head':{'point':[32,17],'angle':1.2 if i%16>=14 else 0.0,'depth':1,'flip':False,'visible':True}}
        for slot,point,fingers,depth in [('main_hand',[24,34],[23,33,3,3],1),('off_hand',[40,34],[39,33,3,3],0),('arms',[38,34],[37,33,3,3],1)]:
            frame['slots'][slot]={'point':point,'fingers':fingers,'angle':0.0,'depth':depth,'flip':i//16==3,'angle_overrides':{},'depth_overrides':{}}
        frames.append(frame)
    manifest={'format':'ragrpg_directional_animation_v2','actor_kind':'mage','pivot':[32,58],**records,'frames':frames}
    (DEST/'presentation.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    enemy=DEST/'enemy'; enemy.mkdir(exist_ok=True)
    (enemy/'body.png').write_bytes((DEST/'body.png').read_bytes())
    enemy_manifest=json.loads(json.dumps(manifest)); enemy_manifest['actor_kind']='warrior'; enemy_manifest['weaponless']=None
    enemy_manifest['body']['path']='res://tests/fixtures/e08_directional/enemy/body.png'
    (enemy/'presentation.json').write_text(json.dumps(enemy_manifest,indent=2)+'\n',encoding='utf-8')
    (DEST/'README.md').write_text('# Fixture sintética direcional E08\n\n64 blocos geométricos com marcadores de vista e pose; NÃO são sprites de produto.\nRegeneração: tools/prepare_e08_directional_fixture.py. Os hashes do manifesto\nsão SHA256 dos bytesRGBA8 descomprimidos (RGB zerado quando alpha=0),\npara ignorar apenas a correção invisível de bordas do importador, não dos PNG.\nSul/norte/leste/oeste,16poses cada: idle4,walk4,ação4,dano2,morte2.\nPontos/fingers são geometria de teste, não calibração anatômica aprovada.\n',encoding='utf-8')
if __name__=='__main__':main()

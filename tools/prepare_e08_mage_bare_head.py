"""Compose authored mage head crops while preserving protected original pixels."""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];D=ROOT/'assets/art/e08_head_fit/mage';ORIGINAL=ROOT/'assets/art/e08_characters/directional/mage/body.png';RIG=ROOT/'assets/art/e08_characters/directional/mage/calibration.json'
def digest(im):
 a=np.array(im.convert('RGBA'));a[a[:,:,3]==0,:3]=0;return hashlib.sha256(a.tobytes()).hexdigest()
def main():
 c=json.loads((D/'calibration.json').read_text(encoding='utf-8'));orig=Image.open(ORIGINAL).convert('RGBA')
 if digest(orig)!=c['original_rgba_sha256'] or len(c['frames'])!=64:raise ValueError('Original body or calibration mismatch')
 rig=json.loads(RIG.read_text(encoding='utf-8'));result=orig.copy();sources={}
 for f in c['frames']:
  i=f['index'];name=f['source'];sources.setdefault(name,Image.open(D/name).convert('RGBA').resize((256,256),Image.Resampling.LANCZOS));s=sources[name];pose=f['source_cell'];crop=s.crop((pose%4*64,pose//4*64,pose%4*64+64,pose//4*64+64));dx,dy=f['offset'];dest=Image.new('RGBA',(64,64));dest.paste(crop,(dx,dy));data=np.array(dest);data[:,:,3]=np.where(data[:,:,3]>=128,255,0);data[data[:,:,3]==0,:3]=0
  x=i%4*64;y=i//4*64;old=np.array(orig.crop((x,y,x+64,y+64)));mask=np.zeros((64,64),bool);x0,y0,x1,y1=f['head_region'];mask[y0:y1,x0:x1]=True
  for x0,y0,x1,y1 in f['protections']:mask[y0:y1,x0:x1]=False
  original_tile=old.copy();old[mask]=data[mask]
  if not np.array_equal(old[~mask],original_tile[~mask]):raise ValueError(f'Outside region changed {i}')
  result.paste(Image.fromarray(old),(x,y))
  for slot in ('main_hand','off_hand'):
   if i%16>=14:continue
   a=rig['frames'][i]['slots'][slot]['fingers'];x0,y0,w,h=a
   if np.any(mask[y0:y0+h,x0:x0+w]) or not np.array_equal(old[y0:y0+h,x0:x0+w],original_tile[y0:y0+h,x0:x0+w]):raise ValueError(f'Grip crop changed {i} {slot}')
  if result.crop((x,y,x+64,y+64)).getchannel('A').getbbox()[3]!=orig.crop((x,y,x+64,y+64)).getchannel('A').getbbox()[3]:raise ValueError(f'Ground changed {i}')
 result.save(D/'body.png');print('original',digest(orig),'bare',digest(result))
if __name__=='__main__':main()

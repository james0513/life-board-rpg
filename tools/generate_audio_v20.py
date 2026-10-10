"""Original deterministic synthesized score and effects; no sampled recordings.
Run from project root: python tools/generate_audio_v20.py (requires numpy).
"""
from pathlib import Path
import numpy as np, wave
ROOT=Path(__file__).resolve().parents[1]/'assets/audio'
SR=22050
rng=np.random.default_rng(20261010)
def write(path,a):
 a=np.asarray(a); peak=np.max(np.abs(a)); a=a/max(1,peak/.82)
 path.parent.mkdir(parents=True,exist_ok=True)
 with wave.open(str(path),'wb') as w:
  w.setnchannels(2 if a.ndim==2 else 1);w.setsampwidth(2);w.setframerate(SR);w.writeframes((a*32767).astype('<i2').tobytes())
def tone(midi,dur,kind='pluck'):
 t=np.arange(int(SR*dur))/SR;f=440*2**((midi-69)/12)
 env=(1-np.exp(-t*60))*np.minimum(1,(dur-t)*16)
 if kind=='bell':return env*np.exp(-t*3)*(np.sin(2*np.pi*f*t)+.3*np.sin(2*np.pi*f*2.76*t))*.5
 if kind=='pad':return env*(np.sin(2*np.pi*f*t)+.25*np.sin(2*np.pi*f*2.003*t))*.3
 return env*np.exp(-t*5)*(np.sin(2*np.pi*f*t)+.35*np.sin(4*np.pi*f*t)+.12*np.sin(6*np.pi*f*t))*.5
# Different meters, tempos, modes and motifs for each location.
configs=[('stage_1',96,4,60,[0,4,7,11],'bell'),('stage_2',112,4,62,[0,4,7,9],'pluck'),('stage_3',108,4,57,[0,3,7,10],'bell'),('stage_4',90,3,65,[0,3,7,10],'pluck'),('stage_5',100,4,50,[0,3,7,10],'pluck'),('stage_6',76,4,59,[0,4,7,11],'pad'),('battle',132,4,52,[0,3,7,10],'pluck'),('boss',144,4,48,[0,3,6,10],'pluck')]
for idx,(name,bpm,meter,root,chord,kind) in enumerate(configs):
 beat=60/bpm;length=16*meter*beat;n=int(length*SR);out=np.zeros((n,2))
 def add(a,start,gain=1,pan=0):
  indices=(int(start*SR)+np.arange(len(a)))%n
  for ch,g in enumerate([np.sqrt((1-pan)/2),np.sqrt((1+pan)/2)]):np.add.at(out[:,ch],indices,a*gain*g)
 for bar in range(16):
  offset=[0,-5,-3,-7][(bar//2)%4];base=root+offset
  for note in chord[:3]:add(tone(base+note,beat*meter*1.2,'pad'),bar*meter*beat,.19,(note-4)/14)
  for b in range(meter):
   start=(bar*meter+b)*beat
   add(tone(base-12+(7 if b%2 else 0),beat*.8),start,.5)
   for half in range(2):
    note=base+12+chord[(bar+b*2+half+idx)%4]
    if (bar+b+half)%5!=0:add(tone(note,beat*.9,kind),start+half*beat,.45,(-.45 if half else .45))
   if idx in [1,2,4,6,7]:
    t=np.arange(int(SR*.16))/SR
    drum=np.sin(2*np.pi*(55*t+7*(1-np.exp(-t*35))))*np.exp(-t*28)
    add(drum,start,.32 if b%2==0 else .16)
    noise=rng.normal(0,1,len(t))*np.exp(-t*55)
    add(noise,start+beat*.5,.035,.3)
 # Circular delay preserves loop tails at the boundary.
 out+=np.roll(out,int(beat*.75*SR),axis=0)*.16
 write(ROOT/'music'/f'{name}_loop.wav',out)
# Short attack/impact cues are separate so impacts do not cut off casting tails.
names=['hero_slash','hero_blunt','hero_bow','hero_staff','monster_claw','monster_bite','boss_swing','hit_enemy','hit_hero','hit_magic','cast_orb','cast_lightning','cast_runes','cast_stars','cast_blade','cast_ice','cast_heal','cast_burst','monster_spell','boss_spell','use_item','guard','flee']
for i,name in enumerate(names):
 dur=.48 if 'cast' in name or 'spell' in name else .18
 t=np.arange(int(SR*dur))/SR;noise=rng.normal(0,1,len(t));env=np.sin(np.pi*t/dur)**2
 if 'cast' in name or 'spell' in name:
  base=180+i*23
  if 'boss' in name:base=85
  a=sum(np.sin(2*np.pi*(base*r*t+120*t*t))*np.exp(-t*(1+k)) /(k+2) for k,r in enumerate([1,1.5,2,3]))
  if 'ice' in name or 'lightning' in name:a+=noise*.15
  if 'heal' in name:a=sum(tone(m,.48,'bell') for m in [72,76,79])*.5
 elif 'hit' in name or 'blunt' in name or 'bite' in name:
  a=(noise*.3+np.sin(2*np.pi*(95*t-90*t*t)))*np.exp(-t*22)
 elif name=='use_item':a=tone(84,dur,'bell')
 elif name=='guard':a=np.sin(2*np.pi*340*t)*np.exp(-t*15)
 else:a=noise*.22+np.sin(2*np.pi*((180+i*35)*t+1500*t*t))*.22
 write(ROOT/'sfx'/f'{name}.wav',a*env*.7)
print('Generated 8 looping scores and 23 sound effects')

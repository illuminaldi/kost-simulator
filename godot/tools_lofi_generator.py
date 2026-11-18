import numpy as np, wave
SR=44100; BPM=78; BEAT=60/BPM; BAR=BEAT*4
rng=np.random.default_rng(7)
def n2f(n): return 440*2**((n-69)/12)
# progresi jazzy (ii-V-I-vi dan variasinya), 16 bar x 2 bagian = 32 bar
A=[[50,57,60,65],[55,59,62,65],[48,55,59,64],[45,52,55,60]]   # Dm9 G7 Cmaj7 Am7
B=[[53,57,60,64],[52,56,59,62],[45,52,55,60],[50,53,57,60]]   # Fmaj7 E7 Am7 Dm7
prog=(A*2+B+A)*2
bars=len(prog); N=int(bars*BAR*SR)
out=np.zeros((N,2))
t_all=np.arange(N)/SR
def env(n,a,d):
    e=np.ones(n); ai=int(a*SR); e[:ai]=np.linspace(0,1,ai) if ai>0 else 1
    return e*np.exp(-np.arange(n)/SR/d)
def rhodes(f,dur,vel=.18):
    n=int(dur*SR); t=np.arange(n)/SR
    w=np.sin(2*np.pi*f*t+0.6*np.sin(2*np.pi*f*t)*np.exp(-t*3))+0.25*np.sin(2*np.pi*2*f*t)*np.exp(-t*4)
    w*=1+0.15*np.sin(2*np.pi*4.5*t)   # tremolo
    return w*env(n,0.01,1.6)*vel
def add(sig,start,pan=0.5):
    i=int(start*SR); j=min(N,i+len(sig)); s=sig[:j-i]
    out[i:j,0]+=s*(1-pan); out[i:j,1]+=s*pan
for b,ch in enumerate(prog):
    t0=b*BAR
    # chord: dimainkan 2x per bar sedikit di-strum
    for hit,dur in ((0,BEAT*2.2),(BEAT*2.5,BEAT*1.8)):
        for k,nn in enumerate(ch):
            add(rhodes(n2f(nn),dur,0.11),t0+hit+k*0.018,0.35+0.1*k)
    # bass
    root=ch[0]-12 if ch[0]>=48 else ch[0]
    for hit,nn,dur in ((0,root,BEAT*1.6),(BEAT*2.5,root+7,BEAT*1.2)):
        n=int(dur*SR);t=np.arange(n)/SR
        add(np.sin(2*np.pi*n2f(nn-12)*t)*env(n,0.01,0.7)*0.32,t0+hit,0.5)
    # melodi pentatonik sederhana, berbeda tiap bar tapi deterministik
    scale=[72,74,77,79,81,84]
    if b%4 in (1,3) or b>=bars//2:
        for s in range(4):
            if rng.random()<0.55:
                nn=rng.choice(scale)-(12 if rng.random()<.3 else 0)
                add(rhodes(n2f(nn),BEAT*1.2,0.07),t0+s*BEAT+rng.choice([0,BEAT/2])+0.02,0.65)
    # drum: kick, snare, hihat swing
    for s in range(8):
        tt=t0+s*BEAT/2+(0.06 if s%2 else 0)
        n=int(0.06*SR);hh=rng.normal(0,1,n)*np.exp(-np.arange(n)/SR/0.015)
        hh=np.diff(np.concatenate([[0],hh]))*0.05
        add(hh,tt,0.6)
    for kt in (0,BEAT*1.75 if b%2 else BEAT*2.5):
        n=int(0.35*SR);t=np.arange(n)/SR
        f=50+60*np.exp(-t*25)
        add(np.sin(2*np.pi*np.cumsum(f)/SR)*np.exp(-t*7)*0.55,t0+kt,0.5)
    for st in (BEAT,BEAT*3):
        n=int(0.25*SR);t=np.arange(n)/SR
        sn=rng.normal(0,1,n)*np.exp(-t*14)*0.12+np.sin(2*np.pi*190*t)*np.exp(-t*20)*0.12
        add(sn,t0+st,0.45)
# vinyl crackle + hiss
crk=np.zeros(N); idx=rng.integers(0,N,int(N/SR*14)); crk[idx]=rng.normal(0,0.25,len(idx))
hiss=rng.normal(0,0.004,N)
out[:,0]+=crk+hiss; out[:,1]+=np.roll(crk,37)+hiss
# lowpass sederhana (warm), kompresi lembut
from numpy.fft import rfft,irfft
for c in range(2):
    F=rfft(out[:,c]); fr=np.fft.rfftfreq(N,1/SR); F*=1/(1+(fr/5200)**4); out[:,c]=irfft(F,N)
# loop mulus: ekor dibungkus ke awal
tail=int(2.5*SR)
ext=out.copy()
out=np.tanh(out*1.6)/np.tanh(1.6)
out/=np.abs(out).max()*1.12
pcm=(out*32767).astype(np.int16)
w=wave.open('/tmp/lofi.wav','wb');w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR);w.writeframes(pcm.tobytes());w.close()
print(bars,N/SR)

import sys, numpy as np, cv2
from PIL import Image
import os
# the user's AI picture (not chibi); this script makes ../idle_v2.png from it
SRC=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','idle_v2_ai_source.png')
im=np.asarray(Image.open(SRC).convert('RGB'))
h,w,_=im.shape
# background: flood from the border over near-white
near=(im.astype(int).min(2)>232)&((im.astype(int).max(2)-im.astype(int).min(2))<14)
mask=np.zeros((h+2,w+2),np.uint8)
bg=np.zeros((h,w),np.uint8); bg[near]=255
ff=bg.copy()
for (x,y) in [(0,0),(w-1,0),(0,h-1),(w-1,h-1)]:
    if ff[y,x]==255: cv2.floodFill(ff,mask,(x,y),128)
back=(ff==128)
a=np.where(back,0,255).astype(np.uint8)
# soften the rim by 1px
a=cv2.GaussianBlur(a,(3,3),0)
rgba=np.dstack([im,a])
def run(name, CUT=386, NECKX=411, KH=1.25, BX=0.9, TY=0.85, LY=0.72, LEG=690):
    head=Image.fromarray(rgba[:CUT])
    torso=Image.fromarray(rgba[CUT:LEG]); legs=Image.fromarray(rgba[LEG:])
    hs=head.resize((round(w*KH),round(CUT*KH)),Image.LANCZOS)
    ts=torso.resize((round(w*BX),round((LEG-CUT)*TY)),Image.LANCZOS)
    ls=legs.resize((round(w*BX),round((h-LEG)*LY)),Image.LANCZOS)
    H=hs.height+ts.height+ls.height; W=max(hs.width,ts.width)+200
    out=Image.new('RGBA',(W,H),(0,0,0,0))
    cx=W//2
    bx=cx-round(NECKX*BX); out.alpha_composite(ts,(bx,hs.height-6)); out.alpha_composite(ls,(bx,hs.height-6+ts.height-1))
    out.alpha_composite(hs,(cx-round(NECKX*KH),0))
    bb=out.getbbox(); out=out.crop(bb)
    flat=Image.new('RGB',out.size,(255,255,255)); flat.paste(out,mask=out.split()[3])
    flat.save(name); return out


if __name__ == '__main__':
    # ../idle_v2.png as kept: the head (hair and face, rows above CUT) x1.4, the width kept, the shirt
    # x0.78 and the legs x0.62 tall, on a 797 x 969 white canvas at (150, 60)
    dst = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(SRC), 'idle_v2.png')
    fig = run(dst, KH=1.4, BX=1.0, TY=0.78, LY=0.62)
    canvas = Image.new('RGB', (797, 969), (255, 255, 255))
    canvas.paste(fig, (150, 60), mask=fig.split()[3])
    canvas.save(dst)

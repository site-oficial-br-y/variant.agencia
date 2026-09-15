from PIL import Image, ImageFilter
import numpy as np
src="/home/user/variant.agencia/mansao/ChatGPT Image 15 de set. de 2026, 19_49_54.png"
im=Image.open(src).convert("RGB")
W,H=im.size; print("size",W,H)
a=np.asarray(im).astype(np.int16)
r,g,b=a[...,0],a[...,1],a[...,2]
bright=a.max(2)
# ceu: azul dominante e claro, ou nuvem branca clara
sky=((b>r+8)&(b>g+2)&(bright>110)) | ((bright>205)&(b>=r-6)&(g>=r-10))
# so o que esta conectado ao topo
from scipy import ndimage
lab,n=ndimage.label(sky)
top=set(np.unique(lab[0:3,:])); top.discard(0)
sky=np.isin(lab,list(top))
# fecha buracos pequenos dentro do ceu (galhos finos ficam como ceu? nao, queremos manter galhos)
sky=ndimage.binary_opening(sky,np.ones((3,3)))
lab,n=ndimage.label(sky)
top=set(np.unique(lab[0:3,:])); top.discard(0)
sky=np.isin(lab,list(top))
fg=(~sky).astype(np.uint8)*255
print("ceu %.1f%%"%(sky.mean()*100))
m=Image.fromarray(fg).filter(ImageFilter.GaussianBlur(0.6))
out=im.convert("RGBA"); out.putalpha(m)
out.save("fg.png")
# preview: fundo magenta pra conferir o recorte
pv=Image.new("RGB",(W,H),(255,0,150)); pv.paste(out,(0,0),out); pv.save("preview_cut.jpg",quality=88)

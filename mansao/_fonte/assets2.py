from PIL import Image
import os
B="/home/user/variant.agencia/mansao/"
full=Image.open(B+"ChatGPT Image 15 de set. de 2026, 19_49_54.png").convert("RGB")
def save(im,name,q=84):
    p="out/"+name; im.save(p,"WEBP",quality=q,method=6)
    print(name,im.size,os.path.getsize(p)//1024,"KB")
for n,box in {
 "g-fachada.webp":(430,330,1320,790),     # volume inteiro
 "g-palmeiras.webp":(250,90,780,900),     # vertical, palmeiras + lateral
 "g-ripado.webp":(470,400,980,620),       # detalhe do ripado de madeira
 "g-espelho.webp":(380,700,1450,941),     # espelho d'agua faixa
}.items(): save(full.crop(box),n)

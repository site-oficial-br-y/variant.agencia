from PIL import Image
import os
B="/home/user/variant.agencia/mansao/"
os.makedirs("out",exist_ok=True)
def save(im,name,q=82,alpha=False):
    p="out/"+name
    im.save(p,"WEBP",quality=q,method=6)
    print(name,im.size,os.path.getsize(p)//1024,"KB")
full=Image.open(B+"ChatGPT Image 15 de set. de 2026, 19_49_54.png").convert("RGB")
fg=Image.open("fg.png")
save(full.resize((1672,941),Image.LANCZOS),"hero-fundo.webp",80)
save(fg,"hero-casa.webp",80)
W,H=full.size
# recortes editoriais da render principal
crops={
 "g-ripado.webp":(455,370,1210,560),      # fachada ripada
 "g-garagem.webp":(820,520,1350,760),     # pilotis e carros
 "g-espelho.webp":(300,740,1400,941),     # espelho d'agua
}
for n,box in crops.items():
    save(full.crop(box),n,84)
for n,f in [("g-pilotis.webp","casa arvore.webp"),("g-varanda.webp","casa arvvore.jpg"),("g-jardim.webp","casa arvore 4.jpg")]:
    im=Image.open(B+f).convert("RGB")
    save(im,n,84)
save(Image.open(B+"mansao 1.jpg").convert("RGB"),"hero-vertical.webp",86)

import base64,re,os
html=open("template.html").read()
html=html.replace("{{FONTS}}",open("fonts.css").read())
def rep(m):
    n=m.group(1); d=open("out/"+n,"rb").read()
    return "data:image/webp;base64,"+base64.b64encode(d).decode()
html=re.sub(r"\{\{IMG:([^}]+)\}\}",rep,html)
assert "{{" not in html
os.makedirs("/home/user/variant.agencia/mansao",exist_ok=True)
open("/home/user/variant.agencia/mansao/index.html","w").write(html)
print("index.html", os.path.getsize("/home/user/variant.agencia/mansao/index.html")//1024,"KB")

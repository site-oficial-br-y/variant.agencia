import re,subprocess,base64,os
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36"
url="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;700;800&family=Cormorant+Garamond:ital,wght@1,300;1,400&display=swap"
css=subprocess.run(["curl","-s","-A",UA,url],capture_output=True,text=True).stdout
blocks=re.findall(r"/\*\s*([\w-]+)\s*\*/\s*(@font-face\s*\{.*?\})",css,re.S)
out=[]
for subset,blk in blocks:
    if subset not in ("latin","latin-ext"): continue
    u=re.search(r"url\((https://[^)]+)\)",blk).group(1)
    data=subprocess.run(["curl","-s","-A",UA,u],capture_output=True).stdout
    b64=base64.b64encode(data).decode()
    blk=re.sub(r"url\(https://[^)]+\)","url(data:font/woff2;base64,%s)"%b64,blk)
    blk=blk.replace("font-display: swap;","font-display: block;")
    out.append(blk)
    print(subset, re.search(r"font-family: '([^']+)'",blk).group(1), re.search(r"font-weight: (\d+)",blk).group(1), re.search(r"font-style: (\w+)",blk).group(1), len(data)//1024,"KB")
open("fonts.css","w").write("\n".join(out))
print("total css", os.path.getsize("fonts.css")//1024,"KB")

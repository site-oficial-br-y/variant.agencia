"""Depois de exportar: faz o navegador baixar o index.pck novo a cada publicação
(sem isso ele reaproveita o pacote antigo do cache e o jogo parece não atualizar)
e coloca o manifest + ícones pra dar pra instalar o jogo na tela inicial."""
import os, re, shutil, sys, time
arq = sys.argv[1]
web = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'web')
for f in os.listdir(web):
    if f.startswith('.') or f.endswith('.import'):
        continue
    shutil.copy(os.path.join(web, f), os.path.join(os.path.dirname(os.path.abspath(arq)), f))
s = open(arq).read()
if 'manifest.webmanifest' not in s:
    s = s.replace('</head>', '<link rel="manifest" href="manifest.webmanifest">\n'
        '<meta name="theme-color" content="#12092a">\n'
        '<script src="qrcode.js"></script>\n<script>if ("serviceWorker" in navigator) navigator.serviceWorker.register("sw.js");</script>\n</head>', 1)
s = re.sub(r',"mainPack":"[^"]*"', '', s)
s = s.replace('"executable":"index"', '"executable":"index","mainPack":"index.pck?v=%d"' % int(time.time()), 1)
open(arq, 'w').write(s)
print(re.search(r'"mainPack":"[^"]*"', s).group(0))

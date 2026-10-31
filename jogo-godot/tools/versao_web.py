"""Depois de exportar: faz o navegador baixar o index.pck novo a cada publicação
(sem isso ele reaproveita o pacote antigo do cache e o jogo parece não atualizar)
e coloca o manifest + ícones pra dar pra instalar o jogo na tela inicial."""
import os, re, shutil, sys, time
arq = sys.argv[1]
web = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'web')
for f in os.listdir(web):
    if f.startswith('.') or f.endswith('.import'):
        continue
    de, para = os.path.join(web, f), os.path.join(os.path.dirname(os.path.abspath(arq)), f)
    if os.path.isdir(de):                              # carregando/: artes da tela de carregamento
        shutil.copytree(de, para, dirs_exist_ok=True, ignore=shutil.ignore_patterns('*.import'))
    else:
        shutil.copy(de, para)
s = open(arq).read()
if 'carregando.js' not in s:                          # tela de carregamento com arte dos personagens
    s = s.replace('</body>', '<script src="carregando/carregando.js"></script>\n</body>', 1)
if 'manifest.webmanifest' not in s:
    s = s.replace('</head>', '<link rel="manifest" href="manifest.webmanifest">\n'
        '<meta name="theme-color" content="#12092a">\n'
        '<script src="qrcode.js"></script>\n<script>if ("serviceWorker" in navigator) navigator.serviceWorker.register("sw.js");</script>\n</head>', 1)
s = re.sub(r',"mainPack":"[^"]*"', '', s)
v = int(time.time())
s = s.replace('"executable":"index"', '"executable":"index","mainPack":"index.pck?v=%d"' % v, 1)
s = re.sub(r'"index\.pck\?v=\d+":\d+,', '', s)
m = re.search(r'"fileSizes":\{"index\.pck":(\d+)', s)
if m:                                                  # a barra de progresso precisa do tamanho com o ?v= no nome
    s = s.replace(m.group(0), '"fileSizes":{"index.pck?v=%d":%s,"index.pck":%s' % (v, m.group(1), m.group(1)), 1)
open(arq, 'w').write(s)
print(re.search(r'"mainPack":"[^"]*"', s).group(0))

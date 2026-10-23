"""Depois de exportar: faz o navegador baixar o index.pck novo a cada publicação
(sem isso ele reaproveita o pacote antigo do cache e o jogo parece não atualizar)."""
import re, sys, time
arq = sys.argv[1]
s = open(arq).read()
s = re.sub(r',"mainPack":"[^"]*"', '', s)
s = s.replace('"executable":"index"', '"executable":"index","mainPack":"index.pck?v=%d"' % int(time.time()), 1)
open(arq, 'w').write(s)
print(re.search(r'"mainPack":"[^"]*"', s).group(0))

"""Junta o index.html, os escudos e o fundo num arquivo só.

O index.html busca as imagens em pastas ao lado, o que é bom pra editar e ruim
pra mandar pra alguém: aberto sozinho, ele fica sem escudo e sem estádio. Este
script embute tudo em base64 e escreve qual-torcida-e-maior.html, que abre em
qualquer lugar, inclusive no celular sem internet.

Rode de dentro da pasta torcida:  python3 gerar-arquivo-unico.py
"""
import base64, os, re

def embutir(caminho):
    tipo = 'image/webp' if caminho.endswith('.webp') else 'image/png'
    with open(caminho, 'rb') as f:
        return 'data:%s;base64,%s' % (tipo, base64.b64encode(f.read()).decode())

s = open('index.html').read()
s = s.replace("url('fundo.webp')", "url('%s')" % embutir('fundo.webp'))

def troca(m):
    caminho = m.group(1)
    return "escudo:'%s'" % embutir(caminho) if os.path.exists(caminho) else m.group(0)

s = re.sub(r"escudo:\s*'(escudos/[^']+)'", troca, s)

faltando = re.findall(r"escudos/[^']+", s)
if faltando:
    print('sem arquivo, seguem no emoji:', ', '.join(sorted(set(faltando))))

open('qual-torcida-e-maior.html', 'w').write(s)
print('qual-torcida-e-maior.html', os.path.getsize('qual-torcida-e-maior.html') // 1024, 'KB')

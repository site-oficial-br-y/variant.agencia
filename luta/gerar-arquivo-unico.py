"""Junta o index.html e as fotos dos lutadores num arquivo só.

O index.html busca as fotos na pasta ao lado, o que é bom pra editar e ruim
pra mandar pra alguém: aberto sozinho, ele fica sem foto. Este script embute
tudo em base64 e escreve quem-ganha-a-luta.html, que abre em qualquer lugar.

Rode de dentro da pasta luta:  python3 gerar-arquivo-unico.py
"""
import base64, json, os, re

def embutir(caminho):
    tipo = 'image/webp' if caminho.endswith('.webp') else 'image/png'
    with open(caminho, 'rb') as f:
        return 'data:%s;base64,%s' % (tipo, base64.b64encode(f.read()).decode())

s = open('index.html').read()

s = re.sub(r"foto:\s*'(fotos/[^']+)'", lambda m: "foto:'%s'" % embutir(m.group(1))
          if os.path.exists(m.group(1)) else m.group(0), s)

# A música fica fora do base64 de propósito: uma faixa de três minutos pesa
# mais que o jogo inteiro, e o arquivo ficaria pesado demais pra abrir. O
# caminho entra relativo, que é como o conector serve a pasta na live.
if os.path.isdir('musicas'):
    sons = sorted(a for a in os.listdir('musicas')
                  if a.lower().endswith(('.mp3', '.m4a', '.ogg', '.wav', '.aac')))
    if sons:
        lista = ','.join("'musicas/%s'" % a.replace("'", "\\'") for a in sons)
        s = s.replace('/*LISTA_DE_MUSICAS*/', lista)
        # O index.html não leva a lista embutida: ele lê este arquivo. Assim
        # subir uma música nova é só rodar o gerador, sem editar o HTML.
        json.dump(sons, open('musicas/lista.json', 'w'), ensure_ascii=False)
        print('músicas na lista:', len(sons))
    else:
        print('pasta musicas vazia: o painel deixa escolher do computador')

faltando = re.findall(r"fotos/[^']+", s)
if faltando:
    print('sem foto, entra o boneco:', ', '.join(sorted(set(faltando))))

open('quem-ganha-a-luta.html', 'w').write(s)
print('quem-ganha-a-luta.html', os.path.getsize('quem-ganha-a-luta.html') // 1024, 'KB')

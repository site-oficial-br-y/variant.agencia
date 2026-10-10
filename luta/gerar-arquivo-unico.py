"""Junta o index.html e as fotos dos lutadores num arquivo só.

O index.html busca as fotos na pasta ao lado, o que é bom pra editar e ruim
pra mandar pra alguém: aberto sozinho, ele fica sem foto. Este script embute
tudo em base64 e escreve quem-ganha-a-luta.html, que abre em qualquer lugar.

Rode de dentro da pasta luta:  python3 gerar-arquivo-unico.py
"""
import base64, json, os, re

def embutir(caminho):
    tipo = {'.webp': 'image/webp', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg'}.get(
        os.path.splitext(caminho)[1].lower(), 'image/png')
    with open(caminho, 'rb') as f:
        return 'data:%s;base64,%s' % (tipo, base64.b64encode(f.read()).decode())

s = open('index.html').read()

# Os sprites e o palco entram inteiros: o caminho aparece montado no script
# ('sprites/' + pasta + '-' + pose) e em url(), então vale trocar arquivo por
# arquivo, por nome, em vez de caçar o caminho no texto.
mapa = []
for arq in sorted(os.listdir('sprites')) if os.path.isdir('sprites') else []:
    nome = os.path.splitext(arq)[0]
    if nome == 'palco':
        s = s.replace("url('sprites/palco.jpg')", "url('%s')" % embutir('sprites/' + arq))
        continue
    mapa.append("'%s':'%s'" % (nome, embutir('sprites/' + arq)))
s = s.replace('/*SPRITES_EMBUTIDOS*/', ','.join(mapa))
print('sprites embutidos:', len(mapa))

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

faltando = re.findall(r"sprites/[A-Za-z0-9_-]+\.[a-z]+", s)
if faltando:
    print('sprite que não achei:', ', '.join(sorted(set(faltando))))

open('quem-ganha-a-luta.html', 'w').write(s)
print('quem-ganha-a-luta.html', os.path.getsize('quem-ganha-a-luta.html') // 1024, 'KB')

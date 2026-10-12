"""Junta o index.html e as fotos dos lutadores num arquivo só.

O index.html busca as fotos na pasta ao lado, o que é bom pra editar e ruim
pra mandar pra alguém: aberto sozinho, ele fica sem foto. Este script embute
tudo em base64 e escreve quem-ganha-a-luta.html, que abre em qualquer lugar.

Rode de dentro da pasta luta:  python3 gerar-arquivo-unico.py
"""
import base64, json, os, re

def embutir(caminho):
    tipo = {'.webp': 'image/webp', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
            '.mp4': 'video/mp4', '.mp3': 'audio/mpeg'}.get(
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
    # Os .jpg de cenário (palco, fundo da live) entram por url() no CSS; os
    # .png dos lutadores entram no mapa SPRITES que o script lê.
    if arq.endswith('.jpg'):
        s = s.replace("url('sprites/%s')" % arq, "url('%s')" % embutir('sprites/' + arq))
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
        # O index.html servido (a live pelo conector) não leva música embutida:
        # lê este lista.json e toca os arquivos de alta qualidade da pasta.
        json.dump(sons, open('musicas/lista.json', 'w'), ensure_ascii=False)
        # O arquivo único, aberto sozinho, não tem a pasta do lado, então a
        # música entra embutida — mas na versão leve de musicas/mini, pra o
        # arquivo não virar um monstro. Sem a pasta mini, cai no caminho (que
        # só funciona servido).
        mini_dir = os.path.join('musicas', 'mini')
        if os.path.isdir(mini_dir):
            minis = sorted(a for a in os.listdir(mini_dir) if a.lower().endswith('.mp3'))
            lista = ','.join("'%s'" % embutir(os.path.join(mini_dir, a)) for a in minis)
            print('músicas embutidas (leves):', len(minis))
        else:
            lista = ','.join("'musicas/%s'" % a.replace("'", "\\'") for a in sons)
            print('músicas na lista (caminho):', len(sons))
        s = s.replace('/*LISTA_DE_MUSICAS*/', lista)
    else:
        print('pasta musicas vazia: o painel deixa escolher do computador')

# As cutscenes entram embutidas no arquivo único, na versão leve de
# cutscene-mini (o original é grande demais pra base64). A chave é o nome do
# arquivo original, que é o que o CUTSCENES aponta. Servido pelo conector, a
# live usa o .mp4 original em alta, da raiz da pasta.
origem = 'cutscene-mini' if os.path.isdir('cutscene-mini') else '.'
videos = ["'%s':'%s'" % (arq, embutir(os.path.join(origem, arq)))
          for arq in sorted(os.listdir('.')) if arq.startswith('cutscene-') and arq.endswith('.mp4')]
s = s.replace('/*VIDEOS_EMBUTIDOS*/', ','.join(videos))
print('cutscenes embutidas (%s):' % origem, len(videos))

# Efeitos de fliperama: pequenos, entram embutidos pelo caminho 'sons/<arq>',
# que é a chave que o SONS_SRC usa.
if os.path.isdir('sons'):
    sfx = ["'sons/%s':'%s'" % (arq, embutir('sons/' + arq))
           for arq in sorted(os.listdir('sons')) if arq.endswith('.mp3')]
    s = s.replace('/*SONS_EMBUTIDOS*/', ','.join(sfx))
    print('efeitos embutidos:', len(sfx))

faltando = re.findall(r"sprites/[A-Za-z0-9_-]+\.[a-z]+", s)
if faltando:
    print('sprite que não achei:', ', '.join(sorted(set(faltando))))

open('quem-ganha-a-luta.html', 'w').write(s)
print('quem-ganha-a-luta.html', os.path.getsize('quem-ganha-a-luta.html') // 1024, 'KB')

# Versão de teste: a mesma, com o painel de botões ligado. window.TESTE entra
# antes do script do jogo, então ele já nasce com os botões aparecendo.
teste = s.replace('<body>', '<body>\n<script>window.TESTE = true</script>', 1)
open('teste-luta.html', 'w').write(teste)
print('teste-luta.html', os.path.getsize('teste-luta.html') // 1024, 'KB')

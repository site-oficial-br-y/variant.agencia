"""Antes de exportar: põe as músicas grandes e os vídeos na pasta midia/ do site (fora do index.pck)
e gera res://midia.json (caminho res:// -> nome do arquivo no site). O nome leva um pedaço do md5
do original, então arquivo mudado = nome novo = o aparelho baixa de novo.
Música sai em Vorbis 96 kbps (no celular não dá pra ouvir diferença); vídeo vai do jeito que está.

Uso: python3 tools/midia.py <pasta do site, ex.: ../rodas/godot>
"""
import hashlib, json, os, shutil, subprocess, sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.join(AQUI, '..')
ARQS = [
    'assets/audio/musica/menu.mp3',
    'assets/audio/musica/adriano.ogg', 'assets/audio/musica/cepe.ogg', 'assets/audio/musica/ctamandura.ogg',
    'assets/audio/musica/escola.ogg', 'assets/audio/musica/geresch.ogg', 'assets/audio/musica/julgamento.ogg',
    'assets/audio/musica/pece.ogg', 'assets/audio/musica/vendedor.ogg', 'assets/audio/musica/james.ogg',
    'assets/geresch/intro.ogv', 'assets/julgamento/entrada.ogv', 'assets/julgamento/martelo.ogv',
]

def main(site):
    dest = os.path.join(site, 'midia')
    os.makedirs(dest, exist_ok=True)
    lista, feitos = {}, set()
    for rel in ARQS:
        src = os.path.join(RAIZ, rel)
        h = hashlib.md5(open(src, 'rb').read()).hexdigest()[:8]
        stem, ext = os.path.splitext(os.path.basename(rel))
        nome = f'{stem}-{h}' + ('.ogv' if ext == '.ogv' else '.ogg')
        out = os.path.join(dest, nome)
        if not os.path.exists(out):
            if ext == '.ogv':
                shutil.copy(src, out)
            else:
                subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', src, '-vn', '-c:a', 'libvorbis', '-b:a', '96k', out], check=True)
        lista['res://' + rel] = nome
        feitos.add(nome)
        print(f'  {nome:28s} {os.path.getsize(src) // 1024:5d} KB -> {os.path.getsize(out) // 1024:5d} KB')
    for f in os.listdir(dest):
        if f not in feitos:
            os.remove(os.path.join(dest, f))
    json.dump(lista, open(os.path.join(RAIZ, 'midia.json'), 'w'), indent=1)
    print('total', sum(os.path.getsize(os.path.join(dest, f)) for f in feitos) // 1024, 'KB')

if __name__ == '__main__':
    main(sys.argv[1])

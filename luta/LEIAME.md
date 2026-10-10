# Quem ganha a luta

Jogo de live no estilo arcade: dois lados, uma barra de vida cada um, e quem
zerar a barra do outro vence o round.

- **comentário** com o nome de um lado escolhe o lado e dá 1 de dano, no
  máximo um a cada 8 segundos por pessoa
- **curtida** dá 1 de dano a cada 25 curtidas da mesma pessoa
- **presente** dá o valor em moedas que o próprio TikTok informa

Curtida e presente só contam pra quem já escolheu o lado no comentário.

## Como rodar

Dois cliques no `COMECAR.bat`. Ele atualiza os arquivos, liga o conector e
abre a janela em 1080x1920. Na primeira vez ele pergunta o seu @.

Na mão, se preferir:

```
node conector.js seuusuario
```

e abrir http://localhost:8080 no Chrome.

## Quadros de animação

Os sprites ficam em `sprites/`, um arquivo por quadro, no formato
`<quem>-<quadro>.png`. Os clipes são montados no `index.html`, em `CLIPES`:

| clipe | quando toca | quadros |
|---|---|---|
| parado | o tempo todo | andar1 a andar6, em laço |
| soco | golpe abaixo de 10 | golpe1 |
| chute | golpe de 10 a 49 | golpe2 |
| forte | golpe de 50 pra cima | golpe3 e golpe5 |
| dano | quem apanha | defesa |
| caido | perdeu o round | caido |
| vitoria | ganhou o round | vitoria |

Pra gerar quadro novo, peça folha de animação ao gerador de imagem assim:

> sprite sheet, 6 frames, 3 columns x 2 rows, idle breathing cycle, same
> character, same scale, feet on the same baseline, side view facing right,
> black background, pixel art

O que não pode faltar: **mesma escala, mesmo chão, fundo preto** e, de
preferência, a linha do chão desenhada, que é o que o extrator usa de régua.
Uma folha por movimento, um quadro por célula. Folha com efeito vazando de
uma célula pra outra não dá pra cortar.

Depois de trocar sprites, rode:

```
python3 gerar-arquivo-unico.py
```

## Trocar a dupla

No `index.html`, procure `const LADOS`. Nome, cor, caminho da foto e as
palavras que o comentário precisa conter estão todos ali.

## Atenção

Mostrar pessoa real apanhando é o tipo de coisa que o TikTok remove, e em ano
de eleição a régua é mais apertada ainda. Por isso o jogo é cartunesco, sem
sangue e sem nada explícito. O risco da conta é de quem transmite.

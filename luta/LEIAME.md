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

## Fotos

Coloque `lula.png` e `flavio.png` em `fotos/`, de preferência recortados, com
fundo transparente e de corpo inteiro. Sem os arquivos entra um boneco da cor
do lado e o jogo funciona igual.

Depois de trocar as fotos, rode:

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

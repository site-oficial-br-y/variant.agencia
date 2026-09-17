# Protótipo do jogo de futebol (nome a definir)

Trabalho em andamento. Abrigo temporário: quando o nome do jogo estiver
decidido, isto vai para um repositório próprio em `site-oficial-br-y`
(o nome define a URL do GitHub Pages, então criar antes seria errado).

## Arquivos

- `index.html` — o jogo, arquivo único, pronto para abrir no celular
- `elencos.json` — a base de dados (fonte da verdade): 30 times, 11 jogadores cada
- `tmpl.html` — o molde; `index.html` é gerado injetando o JSON nele

Para reconstruir o `index.html` depois de editar o JSON ou o molde:

```
python3 -c "
import json
d=json.load(open('elencos.json',encoding='utf-8')); d.pop('_leia',None)
t=open('tmpl.html',encoding='utf-8').read()
open('index.html','w',encoding='utf-8').write(t.replace('__DADOS__',json.dumps(d,ensure_ascii=False,separators=(',',':'))))
"
```

## Mecânica

Dado sorteia um time campeão → escala um jogador daquele elenco → repete 7 vezes
(1 goleiro, 2 defensores, 2 meias, 2 atacantes) → revela o overall → campanha de
7 jogos com narração minuto a minuto.

Travas: jogador escalado desaparece de todos os elencos; time sorteado não repete
na mesma partida; posição já cheia aparece apagada; o dado rola de novo sozinho
se nada for clicável, e volta a permitir times repetidos se for preciso.
Dois passes por partida. Não há preço nem orçamento.

## Números calibrados

- Não há economia. A única restrição é a oferta do dado e a posição já preenchida.
- Força do adversário: a média dos 11 sempre cai entre 80 e 86, o que achatava a
  dificuldade. É esticada 2,2× em torno de 82,5, abrindo a faixa real para 76–91.
- Gols: Poisson com `1.35 × e^(diferença/8)`, teto de 9.
- Grupos: 3 jogos, 3 pontos por vitória, 4 pontos para classificar.

Medido em 800 partidas reais na página e 20.000 campanhas simuladas:

| | overall | campeão | goleada de 7 a 0 | cai nos grupos |
|---|---|---|---|---|
| Escala bem | 88,4 | 30% | 18% | 0% |
| Escala no automático | 82,8 | 1% | 0,4% | 16% |

## Pendente

- Nome e identidade visual (o visual atual é provisório)
- Qual é o objetivo declarado da campanha
- Card de resultado para compartilhar
- Modo diário: um sorteio igual para todo mundo, que vira à meia-noite
- Ver o seu time durante a campanha
- Revisar os nomes dos elencos antigos: Grêmio 1983, Grêmio 1995, Cruzeiro 2003,
  Santos 2002 e Palmeiras 1994 são os que têm mais chute

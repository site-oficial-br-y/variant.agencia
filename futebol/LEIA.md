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

## O jogo

O dado sorteia um time campeão da história do futebol brasileiro. Você escala
um jogador daquele elenco. Sete escolhas — 1 goleiro, 2 defensores, 2 meias,
2 atacantes — e o time montado disputa uma campanha de 7 jogos contra os
próprios elencos da base.

**A conquista é ganhar a final.** Tudo o mais (overall do time, gols marcados,
maior goleada) é estatística do resultado, não objetivo.

A campanha roda em **Automático** ou **Jogo a jogo** (espera o clique entre
as partidas), nas velocidades normal, rápido e ultra, com o relógio da
partida correndo minuto a minuto.

Travas: jogador escalado desaparece de todos os elencos; time sorteado não repete
na mesma partida; posição já cheia aparece apagada; o dado rola de novo sozinho
se nada for clicável, e volta a permitir times repetidos antes de desistir.
Dois passes por partida. Não há preço nem orçamento.

A decisão do jogador é de timing: preencher a vaga com quem está na mão, ou
segurar a posição apostando que um elenco melhor vai sair.

## Base de dados

46 times, 506 entradas, 439 jogadores distintos. **Todos os elencos foram
conferidos em fonte**, registrada no campo `fonte`. Nenhum parcial.

Cobre de 1962 a 2024, e inclui os campeões fora do eixo: Guarani 1978 (o
único campeão do interior), Coritiba 1985, Sport 1987, Bahia 1988 e
Atlético-PR 2001.

Critério do XI: a escalação do jogo decisivo daquela conquista, por ser o
dado verificável. Isso deixa de fora craques que estavam no elenco mas não
naquele jogo (Pelé na final de 63, por lesão; Roberto Carlos no Palmeiras 94;
Deyverson, que entrou na prorrogação da final de 2021). Três detalhes que ela resolve:

- **Homônimos são pessoas diferentes.** Há quatro "Danilo", quatro "Alex" e três
  "Júnior". Cada um tem ID próprio, senão o jogo apagaria o errado.
- **O mesmo jogador aparece em vários elencos** (Everton Ribeiro em cinco).
  Escalado uma vez, sai de todos.
- **Sem escudo nem foto.** Bandeira de duas cores por time.

## Números calibrados

- Não há economia. A única restrição é a oferta do dado e a posição já preenchida.
- Força do adversário: a média dos 11 sempre cai entre 80 e 86, o que achatava a
  dificuldade. É esticada 2,2× em torno de 82,5, abrindo a faixa real para 76–91.
- Gols: Poisson com `1.35 × e^(diferença/8)`, teto de 9.
- Grupos: 3 jogos, 3 pontos por vitória, 4 pontos para classificar.

Medido em 800 partidas reais na página e 20.000 campanhas simuladas:

| | overall | é campeão | cai nos grupos |
|---|---|---|---|
| Escala bem | 88,4 | 30% | 0% |
| Escala no automático | 82,8 | 1% | 16% |

## Pendente

- Nome e identidade visual (o visual atual é provisório)
- Card de resultado para compartilhar
- Modo diário: um sorteio igual para todo mundo, que vira à meia-noite
- Ver o seu time durante a campanha
- Três elencos planejados ficaram de fora: Cruzeiro 1993 (o time do Ronaldo
  não tem título grande naquele ano — quem ganhou a Supercopa foi o São Paulo),
  Santos 1968 e Flamengo 1992
- Repor o Flamengo 2023, removido por não ter conquistado nada naquele ano
- Cadastro e ranking via Supabase (faltam a URL e a anon key do projeto)
- Cadastro e ranking via Supabase (faltam a URL e a anon key do projeto)

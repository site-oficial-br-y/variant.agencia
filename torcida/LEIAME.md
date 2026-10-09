# Qual torcida é maior

Jogo de live pro TikTok. Catorze times, cada presente enche a barra de um, e o
primeiro a encher vence a rodada.

## Como rodar

**1. O jogo**

Abre o `index.html` no navegador. Ele funciona sozinho, sem live, pra você testar:

- tecla **D** liga e desliga presentes aleatórios
- **clique numa barra** dá 10 pontos pra ela

**2. O conector (só quando for transmitir)**

```
npm install
node conector.js SEU_USUARIO
```

Precisa estar ao vivo no momento. O jogo se conecta sozinho e reconecta se cair,
então não importa qual você abre primeiro.

**3. O OBS**

Adiciona uma fonte de **Navegador** apontando pro arquivo `index.html`, com
largura 1080 e altura 1920. A tela escala sozinha pra qualquer tamanho.

## Como o público joga

**Cada time tem o presente dele.** Está escrito na barra: Flamengo é a rosa,
Palmeiras é o sorvete, Santos é o joinha, e assim por diante.

Mandou o presente, pontuou pro time. Não precisa comentar nada.

**O ponto é o valor em moedas do presente.** Presente de 1 moeda dá 1 ponto,
presente de 99 dá 99. Assim nenhum time fica em desvantagem por ter caído com
um presente barato, e quem empurra mais é quem gastou mais.

Quem comenta o nome de um time também ganha +1 e fica marcado como torcedor
dele. Serve pra quem não quer gastar, e pros presentes que não são de time
nenhum.

Primeiro a chegar na meta vence a rodada e ganha uma coroa.

## Mexer no jogo

Tudo que você vai querer trocar está no começo do `<script>` do `index.html`:

- **`TIMES`** — lista de times, com o presente de cada um e as duas cores da
  barra. Acrescentar time é somar uma linha.

  **O campo `presente` precisa bater com o nome exato que o TikTok envia.** Os
  que estão lá são o meu palpite. Numa live de teste, o conector imprime no
  terminal o nome real de cada presente que chegar, assim:

  ```
  presente: "rose" | moedas: 1 | x1 | fulano
  ```

  É só copiar o texto entre aspas pro campo `presente` do time. Faz isso uma vez
  e nunca mais precisa mexer.
- **`META`** — quantas moedas enchem a barra. Menor, rodada mais rápida. Está
  em 300.

Escudo de time é marca registrada, por isso a barra usa cor e nome em vez do
escudo. Evita reclamação em live monetizada.

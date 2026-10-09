# Qual torcida é maior

Jogo de live pro TikTok. Corrida vertical com catorze times subindo rumo à
linha de chegada no topo, num estádio de fundo. Cada presente empurra o time
dele pra cima, e o primeiro a cruzar a linha vence a corrida.

## Como rodar

**1. O jogo**

Abre o `index.html` no navegador. Ele funciona sozinho, sem live, pra você testar:

- tecla **D** liga e desliga presentes aleatórios
- **clique numa raia** avança aquele time em 10

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

**Cada time tem o presente dele.** Está na bolinha do corredor: Flamengo é a rosa,
Palmeiras é o sorvete, Santos é o joinha, e assim por diante.

Mandou o presente, o time sobe. Não precisa comentar nada.

**O avanço é o valor em moedas do presente.** Presente de 1 moeda dá 1 ponto,
presente de 99 sobe 99. Assim nenhum time fica em desvantagem por ter caído com
um presente barato, e quem empurra mais é quem gastou mais.

Quem comenta o nome de um time também ganha +1 e fica marcado como torcedor
dele. Serve pra quem não quer gastar, e pros presentes que não são de time
nenhum.

Primeiro a cruzar a linha de chegada vence a corrida e ganha uma coroa.

## Mexer no jogo

Tudo que você vai querer trocar está no começo do `<script>` do `index.html`:

- **`TIMES`** — lista de times, com o presente, a sigla e a cor de cada um. Acrescentar time é somar uma linha.

  **O campo `presente` precisa bater com o nome exato que o TikTok envia.** Os
  que estão lá são o meu palpite. Numa live de teste, o conector imprime no
  terminal o nome real de cada presente que chegar, assim:

  ```
  presente: "rose" | moedas: 1 | x1 | fulano
  ```

  É só copiar o texto entre aspas pro campo `presente` do time. Faz isso uma vez
  e nunca mais precisa mexer.
- **`META`** — quantas moedas levam até a linha de chegada. Menor, corrida mais
  rápida. Está em 300.
- **`fundo.webp`** — a foto do estádio. Trocar o arquivo troca o cenário.

## Escudos

Os escudos ficam em `escudos/`, em PNG transparente, com o nome que está no
LEIAME de lá. Faltando algum, o emoji do time aparece no lugar e nada quebra.

Vale saber: escudo de time é marca registrada, e em live monetizada pode dar
reclamação. Se preferir não arriscar, é só não colocar os arquivos: o jogo
funciona igual com os emojis.

## Arquivo único

`qual-torcida-e-maior.html` é o jogo inteiro num arquivo só, com os escudos e o
estádio embutidos em base64. Serve pra abrir no celular ou mandar pra alguém:
funciona sem internet e sem a pasta ao lado.

Para transmitir, use o `index.html` normal, que é o que fica fácil de editar.

Depois de mexer no `index.html` ou trocar algum escudo, gere de novo:

```
python3 gerar-arquivo-unico.py
```

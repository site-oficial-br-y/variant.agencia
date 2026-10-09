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

Ele faz duas coisas: lê a live e serve o jogo em **http://localhost:8080**.

Precisa estar ao vivo no momento. O jogo se conecta sozinho e reconecta se cair,
então não importa qual você abre primeiro.

**3. A transmissão**

No **TikTok LIVE Studio**: Adicionar origem, **Vincular**, liga **Resolução
personalizada** em 1080x1920 e cola `http://localhost:8080`.

No **OBS**: fonte de **Navegador**, mesma URL, mesma resolução.

Não use captura de janela. O monitor não tem 1920 de altura, então a janela
sai menor e você acaba dando zoom pra preencher, o que borra tudo. Pela URL o
jogo é desenhado direto no tamanho certo.

## Como o público joga

Uma regra só, escrita na tela:

**1. Comenta o nome do time.** Aceita apelido: mengão, timão, verdão, peixe,
galo. Isso marca a pessoa como torcedora daquele time e já dá +1.

**2. Manda qualquer presente.** Ele empurra o time dela, e o avanço é o valor em
moedas: presente de 10 sobe 10, de 100 sobe 100.

Antes cada time tinha um presente específico. Não funcionava: vários estão
enterrados no painel do TikTok, e ninguém caça presente no meio de centenas.
Agora qualquer presente serve, e a pessoa manda o que ela já ia mandar.

**A faixa do maior torcedor**, no topo, mostra quem mais empurrou na rodada.
É ela que faz gastar: dá pra tomar o lugar de alguém e aparecer na tela. Zera
junto com a corrida.

Primeiro a cruzar a linha de chegada vence a corrida e ganha uma coroa.

## Mexer no jogo

Tudo que você vai querer trocar está no começo do `<script>` do `index.html`:

- **`TIMES`** — lista de times, com o presente, a sigla e a cor de cada um. Acrescentar time é somar uma linha.

  **O campo `presentes` é uma lista de nomes.** O TikTok manda o nome do
  presente no idioma da conta, às vezes "rose", às vezes "rosa", por isso cada
  time aceita vários. Os que estão lá são o meu palpite.

  Durante a live o conector salva um arquivo **`presentes-vistos.txt`** com o
  nome exato e o valor de cada presente que apareceu, do mais barato pro mais
  caro. Se algum presente não estiver pontuando, abre esse arquivo e acrescenta
  o nome que está lá na lista do time. Faz isso uma vez e nunca mais precisa.
- **`META`** — quantas moedas levam até a linha de chegada. Menor, corrida mais
  rápida. Está em 300.
- **`fundo.webp`** — a foto do estádio. Trocar o arquivo troca o cenário.
- **`presentes/`** — a figura de cada presente, recortada do painel do TikTok.
  Faltando alguma, o emoji do time aparece no lugar.

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

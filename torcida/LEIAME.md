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

1. Comenta o nome do time (aceita apelido: mengão, timão, verdão, peixe, galo).
   Isso marca a pessoa como torcedora daquele time e já dá +1.
2. A partir daí, qualquer presente que ela mandar vai pro time dela.
3. Primeiro time a chegar em 100 vence a rodada e ganha uma coroa.

## Mexer no jogo

Tudo que você vai querer trocar está no começo do `<script>` do `index.html`:

- **`TIMES`** — lista de times, com as duas cores da barra. Acrescentar time é
  somar uma linha.
- **`PRESENTES`** — quanto vale cada presente. O campo `nomes` é o identificador
  que o TikTok manda; se um presente não estiver pontuando, é porque o nome ali
  está diferente do que o TikTok envia. O conector imprime o nome real no
  terminal a cada presente, então é só copiar de lá.
- **`META`** — quantos pontos enchem a barra. Menos pontos, rodada mais rápida.

Escudo de time é marca registrada, por isso a barra usa cor e nome em vez do
escudo. Evita reclamação em live monetizada.

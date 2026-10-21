# Sistema de personagens

Prioridade máxima: **usar os personagens do usuário**. Esta referência cobre como
achá-los, prepará-los (inclusive a partir de UMA imagem estática), descrevê-los em
dados, registrá-los e oferecê-los numa tela de seleção.

Volte para o [SKILL.md](../SKILL.md) · física dos segmentos em
[physics-system.md](physics-system.md#5-ragdoll) · pipeline de imagem em
[assets/README.md](../assets/README.md).

---

## 1. Procurar antes de criar

```bash
# imagens candidatas (fora de node_modules/.godot)
find . -path ./node_modules -prune -o -path '*/.godot' -prune -o \
  \( -iname '*.png' -o -iname '*.webp' -o -iname '*.jpg' \) -print | head -100
# dados de personagens já existentes
find . -name 'parts.json' -o -name 'character.tres' -o -name '*.tscn' | grep -iv node_modules
```

- Pergunte/confirme quais imagens são personagens se não for óbvio pelo nome.
- **Nunca** sobrescreva o arquivo original: trabalhe sobre cópias em
  `tools/fonte/` e gere as peças em `assets/<personagem>/`.
- Se não houver personagens, prepare a estrutura (definições vazias com
  `TODO` de asset) — não preencha com boneco genérico.

## 2. Modelo de dados

Duas camadas:

1. **`parts.json`** (gerado pela ferramenta de recorte): geometria em coordenadas
   da arte original — peças, ordem de desenho, corpo físico de cada peça, rodas,
   chassi, formas de colisão, juntas.
2. **`CharacterDefinition` (`.tres`)**: o que é editável no inspetor — nome,
   retrato, parâmetros de jogo, sons, veículos compatíveis.

### `parts.json` (formato usado no projeto real `jogo-godot`)

```json
{
  "nome": "cadeira",
  "ordem": ["tras", "rodinha", "cabeca", "tronco", "coxa", "canela", "braco", "frente", "roda"],
  "pecas": {"cabeca": {"x": 182, "y": 0, "w": 245, "h": 300}},
  "corpo_de": {"tras": "chassi", "frente": "chassi", "roda": "roda0", "rodinha": "roda1",
               "cabeca": "cabeca", "tronco": "tronco", "braco": "braco", "coxa": "coxa", "canela": "canela"},
  "piloto": ["tronco", "cabeca", "braco", "coxa", "canela"],
  "rodas": [{"corpo": "roda0", "c": [261.5, 882.0], "r": 262, "massa": 2.5, "motriz": true}],
  "chassi": {"massa": 7.0, "auto_equilibrio": false, "vmax": 760.0, "forca": 120000.0,
             "poly": [[140, 445], [242, 445], [592, 565], [700, 780], [865, 1030]]},
  "corpos": {"cabeca": {"massa": 0.8, "forma": ["circ", [297, 118], 108]},
             "coxa": {"massa": 1.0, "forma": ["caps", [330, 690], [745, 690], 74]}},
  "juntas": [{"a": "tronco", "b": "cabeca", "p": [282, 268], "lim": 40},
             {"a": "coxa", "b": "canela", "p": [725, 705], "lim": 75}]
}
```

Regras do formato:
- Cada corpo do piloto tem uma peça com **o mesmo nome**; a origem do corpo é o
  centro dessa peça. Peças extras do mesmo corpo (ex.: `tronco_f`, a manga desenhada
  por cima do braço) usam `corpo_de` para acompanhar.
- `ordem` é o `z_index` de cada sprite — preservar a ordem da arte é o que faz a
  remontagem ficar idêntica à imagem.
- Segway/monociclo: em vez de `poly`, `chassi.mastro = {x, y0, y1, w}` e
  `auto_equilibrio: true`.

### `CharacterDefinition`

```gdscript
extends Resource
class_name CharacterDefinition
## Ficha editável de um personagem. Geometria física vem de `partes_json`.

@export var id: String = ""
@export var nome_exibido: String = ""
@export var retrato: Texture2D                 # rosto do quadro de seleção
@export var retrato_cinza: Texture2D           # versão "não selecionado"
@export var preview: Texture2D                 # arte inteira para a vitrine
@export_file("*.json") var partes_json: String = ""
@export_group("Jogo")
@export_range(0.3, 3.0) var fator_resistencia: float = 1.0   # multiplica limiares de dano
@export_range(0.3, 2.0) var fator_forca: float = 1.0         # multiplica a tração do veículo
@export var habilidades: Array[String] = []                  # ex.: ["turbo"], tratadas no controller
@export var veiculos_compativeis: Array[String] = []         # vazio = veículo faz parte da arte
@export_group("Áudio e efeitos")
@export var som_batida: AudioStream
@export var som_morte: AudioStream
@export var cor_sangue: Color = Color(0.72, 0.03, 0.07)
@export var sangue_ativo: bool = true

func carregar_partes() -> Dictionary:
	var f := FileAccess.open(partes_json, FileAccess.READ)
	if f == null:
		push_error("partes não encontradas: %s" % partes_json)
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}
```

## 3. Registro (autoload `CharacterRegistry`)

```gdscript
extends Node
## Autoload: descobre personagens em res://characters/<id>/character.tres.

const PASTA := "res://characters"

var por_id: Dictionary = {}
var ordem: Array[String] = []

func _ready() -> void:
	recarregar()

func recarregar() -> void:
	por_id.clear()
	ordem.clear()
	for sub in DirAccess.get_directories_at(PASTA):
		var caminho := "%s/%s/character.tres" % [PASTA, sub]
		# no build exportado o .tres vira binário com .remap: ResourceLoader resolve sozinho
		if not ResourceLoader.exists(caminho):
			continue
		var def := load(caminho) as CharacterDefinition
		if def and def.id != "":
			por_id[def.id] = def
			ordem.append(def.id)
	ordem.sort()

func pegar(id: String) -> CharacterDefinition:
	return por_id.get(id) as CharacterDefinition
```

> Não varra a pasta procurando arquivos `.tres` com `get_files_at` no build
> exportado: lá eles aparecem como `.tres.remap`. Use `ResourceLoader.exists()`
> com o caminho original, como acima.

## 4. Tela de seleção

Padrão usado (estilo do gênero, arte própria): fundo escuro de tempestade, logo do
jogo no canto, fila de quadros com os **rostos** (selecionado colorido, demais em
cinza, quadros vazios para futuros personagens), personagem escolhido grande
**em pé sobre a plataforma** e botão ✓.

Detalhes que importam:
- Alinhe o preview **pela base** (`y = topo_da_pedra - altura`), não centralizado
  — personagens largos (cadeira, scooter) flutuam se centralizar.
- Posicione tudo a partir de `get_viewport().get_visible_rect().size` (tela larga
  de celular com `aspect=expand`).
- Rostos: recorte da peça `cabeca` redimensionada; versão cinza por luminância.
- Escolha grava `Game.personagem = id` e troca para a cena da fase.

## 5. Imagem estática → personagem com ragdoll

Quando o personagem é **uma ilustração única** (o caso mais comum com usuários), a
estratégia é recortar a própria arte em peças com física, e não substituir por
outro desenho. O projeto real tem a ferramenta em `jogo-godot/tools/segmenta.py`.

Passos (detalhes técnicos em [assets/README.md](../assets/README.md#3-pipeline-de-recorte)):

1. **Fundo**: flood-fill a partir das bordas (preserva brancos internos como tênis
   e fralda) **e** remoção das ilhas de fundo presas — áreas claras **lisas**
   (desvio de cor < 4) e grandes (> 400 px) fechadas entre membros. Fralda/carenagem
   têm sombreado e sobrevivem ao critério.
2. **Espelhar** se o personagem anda para a esquerda.
3. **Partição**: cada pixel vai para UMA peça por regras em ordem (roda → cabeça →
   braço por cor de pele + polígono → veículo da frente → veículo de trás → tronco →
   perna). Sobras vão para a peça vizinha mais próxima; migalhas (< 300–500 px)
   migram. Partição garante remontagem exata.
4. **Casca (o que estava escondido)**: cada peça é completada **somente onde algo
   desenhado na frente dela a tampava**, com textura estendida (pixel próprio mais
   próximo + desfoque). Nunca preencha onde há algo de trás visível nem área
   transparente — senão o personagem montado muda.
5. **Rodas tampadas**: reconstruídas pelo perfil radial médio; onde a roda aparece,
   mantém o pixel original. Raios de roda: ajuste de reta (SVD) em cada raio.
6. **Pivôs** de cada junta em coordenadas da arte; formas de colisão como cápsulas
   entre pivôs.
7. **Validar** (obrigatório, com números):
   - remontagem vs original: no projeto real ficou entre 0,3% e 0,5% de pixels com
     diferença > 16 (bordas de junta e rodas reconstruídas);
   - pose de teste: cada membro girado no pivô (±25–55°) para ver se abre buraco.
8. Só então `parts.json` + `CharacterDefinition`.

Limites honestos: o recorte de membros sobrepostos da mesma cor (moletom preto
sobre calça preta) é feito por polígono definido olhando a imagem com grade —
documente isso; não é segmentação semântica automática.

## 6. Comportamento por personagem

- `fator_resistencia` multiplica os limiares de [dano](physics-system.md#6-dano-por-impacto).
- `fator_forca` multiplica `forca` do veículo.
- `habilidades`: strings tratadas pelo controlador (ex.: `"turbo"` → impulso no
  chassi com recarga). Não crie habilidade sem pedido.
- Sons/efeitos: `som_batida` no `PhysicsDamageSystem.pancada`, `cor_sangue` no
  sistema de sangue.

## 7. Adicionar um personagem (checklist)

1. Copiar a imagem para `tools/fonte/<id>_full.png` (original intocado).
2. Rodar o recorte com config nova; conferir remontagem e pose de teste.
3. `characters/<id>/character.tres` apontando para `assets/<id>/parts.json`.
4. Rodar o teste de carga e o playtest da fase 1 com ele
   ([testing.md](testing.md#criterios-por-fase)).


## Lições do Bicho Ehn (personagens novos: monociclo e cadeira gamer)

- **Fundo preto com roupa preta**: tire o fundo por *flood fill* a partir das bordas
  (pixels com máximo de canal < 14 ligados à borda), não por limiar global — o
  moletom preto (25–45) não some e o vão entre os raios da roda fica vazado.
- **Roda com raios tampada**: em vez do perfil radial (vira disco cinza e perde os
  raios), complete a parte escondida copiando o ponto oposto pelo cubo
  (`rodas_espelho` no `segmenta.py`): raio continua raio e vão continua vazado.
- **Imagem do piloto sem o veículo**: se o usuário mandar, use-a para o corpo (o
  ragdoll fica completo) e a imagem original só para o veículo. As duas não batem
  pixel a pixel (pose muda): alinhe pela cabeça (busca do menor erro em ±40 px) e
  confira o encaixe numa composição antes de recortar (`manter_pecas` no script).
- **Pé abaixo da roda na arte** (cadeira de escritório): o sensor do piloto encosta
  no chão já na largada e derruba. Termine o sensor no tornozelo e aumente o raio de
  colisão das rodinhas.
- **Veículo de entre-eixos curto e centro alto** empina e capota em subida de 27°:
  ponha a roda física na ponta da base (pode ficar escondida), a roda desenhada vira
  parte do chassi.
- **Animação do piloto montado**: monte as peças em nós articulados (tronco no
  quadril, filhos nas juntas do `parts.json`) e mova por molas cujo alvo vem da
  aceleração do veículo (inclina pra trás ao acelerar, cabeça chacoalha em pancada
  vertical) + respiração; perna do monociclo segue o giro da roda. Zere as rotações
  antes de virar ragdoll (o sprite herda a transform global).
- **Monociclo sem ajuda**: força motora no eixo (o corpo fica pra trás), só
  amortecimento leve de giro; o bot equilibra com PD bang-bang
  (`u = rot + 0,35·ω`, botão quando |u| > 0,03) — inclusive enquanto espera.

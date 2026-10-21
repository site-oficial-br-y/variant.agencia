# Fases e level design

Fases curtas, perigosas, rejogáveis e **concluíveis**. Esta referência define o
padrão de cena de fase, o gerenciador de vitória/derrota/checkpoint, peças de
cenário, princípios de design e o validador automático de mapa.

Volte para o [SKILL.md](../SKILL.md) · física das armadilhas em
[physics-system.md](physics-system.md#8-armadilhas-e-objetos) · teste de
conclusão em [testing.md](testing.md#playtest-automatizado).

---

## 1. Convenção de cena de fase

Toda fase é uma cena `levels/faseNN.tscn` cuja raiz tem o script `LevelManager`
e estes filhos (nomes fixos — validador e playtest dependem deles):

| Nó | Tipo | Obrigatório | Função |
|---|---|---|---|
| `Spawn` | `Marker2D` | sim | onde o veículo nasce (roda encostando no chão) |
| `Meta` | `Area2D` | sim | vitória ao entrar o veículo ou o tronco do piloto |
| `Terreno` | `Node2D` com `StaticBody2D` filhos | sim | chão, rampas, paredes |
| `Checkpoints` | `Node2D` com `Checkpoint` filhos | não | pontos de reinício |
| `Perigos` | `Node2D` | não | serras, espinhos (grupo `"perigo"`), zonas de morte (grupo `"zona_morte"`) |
| `Objetos` | `Node2D` | não | caixas, gangorras, plataformas móveis |

E exporte no `LevelManager` o retângulo `limites` (tudo fora dele = morte).

## 2. `LevelManager`

```gdscript
extends Node2D
class_name LevelManager
## Controla a fase: spawn, vitória, morte, checkpoints, limites e reinício rápido.
## Emite sinais que o HUD e o PlaytestController observam.

signal venceu(tempo: float)
signal morreu(motivo: String)
signal checkpoint_ativado(indice: int)
signal reiniciou

@export var limites: Rect2 = Rect2(-1000, -3000, 12000, 6000)
@export var tempo_max: float = 180.0

var ativo := true
var tempo := 0.0
var checkpoint_atual := -1
var foco: Node2D                       # veículo ou tronco do piloto (o jogo atualiza)

func _ready() -> void:
	$Meta.body_entered.connect(_on_meta)
	if has_node("Checkpoints"):
		var i := 0
		for c in $Checkpoints.get_children():
			c.indice = i
			c.ativado.connect(_on_checkpoint)
			i += 1
	for z in get_tree().get_nodes_in_group("zona_morte"):
		if z is Area2D:
			z.body_entered.connect(func(_b: Node2D) -> void: matar("zona_morte"))

func _physics_process(delta: float) -> void:
	if not ativo:
		return
	tempo += delta
	if is_instance_valid(foco) and not limites.has_point(foco.global_position):
		matar("fora_dos_limites")
	elif tempo > tempo_max:
		matar("tempo_esgotado")

func ponto_de_reinicio() -> Vector2:
	if checkpoint_atual >= 0:
		return $Checkpoints.get_child(checkpoint_atual).global_position
	return $Spawn.global_position

func _on_meta(body: Node2D) -> void:
	if ativo and (body == foco or body.is_in_group("piloto") or body.is_in_group("veiculo")):
		ativo = false
		venceu.emit(tempo)

func _on_checkpoint(indice: int) -> void:
	if indice > checkpoint_atual:
		checkpoint_atual = indice
		checkpoint_ativado.emit(indice)

func matar(motivo: String) -> void:
	if ativo:
		ativo = false
		morreu.emit(motivo)

## reinício rápido: recarrega a cena; o checkpoint sobrevive via autoload
func reiniciar() -> void:
	reiniciou.emit()
	get_tree().reload_current_scene()
```

Para manter o checkpoint ao recarregar a cena, guarde `checkpoint_atual` num
autoload (`Game.checkpoint_da_fase[fase] = indice`) e leia no `_ready`.

```gdscript
extends Area2D
class_name Checkpoint
## Bandeira: ativa quando o veículo ou o piloto passa.

signal ativado(indice: int)

var indice := 0
var _ativo := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0b110
	body_entered.connect(func(_b: Node2D) -> void:
		if not _ativo:
			_ativo = true
			ativado.emit(indice))
```

## 3. Peças de cenário

- **Terreno**: `StaticBody2D` + `CollisionPolygon2D` (contorno) + `Polygon2D`
  (visual) com a **mesma** lista de pontos. Espessura ≥ 150 px onde houver alta
  velocidade. Atrito ≈ 1.
- **Rampa**: retângulo rotacionado sobrepondo 20–40 px nas peças vizinhas (sem
  fresta onde a roda prende). 15–25° para salto; > 35° só com intenção.
- **Buraco/fosso**: sempre com `zona_morte` no fundo (ou espinhos) — cair para
  sempre trava o jogo.
- **Gangorra**: `RigidBody2D` prancha + `PinJoint2D` no meio preso a um
  `StaticBody2D`.
- **Ponte que cai**: tábuas `RigidBody2D` com `freeze = true`; ao `body_entered`
  descongele com atraso (`create_timer(0.4)`).
- **Plataforma móvel / serra**: `AnimatableBody2D` (ver física).
- **Caixas/destrutíveis**: camada `objeto`, colidem com tudo.
- **Segredo**: rota alternativa atrás de parede quebrável ou por cima de um teto,
  sem ser necessária para vencer.

## 4. Princípios de design (originais, inspirados no gênero)

1. **Uma ideia por trecho** e depois uma combinação: rampa → fosso → rampa+fosso
   com serra.
2. **Vários jeitos de passar**: devagar com equilíbrio ou rápido saltando por cima.
3. **Leitura clara do perigo**: cor/forma de perigo consistente (serra e espinho
   com contraste alto) e espaço para reagir.
4. **Fracasso engraçado e rápido**: morte → reinício em < 1 s (botão R, e
   checkpoint a cada 20–40 s de jogo).
5. **Dificuldade progressiva**: fase 1 ensina acelerar/frear/inclinar; fase 2 salto
   e pouso; fase 3 armadilhas móveis; fase 4 combinações e rota secreta.
6. **Nada de morte injusta**: sem armadilha invisível, sem quina que prende a roda,
   sem salto que só funciona com timing de quadro. Terreno por polilinha:
   **arredonde as quinas** (3 iterações de Chaikin) — num caso real a rodinha da
   frente (raio 76) de uma cadeira agarrava na quina seca entre chão e rampa de
   salto e capotava para a frente; com a quina arredondada o mesmo salto passou.
7. **Duração**: 30–90 s para um jogador médio.

Não copie layouts, nomes ou trechos de fases de Happy Wheels; descreva a ideia
mecânica e desenhe do zero.

### Obstáculo de tempo justo (pêndulo, pistão, serra que vai e volta)

Caso real (jogo Bicho Ehn): uma bola de demolição na altura do corpo que **ejetava
ao encostar** era impossível para a cadeira de rodas (865 px de comprimento,
760 px/s), embora segway e scooter passassem. A regra:

- Calcule a travessia: `distância = varredura_total (2·alcance + 2·raio) +
  comprimento_do_veículo`; `velocidade_necessária = distância / meio_período`
  (`T = 2π·√(L/g)`). Ela tem que ficar abaixo de ~80% da `vmax` do veículo **mais
  lento e mais comprido**.
- Meça o alcance real (amplitude cai um pouco no começo) — no caso real 390 px
  medidos contra 465 calculados.
- Prefira que o perigo **empurre fisicamente** (corpo pesado na camada `objeto`)
  em vez de "encostou, morreu" (sensor). O empurrão continua derrubando e jogando
  no fosso, mas o resultado depende de física e controle, não de geometria
  impossível.
- Não deixe o pêndulo alcançar caixas/objetos: batendo neles ele perde energia e
  **para pendurado no caminho**, virando parede permanente (outro bug real).
- Exponha ao bot o que o jogador vê: grupo `"pendulo"` + `set_meta("ancora")`,
  `set_meta("alcance")`.

## 5. Validador de mapa (automático)

Roda headless sobre cada `levels/fase*.tscn` e falha com mensagens claras.
Verificações:

1. Nós obrigatórios (`Spawn`, `Meta`, `Terreno`) e `LevelManager` na raiz.
2. `Spawn`, `Meta`, checkpoints e todos os corpos dentro de `limites`.
3. **Chão sob o spawn** (raycast para baixo encontra terreno a < 400 px).
4. **Perfil do caminho**: raycasts verticais de 20 em 20 px do spawn até a meta;
   registra a altura do chão. Acusa:
   - **buraco** sem chão por mais que `salto_max` (estimativa da distância de
     salto do veículo mais fraco) — vira aviso se houver rampa antes;
   - **buraco sem zona de morte** abaixo (raycast que não acha nada até o limite);
   - **degrau** de subida maior que `degrau_max` (a roda não sobe).
5. Perigos fora do caminho principal não bloqueiam — só alerta se um perigo cobre
   100% da largura de um trecho sem rota alternativa.

O validador **não** prova que a fase é concluível: prova que não há
impossibilidade geométrica óbvia. A prova é o [playtest](testing.md#playtest-automatizado).

```gdscript
extends SceneTree
## Uso: godot --headless --path <proj> -s res://tools/validar_fases.gd -- res://levels/fase01.tscn ...
## Sai com código 1 se alguma fase tiver erro.

const SALTO_MAX := 900.0     # px de buraco que o veículo mais fraco transpõe com rampa
const DEGRAU_MAX := 120.0    # px de subida brusca que a roda vence
const PASSO := 20.0

var erros := 0

func _initialize() -> void:
	var fases := OS.get_cmdline_user_args()
	for caminho in fases:
		await _validar(caminho)
	print("[VALIDADOR] %d erro(s)" % erros)
	quit(1 if erros > 0 else 0)

func _erro(fase: String, msg: String) -> void:
	erros += 1
	print("[ERRO] %s: %s" % [fase, msg])

func _validar(caminho: String) -> void:
	var cena := load(caminho) as PackedScene
	if cena == null:
		_erro(caminho, "não carrega")
		return
	var fase := cena.instantiate()
	root.add_child(fase)
	await physics_frame
	await physics_frame
	for n in ["Spawn", "Meta", "Terreno"]:
		if not fase.has_node(n):
			_erro(caminho, "falta o nó %s" % n)
	if erros > 0 or not (fase is LevelManager):
		if not (fase is LevelManager):
			_erro(caminho, "raiz sem LevelManager")
		fase.queue_free()
		return
	var lm := fase as LevelManager
	var spawn: Vector2 = fase.get_node("Spawn").global_position
	var meta: Vector2 = fase.get_node("Meta").global_position
	for p in [spawn, meta]:
		if not lm.limites.has_point(p):
			_erro(caminho, "ponto %s fora dos limites" % p)
	var espaco: PhysicsDirectSpaceState2D = (fase as Node2D).get_world_2d().direct_space_state
	var chao_spawn := _chao(espaco, spawn, 400.0)
	if chao_spawn == INF:
		_erro(caminho, "sem chão sob o Spawn")
	var x := spawn.x
	var y_ant := chao_spawn if chao_spawn != INF else spawn.y
	var buraco := 0.0
	while x < meta.x:
		x += PASSO
		var y := _chao(espaco, Vector2(x, lm.limites.position.y + 1.0), lm.limites.size.y - 2.0)
		if y == INF:
			buraco += PASSO
			continue
		if buraco > SALTO_MAX:
			_erro(caminho, "buraco de %d px antes de x=%d" % [buraco, x])
		if y_ant - y > DEGRAU_MAX and buraco == 0.0:
			_erro(caminho, "degrau de %d px em x=%d" % [y_ant - y, x])
		buraco = 0.0
		y_ant = y
	print("[OK?] %s verificado até x=%d" % [caminho, x])
	fase.queue_free()

## y do primeiro terreno abaixo de `de` (até `alcance`), ou INF
func _chao(espaco: PhysicsDirectSpaceState2D, de: Vector2, alcance: float) -> float:
	var q := PhysicsRayQueryParameters2D.create(de, de + Vector2(0, alcance), 0b001)
	var hit := espaco.intersect_ray(q)
	return hit["position"].y if hit else INF
```

Ajuste `SALTO_MAX`/`DEGRAU_MAX` medindo no playtest (distância real de salto do
veículo mais fraco na rampa padrão), não no chute.

## 6. Organização para crescer

- `levels/lista_fases.tres` (ou array em autoload) com a ordem das fases; o menu e o
  playtest leem dela.
- Cada fase traz um **critério de aprovação** (ver
  [testing.md](testing.md#criterios-por-fase)) e, opcionalmente, um arquivo
  `levels/faseNN.rota.json` com uma rota de referência para o bot (sequência de
  ações com tempo) — ponto de partida da busca, não trapaça.
- Adicionar fase = criar cena seguindo a convenção + entrada na lista + rodar
  validador e playtest. Nenhum sistema central precisa mudar.

## 7. Composição visual da fase

A fase é desenhada como uma sequência de **momentos** (ver
[visual-quality.md §1](visual-quality.md#1-direção-de-arte-antes-de-código)):

- Abertura legível (placa de largada, chão plano para pegar o controle).
- Alternância ritmo/respiro: obstáculo forte → trecho curto de alívio → próximo.
- Cada momento com uma estrutura coerente e reconhecível de longe (guindaste,
  ponte, andaime, loop), não peças soltas no chão.
- Silhueta variada: subida, descida, penhasco, buraco com água/espinhos, plataforma.
- Pelo menos um caminho alternativo ou atalho arriscado nas fases 2+.
- Encerramento claro (placa de chegada num ponto alto/plano).
- Valide com folha de contato: cada quadro deve ter algo interessante na tela.

## 8. Obstáculo de tempo precisa de janela calculada

Antes de posicionar um pêndulo ou prensa, **simule a passagem** (script de 20 linhas:
veículo em velocidade constante × posição do obstáculo no tempo, testando cada
instante de saída) e anote a janela em segundos para cada personagem.

- Pêndulo baixo e de pouca amplitude **varre a pista inteira e nunca abre
  brecha**: um boneco de 1,1–1,4 mil px não passa por baixo. Solução usada: a bola
  passa na altura do peito (700 px acima do chão) e sobe alto nas pontas (85°).
  Com L = 1300 e ω = 0,6 a janela fica em 1,2–1,9 s para os 3 veículos.
- O movimento é cinemático (θ0·cos ωt), então ω pode ser escolhido para dar a
  janela. Não precisa ser √(g/L).
- **Corpo cinemático nasce onde vai ficar**: definir `position` antes de
  `add_child`. Criado na origem e movido depois, ele varre o mundo no 1º passo e
  arremessa quem estiver perto de (0,0). Foi o bug da "bola acertando na largada".
- O bot só prova a fase se esperar como gente: dê a ele a regra do obstáculo
  (metas `fase`/`alcance` no nó) e registre quantas tentativas levou.

# Testes, playtest automatizado e relatório

Compilar não é testar; simular física isolada não é jogar. Esta referência define
o que conta como evidência, os testes de física/regressão, o **bot de playtest**
que tenta concluir cada fase e o modelo de relatório honesto.

Volte para o [SKILL.md](../SKILL.md) · convenção de fase em
[level-design.md](level-design.md#1-convenção-de-cena-de-fase) · componentes em
[architecture.md](architecture.md).

---

<a id="niveis-de-evidencia"></a>
## 1. Níveis de evidência

| Nível | O que foi feito | Pode afirmar |
|---|---|---|
| N0 | projeto importa, scripts sem erro de parse | "compila" |
| N1 | teste de física isolado (cena de teste, sem jogo) | "a mecânica X se comporta assim" |
| N2 | **jogo real** (fase de verdade, HUD, regras) com **entrada simulada no motor** (`Input.action_press`) | "o bot concluiu a fase com entrada simulada" |
| N3 | jogo real renderizado (Xvfb) com **entrada real do sistema** (XTest/xdotool → janela do Godot) | "o jogo foi jogado com teclado (sintético do SO) e a fase foi concluída" |
| N4 | pessoa jogando no aparelho alvo | "testado no celular/PC" |

Sempre informe o nível alcançado. `Input.action_press` dentro do motor é **N2,
não N3** — não diga que "apertou teclas". Toque na tela de celular real só é N4.

## 2. Execução no ambiente

```bash
G=/caminho/para/godot; P=/caminho/do/projeto
# importar (uma vez, ou após mudar assets) — sempre com --path
$G --headless --path $P --import
# erro de parse vira texto "SCRIPT ERROR"/"Parse Error": falhe o passo se aparecer
$G --headless --path $P --quit 2>&1 | grep -E "SCRIPT ERROR|Parse Error" && exit 1
# testes de física (N1)
$G --headless --path $P -s res://tools/testes_fisica.gd
# playtest de uma fase (N2), sem render
$G --headless --path $P res://levels/fase01.tscn -- playtest tentativas=20 semente=1234
# playtest renderizado com screenshots (N2 com imagem)
xvfb-run -a -s "-screen 0 1280x720x24" $G --path $P --rendering-driver opengl3 \
  --resolution 1280x720 res://levels/fase01.tscn -- playtest tentativas=5 semente=1234 fotos
```

- Argumentos próprios **depois de `--`** (`--test` é reservado e aborta o binário).
- Use `timeout` em tudo; trate código 124 como travamento.
- Rode em segundo plano quando passar de ~2 min e espere pelo fim (sem `sleep`
  encadeado).
- Áudio: no contêiner o ALSA falha e cai no driver *dummy* — ignore essas linhas.

## 3. Testes de física e regressão (N1)

Determinísticos: sem aleatoriedade (ou semente fixa), passo fixo de 60 Hz, cada
teste instancia a cena mínima, roda N passos (`await physics_frame`) e confere
números.

| Teste | Critério de APROVADO |
|---|---|
| spawn estável | após 6 s parado: `abs(rotation) < 0.35 rad`, `y` não variou > 30 px |
| roda × terreno | 2,5 s de aceleração: avançou > 150 px, roda girou (`angular_velocity != 0`) |
| sem túnel | queda de 1500 px sobre chão: corpo termina acima do chão |
| juntas estáveis | ragdoll solto a 900 px/s: após 1,3 s `vel_max < 8000`, distância entre pivôs ligados < 6 px |
| ragdoll sob impacto | batida na parede: sinal `pancada` emitido; nenhum `NaN` em posição |
| arrancar membro | `arrancar("braco")`: junta removida, demais preservadas, manchas > 10 |
| armadilha | corpo empurrado para a serra/espinho: `matou` emitido em < 1 s |
| checkpoint | atravessar → `checkpoint_ativado(0)`; morte → reinício nasce no checkpoint |
| vitória/derrota | entrar na `Meta` → `venceu`; sair dos `limites` → `morreu("fora_dos_limites")` |
| carga | cada personagem do registro e cada fase da lista instancia sem erro |
| erros de script | nenhuma linha `SCRIPT ERROR` no log da execução |

Cada teste imprime uma linha `[TESTE] nome APROVADO|FALHOU detalhe` e o runner
sai com código ≠ 0 se algum falhar. Guarde o resultado em
`user://testes/ultimo.json` e compare com o anterior para achar **regressão**
(teste que passava e passou a falhar).

```gdscript
extends SceneTree
## Runner mínimo de testes de física. Uso: godot --headless --path P -s res://tools/testes_fisica.gd

var falhas := 0

func _initialize() -> void:
	await _teste_queda_sem_tunel()
	await _teste_juntas_estaveis()
	print("[TESTES] %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)

func _registrar(nome: String, ok: bool, detalhe: String) -> void:
	if not ok:
		falhas += 1
	print("[TESTE] %s %s %s" % [nome, "APROVADO" if ok else "FALHOU", detalhe])

func _passos(n: int) -> void:
	for i in n:
		await physics_frame

func _chao(y: float) -> StaticBody2D:
	var s := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(4000, 200)
	cs.shape = r
	s.add_child(cs)
	s.position = Vector2(0, y + 100)
	root.add_child(s)
	return s

func _teste_queda_sem_tunel() -> void:
	var chao := _chao(1000.0)
	var b := RigidBody2D.new()
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 20
	cs.shape = c
	b.add_child(cs)
	b.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	b.position = Vector2(0, -500)
	b.linear_velocity = Vector2(0, 3000)
	root.add_child(b)
	await _passos(180)
	_registrar("sem_tunel", b.global_position.y < 1000.0, "y=%.1f" % b.global_position.y)
	b.queue_free()
	chao.queue_free()

func _teste_juntas_estaveis() -> void:
	var chao := _chao(800.0)
	var a := _bola(Vector2(0, 0))
	var b := _bola(Vector2(60, 0))
	var j := PinJoint2D.new()
	root.add_child(j)
	j.global_position = Vector2(30, 0)
	j.node_a = a.get_path()
	j.node_b = b.get_path()
	j.disable_collision = true
	a.linear_velocity = Vector2(900, -300)
	b.linear_velocity = Vector2(900, -300)
	await _passos(80)
	var vmax := maxf(a.linear_velocity.length(), b.linear_velocity.length())
	var dist := a.global_position.distance_to(b.global_position)
	_registrar("juntas_estaveis", vmax < 8000.0 and absf(dist - 60.0) < 6.0,
		"vmax=%.0f dist=%.1f" % [vmax, dist])
	for n in [a, b, j, chao]:
		n.queue_free()

func _bola(p: Vector2) -> RigidBody2D:
	var b := RigidBody2D.new()
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 15
	cs.shape = c
	b.add_child(cs)
	b.position = p
	root.add_child(b)
	return b
```

<a id="playtest-automatizado"></a>
## 4. Playtest automatizado (N2): o bot tenta zerar

O `PlaytestController` roda **dentro do jogo real** (a cena da fase com todos os
sistemas), controla pelas mesmas ações do Input Map que o jogador usa, observa
o `LevelManager` e repete tentativas até vencer ou esgotar.

Estratégias, nesta ordem:
1. **Rota de referência** (`levels/faseNN.rota.json`, se existir): lista de
   `[acao, segundos]`. Serve para regressão: se parou de funcionar, algo mudou.
2. **Piloto reativo**: acelera; corrige inclinação (inclina contra a rotação
   quando `|rot| > 0.35`); se não progride por 3 s, dá ré 0,6 s e tenta de novo;
   alivia o acelerador quando no ar e girando rápido.
3. **Busca com semente**: sequências aleatórias de macros (acelerar N s, soltar,
   inclinar, frear) com `RandomNumberGenerator.seed` registrada — reproduzível.

Detecção por tentativa: `venceu` (sinal) · `morreu` (sinal, com motivo) ·
**travado** (avançou < 30 px em 5 s) · **explosão** (velocidade > 20000 ou `NaN`) ·
**tempo** (> `tempo_max`). Cada tentativa vira uma linha JSONL; ao fim imprime o
resumo e sai com código 0 só se houve vitória.

```gdscript
extends Node
class_name PlaytestController
## Bot de playtest. Ative com: -- playtest tentativas=20 semente=1234 [fotos]
## Precisa: raiz da cena = LevelManager; veículo no grupo "veiculo".

@export var tentativas_max: int = 20
@export var semente: int = 1234
@export var tempo_travado: float = 5.0

var rng := RandomNumberGenerator.new()
var fotos := false
var tentativa := 0
var log_path := "user://playtest/log.jsonl"
var _resultado := ""
var _quedas: Array = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "observar" in args:               # N3: quem joga é a entrada real; aqui só registra
		_observar.call_deferred()
		return
	if not "playtest" in args:
		queue_free()
		return
	for a in args:
		if a.begins_with("tentativas="): tentativas_max = int(a.substr(11))
		if a.begins_with("semente="): semente = int(a.substr(8))
	fotos = "fotos" in args
	rng.seed = semente
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtest"))
	_rodar.call_deferred()

func _observar() -> void:
	var fase := _fase()
	if fase == null:
		return
	fase.venceu.connect(func(t: float) -> void: print("[OBSERVADO] venceu %.2f" % t))
	fase.morreu.connect(func(m: String) -> void: print("[OBSERVADO] morreu " + m))
	while true:
		await get_tree().create_timer(1.0).timeout
		var v := _veiculo()
		if is_instance_valid(v):
			print("[OBSERVADO] x=%.0f rot=%.2f teclas: dir=%s" % [v.global_position.x,
				v.global_rotation, Input.is_action_pressed("accelerate")])

func _fase() -> LevelManager:
	return get_tree().current_scene as LevelManager

func _veiculo() -> Node2D:
	return get_tree().get_first_node_in_group("veiculo") as Node2D

func _rodar() -> void:
	var venceu := false
	while tentativa < tentativas_max and not venceu:
		tentativa += 1
		await get_tree().process_frame
		var fase := _fase()
		if fase == null:
			print("[PLAYTEST] cena atual não é LevelManager")
			get_tree().quit(2)
			return
		_resultado = ""
		fase.venceu.connect(func(t: float) -> void: _resultado = "venceu %.2f" % t, CONNECT_ONE_SHOT)
		fase.morreu.connect(func(m: String) -> void: _resultado = "morreu " + m, CONNECT_ONE_SHOT)
		var estrategia := "reativo" if tentativa <= tentativas_max / 2 else "busca"
		var t0 := Time.get_ticks_msec()
		await _jogar(estrategia, fase)
		var v := _veiculo()
		var x: float = v.global_position.x if is_instance_valid(v) else NAN
		var linha := {"tentativa": tentativa, "estrategia": estrategia, "semente": semente,
			"resultado": _resultado, "x_final": x, "ms": Time.get_ticks_msec() - t0}
		_registrar(linha)
		if fotos:
			await _foto("tentativa_%02d" % tentativa)
		venceu = _resultado.begins_with("venceu")
		if not venceu:
			_quedas.append(x)
			_soltar_tudo()
			fase.reiniciar()
			await get_tree().process_frame
			await get_tree().process_frame
	print("[PLAYTEST] %s após %d tentativa(s); pontos de falha x=%s" %
		["VENCEU" if venceu else "NÃO VENCEU", tentativa, str(_quedas)])
	get_tree().quit(0 if venceu else 1)

func _jogar(estrategia: String, fase: LevelManager) -> void:
	var v := _veiculo()
	var melhor_x: float = v.global_position.x if v else 0.0
	var t_progresso := 0.0
	var t := 0.0
	var macro_ate := 0.0
	var macro := ""
	while _resultado == "":
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		v = _veiculo()
		if not is_instance_valid(v):
			_resultado = "morreu sem_veiculo"
			break
		var rb := v as RigidBody2D
		if rb and (rb.linear_velocity.length() > 20000.0 or is_nan(rb.global_position.x)):
			_resultado = "explosao"
			break
		if v.global_position.x > melhor_x + 30.0:
			melhor_x = v.global_position.x
			t_progresso = 0.0
		else:
			t_progresso += dt
		if t_progresso > tempo_travado:
			_resultado = "travado"
			break
		_soltar_tudo()
		if estrategia == "reativo":
			var rot := v.global_rotation
			if t_progresso > 3.0 and t_progresso < 3.6:
				Input.action_press("brake")
			else:
				Input.action_press("accelerate")
			if rot < -0.35: Input.action_press("lean_fwd")
			elif rot > 0.35: Input.action_press("lean_back")
		else:
			if t >= macro_ate:
				macro = ["accelerate", "accelerate", "lean_back", "lean_fwd", "brake", ""][rng.randi_range(0, 5)]
				macro_ate = t + rng.randf_range(0.2, 1.5)
			if macro != "":
				Input.action_press(macro)
				if macro != "accelerate": Input.action_press("accelerate")
	_soltar_tudo()

func _soltar_tudo() -> void:
	for a in ["accelerate", "brake", "lean_fwd", "lean_back"]:
		Input.action_release(a)

func _registrar(linha: Dictionary) -> void:
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(JSON.stringify(linha))
	print("[TENTATIVA] ", JSON.stringify(linha))

func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://playtest/%s.png" % nome)
```

### Estratégias que funcionaram (caso real)

No jogo Bicho Ehn (3 personagens, 1 fase com rampa, fosso com espetos, pêndulo,
caixas, ponte), o rodízio que concluiu a fase com os três foi:

| Estratégia | O que faz | Para quê |
|---|---|---|
| `reativo` | acelera, corrige inclinação (`|rot| > 0.3` → inclina contra), dá ré 1,2 s se travar 2,5 s | trechos de habilidade |
| `reativo_espera` | igual, mas **olha o perigo**: para antes do alcance e sai no instante em que o pêndulo **vira** no lado de cá (sinal de `vx` troca) | obstáculos de tempo |
| `busca` | macros aleatórias com semente + espera aleatória inicial | descobrir rotas que as outras não acham |

Lições: espera aleatória sem dirigir bem capota antes do obstáculo; esperar longe
demais exige velocidade impossível; limiar de posição "teórico" (alcance
calculado) pode nunca ser atingido — detecte o **evento** (virada), não a posição.
Toda tentativa morrendo no **mesmo x e no mesmo tempo** indica obstáculo
determinístico + estratégia que não se adapta — ou geometria impossível: faça a
conta antes de culpar o bot.

Mais lições reais (3 fases × 3 personagens):

- **Corrija a inclinação relativa ao chão**, não absoluta: meça o ângulo do
  terreno com dois raios (200 px atrás/à frente) e no ar mire nivelado. Corrigir
  pela rotação absoluta fez o bot inclinar a cadeira para a frente **contra a
  rampa** e cair antes do fosso.
- **Meça trajetória por marcos** (velocidade e rotação ao cruzar x = A, B, C…)
  antes de culpar fase ou bot: a previsão teórica de 1300 px/s na saída da rampa
  era 750–990 px/s na prática (atrito/amortecimento padrão).
- **Leia os argumentos (`f=`, `p=`) no início do `_ready`, antes de montar a
  cena.** Lidos depois, todo teste de "fase 2/3" rodou a fase 1 e passou — falso
  positivo detectado só olhando as capturas. Sempre confirme visualmente qual fase
  foi testada.

Desempenho: headless com `--fixed-fps 60` roda muito mais rápido que o tempo real
(física idêntica). **Renderizado por software (Xvfb) com `--fixed-fps` fica lento
demais** (estourou 300 s por personagem) — para fotos, rode em tempo real.

Registre o `PlaytestController` como **autoload** (sobrevive ao
`reload_current_scene()` do reinício). Ele só age com o argumento `playtest`.

> Sobre o reinício: como o autoload persiste e a cena é recarregada, reconecte os
> sinais a cada tentativa (o código acima faz isso).

### Entrada real do sistema (N3)

Se houver Xvfb e `python-xlib` (ou `xdotool`), mande teclas **para o processo do
jogo** pelo servidor X — o Godot recebe como teclado de verdade. O jogo roda em
modo observador (`-- observar`): o `PlaytestController` não injeta nada, só
registra telemetria e vitória/morte.

```python
# tools/playtest_xtest.py — uso: python3 playtest_xtest.py <godot> <projeto> <cena>
import os, subprocess, sys, time
from Xlib import X, XK, display
from Xlib.ext import xtest

godot, proj, cena = sys.argv[1:4]
xvfb = subprocess.Popen(["Xvfb", ":77", "-screen", "0", "1280x720x24"])
time.sleep(1.5)
env = dict(os.environ, DISPLAY=":77")
jogo = subprocess.Popen([godot, "--path", proj, "--rendering-driver", "opengl3",
                         "--resolution", "1280x720", cena, "--", "observar"],
                        env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
d = display.Display(":77")
# sem gerenciador de janelas o foco segue o ponteiro: ponha o ponteiro sobre o jogo
xtest.fake_input(d, X.MotionNotify, x=640, y=360); d.sync()
def tecla(nome, segundos):
    kc = d.keysym_to_keycode(XK.string_to_keysym(nome))
    xtest.fake_input(d, X.KeyPress, kc); d.sync()
    time.sleep(segundos)
    xtest.fake_input(d, X.KeyRelease, kc); d.sync()
time.sleep(6)                         # carregar
for nome, seg in [("Right", 3.0), ("Up", 0.4), ("Right", 2.0)]:
    tecla(nome, seg)
time.sleep(2)
jogo.terminate(); saida = jogo.communicate(timeout=10)[0]; xvfb.terminate()
print(saida[-2000:])
```

Verificado (Godot 4.3 + Xvfb + python-xlib): uma cena-sonda com `_input()`
imprimiu `tecla Right DOWN`, `Right segurada` nos quadros seguintes e
`tecla Right UP` — o motor recebe o XTest como teclado real. Antes de confiar em
um ambiente novo, repita a sonda:

```gdscript
extends Node2D
## Sonda de entrada real: rode sob Xvfb e mande teclas com XTest/xdotool.
func _input(e: InputEvent) -> void:
	if e is InputEventKey and not e.echo:
		print("[SONDA] tecla %s %s" % [OS.get_keycode_string((e as InputEventKey).physical_keycode),
			"DOWN" if e.pressed else "UP"])
```

Sem Xvfb/XTest disponíveis → N3 = **NÃO TESTADO** (diga isso no relatório).

<a id="criterios-por-fase"></a>
## 5. Critérios de aprovação por fase

Cada fase declara e o playtest verifica:

| Critério | Como verificar | Evidência |
|---|---|---|
| inicia | cena carrega, `Spawn` válido, nada de `SCRIPT ERROR` | log |
| controles respondem | 1 s de `accelerate` → x aumenta > 50 px | telemetria |
| interage com obstáculos | algum contato registrado com rampa/perigo | sinal/log |
| caminho viável | **pelo menos 1 vitória** em ≤ N tentativas | `venceu` + JSONL + screenshot |
| vitória aciona | `venceu` emitido ao entrar na `Meta` | log |
| morte e reinício | provocar morte (zona de morte) → `morreu` → reinício no ponto certo | log |
| checkpoints | passar CP, morrer, renascer no CP | log com posições |
| sem bloqueio injusto | nenhuma tentativa termina em `travado` no mesmo x em todas as estratégias | histograma de x |
| sem instabilidade | zero `explosao`, zero `NaN`, nenhuma peça atravessa o chão | log |
| desempenho | FPS médio ≥ 50 no render (`Engine.get_frames_per_second()`) ou tempo de passo de física < 8 ms | telemetria |

Se a fase não for concluída: classifique a causa — **execução** (crash/tempo),
**estratégia** (bot fraco: melhore o bot ou a rota de referência),
**bug** (colisão errada, junta instável, gatilho que não dispara) ou **design**
(salto impossível com o veículo mais fraco). Corrija a causa real; não remova o
desafio só para passar.

## 6. Regressão

Depois de qualquer mudança em física, controles, personagens ou fases:
1. testes de física (N1); 2. carga de personagens e fases; 3. validador de mapa;
4. playtest de todas as fases com **a mesma semente** e as rotas de referência.
Compare com o último resultado salvo; uma fase que vencia e deixou de vencer é
regressão crítica.

<a id="relatorio-de-playtest"></a>
## 7. Relatório de playtest (modelo)

```markdown
# Relatório de playtest — <projeto> v<versão> (<data>)

Ambiente: Godot <versão>, headless/Xvfb, renderizador <x>, nível de evidência máximo: N2|N3
Semente: <n>

| Fase | Tentativas | Resultado | Tempo da vitória | Falhas recorrentes (x) | Nível |
|---|---|---|---|---|---|
| fase01 | 3 | APROVADO | 41,2 s | 1830 (fosso) | N2 |
| fase02 | 20 | FALHOU | — | 2550 ×14 (degrau) | N2 |

Testes de física: 11 APROVADO, 0 FALHOU, 1 NÃO TESTADO (desempenho sem GPU)
Regressão: sem regressão em relação a <data/commit>

Bugs encontrados e corrigidos: ...
Problemas críticos em aberto: ...
Limitações: sem toque real (N4 NÃO TESTADO); WebGL por software no navegador ...
```

Regras: **APROVADO** = executado e critério atendido; **FALHOU** = executado e não
atendido; **NÃO TESTADO** = não foi possível executar. Toda célula com número tem
que vir de log. Sem evidência de vitória, a fase não está "zerada".

## Lições do Bicho Ehn (rodada das fases gigantes)

- **Sensação de "gravidade da lua"** vem da escala: com boneco de ~1300 px (≈ 720 px/m),
  gravidade de 980 px/s² é 1/7 da real. Em vez de reajustar gravidade, velocidade, ω de
  pêndulo e limiares um por um, use `Engine.time_scale` (RITMO) e suba
  `physics_ticks_per_second` na mesma proporção (60 × RITMO): o passo de jogo continua
  1/60 s, então tudo que o bot já validou continua valendo. Custo: mais passos de
  física por segundo real — medir em celular.
- **Obstáculo de tempo fica mais difícil em tempo real** quando o ritmo sobe: recalcule a
  janela em segundos reais e desacelere (ω menor) se cair abaixo de ~1 s.
- **Chamadas adiadas depois do reinício** (`call_deferred`, timers) chegam com o nó fora
  da árvore: cheque `is_inside_tree()` antes de `get_tree()`.
- **Exportação web às vezes falha na 1ª vez** com `Parameter "fd" is null`: confira a
  data do `.pck` e repita; use caminhos absolutos.
- **Caixa solta antes de subida trava o veículo fraco** (rola de volta na frente).
- **Antes de qualquer teste**, carregue os scripts com `load(...).can_instantiate()` num
  `-s` script: erro de parse em cena que o teste não abre não aparece em outro lugar.

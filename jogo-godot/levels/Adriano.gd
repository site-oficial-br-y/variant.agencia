extends Node2D
class_name Adriano
## Chefe da fase 7: queda infinita do 5º andar. A fachada da escola passa borrada
## de baixo pra cima, o Adriano cai junto no fundo mexendo as mãos (não ataca).
## Você anda numa fileira de pisos que caem (piscam vermelho antes) e voltam;
## lasers vermelhos: coluna (pisca e dispara) e cortina (desce com um vão verde).
## Botão verde num piso: aperta, ele leva choque e vai ficando machucado. 6 choques.
## Toda a temporização é em segundos REAIS.

signal derrotado

const VIDA_MAX := 6
const LARG := 1700.0                    # largura de cada piso
const VAO := 50.0
const ESP := 140.0                      # espessura do piso
const ALTURAS := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]   # mesma altura: roda pequena não trava em degrau
var fase: Node2D
var chao := 1000.0
var x0 := 0.0
var vida := VIDA_MAX
var morto := false
var ativo := false
var _t := 0.0
var pisos: Array = []
var lasers: Array = []
var botao: Dictionary = {}
var _prox_queda := 3.0
var _prox_laser := 3.5
var _prox_botao := 3.0
var _estagio := -1
var _tremor := 0.0
var _fim_t := 0.0
# fundo e chefe ficam em camadas de tela (caem junto com você)
var _camada_fundo: CanvasLayer
var _camada_boss: CanvasLayer
var _boss: Node2D
var _corpo: Sprite2D
var _mao_e: Sprite2D
var _mao_d: Sprite2D
var _barra: ColorRect
var _barra_fundo: ColorRect
var _rotulo: Label

const QUEDA_SH := """shader_type canvas_item;
uniform sampler2D tela : repeat_enable, filter_linear;
uniform float vel = 1.4;
float h(float x) { return fract(sin(x * 91.17) * 43758.5); }
void fragment() {
	vec2 uv = vec2(UV.x, UV.y * 0.75 + TIME * vel);
	vec3 c = vec3(0.0);
	for (int k = 0; k < 12; k++) { c += texture(tela, uv + vec2(0.0, float(k) * 0.012)).rgb; }
	c /= 12.0;
	float col = floor(UV.x * 90.0);
	float risco = step(0.93, h(col)) * smoothstep(0.6, 1.0, fract(UV.y * 1.5 + TIME * (3.0 + 3.0 * h(col + 7.0)) + h(col + 3.0)));
	COLOR = vec4(c * 0.62 + vec3(0.85, 0.9, 1.0) * risco * 0.35, 1.0);
}"""

func _real(delta: float) -> float:
	return delta / Engine.time_scale

## monta pisos, paredes e zona de queda no mundo (o visual de queda só liga em comecar)
func montar(main: Node2D, x_ini: float, y_chao: float) -> void:
	fase = main
	chao = y_chao
	x0 = x_ini
	for i in ALTURAS.size():
		var base := Vector2(x0 + LARG / 2.0 + i * (LARG + VAO), chao + float(ALTURAS[i]) + ESP / 2.0)
		var ab := AnimatableBody2D.new()
		ab.sync_to_physics = false
		ab.collision_layer = 0b01
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(LARG, ESP)
		cs.shape = r
		ab.add_child(cs)
		var P: Pecas = fase.pecas
		var atras := -90.0 if i % 2 == 0 else -50.0
		P.poligono(Pecas.retangulo(Vector2(-80, atras), Vector2(LARG, ESP)), Color(0.32, 0.33, 0.37), -1, null, 1.0, ab)   # piso de trás (sobreposto)
		P.poligono(Pecas.retangulo(Vector2.ZERO, Vector2(LARG, ESP)), Color(0.62, 0.62, 0.6), 1, null, 1.0, ab)
		P.poligono(Pecas.retangulo(Vector2(0, -ESP / 2.0 + 14), Vector2(LARG, 28)), Color.WHITE, 1, P.tex("perigo"), 0.6, ab)
		var aviso := P.poligono(Pecas.retangulo(Vector2.ZERO, Vector2(LARG + 20, ESP + 20)), Color(1, 0.1, 0.1, 0.0), 2, null, 1.0, ab)
		ab.position = base
		fase.add_child(ab)
		pisos.append({"no": ab, "base": base, "estado": "ok", "t": 0.0, "v": 0.0, "aviso": aviso, "i": i})
	var fim_x := x0 + ALTURAS.size() * (LARG + VAO)
	for px in [x0 - 200.0, fim_x + 70.0]:              # paredes invisíveis nas pontas
		var sb := StaticBody2D.new()
		sb.collision_layer = 0b01
		var cs2 := CollisionShape2D.new()
		var r2 := RectangleShape2D.new()
		r2.size = Vector2(400, 30000)
		cs2.shape = r2
		sb.add_child(cs2)
		sb.position = Vector2(px, chao - 12000.0)
		fase.add_child(sb)
	var queda: Area2D = fase._area(Vector2((x0 + fim_x) / 2.0, chao + 2200.0), Vector2(fim_x - x0 + 4000.0, 400))
	queda.body_entered.connect(func(b: Node2D) -> void:
		if ativo and not morto and (b.is_in_group("veiculo") or b.is_in_group("piloto")):
			fase._fim(false, "caiu"))

func centro() -> Vector2:
	return Vector2(x0 + ALTURAS.size() * (LARG + VAO) / 2.0, chao)

func piso_inicial() -> Vector2:
	var p: Dictionary = pisos[2]
	return Vector2((p["base"] as Vector2).x, (p["base"] as Vector2).y - ESP / 2.0)

## liga a queda: fundo borrado, Adriano no fundo, barra de vida
func comecar() -> void:
	if ativo:
		return
	ativo = true
	_camada_fundo = CanvasLayer.new()
	_camada_fundo.layer = -60
	fase.add_child(_camada_fundo)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = QUEDA_SH
	mat.shader = sh
	mat.set_shader_parameter("tela", load("res://assets/adriano/fachada.jpg"))
	bg.material = mat
	_camada_fundo.add_child(bg)
	_camada_boss = CanvasLayer.new()
	_camada_boss.layer = -50
	fase.add_child(_camada_boss)
	_boss = Node2D.new()
	_camada_boss.add_child(_boss)
	_corpo = Sprite2D.new()
	_mao_e = Sprite2D.new()
	_mao_d = Sprite2D.new()
	for s in [_corpo, _mao_e, _mao_d]:
		_boss.add_child(s)
	_mao_e.offset = Vector2(-280, 23.5)                    # gira pelo pulso
	_mao_d.offset = Vector2(280, 23.5)
	_trocar_estagio()
	var hud: CanvasLayer = fase.get_node("HUD")
	_barra_fundo = ColorRect.new()
	_barra_fundo.color = Color(0, 0, 0, 0.7)
	_barra_fundo.size = Vector2(620, 40)
	hud.add_child(_barra_fundo)
	_barra = ColorRect.new()
	_barra.color = Color(0.9, 0.15, 0.2)
	_barra.size = Vector2(600, 24)
	hud.add_child(_barra)
	_rotulo = Label.new()
	_rotulo.text = "ADRIANO"
	_rotulo.add_theme_font_size_override("font_size", 30)
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 8)
	hud.add_child(_rotulo)

func _trocar_estagio() -> void:
	var e := 0 if vida > 4 else (1 if vida > 2 else 2)
	if e == _estagio:
		return
	_estagio = e
	_corpo.texture = load("res://assets/adriano/e%d_corpo.png" % e)
	_mao_e.texture = load("res://assets/adriano/e%d_mao_e.png" % e)
	_mao_d.texture = load("res://assets/adriano/e%d_mao_d.png" % e)

func _posicionar(dt: float) -> void:
	var v := fase.get_viewport().get_visible_rect().size
	var esc := minf(v.x * 0.62 / 1880.0, v.y * 0.5 / 837.0)
	var bob := sin(_t * 1.3) * 12.0
	var tremor := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 18.0 * _tremor
	_boss.position = Vector2(v.x / 2.0, v.y * 0.06 + 418.0 * esc + bob) + tremor
	if morto:
		_boss.position.y -= minf(1.0, _fim_t / 2.0) * v.y * 1.3      # derrotado: fica pra trás (sobe na tela)
		_boss.rotation = _fim_t * 0.4
	_boss.scale = Vector2.ONE * esc * (1.0 + 0.012 * sin(_t * 2.1))
	_corpo.position = Vector2.ZERO
	_mao_e.position = Vector2(-300, 51.5) + Vector2(sin(_t * 2.2) * 26.0, cos(_t * 1.7) * 22.0)
	_mao_d.position = Vector2(300, 51.5) + Vector2(sin(_t * 1.9 + 1.0) * 26.0, cos(_t * 2.3 + 2.0) * 22.0)
	_mao_e.rotation = sin(_t * 2.0) * 0.09
	_mao_d.rotation = -sin(_t * 2.4 + 0.7) * 0.09
	_tremor = maxf(0.0, _tremor - dt * 2.0)
	_barra_fundo.position = Vector2(v.x / 2.0 - 310, 112)
	_barra.position = _barra_fundo.position + Vector2(10, 8)
	_barra.size.x = 600.0 * float(vida) / VIDA_MAX
	_rotulo.position = _barra_fundo.position + Vector2(0, -38)

# ---------- passo ----------
func atualizar(delta: float) -> void:
	if not ativo:
		return
	var dt := _real(delta)
	_t += dt
	_posicionar(dt)
	for p in pisos:
		_mover_piso(p, dt)
	for l in lasers.duplicate():
		_passo_laser(l, dt)
	_passo_botao(dt)
	if morto:
		_fim_t += dt
		if _fim_t > 2.2 and _fim_t - dt <= 2.2:
			derrotado.emit()
		return
	if not fase.ativo:
		return
	var nivel := VIDA_MAX - vida
	_prox_queda -= dt
	if _prox_queda <= 0.0:
		_prox_queda = maxf(2.2, 3.6 - 0.25 * nivel)
		_derrubar()
	_prox_laser -= dt
	var tem_cortina := lasers.any(func(l): return l["tipo"] == "cortina")
	if _prox_laser <= 0.0 and not tem_cortina:            # cortina e coluna nunca juntas (vão seguro é seguro)
		_prox_laser = maxf(1.5, 2.6 - 0.2 * nivel)
		if vida <= 4 and randf() < 0.4 and lasers.is_empty():
			_cortina()
			_prox_laser = 1.0
		else:
			_coluna(_alvo_x() + randf_range(-500, 500))
			if vida <= 2 and randf() < 0.5:
				_coluna(randf_range(x0 + 400.0, x0 + ALTURAS.size() * (LARG + VAO) - 400.0))

func _alvo_x() -> float:
	var pl: Player = fase.player
	if is_instance_valid(pl) and is_instance_valid(pl.chassi):
		return pl.foco().global_position.x + (pl.chassi.linear_velocity.x * 0.6 if pl.montado else 0.0)
	return centro().x

func _corpos() -> Array:
	var pl: Player = fase.player
	if not is_instance_valid(pl):
		return []
	if pl.montado and is_instance_valid(pl.chassi):
		return [pl.chassi] + pl.rodas + pl.membros.values()
	return pl.corpos.values()

# ---------- pisos ----------
func _derrubar() -> void:
	var fora := pisos.filter(func(p): return p["estado"] != "ok")
	if fora.size() >= 2:
		return
	var livres: Array = pisos.filter(func(p): return p["estado"] == "ok" and _vizinhos_ok(int(p["i"])))
	if livres.size() <= 1:
		return
	var escolha: Dictionary = livres[randi() % livres.size()]
	if randf() < 0.45:                                   # às vezes o que está embaixo de você
		var ax := _alvo_x()
		for p in livres:
			if absf((p["base"] as Vector2).x - ax) < LARG / 2.0 + VAO:
				escolha = p
	escolha["estado"] = "aviso"
	escolha["t"] = 0.0
	Audio.tocar("metal", 0.5)

## só cai piso cujos vizinhos estão de pé: nunca abre um buraco duplo que te prende
func _vizinhos_ok(i: int) -> bool:
	for j in [i - 1, i + 1]:
		if j >= 0 and j < pisos.size() and pisos[j]["estado"] != "ok":
			return false
	return true

func _mover_piso(p: Dictionary, dt: float) -> void:
	p["t"] += dt
	var no: AnimatableBody2D = p["no"]
	var base: Vector2 = p["base"]
	var av: Polygon2D = p["aviso"]
	match p["estado"]:
		"ok":
			no.position = base
			av.color.a = 0.0
		"aviso":                                         # pisca vermelho e treme: sai daí
			var t: float = p["t"]
			av.color.a = 0.55 if fmod(t, 0.18) < 0.1 else 0.1
			no.position = base                           # só o visual pisca (tremer o corpo derrubava quem estava em cima)
			if t >= 1.4:
				p["estado"] = "caindo"
				p["t"] = 0.0
				p["v"] = 0.0
		"caindo":
			p["v"] = float(p["v"]) + 9000.0 * dt
			no.position.y += float(p["v"]) * dt
			av.color.a = 0.3
			if no.position.y > base.y + 4000.0:
				p["estado"] = "fora"
				p["t"] = 0.0
				no.visible = false
		"fora":
			if p["t"] >= 2.6:
				p["estado"] = "volta"
				p["t"] = 0.0
				no.visible = true
				no.position = base + Vector2(0, 2600)
		"volta":                                         # volta subindo pro lugar
			var k: float = minf(1.0, float(p["t"]) / 0.9)
			no.position = base + Vector2(0, 2600.0 * (1.0 - smoothstep(0.0, 1.0, k)))
			av.color = Color(0.3, 1.0, 0.4, 0.35 * (1.0 - k))
			if k >= 1.0:
				p["estado"] = "ok"
				av.color = Color(1, 0.1, 0.1, 0.0)

# ---------- lasers ----------
func _linha(larg: float, cor: Color, z: int) -> Line2D:
	var l := Line2D.new()
	l.width = larg
	l.default_color = cor
	l.z_index = z
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	l.material = m
	fase.add_child(l)
	return l

## coluna: linha fina piscando onde vai sair, depois um feixe vertical grosso
func _coluna(x: float) -> void:
	x = clampf(x, x0 + 300.0, x0 + ALTURAS.size() * (LARG + VAO) - 300.0)
	var aviso := _linha(26.0, Color(1, 0.15, 0.15, 0.8), 8)
	aviso.points = PackedVector2Array([Vector2(x, chao - 4500.0), Vector2(x, chao + 2000.0)])
	var feixe := _linha(260.0, Color(1, 0.1, 0.1, 0.0), 9)
	feixe.points = aviso.points
	var miolo := _linha(70.0, Color(1, 0.85, 0.85, 0.0), 10)
	miolo.points = aviso.points
	lasers.append({"tipo": "coluna", "x": x, "t": 0.0, "nos": [aviso, feixe, miolo]})
	Audio.tocar("turbo", 0.4, 0.0)

## cortina: feixe deitado que desce a arena inteira, com um vão verde em cima de um piso
func _cortina() -> void:
	var ok := pisos.filter(func(p): return p["estado"] == "ok")
	if ok.is_empty():
		return
	var p: Dictionary = ok[randi() % ok.size()]
	var gx: float = (p["base"] as Vector2).x
	var nos: Array = []
	for k in 4:
		nos.append(_linha(70.0 if k < 2 else 20.0, Color(1, 0.12, 0.12, 0.9) if k < 2 else Color(1, 0.9, 0.9, 1.0), 9))
	var marca := _linha(LARG * 0.8, Color(0.3, 1.0, 0.4, 0.0), 3)    # vão (seguro) marcado de verde
	marca.points = PackedVector2Array([Vector2(gx, chao - 2600.0), Vector2(gx, chao + 100.0)])
	nos.append(marca)
	lasers.append({"tipo": "cortina", "gx": gx, "meio": LARG * 0.42, "t": 0.0, "y": chao - 4200.0, "nos": nos})
	Audio.tocar("turbo", 0.6, 0.0)

func _passo_laser(l: Dictionary, dt: float) -> void:
	l["t"] += dt
	var t: float = l["t"]
	var nos: Array = l["nos"]
	if l["tipo"] == "coluna":
		var aviso: Line2D = nos[0]
		if t < 1.2:
			aviso.visible = fmod(t, 0.14) < 0.09
			return
		aviso.visible = false
		var f := minf(1.0, (t - 1.2) / 0.06) * minf(1.0, (1.7 - t) / 0.15)
		(nos[1] as Line2D).default_color.a = 0.8 * f
		(nos[2] as Line2D).default_color.a = 1.0 * f
		if f > 0.5:
			_acerta_coluna(float(l["x"]))
		if t >= 1.7:
			for n in nos:
				(n as Node).queue_free()
			lasers.erase(l)
		return
	# cortina
	var marca: Line2D = nos[4]
	var gx: float = l["gx"]
	var meio: float = l["meio"]
	if t < 1.3:                                          # aviso: vão verde piscando
		marca.default_color.a = 0.35 if fmod(t, 0.2) < 0.12 else 0.12
		return
	marca.default_color.a = 0.2
	l["y"] = float(l["y"]) + 2400.0 * dt
	var y: float = l["y"]
	var esq := x0 - 300.0
	var dir := x0 + ALTURAS.size() * (LARG + VAO) + 300.0
	for k in 2:
		(nos[k * 2] as Line2D).points = PackedVector2Array([Vector2(esq, y), Vector2(gx - meio, y)]) if k == 0 else PackedVector2Array([Vector2(gx + meio, y), Vector2(dir, y)])
		(nos[k * 2 + 1] as Line2D).points = (nos[k * 2] as Line2D).points
	(nos[1] as Line2D).points = (nos[0] as Line2D).points
	(nos[3] as Line2D).points = (nos[2] as Line2D).points
	_acerta_cortina(y, gx, meio)
	if y > chao + 1800.0:
		for n in nos:
			(n as Node).queue_free()
		lasers.erase(l)

func _morre(b: Node2D) -> void:
	var pl: Player = fase.player
	if morto or not fase.ativo or (pl.imortal_t > 0.0 and pl.montado):
		return
	if pl.repelir(b.global_position):
		return
	fase._on_perigo(b, "laser")

func _acerta_coluna(x: float) -> void:
	for b in _corpos():
		if absf((b as Node2D).global_position.x - x) < 170.0:
			_morre(b)
			return

func _acerta_cortina(y: float, gx: float, meio: float) -> void:
	for b in _corpos():
		var p: Vector2 = (b as Node2D).global_position
		if absf(p.y - y) < 80.0 and absf(p.x - gx) > meio:
			_morre(b)
			return

# ---------- botão ----------
func _passo_botao(dt: float) -> void:
	if morto:
		if not botao.is_empty():
			(botao["no"] as Node).queue_free()
			botao = {}
		return
	if botao.is_empty():
		_prox_botao -= dt
		if _prox_botao <= 0.0:
			_criar_botao()
		return
	var piso: Dictionary = botao["piso"]
	if piso["estado"] != "ok":                           # o piso vai cair: botão muda de lugar
		(botao["no"] as Node).queue_free()
		botao = {}
		_prox_botao = 0.4
		return
	var no: Node2D = botao["no"]
	var seta: Node2D = botao["seta"]
	seta.position.y = -700.0 + absf(sin(_t * 6.0)) * 120.0
	for b in _corpos():
		var p: Vector2 = (b as Node2D).global_position
		var c := no.global_position
		if absf(p.x - c.x) < 330.0 and p.y > c.y - 1300.0 and p.y < c.y + 200.0:
			_apertar()
			return

func _criar_botao() -> void:
	var ok := pisos.filter(func(p): return p["estado"] == "ok")
	if ok.is_empty():
		_prox_botao = 0.5
		return
	var ax := _alvo_x()
	ok.sort_custom(func(a, b): return absf((a["base"] as Vector2).x - ax) > absf((b["base"] as Vector2).x - ax))
	var piso: Dictionary = ok[randi() % maxi(1, ok.size() / 2)]   # longe de você: tem que ir buscar
	var no := Node2D.new()
	no.position = Vector2(randf_range(-LARG * 0.3, LARG * 0.3), -ESP / 2.0)
	no.z_index = 6
	(piso["no"] as Node2D).add_child(no)
	var P: Pecas = fase.pecas
	P.poligono(Pecas.retangulo(Vector2(0, -20), Vector2(420, 40)), Color(0.25, 0.25, 0.28), 0, null, 1.0, no)
	P.poligono(Pecas.retangulo(Vector2(0, -70), Vector2(300, 70)), Color(0.2, 1.0, 0.35), 0, null, 1.0, no)
	var g := Gradient.new()
	g.set_color(0, Color(0.2, 1.0, 0.35, 0.0))
	g.set_color(1, Color(0.3, 1.0, 0.45, 0.5))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	var coluna := TextureRect.new()
	coluna.texture = gt
	coluna.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coluna.stretch_mode = TextureRect.STRETCH_SCALE
	coluna.size = Vector2(460, 3000)
	coluna.position = Vector2(-230, -3000)
	no.add_child(coluna)
	var seta := Node2D.new()
	no.add_child(seta)
	var tri := Polygon2D.new()
	tri.polygon = PackedVector2Array([Vector2(-170, -150), Vector2(170, -150), Vector2(0, 60)])
	tri.color = Color(0.25, 1.0, 0.4)
	seta.add_child(tri)
	botao = {"no": no, "piso": piso, "seta": seta}
	Audio.tocar("checkpoint", 0.8)

func _apertar() -> void:
	var no: Node2D = botao["no"]
	var de := no.get_global_transform_with_canvas().origin
	(botao["no"] as Node).queue_free()
	botao = {}
	_prox_botao = 4.0
	levar_choque(de)

## choque: raio do botão até a cabeça dele (na tela), pisca, treme e machuca
func levar_choque(de_tela := Vector2(-1, -1)) -> void:
	if morto:
		return
	vida -= 1
	_tremor = 1.0
	Audio.tocar("metal", 1.0)
	Audio.tocar("impacto_forte", 1.0)
	var v := fase.get_viewport().get_visible_rect().size
	var cabeca := _boss.position + Vector2(0, -150) * _boss.scale.x
	if de_tela.x < 0.0:
		de_tela = Vector2(v.x / 2.0, v.y * 0.8)
	for camada in 2:
		var l := Line2D.new()
		var pts := PackedVector2Array([de_tela])
		for i in range(1, 12):
			pts.append(de_tela.lerp(cabeca, i / 12.0) + Vector2(randf_range(-40, 40), randf_range(-25, 25)))
		pts.append(cabeca)
		l.points = pts
		l.width = 26.0 if camada == 0 else 9.0
		l.default_color = Color(0.4, 0.8, 1.0, 0.7) if camada == 0 else Color.WHITE
		_camada_boss.add_child(l)
		var tw := l.create_tween()
		tw.tween_property(l, "modulate:a", 0.0, 0.5)
		tw.tween_callback(l.queue_free)
	_boss.modulate = Color(1, 0.4, 0.4)
	var tw2 := _boss.create_tween()
	tw2.tween_property(_boss, "modulate", Color.WHITE, 0.5)
	_trocar_estagio()
	if vida <= 0:
		morto = true
		_rotulo.text = "ADRIANO DERROTADO!"
		_rotulo.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
		for l in lasers:
			for n in l["nos"]:
				(n as Node).queue_free()
		lasers.clear()
		for p in pisos:
			if p["estado"] == "aviso":
				p["estado"] = "ok"

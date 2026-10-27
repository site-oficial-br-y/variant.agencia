extends Node2D
class_name Julgamento
## Fase 9 (O Julgamento), parte normal: fundo de olhos no espaço, corpos vagando no
## fundo, cristais cósmicos caindo do céu (marca vermelha no chão antes) e portões de
## laser roxo que ligam e desligam no caminho.

const CORPOS := ["corpo1", "corpo2", "corpo3", "corpo4", "corpo5"]
const ROXO := Color(0.72, 0.3, 1.0)

var fase: Node2D
var chao := 1000.0
var _t := 0.0
var _prox := 2.0
var _fundo: TextureRect
var _vagando: Array = []                 # corpos no fundo: {no, v, giro}
var _queda: Array = []                    # cristais caindo
var _portoes: Array = []                  # lasers roxos: {x, y, T, fase, nos}
var _tex_feixe: Texture2D
var _tex_brilho: Texture2D

func _real(delta: float) -> float:
	return delta / Engine.time_scale

func montar(main: Node2D, y_chao: float) -> void:
	fase = main
	chao = y_chao
	var camada := CanvasLayer.new()
	camada.layer = -70
	fase.add_child(camada)
	_fundo = TextureRect.new()
	_fundo.texture = load("res://assets/julgamento/fundo_fase.jpg")
	_fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fundo.stretch_mode = TextureRect.STRETCH_SCALE
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(_fundo)
	var corpos := CanvasLayer.new()
	corpos.layer = -65
	fase.add_child(corpos)
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for k in (3 if Game.leve else 7):
		var s := Sprite2D.new()
		s.texture = load("res://assets/julgamento/%s.png" % CORPOS[k % CORPOS.size()])
		var perto := r.randf_range(0.0, 1.0)
		s.modulate = Color(1.0, 0.85, 1.25, lerpf(0.45, 0.85, perto))
		var brilho := CanvasItemMaterial.new()          # luz própria: corpo escuro some no fundo, contorno brilha
		brilho.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = brilho
		s.set_meta("tam", lerpf(0.18, 0.4, perto))
		s.set_meta("fx", r.randf_range(0.0, 1.0))
		s.set_meta("fy", r.randf_range(0.05, 0.75))
		s.set_meta("par", lerpf(0.03, 0.12, perto))
		s.rotation = r.randf_range(-PI, PI)
		corpos.add_child(s)
		_vagando.append({"no": s, "v": Vector2(r.randf_range(-0.012, 0.012), r.randf_range(-0.006, 0.006)), "giro": r.randf_range(-0.12, 0.12)})

## fundo e corpos (chamado todo quadro)
func atualizar(delta: float, camera: Camera2D) -> void:
	var dt := _real(delta)
	_t += dt
	var v := get_viewport().get_visible_rect().size
	var cx := camera.global_position.x if is_instance_valid(camera) else 0.0
	var esc := maxf(v.x / 1916.0, v.y / 821.0) * 1.15
	_fundo.size = Vector2(1916, 821) * esc
	_fundo.position = Vector2(-fposmod(cx * 0.004, _fundo.size.x - v.x), (v.y - _fundo.size.y) / 2.0 + sin(_t * 0.3) * 8.0)
	_fundo.modulate = Color(1, 1, 1, 1).lerp(Color(0.85, 0.75, 1.0), 0.5 + 0.5 * sin(_t * 0.7))
	for c in _vagando:
		var s: Sprite2D = c["no"]
		s.set_meta("fx", fposmod(float(s.get_meta("fx")) + (c["v"] as Vector2).x * dt, 1.3))
		s.set_meta("fy", clampf(float(s.get_meta("fy")) + (c["v"] as Vector2).y * dt, 0.0, 0.8))
		if float(s.get_meta("fy")) <= 0.0 or float(s.get_meta("fy")) >= 0.8:
			c["v"] = Vector2((c["v"] as Vector2).x, -(c["v"] as Vector2).y)
		s.rotation += float(c["giro"]) * dt
		s.position = Vector2(fposmod(float(s.get_meta("fx")) * v.x * 1.3 - cx * float(s.get_meta("par")) * 0.02, v.x * 1.3) - v.x * 0.15,
			float(s.get_meta("fy")) * v.y + sin(_t * 0.5 + float(s.get_meta("fx")) * 9.0) * 14.0)
		s.scale = Vector2.ONE * float(s.get_meta("tam")) * v.y / 500.0
	for p in _portoes:
		_passo_portao(p)

# ---------- cristais caindo ----------
func chuva(delta: float, intervalo: float) -> void:
	var dt := _real(delta)
	for q in _queda.duplicate():
		_passo_cristal(q, dt)
	if intervalo <= 0.0 or not fase.ativo:
		return
	_prox -= dt
	if _prox <= 0.0:
		_prox = intervalo * randf_range(0.8, 1.2)
		_soltar()

func _soltar() -> void:
	var pl: Player = fase.player
	if not is_instance_valid(pl) or not is_instance_valid(pl.chassi):
		return
	var vx: float = pl.chassi.linear_velocity.x if pl.montado else 0.0
	var frente := pl.chassi.global_position.x
	for b in pl.rodas:
		if is_instance_valid(b):
			frente = maxf(frente, (b as Node2D).global_position.x)
	var alvo := frente + vx * Engine.time_scale * 0.45 + randf_range(600, 1700)
	for p in _portoes:                                 # não cai em cima de quem está esperando o laser
		if absf(float(p["x"]) - alvo) < 1100.0:
			return
	var r := fase.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(alvo, chao - 3000.0), Vector2(alvo, chao + 3000.0), 0b0001))
	if r.is_empty():
		return
	var solo := (r["position"] as Vector2).y
	var tam := randf_range(380.0, 560.0)
	var no := Sprite2D.new()
	no.texture = load("res://assets/julgamento/cristal.png")
	no.scale = Vector2.ONE * tam / 700.0
	no.position = Vector2(alvo, solo - 4500.0)
	no.rotation = randf_range(-PI, PI)
	no.z_index = 6
	var brilho := _bola(Vector2.ZERO, 9.0, ROXO)
	brilho.reparent(no, false)
	brilho.z_index = -1
	fase.add_child(no)
	var marca := Geresch.marcador(tam * 0.45)
	marca.position = Vector2(alvo, solo)
	fase.add_child(marca)
	_queda.append({"no": no, "marca": marca, "t": 0.0, "vy": 0.0, "w": tam * 0.45, "x": alvo, "solo": solo, "giro": randf_range(-3, 3)})

func _passo_cristal(q: Dictionary, dt: float) -> void:
	q["t"] = float(q["t"]) + dt
	var no: Sprite2D = q["no"]
	var marca: Node2D = q["marca"]
	if float(q["t"]) < 0.8:
		marca.modulate.a = 1.0 if fmod(float(q["t"]), 0.16) < 0.1 else 0.7
		return
	marca.modulate.a = 1.0
	q["vy"] = float(q["vy"]) + 9000.0 * dt
	no.position.y += float(q["vy"]) * dt
	no.rotation += float(q["giro"]) * dt
	_acerta(no.position, float(q["w"]))
	if no.position.y >= float(q["solo"]) - 60.0:
		impacto(Vector2(no.position.x, float(q["solo"])), float(q["w"]) / 200.0)
		no.queue_free()
		marca.queue_free()
		_queda.erase(q)

func _acerta(onde: Vector2, raio: float) -> void:
	for b in _corpos():
		if (b as Node2D).global_position.distance_to(onde) < raio:
			_morre(b, "esmagado")
			return

## cristal batendo no chão: estilhaços roxos, clarão, tela treme
func impacto(onde: Vector2, forca: float) -> void:
	var f := clampf(forca, 0.6, 3.0)
	fase.pecas.particulas(onde + Vector2(0, -40), int(26 * f), Color(0.85, 0.5, 1.0), Color(0.4, 0.1, 0.8, 0.0), 700.0, 2200.0, 0.9, 30.0, 70.0, 2600.0, Vector2.UP, 70.0)
	fase.pecas.particulas(onde + Vector2(0, -60), int(12 * f), Color(1, 1, 1, 0.9), Color(0.7, 0.4, 1.0, 0.0), 200.0, 700.0, 0.5, 90.0, 180.0, 0.0)
	var luz := _bola(onde + Vector2(0, -80), 14.0 * f, ROXO)
	var tw := luz.create_tween()
	tw.tween_property(luz, "modulate:a", 0.0, 0.45 * Engine.time_scale)
	tw.tween_callback(luz.queue_free)
	tremer(onde, f)
	Audio.tocar("impacto_forte", clampf(0.5 + 0.2 * f, 0.0, 1.0), 0.1)
	Audio.tocar("metal", 0.5)

func tremer(onde: Vector2, f: float) -> void:
	var cam: Camera2D = fase.camera
	var perto := 1.0
	var pl: Player = fase.player
	if is_instance_valid(pl) and is_instance_valid(pl.chassi) and not fase.has_meta("cam_base"):
		perto = clampf(1.0 - absf(pl.chassi.global_position.x - onde.x) / 6000.0, 0.15, 1.0)
	var base: Vector2 = fase.get_meta("cam_base", Vector2(800, -150))
	var tw := cam.create_tween()
	for k in 6:
		tw.tween_property(cam, "offset", base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 80.0 * f * perto * (1.0 - k / 6.0), 0.035 * Engine.time_scale)
	tw.tween_property(cam, "offset", base, 0.035 * Engine.time_scale)

# ---------- portões de laser roxo ----------
## laser vertical do céu até o chão: liga e desliga (pisca antes de ligar)
func portao(x: float, y: float, periodo := 3.2, atraso := 0.0) -> void:
	var aviso := _linha(12.0, Color(0.8, 0.4, 1.0, 0.8), 8)
	aviso.points = PackedVector2Array([Vector2(x, y - 3800.0), Vector2(x, y)])
	var feixe := _feixe(150.0, 9)
	feixe.points = aviso.points
	(feixe.get_meta("halo") as Line2D).points = aviso.points
	feixe.modulate.a = 0.0
	var base := Node2D.new()                           # bocal no chão e no alto: dá pra ver onde fica
	base.position = Vector2(x, y)
	base.z_index = 5
	fase.add_child(base)
	fase.pecas.poligono(Pecas.retangulo(Vector2(0, -30), Vector2(220, 60)), Color(0.18, 0.1, 0.28), 0, null, 1.0, base)
	fase.pecas.poligono(Pecas.retangulo(Vector2(0, -64), Vector2(120, 16)), ROXO, 0, null, 1.0, base)
	var ponta := _bola(Vector2(x, y - 70.0), 4.0, ROXO)
	_portoes.append({"x": x, "y": y, "T": periodo, "fase": atraso, "aviso": aviso, "feixe": feixe, "ponta": ponta})

func _passo_portao(p: Dictionary) -> void:
	var f := fposmod(_t + float(p["fase"]), float(p["T"])) / float(p["T"])
	var aviso: Line2D = p["aviso"]
	var feixe: Line2D = p["feixe"]
	var ponta: Sprite2D = p["ponta"]
	# 0-0.45 desligado | 0.45-0.62 avisa piscando | 0.62-1.0 ligado (mata)
	if f < 0.45:
		aviso.visible = false
		feixe.modulate.a = 0.0
		(feixe.get_meta("halo") as CanvasItem).modulate.a = 0.0
		ponta.modulate.a = 0.25
	elif f < 0.62:
		aviso.visible = fmod(f * 60.0, 1.0) < 0.55
		feixe.modulate.a = 0.0
		(feixe.get_meta("halo") as CanvasItem).modulate.a = 0.0
		ponta.modulate.a = 0.7
	else:
		aviso.visible = false
		var a := minf(1.0, (f - 0.62) / 0.03) * minf(1.0, (1.0 - f) / 0.03)
		feixe.modulate.a = a
		(feixe.get_meta("halo") as CanvasItem).modulate.a = a * (0.85 + 0.15 * sin(_t * 60.0))
		feixe.width = 150.0 * (0.9 + 0.1 * sin(_t * 70.0))
		ponta.modulate.a = 1.0
		if a > 0.5:
			for b in _corpos():
				var pos := (b as Node2D).global_position
				if absf(pos.x - float(p["x"])) < 110.0 and pos.y < float(p["y"]) + 50.0:
					_morre(b, "laser")
					return

# ---------- comum ----------
func _corpos() -> Array:
	var pl: Player = fase.player
	if not is_instance_valid(pl):
		return []
	if pl.montado and is_instance_valid(pl.chassi):
		return [pl.chassi] + pl.rodas + pl.membros.values()
	return pl.corpos.values()

func _morre(b: Node2D, motivo: String) -> void:
	var pl: Player = fase.player
	if not fase.ativo or (pl.imortal_t > 0.0 and pl.montado):
		return
	if pl.repelir(b.global_position):
		return
	fase._on_perigo(b, motivo)

func _feixe_tex() -> Texture2D:
	if _tex_feixe == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.28, 0.43, 0.5, 0.57, 0.72, 1.0])
		g.colors = PackedColorArray([Color(0.6, 0.1, 1.0, 0.0), Color(0.6, 0.15, 1.0, 0.55), Color(0.85, 0.6, 1.0, 1.0),
			Color(1, 1, 1, 1), Color(0.85, 0.6, 1.0, 1.0), Color(0.6, 0.15, 1.0, 0.55), Color(0.6, 0.1, 1.0, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_to = Vector2(0, 1)
		t.width = 4
		t.height = 128
		_tex_feixe = t
	return _tex_feixe

func _feixe(larg: float, z: int) -> Line2D:
	var halo := _linha(larg * 2.6, Color(0.6, 0.2, 1.0, 0.25), z)
	halo.texture = _feixe_tex()
	halo.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	var l := _linha(larg, Color.WHITE, z)
	l.texture = _feixe_tex()
	l.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	l.set_meta("halo", halo)
	return l

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

func _bola(pos: Vector2, tam: float, cor: Color) -> Sprite2D:
	if _tex_brilho == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.25, Color(cor, 0.85))
		g.set_color(g.get_point_count() - 1, Color(cor, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_tex_brilho = t
	var s := Sprite2D.new()
	s.texture = _tex_brilho
	s.scale = Vector2.ONE * tam
	s.z_index = 10
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.position = pos
	fase.add_child(s)
	return s

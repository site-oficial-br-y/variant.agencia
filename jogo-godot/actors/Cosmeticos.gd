extends Node2D
class_name Cosmeticos
## Itens de efeito do passe aplicados no boneco: rastro, aura, roda, chapéu e efeito de morte.
## Fica na fase (filho do Main) e segue o jogador; o nick colorido é feito pelo Main no HUD.
## Texturas das partículas são desenhadas aqui mesmo (com contorno e brilho), sem arte externa.

var pl: Player
var pecas: Pecas
var _t := 0.0
# rastro
var _fita: Array = []                    # Line2D da faixa (arco-íris tem várias)
var _fita_pts: Array = []
var _fita_id := ""
var _part: CPUParticles2D
# aura
var _aura_nos: Array = []
var _aura_id := ""
# rodas
var _rodas_fx: Array = []
# chapéu
var _chapeu: Node2D

static var _tex_cache: Dictionary = {}

static func aplicar(fase: Node2D, jogador: Player) -> Cosmeticos:
	var c := Cosmeticos.new()
	c.pl = jogador
	c.pecas = fase.get("pecas")
	fase.add_child(c)
	return c

func _ready() -> void:
	_montar_rastro(Passe.equipado("rastro"))
	_montar_aura.call_deferred(Passe.equipado("aura"))
	_montar_rodas.call_deferred(Passe.equipado("roda"))
	_montar_chapeu.call_deferred(Passe.equipado("chapeu"))

# ---------- texturas ----------
## forma desenhada com supersample (borda lisa), contorno escuro e brilho
static func tex(forma: String) -> Texture2D:
	if _tex_cache.has(forma):
		return _tex_cache[forma]
	var n := 64
	var ss := 3
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var acc := Color(0, 0, 0, 0)
			for sy in ss:
				for sx in ss:
					var u := ((x + (sx + 0.5) / ss) / n) * 2.0 - 1.0
					var v := ((y + (sy + 0.5) / ss) / n) * 2.0 - 1.0
					acc += _pixel(forma, u, v)
			img.set_pixel(x, y, acc / float(ss * ss))
	var t := ImageTexture.create_from_image(img)
	_tex_cache[forma] = t
	return t

## < 0 dentro, > 0 fora (aproximado), em unidades da imagem (-1..1)
static func _dist_forma(forma: String, u: float, v: float) -> float:
	match forma:
		"coracao":
			var x := u * 1.15
			var y := -v * 1.15 + 0.3
			return pow(x * x + y * y - 0.55, 3.0) - x * x * y * y * y
		"estrela":
			var a := atan2(v, u) + PI / 2.0
			var r := sqrt(u * u + v * v)
			var k := fposmod(a, TAU / 5.0) / (TAU / 5.0)
			return r - lerpf(0.4, 0.9, absf(k - 0.5) * 2.0)
		"nota":
			return maxf(absf(u) - 0.85, absf(v) - 0.5)
		"moeda":
			return sqrt(u * u + v * v) - 0.82
		"confete":
			return maxf(absf(u) - 0.8, absf(v) - 0.35)
		"chama":
			var y := v + 0.1
			if y >= 0.75:
				return 1.0
			var larg := 0.55 * sqrt(clampf((y + 0.9) / 1.6, 0.0, 1.0)) * (1.0 - smoothstep(0.35, 0.75, y))
			return absf(u) - larg
		"floco":
			var a := atan2(v, u)
			var r := sqrt(u * u + v * v)
			if r >= 0.9:
				return 1.0
			return minf(r - 0.22, absf(sin(a * 3.0)) * r - 0.08)
		"faisca":
			return minf(absf(u) * 4.0 + absf(v) - 0.9, absf(v) * 4.0 + absf(u) - 0.9) * 0.3
	return sqrt(u * u + v * v) - 0.9

static func _pixel(forma: String, u: float, v: float) -> Color:
	var r := sqrt(u * u + v * v)
	if forma == "bolha":                                  # mancha macia
		return Color(1, 1, 1, pow(clampf(1.0 - r, 0.0, 1.0), 1.6))
	if forma == "brilho":                                 # ponto de luz com miolo forte
		return Color(1, 1, 1, minf(1.0, pow(clampf(1.0 - r, 0.0, 1.0), 3.0) + (0.6 if r < 0.12 else 0.0)))
	var d := _dist_forma(forma, u, v)
	if d > 0.0:
		return Color(0, 0, 0, 0)
	if d > -0.07 and forma != "faisca" and forma != "chama" and forma != "floco":
		return Color(0.12, 0.08, 0.1, 1.0)                # contorno
	var luz := clampf(0.75 - v * 0.35 - u * 0.15, 0.0, 1.0)   # luz de cima/esquerda
	var c := Color(luz + 0.25, luz + 0.25, luz + 0.25, 1.0)
	if forma == "moeda" and r < 0.58 and r > 0.48:
		c = c.darkened(0.3)
	if forma == "nota" and absf(u) < 0.22 and absf(v) < 0.3:
		c = c.darkened(0.35)                              # "$" do meio
	if (u + 0.35) * (u + 0.35) + (v + 0.35) * (v + 0.35) < 0.04:
		c = Color(1, 1, 1, 1)                             # reflexo
	return c

static func _rampa(cores: Array, offs: Array = []) -> Gradient:
	var g := Gradient.new()
	var o := offs.duplicate()
	if o.is_empty():
		for i in cores.size():
			o.append(float(i) / (cores.size() - 1))
	g.offsets = PackedFloat32Array(o)
	g.colors = PackedColorArray(cores)
	return g

static func _add() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _particulas(textura: Texture2D, qtd: int, vida: float, rampa: Gradient, tam: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.local_coords = false
	p.texture = textura
	p.amount = maxi(4, qtd / 3) if Game.leve else qtd
	p.lifetime = vida
	p.speed_scale = 1.0 / Engine.time_scale
	p.color_ramp = rampa
	p.scale_amount_min = tam.x
	p.scale_amount_max = tam.y
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.3))
	curva.add_point(Vector2(0.15, 1.0))
	curva.add_point(Vector2(1, 0.6))
	p.scale_amount_curve = curva
	p.emitting = false
	return p

# ---------- rastro ----------
func _montar_rastro(id: String) -> void:
	_fita_id = id
	if id == "":
		return
	var faixas: Array = []                               # [largura, gradiente, aditivo]
	match id:
		"rastro_fumaca":
			faixas = [[260.0, _rampa([Color(0.6, 0.6, 0.65, 0.0), Color(0.75, 0.75, 0.8, 0.35), Color(0.9, 0.9, 0.92, 0.55)]), false]]
			_part = _particulas(tex("bolha"), 40, 1.6, _rampa([Color(0.85, 0.85, 0.88, 0.5), Color(0.55, 0.55, 0.6, 0.0)]), Vector2(4.0, 8.0))
			_part.gravity = Vector2(0, -150)
			_part.initial_velocity_max = 80.0
		"rastro_fogo":
			faixas = [[300.0, _rampa([Color(0.4, 0.0, 0.0, 0.0), Color(1.0, 0.25, 0.0, 0.55), Color(1.0, 0.7, 0.1, 0.9), Color(1, 1, 0.7, 1)], [0.0, 0.45, 0.8, 1.0]), true],
				[110.0, _rampa([Color(1, 0.6, 0.1, 0.0), Color(1, 1, 0.85, 1)]), true]]
			_part = _particulas(tex("chama"), 70, 0.7, _rampa([Color(1, 1, 0.7, 1), Color(1, 0.55, 0.05, 0.9), Color(0.6, 0.05, 0.0, 0.0)]), Vector2(2.5, 4.5))
			_part.gravity = Vector2(0, -900)
			_part.initial_velocity_min = 60.0
			_part.initial_velocity_max = 220.0
			_part.material = _add()
		"rastro_arco":
			var cores := [Color(1, 0.2, 0.25), Color(1, 0.6, 0.1), Color(1, 0.95, 0.2), Color(0.3, 0.95, 0.35), Color(0.25, 0.6, 1.0), Color(0.6, 0.3, 1.0)]
			for c in cores:
				faixas.append([48.0, _rampa([Color(c, 0.0), Color(c, 0.95)]), false])
			_part = _particulas(tex("faisca"), 30, 0.8, _rampa([Color(1, 1, 1, 1), Color(1, 1, 1, 0)]), Vector2(1.5, 3.0))
			_part.hue_variation_min = -1.0
			_part.hue_variation_max = 1.0
			_part.color = Color(1, 0.6, 0.9)
			_part.material = _add()
		"rastro_raio":
			faixas = [[150.0, _rampa([Color(0.2, 0.5, 1.0, 0.0), Color(0.4, 0.8, 1.0, 0.45)]), true],
				[34.0, _rampa([Color(0.7, 0.9, 1.0, 0.0), Color(1, 1, 1, 1)]), true]]
			_part = _particulas(tex("brilho"), 30, 0.35, _rampa([Color(0.85, 0.95, 1, 1), Color(0.3, 0.6, 1, 0)]), Vector2(1.5, 3.0))
			_part.initial_velocity_min = 300.0
			_part.initial_velocity_max = 900.0
			_part.spread = 180.0
			_part.material = _add()
		"rastro_coracao":
			faixas = [[160.0, _rampa([Color(1, 0.3, 0.55, 0.0), Color(1, 0.45, 0.65, 0.4)]), true]]
			_part = _particulas(tex("coracao"), 26, 1.6, _rampa([Color(1, 0.35, 0.55, 1), Color(1, 0.5, 0.7, 1), Color(1, 0.6, 0.8, 0)], [0.0, 0.7, 1.0]), Vector2(2.2, 3.6))
			_part.gravity = Vector2(0, -260)
			_part.angle_min = -20.0
			_part.angle_max = 20.0
		"rastro_dinheiro":
			_part = _particulas(tex("nota"), 30, 1.8, _rampa([Color(0.55, 0.95, 0.5, 1), Color(0.35, 0.8, 0.35, 1), Color(0.3, 0.7, 0.3, 0)], [0.0, 0.75, 1.0]), Vector2(2.8, 3.8))
			_part.gravity = Vector2(0, 500)
			_part.initial_velocity_min = 200.0
			_part.initial_velocity_max = 600.0
			_part.angle_min = -180.0
			_part.angle_max = 180.0
			_part.angular_velocity_min = -360.0
			_part.angular_velocity_max = 360.0
			_part.damping_min = 100.0
			_part.damping_max = 200.0
		"rastro_estrela":
			faixas = [[90.0, _rampa([Color(1, 0.85, 0.3, 0.0), Color(1, 0.95, 0.6, 0.6)]), true]]
			_part = _particulas(tex("estrela"), 34, 1.2, _rampa([Color(1, 1, 0.7, 1), Color(1, 0.85, 0.25, 1), Color(1, 0.7, 0.1, 0)], [0.0, 0.6, 1.0]), Vector2(2.0, 3.8))
			_part.angular_velocity_min = -280.0
			_part.angular_velocity_max = 280.0
			_part.gravity = Vector2(0, 150)
	if _part:
		_part.direction = Vector2.LEFT
		_part.spread = maxf(_part.spread, 35.0)
		if _part.initial_velocity_max <= 0.0:
			_part.initial_velocity_min = 60.0
			_part.initial_velocity_max = 260.0
		_part.z_index = 1
		add_child(_part)
	for f in faixas:
		var l := Line2D.new()
		l.width = f[0]
		l.gradient = f[1]
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND
		var curva := Curve.new()                       # fina no fim, grossa perto do boneco
		curva.add_point(Vector2(0, 0.05))
		curva.add_point(Vector2(1, 1))
		l.width_curve = curva
		if f[2]:
			l.material = _add()
		l.z_index = 1
		add_child(l)
		_fita.append(l)

func _passo_rastro(pos: Vector2, rapido: bool, rot: float) -> void:
	var ponta := pos + Vector2(-60, -330).rotated(rot)
	if _part:
		_part.global_position = ponta
		_part.emitting = rapido
	if _fita.is_empty():
		return
	if rapido:
		_fita_pts.append(ponta)
	elif not _fita_pts.is_empty():
		_fita_pts.pop_front()
	var maximo := 26 if _fita_id != "rastro_raio" else 16
	while _fita_pts.size() > maximo:
		_fita_pts.pop_front()
	for i in _fita.size():
		var l: Line2D = _fita[i]
		var pts := PackedVector2Array()
		var desl := 0.0
		if _fita_id == "rastro_arco":                    # faixas paralelas, de cima pra baixo
			desl = (i - (_fita.size() - 1) / 2.0) * 44.0
		var n := _fita_pts.size()
		for k in n:
			var p: Vector2 = _fita_pts[k]
			var onda := Vector2.ZERO
			if _fita_id == "rastro_raio":
				onda = Vector2(0, randf_range(-70, 70) * (1.0 - float(k) / n))
			elif _fita_id == "rastro_fogo":
				onda = Vector2(0, sin(_t * 18.0 + k * 0.8) * 22.0 * (1.0 - float(k) / n))
			elif _fita_id == "rastro_arco":
				onda = Vector2(0, sin(_t * 6.0 + k * 0.5) * 10.0)
			pts.append(p + Vector2(0, desl) + onda)
		l.points = pts
	if _fita_id == "rastro_raio" and rapido and randf() < 0.25 and _fita_pts.size() > 4:   # galho do raio
		var de: Vector2 = _fita_pts[randi_range(2, _fita_pts.size() - 1)]
		var g := Line2D.new()
		var pts2 := PackedVector2Array([de])
		var dirg := Vector2.from_angle(randf_range(0, TAU))
		for k in 4:
			pts2.append(pts2[pts2.size() - 1] + dirg.rotated(randf_range(-0.6, 0.6)) * 90.0)
		g.points = pts2
		g.width = 14.0
		g.default_color = Color(0.75, 0.9, 1.0, 0.9)
		g.material = _add()
		g.z_index = 1
		add_child(g)
		var tw := g.create_tween()
		tw.tween_property(g, "modulate:a", 0.0, 0.15 * Engine.time_scale)
		tw.tween_callback(g.queue_free)

# ---------- aura ----------
func _montar_aura(id: String) -> void:
	_aura_id = id
	if id == "" or not is_instance_valid(pl) or not is_instance_valid(pl.chassi):
		return
	var centro := Vector2(0, -380)
	var cor := Color(1, 0.8, 0.3)
	match id:
		"aura_dourada": cor = Color(1, 0.78, 0.25)
		"aura_roxa": cor = Color(0.7, 0.3, 1.0)
		"aura_gelo": cor = Color(0.55, 0.9, 1.0)
		"aura_semaj": cor = Color(0.5, 0.1, 0.8)
		"aura_arco": cor = Color(1, 0.4, 0.9)
	var brilho := Sprite2D.new()                       # brilho macio atrás do corpo
	brilho.texture = tex("bolha")
	brilho.scale = Vector2(16.0, 22.0)
	brilho.position = centro
	brilho.modulate = Color(cor, 0.55)
	brilho.material = _add()
	brilho.z_index = -2
	pl.chassi.add_child(brilho)
	_aura_nos.append(brilho)
	var anel := Line2D.new()                           # anel de energia girando
	var pts := PackedVector2Array()
	for k in 41:
		pts.append(Vector2(520, 0).rotated(TAU * k / 40.0) * Vector2(1.0, 1.35))
	anel.points = pts
	anel.width = 18.0
	anel.gradient = _rampa([Color(cor, 0.0), Color(cor.lightened(0.4), 0.9), Color(cor, 0.0), Color(cor.lightened(0.4), 0.9), Color(cor, 0.0)])
	anel.material = _add()
	anel.position = centro
	anel.z_index = -1
	pl.chassi.add_child(anel)
	_aura_nos.append(anel)
	var forma := "chama" if id in ["aura_roxa", "aura_semaj"] else ("floco" if id == "aura_gelo" else "faisca")
	var p := _particulas(tex(forma), 46, 1.1, _rampa([Color(cor.lightened(0.5), 1.0), Color(cor, 0.8), Color(cor.darkened(0.3), 0.0)]), Vector2(2.0, 4.0))
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(360, 520)
	p.direction = Vector2.UP
	p.spread = 15.0
	p.gravity = Vector2(0, -500 if forma == "chama" else -120)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 260.0
	if forma != "chama":
		p.angular_velocity_min = -200.0
		p.angular_velocity_max = 200.0
	if id == "aura_arco":
		p.hue_variation_min = -1.0
		p.hue_variation_max = 1.0
	if id != "aura_semaj":
		p.material = _add()
	else:
		p.color_ramp = _rampa([Color(0.2, 0.0, 0.3, 0.9), Color(0.5, 0.1, 0.8, 0.6), Color(0.05, 0.0, 0.1, 0.0)])
	p.z_index = -1
	p.emitting = true
	pl.chassi.add_child(p)
	p.position = centro
	_aura_nos.append(p)

# ---------- rodas ----------
func _montar_rodas(id: String) -> void:
	if id == "" or not is_instance_valid(pl):
		return
	var cor: Color = Passe.item(id)[4]
	for rd in pl.rodas:
		var rb := rd as RigidBody2D
		var cs := rb.get_child(0) as CollisionShape2D
		var raio: float = (cs.shape as CircleShape2D).radius if cs and cs.shape is CircleShape2D else 100.0
		if raio < 30.0 or not rb.get_children().any(func(n) -> bool: return n is Sprite2D):
			continue                                    # a pé / avião: a roda é invisível, sem efeito
		var no := Node2D.new()
		no.z_index = 8
		rb.add_child(no)
		var halo := Sprite2D.new()
		halo.texture = tex("bolha")
		halo.scale = Vector2.ONE * raio * 2.6 / 64.0
		halo.modulate = Color(cor, 0.45)
		halo.material = _add()
		no.add_child(halo)
		for camada in 2:                                # anel grosso de luz + filete branco
			var anel := Line2D.new()
			var pts := PackedVector2Array()
			for k in 41:
				pts.append(Vector2(raio + 4.0, 0).rotated(TAU * k / 40.0))
			anel.points = pts
			anel.width = 26.0 if camada == 0 else 8.0
			anel.default_color = cor if camada == 0 else Color(1, 1, 1, 0.9)
			anel.material = _add()
			no.add_child(anel)
		var forma := "chama" if id == "roda_fogo" else ("floco" if id == "roda_gelo" else "faisca")
		var p := _particulas(tex(forma), 40, 0.55, _rampa([Color(cor.lightened(0.5), 1), Color(cor, 0.85), Color(cor.darkened(0.4), 0)]), Vector2(1.4, 2.6))
		var em := PackedVector2Array()
		for k in 20:
			em.append(Vector2(raio, 0).rotated(TAU * k / 20.0))
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
		p.emission_points = em
		p.direction = Vector2.LEFT
		p.spread = 40.0
		p.initial_velocity_min = 150.0
		p.initial_velocity_max = 450.0
		p.gravity = Vector2(0, -600 if forma == "chama" else 300)
		if id == "roda_arco":
			p.hue_variation_min = -1.0
			p.hue_variation_max = 1.0
		p.material = _add()
		p.z_index = 8
		rb.add_child(p)
		_rodas_fx.append({"no": no, "p": p, "rb": rb, "id": id, "halo": halo})

# ---------- chapéu ----------
func _montar_chapeu(id: String) -> void:
	if id == "" or not is_instance_valid(pl) or not pl.sprites.has("cabeca"):
		return
	var cab: Sprite2D = pl.sprites["cabeca"]
	var h := float(cab.texture.get_height())
	var w := float(cab.texture.get_width())
	var c := Node2D.new()
	c.position = Vector2(-w * 0.04, -h * 0.4)
	c.z_index = 3
	c.scale = Vector2.ONE * w / 210.0
	var escuro := Color(0.12, 0.07, 0.05)
	match id:
		"chapeu_coroa":
			_poli(c, PackedVector2Array([Vector2(-90, 4), Vector2(-96, -72), Vector2(-56, -32), Vector2(-28, -104),
				Vector2(0, -40), Vector2(28, -104), Vector2(56, -32), Vector2(96, -72), Vector2(90, 4)]), Color(0.95, 0.7, 0.12), escuro, 7.0)
			_poli(c, PackedVector2Array([Vector2(-86, 4), Vector2(-88, -20), Vector2(88, -20), Vector2(86, 4)]), Color(0.8, 0.52, 0.08), escuro, 6.0)
			_poli(c, PackedVector2Array([Vector2(-70, -40), Vector2(-56, -32), Vector2(-28, -96), Vector2(-40, -60)]), Color(1, 0.92, 0.55), Color(0, 0, 0, 0), 0.0)
			for k in 3:
				var cj: Color = [Color(0.95, 0.15, 0.25), Color(0.2, 0.55, 1.0), Color(0.2, 0.9, 0.45)][k]
				_poli(c, _circ(Vector2(-55 + k * 55, -8), 13), cj, escuro, 4.0)
				_poli(c, _circ(Vector2(-59 + k * 55, -12), 4), Color(1, 1, 1, 0.9), Color(0, 0, 0, 0), 0.0)
			for p in [Vector2(-96, -72), Vector2(-28, -104), Vector2(28, -104), Vector2(96, -72)]:
				_poli(c, _circ(p, 9), Color(1, 0.95, 0.7), escuro, 3.0)
		"chapeu_aureola":
			for camada in 3:
				var anel := Line2D.new()
				var pts := PackedVector2Array()
				for i in 41:
					pts.append(Vector2(88, 0).rotated(TAU * i / 40.0) * Vector2(1.0, 0.26) + Vector2(0, -105))
				anel.points = pts
				anel.width = [44.0, 18.0, 6.0][camada]
				anel.default_color = [Color(1, 0.85, 0.3, 0.25), Color(1, 0.9, 0.45, 0.85), Color(1, 1, 0.9, 1)][camada]
				anel.material = _add()
				c.add_child(anel)
			c.set_meta("flutua", true)
		"chapeu_chifre":
			for s in [-1.0, 1.0]:
				var pts := PackedVector2Array()
				for k in 9:                                 # lado de fora, curvando pra dentro na ponta
					var t := k / 8.0
					pts.append(Vector2(s * (88.0 + 10.0 * t - 70.0 * t * t), -t * 128.0))
				for k in range(8, -1, -1):                  # lado de dentro
					var t := k / 8.0
					pts.append(Vector2(s * (32.0 + 60.0 * t - 70.0 * t * t + 18.0 * t), -t * 120.0))
				_poli(c, pts, Color(0.82, 0.06, 0.08), escuro, 6.0)
				_poli(c, PackedVector2Array([Vector2(s * 48, -6), Vector2(s * 62, -6), Vector2(s * 70, -70), Vector2(s * 60, -74)]), Color(1, 0.45, 0.4, 0.8), Color(0, 0, 0, 0), 0.0)
		"chapeu_cartola":
			_poli(c, PackedVector2Array([Vector2(-118, 6), Vector2(118, 6), Vector2(108, -16), Vector2(-108, -16)]), Color(0.1, 0.1, 0.12), Color(0.02, 0.02, 0.03), 6.0)
			_poli(c, PackedVector2Array([Vector2(-72, -12), Vector2(72, -12), Vector2(80, -168), Vector2(-80, -168)]), Color(0.13, 0.13, 0.16), Color(0.02, 0.02, 0.03), 6.0)
			_poli(c, PackedVector2Array([Vector2(-73, -26), Vector2(73, -26), Vector2(75, -56), Vector2(-75, -56)]), Color(0.75, 0.08, 0.15), Color(0.02, 0.02, 0.03), 4.0)
			_poli(c, PackedVector2Array([Vector2(-56, -64), Vector2(-40, -64), Vector2(-44, -160), Vector2(-62, -160)]), Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0.0)
	cab.add_child(c)
	_chapeu = c

func _poli(pai: Node2D, pts: PackedVector2Array, cor: Color, borda: Color, larg: float) -> void:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = cor
	pai.add_child(p)
	if larg > 0.0:
		var l := Line2D.new()
		var fechado := pts.duplicate()
		fechado.append(pts[0])
		l.points = fechado
		l.width = larg
		l.default_color = borda
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		pai.add_child(l)

func _circ(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 16:
		pts.append(c + Vector2(r, 0).rotated(TAU * k / 16.0))
	return pts

# ---------- passo ----------
func _process(delta: float) -> void:
	if not is_instance_valid(pl):
		return
	_t += delta / Engine.time_scale
	var vivo := pl.montado and is_instance_valid(pl.chassi)
	var pos := pl.foco().global_position if is_instance_valid(pl.chassi) else Vector2.ZERO
	var rapido := vivo and pl.chassi.linear_velocity.length() > 220.0
	_passo_rastro(pos, rapido, pl.chassi.rotation if vivo else 0.0)
	for n in _aura_nos:
		if not is_instance_valid(n):
			continue
		n.visible = vivo                                 # caiu do veículo: a aura não fica nele
		if n is Sprite2D:
			var pulso := 1.0 + 0.08 * sin(_t * 4.0)
			n.scale = Vector2(16.0, 22.0) * pulso
			if _aura_id == "aura_arco":
				n.modulate = Color.from_hsv(fmod(_t * 0.35, 1.0), 0.6, 1.0, 0.5)
			elif _aura_id == "aura_roxa":
				n.modulate.a = 0.45 + 0.15 * sin(_t * 11.0)
		elif n is Line2D:
			n.rotation = _t * 1.6
			if _aura_id == "aura_arco":
				var c := Color.from_hsv(fmod(_t * 0.35 + 0.5, 1.0), 0.6, 1.0)
				(n as Line2D).gradient = _rampa([Color(c, 0.0), Color(c, 0.9), Color(c, 0.0), Color(c, 0.9), Color(c, 0.0)])
	if is_instance_valid(_chapeu) and _chapeu.has_meta("flutua"):
		_chapeu.position.y = -float((pl.sprites["cabeca"] as Sprite2D).texture.get_height()) * 0.4 + sin(_t * 3.0) * 12.0
	for r in _rodas_fx:
		if not is_instance_valid(r["no"]):
			continue
		var rb: RigidBody2D = r["rb"]
		(r["p"] as CPUParticles2D).emitting = vivo and absf(rb.angular_velocity) > 0.5
		var halo: Sprite2D = r["halo"]
		halo.modulate.a = 0.35 + 0.15 * sin(_t * 8.0)
		if r["id"] == "roda_arco":
			for c in (r["no"] as Node2D).get_children():
				if c is Line2D and (c as Line2D).width > 10.0:
					(c as Line2D).default_color = Color.from_hsv(fmod(_t * 0.6, 1.0), 0.8, 1.0)
			halo.modulate = Color.from_hsv(fmod(_t * 0.6, 1.0), 0.8, 1.0, halo.modulate.a)

# ---------- morte ----------
## efeito do passe na hora que morre
func morrer() -> void:
	var id := Passe.equipado("morte")
	if id == "" or not is_instance_valid(pl):
		return
	var onde := pl.foco().global_position + Vector2(0, -350) if is_instance_valid(pl.chassi) else global_position
	match id:
		"morte_confete":
			for k in 5:
				_estouro(onde, tex("confete"), 26, Color.from_hsv(k * 0.2, 0.75, 1.0), 2.4, Vector2(2.0, 3.0), 900.0, true)
			_flash(onde, Color(1, 0.6, 0.9))
		"morte_moedas":
			_estouro(onde, tex("moeda"), 45, Color(1, 0.82, 0.25), 2.2, Vector2(2.2, 3.0), 2200.0, true)
			_estouro(onde, tex("faisca"), 25, Color(1, 1, 0.7), 0.6, Vector2(1.5, 3.0), 0.0, false)
			_flash(onde, Color(1, 0.85, 0.3))
			Audio.tocar("checkpoint", 0.9, 0.2)
		"morte_pixel":
			for k in 3:
				_estouro(onde, tex("nota"), 30, [Color(0.3, 1, 0.5), Color(0.2, 0.7, 1), Color(1, 1, 1)][k], 1.4, Vector2(0.9, 1.6), 300.0, false)
			_flash(onde, Color(0.3, 1, 0.6))
		"morte_fantasma":
			_fantasma(onde)
		"morte_raio":
			_raios(onde)

func _estouro(onde: Vector2, textura: Texture2D, qtd: int, cor: Color, vida: float, tam: Vector2, grav: float, gira: bool) -> void:
	var p := _particulas(textura, qtd, vida, _rampa([Color(cor, 1), Color(cor, 1), Color(cor, 0)], [0.0, 0.75, 1.0]), tam)
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector2.UP
	p.spread = 80.0
	p.initial_velocity_min = 800.0
	p.initial_velocity_max = 2400.0
	p.gravity = Vector2(0, grav)
	p.damping_min = 200.0
	p.damping_max = 500.0
	if gira:
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.angular_velocity_min = -720.0
		p.angular_velocity_max = 720.0
	p.z_index = 40
	get_parent().add_child(p)
	p.global_position = onde
	p.emitting = true
	get_tree().create_timer(vida * Engine.time_scale + 0.5).timeout.connect(p.queue_free)

func _flash(onde: Vector2, cor: Color) -> void:
	var s := Sprite2D.new()
	s.texture = tex("brilho")
	s.material = _add()
	s.modulate = cor
	s.z_index = 41
	get_parent().add_child(s)
	s.global_position = onde
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * 40.0, 0.25 * Engine.time_scale).from(Vector2.ONE * 5.0)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.35 * Engine.time_scale)
	tw.tween_callback(s.queue_free)

func _fantasma(onde: Vector2) -> void:
	var f := Node2D.new()
	f.z_index = 40
	var pts := PackedVector2Array()
	for k in 17:
		pts.append(Vector2(170, 0).rotated(PI + PI * k / 16.0))
	for k in 9:
		pts.append(Vector2(170 - k * 42.5, 240 + (46 if k % 2 == 0 else 0)))
	var brilho := Sprite2D.new()
	brilho.texture = tex("bolha")
	brilho.scale = Vector2.ONE * 9.0
	brilho.position = Vector2(0, 60)
	brilho.modulate = Color(0.7, 0.85, 1.0, 0.5)
	brilho.material = _add()
	f.add_child(brilho)
	_poli(f, pts, Color(0.96, 0.97, 1.0, 0.92), Color(0.55, 0.6, 0.75), 8.0)
	for s in [-1.0, 1.0]:
		_poli(f, _circ(Vector2(s * 58, -10), 26), Color(0.08, 0.08, 0.14), Color(0, 0, 0, 0), 0.0)
		_poli(f, _circ(Vector2(s * 58 - 8, -18), 8), Color(1, 1, 1), Color(0, 0, 0, 0), 0.0)
	_poli(f, _circ(Vector2(0, 50), 20), Color(0.08, 0.08, 0.14), Color(0, 0, 0, 0), 0.0)
	get_parent().add_child(f)
	f.global_position = onde
	f.scale = Vector2.ONE * 0.2
	var tw := f.create_tween()
	tw.tween_property(f, "scale", Vector2.ONE, 0.3 * Engine.time_scale).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "global_position:y", onde.y - 2400.0, 3.0 * Engine.time_scale).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(f, "rotation", 0.25, 1.5 * Engine.time_scale).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(f, "modulate:a", 0.0, 2.0 * Engine.time_scale).set_delay(1.4 * Engine.time_scale)
	tw.tween_callback(f.queue_free)

func _raios(onde: Vector2) -> void:
	for k in 8:
		var a := TAU * k / 8.0 + randf_range(-0.3, 0.3)
		var pts := PackedVector2Array([onde])
		for i in 8:
			pts.append(onde + Vector2(230.0 * (i + 1), randf_range(-110, 110)).rotated(a))
		for camada in 2:
			var l := Line2D.new()
			l.points = pts
			l.width = 70.0 if camada == 0 else 18.0
			l.default_color = Color(0.3, 0.6, 1.0, 0.5) if camada == 0 else Color(0.95, 0.98, 1.0)
			l.material = _add()
			l.z_index = 40
			get_parent().add_child(l)
			var tw := l.create_tween()
			tw.tween_property(l, "modulate:a", 0.0, 0.7 * Engine.time_scale)
			tw.tween_callback(l.queue_free)
	_flash(onde, Color(0.5, 0.8, 1.0))
	_estouro(onde, tex("faisca"), 40, Color(0.8, 0.95, 1.0), 0.8, Vector2(1.5, 3.5), 0.0, false)
	Audio.tocar("choque", 1.0, 0.0)

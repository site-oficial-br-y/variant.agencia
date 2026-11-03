extends Node2D
class_name Cosmeticos
## Itens de efeito do passe aplicados no boneco: rastro, aura, roda, chapéu e efeito de morte.
## Fica na fase (filho do Main) e segue o jogador; o nick colorido é feito pelo Main no HUD.

var pl: Player
var pecas: Pecas
var _rastro: CPUParticles2D
var _raio: Line2D
var _raio_pts: Array = []
var _aura: Sprite2D
var _chapeu: Node2D
var _rodas_fx: Array = []
var _t := 0.0

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

static func _textura_quadrado() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)

static func _textura_bolha() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

## forma de coração/estrela desenhada numa textura pequena
static func _textura_forma(forma: String) -> ImageTexture:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var dentro := false
			if forma == "coracao":
				var yy := -v * 1.2 + 0.25
				dentro = pow(u * u + yy * yy - 0.5, 3.0) - u * u * yy * yy * yy < 0.0
			elif forma == "estrela":
				var a := atan2(v, u)
				var r := sqrt(u * u + v * v)
				dentro = r < 0.45 + 0.45 * pow(absf(cos(a * 2.5)), 6.0)
			elif forma == "nota":
				dentro = absf(u) < 0.8 and absf(v) < 0.45
			img.set_pixel(x, y, Color(1, 1, 1, 1) if dentro else Color(1, 1, 1, 0))
	return ImageTexture.create_from_image(img)

# ---------- rastro ----------
func _montar_rastro(id: String) -> void:
	if id == "":
		return
	if id == "rastro_raio":
		_raio = Line2D.new()
		_raio.width = 40.0
		_raio.default_color = Color(0.6, 0.9, 1.0, 0.9)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_raio.material = add
		_raio.z_index = 2
		add_child(_raio)
		return
	var p := CPUParticles2D.new()
	p.local_coords = false
	p.amount = 18 if Game.leve else 60
	p.lifetime = 1.0
	p.speed_scale = 1.0 / Engine.time_scale
	p.direction = Vector2.UP
	p.spread = 30.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 120.0
	p.z_index = 1
	var g := Gradient.new()
	match id:
		"rastro_fumaca":
			p.texture = _textura_bolha()
			p.scale_amount_min = 3.0
			p.scale_amount_max = 6.0
			g.set_color(0, Color(0.8, 0.8, 0.82, 0.55))
			g.set_color(1, Color(0.4, 0.4, 0.45, 0.0))
		"rastro_fogo":
			p.texture = _textura_bolha()
			p.scale_amount_min = 2.5
			p.scale_amount_max = 5.0
			p.gravity = Vector2(0, -400)
			g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
			g.colors = PackedColorArray([Color(1, 0.95, 0.5, 0.95), Color(1, 0.4, 0.05, 0.8), Color(0.25, 0.05, 0.05, 0.0)])
		"rastro_arco":
			p.texture = _textura_bolha()
			p.scale_amount_min = 2.0
			p.scale_amount_max = 3.5
			p.hue_variation_min = -1.0
			p.hue_variation_max = 1.0
			p.color = Color(1, 0.3, 0.3)
			g.set_color(0, Color(1, 1, 1, 0.95))
			g.set_color(1, Color(1, 1, 1, 0.0))
		"rastro_coracao":
			p.texture = _textura_forma("coracao")
			p.scale_amount_min = 2.0
			p.scale_amount_max = 3.5
			p.amount = 10 if Game.leve else 26
			g.set_color(0, Color(1, 0.35, 0.55, 1.0))
			g.set_color(1, Color(1, 0.6, 0.75, 0.0))
		"rastro_dinheiro":
			p.texture = _textura_forma("nota")
			p.scale_amount_min = 2.5
			p.scale_amount_max = 3.5
			p.gravity = Vector2(0, 250)
			p.angle_min = -180.0
			p.angle_max = 180.0
			p.angular_velocity_min = -300.0
			p.angular_velocity_max = 300.0
			p.amount = 12 if Game.leve else 30
			g.set_color(0, Color(0.4, 0.9, 0.4, 1.0))
			g.set_color(1, Color(0.2, 0.6, 0.2, 0.0))
		"rastro_estrela":
			p.texture = _textura_forma("estrela")
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
			p.angular_velocity_min = -200.0
			p.angular_velocity_max = 200.0
			g.set_color(0, Color(1, 0.95, 0.5, 1.0))
			g.set_color(1, Color(1, 0.8, 0.2, 0.0))
	p.color_ramp = g
	p.emitting = false
	_rastro = p
	add_child(p)

# ---------- aura ----------
func _montar_aura(id: String) -> void:
	if id == "" or not is_instance_valid(pl) or not is_instance_valid(pl.chassi):
		return
	_aura = Sprite2D.new()
	_aura.texture = _textura_bolha()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if id == "aura_semaj":
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	_aura.material = add
	_aura.z_index = -2
	_aura.scale = Vector2.ONE * 22.0
	_aura.set_meta("id", id)
	_aura.position = Vector2(0, -350)
	pl.chassi.add_child(_aura)

# ---------- rodas ----------
func _montar_rodas(id: String) -> void:
	if id == "" or not is_instance_valid(pl):
		return
	var cor: Color = Passe.item(id)[4]
	for rd in pl.rodas:
		var rb := rd as RigidBody2D
		var cs := rb.get_child(0) as CollisionShape2D
		var raio: float = (cs.shape as CircleShape2D).radius if cs and cs.shape is CircleShape2D else 100.0
		var anel := Line2D.new()
		var pts := PackedVector2Array()
		for k in 33:
			pts.append(Vector2(raio + 6.0, 0).rotated(TAU * k / 32.0))
		anel.points = pts
		anel.width = 22.0
		anel.default_color = cor
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		anel.material = add
		anel.z_index = 8
		rb.add_child(anel)
		var fx := CPUParticles2D.new()
		fx.local_coords = false
		fx.amount = 8 if Game.leve else 24
		fx.lifetime = 0.5
		fx.speed_scale = 1.0 / Engine.time_scale
		fx.texture = _textura_bolha()
		fx.scale_amount_min = 0.25
		fx.scale_amount_max = 0.55
		fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
		var em := PackedVector2Array()
		for k in 16:
			em.append(Vector2(raio, 0).rotated(TAU * k / 16.0))
		fx.emission_points = em
		fx.gravity = Vector2(0, -200 if id != "roda_gelo" else 300)
		fx.color = cor
		if id == "roda_arco":
			fx.hue_variation_min = -1.0
			fx.hue_variation_max = 1.0
		fx.z_index = 8
		rb.add_child(fx)
		_rodas_fx.append([anel, fx, rb, id])

# ---------- chapéu ----------
func _montar_chapeu(id: String) -> void:
	if id == "" or not is_instance_valid(pl) or not pl.sprites.has("cabeca"):
		return
	var cab: Sprite2D = pl.sprites["cabeca"]
	var h := float(cab.texture.get_height())
	var w := float(cab.texture.get_width())
	var c := Node2D.new()
	c.position = Vector2(-w * 0.05, -h * 0.42)
	c.z_index = 3
	var esc := w / 220.0
	c.scale = Vector2.ONE * esc
	match id:
		"chapeu_coroa":
			var pol := Polygon2D.new()
			pol.polygon = PackedVector2Array([Vector2(-90, 0), Vector2(-90, -70), Vector2(-55, -30), Vector2(-25, -95),
				Vector2(0, -35), Vector2(25, -95), Vector2(55, -30), Vector2(90, -70), Vector2(90, 0)])
			pol.color = Color(1.0, 0.8, 0.2)
			c.add_child(pol)
			for k in 3:
				var j := Polygon2D.new()
				var pts := PackedVector2Array()
				for i in 8:
					pts.append(Vector2(-50 + k * 50, -14) + Vector2(11, 0).rotated(TAU * i / 8.0))
				j.polygon = pts
				j.color = [Color(1, 0.2, 0.3), Color(0.3, 0.6, 1), Color(0.3, 1, 0.5)][k]
				c.add_child(j)
		"chapeu_aureola":
			var anel := Line2D.new()
			var pts := PackedVector2Array()
			for i in 33:
				pts.append(Vector2(85, 0).rotated(TAU * i / 32.0) * Vector2(1.0, 0.28) + Vector2(0, -95))
			anel.points = pts
			anel.width = 16.0
			anel.default_color = Color(1, 0.95, 0.55)
			var add := CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			anel.material = add
			c.add_child(anel)
			c.set_meta("flutua", true)
		"chapeu_chifre":
			for s in [-1.0, 1.0]:
				var ch := Polygon2D.new()
				ch.polygon = PackedVector2Array([Vector2(s * 35, 0), Vector2(s * 85, 0), Vector2(s * 95, -110), Vector2(s * 70, -60)])
				ch.color = Color(0.85, 0.08, 0.08)
				c.add_child(ch)
		"chapeu_cartola":
			var aba := Polygon2D.new()
			aba.polygon = Pecas.retangulo(Vector2(0, -8), Vector2(220, 22))
			aba.color = Color(0.1, 0.1, 0.12)
			c.add_child(aba)
			var copa := Polygon2D.new()
			copa.polygon = Pecas.retangulo(Vector2(0, -85), Vector2(140, 150))
			copa.color = Color(0.12, 0.12, 0.14)
			c.add_child(copa)
			var faixa := Polygon2D.new()
			faixa.polygon = Pecas.retangulo(Vector2(0, -35), Vector2(140, 26))
			faixa.color = Color(0.75, 0.1, 0.15)
			c.add_child(faixa)
	cab.add_child(c)
	_chapeu = c

# ---------- passo ----------
func _process(delta: float) -> void:
	if not is_instance_valid(pl):
		return
	_t += delta / Engine.time_scale
	var vivo := pl.montado and is_instance_valid(pl.chassi)
	var pos := pl.foco().global_position if is_instance_valid(pl.chassi) else Vector2.ZERO
	var rapido := vivo and pl.chassi.linear_velocity.length() > 250.0
	if _rastro:
		_rastro.global_position = pos + Vector2(-120, -250).rotated(pl.chassi.rotation if vivo else 0.0)
		_rastro.emitting = rapido
	if _raio:
		if rapido:
			_raio_pts.push_front(pos + Vector2(-80, -300))
		elif not _raio_pts.is_empty():
			_raio_pts.pop_back()
		while _raio_pts.size() > 14:
			_raio_pts.pop_back()
		var pts := PackedVector2Array()
		for i in _raio_pts.size():
			var p: Vector2 = _raio_pts[i]
			pts.append(p + Vector2(0, randf_range(-60, 60) * (i / 14.0)))
		_raio.points = pts
		_raio.width = 26.0 + 14.0 * sin(_t * 40.0)
	if is_instance_valid(_aura):
		var id: String = _aura.get_meta("id")
		var pulso := 1.0 + 0.1 * sin(_t * 4.0)
		_aura.scale = Vector2.ONE * 22.0 * pulso
		match id:
			"aura_dourada":
				_aura.modulate = Color(1, 0.8, 0.3, 0.5)
			"aura_roxa":
				_aura.modulate = Color(0.75, 0.3, 1.0, 0.45 + 0.15 * sin(_t * 9.0))
				_aura.scale = Vector2(20.0, 26.0) * pulso
			"aura_gelo":
				_aura.modulate = Color(0.6, 0.9, 1.0, 0.45)
			"aura_semaj":
				_aura.modulate = Color(0.15, 0.0, 0.25, 0.6)
			"aura_arco":
				_aura.modulate = Color.from_hsv(fmod(_t * 0.4, 1.0), 0.7, 1.0, 0.5)
	if is_instance_valid(_chapeu) and _chapeu.has_meta("flutua"):
		_chapeu.position.y = -float((pl.sprites["cabeca"] as Sprite2D).texture.get_height()) * 0.42 + sin(_t * 3.0) * 12.0
	for r in _rodas_fx:
		if not is_instance_valid(r[0]):
			continue
		(r[1] as CPUParticles2D).emitting = vivo and (r[2] as RigidBody2D).angular_velocity != 0.0
		if r[3] == "roda_arco":
			(r[0] as Line2D).default_color = Color.from_hsv(fmod(_t * 0.6, 1.0), 0.8, 1.0)
		elif r[3] == "roda_neon":
			(r[0] as Line2D).default_color.a = 0.6 + 0.4 * sin(_t * 10.0)

# ---------- morte ----------
## efeito do passe na hora que morre
func morrer() -> void:
	var id := Passe.equipado("morte")
	if id == "" or not is_instance_valid(pl) or pecas == null:
		return
	var onde := pl.foco().global_position + Vector2(0, -300) if is_instance_valid(pl.chassi) else global_position
	match id:
		"morte_confete":
			for k in 4:
				pecas.particulas(onde, 30, Color.from_hsv(k * 0.25, 0.8, 1.0), Color.from_hsv(k * 0.25 + 0.1, 0.8, 1.0, 0.0),
					600.0, 2200.0, 2.0, 18.0, 40.0, 1400.0, Vector2.UP, 80.0)
		"morte_moedas":
			pecas.particulas(onde, 50, Color(1, 0.85, 0.2, 1), Color(1, 0.6, 0.1, 0.0), 800.0, 2200.0, 2.2, 30.0, 50.0, 2200.0, Vector2.UP, 70.0)
			Audio.tocar("checkpoint", 0.8, 0.2)
		"morte_pixel":
			pecas.particulas(onde, 60, Color(0.3, 1, 0.5, 1), Color(0.1, 0.4, 1, 0.0), 300.0, 1400.0, 1.6, 30.0, 60.0, 0.0, Vector2.UP, 180.0)
		"morte_fantasma":
			_fantasma(onde)
		"morte_raio":
			_raios(onde)

func _fantasma(onde: Vector2) -> void:
	var f := Node2D.new()
	f.z_index = 40
	var corpo := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 13:
		pts.append(Vector2(160, 0).rotated(PI + PI * k / 12.0))
	for k in 7:
		pts.append(Vector2(160 - k * 53.0, 220 + (40 if k % 2 == 0 else 0)))
	corpo.polygon = pts
	corpo.color = Color(0.95, 0.97, 1.0, 0.85)
	f.add_child(corpo)
	for s in [-1.0, 1.0]:
		var olho := Polygon2D.new()
		var po := PackedVector2Array()
		for k in 10:
			po.append(Vector2(s * 55, -20) + Vector2(22, 0).rotated(TAU * k / 10.0) * Vector2(1, 1.4))
		olho.polygon = po
		olho.color = Color(0.1, 0.1, 0.15)
		f.add_child(olho)
	get_parent().add_child(f)
	f.global_position = onde
	var tw := f.create_tween()
	tw.tween_property(f, "global_position:y", onde.y - 2200.0, 3.0 * Engine.time_scale).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(f, "modulate:a", 0.0, 3.0 * Engine.time_scale).set_delay(1.2 * Engine.time_scale)
	tw.tween_callback(f.queue_free)

func _raios(onde: Vector2) -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for k in 7:
		var l := Line2D.new()
		var pts := PackedVector2Array([onde])
		var a := TAU * k / 7.0 + randf_range(-0.3, 0.3)
		for i in 7:
			pts.append(onde + Vector2(220.0 * (i + 1), randf_range(-90, 90)).rotated(a))
		l.points = pts
		l.width = 26.0
		l.default_color = Color(0.6, 0.9, 1.0)
		l.material = add
		l.z_index = 40
		get_parent().add_child(l)
		var tw := l.create_tween()
		tw.tween_property(l, "modulate:a", 0.0, 0.6 * Engine.time_scale)
		tw.tween_callback(l.queue_free)
	pecas.particulas(onde, 40, Color(0.8, 0.95, 1, 1), Color(0.3, 0.6, 1, 0.0), 500.0, 1800.0, 0.8, 20.0, 50.0, 0.0, Vector2.UP, 180.0)
	Audio.tocar("choque", 1.0, 0.0)

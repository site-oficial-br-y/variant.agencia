extends RefCounted
class_name Mecanicas
## Armadilhas, plataformas dinâmicas e impulsos. Tudo físico e reutilizável:
## mina, bomba perseguidora, plataforma temporária/retrátil/móvel/quebrável,
## trampolim, painel de aceleração e túnel de vento. `atualizar` roda a cada passo
## de física (chamado pela fase).

const PRETO := Color(0.14, 0.14, 0.16)
const LUZ := Color(1.0, 0.18, 0.12)

var raiz: Node2D
var pecas: Pecas
var jogador: Callable                    # () -> Player
var _vivos: Array = []                   # dicionários com "tipo" e estado
var _t := 0.0

func _init(no: Node2D, p: Pecas, pega_jogador: Callable) -> void:
	raiz = no
	pecas = p
	jogador = pega_jogador

# ---------- utilidades ----------
func _veiculo(b: Node) -> bool:
	return b.is_in_group("veiculo") or b.is_in_group("piloto")

func _corpos_do_jogador() -> Array:
	var pl: Player = jogador.call()
	if not is_instance_valid(pl) or not is_instance_valid(pl.chassi):
		return []
	if pl.montado:
		return [pl.chassi] + pl.rodas
	return pl.corpos.values() + [pl.chassi] + pl.rodas

func _foco() -> Vector2:
	var pl: Player = jogador.call()
	if not is_instance_valid(pl) or not is_instance_valid(pl.chassi):
		return Vector2(INF, INF)
	return pl.foco().global_position

func _circulo(r: float, n := 28, c := Vector2.ZERO) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		pts.append(c + Vector2(r, 0).rotated(TAU * k / n))
	return pts

func _area(centro: Vector2, tamanho: Vector2, pai: Node = null) -> Area2D:
	var a := Area2D.new()
	a.position = centro
	a.collision_layer = 0
	a.collision_mask = 0b110
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = tamanho
	cs.shape = r
	a.add_child(cs)
	(pai if pai else raiz).add_child(a)
	return a

func explosao(pos: Vector2, raio: float, dv: float) -> void:
	pecas.explodir(pos, raio, dv)

## chamada em toda explosão (inclusive TNT da biblioteca): quebra plataforma frágil perto
func quebrar_perto(pos: Vector2, raio: float) -> void:
	for m in _vivos.duplicate():
		if m["tipo"] == "quebravel" and not m["quebrou"] and is_instance_valid(m["no"]) \
				and (m["no"] as Node2D).global_position.distance_to(pos) < raio:
			_quebrar.call_deferred(m)

# ---------- mina terrestre ----------
## meio enterrada; pisca; quem passa perto aciona e ela estoura logo depois
func mina(base: Vector2) -> void:
	var n := Node2D.new()
	n.position = base
	n.z_index = 3
	raiz.add_child(n)
	var cupula := PackedVector2Array()
	for k in 13:
		cupula.append(Vector2(110, 0).rotated(PI + PI * k / 12.0))
	pecas.poligono(cupula, PRETO, 0, null, 1.0, n)
	pecas.poligono(Pecas.retangulo(Vector2(0, 8), Vector2(260, 26)), Color(0.32, 0.32, 0.35), 0, null, 1.0, n)
	pecas.poligono(Pecas.retangulo(Vector2(0, 8), Vector2(220, 10)), Pecas.AMARELO, 0, null, 1.0, n)
	var luz := pecas.poligono(_circulo(22, 12, Vector2(0, -88)), LUZ, 1, null, 1.0, n)
	var tw := luz.create_tween().set_loops()
	tw.tween_property(luz, "modulate:a", 0.15, 0.35)
	tw.tween_property(luz, "modulate:a", 1.0, 0.35)
	var m := {"tipo": "mina", "no": n, "armada": false, "t": 0.0}
	var a := _area(Vector2(0, -150), Vector2(520, 340), n)
	a.body_entered.connect(func(b: Node2D) -> void:
		if not m["armada"] and _veiculo(b):
			m["armada"] = true
			m["t"] = 0.35
			Audio.tocar("clique", 1.0, 0.0))
	_vivos.append(m)

# ---------- bomba perseguidora ----------
## drone-bomba: fica pairando; quando o jogador chega perto, persegue (mais lenta
## que um veículo embalado) e estoura ao encostar ou quando o pavio acaba
func bomba_perseguidora(pos: Vector2, alcance := 3200.0) -> void:
	var n := Node2D.new()
	n.position = pos
	n.z_index = 6
	raiz.add_child(n)
	pecas.poligono(_circulo(135), PRETO, 0, null, 1.0, n)
	pecas.poligono(_circulo(48, 16, Vector2(-45, -45)), Color(0.35, 0.35, 0.4), 0, null, 1.0, n)
	pecas.poligono(Pecas.retangulo(Vector2(0, 0), Vector2(270, 50)), Pecas.AMARELO, 0, null, 1.0, n)
	for k in 4:
		pecas.poligono(PackedVector2Array([Vector2(-120 + k * 70, -25), Vector2(-95 + k * 70, -25), Vector2(-120 + k * 70, 25), Vector2(-145 + k * 70, 25)]), PRETO, 1, null, 1.0, n)
	var olho := pecas.poligono(_circulo(30, 14, Vector2(70, -60)), LUZ, 2, null, 1.0, n)
	pecas.barra_metal(Vector2(0, -135), Vector2(0, -210), 22.0, Color(0.3, 0.3, 0.32), 1, n)
	var helice := Node2D.new()
	helice.position = Vector2(0, -215)
	n.add_child(helice)
	pecas.poligono(Pecas.retangulo(Vector2.ZERO, Vector2(300, 22)), Color(0.55, 0.55, 0.6), 2, null, 1.0, helice)
	var tw := olho.create_tween().set_loops()
	tw.tween_property(olho, "modulate:a", 0.2, 0.3)
	tw.tween_property(olho, "modulate:a", 1.0, 0.3)
	_vivos.append({"tipo": "drone", "no": n, "helice": helice, "olho": olho, "base": pos, "alcance": alcance,
		"ativa": false, "pavio": 6.0, "vel": Vector2.ZERO, "bip": 0.0})

# ---------- plataformas ----------
func _laje(centro: Vector2, larg: float, cor := Pecas.CINZA, corpo: PhysicsBody2D = null) -> PhysicsBody2D:
	var sb: PhysicsBody2D = corpo if corpo else StaticBody2D.new()
	sb.position = centro
	sb.collision_layer = 0b01
	if sb is StaticBody2D or sb is AnimatableBody2D:
		sb.set("physics_material_override", pecas.mat)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(larg, 90)
	cs.shape = r
	sb.add_child(cs)
	pecas.poligono(Pecas.retangulo(Vector2.ZERO, Vector2(larg, 90)), cor, 2, null, 1.0, sb)
	pecas.poligono(Pecas.retangulo(Vector2(0, -36), Vector2(larg, 18)), cor.lightened(0.25), 2, null, 1.0, sb)
	pecas.linha(Pecas.retangulo(Vector2.ZERO, Vector2(larg, 90)) + PackedVector2Array([Vector2(-larg / 2, -45)]), 10.0, cor.darkened(0.5), 2, sb)
	raiz.add_child(sb)
	return sb

func _solida(m: Dictionary, sim: bool) -> void:
	var sb: Node = m["no"]
	(sb.get_child(0) as CollisionShape2D).set_deferred("disabled", not sim)

## aparece e some num ciclo fixo (pisca antes de sumir). `fase` 0..1 desloca o ciclo.
func plataforma_temporaria(topo_centro: Vector2, larg: float, periodo := 3.6, fase := 0.0) -> void:
	var sb := _laje(topo_centro + Vector2(0, 45), larg, Color(0.2, 0.55, 0.85))
	if fase == 0.0:                                    # a primeira da onda: o bot espera ela aparecer
		sb.add_to_group("plataforma_temporaria")
	sb.set_meta("periodo", periodo)
	sb.set_meta("fase", fase)
	_vivos.append({"tipo": "temporaria", "no": sb, "periodo": periodo, "fase": fase, "solida": true})

## escondida até o jogador chegar perto; aparece e some de novo depois de `dura` s
func plataforma_retratil(topo_centro: Vector2, larg: float, dura := 3.5) -> void:
	var sb := _laje(topo_centro + Vector2(0, 45), larg, Color(0.95, 0.6, 0.15))
	sb.modulate.a = 0.18
	var m := {"tipo": "retratil", "no": sb, "dura": dura, "t": -1.0, "solida": false}
	_solida(m, false)
	_vivos.append(m)

## vai e volta entre `a` e `b` (topo da laje); leva quem estiver em cima
func plataforma_movel(a: Vector2, b: Vector2, larg: float, periodo := 4.0) -> void:
	var ab := AnimatableBody2D.new()
	ab.sync_to_physics = false
	_laje(a + Vector2(0, 45), larg, Color(0.45, 0.47, 0.55), ab)
	for x in [-larg * 0.35, larg * 0.35]:                # rodinhas de trilho, só visual
		pecas.poligono(_circulo(34, 14, Vector2(x, 60)), PRETO, 3, null, 1.0, ab)
	pecas.linha(PackedVector2Array([a + Vector2(0, 110), b + Vector2(0, 110)]), 14.0, Color(0.25, 0.25, 0.28), 1)
	_vivos.append({"tipo": "movel", "no": ab, "a": a + Vector2(0, 45), "b": b + Vector2(0, 45), "periodo": periodo})

## rachada: cede pouco depois de receber peso, ou na hora com pancada/explosão
func plataforma_quebravel(topo_centro: Vector2, larg: float) -> void:
	var sb := _laje(topo_centro + Vector2(0, 45), larg, Color(0.62, 0.5, 0.36))
	for k in 3:                                        # rachaduras
		var x := -larg / 2 + larg * (k + 0.5) / 3.0
		pecas.linha(PackedVector2Array([Vector2(x, -45), Vector2(x + 30, -10), Vector2(x - 20, 15), Vector2(x + 10, 45)]), 8.0, Color(0.25, 0.18, 0.1), 3, sb)
	var m := {"tipo": "quebravel", "no": sb, "larg": larg, "quebrou": false, "t": -1.0}
	var a := _area(Vector2(0, -90), Vector2(larg, 120), sb)
	a.body_entered.connect(func(b: Node2D) -> void:
		if m["quebrou"] or not _veiculo(b):
			return
		var v: float = (b as RigidBody2D).linear_velocity.y if b is RigidBody2D else 0.0
		if v > 1400.0:                                   # aterrissou com força: quebra na hora
			_quebrar.call_deferred(m)
		elif m["t"] < 0.0:
			m["t"] = 0.55
			Audio.tocar("caixa", 0.7))
	_vivos.append(m)

func _quebrar(m: Dictionary) -> void:
	if m["quebrou"]:
		return
	m["quebrou"] = true
	var sb: Node2D = m["no"]
	var larg: float = m["larg"]
	Audio.tocar("caixa", 1.0)
	Audio.tocar("impacto_forte", 0.6)
	for k in 4:                                         # vira 4 pedaços que caem (somem depois)
		var p := RigidBody2D.new()
		p.collision_layer = 0b1000
		p.collision_mask = 0b0001
		p.mass = 2.0
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(larg / 4.0 - 10.0, 80)
		cs.shape = r
		p.add_child(cs)
		pecas.poligono(Pecas.retangulo(Vector2.ZERO, Vector2(larg / 4.0 - 10.0, 80)), Color(0.62, 0.5, 0.36), 2, null, 1.0, p)
		p.position = sb.global_position + Vector2(-larg / 2.0 + larg * (k + 0.5) / 4.0, 0)
		raiz.add_child(p)
		p.linear_velocity = Vector2(randf_range(-200, 200), randf_range(-300, 0))
		p.angular_velocity = randf_range(-3, 3)
		raiz.get_tree().create_timer(6.0).timeout.connect(p.queue_free)
	pecas.poeira(sb.global_position, 1.5)
	sb.queue_free()

## mola: joga pra cima e pra frente quem passa por cima
func trampolim(base: Vector2, forca := 2300.0, frente := 500.0) -> void:
	var n := Node2D.new()
	n.position = base
	n.z_index = 3
	raiz.add_child(n)
	pecas.poligono(Pecas.retangulo(Vector2(0, -16), Vector2(380, 32)), PRETO, 0, null, 1.0, n)
	var zig := PackedVector2Array()
	for k in 9:
		zig.append(Vector2(-150 + k * 37.5, -40 - (25 if k % 2 == 0 else -5)))
	pecas.linha(zig, 18.0, Color(0.75, 0.75, 0.8), 0, n)
	var topo := pecas.poligono(Pecas.retangulo(Vector2(0, -80), Vector2(400, 36)), Color(0.9, 0.15, 0.15), 1, null, 1.0, n)
	var m := {"tipo": "trampolim", "no": n, "espera": 0.0}
	var a := _area(Vector2(0, -150), Vector2(380, 200), n)
	a.body_entered.connect(func(b: Node2D) -> void:
		if m["espera"] > 0.0 or not _veiculo(b):
			return
		m["espera"] = 0.7
		for rb in _corpos_do_jogador():
			var c := rb as RigidBody2D
			c.linear_velocity = Vector2(maxf(c.linear_velocity.x, frente), -forca)
		Audio.tocar("pulo", 1.0)
		var tw := topo.create_tween()
		tw.tween_property(topo, "position:y", -40.0, 0.06)
		tw.tween_property(topo, "position:y", 0.0, 0.25))
	_vivos.append(m)

# ---------- impulsos de velocidade ----------
## painel no chão com setas: quem passa ganha velocidade na direção do chão
func painel_aceleracao(base: Vector2, larg := 900.0, ganho := 1100.0, vmax := 3200.0) -> void:
	var n := Node2D.new()
	n.position = base
	n.z_index = 3
	raiz.add_child(n)
	pecas.poligono(Pecas.retangulo(Vector2(0, -10), Vector2(larg, 26)), PRETO, 0, null, 1.0, n)
	var setas: Array = []
	for k in 4:
		var s := pecas.poligono(PackedVector2Array([Vector2(-60, -22), Vector2(10, -22), Vector2(60, -10),
			Vector2(10, 2), Vector2(-60, 2), Vector2(-10, -10)]), Color(0.3, 1.0, 0.45), 1, null, 1.0, n)
		s.position = Vector2(-larg / 2 + larg * (k + 0.5) / 4.0, 0)
		setas.append(s)
		var tw := s.create_tween().set_loops()
		tw.tween_interval(0.12 * k)
		tw.tween_property(s, "modulate:a", 0.25, 0.25)
		tw.tween_property(s, "modulate:a", 1.0, 0.25)
	var a := _area(Vector2(0, -120), Vector2(larg, 240), n)
	a.body_entered.connect(func(b: Node2D) -> void:
		if not b.is_in_group("veiculo"):
			return
		var pl: Player = jogador.call()
		if not is_instance_valid(pl) or b != pl.chassi:
			return
		for rb in _corpos_do_jogador():
			var c := rb as RigidBody2D
			var dir := Vector2.RIGHT.rotated(c.rotation if c == pl.chassi else pl.chassi.rotation)
			var novo := c.linear_velocity + dir * ganho
			c.linear_velocity = novo.limit_length(vmax)
		Audio.tocar("turbo", 0.9, 0.02)
		pecas.particulas(b.global_position, 30, Color(0.4, 1, 0.5, 0.9), Color(0.4, 1, 0.5, 0.0), 300.0, 900.0, 0.6, 40.0, 90.0, 0.0, Vector2.LEFT, 25.0))

## tubo de vento: empurra continuamente na direção de `a` para `b` quem estiver dentro
func tunel_vento(a: Vector2, b: Vector2, largura := 900.0, acel := 2600.0) -> void:
	var d := b - a
	var n := Node2D.new()
	n.position = (a + b) / 2.0
	n.rotation = d.angle()
	n.z_index = -1
	raiz.add_child(n)
	var meio := d.length() / 2.0
	pecas.poligono(Pecas.retangulo(Vector2.ZERO, Vector2(d.length(), largura)), Color(0.45, 0.85, 1.0, 0.18), 0, null, 1.0, n)
	for s in [-1.0, 1.0]:
		pecas.linha(PackedVector2Array([Vector2(-meio, s * largura / 2), Vector2(meio, s * largura / 2)]), 26.0, Color(0.3, 0.35, 0.42), 1, n)
		for k in int(d.length() / 500.0) + 1:          # anéis
			var x := -meio + k * 500.0
			pecas.linha(PackedVector2Array([Vector2(x, s * largura / 2 - 40), Vector2(x, s * largura / 2 + 40)]), 30.0, Color(0.6, 0.62, 0.68), 1, n)
	var fluxo := Node2D.new()
	n.add_child(fluxo)
	for k in int(d.length() / 350.0):
		var y := -largura * 0.3 + (k % 3) * largura * 0.3
		pecas.poligono(PackedVector2Array([Vector2(-40, -18), Vector2(30, 0), Vector2(-40, 18)]), Color(1, 1, 1, 0.65), 1, null, 1.0, fluxo).position = Vector2(-meio + k * 350.0, y)
	var tw := fluxo.create_tween().set_loops()
	tw.tween_property(fluxo, "position:x", 350.0, 0.4).from(0.0)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 0b110
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(d.length(), largura)
	cs.shape = r
	area.add_child(cs)
	n.add_child(area)
	_vivos.append({"tipo": "tunel", "no": n, "area": area, "dir": d.normalized(), "acel": acel})

# ---------- passo de física ----------
func atualizar(dt: float) -> void:
	_t += dt
	var alvo := _foco()
	for m in _vivos.duplicate():
		var no = m["no"]
		if not is_instance_valid(no):
			_vivos.erase(m)
			continue
		match m["tipo"]:
			"mina":
				if m["armada"]:
					m["t"] -= dt
					if m["t"] <= 0.0:
						var pos: Vector2 = (no as Node2D).global_position + Vector2(0, -60)
						_vivos.erase(m)
						no.queue_free()
						explosao(pos, 1400.0, 1000.0)
			"drone":
				_drone(m, dt, alvo)
			"temporaria":
				var f := fposmod(_t / float(m["periodo"]) + float(m["fase"]), 1.0)
				var sim := f < 0.62
				if sim != m["solida"]:
					m["solida"] = sim
					_solida(m, sim)
				var sb: Node2D = no
				sb.modulate.a = 1.0 if f < 0.45 else (0.35 + 0.65 * absf(sin(_t * 30.0)) if sim else 0.12)
				sb.set_meta("ciclo", f)
				sb.set_meta("larg", (sb.get_child(0).shape as RectangleShape2D).size.x)
			"retratil":
				var sb: Node2D = no
				if m["t"] < 0.0 and alvo.x > sb.global_position.x - 2600.0 and alvo.x < sb.global_position.x:
					m["t"] = float(m["dura"])
					_solida(m, true)
					m["solida"] = true
					sb.create_tween().tween_property(sb, "modulate:a", 1.0, 0.25)
					Audio.tocar("clique", 0.8)
				elif m["t"] > 0.0:
					m["t"] -= dt
					if m["t"] <= 0.0 and m["solida"]:
						m["solida"] = false
						_solida(m, false)
						sb.create_tween().tween_property(sb, "modulate:a", 0.18, 0.3)
			"movel":
				var k := 0.5 - 0.5 * cos(TAU * _t / float(m["periodo"]))
				(no as AnimatableBody2D).global_position = (m["a"] as Vector2).lerp(m["b"], k)
			"quebravel":
				if m["t"] > 0.0:
					m["t"] -= dt
					(no as Node2D).position.x += sin(_t * 80.0) * 3.0
					if m["t"] <= 0.0:
						_quebrar(m)
			"trampolim":
				m["espera"] = maxf(0.0, m["espera"] - dt)
			"tunel":
				for b in (m["area"] as Area2D).get_overlapping_bodies():
					if b is RigidBody2D:
						(b as RigidBody2D).apply_central_force(m["dir"] * float(m["acel"]) * (b as RigidBody2D).mass)

func _drone(m: Dictionary, dt: float, alvo: Vector2) -> void:
	var n: Node2D = m["no"]
	(m["helice"] as Node2D).scale.x = sin(_t * 40.0)
	if not m["ativa"]:
		n.position = (m["base"] as Vector2) + Vector2(0, sin(_t * 2.0) * 60.0)
		if alvo.distance_to(n.global_position) < float(m["alcance"]):
			m["ativa"] = true
			Audio.tocar("checkpoint", 0.7)
		return
	m["pavio"] -= dt
	var desejo := (alvo + Vector2(0, -300) - n.global_position).normalized() * 1050.0
	m["vel"] = (m["vel"] as Vector2).lerp(desejo, 2.2 * dt)
	n.global_position += (m["vel"] as Vector2) * dt
	m["bip"] -= dt
	if m["bip"] <= 0.0:
		m["bip"] = maxf(0.08, float(m["pavio"]) * 0.12)
		Audio.tocar("clique", 0.6, 0.0)
	if n.global_position.distance_to(alvo) < 420.0 or m["pavio"] <= 0.0:
		_vivos.erase(m)
		var pos := n.global_position
		n.queue_free()
		explosao(pos, 1500.0, 1100.0)

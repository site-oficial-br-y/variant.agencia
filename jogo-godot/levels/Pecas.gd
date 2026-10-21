extends RefCounted
class_name Pecas
## Biblioteca de peças de fase: terreno texturizado, pontes, guindaste, água, rampa,
## passarela de vigas, caixas, TNT, espinhos, placas, decoração e partículas.
## Tudo com arte de res://assets/arte (gerada por tools/gerar_arte.py) e contorno
## escuro por material. Cada peça é parametrizada e reaproveitável entre fases.

const ARTE := "res://assets/arte/"
const CONTORNO_TERRA := Color(0.17, 0.10, 0.05)
const CONTORNO_MADEIRA := Color(0.23, 0.14, 0.06)
const CONTORNO_METAL := Color(0.11, 0.13, 0.16)
const AMARELO := Color(0.96, 0.71, 0.13)
const LARG_CONTORNO := 14.0
# paleta chapada do gênero: bloco vinho, topo cinza, treliça vermelha, tufo de grama
const VINHO := Color(0.53, 0.06, 0.15)
const CINZA := Color(0.5, 0.5, 0.52)
const CINZA_CLARO := Color(0.62, 0.62, 0.64)
const VERMELHO := Color(0.66, 0.1, 0.17)
const GRAMA := Color(0.22, 0.6, 0.18)

var raiz: Node2D
var mat: PhysicsMaterial
var perigo: Callable          # (corpo: Node2D, motivo: String) -> void — chamado por zona letal
var _brilho: Texture2D
var _cache := {}
var chao_tex := "terra"          # material do terreno da fase (terra, concreto, rocha)
var topo_tex := "grama"          # faixa do topo (grama, asfalto, grama_alpina)
var contorno_chao := CONTORNO_TERRA
var pistoes: Array = []
var y_max := 0.0                 # fundo mais baixo construído (para a zona de morte)
var ao_explodir: Callable        # (pos, raio) -> a fase reage (jogador se machuca, plataforma quebra)

func _init(no: Node2D, material: PhysicsMaterial, ao_perigo: Callable) -> void:
	raiz = no
	mat = material
	perigo = ao_perigo
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	_brilho = gt

## som de objeto do cenário: só toca se estiver perto do jogador (a fase tem várias
## prensas batendo ao mesmo tempo, longe da tela, e isso virava barulho constante)
func som(nome: String, onde: Vector2, forca := 1.0) -> void:
	var pl = raiz.get("player")
	if pl == null or not is_instance_valid(pl) or not is_instance_valid(pl.chassi):
		return
	var d: float = (pl.foco() as Node2D).global_position.distance_to(onde)
	if d < 5000.0:
		Audio.tocar(nome, forca * clampf(1.0 - d / 5000.0, 0.25, 1.0))

func tex(nome: String) -> Texture2D:
	if not _cache.has(nome):
		_cache[nome] = load(ARTE + nome + ".png")
	return _cache[nome]

## elo de corrente deitado (o eixo comprido ao longo da linha)
func _tex_elo() -> Texture2D:
	if not _cache.has("elo_deitado"):
		var img := (tex("elo") as Texture2D).get_image()
		img.rotate_90(CLOCKWISE)
		_cache["elo_deitado"] = ImageTexture.create_from_image(img)
	return _cache["elo_deitado"]

static func suavizar(bruto: PackedVector2Array, passos := 3) -> PackedVector2Array:
	var sup := bruto
	for it in passos:
		var nova := PackedVector2Array([sup[0]])
		for i in sup.size() - 1:
			nova.append(sup[i].lerp(sup[i + 1], 0.25))
			nova.append(sup[i].lerp(sup[i + 1], 0.75))
		nova.append(sup[sup.size() - 1])
		sup = nova
	return sup

func linha(pts: PackedVector2Array, largura: float, cor: Color, z := 0, pai: Node = null) -> Line2D:
	var l := Line2D.new()
	l.points = pts
	l.width = largura
	l.default_color = cor
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.z_index = z
	(pai if pai else raiz).add_child(l)
	return l

func poligono(pts: PackedVector2Array, cor: Color, z := 0, textura: Texture2D = null, escala := 1.0, pai: Node = null) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = cor
	p.z_index = z
	if textura:
		p.texture = textura
		p.texture_scale = Vector2.ONE / escala
		p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	(pai if pai else raiz).add_child(p)
	return p

static func retangulo(c: Vector2, tam: Vector2, ang := 0.0) -> PackedVector2Array:
	var h := tam / 2.0
	var r := PackedVector2Array()
	for v in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
		r.append(c + (v as Vector2).rotated(ang))
	return r

func _fechar(pts: PackedVector2Array) -> PackedVector2Array:
	var r := pts.duplicate()
	r.append(pts[0])
	return r

# ---------- terreno ----------
## terra com textura + faixa de grama seguindo a superfície + contorno nas laterais
func terreno(bruto: PackedVector2Array, fundo_y: float, grama := true) -> PackedVector2Array:
	var sup := suavizar(bruto)
	y_max = maxf(y_max, fundo_y)
	var sb := StaticBody2D.new()
	sb.collision_layer = 0b01
	sb.physics_material_override = mat
	var pts := sup.duplicate()
	pts.append(Vector2(sup[sup.size() - 1].x, fundo_y))
	pts.append(Vector2(sup[0].x, fundo_y))
	var col := CollisionPolygon2D.new()
	col.polygon = pts
	sb.add_child(col)
	raiz.add_child(sb)
	poligono(pts, VINHO, 0, null, 1.0, sb)
	if grama:
		var topo := PackedVector2Array()
		for q in sup:
			topo.append(q + Vector2(0, 32))
		linha(topo, 64.0, CINZA, 2, sb)
		var claro := PackedVector2Array()
		for q in sup:
			claro.append(q + Vector2(0, 8))
		linha(claro, 16.0, CINZA_CLARO, 2, sb)
		var x := sup[0].x + randf_range(200, 900)
		while x < sup[sup.size() - 1].x - 200:            # tufos de grama soltos
			tufo(Vector2(x, Pecas._y_em(sup, x)))
			x += randf_range(900, 2200)
	return sup

# ---------- madeira ----------
func tufo(base: Vector2) -> void:
	var pts := PackedVector2Array([base + Vector2(-110, 6)])
	for k in 7:
		pts.append(base + Vector2(-90 + k * 30, -randf_range(40, 90)))
		pts.append(base + Vector2(-75 + k * 30, -10))
	pts.append(base + Vector2(110, 6))
	poligono(pts, GRAMA, 3)

## barra reta chapada (cinza por padrão; vermelho nas estruturas)
func tabua(a: Vector2, b: Vector2, espessura: float, z := 0, pai: Node = null, cor := CINZA) -> void:
	var d := b - a
	var pts := retangulo((a + b) / 2.0, Vector2(d.length(), espessura), d.angle())
	poligono(pts, cor, z, null, 1.0, pai)

## ponte de madeira em linha reta de `a` até `b`, com postes até `base_y` e corrimão
func ponte_madeira(a: Vector2, b: Vector2, base_y: float) -> void:
	var sb := StaticBody2D.new()
	sb.collision_layer = 0b01
	sb.physics_material_override = mat
	var d := b - a
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(d.length() + 80.0, 70.0)
	cs.shape = r
	cs.position = (a + b) / 2.0 + Vector2(0, 35).rotated(d.angle())
	cs.rotation = d.angle()
	sb.add_child(cs)
	raiz.add_child(sb)
	var n := int(d.length() / 230.0)
	for i in n:                                   # tábuas com fresta mínima
		var p0 := a.lerp(b, float(i) / n) + Vector2(0, 35).rotated(d.angle())
		var p1 := a.lerp(b, float(i + 1) / n) + Vector2(0, 35).rotated(d.angle())
		tabua(p0 + (p1 - p0).normalized() * 4.0, p1 - (p1 - p0).normalized() * 4.0, 70.0, 1)
	var postes := int(d.length() / 620.0) + 1
	var topos := PackedVector2Array()
	for i in postes + 1:
		var p := a.lerp(b, float(i) / postes)
		tabua(p + Vector2(0, 60), Vector2(p.x, base_y), 60.0, -1, null, VERMELHO)  # pilar até o fundo
		tabua(p + Vector2(0, 30), p + Vector2(0, -260), 40.0, -1)               # balaústre
		topos.append(p + Vector2(0, -250))
		if i < postes:                                                          # mão-francesa em X
			var q := a.lerp(b, float(i + 1) / postes)
			var meio := (base_y + maxf(p.y, q.y)) / 2.0
			tabua(Vector2(p.x, p.y + 120), Vector2(q.x, meio), 34.0, -2, null, VERMELHO)
			tabua(Vector2(q.x, q.y + 120), Vector2(p.x, meio), 34.0, -2, null, VERMELHO)
	for i in topos.size() - 1:
		tabua(topos[i], topos[i + 1], 34.0, -1)

## rampa de salto em madeira: superfície curva (sem quina) e armação por baixo
func rampa(x0: float, x1: float, chao: float, altura: float) -> void:
	var bruto := PackedVector2Array()
	for k in 9:
		var t := k / 8.0
		bruto.append(Vector2(lerpf(x0, x1, t), chao - altura * t * t))
	var sup := suavizar(bruto, 2)
	var pts := sup.duplicate()
	pts.append(Vector2(x1, chao + 40))
	pts.append(Vector2(x0, chao + 40))
	var sb := StaticBody2D.new()
	sb.collision_layer = 0b01
	sb.physics_material_override = mat
	var col := CollisionPolygon2D.new()
	col.polygon = pts
	sb.add_child(col)
	raiz.add_child(sb)
	var n := 5
	for i in n + 1:                               # armação: postes verticais + diagonais
		var x := lerpf(x0 + 120, x1 - 30, float(i) / n)
		var y := chao - altura * pow((x - x0) / (x1 - x0), 2.0)
		tabua(Vector2(x, y + 20), Vector2(x, chao + 20), 46.0, -1)
		if i > 0:
			var xa := lerpf(x0 + 120, x1 - 30, float(i - 1) / n)
			tabua(Vector2(xa, chao), Vector2(x, y + 40), 30.0, -1)
	var pista := Line2D.new()                     # pranchão da pista
	pista.points = sup
	pista.width = 70.0
	pista.default_color = CINZA
	pista.z_index = 1
	sb.add_child(pista)
	var cont := PackedVector2Array()
	for p in sup:
		cont.append(p + Vector2(0, 36))


## pista elevada de concreto sobre treliça vermelha (estilo das rampas gigantes do
## gênero). `bruto` é a linha do topo; os apoios descem até `apoio_y`.
func pista_elevada(bruto: PackedVector2Array, apoio_y: float, espessura := 120.0) -> PackedVector2Array:
	var sup := suavizar(bruto)
	y_max = maxf(y_max, apoio_y)
	var pts := sup.duplicate()
	for i in range(sup.size() - 1, -1, -1):
		pts.append(sup[i] + Vector2(0, espessura))
	var sb := StaticBody2D.new()
	sb.collision_layer = 0b01
	sb.physics_material_override = mat
	var col := CollisionPolygon2D.new()
	col.polygon = pts
	sb.add_child(col)
	raiz.add_child(sb)
	poligono(pts, CINZA, 1, null, 1.0, sb)
	var topo := PackedVector2Array()
	var base := PackedVector2Array()
	for q in sup:
		topo.append(q + Vector2(0, 10))
		base.append(q + Vector2(0, espessura))
	linha(topo, 18.0, CINZA_CLARO, 2, sb)
	var vermelho := VERMELHO
	var x0 := sup[0].x + 150.0
	var x1 := sup[sup.size() - 1].x - 150.0
	var n := maxi(1, int((x1 - x0) / 650.0))
	var postes: Array = []
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		var y := _y_em(sup, x) + espessura
		postes.append(Vector2(x, y))
		linha(PackedVector2Array([Vector2(x, y), Vector2(x, apoio_y)]), 54.0, vermelho, -1)
	for i in n:
		var a: Vector2 = postes[i]
		var b: Vector2 = postes[i + 1]
		var y := maxf(a.y, b.y)
		var desce := true
		while y < apoio_y - 200.0:                     # zigue-zague da treliça
			var ya := y if desce else y + 650.0
			var yb := y + 650.0 if desce else y
			linha(PackedVector2Array([Vector2(a.x, minf(ya, apoio_y)), Vector2(b.x, minf(yb, apoio_y))]), 30.0, vermelho, -1)
			linha(PackedVector2Array([Vector2(a.x, y), Vector2(b.x, y)]), 22.0, vermelho.darkened(0.15), -1)
			y += 650.0
			desce = not desce
	return sup

static func _y_em(sup: PackedVector2Array, x: float) -> float:
	for i in sup.size() - 1:
		if sup[i].x <= x and x <= sup[i + 1].x:
			return lerpf(sup[i].y, sup[i + 1].y, (x - sup[i].x) / maxf(sup[i + 1].x - sup[i].x, 0.001))
	return sup[sup.size() - 1].y

## prédio de concreto com janelas; o telhado é pista
func predio(x0: float, x1: float, chao: float, altura: float) -> void:
	var sb := StaticBody2D.new()
	sb.collision_layer = 0b01
	sb.physics_material_override = mat
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(x1 - x0, altura + 200)
	cs.shape = r
	cs.position = Vector2((x0 + x1) / 2.0, chao - altura + (altura + 200) / 2.0)
	sb.add_child(cs)
	raiz.add_child(sb)
	var corpo := retangulo(cs.position, r.size)
	poligono(corpo, Color(0.85, 0.82, 0.78), 0, tex("concreto"), 2.0, sb)
	var andares := int(altura / 260.0)
	for a in andares:
		var y := chao - altura + 120 + a * 260
		var x := x0 + 110
		while x < x1 - 200:
			var jan := retangulo(Vector2(x + 70, y + 60), Vector2(140, 120))
			poligono(jan, Color(0.45, 0.62, 0.78), 0, null, 1.0, sb)
			poligono(retangulo(Vector2(x + 40, y + 40), Vector2(40, 70)), Color(0.75, 0.86, 0.95), 0, null, 1.0, sb)
			linha(_fechar(jan), 10.0, CONTORNO_METAL, 0, sb)
			x += 240
	var beiral := retangulo(Vector2((x0 + x1) / 2.0, chao - altura + 20), Vector2(x1 - x0 + 40, 40))
	poligono(beiral, Color(0.5, 0.48, 0.46), 1, null, 1.0, sb)
	linha(_fechar(corpo), LARG_CONTORNO * 1.4, CONTORNO_METAL, 1, sb)

# ---------- metal ----------
func barra_metal(a: Vector2, b: Vector2, espessura: float, cor: Color, z := -1, pai: Node = null) -> void:
	linha(PackedVector2Array([a, b]), espessura, cor, z, pai)

## treliça entre dois banzos paralelos (a0→a1 em cima, b0→b1 embaixo) com diagonais em X
func trelica(a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2, vaos: int, cor: Color, grossura := 46.0, z := -2) -> void:
	for i in vaos:
		var t0 := float(i) / vaos
		var t1 := float(i + 1) / vaos
		barra_metal(a0.lerp(a1, t0), b0.lerp(b1, t1), grossura * 0.55, cor, z)
		barra_metal(b0.lerp(b1, t0), a0.lerp(a1, t1), grossura * 0.55, cor, z)
		barra_metal(a0.lerp(a1, t0), b0.lerp(b1, t0), grossura * 0.7, cor, z)
	barra_metal(a1, b1, grossura * 0.7, cor, z)
	barra_metal(a0, a1, grossura, cor, z)
	barra_metal(b0, b1, grossura, cor, z)

## guindaste de torre: torre em treliça, lança comprida, contralança com contrapeso
## e carrinho. Retorna o ponto do carrinho (onde prender a corrente).
func guindaste(torre_x: float, chao: float, lanca_y: float, ponta_x: float, carrinho_x: float, moitao := Vector2.ZERO) -> Vector2:
	var larg := 300.0
	var topo := lanca_y - 260.0
	trelica(Vector2(torre_x - larg / 2, chao), Vector2(torre_x - larg / 2, topo),
		Vector2(torre_x + larg / 2, chao), Vector2(torre_x + larg / 2, topo), int((chao - topo) / 300.0), AMARELO)
	var base := retangulo(Vector2(torre_x, chao + 10), Vector2(larg + 260, 120))
	poligono(base, Color(0.55, 0.56, 0.58), -1)
	linha(_fechar(base), LARG_CONTORNO, CONTORNO_METAL, -1)
	var altura := 230.0                            # lança
	trelica(Vector2(ponta_x, lanca_y - altura), Vector2(torre_x + larg / 2, lanca_y - altura),
		Vector2(ponta_x, lanca_y), Vector2(torre_x + larg / 2, lanca_y), int(absf(torre_x - ponta_x) / 260.0), AMARELO, 40.0)
	var contra_x := torre_x + larg / 2 + 1300.0    # contralança
	trelica(Vector2(torre_x + larg / 2, lanca_y - altura), Vector2(contra_x, lanca_y - altura),
		Vector2(torre_x + larg / 2, lanca_y), Vector2(contra_x, lanca_y), 5, AMARELO, 40.0)
	var peso := retangulo(Vector2(contra_x - 260, lanca_y + 210), Vector2(420, 380))
	poligono(peso, Color(0.6, 0.6, 0.62), -1, tex("perigo"), 3.0)
	linha(_fechar(peso), LARG_CONTORNO, CONTORNO_METAL, -1)
	var pico := Vector2(torre_x, topo - 700)       # mastro e tirantes
	barra_metal(Vector2(torre_x - 120, topo), pico, 44.0, AMARELO, -2)
	barra_metal(Vector2(torre_x + 120, topo), pico, 44.0, AMARELO, -2)
	linha(PackedVector2Array([pico, Vector2(ponta_x + 300, lanca_y - altura)]), 14.0, CONTORNO_METAL, -2)
	linha(PackedVector2Array([pico, Vector2(contra_x, lanca_y - altura)]), 14.0, CONTORNO_METAL, -2)
	var cabine := retangulo(Vector2(torre_x - larg / 2 - 140, lanca_y + 150), Vector2(300, 260))
	poligono(cabine, AMARELO.darkened(0.1), -1)
	poligono(retangulo(Vector2(torre_x - larg / 2 - 180, lanca_y + 120), Vector2(170, 130)), Color(0.55, 0.8, 0.95), -1)
	linha(_fechar(cabine), LARG_CONTORNO, CONTORNO_METAL, -1)
	var carro := retangulo(Vector2(carrinho_x, lanca_y + 40), Vector2(260, 90))
	poligono(carro, Color(0.35, 0.37, 0.42), -1)
	linha(_fechar(carro), LARG_CONTORNO, CONTORNO_METAL, -1)
	if moitao != Vector2.ZERO:                      # cabos até o moitão (onde a corrente prende)
		for k in [-40.0, 40.0]:
			linha(PackedVector2Array([Vector2(carrinho_x + k, lanca_y + 80), moitao + Vector2(k, -60)]), 12.0, CONTORNO_METAL, -1)
		var bloco := retangulo(moitao + Vector2(0, -50), Vector2(150, 130))
		poligono(bloco, AMARELO, 0)
		poligono(retangulo(moitao + Vector2(0, -50), Vector2(150, 34)), Color.WHITE, 0, tex("perigo"), 0.5)
		linha(_fechar(bloco), LARG_CONTORNO, CONTORNO_METAL, 0)
		return moitao
	return Vector2(carrinho_x, lanca_y + 85)

## visual da bola de demolição (corpo físico fica com a fase); devolve a corrente
func vestir_bola(bola: Node2D, raio: float) -> Line2D:
	var s := Sprite2D.new()
	s.texture = tex("bola_demolicao")
	s.scale = Vector2.ONE * (raio * 2.0 / 560.0)
	s.position = Vector2(0, -raio * 0.06)
	bola.add_child(s)
	var c := Line2D.new()
	c.width = 64.0
	c.texture = _tex_elo()
	c.texture_mode = Line2D.LINE_TEXTURE_TILE
	c.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	c.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	c.z_index = -1
	raiz.add_child(c)
	return c

## passarela de viga de aço sobre um vão, apoiada em pilares de treliça até `base_y`
func passarela(x0: float, x1: float, topo: float, base_y: float, pilares: Array) -> void:
	var sb := StaticBody2D.new()
	sb.collision_layer = 0b01
	sb.physics_material_override = mat
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(x1 - x0, 110)
	cs.shape = r
	cs.position = Vector2((x0 + x1) / 2.0, topo + 55)
	sb.add_child(cs)
	raiz.add_child(sb)
	var corpo := retangulo(Vector2((x0 + x1) / 2.0, topo + 55), Vector2(x1 - x0, 110))
	poligono(corpo, CINZA, 1, null, 1.0, sb)
	for x in pilares:
		var px: float = x
		trelica(Vector2(px - 130, topo + 110), Vector2(px - 130, base_y), Vector2(px + 130, topo + 110), Vector2(px + 130, base_y),
			int((base_y - topo) / 280.0), VERMELHO, 40.0)
	var gc := PackedVector2Array()                 # guarda-corpo atrás
	var n := int((x1 - x0) / 400.0)
	for i in n + 1:
		var x := lerpf(x0 + 40, x1 - 40, float(i) / n)
		barra_metal(Vector2(x, topo), Vector2(x, topo - 280), 18.0, Color(0.55, 0.6, 0.68), -1)
		gc.append(Vector2(x, topo - 280))
	barra_metal(gc[0], gc[gc.size() - 1], 18.0, Color(0.55, 0.6, 0.68), -1)

# ---------- perigos ----------
## fileira de espinhos metálicos sombreados sobre uma base listrada; zona letal
func espinhos(x0: float, x1: float, chao: float, alt := 300.0) -> void:
	var larg := 110.0
	var n := int((x1 - x0) / larg)
	for i in n:
		var cx := x0 + (i + 0.5) * (x1 - x0) / n
		var esq := PackedVector2Array([Vector2(cx - larg / 2, chao), Vector2(cx, chao - alt), Vector2(cx, chao)])
		var dir := PackedVector2Array([Vector2(cx, chao), Vector2(cx, chao - alt), Vector2(cx + larg / 2, chao)])
		poligono(esq, Color(0.86, 0.88, 0.93), 1)
		poligono(dir, Color(0.55, 0.58, 0.66), 1)
		linha(PackedVector2Array([Vector2(cx - larg / 2, chao), Vector2(cx, chao - alt), Vector2(cx + larg / 2, chao)]), 10.0, CONTORNO_METAL, 1)
	var base := PackedVector2Array([Vector2(x0, chao - 10), Vector2(x1, chao - 10), Vector2(x1, chao + 60), Vector2(x0, chao + 60)])
	poligono(base, Color.WHITE, 1, tex("perigo"), 1.4)
	linha(_fechar(base), 10.0, CONTORNO_METAL, 1)
	zona_letal(Vector2((x0 + x1) / 2.0, chao - alt * 0.45), Vector2(x1 - x0, alt * 0.9), "espetos")

## água: superfície ondulada (shader), translúcida, mata quem afunda
func agua(x0: float, x1: float, sup: float, fundo: float) -> void:
	var pts := PackedVector2Array()
	var n := int((x1 - x0) / 60.0)
	for i in n + 1:
		pts.append(Vector2(lerpf(x0, x1, float(i) / n), sup))
	pts.append(Vector2(x1, fundo))
	pts.append(Vector2(x0, fundo))
	var p := poligono(pts, Color(0.18, 0.5, 0.85, 0.78), 3)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float sup;
varying float prof;
void vertex() {
	if (VERTEX.y < sup + 1.0) {
		VERTEX.y += sin(VERTEX.x * 0.006 + TIME * 2.2) * 22.0 + sin(VERTEX.x * 0.017 - TIME * 3.1) * 9.0;
	}
	prof = VERTEX.y - sup;
}
void fragment() {
	float k = clamp(prof / 500.0, 0.0, 1.0);
	COLOR.rgb = mix(vec3(0.38, 0.72, 0.97), vec3(0.08, 0.27, 0.6), k);
	COLOR.a = mix(0.82, 0.95, k);
	if (prof < 18.0) { COLOR.rgb = vec3(0.85, 0.95, 1.0); }
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("sup", sup)
	p.material = m
	var a := zona_letal(Vector2((x0 + x1) / 2.0, (sup + fundo) / 2.0 + 60.0), Vector2(x1 - x0, fundo - sup), "agua")
	a.body_entered.connect(func(b: Node2D) -> void:
		respingo(Vector2(b.global_position.x, sup)))

func serra(centro: Vector2, raio: float) -> void:
	var s := Sprite2D.new()
	s.texture = tex("serra")
	s.scale = Vector2.ONE * (raio * 2.0 / 600.0)
	s.position = centro
	s.z_index = 1
	raiz.add_child(s)
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "rotation", TAU, 0.6).as_relative()
	zona_letal(centro, Vector2(raio * 1.7, raio * 1.7), "serra")

func zona_letal(centro: Vector2, tamanho: Vector2, motivo: String) -> Area2D:
	var a := Area2D.new()
	a.position = centro
	a.collision_layer = 0
	a.collision_mask = 0b110
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = tamanho
	cs.shape = r
	a.add_child(cs)
	raiz.add_child(a)
	a.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("veiculo") or b.is_in_group("piloto"):
			perigo.call(b, motivo))
	return a

# ---------- objetos ----------
func caixa(pos: Vector2, lado: float) -> RigidBody2D:
	var c := RigidBody2D.new()
	c.mass = 1.5
	c.collision_layer = 0b1000
	c.collision_mask = 0b1111
	c.physics_material_override = mat
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(lado, lado)
	cs.shape = r
	c.add_child(cs)
	var s := Sprite2D.new()
	s.texture = tex("caixa")
	s.scale = Vector2.ONE * lado / 256.0
	c.add_child(s)
	c.position = pos
	c.contact_monitor = true
	c.max_contacts_reported = 2
	c.body_entered.connect(func(_b: Node) -> void:
		if c.linear_velocity.length() > 250.0: som("caixa", c.global_position, c.linear_velocity.length() / 900.0))
	raiz.add_child(c)
	return c

## barril de TNT: explode quando leva pancada (impulso radial, clarão, fogo, fumaça)
func tnt(pos: Vector2, altura := 560.0) -> RigidBody2D:
	var c := RigidBody2D.new()
	c.mass = 1.2
	c.collision_layer = 0b1000
	c.collision_mask = 0b1111
	c.physics_material_override = mat
	var esc := altura / 300.0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(200, 290) * esc
	cs.shape = r
	c.add_child(cs)
	var s := Sprite2D.new()
	s.texture = tex("tnt")
	s.scale = Vector2.ONE * esc
	c.add_child(s)
	var rotulo := Label.new()
	rotulo.text = "TNT"
	rotulo.add_theme_font_size_override("font_size", 110)
	rotulo.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	rotulo.add_theme_color_override("font_outline_color", Color(0.25, 0.03, 0.02))
	rotulo.add_theme_constant_override("outline_size", 22)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.size = Vector2(220, 140)
	rotulo.position = Vector2(-110, -60)
	rotulo.scale = Vector2.ONE * esc * 0.5
	rotulo.pivot_offset = Vector2(110, 70)
	c.add_child(rotulo)
	c.position = pos - Vector2(0, altura / 2.0)
	c.contact_monitor = true
	c.max_contacts_reported = 4
	c.body_entered.connect(func(b: Node) -> void:
		if c.has_meta("explodiu"):
			return
		var rel := c.linear_velocity
		if b is RigidBody2D:
			rel -= (b as RigidBody2D).linear_velocity
		if rel.length() > 180.0 or b.is_in_group("veiculo") or b.is_in_group("piloto"):
			c.set_meta("explodiu", true)
			explodir.call_deferred(c.global_position, 1700.0, 760.0)
			c.queue_free.call_deferred())
	raiz.add_child(c)
	return c

func explodir(pos: Vector2, raio: float, dv_max: float) -> void:
	if ao_explodir.is_valid():
		ao_explodir.call(pos, raio)
	som("impacto_forte", pos, 1.0)
	som("metal", pos, 0.8)
	for n in raiz.get_tree().get_nodes_in_group("veiculo") + raiz.get_tree().get_nodes_in_group("piloto"):
		_empurrar(n, pos, raio, dv_max)
	for n in raiz.get_children():
		if n is RigidBody2D and not n.is_in_group("veiculo"):
			_empurrar(n, pos, raio, dv_max)
	var flash := Sprite2D.new()
	flash.texture = _brilho
	flash.modulate = Color(1, 0.85, 0.4, 0.95)
	flash.position = pos
	flash.scale = Vector2.ONE * raio / 40.0
	flash.z_index = 30
	raiz.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.45)
	tw.tween_callback(flash.queue_free)
	particulas(pos, 45, Color(1, 0.75, 0.2), Color(0.95, 0.2, 0.05, 0.0), 900.0, 2000.0, 0.8, 260.0, 520.0)
	particulas(pos, 26, Color(0.3, 0.28, 0.27, 0.95), Color(0.55, 0.55, 0.55, 0.0), 250.0, 800.0, 2.6, 420.0, 900.0, -300.0)
	particulas(pos, 14, Color(0.75, 0.15, 0.1), Color(0.3, 0.05, 0.05, 0.0), 700.0, 1400.0, 1.4, 30.0, 50.0, 1200.0)

func _empurrar(n: Node, pos: Vector2, raio: float, dv_max: float) -> void:
	if not (n is RigidBody2D):
		return
	var rb := n as RigidBody2D
	var d := rb.global_position - pos
	if d.length() > raio:
		return
	var dir := (d.normalized() + Vector2(0, -0.6)).normalized()
	rb.apply_central_impulse(dir * dv_max * (1.0 - d.length() / raio) * rb.mass)

## prensa hidráulica: pórtico de aço, cilindro e cabeça que desce de golpe e sobe devagar.
## Ciclo normalizado: 0–6% desce, até 16% segura embaixo, até 40% sobe, resto parada no alto.
func prensa(x: float, chao: float, periodo := 4.5, atraso := 0.0) -> AnimatableBody2D:
	var larg := 620.0
	var alto := chao - 1800.0
	var cinza := Color(0.55, 0.6, 0.68)
	trelica(Vector2(x - larg / 2 - 160, chao), Vector2(x - larg / 2 - 160, alto - 500), Vector2(x - larg / 2 - 20, chao),
		Vector2(x - larg / 2 - 20, alto - 500), 7, cinza, 36.0)
	trelica(Vector2(x + larg / 2 + 20, chao), Vector2(x + larg / 2 + 20, alto - 500), Vector2(x + larg / 2 + 160, chao),
		Vector2(x + larg / 2 + 160, alto - 500), 7, cinza, 36.0)
	trelica(Vector2(x - larg / 2 - 160, alto - 700), Vector2(x + larg / 2 + 160, alto - 700), Vector2(x - larg / 2 - 160, alto - 500),
		Vector2(x + larg / 2 + 160, alto - 500), 5, cinza, 40.0)
	var cil := retangulo(Vector2(x, alto - 300), Vector2(220, 420))
	poligono(cil, Color(0.78, 0.2, 0.16), -1)
	poligono(retangulo(Vector2(x - 60, alto - 300), Vector2(40, 380)), Color(0.92, 0.45, 0.38), -1)
	linha(_fechar(cil), LARG_CONTORNO, CONTORNO_METAL, -1)
	var cabeca := AnimatableBody2D.new()
	cabeca.sync_to_physics = false
	cabeca.collision_layer = 0b11000
	cabeca.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(larg, 300)
	cs.shape = r
	cabeca.add_child(cs)
	var corpo := retangulo(Vector2.ZERO, Vector2(larg, 300))
	poligono(corpo, Color.WHITE, 1, tex("metal"), 1.2, cabeca)
	poligono(retangulo(Vector2(0, 110), Vector2(larg, 80)), Color.WHITE, 1, tex("perigo"), 0.8, cabeca)
	linha(_fechar(corpo), LARG_CONTORNO, CONTORNO_METAL, 1, cabeca)
	cabeca.position = Vector2(x, alto + 150)
	raiz.add_child(cabeca)
	var haste := linha(PackedVector2Array([Vector2(x, alto - 100), cabeca.position]), 90.0, Color(0.82, 0.84, 0.88), 0)
	cabeca.add_to_group("pistao")
	cabeca.set_meta("x", x)
	cabeca.set_meta("fase", 0.5)
	cabeca.set_meta("T", periodo)
	cabeca.set_meta("atraso", atraso)
	cabeca.set_meta("topo", alto + 150)
	cabeca.set_meta("fundo", chao - 180.0)
	cabeca.set_meta("chao", chao)
	pistoes.append({"cabeca": cabeca, "haste": haste, "topo": alto + 150, "fundo": chao - 150 - 30,
		"T": periodo, "atraso": atraso, "embaixo": false})
	var zona := zona_letal(Vector2.ZERO, Vector2(larg - 40, 80), "prensa")
	raiz.remove_child(zona)
	zona.position = Vector2(0, 150)
	cabeca.add_child(zona)
	zona.monitoring = false
	cabeca.set_meta("zona", zona)
	return cabeca

static func descida_prensa(f: float) -> float:
	if f < 0.06: return ease(f / 0.06, 2.4)
	if f < 0.16: return 1.0
	if f < 0.40: return 1.0 - smoothstep(0.16, 0.40, f)
	return 0.0

func mover_pistoes(t: float) -> void:
	for p in pistoes:
		var c: AnimatableBody2D = p["cabeca"]
		var f := fposmod(t + float(p["atraso"]), float(p["T"])) / float(p["T"])
		var k := descida_prensa(f)
		c.position.y = lerpf(p["topo"], p["fundo"], k)
		c.set_meta("fase", f)
		(p["haste"] as Line2D).set_point_position(1, c.position)
		var desce := f < 0.06
		(c.get_meta("zona") as Area2D).monitoring = desce          # só esmaga quando está descendo
		var bateu := k >= 0.999
		if bateu and not p["embaixo"]:
			som("metal", c.position, 1.0)
			poeira(Vector2(c.position.x - 250, p["fundo"] + 170), 1.2)
			poeira(Vector2(c.position.x + 250, p["fundo"] + 170), 1.2)
		p["embaixo"] = bateu

# ---------- placas e decoração ----------
func placa(pos: Vector2, texto: String, chegada := false) -> void:
	var s := Sprite2D.new()
	s.texture = tex("placa_chegada" if chegada else "placa_largada")
	s.centered = false
	var esc := 1.5
	s.scale = Vector2.ONE * esc
	s.position = pos - Vector2(450, 1100) * esc
	s.z_index = -1
	raiz.add_child(s)
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 120)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 18)
	l.position = Vector2(40, 70 if chegada else 40)
	l.size = Vector2(820, 260 if chegada else 290)
	s.add_child(l)

## pórtico de chegada: dois pilares, faixa quadriculada no alto com CHEGADA e
## chão quadriculado entre eles
func portal_chegada(base: Vector2) -> void:
	var vao := 1400.0
	var alto := 1950.0
	for x in [base.x, base.x + vao]:
		poligono(retangulo(Vector2(x, base.y - alto / 2.0), Vector2(110, alto)), CINZA, -1)
		var y := base.y - 300.0
		while y > base.y - alto + 200.0:                   # listras vermelhas no pilar
			poligono(retangulo(Vector2(x, y), Vector2(110, 90)), VERMELHO, -1)
			y -= 300.0
		poligono(retangulo(Vector2(x, base.y - alto - 60), Vector2(180, 120)), VERMELHO.darkened(0.2), -1)
	var faixa_y := base.y - alto + 180.0
	var cols := 14
	var lado := (vao + 110.0) / cols
	for i in cols:
		for j in 3:
			var cor := Color.BLACK if (i + j) % 2 == 0 else Color.WHITE
			poligono(retangulo(Vector2(base.x - 55 + (i + 0.5) * lado, faixa_y + (j - 1) * lado), Vector2(lado, lado)), cor, 1)
	var placa_c := retangulo(Vector2(base.x + vao / 2.0, faixa_y), Vector2(900, 230))
	poligono(placa_c, VERMELHO, 2)
	var l := Label.new()
	l.text = "CHEGADA"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 170)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 24)
	l.size = Vector2(900, 230)
	l.position = Vector2(base.x + vao / 2.0 - 450, faixa_y - 115)
	l.z_index = 3
	raiz.add_child(l)
	var cols_chao := 16
	var lc := vao / cols_chao
	for i in cols_chao:
		for j in 2:
			var cor := Color.BLACK if (i + j) % 2 == 0 else Color.WHITE
			poligono(retangulo(Vector2(base.x + (i + 0.5) * lc, base.y + 20 + j * 40), Vector2(lc, 40)), cor, 3)
	for k in 6:                                            # bandeirinhas penduradas
		var px := base.x + 120 + k * (vao - 240) / 5.0
		var py := faixa_y + 1.6 * lado
		poligono(PackedVector2Array([Vector2(px - 50, py), Vector2(px + 50, py), Vector2(px, py + 120)]),
			[Color(0.95, 0.25, 0.2), Color(1, 0.8, 0.15), Color(0.2, 0.6, 1.0)][k % 3], 1)

## festa da vitória: confete caindo sobre o jogador e fogos estourando no pórtico
func festa(portal: Vector2, jogador: Vector2) -> void:
	var cores := [Color(1, 0.25, 0.25), Color(1, 0.85, 0.2), Color(0.3, 0.7, 1), Color(0.3, 0.95, 0.4), Color(0.95, 0.4, 1)]
	for c in cores:
		particulas(jogador + Vector2(0, -900), 70, c, Color(c, 0.0), 500.0, 1600.0, 3.5, 40.0, 80.0, 700.0, Vector2.UP, 160.0)
	for k in 8:
		var alvo := jogador + Vector2(randf_range(-1600, 2200), randf_range(-1900, -1100))
		var cor: Color = cores[k % cores.size()]
		raiz.get_tree().create_timer(0.25 * k).timeout.connect(func() -> void:
			if not raiz.is_inside_tree():
				return
			Audio.tocar("impacto_forte", 0.6)
			particulas(alvo, 70, cor.lightened(0.3), Color(cor, 0.0), 700.0, 1500.0, 1.4, 40.0, 80.0, 600.0, Vector2.UP, 180.0))

func sprite(nome: String, base: Vector2, escala := 1.0, z := -3, espelhar := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(nome)
	s.centered = false
	s.scale = Vector2(-escala if espelhar else escala, escala)
	var w := s.texture.get_width() * escala
	s.position = base - Vector2(-w / 2.0 if espelhar else w / 2.0, s.texture.get_height() * escala - 20.0)
	s.z_index = z
	raiz.add_child(s)
	return s

## placa triangular de aviso (mina à frente)
func placa_perigo(base: Vector2) -> void:
	tabua(base, base + Vector2(0, -620), 34.0, -1, null, Color(0.3, 0.3, 0.32))
	var c := base + Vector2(0, -760)
	var tri := PackedVector2Array([c + Vector2(0, -170), c + Vector2(190, 130), c + Vector2(-190, 130)])
	poligono(tri, AMARELO, -1)
	linha(_fechar(tri), 22.0, Color(0.12, 0.12, 0.12), -1)
	poligono(Pecas.retangulo(c + Vector2(0, -15), Vector2(30, 140)), Color(0.12, 0.12, 0.12), -1)
	poligono(Pecas.retangulo(c + Vector2(0, 85), Vector2(30, 30)), Color(0.12, 0.12, 0.12), -1)

func cone(base: Vector2, escala := 1.6) -> void:
	sprite("cone", base, escala, -1)

func cerca(x0: float, x1: float, chao: float, escala := 2.2) -> void:
	var w := 400.0 * escala
	var x := x0
	while x < x1:
		sprite("cerca", Vector2(x + w / 2.0, chao), escala, -2)
		x += w - 10.0

# ---------- partículas ----------
func particulas(pos: Vector2, qtd: int, cor0: Color, cor1: Color, v0: float, v1: float, vida: float,
		tam0: float, tam1: float, grav := 900.0, dir := Vector2.UP, espalha := 180.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.texture = _brilho
	p.amount = qtd
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = vida
	p.direction = dir
	p.spread = espalha
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = Vector2(0, grav)
	p.damping_min = 40.0
	p.damping_max = 120.0
	p.scale_amount_min = tam0 / 32.0
	p.scale_amount_max = tam1 / 32.0
	var g := Gradient.new()
	g.set_color(0, cor0)
	g.set_color(1, cor1)
	p.color_ramp = g
	p.z_index = 25
	if not raiz.is_inside_tree():
		p.free()
		return
	raiz.add_child(p)
	p.emitting = true
	raiz.get_tree().create_timer(vida + 0.5).timeout.connect(p.queue_free)

func poeira(pos: Vector2, forca := 1.0) -> void:
	particulas(pos, int(10 + 16 * forca), Color(0.72, 0.6, 0.45, 0.85), Color(0.72, 0.6, 0.45, 0.0),
		200.0, 500.0 + 500.0 * forca, 0.9, 60.0, 140.0, 300.0, Vector2.UP, 75.0)

func respingo(pos: Vector2) -> void:
	particulas(pos, 40, Color(0.85, 0.95, 1.0, 0.95), Color(0.4, 0.7, 1.0, 0.0), 500.0, 1300.0, 1.1, 30.0, 70.0, 1400.0, Vector2.UP, 40.0)

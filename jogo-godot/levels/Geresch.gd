extends Node2D
class_name Geresch
## Chefe da fase 8: o Geresch no fundo, jogando Block Blast no celular. A luta alterna:
##  1) DESVIO: peças do Block Blast saem do celular e caem na arena (sombra antes);
##  2) JOGO: a tela vira o Block Blast; cada linha fechada dá dano, combo dá mais.
## Ele fica mais bravo a cada fase (4 imagens): mais peças e menos tempo pra jogar.
## Temporização em segundos REAIS.

signal derrotado

const VIDA_MAX := 18
const CEL := 230.0
const CORES := [Color(1.0, 0.6, 0.15), Color(0.95, 0.3, 0.42), Color(0.3, 0.82, 0.45), Color(0.18, 0.8, 0.68),
	Color(0.25, 0.65, 0.98), Color(0.55, 0.45, 0.98), Color(1.0, 0.82, 0.2)]
const FORMAS := [[[0, 0], [1, 0]], [[0, 0], [1, 0], [2, 0]], [[0, 0], [1, 0], [0, 1], [1, 1]],
	[[0, 0], [0, 1], [1, 1]], [[0, 0], [1, 0], [2, 0], [1, 1]], [[0, 0], [1, 0], [2, 0], [3, 0]],
	[[0, 0], [0, 1], [0, 2]], [[0, 0], [1, 0], [1, 1], [2, 1]]]
const DESVIO := [16.0, 14.0, 12.0, 11.0]          # segundos desviando, por fase de raiva
const JOGO := [26.0, 23.0, 20.0, 18.0]            # segundos de Block Blast
const RITMO := [1.5, 1.2, 0.95, 0.75]             # intervalo entre peças caindo

var fase: Node2D
var chao := 1000.0
var x0 := 0.0
var x1 := 0.0
var vida := VIDA_MAX
var ativo := false
var morto := false
var _estado := "espera"
var _t := 0.0
var _timer := 3.0
var _prox := 1.0
var _queda: Array = []
var _camada: CanvasLayer
var _img: Sprite2D
var _estagio := -1
var _barra: ColorRect
var _barra_fundo: ColorRect
var _rotulo: Label
var _jogo: Control
var _fim_t := 0.0

func _real(d: float) -> float:
	return d / Engine.time_scale

func montar(main: Node2D, xa: float, xb: float, y: float) -> void:
	fase = main
	x0 = xa
	x1 = xb
	chao = y

func estagio() -> int:
	return 0 if vida > 13 else (1 if vida > 9 else (2 if vida > 4 else 3))

func comecar() -> void:
	if ativo:
		return
	ativo = true
	_estado = "desvio"
	_timer = DESVIO[0]
	_camada = CanvasLayer.new()
	_camada.layer = -50
	fase.add_child(_camada)
	_img = Sprite2D.new()
	_camada.add_child(_img)
	_trocar_imagem()
	var hud: CanvasLayer = fase.get_node("HUD")
	_barra_fundo = ColorRect.new()
	_barra_fundo.color = Color(0, 0, 0, 0.7)
	_barra_fundo.size = Vector2(620, 40)
	hud.add_child(_barra_fundo)
	_barra = ColorRect.new()
	_barra.color = Color(0.95, 0.3, 0.6)
	_barra.size = Vector2(600, 24)
	hud.add_child(_barra)
	_rotulo = Label.new()
	_rotulo.text = "GERESCH"
	_rotulo.add_theme_font_size_override("font_size", 30)
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 8)
	hud.add_child(_rotulo)
	fase._mensagem("DESVIA DAS PEÇAS!", Color(1, 0.8, 0.3))

func _trocar_imagem() -> void:
	var e := estagio()
	if e == _estagio:
		return
	_estagio = e
	_img.texture = load("res://assets/geresch/e%d.png" % e)
	if e > 0 and _rotulo:
		fase._mensagem(["", "O GERESCH TÁ FICANDO SÉRIO...", "O GERESCH TÁ BRAVO!", "O GERESCH TÁ FURIOSO!!!"][e], Color(1, 0.35, 0.35))

func atualizar(delta: float) -> void:
	if not ativo:
		return
	var dt := _real(delta)
	_t += dt
	var v := fase.get_viewport().get_visible_rect().size
	var esc := v.y * 0.78 / 1560.0
	var treme := (2.0 + 6.0 * _estagio) if _estagio >= 2 else 0.0
	_img.position = Vector2(v.x * 0.74, v.y * 0.5 + sin(_t * 1.4) * 6.0) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * treme
	_img.scale = Vector2.ONE * esc
	if morto:
		_fim_t += dt
		_img.modulate.a = maxf(0.0, 1.0 - _fim_t / 1.5)
		_img.rotation = _fim_t * 0.6
		_img.position.y += _fim_t * _fim_t * 300.0
		if _fim_t > 1.6 and _fim_t - dt <= 1.6:
			derrotado.emit()
		return
	_barra_fundo.position = Vector2(v.x / 2.0 - 310, 112)
	_barra.position = _barra_fundo.position + Vector2(10, 8)
	_barra.size.x = 600.0 * float(vida) / VIDA_MAX
	_rotulo.position = _barra_fundo.position + Vector2(0, -38)
	for q in _queda.duplicate():
		_passo_peca(q, dt)
	if not fase.ativo:
		return
	match _estado:
		"desvio":
			_timer -= dt
			_prox -= dt
			if _prox <= 0.0:
				_prox = RITMO[_estagio]
				_soltar()
				if _estagio >= 2 and randf() < 0.5:
					_soltar()
			if _timer <= 0.0:
				_estado = "aviso"
				_timer = 1.6
				fase._mensagem("ELE TÁ JOGANDO... ENTRA NO JOGO!", Color(0.6, 0.9, 1.0))
				Audio.tocar("checkpoint", 1.0)
		"aviso":
			_timer -= dt
			if _timer <= 0.0 and _queda.is_empty():
				_abrir_jogo()

## peça do Block Blast caindo do céu perto de você (sombra marcando onde cai)
func _soltar() -> void:
	var pl: Player = fase.player
	if not is_instance_valid(pl) or not is_instance_valid(pl.chassi):
		return
	var forma: Array = FORMAS[randi() % FORMAS.size()]
	var largura := 0
	var altura := 0
	for c in forma:
		largura = maxi(largura, int(c[0]) + 1)
		altura = maxi(altura, int(c[1]) + 1)
	var vx: float = pl.chassi.linear_velocity.x if pl.montado else 0.0
	var alvo := pl.foco().global_position.x + vx * Engine.time_scale * 0.5 + randf_range(-900, 900)
	alvo = clampf(alvo, x0 + 400.0 + largura * CEL / 2.0, x1 - 400.0 - largura * CEL / 2.0)
	var cor: Color = CORES[randi() % CORES.size()]
	var no := Node2D.new()
	no.z_index = 6
	for c in forma:
		_celula(no, Vector2((int(c[0]) - largura / 2.0) * CEL, (int(c[1]) - altura) * CEL), cor)
	no.position = Vector2(alvo, chao - 4500.0)
	fase.add_child(no)
	var sombra := Polygon2D.new()
	var w := largura * CEL / 2.0
	sombra.polygon = PackedVector2Array([Vector2(-w, -20), Vector2(w, -20), Vector2(w, 10), Vector2(-w, 10)])
	sombra.color = Color(cor, 0.0)
	sombra.position = Vector2(alvo, chao)
	sombra.z_index = 4
	fase.add_child(sombra)
	_queda.append({"no": no, "sombra": sombra, "t": 0.0, "vy": 0.0, "w": w, "h": altura * CEL, "x": alvo, "caindo": true})

func _celula(pai: Node2D, canto: Vector2, cor: Color) -> void:
	var r := CEL * 0.92
	var o := canto + Vector2(CEL * 0.04, CEL * 0.04)
	var base := Polygon2D.new()
	base.polygon = PackedVector2Array([o, o + Vector2(r, 0), o + Vector2(r, r), o + Vector2(0, r)])
	base.color = cor.darkened(0.2)
	pai.add_child(base)
	var topo := Polygon2D.new()
	topo.polygon = PackedVector2Array([o, o + Vector2(r, 0), o + Vector2(r, r * 0.86), o + Vector2(0, r * 0.86)])
	topo.color = cor
	pai.add_child(topo)
	var brilho := Polygon2D.new()
	brilho.polygon = PackedVector2Array([o + Vector2(r * 0.18, r * 0.1), o + Vector2(r * 0.82, r * 0.1), o + Vector2(r * 0.82, r * 0.2), o + Vector2(r * 0.18, r * 0.2)])
	brilho.color = Color(1, 1, 1, 0.5)
	pai.add_child(brilho)

func _passo_peca(q: Dictionary, dt: float) -> void:
	q["t"] += dt
	var no: Node2D = q["no"]
	if q["caindo"]:
		var sombra: Polygon2D = q["sombra"]
		if q["t"] < 0.8:                                # aviso: sombra piscando
			sombra.color.a = 0.6 if fmod(q["t"], 0.16) < 0.1 else 0.25
			return
		sombra.color.a = 0.55
		q["vy"] = float(q["vy"]) + 9000.0 * dt
		no.position.y += float(q["vy"]) * dt
		_acerta(q)
		if no.position.y >= chao:
			no.position.y = chao
			q["caindo"] = false
			q["t"] = 0.0
			sombra.queue_free()
			fase.pecas.poeira(Vector2(no.position.x, chao), 1.2)
			Audio.tocar("caixa", 0.9)
	elif q["t"] > 0.25:                                 # no chão: some (não fica no caminho)
		no.modulate.a = maxf(0.0, 1.0 - (float(q["t"]) - 0.25) / 0.4)
		if q["t"] > 0.65:
			no.queue_free()
			_queda.erase(q)

func _acerta(q: Dictionary) -> void:
	var pl: Player = fase.player
	if not is_instance_valid(pl) or (pl.imortal_t > 0.0 and pl.montado):
		return
	var no: Node2D = q["no"]
	var corpos: Array = ([pl.chassi] + pl.membros.values()) if pl.montado and is_instance_valid(pl.chassi) else pl.corpos.values()
	for b in corpos:
		var p: Vector2 = (b as Node2D).global_position
		if absf(p.x - float(q["x"])) < float(q["w"]) and p.y > no.position.y - float(q["h"]) and p.y < no.position.y:
			if pl.repelir(p):
				return
			fase._on_perigo(b, "esmagado")
			return

## a tela vira o Block Blast (jogo pausado); o dano sai quando o tempo acaba
func _abrir_jogo() -> void:
	_estado = "jogo"
	var cena := CanvasLayer.new()
	cena.layer = 70
	cena.process_mode = Node.PROCESS_MODE_ALWAYS
	fase.add_child(cena)
	var bb: Control = load("res://levels/BlockBlast.gd").new()
	bb.duracao = JOGO[_estagio]
	bb.modulate.a = 0.0
	cena.add_child(bb)
	_jogo = bb
	fase.get_tree().paused = true
	var tw := bb.create_tween()
	tw.tween_property(bb, "modulate:a", 1.0, 0.35)
	bb.acabou.connect(func(d: int) -> void:
		var tw2 := bb.create_tween()
		tw2.tween_interval(0.6)
		tw2.tween_property(bb, "modulate:a", 0.0, 0.35)
		tw2.tween_callback(func() -> void:
			cena.queue_free()
			fase.get_tree().paused = false
			_levar_dano(d)))

func _levar_dano(d: int) -> void:
	vida = maxi(0, vida - d)
	if d > 0:
		fase._mensagem("-%d NO GERESCH!" % d, Color(0.5, 1, 0.6))
		Audio.tocar("impacto_forte", 1.0)
		_img.modulate = Color(1, 0.4, 0.4)
		var tw := _img.create_tween()
		tw.tween_property(_img, "modulate", Color.WHITE, 0.5)
	else:
		fase._mensagem("NENHUMA LINHA... ELE RIU DE VOCÊ", Color(1, 0.6, 0.4))
	if vida <= 0:
		morto = true
		_rotulo.text = "GERESCH DERROTADO!"
		_rotulo.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
		_barra.size.x = 0.0
		return
	_trocar_imagem()
	_estado = "desvio"
	_timer = DESVIO[_estagio]
	_prox = 1.2

class_name Arquiteto
extends Node
## Modo O ARQUITETO (fase 13, online). Em cada rodada um jogador é o Arquiteto: vê a pista de cima
## e solta armadilhas ao vivo (com energia que enche). O resto corre até a chegada. Morreu, tá fora
## e vira fantasma (pode soltar 1 mina). Pontos: chegada 3/2/1; Arquiteto ganha 1 por morte (+1 se a
## cabeça estourou), mas se ninguém chegar ele não ganha nada. O papel gira; quem criou a sala manda.

const TIPOS := ["serra", "mina", "espinho", "bola", "tnt", "prensa", "trilho", "drone", "trampolim", "caixas"]
const CUSTO := {"serra": 45.0, "mina": 30.0, "espinho": 25.0, "bola": 60.0, "tnt": 35.0, "prensa": 55.0, "trilho": 50.0,
	"drone": 70.0, "trampolim": 20.0, "caixas": 15.0}
const NOMES := {"serra": "SERRA", "mina": "MINA", "espinho": "ESPINHO", "bola": "BOLA", "tnt": "TNT", "prensa": "PRENSA",
	"trilho": "SERRA TRILHO", "drone": "DRONE", "trampolim": "TRAMPOLIM", "caixas": "CAIXAS"}
const CORES := {"serra": Color(1.0, 0.45, 0.35), "mina": Color(1.0, 0.85, 0.3), "espinho": Color(0.75, 0.8, 0.95), "bola": Color(0.6, 0.6, 0.7),
	"tnt": Color(1.0, 0.3, 0.2), "prensa": Color(0.6, 0.7, 0.85), "trilho": Color(1.0, 0.35, 0.3), "drone": Color(1.0, 0.55, 0.2),
	"trampolim": Color(0.4, 1.0, 0.5), "caixas": Color(0.85, 0.6, 0.3)}
const NO_CHAO := ["mina", "espinho", "tnt", "prensa", "trilho", "trampolim", "caixas"]
const ENERGIA_MAX := 100.0
const ENERGIA_GANHO := 14.0           # por segundo
const TEMPO_RODADA := 75.0          # depois do preparo
const PREPARO := 12.0                 # começo: só o Arquiteto mexe (corredores parados na largada)
const AVISO := 0.8                    # armadilha pisca antes de valer
const X_LIVRE := 3200.0               # perto da largada não pode armar

var fase: Node2D
var arq_id := ""
var sou_arq := false
var ordem: Array = []
var pontos: Dictionary = {}
var k := 0
var total := 1
var energia := ENERGIA_MAX
var tipo := "serra"
var olho: Node2D
var hud: CanvasLayer
var _barra: ColorRect
var _barra_fundo: ColorRect
var _titulo: Label
var _dica: Label
var _relogio: Label
var _botoes: Dictionary = {}
var _seq := 0
var _vistos: Dictionary = {}
var mortes: Dictionary = {}           # id -> true se a cabeça estourou
var chegadas: Dictionary = {}         # id -> tempo
var fantasma := false                 # corredor morto: solta 1 mina
var _mina_fantasma := true
var _fim := false
var _press := Vector2.ZERO
var _apertado := false
var _moveu := 0.0
var _chegada_x := 20000.0
var _bot_t := 1.0
var _bot_i := 0
var _foto_t := 1.0
var _fotos := 0

var chao_y := 0.0

func montar(f: Node2D, chegada_x: float, chao: float) -> void:
	fase = f
	_chegada_x = chegada_x
	chao_y = chao
	var a: Dictionary = Online.arq
	var ids: Array = Online.corrida.get("ids", [Online.id]).duplicate()
	ids.sort()
	if a.is_empty():                                  # 1ª rodada: todo mundo calcula igual
		ordem = ids
		k = 0
		pontos = {}
		total = ordem.size() if ordem.size() > 2 else ordem.size() * 2
	else:
		ordem = a.get("ordem", ids)
		k = int(a.get("k", 0))
		pontos = (a.get("pontos", {}) as Dictionary).duplicate()
		total = int(a.get("total", ordem.size()))
	for q in ordem.size():                            # Arquiteto que saiu da sala: pula pro próximo
		var cand: String = ordem[(k + q) % ordem.size()]
		if cand == Online.id or Online.jogadores.has(cand) or Online.jogadores.is_empty():
			arq_id = cand
			break
	if arq_id == "":
		arq_id = Online.id
	sou_arq = arq_id == Online.id
	_montar_hud()

## chamado depois que o jogador entra na fase: o Arquiteto não corre (fica escondido e parado)
func preparar_jogador() -> void:
	if not sou_arq:
		return
	var pl = fase.player
	pl.visible = false
	for rb in [pl.chassi] + pl.rodas:
		(rb as RigidBody2D).freeze = true
	if is_instance_valid(fase.cosm):
		fase.cosm.queue_free()
	olho = Node2D.new()
	olho.position = Vector2(X_LIVRE + 2500.0, chao_y + 300.0)
	fase.add_child(olho)
	fase.set_meta("cam_base", true)
	fase.camera.alvo = olho
	fase.camera.zoom = Vector2(0.12, 0.12)
	fase.camera.offset = Vector2.ZERO
	fase.dist_label.visible = false
	_esconder_controles()

func _esconder_controles() -> void:
	for i in mini(8, fase._hud.size()):
		(fase._hud[i][0] as CanvasItem).visible = false

# ---------- HUD ----------
func _montar_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 12
	add_child(hud)
	var v := get_viewport().get_visible_rect().size
	_titulo = _rotulo("", 34, 9, Color(1, 0.85, 0.3))
	_titulo.position = Vector2(0, 92)
	_titulo.size = Vector2(v.x, 44)
	hud.add_child(_titulo)
	_dica = _rotulo("", 20, 6, Color(0.95, 0.9, 1.0))
	_dica.position = Vector2(0, 134)
	_dica.size = Vector2(v.x, 28)
	hud.add_child(_dica)
	_relogio = _rotulo("", 30, 8, Color.WHITE)
	_relogio.position = Vector2(0, 50)
	_relogio.size = Vector2(v.x, 40)
	hud.add_child(_relogio)
	if sou_arq:
		_titulo.text = "VOCÊ É O ARQUITETO"
		_dica.text = "Arrasta pra mover · escolhe a armadilha e toca na pista. Se NINGUÉM chegar, você não ganha nada!"
		_barra_fundo = ColorRect.new()
		_barra_fundo.color = Color(0, 0, 0, 0.55)
		_barra_fundo.position = Vector2(v.x / 2.0 - 260, v.y - 206)
		_barra_fundo.size = Vector2(520, 22)
		hud.add_child(_barra_fundo)
		_barra = ColorRect.new()
		_barra.color = Color(0.4, 0.9, 1.0)
		_barra.position = _barra_fundo.position + Vector2(3, 3)
		hud.add_child(_barra)
		var i := 0
		for t in TIPOS:
			var b := Button.new()
			b.text = "%s %d" % [NOMES[t], int(CUSTO[t])]
			b.icon = load("res://assets/arquiteto/%s.png" % t)
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 14)
			b.add_theme_constant_override("icon_max_width", 48)
			b.size = Vector2(118, 82)
			b.position = Vector2(v.x / 2.0 - 2.5 * 124 + (i % 5) * 124 + 3, v.y - 176 + (i / 5) * 88)
			var nome: String = t
			b.pressed.connect(func() -> void:
				tipo = nome
				Audio.tocar("clique")
				_estilo_botoes())
			hud.add_child(b)
			_botoes[t] = b
			i += 1
		_estilo_botoes()
	else:
		_titulo.text = "ARQUITETO: %s" % Online.nome_de(arq_id)
		_dica.text = "Chega no fim! Ele vai encher a pista de armadilha..."
	var placar := _rotulo("RODADA %d DE %d" % [k + 1, total], 20, 6, Color(0.8, 0.75, 0.95))
	placar.position = Vector2(0, 162)
	placar.size = Vector2(v.x, 26)
	hud.add_child(placar)

func _estilo_botoes() -> void:
	for t in _botoes:
		var b: Button = _botoes[t]
		var st := StyleBoxFlat.new()
		var sel: bool = t == tipo
		st.bg_color = Color(0.3, 0.12, 0.08, 0.92) if sel else Color(0.08, 0.05, 0.15, 0.88)
		st.set_corner_radius_all(14)
		st.set_border_width_all(5 if sel else 3)
		st.border_color = CORES[t] if sel else Color(0.5, 0.4, 0.7)
		for s in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(s, st)
		b.modulate.a = 1.0 if energia >= CUSTO[t] else 0.45

func _rotulo(texto: String, tam: int, contorno: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", contorno)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# ---------- todo quadro (chamado pelo Main no online) ----------
func passo(dt: float) -> void:
	var largou: bool = Online.corrida.get("largou", false)
	if largou and not _fim:
		var t0 := (Time.get_ticks_msec() - int(Online.corrida.get("inicio_ms", 0))) / 1000.0
		var t := t0 - PREPARO
		_segurar(t < 0.0)
		if is_instance_valid(_relogio):
			if t < 0.0:
				_relogio.text = ("MONTA! ELES SAEM EM %d" if sou_arq else "O ARQUITETO TÁ MONTANDO... %d") % ceili(-t)
			else:
				_relogio.text = "%d s" % maxi(0, ceili(TEMPO_RODADA - t))
		if sou_arq:
			energia = minf(ENERGIA_MAX, energia + ENERGIA_GANHO * dt)
		if Online.host and t >= 0.0:
			_conferir_fim(t)
	if largou and not _fim and "arq_bot" in OS.get_cmdline_user_args():   # teste: robô
		_bot_t -= dt
		if sou_arq and _bot_t <= 0.0:
			_bot_t = 1.2
			tipo = TIPOS[_bot_i % TIPOS.size()]
			energia = ENERGIA_MAX
			_tentar_armar(Vector2(X_LIVRE + 1500.0 + _bot_i * 1800.0, chao_y - 600.0))
			if olho:
				olho.position.x = X_LIVRE + 1500.0 + maxi(0, _bot_i - 2) * 1800.0
			_bot_i += 1
		elif not sou_arq and not fantasma:
			Input.action_press("accelerate")
	if "arq_fotos" in OS.get_cmdline_user_args():
		_foto_t -= dt
		if _foto_t <= 0.0:
			_foto_t = 4.0
			_fotos += 1
			get_viewport().get_texture().get_image().save_png("user://arq_%s_%02d.png" % ["A" if Online.host else "B", _fotos])
			print("[ARQ] %s foto=%d k=%d sou_arq=%s energia=%.0f mortes=%s chegadas=%s pontos=%s" % ["A" if Online.host else "B", _fotos, k, sou_arq, energia, mortes, chegadas, pontos])
	if sou_arq and is_instance_valid(_barra):
		_barra.size = Vector2((_barra_fundo.size.x - 6) * energia / ENERGIA_MAX, 16)
		_estilo_botoes()
	if fase._rotulo_online:
		fase._rotulo_online.text = "O ARQUITETO · SALA %s · %d correndo" % [Online.sala, _vivos().size()]

var _segurando := false

## preparo: corredor fica travado na largada (veículo congelado), depois solta
func _segurar(sim: bool) -> void:
	if sou_arq or sim == _segurando or not is_instance_valid(fase.player) or not fase.player.montado:
		return
	_segurando = sim
	for rb in [fase.player.chassi] + fase.player.rodas:
		(rb as RigidBody2D).freeze = sim
	if not sim:
		fase._mensagem("VAI!", Color(0.45, 1, 0.5))
		Audio.tocar("confirma")

func _corredores() -> Array:
	var r: Array = []
	for q in Online.corrida.get("ids", []):
		if q != arq_id and (q == Online.id or Online.jogadores.has(q)):
			r.append(q)
	return r

func _vivos() -> Array:
	return _corredores().filter(func(q) -> bool: return not mortes.has(q) and not chegadas.has(q))

func _conferir_fim(t: float) -> void:
	if _vivos().is_empty() or t >= TEMPO_RODADA:
		_decidir()

# ---------- toque: Arquiteto (ou fantasma) arma ----------
func _unhandled_input(ev: InputEvent) -> void:
	if not (sou_arq or (fantasma and _mina_fantasma)) or _fim or not Online.corrida.get("largou", false):
		return
	var pos := Vector2.ZERO
	var apertou := false
	var soltou := false
	var arrasto := Vector2.ZERO
	if ev is InputEventScreenTouch or (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
		pos = ev.position
		apertou = ev.pressed
		soltou = not ev.pressed
	elif ev is InputEventScreenDrag or (ev is InputEventMouseMotion and _apertado):
		arrasto = ev.relative
	else:
		return
	if apertou:
		_apertado = true
		_press = pos
		_moveu = 0.0
	elif arrasto != Vector2.ZERO and _apertado:
		_moveu += arrasto.length()
		if sou_arq and olho:
			olho.position -= arrasto / fase.camera.zoom
			olho.position.x = clampf(olho.position.x, 0.0, _chegada_x + 2000.0)
			olho.position.y = clampf(olho.position.y, chao_y - 6000.0, chao_y + 1000.0)
	elif soltou and _apertado:
		_apertado = false
		if _moveu < 24.0:
			var mundo: Vector2 = fase.get_viewport().get_canvas_transform().affine_inverse() * pos
			_tentar_armar(mundo)

func _tentar_armar(p: Vector2) -> void:
	var t := tipo if sou_arq else "mina"
	if p.x < X_LIVRE or p.x > _chegada_x - 600.0:
		fase._mensagem("AQUI NÃO DÁ!", Color(1, 0.4, 0.3))
		return
	if sou_arq and energia < CUSTO[t]:
		fase._mensagem("SEM ENERGIA!", Color(1, 0.4, 0.3))
		return
	if t in NO_CHAO:                                # vai pro chão embaixo do toque
		var q := PhysicsRayQueryParameters2D.create(p + Vector2(0, -400), p + Vector2(0, 5000), 0b1)
		var hit: Dictionary = fase.get_world_2d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			fase._mensagem("TOCA PERTO DO CHÃO!", Color(1, 0.4, 0.3))
			return
		p = hit["position"]
	if sou_arq:
		energia -= CUSTO[t]
	else:
		_mina_fantasma = false
		_dica.text = "Mina solta! Agora é torcer."
	_seq += 1
	var d := {"r": Online.rodada, "n": _seq, "t": t, "x": int(p.x), "y": int(p.y)}
	_criar(Online.id, d)
	for q in 3:
		get_tree().create_timer(0.05 + q * 0.6, true, false, true).timeout.connect(func() -> void: Online.enviar("arm", d))

## mesma armadilha em todas as telas: pisca AVISO s e depois vale
func _criar(de: String, d: Dictionary) -> void:
	var chave := "%s:%d" % [de, int(d.get("n", 0))]
	if _vistos.has(chave) or int(d.get("r", 0)) != Online.rodada:
		return
	_vistos[chave] = true
	var t := str(d.get("t", "serra"))
	var p := Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
	var aviso := Node2D.new()
	aviso.position = p + (Vector2(0, -250) if t in NO_CHAO else Vector2.ZERO)
	aviso.z_index = 30
	var cor: Color = CORES.get(t, Color.RED)
	aviso.draw.connect(func() -> void:
		aviso.draw_circle(Vector2.ZERO, 330.0, Color(cor, 0.25))
		aviso.draw_arc(Vector2.ZERO, 330.0, 0.0, TAU, 40, Color(1, 0.2, 0.15), 26.0)
		aviso.draw_line(Vector2(0, -150), Vector2(0, 50), Color(1, 0.2, 0.15), 50.0)
		aviso.draw_circle(Vector2(0, 130), 30.0, Color(1, 0.2, 0.15)))
	fase.add_child(aviso)
	var tw := aviso.create_tween().set_loops()
	tw.set_speed_scale(1.0 / maxf(Engine.time_scale, 0.01))
	tw.tween_property(aviso, "modulate:a", 0.25, 0.12)
	tw.tween_property(aviso, "modulate:a", 1.0, 0.12)
	Audio.tocar("clique", 0.8, 0.0)
	get_tree().create_timer(AVISO, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(aviso):
			aviso.queue_free()
		if not is_instance_valid(fase) or _fim:
			return
		match t:
			"serra":
				fase.pecas.serra(p, 300.0)
			"mina":
				fase.mec.mina(p)
			"espinho":
				fase.pecas.espinhos(p.x - 330.0, p.x + 330.0, p.y, 260.0)
			"bola":
				fase._bola_demolicao(p + Vector2(0, -1500.0), 1300.0, 0.95, 360.0)
			"tnt":
				fase.pecas.tnt(p + Vector2(0, -300.0))
			"prensa":
				fase.pecas.prensa(p.x, p.y, 3.0, 0.0)
			"trilho":
				fase.mec.serra_trilho(p, 2.6, 0.0)
			"drone":
				fase.mec.bomba_perseguidora(p, 3600.0)
			"trampolim":
				fase.mec.trampolim(p, 2600.0, 600.0)
			"caixas":
				for q in 3:
					fase.pecas.caixa(p + Vector2([-160.0, 160.0, 0.0][q], -160.0 - (320.0 if q == 2 else 0.0)), 300.0)
		Audio.tocar("metal", 0.7, 0.0))

# ---------- mensagens ----------
func msg(e: String, d: Dictionary, de: String) -> void:
	if int(d.get("r", -1)) != Online.rodada:
		return
	match e:
		"arm":
			_criar(de, d)
		"arq_morte":
			if not mortes.has(de) and not chegadas.has(de):
				mortes[de] = bool(d.get("cab", false))
				fase._mensagem("%s MORREU!" % Online.nome_de(de), Color(1, 0.45, 0.35))
		"arq_cheg":
			if not chegadas.has(de) and not mortes.has(de):
				chegadas[de] = float(d.get("t", 0.0))
				fase._mensagem("%s CHEGOU!" % Online.nome_de(de), Color(0.5, 1, 0.55))
		"arq_res":
			_mostrar_resultado(d)

# ---------- eu (corredor) morri / cheguei ----------
func eu_morri(motivo: String) -> void:
	if sou_arq or mortes.has(Online.id) or chegadas.has(Online.id) or _fim:
		return
	var cab: bool = is_instance_valid(fase.player) and not fase.player.corpos.is_empty() and not fase.player.corpos.has("cabeca")
	mortes[Online.id] = cab
	fase._morto_online = true
	fantasma = true
	fase.aviso.text = {"buraco": "CAIU!", "serra": "SERRADO!", "espetos": "ESPETADO!"}.get(motivo, "MORREU!") + "\nVOCÊ VIROU FANTASMA"
	fase.aviso.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	fase.aviso.visible = true
	Audio.tocar("morte")
	_titulo.text = "FANTASMA"
	_dica.text = "Toca na pista pra soltar 1 MINA nos outros!"
	_esconder_controles()
	for q in 3:
		get_tree().create_timer(0.05 + q * 0.6, true, false, true).timeout.connect(func() -> void:
			Online.enviar("arq_morte", {"r": Online.rodada, "cab": cab}))

func eu_cheguei() -> void:
	if sou_arq or mortes.has(Online.id) or chegadas.has(Online.id) or _fim:
		return
	var t: float = fase.tempo
	chegadas[Online.id] = t
	fase.ativo = false
	Audio.motor(false)
	Audio.tocar("vitoria")
	if is_instance_valid(fase.player):
		fase.pecas.festa(fase._meta_pos, fase.player.foco().global_position)
	fase.aviso.text = "CHEGOU EM %dº!" % chegadas.size()
	fase.aviso.add_theme_color_override("font_color", Color(0.45, 1, 0.5))
	fase.aviso.visible = true
	for q in 3:
		get_tree().create_timer(0.05 + q * 0.6, true, false, true).timeout.connect(func() -> void:
			Online.enviar("arq_cheg", {"r": Online.rodada, "t": t}))

# ---------- fim da rodada (quem criou a sala decide e manda pra todos) ----------
func _decidir() -> void:
	if _fim:
		return
	var ganho: Dictionary = {}
	var lista := chegadas.keys()
	lista.sort_custom(func(a, b) -> bool: return float(chegadas[a]) < float(chegadas[b]))
	for i in lista.size():
		ganho[lista[i]] = [3, 2][i] if i < 2 else 1
	var do_arq := 0
	for q in mortes:
		do_arq += 2 if mortes[q] else 1
	var motivo := ""
	if lista.is_empty():
		do_arq = 0
		motivo = "NINGUÉM CHEGOU: o Arquiteto não ganha nada!"
	ganho[arq_id] = do_arq
	var novos := pontos.duplicate()
	for q in ganho:
		novos[q] = int(novos.get(q, 0)) + int(ganho[q])
	var d := {"r": Online.rodada, "ganho": ganho, "pontos": novos, "motivo": motivo}
	_mostrar_resultado(d)
	for q in 3:
		get_tree().create_timer(0.05 + q * 0.6, true, false, true).timeout.connect(func() -> void: Online.enviar("arq_res", d))
	await get_tree().create_timer(7.0, true, false, true).timeout
	if not is_inside_tree():
		return
	if k + 1 < total:
		Online.arq = {"ordem": ordem, "k": k + 1, "pontos": novos, "total": total}
		fase._nova_rodada(13)
	else:
		Online.arq = {}

func _mostrar_resultado(d: Dictionary) -> void:
	if _fim:
		return
	_fim = true
	fase.ativo = false
	Audio.motor(false)
	var ganho: Dictionary = d.get("ganho", {})
	var novos: Dictionary = d.get("pontos", {})
	pontos = novos
	var ids: Array = ordem.duplicate()
	ids.sort_custom(func(a, b) -> bool: return int(novos.get(a, 0)) > int(novos.get(b, 0)))
	var txt := ""
	for q in ids:
		if not (q == Online.id or Online.jogadores.has(q) or novos.has(q)):
			continue
		var g := int(ganho.get(q, 0))
		txt += "%s%s   %d pts%s\n" % [Online.nome_de(q), " (você)" if q == Online.id else "", int(novos.get(q, 0)),
			("   +%d" % g) if g > 0 else ""]
	var ultima := k + 1 >= total
	var campeao: String = ids[0] if not ids.is_empty() else ""
	if ultima:
		fase.aviso.text = "%s É O CAMPEÃO!" % ("VOCÊ" if campeao == Online.id else Online.nome_de(campeao))
		fase.aviso.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		if campeao == Online.id:
			Audio.tocar("vitoria")
		Passe.ganhar("online_1" if campeao == Online.id else "online")
		Online.arq = {}
	else:
		fase.aviso.text = "FIM DA RODADA %d" % (k + 1)
		fase.aviso.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		var prox: String = ordem[(k + 1) % ordem.size()]
		txt += "\nPRÓXIMO ARQUITETO: %s" % ("VOCÊ" if prox == Online.id else Online.nome_de(prox))
	if str(d.get("motivo", "")) != "":
		txt = str(d["motivo"]) + "\n\n" + txt
	fase.aviso.visible = true
	if ultima:
		hud.visible = false
		fase._fim_online(true, txt.strip_edges())
	else:
		fase.aviso.visible = false
		for n in hud.get_children():
			n.queue_free()
		_barra = null
		_barra_fundo = null
		_botoes.clear()
		var v := get_viewport().get_visible_rect().size
		var escuro := ColorRect.new()
		escuro.color = Color(0, 0, 0, 0.65)
		escuro.size = v
		hud.add_child(escuro)
		var tit := _rotulo("FIM DA RODADA %d DE %d" % [k + 1, total], 56, 14, Color(1, 0.85, 0.3))
		tit.position = Vector2(0, v.y * 0.08)
		tit.size = Vector2(v.x, 80)
		hud.add_child(tit)
		var l := _rotulo(txt.strip_edges(), 30, 8, Color.WHITE)
		l.position = Vector2(0, v.y * 0.25)
		l.size = Vector2(v.x, v.y * 0.7)
		hud.add_child(l)
		_relogio = l

extends Node
## Autoload "Playtest": bot que tenta zerar a fase com as MESMAS ações do jogador
## (entrada simulada no motor = evidência N2). Só age com: -- playtest p=<personagem>
## tentativas=<n> semente=<s> [fotos]. Reinicia como o jogador (R, com checkpoint).

var ativo := false
var tentativas_max := 12
var semente := 1234
var fotos := false
var rng := RandomNumberGenerator.new()
var tentativa := 0
var resultado := ""
var log_path := "user://playtest/log.jsonl"
var falhas: Array = []
var _vx_ant: Dictionary = {}
var _liberado := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not "playtest" in args:
		return
	ativo = true
	for a in args:
		if a.begins_with("tentativas="): tentativas_max = int(a.substr(11))
		if a.begins_with("semente="): semente = int(a.substr(8))
	fotos = "fotos" in args
	rng.seed = semente
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtest"))
	_rodar.call_deferred()

func _fase() -> Node:
	var c := get_tree().current_scene
	return c if c and c.has_signal("venceu") else null

func _rodar() -> void:
	var venceu := false
	while tentativa < tentativas_max and not venceu:
		tentativa += 1
		await get_tree().process_frame
		await get_tree().process_frame
		var fase := _fase()
		if fase == null:
			print("[PLAYTEST] cena atual não é uma fase")
			get_tree().quit(2)
			return
		resultado = ""
		fase.venceu.connect(func(t: float) -> void: resultado = "venceu %.2f" % t, CONNECT_ONE_SHOT)
		fase.perdeu.connect(func(m: String) -> void: resultado = "perdeu " + m, CONNECT_ONE_SHOT)
		# rodízio: dirigir bem / dirigir bem esperando o momento (obstáculo de tempo) / aleatório
		var estrategia: String = ["busca", "reativo", "reativo_espera", "reativo_espera"][tentativa % 4]
		var inicio_x: float = fase.player.chassi.global_position.x
		var t0 := Time.get_ticks_msec()
		await _jogar(fase, estrategia)
		var x: float = fase.player.foco().global_position.x
		var linha := {"tentativa": tentativa, "personagem": Game.personagem, "estrategia": estrategia,
			"semente": semente, "inicio_x": roundi(inicio_x), "resultado": resultado,
			"x_final": roundi(x), "tempo_jogo": snappedf(fase.tempo, 0.01),
			"ms_reais": Time.get_ticks_msec() - t0}
		print("[TENTATIVA] ", JSON.stringify(linha))
		_gravar(linha)
		if fotos:
			await _foto("%s_t%02d" % [Game.personagem, tentativa])
		venceu = resultado.begins_with("venceu")
		if not venceu:
			falhas.append(roundi(x))
			_soltar()
			get_tree().reload_current_scene()     # mesmo R do jogador (mantém checkpoint)
	print("[PLAYTEST] %s: %s em %d tentativa(s); falhas em x=%s" %
		[Game.personagem, "VENCEU" if venceu else "NAO VENCEU", tentativa, str(falhas)])
	get_tree().quit(0 if venceu else 1)

func _jogar(fase: Node, estrategia: String) -> void:
	var melhor_x := -INF
	var parado := 0.0
	var re_ate := -1.0
	var macro := ""
	var macro_ate := 0.0
	# estratégia de gente: em obstáculo de tempo (pêndulo), esperar antes de ir
	var espera := 0.0 if estrategia == "reativo" else rng.randf_range(0.0, 5.0)
	_liberado = false
	_vx_ant.clear()
	while resultado == "":
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		if not is_instance_valid(fase) or fase.tempo > 90.0:
			resultado = "tempo"
			break
		var foco: Node2D = fase.player.foco()
		var rb := foco as RigidBody2D
		if rb and (rb.linear_velocity.length() > 20000.0 or is_nan(rb.global_position.x)):
			resultado = "explosao"
			break
		if foco.global_position.x > melhor_x + 30.0:
			melhor_x = foco.global_position.x
			parado = 0.0
		else:
			parado += dt
		if parado > 7.0:
			resultado = "travado"
			break
		_soltar()
		if not fase.player.montado:
			continue
		if estrategia == "reativo_espera" and _esperar_pendulo(foco):
			parado = 0.0
			Input.action_press("brake") if fase.player.chassi.linear_velocity.x > 30.0 else null
			continue
		if estrategia == "busca" and fase.tempo < espera:
			parado = 0.0
			continue
		# inclinação RELATIVA ao chão embaixo (no ar: manter nivelado)
		var rot: float = fase.player.chassi.global_rotation - _angulo_chao(fase.player.chassi.global_position)
		if estrategia.begins_with("reativo"):
			# trava na frente de algo: dá ré pra ganhar embalo e vai de novo
			if parado > 2.5 and re_ate < 0.0:
				re_ate = fase.tempo + 1.2
			if re_ate > 0.0 and fase.tempo < re_ate:
				Input.action_press("brake")
			else:
				if re_ate > 0.0 and fase.tempo >= re_ate:
					re_ate = -1.0
					parado = 0.0
				Input.action_press("accelerate")
			if rot < -0.3: Input.action_press("lean_fwd")
			elif rot > 0.3: Input.action_press("lean_back")
		else:
			if fase.tempo >= macro_ate:
				macro = ["accelerate", "accelerate", "accelerate", "lean_back", "lean_fwd", "brake"][rng.randi_range(0, 5)]
				macro_ate = fase.tempo + rng.randf_range(0.3, 1.6)
			Input.action_press(macro)
			if macro != "brake":
				Input.action_press("accelerate")
	_soltar()

## olha o pêndulo à frente (como o jogador vê na tela): espera ele estar do lado
## de cá e começando a se afastar, para passar logo atrás dele
func _esperar_pendulo(foco: Node2D) -> bool:
	for b in get_tree().get_nodes_in_group("pendulo"):
		var ancora: Vector2 = b.get_meta("ancora")
		var alcance: float = b.get_meta("alcance")
		var dist := ancora.x - foco.global_position.x
		if dist < 300.0 or dist > 1150.0:          # para logo antes do alcance da bola
			continue
		var bola := b as RigidBody2D
		# sai no instante em que a bola VIRA no canto de cá (velocidade troca de sinal)
		var vx_ant: float = _vx_ant.get(bola, 0.0)
		_vx_ant[bola] = bola.linear_velocity.x
		var virou := vx_ant <= 0.0 and bola.linear_velocity.x > 0.0 and bola.global_position.x < ancora.x - alcance * 0.5
		if virou:
			_liberado = true
		return not _liberado
	return false

## ângulo do terreno sob a posição (dois raios: 200 px atrás e na frente); 0 se no ar
func _angulo_chao(pos: Vector2) -> float:
	var espaco := get_viewport().world_2d.direct_space_state
	var pts: Array = []
	for dx in [-200.0, 200.0]:
		var q := PhysicsRayQueryParameters2D.create(pos + Vector2(dx, -50), pos + Vector2(dx, 900), 0b0001)
		var hit := espaco.intersect_ray(q)
		if hit.is_empty():
			return 0.0
		pts.append(hit["position"])
	return ((pts[1] as Vector2) - (pts[0] as Vector2)).angle()

func _soltar() -> void:
	for a in ["accelerate", "brake", "lean_fwd", "lean_back"]:
		Input.action_release(a)

func _gravar(linha: Dictionary) -> void:
	var existe := FileAccess.file_exists(log_path)
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE if existe else FileAccess.WRITE)
	f.seek_end()
	f.store_line(JSON.stringify(linha))

func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://playtest/%s.png" % nome)

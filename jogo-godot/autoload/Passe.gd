extends Node
## Autoload "Passe": nível da conta (XP vem do servidor) e passe de batalha com 50 níveis.
## A maioria libera um item de efeito (rastro, aura, roda, chapéu, morte, moldura) ou uma skin;
## os outros dão só XP (+300 na hora ou XP em dobro por 15 min), aplicado pelo servidor.
## O que está equipado fica salvo no aparelho; quem decide se está liberado é o nível.

signal mudou

const NIVEL_MAX := 50
## [nível, id, nome, tipo, cor principal]. Tipo "bonus" = nível que dá só XP (o servidor aplica sozinho)
const ITENS := [
	[1, "rastro_fumaca", "Fumaça", "rastro", Color(0.75, 0.75, 0.78)],
	[2, "rastro_fogo", "Rastro de Fogo", "rastro", Color(1.0, 0.5, 0.1)],
	[3, "bonus_dobro_3", "XP em Dobro (15 min)", "bonus", Color(0.4, 0.85, 1.0)],
	[4, "morte_confete", "Explode em Confete", "morte", Color(1.0, 0.4, 0.8)],
	[5, "bonus_xp_5", "+300 XP", "bonus", Color(0.5, 1.0, 0.6)],
	[6, "aura_dourada", "Aura Dourada", "aura", Color(1.0, 0.82, 0.3)],
	[7, "roda_fogo", "Roda de Fogo", "roda", Color(1.0, 0.45, 0.1)],
	[8, "rastro_arco", "Arco-íris", "rastro", Color(0.6, 0.4, 1.0)],
	[9, "bonus_dobro_9", "XP em Dobro (15 min)", "bonus", Color(0.4, 0.85, 1.0)],
	[10, "moldura_ouro", "Nick Dourado", "moldura", Color(1.0, 0.82, 0.25)],
	[11, "bonus_xp_11", "+300 XP", "bonus", Color(0.5, 1.0, 0.6)],
	[12, "chapeu_coroa", "Coroa", "chapeu", Color(1.0, 0.8, 0.2)],
	[13, "bonus_xp_13", "+300 XP", "bonus", Color(0.5, 1.0, 0.6)],
	[14, "morte_moedas", "Chuva de Moedas", "morte", Color(1.0, 0.85, 0.2)],
	[15, "bonus_dobro_15", "XP em Dobro (15 min)", "bonus", Color(0.4, 0.85, 1.0)],
	[16, "rastro_raio", "Rastro de Raio", "rastro", Color(0.5, 0.85, 1.0)],
	[17, "bonus_xp_17", "+300 XP", "bonus", Color(0.5, 1.0, 0.6)],
	[18, "roda_neon", "Roda Neon", "roda", Color(0.2, 1.0, 0.9)],
	[19, "aura_roxa", "Chamas Roxas", "aura", Color(0.7, 0.3, 1.0)],
	[20, "chapeu_aureola", "Auréola", "chapeu", Color(1.0, 0.95, 0.6)],
	[21, "bonus_dobro_21", "XP em Dobro (15 min)", "bonus", Color(0.4, 0.85, 1.0)],
	[22, "rastro_coracao", "Corações", "rastro", Color(1.0, 0.35, 0.55)],
	[23, "bonus_xp_23", "+300 XP", "bonus", Color(0.5, 1.0, 0.6)],
	[24, "morte_pixel", "Desmancha em Pixel", "morte", Color(0.3, 1.0, 0.5)],
	[25, "aura_gelo", "Aura de Gelo", "aura", Color(0.6, 0.9, 1.0)],
	[26, "roda_gelo", "Roda de Gelo", "roda", Color(0.7, 0.95, 1.0)],
	[27, "bonus_dobro_27", "XP em Dobro (15 min)", "bonus", Color(0.4, 0.85, 1.0)],
	[28, "rastro_dinheiro", "Rastro de Dinheiro", "rastro", Color(0.35, 0.85, 0.35)],
	[29, "bonus_xp_29", "+300 XP", "bonus", Color(0.5, 1.0, 0.6)],
	[30, "chapeu_chifre", "Chifres do Diabo", "chapeu", Color(0.9, 0.1, 0.1)],
	[31, "bonus_xp_31", "+300 XP", "bonus", Color(0.5, 1.0, 0.6)],
	[32, "moldura_fogo", "Nick de Fogo", "moldura", Color(1.0, 0.4, 0.15)],
	[33, "bonus_dobro_33", "XP em Dobro (15 min)", "bonus", Color(0.4, 0.85, 1.0)],
	[34, "morte_fantasma", "Vira Fantasma", "morte", Color(0.9, 0.95, 1.0)],
	[35, "skin_wendell", "Wendell: O Acidente", "skin", Color(1.0, 0.55, 0.2)],
	[36, "bonus_xp_36", "+300 XP", "bonus", Color(0.5, 1.0, 0.6)],
	[37, "roda_arco", "Roda Arco-íris", "roda", Color(1.0, 0.3, 0.6)],
	[38, "rastro_estrela", "Estrelas", "rastro", Color(1.0, 0.95, 0.4)],
	[39, "bonus_dobro_39", "XP em Dobro (15 min)", "bonus", Color(0.4, 0.85, 1.0)],
	[40, "chapeu_cartola", "Cartola", "chapeu", Color(0.12, 0.12, 0.14)],
	[41, "bonus_xp_41", "+300 XP", "bonus", Color(0.5, 1.0, 0.6)],
	[42, "aura_semaj", "Sombra do Semaj", "aura", Color(0.55, 0.1, 0.8)],
	[43, "morte_raio", "Explosão Elétrica", "morte", Color(0.4, 0.8, 1.0)],
	[44, "bonus_xp_44", "+300 XP", "bonus", Color(0.5, 1.0, 0.6)],
	[45, "bonus_dobro_45", "XP em Dobro (15 min)", "bonus", Color(0.4, 0.85, 1.0)],
	[46, "moldura_arco", "Nick Arco-íris", "moldura", Color(0.4, 1.0, 0.8)],
	[47, "bonus_xp_47", "+300 XP", "bonus", Color(0.5, 1.0, 0.6)],
	[48, "aura_arco", "Aura Arco-íris", "aura", Color(1.0, 0.4, 0.9)],
	[49, "bonus_xp_49", "+300 XP", "bonus", Color(0.5, 1.0, 0.6)],
	[50, "skin_gian", "Gian: Iceman", "skin", Color(0.3, 0.7, 1.0)],
]
const TIPOS := {"bonus": "BÔNUS", "rastro": "RASTRO", "aura": "AURA", "roda": "RODA", "chapeu": "CHAPÉU", "morte": "MORTE", "moldura": "NICK", "skin": "SKIN"}
## skin do passe -> [personagem, item da skin]; vazio = arte ainda não chegou
const SKINS_PASSE := {"skin_wendell": ["wendell", "wendell_acidente"], "skin_gian": ["scooter", "scooter_iceman"]}

var xp := 0
var equipados: Dictionary = {}          # tipo -> id
var _carregou := false                  # já sabia o XP de antes (só aí mostra "subiu de nível")
var dobro_ate := 0.0                    # unix: até quando o XP vale em dobro

func _ready() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Game.ARQ_PROGRESSO)
	xp = int(cfg.get_value("passe", "xp", 0))
	equipados = cfg.get_value("passe", "equipados", {})
	_carregou = xp > 0
	Conta.mudou.connect(func() -> void:
		if Conta.logado():
			atualizar())

## XP pra sair do nível n pro n+1
static func custo(n: int) -> int:
	return 150 + 30 * n

static func nivel_de(total: int) -> int:
	var n := 1
	var resto := total
	while resto >= custo(n) and n < 99:
		resto -= custo(n)
		n += 1
	return n

func nivel() -> int:
	return nivel_de(xp)

## [xp dentro do nível, xp pra passar]
func progresso() -> Array:
	var n := 1
	var resto := xp
	while resto >= custo(n) and n < 99:
		resto -= custo(n)
		n += 1
	return [resto, custo(n)]

func item(id: String) -> Array:
	for it in ITENS:
		if it[1] == id:
			return it
	return []

func liberado(id: String) -> bool:
	var it := item(id)
	return not it.is_empty() and (nivel() >= int(it[0]) or (Conta.admin and it[3] != "bonus"))

func equipado(tipo: String) -> String:
	var id := str(equipados.get(tipo, ""))
	return id if id != "" and liberado(id) else ""

## equipa (ou tira, se já estava) um item liberado
func alternar(id: String) -> void:
	var it := item(id)
	if it.is_empty() or not liberado(id) or it[3] in ["skin", "bonus"]:
		return
	var tipo: String = it[3]
	if equipados.get(tipo, "") == id:
		equipados.erase(tipo)
	else:
		equipados[tipo] = id
	_salvar()
	mudou.emit()

func _salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Game.ARQ_PROGRESSO)
	cfg.set_value("passe", "xp", xp)
	cfg.set_value("passe", "equipados", equipados)
	cfg.save(Game.ARQ_PROGRESSO)

## busca o XP no servidor (e mostra a tela de nível novo se subiu)
func atualizar() -> void:
	if not Conta.logado():
		return
	var r: Array = await Conta._pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/bicho_meu_passe", {}, true)
	if int(r[0]) == 200 and typeof(r[1]) == TYPE_DICTIONARY:
		_ler_dobro(r[1].get("dobro_ate"))
		_novo_xp(int(r[1].get("xp", xp)), 0)
	else:                                               # servidor sem o SQL novo ainda
		r = await Conta._pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/bicho_meu_xp", {}, true)
		if int(r[0]) == 200 and r[1] != null:
			_novo_xp(int(r[1]), 0)

func _ler_dobro(v) -> void:
	if v == null or str(v) == "":
		dobro_ate = 0.0
		return
	var t := str(v).left(19).replace(" ", "T")
	dobro_ate = float(Time.get_unix_time_from_datetime_string(t))

## segundos de XP em dobro que ainda faltam (0 = sem bônus)
func dobro_resta() -> int:
	return maxi(0, int(dobro_ate - Time.get_unix_time_from_system()))

## pede XP ao servidor por algo que aconteceu (o servidor decide quanto)
func ganhar(motivo: String, fase := 0) -> void:
	if not Conta.logado():
		return
	var r: Array = await Conta._pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/bicho_ganhar_xp", {"p_motivo": motivo, "p_fase": fase}, true)
	if int(r[0]) == 200 and typeof(r[1]) == TYPE_DICTIONARY:
		_novo_xp(int(r[1].get("xp", xp)), int(r[1].get("ganho", 0)))

func _novo_xp(total: int, ganho: int) -> void:
	var antes := nivel()
	var tinha := _carregou
	_carregou = true
	xp = maxi(total, 0)
	_salvar()
	mudou.emit()
	if ganho > 0:
		_flutuante("+%d XP" % ganho)
	if nivel() > antes and tinha:
		_subiu(antes, nivel())
		atualizar.call_deferred()                        # pega o bônus de XP em dobro, se ganhou
		Conta._pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/bicho_resgatar_passe", {}, true)

## "+150 XP" subindo no canto da tela
func _flutuante(txt: String) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 95
	get_tree().root.add_child(cl)
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 46)
	l.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.2))
	l.add_theme_constant_override("outline_size", 12)
	var v := get_viewport().get_visible_rect().size
	l.position = Vector2(v.x * 0.5 - 90, v.y * 0.32)
	cl.add_child(l)
	var tw := l.create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw.tween_property(l, "position:y", l.position.y - 120.0, 1.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tw.tween_callback(cl.queue_free)

## tela de "SUBIU DE NÍVEL!" com o que liberou
func _subiu(de: int, para: int) -> void:
	var novos: Array = []
	for it in ITENS:
		if int(it[0]) > de and int(it[0]) <= para:
			novos.append(it)
	var cl := CanvasLayer.new()
	cl.layer = 96
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(cl)
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.0, 0.08, 0.0)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(fundo)
	var caixa := VBoxContainer.new()
	caixa.set_anchors_preset(Control.PRESET_FULL_RECT)
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	caixa.add_theme_constant_override("separation", 6)
	cl.add_child(caixa)
	var linhas := [["SUBIU DE NÍVEL!", 44, Color(0.75, 0.6, 1.0)], ["NÍVEL %d" % para, 140, Color(1.0, 0.85, 0.3)]]
	for it in novos:
		linhas.append([("BÔNUS: %s" if it[3] == "bonus" else "LIBEROU: %s") % it[2] + (" (chega em breve)" if it[3] == "skin" else ""), 34, it[4]])
	if not novos.is_empty():
		linhas.append(["equipa no INVENTÁRIO, no menu", 24, Color(0.85, 0.85, 0.9)])
	for d in linhas:
		var l := Label.new()
		l.text = d[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", d[1])
		l.add_theme_color_override("font_color", d[2])
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.2))
		l.add_theme_constant_override("outline_size", 16)
		caixa.add_child(l)
	caixa.pivot_offset = get_viewport().get_visible_rect().size / 2.0
	caixa.scale = Vector2.ONE * 0.4
	caixa.modulate.a = 0.0
	Audio.tocar("vitoria", 1.0, 0.0)
	var tw := cl.create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw.tween_property(fundo, "color:a", 0.7, 0.25)
	tw.parallel().tween_property(caixa, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(caixa, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.6)
	tw.tween_property(cl, "offset:y", -40.0, 0.4)
	tw.parallel().tween_property(caixa, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(fundo, "color:a", 0.0, 0.4)
	tw.tween_callback(cl.queue_free)

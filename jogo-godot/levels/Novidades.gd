extends Control
## Aviso de atualização: aparece por cima do lobby na primeira vez que abre a versão nova.
## Fundo é a arte do patch escurecida; o X fecha e fica no lobby.

const VERSAO := "3.5"
const ITENS := [
	["NÍVEL DE CONTA", "Agora você ganha XP jogando: tempo de jogo, fase vencida, chefe derrotado, recorde e partida online. Seu nível aparece no menu.", Color(1.0, 0.82, 0.3)],
	["PASSE DE BATALHA", "50 níveis: rastros, auras, rodas brilhando, chapéus, nick colorido, efeitos de morte e bônus de XP (+300 ou XP em dobro). Toca em NÍVEL no menu.", Color(0.6, 0.85, 1.0)],
	["SKINS NO PASSE", "Wendell: O ACIDENTE (nível 35) e Gian: ICEMAN (nível 50). Chegou no nível, tá no inventário.", Color(1.0, 0.55, 0.2)],
	["INVENTÁRIO", "Nova aba no menu: suas skins e os itens do passe separados por tipo. Toca pra usar.", Color(1.0, 0.8, 0.25)],
	["XP RETROATIVO", "Quem já jogava ganhou XP pelo tempo de jogo e pelas fases que já venceu.", Color(0.5, 1.0, 0.55)],
	["RANKING DA FASE 10", "Vencer o Semaj agora entra no ranking certinho.", Color(0.85, 0.6, 1.0)],
]

static func ja_viu() -> bool:
	var cfg := ConfigFile.new()
	cfg.load(Game.ARQ_PROGRESSO)
	return str(cfg.get_value("extra", "novidades", "")) == VERSAO

var _fundo: TextureRect
var _escuro: ColorRect
var _col: VBoxContainer
var _x: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fundo = TextureRect.new()
	_fundo.texture = load("res://assets/ui/patch_2.jpg")
	_fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_fundo)
	_escuro = ColorRect.new()
	_escuro.color = Color(0.03, 0.01, 0.07, 0.8)
	add_child(_escuro)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 12)
	add_child(_col)
	var v := _rotulo("ATUALIZAÇÃO " + VERSAO, 30, 8, Color(1.0, 0.78, 0.2))
	_col.add_child(v)
	var t := _rotulo("O QUE CHEGOU NO BICHO EHN", 54, 14, Color.WHITE)
	_col.add_child(t)
	for it in ITENS:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		var marca := ColorRect.new()
		marca.color = it[2]
		marca.custom_minimum_size = Vector2(8, 0)
		h.add_child(marca)
		var tx := VBoxContainer.new()
		tx.add_theme_constant_override("separation", 0)
		tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tx.add_child(_rotulo(it[0], 30, 8, it[2]))
		var d := _rotulo(it[1], 21, 6, Color(0.92, 0.9, 0.98))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(760, 0)
		tx.add_child(d)
		h.add_child(tx)
		_col.add_child(h)
	_x = Button.new()
	_x.text = "✕"
	_x.focus_mode = Control.FOCUS_NONE
	_x.add_theme_font_size_override("font_size", 40)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.05, 0.18, 0.9)
	st.set_corner_radius_all(40)
	st.set_border_width_all(3)
	st.border_color = Color(1, 1, 1, 0.7)
	for k in ["normal", "hover", "pressed"]:
		_x.add_theme_stylebox_override(k, st)
	_x.pressed.connect(_fechar)
	add_child(_x)
	get_viewport().size_changed.connect(_layout)
	_layout()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)

func _layout() -> void:
	var v := get_viewport().get_visible_rect().size
	size = v
	var esc := maxf(v.x / 1600.0, v.y / 900.0)
	_fundo.size = Vector2(1600, 900) * esc
	_fundo.position = (v - _fundo.size) / 2.0
	_escuro.size = v
	_col.size = Vector2(860, 0)
	_col.position = Vector2(maxf(40.0, (v.x - 860.0) / 2.0), 34)
	_x.size = Vector2(80, 80)
	_x.position = Vector2(v.x - 110, 26)

func _fechar() -> void:
	Audio.tocar("clique")
	var cfg := ConfigFile.new()
	cfg.load(Game.ARQ_PROGRESSO)
	cfg.set_value("extra", "novidades", VERSAO)
	cfg.save(Game.ARQ_PROGRESSO)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)

func _rotulo(texto: String, tamanho: int, contorno: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.08))
	l.add_theme_constant_override("outline_size", contorno)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

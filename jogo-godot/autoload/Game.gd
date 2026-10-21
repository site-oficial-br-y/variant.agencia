extends Node
## Autoload "Game": estado global + registra as ações de input por código
## (evita depender do formato de InputEvent no project.godot).

signal estado_mudou(novo)

enum Estado { JOGANDO, MORTO, VITORIA }
var estado: int = Estado.JOGANDO
var personagem: String = "segway"
var checkpoint_x: float = -1.0       # -1 = começa do início; sobrevive ao reinício (R)
var checkpoint_chao: float = 1000.0

const ACOES := {
	"accelerate": [KEY_RIGHT, KEY_D],
	"brake":      [KEY_LEFT, KEY_A],
	"lean_fwd":   [KEY_DOWN, KEY_S],
	"lean_back":  [KEY_UP, KEY_W],
	"eject":      [KEY_SPACE],
	"reset":      [KEY_R],
}

var _gira: CanvasLayer

func _ready() -> void:
	_gira = CanvasLayer.new()
	_gira.layer = 100
	var fundo := ColorRect.new()
	fundo.color = Color(0.07, 0.06, 0.11, 0.96)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gira.add_child(fundo)
	var txt := Label.new()
	txt.text = "GIRA O CELULAR\npra jogar deitado"
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	txt.set_anchors_preset(Control.PRESET_FULL_RECT)
	txt.add_theme_font_size_override("font_size", 64)
	_gira.add_child(txt)
	_gira.visible = false
	add_child(_gira)
	for acao in ACOES:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
		for key in ACOES[acao]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(acao, ev)

func _process(_d: float) -> void:
	var t := DisplayServer.window_get_size()
	_gira.visible = t.y > t.x          # celular em pé

func set_estado(e: int) -> void:
	estado = e
	estado_mudou.emit(e)

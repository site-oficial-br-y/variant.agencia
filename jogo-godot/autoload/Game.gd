extends Node
## Autoload "Game": estado global + registra as ações de input por código
## (evita depender do formato de InputEvent no project.godot).

signal estado_mudou(novo)

enum Estado { JOGANDO, MORTO, VITORIA }
var estado: int = Estado.JOGANDO

const ACOES := {
	"accelerate": [KEY_RIGHT, KEY_D],
	"brake":      [KEY_LEFT, KEY_A],
	"lean_fwd":   [KEY_DOWN, KEY_S],
	"lean_back":  [KEY_UP, KEY_W],
	"eject":      [KEY_SPACE],
	"reset":      [KEY_R],
}

func _ready() -> void:
	for acao in ACOES:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
		for key in ACOES[acao]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(acao, ev)

func set_estado(e: int) -> void:
	estado = e
	estado_mudou.emit(e)

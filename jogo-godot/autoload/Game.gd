extends Node
## Autoload "Game": estado global + registra as ações de input por código
## (evita depender do formato de InputEvent no project.godot).

signal estado_mudou(novo)

enum Estado { JOGANDO, MORTO, VITORIA }
var estado: int = Estado.JOGANDO
var personagem: String = "segway"
var fase: int = 1
const FASES := ["FASE 1", "FASE 2", "FASE 3"]
const NOMES := {"segway": "PÉRINE", "cadeira": "GABRIEL", "scooter": "GIAN", "monociclo": "ERICK", "gamer": "GORISCH"}
## habilidade de cada um (botão especial), sempre com limite de uso
const CHECKPOINTS := false              # sem checkpoint: morreu, volta pro começo da fase
const HABILIDADES := {"segway": "salto", "cadeira": "turbo", "scooter": "turbo", "monociclo": "pulo_duplo", "gamer": "turbo"}
const TURBO_INFINITO := ["cadeira"]       # Gabriel: turbo sem combustível
const BOMBA_EXTRA := ["scooter"]          # Gian: turbo + bomba num segundo botão
const RITMO := 3.0                   # mundo 3x mais rápido: queda pesada e ritmo de Happy Wheels
const ARQ_PROGRESSO := "user://progresso.cfg"
var checkpoint_x: float = -1.0       # -1 = começa do início; sobrevive ao reinício (R)
var checkpoint_chao: float = 1000.0

const ACOES := {
	"accelerate": [KEY_RIGHT, KEY_D],
	"brake":      [KEY_LEFT, KEY_A],
	"lean_fwd":   [KEY_DOWN, KEY_S],
	"lean_back":  [KEY_UP, KEY_W],
	"eject":      [KEY_SPACE],
	"especial":   [KEY_SHIFT, KEY_X],          # habilidade de cada personagem
	"bomba":      [KEY_C, KEY_B],              # bomba do Gian
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

## recorde (s) de uma fase; INF se nunca concluiu
func recorde(f: int) -> float:
	var cfg := ConfigFile.new()
	cfg.load(ARQ_PROGRESSO)
	return float(cfg.get_value("recorde", str(f), INF))

func registrar_vitoria(f: int, tempo: float) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(ARQ_PROGRESSO)
	var melhor := float(cfg.get_value("recorde", str(f), INF))
	if tempo < melhor:
		cfg.set_value("recorde", str(f), tempo)
		cfg.save(ARQ_PROGRESSO)
		return true
	return false

func set_estado(e: int) -> void:
	estado = e
	estado_mudou.emit(e)

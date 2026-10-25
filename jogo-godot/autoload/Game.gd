extends Node
## Autoload "Game": estado global + registra as ações de input por código
## (evita depender do formato de InputEvent no project.godot).

signal estado_mudou(novo)

enum Estado { JOGANDO, MORTO, VITORIA }
var estado: int = Estado.JOGANDO
var personagem: String = "segway"
var fase: int = 1
const FASES := ["", "", "", "LABORATÓRIO", "PÉCE", "ATACADÃO", "ESCOLA", "GERESCH"]   # nome de cada fase pelo número interno
## ordem em que aparecem pro jogador (o número interno não muda: recordes e o Vini continuam valendo)
const ORDEM := [1, 2, 3, 4, 6, 7, 5, 8]

func nome_fase(id: int) -> String:
	var n: String = FASES[id - 1]
	return "FASE %d" % (ORDEM.find(id) + 1) + (": " + n if n != "" else "")

func proxima_fase(id: int) -> int:
	var i := ORDEM.find(id)
	return ORDEM[i + 1] if i >= 0 and i < ORDEM.size() - 1 else -1
const NOMES := {"segway": "PÉRINE", "cadeira": "GABRIEL", "scooter": "GIAN", "monociclo": "ERICK", "gamer": "GORISCH", "bicho": "BICHO", "wendell": "WENDELL", "caio": "CAIO", "vini": "VINI", "lima": "LIMA", "chefe": "CHEFE"}
## habilidade de cada um (botão especial), sempre com limite de uso
const CHECKPOINTS := false              # sem checkpoint: morreu, volta pro começo da fase
const HABILIDADES := {"segway": "salto", "cadeira": "turbo", "scooter": "turbo", "monociclo": "pulo_duplo", "gamer": "turbo", "bicho": "baloes", "wendell": "estrela", "caio": "rapido", "vini": "dash", "lima": "mega_pulo", "chefe": "repele"}
const TURBO_INFINITO := ["cadeira"]       # Gabriel: turbo sem combustível
const BOMBA_EXTRA := ["scooter"]          # Gian: turbo + bomba num segundo botão
const NITRO_EXTRA := ["chefe"]           # Vitinho: nitro de fogo azul no segundo botão (C/B)
const VERSAO := "v25.10-B"            # aparece no canto do lobby (pra conferir se atualizou)
const RITMO := 3.0                   # mundo 3x mais rápido: queda pesada e ritmo de Happy Wheels
const ARQ_PROGRESSO := "user://progresso.cfg"
var checkpoint_x: float = -1.0       # -1 = começa do início; sobrevive ao reinício (R)
var checkpoint_chao: float = 1000.0
var queda_fade := false
var online_n := 1                    # jogadores na luta online (escala a dificuldade)              # fase 7: veio da tela preta do terraço (clareia na luta)

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
	_chave_secreta()
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

## Vini libera pra quem vence a fase 5 (Péce e Cepé) ou abriu o link secreto do dono
func vini_liberado() -> bool:
	var cfg := ConfigFile.new()
	cfg.load(ARQ_PROGRESSO)
	return recorde(5) < INF or bool(cfg.get_value("extra", "vini_dono", false))

## link secreto (?dono=vn7k2q): libera o Vini só no navegador de quem abriu por ele
func _chave_secreta() -> void:
	if not OS.has_feature("web"):
		return
	var busca := str(JavaScriptBridge.eval("window.location.search", true))
	if "dono=vn7k2q" in busca:
		var cfg := ConfigFile.new()
		cfg.load(ARQ_PROGRESSO)
		cfg.set_value("extra", "vini_dono", true)
		cfg.save(ARQ_PROGRESSO)

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

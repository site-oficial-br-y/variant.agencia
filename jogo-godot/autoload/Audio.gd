extends Node
## Autoload "Audio": efeitos sonoros (sintetizados, originais) com variação de tom
## e o ronco do motor em loop, cujo tom acompanha a velocidade.

const SONS := ["clique", "confirma", "impacto_leve", "impacto_forte", "osso", "splat",
	"caixa", "metal", "checkpoint", "vitoria", "morte", "pulo", "turbo", "baloes"]
const VOZES := 10

var _streams: Dictionary = {}
var _vozes: Array[AudioStreamPlayer] = []
var _proxima := 0
var _motor: AudioStreamPlayer
var _ultimo: Dictionary = {}          # som -> ms do último toque (evita metralhadora)

func _ready() -> void:
	for s in SONS:
		_streams[s] = load("res://assets/audio/sfx/%s.wav" % s)
	for i in VOZES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_vozes.append(p)
	var m := load("res://assets/audio/sfx/motor.wav") as AudioStreamWAV
	m.loop_mode = AudioStreamWAV.LOOP_FORWARD
	m.loop_begin = 0
	m.loop_end = int(m.get_length() * m.mix_rate)
	_motor = AudioStreamPlayer.new()
	_motor.stream = m
	_motor.volume_db = -14.0
	add_child(_motor)

## toca um efeito; `forca` 0..1 controla volume; ignora repetição em < 40 ms
func tocar(nome: String, forca: float = 1.0, variacao: float = 0.08) -> void:
	if not _streams.has(nome):
		return
	var agora := Time.get_ticks_msec()
	if agora - int(_ultimo.get(nome, -1000)) < 40:
		return
	_ultimo[nome] = agora
	var p := _vozes[_proxima]
	_proxima = (_proxima + 1) % VOZES
	p.stream = _streams[nome]
	p.volume_db = linear_to_db(clampf(forca, 0.05, 1.0))
	p.pitch_scale = 1.0 + randf_range(-variacao, variacao)
	p.play()

## motor: liga/desliga e ajusta o tom pela fração da velocidade máxima
## música de fundo dos menus (abertura, personagem, fases): loop; não reinicia
## ao trocar de tela de menu; para quando a fase começa
var _musica: AudioStreamPlayer
func musica_menu(ligada: bool) -> void:
	if _musica == null:
		_musica = AudioStreamPlayer.new()
		var st := load("res://assets/audio/musica/menu.mp3") as AudioStreamMP3
		st.loop = true
		_musica.stream = st
		_musica.volume_db = -6.0
		add_child(_musica)
	if ligada and not _musica.playing:
		_musica.play()
	elif not ligada and _musica.playing:
		_musica.stop()

func motor(ligado: bool, fracao: float = 0.0) -> void:
	ligado = false                       # ronco contínuo desligado: era o som chato que tocava o tempo todo
	if not ligado:
		if _motor.playing:
			_motor.stop()
		return
	if not _motor.playing:
		_motor.play()
	_motor.pitch_scale = 0.7 + clampf(fracao, 0.0, 1.2) * 0.9

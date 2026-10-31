extends Node
## Autoload "Audio": efeitos sonoros (sintetizados, originais) com variação de tom
## e o ronco do motor em loop, cujo tom acompanha a velocidade.

const SONS := ["clique", "confirma", "impacto_leve", "impacto_forte", "osso", "splat",
	"caixa", "metal", "checkpoint", "vitoria", "morte", "pulo", "turbo", "baloes", "passo", "pece_grito", "choque", "ronco"]
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
const MENU := "res://assets/audio/musica/menu.mp3"
var _musica: AudioStreamPlayer
var _menu_ligado := false
func musica_menu(ligada: bool) -> void:
	_menu_ligado = ligada
	if _musica == null:
		_musica = AudioStreamPlayer.new()
		_musica.volume_db = -6.0
		add_child(_musica)
	if _musica.stream == null:
		var st := Midia.musica(MENU)
		if st == null:                                # ainda baixando: toca quando chegar
			if ligada:
				_esperar_menu()
			return
		st.set("loop", true)
		_musica.stream = st
	if ligada:
		parar_chefe()
	if ligada and not _musica.playing:
		_musica.play()
	elif not ligada and _musica.playing:
		_musica.stop()

func _esperar_menu() -> void:
	if await Midia.esperar(MENU, 120.0) != "" and _menu_ligado and _musica.stream == null:
		musica_menu(true)

## música de chefe (pece, cepe, vendedor): loop até a fase acabar
var _chefe: AudioStreamPlayer
var _chefe_nome := ""
func musica_chefe(nome: String, inicio := 0.0, loop_desde := 0.0) -> void:
	if _chefe == null:
		_chefe = AudioStreamPlayer.new()
		_chefe.process_mode = Node.PROCESS_MODE_ALWAYS     # segue tocando na cutscene (jogo pausado)
		_chefe.volume_db = -4.0
		add_child(_chefe)
	if _chefe.playing and _chefe_nome == nome:
		return                                        # já está tocando: continua (ex.: queda -> luta)
	_chefe_nome = nome
	var res := "res://assets/audio/musica/%s.ogg" % nome
	var st := Midia.musica(res) as AudioStreamOggVorbis
	if st == null:                                    # ainda baixando: entra quando chegar, no ponto certo
		_chefe.stop()
		var t0 := Time.get_ticks_msec()
		await Midia.esperar(res, 120.0)
		if _chefe_nome != nome or _chefe.playing:
			return
		st = Midia.musica(res) as AudioStreamOggVorbis
		if st == null:
			return
		inicio += (Time.get_ticks_msec() - t0) / 1000.0
		if inicio >= st.get_length():
			inicio = loop_desde
	st.loop = true
	st.loop_offset = loop_desde                       # repete a partir daqui (ex.: parte forte)
	_chefe.stream = st
	_chefe.play(inicio)

## abaixa a música do chefe por um instante (grito do Péce por cima)
func abaixar_chefe(segundos: float) -> void:
	if _chefe == null or not _chefe.playing:
		return
	var tw := _chefe.create_tween()
	tw.tween_property(_chefe, "volume_db", -16.0, 0.15)
	tw.tween_interval(segundos)
	tw.tween_property(_chefe, "volume_db", -4.0, 0.4)

## música do especial do Chefe: toca por cima e abaixa a do chefe enquanto dura
var _ult: AudioStreamPlayer
func musica_ult(ligada: bool) -> void:
	if _ult == null:
		_ult = AudioStreamPlayer.new()
		_ult.process_mode = Node.PROCESS_MODE_ALWAYS
		_ult.volume_db = -2.0
		_ult.stream = load("res://assets/audio/musica/chefe.ogg")
		add_child(_ult)
	if ligada:
		_ult.play()
		if _chefe and _chefe.playing:
			_chefe.volume_db = -28.0
	else:
		_ult.stop()
		if _chefe:
			_chefe.volume_db = -4.0

func parar_chefe() -> void:
	_chefe_nome = ""
	if _chefe and _chefe.playing:
		_chefe.stop()
	if _ult and _ult.playing:
		_ult.stop()

func motor(ligado: bool, fracao: float = 0.0) -> void:
	ligado = false                       # ronco contínuo desligado: era o som chato que tocava o tempo todo
	if not ligado:
		if _motor.playing:
			_motor.stop()
		return
	if not _motor.playing:
		_motor.play()
	_motor.pitch_scale = 0.7 + clampf(fracao, 0.0, 1.2) * 0.9

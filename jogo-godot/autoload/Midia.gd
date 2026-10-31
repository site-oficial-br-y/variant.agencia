extends Node
## Autoload "Midia": músicas grandes e vídeos ficam FORA do pacote do jogo (pasta midia/ do site).
## No navegador baixa na hora que a fase precisa, guarda no aparelho (user://midia) e toca de lá:
## o jogo abre mais rápido e o celular não segura tudo na memória o tempo todo.
## Fora do navegador (editor/testes) usa o arquivo de res:// direto.

const LISTA := "res://midia.json"         # gerado por tools/midia.py: caminho res:// -> nome no site
const PASTA := "user://midia/"

const POR_FASE := {
	5: ["res://assets/audio/musica/pece.ogg", "res://assets/audio/musica/cepe.ogg"],
	6: ["res://assets/audio/musica/vendedor.ogg"],
	7: ["res://assets/audio/musica/escola.ogg", "res://assets/audio/musica/adriano.ogg"],
	8: ["res://assets/geresch/intro.ogv", "res://assets/audio/musica/geresch.ogg"],
	9: ["res://assets/julgamento/entrada.ogv", "res://assets/audio/musica/julgamento.ogg",
		"res://assets/audio/musica/ctamandura.ogg", "res://assets/julgamento/martelo.ogv"],
	10: ["res://assets/audio/musica/james.ogg", "res://assets/audio/musica/semaj.ogg"],
}

var _nomes: Dictionary = {}
var _baixando: Dictionary = {}           # res -> true enquanto baixa
signal chegou(res: String, local: String)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS            # continua baixando com o jogo pausado (cutscene)
	if FileAccess.file_exists(LISTA):
		var d = JSON.parse_string(FileAccess.get_file_as_string(LISTA))
		if typeof(d) == TYPE_DICTIONARY:
			_nomes = d
	DirAccess.make_dir_recursive_absolute(PASTA)
	var atuais := _nomes.values()
	for f in DirAccess.get_files_at(PASTA):             # versão antiga de algum arquivo: apaga
		if not f in atuais:
			DirAccess.remove_absolute(PASTA + f)

func _fora(res: String) -> bool:
	return not FileAccess.file_exists(res) and not ResourceLoader.exists(res) and _nomes.has(res)

## caminho pra usar agora ("" = ainda não baixou)
func local(res: String) -> String:
	if not _fora(res):
		return res
	var arq: String = PASTA + str(_nomes[res])
	return arq if FileAccess.file_exists(arq) else ""

## começa a baixar (se precisar) sem esperar
func preparar(res: String) -> void:
	if local(res) == "" and not _baixando.has(res):
		_baixar(res)

func preparar_fase(f: int) -> void:
	for r in POR_FASE.get(f, []):
		preparar(r)

## espera ficar pronto; "" se não deu em `limite` segundos
func esperar(res: String, limite := 25.0) -> String:
	var l := local(res)
	if l != "":
		return l
	preparar(res)
	var fim := Time.get_ticks_msec() + int(limite * 1000.0)
	while Time.get_ticks_msec() < fim:
		await get_tree().process_frame
		l = local(res)
		if l != "" or not _baixando.has(res):
			return l
	return ""

func _baixar(res: String) -> void:
	_baixando[res] = true
	var nome := str(_nomes[res])
	var url := str(JavaScriptBridge.eval("new URL('midia/%s', location.href).href" % nome, true)) if OS.has_feature("web") else ""
	for tentativa in 3:
		if url == "":
			break
		var h := HTTPRequest.new()
		h.timeout = 60.0
		h.accept_gzip = false
		h.download_file = PASTA + nome + ".parte"
		add_child(h)
		if h.request(url) == OK:
			var r: Array = await h.request_completed
			h.queue_free()
			if int(r[0]) == HTTPRequest.RESULT_SUCCESS and int(r[1]) == 200:
				DirAccess.rename_absolute(PASTA + nome + ".parte", PASTA + nome)
				_baixando.erase(res)
				chegou.emit(res, PASTA + nome)
				return
		else:
			h.queue_free()
		await get_tree().create_timer(2.0, true, false, true).timeout
	_baixando.erase(res)

## música pronta pra tocar (null se ainda não baixou)
func musica(res: String) -> AudioStream:
	var l := local(res)
	if l == "":
		return null
	if l.begins_with("res://"):
		return load(l)
	return AudioStreamOggVorbis.load_from_file(l)

func video(res: String) -> VideoStream:
	var l := local(res)
	if l == "":
		return null
	if l.begins_with("res://"):
		return load(l)
	var v := VideoStreamTheora.new()
	v.file = l
	return v

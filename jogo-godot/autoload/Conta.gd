extends Node
## Autoload "Conta": conta com apelido + senha (Supabase Auth), ranking público dos
## melhores tempos de cada fase e de quem tem mais tempo de jogo. Não usa e-mail de
## verdade: o apelido vira um e-mail interno que nunca recebe nada.
## Tabelas e funções do banco: supabase/ranking.sql (roda uma vez no Supabase).

signal mudou                          # entrou ou saiu da conta

const DOMINIO := "bicho.honkponk.com.br"
const ENVIO_JOGO := 60.0              # manda o tempo de jogo a cada 60 s

var url := ""
var apelido := ""
var _access := ""
var _refresh := ""
var _expira := 0.0
var _jogo := 0.0                      # segundos jogados ainda não enviados
var _envio_t := ENVIO_JOGO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS          # minigame e vídeo pausam a árvore, mas é jogo
	url = Online.PROJETO
	for a in OS.get_cmdline_user_args():
		if a.begins_with("sb="):                     # teste: servidor falso local
			url = a.substr(3)
	var cfg := ConfigFile.new()
	cfg.load(Game.ARQ_PROGRESSO)
	apelido = str(cfg.get_value("conta", "apelido", ""))
	_access = str(cfg.get_value("conta", "access", ""))
	_refresh = str(cfg.get_value("conta", "refresh", ""))
	_expira = float(cfg.get_value("conta", "expira", 0.0))

func logado() -> bool:
	return _refresh != ""

func _process(delta: float) -> void:
	if not logado():
		return
	var cena := get_tree().current_scene
	if cena and cena.scene_file_path == "res://levels/Main.tscn":
		_jogo += delta / Engine.time_scale
	_envio_t -= delta / Engine.time_scale
	if _envio_t <= 0.0:
		_envio_t = ENVIO_JOGO
		_enviar_jogo()

func _enviar_jogo() -> void:
	var s := int(_jogo)
	if s < 1:
		return
	_jogo -= s
	var r := await _pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/bicho_somar_tempo", {"p_segundos": s, "p_personagem": Game.personagem}, true)
	if int(r[0]) == 0 or int(r[0]) >= 500:           # sem conexão: tenta de novo no próximo envio
		_jogo += s

## apelido -> parte do e-mail interno (minúsculo, sem acento, só letra, número e _)
static func chave(ap: String) -> String:
	var de := "áàâãäéèêëíìîïóòôõöúùûüçñ"
	var para := "aaaaaeeeeiiiiooooouuuucn"
	var s := ""
	for ch in ap.strip_edges().to_lower():
		var i := de.find(ch)
		var c: String = para[i] if i >= 0 else ch
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_":
			s += c
	return s

func _validar(ap: String, senha: String) -> String:
	var a := ap.strip_edges()
	if a.length() < 3 or a.length() > 16:
		return "O apelido tem que ter de 3 a 16 letras."
	if chave(a).length() < 3:
		return "Usa pelo menos 3 letras ou números no apelido."
	if senha.length() < 6:
		return "A senha tem que ter pelo menos 6 caracteres."
	return ""

func criar(ap: String, senha: String) -> String:
	var erro := _validar(ap, senha)
	if erro != "":
		return erro
	var r := await _pedir(HTTPClient.METHOD_POST, "/auth/v1/signup",
		{"email": chave(ap) + "@" + DOMINIO, "password": senha, "data": {"apelido": ap.strip_edges()}})
	if int(r[0]) == 0:
		return "Sem conexão. Tenta de novo."
	if int(r[0]) >= 400:
		return _erro(r[1])
	if not _guardar_sessao(r[1]):
		return "Conta criada, mas o Supabase pediu confirmação de e-mail (o dono precisa desligar isso)."
	apelido = ap.strip_edges()
	_entrou()
	return ""

func entrar(ap: String, senha: String) -> String:
	if chave(ap).length() < 3 or senha == "":
		return "Preenche o apelido e a senha."
	var r := await _pedir(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password",
		{"email": chave(ap) + "@" + DOMINIO, "password": senha})
	if int(r[0]) == 0:
		return "Sem conexão. Tenta de novo."
	if int(r[0]) >= 400 or not _guardar_sessao(r[1]):
		return _erro(r[1])
	var meta = (r[1] as Dictionary).get("user", {}).get("user_metadata", {})
	apelido = str(meta.get("apelido", ap.strip_edges())) if typeof(meta) == TYPE_DICTIONARY else ap.strip_edges()
	_entrou()
	return ""

func sair() -> void:
	if _jogo >= 1.0:
		await _enviar_jogo()
	apelido = ""
	_access = ""
	_refresh = ""
	_expira = 0.0
	_jogo = 0.0
	_salvar()
	mudou.emit()

func _entrou() -> void:
	_salvar()
	_envio_t = ENVIO_JOGO
	mudou.emit()
	for f in range(1, 9):                            # recordes feitos antes de ter conta também valem
		var t := Game.recorde(f)
		if t < INF:
			enviar_recorde(f, t, "")

## vitória sozinho, do começo da fase: o servidor só guarda se for melhor
func enviar_recorde(fase: int, tempo: float, personagem: String) -> void:
	if not logado():
		return
	await _pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/bicho_registrar_recorde",
		{"p_fase": fase, "p_tempo": snappedf(tempo, 0.01), "p_personagem": personagem if personagem != "" else null}, true)

## [código http, lista]; código 0 = sem conexão
func ranking_fase(fase: int) -> Array:
	return await _pedir(HTTPClient.METHOD_GET, "/rest/v1/bicho_rank_tempos?select=apelido,tempo,personagem&fase=eq.%d&order=tempo.asc,quando.asc&limit=50" % fase)

func ranking_jogo() -> Array:
	return await _pedir(HTTPClient.METHOD_GET, "/rest/v1/bicho_rank_jogo?select=apelido,tempo_jogo,personagem&order=tempo_jogo.desc&limit=50")

func _guardar_sessao(d) -> bool:
	if typeof(d) != TYPE_DICTIONARY or not d.has("access_token") or not d.has("refresh_token"):
		return false
	_access = str(d["access_token"])
	_refresh = str(d["refresh_token"])
	_expira = Time.get_unix_time_from_system() + float(d.get("expires_in", 3600))
	_salvar()
	return true

func _salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Game.ARQ_PROGRESSO)
	cfg.set_value("conta", "apelido", apelido)
	cfg.set_value("conta", "access", _access)
	cfg.set_value("conta", "refresh", _refresh)
	cfg.set_value("conta", "expira", _expira)
	cfg.save(Game.ARQ_PROGRESSO)

## token válido (renova se estiver pra vencer); "" se a conta caiu
func _token() -> String:
	if _refresh == "":
		return ""
	if Time.get_unix_time_from_system() < _expira - 60.0:
		return _access
	var r := await _pedir(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh})
	if _guardar_sessao(r[1]):
		return _access
	if int(r[0]) == 400 or int(r[0]) == 401 or int(r[0]) == 403:   # sessão não vale mais: sai da conta
		apelido = ""
		_access = ""
		_refresh = ""
		_salvar()
		mudou.emit()
	return ""

func _erro(d) -> String:
	var cod := ""
	var msg := ""
	if typeof(d) == TYPE_DICTIONARY:
		cod = str(d.get("error_code", d.get("error", "")))
		msg = str(d.get("msg", d.get("error_description", d.get("message", ""))))
	match cod:
		"invalid_credentials", "invalid_grant":
			return "Apelido ou senha errados."
		"user_already_exists", "email_exists":
			return "Esse apelido já tem dono. Escolhe outro."
		"weak_password":
			return "Senha fraca. Usa pelo menos 6 caracteres."
		"over_request_rate_limit", "over_email_send_rate_limit":
			return "Muitas tentativas. Espera um pouco."
		"email_not_confirmed":
			return "O Supabase está pedindo confirmação de e-mail (o dono precisa desligar isso)."
		"signup_disabled":
			return "Cadastro desligado no Supabase."
	return msg if msg != "" else "Deu erro. Tenta de novo."

## requisição JSON pro Supabase: [código http, resposta]
func _pedir(metodo: int, caminho: String, corpo = null, com_conta := false) -> Array:
	var tk := Online.CHAVE
	if com_conta:
		tk = await _token()
		if tk == "":
			return [401, null]
	var h := HTTPRequest.new()
	h.timeout = 15.0
	add_child(h)
	var cab := PackedStringArray(["apikey: " + Online.CHAVE, "Authorization: Bearer " + tk, "Content-Type: application/json"])
	if h.request(url + caminho, cab, metodo, "" if corpo == null else JSON.stringify(corpo)) != OK:
		h.queue_free()
		return [0, null]
	var r: Array = await h.request_completed
	h.queue_free()
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS:
		return [0, null]
	var txt := (r[3] as PackedByteArray).get_string_from_utf8()
	return [int(r[1]), JSON.parse_string(txt) if txt != "" else null]

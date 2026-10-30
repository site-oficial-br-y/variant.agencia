extends Node
## Autoload "Conta": conta com usuário + senha (Supabase Auth) e nick público, ranking
## dos melhores tempos de cada fase e de quem tem mais tempo de jogo. O usuário só serve
## pra entrar (vira um e-mail interno que nunca recebe nada); no ranking aparece o nick,
## que dá pra trocar quando quiser. Banco: supabase/ranking.sql (roda uma vez no Supabase).

signal mudou                          # entrou, saiu ou trocou o nick

const DOMINIO := "bicho.honkponk.com.br"
const ENVIO_JOGO := 60.0              # manda o tempo de jogo a cada 60 s

var url := ""
var nick := ""
var usuario := ""
var user_id := ""
var _access := ""
var _refresh := ""
var _expira := 0.0
var inventario: Array = []            # skins compradas (fica salvo: funciona sem internet)
var admin := false                    # dono do jogo: confirma os pedidos e tem todas as skins
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
	nick = str(cfg.get_value("conta", "nick", ""))
	usuario = str(cfg.get_value("conta", "usuario", ""))
	user_id = str(cfg.get_value("conta", "user_id", ""))
	_access = str(cfg.get_value("conta", "access", ""))
	_refresh = str(cfg.get_value("conta", "refresh", ""))
	_expira = float(cfg.get_value("conta", "expira", 0.0))
	inventario = cfg.get_value("conta", "inventario", [])
	admin = bool(cfg.get_value("conta", "admin", false))
	if logado():
		carregar_inventario.call_deferred()

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

## usuário -> parte do e-mail interno (minúsculo, sem acento, só letra, número e _)
static func chave(u: String) -> String:
	var de := "áàâãäéèêëíìîïóòôõöúùûüçñ"
	var para := "aaaaaeeeeiiiiooooouuuucn"
	var s := ""
	for ch in u.strip_edges().to_lower():
		var i := de.find(ch)
		var c: String = para[i] if i >= 0 else ch
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_":
			s += c
	return s

static func erro_nick(n: String) -> String:
	var t := n.strip_edges()
	if t.length() < 3 or t.length() > 16:
		return "O nick tem que ter de 3 a 16 letras."
	return ""

func criar(u: String, senha: String, n: String) -> String:
	var k := chave(u)
	if k.length() < 3 or k.length() > 20:
		return "O usuário tem que ter de 3 a 20 letras ou números."
	if senha.length() < 6:
		return "A senha tem que ter pelo menos 6 caracteres."
	var nk := n.strip_edges() if n.strip_edges() != "" else u.strip_edges()
	if erro_nick(nk) != "":
		return erro_nick(nk)
	var r := await _pedir(HTTPClient.METHOD_POST, "/auth/v1/signup",
		{"email": k + "@" + DOMINIO, "password": senha, "data": {"apelido": nk, "usuario": k}})
	if int(r[0]) == 0:
		return "Sem conexão. Tenta de novo."
	if int(r[0]) >= 400:
		return _erro(r[1])
	if not _guardar_sessao(r[1]):
		return "Conta criada, mas o Supabase pediu confirmação de e-mail (o dono precisa desligar isso)."
	usuario = k
	nick = nk
	await _entrou()
	return ""

func entrar(u: String, senha: String) -> String:
	var k := chave(u)
	if k.length() < 3 or senha == "":
		return "Preenche o usuário e a senha."
	var r := await _pedir(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password",
		{"email": k + "@" + DOMINIO, "password": senha})
	if int(r[0]) == 0:
		return "Sem conexão. Tenta de novo."
	if int(r[0]) >= 400 or not _guardar_sessao(r[1]):
		return _erro(r[1])
	usuario = k
	var meta = (r[1] as Dictionary).get("user", {}).get("user_metadata", {})
	nick = str(meta.get("apelido", k)) if typeof(meta) == TYPE_DICTIONARY else k
	var p := await _pedir(HTTPClient.METHOD_GET, "/rest/v1/bicho_perfis?select=apelido&id=eq." + user_id)
	if int(p[0]) == 200 and typeof(p[1]) == TYPE_ARRAY and not (p[1] as Array).is_empty():
		nick = str((p[1] as Array)[0].get("apelido", nick))   # nick atual (pode ter trocado)
	await _entrou()
	return ""

func trocar_nick(n: String) -> String:
	var nk := n.strip_edges()
	if erro_nick(nk) != "":
		return erro_nick(nk)
	var r := await _pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/bicho_trocar_apelido", {"p_apelido": nk}, true)
	if int(r[0]) == 0:
		return "Sem conexão. Tenta de novo."
	match str(r[1]) if int(r[0]) == 200 else "":
		"ok":
			nick = nk
			_salvar()
			mudou.emit()
			return ""
		"existe":
			return "Esse nick já tem dono. Escolhe outro."
		"tamanho":
			return erro_nick("")
	return "Não deu pra trocar agora. Tenta de novo."

func sair() -> void:
	if _jogo >= 1.0:
		await _enviar_jogo()
	_limpar()

func _limpar() -> void:
	nick = ""
	usuario = ""
	user_id = ""
	_access = ""
	_refresh = ""
	_expira = 0.0
	_jogo = 0.0
	inventario = []
	admin = false
	_salvar()
	mudou.emit()

func _entrou() -> void:
	_salvar()
	_envio_t = ENVIO_JOGO
	mudou.emit()
	carregar_inventario()
	# recordes antigos do aparelho não sobem mais (vinham tempos impossíveis); só vitória nova conta

# ---------- loja e inventário ----------
func tem(item: String) -> bool:
	return admin or item in inventario

## atualiza as skins compradas (e se é o dono) a partir do servidor
func carregar_inventario() -> void:
	if not logado():
		return
	var r := await _pedir(HTTPClient.METHOD_GET, "/rest/v1/bicho_inventario?select=item", null, true)
	if int(r[0]) == 200 and typeof(r[1]) == TYPE_ARRAY:
		inventario = (r[1] as Array).map(func(d): return str(d.get("item", "")))
	var a := await _pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/bicho_sou_admin", {}, true)
	if int(a[0]) == 200:
		admin = a[1] == true
	_salvar()
	mudou.emit()

## [código, lista de itens à venda]
func itens_loja() -> Array:
	return await _pedir(HTTPClient.METHOD_GET, "/rest/v1/bicho_itens?select=item,personagem,nome,raridade,preco,ativo&order=ordem")

## pedido novo (ou o que já está em aberto): {"codigo", "valor", "item"} ou {"erro"}
func criar_pedido(item: String) -> Dictionary:
	var r := await _pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/bicho_criar_pedido", {"p_item": item}, true)
	if int(r[0]) == 0:
		return {"erro": "conexao"}
	if int(r[0]) != 200 or typeof(r[1]) != TYPE_DICTIONARY:
		return {"erro": "servidor"}
	return r[1]

func meus_pedidos() -> Array:
	return await _pedir(HTTPClient.METHOD_GET, "/rest/v1/bicho_pedidos?select=codigo,item,valor,status,criado_em&order=criado_em.desc&limit=20", null, true)

## só o dono
func pedidos_abertos() -> Array:
	return await _pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/bicho_pedidos_abertos", {}, true)

func resolver_pedido(codigo: String, pago: bool) -> String:
	var r := await _pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/bicho_resolver_pedido", {"p_codigo": codigo, "p_pago": pago}, true)
	return str(r[1]) if int(r[0]) == 200 else "erro"

## vitória sozinho, do começo da fase: o servidor só guarda se for melhor.
## Devolve o código http (200 = foi), -1 sem conta, -2 servidor recusou o tempo.
func enviar_recorde(fase: int, tempo: float, personagem: String) -> int:
	if not logado():
		return -1
	var corpo := {"p_fase": fase, "p_tempo": snappedf(tempo, 0.01), "p_personagem": personagem if personagem != "" else null}
	var r := await _pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/bicho_registrar_recorde", corpo, true)
	if int(r[0]) == 0 or int(r[0]) >= 500:           # falhou: tenta de novo daqui a pouco
		await get_tree().create_timer(3.0, true, false, true).timeout
		r = await _pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/bicho_registrar_recorde", corpo, true)
	if int(r[0]) == 200 and r[1] != true:
		return -2
	return int(r[0])

## [código http, lista]; código 0 = sem conexão
func ranking_fase(fase: int) -> Array:
	return await _pedir(HTTPClient.METHOD_GET, "/rest/v1/bicho_rank_tempos?select=apelido,tempo,personagem,user_id&fase=eq.%d&order=tempo.asc,quando.asc&limit=50" % fase)

func ranking_jogo() -> Array:
	return await _pedir(HTTPClient.METHOD_GET, "/rest/v1/bicho_rank_jogo?select=apelido,tempo_jogo,personagem,user_id&order=tempo_jogo.desc&limit=50")

func _guardar_sessao(d) -> bool:
	if typeof(d) != TYPE_DICTIONARY or not d.has("access_token") or not d.has("refresh_token"):
		return false
	_access = str(d["access_token"])
	_refresh = str(d["refresh_token"])
	_expira = Time.get_unix_time_from_system() + float(d.get("expires_in", 3600))
	var u = d.get("user", {})
	if typeof(u) == TYPE_DICTIONARY and u.has("id"):
		user_id = str(u["id"])
	_salvar()
	return true

func _salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Game.ARQ_PROGRESSO)
	cfg.set_value("conta", "nick", nick)
	cfg.set_value("conta", "usuario", usuario)
	cfg.set_value("conta", "user_id", user_id)
	cfg.set_value("conta", "access", _access)
	cfg.set_value("conta", "refresh", _refresh)
	cfg.set_value("conta", "expira", _expira)
	cfg.set_value("conta", "inventario", inventario)
	cfg.set_value("conta", "admin", admin)
	cfg.save(Game.ARQ_PROGRESSO)

## token válido (renova se estiver pra vencer); "" se a conta caiu
func _token(forcar := false) -> String:
	if _refresh == "":
		return ""
	if not forcar and Time.get_unix_time_from_system() < _expira - 60.0:
		return _access
	var r := await _pedir(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh})
	if int(r[0]) == 0:                               # celular sem sinal na hora: tenta mais uma vez
		await get_tree().create_timer(2.0, true, false, true).timeout
		r = await _pedir(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh})
	if _guardar_sessao(r[1]):
		return _access
	if int(r[0]) == 400 or int(r[0]) == 401 or int(r[0]) == 403:   # sessão não vale mais: sai da conta
		_limpar()
	return ""

func _erro(d) -> String:
	var cod := ""
	var msg := ""
	if typeof(d) == TYPE_DICTIONARY:
		cod = str(d.get("error_code", d.get("error", "")))
		msg = str(d.get("msg", d.get("error_description", d.get("message", ""))))
	match cod:
		"invalid_credentials", "invalid_grant":
			return "Usuário ou senha errados."
		"user_already_exists", "email_exists":
			return "Esse usuário já existe. Escolhe outro."
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
func _pedir(metodo: int, caminho: String, corpo = null, com_conta := false, repetiu := false) -> Array:
	var tk := Online.CHAVE
	if com_conta:
		tk = await _token()
		if tk == "":
			return [0 if logado() else -1, null]
	var h := HTTPRequest.new()
	h.timeout = 15.0
	h.accept_gzip = false                            # no navegador a resposta já chega descompactada
	add_child(h)
	var cab := PackedStringArray(["apikey: " + Online.CHAVE, "Authorization: Bearer " + tk, "Content-Type: application/json"])
	if h.request(url + caminho, cab, metodo, "" if corpo == null else JSON.stringify(corpo)) != OK:
		h.queue_free()
		return [0, null]
	var r: Array = await h.request_completed
	h.queue_free()
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS:
		return [0, null]
	if com_conta and not repetiu and int(r[1]) == 401:   # token venceu antes da hora (relógio do aparelho): renova e repete
		if await _token(true) != "":
			return await _pedir(metodo, caminho, corpo, true, true)
	var txt := (r[3] as PackedByteArray).get_string_from_utf8()
	return [int(r[1]), JSON.parse_string(txt) if txt != "" else null]

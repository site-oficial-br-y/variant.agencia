extends Node
## Autoload "Online": sala em tempo real pelo Supabase Realtime (canal broadcast, sem
## banco). Cada jogador manda o próprio estado ~10x/s; quem criou a sala (host)
## comanda o chefe e manda os eventos dele. Mensagens: {"e": evento, "de": id, ...}.

signal recebeu(evento: String, dados: Dictionary, de: String)
signal jogadores_mudou
signal conectou
signal caiu

const PROJETO := "https://yowwwtstwdeudbgzddcf.supabase.co"
const CHAVE := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlvd3d3dHN0d2RldWRiZ3pkZGNmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI4Njc1NDIsImV4cCI6MjEwODQ0MzU0Mn0.w_kpeJlJCk84kA7ejQpY0zd_wBjLOwGOmIkZ2Yecd_w"
const MAX_JOGADORES := 4

var ws := WebSocketPeer.new()
var id := ""
var sala := ""
var host := false
var ativo := false                   # dentro de uma partida online
var rodada := 0                      # cada recomeço da luta (evita recomeçar duas vezes)
var conectado := false
var jogadores: Dictionary = {}       # id -> {"nome", "p", "t", "host"}
var _topico := ""
var _ref := 0
var _hb := 0.0
var _oi := 0.0
var _estado_ant := WebSocketPeer.STATE_CLOSED

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS          # continua na cutscene (jogo pausado)
	randomize()
	id = "%08x" % (randi() & 0x7fffffff)

func _url() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("rt="):                     # teste: ponte local
			return a.substr(3)
	return PROJETO.replace("https://", "wss://") + "/realtime/v1/websocket?apikey=" + CHAVE + "&vsn=1.0.0"

static func novo_codigo() -> String:
	var letras := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var c := ""
	for i in 4:
		c += letras[randi() % letras.length()]
	return c

## entra (ou cria) a sala com esse código
func entrar(codigo: String, como_host: bool) -> void:
	sair()
	sala = codigo.strip_edges().to_upper()
	host = como_host
	_topico = "realtime:bicho-" + sala
	jogadores.clear()
	ws = WebSocketPeer.new()
	ws.connect_to_url(_url())
	_estado_ant = WebSocketPeer.STATE_CONNECTING

func sair() -> void:
	if conectado:
		enviar("tchau", {})
	if ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		ws.close()
	conectado = false
	ativo = false
	sala = ""
	jogadores.clear()

func _mandar(evento_phx: String, payload: Dictionary) -> void:
	_ref += 1
	ws.send_text(JSON.stringify({"topic": _topico if evento_phx != "heartbeat" else "phoenix",
		"event": evento_phx, "payload": payload, "ref": str(_ref)}))

func enviar(evento: String, dados: Dictionary) -> void:
	if not conectado:
		return
	var d := dados.duplicate()
	d["e"] = evento
	d["de"] = id
	_mandar("broadcast", {"type": "broadcast", "event": "m", "payload": d})

func numero_jogadores() -> int:
	return 1 + jogadores.size()

func _process(delta: float) -> void:
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN and _estado_ant != WebSocketPeer.STATE_OPEN:
		_mandar("phx_join", {"config": {"broadcast": {"self": false, "ack": false}, "presence": {"key": id}}})
	if st == WebSocketPeer.STATE_CLOSED and _estado_ant != WebSocketPeer.STATE_CLOSED:
		var era := conectado
		conectado = false
		if era or sala != "":
			caiu.emit()
	_estado_ant = st
	if st != WebSocketPeer.STATE_OPEN:
		return
	while ws.get_available_packet_count() > 0:
		var txt := ws.get_packet().get_string_from_utf8()
		var m = JSON.parse_string(txt)
		if typeof(m) != TYPE_DICTIONARY:
			continue
		_tratar(m)
	_hb -= delta
	if _hb <= 0.0:
		_hb = 25.0
		_mandar("heartbeat", {})
	if conectado:
		_oi -= delta
		if _oi <= 0.0:
			_oi = 1.0
			enviar("oi", {"nome": Game.NOMES.get(Game.personagem, "?"), "p": Game.personagem, "host": host})
		var mudou := false
		var agora := Time.get_ticks_msec()
		for k in jogadores.keys():
			if agora - int(jogadores[k]["t"]) > 6000:      # sumiu (fechou o jogo)
				jogadores.erase(k)
				mudou = true
		if mudou:
			jogadores_mudou.emit()

func _tratar(m: Dictionary) -> void:
	var ev: String = m.get("event", "")
	if ev == "phx_reply" and m.get("topic", "") == _topico:
		var p: Dictionary = m.get("payload", {})
		if p.get("status", "") == "ok" and not conectado:
			conectado = true
			_oi = 0.0
			conectou.emit()
		return
	if ev != "broadcast":
		return
	var d = m.get("payload", {}).get("payload", {})
	if typeof(d) != TYPE_DICTIONARY:
		return
	var de: String = str(d.get("de", ""))
	var e: String = str(d.get("e", ""))
	if de == "" or de == id:
		return
	if e == "tchau":
		jogadores.erase(de)
		jogadores_mudou.emit()
	elif e in ["oi", "p"]:
		var novo := not jogadores.has(de)
		var j: Dictionary = jogadores.get(de, {})
		j["t"] = Time.get_ticks_msec()
		if d.has("nome"):
			j["nome"] = d["nome"]
		if d.has("p"):
			j["p"] = d["p"]
		if d.has("host"):
			j["host"] = d["host"]
		jogadores[de] = j
		if novo:
			jogadores_mudou.emit()
	recebeu.emit(e, d, de)

class_name Pix
## Pix "copia e cola" (padrão BR Code do Banco Central) com valor e código do pedido, e o
## QR code dele (no navegador, desenhado pela biblioteca qrcode.js que vai junto do jogo).

const CHAVE := "+5513996410149"
const NOME := "VINICIUS MACEDO"
const CIDADE := "SANTOS"

static func _campo(id: String, valor: String) -> String:
	return id + "%02d" % valor.length() + valor

static func _crc16(s: String) -> String:
	var crc := 0xFFFF
	for b in s.to_utf8_buffer():
		crc ^= b << 8
		for i in 8:
			crc = ((crc << 1) ^ 0x1021) if (crc & 0x8000) else (crc << 1)
			crc &= 0xFFFF
	return "%04X" % crc

## texto do Pix copia e cola
static func copia_e_cola(valor: float, pedido: String) -> String:
	var conta := _campo("00", "br.gov.bcb.pix") + _campo("01", CHAVE)
	var s := _campo("00", "01") + _campo("26", conta) + _campo("52", "0000") + _campo("53", "986") \
		+ _campo("54", "%.2f" % valor) + _campo("58", "BR") + _campo("59", NOME) + _campo("60", CIDADE) \
		+ _campo("62", _campo("05", ("BICHO" + pedido).left(25))) + "6304"
	return s + _crc16(s)

## matriz do QR (Array de Array de bool) ou [] fora do navegador
static func qr(texto: String) -> Array:
	if not OS.has_feature("web"):
		return []
	var js := "(function(t){try{var q=qrcode(0,'M');q.addData(t);q.make();var n=q.getModuleCount(),s='';" \
		+ "for(var r=0;r<n;r++)for(var c=0;c<n;c++)s+=q.isDark(r,c)?'1':'0';return n+':'+s;}catch(e){return '';}})(%s)" % JSON.stringify(texto)
	var r := str(JavaScriptBridge.eval(js, true))
	var p := r.find(":")
	if p < 0:
		return []
	var n := int(r.left(p))
	var bits := r.substr(p + 1)
	var m: Array = []
	for y in n:
		var linha: Array = []
		for x in n:
			linha.append(bits[y * n + x] == "1")
		m.append(linha)
	return m

extends Camera2D
class_name FollowCamera
## Câmera que segue um alvo com suavização. Não é filha do alvo (não herda rotação).

@export var alvo: Node2D
@export var lerp_rate: float = 0.12

func _ready() -> void:
	enabled = true
	make_current()

func _physics_process(_delta: float) -> void:
	if is_instance_valid(alvo):
		global_position = global_position.lerp(alvo.global_position, lerp_rate)

var tremor := 0.0                    # 0..1: pancada forte, explosão (decai sozinho)
var _sacudida := Vector2.ZERO        # só a parte do tremor: o offset da fase (olhar pra frente) fica intacto

func _process(delta: float) -> void:
	if tremor <= 0.0 and _sacudida == Vector2.ZERO:
		return
	offset -= _sacudida
	_sacudida = Vector2.ZERO
	if tremor > 0.0:
		var a := 38.0 * tremor * tremor
		_sacudida = Vector2(randf_range(-a, a), randf_range(-a, a))
		tremor = maxf(0.0, tremor - delta * 2.2 / maxf(Engine.time_scale, 0.01))
	offset += _sacudida

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

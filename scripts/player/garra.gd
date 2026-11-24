extends Sprite2D

@export_group("Animação do Golpe")
@export var angulo_inicial_graus: float = -26.0
@export var angulo_final_graus: float = 18.0
@export var deslocamento_inicial: Vector2 = Vector2(-10.0, -6.0)
@export var deslocamento_final: Vector2 = Vector2(12.0, 4.0)
@export_range(0.05, 0.5, 0.01) var duracao_arco: float = 0.24

@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	var direcao: float = -1.0 if flip_h else 1.0
	rotation = deg_to_rad(angulo_inicial_graus * direcao)
	offset = Vector2(deslocamento_inicial.x * direcao, deslocamento_inicial.y)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(
		self,
		"rotation",
		deg_to_rad(angulo_final_graus * direcao),
		duracao_arco
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		self,
		"offset",
		Vector2(deslocamento_final.x * direcao, deslocamento_final.y),
		duracao_arco
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if anim_player != null:
		anim_player.animation_finished.connect(_on_animation_finished)
	else:
		tween.chain().tween_callback(queue_free)


func _on_animation_finished(_anim_name: StringName) -> void:
	queue_free()

class_name EnemyDeathParticles
extends Node2D

@onready var _smoke_puff: CPUParticles2D = $SmokePuff
@onready var _core_burst: CPUParticles2D = $CoreBurst
@onready var _sparks: CPUParticles2D = $Sparks

var _tint: Color = Color(1.0, 0.45, 0.25, 1.0)
var _effect_scale: float = 1.0


func configure(tint: Color, effect_scale: float = 1.0) -> void:
	_tint = tint
	_effect_scale = maxf(0.2, effect_scale)
	if is_node_ready():
		_play()


func _ready() -> void:
	_play()


func _play() -> void:
	scale = Vector2.ONE * _effect_scale

	if is_instance_valid(_smoke_puff):
		var smoke_color: Color = _tint.darkened(0.35)
		smoke_color.a = 0.55
		_smoke_puff.color = smoke_color
		_smoke_puff.restart()

	if is_instance_valid(_core_burst):
		_core_burst.color = _tint
		_core_burst.restart()

	if is_instance_valid(_sparks):
		_sparks.color = _tint.lightened(0.45)
		_sparks.restart()


func _on_particles_finished() -> void:
	queue_free()

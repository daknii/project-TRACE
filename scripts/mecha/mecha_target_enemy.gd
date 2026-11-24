class_name MechaTargetEnemy
extends CharacterBody2D

signal vida_alterada(vida_atual: int, vida_maxima: int)
signal morreu

@export_group("Health")
@export_range(1, 100, 1) var vida_maxima: int = 10

@export_group("Movement")
@export_range(0.0, 200.0, 5.0) var patrol_speed: float = 26.0
@export_range(0.0, 500.0, 10.0) var patrol_distance: float = 180.0

@export_group("Hit Feedback")
@export_range(0.0, 30.0, 0.5) var hit_shake_strength: float = 9.0
@export_range(5.0, 80.0, 1.0) var hit_shake_decay: float = 34.0
@export_range(0.0, 40.0, 1.0) var death_camera_shake: float = 16.0
@export var death_particles_scene: PackedScene = preload("res://components/enemy_death_particles.tscn")
@export var death_particle_color: Color = Color(1.0, 0.36, 0.22, 1.0)
@export_range(0.3, 4.0, 0.1) var death_particle_scale: float = 2.2

@onready var _visuals: Node2D = $Visuals
@onready var _floor_check_left: RayCast2D = $FloorCheckLeft
@onready var _floor_check_right: RayCast2D = $FloorCheckRight
@onready var _health_bar: ProgressBar = $HealthBar
@onready var _hp_label: Label = $HealthBar/HpLabel
@onready var _hit_sparks: CPUParticles2D = $HitSparks

var vida: int = 10
var esta_morto: bool = false

var _origin_x: float = 0.0
var _patrol_dir: float = -1.0
var _shake_strength: float = 0.0
var _visuals_rest_pos: Vector2 = Vector2.ZERO
var _flash_tween: Tween


func _ready() -> void:
	vida = vida_maxima
	_origin_x = global_position.x
	_visuals_rest_pos = _visuals.position
	_update_health_ui()


func _physics_process(delta: float) -> void:
	if esta_morto:
		return

	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	_update_patrol()
	move_and_slide()
	_update_hit_shake(delta)


func _update_patrol() -> void:
	if patrol_speed <= 0.0:
		velocity.x = 0.0
		return

	if is_on_wall():
		_patrol_dir *= -1.0
	elif _patrol_dir < 0.0:
		if global_position.x <= _origin_x - patrol_distance or not _floor_check_left.is_colliding():
			_patrol_dir = 1.0
	elif _patrol_dir > 0.0:
		if global_position.x >= _origin_x + patrol_distance or not _floor_check_right.is_colliding():
			_patrol_dir = -1.0

	velocity.x = _patrol_dir * patrol_speed
	_visuals.scale.x = -1.0 if _patrol_dir < 0.0 else 1.0


func _update_hit_shake(delta: float) -> void:
	if _shake_strength > 0.01:
		_visuals.position = _visuals_rest_pos + Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength * 0.6, _shake_strength * 0.6)
		)
		_shake_strength = move_toward(_shake_strength, 0.0, hit_shake_decay * delta)
	elif _visuals.position != _visuals_rest_pos:
		_visuals.position = _visuals_rest_pos


func tomar_dano(quantidade: int = 1) -> void:
	if esta_morto or quantidade <= 0:
		return

	vida = clampi(vida - quantidade, 0, vida_maxima)
	vida_alterada.emit(vida, vida_maxima)
	_update_health_ui()
	_play_hit_feedback()

	if vida <= 0:
		_morrer()


func _update_health_ui() -> void:
	if is_instance_valid(_health_bar):
		_health_bar.max_value = vida_maxima
		_health_bar.value = vida
	if is_instance_valid(_hp_label):
		_hp_label.text = "%d/%d" % [vida, vida_maxima]


func _play_hit_feedback() -> void:
	_shake_strength = maxf(_shake_strength, hit_shake_strength)

	if is_instance_valid(_hit_sparks):
		_hit_sparks.restart()

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	_visuals.modulate = Color(2.2, 2.2, 2.2, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_visuals, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.14)


func _morrer() -> void:
	esta_morto = true
	_spawn_death_particles()
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_camera_shake"):
		player.call("apply_camera_shake", death_camera_shake)
	morreu.emit()
	call_deferred("queue_free")


func _spawn_death_particles() -> void:
	if death_particles_scene == null:
		return
	var particles: Node2D = death_particles_scene.instantiate() as Node2D
	if particles == null:
		return
	var parent_node: Node = get_parent() if get_parent() else get_tree().current_scene
	if parent_node == null:
		particles.queue_free()
		return
	parent_node.add_child(particles)
	particles.global_position = global_position
	if particles.has_method("configure"):
		particles.call("configure", death_particle_color, death_particle_scale)


func _on_hitbox_area_entered(area: Area2D) -> void:
	# MechaProjectile calls tomar_dano directly; handle other player_damage areas (e.g. cat claw).
	if area.is_in_group("player_damage") and not (area is MechaProjectile):
		tomar_dano(1)

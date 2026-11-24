class_name CarcassZoneManager
extends CityZoneManager

signal zona_trocando
signal zona_entrada(titulo: String)

@export var fireflies_path: NodePath = NodePath("../Vagalumes")
@export var abyss_particles_path: NodePath = NodePath("../ParticulasAbismo")

@onready var _fireflies: CPUParticles2D = get_node_or_null(fireflies_path) as CPUParticles2D
@onready var _abyss_particles: CPUParticles2D = get_node_or_null(abyss_particles_path) as CPUParticles2D


func _swap_zone(zone_id: StringName, spawn_id: StringName, with_fade: bool) -> void:
	var previous_zone: CityZone = _current_zone
	await super._swap_zone(zone_id, spawn_id, with_fade)
	if not is_inside_tree():
		return
	if is_instance_valid(_current_zone) and _current_zone != previous_zone:
		zona_entrada.emit(_current_zone.zone_title)


func _apply_zone_settings(zone: CityZone, spawn_id: StringName) -> void:
	zona_trocando.emit()
	super._apply_zone_settings(zone, spawn_id)

	var bounds: Rect2i = zone.camera_bounds
	var center: Vector2 = Vector2(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y + bounds.size.y * 0.5
	)
	var extents: Vector2 = Vector2(
		maxf(640.0, bounds.size.x * 0.5),
		maxf(480.0, bounds.size.y * 0.5)
	)

	if is_instance_valid(_fireflies):
		_fireflies.global_position = center
		_fireflies.emission_rect_extents = extents

	if is_instance_valid(_abyss_particles):
		_abyss_particles.global_position = center
		_abyss_particles.emission_rect_extents = Vector2(extents.x, maxf(420.0, extents.y * 0.94))

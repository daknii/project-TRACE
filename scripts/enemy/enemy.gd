extends CharacterBody2D

@onready var olhar_esquerdo: RayCast2D = $olhar_esquerdo
@onready var olhar_direito: RayCast2D = $olhar_direito
@onready var tem_chao_esquerdo: RayCast2D = $tem_chao_esquerdo
@onready var tem_chao_direita: RayCast2D = $tem_chao_direita
@onready var desenho: Sprite2D = $desenho

@export_group("Death VFX")
@export var death_particles_scene: PackedScene = preload("res://components/enemy_death_particles.tscn")
@export var death_particle_color: Color = Color(1.0, 0.45, 0.25, 1.0)
@export_range(0.3, 4.0, 0.1) var death_particle_scale: float = 1.0

const SPEED = 3000.0
const STEPS = 150
var acc_steps = STEPS
var maximo_passos: int
var last_step 
var direction_change_chance = 0.95
var _morreu: bool = false

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	inteligencia(delta)
	
	move_and_slide()

func inteligencia(delta: float):
	var direcao_aleatoria = 0
	if acc_steps == maximo_passos:
		direcao_aleatoria = randi_range(-1, 1)
		if direcao_aleatoria == 0:
			direcao_aleatoria = 1
			
		maximo_passos = randi_range(0, STEPS)
		
		last_step = direcao_aleatoria
		acc_steps = 0
	else:
		direcao_aleatoria=last_step
		acc_steps+=1
	
	# -1 SE TEM CHÃO A ESQUERDA
	if direcao_aleatoria == -1 and tem_chao_esquerdo.is_colliding():
		velocity.x = (SPEED*direcao_aleatoria) * delta
		desenho.flip_h = true
	elif direcao_aleatoria == 1 and tem_chao_direita.is_colliding():
		velocity.x = (SPEED*direcao_aleatoria) * delta
		desenho.flip_h = false
	else:
		velocity.x = 0
		acc_steps = maximo_passos



func bateu_na_hitbox(body: Area2D) -> void:
	if _morreu:
		return
	if body.is_in_group("player_damage"):
		_morreu = true
		_spawn_death_particles()
		queue_free()


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

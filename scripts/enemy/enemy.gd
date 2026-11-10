extends CharacterBody2D

@onready var olhar_esquerdo: RayCast2D = $olhar_esquerdo
@onready var olhar_direito: RayCast2D = $olhar_direito
@onready var tem_chao_esquerdo: RayCast2D = $tem_chao_esquerdo
@onready var tem_chao_direita: RayCast2D = $tem_chao_direita

const SPEED = 3000.0
const STEPS = 50
var acc_steps = STEPS
var last_step 
var direction_change_chance = 0.95

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	inteligencia(delta)
	
	move_and_slide()

func inteligencia(delta: float):
	var direcao_aleatoria = 0
	if acc_steps == STEPS:
		direcao_aleatoria = randi_range(-1, 1)
		last_step = direcao_aleatoria
		acc_steps = 0
	else:
		direcao_aleatoria=last_step
		acc_steps+=1
	
	# -1 SE TEM CHÃO A ESQUERDA
	if direcao_aleatoria == -1 and tem_chao_esquerdo.is_colliding():
		velocity.x = (SPEED*direcao_aleatoria) * delta
	elif direcao_aleatoria == 1 and tem_chao_direita.is_colliding():
		velocity.x = (SPEED*direcao_aleatoria) * delta

	

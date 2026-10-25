extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $Sprite

const SPEED = 300.0
const JUMP_VELOCITY = -600.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		sprite.play("fall")
		velocity += get_gravity() * delta
		
		
	if Input.is_action_just_pressed("pulo") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	var direction := Input.get_axis("esquerda", "direita")

	if direction:
		if is_on_floor():
			
			sprite.play("walk")
		if(direction < 0):
			
			sprite.flip_h = true
		else:
			sprite.flip_h = false
		print(direction)
		velocity.x = direction * SPEED
	else:
		if is_on_floor():
			sprite.play("idle")
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

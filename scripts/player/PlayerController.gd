extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $Sprite

const SPEED = 200.0
const GRAPPLE_DURATION: float = 4.0
const JUMP_VELOCITY = -600.0
const JUMPING_TIME = 0.3

var ON_WALL = false
var WALL_DIR: Global.Direcao = Global.Direcao.DIR
var GRAPPLE = false
var GRAPPLE_DIR: Global.Direcao = Global.Direcao.DIR
var grapple_duracao_atual: float = 0
var jumping_duration:float = 0.0

func _ready() -> void:
	grapple_duracao_atual = GRAPPLE_DURATION

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		if not GRAPPLE:
			if ON_WALL and grapple_duracao_atual > 0:
				velocity.y = (get_gravity().y*10) * delta
				grapple_duracao_atual -= delta
			else:
				velocity.y += get_gravity().y * delta
	else:
		grapple_duracao_atual = GRAPPLE_DURATION
		
	if grapple_duracao_atual > 0:
		if GRAPPLE:
			grapple_duracao_atual -= delta
	elif grapple_duracao_atual <= 0:
		GRAPPLE = false
		
		
	var direction := Input.get_axis("esquerda", "direita")

	if Input.is_action_just_pressed("pulo"):
		
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		if GRAPPLE:
			GRAPPLE = false
			ON_WALL = false
			jumping_duration = JUMPING_TIME
			velocity.y = JUMP_VELOCITY
			direction = 0
			if WALL_DIR == Global.Direcao.ESQ:
				velocity.x = (JUMP_VELOCITY*0.8)*-1
			if WALL_DIR == Global.Direcao.DIR:
				velocity.x = (JUMP_VELOCITY*0.8)
		
	if jumping_duration > 0.0:
		jumping_duration -= delta
		
	if direction:
		if(direction < 0):
			sprite.flip_h = true
			# agora vou ver se ele corre contra a parede
			if ON_WALL and WALL_DIR == Global.Direcao.ESQ and grapple_duracao_atual > 0: #tá indo pra direita e tem uma parede
				if not GRAPPLE:
					GRAPPLE = true
					velocity.y = 0
				else:
					velocity.y = (SPEED*-20) * delta
		else:
			sprite.flip_h = false
			# agora vou ver se ele corre contra a parede
			if ON_WALL and WALL_DIR == Global.Direcao.DIR and grapple_duracao_atual > 0: #tá indo pra direita e tem uma parede
				if not GRAPPLE:
					GRAPPLE = true
					velocity.y = 0
				else:
					velocity.y = (SPEED*-20) * delta
		if jumping_duration < 0.1:
			velocity.x = (direction * SPEED)
	else:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	animation(direction, not is_on_floor())
	
func animation(movimento, no_ar):
	if not is_on_floor():
		if no_ar:
			if Input.is_action_just_pressed("pulo"):
				sprite.play("jump")
				
			elif velocity.y > 0:
				sprite.play("fall")
	else:
		if movimento:
			sprite.play("walk")
		else:
			sprite.play("idle")

var objs_batendo = 0
func pata_direita(body: Node2D):
	ON_WALL = true
	WALL_DIR = Global.Direcao.DIR
	objs_batendo += 1
	
var objs_esquerda_batendo = 0
func pata_esquerda(body: Node2D):
	ON_WALL = true
	WALL_DIR = Global.Direcao.ESQ
	objs_batendo += 1

func sem_agarre(body: Node2D):
	objs_batendo -= 1
	if(objs_batendo == 0):
		ON_WALL = false
		GRAPPLE = false
		

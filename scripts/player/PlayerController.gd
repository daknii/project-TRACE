extends CharacterBody2D

signal vida_alterada(vida_atual: int, vida_maxima: int)
signal morreu

@onready var pataEsquerda = $PatasEsquerda
@onready var pataDireita = $PatasDireita
@onready var sprite: AnimatedSprite2D = $Sprite

const SPEED = 200.0
const GRAPPLE_DURATION: float = 4.0
const JUMP_VELOCITY = -600.0
const JUMPING_TIME = 0.3

@export var vida_maxima: int = 3
@export var tempo_invencibilidade: float = 1.0
@export var attack_obj: PackedScene
@export var auto_reload_on_death: bool = true

var vida: int = 3
var invencivel: bool = false
var esta_morto: bool = false
var ON_WALL = false
var WALL_DIR: Global.Direcao = Global.Direcao.DIR
var GRAPPLE = false
var GRAPPLE_DIR: Global.Direcao = Global.Direcao.DIR
var grapple_duracao_atual: float = 0
var jumping_duration:float = 0.0

var attack_speed = 1
var ultimo_ataque = 2

func _ready() -> void:
	vida = vida_maxima
	vida_alterada.emit(vida, vida_maxima)
	grapple_duracao_atual = GRAPPLE_DURATION

func _empurrando_parede(direction: float) -> bool:
	if is_on_floor() or jumping_duration > 0.0 or not ON_WALL or grapple_duracao_atual <= 0.0:
		return false
	if direction < 0.0 and WALL_DIR == Global.Direcao.ESQ:
		return true
	if direction > 0.0 and WALL_DIR == Global.Direcao.DIR:
		return true
	return false

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("esquerda", "direita")
	var empurrando := _empurrando_parede(direction)
	if not empurrando:
		if GRAPPLE and velocity.y < 0.0:
			velocity.y = 0.0
		GRAPPLE = false
	if not is_on_floor():
		if not GRAPPLE:
			if empurrando and grapple_duracao_atual > 0 and velocity.y >= 0.0:
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

	if Input.is_action_just_pressed("pulo"):
		if is_on_floor() and (GRAPPLE or ON_WALL):
			GRAPPLE = false
			ON_WALL = false
			jumping_duration = JUMPING_TIME
			velocity.y = JUMP_VELOCITY
			direction = 0
			if WALL_DIR == Global.Direcao.DIR:
				velocity.x = SPEED * 0.45
			else:
				velocity.x = SPEED * -0.45
		elif GRAPPLE or ON_WALL:
			GRAPPLE = false
			ON_WALL = false
			jumping_duration = JUMPING_TIME
			velocity.y = JUMP_VELOCITY
			direction = 0
			if WALL_DIR == Global.Direcao.ESQ:
				velocity.x = (JUMP_VELOCITY*0.8)*-1
			if WALL_DIR == Global.Direcao.DIR:
				velocity.x = (JUMP_VELOCITY*0.8)
		elif is_on_floor():
			velocity.y = JUMP_VELOCITY

	
	if Input.is_action_just_pressed("ataque") && ultimo_ataque >= attack_speed:
		ultimo_ataque = 0
		var pocicao_escolhida = false
		if sprite.flip_h == false:
			pocicao_escolhida = pataDireita.position
		else:
			pocicao_escolhida = pataEsquerda.position
			
		var attack = attack_obj.instantiate()
		attack.position = pocicao_escolhida
		add_child(attack)
	else:
		ultimo_ataque += delta
	
	if jumping_duration > 0.0:
		jumping_duration -= delta
		
	if direction:
		if(direction < 0):
			sprite.flip_h = true
			# agora vou ver se ele corre contra a parede
			if ON_WALL and WALL_DIR == Global.Direcao.ESQ and grapple_duracao_atual > 0 and jumping_duration <= 0.0 and not is_on_floor():
				if not GRAPPLE:
					GRAPPLE = true
					velocity.y = 0
				else:
					velocity.y = (SPEED*-20) * delta
		else:
			sprite.flip_h = false
			# agora vou ver se ele corre contra a parede
			if ON_WALL and WALL_DIR == Global.Direcao.DIR and grapple_duracao_atual > 0 and jumping_duration <= 0.0 and not is_on_floor():
				if not GRAPPLE:
					GRAPPLE = true
					velocity.y = 0
				else:
					velocity.y = (SPEED*-20) * delta
		if jumping_duration < 0.1:
			velocity.x = (direction * SPEED)
	else:
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
		



func tomar_dano(quantidade: int = 1) -> void:
	if esta_morto or invencivel:
		return

	vida = clampi(vida - quantidade, 0, vida_maxima)
	vida_alterada.emit(vida, vida_maxima)
	print("tomou dano! Vida: ", vida)

	if vida <= 0:
		morrer()
	else:
		_iniciar_invencibilidade()


func _iniciar_invencibilidade() -> void:
	invencivel = true

	var tween := create_tween()
	var piscadas := maxi(1, int(tempo_invencibilidade / 0.2))
	for i in piscadas:
		tween.tween_property(sprite, "modulate:a", 0.3, 0.1)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.1)

	await get_tree().create_timer(tempo_invencibilidade).timeout
	if not is_instance_valid(self) or esta_morto:
		return

	invencivel = false
	sprite.modulate.a = 1.0

	var hitbox: Area2D = get_node_or_null("hitbox")
	if hitbox:
		for area in hitbox.get_overlapping_areas():
			if area.is_in_group("enemy"):
				tomar_dano(1)
				break


func morrer() -> void:
	if esta_morto:
		return

	esta_morto = true
	set_physics_process(false)
	morreu.emit()
	print("Player morreu!")
	if auto_reload_on_death:
		get_tree().call_deferred("reload_current_scene")


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		tomar_dano(1)

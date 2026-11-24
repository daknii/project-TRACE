extends CharacterBody2D

signal vida_alterada(vida_atual: int, vida_maxima: int)
signal morreu

@onready var pataEsquerda = $PatasEsquerda
@onready var pataDireita = $PatasDireita
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var visual_gato: Node2D = get_node_or_null("GatoAmeba") as Node2D

const SPEED = 200.0
const GRAPPLE_DURATION: float = 4.0
const JUMP_VELOCITY = -600.0
const JUMPING_TIME = 0.3

@export var vida_maxima: int = 3
@export var tempo_invencibilidade: float = 1.0
@export var attack_obj: PackedScene
@export var auto_reload_on_death: bool = true

@export_group("Pulo")
@export_range(0.0, 0.4, 0.01) var coyote_time: float = 0.12

@export_group("Dash")
@export_range(220.0, 900.0, 10.0) var dash_speed: float = 500.0
@export_range(0.05, 0.4, 0.01) var dash_duration: float = 0.14
@export_range(0.1, 2.5, 0.05) var dash_cooldown: float = 0.55

@export_group("Queda Rápida")
@export_range(1.2, 5.0, 0.1) var multiplicador_queda_rapida: float = 2.6
@export_range(0.0, 600.0, 10.0) var velocidade_minima_queda_rapida: float = 260.0
@export_range(500.0, 2000.0, 20.0) var velocidade_maxima_queda_rapida: float = 1100.0

var vida: int = 3
var invencivel: bool = false
var esta_morto: bool = false
var ON_WALL = false
var WALL_DIR: Global.Direcao = Global.Direcao.DIR
var GRAPPLE = false
var GRAPPLE_DIR: Global.Direcao = Global.Direcao.DIR
var grapple_duracao_atual: float = 0
var jumping_duration:float = 0.0

var esta_dando_dash: bool = false
var segurando_baixo: bool = false
var _dash_dir: float = 1.0
var _pode_dash_no_ar: bool = true
var _dash_timer: Timer = null
var _dash_cooldown_timer: Timer = null
var _coyote_timer: Timer = null

var attack_speed = 1
var ultimo_ataque = 2

func _ready() -> void:
	vida = vida_maxima
	vida_alterada.emit(vida, vida_maxima)
	grapple_duracao_atual = GRAPPLE_DURATION
	_dash_timer = _obter_ou_criar_timer("DashTimer", dash_duration)
	_dash_cooldown_timer = _obter_ou_criar_timer("DashCooldownTimer", dash_cooldown)
	_coyote_timer = _obter_ou_criar_timer("CoyoteTimer", maxf(coyote_time, 0.001))
	if not _dash_timer.timeout.is_connected(_on_dash_timer_timeout):
		_dash_timer.timeout.connect(_on_dash_timer_timeout)


func _obter_ou_criar_timer(nome: String, duracao: float) -> Timer:
	var existente := get_node_or_null(nome) as Timer
	if existente != null:
		existente.process_callback = Timer.TIMER_PROCESS_PHYSICS
		existente.one_shot = true
		existente.wait_time = duracao
		return existente
	var novo := Timer.new()
	novo.name = nome
	novo.process_callback = Timer.TIMER_PROCESS_PHYSICS
	novo.one_shot = true
	novo.wait_time = duracao
	add_child(novo)
	return novo


func _empurrando_parede(direction: float) -> bool:
	if segurando_baixo or esta_dando_dash or is_on_floor() or jumping_duration > 0.0 or not ON_WALL or grapple_duracao_atual <= 0.0:
		return false
	if direction < 0.0 and WALL_DIR == Global.Direcao.ESQ:
		return true
	if direction > 0.0 and WALL_DIR == Global.Direcao.DIR:
		return true
	return false


func _iniciar_dash(direcao_dash: float) -> void:
	esta_dando_dash = true
	_dash_dir = -1.0 if direcao_dash < 0.0 else 1.0
	GRAPPLE = false
	jumping_duration = 0.0
	if not is_on_floor():
		_pode_dash_no_ar = false
	sprite.flip_h = _dash_dir < 0.0
	velocity = Vector2(_dash_dir * dash_speed, 0.0)
	_dash_timer.start(dash_duration)
	_dash_cooldown_timer.start(dash_cooldown)
	if visual_gato != null and visual_gato.has_method("reproduzir_dash"):
		visual_gato.call("reproduzir_dash", _dash_dir)


func _encerrar_dash(suavizar_velocidade: bool) -> void:
	if not esta_dando_dash:
		return
	esta_dando_dash = false
	if _dash_timer != null and not _dash_timer.is_stopped():
		_dash_timer.stop()
	if suavizar_velocidade:
		velocity.x = _dash_dir * SPEED * 0.85


func _on_dash_timer_timeout() -> void:
	_encerrar_dash(true)


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("esquerda", "direita")
	segurando_baixo = Input.is_action_pressed("baixo")
	var estava_no_chao := is_on_floor()
	var pulou_neste_frame := false

	if is_on_floor() or GRAPPLE:
		_pode_dash_no_ar = true

	if Input.is_action_just_pressed("dash") and not esta_dando_dash and _dash_cooldown_timer.is_stopped():
		if is_on_floor() or _pode_dash_no_ar:
			var dash_dir: float
			if not is_zero_approx(direction):
				dash_dir = -1.0 if direction < 0.0 else 1.0
			elif (ON_WALL or GRAPPLE) and not is_on_floor():
				dash_dir = 1.0 if WALL_DIR == Global.Direcao.ESQ else -1.0
			else:
				dash_dir = -1.0 if sprite.flip_h else 1.0
			_iniciar_dash(dash_dir)

	var empurrando := _empurrando_parede(direction)
	if not empurrando:
		if GRAPPLE and velocity.y < 0.0:
			velocity.y = 0.0
		GRAPPLE = false

	if not is_on_floor():
		if not esta_dando_dash and not GRAPPLE:
			if empurrando and grapple_duracao_atual > 0 and velocity.y >= 0.0:
				velocity.y = (get_gravity().y * 10) * delta
				grapple_duracao_atual -= delta
			elif segurando_baixo:
				velocity.y += get_gravity().y * multiplicador_queda_rapida * delta
				if velocity.y >= 0.0:
					velocity.y = maxf(velocity.y, velocidade_minima_queda_rapida)
				velocity.y = minf(velocity.y, velocidade_maxima_queda_rapida)
			else:
				velocity.y += get_gravity().y * delta
	else:
		grapple_duracao_atual = GRAPPLE_DURATION

	if grapple_duracao_atual > 0:
		if GRAPPLE:
			grapple_duracao_atual -= delta
	elif grapple_duracao_atual <= 0:
		GRAPPLE = false

	var pode_pular_chao := is_on_floor() or (_coyote_timer != null and not _coyote_timer.is_stopped())
	if Input.is_action_just_pressed("pulo"):
		if is_on_floor() and (GRAPPLE or ON_WALL):
			_encerrar_dash(false)
			if _coyote_timer != null:
				_coyote_timer.stop()
			pulou_neste_frame = true
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
			_encerrar_dash(false)
			if _coyote_timer != null:
				_coyote_timer.stop()
			pulou_neste_frame = true
			GRAPPLE = false
			ON_WALL = false
			jumping_duration = JUMPING_TIME
			velocity.y = JUMP_VELOCITY
			direction = 0
			if WALL_DIR == Global.Direcao.ESQ:
				velocity.x = (JUMP_VELOCITY*0.8)*-1
			if WALL_DIR == Global.Direcao.DIR:
				velocity.x = (JUMP_VELOCITY*0.8)
		elif pode_pular_chao:
			_encerrar_dash(false)
			if _coyote_timer != null:
				_coyote_timer.stop()
			pulou_neste_frame = true
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
		if attack is Sprite2D:
			(attack as Sprite2D).flip_h = sprite.flip_h
		add_child(attack)
		if visual_gato != null and visual_gato.has_method("reproduzir_ataque"):
			var dir_ataque: float = -1.0 if sprite.flip_h else 1.0
			visual_gato.call("reproduzir_ataque", dir_ataque, pocicao_escolhida)
	else:
		ultimo_ataque += delta
	
	if jumping_duration > 0.0:
		jumping_duration -= delta

	if esta_dando_dash:
		velocity.x = _dash_dir * dash_speed
		velocity.y = 0.0
	elif direction:
		if(direction < 0):
			sprite.flip_h = true
			# agora vou ver se ele corre contra a parede
			if ON_WALL and WALL_DIR == Global.Direcao.ESQ and grapple_duracao_atual > 0 and jumping_duration <= 0.0 and not is_on_floor() and not segurando_baixo:
				if not GRAPPLE:
					GRAPPLE = true
					velocity.y = 0
				else:
					velocity.y = (SPEED*-20) * delta
		else:
			sprite.flip_h = false
			# agora vou ver se ele corre contra a parede
			if ON_WALL and WALL_DIR == Global.Direcao.DIR and grapple_duracao_atual > 0 and jumping_duration <= 0.0 and not is_on_floor() and not segurando_baixo:
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
	if is_on_floor():
		if _coyote_timer != null and not _coyote_timer.is_stopped():
			_coyote_timer.stop()
	elif estava_no_chao and not pulou_neste_frame and coyote_time > 0.0:
		if _coyote_timer != null:
			_coyote_timer.start(coyote_time)
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

	var alvo_visual: CanvasItem = visual_gato if visual_gato != null else sprite
	if visual_gato != null and visual_gato.has_method("reproduzir_dano"):
		visual_gato.call("reproduzir_dano", tempo_invencibilidade)

	var tween := create_tween()
	var piscadas := maxi(1, int(tempo_invencibilidade / 0.2))
	for i in piscadas:
		tween.tween_property(alvo_visual, "modulate:a", 0.3, 0.1)
		tween.tween_property(alvo_visual, "modulate:a", 1.0, 0.1)

	await get_tree().create_timer(tempo_invencibilidade).timeout
	if not is_instance_valid(self) or esta_morto:
		return

	invencivel = false
	alvo_visual.modulate.a = 1.0

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
	_encerrar_dash(false)
	if _coyote_timer != null:
		_coyote_timer.stop()
	segurando_baixo = false
	set_physics_process(false)
	morreu.emit()
	print("Player morreu!")
	if auto_reload_on_death:
		get_tree().call_deferred("reload_current_scene")


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		tomar_dano(1)

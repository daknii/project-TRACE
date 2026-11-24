class_name GatoAmeba
extends Node2D

## Visual procedural do gato-ameba controlado por Shader 2D SDF + RayCast2D nativos.
## Lê apenas o estado do CharacterBody2D pai sem alterar sua física ou mecânicas.

@export_group("Aparência (Almas & Cores)")
@export var cor_base: Color = Color(0.97, 0.99, 1.0, 1.0):
	set(value):
		cor_base = value
		_aplicar_paleta_shader()
@export var cor_sombra: Color = Color(0.70, 0.80, 0.89, 1.0):
	set(value):
		cor_sombra = value
		_aplicar_paleta_shader()
@export var cor_brilho: Color = Color(0.84, 0.98, 1.0, 1.0):
	set(value):
		cor_brilho = value
		_aplicar_paleta_shader()
@export var cor_contorno: Color = Color(0.56, 0.68, 0.78, 0.72):
	set(value):
		cor_contorno = value
		_aplicar_paleta_shader()
@export_range(0.0, 1.5, 0.01) var intensidade_aura: float = 0.28:
	set(value):
		intensidade_aura = value
		_aplicar_paleta_shader()

@export_group("Dinâmica da Ameba")
@export_range(0.5, 6.0, 0.1) var tempo_para_derreter: float = 2.2
@export_range(1.5, 12.0, 0.5) var aceleracao_derreter_baixo: float = 6.0
@export_range(0.5, 2.0, 0.05) var elasticidade: float = 1.0
@export var velocidade_referencia: float = 200.0

# Propriedades animadas diretamente pelo AnimationPlayer na animação "ataque"
var ataque_peso: float = 0.0
var ataque_alcance: float = 0.0
var ataque_arco: float = 0.0

@onready var corpo_shader: ColorRect = $CorpoShader
@onready var rosto: Node2D = $Rosto
@onready var olho_esq: Node2D = $Rosto/OlhoEsq
@onready var olho_dir: Node2D = $Rosto/OlhoDir
@onready var focinho: Node2D = $Rosto/Focinho
@onready var bochecha_esq: Sprite2D = $Rosto/BochechaEsq
@onready var bochecha_dir: Sprite2D = $Rosto/BochechaDir
@onready var bigode_esq: Node2D = $Rosto/BigodeEsq
@onready var bigode_dir: Node2D = $Rosto/BigodeDir
@onready var aura_suave: Sprite2D = $AuraSuave
@onready var rastro_pata: Line2D = $RastroPata
@onready var anim_rosto: AnimationPlayer = $AnimacaoRosto

@onready var sonda_chao_esq: RayCast2D = $SondasAmbiente/ChaoEsq
@onready var sonda_chao_centro: RayCast2D = $SondasAmbiente/ChaoCentro
@onready var sonda_chao_dir: RayCast2D = $SondasAmbiente/ChaoDir
@onready var sonda_parede_esq: RayCast2D = $SondasAmbiente/ParedeEsq
@onready var sonda_parede_dir: RayCast2D = $SondasAmbiente/ParedeDir
@onready var sonda_teto: RayCast2D = $SondasAmbiente/Teto

const RAIO_BASE_OLHO_X := 5.6
const POS_BASE_BOCHECHA_X := 9.2
const POS_BASE_BIGODE_X := 15.2
const LIMIAR_TELEPORTE := 90.0

var _pai: CharacterBody2D = null
var _material: ShaderMaterial = null

# Dimensões lidas da cápsula do pai (padrão radius=14, height=98 -> metade=49)
var _metade_capsula: float = 49.0
var _raio_capsula: float = 14.0

# Estado de movimento e direção
var _tempo: float = 0.0
var _olhando: float = 1.0
var _olhar_rosto_x: float = 0.0 # -1 (esq), 0 (frente), +1 (dir)
var _vel_local: Vector2 = Vector2.ZERO
var _vel_y_anterior: float = 0.0
var _estava_no_chao: bool = true
var _pos_global_anterior: Vector2 = Vector2.ZERO
var _tem_pos_anterior: bool = false

# Molas e estados orgânicos
var _atividade: float = 0.0
var _tempo_parado: float = 0.0
var _derretimento: float = 0.0
var _squash: float = 0.0
var _vel_squash: float = 0.0
var _impulso_ataque: float = 0.0
var _impulso_dash: float = 0.0
var _dash_dir: float = 1.0
var _flash_dano: float = 0.0
var _tempo_piscada: float = 2.4

# Posições suavizadas das bolhas da ameba (espaço local)
var _head_pos: Vector2 = Vector2(0.0, 6.0)
var _head_vel: Vector2 = Vector2.ZERO
var _head_rot: float = 0.0
var _torso_pos: Vector2 = Vector2(0.0, 20.0)
var _hip_pos: Vector2 = Vector2(0.0, 32.5)
var _base_l_pos: Vector2 = Vector2(-10.0, 38.0)
var _base_r_pos: Vector2 = Vector2(10.0, 38.0)

# Cauda dinâmica (3 pontos)
var _tail_p0: Vector2 = Vector2(-14.0, 34.0)
var _tail_p1: Vector2 = Vector2(-24.0, 26.0)
var _tail_p2: Vector2 = Vector2(-29.0, 12.0)
var _tail_weight: float = 0.85

# Pata de ataque (brota da ameba em direção ao ponto do golpe)
var _ataque_dir: float = 1.0
var _ataque_alvo: Vector2 = Vector2(37.0, -5.0)
var _paw_base: Vector2 = Vector2(8.0, 14.0)
var _paw_tip: Vector2 = Vector2(37.0, -5.0)
var _rastro_pontos: PackedVector2Array = PackedVector2Array()
var _rastro_alpha: float = 0.0
const MAX_PONTOS_RASTRO := 32

# Leituras suavizadas do ambiente
var _ground_y_l: float = 49.0
var _ground_y_c: float = 49.0
var _ground_y_r: float = 49.0
var _ground_blend: float = 1.0
var _wall_x: float = 14.0
var _wall_dir: float = 1.0
var _wall_blend: float = 0.0
var _ceil_y: float = -60.0
var _ceil_blend: float = 0.0


func _ready() -> void:
	_pai = get_parent() as CharacterBody2D
	_material = corpo_shader.material as ShaderMaterial
	if _material != null:
		# Garante material único por instância para não vazar cor/uniforms entre cenas
		_material = _material.duplicate() as ShaderMaterial
		corpo_shader.material = _material

	_descobrir_capsula_pai()
	_configurar_sondas()
	_propagar_light_mask(self, light_mask)
	_aplicar_paleta_shader()
	_reiniciar_pose()


func _physics_process(delta: float) -> void:
	_tempo += delta
	if _pai == null:
		_atualizar_idle_isolado(delta)
		return

	_verificar_teleporte_zona()

	var escala := global_scale
	var sx := escala.x if absf(escala.x) > 0.001 else 1.0
	var sy := escala.y if absf(escala.y) > 0.001 else 1.0
	_vel_local = Vector2(_pai.velocity.x / sx, _pai.velocity.y / sy)

	var no_chao: bool = _pai.is_on_floor()
	var pai_na_parede: bool = bool(_pai.get("ON_WALL"))
	var pai_agarrado: bool = bool(_pai.get("GRAPPLE"))
	var pai_dash: bool = bool(_pai.get("esta_dando_dash"))
	var segurando_baixo: bool = bool(_pai.get("segurando_baixo"))
	var na_parede: bool = (not no_chao) and (pai_na_parede or pai_agarrado)
	var dir_parede_raw = _pai.get("WALL_DIR")
	var lado_parede: float = -1.0 if dir_parede_raw == Global.Direcao.ESQ else 1.0

	var input_dir: float = Input.get_axis("esquerda", "direita")
	if ataque_peso > 0.05:
		_olhando = _ataque_dir
	elif pai_dash:
		_olhando = _dash_dir
	elif na_parede:
		_olhando = lado_parede
	elif absf(_vel_local.x) > 12.0:
		_olhando = -1.0 if _vel_local.x < 0.0 else 1.0
	elif absf(input_dir) > 0.1:
		_olhando = -1.0 if input_dir < 0.0 else 1.0

	_atualizar_sondas(delta, no_chao, na_parede, lado_parede)
	_atualizar_estados_organicos(delta, no_chao, na_parede, input_dir, pai_dash, segurando_baixo)
	_atualizar_forma_e_cauda(delta, no_chao, na_parede, lado_parede, pai_agarrado, pai_dash)
	_atualizar_rosto(delta, no_chao, na_parede, pai_dash)
	_enviar_uniforms()

	_estava_no_chao = no_chao
	_vel_y_anterior = _vel_local.y
	_pos_global_anterior = _pai.global_position
	_tem_pos_anterior = true


func reproduzir_dano(duracao: float = 1.0) -> void:
	_vel_squash += 4.2 * elasticidade
	_flash_dano = 1.0
	ataque_peso = 0.0
	ataque_alcance = 0.0
	ataque_arco = 0.0
	_limpar_rastro_pata()
	if anim_rosto != null and anim_rosto.has_animation(&"dano"):
		anim_rosto.play(&"dano")
	var tween := create_tween()
	tween.tween_property(self, "_flash_dano", 0.0, maxf(0.18, duracao * 0.45))


func reproduzir_ataque(direcao: float = 0.0, alvo_local: Vector2 = Vector2.ZERO) -> void:
	if absf(direcao) > 0.1:
		_ataque_dir = -1.0 if direcao < 0.0 else 1.0
	else:
		_ataque_dir = _olhando
	_olhando = _ataque_dir
	if alvo_local != Vector2.ZERO:
		_ataque_alvo = alvo_local
	else:
		_ataque_alvo = Vector2(_ataque_dir * 37.0, -5.0)

	_tempo_parado = 0.0
	_impulso_ataque = 1.0
	_vel_squash -= 2.4 * elasticidade
	_limpar_rastro_pata()
	if anim_rosto != null and anim_rosto.has_animation(&"ataque"):
		anim_rosto.stop()
		anim_rosto.play(&"ataque")


func reproduzir_dash(direcao: float = 0.0) -> void:
	if absf(direcao) > 0.1:
		_dash_dir = -1.0 if direcao < 0.0 else 1.0
	else:
		_dash_dir = _olhando
	_olhando = _dash_dir
	_tempo_parado = 0.0
	_derretimento = 0.0
	_impulso_dash = 1.0
	_squash = 0.34 * elasticidade
	_vel_squash = 2.4 * elasticidade


func _descobrir_capsula_pai() -> void:
	if _pai == null:
		return
	for filho: Node in _pai.get_children():
		if filho is CollisionShape2D:
			var col := filho as CollisionShape2D
			if col.shape is CapsuleShape2D:
				var cap := col.shape as CapsuleShape2D
				_metade_capsula = cap.height * 0.5
				_raio_capsula = cap.radius
				return


func _configurar_sondas() -> void:
	var sondas: Array[RayCast2D] = [
		sonda_chao_esq,
		sonda_chao_centro,
		sonda_chao_dir,
		sonda_parede_esq,
		sonda_parede_dir,
		sonda_teto,
	]
	for sonda: RayCast2D in sondas:
		if sonda == null:
			continue
		if _pai != null:
			sonda.add_exception(_pai)
			sonda.collision_mask = _pai.collision_mask
		sonda.enabled = true


func _propagar_light_mask(no: Node, mask_alvo: int) -> void:
	for filho: Node in no.get_children():
		if filho is CanvasItem:
			(filho as CanvasItem).light_mask = mask_alvo
		_propagar_light_mask(filho, mask_alvo)


func _aplicar_paleta_shader() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"cor_base", cor_base)
	_material.set_shader_parameter(&"cor_sombra", cor_sombra)
	_material.set_shader_parameter(&"cor_brilho", cor_brilho)
	_material.set_shader_parameter(&"cor_contorno", cor_contorno)
	_material.set_shader_parameter(&"intensidade_aura", intensidade_aura)
	if aura_suave != null:
		aura_suave.modulate = Color(cor_brilho.r, cor_brilho.g, cor_brilho.b, clampf(intensidade_aura * 0.72, 0.0, 0.5))


func _reiniciar_pose() -> void:
	var chao := _metade_capsula
	_ground_y_l = chao
	_ground_y_c = chao
	_ground_y_r = chao
	_ground_blend = 1.0
	_wall_blend = 0.0
	_ceil_blend = 0.0
	_head_pos = Vector2(0.0, chao - 42.5)
	_head_vel = Vector2.ZERO
	_torso_pos = Vector2(0.0, chao - 27.5)
	_hip_pos = Vector2(0.0, chao - 16.0)
	_base_l_pos = Vector2(-10.0, chao - 10.5)
	_base_r_pos = Vector2(10.0, chao - 10.5)
	_resetar_cauda()
	_enviar_uniforms()


func _resetar_cauda() -> void:
	_tail_p0 = _hip_pos + Vector2(-_olhando * 13.0, 2.0)
	_tail_p1 = _tail_p0 + Vector2(-_olhando * 11.0, -4.0)
	_tail_p2 = _tail_p1 + Vector2(-_olhando * 5.0, -13.0)


func _verificar_teleporte_zona() -> void:
	if _pai == null or not _tem_pos_anterior:
		return
	var salto := _pai.global_position.distance_to(_pos_global_anterior)
	if salto > LIMIAR_TELEPORTE:
		_head_vel = Vector2.ZERO
		_squash = 0.0
		_vel_squash = 0.0
		_derretimento = 0.0
		_tempo_parado = 0.0
		_impulso_dash = 0.0
		ataque_peso = 0.0
		ataque_alcance = 0.0
		ataque_arco = 0.0
		_limpar_rastro_pata()
		_resetar_cauda()


func _atualizar_sondas(delta: float, no_chao: bool, na_parede: bool, lado_parede: float) -> void:
	var taxa_chao := 22.0 if no_chao else 12.0
	var yc := _ler_chao_sonda(sonda_chao_centro, _metade_capsula)
	var yl := _ler_chao_sonda(sonda_chao_esq, yc)
	var yr := _ler_chao_sonda(sonda_chao_dir, yc)
	# Limita degrau extremo para evitar distorção exagerada sobre abismos
	yl = clampf(yl, yc - 18.0, yc + 18.0)
	yr = clampf(yr, yc - 18.0, yc + 18.0)

	_ground_y_c = _amortecer(_ground_y_c, yc, taxa_chao, delta)
	_ground_y_l = _amortecer(_ground_y_l, yl, taxa_chao, delta)
	_ground_y_r = _amortecer(_ground_y_r, yr, taxa_chao, delta)

	var alvo_ground_blend := 1.0 if no_chao else 0.0
	_ground_blend = _amortecer(_ground_blend, alvo_ground_blend, 18.0 if no_chao else 14.0, delta)

	var sonda_p := sonda_parede_esq if lado_parede < 0.0 else sonda_parede_dir
	var alvo_wall_blend := 0.0
	if na_parede:
		_wall_dir = lado_parede
		alvo_wall_blend = 1.0
		var wx := lado_parede * (_raio_capsula + 2.0)
		if sonda_p != null and sonda_p.is_colliding():
			wx = to_local(sonda_p.get_collision_point()).x
		_wall_x = _amortecer(_wall_x, wx, 24.0, delta)
	_wall_blend = _amortecer(_wall_blend, alvo_wall_blend, 15.0, delta)

	var alvo_ceil_blend := 0.0
	if sonda_teto != null and sonda_teto.is_colliding():
		var cy := to_local(sonda_teto.get_collision_point()).y
		var folga := (_head_pos.y - 16.0) - cy
		if folga < 8.0:
			alvo_ceil_blend = clampf((8.0 - folga) / 14.0, 0.0, 1.0)
			_ceil_y = _amortecer(_ceil_y, cy, 24.0, delta)
	_ceil_blend = _amortecer(_ceil_blend, alvo_ceil_blend, 16.0, delta)


func _ler_chao_sonda(sonda: RayCast2D, padrao: float) -> float:
	if sonda != null and sonda.is_colliding():
		return to_local(sonda.get_collision_point()).y
	return padrao


func _atualizar_estados_organicos(
	delta: float,
	no_chao: bool,
	na_parede: bool,
	input_dir: float,
	pai_dash: bool = false,
	segurando_baixo: bool = false
) -> void:
	# Detecção de decolagem e pouso para squash & stretch elástico
	var comecou_pulo := _estava_no_chao and (not no_chao) and _vel_local.y < -80.0
	var pousou := (not _estava_no_chao) and no_chao

	if comecou_pulo:
		_squash = -0.36 * elasticidade
		_vel_squash = -1.6 * elasticidade
		_tempo_parado = 0.0
	elif pousou:
		var impacto := clampf(maxf(_vel_y_anterior, 0.0) / 720.0, 0.22, 0.95)
		_squash = clampf(impacto * 0.78 * elasticidade, 0.18, 0.85)
		_vel_squash = impacto * 2.2 * elasticidade
		_tempo_parado = 0.0

	# Mola amortecida para squash (+ achata / - estica)
	var alvo_squash := 0.0
	if pai_dash:
		alvo_squash = 0.28
	elif not no_chao and not na_parede:
		# Estica verticalmente ao subir ou cair rápido
		alvo_squash = -clampf(absf(_vel_local.y) / 950.0, 0.0, 0.42)
	elif na_parede:
		alvo_squash = -0.14
	var rigidez := 135.0
	var amortecimento := 12.5
	_vel_squash += ((alvo_squash - _squash) * rigidez - _vel_squash * amortecimento) * delta
	_squash = clampf(_squash + _vel_squash * delta, -0.55, 0.92)

	# Decaimento dos pulsos de ataque e dash
	_impulso_ataque = _amortecer(_impulso_ataque, 0.0, 14.0, delta)
	_impulso_dash = 1.0 if pai_dash else _amortecer(_impulso_dash, 0.0, 12.0, delta)

	# Atividade horizontal (0 = parado, 1 = correndo)
	var alvo_ativ := clampf(absf(_vel_local.x) / maxf(velocidade_referencia, 1.0), 0.0, 1.0)
	_atividade = _amortecer(_atividade, alvo_ativ, 8.5, delta)

	# Derretimento gradual quando fica tranquilo e parado no chão (ou mais rápido segurando baixo)
	var parado := no_chao and (not na_parede) and (not pai_dash) and absf(_vel_local.x) < 8.0 and absf(input_dir) < 0.05 and _impulso_ataque < 0.1
	var forcar_ameba := no_chao and (not na_parede) and (not pai_dash) and segurando_baixo and absf(input_dir) < 0.05 and _impulso_ataque < 0.1
	if forcar_ameba:
		_tempo_parado = maxf(_tempo_parado, tempo_para_derreter) + delta * aceleracao_derreter_baixo
	elif parado:
		_tempo_parado += delta
	else:
		_tempo_parado = 0.0

	var alvo_derreter := 0.0
	if (parado or forcar_ameba) and _tempo_parado > tempo_para_derreter:
		alvo_derreter = smoothstep(tempo_para_derreter, tempo_para_derreter + 1.35, _tempo_parado)
	var taxa_derreter: float = 10.0 if (forcar_ameba and alvo_derreter > _derretimento) else (3.2 if alvo_derreter > _derretimento else 11.0)
	_derretimento = _amortecer(_derretimento, alvo_derreter, taxa_derreter, delta)


func _atualizar_forma_e_cauda(
	delta: float,
	no_chao: bool,
	na_parede: bool,
	lado_parede: float,
	pai_agarrado: bool,
	pai_dash: bool = false
) -> void:
	var chao := _ground_y_c
	var resp := sin(_tempo * 2.15) * 1.15 * (1.0 - _atividade * 0.5)
	var onda_passo := sin(_tempo * 11.5) * _atividade

	# Metas de posição para cada estado
	var alvo_head := Vector2.ZERO
	var alvo_torso := Vector2.ZERO
	var alvo_hip := Vector2.ZERO
	var alvo_base_l := Vector2.ZERO
	var alvo_base_r := Vector2.ZERO
	var alvo_head_rot := 0.0
	var alvo_tail_weight := 0.85

	if na_parede:
		# Ameba aderida verticalmente à parede (escalando ou deslizando)
		var pulso_parede := sin(_tempo * 12.0) * (1.8 if (pai_agarrado or absf(_vel_local.y) > 20.0) else 0.35)
		var encosto_x := _wall_x - lado_parede * 11.0
		var centro_y := 6.0
		alvo_head = Vector2(encosto_x - lado_parede * 2.5, centro_y - 20.0 + pulso_parede)
		alvo_torso = Vector2(encosto_x, centro_y - 2.0)
		alvo_hip = Vector2(encosto_x + lado_parede * 0.5, centro_y + 18.0 - pulso_parede * 0.8)
		alvo_base_l = Vector2(encosto_x + lado_parede * 1.5, centro_y + 24.0)
		alvo_base_r = Vector2(encosto_x + lado_parede * 1.5, centro_y - 12.0)
		alvo_head_rot = -lado_parede * 0.14
		alvo_tail_weight = 0.25
	elif not no_chao:
		# No ar: interpola entre pílula vertical (pulo parado) e corpo alongado de lado (pulo andando, 3º desenho)
		var subindo := clampf(-_vel_local.y / 520.0, 0.0, 1.0)
		var caindo := clampf(_vel_local.y / 520.0, 0.0, 1.0)
		var mov_ar := smoothstep(0.08, 0.62, _atividade)
		var centro_y := 8.0

		# 1. Pulo parado: forma vertical em gota/pílula
		var head_vert := Vector2(_olhando * 2.0, centro_y - 20.0 - subindo * 8.0 + caindo * 4.0)
		var torso_vert := Vector2(0.0, centro_y - 2.0 + caindo * 2.0)
		var hip_vert := Vector2(-_olhando * (2.0 + caindo * 4.0), centro_y + 18.0 + subindo * 8.5 - caindo * 4.0)
		var bl_vert := hip_vert + Vector2(-3.5, 3.0)
		var br_vert := hip_vert + Vector2(3.5, 3.0)
		var rot_vert := _olhando * (caindo * 0.08 - subindo * 0.04)

		# 2. Pulo andando: corpo alongado horizontal/arqueado estendido para trás (3º gato)
		var inclinacao_ar := (subindo * 7.5) - (caindo * 8.5)
		var head_lado := Vector2(_olhando * 16.0, centro_y - 14.0 - subindo * 3.0 + caindo * 2.0)
		var torso_lado := Vector2(_olhando * 11.5, centro_y + 3.0)
		var hip_lado := Vector2(-_olhando * 22.0, centro_y + 7.5 + inclinacao_ar)
		# Lóbulos alinhados ao longo da curva do corpo para formar uma cápsula longa e contínua
		var bl_lado := Vector2(-_olhando * 5.0, centro_y + 3.5 + inclinacao_ar * 0.45)
		var br_lado := Vector2(-_olhando * 31.0, centro_y + 10.5 + inclinacao_ar * 1.15)
		var rot_lado := _olhando * (caindo * 0.10 - subindo * 0.06)

		alvo_head = head_vert.lerp(head_lado, mov_ar)
		alvo_torso = torso_vert.lerp(torso_lado, mov_ar)
		alvo_hip = hip_vert.lerp(hip_lado, mov_ar)
		alvo_base_l = bl_vert.lerp(bl_lado, mov_ar)
		alvo_base_r = br_vert.lerp(br_lado, mov_ar)
		alvo_head_rot = lerpf(rot_vert, rot_lado, mov_ar)
		# Cauda fundida ao corpo esticado no pulo andando; discreta só em queda parada
		alvo_tail_weight = lerpf(0.0, 0.28, caindo * (1.0 - subindo)) * (1.0 - mov_ar)
	else:
		# No chão: interpola entre idle sentado, corrida alongada horizontal e poça derretida
		var inclinacao_chao := clampf((_ground_y_r - _ground_y_l) / 44.0, -0.45, 0.45)

		# 1. Pose Idle (sentado redondinho)
		var head_idle := Vector2(_olhando * 1.5, chao - 42.5 + resp)
		var torso_idle := Vector2(0.0, chao - 27.5 + resp * 0.5)
		var hip_idle := Vector2(-_olhando * 1.0, chao - 16.0)
		var bl_idle := Vector2(-10.5, _ground_y_l - 10.0)
		var br_idle := Vector2(10.5, _ground_y_r - 10.0)

		# 2. Pose Andando/Correndo (alongado horizontalmente como no caderno)
		var head_run := Vector2(_olhando * 15.5, chao - 29.5 + absf(onda_passo) * 2.2)
		var torso_run := Vector2(_olhando * 2.0, chao - 17.0 - onda_passo * 1.6)
		var hip_run := Vector2(-_olhando * 15.0, chao - 13.5 + onda_passo * 1.2)
		var bl_run := Vector2(-16.0 - _olhando * 4.0, _ground_y_l - 9.0)
		var br_run := Vector2(16.0 - _olhando * 4.0, _ground_y_r - 9.0)

		alvo_head = head_idle.lerp(head_run, _atividade)
		alvo_torso = torso_idle.lerp(torso_run, _atividade)
		alvo_hip = hip_idle.lerp(hip_run, _atividade)
		alvo_base_l = bl_idle.lerp(bl_run, _atividade)
		alvo_base_r = br_idle.lerp(br_run, _atividade)
		alvo_head_rot = inclinacao_chao * 0.45 + _olhando * _atividade * 0.08

		# 3. Pose Derretida (poça espalhada sobre o contorno do terreno)
		if _derretimento > 0.005:
			var m := _derretimento
			var head_melt := Vector2(-_olhando * 4.0, chao - 20.0 + resp * 0.45)
			var torso_melt := Vector2(_olhando * 4.0, chao - 11.5)
			var hip_melt := Vector2(_olhando * 16.0, chao - 9.5)
			var bl_melt := Vector2(-24.0, _ground_y_l - 8.5)
			var br_melt := Vector2(28.0 * _olhando if _olhando > 0.0 else 24.0, _ground_y_r - 8.5)
			if _olhando < 0.0:
				bl_melt.x = -28.0
			alvo_head = alvo_head.lerp(head_melt, m)
			alvo_torso = alvo_torso.lerp(torso_melt, m)
			alvo_hip = alvo_hip.lerp(hip_melt, m)
			alvo_base_l = alvo_base_l.lerp(bl_melt, m)
			alvo_base_r = alvo_base_r.lerp(br_melt, m)
			alvo_head_rot = lerpf(alvo_head_rot, inclinacao_chao * 0.65, m)

		# Cauda visível sentado/andando, fundida à poça ao derreter
		alvo_tail_weight = lerpf(0.92, 0.72, _atividade) * (1.0 - _derretimento)

	# Alongamento aerodinâmico durante o dash
	var forca_dash := 1.0 if pai_dash else _impulso_dash
	if forca_dash > 0.01 and not na_parede:
		var centro_dash_y: float = (chao - 21.0) if no_chao else 6.0
		var head_dash := Vector2(_dash_dir * 20.0, centro_dash_y - 4.0)
		var torso_dash := Vector2(_dash_dir * 3.0, centro_dash_y)
		var hip_dash := Vector2(-_dash_dir * 16.0, centro_dash_y + 2.0)
		alvo_head = alvo_head.lerp(head_dash, forca_dash * 0.85)
		alvo_torso = alvo_torso.lerp(torso_dash, forca_dash * 0.85)
		alvo_hip = alvo_hip.lerp(hip_dash, forca_dash * 0.85)
		if not no_chao:
			alvo_base_l = alvo_base_l.lerp(hip_dash + Vector2(-_dash_dir * 4.0, 2.0), forca_dash * 0.85)
			alvo_base_r = alvo_base_r.lerp(torso_dash + Vector2(-_dash_dir * 6.0, 2.5), forca_dash * 0.85)
		alvo_head_rot = lerpf(alvo_head_rot, _dash_dir * 0.14, forca_dash)
		alvo_tail_weight = lerpf(alvo_tail_weight, 0.82, forca_dash)

	# Aplica squash/stretch e impulso de ataque sobre as metas
	var sq := _squash
	if no_chao and not na_parede:
		alvo_head.y += sq * 14.0
		alvo_torso.y += sq * 7.5
		alvo_base_l.x -= maxf(sq, 0.0) * 14.0
		alvo_base_r.x += maxf(sq, 0.0) * 14.0
	var forca_ataque := maxf(_impulso_ataque, ataque_alcance * 0.75)
	if forca_ataque > 0.01:
		var recuo_prep := -4.0 * maxf(-ataque_arco, 0.0) * ataque_peso
		alvo_head.x += _ataque_dir * (forca_ataque * 10.0 + recuo_prep)
		alvo_torso.x += _ataque_dir * (forca_ataque * 6.5)
		alvo_head_rot += _ataque_dir * ataque_arco * 0.14 * ataque_peso

	# Mola elástica da cabeça (follow-through gelatinoso)
	var k_head := 170.0
	var d_head := 15.5
	_head_vel += ((alvo_head - _head_pos) * k_head - _head_vel * d_head) * delta
	_head_pos += _head_vel * delta

	# Suavização dos demais lóbulos
	var taxa := 16.0
	_torso_pos = _amortecer_vec2(_torso_pos, alvo_torso, taxa, delta)
	_hip_pos = _amortecer_vec2(_hip_pos, alvo_hip, taxa, delta)
	_base_l_pos = _amortecer_vec2(_base_l_pos, alvo_base_l, taxa, delta)
	_base_r_pos = _amortecer_vec2(_base_r_pos, alvo_base_r, taxa, delta)
	_head_rot = _amortecer(_head_rot, alvo_head_rot, 12.0, delta)
	_tail_weight = _amortecer(_tail_weight, alvo_tail_weight, 6.5, delta)

	# Cauda dinâmica com atraso suave e abanar tranquilo
	var raiz_cauda := _hip_pos + Vector2(-_olhando * (12.5 + _atividade * 3.5), 2.5)
	_tail_p0 = raiz_cauda
	var balanco := sin(_tempo * (2.2 + _atividade * 3.5)) * (2.6 + _atividade * 2.2)
	var alvo_t1: Vector2
	var alvo_t2: Vector2
	if forca_dash > 0.15 and not na_parede:
		alvo_t1 = _tail_p0 + Vector2(-_dash_dir * 13.0, -1.0)
		alvo_t2 = alvo_t1 + Vector2(-_dash_dir * 13.0, -2.0)
	elif na_parede:
		alvo_t1 = _tail_p0 + Vector2(-lado_parede * 7.0, 9.0)
		alvo_t2 = alvo_t1 + Vector2(-lado_parede * 5.0 + balanco * 0.5, 10.0)
	elif not no_chao:
		alvo_t1 = _tail_p0 + Vector2(-_olhando * 9.0, -3.0 - clampf(_vel_local.y * 0.015, -6.0, 8.0))
		alvo_t2 = alvo_t1 + Vector2(-_olhando * 8.0, -6.0 - clampf(_vel_local.y * 0.015, -6.0, 8.0))
	else:
		# Sentado: cauda sobe em arco fofo ao lado (como no caderno e slide_03)
		var t1_idle := _tail_p0 + Vector2(-_olhando * 11.5, -2.5)
		var t2_idle := t1_idle + Vector2(-_olhando * 4.5 + balanco, -16.5)
		# Andando: cauda flui estendida atrás acompanhando o movimento
		var t1_run := _tail_p0 + Vector2(-_olhando * 12.0, -3.5 + balanco * 0.4)
		var t2_run := t1_run + Vector2(-_olhando * 10.5, -5.5 + balanco * 0.9)
		alvo_t1 = t1_idle.lerp(t1_run, _atividade)
		alvo_t2 = t2_idle.lerp(t2_run, _atividade)

	_tail_p1 = _amortecer_vec2(_tail_p1, alvo_t1, 10.5, delta)
	_tail_p2 = _amortecer_vec2(_tail_p2, alvo_t2, 7.5, delta)

	# Evita que a ponta da cauda atravesse o chão
	if no_chao:
		_tail_p1.y = minf(_tail_p1.y, _ground_y_c - 4.0)
		_tail_p2.y = minf(_tail_p2.y, _ground_y_c - 3.0)

	# Atualiza posição da pata de ataque saindo do ombro em arco até a área do golpe
	_paw_base = _torso_pos.lerp(_head_pos, 0.42) + Vector2(_ataque_dir * 7.5, 2.5)
	if ataque_peso > 0.005:
		var ang := ataque_arco * 0.92
		var centro_y := lerpf(_paw_base.y - 6.0, _ataque_alvo.y, 0.55)
		var alcance_x := lerpf(6.0, maxf(absf(_ataque_alvo.x - _paw_base.x) + 12.0, 40.0), ataque_alcance)
		var alcance_y := lerpf(4.0, 26.0, ataque_alcance)
		_paw_tip = Vector2(
			_paw_base.x + _ataque_dir * (cos(ang) * alcance_x + 4.0 * ataque_alcance),
			centro_y + sin(ang) * alcance_y
		)
	else:
		_paw_tip = _paw_base
	_atualizar_rastro_pata(delta)

	# Atualiza posição suave da aura atrás do gato
	if aura_suave != null:
		aura_suave.position = _torso_pos.lerp(_hip_pos, 0.5)
		var aura_scale_x := 1.0 + maxf(_squash, 0.0) * 0.35 + _derretimento * 0.45 + _atividade * 0.15
		var aura_scale_y := 1.0 - maxf(_squash, 0.0) * 0.25 - _derretimento * 0.35
		aura_suave.scale = Vector2(aura_scale_x, aura_scale_y)


func _atualizar_rosto(delta: float, no_chao: bool, na_parede: bool, pai_dash: bool = false) -> void:
	# Olhar 2.5D: frente (0.0) quando parado/derretido, 3/4-perfil (±0.85) quando movendo/escalando
	var alvo_olhar_x := 0.0
	if pai_dash or _impulso_dash > 0.1:
		alvo_olhar_x = _olhando * 0.9
	elif na_parede:
		alvo_olhar_x = _olhando * 0.85
	elif not no_chao:
		alvo_olhar_x = _olhando * 0.65
	elif _atividade > 0.08 or _impulso_ataque > 0.1 or ataque_peso > 0.05:
		alvo_olhar_x = _olhando * clampf(0.45 + _atividade * 0.45 + ataque_peso * 0.35, 0.0, 0.92)
	else:
		# Parado olha suavemente para a frente (igual ao caderno!)
		alvo_olhar_x = _olhando * (0.14 * (1.0 - _derretimento))

	_olhar_rosto_x = _amortecer(_olhar_rosto_x, alvo_olhar_x, 11.0, delta)

	# Posição e squash do bloco do rosto acompanhando a cabeça
	var sq_x := 1.0 + _squash * 0.16 + _derretimento * 0.06
	var sq_y := 1.0 - _squash * 0.18 - _derretimento * 0.06
	rosto.position = _head_pos + Vector2(_olhar_rosto_x * 6.8, 1.8)
	rosto.rotation = _head_rot
	rosto.scale = Vector2(sq_x, sq_y)

	# Perspectiva 2.5D nos olhos, focinho, bochechas e bigodinhos flutuantes
	var abs_o := absf(_olhar_rosto_x)
	var esq_distante := clampf(_olhar_rosto_x, 0.0, 1.0)
	var dir_distante := clampf(-_olhar_rosto_x, 0.0, 1.0)

	olho_esq.position = Vector2(-RAIO_BASE_OLHO_X * (1.0 - esq_distante * 0.34), -1.2)
	olho_dir.position = Vector2(RAIO_BASE_OLHO_X * (1.0 - dir_distante * 0.34), -1.2)
	olho_esq.scale.x = 1.0 - esq_distante * 0.28
	olho_dir.scale.x = 1.0 - dir_distante * 0.28

	focinho.position = Vector2(_olhar_rosto_x * 1.8, 3.0)
	focinho.scale.x = 1.0 - abs_o * 0.14

	bochecha_esq.position = Vector2(-POS_BASE_BOCHECHA_X * (1.0 - esq_distante * 0.32), 2.4)
	bochecha_dir.position = Vector2(POS_BASE_BOCHECHA_X * (1.0 - dir_distante * 0.32), 2.4)
	bochecha_esq.modulate.a = 0.48 * (1.0 - esq_distante * 0.55)
	bochecha_dir.modulate.a = 0.48 * (1.0 - dir_distante * 0.55)

	# Bigodinhos flutuantes nas laterais da bochecha (como no caderno e cutscenes)
	bigode_esq.position = Vector2(-POS_BASE_BIGODE_X + _olhar_rosto_x * 4.5, 1.6)
	bigode_dir.position = Vector2(POS_BASE_BIGODE_X + _olhar_rosto_x * 4.5, 1.6)
	bigode_esq.scale.x = 1.0 - esq_distante * 0.35
	bigode_dir.scale.x = 1.0 - dir_distante * 0.35

	# Piscada natural via AnimationPlayer nativo
	_tempo_piscada -= delta
	if _tempo_piscada <= 0.0:
		_tempo_piscada = 2.4 + randf() * 3.4
		if anim_rosto != null and not anim_rosto.is_playing() and anim_rosto.has_animation(&"piscar"):
			anim_rosto.play(&"piscar")


func _enviar_uniforms() -> void:
	if _material == null:
		return

	var sq := _squash
	var head_rx := (17.2 + maxf(sq, 0.0) * 2.8 + _derretimento * 1.4) * (1.0 - maxf(-sq, 0.0) * 0.14)
	var head_ry := (15.0 - sq * 2.4 - _derretimento * 1.4)

	# Orelhinhas acompanham a rotação da cabeça e inclinam suavemente com velocidade
	var inclina_orelha := clampf(-_vel_local.x * 0.0005, -0.22, 0.22)
	var rot_o := _head_rot + inclina_orelha
	var ear_l_b := _head_pos + Vector2(-9.2, -7.0).rotated(_head_rot)
	var ear_l_t := _head_pos + Vector2(-11.8, -19.2 + _derretimento * 2.2).rotated(rot_o)
	var ear_r_b := _head_pos + Vector2(9.2, -7.0).rotated(_head_rot)
	var ear_r_t := _head_pos + Vector2(11.8, -19.2 + _derretimento * 2.2).rotated(rot_o)

	var torso_r := 15.8 - _atividade * 1.4 + maxf(sq, 0.0) * 2.6 - maxf(-sq, 0.0) * 2.6
	var hip_r := 19.2 - _atividade * 2.2 + maxf(sq, 0.0) * 3.8 - maxf(-sq, 0.0) * 4.5 - _derretimento * 3.0
	var base_r := 11.2 + maxf(sq, 0.0) * 3.5 + _derretimento * 2.6 - maxf(-sq, 0.0) * 3.5

	_material.set_shader_parameter(&"facing", _olhando)
	_material.set_shader_parameter(&"head_pos", _head_pos)
	_material.set_shader_parameter(&"head_radii", Vector2(head_rx, head_ry))
	_material.set_shader_parameter(&"head_rot", _head_rot)
	_material.set_shader_parameter(&"ear_l_base", ear_l_b)
	_material.set_shader_parameter(&"ear_l_tip", ear_l_t)
	_material.set_shader_parameter(&"ear_r_base", ear_r_b)
	_material.set_shader_parameter(&"ear_r_tip", ear_r_t)

	_material.set_shader_parameter(&"torso_pos", _torso_pos)
	_material.set_shader_parameter(&"torso_r", torso_r)
	_material.set_shader_parameter(&"hip_pos", _hip_pos)
	_material.set_shader_parameter(&"hip_r", hip_r)
	_material.set_shader_parameter(&"base_l_pos", _base_l_pos)
	_material.set_shader_parameter(&"base_l_r", base_r)
	_material.set_shader_parameter(&"base_r_pos", _base_r_pos)
	_material.set_shader_parameter(&"base_r_r", base_r)

	_material.set_shader_parameter(&"tail_p0", _tail_p0)
	_material.set_shader_parameter(&"tail_p1", _tail_p1)
	_material.set_shader_parameter(&"tail_p2", _tail_p2)
	_material.set_shader_parameter(&"tail_weight", _tail_weight)

	_material.set_shader_parameter(&"paw_base", _paw_base)
	_material.set_shader_parameter(&"paw_tip", _paw_tip)
	_material.set_shader_parameter(&"paw_weight", ataque_peso)

	_material.set_shader_parameter(&"ground_y_l", _ground_y_l)
	_material.set_shader_parameter(&"ground_y_c", _ground_y_c)
	_material.set_shader_parameter(&"ground_y_r", _ground_y_r)
	_material.set_shader_parameter(&"ground_blend", _ground_blend)

	_material.set_shader_parameter(&"wall_x", _wall_x)
	_material.set_shader_parameter(&"wall_dir", _wall_dir)
	_material.set_shader_parameter(&"wall_blend", _wall_blend)

	_material.set_shader_parameter(&"ceil_y", _ceil_y)
	_material.set_shader_parameter(&"ceil_blend", _ceil_blend)
	_material.set_shader_parameter(&"flash_dano", _flash_dano)


func _atualizar_idle_isolado(delta: float) -> void:
	# Permite pré-visualizar a cena gato_ameba.tscn rodando sozinha (F6)
	_atualizar_forma_e_cauda(delta, true, false, 1.0, false)
	_atualizar_rosto(delta, true, false)
	_enviar_uniforms()


func _limpar_rastro_pata() -> void:
	_rastro_pontos.clear()
	_rastro_alpha = 0.0
	if rastro_pata != null:
		rastro_pata.clear_points()
		rastro_pata.modulate.a = 0.0


func _atualizar_rastro_pata(delta: float) -> void:
	if rastro_pata == null:
		return

	var golpeando := ataque_peso > 0.12 and ataque_alcance > 0.12
	if golpeando:
		_rastro_alpha = _amortecer(_rastro_alpha, 1.0, 30.0, delta)
		if _rastro_pontos.is_empty():
			_rastro_pontos.append(_paw_tip)
		else:
			var ultimo := _rastro_pontos[_rastro_pontos.size() - 1]
			var dist := ultimo.distance_to(_paw_tip)
			if dist > 1.5:
				# Subamostra o arco para manter a curva longa e suave
				if dist > 6.0:
					var meio := ultimo.lerp(_paw_tip, 0.5)
					_rastro_pontos.append(meio)
				_rastro_pontos.append(_paw_tip)
		while _rastro_pontos.size() > MAX_PONTOS_RASTRO:
			_rastro_pontos.remove_at(0)
	else:
		_rastro_alpha = _amortecer(_rastro_alpha, 0.0, 8.5, delta)
		if _rastro_alpha < 0.02:
			_rastro_pontos.clear()

	rastro_pata.points = _rastro_pontos
	rastro_pata.modulate.a = _rastro_alpha


func _amortecer(atual: float, alvo: float, taxa: float, delta: float) -> float:
	return lerpf(atual, alvo, 1.0 - exp(-taxa * delta))


func _amortecer_vec2(atual: Vector2, alvo: Vector2, taxa: float, delta: float) -> Vector2:
	return atual.lerp(alvo, 1.0 - exp(-taxa * delta))

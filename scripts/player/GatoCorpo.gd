extends Node2D

const COMPRIMENTO_CORPO := 34.0
const RAIO_PEITO := 12.5
const RAIO_QUADRIL := 16.0
const ALTURA_MONTARIA := 22.0
const CAMINHADA := 350.0
const CORRIDA := 650.0
const VELOCIDADE_ANDAR := 200.0
const GRAVIDADE := 1600.0
const PULO := 440.0
const PULO_CORRIDA := 500.0
const COMPRIMENTO_ELO := 6.3
const ELOS := 9
const ESCALA_CABECA := 0.07
const DURACAO_GIRO := 0.32
const LIMIAR_GIRO := 48.0
const MARGEM_PATA := 0.9

const COR_CORPO := Color(0.9490196, 0.9490196, 0.9490196, 1.0)
const COR_QUENTE := Color(0.8470588, 0.8470588, 0.8470588, 1.0)
const COR_LONGE := Color(0.627451, 0.627451, 0.627451, 1.0)
const COR_SOMBRA := Color(0.0, 0.0, 0.0, 0.14)
const COR_ENCAIXE := Color(0.0, 0.0, 0.0, 0.32)

const TEXTURA_FRENTE := preload("res://assets/front.png")
const TEXTURA_LADO := preload("res://assets/de_lado.png")

class Passo:
	var de := Vector2.ZERO
	var para := Vector2.ZERO
	var decorrido := 0.0
	var duracao := 0.1
	var altura := 4.0
	var vertical := false

class Elo:
	var ponto := Vector2.ZERO
	var anterior := Vector2.ZERO

class Perna:
	var frente := false
	var longe := false
	var grupo := 0
	var l1 := 16.0
	var l2 := 14.0
	var w1 := 3.0
	var w2 := 2.5
	var pe := Vector2.ZERO
	var pe_ik := Vector2.ZERO
	var joelho := Vector2.ZERO
	var quadril := Vector2.ZERO
	var passo: Passo = null
	var espera := 0.0
	var casa := Vector2.ZERO
	var erro := 0.0
	var limiar := 0.0
	var tem_casa := false

@onready var cabeca: Sprite2D = $Cabeca

var pai: CharacterBody2D
var pernas: Array[Perna] = []
var cauda: Array[Elo] = []
var raios_cauda := PackedFloat32Array()

var origem_x := 0.0
var origem_y := 0.0
var chao_y := 49.0
var metade_capsula := 49.0
var raio_capsula := 14.0
var vel_x := 0.0
var vel_y := 0.0
var vel_y_anterior := 0.0
var olhando := 1.0
var no_chao := true
var estava_no_chao := true
var folga_chao := 0.1
var reserva_pulo := 0.0
var pulo_segurado := false
var em_pe := 1.0
var tempo_parado := 1.0
var coluna := 1.22
var vel_coluna := 0.0
var balanco := 0.0
var vel_balanco := 0.0
var esmagamento := 0.0
var vel_esmagamento := 0.0
var respiracao := 0.0
var atividade := 0.0
var tempo_ar := 0.0
var espernear := 0.0
var tempo := 0.0
var acabou_de_pousar := false
var ultimo_grupo := -1
var espera_grupo := 0.0
var inclinacao_cabeca := 0.0
var espera_piscada := 1.6
var tempo_piscada := 0.0
var piscada := 0.0
var inclinacao_orelha := 0.0
var vel_orelha := 0.0
var quadril := Vector2.ZERO
var peito := Vector2.ZERO
var cabeca_x := 0.0
var cabeca_y := 0.0
var posicao_anterior := Vector2.ZERO
var tem_posicao_anterior := false
var na_parede := false
var lado_parede := 1.0
var parede_x := 0.0
var giro_ativo := false
var giro_t := 0.0
var giro_angulo := 0.0
var giro_sentido := 1.0
var distancia_passo := 0.0
var distancia_parede := 0.0


func _ready() -> void:
	pai = get_parent() as CharacterBody2D
	var hitbox := pai.get_node_or_null("Hitbox") as CollisionShape2D
	if hitbox != null and hitbox.shape is CapsuleShape2D:
		var forma := hitbox.shape as CapsuleShape2D
		metade_capsula = forma.height * 0.5
		raio_capsula = forma.radius
	chao_y = metade_capsula
	montar_pernas()
	montar_cauda()
	chao_y = sondar_chao()
	reiniciar()


func _physics_process(delta: float) -> void:
	atualizar(delta)
	queue_redraw()


func montar_pernas() -> void:
	pernas.clear()
	pernas.append(nova_perna(true, false, 0, 22.0, 20.0, 3.3, 2.7))
	pernas.append(nova_perna(true, true, 1, 22.0, 20.0, 3.0, 2.4))
	pernas.append(nova_perna(false, true, 0, 15.0, 13.0, 5.0, 4.2))
	pernas.append(nova_perna(false, false, 1, 16.0, 14.0, 5.4, 4.5))


func nova_perna(frente: bool, longe: bool, grupo: int, l1: float, l2: float, w1: float, w2: float) -> Perna:
	var perna := Perna.new()
	perna.frente = frente
	perna.longe = longe
	perna.grupo = grupo
	perna.l1 = l1
	perna.l2 = l2
	perna.w1 = w1
	perna.w2 = w2
	return perna


func montar_cauda() -> void:
	cauda.clear()
	raios_cauda = PackedFloat32Array()
	raios_cauda.resize(ELOS)
	for i in ELOS:
		var elo := Elo.new()
		cauda.append(elo)
		var u := float(i) / float(ELOS - 1)
		raios_cauda[i] = lerpf(6.0, 0.9, pow(u, 0.8))


func reiniciar() -> void:
	origem_x = 0.0
	origem_y = chao_y - ALTURA_MONTARIA
	vel_x = 0.0
	vel_y = 0.0
	vel_y_anterior = 0.0
	olhando = 1.0
	no_chao = true
	estava_no_chao = true
	folga_chao = 0.1
	reserva_pulo = 0.0
	pulo_segurado = false
	em_pe = 1.0
	tempo_parado = 1.0
	coluna = 1.08
	vel_coluna = 0.0
	giro_ativo = false
	giro_t = 0.0
	giro_angulo = 0.0
	giro_sentido = 1.0
	distancia_passo = 0.0
	distancia_parede = 0.0
	balanco = 0.0
	vel_balanco = 0.0
	esmagamento = 0.0
	vel_esmagamento = 0.0
	respiracao = 0.0
	atividade = 0.0
	tempo_ar = 0.0
	espernear = 0.0
	tempo = randf() * 10.0
	acabou_de_pousar = false
	ultimo_grupo = -1
	espera_grupo = 0.0
	inclinacao_cabeca = 0.0
	espera_piscada = 1.6 + randf() * 3.0
	tempo_piscada = 0.0
	piscada = 0.0
	inclinacao_orelha = 0.0
	vel_orelha = 0.0
	calcular_nucleo()
	cabeca_x = peito.x + olhando * 15.0
	cabeca_y = peito.y - 10.0
	posicionar_pes()
	reiniciar_cauda()
	atualizar_cabeca()


func superficie_em(x: float) -> float:
	if pai == null:
		return chao_y
	var mundo := pai.get_world_2d()
	if mundo == null:
		return chao_y
	var estado := mundo.direct_space_state
	if estado == null:
		return chao_y
	var cima := to_global(Vector2(x, quadril.y - RAIO_QUADRIL))
	var baixo := to_global(Vector2(x, quadril.y + 140.0))
	var consulta := PhysicsRayQueryParameters2D.create(cima, baixo)
	consulta.collision_mask = pai.collision_mask
	consulta.exclude = [pai.get_rid()]
	consulta.collide_with_bodies = true
	consulta.collide_with_areas = false
	consulta.hit_from_inside = true
	var achado := estado.intersect_ray(consulta)
	if achado.is_empty():
		return chao_y
	return to_local(achado["position"]).y


func sondar_chao() -> float:
	if pai == null:
		return metade_capsula
	var mundo := pai.get_world_2d()
	if mundo == null:
		return chao_y
	var estado := mundo.direct_space_state
	if estado == null:
		return chao_y
	var origem := pai.global_position
	var destino := origem + Vector2(0.0, 480.0)
	var consulta := PhysicsRayQueryParameters2D.create(origem, destino)
	consulta.collision_mask = pai.collision_mask
	consulta.exclude = [pai.get_rid()]
	consulta.collide_with_bodies = true
	consulta.collide_with_areas = false
	var achado := estado.intersect_ray(consulta)
	if achado.is_empty():
		return chao_y
	return to_local(achado["position"]).y


func superficie_parede(lado: float) -> float:
	if pai == null:
		return lado * raio_capsula
	var mundo := pai.get_world_2d()
	if mundo == null:
		return lado * raio_capsula
	var estado := mundo.direct_space_state
	if estado == null:
		return lado * raio_capsula
	var origem := pai.global_position
	var destino := origem + Vector2(lado * 80.0, 0.0)
	var consulta := PhysicsRayQueryParameters2D.create(origem, destino)
	consulta.collision_mask = pai.collision_mask
	consulta.exclude = [pai.get_rid()]
	consulta.collide_with_bodies = true
	consulta.collide_with_areas = false
	var achado := estado.intersect_ray(consulta)
	if achado.is_empty():
		return lado * raio_capsula
	return to_local(achado["position"]).x


func calcular_nucleo() -> void:
	var peso_ar := 1.0 if no_chao else 0.25
	respiracao = sin(tempo * 2.05) * 0.45 * (1.0 - atividade * 0.55) * peso_ar
	var corpo_y := origem_y + balanco
	var base_x := origem_x
	if na_parede:
		base_x = origem_x + lado_parede * 4.5
		corpo_y = origem_y + balanco * 0.35
	quadril = Vector2(base_x, corpo_y)
	peito = Vector2(
		base_x + olhando * COMPRIMENTO_CORPO * cos(coluna),
		corpo_y - COMPRIMENTO_CORPO * sin(coluna) - respiracao
	)
	if na_parede:
		peito.x = lerpf(peito.x, parede_x - lado_parede * (RAIO_PEITO * 0.55), 0.65)
		quadril.x = lerpf(quadril.x, parede_x - lado_parede * (RAIO_QUADRIL * 0.35), 0.55)


func ancora_perna(perna: Perna) -> Vector2:
	if perna.frente:
		return Vector2(
			peito.x - olhando * (2.0 + (2.2 if perna.longe else 0.0)) + olhando * (-1.0 if perna.longe else 1.0),
			peito.y + RAIO_PEITO * 0.55 + (-2.0 if perna.longe else 2.0)
		)
	return Vector2(
		quadril.x - olhando * (2.0 + (2.2 if perna.longe else 0.0)) + olhando * (-1.0 if perna.longe else 1.0),
		quadril.y + RAIO_QUADRIL * 0.42 + (-2.0 if perna.longe else 2.0)
	)


func centro_tronco(t: float) -> Vector2:
	var dx := peito.x - quadril.x
	var dy := peito.y - quadril.y
	var comprimento := Vector2(dx, dy).length()
	if comprimento < 1.0:
		comprimento = 1.0
	var nx := dy / comprimento
	var ny := -dx / comprimento
	var arco := sin(PI * t) * 3.4 * (1.0 - em_pe * 0.35)
	return Vector2(
		lerpf(quadril.x, peito.x, t) + nx * arco,
		lerpf(quadril.y, peito.y, t) + ny * arco
	)


func raio_tronco(t: float) -> float:
	return lerpf(RAIO_QUADRIL, RAIO_PEITO, t) + sin(PI * t) * 2.0


func empurrar_fora_do_corpo(ponto: Vector2, _dianteira: bool = false) -> Vector2:
	var fora := ponto
	for i in 7:
		var t := float(i) / 6.0
		var centro := centro_tronco(t)
		var minimo := raio_tronco(t) * MARGEM_PATA
		var delta := fora - centro
		var dist := delta.length()
		if dist < minimo:
			var preferida := Vector2(olhando * 0.2, 1.0).normalized()
			if dist < 0.001:
				fora = centro + preferida * minimo
			else:
				var empurrada := delta / dist
				if empurrada.y < 0.2:
					empurrada = (empurrada + preferida).normalized()
				fora = centro + empurrada * minimo
	return fora


func altura_livre() -> float:
	return chao_y - origem_y


func longe_do_chao() -> bool:
	return (not no_chao) and altura_livre() > LIMIAR_GIRO


func iniciar_giro() -> void:
	if giro_ativo:
		return
	giro_ativo = true
	giro_t = 0.0
	giro_angulo = 0.0
	giro_sentido = olhando


func atualizar_giro(delta: float) -> void:
	if not giro_ativo:
		giro_angulo = 0.0
		return
	giro_t += delta
	var k := clampf(giro_t / DURACAO_GIRO, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 2.4)
	giro_angulo = TAU * e * giro_sentido
	if k >= 1.0:
		giro_ativo = false
		giro_t = 0.0
		giro_angulo = 0.0


func centro_giro() -> Vector2:
	return esmagar((quadril + peito) * 0.5)


func transformar(ponto: Vector2) -> Vector2:
	var p := esmagar(ponto)
	if absf(giro_angulo) < 0.0001:
		return p
	var c := centro_giro()
	return c + (p - c).rotated(giro_angulo)


func casa_chao(perna: Perna, _ancora: Vector2) -> Vector2:
	var lado := olhando * (-3.0 if perna.longe else 3.0)
	var casa_x := 0.0
	if perna.frente:
		casa_x = peito.x + olhando * 14.0 + lado
	else:
		casa_x = quadril.x - olhando * 8.0 + lado
	return Vector2(casa_x, superficie_em(casa_x) - 1.5)


func fase_da_perna(perna: Perna) -> float:
	return float(perna.grupo) * PI + (0.4 if perna.longe else 0.0)


func pe_ciclo_chao(perna: Perna) -> Vector2:
	var casa := casa_chao(perna, Vector2.ZERO)
	var stride := 10.0 + atividade * 7.0
	var fase := distancia_passo * 0.07 + fase_da_perna(perna)
	var swing := sin(fase)
	var pe_x := casa.x + olhando * stride * swing
	var pe_y := superficie_em(pe_x) - 1.5
	if swing > 0.0:
		pe_y -= sin(PI * swing) * (5.5 + atividade * 3.5)
	if perna.frente:
		var minimo := peito.x + olhando * 8.0
		if (minimo - pe_x) * olhando > 0.0:
			pe_x = minimo
	else:
		var maximo := quadril.x + olhando * 2.0
		if (pe_x - maximo) * olhando > 0.0:
			pe_x = maximo
	return Vector2(pe_x, pe_y)


func pe_ciclo_parede(perna: Perna, ancora: Vector2) -> Vector2:
	var afastamento := 4.0 if perna.longe else 2.5
	var base_y := ancora.y + (10.0 if perna.frente else -8.0)
	if perna.longe:
		base_y += 2.5 if perna.frente else -2.0
	else:
		base_y += -1.0 if perna.frente else 1.2
	var stride_y := 11.0 if perna.frente else 8.0
	var fase := distancia_parede * 0.09 + fase_da_perna(perna)
	var swing := sin(fase)
	var pe_y := base_y + swing * stride_y
	var pe_x := parede_x - lado_parede * afastamento
	if swing > 0.15:
		pe_x -= lado_parede * sin(PI * clampf(swing, 0.0, 1.0)) * 2.4
	return Vector2(pe_x, pe_y)


func pendurar_frente(perna: Perna, ancora: Vector2) -> Vector2:
	var balanco_pata := sin(tempo * 1.35 + (1.8 if perna.longe else 0.0)) * (0.6 + atividade * 1.4)
	return empurrar_fora_do_corpo(Vector2(
		ancora.x + olhando * ((10.0 if perna.longe else 15.0) + balanco_pata),
		ancora.y + 20.0 + (-1.0 if perna.longe else 1.0)
	), true)


func alvo_ar(perna: Perna, ancora: Vector2) -> Vector2:
	var oscila := sin(tempo * 8.5 + (0.0 if perna.frente else 2.4) + (1.7 if perna.longe else 0.0))
	if perna.frente:
		var tx := ancora.x + olhando * (5.0 + espernear * (4.0 + oscila * 5.0))
		var ty := ancora.y + 16.0 + espernear * (12.0 + cos(tempo * 7.0 + 1.0) * 5.0)
		if espernear > 0.04:
			var px := ancora.x + olhando * (14.0 + espernear * 22.0)
			var py := chao_y - 2.0
			var delta := Vector2(px - ancora.x, py - ancora.y)
			if delta.length() < (perna.l1 + perna.l2) * 0.93:
				tx = lerpf(tx, px, espernear * 0.8)
				ty = lerpf(ty, py, espernear * 0.75)
		return empurrar_fora_do_corpo(Vector2(tx, ty))
	return empurrar_fora_do_corpo(Vector2(
		ancora.x - olhando * (5.0 + espernear * (8.0 - oscila * 4.0)),
		ancora.y + 15.0 + espernear * (7.0 + oscila * 4.0)
	))


func posicionar_pes() -> void:
	calcular_nucleo()
	for perna: Perna in pernas:
		var ancora := ancora_perna(perna)
		perna.quadril = ancora
		perna.passo = null
		perna.espera = 0.0
		var destino := Vector2.ZERO
		if not no_chao:
			destino = alvo_ar(perna, ancora)
		elif perna.frente and em_pe > 0.42 and atividade < 0.18:
			destino = pendurar_frente(perna, ancora)
		else:
			destino = casa_chao(perna, ancora)
		perna.pe = destino
		resolver_perna(perna)


func reiniciar_cauda() -> void:
	var ax := quadril.x - olhando * (RAIO_QUADRIL * 0.72)
	var ay := quadril.y + RAIO_QUADRIL * 0.42
	for i in ELOS:
		var elo := cauda[i]
		elo.ponto = Vector2(ax - olhando * float(i) * COMPRIMENTO_ELO, ay + float(i) * 0.45)
		elo.anterior = elo.ponto


func atualizar(delta: float) -> void:
	tempo += delta
	acabou_de_pousar = false
	chao_y = superficie_em(origem_x)
	var movimento := Input.get_axis("esquerda", "direita")
	var pulo := Input.is_action_pressed("pulo")
	var pulo_apertado := Input.is_action_just_pressed("pulo")
	var ataque_apertado := Input.is_action_just_pressed("ataque")
	if pulo_apertado:
		reserva_pulo = 0.13
	else:
		reserva_pulo = maxf(0.0, reserva_pulo - delta)
	folga_chao = 0.1 if no_chao else maxf(0.0, folga_chao - delta)
	var escala := global_scale
	var sx := escala.x if absf(escala.x) > 0.001 else 1.0
	var sy := escala.y if absf(escala.y) > 0.001 else 1.0
	vel_x = clampf(pai.velocity.x / sx, -CORRIDA * 1.2, CORRIDA * 1.2)
	vel_y = minf(pai.velocity.y / sy, 1250.0)
	var no_chao_agora := pai.is_on_floor()
	var pai_na_parede := bool(pai.get("ON_WALL"))
	var pai_agarrado := bool(pai.get("GRAPPLE"))
	var dir_parede = pai.get("WALL_DIR")
	lado_parede = -1.0 if dir_parede == Global.Direcao.ESQ else 1.0
	na_parede = (not no_chao_agora) and (pai_na_parede or pai_agarrado)
	if na_parede:
		olhando = lado_parede
		parede_x = superficie_parede(lado_parede)
	elif movimento != 0.0:
		olhando = sinal(movimento)
	var comecou_pulo := estava_no_chao and not no_chao_agora and vel_y < -90.0
	var pousou := (not estava_no_chao) and no_chao_agora
	if not pulo:
		pulo_segurado = false
	elif pulo:
		pulo_segurado = true
	if comecou_pulo and (reserva_pulo > 0.0 or folga_chao > 0.0 or pulo):
		var correndo := absf(vel_x) >= VELOCIDADE_ANDAR * 0.9
		var impulso := PULO_CORRIDA if correndo else PULO
		esmagamento = -0.18 * (impulso / PULO)
		vel_esmagamento = 0.0
		vel_coluna -= 2.2 + (1.1 if correndo else 0.0)
		coluna = clampf(coluna + 0.28, -0.32, 1.72)
		vel_balanco = 0.0
		tempo_parado = 0.0
		tempo_ar = 0.12
		espernear = 0.0
		reserva_pulo = 0.0
		folga_chao = 0.0
		pulo_segurado = true
	if pousou:
		var impacto := maxf(vel_y_anterior, 0.0)
		esmagamento = clampf(impacto / 760.0, 0.1, 0.9)
		vel_esmagamento = 0.0
		vel_balanco += clampf(impacto / 820.0, 0.0, 1.3) * 1.8
		vel_coluna += olhando * 0.18
		em_pe = 0.0
		tempo_parado = 0.0
		tempo_ar = 0.0
		espernear = 0.0
		acabou_de_pousar = true
	no_chao = no_chao_agora
	if no_chao:
		origem_y = chao_y - ALTURA_MONTARIA
	if no_chao and absf(vel_x) < 7.0 and movimento == 0.0:
		tempo_parado += delta
	else:
		tempo_parado = 0.0
	var alvo_em_pe := 0.0
	if no_chao:
		alvo_em_pe = smoothstep(0.0, 1.0, (tempo_parado - 0.28) / 0.55)
	em_pe = amortecer(em_pe, alvo_em_pe, 7.0, delta)
	atividade = amortecer(atividade, clampf(absf(vel_x) / VELOCIDADE_ANDAR, 0.0, 1.0), 6.5, delta)
	if not no_chao:
		tempo_ar += delta * (0.7 + absf(vel_y) / 620.0 + absf(vel_x) / 260.0)
	else:
		tempo_ar = maxf(0.0, tempo_ar - delta * 4.0)
	var alvo_espernear := smoothstep(0.0, 1.0, (tempo_ar - 0.9) / 1.0)
	espernear = amortecer(espernear, alvo_espernear, 8.0, delta)
	var alvo_coluna := 0.0
	var rigidez := 75.0
	var amortecimento := 12.0
	if na_parede:
		alvo_coluna = 1.48 + sin(tempo * 2.4) * 0.02
		rigidez = 90.0
		amortecimento = 14.0
		esmagamento = amortecer(esmagamento, 0.28, 10.0, delta)
		vel_esmagamento = 0.0
	elif no_chao:
		var rasteira := 0.22 - atividade * 0.06
		alvo_coluna = lerpf(rasteira, 1.08, em_pe)
		alvo_coluna += sin(tempo * 1.7) * 0.01 * (1.0 - atividade) * em_pe
		rigidez = 75.0
		amortecimento = 12.0
	else:
		if giro_ativo:
			alvo_coluna = 0.78
		elif vel_y < -40.0:
			alvo_coluna = 0.72 - clampf(vel_y * 0.00075, -0.4, 0.0)
		elif vel_y > 40.0:
			alvo_coluna = 0.2 - clampf(vel_y * 0.00055, 0.0, 0.35)
		else:
			alvo_coluna = 0.42 - clampf(vel_y * 0.0007, -0.3, 0.3)
		alvo_coluna += espernear * 0.28 + atividade * 0.05
		rigidez = 42.0
		amortecimento = 5.5
	if ataque_apertado and (not giro_ativo) and longe_do_chao() and not na_parede:
		iniciar_giro()
		vel_coluna -= 0.55
	atualizar_giro(delta)
	vel_coluna += ((alvo_coluna - coluna) * rigidez - vel_coluna * amortecimento) * delta
	coluna = clampf(coluna + vel_coluna * delta, -0.32, 1.72)
	vel_balanco += (-balanco * 170.0 - vel_balanco * 20.0) * delta
	balanco = clampf(balanco + vel_balanco * delta, -6.0, 9.0)
	if not na_parede:
		vel_esmagamento += (-esmagamento * 120.0 - vel_esmagamento * 13.0) * delta
		esmagamento = clampf(esmagamento + vel_esmagamento * delta, -0.32, 1.0)
	calcular_nucleo()
	arrastar_referencial(delta)
	if acabou_de_pousar:
		posicionar_pes()
	if na_parede:
		var subindo := absf(vel_y) > 4.0 or bool(pai.get("GRAPPLE"))
		if subindo:
			distancia_parede += maxf(absf(vel_y), 40.0) * delta
	elif no_chao:
		distancia_passo += absf(vel_x) * delta
		if absf(vel_x) < 2.0:
			distancia_passo = lerpf(distancia_passo, roundf(distancia_passo / PI) * PI, 1.0 - exp(-6.0 * delta))
	atualizar_pernas(delta)
	atualizar_cauda(delta)
	atualizar_rosto(delta)
	if na_parede:
		cabeca_x = peito.x + olhando * 6.0
		cabeca_y = peito.y - 12.0
	else:
		cabeca_x = peito.x + olhando * lerpf(15.0, 8.0, em_pe)
		cabeca_y = peito.y - lerpf(10.0, 18.0, em_pe)
	atualizar_cabeca()
	estava_no_chao = no_chao
	vel_y_anterior = vel_y
	posicao_anterior = pai.global_position
	tem_posicao_anterior = true


func arraste_deste_quadro(_delta: float) -> Vector2:
	if pai == null or not tem_posicao_anterior:
		return Vector2.ZERO
	var delta_global := pai.global_position - posicao_anterior
	return -global_transform.affine_inverse().basis_xform(delta_global)


func arrastar_referencial(delta: float) -> void:
	var arraste := arraste_deste_quadro(delta)
	for elo: Elo in cauda:
		elo.ponto += arraste
		elo.anterior += arraste


func atualizar_pernas(delta: float) -> void:
	for perna: Perna in pernas:
		atualizar_perna(perna, delta)


func alvo_parede(perna: Perna, ancora: Vector2) -> Vector2:
	var afastamento := 4.0 if perna.longe else 2.5
	var espalhar := 10.0 if perna.frente else -8.0
	if perna.longe:
		espalhar += 3.0 if perna.frente else -2.5
	else:
		espalhar += -1.2 if perna.frente else 1.5
	return Vector2(parede_x - lado_parede * afastamento, ancora.y + espalhar)


func atualizar_perna(perna: Perna, delta: float) -> void:
	var ancora := ancora_perna(perna)
	perna.quadril = ancora
	perna.espera = 0.0
	perna.passo = null
	perna.tem_casa = false
	perna.erro = 0.0
	perna.limiar = 0.0
	if giro_ativo:
		var recolhido := empurrar_fora_do_corpo(Vector2(
			ancora.x + olhando * (3.5 if perna.frente else -3.5) + (-2.0 if perna.longe else 2.0),
			ancora.y + 10.0
		))
		perna.pe.x = amortecer(perna.pe.x, recolhido.x, 16.0, delta)
		perna.pe.y = amortecer(perna.pe.y, recolhido.y, 16.0, delta)
		resolver_perna(perna)
		return
	if na_parede:
		var alvo := pe_ciclo_parede(perna, ancora)
		perna.pe.x = amortecer(perna.pe.x, alvo.x, 14.0, delta)
		perna.pe.y = amortecer(perna.pe.y, alvo.y, 14.0, delta)
		perna.casa = alvo
		perna.tem_casa = true
		resolver_perna(perna)
		return
	if not no_chao:
		var alvo := alvo_ar(perna, ancora)
		perna.pe.x = amortecer(perna.pe.x, alvo.x, 10.0, delta)
		perna.pe.y = amortecer(perna.pe.y, alvo.y, 10.0, delta)
		resolver_perna(perna)
		return
	var levantar := 0.0
	if perna.frente and atividade < 0.12:
		levantar = smoothstep(0.0, 1.0, (em_pe - 0.18) / 0.5)
	if levantar > 0.02:
		var chao := casa_chao(perna, ancora)
		var pendurada := pendurar_frente(perna, ancora)
		var tx := lerpf(chao.x, pendurada.x, levantar)
		var ty := lerpf(chao.y, pendurada.y, levantar)
		perna.pe.x = amortecer(perna.pe.x, tx, 12.0, delta)
		perna.pe.y = amortecer(perna.pe.y, ty, 12.0, delta)
		resolver_perna(perna)
		return
	var alvo := pe_ciclo_chao(perna)
	perna.casa = alvo
	perna.tem_casa = true
	var taxa := 18.0 if absf(vel_x) > 8.0 else 10.0
	perna.pe.x = amortecer(perna.pe.x, alvo.x, taxa, delta)
	perna.pe.y = amortecer(perna.pe.y, alvo.y, taxa, delta)
	resolver_perna(perna)


func agendar_passos(delta: float) -> void:
	espera_grupo = maxf(0.0, espera_grupo - delta)
	if na_parede or not no_chao or espera_grupo > 0.0 or alguma_perna_no_passo():
		return
	var rapidez := absf(vel_x)
	if rapidez < 2.0:
		return
	var erros := [0.0, 0.0]
	var limiares := [0.0, 0.0]
	var contagens := [0, 0]
	for perna: Perna in pernas:
		if not perna.tem_casa:
			continue
		contagens[perna.grupo] += 1
		erros[perna.grupo] = maxf(erros[perna.grupo], perna.erro)
		limiares[perna.grupo] = maxf(limiares[perna.grupo], perna.limiar)
	var prontos: Array[int] = []
	for grupo in 2:
		if contagens[grupo] > 0 and erros[grupo] > limiares[grupo] * 0.88:
			prontos.append(grupo)
	if prontos.is_empty():
		return
	var escolhido := -1
	if ultimo_grupo >= 0:
		var outro := -1
		var mesmo := -1
		for grupo in prontos:
			if grupo != ultimo_grupo:
				outro = grupo
			else:
				mesmo = grupo
		if outro >= 0 and (erros[outro] > limiares[outro] * 0.55 or mesmo < 0):
			escolhido = outro
		elif mesmo >= 0:
			escolhido = mesmo
		else:
			escolhido = outro
	else:
		var melhor := -1.0
		for grupo in prontos:
			if erros[grupo] > melhor:
				melhor = erros[grupo]
				escolhido = grupo
	if escolhido < 0:
		return
	var comecou := 0
	for perna: Perna in pernas:
		if perna.grupo != escolhido or perna.passo != null or perna.espera > 0.0 or not perna.tem_casa:
			continue
		iniciar_passo(perna, perna.quadril, perna.casa, rapidez)
		resolver_perna(perna)
		comecou += 1
	if comecou > 0:
		ultimo_grupo = escolhido
		espera_grupo = 0.16


func pe_no_chao_alcancavel(ancora: Vector2, desejado_x: float, l1: float, l2: float, frente: bool) -> Vector2:
	var alcance := (l1 + l2) * 0.92
	var x := desejado_x
	if frente:
		var minimo := peito.x + olhando * 6.0
		if (minimo - x) * olhando > 0.0:
			x = minimo
	for _i in 10:
		var y := superficie_em(x) - 1.5
		var delta := Vector2(x - ancora.x, y - ancora.y)
		if delta.length() <= alcance:
			return Vector2(x, y)
		x = lerpf(x, ancora.x, 0.18)
		if frente and (peito.x + olhando * 4.0 - x) * olhando > 0.0:
			x = peito.x + olhando * 4.0
			break
	var y_final := superficie_em(x) - 1.5
	var delta_final := Vector2(x - ancora.x, y_final - ancora.y)
	var dist := delta_final.length()
	if dist < 0.0001:
		return Vector2(ancora.x + olhando * 4.0, ancora.y + minf(alcance * 0.8, 18.0))
	if dist > alcance:
		return ancora + delta_final / dist * alcance
	return Vector2(x, y_final)


func forcar_passo_dianteiro_atrasado() -> void:
	if not no_chao or na_parede or alguma_perna_no_passo() or espera_grupo > 0.0:
		return
	var rapidez := absf(vel_x)
	for perna: Perna in pernas:
		if not perna.frente or perna.passo != null or not perna.tem_casa or perna.espera > 0.0:
			continue
		var atrasado := (peito.x - perna.pe.x) * olhando
		if atrasado > 10.0:
			iniciar_passo(perna, perna.quadril, perna.casa, maxf(rapidez, 40.0))
			resolver_perna(perna)
			espera_grupo = 0.14
			return


func iniciar_passo(perna: Perna, ancora: Vector2, casa: Vector2, rapidez: float) -> void:
	var duracao := clampf(0.28 - atividade * 0.04, 0.22, 0.32)
	var lead := (8.0 if perna.frente else 4.0) + rapidez * duracao * 0.5
	var destino_x := casa.x + olhando * lead
	if perna.frente:
		var minimo := peito.x + olhando * 8.0
		if (minimo - destino_x) * olhando > 0.0:
			destino_x = minimo
	var destino := pe_no_chao_alcancavel(ancora, destino_x, perna.l1, perna.l2, perna.frente)
	var dist := Vector2(destino.x - perna.pe.x, destino.y - perna.pe.y).length()
	var passo := Passo.new()
	passo.de = perna.pe
	passo.para = destino
	passo.decorrido = 0.0
	passo.duracao = duracao
	passo.altura = 4.0 + minf(9.0, dist * 0.22) + atividade * 1.4
	passo.vertical = false
	perna.passo = passo
	perna.espera = 0.06 + randf() * 0.04


func iniciar_passo_parede(perna: Perna, ancora: Vector2) -> void:
	var agarrado := bool(pai.get("GRAPPLE")) if pai != null else false
	var subindo := vel_y < -5.0 or agarrado
	var sentido_y := -1.0 if subindo else 1.0
	var lift := (14.0 if perna.frente else 10.0) * sentido_y
	var base := alvo_parede(perna, ancora)
	var destino_y := clampf(ancora.y + (8.0 if perna.frente else -6.0) + lift * 0.65, ancora.y - 22.0, ancora.y + 20.0)
	var passo := Passo.new()
	passo.de = perna.pe
	passo.para = Vector2(base.x, destino_y)
	passo.decorrido = 0.0
	passo.duracao = 0.28
	passo.altura = 2.5
	passo.vertical = true
	perna.passo = passo
	perna.espera = 0.08 + randf() * 0.04


func agendar_passos_parede(delta: float) -> void:
	espera_grupo = maxf(0.0, espera_grupo - delta)
	if espera_grupo > 0.0 or alguma_perna_no_passo():
		return
	var agarrado := bool(pai.get("GRAPPLE")) if pai != null else false
	if not agarrado and absf(vel_y) < 8.0:
		return
	var escolhido := 0 if ultimo_grupo != 0 else 1
	if ultimo_grupo < 0:
		escolhido = 0
	var comecou := 0
	for perna: Perna in pernas:
		if perna.grupo != escolhido or perna.passo != null or perna.espera > 0.0:
			continue
		iniciar_passo_parede(perna, perna.quadril)
		resolver_perna(perna)
		comecou += 1
	if comecou > 0:
		ultimo_grupo = escolhido
		espera_grupo = 0.18


func resolver_perna(perna: Perna) -> void:
	var dobra := (1.0 if perna.frente else -1.0) * olhando
	if na_parede:
		dobra = -lado_parede
	var pe_alvo := perna.pe
	if (giro_ativo or not no_chao) and not na_parede:
		pe_alvo = empurrar_fora_do_corpo(pe_alvo, perna.frente)
	if perna.frente and no_chao and not na_parede and not giro_ativo:
		var minimo := peito.x + olhando * 6.0
		if (minimo - pe_alvo.x) * olhando > 0.0:
			pe_alvo.x = minimo
	var resultado := resolver_ik(perna.quadril.x, perna.quadril.y, pe_alvo.x, pe_alvo.y, perna.l1, perna.l2, dobra)
	perna.joelho = empurrar_fora_do_corpo(resultado["joelho"], perna.frente)
	perna.pe_ik = resultado["pe"]
	if perna.frente and no_chao and not na_parede:
		var minimo_ik := peito.x + olhando * 4.0
		if (minimo_ik - perna.pe_ik.x) * olhando > 0.0:
			perna.pe_ik.x = minimo_ik


func atualizar_cauda(delta: float) -> void:
	var ax := quadril.x - olhando * (RAIO_QUADRIL * 0.72)
	var ay := quadril.y + RAIO_QUADRIL * 0.42
	var raiz := cauda[0]
	raiz.ponto = Vector2(ax, ay)
	raiz.anterior = raiz.ponto
	var reter := pow(0.5, delta)
	var dt2 := delta * delta
	for i in range(1, ELOS):
		var elo := cauda[i]
		var vx := (elo.ponto.x - elo.anterior.x) * reter
		var vy := (elo.ponto.y - elo.anterior.y) * reter
		elo.anterior = elo.ponto
		var gravidade := (620.0 if no_chao else 180.0) * (GRAVIDADE / 1600.0) * (0.8 + float(i) / float(ELOS) * 0.4)
		var curva := em_pe * pow(float(i) / float(ELOS), 1.4)
		var balanco_cauda := sin(tempo * 1.35 + float(i) * 0.62) * 34.0 * curva
		var abanar := sin(tempo * 2.0 + float(i) * 0.9) * (6.0 + absf(vel_x) * 0.04)
		elo.ponto.x += vx + (balanco_cauda + abanar) * dt2
		elo.ponto.y += vy + (gravidade - 200.0 * curva) * dt2
		var piso := chao_y - raios_cauda[i] * 0.8
		if elo.ponto.y > piso:
			elo.ponto.y = piso
			elo.anterior.x = lerpf(elo.anterior.x, elo.ponto.x, 0.35)
			elo.anterior.y = lerpf(elo.anterior.y, elo.ponto.y, 0.35)
	for _iter in 3:
		for i in range(1, ELOS):
			var a := cauda[i - 1]
			var b := cauda[i]
			var delta_elo := b.ponto - a.ponto
			var dist := delta_elo.length()
			if dist < 0.0001:
				dist = 0.0001
			var diff := (dist - COMPRIMENTO_ELO) / dist
			if i == 1:
				b.ponto -= delta_elo * diff
			else:
				a.ponto += delta_elo * diff * 0.5
				b.ponto -= delta_elo * diff * 0.5
		for i in range(1, ELOS - 1):
			var a := cauda[i - 1]
			var b := cauda[i]
			var c := cauda[i + 1]
			var k := 0.16 * (1.0 - float(i) / float(ELOS))
			b.ponto += ((a.ponto + c.ponto) * 0.5 - b.ponto) * k
		for i in range(1, ELOS):
			var elo := cauda[i]
			var piso := chao_y - raios_cauda[i] * 0.8
			if elo.ponto.y > piso:
				elo.ponto.y = piso
	if em_pe > 0.02 and no_chao:
		var base := cauda[0]
		for i in range(1, ELOS):
			var elo := cauda[i]
			var u := float(i) / float(ELOS - 1)
			var tx := base.ponto.x - olhando * float(i) * COMPRIMENTO_ELO + sin(tempo * 1.1 + float(i) * 0.5) * 1.4 * em_pe
			var ty := base.ponto.y + 1.0 + float(i) * 0.5 - u * u * 17.0 * em_pe
			var piso := chao_y - raios_cauda[i] * 0.8
			elo.ponto.x = lerpf(elo.ponto.x, tx, 0.035 * em_pe)
			elo.ponto.y = lerpf(elo.ponto.y, minf(ty, piso), 0.035 * em_pe)
		for i in range(1, ELOS):
			var a := cauda[i - 1]
			var b := cauda[i]
			var delta_elo := b.ponto - a.ponto
			var dist := delta_elo.length()
			if dist < 0.0001:
				dist = 0.0001
			var diff := (dist - COMPRIMENTO_ELO) / dist
			if i == 1:
				b.ponto -= delta_elo * diff
			else:
				a.ponto += delta_elo * diff * 0.5
				b.ponto -= delta_elo * diff * 0.5


func atualizar_rosto(delta: float) -> void:
	espera_piscada -= delta
	if espera_piscada <= 0.0:
		tempo_piscada = 0.12
		espera_piscada = 2.5 + randf() * 4.5
	if tempo_piscada > 0.0:
		tempo_piscada -= delta
	if tempo_piscada > 0.0:
		piscada = sin(clampf(1.0 - tempo_piscada / 0.12, 0.0, 1.0) * PI)
	else:
		piscada = 0.0
	var alvo_orelha := clampf(
		vel_x * olhando * 0.00009 + espernear * 0.35 + sin(tempo * 0.8) * 0.015,
		-0.28,
		0.45
	)
	vel_orelha += ((alvo_orelha - inclinacao_orelha) * 90.0 - vel_orelha * 12.0) * delta
	inclinacao_orelha = clampf(inclinacao_orelha + vel_orelha * delta, -0.5, 0.6)
	var alvo_inclinacao := clampf(
		vel_y * 0.00022 + sin(tempo * 1.9) * 0.01 * (1.0 - atividade) + espernear * 0.12,
		-0.22,
		0.24
	)
	inclinacao_cabeca = alvo_inclinacao


func atualizar_cabeca() -> void:
	var centro := transformar(Vector2(cabeca_x, cabeca_y))
	cabeca.position = centro
	cabeca.rotation = inclinacao_cabeca * olhando + giro_angulo
	cabeca.flip_h = olhando < 0.0
	var sx := ESCALA_CABECA * (1.0 + esmagamento * 0.14)
	var sy := ESCALA_CABECA * (1.0 - esmagamento * 0.18) * (1.0 - piscada * 0.12)
	if na_parede:
		sx *= 0.96
		sy *= 1.04
	cabeca.scale = Vector2(sx, sy)
	var parado := (not giro_ativo) and (not na_parede) and no_chao and em_pe > 0.55 and absf(vel_x) < 8.0
	var textura: Texture2D = TEXTURA_FRENTE if parado else TEXTURA_LADO
	if cabeca.texture != textura:
		cabeca.texture = textura


func esmagar(ponto: Vector2) -> Vector2:
	var sx := 1.0 + esmagamento * 0.14
	var sy := 1.0 - esmagamento * 0.18
	return Vector2(origem_x + (ponto.x - origem_x) * sx, chao_y + (ponto.y - chao_y) * sy)


func resolver_ik(ax: float, ay: float, tx: float, ty: float, l1: float, l2: float, dobra: float) -> Dictionary:
	var dx := tx - ax
	var dy := ty - ay
	var dist := sqrt(dx * dx + dy * dy)
	if dist < 0.0001:
		dist = 0.0001
	var minimo := absf(l1 - l2) + 0.5
	var maximo := l1 + l2 - 0.4
	if dist < minimo:
		dx = dx / dist * minimo
		dy = dy / dist * minimo
		dist = minimo
	elif dist > maximo:
		dx = dx / dist * maximo
		dy = dy / dist * maximo
		dist = maximo
	tx = ax + dx
	ty = ay + dy
	var base := atan2(dy, dx)
	var cos_a := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var angulo := base + dobra * acos(cos_a)
	return {
		"joelho": Vector2(ax + cos(angulo) * l1, ay + sin(angulo) * l1),
		"pe": Vector2(tx, ty),
	}


func alguma_perna_no_passo() -> bool:
	for perna: Perna in pernas:
		if perna.passo != null:
			return true
	return false


func amortecer(atual: float, alvo: float, taxa: float, delta: float) -> float:
	return lerpf(atual, alvo, 1.0 - exp(-taxa * delta))


func sinal(valor: float) -> float:
	return -1.0 if valor < 0.0 else 1.0


func _draw() -> void:
	desenhar_cauda()
	for perna: Perna in pernas:
		if perna.longe:
			desenhar_perna(perna)
	desenhar_corpo()
	for perna: Perna in pernas:
		if not perna.longe:
			desenhar_perna(perna)


func desenhar_corpo() -> void:
	var dx := peito.x - quadril.x
	var dy := peito.y - quadril.y
	var comprimento := Vector2(dx, dy).length()
	if comprimento < 1.0:
		comprimento = 1.0
	var nx := dy / comprimento
	var ny := -dx / comprimento
	var sy := 1.0 - esmagamento * 0.18
	for i in 7:
		var t := float(i) / 6.0
		var arco := sin(PI * t) * 3.4 * (1.0 - em_pe * 0.35)
		var raio := lerpf(RAIO_QUADRIL, RAIO_PEITO, t) + sin(PI * t) * 2.0
		var centro := Vector2(
			lerpf(quadril.x, peito.x, t) + nx * arco,
			lerpf(quadril.y, peito.y, t) + ny * arco
		)
		draw_circle(transformar(centro), maxf(0.5, raio * sy), COR_CORPO)
	for perna: Perna in pernas:
		if perna.longe:
			continue
		var raio_junta := 4.2 if perna.frente else 5.4
		draw_circle(transformar(perna.quadril), raio_junta * sy, COR_SOMBRA)


func desenhar_perna(perna: Perna) -> void:
	var cor := COR_LONGE if perna.longe else COR_QUENTE
	var sy := 1.0 - esmagamento * 0.18
	var quadril_p := transformar(perna.quadril)
	var joelho_p := transformar(perna.joelho)
	var pe_p := transformar(perna.pe_ik)
	draw_line(quadril_p, joelho_p, cor, maxf(0.5, perna.w1 * sy), true)
	draw_line(joelho_p, pe_p, cor, maxf(0.5, perna.w2 * sy), true)
	draw_circle(joelho_p, maxf(0.4, perna.w2 * 0.55 * sy), cor)
	var pata := (4.7 if perna.frente else 5.3) * sy
	draw_circle(pe_p, maxf(0.5, pata), cor)
	if not perna.longe:
		draw_circle(quadril_p, 2.4 * sy, COR_ENCAIXE)


func desenhar_cauda() -> void:
	var pontos := PackedVector2Array()
	pontos.resize(ELOS)
	for i in ELOS:
		var elo := cauda[i]
		var u := float(i) / float(ELOS - 1)
		var onda := sin(tempo * 5.4 + float(i) * 0.55) * (0.8 + atividade * 2.4 + em_pe * 1.2) * u
		var lento := sin(tempo * 1.4 + float(i) * 0.5) * 1.1 * em_pe * u
		var levantar := pow(u, 1.5) * (atividade * 4.5 + em_pe * 9.0)
		pontos[i] = transformar(Vector2(elo.ponto.x + onda + lento, elo.ponto.y - levantar))
	for i in range(1, ELOS):
		var cor := COR_QUENTE if i > ELOS - 3 else COR_CORPO
		var largura := raios_cauda[i - 1] + raios_cauda[i]
		draw_line(pontos[i - 1], pontos[i], cor, maxf(0.6, largura), true)
	draw_circle(pontos[ELOS - 1], raios_cauda[ELOS - 1], COR_QUENTE)

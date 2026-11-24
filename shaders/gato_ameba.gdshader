shader_type canvas_item;

// Dimensões e origem do ColorRect em espaço local do GatoAmeba (em pixels)
uniform vec2 rect_size = vec2(220.0, 200.0);
uniform vec2 rect_origin = vec2(-110.0, -120.0);

// Paleta configurável (suporta mudança de cor ao absorver almas no futuro)
uniform vec4 cor_base : source_color = vec4(0.97, 0.99, 1.0, 1.0);
uniform vec4 cor_sombra : source_color = vec4(0.70, 0.80, 0.89, 1.0);
uniform vec4 cor_brilho : source_color = vec4(0.84, 0.98, 1.0, 1.0);
uniform vec4 cor_contorno : source_color = vec4(0.56, 0.68, 0.78, 0.72);
uniform float intensidade_aura : hint_range(0.0, 1.5) = 0.28;
uniform float flash_dano : hint_range(0.0, 1.0) = 0.0;

// Direção horizontal do olhar (-1..+1) para orientar luz suave
uniform float facing = 1.0;

// Cabeça e orelhinhas
uniform vec2 head_pos = vec2(0.0, 6.0);
uniform vec2 head_radii = vec2(17.5, 15.2);
uniform float head_rot = 0.0;
uniform vec2 ear_l_base = vec2(-9.5, -6.0);
uniform vec2 ear_l_tip = vec2(-12.5, -18.0);
uniform vec2 ear_r_base = vec2(9.5, -6.0);
uniform vec2 ear_r_tip = vec2(12.5, -18.0);
uniform float ear_r_base_size = 5.4;
uniform float ear_r_tip_size = 2.0;

// Corpo amebóide (tronco, quadril e dois lóbulos de base que se espalham)
uniform vec2 torso_pos = vec2(0.0, 20.0);
uniform float torso_r = 16.0;
uniform vec2 hip_pos = vec2(0.0, 32.5);
uniform float hip_r = 19.5;
uniform vec2 base_l_pos = vec2(-10.0, 38.0);
uniform float base_l_r = 11.5;
uniform vec2 base_r_pos = vec2(10.0, 38.0);
uniform float base_r_r = 11.5;

// Cauda dinâmica (3 pontos formando 2 segmentos cônicos fundidos à massa)
uniform vec2 tail_p0 = vec2(-14.0, 34.0);
uniform vec2 tail_p1 = vec2(-25.0, 28.0);
uniform vec2 tail_p2 = vec2(-30.0, 12.0);
uniform float tail_r0 = 6.2;
uniform float tail_r1 = 4.6;
uniform float tail_r2 = 2.6;
uniform float tail_weight : hint_range(0.0, 1.0) = 0.85;

// Pata de ataque (brota da ameba, golpeia em arco e reabsorve)
uniform vec2 paw_base = vec2(8.0, 14.0);
uniform vec2 paw_tip = vec2(40.0, 4.0);
uniform float paw_r_base = 5.2;
uniform float paw_r_tip = 7.4;
uniform float paw_weight : hint_range(0.0, 1.0) = 0.0;

// Sensores de ambiente (chão em 3 pontos, parede e teto)
uniform float ground_y_l = 49.0;
uniform float ground_y_c = 49.0;
uniform float ground_y_r = 49.0;
uniform float ground_blend : hint_range(0.0, 1.0) = 1.0;

uniform float wall_x = 14.0;
uniform float wall_dir = 1.0;
uniform float wall_blend : hint_range(0.0, 1.0) = 0.0;

uniform float ceil_y = -60.0;
uniform float ceil_blend : hint_range(0.0, 1.0) = 0.0;

// Smooth minimum cúbico (fusão orgânica de metaballs)
float smin(float a, float b, float k) {
	float h = max(k - abs(a - b), 0.0) / max(k, 0.0001);
	return min(a, b) - h * h * h * k * (1.0 / 6.0);
}

// Smooth maximum (achatamento orgânico contra superfícies do ambiente)
float smax(float a, float b, float k) {
	return -smin(-a, -b, k);
}

float sd_circle(vec2 p, vec2 c, float r) {
	return length(p - c) - r;
}

// Elipse aproximada com distância estável e rápida
float sd_ellipse_approx(vec2 p, vec2 c, vec2 r, float angle) {
	vec2 q = p - c;
	float ca = cos(-angle);
	float sa = sin(-angle);
	q = vec2(ca * q.x - sa * q.y, sa * q.x + ca * q.y);
	vec2 inv_r = 1.0 / max(r, vec2(0.001));
	float k0 = length(q * inv_r);
	float k1 = length(q * inv_r * inv_r);
	return k0 * (k0 - 1.0) / max(k1, 0.0001);
}

// Cápsula com raios diferentes nas pontas (perfeita para orelhinhas e cauda)
float sd_uneven_capsule(vec2 p, vec2 a, vec2 b, float ra, float rb) {
	vec2 ba = b - a;
	float l2 = dot(ba, ba);
	if (l2 < 0.0001) {
		return length(p - a) - max(ra, rb);
	}
	float h = clamp(dot(p - a, ba) / l2, 0.0, 1.0);
	float r = mix(ra, rb, h);
	return length(p - (a + ba * h)) - r;
}

// Interpola a curva do chão a partir dos 3 RayCast2D (-22, 0, +22)
float sample_ground_y(float x) {
	float t = clamp(x / 22.0, -1.3, 1.3);
	float a = 0.5 * (ground_y_l + ground_y_r) - ground_y_c;
	float b = 0.5 * (ground_y_r - ground_y_l);
	return ground_y_c + b * t + a * t * t;
}

float map_sdf(vec2 p) {
	// Cabeça + orelhinhas suavemente fundidas
	float d_head = sd_ellipse_approx(p, head_pos, head_radii, head_rot);
	float d_ear_l = sd_uneven_capsule(p, ear_l_base, ear_l_tip, ear_r_base_size, ear_r_tip_size);
	float d_ear_r = sd_uneven_capsule(p, ear_r_base, ear_r_tip, ear_r_base_size, ear_r_tip_size);
	float d = smin(d_head, d_ear_l, 5.2);
	d = smin(d, d_ear_r, 5.2);

	// Tronco e quadril em cápsula orgânica + fusão suave com a cabeça
	float d_trunk = sd_uneven_capsule(p, torso_pos, hip_pos, torso_r, hip_r);
	d = smin(d, d_trunk, 11.5);

	// Lóbulos inferiores que acompanham o chão (pouso e derretimento)
	float d_bl = sd_circle(p, base_l_pos, base_l_r);
	float d_br = sd_circle(p, base_r_pos, base_r_r);
	d = smin(d, d_bl, 10.5);
	d = smin(d, d_br, 10.5);

	// Cauda dinâmica: retrai suavemente quando tail_weight -> 0
	if (tail_weight > 0.02) {
		float scale_t = mix(0.25, 1.0, tail_weight);
		vec2 tp1 = mix(tail_p0, tail_p1, tail_weight);
		vec2 tp2 = mix(tail_p0, tail_p2, tail_weight);
		float d_t1 = sd_uneven_capsule(p, tail_p0, tp1, tail_r0 * scale_t, tail_r1 * scale_t);
		float d_t2 = sd_uneven_capsule(p, tp1, tp2, tail_r1 * scale_t, tail_r2 * scale_t);
		float d_tail = smin(d_t1, d_t2, 3.5);
		d = smin(d, d_tail, 6.5 * tail_weight);
	}

	// Pata de ataque: brota do ombro com 3 dedinhos fofos na ponta e golpeia em arco
	if (paw_weight > 0.01) {
		float pw = paw_weight;
		vec2 tip_atual = mix(paw_base, paw_tip, pw);
		float r_b = paw_r_base * mix(0.35, 1.0, pw);
		float r_t = paw_r_tip * mix(0.3, 1.0, pw);
		float d_paw = sd_uneven_capsule(p, paw_base, tip_atual, r_b, r_t);

		vec2 dir_p = tip_atual - paw_base;
		float len_p = length(dir_p);
		if (len_p > 1.0) {
			vec2 fwd = dir_p / len_p;
			vec2 perp = vec2(-fwd.y, fwd.x);
			float dedo_r = 3.1 * pw;
			float d_dedo_c = sd_circle(p, tip_atual + fwd * (r_t * 0.72), dedo_r);
			float d_dedo_1 = sd_circle(p, tip_atual + fwd * (r_t * 0.52) + perp * (r_t * 0.58), dedo_r * 0.92);
			float d_dedo_2 = sd_circle(p, tip_atual + fwd * (r_t * 0.52) - perp * (r_t * 0.58), dedo_r * 0.92);
			float d_dedos = min(d_dedo_c, min(d_dedo_1, d_dedo_2));
			d_paw = smin(d_paw, d_dedos, 2.6 * pw);
		}
		d = smin(d, d_paw, 6.8 * pw);
	}

	// Adaptação ao chão (menisco viscoso + achatamento sobre a curva do terreno)
	if (ground_blend > 0.005) {
		float gy = sample_ground_y(p.x);
		float d_floor = p.y - gy;
		// Leve espalhamento lateral quando muito próximo ao contato com o piso
		float dist_acima = max(gy - p.y, 0.0);
		float menisco = exp(-dist_acima * 0.22) * 2.4 * ground_blend;
		float d_no_chao = smax(d - menisco, d_floor, 5.0);
		d = mix(d, d_no_chao, ground_blend);
	}

	// Adaptação à parede (aderência viscosa durante escalada/wall-slide)
	if (wall_blend > 0.005) {
		float d_wall = (p.x - wall_x) * wall_dir;
		float dist_parede = max(-d_wall, 0.0);
		float menisco_w = exp(-dist_parede * 0.20) * 2.2 * wall_blend;
		float d_na_parede = smax(d - menisco_w, d_wall, 4.8);
		d = mix(d, d_na_parede, wall_blend);
	}

	// Adaptação ao teto (compressão suave se encostar em teto baixo)
	if (ceil_blend > 0.005) {
		float d_ceil = ceil_y - p.y;
		float d_no_teto = smax(d, d_ceil, 5.0);
		d = mix(d, d_no_teto, ceil_blend);
	}

	return d;
}

void fragment() {
	vec2 p = rect_origin + UV * rect_size;
	float d = map_sdf(p);

	// Descarta pixels longe da aura para manter excelente performance
	if (d > 26.0) {
		COLOR = vec4(0.0);
	} else {
		float aa = max(fwidth(d), 0.75);
		float mask = 1.0 - smoothstep(-aa, aa, d);

		// Gradiente 2D do SDF para construir normal volumétrica 3D de geleia
		float eps = 1.2;
		vec2 grad = vec2(
			map_sdf(p + vec2(eps, 0.0)) - d,
			map_sdf(p + vec2(0.0, eps)) - d
		);
		vec2 n2 = normalize(grad + vec2(0.0001));

		float depth = clamp(-d / 20.0, 0.0, 1.0);
		// Superfície abobadada (mais inclinada perto da borda, suave no centro)
		float rim_slope = pow(1.0 - depth, 0.62);
		vec2 n_xy = n2 * clamp(rim_slope * 0.92, 0.0, 0.96);
		float n_z = sqrt(max(0.02, 1.0 - dot(n_xy, n_xy)));
		vec3 normal3d = normalize(vec3(n_xy, n_z));

		// Iluminação suave vindo de cima-frente (como nas cutscenes)
		vec3 light_dir = normalize(vec3(0.32 * facing, -0.68, 0.66));
		float ndotl = clamp(dot(normal3d, light_dir), 0.0, 1.0);

		// Cor interna leitosa + sombra macia na base/costas
		float shade_t = smoothstep(0.08, 0.88, ndotl * 0.76 + depth * 0.34);
		vec3 body_rgb = mix(cor_sombra.rgb, cor_base.rgb, shade_t);

		// Núcleo translúcido levemente luminoso (efeito gel/subsurface)
		body_rgb += cor_brilho.rgb * (depth * 0.10);

		// Rim light etéreo nas bordas
		float fresnel = pow(1.0 - clamp(normal3d.z, 0.0, 1.0), 2.1);
		body_rgb = mix(body_rgb, cor_brilho.rgb * 1.12, fresnel * 0.42);

		// Brilho especular gelatinoso no ombro/cabeça (igual slide_03 e city_to_carcass)
		vec3 view_dir = vec3(0.0, 0.0, 1.0);
		vec3 half_vec = normalize(light_dir + view_dir);
		float spec = pow(max(dot(normal3d, half_vec), 0.0), 26.0);
		body_rgb += vec3(1.0) * spec * 0.36 * smoothstep(0.05, 0.45, depth);

		// Contorno translúcido delicado para leitura limpa em qualquer fundo
		float outline_band = (1.0 - smoothstep(0.0, 1.8, -d)) * mask;
		body_rgb = mix(body_rgb, cor_contorno.rgb, outline_band * cor_contorno.a * 0.55);

		// Flash suave de dano
		body_rgb = mix(body_rgb, vec3(1.0, 0.80, 0.82), flash_dano * 0.65);

		// Translucidez levemente maior nas bordas (aparência gelatinosa)
		float body_alpha = mask * mix(0.88, 0.98, depth);

		// Aura luminosa externa suave
		float aura = exp(-max(d, 0.0) * 0.14) * intensidade_aura * (1.0 - mask);
		vec3 final_rgb = mix(cor_brilho.rgb, body_rgb, clamp(body_alpha / max(body_alpha + aura, 0.0001), 0.0, 1.0));
		float final_alpha = clamp(body_alpha + aura, 0.0, 1.0);

		COLOR = vec4(final_rgb, final_alpha);
	}
}

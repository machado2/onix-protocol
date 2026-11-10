// Superfície PBR com mapeamento planar em coordenadas do mundo (paredes, chão, objetos grandes).
// Não depende de UV: peças repetidas não mostram a mesma mancha em todo vão.
// COLOR (cor da instância do MultiMesh) tinge o albedo quando use_instance_tint = 1.
shader_type spatial;
#include "res://shaders/cutaway.gdshaderinc"
render_mode cull_back, depth_draw_opaque;

uniform sampler2D tex_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grime : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float tex_m = 4.0;              // metros por repetição da textura
uniform vec3 tint : source_color = vec3(1.0);
uniform float tint_k = 1.0;            // multiplica o tingimento (tinta de faixa sobre o asfalto)
uniform float use_instance_tint = 0.0;
uniform float metal = 0.0;              // somado ao canal B
uniform float rough_mul = 1.0;
uniform float rough_add = 0.0;
uniform float normal_k = 1.0;
uniform float grime_amt = 0.5;          // sujeira na base das paredes e escorridos
uniform float wet = 0.0;                // chão molhado com poças
uniform float ribs = 0.0;               // nervuras horizontais (portas de enrolar), em metros
uniform vec3 emit : source_color = vec3(0.0);
uniform float emit_k = 0.0;
uniform float cut_ok = 1.0;          // 0 no chão: o recorte só vale para prédios e objetos

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 icol;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	icol = COLOR;
}

void fragment() {
	if (cut_ok > 0.5 && cut_away(wpos, FRAGCOORD.xy)) discard;
	vec3 N = normalize(wnrm);
	vec3 an = abs(N);
	vec2 uv;
	vec3 T;
	vec3 B;
	bool wall = false;
	if (an.y >= an.x && an.y >= an.z) {
		if (N.y > 0.0) { uv = vec2(wpos.x, wpos.z); T = vec3(1, 0, 0); B = vec3(0, 0, -1); }
		else { uv = vec2(wpos.x, -wpos.z); T = vec3(1, 0, 0); B = vec3(0, 0, 1); }
	} else if (an.x >= an.z) {
		float s = sign(N.x);
		uv = vec2(-wpos.z * s, -wpos.y); T = vec3(0, 0, -s); B = vec3(0, 1, 0); wall = true;
	} else {
		float s = sign(N.z);
		uv = vec2(wpos.x * s, -wpos.y); T = vec3(s, 0, 0); B = vec3(0, 1, 0); wall = true;
	}
	vec2 tuv = uv / tex_m;
	vec3 a = min(texture(tex_a, tuv).rgb * tint * tint_k, vec3(0.9));
	if (use_instance_tint > 0.5) a *= icol.rgb;
	vec3 orm = texture(tex_orm, tuv).rgb;
	vec3 tn = texture(tex_n, tuv).rgb * 2.0 - 1.0;
	tn.xy *= normal_k;
	float rough = clamp(orm.g * rough_mul + rough_add, 0.02, 1.0);
	float met = clamp(orm.b + metal, 0.0, 1.0);

	if (ribs > 0.0 && wall) {
		float ph = wpos.y / ribs * 6.2831853;
		tn.y += cos(ph) * 0.6;
		a *= 0.85 + 0.15 * sin(ph);
	}

	if (wall && grime_amt > 0.0) {
		vec3 g = texture(grime, vec2(uv.x / 9.0, uv.y / 23.0)).rgb;
		float base = (1.0 - smoothstep(0.0, 1.6 + g.r * 1.2, wpos.y)) * (0.4 + 0.6 * g.r);
		float streak = g.g * (0.35 + 0.65 * g.r);
		float d = clamp((base * 0.7 + streak * 0.45) * grime_amt, 0.0, 0.8);
		a *= 1.0 - d;
		rough = mix(rough, 1.0, d * 0.5);
	}

	if (wet > 0.0 && N.y > 0.7) {
		vec3 g = texture(grime, wpos.xz / 37.0).rgb;
		float puddle = smoothstep(0.52, 0.6, g.b + (texture(grime, wpos.xz / 5.3).r - 0.5) * 0.12) * wet;
		float damp = (0.55 + 0.45 * g.r) * wet;
		a *= mix(1.0, 0.62, damp);
		rough = mix(rough, rough * 0.45, damp);
		a = mix(a, a * 0.5, puddle);
		rough = mix(rough, 0.03, puddle);
		tn.xy *= 1.0 - puddle;
		met = mix(met, 0.0, puddle);
	}

	vec3 nw = normalize(T * tn.x + B * tn.y + N * max(tn.z, 0.05));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ALBEDO = a;
	ROUGHNESS = rough;
	METALLIC = met;
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.4;
	EMISSION = emit * emit_k;
}

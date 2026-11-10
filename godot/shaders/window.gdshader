// Vidro com interior falso ("interior mapping"): cada janela mostra um cômodo em perspectiva,
// aceso ou apagado, com cor de luz, cortina/persiana e móveis em silhueta sorteados pela posição.
// O reflexo vem do próprio vidro (rugosidade baixa) via SSR e ambiente.
// COLOR da instância: rgb = matiz da loja (vitrines), a = chance de cômodo aceso no prédio.
shader_type spatial;
#include "res://shaders/cutaway.gdshaderinc"
render_mode cull_back;

uniform vec2 room = vec2(1.6, 1.6);    // tamanho do vão em metros
uniform float depth = 3.5;              // profundidade do cômodo
uniform float shop = 0.0;               // 1 = vitrine de loja (sempre acesa, prateleiras)
uniform float frost = 0.0;              // vidro jateado
uniform float tint_dark = 0.0;          // vidro espelhado corporativo
uniform float lit_bias = 0.0;
uniform sampler2D grime : hint_default_black, filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wn;
varying vec4 icol;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	icol = COLOR;
}

float h1(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void fragment() {
	if (cut_away(wpos, FRAGCOORD.xy)) discard;
	vec3 N = normalize(wn);
	vec3 B = vec3(0.0, 1.0, 0.0);
	vec3 T = normalize(cross(B, N));
	vec2 wuv = vec2(UV.x, 1.0 - UV.y);
	// posição do canto do vão no mundo identifica a janela
	vec3 origin = wpos - T * wuv.x * room.x - B * wuv.y * room.y;
	vec3 id = floor(origin * 2.0 + 0.5);
	float r0 = h1(id), r1 = h1(id + 17.3), r2 = h1(id + 41.9), r3 = h1(id + 7.7), r4 = h1(id + 93.1);

	vec3 V = normalize(wpos - CAMERA_POSITION_WORLD);
	vec3 rd = vec3(dot(V, T) / room.x, dot(V, B) / room.y, dot(V, -N) / depth);
	vec3 ro = vec3(wuv, 0.0);
	vec3 tq = vec3(
		rd.x > 0.0 ? (1.0 - ro.x) / rd.x : -ro.x / min(rd.x, -1e-5),
		rd.y > 0.0 ? (1.0 - ro.y) / rd.y : -ro.y / min(rd.y, -1e-5),
		1.0 / max(rd.z, 1e-4));
	float t = min(tq.x, min(tq.y, tq.z));
	vec3 hp = ro + rd * t;

	bool lit = r0 < clamp(icol.a + lit_bias, 0.0, 1.0) || shop > 0.5;
	vec3 lc = r1 < 0.55 ? vec3(1.0, 0.72, 0.42) : r1 < 0.85 ? vec3(0.78, 0.88, 1.0) : vec3(0.55, 0.75, 1.0);
	if (shop > 0.5) lc = mix(vec3(1.0, 0.95, 0.85), icol.rgb, 0.35);
	vec3 wallc = mix(vec3(0.55, 0.5, 0.45), vec3(0.45, 0.5, 0.55), r2);
	vec3 col;
	float z = hp.z;
	if (t == tq.z) {
		col = wallc * 0.8;
		// móveis em silhueta contra a parede do fundo
		float fx0 = 0.15 + r3 * 0.4, fx1 = fx0 + 0.25 + r4 * 0.3;
		if (hp.y < 0.32 + r4 * 0.1 && hp.x > fx0 && hp.x < fx1) col *= 0.25;
		if (shop > 0.5 && fract(hp.y * 4.0) < 0.12) col *= 0.3;   // prateleiras
		if (shop > 0.5 && fract(hp.y * 4.0) > 0.12) col = mix(col, icol.rgb, 0.3 * step(0.5, fract(hp.x * 7.0 + r2)));
		// quadro ou TV
		if (r2 > 0.6 && abs(hp.x - 0.5) < 0.18 && abs(hp.y - 0.6) < 0.1) col = r1 > 0.85 ? vec3(0.3, 0.6, 1.6) : col * 0.4;
	} else if (t == tq.y) {
		col = rd.y < 0.0 ? wallc * vec3(0.55, 0.45, 0.38) : vec3(0.85);
		if (rd.y > 0.0) col += (1.0 - smoothstep(0.05, 0.25, length(hp.xz - vec2(0.5, 0.5)))) * 3.0;   // luminária
	} else {
		col = wallc * 0.9;
		if (shop < 0.5 && r3 > 0.5 && hp.y < 0.55 && hp.z > 0.3 && hp.z < 0.75) col *= 0.3;   // estante
	}
	float fall = mix(1.0, 0.45, z) * (rd.y > 0.0 && t == tq.y ? 1.2 : 1.0);
	vec3 inner = col * lc * fall;

	// cortina / persiana
	float bl = r4 * 1.4 - 0.2;
	if (shop < 0.5 && wuv.y > 1.0 - bl) {
		float slat = step(0.35, fract(wuv.y * room.y * 14.0));
		inner = mix(inner, lc * (0.5 + 0.3 * slat) * vec3(0.9, 0.85, 0.8), 0.85);
	}
	if (!lit) inner *= 0.035;
	float kE = shop > 0.5 ? 2.2 : 1.35;

	float fres = pow(1.0 - clamp(dot(-V, N), 0.0, 1.0), 4.0);
	vec3 g = texture(grime, wpos.xy / 3.1 + wpos.zx / 4.3).rgb;
	if (frost > 0.5) inner = (lit ? lc * 0.9 : vec3(0.02)) * (0.8 + 0.2 * g.r);
	inner *= 1.0 - tint_dark * 0.8;
	EMISSION = inner * kE * (1.0 - fres * 0.85);
	ALBEDO = vec3(0.01) + vec3(0.02, 0.025, 0.03) * tint_dark;
	ROUGHNESS = clamp(0.04 + g.r * 0.12 + frost * 0.3, 0.02, 1.0);
	METALLIC = tint_dark * 0.5;
	SPECULAR = 0.6;
}

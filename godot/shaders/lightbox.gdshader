// Caixa de luz de letreiro: face da frente (local +Z) emite na cor da instância, com leve cintilação;
// as laterais são metal escuro. COLOR.a < 0.5 = letreiro apagado/quebrado.
shader_type spatial;
render_mode cull_back;

uniform float power = 3.0;
varying vec3 lnrm;
varying vec3 lpos;
varying vec4 icol;
varying vec3 wpos;

void vertex() {
	lnrm = NORMAL;
	lpos = VERTEX;
	icol = COLOR;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float h1(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void fragment() {
	float front = smoothstep(0.6, 0.9, lnrm.z);
	float id = h1(floor(wpos * 0.33));
	float on = icol.a > 0.5 ? 1.0 : 0.0;
	float flick = (id > 0.92) ? step(0.3, fract(sin(TIME * 7.0 + id * 50.0) * 43758.5)) : 1.0;
	// moldura escura nas bordas da face
	float edge = smoothstep(0.0, 0.03, min(abs(fract(lpos.x / 2.82 + 0.5) - 0.5) * 2.0, 1.0));
	ALBEDO = mix(vec3(0.03), icol.rgb * 0.4, front);
	METALLIC = 0.6 * (1.0 - front);
	ROUGHNESS = mix(0.35, 0.25, front);
	EMISSION = icol.rgb * power * front * on * flick * edge;
}

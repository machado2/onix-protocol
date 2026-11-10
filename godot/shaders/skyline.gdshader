// Prédios de fundo além das bordas do mapa: blocos escuros com grade de janelas acesas ao acaso.
shader_type spatial;
render_mode cull_back;

uniform vec3 wall : source_color = vec3(0.05, 0.055, 0.07);
varying vec3 wpos;
varying vec3 wn;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float h1(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	ALBEDO = wall;
	ROUGHNESS = 0.8;
	if (abs(wn.y) < 0.5) {
		vec2 uv = vec2(abs(wn.x) > 0.5 ? wpos.z : wpos.x, wpos.y) / vec2(3.0, 3.2);
		vec2 c = floor(uv);
		vec2 f = fract(uv);
		float win = step(0.25, f.x) * step(f.x, 0.75) * step(0.3, f.y) * step(f.y, 0.8);
		float lit = step(0.7, h1(c + floor(wpos.xz * 0.01) * 7.0));
		vec3 lc = mix(vec3(1.0, 0.75, 0.45), vec3(0.6, 0.8, 1.0), step(0.6, h1(c * 1.7)));
		EMISSION = lc * win * lit * 1.2;
	}
}

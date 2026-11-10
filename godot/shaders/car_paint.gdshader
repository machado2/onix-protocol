// Pintura automotiva: cor da instância (MultiMesh COLOR), metálico com verniz, reflexos nítidos e
// um pouco de sujeira na parte de baixo.
shader_type spatial;
render_mode cull_back;

uniform sampler2D grime : hint_default_black, filter_linear_mipmap, repeat_enable;
varying vec4 icol;
varying vec3 lpos;
varying vec3 wpos;

void vertex() {
	icol = COLOR;
	lpos = VERTEX;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float g = texture(grime, wpos.xz * 0.37 + wpos.y * 0.21).r;
	float dirt = (1.0 - smoothstep(0.25, 0.75, lpos.y)) * (0.4 + 0.6 * g);
	ALBEDO = mix(icol.rgb, vec3(0.12, 0.1, 0.08), dirt * 0.6);
	METALLIC = 0.55 * (1.0 - dirt);
	ROUGHNESS = mix(0.32, 0.7, dirt);
	CLEARCOAT = 1.0 - dirt;
	CLEARCOAT_ROUGHNESS = 0.05;
}

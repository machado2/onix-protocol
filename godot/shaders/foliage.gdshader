// Folhagem em cartões: alfa recortado, dupla face, luz atravessando as folhas e balanço de vento.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D tex_a : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_n : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color = vec3(1.0);
uniform float wind = 0.08;

varying vec4 icol;

void vertex() {
	icol = COLOR;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y - 2.0, 0.0);
	float t = TIME * 1.3 + wp.x * 0.15 + wp.z * 0.11;
	VERTEX.x += sin(t) * wind * h * 0.15;
	VERTEX.z += cos(t * 0.8) * wind * h * 0.12;
	VERTEX.y += sin(t * 2.3 + wp.x) * wind * 0.05 * h;
}

void fragment() {
	vec4 a = texture(tex_a, UV);
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = a.rgb * tint * mix(vec3(1.0), icol.rgb, 0.5);
	NORMAL_MAP = texture(tex_n, UV).rgb;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
	BACKLIGHT = vec3(0.35, 0.45, 0.2);
	AO = 0.8;
}

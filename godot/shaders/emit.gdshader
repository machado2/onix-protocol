// Emissão simples (faróis, lâmpadas, semáforos). power > 1 dispara o brilho (glow).
shader_type spatial;
render_mode cull_back;
uniform vec3 color : source_color = vec3(1.0);
uniform float power = 4.0;
uniform float flicker = 0.0;
void fragment() {
	float f = 1.0;
	if (flicker > 0.0) f = 0.6 + 0.4 * step(0.5, fract(TIME * flicker));
	ALBEDO = color * 0.2;
	EMISSION = color * power * f;
	ROUGHNESS = 0.2;
}

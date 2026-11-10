// Roupas, pele e equipamento dos personagens. Cada material escolhe uma "camada" (slot) e a cor vem
// por instância (instance uniform), então um mesmo modelo veste agentes, guardas, policiais e civis.
shader_type spatial;
render_mode cull_back;

uniform int slot = 0;          // 0 pele, 1 parte de cima, 2 parte de baixo, 3 calçado, 4 casaco, 5 cabelo, 6 detalhe, 7 metal escuro
uniform float rough = 0.8;
uniform float sheen = 0.0;
uniform float metal = 0.0;
uniform sampler2D grime : hint_default_black, filter_linear_mipmap, repeat_enable;
instance uniform vec3 c_skin : source_color = vec3(0.62, 0.45, 0.35);
instance uniform vec3 c_top : source_color = vec3(0.2);
instance uniform vec3 c_bottom : source_color = vec3(0.12);
instance uniform vec3 c_shoes : source_color = vec3(0.05);
instance uniform vec3 c_coat : source_color = vec3(0.08);
instance uniform vec3 c_hair : source_color = vec3(0.05);
instance uniform vec3 c_accent : source_color = vec3(0.2, 0.9, 1.0);

varying vec3 lp;

void vertex() { lp = VERTEX; }

void fragment() {
	vec3 c = c_skin;
	if (slot == 1) c = c_top;
	else if (slot == 2) c = c_bottom;
	else if (slot == 3) c = c_shoes;
	else if (slot == 4) c = c_coat;
	else if (slot == 5) c = c_hair;
	else if (slot == 6) c = c_accent;
	else if (slot == 7) c = vec3(0.04, 0.042, 0.045);
	float n = texture(grime, lp.xy * 3.1 + lp.zx * 2.3).r;
	float weave = texture(grime, lp.xz * 23.0 + lp.y * 11.0).r;
	ALBEDO = c * (0.85 + 0.3 * n) * (slot >= 1 && slot <= 4 ? 0.92 + 0.16 * weave : 1.0);
	ROUGHNESS = clamp(rough + (n - 0.5) * 0.15, 0.05, 1.0);
	METALLIC = metal;
	if (slot == 0) {
		SSS_STRENGTH = 0.4;
		ROUGHNESS = 0.55;
	}
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * fres * sheen;
}

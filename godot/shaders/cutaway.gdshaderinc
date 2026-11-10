// Recorte dos prédios entre a câmera e o esquadrão: descarta, com dither, o que está dentro de um cone
// da câmera até o foco e acima da altura da cabeça. Os valores vêm de uniforms globais (Game._update_camera).
global uniform vec3 cut_cam;
global uniform vec3 cut_pos;
global uniform float cut_r;

bool cut_away(vec3 p, vec2 frag) {
	vec3 ab = cut_pos - cut_cam;
	float L2 = dot(ab, ab);
	if (cut_r <= 0.0 || L2 < 1.0) return false;
	float t = dot(p - cut_cam, ab) / L2;
	if (t <= 0.0 || t >= 0.985 || p.y < cut_pos.y + 0.8) return false;
	float d = length(p - (cut_cam + ab * t));
	float r = cut_r * clamp(t * 1.25, 0.0, 1.0);
	float n = fract(sin(dot(floor(frag), vec2(12.9898, 78.233))) * 43758.5453);
	return d < r - n * 2.0;
}

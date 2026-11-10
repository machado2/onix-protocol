## Pintura do chão das missões feitas à mão (porte de M.paint da web): marcas de pátio, faixas de segurança,
## heliporto, pisos. Desenha numa imagem do mapa inteiro (TS pixels por tile) que vira um decal sobre o chão.
class_name MPaint
extends RefCounted

const TS := 32
const N := C.N
var img: Image
var rng := RandomNumberGenerator.new()
var M: Mission


func _init(m: Mission) -> void:
	M = m
	img = Image.create(N * TS, N * TS, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	rng.seed = 4711


static func col(s) -> Color:
	return s if s is Color else Color.from_string(s, Color.WHITE)


## Retângulo cheio em pixels (as receitas da web usam tile * TS + pixels).
func fill(x: float, y: float, w: float, h: float, c) -> void:
	var r := Rect2i(int(x), int(y), maxi(1, int(round(w))), maxi(1, int(round(h)))).intersection(Rect2i(0, 0, N * TS, N * TS))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, col(c))


func stroke_rect(x: float, y: float, w: float, h: float, c, lw := 3.0) -> void:
	fill(x, y, w, lw, c)
	fill(x, y + h - lw, w, lw, c)
	fill(x, y, lw, h, c)
	fill(x + w - lw, y, lw, h, c)


func line(x0: float, y0: float, x1: float, y1: float, c, lw := 3.0) -> void:
	var n := int(Vector2(x1 - x0, y1 - y0).length() / (lw * .5)) + 1
	for k in n + 1:
		var f := float(k) / n
		fill(lerpf(x0, x1, f) - lw / 2, lerpf(y0, y1, f) - lw / 2, lw, lw, c)


func ring(cx: float, cy: float, r: float, c, lw := 3.0) -> void:
	var n := int(TAU * r / (lw * .5)) + 8
	for k in n:
		var a := TAU * k / n
		fill(cx + cos(a) * r - lw / 2, cy + sin(a) * r - lw / 2, lw, lw, c)


func ellipse(cx: float, cy: float, rx: float, ry: float, c) -> void:
	for dy in range(-int(ry), int(ry) + 1):
		var k := 1.0 - (dy * dy) / (ry * ry)
		if k <= 0:
			continue
		var hw := rx * sqrt(k)
		fill(cx - hw, cy + dy, hw * 2, 1, c)


## Símbolo "H" de pouso centrado em (X, Y) com unidade u (em pixels).
func helipad_h(X: float, Y: float, u: float, c) -> void:
	fill(X - 2 * u, Y - 2 * u, u * .8, 4 * u, c)
	fill(X + 1.2 * u, Y - 2 * u, u * .8, 4 * u, c)
	fill(X - 2 * u, Y - u * .4, 4 * u, u * .8, c)


## Decal do tamanho do mapa; não pinta personagens nem carros (camada 2) e some nas paredes.
func make_decal() -> Decal:
	img.generate_mipmaps()
	var d := Decal.new()
	d.texture_albedo = ImageTexture.create_from_image(img)
	var W := N * C.TILE
	d.size = Vector3(W, 3.0, W)
	d.position = Vector3(W / 2.0, .4, W / 2.0)
	d.cull_mask = 1
	d.normal_fade = .35
	d.upper_fade = .05
	d.lower_fade = .05
	return d

## Monta a cidade em 3D a partir do mapa gerado (CityGen): chão com meio-fio e faixas,
## prédios com peças modulares instanciadas (MultiMesh por bloco), letreiros, postes e luzes.
class_name CityBuilder
extends Node3D

const T := C.T
const W := C.TILE
const FH := C.FLOOR_H

var M: Dictionary
var kit := {}          # nome da peça -> Mesh original
var styled := {}       # "peça|estilo" -> Mesh com materiais trocados
var mat := {}          # materiais compartilhados
var groups := {}       # "peça|estilo|bloco" -> {xf: [], col: []}
var shop_lights := []  # [posição, cor, loja aberta]
var facade := []       # [peça, Transform3D, bloco] das janelas, para pendurar ar-condicionado e varais
var roofs := []        # [prédio, estilo, retângulo em metros, altura]
var focus := Vector3(84, 0, 96)   # centro da câmera: postes perto dele projetam sombra
var tex_cache := {}

const PLASTER := [Color("#d8d0c0"), Color("#c9b48a"), Color("#b98a6a"), Color("#8fa39a"), Color("#c7a08c"), Color("#a9a49a"), Color("#d6c6a0"), Color("#9aa6b4")]
const SHOP_HUES := [Color("#ff3d8b"), Color("#38e8ff"), Color("#ffb13d"), Color("#a66bff"), Color("#5cff8a"), Color("#ff5a3d"), Color("#fff0c0")]


func _tex(n: String) -> Texture2D:
	if not tex_cache.has(n):
		tex_cache[n] = load("res://assets/tex/%s.png" % n)
	return tex_cache[n]


func surf(tex: String, m_per: float, tint := Color.WHITE, opts := {}) -> ShaderMaterial:
	var s := ShaderMaterial.new()
	s.shader = preload("res://shaders/surface.gdshader")
	s.set_shader_parameter("tex_a", _tex(tex + "_a"))
	s.set_shader_parameter("tex_n", _tex(tex + "_n"))
	s.set_shader_parameter("tex_orm", _tex(tex + "_orm"))
	s.set_shader_parameter("grime", _tex("grime"))
	s.set_shader_parameter("tex_m", m_per)
	s.set_shader_parameter("tint", tint)
	for k in opts:
		s.set_shader_parameter(k, opts[k])
	return s


func win(room: Vector2, depth: float, opts := {}) -> ShaderMaterial:
	var s := ShaderMaterial.new()
	s.shader = preload("res://shaders/window.gdshader")
	s.set_shader_parameter("room", room)
	s.set_shader_parameter("depth", depth)
	s.set_shader_parameter("grime", _tex("grime"))
	for k in opts:
		s.set_shader_parameter(k, opts[k])
	return s


func _make_materials() -> void:
	mat.trim = surf("concrete", 4.0, Color(.92, .92, .92), {grime_amt = .7})
	mat.concrete = surf("concrete", 4.0, Color(.85, .85, .85), {grime_amt = .8})
	mat.frame = surf("metal", 1.5, Color(.07, .075, .08), {metal = .7, rough_mul = .6, grime_amt = 0.0})
	mat.frame_rust = surf("metal", 1.5, Color(.28, .2, .15), {metal = .3, grime_amt = .3})
	mat.rail = surf("metal", 1.5, Color(.05, .05, .055), {metal = .8, rough_mul = .7, grime_amt = 0.0})
	mat.metal = surf("galvanized", 2.0, Color(.85, .85, .85), {grime_amt = .2})
	mat.shutter = surf("galvanized", 2.0, Color(.75, .75, .75), {ribs = .09, grime_amt = .6})
	mat.awning = surf("plaster", 3.0, Color(.55, .12, .1), {grime_amt = .3, rough_mul = 1.0})
	mat.fin = surf("metal", 1.5, Color(.5, .52, .56), {metal = .9, rough_mul = .35, grime_amt = 0.0})
	mat.panel = surf("metal", 1.5, Color(.28, .3, .34), {metal = .5, rough_mul = .5, grime_amt = .15})
	mat.spandrel = surf("metal", 1.5, Color(.03, .035, .04), {metal = .8, rough_mul = .3, grime_amt = 0.0})
	mat.brick = surf("brick", 2.4, Color.WHITE, {grime_amt = .8})
	mat.plaster = surf("plaster", 3.0, Color.WHITE, {use_instance_tint = 1.0, grime_amt = .9})
	mat.roof = surf("roof", 4.0, Color.WHITE, {grime_amt = 0.0, wet = .6})
	var lb := ShaderMaterial.new()
	lb.shader = preload("res://shaders/lightbox.gdshader")
	mat.sign = lb
	mat.asphalt = surf("asphalt", 4.0, Color.WHITE, {wet = 1.0, grime_amt = 0.0})
	mat.pavers = surf("pavers", 3.0, Color.WHITE, {wet = .8, grime_amt = 0.0})
	mat.granite = surf("granite", 4.0, Color.WHITE, {wet = .5, grime_amt = 0.0})
	mat.soil = surf("soil", 4.0, Color.WHITE, {wet = .3, grime_amt = 0.0})
	mat.curb = surf("concrete", 2.0, Color(.75, .75, .72), {grime_amt = .0, wet = .6})
	mat.paint_w = surf("asphalt", 4.0, Color(1, 1, 1), {tint_k = 11.0, wet = 1.0, grime_amt = 0.0, rough_add = -.1})
	mat.paint_y = surf("asphalt", 4.0, Color(1, .72, .1), {tint_k = 11.0, wet = 1.0, grime_amt = 0.0, rough_add = -.1})
	mat.spandrel_glass = win(Vector2(3, .9), 1.0, {tint_dark = 1.0, lit_bias = -2.0})


# ---------------------------------------------------------------- peças
func _load_kit() -> void:
	for f in ["arch", "props", "cars", "trees"]:
		var scene: Node = load("res://assets/kit/%s.glb" % f).instantiate()
		for c in scene.find_children("*", "MeshInstance3D", true, false):
			kit[c.name] = c.mesh
		scene.free()


func std(col: Color, rough := .5, metal_ := 0.0, opts := {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal_
	for k in opts:
		m.set(k, opts[k])
	return m


func emit(col: Color, power := 4.0, flicker := 0.0) -> ShaderMaterial:
	var s := ShaderMaterial.new()
	s.shader = preload("res://shaders/emit.gdshader")
	s.set_shader_parameter("color", col)
	s.set_shader_parameter("power", power)
	s.set_shader_parameter("flicker", flicker)
	return s


func _prop_materials() -> void:
	mat.metal_dark = surf("metal", 1.0, Color(.07, .075, .08), {metal = .6, rough_mul = .7, grime_amt = 0.0})
	mat.lamp_light = emit(Color(1, .85, .65), 4.0)
	mat.ceramic = std(Color("#7a5a44"), .25)
	mat.cable = std(Color("#060606"), .6)
	mat.transformer = surf("metal", 1.0, Color(.42, .44, .45), {metal = .5, grime_amt = .3})
	mat.tl_red = emit(Color(1, .08, .04), 6.0)
	mat.tl_amber = emit(Color(1, .55, .05), .25)
	mat.tl_green = emit(Color(.1, 1, .45), .3)
	mat.tl_off = std(Color("#0a0a0a"), .4)
	mat.wood = surf("wood", 1.0, Color.WHITE, {grime_amt = .2})
	mat.reflector = emit(Color(1, .8, .2), .6)
	mat.bin = std(Color("#c8561a"), .45)
	mat.hydrant = surf("metal", 1.0, Color(.65, .07, .04), {metal = .2, rough_mul = .8, grime_amt = .3})
	mat.ac = surf("metal", 1.0, Color(.78, .77, .73), {metal = -1.0, rough_mul = 1.2, grime_amt = .5})
	mat.grill = std(Color("#151515"), .5, .6)
	mat.tank = std(Color("#2c4e86"), .5)
	mat.pipe = std(Color("#d6d6cc"), .5)
	mat.door = surf("metal", 1.0, Color(.16, .24, .2), {metal = .3, grime_amt = .5})
	mat.beacon = emit(Color(1, .1, .05), 6.0, .7)
	mat.dish = std(Color("#cfcfcf"), .45, .25)
	mat.vend_body = surf("metal", 1.0, Color(.55, .05, .06), {metal = .3, grime_amt = .3})
	mat.vend_glass = emit(Color(1, .92, .85), 2.2)
	mat.kiosk = surf("metal", 1.5, Color(.1, .28, .16), {metal = .35, grime_amt = .6})
	mat.paint_stripe = std(Color("#d8a020"), .55)
	mat.barrel = surf("metal", 1.0, Color.WHITE, {use_instance_tint = 1.0, metal = .2, grime_amt = .7})
	mat.cardboard = surf("plaster", 1.0, Color(.5, .36, .22), {grime_amt = .3})
	mat.bag = std(Color("#09090a"), .22)
	mat.dumpster = surf("metal", 1.5, Color(.8, .52, .08), {metal = .25, grime_amt = 1.0})
	mat.rubble = surf("concrete", 1.0, Color(.7, .68, .64), {grime_amt = .0})
	mat.cloth_a = std(Color("#b02a30"), .9)
	mat.cloth_b = std(Color("#e8e2d0"), .9)
	mat.cloth_c = std(Color("#2a5aa0"), .9)
	var cp := ShaderMaterial.new()
	cp.shader = preload("res://shaders/car_paint.gdshader")
	cp.set_shader_parameter("grime", _tex("grime"))
	mat.paint = cp
	mat.car_glass = std(Color("#050608"), .04, .3)
	mat.headlight = emit(Color(1, .95, .85), 7.0)
	mat.taillight = emit(Color(1, .05, .03), 3.5)
	mat.grille = std(Color("#0b0b0c"), .35, .5)
	mat.trim_dark = std(Color("#0f0f11"), .6)
	mat.tire = std(Color("#0c0c0c"), .85)
	mat.rim = std(Color("#9a9a9e"), .3, .9)
	mat.liner = std(Color("#040404"), .9, 0.0, {cull_mode = BaseMaterial3D.CULL_DISABLED})
	mat.plate = std(Color("#e6e6dc"), .5)
	mat.taxi_sign = emit(Color(1, .82, .35), 3.0)
	mat.police_red = emit(Color(1, .05, .05), 8.0, 2.3)
	mat.police_blue = emit(Color(.1, .3, 1), 8.0, 1.7)
	mat.bark = surf("bark", 1.5, Color.WHITE, {grime_amt = 0.0})
	var lf := ShaderMaterial.new()
	lf.shader = preload("res://shaders/foliage.gdshader")
	lf.set_shader_parameter("tex_a", _tex("leaf_a"))
	lf.set_shader_parameter("tex_n", _tex("leaf_n"))
	mat.leaf = lf


const ROOMS := {A_win = [Vector2(1.6, 1.6), 3.5], A_balc = [Vector2(1.9, 2.38), 4.0], A_vent = [Vector2(.8, .6), 2.0],
	B_win = [Vector2(3, 2.3), 5.0], C_win = [Vector2(1.0, .95), 3.0], G_shop = [Vector2(2.74, 2.48), 5.0], G_lobby = [Vector2(3, 3.1), 8.0]}


func styled_mesh(piece: String, style: String) -> Mesh:
	var key := piece + "|" + style
	if styled.has(key):
		return styled[key]
	var src: ArrayMesh = kit[piece]
	var m: ArrayMesh = src.duplicate()
	for i in m.get_surface_count():
		var nm := src.surface_get_material(i).resource_name if src.surface_get_material(i) else ""
		var sm: Material
		match nm:
			"wall":
				sm = mat.plaster if style == "plaster" else mat.concrete
			"glass" when style == "car":
				sm = mat.car_glass
			"glass", "glass_frost", "shopglass":
				var rd: Array = ROOMS.get(piece, [Vector2(1.5, 1.5), 3.0])
				var o := {}
				if nm == "glass_frost":
					o.frost = 1.0
				if nm == "shopglass":
					o.shop = 1.0
				if piece == "B_win":
					o.tint_dark = .55
				sm = win(rd[0], rd[1], o)
			_:
				sm = mat.get(nm, mat.trim)
		m.surface_set_material(i, sm)
	styled[key] = m
	return m


func put(piece: String, style: String, xf: Transform3D, col: Color, chunk: String) -> void:
	var key := piece + "|" + style + "|" + chunk
	if not groups.has(key):
		groups[key] = {piece = piece, style = style, xf = [], col = []}
	groups[key].xf.append(xf)
	groups[key].col.append(col)


func _flush() -> void:
	for key in groups:
		var g: Dictionary = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = styled_mesh(g.piece, g.style)
		mm.instance_count = g.xf.size()
		for i in g.xf.size():
			mm.set_instance_transform(i, g.xf[i])
			mm.set_instance_color(i, g.col[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.name = key.replace("|", "_")
		add_child(mi)
	groups.clear()


# ---------------------------------------------------------------- mapa
func tile_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= C.N or y >= C.N:
		return T.ROAD
	return M.tile[y * C.N + x]


func hgt_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= C.N or y >= C.N:
		return 0
	return M.hgt[y * C.N + x]


func build(map: Dictionary) -> void:
	M = map
	_load_kit()
	_make_materials()
	_prop_materials()
	_build_ground()
	_build_markings()
	_build_buildings()
	_flush()
	_build_shop_lights()
	CityDress.dress(self)
	_flush()


# ---------------------------------------------------------------- chão
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.add_vertex(v)


func _box(st: SurfaceTool, lo: Vector3, hi: Vector3) -> void:
	var x0 := lo.x; var y0 := lo.y; var z0 := lo.z; var x1 := hi.x; var y1 := hi.y; var z1 := hi.z
	_quad(st, Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.UP)
	_quad(st, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.BACK)
	_quad(st, Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3.FORWARD)
	_quad(st, Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3.RIGHT)
	_quad(st, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3.LEFT)


func _mesh_node(st: SurfaceTool, m: Material, nm: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.name = nm
	add_child(mi)
	return mi


func _build_ground() -> void:
	var sts := {}
	for k in ["asphalt", "pavers", "granite", "soil", "curb"]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts[k] = st
	var h := C.CURB
	for y in C.N:
		for x in C.N:
			var t := tile_at(x, y)
			var x0 := x * W; var z0 := y * W; var x1 := x0 + W; var z1 := z0 + W
			if t == T.ROAD:
				_quad(sts.asphalt, Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector3.UP)
				continue
			var k := "pavers"
			if t == T.PLAZA:
				k = "granite"
			elif t == T.GRASS or t == T.TREE:
				k = "soil"
			_quad(sts[k], Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, h, z1), Vector3.UP)
			# meio-fio de concreto voltado para a rua
			var cw := .16
			if tile_at(x, y + 1) == T.ROAD: _box(sts.curb, Vector3(x0, 0, z1 - cw), Vector3(x1, h + .015, z1))
			if tile_at(x, y - 1) == T.ROAD: _box(sts.curb, Vector3(x0, 0, z0), Vector3(x1, h + .015, z0 + cw))
			if tile_at(x + 1, y) == T.ROAD: _box(sts.curb, Vector3(x1 - cw, 0, z0), Vector3(x1, h + .015, z1))
			if tile_at(x - 1, y) == T.ROAD: _box(sts.curb, Vector3(x0, 0, z0), Vector3(x0 + cw, h + .015, z1))
			# borda de canteiro
			if k == "soil":
				for d in [[0, 1], [0, -1], [1, 0], [-1, 0]]:
					var nt := tile_at(x + d[0], y + d[1])
					if nt != T.GRASS and nt != T.TREE and nt != T.ROAD:
						var a := Vector3(x0 + W * .5 + d[0] * (W * .5 - .06), 0, z0 + W * .5 + d[1] * (W * .5 - .06))
						var e := Vector3(.06 if d[0] != 0 else W * .5, 0, .06 if d[1] != 0 else W * .5)
						_box(sts.curb, a - e, a + e + Vector3(0, h + .06, 0))
	_mesh_node(sts.asphalt, mat.asphalt, "asfalto")
	_mesh_node(sts.pavers, mat.pavers, "calcada")
	_mesh_node(sts.granite, mat.granite, "praca")
	_mesh_node(sts.soil, mat.soil, "canteiro")
	_mesh_node(sts.curb, mat.curb, "meiofio")


func _build_markings() -> void:
	var sw := SurfaceTool.new(); sw.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sy := SurfaceTool.new(); sy.begin(Mesh.PRIMITIVE_TRIANGLES)
	var e := .012
	var rect := func(st: SurfaceTool, x0: float, z0: float, x1: float, z1: float) -> void:
		_quad(st, Vector3(x0, e, z0), Vector3(x1, e, z0), Vector3(x1, e, z1), Vector3(x0, e, z1), Vector3.UP)
	var n := C.N
	for k in C.NB + 1:
		var c := (k * C.P + 1) * W   # centro do corredor de rua
		for i in n:
			if i % C.P < 2:
				continue
			var a := i * W
			# faixa dupla amarela contínua no centro, nos dois sentidos
			rect.call(sy, c - .2, a, c - .08, a + W)
			rect.call(sy, c + .08, a, c + .2, a + W)
			rect.call(sy, a, c - .2, a + W, c - .08)
			rect.call(sy, a, c + .08, a + W, c + .2)
			# faixa de bordo branca
			for s in [-1, 1]:
				var b: float = c + s * (W - .45)
				rect.call(sw, b - .06, a, b + .06, a + W)
				rect.call(sw, a, b - .06, a + W, b + .06)
		# faixas de pedestre nas saídas dos cruzamentos
		for j in C.NB + 1:
			var ci := (j * C.P + 1) * W
			for s in [-1, 1]:
				var z0: float = ci + s * (W + .6)
				var z1: float = z0 + s * 2.6
				for q in 8:
					var xx := c - W + .25 + q * .72
					if xx + .4 > c + W:
						break
					if tile_at(int(z0 / W), int(xx / W)) == T.ROAD:
						rect.call(sw, minf(z0, z1), xx, maxf(z0, z1), xx + .4)
					if tile_at(int(xx / W), int(z0 / W)) == T.ROAD:
						rect.call(sw, xx, minf(z0, z1), xx + .4, maxf(z0, z1))
	_mesh_node(sw, mat.paint_w, "faixas_brancas")
	_mesh_node(sy, mat.paint_y, "faixas_amarelas")


# ---------------------------------------------------------------- prédios
func _style(b: Dictionary) -> String:
	if b.get("corp", false):
		return "B"
	var h := C.hash01(b.x, b.y, 3.0)
	if b.fl >= 7 and h < .35:
		return "B"
	if b.pal == 3 or (b.fl <= 4 and h > .78):
		return "C"
	return "A"


func _build_buildings() -> void:
	for b in M.blds:
		if b.get("kiosk", false):
			continue
		_building(b)


func _building(b: Dictionary) -> void:
	var st := _style(b)
	var wall_style := "plaster" if (st == "A" and b.pal != 2) else "concrete"
	var tint: Color = PLASTER[int(b.seed * 997) % PLASTER.size()]
	var lit := (.25 if st != "B" else .5) + C.hash01(b.x, b.y, 9.0) * .4
	var col := Color(tint.r, tint.g, tint.b, lit)
	var chunk := "%d_%d" % [b.x / (C.P * 2), b.y / (C.P * 2)]
	var x0: float = b.x * W
	var z0: float = b.y * W
	var x1: float = (b.x + b.w) * W
	var z1: float = (b.y + b.d) * W
	var fl: int = b.fl
	var faces := [
		{basis = Basis(), len = b.w, o = func(i): return Vector3(x0 + i * W, 0, z1), out = func(i): return Vector2i(b.x + i, b.y + b.d)},
		{basis = Basis(Vector3.UP, PI), len = b.w, o = func(i): return Vector3(x1 - i * W, 0, z0), out = func(i): return Vector2i(b.x + b.w - 1 - i, b.y - 1)},
		{basis = Basis(Vector3.UP, PI / 2), len = b.d, o = func(i): return Vector3(x1, 0, z1 - i * W), out = func(i): return Vector2i(b.x + b.w, b.y + b.d - 1 - i)},
		{basis = Basis(Vector3.UP, -PI / 2), len = b.d, o = func(i): return Vector3(x0, 0, z0 + i * W), out = func(i): return Vector2i(b.x - 1, b.y + i)},
	]
	var fi := 0
	for F in faces:
		fi += 1
		for i in F.len:
			var ot: Vector2i = F.out.call(i)
			var nt := tile_at(ot.x, ot.y)
			var nh := hgt_at(ot.x, ot.y) if nt == T.BLD else 0
			var street := nt != T.BLD
			var hc := C.hash01(b.x * 7 + fi, b.y * 3 + i, 1.0)   # tipo da coluna de vãos
			for f in fl:
				if f < nh:
					continue
				var p := _pick_piece(st, f, fl, hc, C.hash01(b.x + i, f, fi), street, i, F.len)
				var o: Vector3 = F.o.call(i)
				var xf := Transform3D(F.basis, o + Vector3(0, f * FH, 0))
				var c := col
				if p == "G_shop" or p == "G_shut":
					var hue: Color = SHOP_HUES[int(C.hash01(o.x, o.z, 5.0) * SHOP_HUES.size())]
					c = Color(hue.r, hue.g, hue.b, 1.0 if C.hash01(o.x, o.z, 6.0) < .8 else 0.0)
					if p == "G_shop" or c.a > .5:
						var outv: Vector3 = F.basis * Vector3(0, 0, 1)
						var along: Vector3 = F.basis * Vector3(1, 0, 0)
						shop_lights.append([o + along * 1.5 + outv * 1.1 + Vector3(0, 2.6, 0), hue, p == "G_shop"])
						if c.a > .5:
							_shop_label(xf, hue)
				put(p, wall_style if p.begins_with("A_") else st, xf, c, chunk)
				if p == "A_win" or p == "C_win":
					facade.append([p, xf, chunk])
			# platibanda
			if fl > nh:
				var o2: Vector3 = F.o.call(i)
				var top := Vector3(0, fl * FH, 0)
				if st != "C":
					put(st + "_ledge", st, Transform3D(F.basis, o2 + top - Vector3(0, .3, 0)), col, chunk)
				put(st + "_parapet", wall_style if st == "A" else st, Transform3D(F.basis, o2 + top), col, chunk)
	# quinas
	for cxz in [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x0, 0, z1), Vector3(x1, 0, z1)]:
		for f in fl:
			put(st + "_corner", st, Transform3D(Basis(), cxz + Vector3(0, f * FH, 0)), col, chunk)
	# laje de cobertura
	var roof := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(x1 - x0 - .1, .3, z1 - z0 - .1)
	roof.mesh = bm
	roof.material_override = mat.roof
	roofs.append([b, st, Rect2(x0, z0, x1 - x0, z1 - z0), fl * FH + .05])
	roof.position = Vector3((x0 + x1) / 2, fl * FH - .1, (z0 + z1) / 2)
	add_child(roof)
	if b.sign != "":
		_vertical_sign(b, x0, z0, x1, z1)


func _pick_piece(st: String, f: int, fl: int, hc: float, hr: float, street: bool, i: int, n: int) -> String:
	match st:
		"A":
			if f == 0:
				if not street:
					return "A_wall"
				return "G_shop" if hr < .7 else "G_shut"
			if hc < .12:
				return "A_wall"
			if hc < .24:
				return "A_vent"
			if hc < .42 and f < fl - 1 and hr < .85:
				return "A_balc"
			return "A_win" if hr > .05 else "A_wall"
		"B":
			if f == 0:
				return "G_lobby" if street else "B_wall"
			if (i == 0 or i == n - 1) and n > 3 and hc < .5:
				return "B_wall"
			return "B_win"
		_:
			if f == 0 and street:
				return "C_door" if hr < .45 else ("G_shut" if hr < .7 else "C_win")
			return "C_win" if hr < .62 else "C_wall"


func _shop_label(xf: Transform3D, hue: Color) -> void:
	var lb := Label3D.new()
	var names := C.SIGNS
	lb.text = names[int(C.hash01(xf.origin.x, xf.origin.z, 7.0) * names.size())]
	lb.font_size = 64
	lb.pixel_size = .006
	lb.modulate = Color(.02, .02, .03) if C.hash01(xf.origin.x, xf.origin.z, 8.0) < .5 else Color(hue.r * 5, hue.g * 5, hue.b * 5)
	lb.outline_size = 0
	lb.shaded = false
	lb.double_sided = false
	lb.fixed_size = false
	lb.no_depth_test = false
	lb.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	lb.transform = xf * Transform3D(Basis(), Vector3(1.53, 2.89, .335))
	add_child(lb)


func _vertical_sign(b: Dictionary, x0: float, z0: float, x1: float, z1: float) -> void:
	# letreiro vertical numa quina voltada para a rua
	var s: String = b.sign
	var col: Color = b.sign_col
	var pos := Vector3(x1 + .9, 0, z1 - .4)
	var basis := Basis(Vector3.UP, PI / 2)
	var h := minf(s.length() * 1.15 + .8, b.fl * FH - 4.0)
	if h < 3.0:
		return
	var y0: float = b.fl * FH - h - 1.0
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(.25, h, 1.25)
	box.mesh = bm
	box.material_override = mat.frame
	box.position = pos + Vector3(-.5, y0 + h / 2, 0)
	add_child(box)
	for side in [-1, 1]:
		var lb := Label3D.new()
		lb.text = "\n".join(s.split(""))
		lb.font_size = 96
		lb.pixel_size = .0105
		lb.line_spacing = -18
		lb.modulate = Color(col.r * 6, col.g * 6, col.b * 6)
		lb.outline_size = 0
		lb.shaded = false
		lb.double_sided = false
		lb.position = pos + Vector3(-.5 + side * .14, y0 + h / 2, 0)
		lb.rotation.y = PI / 2 if side > 0 else -PI / 2
		lb.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		add_child(lb)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 3.0
	l.omni_range = 9.0
	l.position = pos + Vector3(.8, y0 + h / 2, 0)
	add_child(l)


# ---------------------------------------------------------------- luzes
func _build_shop_lights() -> void:
	for s in shop_lights:
		var l := OmniLight3D.new()
		l.position = s[0]
		l.light_color = s[1].lerp(Color(1, .9, .8), .4) if s[2] else s[1]
		l.light_energy = 1.6
		l.omni_range = 6.0
		l.omni_attenuation = 1.4
		add_child(l)

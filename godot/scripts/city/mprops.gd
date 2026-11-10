## Objetos 3D das missões feitas à mão: água e cais, cercas, paredes de vidro, contêineres, galpões, muros, sebes,
## guindastes, barco, helicóptero, dirigível, reatores, chaminés, tubulação, fonte, pista de dança, outdoors, gerador,
## teleférico, porta blindada, varais, câmeras de segurança, feixes de alarme, vapor, monotrilho, terminais,
## drones e carros com rota. Também reage aos eventos da simulação (vidro quebrado, poste apagado, portão arrombado).
class_name MissionProps
extends Node3D

const W := C.TILE
const T := C.T
const HU := 1.6          # metros por unidade de altura do JS (pessoa de 1,12 unidade = 1,8 m)

var game
var city: CityBuilder
var M: Mission
var glass_nodes := {}
var cam_nodes: Array = []
var laser_nodes: Array = []
var vent_nodes: Array = []
var term_nodes: Array = []
var car_nodes: Array = []
var train_node: Node3D
var hanging: Node3D
var falling_nodes: Array = []
var anims: Array = []      # [nó, tipo, dados]
var mats := {}


func _m(k: String) -> Material:
	return city.mat.get(k, city.mat.trim)


func _std(c: Color, rough := .5, metal := 0.0) -> StandardMaterial3D:
	return city.std(c, rough, metal)


func _box(size: Vector3, pos: Vector3, m: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = m
	parent.add_child(mi)
	return mi


func _cyl(r0: float, r1: float, h: float, pos: Vector3, m: Material, parent: Node = self, seg := 20) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r1
	cm.bottom_radius = r0
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.position = pos
	mi.material_override = m
	parent.add_child(mi)
	return mi


func _beam(a: Vector3, b: Vector3, th: float, m: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(th, th, 1)
	mi.mesh = bm
	mi.material_override = m
	var L := a.distance_to(b)
	mi.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP if absf((b - a).normalized().y) < .99 else Vector3.RIGHT).scaled(Vector3(1, 1, L)), (a + b) / 2)
	parent.add_child(mi)
	return mi


func _label(text: String, size: int, col: Color, pos: Vector3, rot_y := 0.0, k := 5.0, parent: Node = self) -> Label3D:
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = size
	lb.pixel_size = .01
	lb.modulate = Color(col.r * k, col.g * k, col.b * k)
	lb.shaded = false
	lb.double_sided = false
	lb.outline_size = 0
	lb.position = pos
	lb.rotation.y = rot_y
	parent.add_child(lb)
	return lb


func wp(x: float, y: float, h := 0.0) -> Vector3:
	return Vector3(x * W, h, y * W)


func setup(g) -> void:
	game = g
	city = g.city
	M = g.M
	mats.water = _water_mat()
	mats.fence = _fence_mat()
	mats.glass = _std(Color(.55, .75, .85, .22), .05, .3)
	mats.glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats.hedge = city.surf("soil", 2.0, Color(.55, .9, .5), {grime_amt = 0.0})
	mats.cont = [Color("#8a2e22"), Color("#1f4e7a"), Color("#6b6f78"), Color("#2f6b3e"), Color("#b8681e"), Color("#7a2a52")]
	mats.red = city.emit(Color(1, .1, .08), 6.0)
	mats.green = city.emit(Color(.2, 1, .5), 4.0)
	var hand: bool = city.M.get("hand", false)
	if not hand:
		_terminals()
		return
	if _has_tile(T.WATER):
		var pl := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1200, 1200)
		pl.mesh = pm
		pl.position = Vector3(C.N * W / 2, -.55, C.N * W / 2)
		pl.material_override = mats.water
		add_child(pl)
	for p in city.M.get("piers", []):
		_pier(p)
	_tiles()
	for b in city.M.blds:
		match b.get("style", ""):
			"cont": _containers(b)
			"ware": _warehouse(b)
			"wall": _wall(b)
			"hedge": _hedge(b)
	for d in city.M.get("decor", []):
		_decor(d)
	_terminals()
	for c in M.cams:
		_cam(c)
	for l in M.lasers:
		var mi := _box(Vector3(.035, .035, 1), Vector3(), city.emit(Color(1, .1, .15), 8.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		laser_nodes.append([mi, l])
	for v in M.vents:
		_vent(v)
	if M.rail != null:
		_monorail()


func _has_tile(t: int) -> bool:
	for i in C.N * C.N:
		if M.tile[i] == t:
			return true
	return false


func _water_mat() -> ShaderMaterial:
	var s := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grime : filter_linear_mipmap, repeat_enable;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wp.xz * 0.03;
	float a = texture(grime, uv + vec2(TIME * 0.01, TIME * 0.006)).b;
	float b = texture(grime, uv * 2.3 - vec2(TIME * 0.013, -TIME * 0.009)).b;
	vec3 n = normalize(vec3((a - 0.5) * 0.6 + (b - 0.5) * 0.4, 1.0, (b - 0.5) * 0.6 - (a - 0.5) * 0.3));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = vec3(0.01, 0.025, 0.03);
	ROUGHNESS = 0.06;
	METALLIC = 0.1;
	SPECULAR = 0.7;
}
"""
	s.shader = sh
	s.set_shader_parameter("grime", load("res://assets/tex/grime.png"))
	return s


func _fence_mat() -> ShaderMaterial:
	var s := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 q = vec2(wp.x + wp.z, wp.y) * 9.0;
	vec2 d = abs(fract(vec2(q.x + q.y, q.x - q.y) * 0.5) - 0.5);
	float wire = 1.0 - smoothstep(0.03, 0.08, min(d.x, d.y));
	ALPHA = wire;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = vec3(0.45, 0.48, 0.5);
	METALLIC = 0.8;
	ROUGHNESS = 0.4;
}
"""
	s.shader = sh
	return s


# ---------------------------------------------------------------- tiles especiais
func _tiles() -> void:
	var post_skip := {}
	for d in city.M.get("decor", []):
		if d.type == "crane":
			for p in [[d.x0, d.y0], [d.x1, d.y0], [d.x0, d.y1], [d.x1, d.y1]]:
				post_skip[Vector2i(p[0], p[1])] = true
	if M.rail != null:
		for x in M.rail.xs:
			post_skip[Vector2i(x, M.rail.y)] = true
	for y in C.N:
		for x in C.N:
			var t: int = M.tile[y * C.N + x]
			var c := wp(x + .5, y + .5)
			if t == T.FENCE:
				_cyl(.05, .05, 2.4, c + Vector3(0, 1.2 + C.CURB, 0), city.mat.metal_dark, self, 8)
				for d in [Vector2i(1, 0), Vector2i(0, 1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx < C.N and ny < C.N and M.tile[ny * C.N + nx] == T.FENCE:
						var b := c + Vector3(d.x * W, 0, d.y * W)
						var mid := (c + b) / 2 + Vector3(0, 1.2 + C.CURB, 0)
						var p := _box(Vector3(W if d.x else .02, 2.3, W if d.y else .02), mid, mats.fence)
						p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						_box(Vector3(W if d.x else .04, .04, W if d.y else .04), mid + Vector3(0, 1.15, 0), city.mat.metal_dark)
			elif t == T.POST and not post_skip.has(Vector2i(x, y)):
				_cyl(.35, .3, 7.0, c + Vector3(0, 3.5, 0), city.mat.concrete, self, 12)
			elif t == T.GLASS:
				var g := _box(Vector3(W - .04, 3.4, W - .04), c + Vector3(0, 1.7 + C.CURB, 0), mats.glass)
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var fr := _box(Vector3(W, .12, W), c + Vector3(0, 3.45 + C.CURB, 0), city.mat.frame)
				glass_nodes[Vector2i(x, y)] = [g, fr]


func _pier(p: Dictionary) -> void:
	var a := wp(p.x0, p.y0)
	var b := wp(p.x1 + 1, p.y1 + 1)
	var size := Vector3(b.x - a.x, .3, b.z - a.z)
	_box(size, (a + b) / 2 + Vector3(0, C.CURB, 0), city.mat.wood)
	var x := a.x + 1.5
	while x < b.x:
		var z := a.z + 1.5
		while z < b.z:
			_cyl(.18, .18, 3.0, Vector3(x, -1.3, z), city.mat.wood, self, 8)
			z += 4.5
		x += 4.5


# ---------------------------------------------------------------- estilos de prédio
func _containers(b: Dictionary) -> void:
	var n := Node3D.new()
	add_child(n)
	b.node = n
	var col: Color = mats.cont[int(b.get("col", 0)) % 6]
	var m := city.surf("galvanized", 2.0, col, {grime_amt = .7, metal = -.3})
	var a := wp(b.x, b.y)
	var size := Vector3(b.w * W - .2, 2.6, b.d * W - .2)
	for k in b.fl:
		var c := _box(size, a + Vector3(b.w * W / 2, C.CURB + 1.3 + k * 2.62, b.d * W / 2), m, n)
		var rib := city.surf("galvanized", 2.0, col * .8, {ribs = .25 if b.w >= b.d else 0.0, grime_amt = .5})
		c.material_override = rib


func _warehouse(b: Dictionary) -> void:
	var n := Node3D.new()
	add_child(n)
	b.node = n
	var a := wp(b.x, b.y)
	var w: float = b.w * W
	var d: float = b.d * W
	var h: float = b.fl * 3.0 + 1.5
	var wall := city.surf("galvanized", 2.0, Color(.55, .58, .6), {ribs = .22, grime_amt = .9})
	var body := _box(Vector3(w, h, d), a + Vector3(w / 2, h / 2, d / 2), wall, n)
	var roof := _box(Vector3(w + .4, .4, d + .4), a + Vector3(w / 2, h + .2, d / 2), city.mat.roof, n)
	_box(Vector3(minf(5, w * .4), 4.2, .2), a + Vector3(w / 2, 2.1, d + .05), city.mat.shutter, n)
	if b.sign != "":
		var sc: Color = b.sign_col
		_box(Vector3(minf(w * .8, b.sign.length() * .9 + 1), 1.1, .3), a + Vector3(w / 2, h - .9, d + .2), city.mat.frame, n)
		_label(b.sign, 96, sc, a + Vector3(w / 2, h - .9, d + .37), 0, 4.0, n)
		var l := OmniLight3D.new()
		l.light_color = sc
		l.light_energy = 2.0
		l.omni_range = 8
		l.position = a + Vector3(w / 2, h - 1.5, d + 2)
		n.add_child(l)
	for x in [2.5, w - 2.5]:
		var lamp := city.emit(Color(1, .85, .6), 3.0)
		_box(Vector3(.5, .12, .3), a + Vector3(x, h - .4, d + .2), lamp, n)


func _wall(b: Dictionary) -> void:
	var n := Node3D.new()
	add_child(n)
	b.node = n
	var a := wp(b.x, b.y)
	var w: float = b.w * W
	var d: float = b.d * W
	var thin := Vector3(w - (W - .5 if b.w == 1 else 0.0), 2.6, d - (W - .5 if b.d == 1 else 0.0))
	_box(thin, a + Vector3(w / 2, 1.3 + C.CURB, d / 2), city.mat.concrete, n)
	_box(thin + Vector3(.12, .08, .12), a + Vector3(w / 2, 2.64 + C.CURB, d / 2), city.mat.trim, n)


func _hedge(b: Dictionary) -> void:
	var n := Node3D.new()
	add_child(n)
	b.node = n
	var a := wp(b.x, b.y)
	var w: float = b.w * W
	var d: float = b.d * W
	var size := Vector3(w - (W - 1.6 if b.w == 1 else 0.0), 2.3, d - (W - 1.6 if b.d == 1 else 0.0))
	_box(size, a + Vector3(w / 2, 1.15 + C.CURB, d / 2), mats.hedge, n)


# ---------------------------------------------------------------- objetos de cena
func _decor(d: Dictionary) -> void:
	match d.type:
		"crane": _crane(d)
		"boat": _boat(d)
		"barrier":
			var p := wp(d.x, d.y, C.CURB)
			_box(Vector3(.4, 1.1, .4), p + Vector3(-2.6, .55, 0), city.mat.frame)
			var arm := _box(Vector3(5.2, .14, .14), p + Vector3(0, 1.0, 0), _std(Color(.9, .2, .15), .5))
			d.node = arm
		"van":
			var mi := MeshInstance3D.new()
			mi.mesh = city.styled_mesh("van", "car")
			mi.set_instance_shader_parameter("paint_col", Color(.85, .85, .82, 1))
			mi.transform = Transform3D(Basis(Vector3.UP, PI / 2 - d.get("ang", 0.0)), wp(d.x, d.y))
			add_child(mi)
		"billboard": _billboard(d)
		"cable": _cable(d)
		"chimney":
			var h: float = d.get("h", 7.0) * 4.0
			var c := _cyl(1.4, 1.0, h, wp(d.x, d.y, h / 2), city.mat.brick)
			_cyl(1.1, 1.1, .8, wp(d.x, d.y, h + .4), city.mat.metal_dark)
			var sm := _smoke(Color(.2, .2, .22, .55), 3.0, 8)
			sm.position = wp(d.x, d.y, h + 1)
			d.node = c
			d.smoke = sm
		"pipe":
			var hh: float = d.get("h", 2.4) * HU + 1.0
			var a := wp(d.x1, d.y1, hh)
			var b := wp(d.x2, d.y2, hh)
			var m := city.surf("metal", 1.5, Color(d.get("col", "#6a6a58")), {metal = .3, grime_amt = .6})
			var pipe := _beam(a, b, d.get("r", .2) * 3.0, m)
			var L := a.distance_to(b)
			var k := 0.0
			while k <= L:
				var p := a.lerp(b, k / maxf(L, 1))
				_box(Vector3(.2, hh, .2), Vector3(p.x, hh / 2, p.z), city.mat.metal_dark)
				k += 9.0
		"generator":
			var p := wp(d.x, d.y, C.CURB)
			_box(Vector3(2.6, 1.8, 1.6), p + Vector3(0, .9, 0), city.surf("metal", 1.0, Color(.25, .35, .25), {metal = .3}))
			_cyl(.45, .45, .2, p + Vector3(.6, 1.85, 0), city.mat.grill)
			var led := _box(Vector3(.12, .12, .05), p + Vector3(-.9, 1.4, .82), mats.green)
			d.node = led
		"reactor": _reactor(d)
		"fountain":
			var c := wp((d.x0 + d.x1 + 1) / 2.0, (d.y0 + d.y1 + 1) / 2.0)
			var w: float = (d.x1 - d.x0 + 1) * W
			var dd: float = (d.y1 - d.y0 + 1) * W
			_box(Vector3(w + .6, .6, dd + .6), c + Vector3(0, .1, 0), city.mat.granite)
			_box(Vector3(w, .1, dd), c + Vector3(0, .38, 0), mats.water)
			_cyl(.5, .3, 1.6, c + Vector3(0, 1.0, 0), city.mat.granite)
			var sp := _smoke(Color(.7, .85, 1, .5), 1.2, 30, Vector3(0, 6, 0))
			sp.position = c + Vector3(0, 1.8, 0)
			d.node = sp
		"disco": _disco(d)
		"heli": _heli(d)
		"laundry":
			var hh: float = d.get("h", 1.75) * HU + 3.0
			var a := wp(d.x1, d.y1, hh)
			var b := wp(d.x2, d.y2, hh)
			_beam(a, b, .02, city.mat.cable)
			var n := int(a.distance_to(b) / .7)
			var cols := [city.mat.cloth_a, city.mat.cloth_b, city.mat.cloth_c]
			for i in n:
				var p := a.lerp(b, (i + .5) / n)
				_box(Vector3(.5, .7, .03), p - Vector3(0, .4, 0), cols[i % 3])
		"blastdoor":
			var p := wp(d.x, d.y, C.CURB)
			var n := _box(Vector3(d.get("w", 2) * W, 3.2, .5), p + Vector3(0, 1.6, 0), city.surf("metal", 1.5, Color(.3, .3, .32), {metal = .6, ribs = .4}))
			d.node = n
		"airship": _airship(d)


func _crane(d: Dictionary) -> void:
	var col := city.surf("metal", 1.5, Color(d.col), {metal = .4, grime_amt = .5})
	var H := 22.0
	var a := wp(d.x0 + .5, d.y0 + .5)
	var b := wp(d.x1 + .5, d.y1 + .5)
	for p in [Vector3(a.x, 0, a.z), Vector3(b.x, 0, a.z), Vector3(a.x, 0, b.z), Vector3(b.x, 0, b.z)]:
		_box(Vector3(.8, H, .8), p + Vector3(0, H / 2, 0), col)
	_box(Vector3(b.x - a.x + 1, 1.2, 1.2), Vector3((a.x + b.x) / 2, H, a.z), col)
	_box(Vector3(b.x - a.x + 1, 1.2, 1.2), Vector3((a.x + b.x) / 2, H, b.z), col)
	var hang: Vector2 = d.hang
	var hx := hang.x * W
	var hz := hang.y * W
	_box(Vector3(1.2, 1.4, absf(b.z - hz) + 4), Vector3(hx, H + .6, (b.z + hz) / 2 - 1), col)
	_box(Vector3(3, 2.4, 3), Vector3(hx, H - 1.6, b.z), city.mat.panel)
	if d.get("main", false):
		var n := Node3D.new()
		add_child(n)
		n.position = Vector3(hx, 0, hz)
		_beam(Vector3(0, H - .5, 0), Vector3(0, 12.6, 0), .06, city.mat.cable, n)
		var cm := city.surf("galvanized", 2.0, Color("#b8681e"), {ribs = .25, grime_amt = .6})
		_box(Vector3(9, 2.6, 2.6), Vector3(0, 11.2, 0), cm, n)
		hanging = n
		d.node = n
	else:
		_beam(Vector3(hx, H - .5, hz), Vector3(hx, 6, hz), .06, city.mat.cable)


func _boat(d: Dictionary) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = wp(d.x, d.y, -.5)
	_box(Vector3(4, 1.6, 11), Vector3(0, .5, 0), _std(Color(.12, .14, .18), .5, .3), n)
	_box(Vector3(2.8, 1.8, 3.4), Vector3(0, 2.2, 1.6), _std(Color(.85, .85, .82), .5), n)
	_box(Vector3(2.9, .5, 3.5), Vector3(0, 2.6, 1.6), city.mat.car_glass, n)
	var l := OmniLight3D.new()
	l.light_color = Color(1, .3, .2)
	l.light_energy = 1.5
	l.omni_range = 6
	l.position = Vector3(0, 3.5, -5)
	n.add_child(l)
	d.node = n


func _billboard(d: Dictionary) -> void:
	var p := wp(d.x, d.y, 0)
	var w: float = d.get("w", 5.0) * W
	var h: float = d.get("h", 3.0) * HU + 2.0
	var col := Color(d.get("col", "#ff3d5a"))
	var base := 6.0
	for x in [-w * .35, w * .35]:
		_box(Vector3(.3, base, .3), p + Vector3(x, base / 2, 0), city.mat.metal_dark)
	_box(Vector3(w, h, .4), p + Vector3(0, base + h / 2, 0), _std(Color(.02, .02, .03), .4, .5))
	_box(Vector3(w + .2, .15, .5), p + Vector3(0, base + h, 0), city.emit(col, 6.0))
	_box(Vector3(w + .2, .15, .5), p + Vector3(0, base, 0), city.emit(col, 6.0))
	for side in [1, -1]:
		var r: float = 0.0 if side > 0 else PI
		var z: float = .22 * side
		_label(d.get("text", ""), 180, col, p + Vector3(0, base + h * .62, z), r, 5.0)
		_label(d.get("sub", ""), 64, Color(.9, .9, .95), p + Vector3(0, base + h * .25, z), r, 2.5)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 4
	l.omni_range = 14
	l.position = p + Vector3(0, base + h / 2, 3)
	add_child(l)


func _cable(d: Dictionary) -> void:
	var p := wp(d.x, d.y, C.CURB)
	_box(Vector3(6, .4, 6), p + Vector3(0, 4.5, 0), city.mat.concrete)
	for q in [Vector3(-2.6, 0, -2.6), Vector3(2.6, 0, -2.6), Vector3(-2.6, 0, 2.6), Vector3(2.6, 0, 2.6)]:
		_box(Vector3(.4, 4.5, .4), p + q + Vector3(0, 2.25, 0), city.mat.concrete)
	_beam(p + Vector3(0, 6, 0), p + Vector3(60, 30, -20), .05, city.mat.cable)
	var cab := _box(Vector3(2.2, 2.0, 2.6), p + Vector3(2, 3.4, 0), _std(Color(.85, .2, .15), .4, .3))
	_box(Vector3(2.3, .8, 2.7), p + Vector3(2, 3.8, 0), city.mat.car_glass)
	d.node = cab


func _reactor(d: Dictionary) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = wp(d.x, d.y, C.CURB)
	var r: float = d.get("r", 1.35) * W * .8
	_cyl(r, r * .9, 9, Vector3(0, 4.5, 0), city.surf("metal", 2.0, Color(.6, .62, .64), {metal = .5, grime_amt = .7}), n, 32)
	_cyl(r * 1.05, r * 1.05, .5, Vector3(0, 2, 0), city.mat.metal_dark, n, 32)
	var ring := _cyl(r * 1.03, r * 1.03, .35, Vector3(0, 6.5, 0), city.emit(Color(.3, .8, 1), 4.0), n, 32)
	_cyl(r * .5, r * .3, 2.5, Vector3(0, 10, 0), city.mat.metal_dark, n, 20)
	var l := OmniLight3D.new()
	l.light_color = Color(.3, .8, 1)
	l.light_energy = 3
	l.omni_range = 14
	l.position = Vector3(0, 7, 0)
	n.add_child(l)
	d.node = n
	d.ring = ring
	d.light = l
	anims.append([n, "reactor", d])


func _disco(d: Dictionary) -> void:
	var a := wp(d.x0, d.y0)
	var b := wp(d.x1 + 1, d.y1 + 1)
	var n := Node3D.new()
	add_child(n)
	var cols := [Color("#ff3d8b"), Color("#38e8ff"), Color("#a66bff"), Color("#ffb13d")]
	var x := a.x
	var i := 0
	while x < b.x - .1:
		var z := a.z
		while z < b.z - .1:
			var t := _box(Vector3(W - .1, .04, W - .1), Vector3(x + W / 2, C.CURB + .02, z + W / 2), city.emit(cols[i % 4] * .6, .35), n)
			t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			i += 1
			z += W
		x += W
		i += 1
	var lights := []
	for k in 4:
		var s := SpotLight3D.new()
		s.light_color = cols[k]
		s.light_energy = 12
		s.spot_range = 22
		s.spot_angle = 18
		s.light_volumetric_fog_energy = 4
		s.position = Vector3((a.x + b.x) / 2 + (k - 1.5) * 4, 12, (a.z + b.z) / 2)
		n.add_child(s)
		lights.append(s)
	anims.append([n, "disco", {lights = lights}])


func _heli(d: Dictionary) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = wp(d.x, d.y, C.CURB)
	n.rotation.y = -d.get("ang", 0.0)
	var body := city.surf("metal", 2.0, Color(.12, .13, .16), {metal = .6, rough_mul = .5, grime_amt = 0.0})
	_box(Vector3(2.4, 2.2, 6.0), Vector3(0, 1.6, 0), body, n)
	_box(Vector3(2.0, 1.2, 1.6), Vector3(0, 2.1, -2.6), city.mat.car_glass, n)
	_box(Vector3(.6, .6, 5.5), Vector3(0, 2.0, 5.2), body, n)
	_box(Vector3(.2, 1.6, 1.0), Vector3(0, 2.6, 7.8), body, n)
	for x in [-1.1, 1.1]:
		_box(Vector3(.12, .12, 5), Vector3(x, .3, 0), city.mat.metal_dark, n)
	var rotor := Node3D.new()
	rotor.position = Vector3(0, 3.0, 0)
	n.add_child(rotor)
	for k in 4:
		var bl := _box(Vector3(.4, .05, 11), Vector3(), city.mat.metal_dark, rotor)
		bl.rotation.y = k * PI / 2
	var bc := _box(Vector3(.2, .2, .2), Vector3(0, 3.4, 7.8), mats.red, n)
	d.node = n
	n.visible = d.get("vis", true)
	anims.append([n, "heli", {rotor = rotor, d = d}])


func _airship(d: Dictionary) -> void:
	var n := Node3D.new()
	add_child(n)
	var alt: float = d.get("h", 6.5) * 4.0
	n.position = wp(d.x, d.y, alt)
	var hull := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1
	sm.height = 2
	hull.mesh = sm
	var len: float = d.get("len", 15) * W
	hull.scale = Vector3(len * .16, len * .16, len * .5)
	hull.rotation.y = PI / 2
	hull.material_override = city.surf("metal", 4.0, Color(.8, .82, .86), {metal = .1, grime_amt = .2, emit = Color(.25, .27, .32), emit_k = .35})
	n.add_child(hull)
	for z in [-len * .45, len * .45]:
		_box(Vector3(.4, .4, .4), Vector3(0, len * .16, z), mats.red, n)
	for k in 3:
		var fl := SpotLight3D.new()
		fl.light_color = Color(1, .95, .85)
		fl.light_energy = 8
		fl.spot_range = alt + 10
		fl.spot_angle = 30
		fl.position = Vector3(0, -len * .16 - 2, (k - 1) * len * .25)
		fl.rotation.x = -PI / 2
		n.add_child(fl)
	_box(Vector3(len * .3, 2.6, 3.6), Vector3(0, -len * .16 - 1, 0), city.mat.panel, n)
	var col := Color(d.get("col", "#ff3d5a"))
	for side in [1, -1]:
		_label(d.get("text", ""), 200, col, Vector3(0, 0, side * len * .165), 0.0 if side > 0 else PI, 4.0, n)
	_beam(n.position, wp(d.mx, d.my, 18), .1, city.mat.cable)
	_cyl(.5, .4, 18, wp(d.mx, d.my, 9), city.mat.metal_dark)
	d.node = n
	anims.append([n, "airship", d])


# ---------------------------------------------------------------- terminais, câmeras, vapor, monotrilho
func _terminals() -> void:
	for t in M.terms:
		var n := Node3D.new()
		add_child(n)
		n.position = wp(t.x, t.y, game.ground_at(t.x, t.y))
		_box(Vector3(.7, 1.3, .5), Vector3(0, .65, 0), city.mat.panel, n)
		var scr := _box(Vector3(.55, .4, .05), Vector3(0, 1.1, .27), city.emit(Color(1, .25, .2), 3.0), n)
		var l := OmniLight3D.new()
		l.light_color = Color(1, .3, .2)
		l.light_energy = 1.2
		l.omni_range = 3.5
		l.position = Vector3(0, 1.3, .6)
		n.add_child(l)
		term_nodes.append([n, t, scr, l, false])


func _cam(c: Dictionary) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = wp(c.x, c.y, 0)
	var h := 4.2
	_cyl(.07, .07, h, Vector3(0, h / 2, 0), city.mat.metal_dark, n, 8)
	var head := Node3D.new()
	head.position = Vector3(0, h, 0)
	n.add_child(head)
	_box(Vector3(.3, .25, .55), Vector3(0, 0, .2), _std(Color(.85, .85, .82), .4), head)
	var led := _box(Vector3(.08, .08, .05), Vector3(0, 0, .5), mats.red, head)
	var rng: float = c.range * W
	var hw: float = rng * tan(c.fov)
	var am := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, -h + C.CURB + .06, 0), Vector3(-hw, -h + C.CURB + .06, rng), Vector3(hw, -h + C.CURB + .06, rng)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var cone := MeshInstance3D.new()
	cone.mesh = am
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cmat.albedo_color = Color(1, .9, .3, .08)
	cone.material_override = cmat
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.add_child(cone)
	cam_nodes.append([n, head, cone, cmat, c])


func _vent(v: Dictionary) -> void:
	var p := wp(v.x, v.y, game.ground_at(v.x, v.y) + .02)
	_box(Vector3(1.2, .05, 1.2), p, city.mat.grill)
	var st := _smoke(Color(.9, .92, .95, .5), 1.4, 40, Vector3(0, 9, 0))
	st.position = p
	st.emitting = false
	vent_nodes.append([st, v])


func _monorail() -> void:
	var y: float = M.rail.y
	var h := 7.5
	for x in M.rail.xs:
		_box(Vector3(.9, h, .9), wp(x + .5, y + .5, h / 2), city.mat.concrete)
	_box(Vector3(C.N * W + 60, .8, 1.6), Vector3(C.N * W / 2, h + .4, (y + .5) * W), city.mat.concrete)
	train_node = Node3D.new()
	add_child(train_node)
	for k in 3:
		var car := _box(Vector3(11, 3.0, 2.8), Vector3(-k * 11.6, h + 2.3, (y + .5) * W), city.surf("metal", 2.0, Color(.75, .78, .8), {metal = .5, grime_amt = .4}), train_node)
		_box(Vector3(10.6, .9, 2.85), Vector3(-k * 11.6, h + 2.7, (y + .5) * W), city.emit(Color(1, .9, .7), 1.6), train_node)
	train_node.visible = false


static var _puff: Texture2D


## Textura redonda e suave para fumaça, vapor e respingos.
static func puff_tex() -> Texture2D:
	if _puff == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(.45, Color(1, 1, 1, .55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(.5, .5)
		t.fill_to = Vector2(1, .5)
		t.width = 64
		t.height = 64
		_puff = t
	return _puff


func _smoke(col: Color, size: float, amount: int, vel := Vector3(0, 2.5, 0)) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 3.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = vel.normalized()
	pm.spread = 12
	pm.initial_velocity_min = vel.length() * .6
	pm.initial_velocity_max = vel.length()
	pm.gravity = Vector3(.3, .2, 0)
	pm.scale_min = size * .6
	pm.scale_max = size * 1.4
	var cv := Curve.new()
	cv.add_point(Vector2(0, .4))
	cv.add_point(Vector2(1, 1.6))
	var ct := CurveTexture.new()
	ct.curve = cv
	pm.scale_curve = ct
	p.process_material = pm
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.albedo_texture = puff_tex()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	return p


# ---------------------------------------------------------------- unidades especiais
func drone_view() -> Node3D:
	var n := Node3D.new()
	var body := _box(Vector3(.5, .18, .5), Vector3(0, 0, 0), city.mat.panel, n)
	for k in 4:
		var a := k * PI / 2 + PI / 4
		var arm := Vector3(cos(a), 0, sin(a)) * .45
		_box(Vector3(.06, .04, .45), arm * .5, city.mat.metal_dark, n).rotation.y = -a + PI / 2
		_cyl(.2, .2, .02, arm + Vector3(0, .06, 0), _std(Color(.05, .05, .05, .6), .3), n, 12)
	_box(Vector3(.12, .08, .06), Vector3(0, -.05, .27), mats.red, n)
	var l := SpotLight3D.new()
	l.light_color = Color(1, .95, .85)
	l.light_energy = 3
	l.spot_range = 10
	l.spot_angle = 22
	l.rotation.x = -1.1
	n.add_child(l)
	return n


func car_view(c: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	var model: String = c.get("model", "sedan")
	if not city.kit.has(model):
		model = "sedan"
	mi.mesh = city.styled_mesh(model, "car")
	mi.set_instance_shader_parameter("paint_col", Color(c.col.r, c.col.g, c.col.b, 1))
	mi.layers = 2
	add_child(mi)
	var hl := SpotLight3D.new()
	hl.light_color = Color(1, .93, .8)
	hl.light_energy = 3
	hl.spot_range = 16
	hl.spot_angle = 30
	hl.position = Vector3(0, .8, 2.4)
	hl.rotation.x = -.12
	mi.add_child(hl)
	car_nodes.append([mi, c])


# ---------------------------------------------------------------- atualização
func tick(dt: float) -> void:
	for e in car_nodes:
		var mi: MeshInstance3D = e[0]
		var c: Dictionary = e[1]
		mi.transform = Transform3D(Basis(Vector3.UP, atan2(cos(c.ang), sin(c.ang))), wp(c.x, c.y))
		if c.dead and not c.get("burnt", false):
			c.burnt = true
			mi.set_instance_shader_parameter("paint_col", Color(.05, .05, .05, 1))
			for ch in mi.get_children():
				ch.queue_free()
			var sm := _smoke(Color(.1, .1, .1, .6), 2.0, 20)
			sm.position = wp(c.x, c.y, 1)
	for e in cam_nodes:
		var c: Dictionary = e[4]
		var head: Node3D = e[1]
		head.rotation.y = atan2(cos(c.a), sin(c.a))
		var cmat: StandardMaterial3D = e[3]
		e[2].visible = not c.dead and not c.off
		cmat.albedo_color = Color(1, .2, .15, .16) if c.see > 0 else Color(1, .9, .3, .07)
		if c.dead:
			head.rotation.x = .6
	for e in laser_nodes:
		var mi: MeshInstance3D = e[0]
		var l: Dictionary = e[1]
		mi.visible = l.on and not l.off
		if mi.visible:
			var a := wp(l.x1, l.y1, .9)
			var b := wp(l.x2, l.y2, .9)
			mi.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP).scaled(Vector3(1, 1, maxf(a.distance_to(b), .1))), (a + b) / 2)
	for e in vent_nodes:
		var st: GPUParticles3D = e[0]
		st.emitting = e[1].state == 2
	for e in term_nodes:
		var t: Dictionary = e[1]
		if t.done and not e[4]:
			e[4] = true
			e[2].material_override = mats.green
			e[3].light_color = Color(.2, 1, .5)
	if train_node:
		train_node.visible = M.train != null
		if M.train != null:
			train_node.position.x = M.train.x * W
	if hanging and M.flags.get("dropped", false):
		var f = M.falling[0] if not M.falling.is_empty() else null
		if f != null:
			var k := clampf(f.t / f.T, 0, 1)
			hanging.get_child(1).position.y = lerpf(11.2, 1.45 + C.CURB, k * k)
			hanging.get_child(0).visible = false
	for a in anims:
		var n: Node3D = a[0]
		match a[1]:
			"heli":
				a[2].rotor.rotation.y += dt * 18
				var d: Dictionary = a[2].d
				n.visible = d.get("vis", true)
				if d.has("alt"):
					n.position.y = C.CURB + d.alt * HU
				if M.flags.get("heliGo", false):
					n.position.y += dt * 6
			"disco":
				var k := 0
				for s in a[2].lights:
					s.rotation = Vector3(-1.2 + sin(M.t * 1.3 + k) * .5, M.t * .8 + k * 1.6, 0)
					k += 1
			"reactor":
				var d: Dictionary = a[2]
				if d.get("dead", false):
					n.visible = false
				elif d.get("armed", false):
					var on := fmod(M.t, .6) < .3
					d.ring.material_override = mats.red if on else city.mat.metal_dark
					d.light.light_color = Color(1, .2, .1)
			"airship":
				if M.flags.get("airshipGo", false):
					n.position += Vector3(4, 1.5, -2) * dt
	for d in city.M.get("decor", []):
		if d.type == "chimney" and d.get("dead", false) and d.has("smoke"):
			d.smoke.emitting = false
		if d.type == "fountain" and d.has("node"):
			d.node.emitting = not M.flags.get("fountainOff", false)
		if d.type == "blastdoor" and d.has("node"):
			var shut: bool = M.flags.get(d.get("flag", "shut"), false)
			d.node.position.y = lerpf(d.node.position.y, (1.6 + C.CURB) if shut else -1.8, minf(1, dt * 3))


func event(e: Dictionary) -> void:
	match e.k:
		"lamp":
			var l: Dictionary = e.l
			if l.has("node") and is_instance_valid(l.node):
				l.node.visible = false
		"glass":
			var key := Vector2i(e.x, e.y)
			if glass_nodes.has(key):
				for n in glass_nodes[key]:
					n.queue_free()
				glass_nodes.erase(key)
		"bld":
			var b: Dictionary = e.b
			if b.has("node") and is_instance_valid(b.node):
				b.node.queue_free()

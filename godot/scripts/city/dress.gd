## Mobiliário e objetos da cidade: postes de luz, postes de energia com fiação, semáforos, árvores,
## carros, ar-condicionado e varais nas fachadas, coisas de telhado e entulho de rua.
class_name CityDress

const T := C.T
const W := C.TILE


static func chunk_of(p: Vector3) -> String:
	return "%d_%d" % [int(p.x / (C.P * W * 2)), int(p.z / (C.P * W * 2))]


## Base cujo +Z local (frente dos modelos) aponta para dir.
static func face(dir: Vector3) -> Basis:
	return Basis.looking_at(-dir, Vector3.UP)


static func road_dir(B: CityBuilder, tx: int, ty: int) -> Vector3:
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		if B.tile_at(tx + d[0], ty + d[1]) == T.ROAD:
			return Vector3(d[0], 0, d[1])
	return Vector3.ZERO


static func dress(B: CityBuilder) -> void:
	var used := {}   # tiles já ocupados por postes e árvores
	_lamps(B, used)
	_poles(B, used)
	_traffic(B, used)
	_trees(B, used)
	_cars(B)
	_facades(B)
	_roofs(B)
	_kiosks(B)
	_clutter(B, used)


# ---------------------------------------------------------------- postes de luz
static func _lamps(B: CityBuilder, used: Dictionary) -> void:
	for L in B.M.lamps:
		var tx := int(L.x)
		var ty := int(L.y)
		used[Vector2i(tx, ty)] = true
		var dir := road_dir(B, tx, ty)
		if dir == Vector3.ZERO:
			dir = Vector3(1, 0, 0)
		var base := Vector3(L.x * W, C.CURB, L.y * W) + dir * 1.05
		B.put("lamp", "prop", Transform3D(face(dir), base), Color.WHITE, chunk_of(base))
		var head := base + dir * 2.15 + Vector3(0, 7.0, 0)
		var sp := SpotLight3D.new()
		sp.light_color = L.col
		sp.light_energy = 14.0
		sp.spot_range = 17.0
		sp.spot_angle = 64.0
		sp.spot_attenuation = .6
		sp.light_volumetric_fog_energy = 2.0
		sp.light_size = .3
		sp.position = head
		sp.rotation.x = -PI / 2
		sp.shadow_enabled = head.distance_to(B.focus) < float(B.get_tree().get_meta("shadow_r", 42.0)) and not B.get_tree().has_meta("noshadow")
		sp.distance_fade_enabled = true
		sp.distance_fade_begin = 140.0
		sp.distance_fade_length = 30.0
		sp.shadow_bias = .05
		B.add_child(sp)


# ---------------------------------------------------------------- postes de energia e fios
static func _poles(B: CityBuilder, used: Dictionary) -> void:
	var lines := {}   # rua -> lista de [posição ao longo da rua, Transform3D]
	for b in B.M.blocks:
		var ox: int = b.ox
		var oy: int = b.oy
		var spots := []
		for k in [2, 6]:
			spots.append([Vector2i(ox + k, oy), Vector3(0, 0, -1)])
			spots.append([Vector2i(ox + k, oy + 8), Vector3(0, 0, 1)])
			spots.append([Vector2i(ox, oy + k), Vector3(-1, 0, 0)])
			spots.append([Vector2i(ox + 8, oy + k), Vector3(1, 0, 0)])
		for sd in spots:
			var t: Vector2i = sd[0]
			var dir: Vector3 = sd[1]
			if B.tile_at(t.x, t.y) != T.WALK or used.has(t):
				continue
			if B.tile_at(t.x + int(dir.x), t.y + int(dir.z)) != T.ROAD:
				continue
			used[t] = true
			var p := Vector3((t.x + .5) * W, C.CURB, (t.y + .5) * W) + dir * 1.15
			var bas := Basis(Vector3.UP, atan2(-dir.z, dir.x))
			var tr := C.hash01(t.x, t.y, 4.0) < .3
			var xf := Transform3D(bas, p)
			B.put("pole_tr" if tr else "pole", "prop", xf, Color.WHITE, chunk_of(p))
			var key := ("x%d" % int(p.x * 10)) if dir.x != 0 else ("z%d" % int(p.z * 10))
			if not lines.has(key):
				lines[key] = []
			lines[key].append([p.z if dir.x != 0 else p.x, xf])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pins := [Vector3(-.88, 10.06, 0), Vector3(0, 10.06, 0), Vector3(.88, 10.06, 0), Vector3(-.68, 9.06, 0), Vector3(.68, 9.06, 0)]
	for key in lines:
		var L: Array = lines[key]
		L.sort_custom(func(a, b): return a[0] < b[0])
		for i in L.size() - 1:
			var A: Transform3D = L[i][1]
			var Bx: Transform3D = L[i + 1][1]
			var span: float = L[i + 1][0] - L[i][0]
			if span > 26.0:
				continue
			for pn in pins:
				_wire(st, A * pn, Bx * pn, .25 + span * .012, .007)
			for k in 3:
				var off := Vector3(-.3 + k * .3, 7.42, -.08)
				_wire(st, A * off, Bx * off, .45 + k * .2 + span * .02, .011 + k * .004)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = B.mat.cable
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "fios"
	B.add_child(mi)


static func _wire(st: SurfaceTool, a: Vector3, b: Vector3, sag: float, r: float) -> void:
	var n := 14
	var pts := []
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
	for i in n:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var d := (p1 - p0).normalized()
		var u := d.cross(Vector3.UP).normalized()
		var v := u.cross(d).normalized()
		for k in 3:
			var a0 := TAU * k / 3.0
			var a1 := TAU * (k + 1) / 3.0
			var o0 := (u * cos(a0) + v * sin(a0)) * r
			var o1 := (u * cos(a1) + v * sin(a1)) * r
			var nn := (o0 + o1).normalized()
			for q in [p0 + o0, p1 + o0, p1 + o1, p0 + o0, p1 + o1, p0 + o1]:
				st.set_normal(nn)
				st.add_vertex(q)


# ---------------------------------------------------------------- semáforos
static func _traffic(B: CityBuilder, used: Dictionary) -> void:
	for k in C.NB + 1:
		for j in C.NB + 1:
			var ix := k * C.P
			var iy := j * C.P
			var corners := [[Vector2i(ix + 2, iy + 2), Vector3(-1, 0, 0), Vector3(-1, 0, -1)],
				[Vector2i(ix - 1, iy - 1), Vector3(1, 0, 0), Vector3(1, 0, 1)],
				[Vector2i(ix + 2, iy - 1), Vector3(0, 0, 1), Vector3(-1, 0, 1)],
				[Vector2i(ix - 1, iy + 2), Vector3(0, 0, -1), Vector3(1, 0, -1)]]
			for c in corners:
				var t: Vector2i = c[0]
				var arm: Vector3 = c[1]
				var cor: Vector3 = c[2]
				if B.tile_at(t.x, t.y) != T.WALK or used.has(t) or C.hash01(t.x, t.y, 8.0) < .25:
					continue
				used[t] = true
				var p := Vector3((t.x + .5) * W, C.CURB, (t.y + .5) * W) + cor * 1.05
				B.put("traffic", "prop", Transform3D(face(arm), p), Color.WHITE, chunk_of(p))
				B.put("bollard", "prop", Transform3D(Basis(), p - cor * .2 + Vector3(arm.z, 0, arm.x) * 1.4), Color.WHITE, chunk_of(p))


# ---------------------------------------------------------------- árvores
static func _trees(B: CityBuilder, used: Dictionary) -> void:
	var kinds := ["tree_a", "tree_b", "tree_c"]
	for tr in B.M.trees:
		var h := C.hash01(tr.x, tr.y, 2.0)
		var p := Vector3(tr.x * W + (h - .5) * 1.2, C.CURB, tr.y * W + (C.hash01(tr.y, tr.x, 2.0) - .5) * 1.2)
		var bas := Basis(Vector3.UP, tr.r).scaled(Vector3.ONE * (tr.s * .9))
		B.put(kinds[int(h * 3)], "tree", Transform3D(bas, p), Color(1, 1, 1), chunk_of(p))
	for b in B.M.blocks:
		var ox: int = b.ox
		var oy: int = b.oy
		for k in [1, 3, 5, 7]:
			for t in [Vector2i(ox + k, oy), Vector2i(ox + k, oy + 8), Vector2i(ox, oy + k), Vector2i(ox + 8, oy + k)]:
				if B.tile_at(t.x, t.y) != T.WALK or used.has(t) or C.hash01(t.x, t.y, 12.0) > .4:
					continue
				var dir := road_dir(B, t.x, t.y)
				if dir == Vector3.ZERO:
					continue
				used[t] = true
				var p := Vector3((t.x + .5) * W, C.CURB, (t.y + .5) * W) + dir * .9
				var h := C.hash01(t.x, t.y, 13.0)
				var bas := Basis(Vector3.UP, h * TAU).scaled(Vector3.ONE * (.75 + h * .3))
				B.put(kinds[int(h * 3)], "tree", Transform3D(bas, p), Color(1, 1, 1), chunk_of(p))
	for y in C.N:
		for x in C.N:
			if B.tile_at(x, y) == T.PLAZA and C.hash01(x, y, 21.0) < .06:
				var p := Vector3((x + .5) * W, C.CURB, (y + .5) * W)
				B.put("palm", "tree", Transform3D(Basis(Vector3.UP, C.hash01(x, y, 22.0) * TAU), p), Color.WHITE, chunk_of(p))


# ---------------------------------------------------------------- carros
static func _cars(B: CityBuilder) -> void:
	for c in B.M.cars:
		var dir := Vector3(-c.dx, 0, -c.dy)   # mão direita: inverte o sentido das faixas do jogo original
		var p := Vector3(c.x * W, 0, c.y * W)
		var col: Color = c.col
		var h := C.hash01(p.x, p.z, 31.0)
		var kind := "sedan"
		if col == Color("#e0a020"):
			kind = "taxi"
		elif h < .3:
			kind = "hatch"
		elif h < .45:
			kind = "van"
		elif h < .52:
			kind = "police"
			col = Color("#e8e8e8")
		B.put(kind, "car", Transform3D(face(dir), p), col, chunk_of(p))
		var hl := SpotLight3D.new()
		hl.light_color = Color(1, .93, .8)
		hl.light_energy = 3.0
		hl.spot_range = 16.0
		hl.spot_angle = 32.0
		hl.light_volumetric_fog_energy = 1.0
		B.add_child(hl)
		var from := p + dir * 2.5 + Vector3(0, .7, 0)
		hl.look_at_from_position(from, from + dir * 10.0 - Vector3(0, 1.6, 0), Vector3.UP)


# ---------------------------------------------------------------- fachadas
static func _facades(B: CityBuilder) -> void:
	for f in B.facade:
		var xf: Transform3D = f[1]
		var h := C.hash01(xf.origin.x, xf.origin.y, xf.origin.z)
		if f[0] == "A_win":
			if h < .32:
				B.put("ac", "prop", xf * Transform3D(Basis(), Vector3(1.5, .3, 0)), Color.WHITE, f[2])
		else:
			if h < .4:
				B.put("ac", "prop", xf * Transform3D(Basis(), Vector3(2.52, 1.25, 0)), Color.WHITE, f[2])
			elif h < .58:
				B.put("clothes", "prop", xf * Transform3D(Basis(), Vector3(1.5, 2.72, 0)), Color.WHITE, f[2])


# ---------------------------------------------------------------- telhados
static func _roofs(B: CityBuilder) -> void:
	for r in B.roofs:
		var b: Dictionary = r[0]
		var st: String = r[1]
		var R: Rect2 = r[2]
		var y: float = r[3]
		var ch := chunk_of(Vector3(R.position.x, 0, R.position.y))
		var h := C.hash01(R.position.x, R.position.y, 41.0)
		var c := R.get_center()
		if st != "B":
			var n := (1 + int(h * 2.0)) if R.size.x * R.size.y > 60 else 1
			for k in n:
				var p := Vector3(R.position.x + 1.6 + k * 2.2, y, R.position.y + 1.6 + h * 1.5)
				if p.x < R.end.x - 1.2:
					B.put("tank", "prop", Transform3D(Basis(Vector3.UP, h * 3.0), p), Color.WHITE, ch)
		if b.fl >= 5 and R.size.x >= 6 and R.size.y >= 6:
			B.put("roofbox", "prop", Transform3D(Basis(), Vector3(R.end.x - 3.4, y, R.end.y - 3.0)), Color.WHITE, ch)
		if st == "B":
			for k in 4:
				var q := C.hash01(R.position.x, k, 42.0)
				var p := Vector3(R.position.x + 1.2 + q * (R.size.x - 2.4), y, R.position.y + 1.2 + C.hash01(k, R.position.y, 43.0) * (R.size.y - 2.4))
				B.put("ac", "prop", Transform3D(Basis(Vector3.UP, int(q * 4) * PI / 2), p + Vector3(0, .3, 0)), Color.WHITE, ch)
		if b.get("ant", false):
			B.put("antenna", "prop", Transform3D(Basis(), Vector3(R.end.x - 1.5, y, R.position.y + 1.5)), Color.WHITE, ch)
			var bl := OmniLight3D.new()
			bl.light_color = Color(1, .1, .05)
			bl.light_energy = 1.5
			bl.omni_range = 4.0
			bl.position = Vector3(R.end.x - 1.5, y + 4.3, R.position.y + 1.5)
			B.add_child(bl)
		if h > .6:
			B.put("dish", "prop", Transform3D(Basis(Vector3.UP, h * 9.0), Vector3(c.x + 1.0, y, R.position.y + 1.2)), Color.WHITE, ch)


# ---------------------------------------------------------------- bancas de jornal
static func _kiosks(B: CityBuilder) -> void:
	for b in B.M.blds:
		if not b.get("kiosk", false):
			continue
		var p := Vector3((b.x + .5) * W, C.CURB, (b.y + .5) * W)
		var dir := Vector3(0, 0, 1)
		var col: Color = C.NEON[maxi(b.neon, 0) % C.NEON.size()]
		B.put("banca", "prop", Transform3D(face(dir), p), Color(col.r, col.g, col.b, 1.0), chunk_of(p))
		var l := OmniLight3D.new()
		l.light_color = Color(1, .9, .75)
		l.light_energy = 2.0
		l.omni_range = 6.0
		l.position = p + dir * 2.0 + Vector3(0, 2.0, 0)
		B.add_child(l)


# ---------------------------------------------------------------- entulho de rua
static func _clutter(B: CityBuilder, used: Dictionary) -> void:
	var bar_cols := [Color(.65, .12, .08), Color(.12, .25, .55), Color(.2, .4, .2), Color(.75, .55, .1)]
	for pr in B.M.props:
		var p := Vector3(pr.x * W, C.CURB, pr.y * W)
		var h := C.hash01(p.x, p.z, 51.0)
		B.put("barrel", "prop", Transform3D(Basis(Vector3.UP, h * TAU), p), bar_cols[int(h * 4)], chunk_of(p))
	for s in B.shop_lights:
		var p: Vector3 = s[0]
		var h := C.hash01(p.x, p.z, 52.0)
		var ground := Vector3(p.x, C.CURB, p.z)
		if h < .18:
			B.put("bags", "prop", Transform3D(Basis(Vector3.UP, h * 20.0), ground + Vector3(.9, 0, .3)), Color.WHITE, chunk_of(p))
		elif h < .26:
			B.put("bin", "prop", Transform3D(Basis(), ground + Vector3(-1.1, 0, .2)), Color.WHITE, chunk_of(p))
		elif h < .3 and s[2]:
			B.put("vending", "prop", Transform3D(Basis(), ground), Color.WHITE, chunk_of(p))
		elif h < .34:
			B.put("crates", "prop", Transform3D(Basis(Vector3.UP, h * 30.0), ground + Vector3(.6, 0, -.2)), Color.WHITE, chunk_of(p))
	for y in C.N:
		for x in C.N:
			var t := B.tile_at(x, y)
			var h := C.hash01(x, y, 61.0)
			var p := Vector3((x + .5) * W, C.CURB, (y + .5) * W)
			if t == T.PLAZA and h < .07:
				B.put("bench", "prop", Transform3D(Basis(Vector3.UP, int(h * 57) * PI / 2), p), Color.WHITE, chunk_of(p))
			elif t == T.WALK and not used.has(Vector2i(x, y)) and h > .985:
				var dir := road_dir(B, x, y)
				if dir != Vector3.ZERO:
					B.put("hydrant", "prop", Transform3D(face(dir), p + dir * 1.0), Color.WHITE, chunk_of(p))
			elif t == T.WALK and h > .97 and h <= .985:
				var dir := road_dir(B, x, y)
				if dir != Vector3.ZERO:
					B.put("dumpster", "prop", Transform3D(face(Vector3(dir.z, 0, dir.x)), p + dir * .4), Color.WHITE, chunk_of(p))

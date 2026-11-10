## Geração procedural do distrito (porte da parte de mapa de genMission em v2/js/world.js).
## Devolve um Dictionary com a grade de tiles, prédios, postes, árvores, barris, faixas de carros e o ponto de entrada.
class_name CityGen

static func split(x: int, y: int, w: int, h: int, dep: int, out: Array, r: C.Rng) -> void:
	if dep < 3 and (w >= 4 or h >= 4) and r.next() < .85:
		if (w >= h and w >= 4) or h < 4:
			var s := 2 + int(r.next() * (w - 3))
			split(x, y, s, h, dep + 1, out, r)
			split(x + s, y, w - s, h, dep + 1, out, r)
		else:
			var s := 2 + int(r.next() * (h - 3))
			split(x, y, w, s, dep + 1, out, r)
			split(x, y + s, w, h - s, dep + 1, out, r)
	else:
		out.append({x = x, y = y, w = w, h = h})


static func _fill(tile: PackedByteArray, hgt: PackedByteArray, B: Dictionary) -> void:
	for yy in range(B.y, B.y + B.d):
		for xx in range(B.x, B.x + B.w):
			tile[yy * C.N + xx] = C.T.BLD
			hgt[yy * C.N + xx] = B.fl


## riq: riqueza do distrito (0..1), muda a altura dos prédios. corps: quantas sedes corporativas.
static func generate(seed: int, riq: float = 0.5, corps: int = 1) -> Dictionary:
	var r := C.Rng.new(seed)
	var n := C.N
	var tile := PackedByteArray()
	tile.resize(n * n)
	var hgt := PackedByteArray()
	hgt.resize(n * n)
	for y in n:
		for x in n:
			tile[y * n + x] = C.T.ROAD if (x % C.P < 2 or y % C.P < 2) else C.T.WALK
	var corner := 1 + int(r.next() * 3)
	var kx := C.NB if corner & 1 else 0
	var ky := C.NB if corner & 2 else 0
	var spawn := Vector2(kx * C.P + 1, ky * C.P + 1)
	var sbx := C.NB - 1 if kx else 0
	var sby := C.NB - 1 if ky else 0
	var blocks := []
	for by in C.NB:
		for bx in C.NB:
			blocks.append({bx = bx, by = by, ox = bx * C.P + 2, oy = by * C.P + 2, d = absi(bx - sbx) + absi(by - sby), type = ""})
	var far := blocks.filter(func(b): return b.d >= 5)
	for k in corps:
		var cand := far.filter(func(b): return b.type == "")
		if cand.is_empty():
			break
		var cc: Dictionary = r.pick(cand)
		cc.type = "comp"
	var blds := []
	for b in blocks:
		var x0: int = b.ox + 1
		var y0: int = b.oy + 1
		if b.type == "":
			var q := r.next()
			b.type = ("bld" if q < .7 else "plaza") if b.d == 0 else ("bld" if q < .6 else "park" if q < .8 else "plaza")
		match b.type:
			"bld":
				var rects := []
				split(x0, y0, 7, 7, 0, rects, r)
				for R in rects:
					if r.next() < .12:
						for yy in range(R.y, R.y + R.h):
							for xx in range(R.x, R.x + R.w):
								tile[yy * n + xx] = C.T.PLAZA
						continue
					var fl := mini(11, 2 + int(r.next() * (3 + riq * 6)))
					var B := {x = R.x, y = R.y, w = R.w, d = R.h, fl = fl, pal = int(r.next() * 4), v = int(r.next() * 4),
						neon = int(r.next() * 4) if r.next() < .45 else -1, roof = int(r.next() * 3), seed = r.next()}
					B.sign = r.pick(C.SIGNS) if fl >= 3 and r.next() < .4 else ""
					B.sign_col = r.pick(C.NEON)
					B.ant = fl >= 8 and r.next() < .6
					blds.append(B)
					_fill(tile, hgt, B)
			"park":
				for yy in range(y0, y0 + 7):
					for xx in range(x0, x0 + 7):
						tile[yy * n + xx] = C.T.PLAZA if (xx == x0 + 3 or yy == y0 + 3) else (C.T.TREE if r.next() < .28 else C.T.GRASS)
			"plaza":
				for yy in range(y0, y0 + 7):
					for xx in range(x0, x0 + 7):
						tile[yy * n + xx] = C.T.PLAZA
				var K := {x = x0 + 3, y = y0 + 3, w = 1, d = 1, fl = 1, pal = 5, v = 0, neon = int(r.next() * 4), roof = 0, kiosk = true, seed = r.next(), sign = "", ant = false}
				blds.append(K)
				_fill(tile, hgt, K)
			"comp":
				var fl := 8 + int(r.next() * 3) + 3
				for yy in range(y0, y0 + 7):
					for xx in range(x0, x0 + 7):
						if yy >= y0 + 3:
							tile[yy * n + xx] = C.T.PLAZA
				var B := {x = x0, y = y0, w = 7, d = 3, fl = fl, pal = 4, v = int(r.next() * 4), neon = 0, sign = "HÉLICE",
					sign_col = Color("#ff3d5a"), roof = 1, ant = true, corp = true, seed = r.next()}
				blds.append(B)
				_fill(tile, hgt, B)
				b.court = Vector2(x0 + 3.5, y0 + 5)
	var lamps := []
	var lamp_cols := [Color("#ffb35c"), Color("#ffb35c"), Color("#ffb35c"), Color("#7fe3ff"), Color("#ff6ad5")]
	for b in blocks:
		var offs := [[0, 0], [8, 0], [0, 8], [8, 8], [4, 0], [4, 8], [0, 4], [8, 4]]
		for k in offs.size():
			if k < 4 or r.next() < .55:
				var x: int = b.ox + offs[k][0]
				var y: int = b.oy + offs[k][1]
				if tile[y * n + x] == C.T.WALK:
					lamps.append({x = x + .5, y = y + .5, col = r.pick(lamp_cols)})
	var trees := []
	for y in n:
		for x in n:
			if tile[y * n + x] == C.T.TREE:
				trees.append({x = x + .5, y = y + .5, s = .8 + r.next() * .5, r = r.next() * TAU})
	var props := []
	for k in 7:
		for t in 300:
			var x := int(r.next() * n)
			var y := int(r.next() * n)
			if tile[y * n + x] == C.T.WALK and Vector2(x, y).distance_to(spawn) > 6:
				props.append({x = x + .5, y = y + .5})
				break
	var lanes := []
	for k in C.NB + 1:
		lanes.append({x = k * C.P + .5, dx = 0, dy = -1})
		lanes.append({x = k * C.P + 1.5, dx = 0, dy = 1})
		lanes.append({y = k * C.P + .5, dx = 1, dy = 0})
		lanes.append({y = k * C.P + 1.5, dx = -1, dy = 0})
	var cars := []
	var car_cols := [Color("#8a1f2e"), Color("#1f4f8a"), Color("#c9c2b0"), Color("#2c2f36"), Color("#e0a020"), Color("#3c6e5a"),
		Color("#5e3a7a"), Color("#d8d8dc"), Color("#e0a020")]
	for k in 12 + roundi(riq * 8):
		var L: Dictionary = r.pick(lanes)
		var pos := r.next() * n
		var c := {x = L.get("x", pos), y = L.get("y", pos), dx = L.dx, dy = L.dy, col = r.pick(car_cols)}
		cars.append(c)
	return {tile = tile, hgt = hgt, blds = blds, lamps = lamps, trees = trees, props = props, cars = cars, spawn = spawn, blocks = blocks, riq = riq}

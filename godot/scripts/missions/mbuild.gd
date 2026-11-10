## API de construção das missões feitas à mão (o objeto "B" de genHandcrafted em v2/js/world.js).
## Monta a grade, os prédios, luzes, objetos de cena e cria as unidades direto na Mission.
class_name MB
extends RefCounted

const T := C.T
const N := C.N

var M: Mission
var tile := PackedByteArray()
var hgt := PackedByteArray()
var blds: Array = []
var lamps: Array = []
var trees: Array = []
var props: Array = []
var decor: Array = []
var piers: Array = []
var lane_cars: Array = []
var paint = null


func _init(m: Mission) -> void:
	M = m
	tile.resize(N * N)
	tile.fill(T.WALK)
	hgt.resize(N * N)


func set_tile(x: int, y: int, t: int) -> void:
	if x >= 0 and y >= 0 and x < N and y < N:
		tile[y * N + x] = t


func rect(t: int, x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			set_tile(x, y, t)


func pier(x0: int, y0: int, x1: int, y1: int) -> void:
	rect(T.PLAZA, x0, y0, x1, y1)
	piers.append({x0 = x0, y0 = y0, x1 = x1, y1 = y1})


func bld(o: Dictionary) -> Dictionary:
	var b := {pal = 0, v = 0, neon = -1, sign = "", roof = 0, ant = false, style = "", seed = randf()}
	b.merge(o, true)
	if b.sign == null:
		b.sign = ""
	if b.has("signCol") and b.signCol is String:
		b.sign_col = Color(b.signCol)
	elif not b.has("sign_col"):
		b.sign_col = C.NEON[0]
	blds.append(b)
	for y in range(b.y, b.y + b.d):
		for x in range(b.x, b.x + b.w):
			set_tile(x, y, T.BLD)
			if x >= 0 and y >= 0 and x < N and y < N:
				hgt[y * N + x] = b.fl
	return b


func lamp(x: float, y: float, col := "#ffb35c", tall := false, extra := {}) -> Dictionary:
	var l := {x = x, y = y, col = Color(col), tall = tall, dead = false}
	l.merge(extra, true)
	lamps.append(l)
	return l


func tree(x: float, y: float) -> void:
	trees.append({x = x, y = y, s = 1.0, r = x * 7 + y})
	set_tile(int(x), int(y), T.TREE)


func prop(x: float, y: float) -> void:
	props.append({x = x, y = y})


func add_decor(o: Dictionary) -> Dictionary:
	decor.append(o)
	return o


func term(o: Dictionary) -> Dictionary:
	var t := {prog = 0.0, done = false}
	t.merge(o, true)
	M.terms.append(t)
	return t


func unit(kind: String, x: float, y: float) -> Unit:
	return M.mk_unit(kind, x, y)


func arm(u: Unit, dif: int) -> void:
	M.arm_ai(u, dif)


func rand_tile(pred: Callable) -> Variant:
	for k in 400:
		var x := randi() % N
		var y := randi() % N
		if pred.call(tile[y * N + x], x, y):
			return Vector2(x + .5, y + .5)
	return null


func cam(x: float, y: float, ang: float, o := {}) -> Dictionary:
	var c := {x = x, y = y, base = ang, a = ang, sweep = .6, spd = .5, ph = randf() * 6, fov = .42, range = 7.0, see = 0.0, dead = false, off = false}
	c.merge(o, true)
	M.cams.append(c)
	return c


func laser(x1: float, y1: float, x2: float, y2: float, o := {}) -> Dictionary:
	var l := {x1 = x1, y1 = y1, x2 = x2, y2 = y2, off = false, on = true, per = 0.0, ph = 0.0, duty = .5, trip_t = 0.0}
	l.merge(o, true)
	M.lasers.append(l)
	return l


func heavy(x: float, y: float, dif := 6) -> Unit:
	var u := M.mk_unit("inimigo", x, y)
	M.arm_ai(u, dif)
	u.heavy = true
	u.w = "serra"
	u.mun = GD.WD.serra.pente
	u.hp = 380
	u.max_hp = 380
	u.armor = .5
	u.spd = 1.35
	u.nades = 0
	u.tags.heavy = true
	return u


func vent(x: float, y: float, o := {}) -> Dictionary:
	var v := {x = x, y = y, per = 7.0, dur = 2.2, ph = randf() * 7, r = 1.15, dmg = 60.0, state = 0}
	v.merge(o, true)
	M.vents.append(v)
	return v


func drone(x: float, y: float, route: Array, dif := 0) -> Unit:
	var u := M.mk_unit("drone", x, y)
	for p in route:
		u.route.append(Vector2(p[0], p[1]) if p is Array else p)
	if dif > 0:
		u.acc = .42 + dif * .03
		u.hp = 50 + dif * 5
		u.max_hp = u.hp
	return u


func glass(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if tile[y * N + x] != T.GLASS:
				M.glass_n += 1
			set_tile(x, y, T.GLASS)


func monorail(y: int, xs: Array) -> void:
	M.rail = {y = y, xs = xs}
	for x in xs:
		set_tile(x, y, T.POST)


func disguise(u: Unit, dance: bool) -> void:
	u.disguise = true
	u.dance = dance
	u.still = dance
	u.tags.cell = true
	u.view_kind = "civil"


func lanes(list: Array, count: int) -> void:
	var cols := [Color("#8a1f2e"), Color("#1f4f8a"), Color("#c9c2b0"), Color("#2c2f36"), Color("#e0a020"), Color("#3c6e5a"), Color("#d8d8dc")]
	for k in count:
		var L: Dictionary = list[k % list.size()]
		var pos := randf() * N
		lane_cars.append({x = L.get("x", pos), y = L.get("y", pos), dx = L.dx, dy = L.dy, col = cols[randi() % cols.size()]})


## Fecha o mapa: devolve o dicionário que a cidade 3D (CityBuilder) e a Mission usam.
func to_map(spawn: Vector2) -> Dictionary:
	M.lamps = lamps
	M.decor = decor
	return {tile = tile, hgt = hgt, blds = blds, lamps = lamps, trees = trees, props = props, cars = lane_cars, spawn = spawn,
		blocks = [], riq = .5, decor = decor, piers = piers, hand = true}


## Preenche um retângulo com prédios em grade irregular (a função fill das missões em JS).
## mk(x, y, w, d) devolve o dicionário do prédio; skip(x, y) veta tiles; d_rand = tamanho extra sorteado da profundidade.
func fill(r: C.Rng, x0: int, y0: int, x1: int, y1: int, d_rand: int, prob: float, mk: Callable, skip := Callable()) -> void:
	var y := y0
	while y <= y1:
		var d := 3 + r.range_i(d_rand)
		if y + d - 1 > y1:
			break
		var x := x0
		while x <= x1:
			var w := 3 + r.range_i(4)
			if x + w - 1 > x1:
				break
			var ok := true
			if skip.is_valid():
				for yy in range(y, y + d):
					for xx in range(x, x + w):
						if skip.call(xx, yy):
							ok = false
			if ok and r.next() < prob:
				bld(mk.call(x, y, w, d))
			x += w + 1
		y += d + 1


static func pick(a: Array, r: C.Rng) -> Variant:
	return a[r.range_i(a.size())]

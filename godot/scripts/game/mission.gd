## Estado de uma missão (porte de M em v2/js): mapa, unidades, grade de caminhada, visão e caminhos,
## e a população inicial gerada para cada tipo de missão (parte de genMission em world.js).
class_name Mission
extends RefCounted

const N := C.N
const T := C.T

var map: Dictionary
var tile: PackedByteArray
var walk: PackedByteArray
var tipo := "eliminacao"
var dif := 3
var riq := .5
var units: Array[Unit] = []
var agents: Array[Unit] = []
var sel: Array[Unit] = []
var drops: Array = []     # {x, y, t}
var nades: Array = []     # {sx, sy, tx, ty, t, T, src, wt}
var terms: Array = []     # {x, y, prog, done}
var cars: Array = []
var props: Array = []     # barris explosivos {x, y, hp, dead}
var spawn := Vector2()
var evac = null
var escape = null
var vip: Unit = null
var sci: Unit = null
var t := 0.0
var police_aggro := 0.0
var last_seen = null
var corp_alert := false
var reinf_t := 20.0
var followers := 0
var ended := false
var win := false
var reason := ""
var end_t := 0.0
var last_combat := -99.0
var stats := {abates = 0, civis = 0, policiais = 0, seguidores = 0}
var fires: Array = []     # {x, y, life, tick, src}
var rival_seen: Array = []
var rival_dead: Array = []
var rival_esc: Array = []
var revolta := false
var astar := AStarGrid2D.new()
# missões feitas à mão
var hand := false
var def_name := ""
var flags := {}
var ex := {}              # dados livres do roteiro (reatores, candidatos, célula...)
var objs: Array = []      # {id, text, primary, state}
var timer = null          # {label, end}
var bonus: Array = []     # {text, val}
var cams: Array = []      # {x, y, base, a, sweep, spd, ph, fov, range, see, dead, off, strict, spot}
var lasers: Array = []    # {x1, y1, x2, y2, off, on, per, ph, duty, trip_t, dmg, sweep}
var vents: Array = []     # {x, y, per, dur, ph, r, dmg, state}
var lamps: Array = []     # dicionários do mapa (compartilhados com a cidade 3D)
var decor: Array = []
var rail = null
var train = null
var train_t := 12.0
var glass_n := 0
var glass_q: Array = []
var falling: Array = []
var drop_point = null
var vent_over := 0.0
var vent_src: Unit = null
var evacs: Array = []
var esc_car = null
var revealed := 0
var cine := false
var cine_skip := false
var cam_goal = null       # {p: Vector2, z, dur, t}
var events: Array = []    # avisos para a cena 3D (prédio destruído, vidro quebrado, poste apagado...)
var uid := 0
var rng := C.Rng.new(1)


func setup(m: Dictionary, mission_type: String, difficulty: int, seed: int) -> void:
	map = m
	tile = m.tile
	tipo = mission_type
	dif = difficulty
	riq = m.riq
	rng = C.Rng.new(seed * 977 + 13)
	walk = PackedByteArray()
	walk.resize(N * N)
	for i in N * N:
		var tt: int = tile[i]
		walk[i] = 0 if (tt == T.BLD or tt == T.TREE or tt == T.WATER or tt == T.FENCE or tt == T.POST or tt == T.GLASS) else 1
	astar.region = Rect2i(0, 0, N, N)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for yy in N:
		for xx in N:
			astar.set_point_solid(Vector2i(xx, yy), walk[yy * N + xx] == 0)
	spawn = m.spawn
	for pr in m.props:
		props.append({x = pr.x, y = pr.y, hp = 20.0, dead = false})
	# tráfego: os carros das faixas viram veículos da simulação (mão direita, como na cidade 3D)
	if m.get("dyn_cars", false):
		for c in m.cars:
			var col: Color = c.col
			var h := C.hash01(c.x * C.TILE, c.y * C.TILE, 31.0)
			var model := "sedan"
			if col == Color("#e0a020"):
				model = "taxi"
			elif h < .3:
				model = "hatch"
			elif h < .45:
				model = "van"
			elif h < .52:
				model = "police"
				col = Color("#e8e8e8")
			var dx: float = -c.dx
			var dy: float = -c.dy
			cars.append({x = c.x, y = c.y, ang = atan2(dy, dx), dx = dx, dy = dy, cur = 0.0, v = 2.6 + rng.next() * 1.4, hp = 120.0, dead = false,
				col = col, occ = [], path = [], pi = 0, scripted = false, player = false, model = model, smoke_t = 0.0, held = 0.0, stop_t = 0.0, honked = false})


var road_astar: AStarGrid2D

## Caminho pelas ruas (só tiles de rua) para o carro dirigido pelo esquadrão.
func road_path(sx: float, sy: float, tx: float, ty: float) -> Array:
	if road_astar == null:
		road_astar = AStarGrid2D.new()
		road_astar.region = Rect2i(0, 0, N, N)
		road_astar.cell_size = Vector2.ONE
		road_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		road_astar.update()
		for yy in N:
			for xx in N:
				road_astar.set_point_solid(Vector2i(xx, yy), tile[yy * N + xx] != T.ROAD)
	var near := func(px: float, py: float) -> Vector2i:
		var best := Vector2i(-1, -1)
		var bd := 1e9
		for r in range(0, 12):
			for yy in range(int(py) - r, int(py) + r + 1):
				for xx in range(int(px) - r, int(px) + r + 1):
					if xx < 0 or yy < 0 or xx >= N or yy >= N or tile[yy * N + xx] != T.ROAD:
						continue
					var d := Vector2(xx + .5 - px, yy + .5 - py).length_squared()
					if d < bd:
						bd = d
						best = Vector2i(xx, yy)
			if best.x >= 0:
				return best
		return best
	var a: Vector2i = near.call(sx, sy)
	var b: Vector2i = near.call(tx, ty)
	if a.x < 0 or b.x < 0:
		return []
	var ids := road_astar.get_id_path(a, b)
	var out := []
	for i in range(1, ids.size()):
		out.append(Vector2(ids[i].x + .5, ids[i].y + .5))
	return out


# ---------------------------------------------------------------- grade
func walk_at(px: float, py: float) -> bool:
	if px < 0 or py < 0 or px >= N or py >= N:
		return false
	return walk[int(py) * N + int(px)] == 1


func can_stand(px: float, py: float, r := .2) -> bool:
	return walk_at(px - r, py - r) and walk_at(px + r, py - r) and walk_at(px - r, py + r) and walk_at(px + r, py + r)


func los(ax: float, ay: float, bx: float, by: float) -> bool:
	var dx := bx - ax
	var dy := by - ay
	var n := int(ceil(sqrt(dx * dx + dy * dy) / .2))
	for k in range(1, n):
		var f := float(k) / n
		var xi := int(ax + dx * f)
		var yi := int(ay + dy * f)
		if xi < 0 or yi < 0 or xi >= N or yi >= N:
			return false
		if tile[yi * N + xi] == T.BLD:
			return false
	return true


func _line_ok(a: Vector2, b: Vector2, r: float) -> bool:
	var d := a.distance_to(b)
	var n := int(ceil(d / .25))
	for k in range(1, n + 1):
		var p := a.lerp(b, float(k) / n)
		if not can_stand(p.x, p.y, r):
			return false
	return true


func nearest_walk(xi: int, yi: int) -> Vector2i:
	for r in 10:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var X := xi + dx
				var Y := yi + dy
				if X >= 0 and Y >= 0 and X < N and Y < N and walk[Y * N + X]:
					return Vector2i(X, Y)
	return Vector2i(-1, -1)


## Caminho em tiles (A* nativo) suavizado por linha de visão, como findPath do JS.
func find_path(sx: float, sy: float, tx: float, ty: float, rad := .2) -> Array:
	var ti := Vector2i(clampi(int(tx), 0, N - 1), clampi(int(ty), 0, N - 1))
	var exact := true
	if not walk[ti.y * N + ti.x]:
		ti = nearest_walk(ti.x, ti.y)
		exact = false
		if ti.x < 0:
			return []
	var si := Vector2i(clampi(int(sx), 0, N - 1), clampi(int(sy), 0, N - 1))
	if not walk[si.y * N + si.x]:
		si = nearest_walk(si.x, si.y)
		if si.x < 0:
			return []
	var end_pt := Vector2(tx, ty) if exact and can_stand(tx, ty, rad) else Vector2(ti.x + .5, ti.y + .5)
	if si == ti:
		return [end_pt]
	var ids := astar.get_id_path(si, ti)
	if ids.is_empty():
		return []
	var pts: Array[Vector2] = []
	for k in range(1, ids.size()):
		pts.append(Vector2(ids[k].x + .5, ids[k].y + .5))
	pts[pts.size() - 1] = end_pt
	var out := []
	var cur := Vector2(sx, sy)
	var i := 0
	while i < pts.size():
		var j := mini(pts.size() - 1, i + 10)
		while j > i and not _line_ok(cur, pts[j], rad):
			j -= 1
		out.append(pts[j])
		cur = pts[j]
		i = j + 1
	return out


func path_to(u: Unit, px: float, py: float) -> bool:
	u.path = find_path(u.x, u.y, px, py)
	u.pidx = 0
	return not u.path.is_empty()


func move_along(u: Unit, dt: float, s: float) -> bool:
	if u.path.is_empty():
		u.cur_spd = 0.0
		return false
	var p: Vector2 = u.path[u.pidx]
	var dx := p.x - u.x
	var dy := p.y - u.y
	var dd := sqrt(dx * dx + dy * dy)
	var step := s * GD.SPEED * dt
	if u.aim_t <= 0 and dd > .01:
		u.face = atan2(dy, dx)
	u.cur_spd = s * GD.SPEED
	if dd <= step:
		u.x = p.x
		u.y = p.y
		u.pidx += 1
		if u.pidx >= u.path.size():
			u.path = []
	else:
		var nx := u.x + dx / dd * step
		var ny := u.y + dy / dd * step
		if can_stand(nx, ny):
			u.x = nx
			u.y = ny
		elif can_stand(nx, u.y):
			u.x = nx
		elif can_stand(u.x, ny):
			u.y = ny
		else:
			u.x = nx
			u.y = ny
			if not walk_at(u.x, u.y):
				u.x -= dx / dd * step
				u.y -= dy / dd * step
				u.path = []
	return true


func side_tile(tt: int) -> bool:
	return tt == T.WALK or tt == T.PLAZA or tt == T.GRASS


func random_near(cx: float, cy: float, r: float, pred := Callable()) -> Variant:
	for k in 20:
		var X := int(floor(cx + (randf() * 2 - 1) * r))
		var Y := int(floor(cy + (randf() * 2 - 1) * r))
		if X < 0 or Y < 0 or X >= N or Y >= N:
			continue
		if walk[Y * N + X] and (not pred.is_valid() or pred.call(tile[Y * N + X])):
			return Vector2(X + .5, Y + .5)
	return null


# ---------------------------------------------------------------- unidades
func mk_unit(kind: String, px: float, py: float) -> Unit:
	var K: Dictionary = GD.KIND[kind]
	var u := Unit.new()
	uid += 1
	u.id = uid
	u.kind = kind
	u.x = px
	u.y = py
	u.fac = K.fac
	u.hp = K.hp
	u.max_hp = K.hp
	u.armor = K.get("armor", 0.0)
	u.spd = K.spd
	u.acc = K.get("acc", .5)
	u.w = K.get("w", "")
	u.mun = GD.WD[u.w].pente if u.w != "" else 0
	u.face = randf() * TAU
	u.idle_t = randf() * 3
	u.perc_t = randf() * .3
	u.scan_t = randf() * .3
	u.hunt_t = randf() * 2
	u.seed = uid
	if kind == "civil":
		u.spd = .9 + randf() * .4
		u.hp = 25 + randf() * 10
		u.max_hp = u.hp
	if kind == "torre":
		u.mech = true
	if kind == "drone":
		u.mech = true
		u.fly = true
	units.append(u)
	return u


func arm_ai(u: Unit, d: int) -> void:
	if u.kind == "guarda":
		u.w = "pistola" if d <= 2 else ("smg" if rng.next() < .5 else ("escopeta" if d >= 5 and rng.next() < .4 else "pistola"))
		u.hp = 60 + d * 6
		u.acc = .38 + d * .025
		u.nades = 1 if d >= 6 else 0
	if u.kind == "inimigo":
		u.w = "feixe" if d >= 7 and rng.next() < .35 else ("serra" if d >= 8 and rng.next() < .35 else ("escopeta" if d >= 4 and rng.next() < .25 else "smg"))
		u.hp = 100 + d * 12
		u.acc = .5 + d * .028
		u.nades = 2 if d >= 7 else (1 if d >= 4 else 0)
	u.max_hp = u.hp
	u.mun = GD.WD[u.w].pente


## Agente do esquadrão. ag é a lista de itens (testes) ou o agente da campanha, com implantes.
func mk_agent(k: int, px: float, py: float, ag) -> Unit:
	var u := mk_unit("agente", px, py)
	u.nome = GD.CODINOMES[k]
	u.num = k + 1
	u.hp = 150
	u.max_hp = 150
	u.armor = .08
	u.acc = .75
	u.inv = []
	var inv: Array = []
	if ag is Dictionary:
		u.ag = ag
		u.nome = ag.nome
		var im: Dictionary = ag.imp
		u.max_hp = 150 + 45 * im.chassi
		u.hp = u.max_hp
		u.armor = .08 + .07 * im.chassi + (.1 if Camp.has("blindagem") else 0.0)
		u.spd *= 1 + .12 * im.motor
		u.acc = .75 + .08 * im.otica
		u.rng_mul = 1 + .08 * im.otica
		for q in ag.inv:
			inv.append(q.t)
	else:
		inv = ag
	if ag is Dictionary:
		u.max_estab = maxf(40, 100 - ag.get("dep", 0))
		u.estab = u.max_estab
	var pm := 1.5 if Camp.has("pentes") else 1.0
	for it in inv:
		u.inv.append({t = it, mun = roundi(GD.WD[it].get("pente", 0) * pm)})
	u.eq = -1
	for i in u.inv.size():
		if GD.WD[u.inv[i].t].get("arma", false):
			u.eq = i
			break
	u.face = PI * .25
	agents.append(u)
	return u


func _rand_tile(pred: Callable, cx := -1.0, cy := -1.0, r := 0.0, tries := 300) -> Variant:
	for k in tries:
		var X: int
		var Y: int
		if cx < 0:
			X = int(rng.next() * N)
			Y = int(rng.next() * N)
		else:
			X = int(floor(cx + (rng.next() * 2 - 1) * r))
			Y = int(floor(cy + (rng.next() * 2 - 1) * r))
		if X < 0 or Y < 0 or X >= N or Y >= N:
			continue
		if pred.call(tile[Y * N + X], X, Y):
			return Vector2(X + .5, Y + .5)
	return null


## População da missão procedural (genMission): alvo, guardas, torretas, inimigos, polícia e civis.
func populate(squad_inv: Array) -> void:
	var comps: Array = map.blocks.filter(func(b): return b.type == "comp")
	var is_side := func(tt, _x, _y): return tt == T.WALK or tt == T.PLAZA or tt == T.GRASS
	var far := func(tt, X, Y): return (tt == T.WALK or tt == T.PLAZA or tt == T.GRASS) and Vector2(X, Y).distance_to(spawn) > 16
	if not comps.is_empty():
		var c1: Vector2 = comps[0].court
		match tipo:
			"assassinato":
				var v := mk_unit("vip", c1.x, c1.y)
				v.nome = GD.VIPS[int(rng.next() * GD.VIPS.size())]
				v.route = [c1]
				for k in 2:
					var p = _rand_tile(func(tt, X, Y): return is_side.call(tt, X, Y) and Vector2(X, Y).distance_to(c1) > 7, c1.x, c1.y, 15)
					if p != null:
						v.route.append(p)
				vip = v
				var cs := [Vector2(1, 1), Vector2(C.NB * C.P + 1, 1), Vector2(1, C.NB * C.P + 1), Vector2(C.NB * C.P + 1, C.NB * C.P + 1)]
				cs = cs.filter(func(c): return c != spawn)
				cs.sort_custom(func(a, b): return a.distance_to(c1) > b.distance_to(c1))
				escape = cs[0]
				for k in 2:
					var g := mk_unit("guarda", c1.x + (.8 if k else -.8), c1.y + .6)
					g.escort = v
					arm_ai(g, dif)
			"extracao":
				var s := mk_unit("cientista", c1.x, c1.y + 1)
				s.nome = GD.CIENT[int(rng.next() * GD.CIENT.size())]
				sci = s
				evac = spawn
			"sabotagem":
				var cA: Dictionary = comps[0]
				var cB: Dictionary = comps[min(1, comps.size() - 1)]
				var a0 := Vector2(cA.ox + 1, cA.oy + 1)
				var b0 := Vector2(cB.ox + 1, cB.oy + 1)
				terms.append({x = a0.x + 1.5, y = a0.y + 4.5, prog = 0.0, done = false})
				terms.append({x = a0.x + 5.5, y = a0.y + 4.5, prog = 0.0, done = false})
				terms.append({x = b0.x + 3.5, y = b0.y + 5.8, prog = 0.0, done = false})
		var nG := 3 + dif
		for k in nG:
			var c: Vector2 = comps[k % comps.size()].court
			var p = _rand_tile(func(tt, _x, _y): return tt == T.PLAZA or tt == T.WALK, c.x, c.y, 4)
			if p == null:
				p = c
			var g := mk_unit("guarda", p.x, p.y)
			g.home = p
			arm_ai(g, dif)
		var nT := int(dif / 2.0)
		for k in mini(nT, 4):
			var cp: Dictionary = comps[0]
			var tp: Vector2 = [Vector2(cp.ox + 1, cp.oy + 7), Vector2(cp.ox + 7, cp.oy + 7), Vector2(cp.ox + 1, cp.oy + 4), Vector2(cp.ox + 7, cp.oy + 4)][k]
			mk_unit("torre", tp.x + .5, tp.y + .5)
	var nE := ((2 + int(ceil(dif / 3.0))) if revolta else (2 + int(ceil(dif / 2.0)))) if tipo == "eliminacao" else maxi(0, int((dif - 1) / 2.0))
	for k in nE:
		var p = _rand_tile(far)
		if p == null:
			continue
		var e := mk_unit("inimigo", p.x, p.y)
		e.home = p
		arm_ai(e, dif)
	for k in 2 + int(dif / 2.0):
		var p = _rand_tile(func(tt, _x, _y): return tt == T.WALK)
		if p != null:
			mk_unit("policia", p.x, p.y)
	for k in 30 + roundi(riq * 16) + (22 if revolta else 0):
		var p = _rand_tile(is_side)
		if p != null:
			mk_unit("civil", p.x, p.y)
	spawn_squad(squad_inv)


func spawn_squad(squad_inv: Array) -> void:
	var offs := [Vector2(-.5, -.5), Vector2(.5, -.5), Vector2(-.5, .5), Vector2(.5, .5)]
	for k in squad_inv.size():
		mk_agent(k, spawn.x + offs[k].x, spawn.y + offs[k].y, squad_inv[k])


func objective_text() -> String:
	match tipo:
		"assassinato": return "Elimine %s antes que ele chegue ao transporte." % vip.nome if vip else "Elimine o alvo."
		"extracao": return ("Encontre %s e leve-%s de volta ao ponto de entrada." % [sci.nome, "a" if sci.fem() else "o"]) if sci else "Extraia o cientista."
		"sabotagem": return "Invada os terminais do Consórcio (%d/%d)." % [terms.filter(func(q): return q.done).size(), terms.size()]
		_: return ("Elimine os agitadores do Consórcio (%d restantes)." if revolta else "Elimine os agentes do Consórcio (%d restantes).") % units.filter(func(u): return u.kind == "inimigo" and not u.dead and not u.follower).size()

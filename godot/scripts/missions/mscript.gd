## API do roteiro das missões feitas à mão (o objeto "S" de v2/js/script.js).
## No JS os roteiros eram geradores; aqui são corrotinas do GDScript: "await S.wait(2)", "await S.until(func(): ...)".
## Uma corrotina chamada sem await roda em paralelo (era o S.fork do JS).
class_name MS
extends RefCounted

signal tick

var M: Mission
var sim: Sim
var game


func _init(m: Mission, s: Sim, g) -> void:
	M = m
	sim = s
	game = g


func _skip(c: bool) -> bool:
	return c and M.cine_skip


## Como no JS, toda espera cede pelo menos um passo da simulação (senão um laço de roteiro travaria o jogo).
func wait(s: float) -> void:
	var t0 := M.t
	var c := M.cine
	await tick
	while M.t - t0 < s and not _skip(c):
		await tick


func until(f: Callable) -> void:
	await tick
	while not f.call():
		await tick


func say(key: String, _u = null) -> void:
	if not (M.cine and M.cine_skip):
		game.say(key)


func talk_done() -> void:
	var c := M.cine
	await tick
	while game.talking() and not _skip(c):
		await tick


func cine(on: bool) -> void:
	M.cine = on
	M.cine_skip = false
	if not on:
		M.cam_goal = null


func cam_to(p: Vector2, z: float, dur: float) -> void:
	M.cam_goal = {p = p, z = z, dur = dur, t = 0.0, from = null}
	var c := M.cine
	await tick
	while M.cam_goal != null and M.cam_goal.t < dur and not _skip(c):
		await tick


func obj(id: String, text: String, primary := false) -> void:
	M.objs.append({id = id, text = text, primary = primary, state = "active"})


func set_obj(id: String, patch: Dictionary) -> void:
	for o in M.objs:
		if o.id == id:
			o.merge(patch, true)


func obj_state(id: String) -> String:
	for o in M.objs:
		if o.id == id:
			return o.state
	return ""


func timer(label: String, s: float) -> void:
	M.timer = {label = label, end = M.t + s}


func clear_timer() -> void:
	M.timer = null


func timer_done() -> bool:
	return M.timer == null or M.t >= M.timer.end


func spawn(kind: String, x: float, y: float, dif := 0) -> Unit:
	var u := M.mk_unit(kind, x, y)
	if dif > 0 and u.w != "":
		M.arm_ai(u, dif)
	sim.fx.emit("spawn", {u = u})
	return u


func car(x: float, y: float, ang: float, col: String, hp := 120.0, model := "sedan") -> Dictionary:
	return sim.add_car(x, y, ang, Color(col), hp, model)


func drive(c: Dictionary, pts: Array) -> void:
	c.path = pts.map(func(p): return Vector2(p[0], p[1]) if p is Array else p)
	c.pi = 0


func arrived(c: Dictionary) -> Callable:
	return func(): return c.dead or (c.path.is_empty() and c.cur < .4)


func walk(u: Unit, x: float, y: float) -> void:
	M.path_to(u, x, y)


func win(reason: String) -> void:
	sim.end_mission(true, reason)


func fail(reason: String) -> void:
	sim.end_mission(false, reason)


func bonus(text: String, val: int) -> void:
	M.bonus.append({text = text, val = val})


func note(m: String, c := "") -> void:
	sim.say_log(m, c)


func rival(id: String, x: float, y: float, hp_mul := 1.0) -> Unit:
	if Camp.rival_dead(id):
		return null
	var u := sim.spawn_rival(id, x, y)
	if u:
		u.alerted = true
		u.max_hp = roundf(u.max_hp * hp_mul)
		u.hp = u.max_hp
	return u


func lamp_off(l: Dictionary) -> void:
	l.dead = true
	M.events.append({k = "lamp", l = l})


func block(x0: int, y0: int, x1: int, y1: int, on: bool) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i := y * C.N + x
			M.tile[i] = C.T.BLD if on else C.T.PLAZA
			M.walk[i] = 0 if on else 1
			M.astar.set_point_solid(Vector2i(x, y), on)
	M.events.append({k = "block", x0 = x0, y0 = y0, x1 = x1, y1 = y1, on = on})


func boom(x: float, y: float, r: float, dmg: float) -> void:
	sim.explode(x, y, r, dmg, null)


func breach(b: Dictionary) -> void:
	if not b.get("dead", false):
		sim.explode(b.x + b.w / 2.0, b.y + b.d / 2.0, 1.6, 40, null)
		sim.destroy_bld(b)


func alarm() -> void:
	var a: Unit = null
	for q in M.agents:
		if not q.dead:
			a = q
			break
	for u in M.units:
		if not u.dead and u.fac == "corp" and not u.alerted and not u.disguise and not u.cand:
			if a:
				sim.alert_corp(u, a.x, a.y)
			break
	M.corp_alert = true
	for u in M.units:
		if not u.dead and u.fac == "corp" and not u.disguise and not u.cand:
			u.alerted = true
			if a:
				u.lkp = a.pos2()


## Todos os agentes vivos perto de p (para os objetivos de extração).
func squad_at(p: Vector2, r: float) -> bool:
	var al := M.agents.filter(func(a): return not a.dead)
	return not al.is_empty() and al.all(func(a): return Vector2(a.x - p.x, a.y - p.y).length() < r)

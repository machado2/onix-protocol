## "Doca dos Dirigíveis", Cais Aéreo (porte de v2/js/missions/doca.js).
## Terminal aéreo em terra, três píeres sobre a baía. O dirigível de carga parte em 4 minutos;
## no último minuto a célula corre para a prancha de embarque.
class_name MDoca

const T := C.T
const NOME := "Doca dos Dirigíveis"
const SPAWN := Vector2(2.5, 53.5)
const GANG := Vector2(45, 19.5)
const DEPART := 240.0
const SIGNS := ["HOTEL", "CÂMBIO", "BAR", "PEÇAS", "LOJA FRANCA"]


static func _fill(B: MB, r: C.Rng, x0: int, y0: int, x1: int, y1: int) -> void:
	B.fill(r, x0, y0, x1, y1, 3, .88, func(x, y, w, d): return {x = x, y = y, w = w, d = d, fl = 3 + r.range_i(6), pal = r.range_i(4), v = r.range_i(4),
		neon = r.range_i(4) if r.next() < .4 else -1, sign = MB.pick(SIGNS, r) if r.next() < .3 else "", signCol = MB.pick(["#38e8ff", "#ffb13d", "#ff3d8b"], r), roof = r.range_i(3)})


static func build(B: MB) -> void:
	var r := C.Rng.new(8181)
	B.rect(T.WATER, 0, 0, 56, 56)
	B.rect(T.WALK, 0, 0, 21, 56)
	B.rect(T.WALK, 0, 41, 56, 56)
	B.rect(T.ROAD, 0, 47, 56, 48)
	B.rect(T.ROAD, 4, 0, 5, 46)
	B.bld({x = 8, y = 5, w = 12, d = 11, fl = 6, pal = 2, v = 1, neon = 1, sign = "TERMINAL AÉREO", signCol = "#38e8ff"})
	B.rect(T.PLAZA, 7, 17, 20, 39)
	for p in [[10, 22], [16, 22], [10, 30], [16, 30]]:
		B.bld({x = p[0], y = p[1], w = 1, d = 1, fl = 1, pal = 5, neon = (p[0] + p[1]) % 4, kiosk = true})
	B.bld({x = 24, y = 41, w = 10, d = 5, fl = 3, style = "ware", sign = "HANGAR 2", signCol = "#ffb13d"})
	B.bld({x = 38, y = 41, w = 10, d = 5, fl = 3, style = "ware", sign = "CARGA AÉREA", signCol = "#38e8ff"})
	_fill(B, r, 8, 50, 56, 56)
	_fill(B, r, 8, 0, 20, 3)
	B.pier(22, 6, 24, 40)
	B.pier(25, 7, 50, 10)
	B.pier(25, 19, 54, 22)
	B.pier(25, 31, 50, 34)
	var cont := [[28, 8, 3, 1, 2], [34, 9, 3, 1, 1], [42, 8, 3, 1, 2], [28, 20, 3, 1, 1], [34, 21, 2, 1, 2], [49, 21, 2, 1, 1], [28, 32, 3, 1, 2], [37, 33, 3, 1, 1], [44, 32, 2, 1, 3]]
	for i in cont.size():
		var c: Array = cont[i]
		B.bld({x = c[0], y = c[1], w = c[2], d = c[3], fl = c[4], style = "cont", col = i % 6})
	B.set_tile(54, 20, T.POST)
	B.add_decor({type = "airship", x = 43, y = 14.5, h = 6.5, len = 15, text = "HÉLICE CARGA", col = "#ff3d5a", mx = 54.5, my = 20.5})
	B.add_decor({type = "pipe", x1 = GANG.x, y1 = 19.2, x2 = GANG.x, y2 = 15.6, h = 3.6, r = .3, col = "#3a404e"})
	B.term({x = 53.4, y = 21.6, flag = "amarras", msg = "Amarras travadas: o dirigível não pode partir."})
	for p in [[52.5, 19.5], [49.5, 33.5]]:
		B.unit("torre", p[0], p[1]).acc = .4
	for x in range(26, 52, 6):
		B.lamp(x + .5, 7.3, "#cfe8ff")
		B.lamp(x + .5, 19.3, "#cfe8ff")
		B.lamp(x + 2.5, 22.7, "#7fe3ff")
		B.lamp(x + .5, 31.3, "#cfe8ff")
	for y in range(8, 40, 7):
		B.lamp(21.6, y + .5, "#ffcf7a", true)
	for p in [[8, 18], [19, 18], [8, 38], [19, 38], [13.5, 27]]:
		B.lamp(p[0], p[1], "#ffd99a")
	for x in range(2, 56, 8):
		B.lamp(x + .5, 46.4, "#ffcf7a")
	for p in [[26, 9.5], [31, 21.6], [40, 31.6], [23, 40]]:
		B.prop(p[0], p[1])
	B.cam(21.4, 12.4, 0, {sweep = .7})
	B.cam(21.4, 28.4, 0, {sweep = .7})
	for p in [[30, 21.6], [41, 21.6], [23.5, 14], [33, 7.6]]:
		var e := B.unit("inimigo", p[0], p[1])
		B.arm(e, 6)
		e.home = Vector2(p[0], p[1])
		e.tags.cell = true
	for p in [[39, 21.6], [47, 21.4]]:
		var h := B.heavy(p[0], p[1], 6)
		h.home = Vector2(p[0], p[1])
		h.acc = .3
		h.hp = 340
		h.max_hp = 340
		h.tags.cell = true
	for p in [[19.5, 21], [19.5, 33], [30, 33.6], [38, 9.6]]:
		var g := B.unit("guarda", p[0], p[1])
		B.arm(g, 6)
		g.home = Vector2(p[0], p[1])
	for p in [[12, 45.6], [30, 45.6], [5.5, 30]]:
		B.unit("policia", p[0], p[1])
	for k in 26:
		var p = B.rand_tile(func(t, x, y): return t == T.PLAZA and x >= 7 and x <= 20 and y >= 17)
		if p != null:
			B.unit("civil", p.x, p.y).home = p
	for k in 8:
		var p = B.rand_tile(func(t, x, _y): return t == T.PLAZA and x > 24)
		if p != null:
			var u := B.unit("civil", p.x, p.y)
			u.tags.worker = true
			u.home = p
	for k in 10:
		var p = B.rand_tile(func(t, _x, y): return t == T.WALK and y >= 49)
		if p != null:
			B.unit("civil", p.x, p.y)
	B.lanes([{y = 47.5, dx = 1, dy = 0}, {y = 48.5, dx = -1, dy = 0}], 7)


static func cell(M: Mission) -> Array:
	return M.units.filter(func(u): return u.tags.get("cell", false))


static func alive(M: Mission) -> Array:
	return cell(M).filter(func(u): return not u.dead and not u.follower)


static func run(S: MS, M: Mission) -> void:
	S.obj("kill", "Elimine a célula do Consórcio (0/6)", true)
	S.obj("moor", "Opcional: trave as amarras do dirigível (ponta do píer central)")
	watch_kills(S, M)
	watch_moor(S, M)
	watch_heavy(S, M)
	S.cine(true)
	await S.cam_to(SPAWN, 1.2, .01)
	await S.wait(.6)
	S.say("ctl:m8_intro1")
	await S.cam_to(Vector2(40, 17), .9, 3.2)
	await S.talk_done()
	S.say("ctl:m8_intro2")
	await S.cam_to(GANG, 1.2, 2.4)
	await S.talk_done()
	S.say("ctl:m8_intro3")
	await S.cam_to(Vector2(52, 20.5), 1.15, 2.2)
	await S.talk_done()
	await S.cam_to(SPAWN, 1.2, 1.8)
	S.cine(false)
	watch_departure(S, M)


static func watch_kills(S: MS, M: Mission) -> void:
	var last := -1
	while true:
		var dead := cell(M).filter(func(u): return (u.dead and not u.vanished) or u.follower).size()
		if dead != last:
			last = dead
			S.set_obj("kill", {text = "Elimine a célula do Consórcio (%d/6)" % dead})
		if M.flags.get("escaped", 0):
			S.say("ctl:m8_fail")
			S.fail("Um agente da célula embarcou no dirigível.")
			return
		if dead >= 6:
			break
		await S.wait(.3)
	S.set_obj("kill", {state = "done"})
	S.clear_timer()
	S.say("ctl:m8_win")
	S.win("A célula do Consórcio no Cais Aéreo foi eliminada.")


static func watch_departure(S: MS, M: Mission) -> void:
	S.timer("DIRIGÍVEL PARTE EM", DEPART)
	await S.until(func(): return M.flags.get("amarras", false) or M.ended or (M.timer != null and M.t >= M.timer.end - 60))
	if M.flags.get("amarras", false) or M.ended:
		return
	S.say("ctl:m8_board")
	S.note("A célula está correndo para a prancha de embarque!", "red")
	for u in alive(M):
		u.flee_to = GANG + Vector2((randf() - .5) * .6, .4)
		u.path = []
		u.alerted = true
	for id in ["navalha", "mariposa", "sibila"]:
		var riv := S.rival(id, 23.5, 20.5, .85)
		if riv:
			S.obj("riv", "Opcional: elimine %s" % riv.nome)
			watch_rival(S, riv)
			break
	await S.until(func(): return M.flags.get("amarras", false) or M.ended or S.timer_done())
	if M.flags.get("amarras", false) or M.ended:
		return
	S.clear_timer()
	M.flags.airshipGo = true
	if S.obj_state("moor") == "active":
		S.set_obj("moor", {state = "failed"})
	for u in cell(M):
		if u.flee_to != null:
			u.flee_to = null
			u.path = []
	S.say("ctl:m8_gone")
	S.note("O dirigível partiu sem a célula.", "amber")


static func watch_moor(S: MS, M: Mission) -> void:
	await S.until(func(): return M.flags.get("amarras", false))
	if not M.flags.get("airshipGo", false):
		S.clear_timer()
		S.set_obj("moor", {state = "done"})
		S.bonus("Dirigível retido no cais", 1000)
		S.say("ctl:m8_moor")
		for u in cell(M):
			if u.flee_to != null:
				u.flee_to = null
				u.path = []


static func watch_heavy(S: MS, M: Mission) -> void:
	await S.until(func(): return cell(M).any(func(u): return u.heavy and u.contact))
	S.say("ctl:m8_heavy")


static func watch_rival(S: MS, riv: Unit) -> void:
	await S.until(func(): return riv.dead)
	S.set_obj("riv", {state = "failed" if riv.vanished else "done"})

## "Torre Central", missão final (porte de v2/js/missions/torre.js).
## Praça fortificada diante da torre com portão blindado; átrio entre as alas com o Juiz e dois pilares de escudo;
## sala dos servidores do andar 90 atrás de uma segunda porta.
class_name MTorre

const T := C.T
const NOME := "Torre Central"
const SPAWN := Vector2(28, 54)
const RIVAL_POS := {navalha = [18.5, 24], sibila = [38, 24.5], ferro = [22, 13], mariposa = [34, 13]}


static func build(B: MB) -> void:
	var r := C.Rng.new(9999)
	B.rect(T.WALK, 0, 0, 56, 56)
	B.rect(T.ROAD, 0, 50, 56, 51)
	B.rect(T.ROAD, 2, 0, 3, 49)
	B.rect(T.ROAD, 53, 0, 54, 49)
	B.rect(T.PLAZA, 6, 30, 50, 48)
	var corp := {pal = 4, corp = true, ant = true, neon = 0}
	var cb := func(o: Dictionary) -> Dictionary:
		var d: Dictionary = corp.duplicate()
		d.merge(o, true)
		return B.bld(d)
	cb.call({x = 6, y = 1, w = 45, d = 3, fl = 22, v = 1, sign = "HÉLICE", signCol = "#ff3d5a"})
	cb.call({x = 6, y = 4, w = 10, d = 23, fl = 18, v = 2, sign = "TORRE CENTRAL", signCol = "#ff3d5a"})
	cb.call({x = 41, y = 4, w = 10, d = 23, fl = 18, v = 3})
	cb.call({x = 6, y = 27, w = 20, d = 3, fl = 7, v = 1, sign = "CONSÓRCIO HÉLICE", signCol = "#ff3d5a"})
	cb.call({x = 31, y = 27, w = 20, d = 3, fl = 7, v = 2})
	var wall := func(x, y, w, d): return B.bld({x = x, y = y, w = w, d = d, fl = 1, style = "wall", kiosk = true})
	B.M.ex.door = wall.call(26, 27, 5, 3)
	B.rect(T.PLAZA, 16, 4, 40, 26)
	wall.call(16, 10, 10, 1)
	wall.call(31, 10, 10, 1)
	B.M.ex.srv_door = wall.call(26, 10, 5, 1)
	for p in [[20, 21], [36, 21], [24, 16], [32, 16]]:
		cb.call({x = p[0], y = p[1], w = 1, d = 1, fl = 9, v = 0})
	for y in [5, 8]:
		for x in [18, 20, 22, 24, 32, 34, 36, 38]:
			B.bld({x = x, y = y, w = 1, d = 1, fl = 1, pal = 5, kiosk = true, neon = 1})
	B.term({x = 28.5, y = 6.5, flag = "srv", msg = "Servidores do andar 90 sob controle da Ônix."})
	for p in [[19.5, 13.5], [36.5, 13.5]]:
		var u := B.unit("torre", p[0], p[1])
		u.pylon = true
		u.hp = 150
		u.max_hp = 150
		u.armor = .35
		u.acc = .45
	B.M.ex.sweep = B.laser(16.1, 12, 39.9, 12, {off = true, dmg = 45.0, sweep = {ax = "y", a = 11.6, b = 25.4, spd = 2.6}})
	for q in [[14, 40, 3, 1], [22, 37, 3, 1], [31, 37, 3, 1], [39, 40, 3, 1], [18, 44, 2, 1], [36, 44, 2, 1], [26, 42, 4, 1], [12, 34, 2, 1], [42, 34, 2, 1]]:
		wall.call(q[0], q[1], q[2], q[3])
	B.term({x = 7.6, y = 31.4, flag = "sec1", msg = "Terminal de segurança oeste invadido."})
	B.term({x = 49.4, y = 31.4, flag = "sec2", msg = "Terminal de segurança leste invadido."})
	for p in [[44, 31.5], [23.5, 31.4], [33.5, 31.4]]:
		B.unit("torre", p[0], p[1]).acc = .5
	for p in [[26.5, 32.5], [30.5, 32.5]]:
		var h := B.heavy(p[0], p[1], 9)
		h.acc = .3
		h.hp = 340
		h.max_hp = 340
		h.home = Vector2(p[0], p[1])
	for p in [[10, 38], [46, 38], [20, 34], [36, 34], [28, 39.5], [16, 46.5], [40, 46.5], [20, 6.5], [36, 6.5]]:
		var g := B.unit("guarda", p[0], p[1])
		B.arm(g, 9)
		g.home = Vector2(p[0], p[1])
	B.drone(8, 32.5, [[8, 32.5], [48, 32.5]], 9)
	B.drone(46, 45, [[46, 45], [10, 45]], 9)
	B.cam(6.6, 47.4, -PI / 4, {sweep = .7})
	B.cam(49.4, 47.4, -3 * PI / 4, {sweep = .7})
	B.fill(r, 5, 52, 51, 56, 2, .9, func(x, y, w, d): return {x = x, y = y, w = w, d = d, fl = 4 + r.range_i(8), pal = r.range_i(4), v = r.range_i(4),
		neon = r.range_i(4) if r.next() < .5 else -1, sign = MB.pick(["HOTEL", "BANCO", "CLÍNICA", "BAR"], r) if r.next() < .25 else "", signCol = MB.pick(["#38e8ff", "#ffb13d", "#ff3d8b"], r), roof = r.range_i(3)},
		func(x, _y): return x >= 24 and x <= 32)
	for x in range(8, 50, 7):
		B.lamp(x + .5, 30.6, "#ff3d5a", true)
		B.lamp(x + .5, 48.4, "#cfe8ff", true)
	for p in [[16.6, 12], [39.4, 12], [16.6, 25.4], [39.4, 25.4], [28, 20]]:
		B.lamp(p[0], p[1], "#ff3d5a", true)
	for p in [[17, 4.6], [39.4, 4.6], [28, 9.4]]:
		B.lamp(p[0], p[1], "#38e8ff")
	for p in [[20, 40], [36, 40], [28, 46]]:
		B.prop(p[0], p[1])
	for k in 12:
		var p = B.rand_tile(func(t, _x, y): return t == T.WALK and y >= 49)
		if p != null:
			B.unit("civil", p.x, p.y)
	B.lanes([{y = 50.5, dx = 1, dy = 0}, {y = 51.5, dx = -1, dy = 0}], 6)


static func run(S: MS, M: Mission) -> void:
	S.obj("gate", "Invada os dois terminais de segurança da praça (0/2)", true)
	watch_gate(S, M)
	S.cine(true)
	await S.cam_to(SPAWN, 1.2, .01)
	await S.wait(.6)
	S.say("ctl:m9_intro1")
	await S.cam_to(Vector2(28, 38), .8, 3.2)
	await S.talk_done()
	S.say("ctl:m9_intro2")
	await S.cam_to(Vector2(28, 28), 1.0, 2.4)
	await S.talk_done()
	S.say("ctl:m9_intro3")
	await S.cam_to(Vector2(28, 15), .85, 2.6)
	await S.talk_done()
	await S.cam_to(SPAWN, 1.2, 1.8)
	S.cine(false)


static func watch_gate(S: MS, M: Mission) -> void:
	var last := -1
	while true:
		var n := (1 if M.flags.get("sec1", false) else 0) + (1 if M.flags.get("sec2", false) else 0)
		if n != last:
			last = n
			S.set_obj("gate", {text = "Invada os dois terminais de segurança da praça (%d/2)" % n})
			if n == 1:
				S.say("ctl:m9_term")
		if n >= 2:
			break
		await S.wait(.3)
	S.set_obj("gate", {state = "done"})
	S.say("ctl:m9_breach")
	S.breach(M.ex.door)
	await S.wait(.4)
	boss(S, M)


static func boss(S: MS, M: Mission) -> void:
	var j := S.rival("juiz", 28.5, 16)
	if j == null:
		return
	j.hp = 520
	j.max_hp = 520
	j.acc = .75
	j.boss = true
	j.shield = true
	j.home = Vector2(28.5, 18.5)
	rival_waves(S, M, j)
	S.obj("juiz", "Elimine o Juiz", true)
	S.obj("pyl", "Derrube os pilares de escudo do átrio (0/2)")
	S.say("ctl:m9_juiz")
	watch_pylons(S, M, j)
	_rivals_line(S)
	await S.until(func(): return j.dead or j.hp <= j.max_hp * .66)
	if not j.dead:
		S.say("ctl:m9_reinf")
		var h := S.spawn("inimigo", 17.0 if randf() < .5 else 39.5, 12, 9)
		h.heavy = true
		h.w = "serra"
		h.mun = 220
		h.hp = 340
		h.max_hp = 340
		h.armor = .5
		h.spd = 1.35
		h.nades = 0
		h.acc = .3
		h.alerted = true
	await S.until(func(): return j.dead or j.hp <= j.max_hp * .4)
	if not j.dead:
		M.ex.sweep.off = false
		S.say("ctl:m9_laser")
		S.note("Um feixe de contenção varre o átrio: ele queima quem tocar.", "red")
	await S.until(func(): return j.dead)
	M.ex.sweep.off = true
	S.set_obj("juiz", {state = "done"})
	if S.obj_state("pyl") == "active":
		S.set_obj("pyl", {state = "failed"})
	await S.wait(1.5)
	S.say("ctl:m9_servers")
	S.breach(M.ex.srv_door)
	S.obj("srv", "Cheguem ao terminal dos servidores do andar 90 antes que sejam apagados", true)
	S.timer("VARGA APAGA OS SERVIDORES EM", 60)
	for g in M.units:
		if g.kind == "guarda" and not g.dead and g.y < 10:
			g.alerted = true
	await S.until(func(): return M.flags.get("srv", false) or S.timer_done())
	S.clear_timer()
	if M.flags.get("srv", false):
		S.set_obj("srv", {state = "done"})
		S.say("ctl:m9_win")
		S.win("A Torre Central caiu. Os servidores do andar 90 estão nas mãos da Ônix.")
	else:
		M.flags.wiped = true
		S.set_obj("srv", {state = "failed"})
		S.say("ctl:m9_wiped")
		S.win("A Torre Central caiu, mas Ilse Varga apagou os servidores do andar 90.")


static func _rivals_line(S: MS) -> void:
	await S.wait(3)
	S.say("ctl:m9_rivals")


static func rival_waves(S: MS, _M: Mission, j: Unit) -> void:
	for id in RIVAL_POS:
		if j.dead:
			return
		var p: Array = RIVAL_POS[id]
		var u := S.rival(id, p[0], p[1], .5)
		if u == null:
			continue
		u.home = Vector2(p[0], p[1])
		await S.wait(20)


static func watch_pylons(S: MS, M: Mission, j: Unit) -> void:
	var pyl := M.units.filter(func(u): return u.pylon)
	var last := -1
	while true:
		var n := pyl.filter(func(p): return p.dead or p.fac == "player").size()
		if n != last:
			last = n
			S.set_obj("pyl", {text = "Derrube os pilares de escudo do átrio (%d/2)" % n})
		if n >= 2 or j.dead:
			break
		await S.wait(.3)
	if j.dead:
		return
	j.shield = false
	S.set_obj("pyl", {state = "done"})
	S.say("ctl:m9_shield")
	S.note("O escudo do Juiz caiu.", "green")

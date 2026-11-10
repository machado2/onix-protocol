## "Retiro", Colinas de Vidro (porte de v2/js/missions/retiro.js).
## Mansão murada com portão ao sul e saída de serviço a oeste. Feixes de alarme separam a ala da mansão da
## estufa de vidro. O gerador fora do muro apaga feixes, câmeras e luzes. Zona de pouso no topo do morro (noroeste).
class_name MRetiro

const T := C.T
const NOME := "Retiro"
const ALVO := "Dr. Caio Ventura"
const SPAWN := Vector2(2.5, 53.5)
const LZ := Vector2(6, 5.5)


static func in_compound(x: int, y: int) -> bool:
	return x >= 21 and x <= 55 and y >= 2 and y <= 28


static func build(B: MB) -> void:
	var r := C.Rng.new(7707)
	B.rect(T.GRASS, 0, 0, 56, 56)
	B.rect(T.ROAD, 0, 50, 56, 51)
	B.rect(T.ROAD, 39, 28, 40, 49)
	B.rect(T.WALK, 2, 10, 3, 49)
	B.rect(T.WALK, 2, 30, 38, 31)
	B.rect(T.WALK, 18, 8, 19, 30)
	B.rect(T.WALK, 11, 6, 21, 7)
	B.rect(T.PLAZA, 2, 2, 10, 9)
	var wall := func(x, y, w, d): return B.bld({x = x, y = y, w = w, d = d, fl = 1, style = "wall", kiosk = true})
	wall.call(2, 7, 4, 1)
	wall.call(7, 2, 1, 4)
	wall.call(22, 3, 33, 1)
	wall.call(22, 27, 16, 1)
	wall.call(42, 27, 13, 1)
	wall.call(22, 4, 1, 2)
	wall.call(22, 8, 1, 19)
	wall.call(54, 4, 1, 23)
	B.rect(T.PLAZA, 23, 4, 37, 26)
	B.rect(T.GRASS, 38, 4, 53, 12)
	B.rect(T.PLAZA, 38, 13, 53, 26)
	B.bld({x = 26, y = 6, w = 10, d = 6, fl = 3, pal = 3, v = 2, roof = 1, neon = -1})
	B.rect(T.WATER, 27, 16, 34, 19)
	B.bld({x = 44, y = 23, w = 3, d = 3, fl = 2, pal = 4, v = 1, neon = 1, sign = "SEGURANÇA", signCol = "#ff3d5a", corp = true})
	B.glass(42, 13, 51, 13)
	B.glass(42, 21, 51, 21)
	B.glass(42, 13, 42, 21)
	B.glass(51, 13, 51, 21)
	for q in [[46, 21, 47, 21], [42, 16, 42, 17]]:
		for y in range(q[1], q[3] + 1):
			for x in range(q[0], q[2] + 1):
				if B.tile[y * C.N + x] == T.GLASS:
					B.M.glass_n -= 1
		B.rect(T.PLAZA, q[0], q[1], q[2], q[3])
	for p in [[39.5, 6.5], [44.5, 5.5], [49.5, 7.5], [52.5, 10.5], [41.5, 10.5], [46.5, 10.5]]:
		B.tree(p[0], p[1])
	for p in [[44, 15], [49, 19]]:
		B.tree(p[0] + .5, p[1] + .5)
	B.laser(37.9, 26.4, 42.1, 26.4)
	B.laser(23.4, 5.7, 23.4, 8.3, {per = 4.0, duty = .55})
	B.laser(38.5, 4.1, 38.5, 12.9)
	B.laser(38.5, 13.1, 38.5, 21.9, {per = 5.0, duty = .5, ph = 1.0})
	B.laser(38.5, 22.1, 38.5, 25.9)
	B.laser(41.5, 15.6, 41.5, 18.4)
	B.laser(45.6, 22.4, 48.4, 22.4, {per = 4.5, duty = .5, ph = 2.0})
	B.add_decor({type = "generator", x = 19.6, y = 20.4})
	B.term({x = 19.6, y = 21.8, flag = "blackout", msg = "Gerador do Retiro desligado."})
	B.M.evac = LZ
	var vtol := B.add_decor({type = "heli", x = LZ.x, y = LZ.y, ang = .4, alt = 16.0, vis = false})
	B.M.ex.vtol = vtol
	for h in [[7, 34, 6, 4, 3], [14, 35, 5, 4, 2], [26, 34, 7, 5, 3], [44, 33, 6, 5, 3], [47, 41, 6, 5, 2], [8, 42, 6, 5, 2], [27, 41, 5, 5, 3], [11, 13, 5, 4, 2], [6, 22, 6, 4, 3]]:
		B.bld({x = h[0], y = h[1], w = h[2], d = h[3], fl = h[4], pal = MB.pick([1, 3, 2], r), v = r.range_i(4), roof = r.range_i(3), neon = -1})
	for k in 55:
		var p = B.rand_tile(func(t, x, y): return t == T.GRASS and not in_compound(x, y) and not (x <= 11 and y <= 10) and y < 49)
		if p != null:
			B.tree(p.x, p.y)
	for p in [[24, 4.6], [37, 4.6], [53, 4.6], [24, 25.6], [37, 22.6], [53, 25.6], [41, 13.6], [52.4, 13.6]]:
		B.lamp(p[0], p[1], "#cfe8ff", true, {villa = true})
	for p in [[26, 15], [35.5, 20.5]]:
		B.lamp(p[0], p[1], "#7fe3ff", false, {villa = true})
	for p in [[2, 2], [10.6, 2], [2, 9.6], [10.6, 9.6]]:
		B.lamp(p[0], p[1], "#5dffa0")
	for y in range(30, 49, 6):
		B.lamp(41.4, y + .5, "#ffcf7a")
	for x in range(4, 56, 9):
		B.lamp(x + .5, 49.4, "#ffcf7a")
	B.prop(20.8, 19.4)
	B.prop(36.5, 25.5)
	B.cam(23.6, 26.4, -PI / 4, {sweep = .7})
	B.cam(53.4, 4.6, 3 * PI / 4, {sweep = .6})
	B.cam(39.5, 28.6, PI / 2, {sweep = .8})
	var sci := B.unit("cientista", 46.5, 17.5)
	sci.nome = ALVO
	sci.hp = 160
	sci.max_hp = 160
	sci.armor = .35
	B.M.sci = sci
	for p in [[25, 13.5], [36, 13.2], [30, 23.5], [45, 8], [52.5, 16], [49.5, 24.5], [49.5, 14.5], [37, 29.2], [43, 29.2]]:
		var g := B.unit("guarda", p[0], p[1])
		B.arm(g, 5)
		g.home = Vector2(p[0], p[1])
	B.drone(21, 2, [[21, 1.5], [55, 1.5], [55, 28.5], [21, 28.5]], 5)
	for k in 5:
		B.unit("civil", 24 + randf() * 12, 13.5 + randf() * 1.2).still = true
	for k in 8:
		var p = B.rand_tile(func(t, _x, _y): return t == T.WALK)
		if p != null:
			B.unit("civil", p.x, p.y).home = p
	B.unit("policia", 20, 48.5)
	B.unit("policia", 45, 49.3)
	B.lanes([{y = 50.5, dx = 1, dy = 0}, {y = 51.5, dx = -1, dy = 0}], 5)


static func run(S: MS, M: Mission) -> void:
	S.obj("reach", "Encontre o %s na estufa de vidro" % ALVO, true)
	S.obj("ghost", "Opcional: alcance o doutor sem disparar o alarme")
	watch_blackout(S, M)
	watch_ghost(S, M)
	watch_sci_dead(S, M)
	S.cine(true)
	await S.cam_to(SPAWN, 1.2, .01)
	await S.wait(.6)
	S.say("ctl:m7_intro1")
	await S.cam_to(Vector2(44, 16), 1.0, 3.2)
	await S.talk_done()
	S.say("ctl:m7_intro2")
	await S.cam_to(Vector2(36, 14), 1.15, 2.4)
	await S.talk_done()
	S.say("ctl:m7_intro3")
	await S.cam_to(LZ, 1.0, 2.6)
	await S.talk_done()
	await S.cam_to(SPAWN, 1.2, 1.8)
	S.cine(false)
	S.note("O gerador fora do muro, a sudoeste, apaga os feixes de alarme.", "amber")
	await S.until(func(): return M.sci.follow or M.sci.dead)
	if M.sci.dead:
		return
	S.set_obj("reach", {state = "done"})
	if S.obj_state("ghost") == "active":
		S.set_obj("ghost", {state = "done"})
		S.bonus("Retiro sem alarme", 3000)
	S.say("sci:m7")
	S.obj("lz", "Leve o doutor à zona de pouso no topo do morro (noroeste)", true)
	await S.until(func(): return M.sci.dead or M.sci.pos2().distance_to(LZ) < 3.6)
	if M.sci.dead:
		return
	S.set_obj("lz", {state = "done"})
	S.obj("hold", "Defenda a zona de pouso até o VTOL descer", true)
	var HOLD := 30.0
	S.timer("VTOL CHEGA EM", HOLD)
	S.say("ctl:m7_hold")
	M.sci.hold = true
	M.sci.follow = false
	S.walk(M.sci, 3.6, 3.6)
	S.note("O doutor se abrigou atrás do muro da zona de pouso.", "cyan")
	var v: Dictionary = M.ex.vtol
	v.vis = true
	v.alt = 14.0
	waves(S, M)
	while not S.timer_done():
		v.alt = maxf(0, 14 * (M.timer.end - M.t) / HOLD)
		await S.wait(.5)
	S.clear_timer()
	v.alt = 0.0
	S.say("ctl:m7_vtol")
	await S.wait(2.5)
	S.walk(M.sci, LZ.x - .8, LZ.y)
	await S.until(func(): return M.sci.dead or M.sci.pos2().distance_to(LZ) < 3.6)
	if M.sci.dead:
		return
	S.set_obj("hold", {state = "done"})
	M.sci.vanished = true
	M.flags.heliGo = true
	S.say("ctl:m7_win")
	S.win("O %s foi tirado do Retiro." % ALVO)


static func _go(S: MS, kind: String, x: float, y: float) -> Unit:
	var u := S.spawn(kind, x, y, 5)
	u.alerted = true
	u.lkp = LZ
	u.home = LZ + Vector2(3, 3)
	return u


static func waves(S: MS, _M: Mission) -> void:
	await S.wait(2)
	_go(S, "guarda", 24, 6.5)
	_go(S, "guarda", 25, 7.5)
	_go(S, "drone", 30, 1.5)
	await S.wait(10)
	S.say("ctl:m7_wave")
	for id in ["navalha", "mariposa", "sibila", "ferro"]:
		var riv := S.rival(id, 12, 29, .8)
		if riv:
			riv.lkp = LZ
			break
	_go(S, "inimigo", 10, 29)
	_go(S, "inimigo", 14, 29.5)
	await S.wait(10)
	_go(S, "drone", 40, 1.5)
	_go(S, "drone", 50, 1.5)
	_go(S, "guarda", 18.5, 26)
	_go(S, "guarda", 19, 27)


static func watch_blackout(S: MS, M: Mission) -> void:
	await S.until(func(): return M.flags.get("blackout", false))
	for l in M.lasers:
		l.off = true
	for c in M.cams:
		c.off = true
	for l in M.lamps:
		if l.get("villa", false) and not l.dead:
			S.lamp_off(l)
	S.say("ctl:m7_dark")
	var gs := M.units.filter(func(u): return u.kind == "guarda" and not u.dead and not u.alerted)
	gs.sort_custom(func(a, b): return a.pos2().distance_to(Vector2(19.6, 20.4)) < b.pos2().distance_to(Vector2(19.6, 20.4)))
	for g in gs.slice(0, 2):
		S.walk(g, 19.6 + randf(), 22.5 + randf())


static func watch_ghost(S: MS, M: Mission) -> void:
	await S.until(func(): return M.corp_alert)
	if S.obj_state("ghost") == "active":
		S.set_obj("ghost", {state = "failed"})


static func watch_sci_dead(S: MS, M: Mission) -> void:
	await S.until(func(): return M.sci.dead and not M.sci.vanished)
	S.say("ctl:m7_fail")
	S.fail("O %s morreu." % ALVO)

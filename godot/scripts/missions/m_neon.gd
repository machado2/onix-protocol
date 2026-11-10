## "Clube Cobalto", Baixa Neon (porte de v2/js/missions/neon.js).
## Avenida de neon (y 28–29), Clube Cobalto com pista a céu aberto (x 34–44, y 11–19),
## beco de serviço ao norte com o carro de fuga. Cinco agentes disfarçados entre os civis.
class_name MNeon

const T := C.T
const NOME := "Clube Cobalto"
const SPAWN := Vector2(2.5, 31.5)
const ESC := Vector2(54.5, 5.5)
const SIGNS := ["BAR", "KARAOKÊ", "MOTEL", "SUSHI", "CYBER", "HOTEL", "BOTECO"]


static func _fill(B: MB, r: C.Rng, x0: int, y0: int, x1: int, y1: int, skip := Callable()) -> void:
	B.fill(r, x0, y0, x1, y1, 3, .9, func(x, y, w, d): return {x = x, y = y, w = w, d = d, fl = 3 + r.range_i(8), pal = r.range_i(4), v = r.range_i(4),
		neon = r.range_i(4) if r.next() < .7 else -1, sign = MB.pick(SIGNS, r) if r.next() < .45 else "", signCol = MB.pick(["#ff3d8b", "#38e8ff", "#ffb13d", "#a66bff"], r), roof = r.range_i(3)}, skip)


static func build(B: MB) -> void:
	var r := C.Rng.new(5577)
	B.rect(T.WALK, 0, 0, 56, 56)
	B.rect(T.ROAD, 0, 28, 56, 29)
	B.rect(T.ROAD, 10, 0, 11, 56)
	B.rect(T.ROAD, 12, 5, 56, 6)
	B.bld({x = 30, y = 8, w = 14, d = 3, fl = 3, pal = 4, v = 2, neon = 1})
	B.bld({x = 45, y = 8, w = 4, d = 3, fl = 3, pal = 4, v = 3, neon = 1})
	B.bld({x = 30, y = 11, w = 4, d = 9, fl = 2, pal = 2, v = 1, neon = 0})
	B.bld({x = 45, y = 11, w = 4, d = 9, fl = 2, pal = 2, v = 2, neon = 3})
	B.bld({x = 30, y = 20, w = 8, d = 2, fl = 2, pal = 2, v = 0, neon = 1, sign = "CLUBE COBALTO", signCol = "#38e8ff"})
	B.bld({x = 41, y = 20, w = 8, d = 2, fl = 2, pal = 2, v = 3, neon = 1})
	B.rect(T.PLAZA, 34, 11, 44, 19)
	B.rect(T.PLAZA, 44, 8, 44, 10)
	B.bld({x = 38, y = 11, w = 3, d = 1, fl = 1, pal = 5, neon = 1, kiosk = true})
	B.add_decor({type = "disco", x0 = 34, y0 = 11, x1 = 44, y1 = 19})
	_fill(B, r, 12, 8, 28, 25, func(x, y): return x >= 19 and x <= 25 and y >= 24)
	_fill(B, r, 12, 0, 56, 3)
	_fill(B, r, 50, 8, 55, 26)
	_fill(B, r, 0, 32, 9, 54, func(_x, y): return y <= 34)
	_fill(B, r, 12, 32, 56, 54, func(_x, y): return y <= 33)
	_fill(B, r, 0, 0, 9, 26, func(_x, y): return y >= 24)
	B.add_decor({type = "billboard", x = 22, y = 26.4, w = 5, h = 3.4, text = "HÉLICE", sub = "VIVA MAIS. PENSE MENOS.", col = "#ff3d5a"})
	B.add_decor({type = "billboard", x = 46, y = 30.6, w = 4.4, h = 3, text = "NEURO+", sub = "IMPLANTES EM 12X", col = "#38e8ff"})
	B.add_decor({type = "billboard", x = 16, y = 30.6, w = 4.4, h = 3, text = "KARAOKÊ", sub = "ABERTO 24 HORAS", col = "#ffb13d"})
	for x in range(2, 56, 5):
		B.lamp(x + .5, 27.4, MB.pick(["#ff6ad5", "#7fe3ff", "#ffb35c", "#a66bff"], r))
		B.lamp(x + 2.5, 30.6, MB.pick(["#ff6ad5", "#7fe3ff", "#ffb35c"], r))
	B.lamp(39.5, 22.5, "#38e8ff")
	B.lamp(44.5, 7, "#ff6ad5")
	B.lamp(52, 7, "#ffb35c")
	for p in [[33, 23], [46, 23], [47, 4.5]]:
		B.prop(p[0], p[1])
	for k in 26:
		var c := B.unit("civil", 34.6 + randf() * 9.8, 11.8 + randf() * 7)
		c.dance = true
		c.still = true
	for k in 34:
		var c := B.unit("civil", 1 + randf() * 54, (26.5 + randf() * 1.2) if randf() < .5 else (30.2 + randf() * 1.2))
		c.home = c.pos2()
	for k in 8:
		B.unit("civil", 36 + randf() * 7, 22.5 + randf() * 3).still = true
	for p in [[14, 27], [34, 30.8], [50, 27], [24, 31]]:
		B.unit("policia", p[0], p[1])
	for p in [[36, 14], [41.5, 16], [39, 18.2]]:
		var e := B.unit("inimigo", p[0], p[1])
		B.arm(e, 3)
		B.disguise(e, true)
		e.home = Vector2(p[0], p[1])
	for p in [[22, 27], [44, 31]]:
		var e := B.unit("inimigo", p[0], p[1])
		B.arm(e, 3)
		B.disguise(e, false)
		e.home = Vector2(p[0], p[1])
	B.lanes([{y = 28.5, dx = 1, dy = 0}, {y = 29.5, dx = -1, dy = 0}], 8)


static func cell(M: Mission) -> Array:
	return M.units.filter(func(u): return u.tags.get("cell", false))


static func run(S: MS, M: Mission) -> void:
	S.obj("kill", "Elimine os agentes infiltrados (0/5)", true)
	S.obj("civ", "Opcional: no máximo 2 civis feridos")
	watch_kills(S, M)
	watch_civ(S, M)
	watch_mariposa(S, M)
	watch_flee(S, M)
	M.esc_car = S.car(ESC.x, ESC.y, PI, "#121318", 140)
	S.cine(true)
	await S.cam_to(SPAWN, 1.2, .01)
	await S.wait(.6)
	S.say("ctl:m4_intro1")
	await S.cam_to(Vector2(26, 28), 1.0, 3)
	await S.talk_done()
	S.say("ctl:m4_intro2")
	await S.cam_to(Vector2(39, 15), 1.2, 2.8)
	await S.talk_done()
	S.say("ctl:m4_intro3")
	await S.cam_to(Vector2(50, 6), 1.15, 2.4)
	await S.talk_done()
	await S.cam_to(SPAWN, 1.2, 1.8)
	S.cine(false)


static func watch_kills(S: MS, M: Mission) -> void:
	var last := -1
	while true:
		var dead := cell(M).filter(func(u): return u.dead and not u.vanished).size()
		if dead != last:
			last = dead
			S.set_obj("kill", {text = "Elimine os agentes infiltrados (%d/5)" % dead})
		if M.flags.get("escaped", 0):
			S.say("ctl:m4_fail")
			S.fail("Um agente da célula fugiu no carro do beco.")
			return
		if dead >= 5:
			break
		await S.wait(.3)
	S.set_obj("kill", {state = "done"})
	if S.obj_state("civ") == "active":
		S.set_obj("civ", {state = "done"})
		S.bonus("Multidão preservada", 2500)
	S.say("ctl:m4_win")
	S.win("A célula do Consórcio na Baixa Neon foi eliminada.")


static func watch_civ(S: MS, M: Mission) -> void:
	await S.until(func(): return M.stats.civis > 2)
	S.set_obj("civ", {state = "failed"})


static func watch_mariposa(S: MS, M: Mission) -> void:
	await S.until(func(): return M.revealed >= 1 or M.corp_alert)
	await S.wait(8)
	var m := S.rival("mariposa", 44.5, 6, .85)
	if m:
		m.home = Vector2(39, 15)
		S.obj("mari", "Opcional: elimine a Mariposa")
		S.say("ctl:m4_mari")
		await S.until(func(): return m.dead)
		S.set_obj("mari", {state = "failed" if m.vanished else "done"})


static func watch_flee(S: MS, M: Mission) -> void:
	await S.until(func():
		var alive := cell(M).filter(func(u): return not u.dead and not u.follower)
		return M.corp_alert and alive.size() > 0 and alive.size() <= 2 and cell(M).any(func(u): return u.dead))
	S.say("ctl:m4_flee")
	S.note("Destruir o carro de fuga no beco impede a fuga.", "amber")
	for u in cell(M):
		if not u.dead and not u.follower:
			if u.disguise:
				u.disguise = false
				u.dance = false
				u.alerted = true
				S.sim.fx.emit("reveal", {u = u})
			u.flee_to = Vector2(ESC.x - 1.2, ESC.y)
			u.path = []

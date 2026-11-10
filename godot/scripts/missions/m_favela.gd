## "Linha de Fuga", Vila Ferrugem (porte de v2/js/missions/favela.js).
## Clínica clandestina do Consórcio no alto do morro (norte), favela densa no meio, estrada ao sul (van)
## e estação do teleférico a leste. Primeira aparição do Navalha.
class_name MFavela

const T := C.T
const NOME := "Linha de Fuga"
const SPAWN := Vector2(8.5, 48.5)
const VAN := Vector2(22.5, 48.2)
const CABLE := Vector2(52.5, 24.5)


static func blocked(x: int, y: int) -> bool:
	return (x >= 26 and x <= 30) or (x >= 31 and x <= 52 and y >= 28 and y <= 32) or (x >= 4 and x <= 18 and y >= 29 and y <= 39) or (x >= 49 and y >= 19 and y <= 28) or (x >= 18 and x <= 27 and y >= 45)


static func build(B: MB) -> void:
	var r := C.Rng.new(9091)
	B.rect(T.WALK, 0, 0, 56, 56)
	B.rect(T.PLAZA, 0, 0, 56, 2)
	B.rect(T.PLAZA, 19, 3, 37, 13)
	for x in range(18, 39):
		B.set_tile(x, 2, T.FENCE)
		if x < 27 or x > 29:
			B.set_tile(x, 14, T.FENCE)
	for y in range(2, 15):
		B.set_tile(18, y, T.FENCE)
		B.set_tile(38, y, T.FENCE)
	B.bld({x = 21, y = 4, w = 15, d = 4, fl = 4, pal = 4, v = 3, neon = 1, sign = "HÉLICE BIOMÉDICA", signCol = "#5dffa0", corp = true, ant = true})
	B.add_decor({type = "generator", x = 20.6, y = 11.2})
	B.term({x = 20.6, y = 12.5, flag = "power", msg = "Gerador da clínica desligado: torretas e holofotes apagados."})
	B.rect(T.PLAZA, 27, 15, 29, 49)
	B.rect(T.PLAZA, 32, 29, 51, 31)
	for x in [33, 36, 39, 42, 45, 48]:
		B.bld({x = x, y = 29, w = 2, d = 1, fl = 1, pal = 5, neon = int(x / 3) % 4, kiosk = true})
	B.rect(T.GRASS, 5, 30, 17, 38)
	B.rect(T.PLAZA, 50, 20, 56, 27)
	B.add_decor({type = "cable", x = 54.2, y = 23.2})
	B.rect(T.ROAD, 0, 50, 56, 51)
	B.rect(T.WALK, 18, 45, 27, 49)
	B.add_decor({type = "van", x = VAN.x, y = VAN.y - 1.2, ang = 0.0})
	for ry in [16, 20, 24, 28, 32, 36, 40, 44]:
		var x := 1
		var since := 0
		while x < 55:
			if blocked(x, ry) and blocked(x, ry + 2):
				x += 1
				since = 0
				continue
			if since >= 5 or r.next() < .22:
				x += 1
				since = 0
				continue
			var w := 2 + r.range_i(3)
			var d := 2 if r.next() < .25 else 3
			var ok := true
			for yy in range(ry, ry + d):
				for xx in range(x, x + w):
					if xx > 55 or blocked(xx, yy):
						ok = false
			if not ok:
				x += 1
				since = 0
				continue
			B.bld({x = x, y = ry, w = w, d = d, fl = 2 + r.range_i(3) + (1 if r.next() < .15 else 0), pal = 6 + r.range_i(5), v = r.range_i(4),
				roof = 2 if r.next() < .55 else (1 if r.next() < .3 else 0), neon = r.range_i(4) if r.next() < .08 else -1, favela = true})
			x += w
			since += w
		for k in 3:
			var lx := 2 + r.range_i(48)
			B.add_decor({type = "laundry", x1 = lx, y1 = ry + 3.5, x2 = lx + 3 + r.range_i(3), y2 = ry + 3.5, h = 1.75})
	for b in [[2, 6, 5, 0], [10, 5, 7, 2], [17, 7, 4, 1], [31, 6, 6, 3], [39, 8, 8, 0], [49, 6, 5, 2]]:
		B.bld({x = b[0], y = 53, w = b[1], d = 4, fl = b[2], pal = b[3], v = r.range_i(4), neon = r.range_i(4) if r.next() < .5 else -1})
	for p in [[20, 3.5], [36.5, 3.5], [20, 13], [36.5, 13]]:
		B.lamp(p[0], p[1], "#cfe8ff", true, {clinic = true})
	for y in range(17, 48, 6):
		B.lamp(27.3, y + .5, "#ffb35c" if r.next() < .5 else "#ff6ad5")
	for x in [34, 40, 46]:
		B.lamp(x + .5, 31.6, "#ffd27a")
	B.lamp(51.5, 21.5, "#7fe3ff")
	B.lamp(17.5, 30.5, "#ffd27a", true)
	for x in [5, 15, 35, 45]:
		B.lamp(x + .5, 49.5, "#ffb35c")
	for p in [[24, 47], [45, 31], [19, 13], [33, 12]]:
		B.prop(p[0], p[1])
	var sci := B.unit("cientista", 28.5, 10.5)
	sci.nome = "Dra. Sofia Tanaka"
	B.M.sci = sci
	B.M.evacs = [VAN, CABLE]
	B.M.evac = VAN
	for p in [[24, 10], [33, 10], [28, 12.5], [35, 12], [25.5, 8.6], [28.5, 36]]:
		var g := B.unit("guarda", p[0], p[1])
		B.arm(g, 2)
		g.home = Vector2(p[0], p[1])
	for p in [[19.5, 12.5], [37.5, 12.5]]:
		var t := B.unit("torre", p[0], p[1])
		t.tags.clinic = true
		t.hp = 100
		t.max_hp = 100
		t.acc = .45
	for k in 46:
		var p = B.rand_tile(func(t, _x, y): return (t == T.WALK or t == T.PLAZA) and y >= 15 and y <= 49)
		if p != null:
			B.unit("civil", p.x, p.y).tags.morador = true
	for k in 12:
		var c := B.unit("civil", 33 + randf() * 17, 30 + randf() * 1.6)
		c.tags.morador = true
		c.home = c.pos2()
	B.lanes([{y = 50.5, dx = 1, dy = 0}, {y = 51.5, dx = -1, dy = 0}], 5)


static func paint(P: MPaint) -> void:
	var TS := MPaint.TS
	var c := Color(.92, .94, .9, .55)
	P.stroke_rect(5.3 * TS, 30.3 * TS, 12.4 * TS, 8.4 * TS, c)
	P.line(11.5 * TS, 30.3 * TS, 11.5 * TS, 38.7 * TS, c)
	P.ring(11.5 * TS, 34.5 * TS, 1.4 * TS, c)
	for k in 30:
		P.fill((5.5 + P.rng.randf() * 12) * TS, (30.5 + P.rng.randf() * 8) * TS, 10, 6, Color(.24, .16, .12, .35))


static func run(S: MS, M: Mission) -> void:
	S.obj("reach", "Encontre a Dra. Sofia Tanaka na clínica do Consórcio", true)
	S.obj("power", "Opcional: desligue o gerador da clínica")
	S.obj("noharm", "Opcional: não fira nenhum morador")
	watch_harm(S, M)
	watch_power(S, M)
	watch_sci(S, M)
	S.cine(true)
	await S.cam_to(SPAWN, 1.2, .01)
	await S.wait(.6)
	S.say("ctl:m2_intro1")
	await S.cam_to(Vector2(28.5, 9), 1.0, 3.2)
	await S.talk_done()
	S.say("ctl:m2_intro2")
	await S.cam_to(Vector2(21, 11.5), 1.25, 2)
	await S.talk_done()
	S.say("ctl:m2_intro3")
	await S.cam_to(Vector2(40, 30.5), 1.05, 3)
	await S.talk_done()
	await S.cam_to(SPAWN, 1.2, 1.8)
	S.cine(false)
	await S.until(func(): return M.sci.follow or M.sci.dead)
	if M.sci.dead:
		return
	S.set_obj("reach", {state = "done"})
	S.say("sci:m2")
	S.obj("exfil", "Leve a doutora à van (sul) ou ao teleférico (leste)", true)
	await S.wait(4)
	var van := S.car(56.4, 50.5, PI, "#2a2d34", 160, "van")
	S.drive(van, [Vector2(VAN.x + 3.5, 50.5)])
	await S.until(S.arrived(van))
	if not van.dead:
		S.rival("navalha", van.x, van.y - 1.2, .7)
		var e := S.spawn("inimigo", van.x - 1, van.y - 1, 3)
		e.alerted = true
		e.home = VAN
	S.say("ctl:m2_navalha")
	await S.talk_done()
	S.say("ctl:m2_cable")
	await S.wait(6)
	if not M.flags.get("harm", false):
		for k in 4:
			var c := S.spawn("civil", 40 + k * 1.5, 30.5)
			c.tags.morador = true
			c.w = "smg" if k % 2 else "pistola"
			c.mun = 30
			c.fac = "player"
			c.follower = true
			M.followers += 1
		S.say("ctl:m2_help")
		await S.wait(1.5)
		S.say("civ:m2help")


static func watch_harm(S: MS, M: Mission) -> void:
	await S.until(func(): return M.stats.civis > 0)
	M.flags.harm = true
	S.set_obj("noharm", {state = "failed"})
	S.say("ctl:m2_noh")


static func watch_power(S: MS, M: Mission) -> void:
	await S.until(func(): return M.flags.get("power", false))
	for u in M.units:
		if u.tags.get("clinic", false):
			u.off = true
	for l in M.lamps:
		if l.get("clinic", false) and not l.dead:
			S.lamp_off(l)
	S.set_obj("power", {state = "done"})
	S.bonus("Clínica no escuro", 1500)


static func watch_sci(S: MS, M: Mission) -> void:
	await S.until(func(): return M.sci.dead or (M.sci.follow and M.evacs.any(func(e): return M.sci.pos2().distance_to(e) < 2.3)))
	if M.sci.dead:
		S.fail("A Dra. Tanaka morreu durante a fuga.")
		return
	S.set_obj("exfil", {state = "done"})
	if not M.flags.get("harm", false):
		S.set_obj("noharm", {state = "done"})
		S.bonus("Nenhum morador ferido", 2000)
	S.say("ctl:m2_win")
	S.win("A Dra. Sofia Tanaka foi tirada da Vila Ferrugem.")

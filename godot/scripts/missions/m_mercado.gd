## "Pregão", Mercado Suspenso (porte de v2/js/missions/mercado.js).
## Feira sob o monotrilho (y 18–26), Central de Vigilância cercada ao norte, galeria e beco ao sul.
## Câmeras veem armas à mostra; o trem a cada 40 s abafa os tiros.
class_name MMercado

const T := C.T
const NOME := "Pregão"
const SPAWN := Vector2(3.5, 52.5)
const SIGNS := ["PASTEL", "AÇAÍ", "CYBER", "LOTERIA", "PENHORES", "BAR", "RAMEN", "CLÍNICA"]


static func _fill(B: MB, r: C.Rng, x0: int, y0: int, x1: int, y1: int, skip := Callable()) -> void:
	B.fill(r, x0, y0, x1, y1, 3, .88, func(x, y, w, d): return {x = x, y = y, w = w, d = d, fl = 3 + r.range_i(7), pal = r.range_i(4), v = r.range_i(4),
		neon = r.range_i(4) if r.next() < .45 else -1, sign = MB.pick(SIGNS, r) if r.next() < .3 else "", signCol = MB.pick(["#ff3d8b", "#38e8ff", "#ffb13d"], r), roof = r.range_i(3)}, skip)


static func build(B: MB) -> void:
	var r := C.Rng.new(3131)
	B.rect(T.WALK, 0, 0, 56, 56)
	B.rect(T.ROAD, 0, 16, 56, 17)
	B.rect(T.ROAD, 0, 27, 56, 28)
	B.rect(T.ROAD, 28, 0, 29, 15)
	B.rect(T.ROAD, 28, 29, 29, 56)
	B.rect(T.PLAZA, 0, 18, 56, 26)
	B.monorail(22, [2, 8, 14, 20, 26, 32, 38, 44, 50, 55])
	for x in range(2, 54, 3):
		if x >= 25 and x <= 31:
			continue
		if r.next() < .85:
			B.bld({x = x, y = 19, w = 2, d = 1, fl = 1, pal = 5, kiosk = true, neon = r.range_i(4)})
		if r.next() < .85:
			B.bld({x = x, y = 25, w = 2, d = 1, fl = 1, pal = 5, kiosk = true, neon = r.range_i(4)})
	B.rect(T.PLAZA, 39, 3, 53, 13)
	for y in range(2, 15):
		B.set_tile(38, y, T.FENCE)
		B.set_tile(54, y, T.FENCE)
	for x in range(38, 55):
		B.set_tile(x, 2, T.FENCE)
		if x < 45 or x > 47:
			B.set_tile(x, 14, T.FENCE)
	B.bld({x = 41, y = 4, w = 11, d = 4, fl = 5, pal = 4, v = 1, neon = 0, sign = "VIGILÂNCIA", signCol = "#ff3d5a", corp = true, ant = true})
	_fill(B, r, 2, 2, 26, 14)
	_fill(B, r, 31, 2, 36, 14)
	B.bld({x = 32, y = 31, w = 11, d = 5, fl = 4, pal = 2, v = 2, neon = 2, sign = "GALERIA AURORA", signCol = "#ffb13d"})
	_fill(B, r, 2, 30, 26, 54, func(x, y): return x <= 9 and y >= 47)
	_fill(B, r, 31, 37, 54, 54, func(x, y): return x >= 44 and x <= 49 and y >= 36 and y <= 46)
	_fill(B, r, 49, 30, 54, 35)
	B.rect(T.PLAZA, 44, 37, 49, 45)
	B.term({x = 46.5, y = 10.5, flag = "cams", msg = "Central de Vigilância invadida: câmeras desligadas."})
	B.term({x = 15.5, y = 23.4, flag = "t2", msg = "Terminal da feira invadido."})
	B.term({x = 46.5, y = 41.5, flag = "t3", msg = "Terminal do beco invadido."})
	B.cam(8.6, 22.5, 0, {sweep = .9})
	B.cam(32.6, 22.5, PI, {sweep = .9})
	B.cam(44.6, 22.5, 0, {sweep = .9})
	B.cam(39.6, 13.3, -PI / 4, {strict = true, sweep = .5})
	B.cam(53.4, 13.3, -3 * PI / 4, {strict = true, sweep = .5})
	B.cam(46.5, 36.6, PI / 2, {sweep = .7})
	for x in range(4, 54, 6):
		B.lamp(x + .5, 18.4, "#ff6ad5" if r.next() < .5 else "#7fe3ff")
		B.lamp(x + 3.5, 26.6, "#ffb35c" if r.next() < .5 else "#ff6ad5")
	for p in [[40.5, 3.5], [52.5, 3.5], [40.5, 12.5], [52.5, 12.5]]:
		B.lamp(p[0], p[1], "#cfe8ff", true)
	for x in [6, 18, 36, 48]:
		B.lamp(x + .5, 15.5, "#ffb35c")
		B.lamp(x + .5, 29.5, "#ffb35c")
	B.lamp(44.5, 38, "#ff6ad5")
	B.lamp(49, 44, "#7fe3ff")
	for p in [[24, 20.5], [34, 24], [45, 44.5], [40, 12.5]]:
		B.prop(p[0], p[1])
	for p in [[42, 9.5], [50, 10], [46, 12.6], [20, 24], [38, 20.5], [46.5, 43.5], [45, 39.5]]:
		var g := B.unit("guarda", p[0], p[1])
		B.arm(g, 2)
		g.home = Vector2(p[0], p[1])
	for p in [[12, 18.5], [40, 26.5], [31, 40]]:
		B.unit("policia", p[0], p[1])
	for k in 32:
		var c := B.unit("civil", 2 + randf() * 52, 20 + randf() * 4.6)
		c.home = c.pos2()
	for k in 16:
		var p = B.rand_tile(func(t, _x, y): return t == T.WALK and (y < 16 or y > 28))
		if p != null:
			B.unit("civil", p.x, p.y)
	B.lanes([{y = 16.5, dx = 1, dy = 0}, {y = 17.5, dx = -1, dy = 0}, {y = 27.5, dx = 1, dy = 0}, {y = 28.5, dx = -1, dy = 0}], 7)
	B.M.train_t = 14


static func run(S: MS, M: Mission) -> void:
	S.obj("t", "Invada os terminais de vigilância (0/3)", true)
	S.obj("cams", "Opcional: desligue as câmeras pelo terminal da Central de Vigilância")
	S.obj("quiet", "Opcional: derrube a rede sem disparar o alarme")
	watch_terms(S, M)
	watch_cams(S, M)
	watch_quiet(S, M)
	S.cine(true)
	await S.cam_to(SPAWN, 1.2, .01)
	await S.wait(.6)
	S.say("ctl:m3_intro1")
	await S.cam_to(Vector2(20, 22), 1.05, 3)
	await S.talk_done()
	S.say("ctl:m3_intro2")
	await S.cam_to(Vector2(46, 9), 1.1, 2.6)
	await S.talk_done()
	M.train_t = 1
	S.say("ctl:m3_intro3")
	await S.cam_to(Vector2(26, 22), .95, 2.4)
	await S.talk_done()
	await S.wait(1.5)
	await S.cam_to(SPAWN, 1.2, 1.8)
	S.cine(false)


static func watch_terms(S: MS, M: Mission) -> void:
	var last := -1
	while true:
		var n := M.terms.filter(func(t): return t.done).size()
		if n != last:
			last = n
			S.set_obj("t", {text = "Invada os terminais de vigilância (%d/3)" % n})
			if n == 2 and not M.flags.get("lockdown", false):
				M.flags.lockdown = true
				S.say("ctl:m3_lock")
				for p in [[28.5, 1], [29.5, 1.5], [28.5, 55], [29.5, 54.5], [55, 16.5]]:
					S.spawn("policia", p[0], p[1])
				M.police_aggro = 60
				for a in M.agents:
					if not a.dead:
						M.last_seen = a.pos2()
						break
		if n >= 3:
			break
		await S.wait(.4)
	S.set_obj("t", {state = "done"})
	S.obj("exfil", "Volte ao ponto de inserção", true)
	S.say("ctl:m3_exfil")
	await S.until(func(): return S.squad_at(SPAWN, 3.4))
	S.set_obj("exfil", {state = "done"})
	if S.obj_state("quiet") == "active":
		S.set_obj("quiet", {state = "done"})
		S.bonus("Rede derrubada em silêncio", 3000)
	S.say("ctl:m3_win")
	S.win("A rede de vigilância do Mercado Suspenso caiu.")


static func watch_cams(S: MS, M: Mission) -> void:
	await S.until(func(): return M.flags.get("cams", false))
	for c in M.cams:
		c.off = true
	S.set_obj("cams", {state = "done"})
	S.bonus("Câmeras desligadas", 1000)


static func watch_quiet(S: MS, M: Mission) -> void:
	await S.until(func(): return M.corp_alert)
	S.set_obj("quiet", {state = "failed"})

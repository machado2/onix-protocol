## "Fundição", Setor Industrial 9 (porte de v2/js/missions/fundicao.js).
## Planta cercada com portões a oeste e ao sul. Três reatores, tubulação com saídas de vapor, hangar de drones ao norte.
## Depois da terceira carga: 45 s para voltar ao portão de inserção antes da reação em cadeia.
class_name MFundicao

const T := C.T
const NOME := "Fundição"
const SPAWN := Vector2(3.5, 53.5)
const REACT := [{x = 13.5, y = 10.5, f = "r1"}, {x = 37.5, y = 20.5, f = "r2"}, {x = 50.5, y = 8.5, f = "r3"}]
const SIGNS := ["OFICINA", "BAR", "PENSÃO", "PEÇAS", "MERCEARIA"]


static func build(B: MB) -> void:
	var r := C.Rng.new(9091)
	B.rect(T.WALK, 0, 0, 56, 56)
	B.rect(T.ROAD, 0, 50, 56, 51)
	B.rect(T.ROAD, 0, 30, 56, 31)
	B.rect(T.ROAD, 21, 0, 22, 51)
	for y in range(2, 48):
		if y < 30 or y > 31:
			B.set_tile(6, y, T.FENCE)
	for x in range(6, 57):
		if x < 21 or x > 22:
			B.set_tile(x, 47, T.FENCE)
	var reactors := []
	for R in REACT:
		B.rect(T.BLD, int(R.x) - 1, int(R.y) - 1, int(R.x) + 1, int(R.y) + 1)
		var d := B.add_decor({type = "reactor", x = R.x, y = R.y, r = 1.35})
		B.term({x = R.x, y = R.y + 2.4, flag = R.f, msg = "Carga instalada no reator."})
		reactors.append({d = d, x = R.x, y = R.y, f = R.f})
	B.M.ex.reactors = reactors
	B.bld({x = 8, y = 20, w = 7, d = 5, fl = 3, style = "ware", sign = "LAMINAÇÃO", signCol = "#ffb13d"})
	B.bld({x = 25, y = 3, w = 8, d = 4, fl = 3, style = "ware", sign = "HANGAR DE DRONES", signCol = "#ff3d5a"})
	B.bld({x = 47, y = 15, w = 8, d = 6, fl = 4, style = "ware", sign = "FORNO 3", signCol = "#ffb13d"})
	B.bld({x = 8, y = 34, w = 11, d = 7, fl = 4, style = "ware", sign = "FUNDIÇÃO 9", signCol = "#ff8a3c"})
	B.bld({x = 26, y = 35, w = 10, d = 6, fl = 3, style = "ware", sign = "LINGOTES", signCol = "#ffb13d"})
	B.bld({x = 46, y = 34, w = 9, d = 6, fl = 3, style = "ware", sign = "EXPEDIÇÃO", signCol = "#38e8ff"})
	B.bld({x = 40, y = 33, w = 3, d = 2, fl = 2, pal = 1, v = 2, neon = 1, sign = "PRESSÃO", signCol = "#ff3d5a"})
	var cont := [[16, 20, 3, 1, 2], [17, 23, 3, 1, 1], [8, 4, 3, 1, 2], [16, 4, 3, 1, 3], [25, 12, 3, 1, 2], [25, 14, 3, 1, 1], [29, 24, 1, 3, 2], [52, 23, 3, 1, 2], [10, 43, 3, 1, 2], [14, 43, 3, 1, 1], [38, 42, 3, 1, 2], [48, 42, 3, 1, 3], [30, 43, 3, 1, 1]]
	for i in cont.size():
		var c: Array = cont[i]
		B.bld({x = c[0], y = c[1], w = c[2], d = c[3], fl = c[4], style = "cont", col = i % 6})
	for c in [[10.5, 6.5, 7.5], [35.5, 5.5, 8.5], [38.5, 5.5, 7.0]]:
		B.set_tile(int(c[0]), int(c[1]), T.POST)
		B.add_decor({type = "chimney", x = c[0], y = c[1], h = c[2]})
	B.add_decor({type = "pipe", x1 = 7, y1 = 17.5, x2 = 34, y2 = 17.5, h = 2.4, r = .22, col = "#7a5a40"})
	B.add_decor({type = "pipe", x1 = 44.5, y1 = 3, x2 = 44.5, y2 = 28, h = 2.6, r = .2, col = "#6a6a58"})
	B.add_decor({type = "pipe", x1 = 23, y1 = 28.5, x2 = 56, y2 = 28.5, h = 2.2, r = .18, col = "#7a5a40"})
	var k := 0
	for p in [[9.5, 17.5], [16.5, 17.5], [25.5, 17.5], [31.5, 17.5], [44.5, 7.5], [44.5, 15.5], [44.5, 24.5], [28.5, 28.5], [40.5, 28.5], [52.5, 28.5]]:
		B.vent(p[0], p[1], {per = 7.0, ph = k * 1.7, dmg = 45.0})
		k += 1
	B.term({x = 41.5, y = 35.8, flag = "vapor", msg = "Controle de pressão invadido: todas as saídas de vapor vão disparar."})
	B.fill(r, 8, 53, 56, 56, 2, .85, func(x, y, w, d): return {x = x, y = y, w = w, d = d, fl = 2 + r.range_i(3), pal = r.range_i(4), v = r.range_i(4),
		neon = r.range_i(4) if r.next() < .3 else -1, sign = MB.pick(SIGNS, r) if r.next() < .3 else "", signCol = MB.pick(["#ffb13d", "#38e8ff"], r), roof = r.range_i(3)})
	for p in [[8, 15], [19.5, 14], [24, 10], [33, 15], [42, 10], [55, 12.5], [24, 26], [42, 26], [55, 26], [8, 27], [19.5, 33], [24, 42], [38, 32.5], [55, 42], [12, 45.5], [33, 45.5]]:
		B.lamp(p[0], p[1], "#ffb35c", true)
	for x in range(2, 56, 7):
		B.lamp(x + .5, 49.4, "#ffcf7a")
	for p in [[23.5, 8], [34, 26], [19.5, 26], [45.5, 45]]:
		B.prop(p[0], p[1])
	B.add_decor({type = "van", x = 26, y = 44.6, ang = 0.0})
	B.add_decor({type = "van", x = 43, y = 44.6, ang = PI})
	B.cam(10.6, 8.6, PI / 4, {sweep = .7})
	B.cam(34.6, 17.6, PI / 4, {sweep = .7})
	B.cam(53.4, 11.4, -3 * PI / 4, {sweep = .6})
	for p in [[11, 13.5], [16.5, 8], [48, 11.5], [53.5, 6], [34.5, 18], [40.5, 22.5], [8.5, 28.5], [19.5, 45], [24.5, 45], [30.5, 33.5], [44.5, 41], [28.5, 8.5]]:
		var g := B.unit("guarda", p[0], p[1])
		B.arm(g, 4)
		g.home = Vector2(p[0], p[1])
	B.drone(13.5, 6.5, [[9, 6.5], [18.5, 6.5], [18.5, 15], [9, 15]], 4)
	B.drone(50.5, 5, [[46.5, 4.5], [55, 4.5], [55, 13], [46.5, 13]], 4)
	B.drone(30, 30.5, [[24, 30.5], [55, 30.5]], 4)
	for n in 14:
		var p = B.rand_tile(func(t, x, y): return t == T.WALK and x > 7 and y > 3 and y < 46)
		if p == null:
			continue
		var u := B.unit("civil", p.x, p.y)
		u.tags.worker = true
		u.home = p
	for n in 10:
		var p = B.rand_tile(func(t, _x, y): return t == T.WALK and y >= 52)
		if p != null:
			B.unit("civil", p.x, p.y)
	for p in [[10, 52.4], [40, 52.4]]:
		B.unit("policia", p[0], p[1])
	B.lanes([{y = 50.5, dx = 1, dy = 0}, {y = 51.5, dx = -1, dy = 0}], 6)


static func run(S: MS, M: Mission) -> void:
	S.obj("r", "Instale cargas nos três reatores (0/3)", true)
	S.obj("quiet", "Opcional: instale as três cargas sem disparar o alarme")
	var f := S.rival("ferro", 37.5, 24.4)
	if f:
		f.alerted = false
		f.home = Vector2(37.5, 24)
		S.obj("ferro", "Opcional: elimine o Ferro-Velho")
		watch_ferro(S, M, f)
	watch_charges(S, M)
	watch_quiet(S, M)
	watch_vapor(S, M)
	watch_alarm(S, M)
	S.cine(true)
	await S.cam_to(SPAWN, 1.2, .01)
	await S.wait(.6)
	S.say("ctl:m5_intro1")
	await S.cam_to(Vector2(22, 24), .8, 3.2)
	await S.talk_done()
	M.vent_over = M.t + 2.4
	S.say("ctl:m5_intro2")
	await S.cam_to(Vector2(16, 17), 1.15, 2.4)
	await S.talk_done()
	S.say("ctl:m5_intro3")
	await S.cam_to(Vector2(37, 22), 1.05, 2.6)
	await S.talk_done()
	await S.cam_to(SPAWN, 1.2, 1.8)
	S.cine(false)
	S.note("O terminal de pressão, ao sul, faz todas as saídas de vapor dispararem juntas.", "amber")


static func watch_charges(S: MS, M: Mission) -> void:
	var last := -1
	var R: Array = M.ex.reactors
	while true:
		var n := R.filter(func(q): return M.flags.get(q.f, false)).size()
		for q in R:
			if M.flags.get(q.f, false) and not q.d.get("armed", false):
				q.d.armed = true
				if n < 3:
					S.say("ctl:m5_charge")
		if n != last:
			last = n
			S.set_obj("r", {text = "Instale cargas nos três reatores (%d/3)" % n})
		if n >= 3:
			break
		await S.wait(.3)
	S.set_obj("r", {state = "done"})
	var quiet := S.obj_state("quiet") == "active"
	if quiet:
		S.set_obj("quiet", {state = "done"})
	S.obj("exfil", "Volte ao portão de inserção antes da explosão", true)
	S.timer("REAÇÃO EM CADEIA", 45)
	S.say("ctl:m5_last")
	S.alarm()
	await S.until(func(): return S.timer_done() or S.squad_at(SPAWN, 3.8))
	var made := not S.timer_done()
	S.clear_timer()
	if made:
		S.set_obj("exfil", {state = "done"})
		if quiet:
			S.bonus("Cargas instaladas em silêncio", 3000)
	else:
		S.set_obj("exfil", {state = "failed"})
	S.cine(true)
	await S.cam_to(Vector2(32, 18), .75, 1.4)
	for q in R:
		S.boom(q.x, q.y, 3.4, 240)
		q.d.dead = true
		for k in 3:
			S.boom(q.x + (randf() - .5) * 6, q.y + (randf() - .5) * 6, 1.8, 90)
		await S.wait(.55)
	for d in M.decor:
		if d.type == "chimney":
			d.dead = true
	for v in M.vents:
		v.off = true
	await S.wait(1.4)
	if made:
		S.say("ctl:m5_win")
		S.win("A Fundição Hélice do Setor Industrial 9 foi pelos ares.")
	else:
		S.say("ctl:m5_fail")
		S.fail("O esquadrão ainda estava na planta quando os reatores explodiram.")


static func watch_quiet(S: MS, M: Mission) -> void:
	await S.until(func(): return M.corp_alert)
	if S.obj_state("quiet") == "active":
		S.set_obj("quiet", {state = "failed"})


static func watch_vapor(S: MS, M: Mission) -> void:
	await S.until(func(): return M.flags.get("vapor", false))
	M.vent_over = M.t + 10
	for a in M.agents:
		if not a.dead:
			M.vent_src = a
			break
	S.say("ctl:m5_vapor")


static func watch_alarm(S: MS, M: Mission) -> void:
	await S.until(func(): return M.corp_alert)
	await S.wait(3)
	S.say("ctl:m5_drones")
	for x in [27.5, 30.5]:
		var d := S.spawn("drone", x, 7.8)
		d.alerted = true
		d.acc = .54


static func watch_ferro(S: MS, _M: Mission, f: Unit) -> void:
	await S.until(func(): return f.dead)
	S.set_obj("ferro", {state = "failed" if f.vanished else "done"})

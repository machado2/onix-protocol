## "Maré Baixa", Docas Velhas (porte de v2/js/missions/docas.js).
## Halvard Reis chega em comboio ao porto para encontrar um contrabandista. Mar ao norte (y<11),
## pátio de contêineres cercado (y 11–31), cidade ao sul (y>32). O guindaste 2 pode soltar um contêiner no alvo.
class_name MDocas

const T := C.T
const NOME := "Maré Baixa"
const SPAWN := Vector2(6.5, 40.5)
const DROP := Vector2(28.5, 16.25)
const CONTAINERS := [
	[2, 13, 1, 3, 2], [4, 13, 3, 1, 3], [4, 15, 3, 1, 1], [8, 13, 1, 3, 2], [13, 14, 3, 1, 2], [18, 13, 1, 3, 2], [20, 13, 3, 1, 1], [20, 15, 3, 1, 2], [24, 14, 1, 3, 1],
	[17, 20, 1, 3, 2], [19, 19, 3, 1, 1], [19, 22, 3, 1, 2], [23, 20, 1, 3, 1], [2, 19, 1, 3, 1],
	[2, 27, 3, 1, 2], [7, 28, 3, 1, 2], [7, 30, 3, 1, 1], [11, 29, 1, 3, 3], [13, 28, 3, 1, 1], [17, 27, 1, 3, 2], [19, 29, 3, 1, 2], [23, 27, 3, 1, 1], [23, 30, 3, 1, 3],
	[34, 13, 3, 1, 2], [34, 15, 3, 1, 1], [38, 13, 1, 3, 3], [40, 13, 3, 1, 1], [40, 15, 3, 1, 2], [46, 13, 3, 1, 2], [46, 15, 1, 3, 1], [50, 13, 3, 1, 3], [50, 16, 3, 1, 1],
	[34, 20, 1, 3, 2], [35, 24, 3, 1, 1], [34, 28, 3, 1, 2], [38, 28, 1, 3, 1], [41, 29, 3, 1, 2], [46, 28, 1, 3, 3], [49, 28, 3, 1, 1], [49, 30, 3, 1, 2], [52, 20, 1, 3, 2], [50, 23, 3, 1, 1],
]
const CITY := [
	{x = 1, y = 34, w = 4, d = 8, fl = 5, pal = 0}, {x = 8, y = 34, w = 7, d = 4, fl = 7, pal = 1, neon = 1},
	{x = 8, y = 39, w = 7, d = 3, fl = 3, pal = 3, neon = 2, sign = "BAR DO PORTO", signCol = "#ffb13d"},
	{x = 16, y = 34, w = 5, d = 8, fl = 4, pal = 2, sign = "PENHORES", signCol = "#38e8ff"}, {x = 22, y = 35, w = 4, d = 6, fl = 9, pal = 0, ant = true},
	{x = 33, y = 34, w = 6, d = 8, fl = 6, pal = 1, sign = "HOTEL MARÉ", signCol = "#ff3d8b"}, {x = 40, y = 35, w = 6, d = 6, fl = 10, pal = 2, neon = 0, ant = true},
	{x = 47, y = 34, w = 8, d = 4, fl = 3, pal = 3, sign = "PEIXARIA", signCol = "#38e8ff"}, {x = 47, y = 39, w = 8, d = 3, fl = 5, pal = 0},
	{x = 1, y = 47, w = 6, d = 8, fl = 8, pal = 2, neon = 3}, {x = 9, y = 48, w = 8, d = 6, fl = 5, pal = 0, sign = "FARMÁCIA 24H", signCol = "#5dffa0"},
	{x = 19, y = 47, w = 7, d = 4, fl = 11, pal = 1, neon = 1, ant = true}, {x = 32, y = 47, w = 9, d = 5, fl = 6, pal = 3, sign = "KARAOKÊ", signCol = "#ff3d8b"},
	{x = 43, y = 48, w = 6, d = 7, fl = 9, pal = 0, neon = 0}, {x = 51, y = 47, w = 5, d = 9, fl = 4, pal = 2},
]


static func build(B: MB) -> void:
	var r := C.Rng.new(4242)
	B.rect(T.WALK, 0, 33, 56, 56)
	B.rect(T.WATER, 0, 0, 56, 10)
	B.rect(T.PLAZA, 0, 11, 56, 31)
	B.pier(8, 4, 10, 10)
	B.pier(41, 2, 44, 10)
	for x in 57:
		if x != 5 and x != 28 and x != 29:
			B.set_tile(x, 32, T.FENCE)
	B.rect(T.ROAD, 28, 12, 29, 56)
	B.rect(T.ROAD, 0, 44, 56, 45)
	for b in CITY:
		var o: Dictionary = b.duplicate()
		o.merge({v = r.range_i(4), roof = r.range_i(3)})
		B.bld(o)
	B.bld({x = 30, y = 33, w = 1, d = 1, fl = 2, pal = 4, v = 1, neon = 0})
	B.bld({x = 6, y = 19, w = 10, d = 6, fl = 3, style = "ware", sign = "ARMAZÉM 7", signCol = "#ffb13d"})
	B.bld({x = 40, y = 21, w = 8, d = 6, fl = 6, pal = 4, v = 2, neon = 0, sign = "HÉLICE", signCol = "#ff3d5a", corp = true, ant = true})
	for i in CONTAINERS.size():
		var c: Array = CONTAINERS[i]
		B.bld({x = c[0], y = c[1], w = c[2], d = c[3], fl = c[4], style = "cont", col = i % 6})
	for p in [[12, 12], [16, 12], [12, 17], [16, 17], [26, 13], [31, 13], [26, 18], [31, 18]]:
		B.set_tile(p[0], p[1], T.POST)
	B.add_decor({type = "crane", x0 = 12, y0 = 12, x1 = 16, y1 = 17, col = "#c8501e", hang = Vector2(14.5, 7)})
	B.add_decor({type = "crane", x0 = 26, y0 = 13, x1 = 31, y1 = 18, col = "#d8a020", hang = DROP, main = true})
	B.add_decor({type = "boat", x = 46.6, y = 4.6})
	B.add_decor({type = "barrier", x = 30.2, y = 32.5})
	B.add_decor({type = "van", x = 6.5, y = 36.6, ang = PI / 2})
	B.term({x = 32.6, y = 18.7, crane = true})
	for l in [[10, 18.5, "#ffd27a"], [22, 18, "#ffd27a"], [33, 19.5, "#cfe8ff"], [48, 18, "#ffd27a"], [20, 26, "#cfe8ff"], [36, 27, "#ffd27a"], [10, 30.5, "#ffd27a"], [45, 30.5, "#cfe8ff"], [24, 11.5, "#cfe8ff"], [38, 11.5, "#ffd27a"], [9, 10, "#ffd27a"], [42, 9, "#ffd27a"]]:
		B.lamp(l[0], l[1], l[2], true)
	for x in [4, 12, 20, 34, 42, 50]:
		B.lamp(x + .5, 43.5, "#ffb35c")
	for x in [8, 16, 24, 38, 46, 54]:
		B.lamp(x + .5, 46.5, "#7fe3ff" if r.next() < .3 else "#ffb35c")
	for y in [36, 40, 50, 54]:
		B.lamp(27.5, y + .5, "#ffb35c")
	for y in [38, 52]:
		B.lamp(30.5, y + .5, "#ff6ad5")
	for p in [[3, 43], [13, 43], [37, 43], [52, 43]]:
		B.tree(p[0] + .5, p[1] + .5)
	for p in [[25, 16], [32.5, 15.2], [39, 20], [21, 24.5], [36.5, 26], [3, 25], [51, 26]]:
		B.prop(p[0], p[1])
	for p in [[12, 26], [20, 24.5], [4, 24], [36, 17], [44, 17.5], [18, 30.5]]:
		var u := B.unit("civil", p[0] + .5, p[1] + .5)
		u.tags.worker = true
		u.home = Vector2(p[0] + .5, p[1] + .5)
	var sm := B.unit("civil", 11.5, 26.4)
	sm.still = true
	sm.face = -PI / 2
	sm.nome = "Contrabandista"
	B.M.ex.smuggler = sm
	for p in [[27.2, 31.2], [30.8, 31.2], [20, 20.5], [33.5, 23.5], [45, 19.5], [14, 27.5], [39, 27.5]]:
		var g := B.unit("guarda", p[0], p[1])
		B.arm(g, 1)
		g.home = Vector2(p[0], p[1])
	B.unit("torre", 39.5, 24.5)
	B.unit("policia", 14.5, 43.5)
	B.unit("policia", 40.5, 46.5)
	for k in 24:
		var p = B.rand_tile(func(t, _x, y): return t == T.WALK and y >= 42)
		if p != null:
			B.unit("civil", p.x, p.y)
	B.lanes([{y = 44.5, dx = 1, dy = 0}, {y = 45.5, dx = -1, dy = 0}], 6)
	B.M.escape = Vector2(43, 3)
	B.M.drop_point = DROP


static func run(S: MS, M: Mission) -> void:
	S.obj("kill", "Elimine Halvard Reis", true)
	S.obj("crane", "Opcional: invada a cabine do guindaste 2 e solte o contêiner sobre o alvo (tecla G)")
	S.obj("union", "Opcional: recrute 4 estivadores com a Sonda (0/4)")
	watch_union(S, M)
	watch_alarm(S, M)
	watch_kill(S, M)
	S.cine(true)
	await S.cam_to(SPAWN, 1.25, .01)
	await S.wait(.7)
	S.say("ctl:m1_intro1")
	await S.cam_to(Vector2(29, 37), 1.0, 3)
	await S.talk_done()
	S.say("ctl:m1_intro2")
	await S.cam_to(DROP, 1.15, 3)
	await S.talk_done()
	S.say("ctl:m1_intro3")
	await S.cam_to(Vector2(6, 31), 1.15, 2.4)
	await S.talk_done()
	await S.cam_to(SPAWN, 1.25, 1.6)
	S.cine(false)
	S.timer("Comboio chega em", 70)
	await S.until(func(): return S.timer_done())
	S.clear_timer()
	S.say("ctl:m1_convoy")
	var cols := ["#121318", "#1c1c24", "#121318"]
	var stops := [14.0, DROP.y, 18.8]
	var cars := []
	for i in 3:
		var c := S.car(28.5, 56.3, -PI / 2, cols[i], 170.0 if i == 1 else 120.0, "suv" if i != 1 else "sedan")
		S.drive(c, [Vector2(28.5, stops[i])])
		cars.append(c)
		await S.wait(1.1)
	M.ex.convoy = cars
	await S.until(func(): return cars.all(func(c): return c.dead or (c.path.is_empty() and c.cur < .4)))
	for c in [cars[0], cars[2]]:
		if not c.dead:
			var g := S.spawn("guarda", c.x - .95, c.y + .2, 2)
			g.home = Vector2(c.x - 1.6, c.y)
	await S.wait(1.4)
	var limo: Dictionary = cars[1]
	var vip := S.spawn("vip", limo.x + .95, limo.y)
	vip.nome = "Diretor Halvard Reis"
	vip.scripted = true
	M.vip = vip
	for k in 2:
		var g := S.spawn("guarda", limo.x + .95, limo.y + (.8 if k else -.8), 2)
		g.escort = vip
	if limo.dead:
		vip.hp = 0
		vip.dead = true
		return
	S.say("ctl:m1_arrive")
	vip.face = PI
	await S.wait(2.2)
	if vip.dead:
		return
	if not M.corp_alert:
		S.walk(vip, 11.5, 25.5)
	await S.until(func(): return vip.dead or M.corp_alert or vip.path.is_empty())
	if vip.dead or M.corp_alert:
		return
	vip.face = PI / 2
	S.say("vip:meet")
	await S.wait(3)
	S.say("civ:smug")


static func watch_kill(S: MS, M: Mission) -> void:
	await S.until(func(): return M.vip != null)
	var vip: Unit = M.vip
	leave(S, M, vip, M.ex.convoy[1])
	await S.until(func(): return vip.dead)
	S.set_obj("kill", {state = "done"})
	if M.flags.get("accident", false):
		S.set_obj("crane", {state = "done"})
		S.bonus("Acidente de trabalho", 4000)
		S.say("ctl:m1_accident")
		await S.talk_done()
	elif S.obj_state("crane") == "active":
		S.set_obj("crane", {state = "failed"})
	S.obj("exfil", "Volte à van de extração com todo o esquadrão", true)
	S.say("ctl:m1_exfil")
	if not M.flags.get("reinf", false):
		reinforce(S, M)
	await S.until(func(): return S.squad_at(SPAWN, 3.4))
	S.set_obj("exfil", {state = "done"})
	S.win("Halvard Reis foi eliminado nas Docas Velhas e o esquadrão saiu do porto.")


static func leave(S: MS, M: Mission, vip: Unit, limo: Dictionary) -> void:
	await S.until(func(): return vip.dead or M.corp_alert or (vip.path.is_empty() and Vector2(vip.x - 11.5, vip.y - 25.5).length() < 1.5))
	if vip.dead or M.corp_alert:
		return
	await S.wait(30)
	if vip.dead or M.corp_alert:
		return
	S.say("ctl:m1_leaving")
	if limo.dead:
		return
	S.walk(vip, limo.x + .95, limo.y)
	await S.until(func(): return vip.dead or M.corp_alert or vip.path.is_empty())
	if vip.dead or M.corp_alert or limo.dead:
		return
	vip.in_car = limo
	limo.occ.append(vip)
	await S.wait(1.5)
	var cars: Array = M.ex.convoy
	for c in [cars[2], cars[1], cars[0]]:
		if not c.dead:
			S.drive(c, [Vector2(28.5, 56.6)])
		await S.wait(.9)
	await S.until(func(): return vip.dead or limo.dead or limo.y > 55.6)
	if vip.dead or limo.dead:
		return
	S.say("ctl:m1_gone")
	S.fail("O comboio deixou o porto levando Halvard Reis.")


static func watch_alarm(S: MS, M: Mission) -> void:
	await S.until(func(): return M.corp_alert)
	if M.vip and not M.vip.dead:
		S.say("ctl:m1_boat")
	await S.wait(22)
	if not M.flags.get("reinf", false):
		await reinforce(S, M)


static func reinforce(S: MS, M: Mission) -> void:
	M.flags.reinf = true
	S.say("ctl:m1_reinf")
	var van := S.car(28.5, 56.3, -PI / 2, "#2a2d34", 140, "van")
	S.drive(van, [Vector2(28.5, 34.6)])
	await S.until(S.arrived(van))
	if van.dead:
		return
	for k in 3:
		var e := S.spawn("inimigo", van.x + (k - 1) * .9, van.y - 1, 3)
		e.alerted = true
		e.home = Vector2(28.5, 28)


static func watch_union(S: MS, M: Mission) -> void:
	var last := -1
	while true:
		var n := M.units.filter(func(u): return u.tags.get("worker", false) and u.follower and not u.dead).size()
		if n != last:
			last = n
			S.set_obj("union", {text = "Opcional: recrute 4 estivadores com a Sonda (%d/4)" % mini(n, 4)})
		if n >= 4:
			S.set_obj("union", {state = "done"})
			S.bonus("Estivadores recrutados", 2000)
			S.say("ctl:m1_union")
			return
		await S.wait(.5)

## "Labirinto", Jardins Altos (porte de v2/js/missions/jardins.js).
## Propriedade murada, mansão ao norte, labirinto de sebes no centro com uma praça e fonte no meio.
## Holofotes em torres enxergam qualquer agente. Ao alarme, o senador corre para o bunker a nordeste;
## dentro dele, a porta se fecha e começa a contagem do túnel.
class_name MJardins

const T := C.T
const NOME := "Labirinto"
const ALVO := "Senador Augusto Calvino"
const SPAWN := Vector2(2.5, 53.5)
const BUNKER := Vector2(48.5, 7.5)
const MX := 14
const MY := 14
const L := 28


static func maze(B: MB, r: C.Rng) -> Array:
	var wall := []
	for y in L:
		var row := []
		for x in L:
			row.append(x % 3 == 0 or y % 3 == 0)
		wall.append(row)
	var seen := {Vector2i(4, 4): true}
	var st := [Vector2i(4, 4)]
	var open := func(i: int, j: int, di: int, dj: int) -> void:
		if di != 0:
			for y in [3 * j + 1, 3 * j + 2]:
				wall[y][3 * maxi(i, i + di)] = false
		else:
			for x in [3 * i + 1, 3 * i + 2]:
				wall[3 * maxi(j, j + dj)][x] = false
	while not st.is_empty():
		var c: Vector2i = st[st.size() - 1]
		var nb := []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x >= 0 and n.y >= 0 and n.x < 9 and n.y < 9 and not seen.has(n):
				nb.append(d)
		if nb.is_empty():
			st.pop_back()
			continue
		var d: Vector2i = nb[r.range_i(nb.size())]
		open.call(c.x, c.y, d.x, d.y)
		seen[c + d] = true
		st.append(c + d)
	for j in 9:
		for i in 9:
			if i < 8 and r.next() < .13:
				open.call(i, j, 1, 0)
			if j < 8 and r.next() < .13:
				open.call(i, j, 0, 1)
	for k in [13, 14]:
		wall[0][k] = false
		wall[L - 1][k] = false
		wall[k][0] = false
		wall[k][L - 1] = false
	for y in range(10, 18):
		for x in range(10, 18):
			wall[y][x] = false
	var hedge := func(x, y, w, d): B.bld({x = MX + x, y = MY + y, w = w, d = d, fl = 1, style = "hedge", kiosk = true})
	for y in range(0, L, 3):
		var x := 0
		while x < L:
			if not wall[y][x]:
				x += 1
				continue
			var e := x
			while e < L and wall[y][e]:
				e += 1
			hedge.call(x, y, e - x, 1)
			x = e
	for x in range(0, L, 3):
		var y := 0
		while y < L:
			if y % 3 == 0 or not wall[y][x]:
				y += 1
				continue
			var e := y
			while e < L and e % 3 != 0 and wall[e][x]:
				e += 1
			hedge.call(x, y, 1, e - y)
			y = e
	return wall


static func build(B: MB) -> void:
	var r := C.Rng.new(6464)
	B.rect(T.GRASS, 0, 0, 56, 56)
	B.rect(T.ROAD, 0, 50, 56, 51)
	B.rect(T.WALK, 0, 52, 56, 56)
	B.rect(T.WALK, 0, 48, 56, 49)
	B.rect(T.WALK, 2, 2, 3, 47)
	var wall := func(x, y, w, d): return B.bld({x = x, y = y, w = w, d = d, fl = 1, style = "wall", kiosk = true})
	wall.call(6, 1, 49, 1)
	wall.call(6, 47, 20, 1)
	wall.call(30, 47, 25, 1)
	wall.call(6, 2, 1, 28)
	wall.call(6, 32, 1, 15)
	wall.call(54, 2, 1, 45)
	B.rect(T.PLAZA, 26, 42, 29, 47)
	B.bld({x = 20, y = 2, w = 17, d = 6, fl = 4, pal = 3, v = 2, roof = 1, neon = -1})
	B.rect(T.PLAZA, 14, 8, 42, 12)
	var mw := maze(B, r)
	B.M.ex.maze = mw
	B.rect(T.PLAZA, 24, 24, 31, 31)
	B.rect(T.WATER, 27, 27, 28, 28)
	B.add_decor({type = "fountain", x = 28, y = 28, x0 = 27, y0 = 27, x1 = 28, y1 = 28})
	B.rect(T.WATER, 8, 18, 11, 24)
	for k in 26:
		var p = B.rand_tile(func(t, x, y): return t == T.GRASS and x > 7 and x < 53 and y > 2 and y < 46 and (x < 13 or x > 42 or y < 13 or y > 42) and not (x >= 43 and x <= 53 and y <= 14) and not (y >= 26 and y <= 29) and not (x >= 25 and x <= 30))
		if p != null:
			B.tree(p.x, p.y)
	for k in 30:
		var p = B.rand_tile(func(t, x, y): return t == T.GRASS and (y > 52 or x < 2 or x > 55))
		if p != null:
			B.tree(p.x, p.y)
	wall.call(45, 4, 8, 1)
	wall.call(45, 11, 3, 1)
	wall.call(50, 11, 3, 1)
	wall.call(45, 5, 1, 6)
	wall.call(52, 5, 1, 6)
	B.rect(T.PLAZA, 46, 5, 51, 10)
	B.rect(T.PLAZA, 46, 12, 51, 14)
	B.add_decor({type = "blastdoor", x = 49, y = 11.5, w = 2, flag = "shut"})
	B.M.escape = BUNKER
	B.term({x = 43.6, y = 13.4, flag = "rel1", msg = "Relé oeste do bunker sobrecarregado."})
	B.term({x = 53.2, y = 15.4, flag = "rel2", msg = "Relé leste do bunker sobrecarregado."})
	for s in [[12.5, 12.5, PI / 4], [43.5, 43.5, -3 * PI / 4], [12.5, 43.5, -PI / 4]]:
		B.cam(s[0], s[1], s[2], {strict = true, spot = true, range = 10.0, fov = .26, sweep = 1.05, spd = .33})
	B.cam(19.6, 8.4, PI / 4, {sweep = .6})
	B.cam(37.4, 8.4, 3 * PI / 4, {sweep = .6})
	for x in range(15, 42, 5):
		B.lamp(x + .5, 12.6, "#ffd99a")
	for p in [[24.4, 24.4], [31.6, 24.4], [24.4, 31.6], [31.6, 31.6]]:
		B.lamp(p[0], p[1], "#cfe8ff")
	for p in [[46.4, 12.6], [51.6, 12.6], [26, 46.4], [29.6, 46.4], [13, 27.5], [42, 27.5]]:
		B.lamp(p[0], p[1], "#ffb35c", true)
	for x in range(4, 56, 9):
		B.lamp(x + .5, 49.4, "#ffcf7a")
	var v := B.unit("vip", 28, 10)
	v.nome = ALVO
	v.hp = 90
	v.max_hp = 90
	v.armor = .2
	v.safe_room = true
	v.flee_msg = "O senador está correndo para o bunker!"
	for p in [[28, 10], [25.5, 25.5], [10, 28], [30.5, 30.5], [28, 44], [30.5, 25.5], [47, 22], [28, 10]]:
		v.route.append(Vector2(p[0], p[1]))
	v.idle_t = 4
	B.M.vip = v
	for k in 2:
		var g := B.unit("guarda", 28 + (.8 if k else -.8), 10.6)
		B.arm(g, 7)
		g.escort = v
	var n := 0
	for k in 60:
		if n >= 4:
			break
		var x := MX + 1 + r.range_i(26)
		var y := MY + 1 + r.range_i(26)
		if mw[y - MY][x - MX] or (x >= 24 and x <= 31 and y >= 24 and y <= 31):
			continue
		var g := B.unit("guarda", x + .5, y + .5)
		B.arm(g, 7)
		g.home = Vector2(x + .5, y + .5)
		n += 1
	for p in [[24.5, 48.6], [31.5, 48.6], [46.5, 20], [10, 30], [47, 6], [50.5, 6]]:
		var g := B.unit("guarda", p[0], p[1])
		B.arm(g, 7)
		g.home = Vector2(p[0], p[1])
	for k in 6:
		var p = B.rand_tile(func(t, x, y): return t == T.GRASS and x > 7 and x < 53 and y > 13 and y < 46 and not (x > 13 and x < 42 and y > 13 and y < 42))
		if p != null:
			B.unit("civil", p.x, p.y).home = p
	for k in 4:
		B.unit("civil", 22 + k * 3.5, 11.2).still = true
	for k in 10:
		var p = B.rand_tile(func(t, _x, y): return t == T.WALK and y >= 48)
		if p != null:
			B.unit("civil", p.x, p.y)
	for p in [[14, 48.6], [44, 48.6]]:
		B.unit("policia", p[0], p[1])
	B.lanes([{y = 50.5, dx = 1, dy = 0}, {y = 51.5, dx = -1, dy = 0}], 6)


static func run(S: MS, M: Mission) -> void:
	S.obj("kill", "Elimine o %s" % ALVO, true)
	S.obj("quiet", "Opcional: elimine o senador sem dar tempo ao alarme")
	S.obj("lights", "Opcional: derrube os três holofotes")
	watch_kill(S, M)
	watch_quiet(S, M)
	watch_lights(S, M)
	watch_bunker(S, M)
	watch_rival(S, M)
	S.cine(true)
	await S.cam_to(SPAWN, 1.2, .01)
	await S.wait(.6)
	S.say("ctl:mj_intro1")
	await S.cam_to(Vector2(28, 26), .8, 3.2)
	await S.talk_done()
	S.say("ctl:mj_intro2")
	await S.cam_to(Vector2(14, 15), 1.1, 2.4)
	await S.talk_done()
	S.say("ctl:mj_intro3")
	await S.cam_to(Vector2(48, 10), 1.1, 2.4)
	await S.talk_done()
	await S.cam_to(SPAWN, 1.2, 1.8)
	S.cine(false)


static func watch_kill(S: MS, M: Mission) -> void:
	await S.until(func(): return M.vip.dead and not M.vip.vanished)
	await S.wait(.1)
	S.set_obj("kill", {state = "done"})
	if S.obj_state("relay") == "active":
		S.set_obj("relay", {state = "done"})
	S.clear_timer()
	S.say("ctl:mj_win")
	S.win("O %s foi eliminado nos Jardins Altos." % ALVO)


static func watch_quiet(S: MS, M: Mission) -> void:
	var v: Unit = M.vip
	await S.until(func(): return M.corp_alert or v.dead)
	var by_shot := M.t - v.last_hit < .3
	if not by_shot and not v.dead:
		S.set_obj("quiet", {state = "failed"})
		return
	var t0 := M.t
	await S.until(func(): return v.dead or v.safe or M.t - t0 > 4)
	if v.dead and not v.vanished:
		S.set_obj("quiet", {state = "done"})
		S.bonus("Senador abatido antes do alarme", 3000)
	else:
		S.set_obj("quiet", {state = "failed"})


static func watch_lights(S: MS, M: Mission) -> void:
	var spots := M.cams.filter(func(c): return c.get("spot", false))
	await S.until(func(): return spots.all(func(c): return c.dead))
	S.set_obj("lights", {state = "done"})
	S.bonus("Jardim no escuro", 1000)


static func watch_bunker(S: MS, M: Mission) -> void:
	var v: Unit = M.vip
	await S.until(func(): return v.dead or M.corp_alert)
	if v.dead:
		return
	S.say("ctl:mj_flee")
	await S.until(func(): return v.dead or v.safe)
	if v.dead:
		return
	for u in M.units:
		if not u.dead and u.x >= 48 and u.x < 50 and u.y >= 11 and u.y < 12:
			u.y = 12.5
			u.path = []
	M.flags.shut = true
	S.block(48, 11, 49, 11, true)
	S.say("ctl:mj_bunker")
	S.obj("relay", "Sobrecarregue os dois relés do bunker (0/2)", true)
	S.timer("TÚNEL DE FUGA EM", 75)
	var last := -1
	while true:
		var n := (1 if M.flags.get("rel1", false) else 0) + (1 if M.flags.get("rel2", false) else 0)
		if n != last:
			last = n
			S.set_obj("relay", {text = "Sobrecarregue os dois relés do bunker (%d/2)" % n})
		if n >= 2 or v.dead or S.timer_done():
			break
		await S.wait(.3)
	if v.dead:
		return
	if S.timer_done() and not (M.flags.get("rel1", false) and M.flags.get("rel2", false)):
		S.clear_timer()
		v.vanished = true
		v.dead = true
		S.set_obj("relay", {state = "failed"})
		S.say("ctl:mj_fail")
		S.fail("O senador fugiu pelo túnel do bunker.")
		return
	S.clear_timer()
	S.set_obj("relay", {state = "done"})
	M.flags.shut = false
	S.block(48, 11, 49, 11, false)
	S.boom(49, 12, 1.2, 30)
	v.safe = false
	v.safe_room = false
	S.say("ctl:mj_open")
	S.set_obj("kill", {text = "O bunker está aberto: acabe com o senador"})


static func watch_rival(S: MS, M: Mission) -> void:
	await S.until(func(): return M.vip.safe or M.vip.dead)
	if M.vip.dead:
		return
	await S.wait(3)
	for id in ["sibila", "navalha", "mariposa", "ferro"]:
		var riv := S.rival(id, 49, 15, .6)
		if riv:
			riv.home = Vector2(49, 16)
			S.obj("riv", "Opcional: elimine %s" % riv.nome)
			await S.until(func(): return riv.dead)
			S.set_obj("riv", {state = "failed" if riv.vanished else "done"})
			return

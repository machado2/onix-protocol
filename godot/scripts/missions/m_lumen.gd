## "Gala Lúmen", Distrito Lúmen (porte de v2/js/missions/lumen.js).
## Praça Lúmen cercada de torres, pavilhão de vidro no centro, guarita de segurança e heliporto a leste.
## O alvo e dois sósias idênticos circulam no pavilhão; o scanner (de perto) ou a guarita revelam quem é quem.
class_name MLumen

const T := C.T
const NOME := "Gala Lúmen"
const ALVO := "Otávio Brandt"
const SPAWN := Vector2(2.5, 53.5)
const HELI := Vector2(53.5, 32)
const ESC := Vector2(51.2, 32.5)
const ROUTE := [Vector2(22.5, 22.5), Vector2(28, 22.4), Vector2(33.5, 22.5), Vector2(33.6, 26), Vector2(33.5, 29.6), Vector2(28, 29.7), Vector2(22.5, 29.6), Vector2(22.4, 26)]
const SIGNS := ["GALERIA", "JOIAS", "BISTRÔ", "HOTEL LÚMEN", "CLÍNICA", "ADEGA"]


static func _fill(B: MB, r: C.Rng, x0: int, y0: int, x1: int, y1: int, lo := 6, hi := 14) -> void:
	B.fill(r, x0, y0, x1, y1, 3, .92, func(x, y, w, d): return {x = x, y = y, w = w, d = d, fl = lo + r.range_i(hi - lo), pal = MB.pick([1, 3, 4, 2], r), v = r.range_i(4),
		neon = 1 if r.next() < .35 else -1, sign = MB.pick(SIGNS, r) if r.next() < .3 else "", signCol = MB.pick(["#38e8ff", "#ffd36b", "#cfe8ff"], r), roof = r.range_i(3), ant = r.next() < .4})


static func build(B: MB) -> void:
	var r := C.Rng.new(4242)
	B.rect(T.WALK, 0, 0, 56, 56)
	B.rect(T.ROAD, 0, 4, 56, 5)
	B.rect(T.ROAD, 0, 48, 56, 49)
	B.rect(T.ROAD, 4, 0, 5, 56)
	B.rect(T.ROAD, 46, 0, 47, 56)
	B.rect(T.PLAZA, 14, 14, 44, 40)
	B.glass(20, 20, 36, 20)
	B.glass(20, 32, 36, 32)
	B.glass(20, 20, 20, 32)
	B.glass(36, 20, 36, 32)
	for q in [[27, 20, 29, 20], [27, 32, 29, 32], [20, 25, 20, 27], [36, 25, 36, 27]]:
		for y in range(q[1], q[3] + 1):
			for x in range(q[0], q[2] + 1):
				if B.tile[y * C.N + x] == T.GLASS:
					B.M.glass_n -= 1
		B.rect(T.PLAZA, q[0], q[1], q[2], q[3])
	for p in [[24, 24], [32, 24], [24, 28], [32, 28]]:
		B.bld({x = p[0], y = p[1], w = 1, d = 1, fl = 1, pal = 5, neon = 3, kiosk = true})
	B.add_decor({type = "disco", x0 = 25, y0 = 24, x1 = 31, y1 = 28})
	B.rect(T.WATER, 26, 36, 30, 38)
	B.add_decor({type = "fountain", x = 28.5, y = 37.5, x0 = 26, y0 = 36, x1 = 30, y1 = 38})
	for p in [[15, 15], [40, 36], [15, 36]]:
		B.rect(T.GRASS, p[0], p[1], p[0] + 3, p[1] + 3)
		B.tree(p[0] + 1.5, p[1] + 1.5)
	for p in [[18.5, 18.5], [38.5, 18.5], [18.5, 34.5], [38.5, 34.5]]:
		B.tree(p[0], p[1])
	B.bld({x = 40, y = 14, w = 4, d = 3, fl = 2, pal = 4, v = 1, neon = 1, sign = "SEGURANÇA", signCol = "#ff3d5a", corp = true})
	B.term({x = 41.5, y = 17.8, flag = "booth", msg = "Guarita invadida: registros biométricos da festa."})
	B.rect(T.PLAZA, 49, 26, 56, 38)
	B.add_decor({type = "heli", x = HELI.x, y = HELI.y, ang = 0.0})
	B.M.escape = ESC
	_fill(B, r, 7, 7, 44, 12)
	_fill(B, r, 7, 14, 12, 46)
	_fill(B, r, 14, 42, 44, 46, 5, 10)
	_fill(B, r, 49, 7, 56, 24)
	_fill(B, r, 49, 40, 56, 46)
	_fill(B, r, 8, 51, 44, 56, 3, 7)
	_fill(B, r, 49, 51, 56, 56, 3, 7)
	_fill(B, r, 7, 0, 44, 2, 4, 8)
	_fill(B, r, 49, 0, 56, 2, 4, 8)
	B.add_decor({type = "billboard", x = 29, y = 13.2, w = 5, h = 4, text = "LÚMEN", sub = "O FUTURO TEM ENDEREÇO", col = "#ffd36b"})
	for x in range(15, 44, 5):
		B.lamp(x + .5, 14.4, "#cfe8ff")
		B.lamp(x + .5, 40.6, "#cfe8ff")
	for y in range(18, 40, 6):
		B.lamp(14.4, y + .5, "#ffd99a")
		B.lamp(44.6, y + .5, "#ffd99a")
	for p in [[50, 27], [56, 27], [50, 37.6], [56, 37.6]]:
		B.lamp(p[0], p[1], "#ff3d5a")
	for x in range(2, 56, 8):
		B.lamp(x + .5, 3.4, "#ffcf7a")
		B.lamp(x + .5, 47.4, "#ffcf7a")
	B.cam(14.6, 14.6, PI / 4, {sweep = .8})
	B.cam(43.4, 40.4, -3 * PI / 4, {sweep = .8})
	B.cam(43.4, 19.4, 3 * PI / 4, {sweep = .6})
	B.cam(49.4, 26.6, PI / 4, {strict = true, sweep = .5})
	var real := randi() % 3
	var cands := []
	for k in 3:
		var p: Vector2 = ROUTE[k * 3 % ROUTE.size()]
		var v := B.unit("vip", p.x, p.y)
		v.nome = ALVO
		v.cand = true
		v.double = k != real
		v.route = ROUTE.slice(k * 3) + ROUTE.slice(0, k * 3)
		v.ri = 0
		v.idle_t = 1 + k * 2
		cands.append(v)
	B.M.ex.cands = cands
	var in_pav := func(t, x, y): return t == T.PLAZA and x > 20 and x < 36 and y > 20 and y < 32
	for k in 16:
		var p = B.rand_tile(in_pav)
		if p != null:
			B.unit("civil", p.x, p.y).still = true
	for k in 10:
		var p = B.rand_tile(in_pav)
		if p != null:
			B.unit("civil", p.x, p.y).home = Vector2(28, 26)
	for k in 18:
		var p = B.rand_tile(func(t, x, y): return t == T.PLAZA and (x < 19 or x > 37 or y < 19 or y > 33) and x < 45)
		if p != null:
			B.unit("civil", p.x, p.y).home = p
	for k in 16:
		var p = B.rand_tile(func(t, _x, _y): return t == T.WALK)
		if p != null:
			B.unit("civil", p.x, p.y)
	for p in [[26.5, 26.5], [30.5, 25.5], [28.5, 18.6], [28.5, 33.6], [18.6, 26], [37.4, 26], [38.5, 15.5], [44.5, 20.5], [50.5, 30], [50.5, 35], [16, 24], [42, 32]]:
		var g := B.unit("guarda", p[0], p[1])
		B.arm(g, 5)
		g.home = Vector2(p[0], p[1])
	for p in [[10, 47.4], [30, 47.4], [45, 24], [24, 13.4], [52, 6.4]]:
		B.unit("policia", p[0], p[1])
	B.lanes([{y = 4.5, dx = 1, dy = 0}, {y = 5.5, dx = -1, dy = 0}, {y = 48.5, dx = 1, dy = 0}, {y = 49.5, dx = -1, dy = 0}], 10)


static func real(M: Mission) -> Unit:
	for v in M.ex.cands:
		if not v.double:
			return v
	return null


static func identify(S: MS, M: Mission, silent := false) -> void:
	var v := real(M)
	if M.vip == v:
		return
	M.vip = v
	v.scanned = true
	S.set_obj("kill", {text = "Elimine %s (identificado)" % ALVO})
	if not silent:
		S.say("ctl:m6_real")


static func paint(P: MPaint) -> void:
	var TS := MPaint.TS
	for y in range(14, 41):
		for x in range(14, 45):
			P.fill(x * TS + 1, y * TS + 1, TS - 2, TS - 2, Color("#5a5868") if (x + y) % 2 else Color("#4c4a5a"))
	for y in range(21, 32):
		for x in range(21, 36):
			P.fill(x * TS, y * TS, TS, TS, Color("#4a3426") if x % 2 else Color("#3e2c20"))
			P.fill(x * TS, y * TS, TS, 2, Color(.6, .55, .45))
	P.fill(49 * TS, 26 * TS, 8 * TS, 13 * TS, Color("#2a2c34"))
	P.ring(HELI.x * TS, HELI.y * TS, 2.6 * TS, Color("#ffd36b"), 4)
	P.helipad_h(HELI.x * TS, HELI.y * TS, TS * .5, Color("#ffd36b"))


static func run(S: MS, M: Mission) -> void:
	S.obj("kill", "Elimine %s (alvo verdadeiro não identificado)" % ALVO, true)
	S.obj("clean", "Opcional: não mate nenhum sósia")
	S.obj("booth", "Opcional: invada o terminal da guarita de segurança")
	watch_kill(S, M)
	watch_scan(S, M)
	watch_booth(S, M)
	watch_doubles(S, M)
	watch_sibila(S, M)
	S.cine(true)
	await S.cam_to(SPAWN, 1.2, .01)
	await S.wait(.6)
	S.say("ctl:m6_intro1")
	await S.cam_to(Vector2(28, 26), .95, 3.2)
	await S.talk_done()
	S.say("ctl:m6_intro2")
	await S.cam_to(Vector2(41, 17), 1.15, 2.4)
	await S.talk_done()
	S.say("ctl:m6_intro3")
	await S.cam_to(Vector2(51, 32), 1.1, 2.4)
	await S.talk_done()
	await S.cam_to(SPAWN, 1.2, 1.8)
	S.cine(false)


static func watch_scan(S: MS, M: Mission) -> void:
	while true:
		if M.vip:
			return
		for v in M.ex.cands:
			if v.dead or v.scanned:
				continue
			var near := false
			for a in M.agents:
				if not a.dead and a.dist_to(v) < 3.2 and M.los(a.x, a.y, v.x, v.y):
					near = true
					break
			v.scan_p = v.scan_p + .2 if near else maxf(0, v.scan_p - .1)
			if v.scan_p >= 1.6:
				v.scanned = true
				if v.double:
					S.say("ctl:m6_double")
					S.note("Scanner: implante genérico. É um sósia.", "amber")
				else:
					identify(S, M)
					S.note("Scanner: implantes de executivo. É %s." % ALVO, "green")
		var left: Array = M.ex.cands.filter(func(v): return not v.scanned and not v.dead)
		if not M.vip and left.size() == 1 and not left[0].double:
			identify(S, M)
			S.note("Os outros dois são sósias: só sobrou o verdadeiro.", "green")
		await S.wait(.2)


static func watch_booth(S: MS, M: Mission) -> void:
	await S.until(func(): return M.flags.get("booth", false))
	S.set_obj("booth", {state = "done"})
	S.bonus("Guarita invadida", 800)
	for v in M.ex.cands:
		v.scanned = true
	if not real(M).dead:
		identify(S, M, true)
		S.say("ctl:m6_booth")


static func watch_doubles(S: MS, M: Mission) -> void:
	await S.until(func(): return M.ex.cands.any(func(v): return v.double and v.dead and not v.vanished))
	S.set_obj("clean", {state = "failed"})
	if not real(M).dead:
		S.say("ctl:m6_wrong")


static func watch_kill(S: MS, M: Mission) -> void:
	var v := real(M)
	await S.until(func(): return v.dead)
	if not M.vip:
		M.vip = v
	S.set_obj("kill", {state = "done"})
	if S.obj_state("clean") == "active":
		S.set_obj("clean", {state = "done"})
		S.bonus("Nenhum sósia morto", 2000)
	S.say("ctl:m6_win")
	S.win("%s foi eliminado na Gala Lúmen." % ALVO)


static func watch_sibila(S: MS, M: Mission) -> void:
	await S.until(func(): return M.corp_alert)
	await S.wait(4)
	var s := S.rival("sibila", 54.5, 28.5, .9)
	if s:
		s.home = Vector2(52, 30)
		S.obj("sib", "Opcional: elimine a Sibila")
		S.say("ctl:m6_sibila")
		await S.until(func(): return s.dead)
		S.set_obj("sib", {state = "failed" if s.vanished else "done"})

## Simulação tática (porte de v2/js/sim.js): percepção e alarme, polícia, combate com cobertura e supressão,
## granadas e barris, sonda neural e seguidores, IA de civis, polícia, guardas, inimigos, VIP, cientista e torretas,
## agentes com ordens, reforços e fim de missão. Os efeitos visuais saem pelo sinal "fx".
class_name Sim
extends RefCounted

signal log_msg(text: String, col: String)
signal fx(kind: String, data: Dictionary)

var M: Mission
const N := C.N
const T := C.T
const PRESETS := [{n = "CONTIDO", r = .25, p = .45, c = .85}, {n = "PADRÃO", r = .5, p = .5, c = .5}, {n = "SOBRECARGA", r = .95, p = .95, c = .55}]


## Efeito dos mostradores neurais: reflexo acelera e aumenta a cadência; percepção dá precisão e alcance;
## controle dá resistência a dano, discrição e força na sonda. Em colapso, tudo cai.
static func neuro_mods(u: Unit) -> Dictionary:
	if u.colapso > 0:
		return {spd = .5, acc = .5, rof = 1.4, rng = .9, res = 0.0}
	var n := u.nr
	return {spd = .75 + .75 * n.r, rof = 1.2 - .5 * n.r, acc = .75 + .65 * n.p, rng = 1 + .15 * n.p, res = .3 * n.c}


func lit_at(px: float, py: float) -> bool:
	var L: Array = M.lamps if not M.lamps.is_empty() else M.map.get("lamps", [])
	for l in L:
		if l.get("dead", false):
			continue
		var r := 5.0 if l.get("tall", false) else 3.2
		if absf(l.x - px) < r and absf(l.y - py) < r and Vector2(l.x - px, l.y - py).length() < r:
			return true
	return false


func set_preset(i: int) -> void:
	var p: Dictionary = PRESETS[i]
	for u in M.sel:
		if u.colapso <= 0:
			u.nr = {r = p.r, p = p.p, c = p.c}
	fx.emit("preset", {i = i, u = M.sel[0] if not M.sel.is_empty() else null})


func set_dial(k: String, v: float) -> void:
	for u in M.sel:
		if u.colapso <= 0:
			u.nr[k] = clampf(v, 0, 1)


func preset_of(u: Unit) -> int:
	for i in PRESETS.size():
		var p: Dictionary = PRESETS[i]
		if absf(p.r - u.nr.r) < .01 and absf(p.p - u.nr.p) < .01 and absf(p.c - u.nr.c) < .01:
			return i
	return -1


func upd_neuro(u: Unit, dt: float) -> void:
	var cx: int = u.ag.imp.cortex if u.ag != null else 0
	var load: float = u.nr.r + u.nr.p + u.nr.c - 1.5
	if u.colapso > 0:
		u.colapso -= dt
		if u.colapso <= 0:
			u.nr = {r = .25, p = .45, c = .85}
	elif load > 0:
		u.estab -= dt * load * 10 * (1 - cx * .2) * (.7 if Camp.has("estab") else 1.0)
		u.over += dt * load
		if u.estab <= 0:
			u.estab = 0
			u.colapso = 3.0 if Camp.has("limpa") else 6.0
			say_log("%s entrou em colapso neural." % u.nome, "red")
			fx.emit("crash", {u = u})
	else:
		u.estab = minf(u.max_estab, u.estab + dt * (3 - load * 10) * (1 + cx * .3))
	if load > .4 and u.colapso <= 0 and u.in_car == null:
		u.spark_t -= dt
		if u.spark_t <= 0:
			u.spark_t = .35 + randf() * .3
			fx.emit("spark", {x = u.x, y = u.y})
	u.neuro = neuro_mods(u)


func _init(m: Mission) -> void:
	M = m


func say_log(t: String, c := "") -> void:
	log_msg.emit(t, c)


# ---------------------------------------------------------------- utilidades
static func gauss() -> float:
	return (randf() + randf() + randf() - 1.5) * 1.15


func cur_w(u: Unit) -> String:
	if u.kind == "agente":
		return u.inv[u.eq].t if u.eq >= 0 else ""
	return u.w


func is_armed(u: Unit) -> bool:
	var w := cur_w(u)
	return w != "" and GD.WD[w].get("arma", false)


func is_enemy_of(a: Unit, b: Unit) -> bool:
	if b.dead:
		return false
	if a.fac == "player":
		if b.fac == "corp":
			return b.alerted
		if b.fac == "police":
			return M.police_aggro > 0
		return false
	if a.fac == "corp":
		return a.alerted and b.fac == "player"
	if a.fac == "police":
		return M.police_aggro > 0 and b.fac == "player"
	return false


func nearest_hostile(u: Unit, rng: float) -> Unit:
	var best: Unit = null
	var bd := rng
	for v in M.units:
		if v == u or v.dead or not is_enemy_of(u, v):
			continue
		var d := u.dist_to(v)
		if d < bd and not (v.cloak and d > 1.5) and M.los(u.x, u.y, v.x, v.y):
			best = v
			bd = d
	return best


func nearest_agent(u: Unit, r: float) -> Unit:
	var best: Unit = null
	var bd := r
	for a in M.agents:
		if a.dead:
			continue
		var d := u.dist_to(a)
		if d < bd:
			best = a
			bd = d
	return best


func aim_at(u: Unit, px: float, py: float) -> void:
	u.face = atan2(py - u.y, px - u.x)
	u.aim_t = .6


# ---------------------------------------------------------------- percepção
func alert_corp(v: Unit, px: float, py: float) -> void:
	if v.alerted or v.fac != "corp":
		return
	v.alerted = true
	v.lkp = Vector2(px, py)
	v.cool = maxf(v.cool, .5 + randf() * .6)
	for o in M.units:
		if not o.dead and o.fac == "corp" and not o.alerted and o.dist_to(v) < 11:
			o.alerted = true
			o.lkp = Vector2(px, py)
	if not M.corp_alert:
		M.corp_alert = true
		say_log("ALERTA: a segurança do Consórcio detectou o esquadrão.", "red")
		fx.emit("alarm", {})


func trigger_police(msg: String) -> void:
	if M.police_aggro <= 0:
		say_log(msg, "red")
		M.reinf_t = 14
		fx.emit("siren", {})
	M.police_aggro = 26 if Camp.has("trafego") else 40


func police_sees(px: float, py: float, r: float) -> bool:
	for p in M.units:
		if p.kind == "policia" and not p.dead and not p.follower and Vector2(p.x - px, p.y - py).length() < r and M.los(p.x, p.y, px, py):
			return true
	return false


func noise(px: float, py: float, r: float, src: Unit) -> void:
	if M.flags.get("trainNoise", false):
		r *= .35
	for v in M.units:
		if v.dead or v.follower:
			continue
		var d := Vector2(v.x - px, v.y - py).length()
		if d > r:
			continue
		if v.kind == "civil":
			if v.panic_t <= 0:
				v.path = []
			v.panic_t = 6 + randf() * 4
			v.pfx = px
			v.pfy = py
		elif v.fac == "corp" and not v.alerted and src and src.fac == "player":
			alert_corp(v, px, py)
		elif v.kind == "policia" and src and src.fac == "player" and M.police_aggro <= 0:
			if d < 9 and M.los(v.x, v.y, src.x, src.y):
				trigger_police("A polícia viu o esquadrão atirando.")
			elif not v.invest:
				v.invest = true
				M.path_to(v, px, py)


func detect(u: Unit, dt: float, dr: float, hr: float) -> void:
	u.perc_t -= dt
	if u.perc_t > 0:
		return
	u.perc_t = .3
	for a in M.agents:
		if a.dead or a.cloak:
			continue
		var d := u.dist_to(a)
		var r: float = (dr if is_armed(a) else hr) * (1.2 - .5 * a.nr.c)
		if d < r * 1.4 and not lit_at(a.x, a.y):
			r *= .72
		if d < r and M.los(u.x, u.y, a.x, a.y):
			alert_corp(u, a.x, a.y)
			u.tgt = a
			return


# ---------------------------------------------------------------- combate
func ray_wall(x0: float, y0: float, dx: float, dy: float, max_t: float) -> float:
	var s := .15
	while s < max_t:
		var xi := int(x0 + dx * s)
		var yi := int(y0 + dy * s)
		if xi < 0 or yi < 0 or xi >= N or yi >= N:
			return s
		if M.tile[yi * N + xi] == T.BLD:
			return s
		s += .1
	return max_t


func fire_weapon(u: Unit, wk: String, st, tx: float, ty: float, acc_mul := 1.0, rof_mul := 1.0, rng_mul := 1.0) -> bool:
	if wk == "" or not GD.WD.has(wk):
		return false
	var w: Dictionary = GD.WD[wk]
	if not w.get("arma", false) or u.cool > 0 or u.rel > 0:
		return false
	var mun: int = st.mun
	if mun <= 0:
		u.rel = w.recarga
		u.rel_st = st
		u.rel_w = wk
		return false
	st.mun = mun - 1
	if st.mun <= 0:
		u.rel = w.recarga
		u.rel_st = st
		u.rel_w = wk
	if u.fac == "player" or u.alerted:
		M.last_combat = M.t
	u.cool = w.cad * rof_mul * (2.5 if u.heavy else 1.0)
	u.flash = .07
	aim_at(u, tx, ty)
	var ang := u.face
	var acc := minf(1.15, u.acc * acc_mul)
	var rng: float = w.alcance * u.rng_mul * rng_mul
	var mx := u.x + cos(ang) * .45
	var my := u.y + sin(ang) * .45
	fx.emit("muzzle", {x = mx, y = my, laser = w.get("laser", false), u = u, wk = wk})
	if w.get("flame", false):
		for v in M.units:
			if v == u or v.dead or v.fac == u.fac or v.in_car != null:
				continue
			var dvx := v.x - u.x
			var dvy := v.y - u.y
			if sqrt(dvx * dvx + dvy * dvy) > rng:
				continue
			var da := absf(angle_difference(atan2(dvy, dvx), ang))
			if da < .34 and M.los(u.x, u.y, v.x, v.y):
				hurt(v, w.dano, u)
				v.burn = maxf(v.burn, 2.5)
				v.burn_src = u
		fx.emit("flame", {x = mx, y = my, ang = ang, r = rng})
		noise(u.x, u.y, 7, u)
		return true
	if w.get("laser", false):
		var dx := cos(ang)
		var dy := sin(ang)
		var wt := ray_wall(u.x, u.y, dx, dy, rng)
		for v in M.units:
			if v == u or v.dead or v.fac == u.fac:
				continue
			var rx := v.x - u.x
			var ry := v.y - u.y
			var tt := rx * dx + ry * dy
			if tt < .2 or tt > wt:
				continue
			if absf(rx * dy - ry * dx) < .38:
				hurt(v, w.dano, u)
		fx.emit("tracer", {x1 = mx, y1 = my, x2 = u.x + dx * wt, y2 = u.y + dy * wt, beam = true, player = u.fac == "player"})
	else:
		var pel: int = w.get("pellets", 1)
		var sp: float = w.get("disp", .05) + (1 - minf(acc, 1)) * .22
		for k in pel:
			bullet(u, ang + gauss() * sp, rng * 1.12, w.dano, mx, my)
	noise(u.x, u.y, 9.0 if w.get("laser", false) else 11.0, u)
	return true


func bullet(u: Unit, a: float, rng: float, dmg: float, mx: float, my: float) -> void:
	var dx := cos(a)
	var dy := sin(a)
	var wt := ray_wall(u.x, u.y, dx, dy, rng)
	var best: Unit = null
	var bt := wt
	var prop = null
	for v in M.units:
		if v == u or v.dead or v.fac == u.fac or v.in_car != null or v.hold or (u.fac == "player" and v.kind == "cientista"):
			continue
		var rx := v.x - u.x
		var ry := v.y - u.y
		var tt := rx * dx + ry * dy
		if tt < .2 or tt > bt:
			continue
		if absf(rx * dy - ry * dx) < (.38 if v.mech else .3):
			best = v
			bt = tt
	for p in M.props:
		if p.dead:
			continue
		var rx: float = p.x - u.x
		var ry: float = p.y - u.y
		var tt := rx * dx + ry * dy
		if tt < .3 or tt > bt:
			continue
		if absf(rx * dy - ry * dx) < .28:
			prop = p
			best = null
			bt = tt
	var car = null
	for c in M.cars:
		if c.dead or c.occ.any(func(o): return o.fac == u.fac):
			continue
		var rx: float = c.x - u.x
		var ry: float = c.y - u.y
		var tt := rx * dx + ry * dy
		if tt < .3 or tt > bt:
			continue
		if absf(rx * dy - ry * dx) < .5:
			car = c
			best = null
			prop = null
			bt = tt
	for c in M.cams:
		if c.dead:
			continue
		var rx: float = c.x - u.x
		var ry: float = c.y - u.y
		var tt := rx * dx + ry * dy
		if tt < .3 or tt > bt:
			continue
		if absf(rx * dy - ry * dx) < .25:
			hurt_cam(c)
			break
	if M.glass_n > 0:
		var gs := .25
		while gs < bt:
			var gx := int(u.x + dx * gs)
			var gy := int(u.y + dy * gs)
			if gx >= 0 and gy >= 0 and gx < N and gy < N and M.tile[gy * N + gx] == T.GLASS:
				shatter_glass(gx, gy)
			gs += .2
	if best and u.dist_to(best) > 1.6 and cover_at(best.x, best.y, Vector2(u.x, u.y)) and randf() < .5:
		bt = maxf(.2, bt - .45)
		best = null
	for v in M.units:
		if v == best or v.dead or v.fac == u.fac or v.fac == "civ" or v.fac == "neutral" or v.heavy:
			continue
		var rx := v.x - u.x
		var ry := v.y - u.y
		var tt := rx * dx + ry * dy
		if tt < .2 or tt > bt + .6:
			continue
		if absf(rx * dy - ry * dx) < .7:
			v.supp_p += .22
			if v.supp_p >= 1:
				if v.supp <= 0:
					v.cover_t = minf(v.cover_t, .15)
				v.supp = 1.2
				v.supp_p = .5
	var ex := u.x + dx * bt
	var ey := u.y + dy * bt
	fx.emit("tracer", {x1 = mx, y1 = my, x2 = ex, y2 = ey, beam = false, player = u.fac == "player", hit = best != null, wall = best == null and prop == null and bt >= wt - .001 and bt < rng - .01})
	if best:
		hurt(best, dmg, u)
	elif prop:
		hurt_prop(prop, dmg, u)
	elif car != null:
		hurt_car(car, dmg, u)


func hurt(v: Unit, dmg: float, src: Unit) -> void:
	if v.dead:
		return
	if v.shield:
		fx.emit("shield", {x = v.x, y = v.y})
		if src and src.fac == "player" and v.fac == "corp":
			alert_corp(v, src.x, src.y)
		return
	if v.hold:
		dmg *= .3
	if v.kind == "agente":
		dmg *= 1 - v.neuro.res
	v.hp -= dmg * (1 - v.armor * (.5 if src and src.fac == "player" and Camp.has("perfurante") else 1.0))
	v.hit_t = .08
	v.last_hit = M.t
	if not v.mech and randf() < .6:
		fx.emit("blood", {x = v.x, y = v.y})
	if src and src.fac == "player" and src != v:
		if v.fac == "corp":
			if v.disguise:
				reveal(v)
			alert_corp(v, src.x, src.y)
		if v.fac == "police":
			trigger_police("O esquadrão atacou a polícia.")
		if (v.fac == "civ" or v.fac == "neutral") and M.police_aggro <= 0 and police_sees(v.x, v.y, 10):
			trigger_police("A polícia testemunhou um ataque a civis.")
	if src and src != v and v.tgt == null and v.fac != "civ" and v.fac != "neutral" and is_enemy_of(v, src):
		v.tgt = src
	if v.kind == "agente" and v.hp > 0 and v.hp < v.max_hp * .55:
		fx.emit("hurt", {u = v})
	if v.hp <= 0:
		kill(v, src)


func kill(v: Unit, src: Unit) -> void:
	v.dead = true
	v.death_t = 0
	v.path = []
	v.hp = 0
	v.burn = 0
	v.hj = 0
	if v.kind == "torre":
		explode(v.x, v.y, 1.2, 25, src)
		fx.emit("death", {u = v, src = src})
		return
	if v.kind == "drone":
		explode(v.x, v.y, .9, 14, src)
		if src and src.fac == "player" and v.fac != "player":
			M.stats.abates += 1
		fx.emit("death", {u = v, src = src})
		return
	if v.rival != "" and not v.vanished:
		M.rival_dead.append(v.rival)
		M.bonus.append({text = "Ponteiro eliminado: " + v.nome, val = 3000})
		say_log("%s está morto." % v.nome, "green")
	var drop_w := cur_w(v) if is_armed(v) else ""
	if drop_w != "":
		M.drops.append({x = v.x + (randf() - .5) * .3, y = v.y + (randf() - .5) * .3, t = drop_w})
	if v.follower:
		M.followers = maxi(0, M.followers - 1)
	if src and src.fac == "player" and not v.follower:
		M.stats.abates += 1
		if v.kind == "civil":
			M.stats.civis += 1
		if v.kind == "policia":
			M.stats.policiais += 1
		if src.kind == "agente":
			src.kills += 1
	if v.kind == "agente":
		say_log("Agente %s foi abatido." % v.nome, "red")
		M.sel.erase(v)
		v.sel = false
	if v.kind == "vip":
		say_log("Um sósia foi abatido." if v.double else "Alvo eliminado: %s." % v.nome, "amber" if v.double else "green")
	if v.kind == "cientista":
		say_log("%s foi %s no fogo cruzado." % [v.nome, "morta" if v.fem() else "morto"], "red")
	fx.emit("death", {u = v, src = src})


func hurt_prop(p: Dictionary, dmg: float, src: Unit) -> void:
	if p.dead:
		return
	p.hp -= dmg
	if p.hp <= 0:
		p.dead = true
		explode(p.x, p.y, 2.4, 75, src)


func explode(px: float, py: float, r: float, dmg: float, src: Unit) -> void:
	fx.emit("explosion", {x = px, y = py, r = r})
	for v in M.units:
		if v.dead:
			continue
		var d := Vector2(v.x - px, v.y - py).length()
		if d < r:
			v.burn = maxf(v.burn, 1.2)
			v.burn_src = src
			hurt(v, dmg * (1 - .6 * d / r), src)
	for p in M.props:
		if not p.dead and Vector2(p.x - px, p.y - py).length() < r + .3:
			hurt_prop(p, 999, src)
	for c in M.cars:
		if not c.dead and Vector2(c.x - px, c.y - py).length() < r + .6:
			hurt_car(c, dmg * .8, src)
	for c in M.cams:
		if not c.dead and Vector2(c.x - px, c.y - py).length() < r + .5:
			hurt_cam(c)
	if M.glass_n > 0:
		for gy in range(maxi(0, int(py - r - 1)), mini(N, int(py + r + 2))):
			for gx in range(maxi(0, int(px - r - 1)), mini(N, int(px + r + 2))):
				if M.tile[gy * N + gx] == T.GLASS and Vector2(gx + .5 - px, gy + .5 - py).length() < r + .6:
					shatter_glass(gx, gy)
	for l in M.lamps:
		if not l.get("dead", false) and Vector2(l.x - px, l.y - py).length() < r + .6:
			l.dead = true
			M.events.append({k = "lamp", l = l})
	noise(px, py, 16, src)


# ---------------------------------------------------------------- sonda neural
func convert_unit(v: Unit, owner: Unit) -> void:
	v.fac = "player"
	v.follower = true
	v.owner = owner
	v.hj = 0
	v.hj_t = 0
	v.alerted = false
	v.tgt = null
	v.path = []
	v.panic_t = 0
	v.warned = false
	v.invest = false
	v.escort = null
	v.spd = maxf(v.spd, 2.15)
	if v.kind == "civil":
		v.max_hp = maxf(v.max_hp, 45)
		v.hp = v.max_hp
		if Camp.has("armados") and v.w == "":
			v.w = "pistola"
			v.mun = GD.WD.pistola.pente
			fx.emit("armed", {u = v})
	M.followers += 1
	M.stats.seguidores += 1
	fx.emit("convert", {u = v})
	if M.followers == 1:
		say_log("Primeiro seguidor recrutado. Seguidores apanham armas do chão e lutam pelo esquadrão.", "cyan")


func hijack_tick(u: Unit, dt: float, w: Dictionary) -> void:
	var pw: float = minf(4, 1 + .2 * M.followers) * (.7 + .6 * u.nr.c) * (1.3 if Camp.has("sonda2") else 1.0) * (1.6 if Camp.has("sonda3") else 1.0)
	var rng: float = w.alcance + (1.0 if Camp.has("sonda2") else 0.0)
	var any := false
	for v in M.units:
		if v.dead or v.fac == "player":
			continue
		if not GD.RESIST.has(v.kind):
			continue
		if u.dist_to(v) > rng or not M.los(u.x, u.y, v.x, v.y):
			continue
		v.hj += dt * pw / (GD.RESIST[v.kind] * (1.5 if v.alerted else 1.0))
		v.hj_t = .25
		any = true
		if v.hj >= 1:
			convert_unit(v, u)
	u.probing = any
	u.pulse_t -= dt
	if u.pulse_t <= 0:
		u.pulse_t = .75
		fx.emit("pulse", {x = u.x, y = u.y, r = rng})


func upd_follower(u: Unit, dt: float) -> void:
	if u.w != "" and GD.WD[u.w].get("arma", false):
		if ai_combat(u, dt, GD.WD[u.w].alcance):
			return
	else:
		var best = null
		var bd := 7.0
		for d in M.drops:
			var dd := Vector2(d.x - u.x, d.y - u.y).length()
			if dd < bd:
				bd = dd
				best = d
		if best:
			if bd < .6:
				u.w = best.t
				u.mun = GD.WD[best.t].pente
				M.drops.erase(best)
				fx.emit("armed", {u = u})
				return
			u.rep_t -= dt
			if u.rep_t <= 0 or u.path.is_empty():
				u.rep_t = .8
				M.path_to(u, best.x, best.y)
			M.move_along(u, dt, u.spd)
			return
	var L: Unit = u.owner if u.owner and not u.owner.dead else nearest_agent(u, 999)
	if L == null:
		return
	var d := u.dist_to(L)
	if d > 2.4:
		u.rep_t -= dt
		if u.rep_t <= 0 or u.path.is_empty():
			u.rep_t = .7 + randf() * .4
			M.path_to(u, L.x + (randf() - .5) * 2, L.y + (randf() - .5) * 2)
		M.move_along(u, dt, u.spd * (1.3 if d > 6 else 1.0))
	elif not u.path.is_empty():
		M.move_along(u, dt, u.spd * .8)
	else:
		u.cur_spd = 0


# ---------------------------------------------------------------- cobertura
const N8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


func cover_at(px: float, py: float, from: Vector2) -> bool:
	var u := (from - Vector2(px, py)).normalized()
	var tx := int(floor(px))
	var ty := int(floor(py))
	for o in N8:
		var ol := Vector2(o).length()
		if (o.x * u.x + o.y * u.y) / ol < .72:
			continue
		var X: int = tx + o.x
		var Y: int = ty + o.y
		if X < 0 or Y < 0 or X >= N or Y >= N:
			continue
		if M.tile[Y * N + X] == T.BLD:
			return true
	return false


func find_cover(u: Unit, tp: Vector2, rng: float, retreat: bool):
	var best = null
	var bs := -1e9
	var R := 7.0 if retreat else 5.0
	for k in 36:
		var cx := floorf(u.x + (randf() * 2 - 1) * R) + .5
		var cy := floorf(u.y + (randf() * 2 - 1) * R) + .5
		if not M.can_stand(cx, cy):
			continue
		var dtp := tp.distance_to(Vector2(cx, cy))
		if dtp < 2.2 or (not retreat and dtp > rng * .95):
			continue
		if not cover_at(cx, cy, tp):
			continue
		if not retreat and not M.los(cx, cy, tp.x, tp.y):
			continue
		var s := -Vector2(cx - u.x, cy - u.y).length() * .5 + (dtp * .8 if retreat else -absf(dtp - rng * .7) * .4)
		if s > bs:
			bs = s
			best = Vector2(cx, cy)
	return best


func enemy_nade(u: Unit, tp: Vector2, d: float) -> void:
	u.nades -= 1
	u.nade_t = M.t + 7
	var tx := tp.x + (randf() - .5) * .8
	var ty := tp.y + (randf() - .5) * .8
	aim_at(u, tx, ty)
	M.nades.append({sx = u.x, sy = u.y, tx = tx, ty = ty, t = 0.0, T = 1.15 + d * .06, src = u, wt = "granada"})
	fx.emit("nade", {})


func smart_ai(u: Unit) -> bool:
	return not u.follower and u.spd > 0 and (u.kind == "guarda" or u.kind == "inimigo" or u.kind == "policia")


func ai_combat(u: Unit, dt: float, rng: float) -> bool:
	var t := u.tgt
	if t and (t.dead or not is_enemy_of(u, t) or (t.cloak and u.dist_to(t) > 1.5)):
		t = null
		u.tgt = null
	u.scan_t -= dt
	if u.scan_t <= 0:
		u.scan_t = .35 + randf() * .2
		var nt := nearest_hostile(u, rng * 1.3)
		if nt:
			if nt != t:
				u.cool = maxf(u.cool, .25 + randf() * .3)
			t = nt
			u.tgt = nt
	if t == null:
		return false
	var tp := Vector2(t.x, t.y)
	var d := u.dist_to(t)
	var vis := d <= rng * 1.35 and M.los(u.x, u.y, tp.x, tp.y)
	var smart := smart_ai(u)
	var acc := .6 if u.supp > 0 else 1.0
	if vis:
		u.lost_t = 0
		u.lkp = tp
		if u.kind == "policia" and not u.follower:
			M.police_aggro = maxf(M.police_aggro, 30)
			M.last_seen = tp
		if smart:
			u.cover_t = (randf() * .8 if u.cover_t < 0 else u.cover_t) - dt
			if u.hp < u.max_hp * .35 and not u.retreated:
				u.retreated = true
				var c = find_cover(u, tp, rng, true)
				if c != null:
					u.cover = c
					M.path_to(u, c.x, c.y)
			elif u.cover_t <= 0:
				u.cover_t = 2.5 + randf() * 2
				if d > rng or not cover_at(u.x, u.y, tp):
					var c = find_cover(u, tp, rng, false)
					if c != null and Vector2(c.x - u.x, c.y - u.y).length() > .5:
						u.cover = c
						M.path_to(u, c.x, c.y)
			if u.nades > 0 and M.t >= u.nade_t and d > 3 and d < 7.5 and cover_at(tp.x, tp.y, Vector2(u.x, u.y)):
				enemy_nade(u, tp, d)
			if not u.path.is_empty() and u.cover != null:
				M.move_along(u, dt, u.spd * 1.3)
				if d <= rng:
					aim_at(u, tp.x, tp.y)
					fire_weapon(u, u.w, u, tp.x, tp.y, .55 * acc)
				return true
		if d <= rng:
			u.path = []
			u.cur_spd = 0
			aim_at(u, tp.x, tp.y)
			fire_weapon(u, u.w, u, tp.x, tp.y, acc)
			return true
	else:
		u.lost_t += dt
		if u.lost_t > 4:
			u.tgt = null
			u.cover = null
			return false
	if u.spd > 0:
		if smart and not u.path.is_empty() and u.cover != null:
			M.move_along(u, dt, u.spd * 1.3)
			return true
		u.cover = null
		u.rep_t -= dt
		if u.rep_t <= 0 or u.path.is_empty():
			u.rep_t = .8 + randf() * .5
			M.path_to(u, tp.x, tp.y)
		M.move_along(u, dt, u.spd * 1.15)
	return true


# ---------------------------------------------------------------- IA por tipo
func wander(u: Unit, dt: float, cx: float, cy: float, r: float, mul: float, side := true) -> void:
	if not u.path.is_empty():
		M.move_along(u, dt, u.spd * mul)
		return
	u.cur_spd = 0
	u.idle_t -= dt
	if u.idle_t > 0:
		return
	u.idle_t = 1 + randf() * 4
	var p = M.random_near(cx, cy, r, M.side_tile if side else Callable())
	if p != null:
		M.path_to(u, p.x, p.y)


func upd_civ(u: Unit, dt: float) -> void:
	if u.still and u.panic_t <= 0:
		u.path = []
		u.cur_spd = 0
		return
	if u.panic_t > 0:
		u.panic_t -= dt
		if u.path.is_empty():
			var v := Vector2(u.x - u.pfx, u.y - u.pfy).normalized()
			var p = M.random_near(u.x + v.x * 7, u.y + v.y * 7, 3)
			if p != null:
				M.path_to(u, p.x, p.y)
		M.move_along(u, dt, 2.6)
		return
	if u.home != null:
		wander(u, dt, u.home.x, u.home.y, 6, 1)
	else:
		wander(u, dt, u.x, u.y, 10, 1)


func upd_police(u: Unit, dt: float) -> void:
	if M.police_aggro > 0:
		u.warned = false
		if ai_combat(u, dt, GD.WD[u.w].alcance):
			return
		if M.last_seen != null:
			if u.path.is_empty():
				u.rep_t -= dt
				if u.rep_t <= 0:
					u.rep_t = 2
					M.path_to(u, M.last_seen.x + (randf() - .5) * 3, M.last_seen.y + (randf() - .5) * 3)
			M.move_along(u, dt, u.spd * 1.4)
		else:
			wander(u, dt, u.x, u.y, 8, 1)
		return
	u.perc_t -= dt
	if u.perc_t <= 0:
		u.perc_t = .3
		var seen: Unit = null
		for a in M.agents:
			if not a.dead and not a.cloak and is_armed(a) and u.dist_to(a) < 7 and M.los(u.x, u.y, a.x, a.y):
				seen = a
				break
		u.seeing = seen
		if seen:
			u.path = []
			aim_at(u, seen.x, seen.y)
			u.lost = 0
			if not u.warned:
				u.warned = true
				fx.emit("pol_warn", {u = u})
				u.warn_t = 3.5
				say_log("Polícia: guardem as armas (tecla H) ou haverá confronto.", "amber")
				fx.emit("siren", {})
		elif u.warned:
			u.lost += .3
			if u.lost > 2.5:
				u.warned = false
	if u.warned and u.seeing:
		u.cur_spd = 0
		u.warn_t -= dt
		if u.warn_t <= 0:
			u.warned = false
			M.last_seen = Vector2(u.seeing.x, u.seeing.y)
			trigger_police("A polícia abriu fogo contra o esquadrão!")
		return
	if u.invest:
		if not M.move_along(u, dt, u.spd * 1.3):
			u.invest = false
		return
	wander(u, dt, u.x, u.y, 9, .9)


func upd_guard(u: Unit, dt: float) -> void:
	if u.flee_to != null:
		if M.esc_car != null and M.esc_car.dead:
			u.flee_to = null
			u.path = []
		else:
			if Vector2(u.x - u.flee_to.x, u.y - u.flee_to.y).length() < 1.4:
				u.path = []
				u.cur_spd = 0
				u.board_t += dt
				if u.board_t > 4:
					u.dead = true
					u.vanished = true
					u.hp = 0
					M.flags.escaped = M.flags.get("escaped", 0) + 1
					fx.emit("vanish", {u = u})
			else:
				if u.path.is_empty():
					M.path_to(u, u.flee_to.x, u.flee_to.y)
				M.move_along(u, dt, u.spd * 1.1)
			return
	if u.rival != "" and rival_tick(u, dt):
		return
	if not u.alerted:
		if u.kind == "inimigo" and M.corp_alert:
			u.alerted = true
		else:
			detect(u, dt, 8.5 if u.kind == "inimigo" else 7.0, 3.4)
			if not u.alerted:
				if u.escort and not u.escort.dead:
					if u.dist_to(u.escort) > 1.8:
						u.rep_t -= dt
						if u.rep_t <= 0 or u.path.is_empty():
							u.rep_t = .8
							M.path_to(u, u.escort.x + (randf() - .5), u.escort.y + (randf() - .5))
						M.move_along(u, dt, u.spd)
					else:
						u.cur_spd = 0
				else:
					var h: Vector2 = u.home if u.home != null else Vector2(u.x, u.y)
					wander(u, dt, h.x, h.y, 10.0 if u.kind == "inimigo" else 3.5, .55)
				return
	if ai_combat(u, dt, GD.WD[u.w].alcance):
		return
	if u.lkp != null:
		if Vector2(u.lkp.x - u.x, u.lkp.y - u.y).length() < 1.5:
			u.lkp = null
		else:
			if u.path.is_empty():
				u.rep_t -= dt
				if u.rep_t <= 0:
					u.rep_t = 1.2
					if not M.path_to(u, u.lkp.x, u.lkp.y):
						u.lkp = null
			M.move_along(u, dt, u.spd * 1.25)
			return
	u.hunt_t -= dt
	if u.hunt_t <= 0:
		u.hunt_t = 2.5
		var a := nearest_agent(u, 999.0 if u.kind == "inimigo" else 18.0)
		if a:
			M.path_to(u, a.x + (randf() - .5) * 2, a.y + (randf() - .5) * 2)
		elif u.home != null:
			M.path_to(u, u.home.x, u.home.y)
	M.move_along(u, dt, u.spd * 1.1)


func upd_vip(u: Unit, dt: float) -> void:
	if u.safe:
		u.path = []
		u.cur_spd = 0
		return
	if u.scripted and not M.corp_alert and not u.alerted:
		detect(u, dt, 6, 3)
		if not M.move_along(u, dt, u.spd):
			u.cur_spd = 0
		return
	if not M.corp_alert and not u.alerted:
		detect(u, dt, 6, 3)
		if u.path.is_empty():
			u.cur_spd = 0
			u.idle_t -= dt
			if u.idle_t <= 0 and not u.route.is_empty():
				u.ri = (u.ri + 1) % u.route.size()
				var p: Vector2 = u.route[u.ri]
				M.path_to(u, p.x, p.y)
				u.idle_t = 4 + randf() * 3
		M.move_along(u, dt, u.spd)
		return
	if M.escape == null:
		wander(u, dt, u.x, u.y, 4, 1.2)
		return
	if not u.fleeing:
		u.fleeing = true
		u.path = []
		if not u.double:
			say_log(u.flee_msg if u.flee_msg != "" else "%s está fugindo para o transporte de evacuação!" % u.nome, "amber")
	if u.path.is_empty():
		u.rep_t -= dt
		if u.rep_t <= 0:
			u.rep_t = 1
			M.path_to(u, M.escape.x, M.escape.y)
	M.move_along(u, dt, u.spd * 1.2)
	if Vector2(u.x - M.escape.x, u.y - M.escape.y).length() < 1.3 and not M.ended:
		if u.double:
			u.dead = true
			u.vanished = true
			u.hp = 0
			fx.emit("vanish", {u = u})
		elif u.safe_room:
			u.safe = true
			u.path = []
		else:
			M.flags.heliGo = true
			end_mission(false, "%s alcançou o transporte e escapou." % u.nome)


func upd_sci(u: Unit, dt: float) -> void:
	if u.hold:
		if not M.move_along(u, dt, u.spd):
			u.cur_spd = 0
		return
	if not u.follow:
		u.cur_spd = 0
		var a := nearest_agent(u, 1.9)
		if a:
			u.follow = true
			say_log("%s se juntou ao esquadrão. Leve-%s ao ponto de evacuação." % [u.nome, "a" if u.fem() else "o"], "green")
		return
	var a := nearest_agent(u, 999)
	if a == null:
		return
	var d := u.dist_to(a)
	if d > 1.5:
		u.rep_t -= dt
		if u.rep_t <= 0 or u.path.is_empty():
			u.rep_t = .6
			M.path_to(u, a.x, a.y)
		M.move_along(u, dt, u.spd)
	else:
		u.path = []
		u.cur_spd = 0


func upd_turret(u: Unit, dt: float) -> void:
	if u.off:
		return
	if u.fac == "corp" and not u.alerted:
		u.face += dt * .7
		detect(u, dt, 6.5, 4.5)
		if M.corp_alert and nearest_agent(u, 8):
			u.alerted = true
		return
	if not ai_combat(u, dt, 7):
		u.face += dt * .4


# ---------------------------------------------------------------- agentes
func remove_item(u: Unit, i: int) -> void:
	u.inv.remove_at(i)
	if u.eq == i:
		u.eq = -1
	elif u.eq > i:
		u.eq -= 1


func equip_first_weapon(u: Unit) -> bool:
	for i in u.inv.size():
		if GD.WD[u.inv[i].t].get("arma", false):
			u.eq = i
			return true
	return false


## Agentes dentro do carro atiram sozinhos pela janela no inimigo mais próximo (com menos precisão).
func car_fire(u: Unit, dt: float) -> void:
	upd_neuro(u, dt)
	var it = u.inv[u.eq] if u.eq >= 0 else null
	if it == null or not GD.WD[it.t].get("arma", false) or GD.WD[it.t].get("flame", false):
		return
	var w: Dictionary = GD.WD[it.t]
	var rng: float = w.alcance * u.rng_mul * u.neuro.rng
	u.scan_t -= dt
	if u.scan_t <= 0:
		u.scan_t = .3
		u.auto_t = nearest_hostile(u, rng)
	var t := u.auto_t
	if t and not t.dead and is_enemy_of(u, t) and u.dist_to(t) <= rng and M.los(u.x, u.y, t.x, t.y):
		aim_at(u, t.x, t.y)
		fire_weapon(u, it.t, it, t.x, t.y, u.neuro.acc * .75, u.neuro.rof, u.neuro.rng)


func upd_agent(u: Unit, dt: float) -> void:
	upd_neuro(u, dt)
	var NEURO: Dictionary = u.neuro
	var reg := 2.5 if Camp.has("reparo") else (0.0 if Camp.active else 1.5)
	if reg > 0 and u.hp < u.max_hp and M.t - u.last_hit > 5:
		u.hp = minf(u.max_hp, u.hp + dt * reg)
	var acc_m: float = NEURO.acc * (.65 if u.supp > 0 else 1.0)
	u.cov_t -= dt
	if u.cov_t <= 0:
		u.cov_t = .3
		var h := nearest_hostile(u, 9)
		u.covered = h != null and cover_at(u.x, u.y, Vector2(h.x, h.y))
		if u.ord == null or u.ord.k != "move":
			for q in M.nades:
				if not q.src or q.src.fac == "player" or Vector2(q.tx - u.x, q.ty - u.y).length() > 2.6:
					continue
				var v := Vector2(u.x - q.tx, u.y - q.ty).normalized()
				var p = M.random_near(u.x + v.x * 3.2, u.y + v.y * 3.2, 1.2)
				if p != null:
					M.path_to(u, p.x, p.y)
					u.ord = {k = "move"}
				break
	var it = u.inv[u.eq] if u.eq >= 0 else null
	var w: Dictionary = GD.WD[it.t] if it != null else {}
	var spd: float = u.spd * NEURO.spd * (.78 if w.get("peso", false) else 1.0)
	var rng: float = w.alcance * u.rng_mul * NEURO.rng if w.get("arma", false) else 0.0
	var o = u.ord
	if o != null:
		match o.k:
			"move":
				if u.path.is_empty():
					u.ord = null
			"atk":
				var t: Unit = o.t
				if t.dead or not w.get("arma", false) or t.fac == "player":
					u.ord = null
				else:
					var d := u.dist_to(t)
					o.engaged = d <= rng and M.los(u.x, u.y, t.x, t.y)
					if o.engaged:
						u.path = []
						fire_weapon(u, it.t, it, t.x, t.y, acc_m, NEURO.rof, NEURO.rng)
						aim_at(u, t.x, t.y)
					else:
						o.rep -= dt
						if o.rep <= 0 or u.path.is_empty():
							o.rep = .7
							M.path_to(u, t.x, t.y)
			"fire":
				o.time -= dt
				if o.time <= 0 or not w.get("arma", false):
					u.ord = null
				else:
					aim_at(u, o.x, o.y)
					fire_weapon(u, it.t, it, o.x, o.y, acc_m, NEURO.rof, NEURO.rng)
			"throw":
				var d := Vector2(o.x - u.x, o.y - u.y).length()
				var ii := u.eq if u.eq >= 0 and GD.WD[u.inv[u.eq].t].get("throw", false) else -1
				if ii < 0:
					for i in u.inv.size():
						if GD.WD[u.inv[i].t].get("throw", false):
							ii = i
							break
				if ii < 0:
					u.ord = null
				elif d <= GD.WD[u.inv[ii].t].alcance:
					u.path = []
					aim_at(u, o.x, o.y)
					M.nades.append({sx = u.x, sy = u.y, tx = o.x, ty = o.y, t = 0.0, T = .5 + d * .07, src = u, wt = u.inv[ii].t})
					fx.emit("nade", {u = u})
					remove_item(u, ii)
					if not equip_first_weapon(u):
						u.eq = -1
					u.ord = null
				elif u.path.is_empty():
					M.path_to(u, o.x, o.y)
			"enter":
				var c: Dictionary = o.c
				if c.dead:
					u.ord = null
				else:
					c.held = 1.0
					if Vector2(c.x - u.x, c.y - u.y).length() < 1.15:
						board_car(u, c)
						return
					o.rep -= dt
					if o.rep <= 0 or u.path.is_empty():
						o.rep = .6
						M.path_to(u, c.x, c.y)
			"hack":
				var t: Unit = o.t
				if t.dead or t.fac != "corp" or not w.get("hack", false):
					u.ord = null
				elif u.dist_to(t) <= w.alcance and M.los(u.x, u.y, t.x, t.y):
					u.path = []
					aim_at(u, t.x, t.y)
					o.p += dt
					t.hj_t = .25
					if o.p >= 2.2:
						t.fac = "player"
						t.follower = t.kind == "drone"
						t.off = false
						t.alerted = false
						t.tgt = null
						t.lkp = null
						say_log("Drone invadido: agora ele protege o esquadrão." if t.kind == "drone" else "Torreta invadida: agora ela protege o esquadrão.", "cyan")
						fx.emit("convert", {u = t})
						u.ord = null
				elif u.path.is_empty():
					M.path_to(u, t.x, t.y)
	if w.get("manto", false):
		if it.get("bat", -1.0) < 0:
			it.bat = 25.0
		if it.bat > 0:
			it.bat -= dt
			u.cloak = true
			if it.bat <= 0:
				u.cloak = false
				say_log("O manto de %s descarregou." % u.nome, "amber")
		else:
			u.cloak = false
	else:
		u.cloak = false
	if w.get("arma", false) and not (o != null and (o.k == "fire" or (o.k == "atk" and o.get("engaged", false)))):
		u.scan_t -= dt
		if u.scan_t <= 0:
			u.scan_t = .25
			u.auto_t = nearest_hostile(u, rng)
		var t := u.auto_t
		if t:
			if t.dead or not is_enemy_of(u, t):
				u.auto_t = null
			elif u.dist_to(t) <= rng and M.los(u.x, u.y, t.x, t.y):
				aim_at(u, t.x, t.y)
				fire_weapon(u, it.t, it, t.x, t.y, acc_m, NEURO.rof, NEURO.rng)
	if w.get("sonda", false):
		hijack_tick(u, dt, w)
	else:
		u.probing = false
	if not M.move_along(u, dt, spd):
		u.cur_spd = 0
	for i in range(M.drops.size() - 1, -1, -1):
		var d = M.drops[i]
		if Vector2(d.x - u.x, d.y - u.y).length() > .7 or u.inv.size() >= 6:
			continue
		u.inv.append({t = d.t, mun = pente_of(u, d.t)})
		M.drops.remove_at(i)
		say_log("%s pegou %s." % [u.nome, GD.WD[d.t].ab], "cyan")
		fx.emit("pickup", {u = u})
	for tm in M.terms:
		if tm.done or Vector2(tm.x - u.x, tm.y - u.y).length() > 1.4:
			continue
		tm.prog += dt
		if tm.prog >= 4:
			tm.done = true
			fx.emit("hack", {x = tm.x, y = tm.y})
			if tm.get("flag", "") != "":
				M.flags[tm.flag] = true
				if tm.get("msg", "") != "":
					say_log(tm.msg, "cyan")
				continue
			if tm.get("crane", false):
				M.flags.crane = true
				say_log("Cabine do guindaste invadida. Tecla G solta o contêiner.", "cyan")
				continue
			say_log("Terminal invadido (%d/%d)." % [M.terms.filter(func(q): return q.done).size(), M.terms.size()], "cyan")
			noise(tm.x, tm.y, 9, u)
			fx.emit("hack", {x = tm.x, y = tm.y})


# ---------------------------------------------------------------- laço
func separate() -> void:
	var U := M.units
	for i in U.size():
		var a := U[i]
		if a.dead or a.mech or a.in_car != null or a.hold or a.fly:
			continue
		for j in range(i + 1, U.size()):
			var b := U[j]
			if b.dead or b.mech or b.in_car != null or b.hold or b.fly:
				continue
			var dx := b.x - a.x
			var dy := b.y - a.y
			if absf(dx) > .42 or absf(dy) > .42:
				continue
			var d2 := dx * dx + dy * dy
			if d2 >= .1764 or d2 < 1e-6:
				continue
			var d := sqrt(d2)
			var push := (.42 - d) * .5
			var nx := dx / d * push
			var ny := dy / d * push
			if M.can_stand(a.x - nx, a.y - ny):
				a.x -= nx
				a.y -= ny
			if M.can_stand(b.x + nx, b.y + ny):
				b.x += nx
				b.y += ny


func upd_nades(dt: float) -> void:
	for i in range(M.nades.size() - 1, -1, -1):
		var q = M.nades[i]
		q.t += dt
		if q.t >= q.T:
			M.nades.remove_at(i)
			var W: Dictionary = GD.WD[q.wt]
			explode(q.tx, q.ty, W.raio, W.dano, q.src)
			if W.get("incend", false):
				for k in 9:
					var a := k / 8.0 * TAU
					var r := 0.0 if k == 8 else (1.5 if k % 2 else .8)
					add_fire(q.tx + cos(a) * r, q.ty + sin(a) * r, 10 + randf() * 3, q.src)


func add_fire(px: float, py: float, life: float, src: Unit = null) -> void:
	if px < 0 or py < 0 or px >= N or py >= N or M.fires.size() > 40:
		return
	var tt := M.tile[int(py) * N + int(px)]
	if tt == T.WATER or tt == T.BLD:
		return
	var f := {x = px, y = py, life = life, tick = 0.0, src = src}
	M.fires.append(f)
	fx.emit("fire", f)


func upd_fires(dt: float) -> void:
	for i in range(M.fires.size() - 1, -1, -1):
		var f: Dictionary = M.fires[i]
		f.life -= dt
		if f.life <= 0:
			M.fires.remove_at(i)
			continue
		f.tick -= dt
		if f.tick > 0:
			continue
		f.tick = .3
		for u in M.units:
			if not u.dead and u.in_car == null and not u.mech and absf(u.x - f.x) < .6 and absf(u.y - f.y) < .6:
				if u.burn <= 0:
					u.burn_src = f.src
				u.burn = maxf(u.burn, 1.5)
		for p in M.props:
			if not p.dead and absf(p.x - f.x) < .7 and absf(p.y - f.y) < .7 and randf() < .15:
				hurt_prop(p, 999, null)


func pente_of(u: Unit, wk: String) -> int:
	return roundi(GD.WD[wk].get("pente", 0) * (1.5 if u and u.kind == "agente" and Camp.has("pentes") else 1.0))


func update(dt: float) -> void:
	M.t += dt
	for u in M.units:
		if u.dead:
			u.death_t += dt
			continue
		if u.cool > 0: u.cool -= dt
		if u.supp > 0: u.supp -= dt
		if u.supp_p > 0: u.supp_p -= dt * .8
		if u.rel > 0:
			u.rel -= dt
			if u.rel <= 0 and u.rel_st != null:
				u.rel_st.mun = pente_of(u, u.rel_w)
				u.rel_st = null
		if u.flash > 0: u.flash -= dt
		if u.hit_t > 0: u.hit_t -= dt
		if u.run_t > 0: u.run_t -= dt
		if u.aim_t > 0: u.aim_t -= dt
		if u.burn > 0:
			u.burn -= dt
			hurt(u, 9 * dt, u.burn_src)
			if u.dead:
				continue
			if u.kind == "civil" and not u.follower:
				u.panic_t = 3
		if u.in_car != null:
			u.x = u.in_car.x
			u.y = u.in_car.y
			u.cur_spd = 0
			if u.kind == "agente":
				car_fire(u, dt)
			continue
		if u.hj_t > 0:
			u.hj_t -= dt
			u.path = []
			u.cur_spd = 0
			continue
		if u.hj > 0:
			u.hj = maxf(0, u.hj - dt * .3)
		if u.follower and u.kind != "drone":
			upd_follower(u, dt)
			continue
		if u.disguise:
			upd_disguise(u, dt)
			continue
		match u.kind:
			"agente": upd_agent(u, dt)
			"civil": upd_civ(u, dt)
			"policia": upd_police(u, dt)
			"guarda", "inimigo": upd_guard(u, dt)
			"vip": upd_vip(u, dt)
			"cientista": upd_sci(u, dt)
			"torre": upd_turret(u, dt)
			"drone": upd_drone(u, dt)
	separate()
	upd_cars(dt)
	upd_nades(dt)
	if not M.fires.is_empty(): upd_fires(dt)
	if not M.cams.is_empty(): upd_cams(dt)
	if not M.lasers.is_empty(): upd_lasers(dt)
	if not M.vents.is_empty(): upd_vents(dt)
	if M.rail != null: upd_train(dt)
	if not M.glass_q.is_empty(): upd_glass()
	if not M.falling.is_empty(): upd_falling(dt)
	if M.police_aggro > 0:
		M.police_aggro -= dt
		if M.police_aggro <= 0:
			M.police_aggro = 0
			say_log("A polícia recuou.", "cyan")
		else:
			M.reinf_t -= dt
			if M.reinf_t <= 0:
				M.reinf_t = 35 if Camp.has("trafego") else 20
				spawn_reinforcements()
	if not M.ended:
		check_end()
	else:
		M.end_t += dt


func spawn_reinforcements() -> void:
	var alive := M.units.filter(func(u): return u.kind == "policia" and not u.dead and not u.follower).size()
	if alive >= 14:
		return
	var edges := [Vector2(1, randi() % N), Vector2(N - 2, randi() % N), Vector2(randi() % N, 1), Vector2(randi() % N, N - 2)]
	var e: Vector2 = edges[randi() % 4]
	for k in 2:
		var p = M.random_near(e.x, e.y, 2)
		if p == null:
			continue
		var u := M.mk_unit("policia", p.x, p.y)
		u.spd = 1.9
		fx.emit("spawn", {u = u})
	say_log("Reforços policiais chegaram ao distrito.", "amber")


func check_end() -> void:
	if not M.agents.any(func(a): return not a.dead):
		end_mission(false, "Todo o esquadrão foi abatido.")
		return
	if M.hand:
		return
	match M.tipo:
		"assassinato":
			if M.vip and M.vip.dead:
				end_mission(true, "%s foi eliminado." % M.vip.nome)
		"extracao":
			if M.sci and M.sci.dead:
				end_mission(false, "%s morreu durante a operação." % M.sci.nome)
			elif M.sci and M.sci.follow and Vector2(M.sci.x - M.evac.x, M.sci.y - M.evac.y).length() < 2.3:
				end_mission(true, "%s foi %s com sucesso." % [M.sci.nome, "extraída" if M.sci.fem() else "extraído"])
		"sabotagem":
			if M.terms.all(func(q): return q.done):
				end_mission(true, "A rede de vigilância do distrito caiu.")
		"eliminacao":
			if M.units.all(func(u): return u.kind != "inimigo" or u.dead or u.follower):
				end_mission(true, "Os agitadores do Consórcio foram eliminados." if M.revolta else "A célula de agentes do Consórcio foi eliminada.")


func end_mission(w: bool, r: String) -> void:
	if M.ended:
		return
	M.ended = true
	M.win = w
	M.reason = r
	M.end_t = 0
	say_log("OBJETIVO CUMPRIDO" if w else "MISSÃO FRACASSADA", "green" if w else "red")
	fx.emit("end", {win = w})


# ---------------------------------------------------------------- ordens do jogador
func set_sel(list: Array) -> void:
	for a in M.agents:
		a.sel = false
	M.sel.clear()
	for a in list:
		if not a.dead:
			M.sel.append(a)
			a.sel = true


func issue_move(p: Vector2) -> void:
	var offs := [Vector2(0, 0), Vector2(.8, 0), Vector2(0, .8), Vector2(.8, .8)]
	var n := M.sel.size()
	for k in n:
		var u: Unit = M.sel[k]
		if u.in_car != null:
			var c: Dictionary = u.in_car
			if not c.get("scripted", false):
				c.path = M.road_path(c.x, c.y, p.x, p.y)
				c.pi = 0
			continue
		var tx: float = p.x + offs[k % 4].x - (.4 if n > 1 else 0.0)
		var ty: float = p.y + offs[k % 4].y - (.4 if n > 2 else 0.0)
		if not M.can_stand(tx, ty):
			tx = p.x
			ty = p.y
		u.ord = {k = "move"}
		M.path_to(u, tx, ty)
	fx.emit("mark", {x = p.x, y = p.y, col = Color("#4fd8ff")})


func issue_attack(t: Unit) -> void:
	for u in M.sel:
		if u.in_car != null:
			continue
		var it = u.inv[u.eq] if u.eq >= 0 else null
		var w: Dictionary = GD.WD[it.t] if it != null else {}
		if w.get("throw", false):
			u.ord = {k = "throw", x = t.x, y = t.y}
		elif w.get("hack", false):
			if t.fac == "corp" and (t.kind == "torre" or t.kind == "drone"):
				u.ord = {k = "hack", t = t, p = 0.0}
		else:
			if not w.get("arma", false):
				equip_first_weapon(u)
			if u.eq >= 0 and GD.WD[u.inv[u.eq].t].get("arma", false):
				u.ord = {k = "atk", t = t, rep = 0.0, engaged = false}
	fx.emit("mark", {x = t.x, y = t.y, col = Color("#ff4d5e")})


func issue_ground(p: Vector2) -> void:
	for u in M.sel:
		var it = u.inv[u.eq] if u.eq >= 0 else null
		if it == null:
			continue
		var w: Dictionary = GD.WD[it.t]
		if w.get("throw", false):
			u.ord = {k = "throw", x = p.x, y = p.y}
		elif w.get("arma", false):
			u.ord = {k = "fire", x = p.x, y = p.y, time = .5}
	fx.emit("mark", {x = p.x, y = p.y, col = Color("#ffa53d")})


func cycle_weapon(dir: int) -> void:
	for u in M.sel:
		var opts := [-1]
		for i in u.inv.size():
			var w: Dictionary = GD.WD[u.inv[i].t]
			if w.get("arma", false) or w.get("throw", false) or w.get("sonda", false) or w.get("hack", false) or w.get("manto", false):
				opts.append(i)
		var p := opts.find(u.eq)
		u.eq = opts[(p + dir + opts.size()) % opts.size()]
		u.ord = null


func holster() -> void:
	for u in M.sel:
		u.eq = -1
		u.ord = null


func use_slot(i: int) -> void:
	if M.sel.is_empty():
		return
	var L: Unit = M.sel[0]
	if i < 0 or i >= L.inv.size():
		return
	var it = L.inv[i]
	var w: Dictionary = GD.WD[it.t]
	if w.get("heal", false) and Camp.has("nanomed"):
		var n := 0
		for a in M.agents:
			if not a.dead and a.dist_to(L) < 2.5:
				a.hp = a.max_hp
				n += 1
		remove_item(L, i)
		say_log("Nanomedkit: %d agente(s) restaurado(s)." % n, "green")
		return
	if w.get("heal", false):
		if L.hp >= L.max_hp:
			say_log("%s já está com integridade máxima." % L.nome)
			return
		L.hp = L.max_hp
		remove_item(L, i)
		say_log("%s usou um kit médico." % L.nome, "green")
		return
	for u in M.sel:
		var idx := i if u == L else -1
		if u != L:
			for j in u.inv.size():
				if u.inv[j].t == it.t:
					idx = j
					break
		if idx >= 0:
			u.eq = idx
			u.ord = null


# ---------------------------------------------------------------- disfarces
func reveal(u: Unit) -> void:
	if not u.disguise:
		return
	u.disguise = false
	u.dance = false
	u.alerted = false
	M.revealed += 1
	fx.emit("reveal", {u = u})
	alert_corp(u, u.x, u.y)
	u.alerted = true


func upd_disguise(u: Unit, dt: float) -> void:
	if u.alerted:
		reveal(u)
		return
	var near := false
	for a in M.agents:
		if not a.dead and u.dist_to(a) < 2.6:
			near = true
			break
	u.reveal_p = u.reveal_p + dt if near else maxf(0, u.reveal_p - dt * .5)
	if u.reveal_p >= 1.6:
		reveal(u)
		return
	if u.dance:
		u.path = []
		u.cur_spd = 0
		return
	var h: Vector2 = u.home if u.home != null else Vector2(u.x, u.y)
	wander(u, dt, h.x, h.y, 5, .9)


# ---------------------------------------------------------------- Ponteiros
func spawn_rival(id: String, px: float, py: float) -> Unit:
	if not GD.RIVALS.has(id):
		return null
	var R: Dictionary = GD.RIVALS[id]
	var u := M.mk_unit("inimigo", px, py)
	u.rival = id
	u.nome = R.nome
	u.seed = Portraits.RIVAL_SEED.get(id, u.seed)
	u.w = R.w
	u.mun = GD.WD[R.w].pente
	u.hp = R.hp
	u.max_hp = R.hp
	u.armor = R.armor
	u.spd = R.spd
	u.acc = R.acc
	u.nades = 2
	u.home = Vector2(px, py)
	u.view_kind = "enemy"
	fx.emit("spawn", {u = u})
	return u


func rival_tick(u: Unit, dt: float) -> bool:
	var R: Dictionary = GD.RIVALS.get(u.rival, {})
	if not u.contact:
		var a := nearest_agent(u, 9)
		if a and M.los(u.x, u.y, a.x, a.y):
			u.contact = true
			if not u.rival in M.rival_seen:
				M.rival_seen.append(u.rival)
			say_log("%s, um dos Ponteiros do Consórcio, entrou no combate." % u.nome, "red")
			fx.emit("rival_spot", {u = u})
	if u.escaping:
		u.esc_t -= dt
		M.move_along(u, dt, u.spd * 1.4)
		if u.path.is_empty() or u.esc_t <= 0 or u.x < 1.3 or u.y < 1.3 or u.x > N - 1.3 or u.y > N - 1.3:
			u.dead = true
			u.vanished = true
			u.hp = 0
			M.rival_esc.append(u.rival)
			say_log("%s escapou." % u.nome, "amber")
			fx.emit("vanish", {u = u})
		return true
	if not R.get("hq_only", false) and u.hp < u.max_hp * .3:
		u.escaping = true
		u.esc_t = 10
		u.tgt = null
		var ex := [Vector2(1, u.y), Vector2(N - 1.5, u.y), Vector2(u.x, 1), Vector2(u.x, N - 1.5)]
		ex.sort_custom(func(a, b): return a.distance_to(u.pos2()) < b.distance_to(u.pos2()))
		M.path_to(u, ex[0].x, ex[0].y)
		return true
	return false


# ---------------------------------------------------------------- drones
func fly_to(u: Unit, px: float, py: float, dt: float, s: float) -> bool:
	var d := Vector2(px - u.x, py - u.y)
	var l := d.length()
	if l < .2:
		u.cur_spd = 0
		return true
	var st := minf(l, s * GD.SPEED * dt)
	u.x = clampf(u.x + d.x / l * st, 1, N - 1)
	u.y = clampf(u.y + d.y / l * st, 1, N - 1)
	u.cur_spd = s * GD.SPEED
	if u.aim_t <= 0:
		u.face = atan2(d.y, d.x)
	return false


func orbit(u: Unit, p: Vector2, R: float, dt: float) -> void:
	var dir := 1.0 if u.id % 2 else -1.0
	var a := atan2(u.y - p.y, u.x - p.x) + .45 * dir
	for r in [R, R * .7, R * .45]:
		var tx: float = p.x + cos(a) * r
		var ty: float = p.y + sin(a) * r
		if M.can_stand(tx, ty):
			fly_to(u, tx, ty, dt, u.spd)
			return
	fly_to(u, p.x, p.y, dt, u.spd * .5)


func upd_drone(u: Unit, dt: float) -> void:
	u.path = []
	if u.off:
		u.cur_spd = 0
		return
	if u.fac == "player":
		var t := nearest_hostile(u, 7.5)
		if t:
			aim_at(u, t.x, t.y)
			fire_weapon(u, u.w, u, t.x, t.y)
		var a := nearest_agent(u, 999)
		if a:
			if u.dist_to(a) > 2.4:
				fly_to(u, a.x + cos(u.id) * 1.3, a.y + sin(u.id) * 1.3, dt, u.spd * 1.2)
			else:
				u.cur_spd = 0
		return
	if not u.alerted:
		detect(u, dt, 7.5, 4.2)
		if not u.alerted and M.corp_alert and nearest_agent(u, 14):
			u.alerted = true
		if not u.alerted:
			if not u.route.is_empty():
				var p: Vector2 = u.route[u.ri % u.route.size()]
				if fly_to(u, p.x, p.y, dt, u.spd * .55):
					u.ri += 1
			else:
				u.face += dt * .8
				u.cur_spd = 0
			return
	var t := u.tgt
	if t and (t.dead or not is_enemy_of(u, t) or (t.cloak and u.dist_to(t) > 1.5)):
		t = null
		u.tgt = null
	u.scan_t -= dt
	if u.scan_t <= 0:
		u.scan_t = .35
		var nt := nearest_hostile(u, 9.5)
		if nt:
			t = nt
			u.tgt = nt
	if t:
		var p := t.pos2()
		u.lkp = p
		orbit(u, p, 4.6, dt)
		if u.dist_to(t) < 8.5 and M.los(u.x, u.y, p.x, p.y):
			aim_at(u, p.x, p.y)
			fire_weapon(u, u.w, u, p.x, p.y, .6 if u.supp > 0 else 1.0)
		return
	var g = u.lkp
	if g == null:
		var a := nearest_agent(u, 22)
		if a:
			g = a.pos2()
	if g != null:
		if fly_to(u, g.x, g.y, dt, u.spd):
			u.lkp = null
	else:
		u.cur_spd = 0


# ---------------------------------------------------------------- câmeras de segurança
func upd_cams(dt: float) -> void:
	for c in M.cams:
		if c.dead or c.off:
			continue
		c.a = c.base + sin(M.t * c.spd + c.ph) * c.sweep
		c.chk = c.get("chk", 0.0) - dt
		if c.chk > 0:
			continue
		c.chk = .2
		var seen: Unit = null
		for a in M.agents:
			if a.dead or a.cloak:
				continue
			if not c.get("strict", false) and not is_armed(a):
				continue
			var dx: float = a.x - c.x
			var dy: float = a.y - c.y
			if sqrt(dx * dx + dy * dy) > c.range:
				continue
			if absf(angle_difference(atan2(dy, dx), c.a)) > c.fov:
				continue
			if M.los(c.x, c.y, a.x, a.y):
				seen = a
				break
		if seen:
			c.see += .2
			if c.see >= .8 and not c.get("fired", false):
				c.fired = true
				cam_alarm(c, seen)
		else:
			c.see = maxf(0, c.see - .1)


func cam_alarm(c: Dictionary, a: Unit) -> void:
	say_log("Uma câmera de segurança viu o esquadrão!", "red")
	var best: Unit = null
	var bd := 1e9
	for u in M.units:
		if not u.dead and u.fac == "corp" and not u.disguise:
			var d := Vector2(u.x - c.x, u.y - c.y).length()
			if d < bd:
				bd = d
				best = u
	if best:
		alert_corp(best, a.x, a.y)
	for u in M.units:
		if not u.dead and u.fac == "corp" and not u.alerted and Vector2(u.x - c.x, u.y - c.y).length() < 14:
			u.alerted = true
			u.lkp = a.pos2()


func hurt_cam(c: Dictionary) -> void:
	if c.dead:
		return
	c.dead = true
	fx.emit("cam_dead", {c = c})


# ---------------------------------------------------------------- feixes de alarme
func upd_lasers(dt: float) -> void:
	for l in M.lasers:
		var per: float = l.get("per", 0.0)
		l.on = not l.off and (per <= 0 or fmod(M.t + l.get("ph", 0.0), per) < per * l.get("duty", .5))
		if l.trip_t > 0:
			l.trip_t -= dt
		if not l.on:
			continue
		if l.get("sweep") != null:
			var s: Dictionary = l.sweep
			var L: float = s.b - s.a
			var ph := fmod(M.t * s.spd, 2 * L)
			var p: float = s.a + (ph if ph < L else 2 * L - ph)
			if s.ax == "y":
				l.y1 = p
				l.y2 = p
			else:
				l.x1 = p
				l.x2 = p
		var dx: float = l.x2 - l.x1
		var dy: float = l.y2 - l.y1
		var L2 := maxf(dx * dx + dy * dy, 1e-4)
		if l.get("dmg", 0.0) > 0:
			l.tick = l.get("tick", 0.0) - dt
			if l.tick > 0:
				continue
			l.tick = .2
			for u in M.units:
				if u.dead or u.in_car != null or u.mech or u.boss:
					continue
				var t := clampf(((u.x - l.x1) * dx + (u.y - l.y1) * dy) / L2, 0, 1)
				var px: float = l.x1 + dx * t - u.x
				var py: float = l.y1 + dy * t - u.y
				if px * px + py * py > .16:
					continue
				hurt(u, l.dmg * .2, null)
				l.trip_t = .3
			continue
		for a in M.agents:
			if a.dead:
				continue
			var t := clampf(((a.x - l.x1) * dx + (a.y - l.y1) * dy) / L2, 0, 1)
			var px: float = l.x1 + dx * t - a.x
			var py: float = l.y1 + dy * t - a.y
			if px * px + py * py > .09:
				continue
			l.trip_t = 1.2
			if not l.get("tripped", false):
				l.tripped = true
				say_log("Um feixe de alarme foi cortado!", "red")
				fx.emit("alarm", {})
			if not M.corp_alert:
				var best: Unit = null
				var bd := 1e9
				for u in M.units:
					if not u.dead and u.fac == "corp" and not u.disguise and not u.cand:
						var d := u.dist_to(a)
						if d < bd:
							bd = d
							best = u
				if best:
					alert_corp(best, a.x, a.y)
			break


# ---------------------------------------------------------------- saídas de vapor
func upd_vents(dt: float) -> void:
	var over := M.vent_over > M.t
	for v in M.vents:
		if v.get("off", false):
			v.state = 0
			continue
		var ph: float = v.per if over else fmod(M.t + v.ph, v.per)
		var b0: float = v.per - v.dur
		var warn := not over and ph > b0 - 1.2 and ph < b0
		var burst := over or ph >= b0
		v.state = 2 if burst else (1 if warn else 0)
		if warn or burst:
			v.av_t = v.get("av_t", 0.0) - dt
			if v.av_t <= 0:
				v.av_t = .3
				for u in M.units:
					if u.dead or u.in_car != null or u.mech or u.fac == "player" or u.alerted or u.panic_t > 0 or u.flee_to != null:
						continue
					var d := Vector2(u.x - v.x, u.y - v.y)
					if d.length() > v.r + .7:
						continue
					var n := d.normalized()
					var p = M.random_near(v.x + n.x * 2.6, v.y + n.y * 2.6, 1.2)
					if p != null:
						M.path_to(u, p.x, p.y)
						u.idle_t = 2
		if not burst:
			continue
		v.tick = v.get("tick", 0.0) - dt
		if v.tick <= 0:
			v.tick = .25
			for u in M.units:
				if not u.dead and u.in_car == null and not u.mech and Vector2(u.x - v.x, u.y - v.y).length() < v.r:
					hurt(u, v.dmg * .25, M.vent_src if over else null)
					if u.kind == "civil" and not u.follower:
						u.panic_t = 3


# ---------------------------------------------------------------- vidro, monotrilho, guindaste
func shatter_glass(tx: int, ty: int) -> void:
	var i := ty * N + tx
	if M.tile[i] != T.GLASS:
		return
	M.tile[i] = T.PLAZA
	M.walk[i] = 1
	M.astar.set_point_solid(Vector2i(tx, ty), false)
	M.glass_n -= 1
	M.events.append({k = "glass", x = tx, y = ty})
	fx.emit("glass", {x = tx + .5, y = ty + .5})
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var x: int = tx + d.x
		var y: int = ty + d.y
		if x >= 0 and y >= 0 and x < N and y < N and M.tile[y * N + x] == T.GLASS and randf() < .35:
			M.glass_q.append({x = x, y = y, t = M.t + .08 + randf() * .15})
	noise(tx + .5, ty + .5, 5, null)


func upd_glass() -> void:
	var q := M.glass_q
	M.glass_q = []
	for g in q:
		if M.t >= g.t:
			shatter_glass(g.x, g.y)
		else:
			M.glass_q.append(g)


func upd_train(dt: float) -> void:
	if M.train == null:
		M.train_t -= dt
		if M.train_t <= 0:
			M.train = {x = -14.0, dir = 1}
			M.train_t = 40
	else:
		M.train.x += 11 * dt
		if M.train.x > N + 16:
			M.train = null
	M.flags.trainNoise = M.train != null and M.train.x > -6 and M.train.x < N + 6


func drop_container() -> void:
	if not M.flags.get("crane", false) or M.flags.get("dropped", false) or M.drop_point == null:
		return
	M.flags.dropped = true
	M.falling.append({x = M.drop_point.x, y = M.drop_point.y, t = 0.0, T = .8, landed = false})
	fx.emit("drop", {x = M.drop_point.x, y = M.drop_point.y})


func upd_falling(dt: float) -> void:
	for f in M.falling:
		if f.landed:
			continue
		f.t += dt
		if f.t < f.T:
			continue
		f.landed = true
		var src: Unit = null
		for a in M.agents:
			if not a.dead:
				src = a
				break
		fx.emit("explosion", {x = f.x, y = f.y, r = 1.6})
		for c in M.cars:
			if not c.dead and absf(c.x - f.x) < 1.8 and absf(c.y - f.y) < 1.1:
				c.hp = 1
				hurt_car(c, 999, src)
		var vip_alive: bool = M.vip != null and not M.vip.dead
		for u in M.units:
			if not u.dead and u.in_car == null and absf(u.x - f.x) < 1.7 and absf(u.y - f.y) < 1:
				hurt(u, 999, src)
		if vip_alive and M.vip.dead:
			M.flags.accident = true
		for x in range(int(floor(f.x - 1.4)), int(floor(f.x + 1.4)) + 1):
			var i := int(f.y) * N + x
			M.tile[i] = T.BLD
			M.walk[i] = 0
			M.astar.set_point_solid(Vector2i(x, int(f.y)), true)
		noise(f.x, f.y, 16, src)


# ---------------------------------------------------------------- carros com rota
func add_car(px: float, py: float, ang: float, col: Color, hp := 120.0, model := "sedan") -> Dictionary:
	var c := {x = px, y = py, ang = ang, dx = cos(ang), dy = sin(ang), cur = 0.0, hp = hp, dead = false, col = col, occ = [],
		path = [], pi = 0, scripted = true, model = model, smoke_t = 0.0}
	M.cars.append(c)
	fx.emit("car", {c = c})
	return c


func drive_car(c: Dictionary, dt: float) -> void:
	if c.path.is_empty():
		c.cur = maxf(0, c.cur - 10 * dt)
	else:
		var p: Vector2 = c.path[c.pi]
		var dx: float = p.x - c.x
		var dy: float = p.y - c.y
		var dd := sqrt(dx * dx + dy * dy)
		if dd < .55:
			c.pi += 1
			if c.pi >= c.path.size():
				c.path = []
		else:
			var da := angle_difference(c.ang, atan2(dy, dx))
			c.ang += clampf(da, -6 * dt, 6 * dt)
			var last: bool = c.pi >= c.path.size() - 1
			var target := 2.2 if absf(da) > .9 else (3.0 if last and dd < 2.5 else 7.5)
			c.cur += clampf(target - c.cur, -14 * dt, 5 * dt)
	var ndx := cos(c.ang)
	var ndy := sin(c.ang)
	var nx: float = c.x + ndx * c.cur * GD.SPEED * dt
	var ny: float = c.y + ndy * c.cur * GD.SPEED * dt
	if not c.get("player", false) or _road_at(nx + ndx * .7, ny + ndy * .7) or _road_at(nx, ny):
		c.x = clampf(nx, .4, N - .4) if c.get("player", false) else nx
		c.y = clampf(ny, .4, N - .4) if c.get("player", false) else ny
	elif not c.path.is_empty():
		var p: Vector2 = c.path[c.pi]
		c.ang = atan2(p.y - c.y, p.x - c.x)
		c.cur = 1.0
	else:
		c.cur = 0.0
	c.dx = ndx
	c.dy = ndy
	if c.get("player", false) and c.cur > 2.5:
		var drv: Unit = null
		for o in c.occ:
			if o.kind == "agente":
				drv = o
				break
		for u in M.units:
			if u.dead or u.in_car != null or u.mech or u.run_t > 0 or (u.fac == "player" and u.kind == "agente"):
				continue
			if Vector2(u.x - c.x, u.y - c.y).length() < .6:
				u.run_t = 1.0
				hurt(u, 55, drv)
				var s := _spot_near(u.x + ndy * .6, u.y - ndx * .6, 0)
				u.x = s.x
				u.y = s.y
		return
	if c.cur > .5:
		for u in M.units:
			if u.dead or u.in_car != null or u.mech:
				continue
			var rx: float = u.x - c.x
			var ry: float = u.y - c.y
			var f := rx * ndx + ry * ndy
			var l := rx * ndy - ry * ndx
			if absf(f) < 1 and absf(l) < .55:
				var s := 1.0 if l >= 0 else -1.0
				var px := u.x + ndy * s * .12
				var py := u.y - ndx * s * .12
				if M.can_stand(px, py):
					u.x = px
					u.y = py


func _road_at(px: float, py: float) -> bool:
	if px < 0 or py < 0 or px >= N or py >= N:
		return false
	var t: int = M.tile[int(py) * N + int(px)]
	return t == T.ROAD or t == T.PLAZA or t == T.WALK


func _spot_near(px: float, py: float, k: int) -> Vector2:
	var r := .8
	while r < 3.5:
		var a := k * 1.3
		while a < k * 1.3 + TAU:
			var qx := px + cos(a) * r
			var qy := py + sin(a) * r
			if M.can_stand(qx, qy):
				return Vector2(qx, qy)
			a += .5
		r += .4
	return Vector2(px, py)


func board_car(u: Unit, c: Dictionary) -> void:
	if u.in_car != null or c.dead:
		return
	u.in_car = c
	c.occ.append(u)
	c.player = true
	c.path = []
	c.cur = 0.0
	u.path = []
	u.ord = null
	fx.emit("door", {x = c.x, y = c.y})
	if c.occ.filter(func(o): return o.kind == "agente").size() == 1:
		say_log("Agente no veículo. Clique no mapa para dirigir · V para sair.", "cyan")
		fx.emit("car_in", {u = u})


func exit_car(c: Dictionary) -> void:
	var occ: Array = c.occ.duplicate()
	c.occ = []
	for k in occ.size():
		var u: Unit = occ[k]
		var s := _spot_near(c.x, c.y, k)
		u.x = s.x
		u.y = s.y
		u.in_car = null
		u.path = []
	c.path = []
	c.cur = 0.0
	if not occ.is_empty():
		fx.emit("door", {x = c.x, y = c.y})


func issue_enter(c: Dictionary) -> void:
	if c.dead:
		return
	for u in M.sel:
		if not u.dead and u.in_car == null:
			u.ord = {k = "enter", c = c, rep = 0.0}
	c.held = 2.0
	fx.emit("mark", {x = c.x, y = c.y, col = Color("#4fd8ff")})


func exit_selected() -> void:
	var done := []
	for u in M.sel:
		if u.in_car != null and not u.in_car in done:
			done.append(u.in_car)
			exit_car(u.in_car)


## Tráfego: segue a faixa, para atrás de pedestres e carros, buzina e dá a volta no mapa.
func traffic(c: Dictionary, dt: float) -> void:
	if c.held > 0:
		c.held -= dt
		c.cur = maxf(0, c.cur - 14 * dt)
		return
	var blocked := false
	for u in M.units:
		if u.dead or u.in_car != null or u.mech or u.fly:
			continue
		var rx: float = u.x - c.x
		var ry: float = u.y - c.y
		var f: float = rx * c.dx + ry * c.dy
		if f > .3 and f < 1.8 and absf(rx * c.dy - ry * c.dx) < .6:
			blocked = true
			break
	if not blocked:
		for o in M.cars:
			if o == c:
				continue
			var rx: float = o.x - c.x
			var ry: float = o.y - c.y
			var f: float = rx * c.dx + ry * c.dy
			if f > .3 and f < 2.1 and absf(rx * c.dy - ry * c.dx) < .75:
				blocked = true
				break
	if blocked and c.stop_t < 3.5:
		c.stop_t += dt
		c.cur = maxf(0, c.cur - 14 * dt)
		if c.stop_t > 1.6 and not c.honked:
			c.honked = true
			fx.emit("honk", {x = c.x, y = c.y})
	else:
		if not blocked:
			c.stop_t = 0.0
			c.honked = false
		c.cur = minf(c.v, c.cur + 4 * dt)
	c.ang = atan2(c.dy, c.dx)
	c.x += c.dx * c.cur * GD.SPEED * dt
	c.y += c.dy * c.cur * GD.SPEED * dt
	if c.x < -2: c.x = N + 2
	if c.x > N + 2: c.x = -2
	if c.y < -2: c.y = N + 2
	if c.y > N + 2: c.y = -2
	if c.cur > .5:
		for u in M.units:
			if u.dead or u.in_car != null or u.mech:
				continue
			var rx: float = u.x - c.x
			var ry: float = u.y - c.y
			var f: float = rx * c.dx + ry * c.dy
			var l: float = rx * c.dy - ry * c.dx
			if absf(f) < .8 and absf(l) < .5:
				var s := 1.0 if l >= 0 else -1.0
				var px: float = u.x + c.dy * s * .08
				var py: float = u.y - c.dx * s * .08
				if M.can_stand(px, py):
					u.x = px
					u.y = py


func upd_cars(dt: float) -> void:
	for c in M.cars:
		if c.dead:
			continue
		if c.get("scripted", true) or c.get("player", false):
			drive_car(c, dt)
		else:
			traffic(c, dt)


func hurt_car(c: Dictionary, dmg: float, src: Unit) -> void:
	if c.dead:
		return
	c.hp -= dmg
	if c.hp <= 0:
		c.dead = true
		c.cur = 0
		c.path = []
		var occ: Array = c.occ.duplicate()
		c.occ = []
		for u in occ:
			u.in_car = null
		explode(c.x, c.y, 2, 60, src)
		for u in occ:
			if not u.dead:
				hurt(u, 30, src)
				u.burn = maxf(u.burn, 2)
		fx.emit("car_dead", {c = c})


## Destrói um prédio inteiro (portões arrombados pelo roteiro).
func destroy_bld(b: Dictionary) -> void:
	if b.get("dead", false):
		return
	b.dead = true
	for y in range(b.y, b.y + b.d):
		for x in range(b.x, b.x + b.w):
			var i: int = y * N + x
			M.tile[i] = T.PLAZA
			M.walk[i] = 1
			M.astar.set_point_solid(Vector2i(x, y), false)
	M.events.append({k = "bld", b = b})
	noise(b.x + b.w / 2.0, b.y + b.d / 2.0, 12, null)

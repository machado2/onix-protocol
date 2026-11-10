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
const NEURO := {spd = 1.125, rof = .95, acc = 1.075, rng = 1.075, res = .15}   # predefinição PADRÃO


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
		if d < bd and M.los(u.x, u.y, v.x, v.y):
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
	M.police_aggro = 40


func police_sees(px: float, py: float, r: float) -> bool:
	for p in M.units:
		if p.kind == "policia" and not p.dead and not p.follower and Vector2(p.x - px, p.y - py).length() < r and M.los(p.x, p.y, px, py):
			return true
	return false


func noise(px: float, py: float, r: float, src: Unit) -> void:
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
		if a.dead:
			continue
		var d := u.dist_to(a)
		var r := (dr if is_armed(a) else hr) * .95
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
		if v == u or v.dead or v.fac == u.fac or (u.fac == "player" and v.kind == "cientista"):
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


func hurt(v: Unit, dmg: float, src: Unit) -> void:
	if v.dead:
		return
	if v.kind == "agente":
		dmg *= 1 - NEURO.res
	v.hp -= dmg * (1 - v.armor)
	v.hit_t = .08
	v.last_hit = M.t
	if not v.mech and randf() < .6:
		fx.emit("blood", {x = v.x, y = v.y})
	if src and src.fac == "player" and src != v:
		if v.fac == "corp":
			alert_corp(v, src.x, src.y)
		if v.fac == "police":
			trigger_police("O esquadrão atacou a polícia.")
		if (v.fac == "civ" or v.fac == "neutral") and M.police_aggro <= 0 and police_sees(v.x, v.y, 10):
			trigger_police("A polícia testemunhou um ataque a civis.")
	if src and src != v and v.tgt == null and v.fac != "civ" and v.fac != "neutral" and is_enemy_of(v, src):
		v.tgt = src
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
		return
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
		say_log("Alvo eliminado: %s." % v.nome, "green")
	if v.kind == "cientista":
		say_log("%s foi morta no fogo cruzado." % v.nome, "red")
	fx.emit("death", {u = v})


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
	M.followers += 1
	M.stats.seguidores += 1
	fx.emit("convert", {u = v})
	if M.followers == 1:
		say_log("Primeiro seguidor recrutado. Seguidores apanham armas do chão e lutam pelo esquadrão.", "cyan")


func hijack_tick(u: Unit, dt: float, w: Dictionary) -> void:
	var pw := minf(4, 1 + .2 * M.followers) * (.7 + .6 * .5)
	var rng: float = w.alcance
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
	if t and (t.dead or not is_enemy_of(u, t)):
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
			if not a.dead and is_armed(a) and u.dist_to(a) < 7 and M.los(u.x, u.y, a.x, a.y):
				seen = a
				break
		u.seeing = seen
		if seen:
			u.path = []
			aim_at(u, seen.x, seen.y)
			u.lost = 0
			if not u.warned:
				u.warned = true
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
	if not u.fleeing:
		u.fleeing = true
		u.path = []
		say_log("%s está fugindo para o transporte de evacuação!" % u.nome, "amber")
	if u.path.is_empty():
		u.rep_t -= dt
		if u.rep_t <= 0:
			u.rep_t = 1
			M.path_to(u, M.escape.x, M.escape.y)
	M.move_along(u, dt, u.spd * 1.2)
	if Vector2(u.x - M.escape.x, u.y - M.escape.y).length() < 1.3 and not M.ended:
		end_mission(false, "%s alcançou o transporte e escapou." % u.nome)


func upd_sci(u: Unit, dt: float) -> void:
	if not u.follow:
		u.cur_spd = 0
		var a := nearest_agent(u, 1.9)
		if a:
			u.follow = true
			say_log("%s se juntou ao esquadrão. Leve-a ao ponto de evacuação." % u.nome, "green")
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


func upd_agent(u: Unit, dt: float) -> void:
	if u.hp < u.max_hp and M.t - u.last_hit > 5:
		u.hp = minf(u.max_hp, u.hp + dt * 1.5)
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
	var spd := u.spd * NEURO.spd * (.78 if w.get("peso", false) else 1.0)
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
				var ii := -1
				for i in u.inv.size():
					if u.inv[i].t == "granada":
						ii = i
						break
				if ii < 0:
					u.ord = null
				elif d <= GD.WD.granada.alcance:
					u.path = []
					aim_at(u, o.x, o.y)
					M.nades.append({sx = u.x, sy = u.y, tx = o.x, ty = o.y, t = 0.0, T = .5 + d * .07, src = u, wt = "granada"})
					fx.emit("nade", {})
					remove_item(u, ii)
					if not equip_first_weapon(u):
						u.eq = -1
					u.ord = null
				elif u.path.is_empty():
					M.path_to(u, o.x, o.y)
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
		u.inv.append({t = d.t, mun = GD.WD[d.t].pente})
		M.drops.remove_at(i)
		say_log("%s pegou %s." % [u.nome, GD.WD[d.t].ab], "cyan")
	for tm in M.terms:
		if tm.done or Vector2(tm.x - u.x, tm.y - u.y).length() > 1.4:
			continue
		tm.prog += dt
		if tm.prog >= 4:
			tm.done = true
			say_log("Terminal invadido (%d/%d)." % [M.terms.filter(func(q): return q.done).size(), M.terms.size()], "cyan")
			noise(tm.x, tm.y, 9, u)
			fx.emit("hack", {x = tm.x, y = tm.y})


# ---------------------------------------------------------------- laço
func separate() -> void:
	var U := M.units
	for i in U.size():
		var a := U[i]
		if a.dead or a.mech:
			continue
		for j in range(i + 1, U.size()):
			var b := U[j]
			if b.dead or b.mech:
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
				u.rel_st.mun = GD.WD[u.rel_w].pente
				u.rel_st = null
		if u.flash > 0: u.flash -= dt
		if u.hit_t > 0: u.hit_t -= dt
		if u.aim_t > 0: u.aim_t -= dt
		if u.burn > 0:
			u.burn -= dt
			hurt(u, 9 * dt, u.burn_src)
			if u.dead:
				continue
			if u.kind == "civil" and not u.follower:
				u.panic_t = 3
		if u.hj_t > 0:
			u.hj_t -= dt
			u.path = []
			u.cur_spd = 0
			continue
		if u.hj > 0:
			u.hj = maxf(0, u.hj - dt * .3)
		if u.follower:
			upd_follower(u, dt)
			continue
		match u.kind:
			"agente": upd_agent(u, dt)
			"civil": upd_civ(u, dt)
			"policia": upd_police(u, dt)
			"guarda", "inimigo": upd_guard(u, dt)
			"vip": upd_vip(u, dt)
			"cientista": upd_sci(u, dt)
			"torre": upd_turret(u, dt)
	separate()
	upd_nades(dt)
	if M.police_aggro > 0:
		M.police_aggro -= dt
		if M.police_aggro <= 0:
			M.police_aggro = 0
			say_log("A polícia recuou.", "cyan")
		else:
			M.reinf_t -= dt
			if M.reinf_t <= 0:
				M.reinf_t = 20
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
	match M.tipo:
		"assassinato":
			if M.vip and M.vip.dead:
				end_mission(true, "%s foi eliminado." % M.vip.nome)
		"extracao":
			if M.sci and M.sci.dead:
				end_mission(false, "%s morreu durante a operação." % M.sci.nome)
			elif M.sci and M.sci.follow and Vector2(M.sci.x - M.evac.x, M.sci.y - M.evac.y).length() < 2.3:
				end_mission(true, "%s foi extraída com sucesso." % M.sci.nome)
		"sabotagem":
			if M.terms.all(func(q): return q.done):
				end_mission(true, "A rede de vigilância do distrito caiu.")
		"eliminacao":
			if M.units.all(func(u): return u.kind != "inimigo" or u.dead or u.follower):
				end_mission(true, "A célula de agentes do Consórcio foi eliminada.")


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
		var it = u.inv[u.eq] if u.eq >= 0 else null
		var w: Dictionary = GD.WD[it.t] if it != null else {}
		if w.get("throw", false):
			u.ord = {k = "throw", x = t.x, y = t.y}
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
			if w.get("arma", false) or w.get("throw", false) or w.get("sonda", false):
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

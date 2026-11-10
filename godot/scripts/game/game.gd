## Partida: liga a simulação (Sim/Mission) à cidade 3D. Câmera tática, seleção e ordens com o mouse e o teclado,
## personagens animados pelo estado das unidades, efeitos de tiro e explosão, recorte dos prédios e HUD.
class_name Game
extends Node3D

const W := C.TILE
const STEP := 1.0 / 30.0

var M: Mission
var sim: Sim
var city: CityBuilder
var cam: Camera3D
var hud: GameHUD
var fxl: GameFX
var acc := 0.0
var paused := false
var speed := 1.0

# câmera
var cam_target := Vector3()
var cam_yaw := 45.0
var cam_yaw_goal := 45.0
var cam_pitch := 52.0
var cam_dist := 34.0
var cam_dist_goal := 34.0
var shake := 0.0

# mouse
var drag_from = null
var dragging := false
var rot_from = null
var hover: Unit = null

var hgt := PackedFloat32Array()
var mdef = null
var S: MS
var mprops: MissionProps
# falas
var vo_lines := {}
var vo_player: AudioStreamPlayer
var sub_t := 0.0
var auto := false
var look = null      # --look=x,y,dist,yaw: câmera fixa para capturas
var auto_t := 2.0


signal finished

func start(map: Dictionary, builder: CityBuilder, tipo: String, dif: int, seed: int, pre: Mission = null, def = null, team: Array = [], revolta := false) -> void:
	city = builder
	var squad: Array = team if not team.is_empty() else [["smg", "pistola", "granada", "medkit"], ["smg", "sonda", "granada"], ["escopeta", "pistola", "granada"], ["feixe", "pistola", "medkit"]]
	if pre:
		M = pre
		M.setup(map, tipo, dif, seed)
		M.spawn_squad(squad)
	else:
		M = Mission.new()
		M.revolta = revolta
		M.setup(map, tipo, dif, seed)
		M.populate(squad)
	sim = Sim.new(M)
	mdef = def
	hgt.resize(C.N * C.N)
	for i in C.N * C.N:
		hgt[i] = 0.0 if M.tile[i] == C.T.ROAD else C.CURB
	fxl = GameFX.new()
	fxl.name = "FX"
	add_child(fxl)
	fxl.setup(self)
	sim.fx.connect(_on_fx)
	sim.log_msg.connect(func(t, c):
		hud.add_log(t, c)
		print("[%5.1f] %s" % [M.t, t]))
	mprops = MissionProps.new()
	mprops.name = "ObjetosDeMissao"
	add_child(mprops)
	mprops.setup(self)
	for u in M.units:
		_make_view(u)
	for c in M.cars:
		if not c.get("scripted", true):
			mprops.car_view(c)
	if "--carlog" in OS.get_cmdline_user_args():
		for c in M.cars.slice(0, 3):
			print("CAR %.1f %.1f ang %.2f model %s" % [c.x, c.y, c.ang, c.model])
	cam = Camera3D.new()
	cam.fov = 30
	cam.near = .5
	cam.far = 800
	add_child(cam)
	cam.make_current()
	cam_target = _world(M.spawn.x, M.spawn.y)
	hud = GameHUD.new()
	add_child(hud)
	hud.setup(self)
	sim.set_sel(M.agents.duplicate())
	_setup_vo()
	_tips_load()
	listener = AudioListener3D.new()
	add_child(listener)
	listener.make_current()
	if mdef != null:
		S = MS.new(M, sim, self)
		mdef.run(S, M)
	hud.add_log("Missão: %s. %s" % [GD.TIPOS[tipo], M.objective_text()], "cyan")
	auto = "--auto" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--speed="):
			speed = float(a.substr(8))
		elif a.begins_with("--look="):
			look = a.substr(7).split(",")
	hud.add_log("Clique para mover · botão direito ataca · arraste para selecionar · Z/X giram a câmera.", "")


func toggle_pause_menu() -> void:
	if M.ended:
		return
	if hud.pause_open:
		hud.show_pause(false)
		paused = false
	else:
		paused = true
		hud.show_pause(true)


func abort() -> void:
	hud.show_pause(false)
	paused = false
	sim.end_mission(false, "Missão abortada. O esquadrão recuou.")


func _exit_tree() -> void:
	Snd.set_intensity(0)
	Snd.engine(0)
	Snd.duck = false
	RenderingServer.global_shader_parameter_set("cut_pos", Vector3(0, -1000, 0))
	RenderingServer.global_shader_parameter_set("cut_r", 0.0)


func _world(x: float, y: float, h := 0.0) -> Vector3:
	return Vector3(x * W, h, y * W)


func ground_at(x: float, y: float) -> float:
	var xi := clampi(int(x), 0, C.N - 1)
	var yi := clampi(int(y), 0, C.N - 1)
	return hgt[yi * C.N + xi]


# ---------------------------------------------------------------- personagens
func _view_kind(u: Unit) -> String:
	match u.kind:
		"agente": return "agent"
		"policia": return "police"
		"guarda": return "guard"
		"inimigo": return "enemy"
		"vip": return "vip"
		"cientista": return "scientist"
	return "civil"


func _view_kind_of(u: Unit) -> String:
	return u.view_kind if u.view_kind != "" else _view_kind(u)


func _make_view(u: Unit) -> void:
	if u.kind == "drone":
		u.view = mprops.drone_view()
		add_child(u.view)
		return
	if u.kind == "torre":
		u.view = _turret()
		add_child(u.view)
		return
	var ch := Character3D.new()
	add_child(ch)
	ch.setup(_view_kind_of(u), u.seed)
	u.view = ch


func _turret() -> Node3D:
	var n := Node3D.new()
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = .35
	cm.bottom_radius = .45
	cm.height = 1.0
	base.mesh = cm
	base.position.y = .5
	base.material_override = city.mat.metal_dark
	n.add_child(base)
	var head := Node3D.new()
	head.name = "head"
	head.position.y = 1.15
	n.add_child(head)
	var hb := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(.5, .35, .6)
	hb.mesh = bm
	hb.material_override = city.mat.panel
	head.add_child(hb)
	var gun := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(.08, .08, .7)
	gun.mesh = gm
	gun.position = Vector3(0, 0, .5)
	gun.material_override = city.mat.metal_dark
	head.add_child(gun)
	var eye := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = .06
	em.height = .12
	eye.mesh = em
	eye.position = Vector3(0, .05, .31)
	eye.material_override = city.emit(Color(1, .1, .1), 6.0)
	head.add_child(eye)
	return n


func _update_views(dt: float) -> void:
	for u in M.units:
		var v = u.view
		if v == null:
			continue
		v.visible = u.in_car == null and not u.vanished
		if not v.visible:
			continue
		var p := _world(u.x, u.y, ground_at(u.x, u.y) + (2.6 + sin(M.t * 3 + u.id) * .15 if u.fly else 0.0))
		if u.kind == "drone":
			v.position = v.position.lerp(p, minf(1.0, dt * 10.0))
			v.rotation.y = lerp_angle(v.rotation.y, atan2(cos(u.face), sin(u.face)), minf(1, dt * 8))
			if u.dead:
				v.visible = u.death_t < .2
			continue
		v.position = v.position.lerp(p, minf(1.0, dt * 20.0)) if v.position.distance_to(p) < 3 else p
		var goal := atan2(cos(u.face), sin(u.face))
		if u.kind == "torre":
			var h: Node3D = v.get_node("head")
			h.rotation.y = lerp_angle(h.rotation.y, goal, minf(1, dt * 10))
			if u.dead:
				v.visible = u.death_t < .3
			continue
		var ch: Character3D = v
		if not u.dead:
			ch.rotation.y = lerp_angle(ch.rotation.y, goal, minf(1, dt * 12))
		var armed := sim.is_armed(u)
		ch.armed_now = armed
		ch.set_weapon_visible(armed)
		var mv := u.cur_spd * W
		var a := "idle"
		var sp := 1.0
		if u.dead:
			a = "die"
		elif u.kind == "civil" and u.panic_t > 0 and mv > .2 and not u.follower:
			a = "panic" if ch.anim.has_animation("panic") and mv < 3 else "run"
		elif mv < .25:
			a = "aim" if (armed and (u.aim_t > 0 or u.flash > 0)) else ("type" if u.kind == "agente" and _at_terminal(u) else "idle")
		elif armed and u.aim_t > 0:
			a = "aim_walk"
		else:
			a = "walk" if mv < 2.3 else "run"
		if a in ["walk", "run", "aim_walk", "panic"]:
			var cs := ch.clip_speed(a.replace("aim_", ""))
			if cs > .1:
				sp = clampf(mv / cs, .6, 1.7)
		ch.play(a, .2, sp)
		ch.anim.speed_scale = sp if not paused else 0.0
		ch.set_selected(u.sel)
		ch.set_cloak(u.cloak)


func _at_terminal(u: Unit) -> bool:
	for tm in M.terms:
		if not tm.done and Vector2(tm.x - u.x, tm.y - u.y).length() < 1.4:
			return true
	return false


# ---------------------------------------------------------------- laço
func _process(dt: float) -> void:
	if M == null:
		return
	if not paused:
		acc += dt * speed
		var n := 0
		while acc >= STEP and n < 16:
			sim.update(STEP)
			if S:
				S.tick.emit()
			acc -= STEP
			n += 1
	if look != null and not M.cine:
		cam_target = _world(float(look[0]), float(look[1]))
		cam_dist_goal = float(look[2])
		cam_dist = cam_dist_goal
		if look.size() > 3:
			cam_yaw_goal = float(look[3])
			cam_yaw = cam_yaw_goal
	if M.cine and "--skipcine" in OS.get_cmdline_user_args():
		M.cine_skip = true
	if auto and not M.ended and not M.cine:
		_autoplay(dt)
	_update_views(dt)
	_update_camera(dt)
	_audio(dt)
	_tips(dt)
	fxl.tick(dt)
	mprops.tick(dt)
	_events()
	sub_t = maxf(0, sub_t - dt)
	hud.refresh()


## Piloto automático para testes: o esquadrão vai ao objetivo e ataca quem estiver mais perto.
func _autoplay(dt: float) -> void:
	auto_t -= dt * speed
	center_on_selection()
	if auto_t > 0:
		return
	auto_t = 2.5
	sim.set_sel(M.agents.filter(func(a): return not a.dead))
	if M.sel.is_empty():
		return
	var L: Unit = M.sel[0]
	var best: Unit = null
	var bd := 9.0
	for u in M.units:
		if u.dead or u.fac == "player" or u.fac == "civ" or u.fac == "neutral" or (u.fac == "police" and M.police_aggro <= 0):
			continue
		var d := L.dist_to(u)
		if d < bd:
			bd = d
			best = u
	if best:
		sim.issue_attack(best)
		return
	var goal = null
	if M.hand:
		for tm in M.terms:
			if not tm.done:
				goal = Vector2(tm.x, tm.y)
				break
		if M.sci and not M.sci.dead and not M.sci.follow:
			goal = M.sci.pos2()
		elif M.vip and not M.vip.dead:
			goal = M.vip.pos2()
		if goal == null:
			for u in M.units:
				if (u.kind == "inimigo" or u.kind == "guarda") and not u.dead and not u.follower:
					goal = u.pos2()
					break
		if goal == null:
			goal = M.spawn
		sim.issue_move(goal)
		return
	match M.tipo:
		"assassinato": goal = M.vip.pos2() if M.vip and not M.vip.dead else null
		"extracao": goal = M.sci.pos2() if not M.sci.follow else M.evac
		"sabotagem":
			for tm in M.terms:
				if not tm.done:
					goal = Vector2(tm.x, tm.y)
					break
		_:
			for u in M.units:
				if u.kind == "inimigo" and not u.dead and not u.follower:
					goal = u.pos2()
					break
	if goal != null:
		sim.issue_move(goal)


# ---------------------------------------------------------------- câmera
func _update_camera(dt: float) -> void:
	var pan := Vector2()
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): pan.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): pan.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): pan.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): pan.x += 1
	var vp := get_viewport()
	var mp := vp.get_mouse_position()
	var vs := vp.get_visible_rect().size
	if DisplayServer.window_is_focused() and drag_from == null and mp.x >= 0 and mp.y >= 0 and mp.x < vs.x and mp.y < vs.y:
		if mp.x < 6: pan.x -= 1
		if mp.x > vs.x - 6: pan.x += 1
		if mp.y < 6: pan.y -= 1
		if mp.y > vs.y - 6: pan.y += 1
	if M.cine:
		pan = Vector2.ZERO
	if pan != Vector2.ZERO:
		var yr := deg_to_rad(cam_yaw)
		var fwd := Vector3(-sin(yr), 0, -cos(yr))
		var right := Vector3(cos(yr), 0, -sin(yr))
		cam_target += (right * pan.x - fwd * pan.y) * dt * cam_dist * .9
	cam_target.x = clampf(cam_target.x, 0, C.N * W)
	cam_target.z = clampf(cam_target.z, 0, C.N * W)
	if M.cam_goal != null:
		var g: Dictionary = M.cam_goal
		if g.from == null:
			g.from = [cam_target, cam_dist_goal]
		g.t += dt
		var k := smoothstep(0.0, 1.0, clampf(g.t / maxf(g.dur, .01), 0, 1))
		cam_target = g.from[0].lerp(_world(g.p.x, g.p.y), k)
		cam_dist_goal = lerpf(g.from[1], 34.0 / g.z, k)
		if g.t >= g.dur and not M.cine:
			M.cam_goal = null
	cam_yaw = lerpf(cam_yaw, cam_yaw_goal, minf(1, dt * 8))
	cam_dist = lerpf(cam_dist, cam_dist_goal, minf(1, dt * 10))
	shake = maxf(0, shake - dt * 2)
	var yr := deg_to_rad(cam_yaw)
	var pr := deg_to_rad(cam_pitch)
	var off := Vector3(sin(yr) * cos(pr), sin(pr), cos(yr) * cos(pr)) * cam_dist
	var jitter := Vector3(randf() - .5, randf() - .5, randf() - .5) * shake * .6
	cam.position = cam_target + off + jitter
	cam.look_at(cam_target + jitter * .5, Vector3.UP)
	# recorte dos prédios: cilindro entre a câmera e o esquadrão (ou o centro da tela)
	var focus := cam_target + Vector3(0, 1.0, 0)
	var alive := M.sel if not M.sel.is_empty() else M.agents.filter(func(a): return not a.dead)
	if not alive.is_empty():
		var c := Vector3()
		for a in alive:
			c += _world(a.x, a.y, 1.0)
		focus = c / alive.size()
	RenderingServer.global_shader_parameter_set("cut_cam", cam.global_position)
	RenderingServer.global_shader_parameter_set("cut_pos", focus)
	RenderingServer.global_shader_parameter_set("cut_r", 7.0)


func center_on_selection() -> void:
	var list := M.sel if not M.sel.is_empty() else M.agents.filter(func(a): return not a.dead)
	if list.is_empty():
		return
	var c := Vector3()
	for a in list:
		c += _world(a.x, a.y)
	cam_target = c / list.size()


# ---------------------------------------------------------------- entrada
func screen_to_tile(sp: Vector2) -> Vector2:
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	if absf(d.y) < 1e-4:
		return Vector2(-1, -1)
	var t := (C.CURB * .5 - o.y) / d.y
	var p := o + d * t
	return Vector2(p.x / W, p.z / W)


## Carro livre (não roteirizado, inteiro) sob o ponto p em tiles.
func pick_car(p: Vector2):
	var best = null
	var bd := 1.0
	for c in M.cars:
		if c.dead or c.get("scripted", false):
			continue
		var d := Vector2(c.x, c.y).distance_to(p)
		if d < bd:
			bd = d
			best = c
	return best


func pick_unit(sp: Vector2) -> Unit:
	var best: Unit = null
	var bd := 34.0
	for u in M.units:
		if u.dead:
			continue
		var wp := _world(u.x, u.y, ground_at(u.x, u.y) + 1.0)
		if cam.is_position_behind(wp):
			continue
		var s := cam.unproject_position(wp)
		var d := s.distance_to(sp)
		if d < bd:
			bd = d
			best = u
	return best


func _unhandled_input(e: InputEvent) -> void:
	if M == null:
		return
	if M.cine:
		if e is InputEventKey and e.pressed and (e.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]):
			M.cine_skip = true
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_dist_goal = clampf(cam_dist_goal / 1.12, 14, 90)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam_dist_goal = clampf(cam_dist_goal * 1.12, 14, 90)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			rot_from = mb.position if mb.pressed else null
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				drag_from = mb.position
				dragging = false
			elif drag_from != null:
				if dragging:
					_box_select(drag_from, mb.position, mb.shift_pressed)
				else:
					_left_click(mb.position, mb.shift_pressed)
				drag_from = null
				dragging = false
				hud.set_box(Rect2())
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_right_click(mb.position)
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if rot_from != null:
			var d: float = mm.position.x - rot_from.x
			if absf(d) > 60:
				cam_yaw_goal += 45.0 * signf(d)
				rot_from = mm.position
		if drag_from != null and mm.position.distance_to(drag_from) > 8:
			dragging = true
			hud.set_box(Rect2(drag_from, mm.position - drag_from).abs())
		hover = pick_unit(mm.position)
		hover_car = pick_car(screen_to_tile(mm.position)) if not M.sel.is_empty() else null
	elif e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).keycode
		if M.ended and Camp.active and (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_ESCAPE):
			finished.emit()
			return
		if k == KEY_ESCAPE:
			toggle_pause_menu()
			return
		if hud.pause_open:
			return
		match k:
			KEY_1, KEY_2, KEY_3, KEY_4:
				var a: Unit = M.agents[k - KEY_1] if k - KEY_1 < M.agents.size() else null
				if a and not a.dead:
					if e.shift_pressed:
						var l := M.sel.duplicate()
						if a in l: l.erase(a)
						else: l.append(a)
						sim.set_sel(l)
					else:
						if M.sel.size() == 1 and M.sel[0] == a:
							center_on_selection()
						sim.set_sel([a])
			KEY_0, KEY_QUOTELEFT:
				sim.set_sel(M.agents.filter(func(x): return not x.dead))
			KEY_G: sim.drop_container()
			KEY_Q: sim.cycle_weapon(-1)
			KEY_E: sim.cycle_weapon(1)
			KEY_H: sim.holster()
			KEY_V: sim.exit_selected()
			KEY_F:
				if not M.sel.is_empty():
					sim.set_preset((maxi(-1, sim.preset_of(M.sel[0])) + 1) % 3)
			KEY_Z: cam_yaw_goal -= 45
			KEY_X: cam_yaw_goal += 45
			KEY_C: center_on_selection()
			KEY_SPACE: paused = not paused and not M.ended
			KEY_R:
				if not Camp.active and (M.ended or e.ctrl_pressed):
					get_tree().reload_current_scene()
			KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6:
				sim.use_slot(k - KEY_F1)


func _left_click(sp: Vector2, shift: bool) -> void:
	var u := pick_unit(sp)
	if u and u.kind == "agente":
		if shift:
			var l := M.sel.duplicate()
			if u in l: l.erase(u)
			else: l.append(u)
			sim.set_sel(l)
		else:
			sim.set_sel([u])
			bark("ag:sel", u)
		Snd.play("ui")
		return
	if M.sel.is_empty():
		return
	var p := screen_to_tile(sp)
	if p.x < 0 or p.y < 0 or p.x >= C.N or p.y >= C.N:
		return
	var car = pick_car(p)
	if car != null and M.sel.any(func(a): return a.in_car == null):
		sim.issue_enter(car)
		Snd.play("ui")
		return
	sim.issue_move(p)
	bark("ag:mov", M.sel[0])


func _right_click(sp: Vector2) -> void:
	if M.sel.is_empty():
		return
	var u := pick_unit(sp)
	if u and u.fac != "player":
		sim.issue_attack(u)
		bark("ag:atk", M.sel[0])
	else:
		var p := screen_to_tile(sp)
		sim.issue_ground(p)


func _box_select(a: Vector2, b: Vector2, shift: bool) -> void:
	var r := Rect2(a, b - a).abs()
	var inside := []
	for ag in M.agents:
		if ag.dead:
			continue
		var s := cam.unproject_position(_world(ag.x, ag.y, 1.0))
		if r.has_point(s):
			inside.append(ag)
	if inside.is_empty():
		return
	if shift:
		for x in M.sel:
			if not x in inside:
				inside.append(x)
	sim.set_sel(inside)


# ---------------------------------------------------------------- efeitos
func _on_fx(kind: String, d: Dictionary) -> void:
	match kind:
		"spawn":
			if d.u.view == null:
				_make_view(d.u)
		"car":
			mprops.car_view(d.c)
		"reveal":
			var u: Unit = d.u
			u.view_kind = "enemy"
			if u.view:
				u.view.queue_free()
				u.view = null
			_make_view(u)
		"explosion":
			shake = minf(1.0, shake + .6)
		"end":
			hud.show_end(d.win, M.reason)
	_sound(kind, d)
	fxl.event(kind, d)



# ---------------------------------------------------------------- falas com legenda
func _setup_vo() -> void:
	var f := FileAccess.open("res://assets/audio/vo.json", FileAccess.READ)
	if f:
		vo_lines = JSON.parse_string(f.get_as_text())
	vo_player = AudioStreamPlayer.new()
	vo_player.bus = "Radio"
	add_child(vo_player)


func say(key: String) -> void:
	var opts = vo_lines.get(key, vo_lines.get(key + ":m", vo_lines.get(key + ":f", null)))
	if opts == null or opts.is_empty():
		return
	var line: Array = opts[randi() % opts.size()]
	var txt: String = line[1]
	hud.subtitle(txt)
	sub_t = 1.5 + txt.length() * .055
	var path := "res://assets/audio/vo/%s.mp3" % line[0]
	if ResourceLoader.exists(path):
		vo_player.stream = load(path)
		vo_player.play()
		Snd.play("squelch")
		sub_t = maxf(sub_t, vo_player.stream.get_length() + .3)
		comm_until = maxf(comm_until, M.t + vo_player.stream.get_length() + .3)


# ---------------------------------------------------------------- som: efeitos, falas curtas e trilha
const BARK_CD := {"ag:sel": 1.2, "ag:mov": 1.4, "ag:atk": 2.5, "ag:kill": 3.0, "ag:hurt": 6.0, "ag:rel": 5.0, "pol:warn": 4.0}
const VOICE_BUS := {ag = "Radio", ctl = "Radio", riv = "Helmet", grd = "Helmet", ene = "Helmet", pol = "Mega", civ = "SFX", vip = "SFX", sci = "SFX"}
var listener: AudioListener3D
var comm_until := 0.0
var bark_last := {}
var bark_file := {}
var hum_t := 0.0
var vent_state := {}
var had_train := false


func _voice_of(u: Unit) -> String:
	return "f" if u and u.seed % 2 == 1 else "m"


## Fala curta pelo rádio do esquadrão (ag:*, ctl:*) ou no mundo (riv:*, pol:*...). Respeita intervalos e o canal ocupado.
func bark(key: String, u: Unit = null) -> void:
	if M.cine or M.ended and not key.begins_with("ctl:"):
		return
	var k := key
	if key.begins_with("ag:"):
		k = "%s:%s" % [key, _voice_of(u)]
	var role := k.split(":")[0]
	var comm := role == "ag" or role == "ctl"
	var now := M.t
	if now - bark_last.get(key, -99.0) < BARK_CD.get(key, 2.5):
		return
	if comm and (now < comm_until or talking()):
		return
	var opts: Array = vo_lines.get(k, [])
	if opts.is_empty():
		return
	var i := randi() % opts.size()
	if opts.size() > 1 and opts[i][0] == bark_file.get(k, ""):
		i = (i + 1) % opts.size()
	bark_file[k] = opts[i][0]
	bark_last[key] = now
	var path := "res://assets/audio/vo/%s.mp3" % opts[i][0]
	if not ResourceLoader.exists(path):
		return
	var s: AudioStream = load(path)
	var pitch := .95 + float(u.seed % 10) / 100.0 if u and role == "ag" else randf_range(.97, 1.03)
	if comm:
		comm_until = now + s.get_length() / pitch + .25
		Snd.voice(s, "Radio", null, pitch)
		hud.add_log("%s: %s" % [(u.nome.to_upper() if u else "CONTROLE"), opts[i][1]], "cyan" if role == "ag" else "amber")
	else:
		Snd.voice(s, VOICE_BUS.get(role, "SFX"), _world(u.x, u.y, 1.6) if u else null, pitch)


func _sound(kind: String, d: Dictionary) -> void:
	match kind:
		"muzzle":
			var w: Dictionary = GD.WD.get(d.get("wk", ""), {})
			if w.has("som"):
				Snd.play(w.som, _world(d.x, d.y, 1.4), -2.0 if d.u.fac != "player" else 0.0)
		"explosion":
			Snd.play("boom", _world(d.x, d.y, 1))
		"glass":
			Snd.play("glass", _world(d.x, d.y, 2))
		"car_dead":
			Snd.play("crash", _world(d.c.x, d.c.y, 1))
		"blood":
			Snd.play("hit", _world(d.x, d.y, 1.2))
		"tracer":
			if d.get("wall", false) and randf() < .3:
				Snd.play("ric", _world(d.x2, d.y2, 1.3))
		"death":
			var u: Unit = d.u
			if not u.mech:
				Snd.play("die", _world(u.x, u.y, 1))
			var src = d.get("src")
			if u.kind == "agente":
				var o: Unit = null
				for a in M.agents:
					if not a.dead:
						o = a
						break
				if o:
					bark("ag:down", o)
			elif u.rival != "":
				bark("riv:%s_death" % u.rival, u)
			elif src is Unit and src.kind == "agente" and u.kind != "civil" and randf() < .55:
				bark("ag:kill", src)
		"hurt":
			bark("ag:hurt", d.u)
		"pickup":
			Snd.play("pickup")
		"door":
			Snd.play("door", _world(d.x, d.y, 1))
		"honk":
			Snd.play("honk", _world(d.x, d.y, 1))
		"car_in":
			bark("ag:car", d.u)
		"alarm":
			Snd.play("alarm")
		"siren":
			Snd.play("siren")
		"hack":
			Snd.play("hack")
		"convert":
			var u: Unit = d.u
			Snd.play("convert", _world(u.x, u.y, 1))
			if u.owner and u.owner.kind == "agente" and randf() < .5:
				bark("ag:conv", u.owner)
		"crash":
			bark("ag:crash", d.u)
		"preset":
			Snd.play("ui")
			if d.i == 2 and d.u:
				bark("ag:over", d.u)
		"rival_spot":
			bark("riv:%s_intro" % d.u.rival, d.u)
		"vanish":
			var u: Unit = d.u
			if u.rival != "":
				bark("riv:%s_esc" % u.rival, u)
		"pol_warn":
			bark("pol:warn", d.u)
		"nade":
			if d.has("u"):
				bark("ag:grn", d.u)
		"end":
			Snd.play("win" if d.win else "lose")


func _audio(dt: float) -> void:
	if cam:
		var yaw := cam.global_basis.get_euler().y
		listener.global_transform = Transform3D(Basis(Vector3.UP, yaw), cam_target + Vector3(0, 4, 0))
	Snd.duck = vo_player.playing or M.t < comm_until
	Snd.set_intensity(0 if M.ended else (3 if M.t - M.last_combat < 7 else (2 if M.corp_alert or M.police_aggro > 0 else 1)))
	# motor do carro em movimento mais perto da câmera
	var best = null
	var bd := 30.0
	for c in M.cars:
		if c.get("dead", false) or c.get("cur", 0.0) < .3:
			continue
		var dd := Vector2(c.x * W, c.y * W).distance_to(Vector2(cam_target.x, cam_target.z))
		if dd < bd * W:
			bd = dd / W
			best = c
	if best != null:
		Snd.engine(best.cur, _world(best.x, best.y, .8))
	else:
		Snd.engine(0)
	hum_t -= dt
	if hum_t <= 0:
		hum_t = .5
		for u in M.units:
			if u.kind == "drone" and not u.dead and not u.off and _world(u.x, u.y).distance_to(cam_target) < 40:
				Snd.play("drone", _world(u.x, u.y, 2.6), -4.0)
				break
	for i in M.vents.size():
		var v: Dictionary = M.vents[i]
		var st: int = v.get("state", 0)
		if st == 2 and vent_state.get(i, 0) != 2:
			Snd.play("steam", _world(v.x, v.y, .5))
		vent_state[i] = st
	if (M.train != null) != had_train:
		had_train = M.train != null
		if had_train and M.rail != null:
			Snd.play("train", cam_target, -2.0)


# ---------------------------------------------------------------- dicas contextuais (uma vez cada, podem ser desligadas)
const TIPS := {
	start = "Clique num agente (ou arraste para pegar o grupo) e clique no chão para mover. Botão direito ataca.",
	probe = "Um agente leva a SONDA: equipe-a e fique perto das pessoas para recrutá-las como seguidores.",
	police = "A polícia está advertindo: aperte H para guardar as armas e ela se acalma.",
	alert = "Combate! Espaço pausa o jogo para você dar ordens com calma.",
	hurt = "Agente ferido: use o KIT MÉDICO no inventário (teclas F1–F6) para curá-lo.",
	cover = "O escudo indica cobertura: encostado em paredes, contêineres ou carros, o agente evita metade dos tiros.",
	car = "Com agentes selecionados, clique num carro para entrar. Depois clique no mapa para dirigir e V para sair.",
	rotate = "Z e X giram a câmera quando um prédio atrapalha a visão.",
	drone = "Drones de segurança voam por cima dos muros. Equipe a CHAVE FANTASMA e clique com o botão direito num drone para invadi-lo.",
	vent = "A grade fica laranja e chia antes do vapor sair. Afaste o esquadrão e atraia os guardas para ela.",
	laser = "Cruzar um feixe vermelho dispara o alarme. Alguns piscam: espere apagar para passar.",
	glass = "Vidro não segura balas: os tiros atravessam e estilhaçam as paredes.",
	heavy = "Soldados pesados aguentam muita bala comum. Granadas e munição perfurante funcionam melhor.",
	shield = "O escudo azul vem dos pilares ligados por feixes. Derrube os pilares ou invada-os com a CHAVE FANTASMA.",
	scan = "Sósias: fique perto de um suspeito, com as armas guardadas, até o anel do scanner fechar.",
	neuro = "Os mostradores neurais ao lado dos cartões trocam velocidade, precisão e discrição. F alterna as predefinições; SOBRECARGA cansa e pode levar ao colapso.",
}
const TIP_CFG := "user://config.cfg"
var hover_car = null
var tip_q: Array = []
var tip_t := 0.0
var tip_chk := 0.0
var tips_on := true
var tips_seen: Array = []


func _tips_load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(TIP_CFG) == OK:
		tips_on = cfg.get_value("tips", "on", true)
		tips_seen = cfg.get_value("tips", "seen", [])
	if "--notips" in OS.get_cmdline_user_args():
		tips_on = false


static func set_tips(on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(TIP_CFG)
	cfg.set_value("tips", "on", on)
	if on:
		cfg.set_value("tips", "seen", [])
	cfg.save(TIP_CFG)


static func tips_enabled() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(TIP_CFG) == OK:
		return cfg.get_value("tips", "on", true)
	return true


func tip(id: String) -> void:
	if tips_on and not id in tips_seen and not id in tip_q:
		tip_q.append(id)


func _tips(dt: float) -> void:
	if not tips_on or M.ended or auto or look != null:
		return
	tip_chk -= dt
	if tip_chk <= 0 and not M.cine:
		tip_chk = .5
		_tip_checks()
	tip_t -= dt
	if tip_t > 0 or tip_q.is_empty() or M.cine:
		return
	var id: String = tip_q.pop_front()
	tips_seen.append(id)
	var cfg := ConfigFile.new()
	cfg.load(TIP_CFG)
	cfg.set_value("tips", "seen", tips_seen)
	cfg.save(TIP_CFG)
	hud.show_tip(TIPS[id])
	tip_t = 11.0


func _near_agent(x: float, y: float, r: float) -> bool:
	for a in M.agents:
		if not a.dead and a.in_car == null and Vector2(a.x - x, a.y - y).length() < r:
			return true
	return false


func _tip_checks() -> void:
	if M.t > 1: tip("start")
	if M.t > 20: tip("neuro")
	for a in M.agents:
		if a.dead:
			continue
		if M.t > 6 and a.inv.any(func(q): return q.t == "sonda"): tip("probe")
		if a.hp < a.max_hp * .5 and a.inv.any(func(q): return q.t == "medkit"): tip("hurt")
		if a.covered: tip("cover")
	if M.corp_alert or M.police_aggro > 0: tip("alert")
	if hover_car != null: tip("car")
	if M.t > 45: tip("rotate")
	if M.glass_n > 0 and M.t > 25: tip("glass")
	for u in M.units:
		if u.dead:
			continue
		if u.kind == "policia" and u.warned: tip("police")
		elif u.kind == "drone" and u.fac == "corp" and _near_agent(u.x, u.y, 10): tip("drone")
		elif u.heavy and u.alerted and _near_agent(u.x, u.y, 9): tip("heavy")
		elif u.boss and u.shield and _near_agent(u.x, u.y, 12): tip("shield")
		elif u.cand and not u.scanned and _near_agent(u.x, u.y, 7): tip("scan")
	for v in M.vents:
		if not v.get("off", false) and _near_agent(v.x, v.y, 4): tip("vent")
	for l in M.lasers:
		if l.get("on", false) and not l.has("dmg") and _near_agent((l.x1 + l.x2) / 2, (l.y1 + l.y2) / 2, 6): tip("laser")


func talking() -> bool:
	return sub_t > 0 or vo_player.playing


# ---------------------------------------------------------------- mudanças no mapa vindas da simulação
func _events() -> void:
	if M.events.is_empty():
		return
	for e in M.events:
		mprops.event(e)
	M.events.clear()

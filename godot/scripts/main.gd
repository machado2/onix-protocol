## Cena principal. Sem argumentos abre a campanha: a cidade 3D gira ao fundo dos menus (CampaignMenu) e cada
## distrito lança uma missão (Game); no fim, o resultado volta para a campanha (Camp).
## Testes (depois de --): --mission=docas|...|assassinato|extracao|sabotagem|eliminacao --dif=1..9 --seed=N --riq=0.6
## Vitrine sem jogo: --cam=x,z,dist,yaw,pitch,fov (metros e graus) com --chars, --crowd ou --view.
## Roteiro da campanha com capturas: --camptest=pasta [--launch=N] [--auto --speed=4].
extends Node3D

const CFG := "user://config.cfg"

var cam: Camera3D
var env: Environment
var moon: DirectionalLight3D
var vp_base_mode := Viewport.SCALING_3D_MODE_BILINEAR
var quality := "medium"
var menu: CampaignMenu
var city: CityBuilder
var game: Game
var orbit := false
var orbit_c := Vector3()
var orbit_r := 110.0
var orbit_a := .6
var cur_di := -1
var cur_rev := false
var test_dir := ""


func _arg(k: String, def := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
		if a == k:
			return "1"
	return def


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG) == OK:
		quality = cfg.get_value("video", "quality", quality)
	quality = _arg("--quality", quality)
	if _arg("--simtest") != "":
		add_child(load("res://scripts/dev/simtest.gd").new())
		return
	_environment()
	var args := OS.get_cmdline_user_args()
	var dev := _arg("--mission") != "" or "--chars" in args or "--crowd" in args or "--view" in args
	if dev:
		_dev()
	else:
		_campaign()


# ---------------------------------------------------------------- campanha
func _campaign() -> void:
	cam = Camera3D.new()
	cam.fov = 34
	cam.near = 1.0
	cam.far = 900.0
	add_child(cam)
	cam.make_current()
	menu = CampaignMenu.new()
	menu.quality = quality
	add_child(menu)
	menu.launch.connect(_launch)
	menu.quality_changed.connect(_set_quality)
	var map := CityGen.generate(31337, .75, 1)
	_backdrop(map, Vector2(C.N * .5, C.N * .5), 120.0)
	menu.show_title()
	test_dir = _arg("--camptest")
	if test_dir != "":
		_camptest()


## Cidade de fundo dos menus com a câmera girando devagar em volta de p (em tiles).
func _backdrop(map: Dictionary, p: Vector2, r: float) -> void:
	if city == null:
		city = CityBuilder.new()
		city.name = "Cidade"
		city.focus = Vector3(p.x * C.TILE, 0, p.y * C.TILE)
		add_child(city)
		city.build(map)
	orbit_c = Vector3(p.x * C.TILE, 0, p.y * C.TILE)
	orbit_r = r
	orbit = true
	cam.make_current()


func _launch(di: int, rev: bool) -> void:
	cur_di = di
	cur_rev = rev
	var d: Dictionary = Camp.DIST[di]
	menu.show_loading(d.nome.to_upper(), "Repressão da revolta · montando o distrito" if rev else "Montando o distrito · %s" % CampaignMenu.TIPOS[d.tipo].to_lower())
	await get_tree().process_frame
	await get_tree().process_frame
	if city:
		city.queue_free()
		city = null
	await get_tree().process_frame
	orbit = false
	var tipo: String = d.tipo
	var dif: int = d.dif
	var seed: int = di * 7919 + Camp.G.dia * 31337
	var hand_def = null
	var hand_m: Mission = null
	var map: Dictionary
	if not rev:
		hand_def = Missions.script_for(d.mission)
		hand_m = Mission.new()
		hand_m.hand = true
		hand_m.def_name = d.mission
		var B := MB.new(hand_m)
		hand_def.build(B)
		map = B.to_map(hand_def.SPAWN)
	else:
		tipo = "eliminacao"
		map = CityGen.generate(seed, d.riq, 1)
	city = CityBuilder.new()
	city.name = "Cidade"
	city.focus = Vector3(map.spawn.x * C.TILE, 0, map.spawn.y * C.TILE)
	add_child(city)
	city.build(map)
	game = Game.new()
	game.name = "Partida"
	add_child(game)
	game.start(map, city, tipo, dif, seed, hand_m, hand_def, Camp.squad(), rev)
	game.finished.connect(_mission_done)
	menu.hide_all()


func _mission_done() -> void:
	if game == null:
		return
	var r := Camp.apply_result(game.M, cur_di, cur_rev)
	var p: Vector3 = game.cam_target
	game.queue_free()
	game = null
	_backdrop({}, Vector2(p.x / C.TILE, p.z / C.TILE), 70.0)
	menu.show_result(r)
	if test_dir != "":
		_snap_later("08_resultado", 30)


func _process(dt: float) -> void:
	if orbit and cam:
		orbit_a += dt * .035
		var h := orbit_r * .55
		cam.position = orbit_c + Vector3(sin(orbit_a) * orbit_r, h, cos(orbit_a) * orbit_r)
		cam.look_at(orbit_c + Vector3(0, 6, 0), Vector3.UP)
	if game and game.auto and game.M.ended and game.M.end_t > 2.5:
		_mission_done()
	for w in walkers:
		w[0].position += w[1] * dt


func _set_quality(q: String) -> void:
	quality = q
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value("video", "quality", q)
	cfg.save(CFG)
	_apply_quality()


# ---------------------------------------------------------------- roteiro de teste
func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(test_dir.path_join(name + ".jpg"), .88)
	print("SNAP ", name)


func _snap_later(name: String, frames: int) -> void:
	for k in frames:
		await get_tree().process_frame
	await _snap(name)
	if name == "08_resultado":
		await _wait(10)
		menu.close_modal()
		menu.show_map()
		await _wait(20)
		await _snap("09_mapa_depois")
		get_tree().quit()


func _wait(frames: int) -> void:
	for k in frames:
		await get_tree().process_frame


func _camptest() -> void:
	DirAccess.make_dir_recursive_absolute(test_dir)
	await _wait(40)
	await _snap("01_titulo")
	Camp.new_game()
	menu.map_sel = 0
	menu.show_map()
	menu.show_msg("inicio", false)
	await _wait(10)
	await _snap("02_mensagem")
	menu.show_map()
	await _wait(10)
	await _snap("03_mapa")
	menu.open_briefing(0)
	await _wait(10)
	await _snap("04_briefing")
	Camp.G.dinheiro += 30000
	Camp.G.pesq.done["impl2"] = true
	menu.show_arsenal()
	await _wait(10)
	await _snap("05_arsenal")
	menu.show_lab()
	await _wait(10)
	await _snap("06_laboratorio")
	Camp.unlock("docas")
	Camp.unlock("navalha_visto")
	menu.show_inbox()
	await _wait(10)
	await _snap("07_interceptacoes")
	var li := _arg("--launch")
	if li == "":
		get_tree().quit()
		return
	menu.close_modal()
	if _arg("--rich") != "":
		for a in Camp.G.agentes:
			a.inv = [{t = "smg"}, {t = "pistola"}, {t = "granada"}, {t = "medkit"}]
			a.imp.chassi = 2
			a.imp.otica = 1
	if _arg("--revolt") != "":
		Camp.G.dono[int(li)] = "player"
		Camp.terr(int(li)).revolta = 2
		Camp.terr(int(li)).lealdade = 0
	await _launch(int(li), _arg("--revolt") != "")
	await _wait(int(_arg("--snapat", "400")))
	await _snap("075_missao")


# ---------------------------------------------------------------- testes e vitrine (sem campanha)
func _dev() -> void:
	var seed := 4242
	var riq := .6
	var camv := [84.0, 96.0, 70.0, 45.0, 42.0, 30.0]
	var tipo: String = ["assassinato", "extracao", "sabotagem", "eliminacao"][randi() % 4]
	var dif := 3
	var args := OS.get_cmdline_user_args()
	var play := not ("--chars" in args or "--crowd" in args or "--view" in args)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mission="):
			tipo = a.substr(10)
		elif a.begins_with("--dif="):
			dif = int(a.substr(6))
		if a.begins_with("--seed="):
			seed = int(a.substr(7))
		elif a.begins_with("--riq="):
			riq = float(a.substr(6))
		elif a.begins_with("--cam="):
			var p := a.substr(6).split(",")
			for i in p.size():
				camv[i] = float(p[i])
	var hand_def = Missions.script_for(tipo) if Missions.DIST.has(tipo) else null
	var hand_m: Mission = null
	var map: Dictionary
	if hand_def != null:
		hand_m = Mission.new()
		hand_m.hand = true
		hand_m.def_name = tipo
		var B := MB.new(hand_m)
		hand_def.build(B)
		map = B.to_map(hand_def.SPAWN)
		dif = Missions.DIST[tipo].dif
	else:
		map = CityGen.generate(seed, riq, 2 if tipo == "sabotagem" else 1)
	if "--list" in OS.get_cmdline_user_args():
		for b in map.blds:
			if b.fl >= 5:
				print("BLD x=%d y=%d w=%d d=%d fl=%d" % [b.x * 3, b.y * 3, b.w, b.d, b.fl])
	var city := CityBuilder.new()
	city.name = "Cidade"
	city.focus = Vector3(camv[0], 0, camv[1])
	add_child(city)
	if play:
		city.focus = Vector3(map.spawn.x * C.TILE, 0, map.spawn.y * C.TILE)
	city.build(map)
	if play:
		var g := Game.new()
		g.name = "Partida"
		add_child(g)
		if hand_def != null:
			g.start(map, city, Missions.DIST[tipo].tipo, dif, seed, hand_m, hand_def)
		else:
			g.start(map, city, tipo, dif, seed)
		return
	if "--chars" in OS.get_cmdline_user_args():
		var kinds := ["agent", "agent", "guard", "police", "civil", "civil", "civil", "vip", "civil", "scientist", "civil", "civil"]
		var anims := ["aim", "walk", "walk", "aim", "walk", "idle", "panic", "idle", "run", "type", "walk", "idle"]
		for i in kinds.size():
			var ch := Character3D.new()
			add_child(ch)
			ch.setup(kinds[i], i)
			var p := Vector3(camv[0] + (i % 6 - 2.5) * 1.5, 0, camv[1] + (i / 6) * 2.2)
			var t: int = map.tile[int(p.z / C.TILE) * C.N + int(p.x / C.TILE)]
			p.y = 0.0 if t == C.T.ROAD else C.CURB
			ch.position = p
			ch.rotation.y = .5
			ch.play(anims[i], 0.0, 1.0, i * .37)
	if "--crowd" in OS.get_cmdline_user_args():
		_crowd(map, Vector3(camv[0], 0, camv[1]))
	cam = Camera3D.new()
	cam.fov = camv[5]
	cam.near = 1.0
	cam.far = 600.0
	add_child(cam)
	var yaw := deg_to_rad(camv[3])
	var pitch := deg_to_rad(camv[4])
	var target := Vector3(camv[0], 0, camv[1])
	var off: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * camv[2]
	cam.position = target + off
	cam.look_at(target, Vector3.UP)




func _environment() -> void:
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#0e1222")
	sm.sky_horizon_color = Color("#4a3450")
	sm.ground_bottom_color = Color("#05060a")
	sm.ground_horizon_color = Color("#3a2a40")
	sm.sky_energy_multiplier = 1.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.25
	env.ssr_enabled = true
	env.ssr_max_steps = 96
	env.ssr_fade_in = .1
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = .3
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.5
	env.ssao_power = 1.4
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 1.2
	env.glow_enabled = true
	env.glow_intensity = .55
	env.glow_strength = 1.0
	env.glow_bloom = .04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, .8)
	env.set_glow_level(4, .6)
	env.set_glow_level(5, .4)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = .02
	env.volumetric_fog_albedo = Color("#8890a8")
	env.volumetric_fog_emission = Color("#0a0c14")
	env.volumetric_fog_emission_energy = .3
	env.volumetric_fog_length = 160.0
	env.volumetric_fog_anisotropy = .5
	env.volumetric_fog_ambient_inject = .2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.1
	_apply_quality()
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.light_color = Color("#9fb4ff")
	moon.light_energy = .45
	moon.rotation_degrees = Vector3(-55, 30, 0)
	moon.directional_shadow_max_distance = 220.0
	moon.light_volumetric_fog_energy = .4
	add_child(moon)
	moon.shadow_enabled = not get_tree().has_meta("nomoon")


## Níveis de qualidade: low (placas de entrada), medium (GTX 1650 a 60 fps), high (tudo ligado).
## Vale na hora para o ambiente; sombras de postes e a resolução das sombras valem a partir do próximo distrito.
func _apply_quality() -> void:
	var vp := get_viewport()
	var off := _arg("--off").split(",")
	env.ssr_enabled = not "ssr" in off
	env.ssr_max_steps = 96
	env.ssil_enabled = not "ssil" in off
	env.ssao_enabled = not "ssao" in off
	env.volumetric_fog_enabled = not "fog" in off
	env.volumetric_fog_density = .02
	for m in ["nomoon", "noshadow", "shadow_r"]:
		if get_tree().has_meta(m):
			get_tree().remove_meta(m)
	if "shadows" in off:
		get_tree().set_meta("noshadow", true)
	if "moon" in off:
		get_tree().set_meta("nomoon", true)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 1.0
	match quality:
		"low":
			env.ssr_enabled = false
			env.ssil_enabled = false
			env.volumetric_fog_enabled = false
			env.ssao_enabled = false
			get_tree().set_meta("nomoon", true)
			get_tree().set_meta("noshadow", true)
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
			vp.scaling_3d_scale = .67
		"medium":
			env.ssil_enabled = false
			env.ssr_max_steps = 48
			env.volumetric_fog_density = .016
			get_tree().set_meta("nomoon", true)
			get_tree().set_meta("shadow_r", 24.0)
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
			vp.scaling_3d_scale = .77
	if moon:
		moon.shadow_enabled = not get_tree().has_meta("nomoon")


## Povoa a área perto do foco: pedestres andando nas calçadas, esquadrão de agentes, guardas e polícia.
var walkers := []

func _crowd(map: Dictionary, focus: Vector3) -> void:
	var r := C.Rng.new(77)
	var n := 0
	for k in 900:
		if n >= 26:
			break
		var x := int(focus.x / C.TILE) + r.range_i(17) - 8
		var y := int(focus.z / C.TILE) + r.range_i(17) - 8
		if x < 0 or y < 0 or x >= C.N or y >= C.N:
			continue
		var t: int = map.tile[y * C.N + x]
		if t != C.T.WALK and t != C.T.PLAZA:
			continue
		var ch := Character3D.new()
		add_child(ch)
		ch.setup("civil", n)
		var dir := Vector3(1, 0, 0) if r.next() < .5 else Vector3(0, 0, 1)
		if r.next() < .5:
			dir = -dir
		ch.position = Vector3((x + .2 + r.next() * .6) * C.TILE, C.CURB, (y + .2 + r.next() * .6) * C.TILE)
		ch.rotation.y = atan2(dir.x, dir.z)
		var a := "walk" if r.next() < .7 else "idle"
		ch.play(a, 0.0, 1.0, r.next() * 3.0)
		if a == "walk":
			walkers.append([ch, dir * ch.clip_speed("walk")])
		n += 1
	var squad := ["agent", "agent", "agent", "agent"]
	for i in 4:
		var ch := Character3D.new()
		add_child(ch)
		ch.setup(squad[i], i)
		ch.position = focus + Vector3((i % 2) * 1.4 - .7, 0, (i / 2) * 1.6 - .8)
		ch.rotation.y = -2.2 + i * .2
		ch.play("aim" if i < 2 else "walk", 0.0, 1.0, i * .5)
	for i in 3:
		var ch := Character3D.new()
		add_child(ch)
		ch.setup("guard" if i < 2 else "police", i)
		ch.position = focus + Vector3(-9 + i * 2.0, C.CURB, -10 + i)
		ch.rotation.y = .9
		ch.play("aim" if i == 0 else "idle", 0.0, 1.0, i * .7)



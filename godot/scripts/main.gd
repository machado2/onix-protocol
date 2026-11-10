## Cena principal da fatia visual: gera um distrito, monta a cidade, ambiente noturno e câmera isométrica.
## Argumentos (depois de --): --seed=N --riq=0.6 --cam=x,z,dist,yaw,pitch,fov (metros e graus)
extends Node3D

var cam: Camera3D

func _ready() -> void:
	var seed := 4242
	var riq := .6
	var camv := [84.0, 96.0, 70.0, 45.0, 42.0, 30.0]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed = int(a.substr(7))
		elif a.begins_with("--riq="):
			riq = float(a.substr(6))
		elif a.begins_with("--cam="):
			var p := a.substr(6).split(",")
			for i in p.size():
				camv[i] = float(p[i])
	_environment()
	var map := CityGen.generate(seed, riq, 1)
	if "--list" in OS.get_cmdline_user_args():
		for b in map.blds:
			if b.fl >= 5:
				print("BLD x=%d y=%d w=%d d=%d fl=%d" % [b.x * 3, b.y * 3, b.w, b.d, b.fl])
	var city := CityBuilder.new()
	city.name = "Cidade"
	city.focus = Vector3(camv[0], 0, camv[1])
	add_child(city)
	city.build(map)
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
	var env := Environment.new()
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
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--off="):
			for k in a.substr(6).split(","):
				match k:
					"fog": env.volumetric_fog_enabled = false
					"ssr": env.ssr_enabled = false
					"ssil": env.ssil_enabled = false
					"ssao": env.ssao_enabled = false
					"glow": env.glow_enabled = false
					"shadows": get_tree().set_meta("noshadow", true)
					"moon": get_tree().set_meta("nomoon", true)
	# níveis de qualidade: low (placas de entrada), medium (GTX 1650 a 60 fps), high (tudo ligado)
	var q := "high"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			q = a.substr(10)
	var vp := get_viewport()
	match q:
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
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#9fb4ff")
	moon.light_energy = .45
	moon.rotation_degrees = Vector3(-55, 30, 0)
	moon.shadow_enabled = not get_tree().has_meta("nomoon")
	moon.directional_shadow_max_distance = 220.0
	moon.light_volumetric_fog_energy = .4
	add_child(moon)


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


func _process(dt: float) -> void:
	for w in walkers:
		w[0].position += w[1] * dt

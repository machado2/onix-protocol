## Efeitos da partida: traçantes, clarão do cano, explosões com luz e fumaça, sangue no chão, pulso da sonda
## neural, marcas de ordem e conversão de seguidores. Tudo com pools para não criar nós a cada tiro.
class_name GameFX
extends Node3D

const W := C.TILE
var game
var tracers: Array = []       # [MeshInstance3D, vida]
var flashes: Array = []       # [OmniLight3D, vida, máx]
var rings: Array = []         # [MeshInstance3D, vida, máx, raio final]
var booms: Array = []         # [Node3D, vida]
var decals: Array[Decal] = []
var mat_tr_p: StandardMaterial3D
var mat_tr_e: StandardMaterial3D
var mat_beam: StandardMaterial3D
var blood_tex: ImageTexture
var scorch_tex: ImageTexture
var smoke_mat: StandardMaterial3D


func _emat(c: Color, k: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = k
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func setup(g) -> void:
	game = g
	mat_tr_p = _emat(Color(1, .9, .6, .9), 6)
	mat_tr_e = _emat(Color(1, .6, .35, .9), 6)
	mat_beam = _emat(Color(1, .25, .5, .95), 10)
	blood_tex = _splat(Color(.28, .01, .02, .92), 7)
	scorch_tex = _splat(Color(.02, .02, .02, .85), 3)
	smoke_mat = StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(.12, .12, .14, .6)
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL


func _splat(c: Color, blobs: int) -> ImageTexture:
	var S := 128
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var r := RandomNumberGenerator.new()
	r.seed = blobs * 31
	var centers := []
	for k in blobs:
		centers.append([Vector2(S / 2.0, S / 2.0) + Vector2(r.randf_range(-30, 30), r.randf_range(-30, 30)) * (0.0 if k == 0 else 1.0), r.randf_range(10, 34)])
	for y in S:
		for x in S:
			var a := 0.0
			for cc in centers:
				var d: float = Vector2(x, y).distance_to(cc[0]) / cc[1]
				a = maxf(a, clampf(1.4 - d, 0, 1))
			img.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * smoothstep(0, .4, a)))
	return ImageTexture.create_from_image(img)


func _pos(x: float, y: float, h: float) -> Vector3:
	return Vector3(x * W, h, y * W)


func event(kind: String, d: Dictionary) -> void:
	match kind:
		"tracer":
			_tracer(_pos(d.x1, d.y1, 1.35), _pos(d.x2, d.y2, 1.2 if d.get("hit", false) else 1.3), d.beam, d.player)
		"muzzle":
			_flash(_pos(d.x, d.y, 1.35), Color(1, .3, .55) if d.laser else Color(1, .75, .4), 2.5, 5.0, .06)
		"explosion":
			_explosion(_pos(d.x, d.y, 0), d.r * W)
		"blood":
			_decal(_pos(d.x + randf_range(-.15, .15), d.y + randf_range(-.15, .15), game.ground_at(d.x, d.y)), blood_tex, randf_range(.6, 1.2))
		"death":
			var u: Unit = d.u
			_decal(_pos(u.x, u.y, game.ground_at(u.x, u.y)), blood_tex, 1.8)
		"pulse":
			_ring(_pos(d.x, d.y, .2), d.r * W, Color(.2, .75, 1), .75)
		"mark":
			_ring(_pos(d.x, d.y, .2), 1.2, d.col, .45)
		"convert":
			var u: Unit = d.u
			_ring(_pos(u.x, u.y, .2), 2.2, Color(.3, .9, 1), .6)
			_flash(_pos(u.x, u.y, 1.5), Color(.3, .9, 1), 4, 6, .4)
		"hack":
			_ring(_pos(d.x, d.y, .2), 3.0, Color(.3, 1, .6), .8)


func _tracer(a: Vector3, b: Vector3, beam: bool, player: bool) -> void:
	var m: MeshInstance3D
	if tracers.size() < 80:
		m = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1, 1, 1)
		m.mesh = bm
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
	else:
		var old = tracers.pop_front()
		m = old[0]
	var L := a.distance_to(b)
	if L < .05:
		m.visible = false
		return
	var th := .07 if beam else .025
	m.material_override = mat_beam if beam else (mat_tr_p if player else mat_tr_e)
	m.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP).scaled(Vector3(th, th, L)), (a + b) / 2)
	m.visible = true
	tracers.append([m, .3 if beam else .06])


func _flash(p: Vector3, c: Color, e: float, r: float, life: float) -> void:
	var l: OmniLight3D
	if flashes.size() < 24:
		l = OmniLight3D.new()
		l.shadow_enabled = false
		add_child(l)
	else:
		var old = flashes.pop_front()
		l = old[0]
	l.position = p
	l.light_color = c
	l.light_energy = e
	l.omni_range = r
	l.visible = true
	flashes.append([l, life, life, e])


func _ring(p: Vector3, r: float, c: Color, life: float) -> void:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = .9
	t.outer_radius = 1.0
	t.rings = 40
	t.ring_segments = 4
	m.mesh = t
	m.material_override = _emat(c, 4)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = p
	m.scale = Vector3(.05, .05, .05)
	add_child(m)
	rings.append([m, life, life, r])


func _explosion(p: Vector3, r: float) -> void:
	_flash(p + Vector3(0, 1.5, 0), Color(1, .55, .2), 40, r * 2.5, .6)
	var n := Node3D.new()
	n.position = p
	add_child(n)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1
	sm.height = 2
	ball.mesh = sm
	ball.material_override = _emat(Color(1, .6, .25, .9), 8)
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ball)
	var parts := GPUParticles3D.new()
	parts.amount = 40
	parts.lifetime = 2.2
	parts.one_shot = true
	parts.explosiveness = .9
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70
	pm.initial_velocity_min = 2
	pm.initial_velocity_max = 7
	pm.gravity = Vector3(0, .8, 0)
	pm.damping_min = 2
	pm.damping_max = 4
	pm.scale_min = 1.2
	pm.scale_max = 2.6
	var curve := CurveTexture.new()
	var cv := Curve.new()
	cv.add_point(Vector2(0, .3))
	cv.add_point(Vector2(1, 1))
	curve.curve = cv
	pm.scale_curve = curve
	parts.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	var smm := smoke_mat.duplicate()
	smm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smm.vertex_color_use_as_albedo = true
	qm.material = smm
	parts.draw_pass_1 = qm
	parts.position.y = 1
	n.add_child(parts)
	parts.emitting = true
	booms.append([n, 2.5, ball, r])
	_decal(p, scorch_tex, r * 1.4)


func _decal(p: Vector3, tex: Texture2D, size: float) -> void:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = Vector3(size, .6, size)
	d.position = p + Vector3(0, .1, 0)
	d.rotation.y = randf() * TAU
	d.cull_mask = 1
	add_child(d)
	decals.append(d)
	if decals.size() > 120:
		decals.pop_front().queue_free()


func tick(dt: float) -> void:
	for i in range(tracers.size() - 1, -1, -1):
		tracers[i][1] -= dt
		if tracers[i][1] <= 0:
			tracers[i][0].visible = false
	for f in flashes:
		f[1] -= dt
		var l: OmniLight3D = f[0]
		l.visible = f[1] > 0
		l.light_energy = f[3] * maxf(0, f[1] / f[2])
	for i in range(rings.size() - 1, -1, -1):
		var r = rings[i]
		r[1] -= dt
		var k: float = 1 - r[1] / r[2]
		var m: MeshInstance3D = r[0]
		m.scale = Vector3.ONE * maxf(.05, r[3] * k)
		m.material_override.albedo_color.a = 1 - k
		m.material_override.emission_energy_multiplier = 4 * (1 - k)
		if r[1] <= 0:
			m.queue_free()
			rings.remove_at(i)
	for i in range(booms.size() - 1, -1, -1):
		var b = booms[i]
		b[1] -= dt
		var ball: MeshInstance3D = b[2]
		var age: float = 2.5 - b[1]
		ball.visible = age < .45
		ball.scale = Vector3.ONE * b[3] * .8 * minf(1, age / .25 + .2)
		ball.material_override.albedo_color.a = maxf(0, 1 - age / .45)
		if b[1] <= 0:
			b[0].queue_free()
			booms.remove_at(i)

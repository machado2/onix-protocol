## Retratos dos agentes e dos Ponteiros, renderizados dos próprios modelos 3D num mundo à parte.
## Autoload "Portraits": tex(kind, seed) devolve na hora uma textura que é preenchida assim que o retrato fica pronto.
extends Node

const SIZE := Vector2i(240, 300)
const RIVAL_SEED := {navalha = 10, sibila = 11, ferro = 12, mariposa = 13, juiz = 14}

var cache := {}
var queue: Array = []
var busy := false
var vp: SubViewport
var stage: Node3D
var yaw := -PI / 2 + .45   # o idle olha para -X; um pouco de três quartos
var cam: Camera3D


## Teste: --portraittest=pasta grava o mesmo retrato em quatro rotações.
func test(dir: String) -> void:
	for k in 4:
		yaw = -PI / 2 + .45 + (k - 1) * .3
		cache.clear()
		var t := tex("agent", 1)
		while busy:
			await get_tree().process_frame
		t.get_image().save_png(dir.path_join("rot%d.png" % k))
	print("PORTRAITS OK")
	get_tree().quit()


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	vp = SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#3a4660")
	env.ambient_light_energy = .9
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.3
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffe2c4")
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-25, 35, 0)
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("#4fd8ff")
	rim.light_energy = 2.2
	rim.rotation_degrees = Vector3(-10, 160, 0)
	vp.add_child(rim)
	cam = Camera3D.new()
	cam.fov = 21
	cam.position = Vector3(0, 1.6, 1.25)
	vp.add_child(cam)
	cam.look_at(Vector3(0, 1.52, 0))
	cam.current = true
	stage = Node3D.new()
	vp.add_child(stage)


func agent(a: Dictionary) -> Texture2D:
	return tex("agent", int(a.id))


func rival(id: String) -> Texture2D:
	return tex("enemy", RIVAL_SEED.get(id, 10))


func tex(kind: String, seed: int) -> Texture2D:
	var k := "%s_%d" % [kind, seed]
	if cache.has(k):
		return cache[k]
	var img := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var t := ImageTexture.create_from_image(img)
	cache[k] = t
	if vp:
		queue.append([kind, seed, t])
		if not busy:
			_run()
	return t


func _run() -> void:
	busy = true
	while not queue.is_empty():
		var q: Array = queue.pop_front()
		var ch := Character3D.new()
		stage.add_child(ch)
		ch.setup(q[0], q[1])
		ch.rotation.y = yaw
		ch.set_weapon_visible(false)
		ch.play("idle", 0.0, 1.0, .4)
		await get_tree().process_frame
		ch.anim.speed_scale = 0.0
		var sk: Skeleton3D = ch.find_child("*", true, false) as Skeleton3D
		for n in ch.find_children("*", "Skeleton3D", true, false):
			sk = n
			break
		var head := Vector3(0, 1.6, 0)
		if sk:
			var bi := sk.find_bone("head")
			if bi >= 0:
				head = sk.global_transform * sk.get_bone_global_pose(bi).origin + Vector3(0, .06, 0)
		cam.position = head + Vector3(0, .05, 1.3)
		cam.look_at(head - Vector3(0, .1, 0))
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		(q[2] as ImageTexture).update(img)
		ch.queue_free()
		await get_tree().process_frame
	busy = false

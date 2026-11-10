## Personagem 3D: humano do MPFB2 (assets/chars/<variante>.glb) com animações de mocap do CMU.
## Tipos: agent, guard, police, civil, vip, scientist. Equipamento (sobretudo, colete, capacete, armas) usa o shader de roupa,
## com as cores por instância; as roupas do MakeHuman podem ser tingidas por tipo.
class_name Character3D
extends Node3D

const VARIANTS := {
	agent = ["agent_m", "agent_f"], enemy = ["agent_m", "agent_f"], guard = ["guard"], police = ["police"], vip = ["vip"], scientist = ["scientist"],
	civil = ["civ_m1", "civ_m2", "civ_m3", "civ_f1", "civ_f2", "civ_f3"],
}
const LOOPS := ["idle", "walk", "run", "panic", "crouch", "sneak", "type", "idle_gun", "walk_gun", "run_gun", "aim", "aim_walk", "crouch_gun"]
const ARMED := ["agent", "enemy", "guard", "police"]
# tingimento das roupas do MakeHuman por tipo (multiplica a textura)
const CLOTH_TINT := {agent = Color(.32, .33, .36), enemy = Color(.3, .2, .22), guard = Color(.38, .4, .44), police = Color(.45, .5, .7)}

static var _scenes := {}
static var _meta := {}
static var _mats := {}

var model: Node3D
var anim: AnimationPlayer
var kind := "civil"
var variant := ""
var current := ""
var speeds := {}
var armed_now := true
var ring: MeshInstance3D


static func _scene(v: String) -> PackedScene:
	if not _scenes.has(v):
		_scenes[v] = load("res://assets/chars/%s.glb" % v)
		var f := FileAccess.open("res://assets/chars/%s.json" % v, FileAccess.READ)
		_meta[v] = JSON.parse_string(f.get_as_text()) if f else {}
	return _scenes[v]


static func _mat(slot: int, rough: float, sheen := 0.0, metal := 0.0) -> ShaderMaterial:
	var key := "%d_%f_%f_%f" % [slot, rough, sheen, metal]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/cloth.gdshader")
		m.set_shader_parameter("slot", slot)
		m.set_shader_parameter("rough", rough)
		m.set_shader_parameter("sheen", sheen)
		m.set_shader_parameter("metal", metal)
		m.set_shader_parameter("grime", load("res://assets/tex/grime.png"))
		_mats[key] = m
	return _mats[key]


static func _gear_material(name: String) -> Material:
	match name:
		"coat": return _mat(4, .42, .3)
		"belt": return _mat(7, .4, 0.0, .3)
		"vest": return _mat(1, .7)
		"vest_pouch": return _mat(7, .75)
		"helmet": return _mat(1, .35, .1, .2)
		"cap": return _mat(1, .8)
		"cap_brim": return _mat(7, .5)
		"badge": return _mat(6, .3, 0.0, .9)
		"gun": return _mat(7, .35, 0.0, .7)
		"gun_grip": return _mat(7, .7)
		"visor":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(.02, .02, .02)
			m.emission_enabled = true
			m.emission = Color(.2, .9, 1.0)
			m.emission_energy_multiplier = 5.0
			m.roughness = .1
			return m
	return _mat(7, .6)


func setup(k: String, seed: int) -> void:
	kind = k
	var vs: Array = VARIANTS.get(k, VARIANTS.civil)
	variant = vs[seed % vs.size()]
	model = _scene(variant).instantiate()
	add_child(model)
	speeds = _meta[variant].get("speed", {})
	anim = model.find_child("AnimationPlayer", true, false)
	for a in LOOPS:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var r := C.Rng.new(seed * 7 + 13)
	var cols := {c_coat = Color("#121318"), c_top = Color("#2b2f38"), c_accent = Color("#38e8ff")}
	if k == "guard":
		cols.c_top = Color("#2b2f38")
		cols.c_accent = Color("#ff3d5a")
	elif k == "enemy":
		cols.c_coat = Color("#24090f")
		cols.c_accent = Color("#ff2e4d")
	elif k == "police":
		cols.c_top = Color("#1e2a44")
		cols.c_accent = Color("#d8b040")
	var tint: Color = CLOTH_TINT.get(k, Color.WHITE)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.layers = 2   # camada dos atores: decais do chão (sangue, pintura) não os pintam
		var nm := String(mi.name)
		var gear := nm.begins_with("gear_")
		for i in mi.mesh.get_surface_count():
			var sm: Material = mi.mesh.surface_get_material(i)
			if gear:
				mi.set_surface_override_material(i, _gear_material(sm.resource_name if sm else ""))
			elif sm is BaseMaterial3D:
				var m: BaseMaterial3D = sm.duplicate()
				var low := nm.to_lower()
				var is_hair := low.contains("hair") or low.contains("short0") or low.contains("long0") or low.contains("bob") or low.contains("ponytail") or low.contains("afro") or low.contains("eyebrow") or low.contains("eyelash")
				if is_hair:
					m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					m.alpha_scissor_threshold = .45
					m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
					m.cull_mode = BaseMaterial3D.CULL_DISABLED
				else:
					m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					if tint != Color.WHITE and not (low.contains("generic") or low.contains("low-poly") or low.contains("body")):
						m.albedo_color = m.albedo_color * tint
				if low.contains("generic"):
					m.roughness = .55
					m.subsurf_scatter_enabled = true
					m.subsurf_scatter_strength = .35
				if is_hair:
					m.roughness = .6
					m.metallic_specular = .3
				mi.set_surface_override_material(i, m)
		if gear:
			for c in cols:
				mi.set_instance_shader_parameter(c, cols[c])


func armed() -> bool:
	return kind in ARMED and armed_now


func set_weapon_visible(on: bool) -> void:
	for n in ["gear_rifle", "gear_pistol"]:
		var m := model.find_child(n, true, false)
		if m:
			m.visible = on


var cloaked := false

## Manto óptico: o corpo fica quase transparente (o anel de seleção continua visível).
func set_cloak(on: bool) -> void:
	if on == cloaked:
		return
	cloaked = on
	for m in model.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).transparency = .82 if on else 0.0


func set_selected(on: bool) -> void:
	if on and ring == null:
		ring = MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = .42
		t.outer_radius = .5
		t.rings = 24
		t.ring_segments = 6
		ring.mesh = t
		ring.scale = Vector3(1, .05, 1)
		ring.position.y = .03
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(.3, .95, 1.0)
		m.emission_enabled = true
		m.emission = Color(.3, .95, 1.0)
		m.emission_energy_multiplier = 2.0
		ring.material_override = m
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
	if ring:
		ring.visible = on


## Toca uma animação; personagens armados usam a versão com arma quando existe.
func play(a: String, blend := .25, speed := 1.0, offset := 0.0) -> void:
	if armed() and anim.has_animation(a + "_gun"):
		a = a + "_gun"
	if a == current or not anim.has_animation(a):
		return
	current = a
	anim.play(a, blend, speed)
	if a.begins_with("die"):
		anim.get_animation(a).loop_mode = Animation.LOOP_NONE
	if offset > 0.0:
		anim.seek(fmod(offset, anim.current_animation_length), true)


## Velocidade natural do clipe (m/s), para casar o passo com o deslocamento.
func clip_speed(a: String) -> float:
	return float(speeds.get(a, 0.0))

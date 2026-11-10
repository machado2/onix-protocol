## Áudio (porte de v2/js/audio.js). Autoload "Snd".
## Efeitos: WAVs gerados por tools/sfxgen/sfxgen.py, com variações, tocados em 3D a partir de um pool.
## Trilha: seis camadas em loop sincronizado (AudioStreamSynchronized) que entram e saem pela intensidade
## (0 menu, 1 discrição, 2 alerta, 3 combate). Ambiente: tráfego e zumbido em loop com trovões, sirenes e
## buzinas distantes de vez em quando (sem chuva). Vozes passam por barramentos de rádio, capacete ou megafone.
extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const CFG := "user://config.cfg"
const ORDER := ["pad", "bass", "arp", "hat", "kick", "snare"]
const LAYERS := {pad = [.5, .45, .38, .3], bass = [0.0, .55, .75, .9], arp = [.28, .22, .45, .6], hat = [0.0, 0.0, .45, .75], kick = [0.0, 0.0, .5, .9], snare = [0.0, 0.0, 0.0, .7]}
const GAP := {smg = .035, hit = .06, flame = .09, ric = .05, die = .08}

var vol := {mus = .6, sfx = 1.0, vo = 1.0}
var streams := {}
var last := {}
var pool3: Array[AudioStreamPlayer3D] = []
var pool2: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var sync: AudioStreamSynchronized
var gain := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var intensity := 0
var rising := true
var amb: AudioStreamPlayer
var amb_t := 14.0
var engine_p: AudioStreamPlayer3D
var duck := false
var duck_g := 1.0
var muted := false
var rec: AudioEffectRecord
var rec_path := ""
var stats := {}


func _exit_tree() -> void:
	if rec and rec.is_recording_active():
		var w := rec.get_recording()
		rec.set_recording_active(false)
		if w:
			w.save_to_wav(rec_path)
			print("AUDIO ", rec_path, " %.1fs" % w.get_length(), " ", stats)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_buses()
	var cfg := ConfigFile.new()
	if cfg.load(CFG) == OK:
		for k in vol:
			vol[k] = cfg.get_value("audio", k, vol[k])
	muted = "--mute" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--recaudio="):
			rec_path = a.substr(11)
			rec = AudioEffectRecord.new()
			AudioServer.add_bus_effect(0, rec, 0)
			rec.set_recording_active(true)
	AudioServer.set_bus_mute(0, muted)
	_apply()
	_start_music()
	_start_amb()
	engine_p = AudioStreamPlayer3D.new()
	_cfg3(engine_p)
	engine_p.stream = _loop(load("res://assets/audio/engine_loop.wav")) if ResourceLoader.exists("res://assets/audio/engine_loop.wav") else null
	engine_p.volume_db = -80
	add_child(engine_p)


# ---------------------------------------------------------------- barramentos
func _bus(name: String, effects: Array) -> void:
	if AudioServer.get_bus_index(name) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, name)
	AudioServer.set_bus_send(i, "Master")
	for e in effects:
		AudioServer.add_bus_effect(i, e)


func _hp(f: float) -> AudioEffectHighPassFilter:
	var e := AudioEffectHighPassFilter.new()
	e.cutoff_hz = f
	return e


func _lp(f: float) -> AudioEffectLowPassFilter:
	var e := AudioEffectLowPassFilter.new()
	e.cutoff_hz = f
	return e


func _dist(drive: float) -> AudioEffectDistortion:
	var e := AudioEffectDistortion.new()
	e.mode = AudioEffectDistortion.MODE_ATAN
	e.drive = drive
	e.post_gain = -4.0
	return e


func _buses() -> void:
	if AudioServer.get_bus_effect_count(0) == 0:
		var c := AudioEffectCompressor.new()
		c.threshold = -14
		c.ratio = 4
		c.attack_us = 3000
		c.release_ms = 250
		AudioServer.add_bus_effect(0, c)
		AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())
	_bus("SFX", [])
	_bus("Music", [])
	_bus("Amb", [])
	_bus("Radio", [_hp(380), _lp(3400), _dist(.3)])
	var bp := AudioEffectBandPassFilter.new()
	bp.cutoff_hz = 1500
	bp.resonance = .6
	_bus("Mega", [bp, _dist(.55), _lp(3800)])
	_bus("Helmet", [_hp(300), _lp(2500), _dist(.4)])


func _apply() -> void:
	var lin := func(v: float) -> float: return linear_to_db(maxf(v, .0001))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), lin.call(vol.sfx * .9))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Amb"), lin.call(vol.sfx * .8))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), lin.call(vol.mus * .55 * duck_g))
	for b in ["Radio", "Mega", "Helmet"]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(b), lin.call(vol.vo * 1.15))


func set_volume(k: String, v: float) -> void:
	vol[k] = clampf(v, 0, 1)
	_apply()
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value("audio", k, vol[k])
	cfg.save(CFG)


# ---------------------------------------------------------------- efeitos
func _variants(kind: String) -> Array:
	if streams.has(kind):
		return streams[kind]
	var l := []
	var i := 0
	while ResourceLoader.exists(SFX_DIR + "%s_%d.wav" % [kind, i]):
		l.append(load(SFX_DIR + "%s_%d.wav" % [kind, i]))
		i += 1
	streams[kind] = l
	return l


func _cfg3(p: AudioStreamPlayer3D) -> void:
	p.bus = "SFX"
	p.unit_size = 16.0
	p.max_distance = 120.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.attenuation_filter_cutoff_hz = 6000.0
	p.attenuation_filter_db = -16.0
	p.panning_strength = 1.3
	p.max_db = 4.0


func _player3() -> AudioStreamPlayer3D:
	for p in pool3:
		if not p.playing:
			return p
	if pool3.size() < 48:
		var p := AudioStreamPlayer3D.new()
		_cfg3(p)
		add_child(p)
		pool3.append(p)
		return p
	var o: AudioStreamPlayer3D = pool3.pop_front()
	pool3.append(o)
	return o


func _player2() -> AudioStreamPlayer:
	for p in pool2:
		if not p.playing:
			return p
	var p := AudioStreamPlayer.new()
	add_child(p)
	pool2.append(p)
	return p


## Toca um efeito; com pos (Vector3, em metros) ele soa no mundo, senão é de interface.
func play(kind: String, pos = null, db := 0.0, pitch := 1.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - last.get(kind, -9.0) < GAP.get(kind, .03):
		return
	last[kind] = now
	var v := _variants(kind)
	if v.is_empty():
		return
	var s: AudioStream = v[randi() % v.size()]
	stats[kind] = stats.get(kind, 0) + 1
	if pos is Vector3:
		var p := _player3()
		p.bus = "SFX"
		p.global_position = pos
		p.stream = s
		p.volume_db = db
		p.pitch_scale = pitch * randf_range(.96, 1.04)
		p.play()
	else:
		var p := _player2()
		p.bus = "SFX"
		p.stream = s
		p.volume_db = db
		p.pitch_scale = pitch
		p.play()


## Voz: rádio do esquadrão (sem posição) ou voz no mundo (capacete, megafone) com posição.
func voice(stream: AudioStream, bus: String, pos = null, pitch := 1.0) -> Node:
	if pos is Vector3:
		var p := _player3()
		p.bus = bus
		p.global_position = pos
		p.stream = stream
		p.volume_db = 2.0
		p.pitch_scale = pitch
		p.play()
		return p
	var q := _player2()
	q.bus = bus
	q.stream = stream
	q.volume_db = 0.0
	q.pitch_scale = pitch
	q.play()
	if bus == "Radio":
		play("squelch")
	return q


## Motor do carro em movimento mais próximo (speed em tiles/s; 0 desliga).
func engine(speed: float, pos = null) -> void:
	if engine_p.stream == null:
		return
	if speed <= .2 or not (pos is Vector3):
		engine_p.volume_db = move_toward(engine_p.volume_db, -60, 3)
		if engine_p.volume_db <= -59 and engine_p.playing:
			engine_p.stop()
		return
	if not engine_p.playing:
		engine_p.play()
	engine_p.global_position = pos
	engine_p.pitch_scale = (38 + speed * 9) / 40.0
	engine_p.volume_db = linear_to_db(.25 + speed * .05)


# ---------------------------------------------------------------- trilha e ambiente
func _loop(s: AudioStream) -> AudioStream:
	if s is AudioStreamWAV:
		var w: AudioStreamWAV = s
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	return s


func _start_music() -> void:
	sync = AudioStreamSynchronized.new()
	sync.stream_count = ORDER.size()
	for i in ORDER.size():
		var path := "res://assets/audio/mus_%s.wav" % ORDER[i]
		if not ResourceLoader.exists(path):
			return
		sync.set_sync_stream(i, _loop(load(path)))
		sync.set_sync_stream_volume(i, -80)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.stream = sync
	add_child(music)
	music.play()


func set_intensity(i: int) -> void:
	if i != intensity:
		rising = i > intensity
		intensity = i


func _start_amb() -> void:
	if not ResourceLoader.exists("res://assets/audio/amb_loop.wav"):
		return
	amb = AudioStreamPlayer.new()
	amb.bus = "Amb"
	amb.stream = _loop(load("res://assets/audio/amb_loop.wav"))
	amb.volume_db = -3
	add_child(amb)
	amb.play()


func _process(dt: float) -> void:
	if sync and music:
		var k := 1.0 - exp(-dt / (.4 if rising else 1.6))
		for i in ORDER.size():
			var target: float = LAYERS[ORDER[i]][intensity]
			gain[i] = lerpf(gain[i], target, k)
			sync.set_sync_stream_volume(i, linear_to_db(maxf(gain[i], .0001)))
	var dg := .4 if duck else 1.0
	if absf(duck_g - dg) > .01:
		duck_g = lerpf(duck_g, dg, 1.0 - exp(-dt / (.05 if duck else .4)))
		_apply()
	amb_t -= dt
	if amb_t <= 0:
		amb_t = 25 + randf() * 40
		var r := randf()
		var p := _player2()
		p.bus = "Amb"
		var v := _variants("amb_thunder" if r < .35 else ("amb_siren" if r < .7 else "amb_horn"))
		if not v.is_empty():
			p.stream = v[randi() % v.size()]
			p.volume_db = -6
			p.pitch_scale = 1.0
			p.play()

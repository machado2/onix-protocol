## Captura de tela para testes automáticos: godot --path godot -- --shot=arquivo.png [--frames=120]
## Também mede o tempo de GPU médio dos últimos quadros e imprime no console.
extends Node

var path := ""
var target := 120
var frames := 0
var gpu_sum := 0.0
var cpu_sum := 0.0
var n := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.substr(7)
		elif a.begins_with("--frames="):
			target = int(a.substr(9))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)

func _process(_dt: float) -> void:
	if path == "":
		return
	frames += 1
	if frames > target - 40:
		var rid := get_viewport().get_viewport_rid()
		gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
		n += 1
	if frames == target:
		var img := get_viewport().get_texture().get_image()
		if path.ends_with(".jpg"):
			img.save_jpg(path, 0.9)
		else:
			img.save_png(path)
		print("SHOT %s gpu=%.2fms cpu=%.2fms fps=%d draws=%d prims=%d" % [path, gpu_sum / n, cpu_sum / n, Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		get_tree().quit()

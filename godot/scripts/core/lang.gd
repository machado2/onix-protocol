## Idioma (autoload "Lang"): português por padrão ou inglês, salvo em user://config.cfg.
## --lang=en força o inglês; --i18nmiss=arquivo grava, ao sair, as frases em português que ficaram sem tradução.
extends Node

const CFG := "user://config.cfg"
var lang := "pt"
var en: Translation
var miss_path := ""
var registered := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG) == OK:
		lang = cfg.get_value("ui", "lang", "pt")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			lang = a.substr(7)
		elif a.begins_with("--i18nmiss="):
			miss_path = a.substr(11)
	en = load("res://scripts/core/i18n_en.gd").new()
	_apply()


## A tradução inglesa só fica registrada no modo inglês: sem ela, o TranslationServer não teria para onde
## cair (o idioma reserva do Godot é o inglês) e o português apareceria traduzido.
func _apply() -> void:
	if lang == "en":
		if not registered:
			TranslationServer.add_translation(en)
			registered = true
		TranslationServer.set_locale("en")
	else:
		if registered:
			TranslationServer.remove_translation(en)
			registered = false
		TranslationServer.set_locale("pt_BR")


func set_lang(l: String) -> void:
	lang = l
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value("ui", "lang", l)
	cfg.save(CFG)
	_apply()


func is_en() -> bool:
	return lang == "en"


## Pasta e roteiro das falas gravadas no idioma atual.
func vo_dir() -> String:
	return "res://assets/audio/vo_en/" if is_en() else "res://assets/audio/vo/"


func vo_json() -> String:
	return "res://assets/audio/vo_en.json" if is_en() else "res://assets/audio/vo.json"


func _exit_tree() -> void:
	if miss_path != "" and en:
		var f := FileAccess.open(miss_path, FileAccess.WRITE)
		if f:
			var keys: Array = en.miss.keys()
			keys.sort()
			f.store_string("\n".join(keys))
			print("I18N MISS ", keys.size())
	# a tradução é um script: tirá-la do servidor antes que o GDScript seja desligado (senão o jogo cai ao fechar)
	if registered:
		TranslationServer.remove_translation(en)
		registered = false
	en = null

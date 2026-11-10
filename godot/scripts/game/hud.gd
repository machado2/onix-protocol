## HUD da partida: objetivo e estado de alerta, cartões dos agentes (vida, arma, munição), inventário do agente
## selecionado (F1–F6), registro de mensagens, retângulo de seleção, rótulo da unidade sob o mouse e o fim de missão.
class_name GameHUD
extends CanvasLayer

const CYAN := Color("#4fd8ff")
const COLS := {"red": Color("#ff5a6a"), "green": Color("#6dff9a"), "amber": Color("#ffb13d"), "cyan": Color("#4fd8ff"), "": Color("#d6dbe4")}

var game
var top: Label
var status: Label
var cards: HBoxContainer
var inv: HBoxContainer
var logbox: VBoxContainer
var box: Panel
var tip: Label
var banner: PanelContainer
var lines: Array = []
var sub: Label
var objlist: VBoxContainer
var timer_lbl: Label
var bars: Array = []
var tp_panel: PanelContainer
var font: Font
var card_nodes: Array = []
var inv_sig := ""


func _panel_style(alpha := .72) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(.03, .05, .08, alpha)
	s.border_color = Color(.3, .85, 1, .35)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _label(txt: String, size := 15, col := Color("#d6dbe4")) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


func setup(g) -> void:
	game = g
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# topo: objetivo e estado
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", _panel_style())
	tp.position = Vector2(16, 14)
	tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tv := VBoxContainer.new()
	tp.add_child(tv)
	top = _label("", 17, Color("#eef3fa"))
	status = _label("", 14, CYAN)
	tv.add_child(_label("PROTOCOLO ÔNIX · " + GD.TIPOS[game.M.tipo].to_upper(), 12, Color(.55, .85, 1, .8)))
	tv.add_child(top)
	objlist = VBoxContainer.new()
	tv.add_child(objlist)
	tv.add_child(status)
	root.add_child(tp)
	tp_panel = tp
	timer_lbl = _label("", 26, Color("#ffb13d"))
	timer_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_lbl.offset_top = 14
	timer_lbl.offset_left = -200
	timer_lbl.offset_right = 200
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(timer_lbl)
	# faixas de cinema e legenda
	for k in 2:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, .92)
		bar.anchor_right = 1
		if k == 0:
			bar.offset_bottom = 90
		else:
			bar.anchor_top = 1
			bar.anchor_bottom = 1
			bar.offset_top = -90
		bar.visible = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bar)
		bars.append(bar)
	sub = _label("", 22, Color("#f2f5fa"))
	sub.anchor_left = .15
	sub.anchor_right = .85
	sub.anchor_top = 1
	sub.anchor_bottom = 1
	sub.offset_top = -250
	sub.offset_bottom = -190
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(sub)
	# registro
	logbox = VBoxContainer.new()
	logbox.anchor_left = 1
	logbox.anchor_right = 1
	logbox.offset_left = -520
	logbox.offset_right = -16
	logbox.offset_top = 14
	logbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(logbox)
	# base: cartões e inventário
	var bottom := VBoxContainer.new()
	bottom.anchor_top = 1
	bottom.anchor_bottom = 1
	bottom.offset_top = -168
	bottom.offset_left = 16
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	inv = HBoxContainer.new()
	inv.add_theme_constant_override("separation", 6)
	bottom.add_child(inv)
	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	bottom.add_child(cards)
	for a in game.M.agents:
		var c := _card(a)
		cards.add_child(c)
		card_nodes.append(c)
	box = Panel.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(.3, .85, 1, .08)
	bs.border_color = Color(.3, .85, 1, .8)
	bs.set_border_width_all(1)
	box.add_theme_stylebox_override("panel", bs)
	box.visible = false
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	tip = _label("", 14, Color("#ffffff"))
	tip.visible = false
	root.add_child(tip)
	banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _panel_style(.85))
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.visible = false
	root.add_child(banner)


func _card(a: Unit) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(190, 74)
	b.focus_mode = Control.FOCUS_NONE
	var st := _panel_style(.7)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", st)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_top = 6
	v.offset_right = -10
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nm := _label("%d  %s" % [a.num, a.nome.to_upper()], 15, Color("#eef3fa"))
	nm.name = "nm"
	v.add_child(nm)
	var bar := ProgressBar.new()
	bar.name = "hp"
	bar.custom_minimum_size = Vector2(0, 8)
	bar.show_percentage = false
	bar.max_value = a.max_hp
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("#6dff9a")
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(.1, .12, .15)
	bar.add_theme_stylebox_override("fill", fg)
	bar.add_theme_stylebox_override("background", bg)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar)
	var wp := _label("", 13, CYAN)
	wp.name = "wp"
	v.add_child(wp)
	b.add_child(v)
	b.pressed.connect(func():
		if Input.is_key_pressed(KEY_SHIFT):
			var l: Array = game.M.sel.duplicate()
			if a in l: l.erase(a)
			else: l.append(a)
			game.sim.set_sel(l)
		else:
			game.sim.set_sel([a]))
	return b


func add_log(t: String, c: String) -> void:
	var l := _label(t, 14, COLS.get(c, COLS[""]))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size = Vector2(500, 0)
	logbox.add_child(l)
	lines.append([l, 9.0])
	while lines.size() > 7:
		lines.pop_front()[0].queue_free()


func set_box(r: Rect2) -> void:
	box.visible = r.size.length() > 2
	box.position = r.position
	box.size = r.size


func show_end(win: bool, reason: String) -> void:
	for c in banner.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := _label("OBJETIVO CUMPRIDO" if win else "MISSÃO FRACASSADA", 38, COLS.green if win else COLS.red)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var r := _label(reason, 18)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(r)
	var s: Dictionary = game.M.stats
	var st := _label("Abates: %d · civis: %d · policiais: %d · seguidores: %d" % [s.abates, s.civis, s.policiais, s.seguidores], 15, Color("#9fb0c4"))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	for b in game.M.bonus:
		var bl := _label("+ %s  $%d" % [b.text, b.val], 15, COLS.amber)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(bl)
	var h := _label("R para jogar de novo", 15, CYAN)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	banner.add_child(v)
	banner.visible = true
	banner.position = get_viewport().get_visible_rect().size / 2 - Vector2(320, 90)
	banner.custom_minimum_size = Vector2(640, 180)


func subtitle(t: String) -> void:
	sub.text = t


func refresh() -> void:
	var M: Mission = game.M
	if not game.talking():
		sub.text = ""
	var cine: bool = M.cine
	for b in bars:
		b.visible = cine
	cards.get_parent().visible = not cine
	tp_panel.visible = not cine
	logbox.visible = not cine
	sub.offset_top = -170 if cine else -250
	sub.offset_bottom = -110 if cine else -190
	if M.timer != null:
		var left := maxf(0, M.timer.end - M.t)
		timer_lbl.text = "%s  %d:%02d" % [M.timer.label.to_upper(), int(left) / 60, int(left) % 60]
		timer_lbl.visible = not cine
	else:
		timer_lbl.visible = false
	if M.hand:
		top.visible = false
		_refresh_objs(M)
	else:
		top.text = M.objective_text()
	var st := []
	if M.corp_alert:
		st.append("ALERTA DO CONSÓRCIO")
	if M.police_aggro > 0:
		st.append("POLÍCIA HOSTIL %ds" % int(M.police_aggro))
	if M.followers > 0:
		st.append("SEGUIDORES %d" % M.followers)
	if game.paused:
		st.append("PAUSADO (espaço)")
	status.text = "  ·  ".join(st) if not st.is_empty() else "Discrição: armas à mostra chamam atenção."
	status.add_theme_color_override("font_color", COLS.red if M.corp_alert or M.police_aggro > 0 else CYAN)
	for i in M.agents.size():
		var a: Unit = M.agents[i]
		var c: Button = card_nodes[i]
		var bar: ProgressBar = c.find_child("hp", true, false)
		bar.value = a.hp
		var wp: Label = c.find_child("wp", true, false)
		if a.dead:
			wp.text = "ABATIDO"
			c.modulate = Color(1, 1, 1, .4)
		else:
			var it = a.inv[a.eq] if a.eq >= 0 else null
			if it == null:
				wp.text = "arma guardada"
			else:
				var w: Dictionary = GD.WD[it.t]
				wp.text = w.ab + ("  %d/%d" % [it.mun, w.pente] if w.get("arma", false) else "") + ("  recarregando" if a.rel > 0 else "")
		var stl: StyleBoxFlat = c.get_theme_stylebox("normal")
		stl.border_color = Color(.3, .95, 1, .95) if a.sel else Color(.3, .85, 1, .25)
		stl.set_border_width_all(2 if a.sel else 1)
	_refresh_inv()
	for l in lines:
		l[1] -= get_process_delta_time()
		l[0].modulate.a = clampf(l[1] / 2.0, 0, 1)
	var h: Unit = game.hover
	if h and not h.dead:
		tip.visible = true
		tip.text = _label_for(h)
		tip.position = get_viewport().get_mouse_position() + Vector2(16, 12)
	else:
		tip.visible = false


var obj_sig := ""


func _refresh_objs(M: Mission) -> void:
	var sig := ""
	for o in M.objs:
		sig += "%s|%s|%s;" % [o.id, o.text, o.state]
	if sig == obj_sig:
		return
	obj_sig = sig
	for c in objlist.get_children():
		c.queue_free()
	for o in M.objs:
		var mark := "✓ " if o.state == "done" else ("✗ " if o.state == "failed" else ("▸ " if o.primary else "· "))
		var col := COLS.green if o.state == "done" else (COLS.red if o.state == "failed" else (Color("#eef3fa") if o.primary else Color("#9fb0c4")))
		objlist.add_child(_label(mark + o.text, 16 if o.primary else 14, col))


func _label_for(u: Unit) -> String:
	match u.kind:
		"agente": return "Agente " + u.nome
		"civil": return "Seguidor" if u.follower else "Civil"
		"policia": return "Seguidor (policial)" if u.follower else ("Policial (hostil)" if game.M.police_aggro > 0 else ("Policial (advertindo)" if u.warned else "Policial"))
		"guarda": return "Seguidor (segurança)" if u.follower else ("Segurança Hélice (alerta)" if u.alerted else "Segurança Hélice")
		"inimigo": return "Seguidor (agente)" if u.follower else ("Agente do Consórcio (caçando)" if u.alerted else "Agente do Consórcio")
		"vip": return ("Alvo ou sósia? (aproxime-se para escanear)" if u.cand and not u.scanned and u != game.M.vip else ("Sósia de " + u.nome if u.double else "ALVO: " + u.nome))
		"cientista": return u.nome
		"torre": return ("Pilar de escudo" if u.pylon else "Torreta automática") + (" (desligada)" if u.off else "")
		"drone": return "Drone de segurança" + (" (caçando)" if u.alerted else "")
	return ""


func _refresh_inv() -> void:
	var M: Mission = game.M
	var L: Unit = M.sel[0] if not M.sel.is_empty() else null
	var sig := ""
	if L:
		sig = "%d|%d|%s" % [L.id, L.eq, ",".join(L.inv.map(func(q): return q.t))]
	if sig == inv_sig:
		return
	inv_sig = sig
	for c in inv.get_children():
		c.queue_free()
	if L == null:
		inv.add_child(_label("Selecione um agente (1–4) ou arraste para selecionar o grupo.", 14))
		return
	for i in range(-1, L.inv.size()):
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		var on := L.eq == i
		var st := _panel_style(.75)
		if on:
			st.border_color = Color(.3, .95, 1, .95)
			st.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)
		b.add_theme_font_size_override("font_size", 13)
		if i < 0:
			b.text = "—\nGUARDADA (H)"
			b.pressed.connect(func(): game.sim.holster())
		else:
			var w: Dictionary = GD.WD[L.inv[i].t]
			var sub := "ARREMESSAR" if w.get("throw", false) else ("USAR" if w.get("heal", false) else ("SEQUESTRAR" if w.get("sonda", false) else ""))
			b.text = "%s\nF%d %s" % [w.ab, i + 1, sub]
			b.pressed.connect(func(): game.sim.use_slot(i))
		b.custom_minimum_size = Vector2(108, 46)
		inv.add_child(b)

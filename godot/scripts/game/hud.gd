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
var pause_open := false
var pause_panel: PanelContainer


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
	var th := Theme.new()
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	th.default_font = sf
	root.theme = th
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
	bottom.offset_top = -184
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
	cards.add_child(_neuro_panel())
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
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", _panel_style(.9))
	pause_panel.visible = false
	root.add_child(pause_panel)


# ---------------------------------------------------------------- mostradores neurais
var dials: Array = []
var neuro_title: Label
var neuro_stab: Label
var preset_btns: Array = []

func _neuro_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel_style(.7))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	neuro_title = _label("NEURAL", 11, Color(.55, .85, 1, .8))
	v.add_child(neuro_title)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	for k in [["r", "REF", "Reflexo: velocidade e cadência"], ["p", "PER", "Percepção: precisão e alcance"], ["c", "CTR", "Controle: discrição, resistência e sonda"]]:
		var d := NeuroDial.new()
		d.key = k[0]
		d.label = k[1]
		d.tooltip_text = k[2]
		d.hud = self
		h.add_child(d)
		dials.append(d)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 3)
	h.add_child(pv)
	for i in Sim.PRESETS.size():
		var b := Button.new()
		b.text = Sim.PRESETS[i].n
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 10)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(.04, .06, .1, .9)
		st.border_color = Color(.15, .2, .29)
		st.set_border_width_all(1)
		st.content_margin_left = 6
		st.content_margin_right = 6
		st.content_margin_top = 3
		st.content_margin_bottom = 3
		b.add_theme_stylebox_override("normal", st)
		var hv := st.duplicate()
		hv.border_color = CYAN
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", hv)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): game.sim.set_preset(i))
		b.tooltip_text = "Tecla F alterna as predefinições"
		pv.add_child(b)
		preset_btns.append(b)
	neuro_stab = _label("", 11, Color("#9fb0c4"))
	v.add_child(neuro_stab)
	return p


func _refresh_neuro() -> void:
	var M: Mission = game.M
	var L: Unit = M.sel[0] if not M.sel.is_empty() else null
	if L and L.dead:
		L = null
	for d in dials:
		d.value = L.nr[d.key] if L else 0.0
		d.locked = L == null or L.colapso > 0
		d.queue_redraw()
	neuro_title.text = "NEURAL · " + (L.nome.to_upper() if L else "—")
	var pi: int = game.sim.preset_of(L) if L else -1
	for i in preset_btns.size():
		preset_btns[i].add_theme_color_override("font_color", COLS.amber if i == pi else Color("#9fb0c4"))
	if L == null:
		neuro_stab.text = ""
	elif L.colapso > 0:
		neuro_stab.text = "COLAPSO %.0fs" % L.colapso
		neuro_stab.add_theme_color_override("font_color", COLS.red)
	else:
		neuro_stab.text = "ESTAB %d/%d" % [roundi(L.estab), roundi(L.max_estab)]
		neuro_stab.add_theme_color_override("font_color", COLS.amber if L.estab < L.max_estab * .35 else Color("#9fb0c4"))


## Mostrador vertical: arraste ou role a roda para ajustar o canal neural dos agentes selecionados.
class NeuroDial extends Control:
	var key := "r"
	var label := ""
	var value := .5
	var locked := false
	var hud

	func _init() -> void:
		custom_minimum_size = Vector2(30, 62)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_VSIZE

	func _draw() -> void:
		var h := size.y - 14
		draw_rect(Rect2(0, 0, size.x, h), Color("#0b0f19"))
		var hi := value > .75
		var col := Color("#ffa53d") if hi else Color("#4fd8ff")
		if locked:
			col = Color(.4, .4, .45)
		var fh := h * value
		draw_rect(Rect2(1, h - fh, size.x - 2, fh), Color(col, .85))
		draw_rect(Rect2(1, h - fh, size.x - 2, 2), col.lightened(.4))
		draw_rect(Rect2(0, 0, size.x, h), Color("#26324a"), false, 1)
		var f := get_theme_default_font()
		draw_string(f, Vector2(0, size.y - 2), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color("#7e8ba4"))

	func _set_from(y: float) -> void:
		if locked:
			return
		hud.game.sim.set_dial(key, 1.0 - clampf(y / (size.y - 14), 0, 1))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT:
				_set_from(e.position.y)
			elif not locked and e.button_index == MOUSE_BUTTON_WHEEL_UP:
				hud.game.sim.set_dial(key, value + .1)
			elif not locked and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				hud.game.sim.set_dial(key, value - .1)
			accept_event()
		elif e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_set_from(e.position.y)
			accept_event()


func _card(a: Unit) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(190, 80)
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
	var sb := ProgressBar.new()
	sb.name = "st"
	sb.custom_minimum_size = Vector2(0, 3)
	sb.show_percentage = false
	sb.max_value = 100
	var sfg := StyleBoxFlat.new()
	sfg.bg_color = CYAN
	sb.add_theme_stylebox_override("fill", sfg)
	sb.add_theme_stylebox_override("background", bg)
	sb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sb)
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
	if Camp.active:
		var b := _button("Continuar  (Enter)", func(): game.finished.emit())
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(b)
	else:
		var h := _label("R para jogar de novo", 15, CYAN)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(h)
	banner.add_child(v)
	banner.visible = true
	banner.position = get_viewport().get_visible_rect().size / 2 - Vector2(320, 90)
	banner.custom_minimum_size = Vector2(640, 180)


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 16)
	var mk := func(bg: Color, bd: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		s.border_color = bd
		s.set_border_width_all(1)
		s.corner_radius_top_left = 8
		s.corner_radius_bottom_right = 8
		s.corner_detail = 1
		s.content_margin_left = 20
		s.content_margin_right = 20
		s.content_margin_top = 10
		s.content_margin_bottom = 10
		return s
	b.add_theme_stylebox_override("normal", mk.call(Color("#0d121e"), Color("#26324a")))
	b.add_theme_stylebox_override("hover", mk.call(Color(.11, .15, .24), Color("#ffa53d")))
	b.add_theme_stylebox_override("pressed", mk.call(Color(.08, .1, .16), Color("#ffa53d")))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	return b


## Menu de pausa (Esc): continuar ou abortar a missão.
func show_pause(on: bool) -> void:
	pause_open = on
	for c in pause_panel.get_children():
		c.queue_free()
	pause_panel.visible = on
	if not on:
		return
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pause_panel.add_child(v)
	var t := _label("PAUSA TÁTICA", 30, Color("#ffa53d"))
	v.add_child(t)
	v.add_child(_label(game.M.objective_text() if not game.M.hand else "Missão em andamento.", 16))
	v.add_child(_label("Esq: mover, selecionar, entrar em carro · Dir: atacar, disparar, arremessar, invadir\n1–4 agentes · Q/E armas · H guardar · F predefinição neural · Z/X girar câmera · Espaço pausa · F1–F6 itens", 13, Color("#7e8ba4")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var vr := HBoxContainer.new()
	vr.add_theme_constant_override("separation", 10)
	for k in [["mus", "Música"], ["sfx", "Efeitos"], ["vo", "Vozes"]]:
		vr.add_child(_label(k[1], 14))
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 1
		s.step = .05
		s.value = Snd.vol[k[0]]
		s.custom_minimum_size = Vector2(110, 0)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.value_changed.connect(func(val): Snd.set_volume(k[0], val))
		vr.add_child(s)
	var tc := CheckBox.new()
	tc.text = "Dicas na tela"
	tc.button_pressed = game.tips_on
	tc.toggled.connect(func(on):
		Game.set_tips(on)
		game.tips_on = on
		if on:
			game.tips_seen = [])
	vr.add_child(tc)
	v.add_child(vr)
	row.add_child(_button("Continuar", func(): game.toggle_pause_menu()))
	if Camp.active:
		row.add_child(_button("Abortar missão", func(): game.abort()))
	else:
		row.add_child(_button("Sair do jogo", func(): game.get_tree().quit()))
	v.add_child(row)
	pause_panel.reset_size()
	pause_panel.position = get_viewport().get_visible_rect().size / 2 - Vector2(330, 110)
	pause_panel.custom_minimum_size = Vector2(660, 0)


var tip_panel: PanelContainer
var tip_lbl: Label
var tip_life := 0.0

## Dica contextual no alto da tela; some sozinha em 9 s ou no ×.
func show_tip(t: String) -> void:
	if tip_panel == null:
		tip_panel = PanelContainer.new()
		var st := _panel_style(.88)
		st.border_color = Color(1, .65, .24, .7)
		st.border_width_left = 3
		tip_panel.add_theme_stylebox_override("panel", st)
		tip_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		tip_panel.add_child(h)
		var ic := _label("DICA", 12, Color("#ffa53d"))
		h.add_child(ic)
		tip_lbl = _label("", 16, Color("#eef3fa"))
		tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip_lbl.custom_minimum_size = Vector2(560, 0)
		h.add_child(tip_lbl)
		var x := Button.new()
		x.text = "×"
		x.flat = true
		x.focus_mode = Control.FOCUS_NONE
		x.pressed.connect(func(): tip_panel.visible = false)
		h.add_child(x)
		get_child(0).add_child(tip_panel)
	tip_lbl.text = t
	tip_panel.visible = true
	tip_panel.reset_size()
	tip_panel.position = Vector2((get_viewport().get_visible_rect().size.x - tip_panel.size.x) / 2, 64)
	tip_life = 9.0


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
		var sb: ProgressBar = c.find_child("st", true, false)
		sb.value = 100.0 if a.colapso > 0 else a.estab
		(sb.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = COLS.red if a.colapso > 0 else (COLS.amber if a.nr.r + a.nr.p + a.nr.c > 1.5 else CYAN)
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
				wp.text = w.ab + ("  %d/%d" % [it.mun, game.sim.pente_of(a, it.t)] if w.get("arma", false) else "") + ("  recarregando" if a.rel > 0 else "")
		var stl: StyleBoxFlat = c.get_theme_stylebox("normal")
		stl.border_color = Color(.3, .95, 1, .95) if a.sel else Color(.3, .85, 1, .25)
		stl.set_border_width_all(2 if a.sel else 1)
	_refresh_inv()
	_refresh_neuro()
	if tip_panel and tip_panel.visible:
		tip_life -= get_process_delta_time()
		tip_panel.modulate.a = clampf(tip_life / .6, 0, 1)
		tip_panel.visible = tip_life > 0 and not M.cine
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

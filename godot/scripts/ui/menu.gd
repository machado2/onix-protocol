## Interface da campanha (porte das telas de v2/js/ui.js): título, mapa tático de Nova Aurora com briefing
## e território, arsenal (esquadrão, implantes, clínica, loja), laboratório e as janelas de relatório,
## interceptações e escolha final. Tudo montado em código sobre a cidade 3D que gira ao fundo.
class_name CampaignMenu
extends CanvasLayer

signal launch(di: int, revolta: bool)
signal quality_changed(q: String)

const BG := Color("#06070b")
const PANEL := Color(.031, .043, .075, .9)
const PANEL2 := Color("#0d121e")
const LINE := Color("#26324a")
const FG := Color("#d3dcea")
const DIM := Color("#7e8ba4")
const AMBER := Color("#ffa53d")
const CYAN := Color("#4fd8ff")
const RED := Color("#ff4d5e")
const GREEN := Color("#5dffa0")
const COLS := {"red": RED, "green": GREEN, "amber": AMBER, "cyan": CYAN, "": FG}
const TIPOS := {assassinato = "Assassinato", extracao = "Extração", sabotagem = "Sabotagem", eliminacao = "Eliminação"}

var root: Control
var screen: Control
var modal_layer: Control
var theme: Theme
var f_disp: Font
var f_bold: Font
var f_mono: Font
var map_sel := -1
var ars_sel := -1
var map_view: MapView
var side: VBoxContainer
var quality := "medium"


# ---------------------------------------------------------------- tema e peças
func _ready() -> void:
	layer = 10
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	f_disp = sf
	var sb := SystemFont.new()
	sb.font_names = PackedStringArray(["Bahnschrift SemiBold", "Bahnschrift", "Segoe UI Semibold", "Arial"])
	sb.font_weight = 600
	f_bold = sb
	var sm := SystemFont.new()
	sm.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New"])
	f_mono = sm
	theme = Theme.new()
	theme.default_font = f_disp
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", FG)
	theme.set_color("default_color", "RichTextLabel", FG)
	theme.set_font("bold_font", "RichTextLabel", f_bold)
	theme.set_font("mono_font", "RichTextLabel", f_mono)
	theme.set_constant("line_separation", "RichTextLabel", 4)
	_button_styles("Button", PANEL2, LINE, FG, Color(.11, .15, .24), AMBER)
	theme.set_type_variation("PriButton", "Button")
	_button_styles("PriButton", AMBER.darkened(.08), AMBER, Color("#140c02"), AMBER.lightened(.15), Color("#ffe0b0"))
	theme.set_type_variation("GhostButton", "Button")
	var ghost := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(st, "GhostButton", ghost)
	theme.set_color("font_color", "GhostButton", DIM)
	theme.set_color("font_hover_color", "GhostButton", AMBER)
	var sl := StyleBoxFlat.new()
	sl.bg_color = LINE
	sl.content_margin_top = 2
	sl.content_margin_bottom = 2
	theme.set_stylebox("slider", "HSlider", sl)
	var ga := StyleBoxFlat.new()
	ga.bg_color = AMBER
	ga.content_margin_top = 2
	ga.content_margin_bottom = 2
	theme.set_stylebox("grabber_area", "HSlider", ga)
	theme.set_stylebox("grabber_area_highlight", "HSlider", ga)
	var vs := StyleBoxFlat.new()
	vs.bg_color = Color(.3, .4, .55, .35)
	vs.set_corner_radius_all(2)
	theme.set_stylebox("grabber", "VScrollBar", vs)
	theme.set_stylebox("grabber_highlight", "VScrollBar", vs)
	theme.set_stylebox("grabber_pressed", "VScrollBar", vs)
	theme.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	screen = Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal_layer)


func _button_styles(type: String, bg: Color, border: Color, fc: Color, hover_bg: Color, hover_border: Color) -> void:
	var mk := func(b: Color, l: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = b
		s.border_color = l
		s.set_border_width_all(1)
		s.corner_radius_top_left = 9
		s.corner_radius_bottom_right = 9
		s.corner_detail = 1
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 11
		s.content_margin_bottom = 11
		return s
	theme.set_stylebox("normal", type, mk.call(bg, border))
	theme.set_stylebox("hover", type, mk.call(hover_bg, hover_border))
	theme.set_stylebox("pressed", type, mk.call(hover_bg.darkened(.2), hover_border))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	theme.set_stylebox("disabled", type, mk.call(Color(bg, .35), Color(border, .3)))
	theme.set_color("font_color", type, fc)
	theme.set_color("font_hover_color", type, fc if type != "Button" else Color.WHITE)
	theme.set_color("font_pressed_color", type, fc)
	theme.set_color("font_focus_color", type, fc)
	theme.set_color("font_disabled_color", type, Color(fc, .35))
	theme.set_font("font", type, f_bold)
	theme.set_font_size("font_size", type, 14)


func _lbl(t: String, size := 16, col := FG, font: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	return l


func _para(t: String, size := 15, col := DIM) -> Label:
	var l := _lbl(t, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	return l


func _rich(bb: String, size := 16) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bb
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("mono_font_size", size - 2)
	r.custom_minimum_size.x = 200
	return r


func _eyebrow(t: String) -> Label:
	var l := _lbl("▍ " + t.to_upper(), 12, AMBER, f_mono)
	l.add_theme_constant_override("outline_size", 0)
	return l


func _btn(t: String, cb: Callable, pri := false, dis := false) -> Button:
	var b := Button.new()
	b.text = t.to_upper()
	if pri:
		b.theme_type_variation = "PriButton"
	b.disabled = dis
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func(): Snd.play("ui"))
	b.pressed.connect(cb)
	return b


func _small(b: Button) -> Button:
	b.add_theme_font_size_override("font_size", 12)
	var type := b.theme_type_variation if b.theme_type_variation != "" else &"Button"
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s: StyleBoxFlat = theme.get_stylebox(st, type).duplicate()
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		s.content_margin_left = 10
		s.content_margin_right = 10
		b.add_theme_stylebox_override(st, s)
	return b


func _box(vertical: bool, sep := 10) -> BoxContainer:
	var b: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


func _frame(pad := 22) -> Frame:
	var f := Frame.new()
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.border_color = LINE
	s.set_border_width_all(1)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	f.add_theme_stylebox_override("panel", s)
	return f


func _scroll(c: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(c)
	return s


func _bar(v: float, col: Color, w := 0.0, h := 6.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.max_value = 1
	p.value = clampf(v, 0, 1)
	p.custom_minimum_size = Vector2(w, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#121a2a")
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fg)
	return p


func _pips(n: int, mx := 10, col := AMBER) -> HBoxContainer:
	var h := _box(false, 3)
	for k in mx:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(9, 9)
		r.color = col if k < n else Color("#1b2436")
		h.add_child(r)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return h


func _kv(rows: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 7)
	for r in rows:
		var k := _lbl(str(r[0]).to_upper(), 12, DIM, f_mono)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(k)
		if r[1] is Control:
			g.add_child(r[1])
		else:
			var v := _lbl(str(r[1]), 15, r[2] if r.size() > 2 else FG, f_bold)
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			g.add_child(v)
	return g


static func _n(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else str(v).replace(".", ",")


func _pic(t: Texture2D, w: float, h: float, border := Color(0, 0, 0, 0)) -> Control:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#0b1020")
	s.border_color = border if border.a > 0 else LINE
	s.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", s)
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.custom_minimum_size = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(r)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _sep() -> HSeparator:
	var s := HSeparator.new()
	var st := StyleBoxLine.new()
	st.color = LINE
	s.add_theme_stylebox_override("separator", st)
	return s


func _clear(c: Node) -> void:
	for ch in c.get_children():
		ch.queue_free()


func _topbar(title: String, stats: Array, back: bool) -> HBoxContainer:
	var h := _box(false, 22)
	var hex := _lbl("⬢", 22, AMBER)
	h.add_child(hex)
	var t := _lbl(title, 22, FG, f_bold)
	h.add_child(t)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	for s in stats:
		var r := _rich("[font_size=12][color=#7e8ba4]%s[/color][/font_size]  [b]%s[/b]" % [s[0], s[1]], 16)
		r.autowrap_mode = TextServer.AUTOWRAP_OFF
		r.custom_minimum_size.x = 0
		h.add_child(r)
	if back:
		h.add_child(_btn("Voltar ao mapa", show_map))
	return h


func _screen_root(pad := 28) -> VBoxContainer:
	_clear(screen)
	var bg := ColorRect.new()
	bg.color = Color(BG, .82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, pad)
	screen.add_child(m)
	var v := _box(true, 16)
	m.add_child(v)
	return v


# ---------------------------------------------------------------- janelas
func close_modal() -> void:
	_clear(modal_layer)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func modal(eyebrow: String, title: String, title_col: Color, body: Array, buttons: Array, width := 780.0) -> void:
	close_modal()
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, .55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(cc)
	var f := _frame(30)
	f.code = "ONX-%d · CLASSIFICADO" % (1000 + randi() % 9000)
	f.custom_minimum_size.x = width
	cc.add_child(f)
	var v := _box(true, 14)
	v.add_theme_constant_override("separation", 14)
	f.add_child(v)
	v.add_child(_eyebrow(eyebrow))
	var t := _lbl(title, 30, FG, f_bold)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var u := ColorRect.new()
	u.color = title_col
	u.custom_minimum_size = Vector2(56, 3)
	u.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(u)
	var inner := _box(true, 12)
	for b in body:
		inner.add_child(b if b is Control else _para(str(b), 16, FG))
	var vh := get_viewport().get_visible_rect().size.y
	var sc := _scroll(inner)
	sc.custom_minimum_size.y = 0
	v.add_child(sc)
	inner.resized.connect(func(): sc.custom_minimum_size.y = minf(inner.size.y, vh * .62))
	var row := _box(false, 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	for b in buttons:
		if b is Control:
			row.add_child(b)
		else:
			row.add_child(_btn(b[0], b[1], b.size() > 2 and b[2], b.size() > 3 and b[3]))
	v.add_child(row)
	var pri: Array = row.get_children().filter(func(c): return c is Button and c.theme_type_variation == "PriButton" and not c.disabled)
	if not pri.is_empty():
		(pri[0] as Button).grab_focus.call_deferred()


func _notes(notes: Array) -> VBoxContainer:
	var v := _box(true, 6)
	for n in notes:
		v.add_child(_para(n[0], 15, COLS.get(n[1], FG)))
	return v


# ---------------------------------------------------------------- título
func show_title() -> void:
	close_modal()
	_clear(screen)
	var g := Gradient.new()
	g.set_color(0, Color(BG, .95))
	g.set_color(1, Color(BG, 0))
	g.add_point(.45, Color(BG, .72))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	var shade := TextureRect.new()
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.anchor_right = .8
	screen.add_child(shade)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", int(get_viewport().get_visible_rect().size.x * .07))
	screen.add_child(m)
	var cc := HBoxContainer.new()
	m.add_child(cc)
	var edge := ColorRect.new()
	edge.color = Color(AMBER, .35)
	edge.custom_minimum_size = Vector2(2, 0)
	var v := _box(true, 20)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.custom_minimum_size.x = 600
	var wrap := _box(false, 24)
	wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrap.add_child(edge)
	wrap.add_child(v)
	cc.add_child(wrap)
	cc.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.add_child(_lbl("NOVA AURORA · 2091", 14, AMBER, f_mono))
	v.add_child(_lbl("ÔNIX-OS 2.91 · TERMINAL DE CONTROLE · ACESSO AUTORIZADO", 11, DIM, f_mono))
	var logo := _box(true, -18)
	logo.add_child(_lbl("PROTOCOLO", 96, FG, f_bold))
	logo.add_child(_lbl("ÔNIX", 96, AMBER, f_bold))
	v.add_child(logo)
	v.add_child(_para("A cidade foi loteada entre corporações. A Ônix comanda quatro agentes ciberneticamente aprimorados e uma ambição simples: tomar cada distrito do Consórcio Hélice.", 18))
	var bt := _box(false, 12)
	bt.add_child(_btn("Nova campanha", _new_campaign, true))
	if Camp.has_save():
		bt.add_child(_btn("Continuar", func():
			if Camp.load_game():
				map_sel = -1
				show_map()))
	bt.add_child(_btn("Sair", func(): get_tree().quit()))
	v.add_child(bt)
	var q := _box(false, 10)
	q.add_child(_lbl("GRÁFICOS", 12, DIM, f_mono))
	for p in [["low", "Baixa"], ["medium", "Média"], ["high", "Alta"]]:
		var b := _small(_btn(p[1], func():
			quality = p[0]
			quality_changed.emit(p[0])
			show_title(), quality == p[0]))
		b.disabled = false
		q.add_child(b)
	v.add_child(q)
	var vh := _volumes()
	var tc := CheckBox.new()
	tc.text = "Dicas"
	tc.button_pressed = Game.tips_enabled()
	tc.toggled.connect(func(on): Game.set_tips(on))
	vh.add_child(tc)
	v.add_child(vh)
	var lh := _box(false, 10)
	lh.add_child(_lbl("IDIOMA", 12, DIM, f_mono))
	for p in [["pt", "Português"], ["en", "English"]]:
		var lb := _small(_btn(p[1], func():
			Lang.set_lang(p[0])
			show_title(), Lang.lang == p[0]))
		lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		lh.add_child(lb)
	v.add_child(lh)
	var keys := _rich("[font_size=12][color=#7e8ba4]Botão esq. mover · selecionar · arrastar seleção\nBotão dir. atacar · disparar · arremessar · invadir\n1–4 agentes · Q/E armas · H guardar · F predefinição neural · Z/X girar câmera · Espaço pausa · Esc menu[/color][/font_size]", 12)
	v.add_child(_sep())
	v.add_child(keys)


func _volumes() -> HBoxContainer:
	var h := _box(false, 10)
	h.add_child(_lbl("SOM", 12, DIM, f_mono))
	for k in [["mus", "Música"], ["sfx", "Efeitos"], ["vo", "Vozes"]]:
		h.add_child(_lbl(k[1], 13, FG))
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 1
		s.step = .05
		s.value = Snd.vol[k[0]]
		s.custom_minimum_size = Vector2(90, 0)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.value_changed.connect(func(v): Snd.set_volume(k[0], v))
		h.add_child(s)
	return h


func _new_campaign() -> void:
	var go := func():
		Camp.new_game()
		map_sel = 0
		show_map()
		show_msg("inicio", false)
	if Camp.has_save():
		modal("Nova campanha", "Apagar o progresso salvo?", RED, ["Começar uma nova campanha substitui a campanha salva neste computador."],
			[["Cancelar", close_modal], ["Começar do zero", go, true]], 620)
	else:
		go.call()


# ---------------------------------------------------------------- mapa
func show_map() -> void:
	close_modal()
	if map_sel < 0 or (not Camp.avail(map_sel) and Camp.G.dono[map_sel] != "player"):
		map_sel = -1
		for i in Camp.DIST.size():
			if Camp.avail(i):
				map_sel = i
				break
	var v := _screen_root(24)
	var G := Camp.G
	v.add_child(_topbar("ÔNIX · MAPA TÁTICO", [["DIA", str(G.dia)], ["FUNDOS", Camp.fmt(G.dinheiro)], ["DISTRITOS", "%d/%d" % [Camp.owned(), Camp.DIST.size()]],
		["RENDA", Camp.fmt(Camp.total_income()) + "/dia"], ["AGENTES", str(G.agentes.size())]], false))
	v.add_child(_sep())
	var body := _box(false, 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	map_view = MapView.new()
	map_view.menu = self
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(map_view)
	var sf := _frame(24)
	sf.custom_minimum_size.x = 440
	body.add_child(sf)
	side = _box(true, 14)
	sf.add_child(_scroll(side))
	var bar := _box(false, 10)
	bar.add_child(_btn("Equipe e arsenal", show_arsenal))
	bar.add_child(_btn("Laboratório", show_lab))
	var un := Camp.unread()
	bar.add_child(_btn("Interceptações (%d)" % un if un else "Interceptações", show_inbox, un > 0))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	bar.add_child(_lbl("Distritos em âmbar podem ser atacados. Um dia passa a cada missão.", 13, DIM))
	bar.add_child(_btn("Menu principal", show_title))
	v.add_child(bar)
	_render_side()


func select_dist(i: int) -> void:
	map_sel = i
	_render_side()


func _render_side() -> void:
	_clear(side)
	if map_sel < 0:
		side.add_child(_eyebrow("Mapa de Nova Aurora"))
		side.add_child(_lbl("Selecione um distrito", 26, FG, f_bold))
		return
	var i := map_sel
	var d: Dictionary = Camp.DIST[i]
	var G := Camp.G
	if G.dono[i] == "player":
		_render_owned(i)
		return
	var av := Camp.avail(i)
	side.add_child(_eyebrow("Quartel-general do Consórcio" if d.get("hq", false) else "Distrito"))
	side.add_child(_lbl(d.nome, 30, FG, f_bold))
	side.add_child(_lbl("ALVO DISPONÍVEL" if av else "FORA DE ALCANCE", 13, AMBER if av else RED, f_mono))
	side.add_child(_kv([["Operação", TIPOS[d.tipo]], ["Ameaça", _pips(d.dif)], ["Recompensa", Camp.fmt(Camp.reward(i))], ["Renda diária", Camp.fmt(d.renda)]]))
	side.add_child(_para(d.short if av else "Conquiste um distrito vizinho para alcançar este setor.", 16, FG))
	side.add_child(_sep())
	side.add_child(_kv([["Renda atual da Ônix", Camp.fmt(Camp.total_income()) + "/dia"], ["Esquadrão", "%d/4 agentes" % G.esq.size()], ["Laboratório", Camp.lab_line()]]))
	var acts := _box(false, 10)
	if av:
		acts.add_child(_btn("Briefing da missão", func(): open_briefing(i), true))
	side.add_child(acts)


func _render_owned(i: int) -> void:
	var d: Dictionary = Camp.DIST[i]
	var t := Camp.terr(i)
	var st: Array = ["EM REVOLTA", RED] if t.revolta else (["AGITADO", AMBER] if t.lealdade < 25 else ["CONTROLADO PELA ÔNIX", CYAN])
	side.add_child(_eyebrow("Distrito da Ônix"))
	side.add_child(_lbl(d.nome, 30, FG, f_bold))
	side.add_child(_lbl(st[0], 13, st[1], f_mono))
	var tax_l := _lbl("", 15, FG, f_bold)
	var inc_l := _lbl("", 15, FG, f_bold)
	var dl_l := _lbl("", 15, FG, f_bold)
	var upd := func():
		tax_l.text = "%d%%" % roundi(t.imposto * 100)
		inc_l.text = Camp.fmt(Camp.dist_income(i)) + "/dia"
		var n := Camp.loyalty_delta(i)
		dl_l.text = ("+" if n > 0 else "") + str(n) + "/dia"
		dl_l.add_theme_color_override("font_color", RED if n < 0 else GREEN)
	upd.call()
	var th := _box(false, 12)
	th.add_child(_lbl("IMPOSTO", 12, DIM, f_mono))
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 60
	s.step = 5
	s.value = roundi(t.imposto * 100)
	s.editable = not t.revolta
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(val):
		t.imposto = val / 100.0
		upd.call())
	s.drag_ended.connect(func(_c): Camp.save())
	th.add_child(s)
	th.add_child(tax_l)
	side.add_child(th)
	var loy := _box(false, 8)
	loy.add_child(_bar(t.lealdade / 100.0, _loy_col(t.lealdade), 120, 7))
	loy.add_child(_lbl(str(t.lealdade), 15, FG, f_bold))
	side.add_child(_kv([["Renda do distrito", inc_l], ["Lealdade", loy], ["Tendência", dl_l]]))
	if t.revolta:
		side.add_child(_para("Agitadores do Consórcio tomaram as ruas. Reprima a revolta em %d dia(s) ou o distrito volta ao Consórcio." % t.revolta, 15, RED))
	else:
		side.add_child(_para("Impostos altos derrubam a lealdade a cada dia; impostos baixos a recuperam. Cada fronteira com o Consórcio pesa um pouco. Abaixo de 25 o distrito paga metade; em zero, se revolta.", 14))
	side.add_child(_sep())
	side.add_child(_kv([["Renda total da Ônix", Camp.fmt(Camp.total_income()) + "/dia"], ["Laboratório", Camp.lab_line()]]))
	if t.revolta:
		side.add_child(_btn("Reprimir revolta", func(): open_revolt(i), true))


static func _loy_col(v: float) -> Color:
	return RED if v < 25 else (AMBER if v < 50 else CYAN)


func _squad_list() -> VBoxContainer:
	var v := _box(true, 4)
	var sq := Camp.squad()
	if sq.is_empty():
		v.add_child(_para("Nenhum agente no esquadrão. Monte a equipe no arsenal.", 15, RED))
	for a in sq:
		var h := _box(false, 12)
		h.add_child(_pic(Portraits.agent(a), 32, 40))
		var nl := _lbl(a.nome, 16, CYAN, f_bold)
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(nl)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sp)
		h.add_child(_lbl(" · ".join(a.inv.map(func(q): return GD.WD[q.t].ab)), 13, DIM, f_mono))
		v.add_child(h)
	return v


func open_briefing(i: int) -> void:
	var d: Dictionary = Camp.DIST[i]
	var ok := not Camp.squad().is_empty()
	modal("Briefing · %s · ameaça %d/10" % [TIPOS[d.tipo], d.dif], d.nome, AMBER, [d.brief, _sep(), _squad_list()],
		[["Voltar", close_modal], ["Arsenal", show_arsenal], ["Iniciar missão", func():
			close_modal()
			launch.emit(i, false), true, not ok]])


func open_revolt(i: int) -> void:
	var d: Dictionary = Camp.DIST[i]
	var ok := not Camp.squad().is_empty()
	modal("Briefing · Repressão · %d dia(s) restante(s)" % Camp.terr(i).revolta, "%s em revolta" % d.nome, RED,
		["Agitadores do Consórcio incitaram a população de %s contra a Ônix. Elimine os agitadores antes que o distrito caia. As ruas estão cheias: cada civil morto deixa o distrito menos leal depois da operação." % d.nome, _sep(), _squad_list()],
		[["Voltar", close_modal], ["Iniciar repressão", func():
			close_modal()
			launch.emit(i, true), true, not ok]])


# ---------------------------------------------------------------- relatório
func show_result(r: Dictionary) -> void:
	show_map()
	var body := [_lbl("CUMPRIDA" if r.win else "FRACASSO", 15, GREEN if r.win else RED, f_mono), r.reason, _kv(r.rows), _sep(), _notes(r.notes)]
	if r.vitoria:
		body.append(_para("O Consórcio Hélice colapsou. Cada distrito agora paga tributo à Ônix.", 16, FG))
	if r.game_over:
		body.append(_para("Sem agentes e sem fundos para recrutar. A Ônix foi dissolvida.", 16, RED))
		modal("Relatório · %s · dia %d" % [r.dist, r.dia], r.title, RED, body, [["Nova campanha", func():
			Camp.new_game()
			map_sel = 0
			show_map(), true]])
		return
	modal("Relatório · %s · dia %d" % [r.dist, r.dia], r.title, GREEN if r.win else RED, body, [["Voltar ao mapa", func():
		if r.vitoria and Camp.G.final == "":
			show_final()
		else:
			show_map(), true]])


# ---------------------------------------------------------------- arsenal
func show_arsenal() -> void:
	close_modal()
	var G := Camp.G
	if Camp.agent(ars_sel) == null:
		ars_sel = G.agentes[0].id if not G.agentes.is_empty() else -1
	var v := _screen_root(24)
	v.add_child(_topbar("ÔNIX · ARSENAL", [["FUNDOS", Camp.fmt(G.dinheiro)], ["ESQUADRÃO", "%d/4" % G.esq.size()], ["DISTRITOS", str(Camp.owned())]], true))
	v.add_child(_sep())
	var cols := _box(false, 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	# agentes
	var c1 := _box(true, 10)
	c1.add_child(_eyebrow("Agentes"))
	for q in G.agentes:
		var row := _box(false, 8)
		var nb := Button.new()
		nb.text = "%s   ·   %d missões" % [q.nome, q.missoes]
		nb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nb.theme_type_variation = "PriButton" if q.id == ars_sel else ""
		nb.pressed.connect(func():
			ars_sel = q.id
			show_arsenal())
		row.add_child(_pic(Portraits.agent(q), 36, 45, AMBER if q.id == ars_sel else LINE))
		row.add_child(nb)
		var inS: bool = q.id in G.esq
		var sb := _small(_btn("No esquadrão" if inS else "Reserva", func():
			if inS:
				G.esq.erase(q.id)
			elif G.esq.size() < 4:
				G.esq.append(q.id)
			Camp.save()
			show_arsenal(), false, not inS and G.esq.size() >= 4))
		sb.add_theme_color_override("font_color", CYAN if inS else DIM)
		sb.custom_minimum_size.x = 130
		row.add_child(sb)
		c1.add_child(row)
	c1.add_child(_btn("Recrutar agente · " + Camp.fmt(Camp.RECRUTA), func():
		G.dinheiro -= Camp.RECRUTA
		var n := Camp.novo_agente()
		G.agentes.append(n)
		if G.esq.size() < 4:
			G.esq.append(n.id)
		ars_sel = n.id
		Camp.save()
		show_arsenal(), false, G.dinheiro < Camp.RECRUTA or G.agentes.size() >= Camp.MAX_AGENTES))
	c1.add_child(_para("Até 8 agentes na folha e 4 em campo. Agentes abatidos em missão não voltam.", 13))
	var f1 := _frame()
	f1.custom_minimum_size.x = 430
	f1.add_child(_scroll(c1))
	cols.add_child(f1)
	# agente selecionado
	var c2 := _box(true, 12)
	var a = Camp.agent(ars_sel)
	if a != null:
		var ah := _box(false, 18)
		ah.add_child(_pic(Portraits.agent(a), 112, 140, AMBER))
		var av := _box(true, 6)
		av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		av.add_child(_lbl(a.nome, 34, FG, f_bold))
		av.add_child(_lbl("%d missões · %d abates" % [a.missoes, a.abates], 13, DIM, f_mono))
		ah.add_child(av)
		c2.add_child(ah)
		c2.add_child(_eyebrow("Implantes cibernéticos"))
		var cap := Camp.imp_cap()
		for k in Camp.IMP:
			var lv: int = a.imp[k]
			var h := _box(false, 10)
			var nm := _lbl(Camp.IMP[k].nome, 16, FG, f_bold)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(nm)
			h.add_child(_pips(lv, 3, CYAN))
			if lv >= 3:
				h.add_child(_lbl("MÁX", 13, CYAN, f_mono))
			elif lv >= cap:
				h.add_child(_lbl("Requer Mk " + ("II" if lv == 1 else "III"), 12, DIM, f_mono))
			else:
				var pr: int = Camp.IMP_PRECO[lv]
				h.add_child(_small(_btn(Camp.fmt(pr), func():
					G.dinheiro -= pr
					a.imp[k] += 1
					Camp.save()
					show_arsenal(), false, G.dinheiro < pr)))
			c2.add_child(h)
			c2.add_child(_para(Camp.IMP[k].desc, 13))
		var dh := _box(false, 10)
		var dn := _lbl("Dependência neural", 16, FG, f_bold)
		dn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dh.add_child(dn)
		dh.add_child(_lbl("%d%%" % a.dep, 15, RED if a.dep > 20 else DIM, f_mono))
		if a.dep:
			dh.add_child(_small(_btn("Clínica " + Camp.fmt(Camp.CLINICA), func():
				G.dinheiro -= Camp.CLINICA
				a.dep = 0
				Camp.save()
				show_arsenal(), false, G.dinheiro < Camp.CLINICA)))
		c2.add_child(dh)
		c2.add_child(_para("Tempo em sobrecarga gera dependência, que reduz a estabilidade máxima nas missões.", 13))
		c2.add_child(_eyebrow("Inventário · clique para vender por 50%"))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for s in Camp.MAXINV:
			var b := Button.new()
			b.custom_minimum_size = Vector2(120, 62)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if s < a.inv.size():
				var t: String = a.inv[s].t
				var val: int = Camp.ITEM[t].preco / 2
				b.text = "%s\nvender %s" % [GD.WD[t].ab, Camp.fmt(val)]
				b.pressed.connect(func():
					G.dinheiro += val
					a.inv.remove_at(s)
					Camp.save()
					show_arsenal())
			else:
				b.text = "vazio"
				b.disabled = true
			grid.add_child(b)
		c2.add_child(grid)
	else:
		c2.add_child(_para("Nenhum agente. Recrute alguém para continuar.", 16, FG))
	var f2 := _frame()
	f2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f2.add_child(_scroll(c2))
	cols.add_child(f2)
	# loja
	var c3 := _box(true, 12)
	c3.add_child(_eyebrow("Fornecedores do mercado cinza"))
	for t in Camp.SHOP:
		var w: Dictionary = GD.WD[t]
		var it: Dictionary = Camp.ITEM[t]
		var lock: bool = it.has("res") and not Camp.has(it.res)
		var card := _box(true, 4)
		var h := _box(false, 8)
		var nm := _lbl(w.nome, 17, DIM if lock else FG, f_bold)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(_lbl(Camp.fmt(it.preco), 15, AMBER, f_mono))
		card.add_child(h)
		card.add_child(_para(it.desc, 13))
		var st := ""
		if w.get("arma", false):
			st = ("fogo · alcance %s" % _n(w.alcance)) if w.get("flame", false) else ("dano %s%s · alcance %s · %s tiros/s · pente %d" % [_n(w.dano), ("×%d" % w.pellets) if w.has("pellets") else "", _n(w.alcance), _n(snappedf(1.0 / w.cad, .1)), w.pente])
		elif w.get("throw", false):
			st = "dano %s em área · alcance %s" % [_n(w.dano), _n(w.alcance)]
		if st != "":
			card.add_child(_lbl(st, 12, Color(CYAN, .8), f_mono))
		if lock:
			card.add_child(_lbl("Requer pesquisa: " + Camp.res_by_id(it.res).nome, 12, RED, f_mono))
		else:
			var full: bool = a == null or a.inv.size() >= Camp.MAXINV
			var bb := _small(_btn("Comprar para " + (a.nome if a != null else "—"), func():
				G.dinheiro -= it.preco
				a.inv.append({t = t})
				Camp.save()
				show_arsenal(), false, full or G.dinheiro < it.preco))
			bb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			card.add_child(bb)
		card.add_child(_sep())
		c3.add_child(card)
	var f3 := _frame()
	f3.custom_minimum_size.x = 520
	f3.add_child(_scroll(c3))
	cols.add_child(f3)


# ---------------------------------------------------------------- laboratório
func show_lab() -> void:
	close_modal()
	var G := Camp.G
	var v := _screen_root(24)
	v.add_child(_topbar("ÔNIX · LABORATÓRIO", [["FUNDOS", Camp.fmt(G.dinheiro)], ["CIENTISTAS", str(G.cientistas)], ["PRODUÇÃO", "%d PD/dia" % Camp.pd_dia()],
		["SALÁRIOS", Camp.fmt(G.cientistas * Camp.CIENT_SAL) + "/dia"]], true))
	v.add_child(_sep())
	var cols := _box(false, 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var c1 := _box(true, 12)
	c1.add_child(_eyebrow("Projeto em andamento"))
	var a := Camp.res_by_id(G.pesq.ativo) if G.pesq.ativo else {}
	if not a.is_empty():
		var p: int = G.pesq.prog.get(a.id, 0)
		c1.add_child(_lbl(a.nome, 24, FG, f_bold))
		c1.add_child(_lbl("%d/%d PD · %d dia(s)" % [p, a.custo, ceili(float(a.custo - p) / maxi(1, Camp.pd_dia()))], 13, DIM, f_mono))
		c1.add_child(_bar(float(p) / a.custo, AMBER, 0, 8))
		c1.add_child(_para(a.desc, 14))
	else:
		c1.add_child(_para("Nenhum projeto ativo. Escolha um ao lado.", 15, AMBER))
	c1.add_child(_sep())
	c1.add_child(_eyebrow("Equipe científica"))
	c1.add_child(_para("Cada cientista produz %d PD por dia e custa %s de salário. Um dia passa a cada missão. Missões de extração trazem cientistas desertores de graça." % [Camp.PD_POR_CIENT, Camp.fmt(Camp.CIENT_SAL)], 14))
	c1.add_child(_btn("Contratar cientista · " + Camp.fmt(Camp.CIENT_PRECO), func():
		G.dinheiro -= Camp.CIENT_PRECO
		G.cientistas += 1
		Camp.save()
		show_lab(), false, G.dinheiro < Camp.CIENT_PRECO or G.cientistas >= Camp.MAX_CIENT))
	c1.add_child(_btn("Dispensar um cientista", func():
		G.cientistas -= 1
		Camp.save()
		show_lab(), false, G.cientistas <= 1))
	c1.add_child(_sep())
	c1.add_child(_eyebrow("Concluídas"))
	var done: Array = Camp.RESEARCH.filter(func(r): return Camp.has(r.id)).map(func(r): return r.nome)
	c1.add_child(_para(" · ".join(done) if not done.is_empty() else "nenhuma ainda", 14))
	var f1 := _frame()
	f1.custom_minimum_size.x = 400
	f1.add_child(_scroll(c1))
	cols.add_child(f1)
	var tree := _box(false, 12)
	for cat in Camp.RES_CATS:
		var col := _box(true, 10)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_eyebrow(cat))
		for r in Camp.RESEARCH.filter(func(q): return q.cat == cat):
			col.add_child(_res_card(r))
		tree.add_child(col)
	var f2 := _frame()
	f2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f2.add_child(_scroll(tree))
	cols.add_child(f2)


func _res_card(r: Dictionary) -> Control:
	var G := Camp.G
	var done := Camp.has(r.id)
	var av := Camp.res_avail(r)
	var act: bool = G.pesq.ativo == r.id
	var pr: int = G.pesq.prog.get(r.id, 0)
	var col: Color = GREEN if done else (AMBER if act else (CYAN if av else DIM))
	var pc := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(col, .1 if (act or done) else .04)
	s.border_color = Color(col, .7 if act else .3)
	s.set_border_width_all(1)
	s.border_width_left = 3
	s.content_margin_left = 12
	s.content_margin_right = 10
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	pc.add_theme_stylebox_override("panel", s)
	var v := _box(true, 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	v.add_child(_lbl(r.nome, 15, FG if (av or done) else DIM, f_bold))
	v.add_child(_lbl("CONCLUÍDA" if done else ("EM ANDAMENTO" if act else "%d PD" % r.custo), 11, col, f_mono))
	var d := _para(r.desc, 12)
	v.add_child(d)
	if pr and not done:
		v.add_child(_bar(float(pr) / r.custo, AMBER, 0, 4))
	if not done and not av:
		var miss: Array = r.get("req", []).filter(func(x): return not Camp.has(x)).map(func(x): return Camp.res_by_id(x).nome)
		v.add_child(_lbl("Requer " + ", ".join(miss), 11, RED, f_mono))
	for c in v.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if av and not act:
		pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pc.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				G.pesq.ativo = r.id
				Camp.save()
				show_lab())
		pc.mouse_entered.connect(func(): s.border_color = Color(AMBER, .8))
		pc.mouse_exited.connect(func(): s.border_color = Color(col, .3))
	return pc


# ---------------------------------------------------------------- interceptações e final
func show_inbox() -> void:
	var G := Camp.G
	var riv := _box(false, 14)
	riv.add_child(_lbl("OS PONTEIROS", 12, DIM, f_mono))
	for id in ["navalha", "sibila", "ferro", "mariposa", "juiz"]:
		var s: Dictionary = G.rivais.get(id, {})
		var v := _box(true, 2)
		var dead: bool = s.get("morto", false)
		var pic := _pic(Portraits.rival(id), 64, 80, Color(Camp.RIVAL_INFO[id].trim) if not dead else LINE)
		if dead:
			pic.modulate = Color(.45, .45, .5)
		v.add_child(pic)
		v.add_child(_lbl(GD.RIVALS[id].nome, 15, Color(Camp.RIVAL_INFO[id].trim) if not s.get("morto", false) else DIM, f_bold))
		v.add_child(_lbl("morto" if s.get("morto", false) else ("%d fuga(s)" % s.fugas if s.get("fugas", 0) else "à solta"), 11, DIM, f_mono))
		riv.add_child(v)
	var list := _box(true, 6)
	var msgs: Array = G.msgs.duplicate()
	msgs.reverse()
	for m in msgs:
		var d: Dictionary = Camp.MSGS[m.id]
		var b := Button.new()
		b.text = "%s%s  —  %s   ·   dia %d" % ["● " if not m.lida else "", d.de, d.assunto, m.dia]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.clip_text = true
		if not m.lida:
			b.add_theme_color_override("font_color", AMBER)
		b.pressed.connect(func(): show_msg(m.id, true))
		list.add_child(b)
	if msgs.is_empty():
		list.add_child(_para("Nenhuma mensagem ainda.", 15))
	modal("Interceptações · %d mensagem(ns)" % msgs.size(), "Caixa de entrada", AMBER, [riv, _sep(), list], [["Fechar", show_map, true]], 860)


func show_msg(id: String, back_inbox: bool) -> void:
	for m in Camp.G.msgs:
		if m.id == id:
			m.lida = true
	Camp.save()
	var d: Dictionary = Camp.MSGS[id]
	var body := []
	for p in d.corpo.split("\n"):
		body.append(_para(p, 17, FG))
	modal("De %s · para %s" % [d.de, d.para], d.assunto, AMBER, body,
		[["Voltar à caixa", show_inbox, true]] if back_inbox else [["Entendido", show_map, true]], 760)


func show_final() -> void:
	var G := Camp.G
	if G.wiped:
		_epilogue("apagado")
		return
	var d: Dictionary = Camp.MSGS.fim
	var body := []
	for p in d.corpo.split("\n"):
		body.append(_para(p, 17, FG))
	modal("De %s · para %s" % [d.de, d.para], d.assunto, AMBER, body,
		[["Destruir o Coral", func(): _epilogue("destruir")], ["Ativar o Coral", func(): _epilogue("ativar"), true]], 760)


func _epilogue(k: String) -> void:
	Camp.G.final = k
	Camp.save()
	var e: Dictionary = Camp.ENDINGS[k]
	var body := []
	for p in e.texto.split("\n"):
		body.append(_para(p, 17, FG))
	modal("Epílogo", e.titulo, AMBER, body, [["Voltar ao mapa", show_map, true]], 760)


# ---------------------------------------------------------------- carregamento
func show_loading(title: String, sub: String) -> void:
	close_modal()
	_clear(screen)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(cc)
	var v := _box(true, 10)
	cc.add_child(v)
	v.add_child(_eyebrow("Inserção"))
	v.add_child(_lbl(title, 44, FG, f_bold))
	v.add_child(_lbl(sub, 14, DIM, f_mono))


func hide_all() -> void:
	close_modal()
	_clear(screen)


# ---------------------------------------------------------------- peças desenhadas
## Painel com colchetes âmbar nos cantos e uma etiqueta de código opcional.
class Frame extends PanelContainer:
	var code := ""

	func _draw() -> void:
		var c := Color(1, .647, .239, .9)
		var s := size
		var L := 14.0
		for p in [[Vector2(0, 0), Vector2(1, 1)], [Vector2(s.x, 0), Vector2(-1, 1)], [Vector2(0, s.y), Vector2(1, -1)], [Vector2(s.x, s.y), Vector2(-1, -1)]]:
			var o: Vector2 = p[0]
			var d: Vector2 = p[1]
			draw_line(o, o + Vector2(L * d.x, 0), c, 2)
			draw_line(o, o + Vector2(0, L * d.y), c, 2)
		if code != "":
			var f := get_theme_default_font()
			var w := f.get_string_size(tr(code), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 24
			var x := s.x - 22 - w
			draw_colored_polygon(PackedVector2Array([Vector2(x + 7, 0), Vector2(x + w, 0), Vector2(x + w, 17), Vector2(x, 17)]), c)
			draw_string(f, Vector2(x + 14, 12.5), tr(code), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#140c02"))


## Mapa tático: distritos de Nova Aurora como polígonos, coloridos por dono e disponibilidade.
class MapView extends Control:
	var menu
	var hover := -1
	var t := 0.0
	var s := 1.0
	var off := Vector2()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _pt(p) -> Vector2:
		return off + Vector2(p[0], p[1]) * s

	func _poly(src: Array) -> PackedVector2Array:
		var a := PackedVector2Array()
		for p in src:
			a.append(_pt(p))
		return a

	func _state(i: int) -> String:
		if Camp.G.dono[i] == "player":
			return "own"
		return "avail" if Camp.avail(i) else "enemy"

	func _draw() -> void:
		s = minf(size.x / 1000.0, size.y / 620.0) * .97
		off = (size - Vector2(1000, 620) * s) / 2
		var f: Font = menu.f_bold
		var fm: Font = menu.f_mono
		draw_rect(Rect2(off, Vector2(1000, 620) * s), Color(.02, .03, .05, .7))
		for k in range(0, 1001, 20):
			draw_line(_pt([k, 0]), _pt([k, 620]), Color(.07, .1, .16, .5), 1)
		for k in range(0, 621, 20):
			draw_line(_pt([0, k]), _pt([1000, k]), Color(.07, .1, .16, .5), 1)
		var bay := _poly(Camp.BAY)
		draw_colored_polygon(bay, Color(.03, .08, .14, .8))
		for k in range(-30, 60):
			var x0 := 700.0 + k * 9
			var seg := PackedVector2Array([_pt([x0, 620]), _pt([x0 + 300, 320])])
			for piece in Geometry2D.intersect_polyline_with_polygon(seg, bay):
				draw_polyline(piece, Color(.08, .17, .26, .9), 1.5)
		var bc := _pt([850, 470])
		draw_string(fm, bc - Vector2(150, 0), tr("BAÍA DE AURORA"), HORIZONTAL_ALIGNMENT_CENTER, 300, 12, Color("#2e5a80"))
		for i in Camp.DIST.size():
			var d: Dictionary = Camp.DIST[i]
			var st := _state(i)
			var poly := _poly(d.poly)
			var col: Color = {own = CampaignMenu.CYAN, avail = CampaignMenu.AMBER, enemy = CampaignMenu.RED}[st]
			var T = Camp.terr(i) if st == "own" else null
			if T != null and T.revolta:
				col = CampaignMenu.RED
			var a := .16 if st != "enemy" else .07
			if i == hover:
				a += .07
			if i == menu.map_sel:
				a += .1 + .05 * sin(t * 4)
			draw_colored_polygon(poly, Color(col, a))
			var closed := poly.duplicate()
			closed.append(poly[0])
			if i == menu.map_sel:
				draw_polyline(closed, Color(col, .25), 9)
			draw_polyline(closed, Color(col, .95 if i == menu.map_sel else .55), 2.0 if i == menu.map_sel else 1.2)
			var c := Vector2()
			for p in poly:
				c += p
			c /= poly.size()
			var fs := clampi(int(20 * s / .9), 13, 24)
			draw_string(f, c + Vector2(-160, -2), d.nome.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 320, fs, Color(1, 1, 1, .92 if st != "enemy" else .55))
			var sub := ("ÔNIX" if st == "own" else ("QG HÉLICE" if d.get("hq", false) else "HÉLICE")) + " · NV %d" % d.dif
			draw_string(fm, c + Vector2(-160, 18), tr(sub), HORIZONTAL_ALIGNMENT_CENTER, 320, 11, Color(col, .9))
			if T != null:
				var w := 84.0
				draw_rect(Rect2(c + Vector2(-w / 2, 28), Vector2(w, 5)), Color("#121a2a"))
				draw_rect(Rect2(c + Vector2(-w / 2, 28), Vector2(w * T.lealdade / 100.0, 5)), CampaignMenu._loy_col(T.lealdade))
				if T.revolta:
					draw_string(fm, c + Vector2(-160, 48), tr("REVOLTA"), HORIZONTAL_ALIGNMENT_CENTER, 320, 11, Color(CampaignMenu.RED, .6 + .4 * sin(t * 6)))
		draw_string(fm, off + Vector2(8, 16), tr("NOVA AURORA · GRADE TÁTICA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(.5, .55, .65, .55))

	func _hit(p: Vector2) -> int:
		for i in Camp.DIST.size():
			if Geometry2D.is_point_in_polygon(p, _poly(Camp.DIST[i].poly)):
				return i
		return -1

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			hover = _hit(e.position)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover >= 0 else Control.CURSOR_ARROW
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var i := _hit(e.position)
			if i >= 0:
				menu.select_dist(i)
				if e.double_click and Camp.avail(i):
					menu.open_briefing(i)

## Tradução para inglês (porte de v2/js/i18n.js e en.js). Fica registrada no TranslationServer, então todo texto
## de Label/Button/RichTextLabel passa por aqui sozinho. Frases exatas vêm de i18n_en.json (+ i18n_en_extra.json);
## frases com números e nomes, das regras de i18n_rules_en.json, com modelos:
##   {1} grupo cru · {t1} grupo traduzido · {m1} dinheiro (1.500 → 1,500) · {p1:um:vários} plural · {?2:texto} se o grupo existir.
## Nomes de lugares, de pessoas e os codinomes ficam em português de propósito.
extends Translation

var EN := {}
var low := {}
var rules: Array = []
var cache := {}
var miss := {}
var tag_re := RegEx.new()
var edge_re := RegEx.new()
var pt_re := RegEx.new()


func _init() -> void:
	locale = "en"
	for p in ["res://assets/i18n_en.json", "res://assets/i18n_en_extra.json"]:
		var f := FileAccess.open(p, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				EN.merge(d, true)
	for k in EN:
		low[String(k).to_lower()] = EN[k]
	var rr := []
	for p in ["res://assets/i18n_rules_en.json", "res://assets/i18n_rules_en_extra.json"]:
		var f := FileAccess.open(p, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Array:
				rr.append_array(d)
	rr.sort_custom(func(a, b): return String(a[0]).length() > String(b[0]).length())
	for r in rr:
		var re := RegEx.new()
		if re.compile("(?i)" + String(r[0]).replace("\\/", "/")) == OK:
			rules.append([re, String(r[1])])
	tag_re.compile("\\[[^\\]]*\\]")
	edge_re.compile("^(\\s*[✓✗◆○▼·•▸▍⬢●]*\\s*)([\\s\\S]*?)(\\s*)$")
	pt_re.compile("[ãõçáéíóúâêôà]|\\b(de|do|da|em|para|com|não|os|as)\\b")


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var s := String(src_message)
	if s.is_empty():
		return src_message
	if cache.has(s):
		return cache[s]
	var r := t(s)
	if cache.size() > 6000:
		cache.clear()
	cache[s] = StringName(r)
	return cache[s]


func t(s: String) -> String:
	if s.is_empty():
		return s
	if EN.has(s):
		return EN[s]
	if s.contains("[") and tag_re.search(s):
		var out := ""
		var pos := 0
		for m in tag_re.search_all(s):
			out += _line(s.substr(pos, m.get_start() - pos)) + m.get_string()
			pos = m.get_end()
		return out + _line(s.substr(pos))
	if s.contains("\n"):
		var parts := s.split("\n")
		for i in parts.size():
			parts[i] = _line(parts[i])
		return "\n".join(parts)
	return _line(s)


func _line(s: String) -> String:
	if s.strip_edges().is_empty():
		return s
	if EN.has(s):
		return EN[s]
	var m := edge_re.search(s)
	var pre := m.get_string(1)
	var core := m.get_string(2)
	var post := m.get_string(3)
	if core.is_empty():
		return s
	var r = _core(core)
	if r == null:
		if pt_re.search(core.to_lower()):
			miss[core] = true
		return s
	return pre + r + post


func _is_upper(s: String) -> bool:
	return s == s.to_upper() and s != s.to_lower()


func _core(core: String):
	if EN.has(core):
		return EN[core]
	var up := _is_upper(core)
	var lk := core.to_lower()
	if low.has(lk):
		return String(low[lk]).to_upper() if up else low[lk]
	for r in rules:
		var m: RegExMatch = r[0].search(core)
		if m == null and up:
			m = r[0].search(lk)
		if m:
			var out := _fill(r[1], m)
			return out.to_upper() if up else out
	# listas "A · B · C": traduz cada pedaço
	for sep in ["  ·  ", " · "]:
		if core.contains(sep):
			var parts := core.split(sep)
			var any := false
			for i in parts.size():
				var p = _core(parts[i])
				if p != null:
					parts[i] = p
					any = true
			if any:
				return sep.join(parts)
	return null


func _fill(tpl: String, m: RegExMatch) -> String:
	var out := ""
	var i := 0
	while i < tpl.length():
		var c := tpl[i]
		if c != "{":
			out += c
			i += 1
			continue
		var j := tpl.find("}", i)
		if j < 0:
			out += tpl.substr(i)
			break
		var body := tpl.substr(i + 1, j - i - 1)
		i = j + 1
		if body.begins_with("?"):
			var k := int(body[1])
			if m.get_string(k) != "":
				out += body.substr(3)
		elif body.begins_with("t"):
			var g := m.get_string(int(body.substr(1)))
			var tr_g = _core(g)
			if tr_g == null and g.contains(", "):
				var ps := g.split(", ")
				for k in ps.size():
					var q = _core(ps[k])
					if q != null:
						ps[k] = q
				tr_g = ", ".join(ps)
			out += String(tr_g) if tr_g != null else g
		elif body.begins_with("m"):
			out += m.get_string(int(body.substr(1))).replace(".", ",").replace("$", "")
		elif body.begins_with("p"):
			var parts := body.split(":")
			var n := m.get_string(int(parts[0].substr(1)))
			out += (parts[1] if parts.size() > 1 else "") if n == "1" else (parts[2] if parts.size() > 2 else "s")
		else:
			out += m.get_string(int(body))
	return out

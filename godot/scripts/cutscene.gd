class_name Cutscene
extends CanvasLayer
## Cerita pembuka: beberapa adegan ilustrasi dengan gerak kamera pelan (Ken Burns),
## teks mengetik, lalu pemain memberi nama kost-nya. Ketuk untuk lanjut, bisa dilewati.

signal finished(kost_name: String)

var ui: Node
var font: Font
var art: Texture2D
var root: Control
var stage: Control
var text_lbl: Label
var who_lbl: Label
var box: PanelContainer
var idx := -1
var typing: Tween
var cam: Tween
var scenes: Array = []
var name_mode := false
var _cur_name := "Kost Harmoni"


func setup(p_ui: Node, p_font: Font, p_art: Texture2D, cur_name: String) -> void:
	ui = p_ui
	font = p_font
	art = p_art
	_cur_name = cur_name
	layer = 60
	root = Control.new()
	root.size = Vector2(D.IW, D.IH)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("1d1a24")
	bg.size = root.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	stage = Control.new()
	stage.size = root.size
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage)
	# Kotak teks di bawah
	box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.984, 0.96, 0.918, 0.97)
	sb.border_color = D.C_LINE
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(40)
	sb.content_margin_left = 54
	sb.content_margin_right = 54
	sb.content_margin_top = 36
	sb.content_margin_bottom = 44
	box.add_theme_stylebox_override("panel", sb)
	box.position = Vector2(60, 1960)
	box.size = Vector2(D.IW - 120, 380)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(v)
	who_lbl = _lbl("", 44, Color("b06a3b"))
	v.add_child(who_lbl)
	text_lbl = _lbl("", 52, D.C_INK)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.custom_minimum_size.x = D.IW - 240
	v.add_child(text_lbl)
	var hint := _lbl("Ketuk untuk lanjut", 32, Color("9a8068"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)
	root.add_child(box)
	var skip: Button = ui._btn("Lewati", D.C_CREAM, func(): _finish(_cur_name))
	skip.position = Vector2(D.IW - 300, 80)
	root.add_child(skip)
	root.gui_input.connect(_on_input)
	scenes = [
		{"bg": "office", "who": "", "t": "Jakarta, pukul 23.40. Maryam masih di kantor: eksekutif muda yang hidupnya habis untuk rapat, target, dan lembur."},
		{"bg": "letter", "who": "", "t": "Malam itu, sepucuk surat dari Nenek menunggunya di meja."},
		{"bg": "resign", "who": "Maryam", "t": "\"Sudah cukup. Nenek benar, aku harus pulang.\" Besok paginya, Maryam mengirim surat pengunduran diri."},
		{"bg": "old", "who": "", "t": "Kost peninggalan Nenek sudah lama sepi. Kamarnya kosong, catnya pudar, debunya di mana-mana."},
		{"bg": "lobby", "who": "Maryam", "t": "\"Mulai hari ini aku penjaga kost ini. Tenang, Nek. Tempat ini bakal hangat lagi!\""},
		{"bg": "lobby2", "who": "Maryam", "t": "\"Pelan-pelan saja: satu kamar, satu penghuni, satu senyum. Kamu bantu aku, ya?\""},
		{"bg": "name", "who": "Maryam", "t": "\"Oh iya, kost ini enaknya dikasih nama apa, ya?\""},
	]
	_next()


func _lbl(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _on_input(e: InputEvent) -> void:
	if name_mode:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var on_name: bool = scenes[idx].bg == "name"
		if typing and typing.is_running():
			typing.kill()
			text_lbl.visible_ratio = 1.0
			if on_name: _ask_name()
		elif on_name:
			_ask_name()
		else:
			_next()


func _next() -> void:
	idx += 1
	if idx >= scenes.size():
		_finish(_cur_name)
		return
	var sc: Dictionary = scenes[idx]
	var old := stage.get_children()
	var layer_c := _build(sc.bg)
	_no_mouse(layer_c)
	layer_c.modulate.a = 0.0
	stage.add_child(layer_c)
	var tw := create_tween()
	tw.tween_property(layer_c, "modulate:a", 1.0, 0.7)
	tw.tween_callback(func():
		for o in old: o.queue_free())
	who_lbl.text = sc.who
	who_lbl.visible = sc.who != ""
	text_lbl.text = sc.t
	text_lbl.visible_ratio = 0.0
	typing = create_tween()
	typing.tween_property(text_lbl, "visible_ratio", 1.0, sc.t.length() * 0.035)
	if sc.bg == "name":
		typing.tween_callback(_ask_name)


## Semua isi adegan tembus sentuhan, supaya ketukan sampai ke root (lanjut adegan).
func _no_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in n.get_children():
		_no_mouse(ch)


# ---------- Adegan ----------
func _tex_rect(tex: Texture2D, region: Rect2, pos: Vector2, size: Vector2) -> TextureRect:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region
	var tr := TextureRect.new()
	tr.texture = at
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = pos
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Gerak kamera pelan: geser + zoom dari a ke b.
func _ken(node: Control, from_scale: float, to_scale: float, from_pos: Vector2, to_pos: Vector2, dur: float = 9.0) -> void:
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2.ONE * from_scale
	node.position = from_pos
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "scale", Vector2.ONE * to_scale, dur)
	t.tween_property(node, "position", to_pos, dur)


func _build(kind: String) -> Control:
	var c := Control.new()
	c.size = root.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match kind:
		"city":
			var sky := ColorRect.new()
			sky.color = Color("262a45")
			sky.size = c.size
			c.add_child(sky)
			c.add_child(_Moon.new())
			var b := _tex_rect(art, Rect2(0, 190, D.IW, D.LOBBY_TOP + 410), Vector2(0, 360), Vector2(D.IW, D.LOBBY_TOP + 410))
			b.modulate = Color(0.42, 0.45, 0.68)
			c.add_child(b)
			_ken(b, 1.0, 1.12, Vector2(0, 420), Vector2(0, 300))
		"letter":
			var desk := ColorRect.new()
			desk.color = Color("b8835a")
			desk.size = c.size
			c.add_child(desk)
			var paper := PanelContainer.new()
			var ps := StyleBoxFlat.new()
			ps.bg_color = Color("fbf3e2")
			ps.border_color = D.C_LINE
			ps.set_border_width_all(5)
			ps.set_corner_radius_all(14)
			ps.content_margin_left = 80
			ps.content_margin_right = 80
			ps.content_margin_top = 80
			ps.content_margin_bottom = 80
			ps.shadow_color = Color(0, 0, 0, 0.25)
			ps.shadow_size = 18
			paper.add_theme_stylebox_override("panel", ps)
			paper.size = Vector2(1060, 1300)
			paper.position = Vector2(189, 300)
			paper.rotation = -0.04
			var lt := _lbl("Maryam, cucuku sayang,\n\nNenek sudah terlalu sepuh untuk mengurus kost tua kita. Mulai sekarang kost itu milikmu.\n\nNenek tahu kamu lelah di kota. Pulanglah, jadikan kost itu rumah yang hangat untuk anak-anak rantau.\n\nPeluk dari jauh,\nNenek", 54, Color("4a3626"))
			lt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lt.custom_minimum_size.x = 900
			paper.add_child(lt)
			c.add_child(paper)
			_ken(paper, 0.94, 1.0, Vector2(189, 330), Vector2(189, 280), 7.0)
		"office", "resign":
			# Ilustrasi kantor utuh (malam lembur / pagi resign), kamera pelan mendekat.
			var tex: Texture2D = load("res://assets/story/office_%s.jpg" % kind)
			var b := _tex_rect(tex, Rect2(Vector2.ZERO, tex.get_size()), Vector2.ZERO, Vector2(D.IW, D.IH))
			c.add_child(b)
			_ken(b, 1.0, 1.06, Vector2.ZERO, Vector2(0, -30), 9.0)
		"old":
			var bg := ColorRect.new()
			bg.color = Color("efe3cf")
			bg.size = c.size
			c.add_child(bg)
			var shell: Texture2D = load("res://assets/kost-shell.jpg")
			var b := _tex_rect(shell, Rect2(0, 200, D.IW, 1640), Vector2(0, 160), Vector2(D.IW, 1640))
			b.modulate = Color(0.78, 0.72, 0.66)
			c.add_child(b)
			_ken(b, 1.0, 1.25, Vector2(0, 180), Vector2(0, 120), 10.0)
		"lobby", "lobby2", "name":
			var l := _tex_rect(art, Rect2(0, D.LOBBY_TOP, D.IW, 600), Vector2(0, 0), Vector2(D.IW, 1880))
			l.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			c.add_child(l)
			_ken(l, 1.25, 1.1, Vector2(-120, 0), Vector2(0, 0), 10.0)
			var keeper := TextureRect.new()
			keeper.texture = load("res://assets/chars/penjaga/happy_L.png")
			keeper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			keeper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
			keeper.size = Vector2(700, 1180)
			keeper.position = Vector2(370 if kind != "lobby" else 900, 700)
			keeper.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(keeper)
			if kind == "lobby":
				var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				t.tween_property(keeper, "position:x", 370.0, 0.9)
	return c


# ---------- Nama kost ----------
func _ask_name() -> void:
	if name_mode:
		return
	name_mode = true
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = D.C_PAPER
	sb.border_color = D.C_LINE
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(40)
	sb.content_margin_left = 50
	sb.content_margin_right = 50
	sb.content_margin_top = 40
	sb.content_margin_bottom = 40
	p.add_theme_stylebox_override("panel", sb)
	p.position = Vector2(100, 1180)
	p.size = Vector2(D.IW - 200, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 24)
	p.add_child(v)
	v.add_child(_lbl("Nama kost-mu", 46, D.C_INK))
	var le := LineEdit.new()
	le.text = _cur_name
	le.max_length = 22
	le.add_theme_font_override("font", font)
	le.add_theme_font_size_override("font_size", 56)
	le.custom_minimum_size = Vector2(0, 110)
	var ls := StyleBoxFlat.new()
	ls.bg_color = Color.WHITE
	ls.border_color = D.C_LINE
	ls.set_border_width_all(5)
	ls.set_corner_radius_all(22)
	ls.content_margin_left = 26
	ls.content_margin_right = 26
	le.add_theme_stylebox_override("normal", ls)
	le.add_theme_stylebox_override("focus", ls)
	le.add_theme_color_override("font_color", D.C_INK)
	le.add_theme_color_override("caret_color", D.C_INK)
	v.add_child(le)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	if OS.has_feature("web"):
		row.add_child(ui._btn("Ketik nama", D.C_CREAM, func():
			var r = JavaScriptBridge.eval("window.prompt('Nama kost kamu?', %s)" % JSON.stringify(le.text))
			if r != null and str(r).strip_edges() != "":
				le.text = str(r).strip_edges().left(22)))
	row.add_child(ui._btn("Buka Kost!", D.C_YELLOW, func():
		var nm := le.text.strip_edges()
		if nm == "": nm = "Kost Harmoni"
		_finish(nm)))
	root.add_child(p)


func _finish(nm: String) -> void:
	finished.emit(nm)
	var t := create_tween()
	t.tween_property(root, "modulate:a", 0.0, 0.5)
	t.tween_callback(queue_free)


class _Moon extends Control:
	func _ready() -> void:
		size = Vector2(D.IW, 500)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_circle(Vector2(1100, 260), 110, Color("f6dd9a"))
		draw_circle(Vector2(1150, 225), 104, Color("262a45"))
		for s in [Vector2(160, 140), Vector2(380, 300), Vector2(640, 110), Vector2(820, 380), Vector2(1300, 470), Vector2(90, 420), Vector2(520, 520)]:
			draw_circle(s, 6, Color("f6dd9a"))


## Jendela-jendela kota yang menyala satu per satu.
class _Windows extends Control:
	var t := 0.0
	func _ready() -> void:
		size = Vector2(D.IW, D.IH)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		var pts := [Vector2(380, 900), Vector2(1000, 900), Vector2(380, 1290), Vector2(1000, 1290), Vector2(380, 1680), Vector2(1000, 1680)]
		for i in range(pts.size()):
			var a := clampf(t * 0.8 - i * 0.6, 0.0, 1.0)
			draw_circle(pts[i], 150, Color(1, 0.85, 0.5, 0.18 * a))

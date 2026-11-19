class_name Tutorial
extends Control
## Tutorial interaktif: Mariam memberi satu tugas per langkah, panah menunjuk ke tempat
## yang harus disentuh, dan langkah berikutnya terbuka begitu tugasnya benar-benar dikerjakan.

var game: Node
var ui: Node
var font: Font
var bubble: PanelContainer
var text_lbl: Label
var next_btn: Button
var arrow: _Arrow
var ring: _Ring
var arrow2: _Arrow
var ring2: _Ring
var tag1: PanelContainer
var tag2: PanelContainer
var dot: _Dot
var step := 0
var _base := {}
var _t := 0.0

const NAV := {"beli": Vector2(204, 2440), "penyewa": Vector2(545, 2440), "karyawan": Vector2(890, 2440), "kelola": Vector2(1232, 2440), "jam": Vector2(1220, 175)}


func setup(p_game: Node, p_ui: Node, p_font: Font) -> void:
	game = p_game
	ui = p_ui
	font = p_font
	size = Vector2(D.IW, D.IH)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring = _Ring.new()
	add_child(ring)
	ring2 = _Ring.new()
	add_child(ring2)
	dot = _Dot.new()
	add_child(dot)
	arrow = _Arrow.new()
	add_child(arrow)
	arrow2 = _Arrow.new()
	add_child(arrow2)
	tag1 = _tag()
	tag2 = _tag()
	bubble = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffaf0")
	sb.border_color = D.C_LINE
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(36)
	sb.content_margin_left = 30
	sb.content_margin_right = 36
	sb.content_margin_top = 24
	sb.content_margin_bottom = 26
	sb.shadow_color = Color(0.24, 0.16, 0.1, 0.25)
	sb.shadow_offset = Vector2(0, 8)
	bubble.add_theme_stylebox_override("panel", sb)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(h)
	var face := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/chars/penjaga/happy_L.png")
	at.region = Rect2(20, 0, 170, 150)
	face.texture = at
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(150, 140)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(face)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var who := Label.new()
	who.text = "Mariam · Tutorial"
	who.add_theme_font_override("font", font)
	who.add_theme_font_size_override("font_size", 32)
	who.add_theme_color_override("font_color", Color("b06a3b"))
	v.add_child(who)
	text_lbl = Label.new()
	text_lbl.add_theme_font_override("font", font)
	text_lbl.add_theme_font_size_override("font_size", 40)
	text_lbl.add_theme_color_override("font_color", D.C_INK)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.custom_minimum_size.x = 1020
	v.add_child(text_lbl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var skip: Button = ui._btn("Lewati tutorial", D.C_CREAM, func(): finish(true))
	skip.add_theme_font_size_override("font_size", 30)
	row.add_child(skip)
	next_btn = ui._btn("Lanjut", D.C_YELLOW, func(): _advance())
	row.add_child(next_btn)
	add_child(bubble)
	bubble.position = Vector2(40, 220)
	bubble.size = Vector2(D.IW - 80, 0)


## Label aksi di atas panah: Tap / Hold / Drop.
func _tag() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("6b4f3a")
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 2
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", Color("fff2dc"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	add_child(p)
	return p


func _place(a: _Arrow, r: _Ring, tg: PanelContainer, p: Vector2, label: String, force_down: int = 0) -> void:
	var up: bool = p.y > 1300 if force_down == 0 else force_down > 0
	var bob := sin(_t * 6.0) * 22.0
	a.visible = true
	r.visible = true
	tg.visible = true
	a.down = up
	a.position = p + Vector2(0, (-150 - bob) if up else (150 + bob))
	a.queue_redraw()
	r.position = p
	r.r = 90.0 + sin(_t * 4.0) * 10.0
	r.queue_redraw()
	(tg.get_child(0) as Label).text = label
	tg.reset_size()
	tg.position = a.position + Vector2(-tg.size.x / 2.0, (-150 - tg.size.y) if up else 90)


func start(from: int = 0) -> void:
	step = from
	visible = true
	_enter()


func _kost() -> String:
	return str(game.S.get("kost_name", "Kost Harmoni"))


func _steps() -> Array:
	return [
		{"t": "Halo Juragan! Saya Mariam. Yuk saya tunjukkan cara mengelola %s, pelan-pelan saja." % _kost(), "manual": true},
		{"t": "Ada calon penyewa datang ke lobi. Ketuk tombol Penyewa untuk melihat profilnya.", "at": "penyewa"},
		{"t": "Sebelum menerima, cek dulu latar belakangnya: ketuk \"Cek KTP & slip gaji\". Penyewa yang sering telat bayar bikin rugi!", "top": true},
		{"t": "Kalau aman, tutup panel ini. Lalu Hold (tahan) calon penyewa di lobi, seret, dan Drop (lepas) di kamar kosong.", "at": "room", "from": "guest"},
		{"t": "Kamar makin nyaman & sewanya makin mahal kalau perabotnya lengkap. Ketuk Beli, lalu pilih Lampu.", "at": "beli"},
		{"t": "Pickup sedang datang membawa kotaknya. Begitu kotak muncul, Hold (tahan) kotaknya, seret, lalu Drop (lepas) di kamar.", "at": "boxroom", "from": "box"},
		{"t": "Andi si kurir akan mengantar ke kamar. Sekarang ketuk Karyawan dan rekrut Ryan, petugas kebersihan.", "at": "karyawan"},
		{"t": "Terakhir: ketuk jam di kanan atas untuk mempercepat waktu.", "at": "jam"},
		{"t": "Mantap, Juragan! %s siap berkembang. Kalau ada masalah, cek menu Kelola ya. Semangat!" % _kost(), "manual": true, "end": true},
	]


func _enter() -> void:
	var st: Dictionary = _steps()[step]
	text_lbl.text = st.t
	next_btn.visible = st.get("manual", false)
	next_btn.text = "Selesai" if st.get("end", false) else "Lanjut"
	var S: Dictionary = game.S
	_base = {"tenants": game.each_tenant().size(), "speed": int(S.speed), "jobs": S.jobs.size(), "orders": S.get("orders", []).size() + S.cargo.size()}
	if step == 1 and S.queue.is_empty():
		S.next_cand = 0.0     # datangkan calon penyewa sekarang
	game.S.tut = step
	bubble.position.y = 220 if not st.get("top_low", false) else 1200
	bubble.reset_size()


func _advance() -> void:
	if step >= _steps().size() - 1:
		finish(false)
		return
	step += 1
	_enter()


func finish(skipped: bool) -> void:
	game.S.tut = -1
	visible = false
	if skipped:
		ui.toast("Tutorial dilewati. Bisa diulang dari menu Kelola.")
	game.save_game()


func _done() -> bool:
	var S: Dictionary = game.S
	match step:
		1: return ui.kind == "tenants" and S.queue.size() > 0
		2:
			if S.queue.is_empty(): return true
			return S.queue[0].get("checked", {}).has("kerja")
		3: return game.each_tenant().size() > int(_base.tenants)
		4: return S.get("orders", []).size() + S.cargo.size() > int(_base.orders) or _has_job("deliver")
		5: return _has_job("deliver")
		6: return S.staff.get("cleaner", false)
		7: return int(S.speed) != int(_base.speed)
	return false


func _has_job(t: String) -> bool:
	for j in game.S.jobs:
		if j.type == t: return true
	return false


func _room_center(id: String) -> Vector2:
	var r := D.rect_of(id)
	return game.bld.get_global_transform() * (r.position + Vector2(r.size.x / 2.0, r.size.y * 0.55))


func _source() -> Variant:
	var st: Dictionary = _steps()[step]
	match st.get("from", ""):
		"guest":
			var S: Dictionary = game.S
			if S.queue.is_empty() or not game.npcs.has(S.queue[0].id): return null
			var n: Node2D = game.npcs[S.queue[0].id]
			if n.scene != "lobby": return null
			return n.global_position + Vector2(0, -95)
		"box":
			if game.S.cargo.size() > 0 and game.box_nodes.size() > 0:
				return game.box_nodes[0].get_global_transform() * Vector2(0, -30)
	return null


func _target() -> Variant:
	var st: Dictionary = _steps()[step]
	var at: String = st.get("at", "")
	if NAV.has(at):
		return NAV[at]
	match at:
		"room":
			var er: Array = game.empty_rooms()
			if er.is_empty(): return null
			var r := D.rect_of(er[0])
			return game.bld.get_global_transform() * (r.position + Vector2(r.size.x / 2.0, r.size.y * 0.35))
		"boxroom":
			# Kamar tujuan kotak lampu: kamar terbangun yang belum punya lampu.
			if game.S.cargo.is_empty(): return null
			for id in D.ROOMS:
				var r: Dictionary = game.S.rooms[id]
				if r.built and not r.furn.has("lampu"): return _room_center(id)
			for id in D.ROOMS:
				if game.S.rooms[id].built: return _room_center(id)
			return null
		"truck":
			if game.S.cargo.size() > 0 and game.box_nodes.size() > 0:
				return game.box_nodes[0].get_global_transform() * Vector2(0, -40)
			return Vector2(D.TRUCK_X + 140, 2150)
	return null


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	if not _steps()[step].get("manual", false) and _done():
		_advance()
		return
	var tp = _target()
	var sp = _source()
	var st: Dictionary = _steps()[step]
	# Saat panel terbuka, panah ke dunia disembunyikan (kecuali tombol navigasi).
	var hide_world: bool = ui.kind != "" and st.get("at", "") in ["room", "boxroom", "truck"]
	for c in [arrow, ring, arrow2, ring2, tag1, tag2, dot]:
		c.visible = false
	if hide_world:
		return
	if st.has("from"):
		# Hold di sumber, Drop di tujuan, titik bergerak menunjukkan arah seret.
		if sp != null:
			_place(arrow2, ring2, tag2, sp, "Hold")
		elif st.from == "box":
			_place(arrow2, ring2, tag2, Vector2(D.TRUCK_X + 140, 2150), "Tunggu pickup")
		if tp != null:
			_place(arrow, ring, tag1, tp, "Drop", 1)
		if sp != null and tp != null:
			dot.visible = true
			var k := fmod(_t * 0.6, 1.0)
			dot.position = (sp as Vector2).lerp(tp, k)
			dot.modulate.a = sin(k * PI)
	elif tp != null:
		_place(arrow, ring, tag1, tp, "Tap")
	# Gelembung tutorial jangan menutupi panel yang sedang dipakai.


class _Arrow extends Control:
	var down := true
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var s := 1.0 if down else -1.0
		var pts := PackedVector2Array([Vector2(-46, -70 * s), Vector2(46, -70 * s), Vector2(46, 0), Vector2(80, 0), Vector2(0, 80 * s), Vector2(-80, 0), Vector2(-46, 0)])
		draw_colored_polygon(pts, Color("f7d36e"))
		pts.append(pts[0])
		draw_polyline(pts, Color("6b4f3a"), 8.0, true)


class _Dot extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 30, Color(1, 0.85, 0.35, 0.95))
		draw_arc(Vector2.ZERO, 30, 0, TAU, 32, Color("6b4f3a"), 6.0, true)


class _Ring extends Control:
	var r := 90.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(1, 0.85, 0.35, 0.9), 10.0, true)

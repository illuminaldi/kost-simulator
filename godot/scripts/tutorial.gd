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
	arrow = _Arrow.new()
	add_child(arrow)
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
		{"t": "Kalau aman, tutup panel ini, lalu tahan & seret calon penyewa ke kamar kosong yang ditandai.", "at": "room"},
		{"t": "Kamar makin nyaman & sewanya makin mahal kalau perabotnya lengkap. Ketuk Beli, lalu pilih Lampu.", "at": "beli"},
		{"t": "Pickup sedang datang membawa kotaknya. Begitu kotak muncul, tahan & seret kotaknya ke kamar.", "at": "truck"},
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
	# Saat panel terbuka, panah ke dunia disembunyikan (kecuali tombol navigasi).
	var st: Dictionary = _steps()[step]
	var hide_world: bool = ui.kind != "" and st.get("at", "") in ["room", "truck"]
	arrow.visible = tp != null and not hide_world
	ring.visible = arrow.visible
	if arrow.visible:
		var p: Vector2 = tp
		var up: bool = p.y > 1300     # target di bawah: panah menunjuk ke bawah dari atasnya
		arrow.position = p + Vector2(0, (-150 if up else 150) - sin(_t * 6.0) * 22.0 * (1 if up else -1))
		arrow.down = up
		arrow.queue_redraw()
		ring.position = p
		ring.r = 90.0 + sin(_t * 4.0) * 10.0
		ring.queue_redraw()
	# Gelembung tutorial jangan menutupi panel yang sedang dipakai.
	bubble.position.y = 220 if (ui.kind == "" or step == 2) else 220


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


class _Ring extends Control:
	var r := 90.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(1, 0.85, 0.35, 0.9), 10.0, true)

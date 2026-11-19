class_name BrandIntro
extends CanvasLayer
## Pembuka sebelum game: animasi KelolaPro → KostTerdekat → splash Cozy Kost.
## Diambil dari splash di aplikasi KelolaPro (logo + tagline) dan KostTerdekat (Mpus cari kost).
## Layar KelolaPro sama dengan layar loading; menunggu ketukan (supaya suara boleh diputar di browser).
## Ketuk layar untuk lompat ke adegan berikutnya.

signal finished

var font: Font
var root: Control
var scene_i := -1
var cur: Control
var _busy := false
var sound := true
var auto_tap := false
var _waiting := false
var _player: AudioStreamPlayer

const W := 1438.0
const H := 2576.0


func setup(p_font: Font, p_sound := true, p_auto := false) -> void:
	font = p_font
	sound = p_sound
	auto_tap = p_auto
	_player = AudioStreamPlayer.new()
	add_child(_player)
	layer = 70
	root = Control.new()
	root.size = Vector2(W, H)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if _waiting: _start()
			else: _next())
	_next()


func _play(nm: String) -> void:
	if not sound: return
	_player.stream = load("res://assets/sfx/%s.wav" % nm)
	_player.volume_db = -3.0
	_player.play()


## Ketukan pertama di layar KelolaPro: bunyikan denting, lalu lanjut.
var _tap_lbl: Label


func _start() -> void:
	_waiting = false
	_play("brand_kelolapro")
	if _tap_lbl:
		_tap_lbl.create_tween().tween_property(_tap_lbl, "modulate:a", 0.0, 0.3)
	var my := scene_i
	get_tree().create_timer(1.8).timeout.connect(func():
		if scene_i == my: _next())


func _next() -> void:
	if _busy: return
	scene_i += 1
	var old := cur
	match scene_i:
		0: cur = _kelolapro()
		1: cur = _kostterdekat()
		2: cur = _cozy()
		_:
			_busy = true
			var t := create_tween()
			t.tween_property(root, "modulate:a", 0.0, 0.45)
			t.tween_callback(func():
				finished.emit()
				queue_free())
			return
	cur.modulate.a = 0.0 if scene_i > 0 else 1.0
	root.add_child(cur)
	if scene_i == 1: _play("brand_kostterdekat")
	elif scene_i == 2: _play("brand_cozy")
	var tw := create_tween()
	tw.tween_property(cur, "modulate:a", 1.0, 0.35)
	if old:
		tw.parallel().tween_property(old, "modulate:a", 0.0, 0.35)
		tw.tween_callback(old.queue_free)
	if scene_i == 0:
		_waiting = true
		if auto_tap: get_tree().create_timer(0.6).timeout.connect(_start)
		return
	var dur: float = [0.0, 4.4, 6.5][scene_i]
	var my := scene_i
	get_tree().create_timer(dur).timeout.connect(func():
		if scene_i == my: _next())


# ---------- helpers ----------
func _lbl(t: String, size: int, col: Color, center := true) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(W, size * 1.4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _img(path: String, w: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	var s: Vector2 = tr.texture.get_size()
	tr.size = Vector2(w, w * s.y / s.x)
	tr.pivot_offset = tr.size / 2.0
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _grad(c1: Color, c2: Color, radial := false) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 456
	if radial:
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.45)
		gt.fill_to = Vector2(1.05, 0.95)
	else:
		gt.fill_from = Vector2(0.5, 0)
		gt.fill_to = Vector2(0.5, 1)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.size = Vector2(W, H)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _box() -> Control:
	var c := Control.new()
	c.size = Vector2(W, H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# ---------- 1. KelolaPro ----------
func _kelolapro() -> Control:
	# Sama persis dengan layar loading (boot splash), jadi peralihannya mulus.
	var c := _box()
	var bg := TextureRect.new()
	bg.texture = load("res://assets/brand/kelolapro_splash.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = Vector2(W, H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	_tap_lbl = _lbl("Ketuk untuk mulai", 50, Color("285a9c"))
	_tap_lbl.position = Vector2(0, 2150)
	c.add_child(_tap_lbl)
	var tw := c.create_tween().set_loops()
	tw.tween_property(_tap_lbl, "modulate:a", 0.35, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_tap_lbl, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	return c


# ---------- 2. KostTerdekat: Mpus nyari kost ----------
func _kostterdekat() -> Control:
	var c := _box()
	c.add_child(_grad(Color("ffe08a"), Color("f2ae34"), true))
	var hunt := _Hunt.new()
	hunt.font = font
	hunt.position = Vector2((W - 900) / 2.0, 560)
	c.add_child(hunt)
	var brand := _lbl("KostTerdekat", 96, Color("1e4578"))
	brand.position = Vector2(0, 1300)
	c.add_child(brand)
	var tag := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("285a9c")
	sb.set_corner_radius_all(60)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 10
	sb.content_margin_bottom = 14
	tag.add_theme_stylebox_override("panel", sb)
	tag.add_child(_lbl("AI CARI KOST PLANNER", 38, Color.WHITE, false))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(tag)
	tag.reset_size()
	tag.position = Vector2((W - 600) / 2.0, 1450)
	(func(): tag.position.x = (W - tag.size.x) / 2.0).call_deferred()
	var cap := _lbl("Mpus lagi nyari kost…", 46, Color("6b4a10"))
	cap.position = Vector2(0, 1600)
	c.add_child(cap)
	hunt.cap = cap
	return c


# ---------- 3. Cozy Kost ----------
func _cozy() -> Control:
	var c := _box()
	var bg := ColorRect.new()
	bg.color = Color("f4d8c0")
	bg.size = Vector2(W, H)
	c.add_child(bg)
	var floor_r := ColorRect.new()
	floor_r.color = Color("d9b38a")
	floor_r.position = Vector2(0, H - 612)
	floor_r.size = Vector2(W, 612)
	c.add_child(floor_r)
	var edge := ColorRect.new()
	edge.color = Color("5a3d2b")
	edge.position = Vector2(0, H - 616)
	edge.size = Vector2(W, 16)
	c.add_child(edge)
	var board := _img("res://assets/brand/cozy_board.png", 1172)
	board.pivot_offset = Vector2(586, 0)
	board.position = Vector2(133, -1100)
	c.add_child(board)
	var plate := _img("res://assets/brand/cozy_plate.png", 1103)
	plate.position = Vector2((W - 1103) / 2.0, 1030)
	plate.scale = Vector2.ZERO
	c.add_child(plate)
	var tw := c.create_tween()
	tw.tween_property(board, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(plate, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var sw := c.create_tween().set_loops(3)
	sw.tween_property(board, "rotation", 0.025, 0.45).set_trans(Tween.TRANS_SINE)
	sw.tween_property(board, "rotation", -0.025, 0.45).set_trans(Tween.TRANS_SINE)
	# Barisan karyawan: tanaman, Aji, Maryam, Ryan, Andi, lampu
	var cast := [
		["res://assets/furn/item/tanaman_1.png", 400, 0.0],
		["res://assets/chars/satpam/idle_L.png", 690, -60.0],
		["res://assets/chars/penjaga/happy_L.png", 710, -70.0],
		["res://assets/chars/kebersihan/happy_L.png", 690, -80.0],
		["res://assets/chars/kurir/carry_L.png", 690, -60.0],
		["res://assets/furn/item/lampu_1.png", 330, 0.0],
	]
	var ground := H - 420.0
	var items: Array = []
	var total := 0.0
	for e in cast:
		var tex: Texture2D = load(e[0])
		var hgt: float = e[1]
		var wid := hgt * tex.get_width() / tex.get_height()
		items.append([tex, wid, hgt, float(e[2])])
		total += wid + float(e[2])
	# Muatkan barisan ke lebar layar
	var fit := minf(1.0, (W - 60.0) / total)
	for it in items:
		it[1] *= fit
		it[2] *= fit
		it[3] *= fit
	total *= fit
	var x := (W - total) / 2.0
	var i := 0
	for it in items:
		var tr := TextureRect.new()
		tr.texture = it[0]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.size = Vector2(it[1], it[2])
		tr.pivot_offset = Vector2(it[1] / 2.0, it[2])
		tr.position = Vector2(x, ground - it[2])
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 2: tr.z_index = 2
		c.add_child(tr)
		x += it[1] + it[3]
		var y0 := tr.position.y
		tr.position.y = y0 + 260
		tr.modulate.a = 0.0
		var t2 := c.create_tween()
		t2.tween_interval(1.1 + i * 0.14)
		t2.tween_property(tr, "modulate:a", 1.0, 0.15)
		t2.parallel().tween_property(tr, "position:y", y0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t2.tween_property(tr, "scale", Vector2(1.05, 0.95), 0.12)
		t2.tween_property(tr, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
		i += 1
	return c


class _Circle extends Control:
	var c: Vector2
	var r: float
	var col: Color
	func _init(p_c: Vector2, p_r: float, p_col: Color) -> void:
		c = p_c
		r = p_r
		col = p_col
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(1438, 2576)
	func _draw() -> void:
		draw_circle(c, r, col)


## Mpus menyusuri deretan rumah, lalu loncat senang saat ketemu kost (satu putaran 2,8 detik).
class _Hunt extends Control:
	var t := 0.0
	var font: Font
	var cap: Label
	var a: Texture2D = load("res://assets/brand/mpus_nyelidikin.png")
	var b: Texture2D = load("res://assets/brand/mpus_ketemu.png")
	const T := 2.8
	const K := 3.0   # skala dari CSS (300px) ke layar game (900px)
	func _ready() -> void:
		size = Vector2(900, 690)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(dt: float) -> void:
		t = minf(t + dt, T)
		queue_redraw()
		if cap:
			var p := t / T
			cap.text = "Mpus lagi nyari kost…" if p < 0.33 else ("Ngintip kamar kosong…" if p < 0.6 else "Ketemu yang pas!")
			cap.add_theme_color_override("font_color", Color("1e4578") if p >= 0.6 else Color("6b4a10"))
	func _house(o: Vector2, roof: Color, wall: Color, target: bool, sq: Vector2) -> void:
		var k := K * 1.15
		var tr := Transform2D(0, sq * k, 0, o)
		draw_set_transform_matrix(tr)
		var ink := Color("3a2f55")
		draw_colored_polygon(PackedVector2Array([Vector2(-22, -30), Vector2(0, -48), Vector2(22, -30)]), roof)
		draw_rect(Rect2(-17, -31, 34, 27), wall)
		draw_rect(Rect2(-17, -31, 34, 27), ink, false, 1.2)
		draw_polyline(PackedVector2Array([Vector2(-22, -30), Vector2(0, -48), Vector2(22, -30)]), ink, 1.2)
		draw_rect(Rect2(-5, -20, 10, 16), ink)
		var win := Color("ffd84d") if target else Color("cfe6ff")
		draw_rect(Rect2(-13, -25, 6, 6), win)
		draw_rect(Rect2(7, -25, 6, 6), win)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	func _draw() -> void:
		var p := t / T
		# jalan
		draw_rect(Rect2(14 * K, 204 * K - 30, 272 * K, 4 * K), Color(0.227, 0.184, 0.333, 0.18))
		# deretan rumah bergeser ke kiri sampai 58%
		var shift := -320.0 * K * clampf(p / 0.58, 0, 1)
		var cols := [[Color("9ad0ff"), Color.WHITE], [Color("c7b8ff"), Color("fff6e0")], [Color("9be3c3"), Color.WHITE], [Color("ff7a45"), Color("fff1c9")]]
		for i in range(4):
			var hx := (300 + 28 + i * 80) * K + shift
			if hx < -60 or hx > 960: continue
			var target := i == 3
			var sq := Vector2.ONE
			if target and p > 0.58 and p < 0.76:
				var q := (p - 0.58) / 0.18
				sq = Vector2(1.0 + 0.18 * sin(q * PI), 1.0 - 0.12 * sin(q * PI))
			_house(Vector2(hx, 200 * K - 30), cols[i][0], cols[i][1], target, sq)
			if not target and font:
				draw_string(font, Vector2(hx - 12, 200 * K - 30 - 62 * K + sin(t * 7.0 + i) * 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(0.227, 0.184, 0.333, 0.55))
			if target and p > 0.6:
				var pin_y := 200 * K - 30 - 74 * K + (0.0 if p > 0.66 else -90 * (0.66 - p) / 0.06)
				draw_circle(Vector2(hx, pin_y), 30, Color("ff5a3c"))
				draw_colored_polygon(PackedVector2Array([Vector2(hx - 22, pin_y + 14), Vector2(hx + 22, pin_y + 14), Vector2(hx, pin_y + 52)]), Color("ff5a3c"))
				draw_circle(Vector2(hx, pin_y), 11, Color.WHITE)
		# Mpus
		var cy := 0.0
		var rot := 0.0
		var sc := Vector2.ONE
		if p < 0.58:
			var ph := fmod(p, 0.1) / 0.1
			cy = -7 * K * sin(ph * PI)
			rot = deg_to_rad(3.0 * cos(ph * TAU))
		elif p < 0.66:
			var q := (p - 0.58) / 0.08
			cy = -26 * K * q
			sc = Vector2(1.04 - 0.07 * q, 0.94 + 0.11 * q)
		elif p < 0.74:
			var q2 := (p - 0.66) / 0.08
			cy = -26 * K * (1.0 - q2)
		var tex := a if p < 0.6 else b
		var cs := 150.0 * K
		var base := Vector2(34 * K + cs / 2.0, 230 * K - 22 * K)
		draw_set_transform(base + Vector2(0, cy), rot, sc)
		draw_texture_rect(tex, Rect2(-cs / 2.0, -cs, cs, cs), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		# Ketemu!
		if p > 0.62 and font:
			var bx := 186 * K
			var by := 36 * K
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color.WHITE
			sb.set_corner_radius_all(48)
			draw_style_box(sb, Rect2(bx, by, 300, 96))
			draw_string(font, Vector2(bx, by + 68), "Ketemu!", HORIZONTAL_ALIGNMENT_CENTER, 300, 52, Color("ff5a3c"))
			for s in [Vector2(196, 70), Vector2(262, 96), Vector2(20, 54)]:
				var cpos: Vector2 = s * K + Vector2(20, 20)
				var pts := PackedVector2Array()
				for k in range(8):
					var rr := 26.0 if k % 2 == 0 else 8.0
					pts.append(cpos + Vector2(cos(k * PI / 4.0 - PI / 2), sin(k * PI / 4.0 - PI / 2)) * rr)
				draw_colored_polygon(pts, Color("ffb000"))

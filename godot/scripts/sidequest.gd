class_name SideQuest
extends Control
## Jalan-jalan Maryam: geser lobi ke kiri/kanan saat Maryam ada di meja.
## Kiri: Kost → jalan kota → Cafe Book → taman → Lapangan Padel → (kota) → Kost.
## Kanan: urutan sebaliknya. Di Cafe Book & Padel ada permainan kecil.

const RING := ["kost", "cafe", "padel"]
# Pemandangan di antara dua tujuan, searah "kiri" (indeks naik).
const SCENERY := {"kost>cafe": "kota", "cafe>padel": "taman", "padel>kost": "kota"}
const NAMES := {"kost": "Kost", "cafe": "Cafe Book", "padel": "Lapangan Padel", "kota": "Jalan Kota", "taman": "Taman Kota"}

var game: Node
var ui: Node
var font: Font
var loc := "kost"
var view := ""             # walk / cafe_ext / cafe_in / padel
var _layer: Control
var _press := Vector2.ZERO
var _pressed := false
var _swiped := false


func setup(g: Node, u: Node, f: Font) -> void:
	game = g
	ui = u
	font = f
	position = Vector2.ZERO
	size = Vector2(D.IW, D.IH)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func active() -> bool:
	return visible


## dir: -1 = geser ke kiri (jalan ke kiri), +1 = geser ke kanan.
func start(dir: int) -> void:
	visible = true
	loc = "kost"
	ui.set_nav_visible(false)
	_walk(dir)


func _close() -> void:
	_clear()
	visible = false
	view = ""
	loc = "kost"
	ui.set_nav_visible(true)


func _clear() -> void:
	if _layer: _layer.queue_free()
	_layer = Control.new()
	_layer.size = size
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)


func _next(dir: int) -> String:
	var i := RING.find(loc)
	return RING[(i + (1 if dir < 0 else -1) + RING.size()) % RING.size()]


# ---------------- Berjalan ----------------
func _walk(dir: int) -> void:
	var to := _next(dir)
	var key: String = ("%s>%s" % [loc, to]) if dir < 0 else ("%s>%s" % [to, loc])
	var theme: String = SCENERY.get(key, "kota")
	_clear()
	view = "walk"
	var w := _Walk.new()
	w.theme = theme
	w.dir = dir
	w.font = font
	w.dest = NAMES[to]
	w.from = NAMES[loc]
	_layer.add_child(w)
	w.done.connect(func(): _arrive(to))
	game.sfx("pop", -12.0)


func _arrive(to: String) -> void:
	loc = to
	match to:
		"kost":
			_close()
			game.keeper_say("Sudah pulang! Kost aman kan?", 2.5)
		"cafe": _show_cafe_ext()
		"padel": _show_padel()


# ---------------- Tampilan bantu ----------------
func _bg(path: String) -> void:
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.size = size
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(tr)


func _hit(r: Rect2, cb: Callable) -> void:
	var b := Button.new()
	b.flat = true
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	var e := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, e)
	b.pressed.connect(cb)
	b.button_down.connect(func(): b.modulate = Color(0.85, 0.85, 0.85))
	b.button_up.connect(func(): b.modulate = Color.WHITE)
	_layer.add_child(b)


func _panel(r: Rect2, col := Color("fbf3e6")) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = r.position
	p.size = r.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = D.C_LINE
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(26)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(p)
	return p


func _lbl(t: String, sz: int, col := D.C_INK, wrap := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Tombol bawah bergaya sama dengan navigasi kost (pil besar, bayangan bawah, teks tebal).
func _bottom(btns: Array, band_y: float = D.NAV_Y - 22) -> void:
	var band := ColorRect.new()
	band.color = Color("b98a5e")
	band.position = Vector2(0, band_y)
	band.size = Vector2(D.IW, D.IH - band_y)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(band)
	var edge := ColorRect.new()
	edge.color = Color("6b4f3a")
	edge.position = band.position
	edge.size = Vector2(D.IW, 8)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(edge)
	var n := btns.size()
	var gap := 26.0
	var w := (D.IW - 52.0 - gap * (n - 1)) / n
	for i in range(n):
		var b: Array = btns[i]
		var r := Rect2(26 + i * (w + gap), D.NAV_Y, w, 170)
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = b[1]
		sb.border_color = D.C_LINE
		sb.set_border_width_all(6)
		sb.set_corner_radius_all(46)
		sb.shadow_color = D.C_LINE
		sb.shadow_offset = Vector2(0, 9)
		sb.shadow_size = 1
		pc.add_theme_stylebox_override("panel", sb)
		pc.position = r.position
		pc.size = r.size - Vector2(0, 10)
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_child(_lbl(b[0], 50 if n <= 3 else 44))
		_layer.add_child(pc)
		_hit(r, b[2])


func _toast_once(key: String) -> bool:
	var S: Dictionary = game.S
	if not S.has("side"): S.side = {}
	if int(S.side.get(key, -1)) == int(S.day): return false
	S.side[key] = int(S.day)
	return true


# ---------------- Cafe Book: tampak luar ----------------
func _show_cafe_ext() -> void:
	_clear()
	view = "cafe_ext"
	_bg("res://assets/side/cafe_ext.jpg")
	var m := TextureRect.new()
	m.texture = load("res://assets/chars/penjaga/happy_L.png")
	m.size = m.texture.get_size() * 1.32
	m.position = Vector2(522 - m.size.x / 2.0, 2095 - m.size.y)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(m)
	var tip := _panel(Rect2(250, 2160, 940, 110), Color(1, 0.98, 0.94, 0.92))
	tip.add_child(_lbl("Geser kiri: ke Lapangan Padel · Geser kanan: pulang", 32, D.C_MUTED, true))
	_bottom([["Masuk Cafe", D.C_GREEN, _show_cafe_in], ["Lanjut ke Padel", D.C_YELLOW, func(): _walk(-1)], ["Balik ke Kost", D.C_PINK, func(): _walk(1)]])


# ---------------- Cafe Book: membaca ----------------
const BOOKS := [
	{"t": "Rahasia Kost Nyaman", "p": [
		"Penghuni betah bukan karena kamar mewah, tapi karena pemiliknya cepat tanggap.",
		"Bersih itu nomor satu. Kamar kotor membuat sewa terasa mahal.",
		"Sapa penghuni setiap pagi. Senyum itu gratis, efeknya mahal.",
		"Perbaikan kecil hari ini mencegah keluhan besar minggu depan.",
		"Fasilitas bersama membuat penghuni saling kenal dan jarang pindah.",
		"Kamu sudah membaca satu buku! Ide baru siap dicoba di kost."]},
	{"t": "Kopi & Ketenangan", "p": [
		"Hirup aroma kopinya dulu. Tidak semua hal harus selesai hari ini.",
		"Istirahat bukan berhenti; istirahat itu mengisi bensin.",
		"Kerja keras itu bagus. Kerja sambil bahagia itu lebih awet.",
		"Rumah yang hangat dimulai dari pemilik yang tidak kelelahan.",
		"Nenek bilang: rawat dirimu, baru rawat orang lain.",
		"Selesai! Maryam merasa jauh lebih segar."]},
	{"t": "Catatan Pengusaha Muda", "p": [
		"Catat semua pemasukan dan pengeluaran, sekecil apa pun.",
		"Harga sewa yang adil membuat kamar jarang kosong.",
		"Dengarkan keluhan: itu daftar perbaikan gratis.",
		"Reputasi dibangun bertahun-tahun, rusak dalam sehari.",
		"Investasi terbaik: kenyamanan penghuni.",
		"Tamat. Saatnya mempraktikkan di kost!"]},
]
var book := 0
var page := 0
var coffee := 1.0
var _page_lbl: Label
var _title_lbl: Label
var _num_lbl: Label
var _coffee_bar: ColorRect


func _show_cafe_in() -> void:
	_clear()
	view = "cafe_in"
	page = 0
	_bg("res://assets/side/cafe_in.jpg")
	# Halaman buku: kertas bersih di atas buku dalam ilustrasi.
	var pg := _panel(Rect2(250, 1150, 940, 640), Color("fdf6e3"))
	pg.rotation = -0.06
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pg.add_child(v)
	_title_lbl = _lbl("", 40, Color("8a5a3a"))
	v.add_child(_title_lbl)
	_page_lbl = _lbl("", 46, D.C_INK, true)
	_page_lbl.custom_minimum_size = Vector2(880, 380)
	v.add_child(_page_lbl)
	_num_lbl = _lbl("", 30, D.C_MUTED)
	v.add_child(_num_lbl)
	# Meter santai (kopi)
	var cp := _panel(Rect2(40, 1990, 520, 90), Color(1, 0.98, 0.94, 0.95))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	cp.add_child(hb)
	hb.add_child(_lbl("Santai", 32))
	var bg := ColorRect.new()
	bg.color = Color("e6d8c2")
	bg.custom_minimum_size = Vector2(320, 30)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(bg)
	_coffee_bar = ColorRect.new()
	_coffee_bar.color = Color("b07a4a")
	_coffee_bar.size = Vector2(320, 30)
	bg.add_child(_coffee_bar)
	# Tombol yang sudah tergambar di ilustrasi (posisi sudah digeser 90 px ke atas).
	_hit(Rect2(70, 1125, 152, 150), func(): _flip(-1))
	_hit(Rect2(1218, 1125, 152, 150), func(): _flip(1))
	_hit(Rect2(1160, 2020, 230, 190), _sip)
	_bottom([["Keluar Cafe", D.C_GREEN, _show_cafe_ext], ["Order Minuman", D.C_PINK, _order],
		["Baca Buku Lain", D.C_YELLOW, func():
			book = (book + 1) % BOOKS.size()
			page = 0
			game.sfx("pop", -6.0)
			_render_book()]], 2262)
	_cafe_hint = _panel(Rect2(360, 2150, 760, 96), Color("5a4434"))
	_cafe_hint_lbl = _lbl("", 32, Color("fff6e6"))
	_cafe_hint.add_child(_cafe_hint_lbl)
	_render_book()


var _cafe_hint: PanelContainer
var _cafe_hint_lbl: Label


func _render_book() -> void:
	var b: Dictionary = BOOKS[book]
	_title_lbl.text = b.t
	_page_lbl.text = b.p[page]
	_num_lbl.text = "Halaman %d / %d" % [page + 1, b.p.size()]
	_coffee_bar.size.x = 320.0 * clampf(coffee, 0, 1)
	if _cafe_hint_lbl:
		var n: int = BOOKS[book].p.size()
		if coffee <= 0.05: _cafe_hint_lbl.text = "Ngantuk... ketuk Hirup Kopi"
		elif page >= n - 1: _cafe_hint_lbl.text = "Tamat! Ganti buku di bawah"
		else: _cafe_hint_lbl.text = "Ketuk panah > untuk halaman %d" % (page + 2)


func _flip(d: int) -> void:
	if coffee <= 0.05 and d > 0:
		game.ui.toast("Maryam mulai ngantuk... hirup kopi dulu atau pesan minuman!", "bad")
		return
	var n: int = BOOKS[book].p.size()
	var np := clampi(page + d, 0, n - 1)
	if np == page: return
	page = np
	if d > 0: coffee = maxf(0.0, coffee - 0.22)
	game.sfx("pop", -8.0)
	if page == n - 1 and _toast_once("baca%d" % book):
		game.add_xp(15)
		for e in game.each_tenant():
			e[1].tenant.happy = clampf(float(e[1].tenant.happy) + 2.0, 0, 100)
		game.maybe_review("baca")
		game.ui.toast("Maryam selesai membaca \"%s\"! +15 XP, penghuni ikut senang (+2)." % BOOKS[book].t, "gold")
	_render_book()


func _sip() -> void:
	if coffee >= 0.99:
		game.ui.toast("Kopinya masih penuh, lanjut baca!")
		return
	coffee = minf(1.0, coffee + 0.35)
	game.ui.toast("Sruput~ Hangat dan wangi.")
	_render_book()


func _order() -> void:
	var c := 25000.0
	if float(game.S.money) < c:
		game.ui.toast(game.ui.money_why(c), "bad"); return
	game.spend(c, "other")
	coffee = 1.0
	game.sfx("buy", -6.0)
	game.ui.toast("Es kopi gula aren datang! (%s)" % D.rp(c), "gold")
	_render_book()


# ---------------- Lapangan Padel ----------------
# Maryam melawan Ryan atau Aji; Kak Ray jadi pelatih di pinggir lapangan.
const FOES := [["Ryan", 0.55, "kebersihan", "happy", "wring"], ["Aji", 0.75, "satpam", "idle", "help"]]
var foe := 0
var pts := [0, 0]
var _score_lbl: Label
var _foe_lbl: Label
var _ball: _Ball
var _msg: Label
var _hint: Label
var _ray_lbl: Label
var _ray_box: PanelContainer
var _mar: TextureRect
var _opp: TextureRect
var _ray: TextureRect
var _tut := 0          # 0 sapa, 1 lihat bola, 2 tunggu lingkaran, 3 pukul!, 4 selesai
var _rally := 0


func _sprite(path: String, sc: float, feet: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.size = tr.texture.get_size() * sc
	tr.position = feet - Vector2(tr.size.x / 2.0, tr.size.y)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.pivot_offset = Vector2(tr.size.x / 2.0, tr.size.y)
	_layer.add_child(tr)
	return tr


func _show_padel() -> void:
	_clear()
	view = "padel"
	_bg("res://assets/side/padel.jpg")
	_opp = _sprite("res://assets/chars/%s/%s_L.png" % [FOES[foe][2], FOES[foe][3]], 0.62, Vector2(800, 1060))
	_ball = _Ball.new()
	_layer.add_child(_ball)
	_ray = _sprite("res://assets/chars/trainer/clip_L.png", 1.15, Vector2(185, 2140))
	_mar = _sprite("res://assets/chars/penjaga/idle_L.png", 1.75, Vector2(820, 2130))
	_ball.player = _mar
	_ball.missed.connect(_point.bind(1))
	_ball.foe_missed.connect(_point.bind(0))
	_ball.hit_ok.connect(_on_hit)
	# Papan skor
	var sp := _panel(Rect2(420, 210, 600, 120))
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 22)
	sp.add_child(hb)
	hb.add_child(_lbl("Maryam", 36))
	_score_lbl = _lbl("0 - 0", 54)
	_score_lbl.custom_minimum_size = Vector2(200, 0)
	hb.add_child(_score_lbl)
	_foe_lbl = _lbl("", 36)
	hb.add_child(_foe_lbl)
	# Pesan besar di tengah lapangan
	_msg = _lbl("", 64, Color("fff6e6"))
	_msg.add_theme_color_override("font_outline_color", D.C_LINE)
	_msg.add_theme_constant_override("outline_size", 16)
	_msg.position = Vector2(0, 1480)
	_msg.size = Vector2(D.IW, 120)
	_layer.add_child(_msg)
	# Gelembung Kak Ray
	_ray_box = _panel(Rect2(40, 1440, 640, 220), Color("fffaf0"))
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	_ray_box.add_child(rv)
	var rn := _lbl("Kak Ray · Pelatih", 30, Color("8a5a3a"))
	rn.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rv.add_child(rn)
	_ray_lbl = _lbl("", 36, D.C_INK, true)
	_ray_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_ray_lbl.custom_minimum_size = Vector2(590, 0)
	rv.add_child(_ray_lbl)
	# Petunjuk yang mengikuti keadaan bola
	_hint = _lbl("", 44, Color("fff6e6"))
	_hint.add_theme_color_override("font_outline_color", D.C_LINE)
	_hint.add_theme_constant_override("outline_size", 12)
	_hint.position = Vector2(0, 2165)
	_hint.size = Vector2(D.IW, 70)
	_layer.add_child(_hint)
	_bottom([["Balik ke Kost", D.C_GREEN, func(): _walk(-1)],
		["Ganti Lawan", D.C_PINK, func():
			foe = (foe + 1) % FOES.size()
			_opp.texture = load("res://assets/chars/%s/%s_L.png" % [FOES[foe][2], FOES[foe][3]])
			_ray_say("Lawan baru: %s! %s" % [FOES[foe][0], "Dia santai, cocok buat pemanasan." if foe == 0 else "Pak Aji pukulannya keras, fokus ya!"])
			_new_match()],
		["Main Lagi", D.C_YELLOW, func():
			_ray_say("Ulang dari nol. Atur napas dulu, Mbak!")
			_new_match()]], 2248)
	var S: Dictionary = game.S
	if not S.has("side"): S.side = {}
	_tut = 4 if S.side.get("padel_tut", false) else 0
	if _tut == 0:
		_ray_say("Halo Mbak Maryam! Aku Kak Ray. Hari ini lawanmu %s. Perhatikan bola dari seberang net, ya." % FOES[foe][0])
	else:
		_ray_say("Selamat datang lagi! Lawanmu %s. Ingat: pukul saat bola masuk lingkaran putih." % FOES[foe][0])
	_new_match()


func _ray_say(t: String) -> void:
	_ray_lbl.text = t
	_ray_box.modulate.a = 1.0
	_ray.texture = load("res://assets/chars/trainer/%s_L.png" % ("happy" if t.find("!") >= 0 else "clip"))


func _new_match() -> void:
	pts = [0, 0]
	_rally = 0
	_foe_lbl.text = FOES[foe][0]
	_ball.skill = float(FOES[foe][1])
	_render_score()
	_ball.serve(2.2 if _tut < 4 else 1.4)


const PT := ["0", "15", "30", "40"]


func _render_score() -> void:
	if pts[0] >= 3 and pts[1] >= 3:
		_score_lbl.text = "Deuce" if pts[0] == pts[1] else ("Adv M" if pts[0] > pts[1] else "Adv " + FOES[foe][0].substr(0, 1))
	else:
		_score_lbl.text = "%s - %s" % [PT[mini(pts[0], 3)], PT[mini(pts[1], 3)]]


func _say(t: String) -> void:
	_msg.text = t
	_msg.modulate.a = 1.0
	var tw := _msg.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_msg, "modulate:a", 0.0, 0.4)


func _process(_dt: float) -> void:
	if view != "padel" or _ball == null: return
	# Lawan bergerak mengikuti bola
	var tx := clampf(_ball.a.x if _ball.state == "in" else _ball.b.x, 520, 1060)
	_opp.position.x = lerpf(_opp.position.x, tx - _opp.size.x / 2.0, 0.08)
	# Petunjuk sesuai keadaan bola (bukan teks hiasan)
	var zone := _ball.in_zone()
	if _ball.state == "in" and zone:
		_hint.text = "SEKARANG! Geser ke atas!"
		_hint.add_theme_color_override("font_color", Color("ffe28a"))
	elif _ball.state == "in":
		_hint.text = "Bola datang... tunggu lingkaran putih"
		_hint.add_theme_color_override("font_color", Color("fff6e6"))
	elif _ball.state == "out":
		_hint.text = "Bagus! Bola menuju %s" % FOES[foe][0]
		_hint.add_theme_color_override("font_color", Color("fff6e6"))
	else:
		_hint.text = "%s bersiap servis..." % FOES[foe][0]
		_hint.add_theme_color_override("font_color", Color("fff6e6"))
	# Tutorial Kak Ray mengikuti apa yang terjadi di lapangan
	if _tut == 0 and _ball.state == "in":
		_tut = 1
		_ray_say("Itu bolanya datang! Jangan buru-buru, tunggu sampai bola turun ke dekatmu.")
	elif _tut == 1 and zone:
		_tut = 2
		_ray_say("Lingkaran putih muncul = zona pukul. Geser jarimu ke ATAS sekarang!")
	_ball.show_guide = _tut < 4


func _on_hit() -> void:
	_rally += 1
	game.sfx("pop", -4.0)
	_mar.texture = load("res://assets/chars/penjaga/happy_L.png")
	var tw := _mar.create_tween()
	tw.tween_property(_mar, "rotation", -0.12, 0.08)
	tw.tween_property(_mar, "rotation", 0.0, 0.15)
	tw.tween_interval(0.6)
	tw.tween_callback(func(): _mar.texture = load("res://assets/chars/penjaga/idle_L.png"))
	if _tut < 4:
		_tut = 4
		game.S.side["padel_tut"] = true
		_ray_say("Mantap! Itu pukulan pertamamu. Sekarang lanjutkan sampai menang satu game!")
	elif _rally >= 3:
		_ray_say("Reli %d pukulan! Pertahankan ritmenya!" % _rally)


func _point(who: int) -> void:
	pts[who] += 1
	_rally = 0
	game.sfx("pop" if who == 0 else "arrive", -6.0)
	_opp.texture = load("res://assets/chars/%s/%s_L.png" % [FOES[foe][2], FOES[foe][4] if who == 1 else FOES[foe][3]])
	if pts[who] >= 4 and pts[who] - pts[1 - who] >= 2:
		if who == 0:
			_say("GAME! Maryam menang!")
			_ray_say("Hebat, Mbak Maryam menang! %s minta tanding ulang tuh." % FOES[foe][0])
			if _toast_once("padel"):
				game.add_xp(25)
				for e in game.each_tenant():
					e[1].tenant.happy = clampf(float(e[1].tenant.happy) + 3.0, 0, 100)
				game.maybe_review("padel")
				game.ui.toast("Maryam menang lawan %s! Badan segar, semangat mengurus kost (+25 XP, penghuni +3 senang)." % FOES[foe][0], "gold")
			else:
				game.ui.toast("Menang lagi! Hadiah harian sudah diambil, main santai saja~")
		else:
			_say("%s menang game ini." % FOES[foe][0])
			_ray_say("Nggak apa-apa! Pukul sedikit lebih lambat, pas bola di tengah lingkaran.")
		pts = [0, 0]
		_render_score()
		_ball.serve(2.4)
		return
	if who == 0:
		_say("Poin Maryam!")
		if _tut >= 4: _ray_say(["%s nggak sempat mengejar. Bagus!" % FOES[foe][0], "Pukulan yang rapi!", "Terus tekan, Mbak!"].pick_random())
	else:
		_say("Bola lolos...")
		if _tut >= 4: _ray_say(["Terlalu cepat menggesek. Tunggu lingkaran putih.", "Bola lolos. Tetap tenang, fokus ke bayangan bola.", "Hampir! Geser ke atas tepat saat lingkaran muncul."].pick_random())
	_render_score()
	_ball.serve(1.6)


# ---------------- Input: geser ----------------
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = e.position
			_pressed = true
			_swiped = false
		else:
			_pressed = false
	elif e is InputEventMouseMotion and _pressed and not _swiped:
		var d: Vector2 = e.position - _press
		if view == "padel":
			if d.y < -70.0 or d.length() > 110.0:
				_swiped = true
				_ball.swing()
		elif view == "cafe_ext" and absf(d.x) > 160.0 and absf(d.x) > absf(d.y) * 2.0:
			_swiped = true
			_walk(-1 if d.x < 0 else 1)
		elif view == "walk" and absf(d.x) > 160.0:
			_swiped = true
			for c in _layer.get_children():
				if c is _Walk: c.t = c.dur


## Pemandangan berjalan: langit, gedung/pohon, trotoar bergerak; Maryam melangkah di tengah.
class _Walk extends Node2D:
	signal done
	var theme := "kota"
	var dir := -1
	var font: Font
	var dest := ""
	var from := ""
	var t := 0.0
	var dur := 4.2
	var _fired := false
	var _frames: Array = []
	var _city: Texture2D
	var _city_f: Texture2D
	var _sky := Color("cfe3ee")
	var _veh: Array = []      # [tex_kanan, tex_kiri, x_awal, kecepatan, skala, jalur]

	func _flip_tex(t: Texture2D) -> Texture2D:
		var im := t.get_image()
		im.flip_x()
		return ImageTexture.create_from_image(im)

	## Lalu lintas: kendaraan di jalan kota, sepeda di jalan taman.
	func _make_traffic() -> void:
		var kinds := ["car_yellow", "motor_red", "bus", "car_green", "motor_grey", "angkot", "car_sedan", "truck", "car_suv", "pickup"] if theme == "kota" else ["bike_hijab", "bike_kid", "bike_man"]
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in range(kinds.size()):
			var t: Texture2D = load("res://assets/traffic/%s.png" % kinds[i])
			var right := i % 2 == 0
			var sp := rng.randf_range(260, 420) if theme == "kota" else rng.randf_range(120, 200)
			if kinds[i].begins_with("bus") or kinds[i].begins_with("truck"): sp *= 0.8
			var sc := 0.85 if theme == "kota" else 0.62
			if kinds[i].begins_with("motor"): sc = 0.75
			var x0 := rng.randf_range(-2600, 2600) + i * 520.0 * (1 if right else -1)
			_veh.append([t, _flip_tex(t), x0, sp * (1 if right else -1), sc, 0 if right else 1])
	const INK := Color("4a3626")

	func _ready() -> void:
		_city = load("res://assets/side/kota.jpg" if theme == "kota" else "res://assets/side/taman.jpg")
		var ci := _city.get_image()
		_sky = ci.get_pixel(ci.get_width() / 2, 4)
		ci.flip_x()
		_city_f = ImageTexture.create_from_image(ci)
		_make_traffic()
		for f in ["walk", "walk2"]:
			var tx: Texture2D = load("res://assets/chars/penjaga/%s_L.png" % f)
			if dir < 0:
				var img := tx.get_image()
				img.flip_x()
				tx = ImageTexture.create_from_image(img)
			_frames.append(tx)

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
		if t >= dur and not _fired:
			_fired = true
			done.emit()

	func _draw() -> void:
		var W := float(D.IW)
		var H := float(D.IH)
		var off := t * 420.0 * float(-dir)   # pemandangan bergeser berlawanan arah langkah
		var kota := theme == "kota"
		if _city:
			_draw_city(off)
			return
		# Langit
		var top := Color("bfe0ee") if kota else Color("cfe9e3")
		var bot := Color("fbeedd")
		for i in range(24):
			var y0 := H * 0.75 * i / 24.0
			draw_rect(Rect2(0, y0, W, H * 0.75 / 24.0 + 2), top.lerp(bot, i / 24.0))
		# Awan
		for i in range(5):
			var cx := fposmod(i * 420.0 + off * 0.15, W + 400) - 200
			var cy := 420.0 + (i % 3) * 140
			for k in range(3):
				draw_circle(Vector2(cx + k * 70, cy - (k % 2) * 30), 70, Color(1, 1, 1, 0.85))
		var ground := 2050.0
		if kota:
			_row(off * 0.4, 0.7, ground - 150, [Color("c8b9a6"), Color("b9c7cf"), Color("d4c3b0")], 380, 2000, false)
			_row(off, 1.0, ground, [Color("e8cfae"), Color("f2dcc0"), Color("d9b896"), Color("cfe0d6")], 360, 1350, true)
		else:
			_trees(off * 0.4, 1.1, ground - 150, Color("9cc49a"))
			_trees(off, 1.8, ground, Color("7fb07a"))
		# Trotoar
		draw_rect(Rect2(0, ground, W, 260), Color("d9d6cf") if kota else Color("e6d9b8"))
		var x := fposmod(off, 220.0) - 220
		while x < W:
			draw_line(Vector2(x, ground), Vector2(x - 60, ground + 260), Color("bdb9b0"), 4)
			x += 220
		draw_line(Vector2(0, ground), Vector2(W, ground), INK, 6)
		draw_rect(Rect2(0, ground + 260, W, H - ground - 260), Color("8e8a85") if kota else Color("a9c98f"))
		_draw_traffic(off, ground + 110.0, 60.0)
		# Maryam
		var tex: Texture2D = _frames[int(t * 6.0) % 2]
		var s := 1.4
		var sz := tex.get_size() * s
		var bob := -absf(sin(t * 12.0)) * 8.0
		var r := Rect2(W / 2.0 - sz.x / 2.0, ground + 170 - sz.y + bob, sz.x, sz.y)
		draw_texture_rect(tex, r, false)
		# Papan keterangan
		if font:
			var txt := "%s  →  %s" % [from, dest] if dir > 0 else "%s  ←  %s" % [dest, from]
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
			var pr := Rect2(W / 2.0 - tw / 2.0 - 40, 300, tw + 80, 100)
			draw_rect(pr, Color("fbf3e6"))
			draw_rect(pr, INK, false, 6)
			draw_string(font, pr.position + Vector2(40, 68), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, INK)
			var hint := "Geser untuk lewati"
			draw_string(font, Vector2(W / 2.0 - 160, 2350), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(INK, 0.7))
		# Progres
		draw_rect(Rect2(200, 2420, W - 400, 18), Color(1, 1, 1, 0.6))
		draw_rect(Rect2(200, 2420, (W - 400) * clampf(t / dur, 0, 1), 18), Color("e98b7a"))

	## Jalan kota bergambar (dari ilustrasi), disambung bergantian dengan cerminannya agar mulus.
	func _draw_city(off: float) -> void:
		var W := float(D.IW)
		var kota := theme == "kota"
		var sc := 1.25 if kota else 1.0
		var tw := _city.get_width() * sc
		var th := _city.get_height() * sc
		var top := (2320.0 - th) if kota else 440.0
		draw_rect(Rect2(0, 0, W, top + 4), _sky)
		var start := floori(-off / tw) - 1
		for i in range(start, start + int(W / tw) + 3):
			var x := i * tw + off
			draw_texture_rect(_city if posmod(i, 2) == 0 else _city_f, Rect2(x, top, tw, th), false)
		if kota:
			draw_rect(Rect2(0, 2320, W, D.IH - 2320), Color("d9d6cf"))
			_draw_traffic(off, top + 1300.0 * sc, 70.0)
		else:
			draw_rect(Rect2(0, top + th - 2, W, D.IH - top - th + 2), Color("5f5a57"))
			_draw_traffic(off, 2130.0, 60.0)
		var tex: Texture2D = _frames[int(t * 6.0) % 2]
		var s := 1.4
		var sz := tex.get_size() * s
		var bob := -absf(sin(t * 12.0)) * 8.0
		var feet := (top + (1940.0 - 470.0) * sc) if kota else 2245.0
		draw_texture_rect(tex, Rect2(W / 2.0 - sz.x / 2.0, feet - sz.y + bob, sz.x, sz.y), false)
		_label_draw()

	func _draw_traffic(off: float, base_y: float, lane_gap: float) -> void:
		var W := float(D.IW)
		var span := W + 4200.0
		# jalur jauh (ke kiri) dulu, lalu jalur dekat (ke kanan)
		for lane in [1, 0]:
			for v in _veh:
				if int(v[5]) != lane: continue
				var tex: Texture2D = v[0] if float(v[3]) > 0 else v[1]
				var sz: Vector2 = tex.get_size() * float(v[4])
				var x := fposmod(float(v[2]) + float(v[3]) * t + off, span) - 2100.0
				var y: float = base_y - float(lane) * lane_gap - sz.y
				draw_texture_rect(tex, Rect2(x, y, sz.x, sz.y), false)

	func _label_draw() -> void:
		var W := float(D.IW)
		if font:
			var txt := "%s  →  %s" % [from, dest] if dir > 0 else "%s  ←  %s" % [dest, from]
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
			var pr := Rect2(W / 2.0 - tw / 2.0 - 40, 300, tw + 80, 100)
			draw_rect(pr, Color("fbf3e6"))
			draw_rect(pr, INK, false, 6)
			draw_string(font, pr.position + Vector2(40, 68), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, INK)
			draw_string(font, Vector2(W / 2.0 - 160, 2400), "Geser untuk lewati", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(INK, 0.7))
		draw_rect(Rect2(200, 2460, W - 400, 18), Color(1, 1, 1, 0.6))
		draw_rect(Rect2(200, 2460, (W - 400) * clampf(t / dur, 0, 1), 18), Color("e98b7a"))

	func _row(off: float, sc: float, base: float, cols: Array, wmin: float, hmax: float, shops: bool) -> void:
		var unit := 460.0 * sc
		var start: float = floor(-off / unit) - 1
		for i in range(int(start), int(start) + int(D.IW / unit) + 3):
			var rng := RandomNumberGenerator.new()
			rng.seed = i * 7919 + int(sc * 10)
			var w := rng.randf_range(wmin, unit - 30) * (1.0 if shops else 0.9)
			var h := rng.randf_range(hmax * 0.55, hmax) * sc
			var x := i * unit + off
			var c: Color = cols[absi(i) % cols.size()]
			var r := Rect2(x, base - h, w, h)
			draw_rect(r, c)
			draw_rect(r, INK, false, 5 * sc)
			# jendela
			var wy := r.position.y + 50 * sc
			while wy < base - (260 if shops else 80) * sc:
				var wx := r.position.x + 40 * sc
				while wx < r.end.x - 90 * sc:
					draw_rect(Rect2(wx, wy, 60 * sc, 70 * sc), Color("cfe3ee"))
					draw_rect(Rect2(wx, wy, 60 * sc, 70 * sc), INK, false, 3 * sc)
					wx += 110 * sc
				wy += 130 * sc
			if shops:
				# kanopi bergaris & pintu toko
				var aw := Rect2(r.position.x - 10, base - 260, w + 20, 60)
				var stripe := Color("e98b7a") if absi(i) % 2 == 0 else Color("8fb3c9")
				var k := 0.0
				while k < aw.size.x:
					draw_rect(Rect2(aw.position.x + k, aw.position.y, minf(40, aw.size.x - k), aw.size.y), stripe if int(k / 40) % 2 == 0 else Color("fbf3e6"))
					k += 40
				draw_rect(aw, INK, false, 4)
				draw_rect(Rect2(r.position.x + w * 0.35, base - 180, w * 0.3, 180), Color("a8774f"))
				draw_rect(Rect2(r.position.x + w * 0.35, base - 180, w * 0.3, 180), INK, false, 4)

	func _trees(off: float, sc: float, base: float, col: Color) -> void:
		var unit := 300.0 * sc
		var start: float = floor(-off / unit) - 1
		for i in range(int(start), int(start) + int(D.IW / unit) + 3):
			var rng := RandomNumberGenerator.new()
			rng.seed = i * 104729 + int(sc * 10)
			var x := i * unit + off + rng.randf_range(-40, 40)
			var h := rng.randf_range(260, 420) * sc
			draw_rect(Rect2(x - 14 * sc, base - h * 0.45, 28 * sc, h * 0.45), Color("8a6142"))
			for k in range(3):
				draw_circle(Vector2(x + (k - 1) * 55 * sc, base - h * 0.55 - (k % 2) * 60 * sc), 95 * sc, col.darkened(0.08 * k))
			draw_circle(Vector2(x, base - h * 0.75), 90 * sc, col.lightened(0.08))
			if sc >= 1.5 and absi(i) % 3 == 0:
				# bangku taman
				draw_rect(Rect2(x + 90, base - 70, 160, 20), Color("b0784c"))
				draw_rect(Rect2(x + 100, base - 50, 12, 50), INK)
				draw_rect(Rect2(x + 226, base - 50, 12, 50), INK)
			if absi(i) % 2 == 0:
				for f in range(4):
					draw_circle(Vector2(x - 60 + f * 30, base - 10), 10, [Color("f4a7b9"), Color("f7d36e"), Color("c9b6ea")][f % 3])


## Bola padel: dipukul lawan ke arah Maryam; geser ke atas saat bola di zona pukul.
class _Ball extends Node2D:
	signal missed
	signal foe_missed
	signal hit_ok
	var skill := 0.6
	var state := "idle"     # idle / in / out
	var t := 0.0
	var dur := 1.2
	var a := Vector2(800, 1000)
	var b := Vector2(900, 1720)
	var player: TextureRect
	var show_guide := false
	var _wait := 0.0
	var _swing_t := 0.0
	var _clock := 0.0

	func serve(delay: float) -> void:
		state = "idle"
		_wait = delay

	func in_zone() -> bool:
		return state == "in" and t >= dur * 0.72 and t <= dur + 0.2

	func _process(dt: float) -> void:
		_clock += dt
		_swing_t = maxf(0.0, _swing_t - dt)
		if state == "idle":
			if _wait > 0.0:
				_wait -= dt
				if _wait <= 0.0:
					_incoming()
			queue_redraw()
			return
		t += dt
		if state == "in" and t > dur + 0.2:
			state = "idle"
			missed.emit()
		elif state == "out" and t >= dur:
			if randf() < skill:
				_incoming()
			else:
				state = "idle"
				foe_missed.emit()
		queue_redraw()

	func _incoming() -> void:
		state = "in"
		t = 0.0
		dur = randf_range(1.25, 1.55) - skill * 0.3
		a = Vector2(randf_range(640, 980), 1010)
		var px := player.position.x + player.size.x * 0.78 if player else 980.0
		b = Vector2(px + randf_range(-30, 40), 1730)

	func swing() -> void:
		_swing_t = 0.28
		if in_zone():
			state = "out"
			t = 0.0
			dur = 1.0
			a = _pos()
			b = Vector2(randf_range(600, 1000), 1000)
			hit_ok.emit()

	func _pos() -> Vector2:
		var k := clampf(t / dur, 0.0, 1.0)
		var p := a.lerp(b, k)
		p.y -= sin(k * PI) * 240.0
		return p

	func _draw() -> void:
		# Raket Maryam
		if player:
			var hand := player.position + Vector2(player.size.x * 0.82, player.size.y * 0.5)
			var ang := -0.5 - (sin((0.28 - _swing_t) / 0.28 * PI) * 1.6 if _swing_t > 0 else 0.0)
			var dir := Vector2(cos(ang), sin(ang))
			var head := hand + dir * 120.0
			draw_line(hand, hand + dir * 55.0, Color("2e2a2a"), 14)
			draw_set_transform(head, ang + PI / 2.0, Vector2.ONE)
			draw_circle(Vector2.ZERO, 58, Color("4f6378"))
			draw_arc(Vector2.ZERO, 58, 0, TAU, 28, Color("2e2a2a"), 6)
			for i in range(-2, 3):
				for j in range(-2, 3):
					if i * i + j * j <= 5: draw_circle(Vector2(i * 18, j * 18), 4, Color("2e3a48"))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		if state == "idle": return
		var k := clampf(t / dur, 0.0, 1.0)
		var near := k if state == "in" else 1.0 - k
		var r := lerpf(12.0, 30.0, near)
		var p := _pos()
		var ground := a.lerp(b, k)
		draw_circle(ground + Vector2(0, 8), r * 0.9, Color(0, 0, 0, 0.18))
		if in_zone():
			draw_arc(b, 80, 0, TAU, 36, Color(1, 1, 1, 0.85), 8)
			draw_arc(b, 80 + fmod(_clock * 120.0, 30.0), 0, TAU, 36, Color(1, 1, 1, 0.35), 4)
			if show_guide:
				# Tangan & panah petunjuk: geser ke atas
				var hp := b + Vector2(130, 140 - fmod(_clock * 220.0, 120.0))
				draw_line(b + Vector2(130, 160), b + Vector2(130, 10), Color(1, 1, 1, 0.8), 10)
				draw_colored_polygon(PackedVector2Array([b + Vector2(105, 20), b + Vector2(155, 20), b + Vector2(130, -20)]), Color(1, 1, 1, 0.85))
				draw_circle(hp, 26, Color("fbe9d8"))
				draw_arc(hp, 26, 0, TAU, 20, Color("6b4f3a"), 4)
		draw_circle(p, r, Color("e6e85a"))
		draw_arc(p, r, 0, TAU, 20, Color("6b6a20"), 3)

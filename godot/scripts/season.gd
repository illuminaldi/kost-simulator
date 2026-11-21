extends RefCounted
class_name Season
## Event musiman lokal mengikuti tanggal asli di HP: hiasan gedung, ucapan, bonus kecil,
## dan obrolan bertema di grup penghuni.

var g
var key := ""
var decor_bld: Node2D
var decor_lobby: Node2D
var rain: Node2D

# Perkiraan awal Ramadan & Imlek (tanggal bisa bergeser 1 hari).
const RAMADAN := {2026: [2, 18], 2027: [2, 8], 2028: [1, 28], 2029: [1, 16], 2030: [1, 6]}
const IMLEK := {2026: [2, 17], 2027: [2, 6], 2028: [1, 26], 2029: [2, 13], 2030: [2, 3]}

const INFO := {
	"agustus": {"n": "Agustusan", "greet": "Dirgahayu Republik Indonesia ke-%d! Kost dihias merah putih. Penghuni lebih semangat (+senang tiap hari).",
		"wa": [["Lomba makan kerupuk di lobi jam 4 sore, siapa ikut?", "Ikut! Aku juara tahun lalu!", "Aku ikut balap karung aja."],
			["Merdeka!!", "Merdeka! Jangan lupa upacara besok pagi ya."],
			["Umbul-umbulnya cakep banget, Mbak Maryam.", "Makasih! Biar semangat Agustusan."]]},
	"ramadan": {"n": "Ramadan", "greet": "Marhaban ya Ramadan! Kost dihias lampion & ketupat. Penghuni lebih betah (+senang), apalagi kalau ada Mushola atau Warteg/Kantin.",
		"wa": [["Sahur! Sahur! Yang belum bangun, ayo bangun!", "Udah bangun kok, lagi masak mi.", "Aku telat bangun lagi..."],
			["Ada yang mau bukber bareng di lobi?", "Mau! Aku bawa kolak.", "Aku bawa gorengan."],
			["Takjilnya enak, makasih Mbak Maryam!", "Sama-sama, selamat berbuka!"]]},
	"imlek": {"n": "Imlek", "greet": "Gong Xi Fa Cai! Lampion merah menghiasi kost. Penghuni dapat angpao kecil (+senang).",
		"wa": [["Gong Xi Fa Cai semuanya!", "Gong Xi Fa Cai! Angpao mana nih?", "Hahaha nanti dibagi."],
			["Lampion merahnya bagus banget di malam hari.", "Iya, kost jadi meriah."]]},
	"natal": {"n": "Natal & Tahun Baru", "greet": "Selamat Natal & Tahun Baru! Lampu kelap-kelip menghiasi kost. Penghuni lebih ceria (+senang).",
		"wa": [["Selamat Natal bagi yang merayakan!", "Terima kasih! Damai untuk kita semua."],
			["Malam tahun baru nonton kembang api di rooftop?", "Gas! Aku bawa jagung bakar."],
			["Resolusi tahun depan apa nih?", "Lulus kuliah!", "Naik gaji, amin."]]},
	"hujan": {"n": "Musim Hujan", "greet": "Musim hujan tiba. Atap bisa bocor lebih sering, siapkan teknisi! Jemuran juga lebih lama kering.",
		"wa": [["Hujan lagi... jemuranku belum kering.", "Taruh di dalam aja, kipasin."],
			["Ada yang punya payung lebih?", "Pinjam punyaku, di depan kamar."],
			["Hujan-hujan gini enaknya mi kuah.", "Setuju! Ke warteg yuk."]]},
}


func _init(game) -> void:
	g = game


## Musim aktif berdasarkan tanggal sistem ("" = tidak ada).
func detect(override := "") -> String:
	if override != "": return override
	var d := Time.get_date_dict_from_system()
	var y: int = d.year
	var m: int = d.month
	var day: int = d.day
	var doy := _doy(y, m, day)
	if RAMADAN.has(y):
		var r0 := _doy(y, RAMADAN[y][0], RAMADAN[y][1])
		if doy >= r0 and doy <= r0 + 32: return "ramadan"     # termasuk Lebaran
	if IMLEK.has(y):
		var i0 := _doy(y, IMLEK[y][0], IMLEK[y][1])
		if doy >= i0 - 5 and doy <= i0 + 7: return "imlek"
	if m == 8: return "agustus"
	if (m == 12 and day >= 18) or (m == 1 and day <= 3): return "natal"
	if m >= 11 or m <= 3: return "hujan"
	return ""


func _doy(y: int, m: int, d: int) -> int:
	var t := Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 12})
	var t0 := Time.get_unix_time_from_datetime_dict({"year": y, "month": 1, "day": 1, "hour": 12})
	return int((t - t0) / 86400.0)


func start(override := "") -> void:
	key = detect(override)
	if key == "": return
	_decorate()
	var S: Dictionary = g.S
	var tag := "%s%d" % [key, int(Time.get_date_dict_from_system().year)]
	if S.get("season_seen", "") != tag:
		S.season_seen = tag
		var txt: String = INFO[key].greet
		if key == "agustus": txt = txt % (int(Time.get_date_dict_from_system().year) - 1945)
		g.ui.toast(txt, "gold")
		if g.wa: g.wa.post("Maryam", "Pengumuman: %s" % txt, "chat")


## Bonus harian kecil untuk penghuni selama musim perayaan.
func happy_bonus() -> float:
	match key:
		"agustus", "imlek", "natal": return 1.5
		"ramadan": return 1.0 + (1.0 if g.has_facil("mushola") else 0.0) + (0.5 if g.has_facil("warteg") or g.has_facil("kantin") else 0.0)
	return 0.0


## Peluang masalah tertentu naik di musim hujan.
func event_mul(k: String) -> float:
	if key == "hujan" and k == "atap_bocor": return 2.0
	if key == "hujan" and k == "nyamuk": return 2.0
	return 1.0


func hourly(h: int) -> void:
	if key == "" or g.wa == null: return
	var ten: Array = g.each_tenant()
	if ten.size() < 2 or randf() > 0.08: return
	if key == "ramadan" and not (h in [3, 4, 17, 18, 19]) and randf() < 0.7: return
	ten.shuffle()
	var conv: Array = INFO[key].wa.pick_random()
	for i in range(conv.size()):
		var e: Array = ten[i % 2]
		g.wa.post(str(e[1].tenant.name), str(conv[i]), "chat", e[0])
	if rain: rain.visible = key == "hujan" and (h >= 13 and h <= 18) and int(g.S.day) % 2 == 0


func _decorate() -> void:
	decor_bld = _Decor.new()
	decor_bld.kind = key
	decor_bld.mode = "bld"
	g.bld.add_child(decor_bld)
	# Di belakang lapisan kamar supaya label nama kamar tetap terbaca.
	for c in g.bld.get_children():
		if c.get_child_count() > 0 and c.get_child(0) is RoomFx:
			g.bld.move_child(decor_bld, c.get_index())
			break
	decor_lobby = _Decor.new()
	decor_lobby.kind = key
	decor_lobby.mode = "lobby"
	g.lobby_root.add_child(decor_lobby)
	if key == "hujan":
		rain = _Rain.new()
		rain.visible = false
		g.ui.add_child(rain)
		g.ui.move_child(rain, 0)


class _Decor extends Node2D:
	var kind := ""
	var mode := "bld"
	var t := 0.0

	func _process(dt: float) -> void:
		t += dt
		if kind in ["natal", "imlek", "ramadan"]: queue_redraw()

	func _bunting(y: float, x0: float, x1: float, cols: Array) -> void:
		var n := int((x1 - x0) / 46.0)
		var sag := 18.0
		var pts := PackedVector2Array()
		for i in range(n + 1):
			var k := float(i) / n
			pts.append(Vector2(lerpf(x0, x1, k), y + sin(k * PI) * sag))
		draw_polyline(pts, Color("5a4232"), 3.0, true)
		for i in range(n):
			var a := pts[i]
			var b := pts[i + 1]
			var m := (a + b) / 2.0
			var c: Color = cols[i % cols.size()]
			draw_colored_polygon(PackedVector2Array([a + Vector2(4, 0), b - Vector2(4, 0), m + Vector2(0, 34)]), c)
			draw_polyline(PackedVector2Array([a + Vector2(4, 0), m + Vector2(0, 34), b - Vector2(4, 0)]), Color("5a4232", 0.6), 2.0, true)

	func _lights(y: float, x0: float, x1: float, cols: Array) -> void:
		var n := int((x1 - x0) / 40.0)
		var pts := PackedVector2Array()
		for i in range(n + 1):
			var k := float(i) / n
			pts.append(Vector2(lerpf(x0, x1, k), y + sin(k * PI) * 14.0))
		draw_polyline(pts, Color("3d2a1e"), 2.5, true)
		for i in range(n + 1):
			var on := int(t * 2.0 + i) % 3 != 0
			var c: Color = cols[i % cols.size()]
			draw_circle(pts[i] + Vector2(0, 8), 7.0, c if on else c.darkened(0.5))
			if on: draw_circle(pts[i] + Vector2(0, 8), 14.0, Color(c, 0.25))

	func _lantern(p: Vector2, c: Color, s: float) -> void:
		var sw := sin(t * 1.6 + p.x * 0.01) * 4.0
		p.x += sw
		draw_line(p + Vector2(-sw, -40 * s), p + Vector2(0, -24 * s), Color("3d2a1e"), 2.5)
		draw_circle(p, 24 * s, c)
		draw_arc(p, 24 * s, 0, TAU, 24, Color("5a3a24"), 2.5)
		draw_rect(Rect2(p + Vector2(-12, -26) * s, Vector2(24, 6) * s), Color("e2b54a"))
		draw_rect(Rect2(p + Vector2(-12, 20) * s, Vector2(24, 6) * s), Color("e2b54a"))
		draw_line(p + Vector2(0, 26 * s), p + Vector2(0, 44 * s), Color("e2b54a"), 3.0)
		draw_circle(p, 30 * s, Color(c, 0.18))

	func _ketupat(p: Vector2, s := 1.0) -> void:
		var d := 22.0 * s
		draw_line(p + Vector2(0, -d - 28), p + Vector2(0, -d), Color("3d2a1e"), 2.5)
		var poly := PackedVector2Array([p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)])
		draw_colored_polygon(poly, Color("9cc46a"))
		draw_line(p + Vector2(-d / 2, -d / 2), p + Vector2(d / 2, d / 2), Color("e2b54a"), 3.0)
		draw_line(p + Vector2(d / 2, -d / 2), p + Vector2(-d / 2, d / 2), Color("e2b54a"), 3.0)
		draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), Color("4a6a32"), 2.5, true)
		draw_line(p + Vector2(0, d), p + Vector2(-6 * s, d + 22 * s), Color("e2b54a"), 3.0)
		draw_line(p + Vector2(0, d), p + Vector2(6 * s, d + 22 * s), Color("e2b54a"), 3.0)

	func _draw() -> void:
		var x0 := 131.0
		var x1 := 1405.0
		if mode == "lobby":
			var y := D.LOBBY_TOP + 40.0
			match kind:
				"agustus": _bunting(y, 20, D.IW - 20, [Color("d93a32"), Color("fbf7f0")])
				"natal": _lights(y, 20, D.IW - 20, [Color("e0533d"), Color("5fae4f"), Color("f2c94c"), Color("4f8ad9")])
				"imlek":
					for i in range(6): _lantern(Vector2(150 + i * 230, y + 40), Color("d93a32"), 1.3)
				"ramadan":
					for i in range(7):
						if i % 2 == 0: _lantern(Vector2(120 + i * 200, y + 40), Color("f2c14e"), 0.9)
						else: _ketupat(Vector2(120 + i * 200, y + 50), 1.2)
			return
		for f in range(1, D.TOP_FLOOR + 1):
			var y: float = float(D.ROWS[f].x) + 4.0
			match kind:
				"agustus": _bunting(y, x0, x1, [Color("d93a32"), Color("fbf7f0")])
				"natal": _lights(y, x0, x1, [Color("e0533d"), Color("5fae4f"), Color("f2c94c"), Color("4f8ad9")])
				"imlek":
					for x in [470.0, 780.0, 1340.0]: _lantern(Vector2(x, y + 60), Color("d93a32"), 1.5)
				"ramadan":
					for i in range(3):
						var x: float = [470.0, 780.0, 1340.0][i]
						if (i + f) % 2 == 0: _lantern(Vector2(x, y + 60), Color("f2c14e"), 1.4)
						else: _ketupat(Vector2(x, y + 66), 1.5)
		if kind == "agustus":
			# Bendera merah putih di atap
			var top: float = float(D.ROWS[D.TOP_FLOOR].x) - 10.0
			draw_line(Vector2(1300, top), Vector2(1300, top - 220), Color("8a8f96"), 6.0)
			var w := sin(Time.get_ticks_msec() / 300.0) * 6.0
			draw_colored_polygon(PackedVector2Array([Vector2(1303, top - 216), Vector2(1440, top - 210 + w), Vector2(1440, top - 168 + w), Vector2(1303, top - 174)]), Color("d93a32"))
			draw_colored_polygon(PackedVector2Array([Vector2(1303, top - 174), Vector2(1440, top - 168 + w), Vector2(1440, top - 126 + w), Vector2(1303, top - 132)]), Color("fbf7f0"))


class _Rain extends Node2D:
	var drops: Array = []
	func _ready() -> void:
		for i in range(140):
			drops.append(Vector2(randf() * D.IW, randf() * D.IH))
	func _process(dt: float) -> void:
		if not visible: return
		for i in range(drops.size()):
			var p: Vector2 = drops[i]
			p += Vector2(-120, 1500) * dt
			if p.y > D.IH: p = Vector2(randf() * (D.IW + 200), -20)
			drops[i] = p
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(0, 0, D.IW, D.IH), Color(0.35, 0.42, 0.55, 0.12))
		for p in drops:
			draw_line(p, p + Vector2(-8, 60), Color(0.85, 0.9, 1.0, 0.45), 2.5)

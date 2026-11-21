class_name Onar
extends RefCounted
## Pengacau kamar (kejadian onar di dalam kamar penghuni) + QRIS bodong di lobi.
## Satu kejadian kamar aktif sekaligus. Data di S.funny.onar = {k, room, until, ...}.

const KEYS := ["lobster", "kardus", "sadap", "biawak", "dupa", "palsu", "qris", "harian", "hairdryer", "mules"]
const NAMES := {"lobster": "Kolam Lobster di Kamar", "kardus": "Gunung Kardus", "sadap": "Markas Penyadapan",
	"biawak": "Biawak Kolong Kasur", "dupa": "Teror Dupa", "palsu": "Pabrik Uang Palsu", "qris": "QRIS Bodong",
	"harian": "Kos Harian Ilegal", "hairdryer": "Hair Dryer Lupa Dimatikan", "mules": "Teriakan Kamar Mandi"}

var game: Node
var S: Dictionary
var fx: Node2D          # overlay di kamar
var sticker: Node2D     # stiker QRIS di lobi


func _init(g: Node) -> void:
	game = g
	S = g.S


func st() -> Dictionary:
	return S.funny.get("onar", {})


func active() -> bool:
	return not st().is_empty()


func possible(k: String) -> bool:
	if active() and k != "hairdryer": return false
	match k:
		"qris": return not S.funny.has("qris_on") and int(S.lvl) >= 3
		"sadap", "palsu": return int(S.lvl) >= 5 and _rooms().size() > 0
		"harian", "lobster": return int(S.lvl) >= 3 and _rooms().size() > 0
	return _rooms().size() > 0


func _rooms() -> Array:
	var a := []
	for e in game.each_tenant():
		if str(S.rooms[e[0]].get("broken", "")) == "": a.append(e[0])
	return a


func _tenant(rid: String):
	return S.rooms[rid].tenant if S.rooms.has(rid) else null


func _say(rid: String, text: String, dur := 3.5) -> void:
	var t = _tenant(rid)
	if t != null and game.npcs.has(t.id):
		game.npcs[t.id].say(text, dur)


func start(k: String) -> void:
	if k == "qris":
		_start_qris(); return
	if _rooms().is_empty(): return
	var rid: String = _rooms().pick_random()
	if k == "hairdryer":
		game.ui.toast("Penghuni Kamar %s lupa mematikan hair dryer di atas kasur..." % D.room_name(rid), "bad")
		game.start_fire(rid)
		return
	S.funny.onar = {"k": k, "room": rid, "until": int(S.day) + (1 if k == "mules" else 4)}
	_show()
	game.jump_to_floor(D.fl(rid))
	var t = _tenant(rid)
	var nm: String = str(t.name) if t != null else "Penghuni"
	match k:
		"lobster":
			game.ui.toast("Kamar %s disulap %s jadi kolam ternak lobster! Ketuk kamarnya." % [D.room_name(rid), nm], "bad")
			_say(rid, "Lobster air tawar, Bu! Cuan!")
		"kardus":
			game.ui.toast("Kamar %s penuh gunungan kardus sampai pintunya macet! Ketuk kamarnya." % D.room_name(rid), "bad")
			_say(rid, "Hehe saya suka belanja online, jadi kardusnya saya koleksi.", 4.5)
		"sadap":
			game.ui.toast("Ada yang aneh di Kamar %s: antena, kabel, dan layar di mana-mana... Ketuk kamarnya." % D.room_name(rid), "bad")
		"biawak":
			game.sfx("whoosh", -4.0)
			game.ui.toast("BIAWAK sepanjang 1 meter nyasar ke kolong kasur Kamar %s! Ketuk kamarnya." % D.room_name(rid), "bad")
			_say(rid, "TOLOOONG! Ada biawak!!")
		"dupa":
			game.ui.toast("Bau dupa & bunga kamboja dari Kamar %s. Penghuni lain merinding. Ketuk kamarnya." % D.room_name(rid), "bad")
		"palsu":
			game.ui.toast("Kamar %s sepi, tapi terdengar suara mesin cetak tiap malam... Ketuk kamarnya." % D.room_name(rid), "bad")
		"harian":
			game.ui.toast("Turis asing keluar-masuk Kamar %s bawa koper. Disewakan harian lewat aplikasi?! Ketuk kamarnya." % D.room_name(rid), "bad")
		"mules":
			game.sfx("thunder", -14.0)
			game.ui.toast("Teriakan keras dari kamar mandi Kamar %s! Ada kecelakaan?! Ketuk kamarnya." % D.room_name(rid), "bad")
			_say(rid, "AAAARGHHH!!!", 3.0)
	game.dirty = true


func restore() -> void:
	if active(): _show()
	if S.funny.has("qris_on"): _show_sticker()


func daily() -> void:
	if S.funny.has("qris_on"):
		# stiker belum dicopot: sebagian sewa hari ini masuk ke rekening palsu
		var lost := roundf(float(S.today.get("rent", 0.0)) * 0.25 / 1000.0) * 1000.0
		if lost > 0:
			game.spend(lost, "other")
			game.ui.toast("Beberapa penghuni bayar lewat QRIS palsu. Hilang %s!" % D.rp(lost), "bad")
	if not active(): return
	var o: Dictionary = st()
	var rid: String = o.room
	match str(o.k):
		"lobster":
			if o.get("deal", false):
				S.money = float(S.money) + 150000.0
				S.rooms[rid].clean = maxf(0.0, float(S.rooms[rid].clean) - 25.0)
				game.float_at(rid, "+Rp150rb lobster", Color("2f7a2a"))
		"kardus", "dupa":
			S.rep = clampf(float(S.rep) - 0.03, 1, 5)
			for e in game.each_tenant():
				if e[0] != rid: e[1].tenant.happy = maxf(0.0, float(e[1].tenant.happy) - 2.0)
		"palsu", "sadap":
			if o.get("ignored", false) and randf() < 0.5:
				_raid(rid, true); return
	if int(S.day) >= int(o.until):
		_auto_end()


func _auto_end() -> void:
	var o: Dictionary = st()
	match str(o.k):
		"lobster": game.ui.toast("Lobsternya dijual habis. Kamar %s kembali normal (tapi bau amis)." % D.room_name(o.room))
		"kardus": game.ui.toast("Kardus di Kamar %s akhirnya diloak sendiri oleh penghuninya." % D.room_name(o.room))
		"biawak": game.ui.toast("Biawaknya keluar sendiri lewat selokan. Fiuh.")
		"dupa": game.ui.toast("Dupanya habis. Kamar %s tidak berasap lagi." % D.room_name(o.room))
		"harian": game.ui.toast("Turis harian sudah check-out dari Kamar %s." % D.room_name(o.room))
		"mules": game.ui.toast("Kamar mandi Kamar %s sudah sepi. Penghuninya keluar dengan lega." % D.room_name(o.room))
		"palsu", "sadap":
			_raid(o.room, true); return
	_end()


func _end() -> void:
	S.funny.erase("onar")
	if fx != null and is_instance_valid(fx): fx.queue_free()
	fx = null
	game.dirty = true


func tick(_dt: float) -> void:
	if active() and (fx == null or not is_instance_valid(fx)):
		_show()


func _show() -> void:
	var rid: String = st().room
	if not game.room_fx.has(rid): return
	if fx != null and is_instance_valid(fx): fx.queue_free()
	fx = _RoomProp.new()
	fx.k = st().k
	fx.sz = D.rect_of(rid).size
	fx.right = rid.ends_with("R")
	var t = _tenant(rid)
	fx.ch = str(t.get("char", "kutu")) if t != null else "kutu"
	fx.stage = str(st().get("stage", ""))
	game.room_fx[rid].add_child(fx)


func tap(p: Vector2) -> bool:
	if sticker != null and is_instance_valid(sticker) and Rect2(sticker.position + Vector2(-60, -70), Vector2(120, 150)).has_point(p):
		_sticker_removed()
		return true
	if not active(): return false
	var rid: String = st().room
	var lp: Vector2 = p - game.bld.position
	if D.rect_of(rid).has_point(lp):
		game.ui.open_sheet("funny", "onar")
		return true
	return false


## Halaman pilihan (dipakai Funny.sheet).
func sheet() -> Dictionary:
	if not active(): return {"t": "", "d": "", "o": []}
	var o: Dictionary = st()
	var rid: String = o.room
	var room := D.room_name(rid)
	var close := func(): game.ui.close_sheet()
	match str(o.k):
		"lobster":
			return {"t": "Kolam Lobster di Kamar %s" % room, "d": "Kamar disulap jadi kolam ternak lobster air tawar: akuarium bertumpuk, pompa berisik, lantai basah. Kata penghuninya, \"Cuan, Bu!\"",
				"o": [["Suruh bongkar kolamnya", D.C_CREAM, 0.0, func(): close.call(); _lobster(false)],
					["Bagi hasil (+Rp150rb/hari, kamar cepat kotor)", D.C_YELLOW, 0.0, func(): close.call(); _lobster(true)]]}
		"kardus":
			var has_satpam: bool = S.staff.get("satpam", false)
			return {"t": "Gunung Kardus di Kamar %s" % room, "d": "\"Hehe saya suka belanja online, jadi kardusnya saya koleksi.\" Pintunya macet tertahan kardus. Bau apek ke mana-mana, penghuni lain mengeluh.",
				"o": [["Satpam dobrak pintu & angkut kardus" if has_satpam else "Sewa satpam lepas untuk dobrak pintu", D.C_YELLOW, 0.0 if has_satpam else 150000.0, func(): close.call(); _kardus()],
					["Biarkan dulu", D.C_CREAM, 0.0, func(): close.call(); game.ui.toast("Kardus dibiarkan. Rating turun pelan tiap hari...", "bad")]]}
		"sadap":
			return {"t": "Markas Penyadapan di Kamar %s" % room, "d": "Monitor berjejer, radio, kabel, dan seorang hacker berkacamata. Di dinding: foto Presiden dan tulisan \"Alat Penyadap Protektor\". Ini sindikat penyadapan!",
				"o": [["Lapor Polisi", D.C_RED, 0.0, func(): close.call(); _raid(rid, false)],
					["Pura-pura tidak tahu", D.C_CREAM, 0.0, func(): close.call(); o.ignored = true; game.ui.toast("Kamu pura-pura tidak lihat... semoga tidak ketahuan polisi.", "bad")]]}
		"biawak":
			return {"t": "Biawak di Kolong Kasur %s" % room, "d": "Biawak sepanjang 1 meter mendesis di kolong kasur. Penghuninya berdiri di atas kasur sambil pegang sapu.",
				"o": [["Panggil Damkar (tangkap aman)", D.C_YELLOW, 100000.0, func(): close.call(); _biawak(true)],
					["Tangkap sendiri pakai sapu", D.C_CREAM, 0.0, func(): close.call(); _biawak(false)]]}
		"dupa":
			return {"t": "Teror Dupa di Kamar %s" % room, "d": "Asap dupa, bunga kamboja, dan sesajen di meja. Katanya penghuninya \"memelihara\" sesuatu. Penghuni lain merinding dan susah tidur.",
				"o": [["Tegur baik-baik", D.C_YELLOW, 0.0, func(): close.call(); _dupa()],
					["Biarkan saja", D.C_CREAM, 0.0, func(): close.call(); game.ui.toast("Asap dupa masih mengepul. Penghuni lain makin gelisah...", "bad")]]}
		"palsu":
			return {"t": "Pabrik Uang Palsu di Kamar %s" % room, "d": "Ternyata kamar yang selalu sepi itu jadi tempat mencetak uang palsu! Mesin cetak, tinta, dan tumpukan lembaran \"Rp 100.000\".",
				"o": [["Lapor Polisi", D.C_RED, 0.0, func(): close.call(); _raid(rid, false)],
					["Pura-pura tidak tahu", D.C_CREAM, 0.0, func(): close.call(); o.ignored = true; game.ui.toast("Kamu pura-pura tidak tahu... berbahaya kalau sampai digerebek.", "bad")]]}
		"harian":
			return {"t": "Kos Harian Ilegal di Kamar %s" % room, "d": "Penghuni Kamar %s diam-diam menyewakan kamarnya per malam lewat aplikasi. Turis asing check-in pakai koper!" % room,
				"o": [["Tegur & pulangkan turisnya", D.C_YELLOW, 0.0, func(): close.call(); _harian(false)],
					["Minta bagi hasil (+Rp300rb)", D.C_CREAM, 0.0, func(): close.call(); _harian(true)]]}
		"mules":
			return {"t": "Teriakan di Kamar Mandi %s" % room, "d": "Dari kamar mandi terdengar teriakan panjang dan rintihan. Penghuni lain panik, dikira terpeleset atau kesetrum!",
				"o": [["Dobrak pintunya!", D.C_RED, 100000.0, func(): close.call(); _mules(true)],
					["Ketuk pintu dulu", D.C_CREAM, 0.0, func(): close.call(); _mules(false)]]}
	return {"t": "", "d": "", "o": []}


# ---------------- Penyelesaian ----------------
func _lobster(deal: bool) -> void:
	var rid: String = st().room
	if deal:
		st().deal = true
		st().until = int(S.day) + 5
		_say(rid, "Siap, Bu! Bagi dua ya!")
		game.ui.toast("Bisnis lobster jalan 5 hari: +Rp150rb/hari, tapi kamarnya cepat kotor.", "gold")
	else:
		var t = _tenant(rid)
		if t != null: t.happy = maxf(0.0, float(t.happy) - 10.0)
		_say(rid, "Yaah... lobsterku...")
		game.ui.toast("Kolam lobster dibongkar. Penghuninya agak kecewa.")
		game.add_xp(8)
		_end()


func _kardus() -> void:
	var rid: String = st().room
	if not S.staff.get("satpam", false): game.spend(150000.0, "other")
	fx.stage = "dobrak"
	game.sfx("thunder", -10.0)
	game.ui.toast("BRAKK! Pintu didobrak satpam. Kardus diangkut berkarung-karung.", "gold")
	_say(rid, "Hehe... maaf ya, Pak.")
	S.rooms[rid].clean = 100.0
	game.add_xp(10)
	game.get_tree().create_timer(3.0).timeout.connect(_end)


func _raid(rid: String, late: bool) -> void:
	var o: Dictionary = st()
	var k: String = o.k
	if fx != null and is_instance_valid(fx): fx.stage = "caught"
	_police_visit(k)
	var t = _tenant(rid)
	if late:
		S.rep = clampf(float(S.rep) - 0.4, 1, 5)
		game.ui.toast("Polisi menggerebek Kamar %s! Kost masuk berita, rating anjlok." % D.room_name(rid), "bad")
	else:
		S.rep = clampf(float(S.rep) + 0.1, 1, 5)
		game.add_xp(20)
		game.ui.toast("Polisi menggerebek Kamar %s berkat laporanmu! %s" % [D.room_name(rid), "Sindikat penyadap diamankan." if k == "sadap" else "Pabrik uang palsu ditutup."], "gold")
	if t != null:
		game._sad_leave[t.id] = true
		S.rooms[rid].tenant = null
	game.get_tree().create_timer(3.5).timeout.connect(_end)


func _biawak(damkar: bool) -> void:
	var rid: String = st().room
	if damkar:
		game.spend(100000.0, "other")
		game.ui.toast("Damkar menjerat biawaknya dan melepas ke sungai. Aman!", "gold")
		game.add_xp(10)
		fx.stage = "gone"
		game.get_tree().create_timer(2.0).timeout.connect(_end)
	elif randf() < 0.5:
		game.ui.toast("Berhasil! Biawaknya diusir pakai sapu sampai keluar jendela.", "gold")
		game.add_xp(14)
		fx.stage = "gone"
		game.get_tree().create_timer(2.0).timeout.connect(_end)
	else:
		var t = _tenant(rid)
		if t != null: t.happy = maxf(0.0, float(t.happy) - 12.0)
		game.ui.toast("Biawaknya malah mendesis & menggigit sapu! Penghuni makin trauma. Coba lagi atau panggil Damkar.", "bad")
		_say(rid, "Bu, saya nggak mau tidur di sini!!")


func _dupa() -> void:
	var rid: String = st().room
	var t = _tenant(rid)
	if t != null: t.happy = maxf(0.0, float(t.happy) - 5.0)
	_say(rid, "Iya, iya... saya beresin sesajennya.")
	game.ui.toast("Dupa & sesajen dibereskan. Penghuni lain lega.", "gold")
	game.add_xp(8)
	_end()


func _harian(deal: bool) -> void:
	var rid: String = st().room
	if deal:
		S.money = float(S.money) + 300000.0
		S.rep = clampf(float(S.rep) - 0.1, 1, 5)
		game.ui.toast("Dapat bagi hasil Rp300rb... tapi penghuni lain terganggu tamu asing. Rating turun.", "bad")
	else:
		var t = _tenant(rid)
		if t != null: t.happy = maxf(0.0, float(t.happy) - 8.0)
		S.rep = clampf(float(S.rep) + 0.05, 1, 5)
		game.ui.toast("Turis dipulangkan dengan sopan. Kamar kembali untuk penghuni tetap.", "gold")
		game.add_xp(10)
	fx.stage = "leave"
	game.get_tree().create_timer(2.5).timeout.connect(_end)


func _mules(dobrak: bool) -> void:
	var rid: String = st().room
	if dobrak:
		game.spend(100000.0, "other")
		game.ui.toast("BRAKK! Pintu didobrak... ternyata penghuninya cuma menahan MULES. Pintunya harus diganti.", "bad")
	else:
		game.ui.toast("\"Saya nggak apa-apa, Bu! Cuma MULES!!\" Semua orang tertawa lega.", "gold")
	_say(rid, "Maaf... tadi makan sambal kebanyakan...", 3.5)
	game.add_xp(8)
	fx.stage = "lega"
	game.get_tree().create_timer(3.0).timeout.connect(_end)


func _police_visit(why: String) -> void:
	if game.npcs.has("polisi"): return
	var n := Npc.new()
	game.npc_lobby.add_child(n)
	n.setup("polisi", "visitor", D.STAFF_LOOK.teknisi, Vector2(D.IW + 220, D.LOBBY_Y), game.font)
	n.art = true
	n.char_id = "polisi"
	n.art_map = {"walk": "walk", "stand": "stop", "happy": "happy"}
	n.set_meta("nama", D.OUTSRC.polisi.nama)
	n.set_meta("spd", 1.6)
	game.npcs["polisi"] = n
	game.sfx("arrive", -8.0)
	n.plan("lobby", Vector2(760, D.LOBBY_Y), "stand", func(m: Npc):
		m.say("Penyadapan itu kejahatan serius! Kami amankan." if why == "sadap" else "Uang palsu disita! Pelaku ikut kami.", 3.0)
		m.work = {"t": 3.2, "pose": "stand", "fn": func(z: Npc):
			z.plan("lobby", Vector2(D.OUT_X - 360, D.LOBBY_Y), "stand", func(y: Npc): game._remove_npc(y))})


# ---------------- QRIS bodong (lobi) ----------------
func _start_qris() -> void:
	S.funny.qris_on = true
	_show_sticker()
	var n := Npc.new()
	game.npc_lobby.add_child(n)
	n.setup("preman_q", "visitor", D.STAFF_LOOK.teknisi, Vector2(D.IW + 200, D.LOBBY_Y), game.font)
	n.art = true
	n.char_id = "preman"
	n.art_map = {"walk": "walk", "stand": "count"}
	n.set_meta("nama", "Preman")
	game.npcs["preman_q"] = n
	game.ui.toast("Preman menempel stiker QRIS palsu di meja resepsionis! Ketuk stikernya sebelum ada yang bayar.", "bad")
	n.plan("lobby", Vector2(1010, D.LOBBY_Y), "stand", func(m: Npc):
		m.say("Hehe, transfer ke sini aja ya...", 2.6)
		m.work = {"t": 2.8, "pose": "stand", "fn": func(z: Npc):
			z.set_meta("spd", 1.5)
			z.plan("lobby", Vector2(D.OUT_X - 300, D.LOBBY_Y), "stand", func(y: Npc): game._remove_npc(y))})


func _show_sticker() -> void:
	if sticker != null and is_instance_valid(sticker): return
	sticker = _Qris.new()
	sticker.position = Vector2(1120, 2170)
	game.lobby_root.add_child(sticker)


func _sticker_removed() -> void:
	S.funny.erase("qris_on")
	sticker.queue_free()
	sticker = null
	game.add_xp(10)
	game.keeper_say("Stiker QRIS palsu! Bayar sewa cuma lewat QRIS resmi kost ya~", 3.5)
	game.ui.toast("Stiker QRIS palsu dicopot. Uang sewa aman!", "gold")


class _Qris extends Node2D:
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		var ink := Color("2b2b2b")
		var r := Rect2(-48, -62, 96, 124)
		draw_rect(r, Color.WHITE)
		draw_rect(Rect2(-48, -62, 96, 22), Color("d6322f"))
		draw_string(ThemeDB.fallback_font, Vector2(-34, -45), "QRIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in range(8):
			for j in range(8):
				if rng.randf() < 0.5: draw_rect(Rect2(-36 + i * 9, -32 + j * 9, 9, 9), ink)
		for c in [Vector2(-36, -32), Vector2(18, -32), Vector2(-36, 22)]:
			draw_rect(Rect2(c, Vector2(18, 18)), ink, false, 3)
		draw_rect(r, ink, false, 3)
		var a := 0.5 + 0.5 * sin(t * 5.0)
		draw_arc(Vector2.ZERO, 82, 0, TAU, 32, Color(1, 0.3, 0.2, a), 4)


# ---------------- Gambar isi kamar ----------------
class _RoomProp extends Node2D:
	var k := ""
	var sz := Vector2(420, 367)
	var right := false
	var ch := "kutu"
	var stage := ""
	var t := 0.0
	var _tx := {}
	const INK := Color("3e2b1d")

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _tex(c: String, p: String) -> Texture2D:
		var key := c + "/" + p
		if not _tx.has(key):
			var path := "res://assets/chars/%s/%s_R.png" % [c, p]
			_tx[key] = load(path) if ResourceLoader.exists(path) else null
		return _tx[key]

	## Gambar karakter (alas tengah-bawah di p), tinggi h.
	func _chr(c: String, p: String, at: Vector2, h := 150.0, flip := false, a := 1.0) -> void:
		var tx := _tex(c, p)
		if tx == null: tx = _tex(c, "idle")
		if tx == null: return
		var w := tx.get_width() * h / tx.get_height()
		var r := Rect2(at.x - w / 2.0, at.y - h, w, h)
		if flip:
			draw_set_transform(Vector2(r.position.x * 2.0 + w, 0), 0.0, Vector2(-1, 1))
			draw_texture_rect(tx, r, false, Color(1, 1, 1, a))
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect(tx, r, false, Color(1, 1, 1, a))

	func _box(r: Rect2, c: Color, bw := 3.0) -> void:
		draw_rect(r, c)
		draw_rect(r, INK, false, bw)

	func _draw() -> void:
		var fy := sz.y - 22.0               # garis lantai depan
		var cx := sz.x * (0.38 if right else 0.62)
		var bob := sin(t * 3.0) * 3.0
		match k:
			"lobster":
				for i in range(2):
					for j in range(2):
						var r := Rect2(cx - 150 + i * 150, fy - 70 - j * 74, 140, 66)
						_box(r, Color(0.55, 0.8, 0.95, 0.85))
						draw_rect(Rect2(r.position + Vector2(0, 8), Vector2(r.size.x, 4)), Color(1, 1, 1, 0.5))
						for l in range(2):
							var lp := r.position + Vector2(30 + l * 60 + sin(t * 1.5 + i + j + l) * 12, 44)
							draw_circle(lp, 10, Color("d8432f"))
							draw_circle(lp + Vector2(14, 0), 7, Color("d8432f"))
							draw_line(lp + Vector2(-10, 0), lp + Vector2(-22, -8), Color("d8432f"), 3)
						for b in range(3):
							var by := r.position.y + r.size.y - 6 - fmod(t * 30.0 + b * 20.0 + i * 13, r.size.y - 12)
							draw_circle(Vector2(r.position.x + 20 + b * 40, by), 3, Color(1, 1, 1, 0.8))
				_chr(ch, "happy", Vector2(cx + 150 * (-1 if right else 1), fy + 4), 150, right)
			"kardus":
				var rng := RandomNumberGenerator.new()
				rng.seed = 3
				for i in range(26):
					var w := rng.randf_range(60, 110)
					var h := rng.randf_range(40, 70)
					var x := rng.randf_range(10, sz.x - w - 10)
					var y := fy - h - rng.randf_range(0, 190) * (1.0 - absf(x + w / 2 - sz.x / 2) / sz.x)
					var col := Color("c99a62").darkened(rng.randf_range(0, 0.25))
					if stage == "dobrak": y += t * 60.0
					_box(Rect2(x, y, w, h), col, 2)
					draw_line(Vector2(x, y + h * 0.35), Vector2(x + w, y + h * 0.35), INK, 2)
				if stage != "dobrak":
					_chr(ch, "happy", Vector2(cx, fy - 60 + bob), 120, right)
				else:
					_chr("satpam", "help", Vector2(sz.x * (0.85 if right else 0.15), fy + 4), 150, not right)
			"sadap":
				_box(Rect2(cx - 160, fy - 92, 320, 18), Color("8a8f96"))
				for i in range(3):
					var m := Rect2(cx - 150 + i * 105, fy - 190, 92, 64)
					_box(m, Color("1f2a36"))
					for l in range(4):
						var lw: float = 20.0 + fmod(t * 40.0 + l * 17 + i * 9, 50.0)
						draw_line(m.position + Vector2(8, 12 + l * 12), m.position + Vector2(8 + lw, 12 + l * 12), Color(0.4, 1, 0.6, 0.9), 2)
				draw_line(Vector2(cx + 170, fy - 92), Vector2(cx + 170, fy - 250), INK, 3)
				draw_arc(Vector2(cx + 170, fy - 250), 22 + fmod(t * 20.0, 30.0), PI * 1.15, PI * 1.85, 10, Color(0.3, 0.8, 1.0, 0.7), 3)
				var hp := "panic" if stage == "caught" else "chair"
				_chr("hacker", hp, Vector2(cx - 20, fy + 4), 160 if hp == "chair" else 150, right)
			"biawak":
				var bedx := sz.x * (0.74 if right else 0.28)
				_chr(ch, "scared", Vector2(bedx, fy - 52 + bob), 140, right)
				if stage != "gone":
					var lx := bedx + sin(t * 0.8) * 70
					var ly := fy - 14
					var dir := 1.0 if cos(t * 0.8) > 0 else -1.0
					var body := PackedVector2Array()
					for i in range(14):
						var u := float(i) / 13.0
						body.append(Vector2(lx - dir * (u * 120 - 40), ly + sin(t * 6.0 + u * 5) * 4))
					draw_polyline(body, Color("5b6b3a"), 18)
					draw_polyline(body, INK, 2)
					draw_circle(Vector2(lx + dir * 48, ly), 13, Color("5b6b3a"))
					draw_circle(Vector2(lx + dir * 52, ly - 4), 3, INK)
					if fmod(t, 1.2) < 0.4:
						draw_line(Vector2(lx + dir * 60, ly + 2), Vector2(lx + dir * 82, ly + 4), Color("d8432f"), 3)
					for i in range(2):
						var lx2 := lx + dir * (10 - i * 50)
						draw_line(Vector2(lx2, ly), Vector2(lx2 + 10 * sin(t * 6 + i), ly + 14), INK, 4)
			"dupa":
				_box(Rect2(cx - 70, fy - 64, 140, 60), Color("a23a2c"))
				for i in range(3):
					var ix := cx - 30 + i * 30
					draw_line(Vector2(ix, fy - 64), Vector2(ix, fy - 96), Color("7a4b2a"), 3)
					for s in range(6):
						var u := fmod(t * 0.4 + s * 0.16 + i * 0.1, 1.0)
						draw_circle(Vector2(ix + sin(t * 2 + s + i) * 10 * u, fy - 100 - u * 150), 8 + u * 16, Color(0.85, 0.85, 0.85, 0.35 * (1.0 - u)))
				for i in range(5):
					var fp := Vector2(cx - 60 + i * 28, fy - 70)
					for pt in range(5):
						var a := TAU * pt / 5.0
						draw_circle(fp + Vector2(cos(a), sin(a)) * 6, 5, Color("fff7e6"))
					draw_circle(fp, 4, Color("f2c94c"))
				var gx := cx + 110 * (-1 if right else 1) + sin(t * 0.7) * 20
				var ga := 0.25 + 0.2 * sin(t * 1.3)
				draw_circle(Vector2(gx, fy - 200), 34, Color(1, 1, 1, ga))
				draw_rect(Rect2(gx - 34, fy - 200, 68, 90), Color(1, 1, 1, ga))
				draw_circle(Vector2(gx - 12, fy - 206), 5, Color(0.1, 0.1, 0.15, ga * 2))
				draw_circle(Vector2(gx + 12, fy - 206), 5, Color(0.1, 0.1, 0.15, ga * 2))
			"palsu":
				var m := Rect2(cx - 40, fy - 120, 170, 100)
				_box(m, Color("6b7280"))
				_box(Rect2(m.position + Vector2(20, -24), Vector2(130, 24)), Color("4b5563"))
				draw_circle(m.position + Vector2(40, 50), 18 + sin(t * 8) * 1, Color("374151"))
				for i in range(4):
					var u := fmod(t * 0.6 + i * 0.25, 1.0)
					var bp := m.position + Vector2(170 + u * 60, 40 - u * 30)
					draw_rect(Rect2(bp, Vector2(36, 18)), Color(0.95, 0.6, 0.65))
					draw_rect(Rect2(bp, Vector2(36, 18)), INK, false, 1.5)
				for i in range(3):
					_box(Rect2(cx - 150 + i * 6, fy - 24 - i * 10, 60, 22), Color(0.95, 0.6, 0.65), 1.5)
				var pp := "nervous" if stage == "caught" else "work"
				_chr("pemalsu", pp, Vector2(cx - 120, fy + 4), 150, right)
			"harian":
				var off := t * 40.0 if stage == "leave" else 0.0
				var a := clampf(1.0 - off / 120.0, 0, 1)
				_box(Rect2(cx - 150 + off, fy - 64, 44, 60), Color("7c8aa5"))
				draw_line(Vector2(cx - 128 + off, fy - 64), Vector2(cx - 128 + off, fy - 84), INK, 3)
				_chr("turis", "happy" if stage == "" else "annoyed", Vector2(cx - 80 + off, fy + 4), 150, false, a)
				_chr("turis_p", "idle" if stage == "" else "sad", Vector2(cx + 20 + off, fy + 4), 145, true, a)
				if stage == "":
					var r := Rect2(cx + 80, fy - 170 + bob, 64, 110)
					_box(r, Color("2b2f3a"), 2)
					draw_rect(r.grow(-6), Color("6cb6ff"))
					draw_string(ThemeDB.fallback_font, r.position + Vector2(8, 40), "Book", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
			"mules":
				_box(Rect2(cx + 50 * (1 if right else -1) - 50, fy - 220, 100, 216), Color("b9c7d4"))
				draw_circle(Vector2(cx + 50 * (1 if right else -1) + 30, fy - 110), 6, INK)
				if stage == "lega":
					_chr(ch, "happy", Vector2(cx - 90 * (1 if right else -1), fy + 4), 150, right)
				else:
					var sh := sin(t * 40.0) * 3.0
					draw_set_transform(Vector2(sh, 0))
					for i in range(3):
						var a2 := fmod(t * 1.5 + i * 0.33, 1.0)
						draw_string(ThemeDB.fallback_font, Vector2(cx - 60 + i * 50, fy - 240 - a2 * 40), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(0.85, 0.1, 0.1, 1.0 - a2))
					draw_set_transform(Vector2.ZERO)
		# penanda bisa diketuk
		if stage == "" or stage == "ignored":
			var bx := Vector2(sz.x * 0.5, 40 + sin(t * 4.0) * 6)
			draw_circle(bx, 26, Color("e0533d"))
			draw_circle(bx, 26, Color.WHITE, false, 4)
			draw_string(ThemeDB.fallback_font, bx + Vector2(-7, 14), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)

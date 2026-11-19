class_name Funny
extends Node
## Kejadian kocak bulanan: kira-kira satu kali tiap bulan game ada satu kejadian lucu.
## beruang  : Oyen tertukar anak beruang; induknya datang sopan menjemput, tamu kabur ketakutan.
## petir    : satu kamar tersambar petir, gosong, harus direnovasi.
## maling   : maling memanjat dinding luar; ketuk dia sebelum sampai jendela.
## hantu    : "hantu" di jendela kamar kosong (ternyata gorden). Calon penyewa menolak kamar itu.
## viral    : konten kreator bikin kost viral; tamu membludak 2 hari.
## durian   : pickup salah kirim sekotak durian, lobi bau seharian.

const GOSONG := "Gosong tersambar petir"
const LIST := ["beruang", "petir", "maling", "hantu", "viral", "durian", "zombie"]
const NAMES := {"beruang": "Anak Beruang Nyasar", "petir": "Tersambar Petir", "maling": "Maling Manjat Jendela",
	"hantu": "Hantu Kamar Kosong", "viral": "Kost Viral!", "durian": "Salah Kirim Durian", "zombie": "Serbuan Zombie?!"}
# Kaca jendela tiap gambar kamar acuan (px kamar).
const WIN := {"4L": Rect2(234, 42, 135, 128), "4R": Rect2(49, 42, 131, 129), "3L": Rect2(227, 42, 118, 115), "3R": Rect2(71, 42, 116, 115),
	"2L": Rect2(194, 34, 115, 113), "2R": Rect2(106, 34, 113, 113), "1L": Rect2(194, 26, 113, 111), "1R": Rect2(108, 26, 111, 112)}

var game: Node
var S: Dictionary
var cub: Node2D
var mama: Node2D
var durian: Node2D
var ghost: Node2D
var climber: Node2D
var _climb_t := 0.0
var _climb_f := 0
var _soot := {}          # kamar -> node jelaga


func setup(g: Node) -> void:
	game = g
	S = g.S
	if not S.has("funny"):
		S.funny = {"next": 9 + randi() % 6, "last": []}
	restore()


func st() -> Dictionary:
	return S.funny


## Pulihkan tampilan kejadian yang masih berlangsung setelah game dimuat.
func restore() -> void:
	var f: Dictionary = st()
	if f.get("cub", false): _show_cub()
	if f.get("ghost", "") != "": _show_ghost(str(f.ghost))
	if f.get("durian_until", -1) >= int(S.day): _show_durian()
	for id in D.ROOMS:
		if str(S.rooms[id].get("broken", "")) == GOSONG: _show_soot(id)


# ---------------- Jadwal ----------------
func daily() -> void:
	var f: Dictionary = st()
	if f.get("ghost", "") != "" and int(S.day) >= int(f.get("ghost_until", 0)):
		_ghost_gone(false)
	if f.get("durian_until", -1) >= 0 and int(S.day) > int(f.durian_until):
		_durian_gone()
	if int(S.day) >= int(f.get("next", 999999)):
		var pool := []
		for k in LIST:
			if k in f.get("last", []): continue
			if _possible(k): pool.append(k)
		if not pool.is_empty():
			start(pool.pick_random())
		f.next = int(S.day) + 25 + randi() % 11


func _possible(k: String) -> bool:
	match k:
		"petir": return game.each_tenant().size() > 0
		"hantu": return _empty_rooms().size() > 0
		"maling": return int(S.lvl) >= 2
		"beruang": return not st().get("cub", false)
	return true


func _empty_rooms() -> Array:
	var a := []
	for id in D.ROOMS:
		var r: Dictionary = S.rooms[id]
		if r.built and r.tenant == null and str(r.get("broken", "")) == "": a.append(id)
	return a


func start(k: String) -> void:
	var f: Dictionary = st()
	var last: Array = f.get("last", [])
	last.append(k)
	while last.size() > 2: last.pop_front()
	f.last = last
	game.add_xp(5)
	match k:
		"beruang": _start_bear()
		"petir": _start_lightning()
		"maling": _start_climber()
		"hantu": _start_ghost()
		"viral": _start_viral()
		"durian": _start_durian()
		"zombie": _start_zombie()
	game.dirty = true


func hourly(h: int) -> void:
	var f: Dictionary = st()
	if f.get("cub", false) and mama == null and int(S.day) * 24 + h >= int(f.get("mama_at", 0)):
		_mama_comes()
	if f.get("durian_until", -1) >= 0 and h == 21:
		_durian_gone()
		game.ui.toast("Bau durian akhirnya hilang. Lobi wangi lagi~")


## Kelipatan kedatangan calon penyewa (viral = jauh lebih sering).
func cand_mul() -> float:
	var f: Dictionary = st()
	var m := 1.0
	if int(f.get("viral_until", -1)) >= int(S.day): m *= 0.25
	if f.get("cub", false): m *= 4.0              # tamu takut beruang
	if int(f.get("durian_until", -1)) >= int(S.day): m *= 1.6
	return m


func haunted(id: String) -> bool:
	return str(st().get("ghost", "")) == id


func tick(dt: float) -> void:
	if climber != null:
		_climb_tick(dt)
	for id in _soot.keys():
		if str(S.rooms[id].get("broken", "")) != GOSONG:
			_soot[id].queue_free()
			_soot.erase(id)
			game.ui.toast("Kamar %s selesai direnovasi, tidak gosong lagi!" % D.room_name(id), "gold")


## Ketukan pemain. Koordinat layar (global).
func tap(p: Vector2) -> bool:
	if climber != null:
		var lp: Vector2 = p - game.bld.position
		if Rect2(climber.position + Vector2(-90, -230), Vector2(180, 260)).has_point(lp):
			_climber_caught()
			return true
	if ghost != null:
		var lp2: Vector2 = p - game.bld.position
		if Rect2(ghost.position - Vector2(30, 30), ghost.get_meta("size") + Vector2(60, 60)).has_point(lp2):
			_ghost_reveal()
			return true
	if cub != null and Rect2(cub.position + Vector2(-110, -150), Vector2(220, 170)).has_point(p):
		game.ui.open_sheet("funny", "beruang")
		return true
	if durian != null and Rect2(durian.position + Vector2(-110, -230), Vector2(220, 250)).has_point(p):
		game.ui.open_sheet("funny", "durian")
		return true
	return false


## Isi halaman pilihan untuk kejadian (dipakai ui._sheet_funny).
func sheet(k: String) -> Dictionary:
	match k:
		"beruang":
			return {"t": "Anak Beruang di Lobi", "d": "Oyen menghilang... dan di bantalnya malah tidur seekor anak beruang! Calon penyewa takut masuk. Induknya pasti sedang mencari.",
				"o": [["Tunggu induknya datang", D.C_CREAM, 0.0, func(): game.ui.close_sheet(); game.keeper_say("Sabar ya, Dek Beruang. Mamamu pasti datang.", 3.5)],
					["Telepon Damkar (langsung dijemput)", D.C_YELLOW, 200000.0, func(): game.ui.close_sheet(); _call_damkar()]]}
		"durian":
			return {"t": "Kotak Durian Nyasar", "d": "Pickup salah kirim sekotak durian Medan. Lobi bau menyengat! Sebagian penghuni suka, sebagian mual.",
				"o": [["Pesta durian bareng penghuni!", D.C_GREEN, 0.0, func(): game.ui.close_sheet(); _durian_party()],
					["Kembalikan ke kurir", D.C_CREAM, 0.0, func(): game.ui.close_sheet(); _durian_gone(); game.ui.toast("Kotak durian dikembalikan. Pintu dibuka lebar biar baunya keluar.")]]}
	return {"t": "", "d": "", "o": []}


# ================= Beruang =================
func _start_bear() -> void:
	var f: Dictionary = st()
	f.cub = true
	f.mama_at = int(S.day) * 24 + int(S.min) / 60 + 5
	_show_cub()
	game.sfx("bear", -4.0)
	game.ui.toast("Lho, itu bukan Oyen... itu ANAK BERUANG! Ketuk untuk pilihan.", "bad")
	game.keeper_say("Ya ampun! Oyen ke mana?! Ini kok... beruang?", 4.0)
	_scare_guests("Aaaa! Ada beruang!")


func _show_cub() -> void:
	if cub != null: return
	game.cat_spr.visible = false
	cub = _Bear.new()
	cub.small = true
	cub.position = game.CAT_FLOOR + Vector2(0, 4)
	game.lobby_root.add_child(cub)
	game.lobby_root.move_child(cub, game.npc_lobby.get_index())


## Calon penyewa di lobi lari ketakutan.
func _scare_guests(line: String) -> void:
	var said := false
	for n in game.npcs.values():
		if n.kind == "cand" and n.scene == "lobby":
			if not said:
				n.say(line, 2.4)
				said = true
			n.set_meta("spd", 2.4)
			n.art_map["walk"] = "run"
	var keep := []
	for p in S.queue:
		if p.get("auto", false): keep.append(p)
	var lost: int = S.queue.size() - keep.size()
	S.queue = keep
	if lost > 0:
		game.ui.toast("%d calon penyewa kabur ketakutan!" % lost, "bad")


func _mama_comes() -> void:
	mama = _Bear.new()
	mama.position = Vector2(D.OUT_X - 100, D.LOBBY_Y)
	game.npc_lobby.add_child(mama)
	game.sfx("arrive", -10.0)
	var t := mama.create_tween()
	t.tween_property(mama, "position:x", cub.position.x + 210, 4.5)
	t.tween_callback(func():
		mama.walking = false
		mama.bow = 1.0
		game.sfx("bear", -6.0)
		game.npc_say_at(mama.position + Vector2(0, -400), "Permisi... maaf, anak saya nyasar ke sini.", 3.5)
		game.keeper_say("E-eh, iya Bu... silakan dijemput.", 3.0))
	t.tween_interval(3.2)
	t.tween_callback(func():
		mama.bow = 0.0
		cub.reparent(mama)
		cub.position = Vector2(-60, -150)
		cub.scale = Vector2(0.7, 0.7)
		mama.walking = true
		mama.flip = true
		game.npc_say_at(mama.position + Vector2(0, -400), "Terima kasih sudah dijaga. Ini madu, buat Mbak.", 3.0))
	t.tween_property(mama, "position:x", D.OUT_X - 300, 5.0)
	t.tween_callback(_bear_done.bind(true))


func _call_damkar() -> void:
	if float(S.money) < 200000:
		game.ui.toast(game.ui.money_why(200000), "bad"); return
	game.spend(200000, "other")
	if mama != null: return
	_bear_done(false)
	game.ui.toast("Petugas Damkar menjemput anak beruang dengan aman. Oyen pulang dari atap!", "gold")


func _bear_done(polite: bool) -> void:
	var f: Dictionary = st()
	f.cub = false
	if mama != null:
		mama.queue_free()
		mama = null
	if cub != null and is_instance_valid(cub):
		cub.queue_free()
	cub = null
	game.cat_spr.visible = true
	game.sfx("meow", -4.0)
	if polite:
		S.money = float(S.money) + 150000
		game.ui.toast("Induk beruang pamit sopan dan meninggalkan sebotol madu (+Rp 150rb). Oyen keluar dari kolong meja!", "gold")
		game.add_xp(15)
	game.dirty = true


# ================= Petir =================
func _start_lightning() -> void:
	var occ: Array = game.each_tenant()
	var id: String = occ.pick_random()[0]
	var r: Dictionary = S.rooms[id]
	r.broken = GOSONG
	if r.tenant != null:
		r.tenant.happy = maxf(0.0, float(r.tenant.happy) - 15.0)
	game.jump_to_floor(D.fl(id))
	# Kilat dari langit ke atap kamar + layar berkedip putih.
	var rect := D.rect_of(id)
	var bolt := _Bolt.new()
	bolt.a = Vector2(rect.get_center().x + randf_range(-60, 60), D.BUILDING_TOP - 260)
	bolt.b = Vector2(rect.get_center().x, rect.position.y + 40)
	game.bld.add_child(bolt)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 0.95, 0.9)
	flash.size = Vector2(D.IW, D.IH)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cl := CanvasLayer.new()
	cl.layer = 55
	cl.add_child(flash)
	game.add_child(cl)
	var t := flash.create_tween()
	t.tween_property(flash, "color:a", 0.0, 0.18)
	t.tween_property(flash, "color:a", 0.7, 0.05)
	t.tween_property(flash, "color:a", 0.0, 0.5)
	t.tween_callback(cl.queue_free)
	var t2 := bolt.create_tween()
	t2.tween_interval(0.5)
	t2.tween_property(bolt, "modulate:a", 0.0, 0.4)
	t2.tween_callback(bolt.queue_free)
	game.sfx("thunder", 0.0)
	_show_soot(id)
	game.ui.toast("JDERR! Petir menyambar Kamar %s, kamarnya gosong! Panggil teknisi untuk renovasi." % D.room_name(id), "bad")
	if r.tenant != null and game.npcs.has(r.tenant.id):
		game.npcs[r.tenant.id].say("Rambutku kriting! Kamarku gosong!", 3.5)
		game.npcs[r.tenant.id].react("angry", 3.0)


func _show_soot(id: String) -> void:
	if _soot.has(id) or not game.room_fx.has(id): return
	var s := _Soot.new()
	s.sz = D.rect_of(id).size
	game.room_fx[id].add_child(s)
	_soot[id] = s


# ================= Maling manjat =================
func _start_climber() -> void:
	var top: int = 1
	for id in D.ROOMS:
		if S.rooms[id].built: top = maxi(top, D.fl(id))
	_climb_f = clampi(randi_range(2, top), 1, top)
	climber = _Climber.new()
	climber.tex = load("res://assets/chars/maling/caught_R.png")
	climber.side = [-1, 1].pick_random()
	climber.position = Vector2(66 if climber.side < 0 else D.IW - 66, D.LOBBY_TOP + 20)
	climber.goal_y = D.ROWS[_climb_f].x + 190
	climber.rope_top = D.BUILDING_TOP + 40
	game.bld.add_child(climber)
	_climb_t = 0.0
	game.jump_to_floor(maxi(1, _climb_f - 1))
	game.sfx("pop", -8.0)
	game.ui.toast("Ada maling memanjat dinding luar ke lantai %d! Ketuk dia cepat!" % _climb_f, "bad")
	game.keeper_say("Eh?! Ada yang manjat tembok!", 3.0)


func _climb_tick(dt: float) -> void:
	var sp := float(int(S.speed))
	if sp <= 0.0 or climber.falling: return
	var speed := 70.0 * (1.0 + (sp - 1.0) * 0.5)
	climber.position.y -= speed * dt
	game.set_scroll(clampf(-climber.position.y + D.IH * 0.55, 0.0, game.max_scroll()))
	if climber.position.y <= climber.goal_y:
		var loss := minf(maxf(float(S.money) * 0.04, 100000), 500000)
		if S.fac.has("cctv"):
			game.ui.toast("Maling masuk lewat jendela, tapi CCTV merekamnya. Polisi mengembalikan barangnya!", "gold")
		else:
			game.spend(loss, "other")
			game.ui.toast("Maling berhasil masuk lewat jendela lantai %d! Hilang %s." % [_climb_f, D.rp(loss)], "bad")
		climber.queue_free()
		climber = null


func _climber_caught() -> void:
	climber.falling = true
	game.sfx("pop", -2.0)
	var c := climber
	c.say = "Aduh! Ketahuan!"
	var t := c.create_tween()
	t.tween_property(c, "position:y", D.LOBBY_TOP + 10, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): c.say = "Ampun, kabur!")
	t.tween_property(c, "position:x", -200.0 if c.side < 0 else D.IW + 200.0, 1.2)
	t.tween_callback(c.queue_free)
	climber = null
	game.add_xp(12)
	game.ui.toast("Kamu berteriak \"MALING!\". Dia jatuh ke semak-semak dan kabur!", "gold")


# ================= Hantu (gorden) =================
func _start_ghost() -> void:
	var id: String = _empty_rooms().pick_random()
	st().ghost = id
	st().ghost_until = int(S.day) + 3
	_show_ghost(id)
	game.jump_to_floor(D.fl(id))
	game.sfx("whoosh", -2.0)
	game.ui.toast("Penghuni bilang ada HANTU di jendela Kamar %s! Calon penyewa tidak mau ke sana. Ketuk untuk memeriksa." % D.room_name(id), "bad")


func _show_ghost(id: String) -> void:
	if ghost != null: ghost.queue_free()
	var w: Rect2 = WIN.get(D.tpl(id), Rect2(120, 40, 120, 115))
	var rect := D.rect_of(id)
	ghost = _Ghost.new()
	ghost.position = rect.position + w.position
	ghost.set_meta("size", w.size)
	ghost.sz = w.size
	game.bld.add_child(ghost)


func _ghost_reveal() -> void:
	game.sfx("whoosh", -8.0)
	ghost.revealed = true
	game.keeper_say("Lho... ternyata cuma gorden tertiup angin, hihi.", 3.5)
	game.ui.toast("Ternyata cuma gorden putih tertiup angin! Kamar bisa disewakan lagi.", "gold")
	game.add_xp(10)
	_ghost_gone(true)


func _ghost_gone(revealed: bool) -> void:
	st().ghost = ""
	if ghost != null:
		var g := ghost
		ghost = null
		var t := g.create_tween()
		t.tween_interval(2.5 if revealed else 0.0)
		t.tween_property(g, "modulate:a", 0.0, 0.8)
		t.tween_callback(g.queue_free)


# ================= Viral =================
func _start_viral() -> void:
	var n := Npc.new()
	game.npc_lobby.add_child(n)
	n.setup("kreator", "visitor", D.STAFF_LOOK.teknisi, Vector2(D.IW + 200, D.LOBBY_Y), game.font)
	n.art = true
	n.char_id = "flanel"
	n.art_map = {"walk": "walk", "stand": "happy"}
	game.npcs["kreator"] = n
	game.sfx("arrive", -10.0)
	game.ui.toast("Seorang konten kreator datang merekam kost-mu...")
	n.plan("lobby", Vector2(820, D.LOBBY_Y), "stand", func(m: Npc):
		m.dir = -1
		m.say("Halo guys! Kost ini estetik parah!", 3.0)
		m.work = {"t": 7.0, "pose": "stand", "fn": func(k: Npc):
			k.say("Jangan lupa like & share ya~", 2.5)
			_go_viral()
			k.plan("lobby", Vector2(D.IW + 250, D.LOBBY_Y), "stand", func(z: Npc): game._remove_npc(z))})


func _go_viral() -> void:
	st().viral_until = int(S.day) + 2
	S.rep = clampf(float(S.rep) + 0.1, 1.0, 5.0)
	S.next_cand = minf(float(S.next_cand), 20.0)
	game.ui.toast("Videonya VIRAL! 1,2 juta views. Calon penyewa membludak 2 hari ke depan!", "gold")
	game.keeper_say("Waduh, kita masuk FYP!", 3.0)


# ================= Durian =================
func _start_durian() -> void:
	st().durian_until = int(S.day)
	_show_durian()
	for e in game.each_tenant():
		var t: Dictionary = e[1].tenant
		t.happy = maxf(0.0, float(t.happy) - 4.0)
	game.sfx("arrive", -10.0)
	game.ui.toast("Pickup salah kirim: sekotak DURIAN di lobi! Baunya ke mana-mana. Ketuk kotaknya.", "bad")
	game.keeper_say("Uhuk... bau apa ini?! Durian?!", 3.5)


func _show_durian() -> void:
	if durian != null: return
	durian = _Durian.new()
	durian.position = Vector2(870, D.LOBBY_Y - 6)
	game.lobby_root.add_child(durian)
	game.lobby_root.move_child(durian, game.npc_lobby.get_index())


func _durian_party() -> void:
	var love := 0
	for e in game.each_tenant():
		var t: Dictionary = e[1].tenant
		if absi(str(t.id).hash()) % 3 != 0:
			t.happy = minf(100.0, float(t.happy) + 10.0)
			love += 1
		else:
			t.happy = maxf(0.0, float(t.happy) - 3.0)
	game.keeper_say("Ayo makan durian bareng! Yang nggak suka, maaf ya~", 3.5)
	game.ui.toast("Pesta durian! %d penghuni senang banget, sisanya tutup hidung." % love, "gold")
	game.add_xp(8)
	_durian_gone()


func _durian_gone() -> void:
	st().durian_until = -1
	if durian != null:
		durian.queue_free()
		durian = null


# ================= Gambar =================
## Beruang gambar tangan sederhana (induk berdiri sopan pakai topi bunga; anak tidur meringkuk).
class _Bear extends Node2D:
	var small := false
	var walking := true
	var flip := false
	var bow := 0.0
	var t := 0.0
	const INK := Color("3e2b1d")
	const FUR := Color("9a6a45")
	const FUR2 := Color("7d5234")
	const MUZ := Color("e9cfa8")
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _ell(c: Vector2, r: Vector2, col: Color, outline := true) -> void:
		var pts := PackedVector2Array()
		for i in range(32):
			var a := TAU * i / 32.0
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, col)
		if outline:
			pts.append(pts[0])
			draw_polyline(pts, INK, 5.0 if not small else 4.0, true)
	func _draw() -> void:
		if small:
			# Anak beruang meringkuk tidur di bantal Oyen
			var br := sin(t * 2.0) * 3.0
			_ell(Vector2(0, -10), Vector2(100, 22), Color("e7c9a0"))
			_ell(Vector2(0, -48), Vector2(78, 46 + br * 0.4), FUR)
			_ell(Vector2(48, -78), Vector2(40, 36), FUR)
			_ell(Vector2(26, -108), Vector2(13, 13), FUR)
			_ell(Vector2(70, -108), Vector2(13, 13), FUR)
			_ell(Vector2(62, -66), Vector2(17, 12), MUZ)
			draw_circle(Vector2(66, -71), 4.5, INK)
			draw_arc(Vector2(40, -82), 7, 0.2, PI - 0.2, 8, INK, 3.5)
			draw_arc(Vector2(62, -86), 7, 0.2, PI - 0.2, 8, INK, 3.5)
			_ell(Vector2(-60, -28), Vector2(22, 16), FUR2)
			var z := Vector2(90, -140 - fmod(t * 20.0, 40.0))
			draw_string(ThemeDB.fallback_font, z, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(INK, 1.0 - fmod(t * 20.0, 40.0) / 40.0))
			return
		var s := -1.0 if flip else 1.0
		var step := sin(t * 8.0) * (12.0 if walking else 0.0)
		draw_set_transform(Vector2.ZERO, bow * 0.18 * s, Vector2(s, 1))
		# kaki
		_ell(Vector2(-38, -40 + maxf(0.0, step) * -0.6), Vector2(30, 44), FUR2)
		_ell(Vector2(38, -40 + maxf(0.0, -step) * -0.6), Vector2(30, 44), FUR2)
		# badan + perut
		_ell(Vector2(0, -150), Vector2(92, 112), FUR)
		_ell(Vector2(0, -132), Vector2(56, 70), MUZ, false)
		# tas tangan
		draw_line(Vector2(-86, -170), Vector2(-104, -96), INK, 4.0)
		draw_rect(Rect2(-130, -100, 56, 44), Color("e98b7a"))
		draw_rect(Rect2(-130, -100, 56, 44), INK, false, 4.0)
		# lengan
		_ell(Vector2(-84, -168 + step * 0.4), Vector2(24, 52), FUR)
		_ell(Vector2(84, -168 - step * 0.4), Vector2(24, 52), FUR)
		# kepala
		_ell(Vector2(-58, -318), Vector2(26, 26), FUR)
		_ell(Vector2(58, -318), Vector2(26, 26), FUR)
		_ell(Vector2(0, -268), Vector2(78, 70), FUR)
		_ell(Vector2(0, -240), Vector2(34, 25), MUZ)
		draw_circle(Vector2(0, -252), 9, INK)
		draw_arc(Vector2(0, -238), 12, 0.3, PI - 0.3, 10, INK, 3.5)
		draw_circle(Vector2(-30, -282), 7, INK)
		draw_circle(Vector2(30, -282), 7, INK)
		draw_circle(Vector2(-48, -256), 10, Color(1, 0.6, 0.6, 0.45))
		draw_circle(Vector2(48, -256), 10, Color(1, 0.6, 0.6, 0.45))
		# topi bunga
		draw_colored_polygon(PackedVector2Array([Vector2(-70, -322), Vector2(70, -322), Vector2(50, -350), Vector2(-50, -350)]), Color("f3d9a4"))
		draw_polyline(PackedVector2Array([Vector2(-70, -322), Vector2(70, -322), Vector2(50, -350), Vector2(-50, -350), Vector2(-70, -322)]), INK, 4.0)
		for i in range(5):
			draw_circle(Vector2(36, -352) + Vector2(cos(TAU * i / 5.0), sin(TAU * i / 5.0)) * 11, 8, Color("f4a7b9"))
		draw_circle(Vector2(36, -352), 6, Color("f7d36e"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class _Bolt extends Node2D:
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	func _draw() -> void:
		var pts := PackedVector2Array([a])
		var n := 9
		for i in range(1, n):
			var k := float(i) / n
			pts.append(a.lerp(b, k) + Vector2(randf_range(-55, 55), 0))
		pts.append(b)
		draw_polyline(pts, Color(1, 0.95, 0.5, 0.45), 26.0)
		draw_polyline(pts, Color("fff7c2"), 10.0)
		draw_polyline(pts, Color.WHITE, 4.0)


## Jelaga gosong + asap tipis di kamar yang tersambar petir.
class _Soot extends Node2D:
	var sz := Vector2(420, 367)
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.12, 0.09, 0.07, 0.42))
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in range(14):
			var c := Vector2(rng.randf_range(20, sz.x - 20), rng.randf_range(10, sz.y * 0.7))
			draw_circle(c, rng.randf_range(14, 34), Color(0.08, 0.06, 0.05, 0.16))
		for i in range(5):
			var k := fmod(t * 0.25 + i * 0.2, 1.0)
			var p := Vector2(sz.x * (0.2 + 0.15 * i), sz.y * 0.75 - k * sz.y * 0.7)
			draw_circle(p, 16 + k * 30, Color(0.55, 0.55, 0.55, 0.35 * (1.0 - k)))


## Maling memanjat tali di dinding luar.
class _Climber extends Node2D:
	var tex: Texture2D
	var side := -1
	var goal_y := 0.0
	var rope_top := 0.0
	var falling := false
	var say := ""
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		if not falling:
			draw_line(Vector2(0, rope_top - position.y), Vector2(0, 40), Color("8a6a3a"), 5.0)
			draw_circle(Vector2(0, goal_y - position.y - 20), 14 + sin(t * 6.0) * 4, Color(1, 0.3, 0.2, 0.5))
		var h := 200.0
		var w := h * tex.get_width() / tex.get_height()
		var wob := sin(t * 9.0) * 6.0 if not falling else 0.0
		draw_texture_rect(tex, Rect2(-w / 2 + wob, -h + 30, w, h), false)
		if say != "":
			var f := ThemeDB.fallback_font
			var tw := f.get_string_size(say, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			var r := Rect2(-tw / 2 - 18 + (140.0 * -side), -h - 40, tw + 36, 54)
			draw_rect(r, Color("fffaf0"))
			draw_rect(r, Color("3e2b1d"), false, 3.0)
			draw_string(f, r.position + Vector2(18, 38), say, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("3e2b1d"))


## "Hantu" putih melambai di jendela. Setelah diperiksa: cuma gorden.
class _Ghost extends Node2D:
	var sz := Vector2(120, 115)
	var t := 0.0
	var revealed := false
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		var pts := PackedVector2Array()
		var n := 14
		pts.append(Vector2(0, 0))
		pts.append(Vector2(sz.x, 0))
		for i in range(n + 1):
			var k := float(i) / n
			var x := sz.x * (1.0 - k)
			var wave := sin(t * 3.0 + k * 9.0) * 10.0
			pts.append(Vector2(x + wave * 0.5, sz.y + 6 + wave))
		draw_colored_polygon(pts, Color(1, 1, 1, 0.82))
		for i in range(1, 4):
			var x := sz.x * i / 4.0 + sin(t * 3.0 + i) * 5.0
			draw_line(Vector2(x, 4), Vector2(x + sin(t * 3.0 + i * 2.0) * 6.0, sz.y), Color(0.75, 0.78, 0.85, 0.7), 3.0)
		if not revealed:
			var e := Vector2(sz.x * 0.5, sz.y * 0.45)
			draw_circle(e + Vector2(-20, 0), 9, Color(0.15, 0.15, 0.2))
			draw_circle(e + Vector2(20, 0), 9, Color(0.15, 0.15, 0.2))
			draw_arc(e + Vector2(0, 30), 13, PI + 0.3, TAU - 0.3, 10, Color(0.15, 0.15, 0.2), 4.0)
			draw_string(ThemeDB.fallback_font, Vector2(sz.x + 8, 10 + sin(t * 2.0) * 6.0), "hiii~", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.4, 0.45, 0.6))
		else:
			draw_line(Vector2(-6, -2), Vector2(sz.x + 6, -2), Color("8a6a4a"), 6.0)


## Kotak durian dengan garis bau hijau.
class _Durian extends Node2D:
	var t := 0.0
	const INK := Color("3e2b1d")
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(-90, -110, 180, 110), Color("c99a62"))
		draw_rect(Rect2(-90, -110, 180, 110), INK, false, 5.0)
		draw_line(Vector2(-90, -78), Vector2(90, -78), INK, 3.0)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(-62, -30), "DURIAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)
		# durian menyembul
		for c in [Vector2(-34, -124), Vector2(30, -128)]:
			draw_circle(c, 34, Color("9bb34a"))
			for i in range(10):
				var a := TAU * i / 10.0
				draw_colored_polygon(PackedVector2Array([c + Vector2(cos(a - 0.15), sin(a - 0.15)) * 32, c + Vector2(cos(a), sin(a)) * 46, c + Vector2(cos(a + 0.15), sin(a + 0.15)) * 32]), Color("7f9a33"))
			draw_arc(c, 34, 0, TAU, 24, INK, 4.0)
		# garis bau
		for i in range(4):
			var x := -70.0 + i * 46.0
			var pts := PackedVector2Array()
			for j in range(12):
				var y := -170.0 - j * 14.0 - fmod(t * 40.0, 14.0)
				pts.append(Vector2(x + sin(t * 3.0 + j * 0.8 + i) * 12.0, y))
			draw_polyline(pts, Color(0.45, 0.7, 0.2, 0.6), 5.0)


# ================= Zombie (ternyata karnaval Halloween) =================
var zombies: Array = []


func _start_zombie() -> void:
	zombies.clear()
	for i in range(6):
		var n := Npc.new()
		game.npc_lobby.add_child(n)
		var nid := "zombie%d" % i
		n.setup(nid, "visitor", D.STAFF_LOOK.teknisi, Vector2(D.IW + 160 + i * 130, D.LOBBY_Y), game.font)
		n.art = true
		n.char_id = "zombie" if i % 2 == 0 else "zombie2"
		n.art_map = {"walk": "walk", "stand": "reach"}
		n.set_meta("spd", 0.45)
		n.dir = -1
		n.set_meta("nama", "???")
		game.npcs[nid] = n
		zombies.append(n)
		n.plan("lobby", Vector2(560 + i * 120, D.LOBBY_Y), "stand")
	game.sfx("whoosh", -2.0)
	game.ui.toast("Gerombolan ZOMBIE menyerbu kost! Tamu berlarian ketakutan!", "bad")
	game.keeper_say("Aaaa! Zombie?! Semuanya masuk kamar!", 3.5)
	_scare_guests("Zombieee! Kabuuur!")
	# Penghuni di lobi lari keluar; yang paling tidak betah terlanjur pindah.
	var worst: Dictionary = {}
	var worst_r := ""
	for e in game.each_tenant():
		var t: Dictionary = e[1].tenant
		if game.npcs.has(t.id) and game.npcs[t.id].scene == "lobby":
			game.npcs[t.id].say("Tolooong!", 1.6)
		if float(t.happy) < 55.0 and (worst.is_empty() or float(t.happy) < float(worst.happy)):
			worst = t
			worst_r = e[0]
	if not worst.is_empty():
		var tn: String = worst.name
		game._sad_leave[worst.id] = true
		S.rooms[worst_r].tenant = null
		game.ui.toast("%s terlanjur kabur dan pindah dari kost karena ketakutan..." % tn, "bad")
	var t := game.create_tween()
	t.tween_interval(9.0)
	t.tween_callback(_zombie_reveal)


func _zombie_reveal() -> void:
	game.ui.toast("Eh, ternyata cuma rombongan KARNAVAL HALLOWEEN! Mereka minta foto bareng.", "gold")
	game.keeper_say("Ya ampun... kirain zombie beneran, hahaha!", 3.5)
	var lines := ["Trick or treat!", "Hehe, maaf bikin kaget!", "Ayo foto bareng!", "Karnaval Halloween, Kak!", "Mampir ya ke parade!", "Boo! Hahaha"]
	var i := 0
	for z in zombies:
		if not is_instance_valid(z): continue
		z.say(lines[i % lines.size()], 2.6)
		z.art_map["stand"] = "happy"
		z.set_meta("nama", "Peserta Karnaval")
		i += 1
	S.rep = clampf(float(S.rep) + 0.05, 1.0, 5.0)
	S.next_cand = minf(float(S.next_cand), 30.0)
	game.add_xp(15)
	var t := game.create_tween()
	t.tween_interval(4.0)
	t.tween_callback(func():
		for z in zombies:
			if not is_instance_valid(z): continue
			z.set_meta("spd", 1.0)
			z.plan("lobby", Vector2(-260, D.LOBBY_Y), "stand", func(m: Npc): game._remove_npc(m))
		zombies.clear())

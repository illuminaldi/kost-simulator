extends Node2D
## Kost Simulator — logika utama: waktu, ekonomi, penyewa, NPC, cahaya, input.

const SAVE_PATH := "user://kost_save.json"
const WALLET_PATH := "user://wallet.json"   # dompet terpisah: tidak ikut terhapus saat "Mulai baru"
const TURBO_MIN := 7 * 1440                 # 1 Tiket Ngebut = 2x selama 7 hari di dalam game
const FREE_TICKETS := 3
const PLAN_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 s = vec3(g * 1.05, g * 0.98, g * 0.88);
	s = mix(s, vec3(0.94, 0.89, 0.82), 0.5);
	float st = step(0.5, fract((FRAGCOORD.x + FRAGCOORD.y) / 22.0));
	s *= 1.0 - st * 0.05;
	COLOR = vec4(s, c.a);
}
"""
# Warna CanvasModulate per jam (siang putih, malam kebiruan).
const TINT := [[0.0, Color(0.45, 0.5, 0.78)], [4.5, Color(0.45, 0.5, 0.78)], [6.0, Color(0.95, 0.8, 0.75)],
	[7.5, Color(1, 0.97, 0.93)], [9.0, Color.WHITE], [15.5, Color.WHITE], [17.0, Color(1, 0.86, 0.72)],
	[18.3, Color(0.8, 0.66, 0.78)], [19.3, Color(0.45, 0.5, 0.78)], [24.01, Color(0.45, 0.5, 0.78)]]
const GLOW := [[0.0, 1.0], [5.0, 1.0], [6.6, 0.0], [17.0, 0.0], [18.2, 0.55], [19.2, 1.0], [24.01, 1.0]]

var S: Dictionary = {}
var ui: Ui
var art: Texture2D
var shell_tex: Texture2D
var font: Font
var font_m: Font
var plan_mat: ShaderMaterial

var npc_layer: Node2D          # NPC di dalam gedung (ikut scroll)
var npc_lobby: Node2D          # NPC di lobi (tetap)
var bld: Node2D                # akar gedung yang bisa di-scroll
var lobby_root: Node2D
var scroll := 0.0
var scroll_v := 0.0
var pan := {}
var _last_btn := {}      # true/false (press/release) -> [msec, posisi]
var truck: Sprite2D
var cat_spr: Sprite2D
var funny: Funny
var _cat_pets := 0
var app_tablet: Sprite2D
var app_banner: Sprite2D
var driver: Sprite2D
var facil_sp := {}
var facil_lights := {}
var box_tex: Texture2D
var box_nodes: Array = []
var truck_state := "gone"      # gone / coming / parked / going
var fx_layer: Node2D
var canvas_mod: CanvasModulate
var room_fx := {}
var room_lights := {}
var fixed_lights: Array = []
var npcs := {}
var recep: Npc
var recep_art: Sprite2D
var desk_tag: PanelContainer

var dirty := true
var _acc := 0.0
var _brain_acc := 0.0
var _save_acc := 0.0
var _light_tex: Texture2D
var _sad_leave := {}
var dekor := false            # mode Dekor (baki perabot terbuka)
var drag := {}                # {kind, item, start, active}
var _hover_room := ""


func _ready() -> void:
	randomize()
	art = load("res://assets/kost-art.jpg")
	shell_tex = load("res://assets/kost-shell.jpg")
	font = load("res://assets/fonts/Fredoka-SemiBold.woff2")
	font_m = load("res://assets/fonts/Fredoka-Medium.woff2")
	plan_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = PLAN_SHADER
	plan_mat.shader = sh
	var peek := _load_game_raw()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--floors="): peek = {"open_floor": int(a.substr(9)) - 1}
	D.setup_floors(wanted_top(peek))
	_build_world()
	_setup_music()
	ui = Ui.new()
	add_child(ui)
	ui.setup(self, art, font, font_m)
	ui.make_side()
	var args := OS.get_cmdline_user_args()
	if not args.has("--fresh"):
		S = _load_game()
	if S.is_empty():
		_new_game()
	_load_wallet()
	wa = WaGroup.new(self)
	apply_volume.call_deferred()
	if int(S.speed) > 2: S.speed = 2
	if int(S.speed) == 2 and int(W.turbo_min) <= 0: S.speed = 1
	_materialize_window(vis_floors())
	_refresh_world()
	if not args.has("--fresh"): _offline_gain()
	for a0 in args:
		if a0.begins_with("--away="):
			S.saved_at = Time.get_unix_time_from_system() - float(a0.substr(7)) * 3600.0
			_offline_gain()
	# Tangga & cat ruang tangga dibuat sebelum save dimuat, jadi segarkan lagi di sini.
	_refresh_stairs()
	_refresh_hall_paint()
	_sync_npcs()
	_refresh_cargo()
	_refresh_bags()
	ui.update_hud()
	_handle_cli(args)
	season = Season.new(self)
	var sov := ""
	for a1 in args:
		if a1.begins_with("--season="): sov = a1.substr(9)
	if not args.has("--fresh") or sov != "": season.start(sov)
	_maybe_intro.call_deferred(args)


# ================= Cerita pembuka & tutorial =================
var cutscene_on := false


func _maybe_intro(args: PackedStringArray) -> void:
	# Pembuka brand (KelolaPro → KostTerdekat → Cozy Kost) setiap game dibuka; dilewati saat uji CLI.
	var dev := false
	for a in args:
		if a.begins_with("--") and a != "--brand" and a != "--brandtap": dev = true
	if args.has("--brand") or args.has("--brandtap") or not dev:
		cutscene_on = true
		var bi := BrandIntro.new()
		add_child(bi)
		bi.setup(font, S.get("sfx", true), args.has("--brand") and not args.has("--brandtap"))
		await bi.finished
		cutscene_on = false
	if args.has("--intro") or not S.get("seen", false):
		var cs := play_intro()
		for a in args:
			if a.begins_with("--introat="):
				for _i in range(int(a.substr(10))): cs._next()
	elif int(S.get("tut", -1)) >= 0:
		ui.tutorial.start(int(S.tut))
	elif not away.is_empty():
		ui.open_sheet("away")
	if restored_from != "":
		ui.toast("Data utama rusak, dipulihkan dari cadangan otomatis." if restored_from != "gagal" else "Data save rusak dan tidak bisa dipulihkan. Mulai kost baru.", "bad")


func _tapat(p: Vector2, delay: float = 1.5) -> void:
	if thief != null: print("THIEFPOS ", thief.global_position)
	await get_tree().create_timer(delay).timeout
	if thief != null: print("THIEFPOS ", thief.global_position)
	Input.warp_mouse(p)
	await get_tree().create_timer(0.1).timeout
	for pr in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = p
		e.global_position = p
		e.pressed = pr
		Input.parse_input_event(e)
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(1.5).timeout
	print("TAP money=", S.money," due=", due_total()," sheet=", ui.kind," brand=", get_children().any(func(c): return c is BrandIntro)," cut=", get_children().any(func(c): return c is Cutscene))


func _bagdrag_test() -> void:
	await get_tree().create_timer(0.6).timeout
	if OS.get_cmdline_user_args().has("--bighouse"):
		S.lvl = 24
		S.fac["lift"] = true
		_refresh_lift()
		for id in D.ROOMS:
			if D.fl(id) <= 9:
				S.rooms[id].built = true
				S.rooms[id].furn = {"kasur": 1}
				S.rooms[id].tenant = gen_person("l")
		_refresh_world()
		_sync_npcs()
		jump_to_floor(7)
		await get_tree().create_timer(0.6).timeout
	var e0: Array = each_tenant()
	if OS.get_cmdline_user_args().has("--bighouse"):
		e0 = e0.filter(func(x): return x[0] == "7R")
	drop_bag(str(e0[0][1].tenant.id), str(e0[0][1].tenant.name), e0[0][0], "mie ayam")
	await get_tree().create_timer(0.3).timeout
	var bp: Vector2 = bag_nodes[0].position + Vector2(0, -50)
	var rp: Vector2 = D.rect_of(e0[0][0]).get_center() + Vector2(0, scroll)
	print("BAGTEST bag at ", bp," room ", e0[0][0]," at ", rp)
	var seq := [[bp, true]]
	for k in range(1, 9): seq.append([bp.lerp(rp, k / 8.0), null])
	seq.append([rp, false])
	for st in seq:
		var ev: InputEvent
		if st[1] == null:
			ev = InputEventMouseMotion.new()
		else:
			ev = InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = st[1]
		ev.position = st[0]
		ev.global_position = st[0]
		Input.warp_mouse(st[0])
		Input.parse_input_event(ev)
		await get_tree().create_timer(0.08).timeout
	await get_tree().create_timer(0.5).timeout
	print("BAGTEST drag=", drag," bags=", S.bags.size()," frames ok")
	await get_tree().create_timer(1.0).timeout
	print("BAGTEST still alive, min=", S.min)


## Uji acak: ketuk & seret di sembarang tempat, laporkan kalau waktu game berhenti.
func _monkey() -> void:
	await get_tree().create_timer(1.0).timeout
	if not OS.get_cmdline_user_args().has("--big24"):
		S.lvl = 12
		S.money = 50000000.0
		S.fac["lift"] = true
		_refresh_lift()
	var last_min := int(S.min) + int(S.day) * 1440
	var stuck := 0
	for i in range(900):
		var a := Vector2(randf_range(20, D.IW - 20), randf_range(250, D.IH - 20))
		var b := a + Vector2(randf_range(-500, 500), randf_range(-900, 400))
		var drag_it := randf() < 0.5
		for st in ([[a, true], [b, null], [b, false]] if drag_it else [[a, true], [a, false]]):
			var ev: InputEvent
			if st[1] == null:
				ev = InputEventMouseMotion.new()
			else:
				ev = InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = st[1]
			ev.position = st[0]
			ev.global_position = st[0]
			Input.warp_mouse(st[0])
			Input.parse_input_event(ev)
			await get_tree().process_frame
		if randf() < 0.15 and ui.kind != "": ui.close_sheet()
		if randf() < 0.05 and ui.side.visible: ui.side._walk(1)
		await get_tree().create_timer(0.05).timeout
		if i % 50 == 49:
			var now := int(S.min) + int(S.day) * 1440
			print("MONKEY i=", i, " t=", now, " sheet=", ui.kind, " side=", ui.side.visible, " drag=", drag.get("kind", ""), " speed=", S.speed, " cut=", cutscene_on)
			if now == last_min: stuck += 1
			last_min = now
	print("MONKEY done stuck=", stuck)
	get_tree().quit()


func _clicktest() -> void:
	await get_tree().create_timer(2.5).timeout
	for i in range(4):
		for pr in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.position = Vector2(700, 800)
			e.global_position = e.position
			e.pressed = pr
			Input.parse_input_event(e)
			await get_tree().create_timer(0.15).timeout
		await get_tree().create_timer(0.6).timeout
	for c in get_children():
		if c is Cutscene: print("CUTSCENE idx=", c.idx)


func play_intro() -> Cutscene:
	ui.close_sheet()
	ui.tutorial.visible = false
	cutscene_on = true
	var cs := Cutscene.new()
	add_child(cs)
	cs.setup(ui, font, art, str(S.get("kost_name", "Kost Harmoni")))
	cs.finished.connect(func(nm: String):
		cutscene_on = false
		var first: bool = not S.get("seen", false)
		S.kost_name = nm
		S.seen = true
		_refresh_sign()
		ui.toast("%s resmi dibuka!" % nm, "gold")
		if first:
			ui.tutorial.start(0)
		save_game())
	return cs


var kost_sign: PanelContainer


func _refresh_sign() -> void:
	if kost_sign:
		(kost_sign.get_child(0) as Label).text = str(S.get("kost_name", "Kost Harmoni"))
		kost_sign.reset_size()
		kost_sign.position.x = 770.0 - kost_sign.size.x / 2.0


# ================= Dunia =================
func _sprite(parent: Node, region: Rect2, at: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = art
	sp.centered = false
	sp.region_enabled = true
	sp.region_rect = region
	sp.position = at
	parent.add_child(sp)
	return sp


var music: AudioStreamPlayer


func _setup_music() -> void:
	music = AudioStreamPlayer.new()
	var st: AudioStreamOggVorbis = load("res://assets/music/lofi_kost.ogg")
	st.loop = true
	music.stream = st
	music.volume_db = -9.0
	add_child(music)


## Volume 0-100 (disimpan di dompet/pengaturan, tidak ikut "Mulai baru").
func vol(kind: String) -> int:
	return int(W.get("vol_" + kind, 80)) if not W.is_empty() else 80


func set_vol(kind: String, v: int) -> void:
	W["vol_" + kind] = clampi(v, 0, 100)
	save_wallet()
	apply_volume()
	if kind == "sfx": sfx("pop", -4.0)


func apply_volume() -> void:
	var m := vol("music") / 100.0
	music.volume_db = -9.0 + linear_to_db(maxf(m, 0.001))
	music.stream_paused = m <= 0.0


var _sfx := {}
var _sfx_players: Array = []


func sfx(nm: String, vol: float = -4.0) -> void:
	if not S.get("sfx", true):
		return
	if _sfx_players.is_empty():
		for i in range(4):
			var p := AudioStreamPlayer.new()
			add_child(p)
			_sfx_players.append(p)
	if not _sfx.has(nm):
		_sfx[nm] = load("res://assets/sfx/%s.wav" % nm)
	for p in _sfx_players:
		if not p.playing:
			p.stream = _sfx[nm]
			var sv := vol("sfx") / 100.0
			if sv <= 0.0: return
			p.volume_db = vol + linear_to_db(sv)
			p.play()
			return


func set_music(on: bool) -> void:
	S.music = on
	if on and not music.playing:
		music.play()
	elif not on:
		music.stop()


func _build_world() -> void:
	bld = Node2D.new()
	add_child(bld)
	_sprite(bld, Rect2(0, 0, D.IW, D.LOBBY_TOP + 40), Vector2.ZERO)
	_sprite(bld, Rect2(0, 0, D.IW, 242), Vector2(0, D.BUILDING_TOP))
	# Lantai dibuat "malas": hanya lantai di sekitar layar yang punya node (lihat _materialize).
	L_bg = Node2D.new(); bld.add_child(L_bg)
	L_hall = Node2D.new(); bld.add_child(L_hall)
	L_stairs = Node2D.new(); bld.add_child(L_stairs)
	stair_nodes = []
	stair_nodes.resize(D.TOP_FLOOR)
	# Balok pemisah lantai 4-5 setebal lantai lain (ilustrasi asli lantai 4 tanpa balok atas).
	_sprite(bld, Rect2(0, 626, D.IW, 25), Vector2(0, 241))
	# Ornamen samping gedung: pipa talang + unit AC luar di lantai yang kamarnya pakai AC.
	var side := _SideDecor.new()
	side.game = self
	bld.add_child(side)
	rooms_root = Node2D.new()
	bld.add_child(rooms_root)
	L_facil = Node2D.new(); bld.add_child(L_facil)
	npc_layer = Node2D.new()
	npc_layer.y_sort_enabled = true
	bld.add_child(npc_layer)
	fx_layer = Node2D.new()
	fx_layer.z_index = 100
	bld.add_child(fx_layer)
	# Lobi: digambar di atas gedung dan tidak ikut scroll.
	lobby_root = Node2D.new()
	add_child(lobby_root)
	_sprite(lobby_root, Rect2(0, D.LOBBY_TOP, D.IW, D.IH - D.LOBBY_TOP), Vector2(0, D.LOBBY_TOP))
	truck = Sprite2D.new()
	truck.texture = load("res://assets/truck_open.png")
	truck.centered = false
	truck.scale = Vector2(0.72, 0.72)
	truck.position = Vector2(-700, D.LOBBY_Y + 45 - 470 * 0.72)
	truck.visible = false
	truck.z_index = 50          # pickup selalu di lapisan paling atas lobi
	lobby_root.add_child(truck)
	# Andi (kurir) jadi supir: kepala & bahu terlihat di jendela kabin.
	driver = Sprite2D.new()
	driver.texture = load("res://assets/chars/kurir/driver.png")   # tampak samping, menghadap depan pickup
	driver.centered = false
	driver.scale = Vector2(1.0, 1.0)
	driver.position = Vector2(268, 218 - 112)
	driver.show_behind_parent = false
	truck.add_child(driver)
	npc_lobby = Node2D.new()
	npc_lobby.y_sort_enabled = true
	lobby_root.add_child(npc_lobby)
	# Si Mpus (kucing) bisa dielus.
	cat_spr = Sprite2D.new()
	for k in CAT_POSES: cat_tex[k] = load("res://assets/cat/%s.png" % k)
	cat_spr.centered = false
	_cat_pose("sleep")
	cat_spr.scale = Vector2.ONE * CAT_S
	cat_spr.position = CAT_FLOOR
	lobby_root.add_child(cat_spr)
	lobby_root.move_child(cat_spr, npc_lobby.get_index())
	# Pagar & tanaman depan meja selalu di depan karakter.
	var fg := Sprite2D.new()
	fg.texture = load("res://assets/fg_day.png")
	fg.centered = false
	fg.position = Vector2(1150, 1990)
	fg.z_index = 40
	lobby_root.add_child(fg)
	# Tablet KelolaPro di meja depan & spanduk KostTerdekat
	app_tablet = Sprite2D.new()
	app_tablet.texture = load("res://assets/brand/tablet.png")
	app_tablet.scale = Vector2(0.62, 0.62)
	app_tablet.position = Vector2(1265, 2072)
	app_tablet.visible = false
	lobby_root.add_child(app_tablet)
	app_banner = Sprite2D.new()
	app_banner.texture = load("res://assets/brand/banner.png")
	app_banner.scale = Vector2(0.62, 0.62)
	app_banner.position = Vector2(205, 1915)
	app_banner.visible = false
	lobby_root.add_child(app_banner)
	# Tablet & spanduk di belakang karakter (Maryam berdiri di depan meja).
	lobby_root.move_child(app_tablet, npc_lobby.get_index())
	lobby_root.move_child(app_banner, npc_lobby.get_index())
	funny = Funny.new()
	add_child(funny)
	funny.setup.call_deferred(self)
	lobby_root.move_child(app_banner, npc_lobby.get_index())
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	# Tekstur cahaya radial untuk semua lampu.
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.35, Color(1, 1, 1, 0.45))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 256
	gt.height = 256
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	_light_tex = gt
	for l in D.STAIR_LAMPS:
		fixed_lights.append(_mk_light(Vector2(l[0], l[1]), l[2], bld))
	for l in D.GROUND_LAMPS:
		var gl := _mk_light(Vector2(l[0], l[1]), l[2], lobby_root)
		gl.range_item_cull_mask = 3
		fixed_lights.append(gl)
	# Cahaya lampu kamar/tangga tidak menembus ke lobi: semua isi lobi pakai light mask 2.
	_lobby_mask(lobby_root)
	get_tree().node_added.connect(func(nd: Node):
		if nd is CanvasItem and is_instance_valid(lobby_root) and lobby_root.is_ancestor_of(nd):
			(nd as CanvasItem).light_mask = 2)
	recep = Npc.new()
	npc_lobby.add_child(recep)
	recep.setup("recep", "static", D.STAFF_LOOK.resep, Vector2(1150, 2133), font)
	recep.k = 1.0
	recep.idle_pose = "counter"
	recep.scene = "desk"
	recep.visible = false
	# Resepsionis dari ilustrasi: cewek ramah melambai, setengah badan di balik meja.
	recep_art = Sprite2D.new()
	_set_keeper("idle")
	recep_art.centered = false
	recep_art.region_enabled = true
	recep_art.scale = Vector2(0.9, 0.9)
	recep_art.z_index = 0
	# Urutan lapisan: Maryam di meja -> tablet KelolaPro -> karakter lain (driver, tamu).
	lobby_root.add_child(recep_art)
	lobby_root.move_child(recep_art, app_tablet.get_index() if app_tablet else npc_lobby.get_index())
	kost_sign = PanelContainer.new()
	var ksb := StyleBoxFlat.new()
	ksb.bg_color = Color("b8835a")
	ksb.border_color = Color("5a3d2b")
	ksb.set_border_width_all(6)
	ksb.set_corner_radius_all(16)
	ksb.content_margin_left = 30
	ksb.content_margin_right = 30
	ksb.content_margin_top = 4
	ksb.content_margin_bottom = 8
	kost_sign.add_theme_stylebox_override("panel", ksb)
	var kl := Label.new()
	kl.add_theme_font_override("font", font)
	kl.add_theme_font_size_override("font_size", 40)
	kl.add_theme_color_override("font_color", Color("fff2dc"))
	kost_sign.add_child(kl)
	kost_sign.position = Vector2(600, 1868)
	kost_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby_root.add_child(kost_sign)
	_refresh_sign.call_deferred()
	desk_tag = PanelContainer.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color.WHITE
	dsb.border_color = D.C_LINE
	dsb.set_border_width_all(5)
	dsb.set_corner_radius_all(26)
	dsb.content_margin_left = 18
	dsb.content_margin_right = 18
	dsb.content_margin_top = 6
	dsb.content_margin_bottom = 8
	desk_tag.add_theme_stylebox_override("panel", dsb)
	var dl := Label.new()
	dl.text = D.STAFF.resep.nama
	dl.add_theme_font_override("font", font)
	dl.add_theme_font_size_override("font_size", 28)
	dl.add_theme_color_override("font_color", D.C_INK)
	desk_tag.add_child(dl)
	desk_tag.z_index = 50
	npc_lobby.add_child(desk_tag)
	_desk_text.call_deferred(D.STAFF.resep.nama, false)


var _keeper_pose := ""
var _keeper_t := 0.0
var _keeper_walk := 0.0        # hitung mundur sampai penjaga keliling ke tangga


## Penjaga kost di balik meja depan (setengah badan). pose: idle / happy / tired.
func _set_keeper(pose: String, secs: float = 0.0) -> void:
	_keeper_t = secs
	if pose == _keeper_pose:
		return
	_keeper_pose = pose
	var rt: Texture2D = load("res://assets/chars/penjaga/%s_L.png" % pose)
	recep_art.texture = rt
	var top := 0.0 if pose == "happy" else 0.0
	recep_art.region_rect = Rect2(0, top, rt.get_width(), 175)
	recep_art.flip_h = true      # menghadap ke kiri (ke arah pintu & tamu)
	var face_x := rt.get_width() * (0.55 if pose == "happy" else 0.5)
	recep_art.position = Vector2(1185 - face_x * 0.9, 1952 if pose != "happy" else 1945)


func _mk_light(p: Vector2, radius: float, parent: Node) -> PointLight2D:
	var pl := PointLight2D.new()
	pl.texture = _light_tex
	pl.texture_scale = radius * 2.6 / 256.0
	pl.color = Color(1.0, 0.8, 0.5)
	pl.energy = 0.0
	pl.position = p
	pl.enabled = false
	parent.add_child(pl)
	return pl


# ---------- Lift kaca di luar gedung (sisi kiri) ----------
var lift_node: Node2D


func _refresh_lift() -> void:
	var on: bool = S.fac.has("lift")
	if not on:
		if lift_node: lift_node.visible = false
		return
	if lift_node == null:
		lift_node = _Lift.new()
		lift_node.font = font
		bld.add_child(lift_node)
		lobby_root.add_child(lift_node.base)
	lift_node.top_y = D.rect_of("%dS" % D.TOP_FLOOR).position.y - 20
	lift_node.visible = true
	lift_node.base.visible = true


func has_lift() -> bool:
	return S.fac.has("lift") and lift_node != null


func lift_at(p: Vector2) -> bool:
	if not has_lift(): return false
	if p.y >= D.LOBBY_TOP: return p.x < 160.0
	var q := to_bld(p)
	return q.x < 140.0 and q.y > lift_node.top_y - 40.0 and q.y < 1820.0


var lift_pending: Array = []


## Kamar paling butuh perabot t: belum punya dulu, lalu level terendah, lantai terendah.
func auto_room_for(t: String) -> String:
	var best := ""
	var bk := 999999
	for id in D.ROOMS:
		var r: Dictionary = S.rooms[id]
		if not r.built or not D.furn_has(id, t): continue
		var lv := int(r.furn.get(t, 0))
		if lv >= 3 or job_for(id, "deliver", t) != {} or lift_pending.has(id + "|" + t): continue
		var k := lv * 1000 + D.fl(id) * 10 + (0 if D.col(id) == "L" else 1)
		if k < bk:
			bk = k
			best = id
	return best


func lift_send(d: Dictionary) -> void:
	if d.kind == "bag":
		var b := _bag(str(d.item))
		if b.is_empty(): return
		var rid := str(b.room)
		b.lift = true
		_refresh_bags()
		ui.toast("Lift barang mengantar pesanan %s ke Kamar %s" % [b.name, D.room_name(rid)])
		lift_node.add_trip(D.fl(rid), load("res://assets/bag.png"), func():
			deliver_bag(str(b.id), rid))
		return
	var i := int(d.item)
	if i >= S.cargo.size(): return
	_cargo_sync()
	var t: String = S.cargo[i]
	var rid2: String = str(S.cargo_to[i])
	if rid2 != "":
		var r0: Dictionary = S.rooms[rid2]
		if not r0.built or int(r0.furn.get(t, 0)) >= 3 or lift_pending.has(rid2 + "|" + t): rid2 = ""
	if rid2 == "": rid2 = auto_room_for(t)
	if rid2 == "":
		ui.toast("Semua kamar sudah punya %s level maksimal." % D.FURN[t].n, "bad"); return
	S.cargo.pop_at(i)
	S.cargo_to.pop_at(i)
	truck_touch()
	_refresh_cargo()
	var key := rid2 + "|" + t
	lift_pending.append(key)
	ui.toast("Lift barang membawa %s ke Kamar %s" % [D.FURN[t].n, D.room_name(rid2)])
	lift_node.add_trip(D.fl(rid2), load("res://assets/box.png"), func():
		lift_pending.erase(key)
		var r: Dictionary = S.rooms[rid2]
		var lv := int(r.furn.get(t, 0)) + 1
		if lv > 3: return
		r.furn[t] = lv
		update_tier(r)
		sfx("place" if lv == 1 else "upgrade")
		_refresh_world()
		if room_fx.has(rid2): room_fx[rid2].pop_item(t)
		if r.tenant != null: r.tenant.happy = clampf(float(r.tenant.happy) + 4.0 * lv, 0, 100)
		float_at(rid2, ("+" + D.FURN[t].n) if lv == 1 else "%s jadi %s!" % [D.FURN[t].n, D.FURN_LV_NAME[lv]], Color("2f7a2a"))
		add_xp(8 if lv == 1 else 12)
		dirty = true)
	save_game()


class _Lift extends Node2D:
	var top_y := -1500.0
	var trips: Array = []      # {"f", "icon", "cb"}
	var _phase := ""           # "" | "pickup" | "carry"
	var icon: Texture2D

	func add_trip(f: int, ic: Texture2D, cb: Callable) -> void:
		trips.append({"f": f, "icon": ic, "cb": cb})
		if _phase == "" and _move_t >= _move_dur:
			_wait = 0.01

	func _go(y: float) -> void:
		_from = cy
		_to = y
		_move_dur = maxf(0.8, absf(_to - _from) / (SPEED * 3.0))
		_move_t = 0.0
		_wait = 0.0
	var font: Font
	var t := 0.0
	var base := Node2D.new()
	var cy := -1.0          # posisi kabin (atas kabin)
	var _from := 0.0
	var _to := 0.0
	var _move_t := 0.0
	var _move_dur := 1.0
	var _wait := 4.0
	const X0 := 20.0
	const X1 := 118.0
	const CAB_H := 132.0
	const SPEED := 55.0      # px/detik: pelan dan santai
	func _stop_y(f: int) -> float:
		return float(D.FEET[f]) - CAB_H - 4.0
	func _process(dt: float) -> void:
		t += dt
		if cy < 0.0:
			cy = _stop_y(1)
		if _wait > 0.0 and not trips.is_empty() and _phase == "":
			_wait = 0.0
			_phase = "pickup"
			_go(_stop_y(1))
		elif _wait > 0.0:
			_wait -= dt
			if _wait <= 0.0:
				# pilih lantai tujuan lain, tidak terlalu jauh
				var cur := 1
				for f in range(1, D.TOP_FLOOR + 1):
					if absf(_stop_y(f) - cy) < 5.0: cur = f
				var nf := clampi(cur + [-2, -1, 1, 2].pick_random(), 1, D.TOP_FLOOR)
				if nf == cur: nf = clampi(cur + 1, 1, D.TOP_FLOOR) if cur < D.TOP_FLOOR else cur - 1
				_from = cy
				_to = _stop_y(nf)
				_move_dur = maxf(2.0, absf(_to - _from) / SPEED)
				_move_t = 0.0
		else:
			_move_t += dt
			var k := clampf(_move_t / _move_dur, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)          # mulus di awal dan akhir
			cy = lerpf(_from, _to, k)
			if _move_t >= _move_dur:
				if _phase == "pickup":
					icon = trips[0].icon
					_phase = "carry"
					_go(_stop_y(int(trips[0].f)))
				elif _phase == "carry":
					var tr: Dictionary = trips.pop_front()
					icon = null
					_phase = ""
					tr.cb.call()
					_wait = 1.2 if not trips.is_empty() else randf_range(7.0, 14.0)
				else:
					_wait = randf_range(7.0, 14.0)  # berhenti agak lama di tiap lantai
		queue_redraw()
	func _draw() -> void:
		var bottom := 1800.0
		var frame := Color(0.55, 0.45, 0.36, 0.55)
		# Kaca tipis, hampir menyatu dengan langit
		draw_rect(Rect2(X0, top_y, X1 - X0, bottom - top_y), Color(0.86, 0.92, 0.95, 0.28))
		draw_line(Vector2(X0, top_y), Vector2(X0, bottom), frame, 3.0)
		draw_line(Vector2(X1, top_y), Vector2(X1, bottom), frame, 3.0)
		draw_line(Vector2(X0, top_y), Vector2(X1, top_y), frame, 3.0)
		var y := top_y + 30.0
		while y < bottom:
			draw_line(Vector2(X0, y), Vector2(X1, y), Color(0.45, 0.36, 0.28, 0.18), 2.0)
			y += 392.0
		# Kabin warna kalem
		var mid := (X0 + X1) / 2.0
		draw_line(Vector2(mid, top_y), Vector2(mid, cy), Color(0.4, 0.32, 0.25, 0.35), 2.0)
		var cab := Rect2(X0 + 8, cy, X1 - X0 - 16, CAB_H)
		draw_rect(cab, Color(0.86, 0.81, 0.73, 0.95))
		draw_rect(cab, Color(0.45, 0.36, 0.28, 0.7), false, 3.0)
		var dw := (cab.size.x - 18.0) / 2.0
		draw_rect(Rect2(cab.position.x + 6, cy + 14, dw, CAB_H - 24), Color(0.93, 0.9, 0.84))
		draw_rect(Rect2(cab.position.x + 12 + dw, cy + 14, dw, CAB_H - 24), Color(0.93, 0.9, 0.84))
		if icon:
			var isz := icon.get_size() * minf(70.0 / icon.get_width(), 80.0 / icon.get_height())
			draw_texture_rect(icon, Rect2(mid - isz.x / 2.0, cy + CAB_H - 8 - isz.y, isz.x, isz.y), false)
		if font:
			draw_string(font, Vector2(X0, top_y - 10), "BARANG", HORIZONTAL_ALIGNMENT_CENTER, X1 - X0, 26, Color(0.45, 0.36, 0.28, 0.6))


func _refresh_world() -> void:
	_refresh_hubs()
	_refresh_lift()
	for id in room_fx:
		room_fx[id].dekor = dekor
		room_fx[id].building = job_for(id, "build") != {}
	_refresh_facil()
	if app_tablet:
		app_tablet.visible = has_app("kelolapro")
		app_banner.visible = has_app("kostterdekat")
	for id in room_fx:
		var ev_id := event_at(id)
		S.rooms[id]["_ev"] = "" if ev_id.is_empty() else str(ev_id.type)
		room_fx[id].refresh(S.rooms[id], int(S.lvl), build_cost(), font)
		room_fx[id].set_floor_lock(floor_lock_sign(D.fl(id)))
	dirty = false


func _lerp_keys(keys: Array, h: float):
	for i in range(keys.size() - 1):
		var a: float = keys[i][0]
		var b: float = keys[i + 1][0]
		if h >= a and h <= b:
			var t := (h - a) / (b - a)
			var va = keys[i][1]
			var vb = keys[i + 1][1]
			if va is Color:
				return (va as Color).lerp(vb, t)
			return lerpf(va, vb, t)
	return keys[0][1]


func glow_level() -> float:
	return _lerp_keys(GLOW, S.min / 60.0)


func _update_light() -> void:
	var h: float = S.min / 60.0
	canvas_mod.color = _lerp_keys(TINT, h)
	var gl := glow_level()
	var vr := _vis_last if _vis_last.y >= 0 else vis_floors()
	for id in room_lights:
		var r: Dictionary = S.rooms[id]
		var fid := D.fl(id)
		var on: bool = fid >= vr.x and fid <= vr.y and gl > 0.02 and r.built and r.tenant != null and r.furn.has("lampu") and str(r.broken) != "Lampu mati" and presence(r.tenant) != "away"
		for pl in room_lights[id]:
			pl.enabled = on
			pl.energy = gl * 1.15
	for f in facil_lights:
		facil_lights[f].enabled = gl > 0.02 and S.facil.has(str(f)) and int(f) >= vr.x and int(f) <= vr.y
		facil_lights[f].energy = gl * 1.0
	for pl in fixed_lights:
		pl.enabled = gl > 0.02
		pl.energy = gl * 0.9


# ================= State =================
func _new_game() -> void:
	S = {}
	var rooms := {}
	for id in D.ROOMS:
		rooms[id] = {"built": false, "lv": 1, "clean": 100.0, "broken": "", "tenant": null, "furn": {}}
	for id in ["1L", "1R", "2L", "2R"]:
		rooms[id].built = true
	rooms["1R"].furn = {"kasur": 1, "lampu": 1, "tanaman": 1}
	rooms["2L"].furn = {"kasur": 1, "lampu": 1, "karpet": 1}
	rooms["2R"].furn = {"kasur": 1, "lampu": 1}
	rooms["1L"].furn = {"kasur": 1}
	S = {"money": 1500000.0, "lvl": 1, "xp": 0.0, "day": 1, "min": 420, "rep": 3.5, "price": 1, "speed": 1,
		"rooms": rooms, "staff": {}, "fac": {}, "queue": [], "next_cand": 150.0,
		"today": {"rent": 0.0, "salary": 0.0, "util": 0.0, "other": 0.0}, "last": null,
		"total": {"rent": 0.0, "served": 0}, "seen": false, "jobs": [], "orders": [], "cargo": [], "events": [], "prevent": {}, "facil": {}, "apps": {}, "kost_name": "Kost Harmoni", "tut": 0}
	var t1 := gen_person("p")
	t1.job = "Mahasiswa"; t1.pref = 1; t1.happy = 78
	rooms["1R"].tenant = t1
	var t2 := gen_person("l")
	t2.job = "Freelancer"; t2.pref = 1; t2.happy = 72
	rooms["2R"].tenant = t2
	var t3 := gen_person("p")
	t3.job = "Mahasiswa"; t3.pref = 1; t3.happy = 75
	rooms["2L"].tenant = t3
	S.queue.append(gen_person(["l", "p"].pick_random()))
	S.staff["resep"] = true
	for id in D.ROOMS:
		update_tier(S.rooms[id])


func gen_person(g: String) -> Dictionary:
	var pool_c := []
	for c in D.CHARS:
		if D.CHARS[c] == g: pool_c.append(c)
	var ch: String = pool_c.pick_random()
	var lv := int(S.get("lvl", 1))
	var pool := []
	var tua: bool = ch in D.CHAR_TUA
	for j in D.JOBS:
		# Kakek/nenek: pensiunan atau pedagang; yang muda: mahasiswa, karyawan, dst.
		if int(D.JOBS[j].min) <= lv and bool(D.JOBS[j].get("tua", false)) == tua:
			pool.append(j)
	var job: String = pool.pick_random()
	var pref := int(D.JOBS[job].pref)
	if randf() < 0.25:
		pref += -1 if randf() < 0.5 else 1
	var used := {}
	for q in S.get("queue", []): used[q.name] = true
	for id in S.get("rooms", {}):
		if S.rooms[id].tenant != null: used[S.rooms[id].tenant.name] = true
	var names := []
	for nm in (D.NAMES_P if g == "p" else D.NAMES_L):
		if not used.has(nm): names.append(nm)
	if names.is_empty(): names = (D.NAMES_P if g == "p" else D.NAMES_L)
	# Variasi warna baju: hindari kombinasi karakter+warna yang sudah ada.
	var taken := {}
	for q in S.get("queue", []): taken["%s%d" % [q.get("char", ""), int(q.get("tint", 0))]] = true
	for rid in S.get("rooms", {}):
		var tn = S.rooms[rid].tenant
		if tn != null: taken["%s%d" % [tn.get("char", ""), int(tn.get("tint", 0))]] = true
	var tint := randi() % Npc.TINTS.size()
	for _i in range(Npc.TINTS.size()):
		if not taken.has("%s%d" % [ch, tint]): break
		tint = (tint + 1) % Npc.TINTS.size()
	return {"id": "p%d" % randi(), "name": names.pick_random(), "g": g, "char": ch, "tint": tint,
		"look": Spr.random_look(g), "job": job, "pref": clampi(pref, 1, 3), "days": randi_range(8, 30),
		"stay": 0, "happy": randi_range(62, 80), "wait": 0, "traits": _roll_traits(), "checked": {}}


## Sifat tersembunyi calon penyewa (paling banyak 2 yang buruk).
func _roll_traits() -> Array:
	var out := []
	var bad := 0
	var keys := D.TRAITS.keys()
	keys.shuffle()
	for k in keys:
		var tr: Dictionary = D.TRAITS[k]
		if tr.bad and bad >= 2: continue
		if randf() < float(tr.p):
			# sifat yang saling bertentangan
			if (k == "tepat" and out.has("bayar_seret")) or (k == "bayar_seret" and out.has("tepat")): continue
			if (k == "rapi" and out.has("jorok")) or (k == "jorok" and out.has("rapi")): continue
			if (k == "ramah" and out.has("berisik")) or (k == "berisik" and out.has("ramah")): continue
			out.append(k)
			if tr.bad: bad += 1
	return out


func _trait_sum(t: Dictionary, key: String) -> float:
	var s := 0.0
	for k in t.get("traits", []):
		if D.TRAITS[k].has(key): s += float(D.TRAITS[k][key])
	return s


func has_trait(t: Dictionary, k: String) -> bool:
	return k in t.get("traits", [])


## Hasil pemeriksaan: sifat yang ditemukan lewat cek ini.
func found_traits(p: Dictionary, check: String) -> Array:
	var out := []
	for k in p.get("traits", []):
		if D.TRAITS[k].via == check: out.append(k)
	return out


func _trait_mult(t: Dictionary, key: String, default: float = 1.0) -> float:
	var m := default
	for k in t.get("traits", []):
		if D.TRAITS[k].has(key): m *= float(D.TRAITS[k][key])
	return m


func _screen(pid: String, check: String) -> void:
	var p: Dictionary = {}
	for q in S.queue:
		if q.id == pid: p = q
	if p.is_empty() or p.get("checked", {}).has(check): return
	var ck: Dictionary = D.CHECKS[check]
	if int(S.lvl) < int(ck.lv): return
	if float(S.money) < float(ck.cost) and not (check == "riwayat" and has_app("kelolapro")):
		ui.toast("Uang belum cukup", "bad"); return
	var cost := 0.0 if (check == "riwayat" and has_app("kelolapro")) else float(ck.cost)
	if cost > 0: spend(cost, "other")
	if not p.has("checked"): p.checked = {}
	p.checked[check] = true
	p.wait = int(p.wait) + 1
	var f := found_traits(p, check)
	var bad := f.filter(func(k): return D.TRAITS[k].bad)
	if bad.size() > 0:
		ui.toast("%s: %s" % [ck.n,", ".join(bad.map(func(k): return D.TRAITS[k].n))], "bad")
	else:
		ui.toast("%s %s: aman" % [ck.n, p.name])


# ================= Dompet: Diamond & Tiket Ngebut =================
var W := {}


func _load_wallet() -> void:
	W = {}
	if FileAccess.file_exists(WALLET_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(WALLET_PATH))
		if typeof(d) == TYPE_DICTIONARY: W = d
	for k in ["diamonds", "tickets", "turbo_min"]:
		W[k] = int(W.get(k, 0))
	if not W.get("free_given", false):
		W.free_given = true
		W.tickets = int(W.tickets) + FREE_TICKETS
		W.diamonds = int(W.diamonds) + 30    # hadiah pemain baru
	save_wallet()


func save_wallet() -> void:
	var f := FileAccess.open(WALLET_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(W))


## Jeda / 1x gratis. 2x butuh Tiket Ngebut (berlaku 7 hari di game, hanya terpakai saat 2x).
func set_speed(v: int) -> void:
	v = clampi(v, 0, 2)
	if v == 2 and int(W.turbo_min) <= 0:
		if int(W.tickets) > 0:
			W.tickets = int(W.tickets) - 1
			W.turbo_min = TURBO_MIN
			save_wallet()
			ui.toast("Tiket Ngebut dipakai! Kecepatan 2x selama 7 hari di game. Sisa tiket: %d" % int(W.tickets), "gold")
			sfx("upgrade", -6.0)
		else:
			ui.toast("Tiket Ngebut habis. Beli di Toko.", "bad")
			ui.open_sheet("toko")
			return
	S.speed = v
	ui.toast("Kecepatan %dx" % v if v > 0 else "Waktu dijeda")
	if ui.kind in ["manage", "toko"]: ui.refresh_sheet()


func turbo_text() -> String:
	var m := int(W.get("turbo_min", 0))
	if m <= 0: return ""
	var d := m / 1440
	var h := (m % 1440) / 60
	return ("%d hari %d jam" % [d, h]) if d > 0 else ("%d jam" % maxi(1, h))


func _turbo_tick() -> void:
	if int(S.speed) != 2: return
	W.turbo_min = int(W.turbo_min) - 2
	if int(W.turbo_min) == 1440:
		ui.toast("Waktu 2x tinggal 1 hari di game.", "gold")
	if int(W.turbo_min) % 120 == 0: save_wallet()
	if int(W.turbo_min) <= 0:
		W.turbo_min = 0
		save_wallet()
		S.speed = 1
		keeper_say("Yah, mode ngebut udah habis~", 3.5)
		ui.toast("Waktu 2x habis, kembali ke 1x. Pakai Tiket Ngebut lagi untuk 2x.", "bad")


## Toko (bayar pakai Diamond). Diamond dibeli di Play Store pada versi Android.
const SHOP := {
	"tiket1": {"n": "1 Tiket Ngebut", "d": "Kecepatan 2x selama 7 hari di game", "cost": 25},
	"tiket5": {"n": "5 Tiket Ngebut", "d": "Hemat 20%", "cost": 100},
	"uang1": {"n": "Kantong Uang", "d": "", "cost": 30, "money": 500000},
	"uang2": {"n": "Peti Uang", "d": "", "cost": 100, "money": 2000000},
}
const DIAMOND_PACKS := [["60", "Rp 15.000"], ["330 (+10%)", "Rp 75.000"], ["700 (+17%)", "Rp 150.000"]]


func shop_money(k: String) -> float:
	return float(SHOP[k].get("money", 0)) * maxf(1.0, int(S.lvl) * 0.75)


func shop_buy(k: String) -> void:
	var it: Dictionary = SHOP[k]
	if int(W.diamonds) < int(it.cost):
		ui.toast("Diamond belum cukup.", "bad")
		return
	W.diamonds = int(W.diamonds) - int(it.cost)
	match k:
		"tiket1": W.tickets = int(W.tickets) + 1
		"tiket5": W.tickets = int(W.tickets) + 5
		_:
			var m := shop_money(k)
			S.money = float(S.money) + m
			ui.toast("+%s masuk ke kas kost!" % D.rp(m), "gold")
	save_wallet()
	sfx("buy")
	ui.refresh_sheet()


const SAVE_VER := 2
const BACKUPS := ["user://kost_backup_1.json", "user://kost_backup_2.json", "user://kost_backup_3.json"]
var _backup_acc := 0.0


func save_game() -> void:
	if S.is_empty(): return
	S.ver = SAVE_VER
	S.saved_at = Time.get_unix_time_from_system()
	var txt := JSON.stringify(S)
	# Tulis ke file sementara dulu, cek bisa dibaca, baru timpa save utama (anti save rusak).
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null: return
	f.store_string(txt)
	f.close()
	if typeof(JSON.parse_string(FileAccess.get_file_as_string(tmp))) != TYPE_DICTIONARY: return
	var g := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if g:
		g.store_string(txt)
		g.close()
	# Cadangan berputar tiap ±5 menit main (3 cadangan terakhir).
	if Time.get_ticks_msec() / 1000.0 - _backup_acc > 300.0 or _backup_acc == 0.0:
		_backup_acc = Time.get_ticks_msec() / 1000.0
		for i in range(BACKUPS.size() - 1, 0, -1):
			if FileAccess.file_exists(BACKUPS[i - 1]):
				var t0 := FileAccess.get_file_as_string(BACKUPS[i - 1])
				var b := FileAccess.open(BACKUPS[i], FileAccess.WRITE)
				if b: b.store_string(t0)
		var b0 := FileAccess.open(BACKUPS[0], FileAccess.WRITE)
		if b0: b0.store_string(txt)


## Kode cadangan: save + dompet, dikompres & base64. Bisa ditempel di HP lain.
func export_code() -> String:
	save_game()
	var pack := JSON.stringify({"cozy": 1, "S": S, "W": W})
	var raw := pack.to_utf8_buffer()
	var z := raw.compress(FileAccess.COMPRESSION_GZIP)
	return "COZY1:" + str(raw.size()) + ":" + Marshalls.raw_to_base64(z)


## Muat dari kode. Mengembalikan "" kalau sukses, atau alasan gagal.
func import_code(code: String) -> String:
	code = code.strip_edges().replace("\n", "").replace(" ", "")
	if not code.begins_with("COZY1:"): return "Kode tidak dikenali. Pastikan menyalin seluruh kode yang diawali COZY1:"
	var parts := code.split(":")
	if parts.size() != 3: return "Kode tidak lengkap."
	var z := Marshalls.base64_to_raw(parts[2])
	if z.is_empty(): return "Kode rusak atau terpotong."
	var raw := z.decompress(int(parts[1]), FileAccess.COMPRESSION_GZIP)
	var d = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY or not d.has("S") or typeof(d.S) != TYPE_DICTIONARY or not d.S.has("rooms"):
		return "Kode rusak atau terpotong."
	# Simpan save lama sebagai cadangan dulu, lalu pasang yang baru dan muat ulang game.
	if FileAccess.file_exists(SAVE_PATH):
		var b := FileAccess.open("user://kost_before_import.json", FileAccess.WRITE)
		if b: b.store_string(FileAccess.get_file_as_string(SAVE_PATH))
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null: return "Gagal menulis data."
	d.S.saved_at = Time.get_unix_time_from_system()   # tidak dihitung sebagai "pergi"
	f.store_string(JSON.stringify(d.S))
	f.close()
	if typeof(d.get("W")) == TYPE_DICTIONARY:
		W = d.W
		save_wallet()
	_no_save = true
	get_tree().reload_current_scene()
	return ""


var _no_save := false


## Unduh kode cadangan sebagai file teks (versi web).
func download_backup() -> void:
	var code := export_code()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(code.to_utf8_buffer(), "cozykost-cadangan-hari%d.txt" % int(S.day), "text/plain")
	else:
		var f := FileAccess.open("user://cozykost-cadangan.txt", FileAccess.WRITE)
		if f: f.store_string(code)


func _load_game_raw() -> Dictionary:
	if OS.get_cmdline_user_args().has("--fresh") or not FileAccess.file_exists(SAVE_PATH): return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return d if typeof(d) == TYPE_DICTIONARY else {}


var restored_from := ""


func _load_game() -> Dictionary:
	var d = null
	for path in [SAVE_PATH] + BACKUPS:
		if not FileAccess.file_exists(path): continue
		var cand = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(cand) == TYPE_DICTIONARY and cand.has("rooms") and cand.has("lvl"):
			d = cand
			if path != SAVE_PATH: restored_from = path
			break
	if d == null:
		if FileAccess.file_exists(SAVE_PATH): restored_from = "gagal"
		return {}
	d = _migrate(d)
	# JSON mengubah semua angka jadi float; kembalikan yang perlu bulat.
	for k in ["lvl", "day", "min", "price", "speed"]:
		d[k] = int(d[k])
	for id in d.rooms.keys():
		if not D.ROOMS.has(id):
			if d.rooms[id].get("tenant") != null:
				var t: Dictionary = d.rooms[id].tenant
				t.wait = 0
				d.queue.push_front(t)
			d.rooms.erase(id)
	if d.has("jobs"):
		d.jobs = d.jobs.filter(func(j): return D.ROOMS.has(j.room) or str(j.room).begins_with("S"))
	for id in D.ROOMS:
		if not d.rooms.has(id):
			d.rooms[id] = {"built": false, "lv": 1, "clean": 100.0, "broken": "", "tenant": null, "furn": {}}
	for id in d.rooms:
		var r: Dictionary = d.rooms[id]
		r.lv = int(r.lv)
		if not r.has("furn"):
			r.furn = {"kasur": 1, "lampu": 1} if r.built else {}
		for t in r.furn:
			r.furn[t] = int(r.furn[t])
	if not d.has("jobs"):
		d.jobs = []
	if not d.has("orders"): d.orders = []
	if not d.has("events"): d.events = []
	if not d.has("prevent"): d.prevent = {}
	if not d.has("facil"): d.facil = {}
	if not d.has("apps"): d.apps = {}
	for t0 in d.get("queue", []):
		if t0.get("char", "") in D.CHAR_TUA and not D.JOBS.get(t0.get("job", ""), {}).get("tua", false): t0.job = "Pensiunan"
	for rid0 in d.rooms:
		var t1 = d.rooms[rid0].get("tenant")
		if t1 != null and t1.get("char", "") in D.CHAR_TUA and not D.JOBS.get(t1.get("job", ""), {}).get("tua", false): t1.job = "Pensiunan"
	for fk in d.facil.keys():
		if d.facil[fk] == "rooftop": d.facil[fk] = "minimart"
		if d.facil[fk] == "lift":
			d.facil.erase(fk)
			d.fac["lift"] = true
	if not d.has("cargo"): d.cargo = []
	for jb in d.get("jobs", []):
		if jb.type in ["build", "fbuild"]: jb.started = true
		elif jb.type == "deliver":
			jb.taken = false
			jb.started = false
	d.staff["resep"] = true      # Maryam pemilik kost, selalu ada
	if d.has("strike"): d.strike.erase("resep")
	for o in d.orders: o.t = float(o.t)
	for j in d.jobs:
		j.t = float(j.t)
	return d


## Migrasi save lama ke format terbaru. Tambahkan langkah baru di sini setiap format berubah.
func _migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("ver", 1))
	if v < 2:
		# v1 -> v2: kunci baru yang diperkenalkan setelah rilis demo.
		for k in ["out", "flv", "hall_paint", "side", "slv", "renov", "fire"]:
			if not d.has(k): d[k] = {}
		if not d.has("bags"): d.bags = []
		if not d.has("cargo_to"): d.cargo_to = []
		if not d.has("fac"): d.fac = {}
		if not d.has("staff"): d.staff = {}
		v = 2
	# Fasilitas yang sudah dihapus dari game
	for k in ["jemur", "parkir"]:
		if d.has("fac") and d.fac.has(k): d.fac.erase(k)
	d.ver = v
	return d


func each_tenant() -> Array:
	var out := []
	for id in D.ROOMS:
		if S.rooms[id].tenant != null:
			out.append([id, S.rooms[id]])
	return out


func fac_count() -> int:
	return S.fac.size()


func comfort(r: Dictionary) -> float:
	var c := 0.0
	for t in r.get("furn", {}):
		c += float(D.FURN[t].c) * D.FURN_MULT[int(r.furn[t])]
	return c + paint_comfort(r.get("paint", {}))


## Bonus kenyamanan dari cat & lantai (menaikkan sewa sedikit).
func paint_comfort(p: Dictionary) -> float:
	var c := 0.0
	if p.get("wall", "asli") != "asli": c += 0.5
	if p.get("motif", "polos") != "polos": c += 0.3
	var fk: int = int(D.FLOORS[p.get("floor", "asli")].k)
	c += [0.0, 0.6, 1.0, 0.8][fk]
	return c


func paint_cost(rid: String, sel: Dictionary) -> float:
	var cur: Dictionary = S.rooms[rid].get("paint", {})
	var c := 0.0
	if sel.get("wall", "asli") != cur.get("wall", "asli") or sel.get("motif", "polos") != cur.get("motif", "polos"):
		c += D.PAINT_PRICE + float(D.MOTIFS[sel.get("motif", "polos")].p)
	if sel.get("floor", "asli") != cur.get("floor", "asli"):
		c += maxf(100000.0, float(D.FLOORS[sel.get("floor", "asli")].p))
	return c


func preview_paint(rid: String, sel: Dictionary) -> void:
	if not room_fx.has(rid): return
	room_fx[rid].paint_preview = sel.duplicate()
	room_fx[rid].apply_paint({})


func clear_paint_preview() -> void:
	for fx in room_fx.values():
		if not fx.paint_preview.is_empty():
			fx.paint_preview = {}
			fx.apply_paint(S.rooms[fx.rid].get("paint", {}))


func buy_paint(rid: String, sel: Dictionary) -> void:
	var c := paint_cost(rid, sel)
	if c <= 0.0:
		ui.toast("Belum ada yang diubah.", "bad"); return
	if float(S.money) < c:
		ui.toast("Uang tidak cukup (butuh %s)" % D.rp(c), "bad"); return
	spend(c, "other")
	var r: Dictionary = S.rooms[rid]
	r.paint = sel.duplicate()
	update_tier(r)
	if r.tenant != null:
		r.tenant.happy = minf(100.0, float(r.tenant.happy) + 10.0)
		if npcs.has(r.tenant.id): npcs[r.tenant.id].say("Wah, kamarku jadi cantik!", 2.5)
	if room_fx.has(rid): room_fx[rid].paint_preview = {}
	sfx("upgrade")
	add_xp(8)
	ui.toast("Kamar %s didekorasi ulang!" % D.room_name(rid), "gold")
	dirty = true


func update_tier(r: Dictionary) -> void:
	var c := comfort(r)
	r.lv = 1 if c < 5.0 else (2 if c < 10.0 else 3)


func _id_of(r: Dictionary) -> String:
	for id in S.rooms:
		if S.rooms[id] == r: return id
	return "1L"


func rent_of(r: Dictionary) -> float:
	var fl := D.fl(_id_of(r))
	var v: float = (30000.0 + comfort(r) * 9000.0) * D.PRICE[int(S.price)].m * (1.0 + 0.04 * fac_count() + (0.05 if has_facil("cafe") else 0.0) + float(D.STAIRS[stair_lv()].bonus)) * (1.0 + 0.03 * (fl - 1))
	return round(v / 1000.0) * 1000.0


func can_rent(id: String) -> bool:
	var r: Dictionary = S.rooms[id]
	return r.built and r.tenant == null and r.get("furn", {}).has("kasur") and str(r.get("broken", "")) != Funny.GOSONG and not (funny and funny.game and funny.haunted(id))


func build_cost() -> float:
	var n := 0
	for id in D.ROOMS:
		if S.rooms[id].built:
			n += 1
	# Sedikit makin mahal untuk gedung besar supaya uang late-game tetap berarti.
	var big := maxi(0, n - 12)
	return roundf((600000.0 + n * 250000.0 + big * big * 12000.0) / 50000.0) * 50000.0


func xp_need(l: int) -> float:
	return 100.0 * l + 60.0 * l * l


func empty_rooms() -> Array:
	var out := []
	for id in D.ROOMS:
		if can_rent(id):
			out.append(id)
	return out


func spend(n: float, cat: String) -> void:
	S.money = float(S.money) - n
	S.today[cat] = float(S.today.get(cat, 0.0)) + n


func presence(t: Dictionary) -> String:
	var h: float = S.min / 60.0
	var a: Array = D.JOBS[t.job].away
	if a.size() == 2:
		var inside: bool = (h >= a[0] and h < a[1]) if a[0] < a[1] else (h >= a[0] or h < a[1])
		if inside:
			return "away"
	if h >= 22.0 or h < 6.0:
		return "sleep"
	return "work" if t.job == "Freelancer" else "sit"


func add_xp(n: float) -> void:
	S.xp = float(S.xp) + n
	while float(S.xp) >= xp_need(int(S.lvl)):
		S.xp = float(S.xp) - xp_need(int(S.lvl))
		S.lvl = int(S.lvl) + 1
		var bonus := 300000.0 * int(S.lvl)
		S.money = float(S.money) + bonus
		ui.toast("Naik ke Level %d! Bonus %s" % [int(S.lvl), D.rp(bonus)], "gold")
		maybe_review("level")
		var lf := int(S.lvl)
		if lf <= 8: ui.toast("Lantai %d terbuka untuk dibangun" % lf, "gold")
		elif lf <= D.TOP_FLOOR and not floor_open(lf): ui.toast("Lantai %d bisa dibangun sekarang!" % lf, "gold")
		dirty = true


func float_at(id: String, text: String, col: Color) -> void:
	var r := D.rect_of(id)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 42)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 14)
	fx_layer.add_child(l)
	l.reset_size()
	l.position = Vector2(r.position.x + r.size.x / 2.0 - l.size.x / 2.0, r.position.y + r.size.y * 0.3)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 110, 1.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


# ================= Waktu & ekonomi =================
var _beat_acc := 0.0
var _cull_acc := 0.0
var _npccheck := OS.get_cmdline_user_args().has("--npccheck")


## Rentang lantai yang terlihat di layar (plus 1 lantai cadangan atas & bawah).
func vis_floors() -> Vector2i:
	var top := -scroll - 420.0
	var bot := D.LOBBY_TOP - scroll + 420.0
	var lo := 999999
	var hi := 0
	for f in range(1, D.TOP_FLOOR + 1):
		var r: Vector2 = D.ROWS[f]
		if r.y > top and r.x < bot:
			lo = mini(lo, f); hi = maxi(hi, f)
	if hi == 0: return Vector2i(0, -1)
	return Vector2i(lo, hi)


var _vis_last := Vector2i(-1, -1)
var L_bg: Node2D
var L_hall: Node2D
var L_stairs: Node2D
var L_facil: Node2D
var rooms_root: Node2D
var _floor_nodes := {}    # lantai -> [node, ...] yang dibuat untuk lantai itu
const MAT_PAD := 2        # lantai cadangan di atas/bawah layar yang tetap dibuat
const MAT_DROP := 4       # lantai di luar jarak ini dibuang dari memori


## Buat semua node satu lantai (latar, ruang tangga, tangga, kamar, fasilitas, lampu).
func _materialize(f: int) -> void:
	if _floor_nodes.has(f) or f < 1 or f > D.TOP_FLOOR: return
	var nodes := []
	if f >= 5:
		var fy := 242 - (f - 4) * D.EXTRA_PITCH
		var fs := _sprite(L_bg, Rect2(0, 627, D.IW, D.EXTRA_PITCH), Vector2(0, fy))
		fs.modulate = D.floor_tint(f)
		nodes.append(fs)
		if f % 2 == 1:
			nodes.append(_sprite(L_bg, Rect2(0, 235, 86, D.EXTRA_PITCH), Vector2(0, fy)))
		else:
			var sky := _sprite(L_bg, Rect2(0, 240, 40, 40), Vector2(0, fy))
			sky.scale = Vector2(86.0 / 40.0, D.EXTRA_PITCH / 40.0)
			nodes.append(sky)
	var src := D.rect_of("1S") if f % 2 == 1 else D.rect_of("3S")
	var dst := D.rect_of("%dS" % f)
	var hs := _sprite(L_hall, src, dst.position)
	hs.scale = dst.size / src.size
	nodes.append(hs)
	var hp := Sprite2D.new()
	hp.texture = art
	hp.centered = false
	hp.region_enabled = true
	hp.region_rect = src
	hp.position = dst.position
	hp.scale = dst.size / src.size
	hp.visible = false
	L_hall.add_child(hp)
	hall_paint_sp[f] = hp
	nodes.append(hp)
	var st := _Stairs.new()
	st.variant = 1 if f % 2 == 1 else 3
	st.position = dst.position
	st.scale = dst.size / src.size
	st.lv = stair_lv()
	if hub_nodes.has(f): st.long = HUB_STAIR_LONG
	L_stairs.add_child(st)
	stair_nodes[f - 1] = st
	nodes.append(st)
	for side in ["L", "R"]:
		var id := "%d%s" % [f, side]
		if not S.rooms.has(id) or not D.ROOMS.has(id): continue
		var fx := RoomFx.new()
		rooms_root.add_child(fx)
		fx.setup(self, id, shell_tex, null, font)
		room_fx[id] = fx
		nodes.append(fx)
		fx.dekor = dekor
		fx.building = job_for(id, "build") != {}
		var ev_id := event_at(id)
		S.rooms[id]["_ev"] = "" if ev_id.is_empty() else str(ev_id.type)
		fx.refresh(S.rooms[id], int(S.lvl), build_cost(), font)
		fx.set_floor_lock(floor_lock_sign(f))
		var lt: Texture2D = load(D.furn_tex(id, "lampu", 1))
		var lr := D.furn_rect(id, "lampu", lt.get_size())
		var pl := _mk_light(Vector2(lr.position.x + lr.size.x * (0.58 if D.furn_flip(id) else 0.42), lr.position.y + lr.size.y * 0.16), 120, bld)
		room_lights[id] = [pl]
		nodes.append(pl)
		if funny and funny.game and str(S.rooms[id].get("broken", "")) == Funny.GOSONG: funny._show_soot(id)
	var sp := Sprite2D.new()
	sp.centered = false
	sp.position = D.facil_rect(f).position
	sp.visible = false
	L_facil.add_child(sp)
	facil_sp[f] = sp
	nodes.append(sp)
	var fr := D.facil_rect(f)
	var fl := _mk_light(fr.position + Vector2(fr.size.x / 2.0, 70), 95, bld)
	facil_lights[f] = fl
	nodes.append(fl)
	_floor_nodes[f] = nodes
	_refresh_facil_floor(f)
	_refresh_hall_paint()
	_refresh_fire()


func _dematerialize(f: int) -> void:
	if not _floor_nodes.has(f): return
	for side in ["L", "R"]:
		var id := "%d%s" % [f, side]
		room_fx.erase(id)
		room_lights.erase(id)
		fire_fx.erase(id)
		if funny: funny._soot.erase(id)
	hall_paint_sp.erase(f)
	facil_sp.erase(f)
	facil_lights.erase(f)
	if f - 1 < stair_nodes.size(): stair_nodes[f - 1] = null
	for n in _floor_nodes[f]:
		if is_instance_valid(n): n.queue_free()
	_floor_nodes.erase(f)


func _materialize_window(vr: Vector2i) -> void:
	if vr.y < vr.x: vr = Vector2i(1, 1)
	for f in range(maxi(1, vr.x - MAT_PAD), mini(D.TOP_FLOOR, vr.y + MAT_PAD) + 1):
		_materialize(f)
	for f in _floor_nodes.keys():
		if f < vr.x - MAT_DROP or f > vr.y + MAT_DROP: _dematerialize(f)


## Hanya lantai yang terlihat (plus 1 di atas & bawah) yang digambar dan dianimasikan.
func _cull() -> void:
	_cull_acc = 0.0
	if bld == null: return
	var top := -scroll - 420.0
	var bot := D.LOBBY_TOP - scroll + 420.0
	for n in npcs.values():
		if not is_instance_valid(n): continue
		if n.scene == "lobby" or n.get_parent() == npc_lobby:
			n.set_culled(false)
			continue
		var y: float = n.position.y
		n.set_culled(y < top or y > bot)
	for id in room_fx:
		var fx: Node2D = room_fx[id]
		var r: Rect2 = D.rect_of(id)
		var on := r.end.y > top and r.position.y < bot
		if fx.is_processing() != on: fx.set_process(on)
		if fx.visible != on: fx.visible = on
	var vr := vis_floors()
	if vr != _vis_last: _materialize_window(vr)
	for i in stair_nodes.size():
		var st: Node2D = stair_nodes[i]
		if st == null: continue
		var on2 := i + 1 >= vr.x and i + 1 <= vr.y
		if st.visible != on2:
			st.visible = on2
			st.set_process(on2)
	for hf in hub_nodes:
		var hn: Node2D = hub_nodes[hf]
		var on3: bool = int(hf) >= vr.x and int(hf) <= vr.y
		if hn.visible != on3:
			hn.visible = on3
			hn.set_process(on3)
	if vr != _vis_last:
		_vis_last = vr
		_sync_npcs()
var _probe := false
var _probe_t := 0


func _process(dt: float) -> void:
	if _probe:
		var now := Time.get_ticks_msec()
		if now / 5000 != _probe_t / 5000: print("MEM static ", int(OS.get_static_memory_usage() / 1048576), "MB tex ", int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576), "MB objs ", Performance.get_monitor(Performance.OBJECT_COUNT), " nodes ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if _probe_t > 0 and now - _probe_t > 400: print("SLOW frame ", now - _probe_t, "ms at ", int(S.min) / 60, ":", int(S.min) % 60, " day ", S.day, " npcs ", npcs.size())
		_probe_t = now
	# Detak untuk penjaga di halaman web: kalau game berhenti total, halaman dimuat ulang.
	_beat_acc += dt
	if _beat_acc > 1.0 and OS.has_feature("web"):
		_beat_acc = 0.0
		JavaScriptBridge.eval("window.__gdbeat=Date.now()", true)
	_renov_acc += dt
	if _renov_acc > 1.0:
		_renov_acc = 0.0
		if not S.get("renov", {}).is_empty():
			_check_renov()
			dirty = true
	var sp := int(S.speed)
	if not ui.is_welcome_open() and not cutscene_on and sp > 0:
		_acc += dt
		var guard := 0
		while _acc >= 0.1 and guard < 10:
			_acc -= 0.1
			guard += 1
			for i in range(sp):
				_step()
	_drag_watchdog(dt)
	_cull_acc += dt
	if _cull_acc > 0.2:
		_cull_acc = 0.0
		_cull()
	_separate_npcs()
	_chat_tick(dt)
	_thief_tick(dt)
	_cat_tick(dt)
	_facil_tick(dt)
	_auto_acc += dt
	_tired_tick(dt)
	if _auto_acc > 3.0:
		_auto_acc = 0.0
		if not S.queue.is_empty(): _auto_checkin()
	if funny and funny.game: funny.tick(dt)
	_preman_tick(dt)
	_ojol_tick(dt)
	if sp > 0:
		for n in npcs.values().duplicate():
			if is_instance_valid(n):
				var lvm := 1.0
				if n.kind == "staff" and n.role != "":
					lvm = 1.0 + (staff_perf(n.role) - 1.0) * 0.5
				n.speed_mul = (1.0 + (sp - 1) * 0.5) * float(n.get_meta("spd", 1.0)) * lvm
				n.tick(dt)
		recep_art.visible = S.staff.get("resep", false) and not npcs.has("keeper")
		_keeper_tick(dt)
		if _keeper_t > 0.0:
			_keeper_t -= dt
			if _keeper_t <= 0.0:
				_set_keeper("idle")
		recep_art.position.y = 1962 + sin(Time.get_ticks_msec() / 600.0) * 1.5
	_brain_acc += dt
	if _brain_acc >= 0.5:
		_brain_acc = 0.0
		_sync_npcs()
		_staff_brain()
	# Inersia scroll & auto-scroll saat menyeret ke tepi.
	if pan.is_empty() and absf(scroll_v) > 5.0:
		set_scroll(scroll + scroll_v * dt)
		scroll_v *= pow(0.04, dt)
	if not drag.is_empty() and drag.get("active", false):
		var my := get_global_mouse_position().y
		if my < 420.0:
			set_scroll(scroll + 1100.0 * dt)
		elif my > 1600.0 and my < D.LOBBY_TOP + 60:
			set_scroll(scroll - 1100.0 * dt)
	_reparent_npcs()
	_truck_tick(dt)
	_update_light()
	if dirty:
		_refresh_world()
		if ui.kind != "" and ui.kind != "welcome":
			ui.refresh_sheet()
	ui.update_hud()
	_save_acc += dt
	if _save_acc > 10.0 and not _no_save:
		_save_acc = 0.0
		save_game()


func _notification(what: int) -> void:
	if _no_save: return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not S.is_empty():
			save_game()


var _renov_acc := 0.0


func _step() -> void:
	_turbo_tick()
	_tick_jobs(2.0)
	S.min = int(S.min) + 2
	S.next_cand = float(S.next_cand) - 2.0
	if S.next_cand <= 0.0:
		_spawn_cand()
	if int(S.min) % 60 == 0:
		if int(S.min) >= 1440:
			_new_day()
		_hourly()


func _next_guest_soon() -> void:
	if S.queue.is_empty():
		S.next_cand = minf(float(S.next_cand), randf_range(40.0, 90.0))


## Filter calon penyewa (gratis, butuh aplikasi KostTerdekat). Makin ketat, makin jarang datang.
func kt_filter() -> Dictionary:
	if not has_app("kostterdekat"): return {"g": "", "job": "", "clean": false}
	var f: Dictionary = S.get("kt_filter", {})
	return {"g": str(f.get("g", "")), "job": str(f.get("job", "")), "clean": bool(f.get("clean", false))}


func kt_filter_slow() -> float:
	var f := kt_filter()
	return 1.0 + (0.15 if f.g != "" else 0.0) + (0.2 if f.job != "" else 0.0) + (0.15 if f.clean else 0.0)


func set_kt_filter(key: String, val) -> void:
	if not S.has("kt_filter"): S.kt_filter = {}
	S.kt_filter[key] = val
	dirty = true


func _spawn_cand() -> void:
	var base := 330.0 * (1.4 - float(S.rep) * 0.15) * (0.7 if S.staff.get("resep", false) else 1.0) \
		* float(D.PRICE[int(S.price)].c) * pow(0.96, fac_count()) * (0.8 if has_facil("tunggu") else 1.0)
	S.next_cand = base * randf_range(0.7, 1.3) * (0.6 if has_app("kostterdekat") else (2.4 if is_sepi() else 1.0)) * (funny.cand_mul() if funny and funny.game else 1.0) * kt_filter_slow()
	if S.queue.size() >= queue_cap():
		return
	var flt: Dictionary = kt_filter()
	var p := gen_person(str(flt.g) if str(flt.g) != "" else ["p", "l"].pick_random())
	if str(flt.job) != "" and D.JOBS.has(flt.job) and int(D.JOBS[flt.job].min) <= int(S.lvl) and not (p.char in D.CHAR_TUA):
		p.job = flt.job
		p.pref = int(D.JOBS[flt.job].pref)
	if flt.get("clean", false):
		# KostTerdekat sudah cek pekerjaan & riwayat: sifat buruk dari dua sumber itu tersaring.
		p.traits = p.traits.filter(func(k): return not (D.TRAITS[k].bad and D.TRAITS[k].via in ["kerja", "riwayat"]))
		p.checked["riwayat"] = true
	if S.staff.get("resep", false):
		p.checked["wawancara"] = true    # Maryam mewawancarai tamu di meja depan
	if has_app("kostterdekat"):
		p.checked["kerja"] = true        # profil terverifikasi di aplikasi
		p.via = "KostTerdekat"
	S.queue.append(p)
	ui.toast("Calon penyewa datang: %s (%s)" % [p.name, p.job])
	dirty = true


func _hourly() -> void:
	_tick_events_hour()
	_auto_checkin()
	var h := int(S.min) / 60
	_maybe_thief(h)
	if funny: funny.hourly(h)
	if out_lv("polisi") < 2 or randf() < 0.4: _maybe_preman(h)
	_maybe_fire(h)
	_maybe_ojol(h)
	_maybe_galon(h)
	if wa: wa.hourly(h)
	if season: season.hourly(h)
	_maybe_sampah(h)
	for id in D.ROOMS:
		var r: Dictionary = S.rooms[id]
		if not r.built:
			continue
		r.clean = clampf(float(r.clean) - [1.3, 1.0, 0.85, 0.75][out_lv("sampah")] * (0.6 * _trait_mult(r.tenant, "dirt") if r.tenant != null else 0.08) * (0.75 if has_facil("laundry") else 1.0), 0, 100)
		if r.tenant != null and str(r.broken) == "" and randf() < 0.003:
			r.broken = D.RANDOM_ISSUES.pick_random()
			ui.toast("%s di Kamar %s!" % [r.broken, D.room_name(id)], "bad")
	var pat := (72 if S.staff.get("resep", false) else 48) + (36 if has_facil("tunggu") else 0)
	var keep := []
	for p in S.queue:
		p.wait = int(p.wait) + 1
		if int(p.wait) > pat + (48 if p.get("auto", false) else 0):
			ui.toast("%s lelah menunggu dan pergi" % p.name)
		else:
			keep.append(p)
	S.queue = keep
	if h == 8:
		_check_sepi()
	if h == 9:
		_collect_rent()
	if h == 17:
		_pay_salary()
	dirty = true


func _collect_rent() -> void:
	var tot := 0.0
	for e in each_tenant():
		var id: String = e[0]
		var r: Dictionary = e[1]
		var t: Dictionary = r.tenant
		var ev_r := event_at(id)
		if not ev_r.is_empty() and ev_r.type == "telat_bayar":
			float_at(id, "Belum bayar", Color("b5543c"))
			continue
		if (float(t.happy) < 30 and randf() < 0.4) or (has_trait(t, "bayar_seret") and randf() < (0.08 if has_app("kelolapro") else 0.2)):
			float_at(id, "Telat bayar", Color("b5543c"))
			continue
		var a := rent_of(r)
		_maybe_tip(id)
		if npcs.has(t.id) and float(t.happy) > 80 and presence(t) != "away" and randf() < 0.5:
			npcs[t.id].react("happy", 1.8)
		if not has_app("kelolapro"):
			# Tanpa KelolaPro: sewa menunggu ditagih manual (ketuk koin di kamar).
			r.due = float(r.get("due", 0.0)) + a
			continue
		tot += a
		float_at(id, "+" + D.short(a), Color("2f7a2a"))
	if tot > 0:
		S.money = float(S.money) + tot
		S.today.rent = float(S.today.rent) + tot
		S.total.rent = float(S.total.rent) + tot
		add_xp(round(tot / 2500.0))
		ui.toast("KelolaPro menagih sewa otomatis: %s" % D.rp(tot), "gold")
	if has_app("kelolapro"):
		for id in D.ROOMS: collect_due(id)
	elif due_total() > 0:
		ui.toast("Sewa sudah jatuh tempo! Ketuk koin di kamar untuk menagih.", "gold")


## Mulai Level 4 kost mulai sepi: tanpa promosi di KostTerdekat calon penyewa jauh lebih jarang.
const SEPI_LV := 4


func is_sepi() -> bool:
	return int(S.lvl) >= SEPI_LV and not has_app("kostterdekat")


func _check_sepi() -> void:
	if not is_sepi() or S.get("sepi_told", false): return
	S.sepi_told = true
	keeper_say("Hmm, kost lagi sepi nih...", 4.0)
	ui.toast("Kost mulai sepi! Calon penyewa jarang datang. Promosikan kost lewat KostTerdekat (Kelola › Fasilitas Kost).", "bad")


## Penghuni yang puas kadang memberi tips (saat bayar sewa).
func _maybe_tip(id: String) -> void:
	var r: Dictionary = S.rooms[id]
	var t = r.tenant
	if t == null or float(t.happy) < 85 or randf() > 0.25: return
	var tip := roundf(rent_of(r) * randf_range(0.3, 0.8) / 1000.0) * 1000.0
	S.money = float(S.money) + tip
	S.today.rent = float(S.today.rent) + tip
	float_at(id, "Tips +" + D.short(tip), Color("c08a10"))
	sfx("buy", -8.0)
	var why: String = ["Kamarnya nyaman banget!", "Makasih udah dirawat baik!", "Kost terbaik!", "Buat jajan, Mbak Maryam!"].pick_random()
	ui.toast("%s memberi tips %s: \"%s\"" % [t.name, D.rp(tip), why], "gold")
	if npcs.has(t.id): npcs[t.id].say(why, 2.5)


func due_total() -> float:
	var s := 0.0
	for id in D.ROOMS:
		s += float(S.rooms[id].get("due", 0.0))
	return s


func collect_due(id: String) -> void:
	var r: Dictionary = S.rooms[id]
	var a := float(r.get("due", 0.0))
	if a <= 0.0: return
	r.due = 0.0
	S.money = float(S.money) + a
	S.today.rent = float(S.today.rent) + a
	S.total.rent = float(S.total.rent) + a
	add_xp(round(a / 2500.0))
	float_at(id, "+" + D.short(a), Color("2f7a2a"))
	sfx("buy", -6.0)
	if r.tenant != null and npcs.has(r.tenant.id) and randf() < 0.5:
		npcs[r.tenant.id].say(["Ini sewanya, Mbak Maryam!", "Lunas ya~", "Makasih, Mbak!"].pick_random(), 2.2)
	dirty = true


## Waiting list: Penjaga Kost mengarahkan tamu ke Ruang Tunggu.
func waiting_room_on() -> bool:
	return has_facil("tunggu") and S.staff.get("resep", false)


func queue_cap() -> int:
	return 1 + (1 if has_app("kostterdekat") else 0) + (3 if waiting_room_on() else 0)


var _desk_say_t := 0.0


func keeper_say(text: String, dur: float = 3.5) -> void:
	if npcs.has("keeper"):
		npcs.keeper.say(text, dur)
	elif desk_tag:
		_desk_text(text, true)
		_desk_say_t = dur


## Label di atas meja depan: nama Maryam, atau kalimatnya (dibungkus, tetap di dalam layar).
func _desk_text(text: String, talk: bool) -> void:
	var l := desk_tag.get_child(0) as Label
	# Bungkus manual per ±24 huruf (autowrap di PanelContainer membuat tinggi kotak keliru).
	var lines: Array = []
	var cur := ""
	for wd in text.split(" "):
		if talk and cur != "" and (cur +" " + wd).length() > 24:
			lines.append(cur)
			cur = wd
		else:
			cur = wd if cur == "" else cur +" " + wd
	lines.append(cur)
	l.text = "\n".join(lines)
	desk_tag.size = Vector2.ZERO
	desk_tag.reset_size()
	desk_tag.position = Vector2(minf(1140.0, 1418.0 - desk_tag.size.x), 1960.0 - desk_tag.size.y)


## Taruh tamu di Ruang Tunggu: dia duduk menunggu & otomatis masuk kamar yang kosong.
func send_to_waiting(pid: String) -> void:
	for p in S.queue:
		if str(p.id) == pid:
			p.auto = true
			p.wait = 0
			ui.toast("%s menunggu di Ruang Tunggu. Begitu ada kamar siap, dia langsung masuk." % p.name, "gold")
			_auto_checkin()
			dirty = true
			return


## Ruang Tunggu (dijaga Maryam) otomatis memasukkan antrean ke kamar kosong.
func _auto_checkin() -> void:
	var auto_all := waiting_room_on()
	for p in S.queue.duplicate():
		if not p.get("auto", false) and not auto_all: continue
		var er := empty_rooms()
		if er.is_empty(): return
		er.sort_custom(func(a, b): return D.fl(a) < D.fl(b))
		var rid: String = er[0]
		act("assign","%s|%s" % [p.id, rid])
		ui.toast("Ruang Tunggu: %s langsung masuk Kamar %s" % [p.name, D.room_name(rid)], "gold")
		dirty = true


var _auto_acc := 0.0

# ---------------- Maryam capek setelah 2 jam main nonstop ----------------
const TIRED_SECS := 2 * 3600.0
var play_secs := 0.0


func _tired_tick(dt: float) -> void:
	if ui.side.active():
		# Istirahat di cafe / padel memulihkan Maryam dengan cepat.
		play_secs = maxf(0.0, play_secs - dt * 40.0)
		return
	play_secs += dt
	if play_secs < TIRED_SECS: return
	if ui.kind != "" or not drag.is_empty() or cutscene_on or int(S.get("tut", -1)) >= 0: return
	play_secs = TIRED_SECS - 1800.0   # kalau ditunda, ditanya lagi 30 menit kemudian
	keeper_say("Huft... capek juga ya. Ngopi dulu yuk?", 4.0)
	ui.open_sheet("tired")


func go_side(where: String) -> void:
	ui.close_sheet()
	if npcs.has("keeper"):
		ui.toast("Maryam selesaikan tugasnya dulu, sebentar lagi berangkat.")
		return
	ui.side.visible = true
	ui.set_nav_visible(false)
	ui.side.loc = "kost" if where == "cafe" else "cafe"
	ui.side._walk(-1)


func has_app(k: String) -> bool:
	return S.get("apps", {}).has(k)


# ================= Level & kelelahan karyawan =================
## Berapa kamar yang sanggup diurus satu karyawan per level.
const STAFF_CAP := [0, 6, 12, 20, 32, 50, 75, 110]


func staff_lv(k: String) -> int:
	return int(S.get("slv", {}).get(k, 1))


func staff_cap(k: String) -> int:
	var lv := staff_lv(k)
	if lv < STAFF_CAP.size(): return STAFF_CAP[maxi(lv, 1)]
	return 110 + 40 * (lv - STAFF_CAP.size() + 1)


## Level tanpa batas, tapi manfaatnya makin landai (soft cap): kinerja mendekati 2,4x.
func staff_perf(k: String) -> float:
	return 1.0 + 1.4 * (1.0 - pow(0.86, float(staff_lv(k) - 1)))


## Gelar sesuai level, untuk tampilan.
func staff_rank(k: String) -> String:
	var lv := staff_lv(k)
	if lv >= 20: return "Legenda"
	if lv >= 15: return "Master"
	if lv >= 10: return "Ahli"
	if lv >= 5: return "Senior"
	return "Junior"


func staff_sal(k: String) -> float:
	var lv := staff_lv(k)
	var m := 1.0 + 0.4 * (mini(lv, 7) - 1) + 0.2 * maxi(lv - 7, 0)
	return roundf(float(D.STAFF[k].sal) * m / 1000.0) * 1000.0


func staff_up_cost(k: String) -> float:
	var lv := staff_lv(k)
	return roundf(float(D.STAFF[k].sal) * 12.0 * lv * pow(1.12, maxf(0.0, lv - 7.0)) / 1000.0) * 1000.0


func staff_tired(k: String) -> float:
	return float(S.get("tired", {}).get(k, 0.0))


func staff_strike(k: String) -> bool:
	return S.get("strike", {}).has(k)


func built_rooms() -> int:
	var n := 0
	for id in D.ROOMS:
		if S.rooms[id].built: n += 1
	return n


## Tiap pagi: beban kerja di atas kapasitas menambah capek; 100% = mogok sehari.
func _staff_daily() -> void:
	if not S.has("tired"): S.tired = {}
	if not S.has("strike"): S.strike = {}
	for k in S.strike.keys():
		if int(S.day) >= int(S.strike[k]):
			S.strike.erase(k)
			S.staff[k] = true
			S.tired[k] = 30.0
			ui.toast("%s kembali bekerja setelah istirahat." % D.staff_label(k), "gold")
	var rooms := built_rooms()
	for k in S.staff.keys():
		if not S.staff[k] or D.STAFF[k].get("owner", false): continue
		var over := rooms - staff_cap(k)
		var t := staff_tired(k)
		t = t + over * 9.0 if over > 0 else t - 20.0
		t = clampf(t, 0.0, 100.0)
		S.tired[k] = t
		if t >= 100.0:
			S.staff[k] = false
			S.strike[k] = int(S.day) + 1
			S.tired[k] = 100.0
			ui.toast("%s kecapekan & MOGOK sehari! Upgrade level-nya di menu Karyawan." % D.staff_label(k), "bad")
			keeper_say("Aduh, %s mogok kerja..." % D.STAFF[k].nama, 4.0)
		elif t >= 70.0 and over > 0:
			ui.toast("%s mulai kecapekan (%d%%). Kamar terlalu banyak untuk Level %d." % [D.STAFF[k].nama, roundi(t), staff_lv(k)], "bad")


func staff_upgrade(k: String) -> void:
	var c := staff_up_cost(k)
	if float(S.money) < c:
		ui.toast("Uang tidak cukup (%s)" % D.rp(c), "bad"); return
	spend(c, "other")
	if not S.has("slv"): S.slv = {}
	S.slv[k] = staff_lv(k) + 1
	if S.has("tired"): S.tired[k] = maxf(0.0, staff_tired(k) - 50.0)
	ui.toast("%s naik ke Level %d (%s)! Sanggup mengurus %d kamar, kinerja %d%%." % [D.staff_label(k), staff_lv(k), staff_rank(k), staff_cap(k), roundi(staff_perf(k) * 100.0)], "gold")
	sfx("upgrade")


## Catat kemunculan pengacau (untuk katalog Karyawan > Pengacau).
func pengacau_seen(k: String) -> void:
	if not S.has("pengacau"): S.pengacau = {}
	S.pengacau[k] = int(S.pengacau.get(k, 0)) + 1


func out_lv(k: String) -> int:
	return clampi(int(S.get("out", {}).get(k, 0)), 0, D.OUTSRC[k].lv.size() - 1)


func out_upgrade(k: String) -> void:
	var lv := out_lv(k)
	if lv >= D.OUTSRC[k].lv.size() - 1: return
	var nx: Dictionary = D.OUTSRC[k].lv[lv + 1]
	if D.OUTSRC[k].get("dia", false):
		if int(W.diamonds) < int(nx.cost):
			ui.toast("Diamond tidak cukup (butuh %d). Beli di Toko." % int(nx.cost), "bad")
			ui.open_sheet("toko")
			return
		W.diamonds = int(W.diamonds) - int(nx.cost)
		save_wallet()
	else:
		if float(S.money) < float(nx.cost):
			ui.toast(ui.money_why(float(nx.cost)), "bad"); return
		spend(float(nx.cost), "other")
	if not S.has("out"): S.out = {}
	S.out[k] = lv + 1
	sfx("upgrade")
	add_xp(15)
	ui.toast("%s sekarang: %s!" % [D.OUTSRC[k].n, nx.n], "gold")
	dirty = true


# ================= Penghasilan saat game ditutup =================
const AWAY_MAX_H := 12.0          # maksimal jam yang dihitung
const AWAY_DAYS_PER_H := 1.5      # 1 jam nyata = 1,5 hari di kost
var away := {}
var wa: WaGroup
var season: Season


func _salary_total() -> float:
	var s := float(D.OUTSRC.sampah.lv[out_lv("sampah")].get("fee", 0))
	for k in S.staff:
		if S.staff[k]: s += staff_sal(k) * staff_crew(k)
	for k in S.apps:
		s += roundf(float(D.APPS[k].fee))
	return s


func _facil_income_est() -> float:
	var occ := each_tenant().size()
	var inc := 0.0
	var seen := {}
	for f in S.facil:
		var fc: Dictionary = D.FACIL[S.facil[f]]
		var bi: int = int(seen.get(S.facil[f], 0))
		seen[S.facil[f]] = bi + 1
		var mult := 1.0 if bi == 0 else maxf(0.3, 0.85 - 0.15 * bi)
		if fc.has("staff"):
			var on: bool = S.staff.get(fc.staff, false)
			if S.facil[f] == "laundry": mult = 2.0 if on else 1.0
			else: mult = mult if on else 0.0
		mult *= FACIL_LV_INC[facil_lv(str(f))]
		inc += float(fc.inc) * mult * occ
	return inc


## Waktu di kost tidak berjalan saat game ditutup (tidak ada kejadian buruk), tapi sewa,
## pemasukan fasilitas, dan gaji tetap dihitung untuk maks. 12 jam.
func _offline_gain() -> void:
	away = {}
	var t0 := float(S.get("saved_at", 0.0))
	if t0 <= 0.0: return
	var secs := Time.get_unix_time_from_system() - t0
	if secs < 600.0: return
	var hrs := minf(secs / 3600.0, AWAY_MAX_H)
	var days := hrs * AWAY_DAYS_PER_H
	var rent := 0.0
	for e in each_tenant(): rent += rent_of(e[1])
	rent *= days
	var fac := _facil_income_est() * days
	var sal := _salary_total() * days
	var due := 0.0
	if has_app("kelolapro"):
		S.money = float(S.money) + rent
	else:
		# Tanpa KelolaPro sewa menunggu ditagih (ketuk koin di kamar).
		for e in each_tenant():
			var a := rent_of(e[1]) * days
			e[1].due = float(e[1].get("due", 0.0)) + a
			due += a
	S.money = float(S.money) + fac - sal
	S.total.rent = float(S.total.rent) + rent + fac
	away = {"secs": secs, "hrs": hrs, "days": days, "rent": rent, "due": due, "fac": fac, "sal": sal, "capped": secs / 3600.0 > AWAY_MAX_H}
	S.saved_at = Time.get_unix_time_from_system()


func _pay_salary() -> void:
	var s := 0.0
	s += float(D.OUTSRC.sampah.lv[out_lv("sampah")].get("fee", 0))
	for k in S.staff:
		if S.staff[k]:
			s += staff_sal(k) * staff_crew(k)
	for k in S.apps:
		s += roundf(float(D.APPS[k].fee))
	if s > 0:
		spend(s, "salary")
		ui.toast("Gaji karyawan dibayar %s" % D.rp(s))


# ================= Dialog antar NPC =================
var _convos: Array = []
var _chat_acc := 0.0
var _chat_cd := {}   # id -> waktu (detik nyata) boleh ngobrol lagi
var _clock := 0.0

const CHAT_LONG := {
	"res": [
		["Eh, udah makan belum?", "Belum nih. Ke kantin bareng, yuk?", "Boleh! Aku traktir es teh.", "Asik, makasih ya!"],
		["Tugas kuliahmu udah kelar?", "Belum, deadline-nya besok...", "Semangat! Nanti kubantu cek.", "Kamu penyelamatku!"],
		["WiFi lancar ya hari ini.", "Iya, nonton nggak buffering lagi.", "Betah deh di kost ini."],
		["Kemarin hujan deras banget.", "Iya, jemuranku basah semua.", "Haha, nasib anak kost."],
		["Kamu asli mana?", "Aku dari Solo. Kamu?", "Medan. Sama-sama merantau ya.", "Iya, kost ini jadi rumah kedua."],
		["Kamar sebelah berisik nggak semalam?", "Aman kok, aku tidur nyenyak.", "Syukurlah. Kemarin aku begadang."],
		["Weekend ada rencana?", "Mau pulang kampung sebentar.", "Titip oleh-oleh ya, hehe.", "Siap, nanti kubawain keripik!"],
		["Kost ini makin bagus ya.", "Iya, perabotnya baru-baru.", "Semoga sewanya nggak naik.", "Amin, hahaha."],
	],
	"cand": [
		["Lagi cari kost juga?", "Iya, biar dekat kampus.", "Semoga kebagian kamar ya!", "Kamu juga, semangat!"],
		["Antrenya lumayan ya.", "Kost bagus memang rame.", "Katanya kamarnya bersih-bersih."],
		["Udah lihat kamarnya?", "Belum, nunggu dipanggil.", "Semoga dapat yang ada jendelanya."],
	],
	"barista": [["Kopi susu satu ya, Kak Nadia!", "Siap, ditunggu sebentar.", "Wangi banget kopinya.", "Gula arennya asli lho."]],
	"kantin": [["Bu Sari, nasi goreng satu.", "Pedas atau nggak, Nak?", "Pedas dong, Bu!", "Siap, sebentar ya."]],
	"trainer": [["Kak Ray, hari ini latihan apa?", "Kaki dulu! Squat 3 set ya.", "Waduh, besok jalan ngangkang nih.", "Hahaha, itu tandanya berhasil!"],
		["Kak Ray, perutku kapan sixpack?", "Kurangi gorengan, rajin cardio.", "Berat juga ya...", "Pelan-pelan aja, yang penting rutin!"]],
	"laundry": [["Mas Budi, titip cucian ya.", "Oke, besok sore beres.", "Sekalian disetrika ya, Mas.", "Beres!"]],
	"keeper": [
		["Mbak Maryam, paketku udah datang?", "Sudah, ada di meja depan.", "Makasih, Mbak!"],
		["Mbak Maryam, airnya lancar kan?", "Aman, baru dicek tadi pagi.", "Sip, makasih!"],
	],
}
# Dialog saat penghuni sedang punya perasaan/masalah: [kalimat penghuni & lawan bicara bergantian]
const MOOD_KEEPER := {
	"marah": [["Mbak Maryam, aku kesel banget! Kamarku bikin nggak nyaman!", "Aduh, maaf ya. Ceritain pelan-pelan, apa yang bikin kesel?", "Pokoknya kotor, sumpek, bikin bete!", "Siap, aku beresin hari ini juga. Sabar ya~", "...Oke deh, makasih Mbak."]],
	"pusing": [["Mbak, kepalaku pusing banget...", "Aduh, udah makan belum? Minum air putih dulu, ya.", "Belum sempat, tugasnya numpuk.", "Istirahat dulu. Nanti saya bikinin teh hangat.", "Mbak Maryam baik banget, makasih!"]],
	"lelah": [["Hoaam... capek banget hari ini, Mbak.", "Kerja keras ya? Langsung mandi air hangat terus tidur.", "Iya, besok masuk pagi lagi.", "Semangat! Kost ini rumahmu, istirahat yang cukup ya."]],
	"air_mati": [["Mbak, air di kamarku mati! Aku belum mandi!", "Waduh! Saya cek pompanya sekarang, ya.", "Cepetan ya Mbak, mau berangkat kerja..."]],
	"wifi_lemot": [["Mbak, WiFi-nya lemot banget, aku lagi meeting online!", "Aduh, coba saya restart router-nya dulu, ya."]],
	"berisik": [["Mbak, kamar sebelah berisik terus, aku nggak bisa tidur...", "Duh, nanti saya tegur baik-baik, ya. Maaf banget."]],
	"kunci_hilang": [["Mbak, kunci kamarku hilang!", "Tenang, ada kunci cadangan di meja depan. Nanti saya ambilkan."]],
	"mcb": [["Listrik kamarku jeglek, Mbak!", "Coba saya naikkan MCB-nya dulu, ya."]],
	"atap_bocor": [["Mbak, atap kamarku bocor, kasurku basah!", "Waduh! Taruh ember dulu ya, saya panggilkan teknisi."]],
	"hama": [["Mbak, ada kecoak di kamarku! Ihh!", "Tenang, tenang! Saya ambil semprotan dulu!"]],
	"paket_hilang": [["Mbak, paketku kok nggak ada ya?", "Hmm, coba saya cek CCTV dan buku tamu dulu."]],
}
const MOOD_FRIEND := {
	"marah": [["Lagi bete ya? Mukamu kusut banget.", "Iya, kamarku bikin kesel.", "Lapor aja ke Mbak Maryam, dia cepat tanggap kok.", "Oke, nanti aku bilang."]],
	"pusing": [["Kamu pucat, lagi sakit?", "Pusing dikit...", "Nih, aku punya minyak angin. Istirahat ya!", "Makasih banget!"]],
	"lelah": [["Capek ya? Mau kubikinin mie?", "Boleh banget... laper.", "Yuk ke dapur bareng!"]],
}
const MOOD_STAFF := {
	"cleaner": [["Mas Mustofa, kamarku tolong dibersihin dong.", "Siap, habis ini langsung saya ke sana!"]],
	"teknisi": [["Mas Boy, ada yang rusak di kamarku...", "Oke, saya bawa perkakas dulu, ya."]],
	"satpam": [["Pak John, paketku kok hilang ya?", "Saya cek CCTV & buku tamu dulu, Kak."]],
}


## Perasaan/masalah penghuni yang bisa jadi bahan obrolan ("" = biasa saja).
func _talk_mood(n: Npc) -> String:
	if n.kind != "res": return ""
	for e in each_tenant():
		var t: Dictionary = e[1].tenant
		if t.id != n.id: continue
		var ev := event_at(e[0])
		if not ev.is_empty() and MOOD_KEEPER.has(ev.type): return ev.type
		var hp := float(t.happy)
		if hp < 32: return "marah"
		if hp < 48: return "pusing"
		var hr := int(S.min) / 60
		if hr >= 20 or hr < 2: return "lelah"
		return ""
	return ""


## Curhat ke petugas hanya kalau memang urusan petugas itu.
func _staff_fits(role: String, mood: String, n: Npc) -> bool:
	var id := _room_of_npc(n)
	match role:
		"teknisi": return mood in ["air_mati", "mcb", "atap_bocor", "wifi_lemot"] or (id != "" and str(S.rooms[id].broken) != "")
		"cleaner": return mood == "hama" or (id != "" and float(S.rooms[id].clean) < 45)
		"satpam": return mood == "paket_hilang" or _recent("maling", 0, 2)
	return false


func _room_of_npc(n: Npc) -> String:
	for e in each_tenant():
		if e[1].tenant.id == n.id: return e[0]
	return ""


## Penghuni yang sedang kesal/pusing lewat lobi → curhat ke Maryam di meja depan.
var _desk_convo := {}


func _desk_chat_tick(dt: float) -> void:
	if not _desk_convo.is_empty():
		var n: Npc = _desk_convo.n
		if not is_instance_valid(n) or n.scene != "lobby" or not recep_art.visible:
			if is_instance_valid(n): n.blocked = false
			_desk_convo = {}
			return
		n.blocked = true
		n.dir = 1
		_desk_convo.t -= dt
		if _desk_convo.t > 0.0: return
		var lines: Array = _desk_convo.lines
		var i: int = _desk_convo.i
		if i >= lines.size():
			n.blocked = false
			_mood_relief(n, _desk_convo.mood)
			_chat_cd[n.id] = _clock + 90.0
			_desk_convo = {}
			return
		var line: String = lines[i]
		var dur := clampf(1.3 + line.length() * 0.06, 2.0, 4.2)
		if i % 2 == 0: n.say(line, dur)
		else: keeper_say(line, dur)
		_desk_convo.t = dur * 0.95
		_desk_convo.i = i + 1
		return
	if not S.staff.get("resep", false) or not recep_art.visible: return
	for n in npcs.values():
		if n.kind != "res" or n.scene != "lobby" or n.chat_with != null or n.fade_state != "": continue
		if float(_chat_cd.get(n.id, 0.0)) > _clock: continue
		if absf(n.position.x - 1150.0) > 520.0: continue
		var m := _talk_mood(n)
		if m == "" or m == "lelah" and randf() < 0.6: continue
		_chat_cd[n.id] = _clock + 30.0
		if randf() > 0.7: continue
		var sets: Array = MOOD_KEEPER[m]
		_desk_convo = {"n": n, "lines": sets.pick_random(), "i": 0, "t": 0.0, "mood": m}
		if OS.is_debug_build(): print("DESKCHAT ", m)
		if m == "marah": n.react("angry", 2.5)
		elif m == "pusing": n.react("sad", 2.5)
		elif m == "lelah": n.react("tired", 2.5)
		return


## Setelah curhat ditanggapi, penghuni sedikit lega.
func _mood_relief(n: Npc, mood: String) -> void:
	var id := _room_of_npc(n)
	if id == "": return
	var t: Dictionary = S.rooms[id].tenant
	t.happy = clampf(float(t.happy) + (5.0 if mood in ["marah", "pusing"] else 2.0), 0, 100)
	if is_instance_valid(n): n.react("happy", 1.6)


const CHAT_HI := ["Hai!", "Halo!", "Permisi~", "Mau ke mana?", "Duluan ya!", "Eh, hai!"]
const CHAT_REPLY := ["Hai juga!", "Mari~", "Hati-hati!", "Iya, silakan.", "Dadah!", "Halo!"]


func _greet() -> String:
	var hr := int(S.min) / 60
	if randf() < 0.5:
		return CHAT_HI[randi() % CHAT_HI.size()]
	if hr < 11: return "Pagi!"
	if hr < 15: return "Siang!"
	if hr < 18: return "Sore!"
	return "Malam!"


func _chatty(n: Npc) -> bool:
	if n == null or not is_instance_valid(n) or not n.visible or n.culled: return false
	if n.kind not in ["res", "cand", "staff", "keeper", "worker"]: return false
	if n.leaving or n.fade_state != "" or n.chat_with != null: return false
	if n.pose == "lie" or n.pose == "climb": return false
	return float(_chat_cd.get(n.id, 0.0)) <= _clock


func _idle(n: Npc) -> bool:
	return n.route.size() == 0 and (n.work.is_empty() or str(n.work.get("pose", "")) in ["stand", "counter", "sit"])


func _chat_tick(dt: float) -> void:
	_clock += dt
	for n in npcs.values():
		n.chat_tick(dt)
		if n.has_meta("nama"):
			n.set_bubble(str(n.get_meta("nama")) if n.scene == "lobby" and n.fade_state == "" else "")
	if desk_tag:
		desk_tag.visible = recep_art.visible
		if _desk_say_t > 0.0:
			_desk_say_t -= dt
			if _desk_say_t <= 0.0:
				_desk_text(D.STAFF.resep.nama, false)
	for c in _convos.duplicate():
		# NPC bisa sudah dihapus (pulang/pergi): jangan simpan ke variabel bertipe sebelum dicek.
		if not is_instance_valid(c.n[0]) or not is_instance_valid(c.n[1]):
			_end_chat(c)
			continue
		var a: Npc = c.n[0]
		var b: Npc = c.n[1]
		if c.get("hold", false) and is_instance_valid(a) and is_instance_valid(b):
			a.blocked = true
			b.blocked = true
		if not is_instance_valid(a) or not is_instance_valid(b) or a.leaving or b.leaving or a.scene != b.scene \
				or (c.long and not c.get("hold", false) and (a.route.size() > 0 or b.route.size() > 0)):
			_end_chat(c)
			continue
		c.t -= dt
		if c.t > 0.0: continue
		if c.i >= c.lines.size():
			if c.get("mood", "") != "": _mood_relief(c.moody, c.mood)
			_end_chat(c)
			continue
		var sp: Npc = c.n[c.i % 2]
		var line: String = c.lines[c.i]
		var dur := clampf(1.3 + line.length() * 0.06, 1.8, 3.6)
		if c.long:
			a.dir = 1 if b.position.x > a.position.x else -1
			b.dir = -a.dir
			for m in [a, b]:
				if m.work.is_empty() and m.route.size() == 0:
					m.work = {"t": 2.0, "pose": "stand" if m.pose not in ["sit", "counter"] else m.pose}
				elif not m.work.is_empty():
					m.work.t = maxf(float(m.work.t), 2.0)
		sp.say(line, dur)
		c.t = dur * 0.92
		c.i += 1
	_desk_chat_tick(dt)
	_chat_acc += dt
	if _chat_acc < 1.2: return
	_chat_acc = 0.0
	var pool: Array = []
	for n in npcs.values():
		if _chatty(n): pool.append(n)
	pool.shuffle()
	for a in pool:
		if a.chat_with != null: continue
		for b in pool:
			if b == a or b.chat_with != null or b.scene != a.scene: continue
			var near: float = 300.0 if a.scene == "lobby" else 150.0
			var dist: float = a.position.distance_to(b.position)
			if dist > near: continue
			var ma := _talk_mood(a)
			var mb := _talk_mood(b)
			if ma == "" and mb != "":
				var tmp: Npc = a
				a = b
				b = tmp
				ma = mb
			if ma != "" and dist < near * 0.8 and randf() < 0.6:
				var lines: Array = []
				if b.kind == "keeper" and MOOD_KEEPER.has(ma): lines = MOOD_KEEPER[ma].pick_random()
				elif b.kind == "staff" and MOOD_STAFF.has(b.role) and _staff_fits(b.role, ma, a):
					lines = MOOD_STAFF[b.role].pick_random()
				elif b.kind == "res" and MOOD_FRIEND.has(ma):
					var fl: Array = MOOD_FRIEND[ma].pick_random()
					lines = fl
					# yang menyapa duluan adalah teman yang perhatian
					var tmp2: Npc = a
					a = b
					b = tmp2
				if not lines.is_empty():
					_start_chat(a, b, lines, true)
					_convos[_convos.size() - 1].hold = true
					_convos[_convos.size() - 1].mood = ma
					var moody: Npc = a if _talk_mood(a) != "" else b
					_convos[_convos.size() - 1].moody = moody
					if OS.is_debug_build(): print("MOODCHAT ", ma," ", b.kind)
					moody.react({"marah": "angry", "pusing": "sad", "lelah": "tired"}.get(ma, "annoyed"), 2.5)
					break
			var both_idle: bool = _idle(a) and _idle(b)
			if both_idle and randf() < 0.35 and _convos.filter(func(c): return c.long).size() < 3:
				_start_long(a, b)
			elif not both_idle and dist < near * 0.6 and randf() < 0.5:
				var bn2 := _panggil(_who(b))
				var hr2 := int(S.min) / 60
				var tg := "Pagi" if hr2 < 11 else ("Siang" if hr2 < 15 else ("Sore" if hr2 < 18 else "Malam"))
				_start_chat(a, b, [_greet() if bn2 == "" or randf() < 0.5 else "%s, %s!" % [tg, bn2], CHAT_REPLY[randi() % CHAT_REPLY.size()]], false)
			break


func _start_long(a: Npc, b: Npc) -> void:
	# Yang lebih "tamu" (penghuni/calon) memulai, petugas menjawab.
	var rank := {"cand": 0, "res": 1, "worker": 2, "staff": 2, "keeper": 3}
	if int(rank.get(a.kind, 1)) > int(rank.get(b.kind, 1)):
		var t := a
		a = b
		b = t
	var lines := _context_lines(_who(a), _who(b))
	if lines.is_empty(): return
	_start_chat(a, b, lines, true)


## Data singkat tentang NPC untuk memilih topik obrolan yang masuk akal.
func _who(n: Npc) -> Dictionary:
	var w := {"kind": n.kind, "name": str(n.get_meta("nama", "")), "role": n.role, "job": "", "room": "", "floor": 0, "stay": 99, "happy": 70.0, "clean": 100.0, "p": {}}
	if n.kind == "keeper": w.name = D.STAFF.resep.nama
	if n.kind == "worker":
		w.role = n.char_id   # tukang / teknisi / kurir
		w.name = {"tukang": D.WORKER.build.nama, "teknisi": D.WORKER.fix.nama, "kurir": D.WORKER.deliver.nama}.get(n.char_id, "")
	if n.kind == "res":
		var id := _room_of_npc(n)
		if id != "":
			var r: Dictionary = S.rooms[id]
			var t: Dictionary = r.tenant
			w.name = t.name
			w.job = str(t.job)
			w.room = id
			w.floor = D.fl(id)
			w.stay = int(t.stay)
			w.happy = float(t.happy)
			w.clean = float(r.clean)
			w.p = t
	if n.kind == "cand":
		for q in S.queue:
			if q.id == n.id:
				w.name = q.name
				w.job = str(q.job)
				w.p = q
	return w


func _log_recent(type: String, room: String) -> void:
	if not S.has("recent"): S.recent = []
	S.recent.append({"type": type, "room": room, "day": int(S.day)})
	while S.recent.size() > 20: S.recent.pop_front()


func _recent(type: String, floor: int = 0, days: int = 1) -> bool:
	for e in S.get("recent", []):
		if e.type == type and int(S.day) - int(e.day) <= days and (floor == 0 or str(e.room) == "" or D.fl(str(e.room)) == floor):
			return true
	for e in S.events:
		if e.type == type and (floor == 0 or str(e.room) == "" or D.fl(str(e.room)) == floor):
			return true
	return false


const KOTA := ["Solo", "Medan", "Makassar", "Padang", "Malang", "Bandung", "Palembang", "Pontianak", "Kupang", "Banjarmasin"]
const SAPA := {"cleaner": "Mas", "teknisi": "Mas", "satpam": "Pak", "laundry": "Mas", "kantin": "Bu", "barista": "Kak", "tukang": "Pak", "kurir": "Mas", "trainer": "Kak", "kasir": "Kak", "tani": "Kang", "lele": "Pak", "petshop": "Mbak", "florist": "Mbak", "koperasi": "Bu", "warteg": "Bu"}


func _panggil(w: Dictionary) -> String:
	var nm: String = w.name
	if nm == "": return ""
	if w.kind == "keeper": return "Mbak" + nm
	if w.kind in ["staff", "worker"] and not nm.begins_with("Bu") and not nm.begins_with("Pak"):
		return "%s %s" % [SAPA.get(w.role, "Mas"), nm]
	return nm


## Pilih obrolan sesuai siapa yang bicara, jam, & kejadian yang benar-benar terjadi.
func _context_lines(a: Dictionary, b: Dictionary) -> Array:
	var hr := int(S.min) / 60
	var pagi := hr >= 5 and hr < 10
	var makan := (hr >= 11 and hr <= 13) or (hr >= 18 and hr <= 20)
	var malam := hr >= 19 or hr < 4
	var opts: Array = []
	var bn := _panggil(b)
	if a.kind == "res" and b.kind == "res":
		if int(b.stay) <= 1:
			opts.append(["Eh, penghuni baru ya? Aku %s dari kamar %s." % [a.name, D.room_name(a.room)], "Iya, aku %s. Baru pindah ke sini." % b.name, "Selamat datang! Kalau butuh apa-apa bilang aja.", "Makasih ya!"])
		if pagi:
			match str(b.job):
				"Mahasiswa": opts.append(["Pagi! Ada kuliah jam berapa?", "Jam sembilan, mau berangkat nih.", "Semangat kuliahnya!"])
				"Karyawan", "Manajer": opts.append(["Pagi! Mau berangkat kerja?", "Iya, takut kena macet.", "Hati-hati di jalan!"])
				"Freelancer": opts.append(["Hari ini kerja dari kamar lagi?", "Iya, lagi kejar deadline klien.", "Semangat! Jangan lupa makan."])
				"Pensiunan": opts.append(["Pagi, %s! Habis jalan pagi?" % ("Kek" if b.p.get("char", "") == "kakek" else "Nek"), "Iya, biar badan tetap sehat.", "Hebat, semangat terus!"])
				"Pedagang Pasar": opts.append(["Dagangan laris hari ini?", "Alhamdulillah, habis sebelum siang!", "Wah, mantap!"])
		if str(b.job) == "Perawat" and hr >= 12 and hr < 14:
			opts.append(["Mau masuk shift siang ya?", "Iya, jaga sampai malam.", "Semangat, Kak!"])
		if str(b.job) == "Mahasiswa" and hr >= 16:
			opts.append(["Tugas kuliahmu udah kelar?", "Belum, deadline-nya besok...", "Semangat! Nanti kubantu cek.", "Kamu penyelamatku!"])
		if str(b.job) in ["Karyawan", "Manajer"] and hr >= 18:
			opts.append(["Baru pulang? Lembur ya?", "Iya, kerjaan lagi numpuk.", "Istirahat gih, mukamu capek."])
		if _recent("berisik", int(a.floor)):
			opts.append(["Semalam kamar sebelah berisik banget, kamu kebangun nggak?", "Iya, aku sampai susah tidur.", "Semoga Mbak Maryam udah negur."])
		if _recent("air_mati"):
			opts.append(["Airnya sempat mati ya tadi?", "Iya, untung sekarang udah nyala lagi."])
		if _recent("hama"):
			opts.append(["Kamu lihat kecoak juga nggak kemarin?", "Lihat! Ihh, semoga udah dibasmi."])
		if makan:
			if has_facil("kantin"): opts.append(["Udah makan? Ke kantin bareng, yuk!", "Boleh! Aku traktir es teh.", "Asik, makasih ya!"])
			else: opts.append(["Udah makan? Beli nasi goreng depan, yuk!", "Yuk, laper juga nih."])
		if S.fac.has("wifi") and not _recent("wifi_lemot"):
			opts.append(["WiFi lancar ya hari ini.", "Iya, nonton nggak buffering lagi.", "Betah deh di sini."])
		if int(S.day) % 7 >= 5:
			opts.append(["Weekend ada rencana?", "Mau pulang kampung sebentar.", "Titip oleh-oleh ya, hehe.", "Siap, nanti kubawain keripik!"])
		if has_facil("gym") and (hr in [6, 7, 16, 17]):
			opts.append(["Nge-gym bareng yuk?", "Ayo, biar sehat!"])
		if float(S.rep) >= 4.0:
			opts.append(["Kost ini makin bagus ya.", "Iya, betah banget di sini."])
		var k1: String = KOTA[absi(str(a.name).hash()) % KOTA.size()]
		var k2: String = KOTA[absi(str(b.name).hash()) % KOTA.size()]
		opts.append(["Kamu asli mana?", "Aku dari %s. Kamu?" % k2,"%s. Sama-sama merantau ya." % k1, "Iya, kost ini jadi rumah kedua."])
	elif a.kind in ["res", "cand"] and b.kind == "keeper":
		if a.kind == "cand":
			opts.append(["Mbak, masih ada kamar kosong?", "Ada, Kak. Tunggu sebentar, saya cek dulu ya."])
		else:
			opts.append(["Mbak Maryam, paketku udah datang?", "Sudah, ada di meja depan.", "Makasih, Mbak!"])
			if int(a.stay) <= 1: opts.append(["Mbak, jam malam kost ini jam berapa?", "Jam sebelas, Kak. Tamu nggak boleh menginap, ya."])
			if float(S.rooms[a.room].get("due", 0.0)) > 0: opts.append(["Mbak, sewaku udah bisa dibayar?", "Bisa, Kak. Nanti aku tagih langsung ke kamar, ya."])
	elif a.kind in ["res", "cand"] and b.kind in ["staff", "worker"]:
		match str(b.role):
			"cleaner":
				if a.kind == "res" and float(a.clean) < 50: opts.append(["%s, kamarku tolong dibersihin dong." % bn, "Siap, habis ini saya ke sana!"])
				else: opts.append(["Makasih ya %s, lorongnya jadi kinclong." % bn, "Sama-sama, Kak. Jaga kebersihan, ya!"])
			"teknisi":
				if a.kind == "res" and (str(S.rooms[a.room].broken) != "" or not event_at(a.room).is_empty()):
					opts.append(["%s, ada yang rusak di kamarku..." % bn, "Oke, saya bawa perkakas dulu, ya."])
				else: opts.append(["%s, lagi cek apa?" % bn, "Cek instalasi listrik, biar aman.", "Makasih, Mas!"])
			"satpam":
				if _recent("maling", 0, 2): opts.append(["Pak John, katanya ada maling ya?", "Iya, tapi tenang, sudah saya usir."])
				elif malam: opts.append(["Pak John, aman malam ini?", "Aman, Kak. Saya keliling terus."])
				else: opts.append(["Pak John, titip motor ya.", "Siap, saya jagain."])
			"kurir": opts.append(["Paket buat siapa, %s?" % bn, "Perabot baru buat salah satu kamar!", "Wah, asik!"])
			"tukang": opts.append(["Lagi bangun apa, %s?" % bn, "Ruangan baru, biar kost makin rame!"])
			"barista", "kantin", "laundry", "trainer":
				var sets: Array = CHAT_LONG[b.role]
				opts.append(sets.pick_random())
	elif a.kind == "cand" and b.kind == "res":
		opts.append(["Kak, kost ini enak nggak?", "Enak kok, Mbak Maryam ramah!" if float(b.happy) > 60 else "Lumayan... kadang ada aja masalahnya.", "Makasih infonya, Kak!"])
	elif a.kind == "cand" and b.kind == "cand":
		opts.append(CHAT_LONG.cand.pick_random())
	elif a.kind in ["staff", "worker", "keeper"] and b.kind in ["staff", "worker", "keeper"]:
		var an := _panggil(a)
		if makan: opts.append(["Udah makan, %s?" % bn, "Belum, nanti bareng aja.", "Oke, habis kerjaan ini ya."])
		if pagi: opts.append(["Pagi, %s! Udah ngopi?" % bn, "Udah dong, biar semangat.", "Mantap!"])
		if malam: opts.append(["Shift malam lagi, %s?" % bn, "Iya. Kopi dulu biar melek.", "Semangat!"])
		if hr >= 15 and hr < 19: opts.append(["Capek juga ya hari ini, %s." % bn, "Iya, tapi kost-nya makin rame, %s." % an])
		if not makan and not pagi and not malam: opts.append(["Kerjaan aman, %s?" % bn, "Aman, %s. Lancar hari ini." % an])
	if opts.is_empty(): return []
	return opts.pick_random()


func _start_chat(a: Npc, b: Npc, lines: Array, long: bool) -> void:
	if OS.is_debug_build() and OS.get_cmdline_user_args().has("--chatlog"):
		print("CHAT %02d:00 %s(%s)->%s(%s): %s" % [int(S.min) / 60, a.kind, a.role if a.role != "" else _who(a).job, b.kind, b.role if b.role != "" else _who(b).job," / ".join(lines)])
	a.chat_with = b
	b.chat_with = a
	_convos.append({"n": [a, b], "lines": lines, "i": 0, "t": 0.0, "long": long})


func _end_chat(c: Dictionary) -> void:
	_convos.erase(c)
	for m in c.n:
		if is_instance_valid(m):
			m.chat_with = null
			if c.get("hold", false): m.blocked = false
			_chat_cd[m.id] = _clock + (45.0 if c.long else 14.0) + randf() * 20.0


# ================= Maling =================
# Malam hari maling mengendap-endap di lobi. Satpam mengejar, CCTV merekam,
# dan pemain bisa mengetuk maling untuk meneriakinya.
var thief: Npc = null
var _thief_state := ""
var _thief_t := 0.0
var _thief_night := -1


func _maybe_thief(h: int) -> void:
	if thief != null or not (h >= 23 or h <= 3): return
	if int(S.day) == _thief_night: return
	var occ := each_tenant().size()
	if occ < 3 or int(S.lvl) < 2: return
	var p := 0.06 if S.staff.get("satpam", false) else 0.11
	if randf() > p: return
	_thief_night = int(S.day)
	spawn_thief()


func spawn_thief() -> void:
	if thief != null: return
	if wa: wa.post("Penghuni ", "Eh, ada orang mencurigakan di lobi!!", "alert")
	var n := Npc.new()
	npc_lobby.add_child(n)
	n.setup("thief", "thief", D.STAFF_LOOK.teknisi, Vector2(D.OUT_X, D.LOBBY_Y), font)
	n.art = true
	n.char_id = "maling"
	n.art_map = {"walk": "walk", "stand": "idle", "steal": "steal", "caught": "caught"}
	n.set_meta("spd", 0.55)
	npcs["thief"] = n
	thief = n
	pengacau_seen("maling")
	_thief_state = "sneak"
	cat_startle()
	_thief_t = 0.0
	n.plan("lobby", Vector2(1000, D.LOBBY_Y), "stand", func(m: Npc):
		_thief_state = "grab"
		_thief_t = 3.0
		m.work = {"t": 3.0, "pose": "steal"}
		m.say("Hehehe...", 2.0))
	sfx("pop", -14.0)


func _thief_tick(dt: float) -> void:
	if thief == null: return
	if not is_instance_valid(thief):
		thief = null
		return
	_thief_t -= dt
	var guard: Npc = npcs.get("staff-satpam")
	match _thief_state:
		"sneak":
			if guard != null and is_instance_valid(guard) and guard.scene == "lobby" and absf(guard.position.x - thief.position.x) < 700:
				_thief_state = "chased"
				guard.say("Hei! Maling! Berhenti!", 2.5)
				guard.set_meta("spd", 1.5)
				guard.work = {}
				guard.plan("lobby", Vector2(thief.position.x, D.LOBBY_Y), "stand", func(m: Npc):
					m.set_meta("spd", 1.0)
					m.say("Jangan balik lagi, ya!", 2.5))
				_thief_flee("Waduh, ada satpam!")
				_thief_end("John mengusir maling! Kost aman.", 0.0)
		"grab":
			if out_lv("polisi") >= 2 and not npcs.has("polisi"):
				_police_come("thief")
			if _thief_t <= 0.0 and npcs.has("polisi"):
				_thief_t = 0.5
			elif _thief_t <= 0.0:
				var loss := minf(maxf(float(S.money) * 0.05, 100000), 600000)
				thief.art_map["walk"] = "carry"
				if S.fac.has("cctv"):
					_thief_flee("Dapat!")
					_thief_end("Maling mencuri, tapi CCTV merekam wajahnya. Barang berhasil kembali!", 0.0)
				else:
					_thief_flee("Kabur!")
					_thief_end("Kemalingan! Hilang %s. Pasang CCTV atau rekrut Satpam (John)." % D.rp(loss), loss)


func _thief_flee(line: String) -> void:
	_thief_state = "flee"
	thief.say(line, 2.0)
	if thief.art_map.get("walk", "") != "carry":
		thief.art_map["walk"] = "run"
	thief.set_meta("spd", 2.4)
	thief.work = {}
	thief.plan("lobby", Vector2(D.OUT_X - 200, D.LOBBY_Y), "stand", func(m: Npc):
		_remove_npc(m)
		thief = null)


func _thief_end(msg: String, loss: float) -> void:
	_log_recent("maling", "")
	if OS.is_debug_build(): print("THIEF ", msg)
	if loss > 0:
		spend(loss, "other")
		S.rep = clampf(float(S.rep) - 0.05, 1, 5)
		ui.toast(msg, "bad")
	else:
		ui.toast(msg, "gold")
		add_xp(10)


## Pemain mengetuk maling: berteriak "MALING!", maling kabur tanpa hasil.
func _thief_tap(p: Vector2) -> bool:
	if thief == null or not is_instance_valid(thief) or _thief_state in ["flee", ""]: return false
	var fp := thief.global_position
	if absf(p.x - fp.x) > 130 or p.y > fp.y + 30 or p.y < fp.y - 400: return false
	# Kaget, angkat tangan sebentar, lalu kabur.
	_thief_state = "flee"
	thief.work = {"t": 1.2, "pose": "caught"}
	thief.route = []
	thief.say("Ampun! Ampun!", 1.6)
	var th := thief
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(th) and thief == th: _thief_flee("Kabur!"))
	for n in npcs.values():
		if n.kind == "res" and n.scene == "lobby":
			n.say("Maling! Maling!", 2.0)
			break
	_thief_end("Kamu berteriak \"MALING!\" dan maling kabur tanpa hasil!", 0.0)
	return true


# ================= Preman pungli =================
# Siang hari (mulai Level 3) preman datang ke lobi minta "uang keamanan".
var preman: Npc = null
var _preman_wait := 0.0


func preman_amount() -> float:
	return roundf(100000.0 * (1.0 + 0.25 * int(S.lvl)) * pow(1.3, mini(int(S.get("preman_paid", 0)), 4)) / 5000.0) * 5000.0


func _maybe_preman(h: int) -> void:
	if preman != null or h < 10 or h > 16 or int(S.lvl) < 3: return
	if int(S.day) < int(S.get("preman_next", 0)): return
	if randf() > 0.12: return
	spawn_preman()


func spawn_preman() -> void:
	if preman != null: return
	if wa: wa.post("Penghuni ", "Ada preman minta-minta duit di depan. Hati-hati semua!", "alert")
	cat_startle()
	var n := Npc.new()
	npc_lobby.add_child(n)
	n.setup("preman", "preman", D.STAFF_LOOK.teknisi, Vector2(D.OUT_X, D.LOBBY_Y), font)
	n.art = true
	n.char_id = "preman"
	n.art_map = {"walk": "walk", "stand": "idle", "demand": "demand", "count": "count", "happy": "happy", "caught": "caught"}
	npcs["preman"] = n
	preman = n
	pengacau_seen("preman")
	_preman_wait = 0.0
	n.plan("lobby", Vector2(880, D.LOBBY_Y), "stand", func(m: Npc):
		m.work = {"t": 9999.0, "pose": "demand"}
		m.say("Bos! Uang keamanan dulu dong, %s!" % D.short(preman_amount()), 4.0)
		keeper_say("Waduh... ada preman minta jatah.", 4.0)
		ui.toast("Preman minta pungli %s! Ketuk premannya untuk menanggapi." % D.rp(preman_amount()), "bad"))


func _preman_tick(dt: float) -> void:
	if preman == null: return
	if not is_instance_valid(preman):
		preman = null
		return
	if preman.work.get("pose", "") != "demand": return
	_preman_wait += dt * maxf(1.0, float(int(S.speed)))
	if fmod(_preman_wait, 9.0) < dt * maxf(1.0, float(int(S.speed))):
		preman.say(["Mana, Bos? Saya nunggu nih.", "Biar aman, Bos. Ngerti kan?", "Cepetan, Bos!"].pick_random(), 3.0)
	if _preman_wait > 60.0:
		preman_answer("ignore")


func _preman_tap(p: Vector2) -> bool:
	if preman == null or not is_instance_valid(preman) or preman.work.get("pose", "") != "demand": return false
	var fp := preman.global_position
	if absf(p.x - fp.x) > 140 or p.y > fp.y + 30 or p.y < fp.y - 400: return false
	ui.open_sheet("preman")
	return true


func _preman_leave(pose: String, secs: float, run: bool = false) -> void:
	var n := preman
	n.work = {"t": secs, "pose": pose, "fn": func(m: Npc):
		if run: m.art_map["walk"] = "run"
		m.set_meta("spd", 2.0 if run else 1.0)
		m.plan("lobby", Vector2(D.OUT_X - 200, D.LOBBY_Y), "stand", func(z: Npc):
			_remove_npc(z)
			preman = null)}


func preman_answer(how: String) -> void:
	if preman == null or not is_instance_valid(preman): return
	ui.close_sheet()
	var amt := preman_amount()
	match how:
		"pay":
			if float(S.money) < amt:
				ui.toast("Uang belum cukup", "bad"); return
			spend(amt, "other")
			S.preman_paid = int(S.get("preman_paid", 0)) + 1
			S.preman_next = int(S.day) + 2
			preman.say("Mantap, Bos! Aman deh kost-nya.", 3.0)
			ui.toast("Kamu membayar %s. Preman akan datang lagi, makin sering & makin mahal." % D.rp(amt), "bad")
			_preman_leave("count", 3.0)
		"police":
			if out_lv("polisi") >= 1:
				_police_come("preman")
				ui.close_sheet()
				return
			if float(S.money) < 50000:
				ui.toast("Uang belum cukup", "bad"); return
			spend(50000, "other")
			S.preman_next = int(S.day) + 10
			S.preman_paid = 0
			preman.say("Ampun, Pak! Saya cuma bercanda!", 3.0)
			S.rep = clampf(float(S.rep) + 0.05, 1, 5)
			add_xp(15)
			ui.toast("Polisi datang menangkap preman. Lingkungan kost aman lagi!", "gold")
			_preman_leave("caught", 3.5, true)
		_:
			var guard: Npc = npcs.get("staff-satpam")
			if guard != null and is_instance_valid(guard) and guard.scene == "lobby":
				guard.work = {}
				guard.plan("lobby", Vector2(preman.position.x - 120, D.LOBBY_Y), "stand", func(m: Npc):
					m.say("Pergi! Di sini nggak ada pungli!", 3.0))
				preman.say("Iya, iya... saya pergi.", 2.5)
				S.preman_next = int(S.day) + 5
				add_xp(10)
				ui.toast("John mengusir preman. Kost aman!", "gold")
				_preman_leave("angry", 2.5, true)
			else:
				preman.say("Awas ya, Bos! Nyesel nanti!", 3.0)
				for e in each_tenant():
					e[1].tenant.happy = clampf(float(e[1].tenant.happy) - 6.0, 0, 100)
				S.rep = clampf(float(S.rep) - 0.05, 1, 5)
				S.preman_next = int(S.day) + 3
				var dmg := ""
				if how == "ignore":
					# Didiamkan: preman merusak barang di salah satu kamar.
					var pool := []
					for id in D.ROOMS:
						if S.rooms[id].built and str(S.rooms[id].broken) == "": pool.append(id)
					if not pool.is_empty():
						var rid: String = pool.pick_random()
						var keys: Array = D.RANDOM_ISSUES
						S.rooms[rid].broken = keys.pick_random()
						dmg =" Dia juga merusak %s di Kamar %s!" % [str(S.rooms[rid].broken), D.room_name(rid)]
						preman.say("Nih, biar tahu rasa!", 3.0)
				ui.toast(("Preman marah & mengancam. Penghuni jadi takut (kebahagiaan turun). Rekrut John (Satpam) atau lapor polisi." if how == "refuse" else "Preman dicuekin, marah-marah & menakuti penghuni.") + dmg, "bad")
				_preman_leave("angry", 2.5)
	dirty = true


# ================= Lantai tanpa batas =================
## Lantai 1-8 terbuka sesuai level. Lantai 9+ butuh level, rating & biaya renovasi.
func floor_open(f: int) -> bool:
	if f > D.TOP_FLOOR or int(S.lvl) < f: return false
	return f <= 8 or f <= int(S.get("open_floor", 8))


func floor_lock_text(f: int) -> String:
	if int(S.lvl) < f: return "Lantai %d terbuka di Level %d" % [f, f]
	return "Lantai %d perlu dibangun dulu (%s, rating %.1f)" % [f, D.rp(D.floor_cost(f)), D.floor_rep(f)]


## Teks papan untuk lahan kosong di lantai terkunci ("" = boleh dibangun).
func floor_lock_sign(f: int) -> String:
	if f <= 8 or floor_open(f): return ""
	if not S.get("renov", {}).is_empty() and int(S.renov.f) == f:
		return "Dibangun\n" + fmt_real(renov_left())
	if int(S.lvl) < f: return ""      # papan "Terkunci Level X" bawaan
	return "Bangun Lantai\n%s" % D.short(D.floor_cost(f))


func renovate_floor(f: int) -> void:
	if f != int(S.get("open_floor", 8)) + 1: return
	if int(S.lvl) < f:
		ui.toast("Lantai %d terbuka di Level %d" % [f, f], "bad"); return
	if float(S.rep) < D.floor_rep(f):
		ui.toast("Rating kost harus minimal %.1f untuk membangun lantai %d" % [D.floor_rep(f), f], "bad"); return
	if float(S.money) < D.floor_cost(f):
		ui.toast("Uang belum cukup (%s)" % D.rp(D.floor_cost(f)), "bad"); return
	if not S.get("renov", {}).is_empty():
		ui.toast("Pembangunan lantai %d masih berjalan." % int(S.renov.f), "bad"); return
	spend(D.floor_cost(f), "other")
	# Renovasi berjalan 3 hari waktu nyata (tetap berjalan walau game ditutup).
	S.renov = {"f": f, "end": Time.get_unix_time_from_system() + RENOV_SECS}
	ui.toast("Bangun lantai %d dimulai: selesai dalam 3 hari waktu nyata (bisa dipercepat pakai Diamond)." % f, "gold")
	sfx("buy")
	dirty = true


const RENOV_SECS := 72 * 3600   # renovasi lantai: 3 hari waktu nyata
const GAME_MIN_PER_SEC := 20.0   # 1x: 20 menit game per detik nyata


func renov_left() -> float:
	if S.get("renov", {}).is_empty(): return 0.0
	return maxf(0.0, float(S.renov.end) - Time.get_unix_time_from_system())


## "23j 10m" waktu nyata.
func fmt_real(secs: float) -> String:
	var h := int(secs) / 3600
	var m := (int(secs) % 3600) / 60
	return ("%dj %02dm" % [h, m]) if h > 0 else ("%dm %02ds" % [m, int(secs) % 60])


## Biaya Diamond untuk mempercepat renovasi lantai.
func renov_speed_cost() -> int:
	return maxi(1, ceili(renov_left() / 7200.0))   # 1 Diamond / 2 jam nyata (maks. 36)


func renov_speedup() -> void:
	var c := renov_speed_cost()
	if int(W.diamonds) < c:
		ui.toast("Diamond tidak cukup (butuh %d). Beli di Toko." % c, "bad")
		ui.open_sheet("toko")
		return
	W.diamonds = int(W.diamonds) - c
	save_wallet()
	S.renov.end = Time.get_unix_time_from_system()
	_check_renov()


func _check_renov() -> void:
	if S.get("renov", {}).is_empty() or renov_left() > 0.0: return
	var f := int(S.renov.f)
	S.renov = {}
	S.open_floor = f
	add_xp(50)
	ui.toast("Lantai %d selesai dibangun! Kamarnya siap diisi." % f, "gold")
	sfx("upgrade")
	# Tambah satu lantai terkunci di atasnya lalu muat ulang gedung.
	save_game()
	save_wallet()
	get_tree().reload_current_scene()


## Percepat pembangunan kamar / ruang fasilitas: 1 Diamond per 2 jam game sisa.
func job_speed_cost(j: Dictionary) -> int:
	if j.has("end"): return maxi(1, ceili(job_left_real(j) / 7200.0))   # 1 Diamond / 2 jam nyata
	return maxi(1, ceili(float(j.t) / 120.0))


func job_speedup(room: String, type: String) -> void:
	var j := job_for(room, type)
	if j.is_empty(): return
	var c := job_speed_cost(j)
	if int(W.diamonds) < c:
		ui.toast("Diamond tidak cukup (butuh %d). Beli di Toko." % c, "bad")
		ui.open_sheet("toko")
		return
	W.diamonds = int(W.diamonds) - c
	save_wallet()
	_finish_job(j)
	if npcs.has("job-" + str(j.id)):
		_remove_npc(npcs["job-" + str(j.id)])
	sfx("upgrade")
	ui.close_sheet()


## Lantai tertinggi yang ditampilkan: lantai terbuka + 1 lantai berikutnya (masih terkunci).
func wanted_top(s: Dictionary) -> int:
	return maxi(8, int(s.get("open_floor", 8)) + 1)


func jump_to_floor(f: int) -> void:
	var r := D.rect_of("%dS" % clampi(f, 1, D.TOP_FLOOR))
	set_scroll(1200.0 - r.position.y)
	scroll_v = 0.0
	ui.close_sheet()


# ================= Bang Ojol & Kang Galon =================
var ojol: Npc = null
var ojol_for := ""
var _ojol_state := ""
var _ojol_t := 0.0
var galon: Npc = null
const OJOL_NAMES := ["Bang Thoyib", "Bang Thoyib", "Bang Rizal", "Bang Udin", "Bang Fikri", "Bang Tono"]
const FOODS := ["nasi padang", "ayam geprek", "martabak", "bakso", "seblak", "kopi susu", "mie ayam"]


func _maybe_ojol(h: int) -> void:
	if ojol != null or not ((h >= 11 and h <= 13) or (h >= 18 and h <= 20)): return
	# Maksimal satu antaran per jam makan (siang/malam), dan tidak saat masih ada paper bag menumpuk.
	var win := int(S.day) * 2 + (0 if h <= 13 else 1)
	if int(S.get("ojol_win", -1)) == win or not S.get("bags", []).is_empty(): return
	var pool := []
	for e in each_tenant():
		var t: Dictionary = e[1].tenant
		if presence(t) in ["sit", "work"] and npcs.has(t.id): pool.append(t)
	if pool.is_empty() or randf() > [0.2, 0.28, 0.36][out_lv("ojol")]: return
	S.ojol_win = win
	var t: Dictionary = pool.pick_random()
	spawn_ojol(t)


func spawn_ojol(t: Dictionary) -> void:
	var n := Npc.new()
	npc_lobby.add_child(n)
	n.setup("ojol", "visitor", D.STAFF_LOOK.teknisi, Vector2(D.IW + 250, D.LOBBY_Y), font)
	n.art = true
	n.char_id = "ojol"
	n.art_map = {"walk": "ride", "stand": "ride3"}
	n.set_meta("spd", 2.4)
	n.size_mul = 1.3
	n.set_meta("nama", OJOL_NAMES.pick_random())
	npcs["ojol"] = n
	ojol = n
	ojol_for = str(t.id)
	_ojol_state = "come"
	var food: String = FOODS.pick_random()
	n.plan("lobby", Vector2(760, D.LOBBY_Y), "stand", func(m: Npc):
		_ojol_state = "wait"
		_ojol_t = 0.0
		m.dir = -1
		sfx("arrive", -12.0)
		m.say("Paket %s atas nama %s!" % [food, t.name], 3.5)
		var rid := _room_of_tenant(str(t.id))
		var who: Npc = npcs.get(str(t.id))
		if who != null and is_instance_valid(who) and who.scene == "lobby":
			ui.toast("%s mengantar %s untuk %s" % [str(m.get_meta("nama", "Bang Ojol")), food, t.name])
		else:
			# Penghuni di kamar: kantong ditaruh di lobi, seret ke kamar yang benar.
			drop_bag(str(t.id), str(t.name), rid, food)
			m.say("Titip ya, Mbak! Buat %s." % t.name, 3.0)
			_ojol_leave()
		dirty = true)


func _ojol_tick(dt: float) -> void:
	if ojol == null: return
	if not is_instance_valid(ojol):
		ojol = null
		return
	if _ojol_state != "wait": return
	_ojol_t += dt * maxf(1.0, float(int(S.speed)))
	var who: Npc = npcs.get(ojol_for)
	if who != null and is_instance_valid(who) and who.scene == "lobby" and who.route.size() == 0 and absf(who.position.x - ojol.position.x) < 240:
		who.dir = 1
		who.say("Makasih, Bang!", 2.2)
		ojol.say("Sama-sama, bintang 5 ya!", 2.4)
		who.react("happy", 2.0)
		for e in each_tenant():
			if str(e[1].tenant.id) == ojol_for:
				e[1].tenant.happy = clampf(float(e[1].tenant.happy) + [4.0, 6.0, 8.0][out_lv("ojol")], 0, 100)
		_ojol_leave()
	elif _ojol_t > 45.0:
		keeper_say("Saya terima ya, Bang. Nanti saya antar.", 3.0)
		ojol.say("Siap, Mbak!", 2.0)
		_ojol_leave()


func _ojol_leave() -> void:
	_ojol_state = "leave"
	ojol_for = ""
	dirty = true
	var n := ojol
	n.work = {"t": 2.5, "pose": "stand", "fn": func(m: Npc):
		m.plan("lobby", Vector2(D.IW + 300, D.LOBBY_Y), "stand", func(z: Npc):
			_remove_npc(z)
			ojol = null
			_ojol_state = "")}


## Kang Galon mengantar air minum setiap 2 hari pagi.
func _maybe_galon(h: int) -> void:
	# Air galon untuk Kantin: tanpa kiriman galon, Kantin tidak bisa jualan.
	if galon != null or h != 9 or not has_facil("kantin"): return
	if int(S.day) - int(S.get("water_day", -9)) < (1 if out_lv("galon") >= 2 else 2): return
	spawn_galon()


func spawn_galon() -> void:
	var n := Npc.new()
	npc_lobby.add_child(n)
	n.setup("galon", "visitor", D.STAFF_LOOK.teknisi, Vector2(D.OUT_X, D.LOBBY_Y), font)
	n.art = true
	n.char_id = "galon"
	n.art_map = {"walk": "carry", "stand": "hold", "lift": "lift", "happy": "happy"}
	n.set_meta("nama", D.OUTSRC.galon.nama)
	npcs["galon"] = n
	galon = n
	var gal := maxi(2, int(ceil(each_tenant().size() / 3.0)))
	var cost := (20000.0 if out_lv("galon") == 0 else 25000.0) * gal
	var ff := facil_floor("kantin")
	var scene := "S%d" % ff if ff > 0 else "lobby"
	var spot := D.facil_spot(ff) if ff > 0 else Vector2(1000, D.LOBBY_Y)
	n.plan(scene, spot, "stand", func(m: Npc):
		m.say("Galonnya, Bu Sari! Buat kantin ya.", 2.6)
		S.water_day = int(S.day)
		spend(cost, "util")
		ui.toast("Kang Galon mengantar %d galon air untuk Kantin (%s)" % [gal, D.rp(cost)])
		for e in each_tenant():
			e[1].tenant.happy = clampf(float(e[1].tenant.happy) + [1.0, 2.0, 3.0][out_lv("galon")], 0, 100)
		m.work = {"t": 2.2, "pose": "lift", "fn": func(k: Npc):
			k.art_map["walk"] = "walk"
			k.work = {"t": 1.5, "pose": "happy", "fn": func(z: Npc):
				z.plan("lobby", Vector2(D.OUT_X - 200, D.LOBBY_Y), "stand", func(y: Npc):
					_remove_npc(y)
					galon = null)}})


# ================= Ruang fasilitas =================
func has_facil(k: String) -> bool:
	for f in S.facil:
		if S.facil[f] == k: return true
	return false


# ---------- Level fasilitas tambahan ----------
const FACIL_LV_MAX := 3
const FACIL_LV_INC := [1.0, 1.0, 1.6, 2.3]        # pengali pemasukan
const FACIL_LV_CAP := [0, 45, 60, 75]              # peluang penghuni berkunjung (kapasitas)


func facil_lv(f: String) -> int:
	return clampi(int(S.get("flv", {}).get(f, 1)), 1, FACIL_LV_MAX)


func facil_up_cost(f: String) -> float:
	var k: String = S.facil.get(f, "")
	if k == "": return 0.0
	return float(D.FACIL[k].cost) * [0.0, 0.6, 1.2][facil_lv(f)]


func facil_upgrade(f: String) -> void:
	var lv := facil_lv(f)
	if lv >= FACIL_LV_MAX or not S.facil.has(f): return
	var c := facil_up_cost(f)
	if float(S.money) < c:
		ui.toast(ui.money_why(c), "bad"); return
	spend(c, "other")
	if not S.has("flv"): S.flv = {}
	S.flv[f] = lv + 1
	sfx("upgrade")
	add_xp(20)
	ui.toast("%s naik ke Level %d: kapasitas & pemasukan bertambah!" % [D.FACIL[S.facil[f]].n, lv + 1], "gold")
	_refresh_facil()
	dirty = true


## Ganti fasilitas di sisi tangga ini dengan fasilitas lain (bangun ulang, level kembali 1).
func facil_swap(f: String, k: String) -> void:
	var old: String = S.facil.get(f, "")
	if old == "" or old == k: return
	var bw := branch_why(k)
	if bw != "":
		ui.toast(bw, "bad"); return
	var fc: Dictionary = D.FACIL[k]
	if int(S.lvl) < int(fc.lv):
		ui.toast("%s terbuka di Level %d" % [fc.n, int(fc.lv)], "bad"); return
	var cost := facil_cost(k)
	if float(S.money) < cost:
		ui.toast(ui.money_why(cost), "bad"); return
	spend(cost, "other")
	S.facil.erase(f)
	if S.has("flv"): S.flv.erase(f)
	add_job("fbuild", "S%s" % f, k)
	ui.toast("%s dibongkar, %s mulai dibangun." % [D.FACIL[old].n, fc.n])
	_refresh_facil()
	ui.close_sheet()
	dirty = true


## Jumlah cabang fasilitas k (yang sudah jadi + sedang dibangun).
func facil_count(k: String) -> int:
	var n := 0
	for f in S.facil:
		if S.facil[f] == k: n += 1
	for j in S.jobs:
		if j.type == "fbuild" and j.item == k: n += 1
	return n


## Level karyawan yang dibutuhkan untuk cabang ke-n: 1, 3, 6, 10, 15, ...
func branch_need(n: int) -> int:
	return n * (n + 1) / 2


## Harga cabang berikutnya: tiap cabang +50% dari harga dasar.
func facil_cost(k: String) -> float:
	return float(D.FACIL[k].cost) * (1.0 + 0.5 * facil_count(k))


## "" kalau cabang berikutnya boleh dibangun; selain itu alasannya.
func branch_why(k: String) -> String:
	var n := facil_count(k)
	if n == 0: return ""
	var fc: Dictionary = D.FACIL[k]
	var need := branch_need(n + 1)
	if fc.has("staff"):
		var st: String = fc.staff
		if not S.staff.get(st, false) and not staff_strike(st):
			return "Cabang ke-%d butuh %s (rekrut dulu)" % [n + 1, D.STAFF[st].n]
		if staff_lv(st) < need:
			return "Cabang ke-%d butuh %s Lv %d (sekarang Lv %d)" % [n + 1, D.STAFF[st].nama, need, staff_lv(st)]
	elif int(S.lvl) < int(fc.lv) + 3 * n:
		return "Cabang ke-%d terbuka di Level kost %d" % [n + 1, int(fc.lv) + 3 * n]
	return ""


func facil_floor(k: String) -> int:
	for f in S.facil:
		if S.facil[f] == k: return int(f)
	return 0


func _refresh_facil() -> void:
	for f in facil_sp.keys():
		_refresh_facil_floor(f)


func _refresh_facil_floor(f: int) -> void:
	if true:
		if not facil_sp.has(f): return
		var sp: Sprite2D = facil_sp[f]
		var k: String = S.facil.get(str(f), "")
		var j := job_for("S%d" % f, "fbuild")
		if j.is_empty() and k == "":
			sp.visible = false
			_facil_sign(int(f), "")
			return
		var key: String = k if k != "" else str(j.item)
		var tex: Texture2D = load("res://assets/facil/%s.png" % key)
		sp.texture = tex
		var fr := D.facil_draw_rect(int(f))
		sp.position = fr.position
		sp.scale = fr.size / tex.get_size()
		sp.visible = true
		sp.modulate = Color(1, 1, 1, 1) if k != "" else Color(1, 1, 1, 0.35)
		var need := ""
		if k != "" and D.FACIL[k].has("staff"):
			var stk: String = D.FACIL[k].staff
			if not S.staff.get(stk, false):
				need = "Mogok" if staff_strike(stk) else "Butuh\n" + D.STAFF[stk].n
		_facil_sign(int(f), need)


var facil_signs := {}


## Plang di ruang fasilitas, mis. "Butuh Petugas Laundry".
func _facil_sign(f: int, text: String) -> void:
	var pc: PanelContainer = facil_signs.get(f)
	if text == "":
		if pc: pc.visible = false
		return
	if pc == null:
		pc = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("e0533a")
		sb.border_color = Color("5a3d2b")
		sb.set_border_width_all(5)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 4
		sb.content_margin_bottom = 6
		pc.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pc.add_child(l)
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bld.add_child(pc)   # tanpa z_index: tidak menembus panel lobi
		facil_signs[f] = pc
	(pc.get_child(0) as Label).text = text
	pc.visible = true
	pc.reset_size()
	var r := D.facil_draw_rect(f)
	pc.position = Vector2(r.position.x + r.size.x / 2.0 - pc.size.x / 2.0, r.position.y + 40)
	pc.rotation = -0.05


func facil_ok(f: int, k: String) -> String:
	var fc: Dictionary = D.FACIL[k]
	if int(S.lvl) < int(fc.lv): return "%s terbuka di Level %d" % [fc.n, int(fc.lv)]
	if not floor_open(f): return floor_lock_text(f)
	if D.is_hub(f): return "Lantai %d dipakai %s" % [f, D.hub_info(f).n]
	if S.facil.has(str(f)) or job_for("S%d" % f, "fbuild") != {}: return "Sisi tangga lantai %d sudah terpakai" % f
	var bw := branch_why(k)
	if bw != "": return bw
	if float(S.money) < facil_cost(k): return "Uang belum cukup (%s)" % D.rp(facil_cost(k))
	return ""


## Lantai terendah yang sisi tangganya masih kosong & sudah terbuka.
func free_facil_floor() -> int:
	for f in range(1, D.TOP_FLOOR + 1):
		if not floor_open(f) or D.is_hub(f): continue
		if S.facil.has(str(f)) or job_for("S%d" % f, "fbuild") != {}: continue
		return f
	return 0


func stair_at(p: Vector2) -> int:
	if p.y >= D.LOBBY_TOP or p.y < 200: return 0
	var q := to_bld(p)
	for f in range(1, D.TOP_FLOOR + 1):
		if D.facil_rect(f).has_point(q): return f
	return 0


func _facil_daily() -> void:
	var occ := each_tenant().size()
	var inc := 0.0
	var seen := {}
	for f in S.facil:
		var fc: Dictionary = D.FACIL[S.facil[f]]
		var bi: int = int(seen.get(S.facil[f], 0))
		seen[S.facil[f]] = bi + 1
		# Cabang berikutnya berbagi pengunjung: 100%, 70%, 55%, 45%, ...
		var mult := 1.0 if bi == 0 else maxf(0.3, 0.85 - 0.15 * bi)
		if fc.has("staff"):
			var on: bool = S.staff.get(fc.staff, false)
			if S.facil[f] == "laundry": mult = 2.0 if on else 1.0
			else: mult = 1.0 if on else 0.0
			if S.facil[f] == "kantin" and on and int(S.day) - int(S.get("water_day", -9)) > 3:
				mult = 0.0
				ui.toast("Kantin tutup: stok air galon habis. Kang Galon datang besok pagi.", "bad")
		mult *= FACIL_LV_INC[facil_lv(str(f))]
		inc += float(fc.inc) * mult * occ
		if float(fc.inc) * mult * occ > 0:
			_float_world(D.facil_spot(int(f)) + Vector2(0, -260), "+" + D.short(float(fc.inc) * mult * occ), Color("2f7a2a"))
	if has_facil("mushola"): S.rep = clampf(float(S.rep) + 0.01, 1, 5)
	if inc > 0:
		S.money = float(S.money) + inc
		S.today.rent = float(S.today.rent) + inc
		ui.toast("Pemasukan fasilitas: %s" % D.rp(inc), "gold")


func _float_world(p: Vector2, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 46)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 12)
	l.position = p - Vector2(80, 0)
	l.z_index = 30
	bld.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "position:y", p.y - 120, 2.0)
	t.parallel().tween_property(l, "modulate:a", 0.0, 2.0).set_delay(1.0)
	t.tween_callback(l.queue_free)


## Perkiraan pemasukan harian satu fasilitas.
func facil_income(k: String) -> float:
	var fc: Dictionary = D.FACIL[k]
	if float(fc.inc) <= 0: return 0.0
	var mult := 1.0
	if fc.has("staff"):
		var on: bool = S.staff.get(fc.staff, false)
		mult = (2.0 if on else 1.0) if k == "laundry" else (1.0 if on else 0.0)
	mult *= FACIL_LV_INC[facil_lv(str(facil_floor(k)))]
	return float(fc.inc) * mult * each_tenant().size()


func facil_happy() -> int:
	var h := 0
	for f in S.facil: h += int(D.FACIL[S.facil[f]].happy) + (facil_lv(str(f)) - 1)
	return h


# ================= Masalah kost (event) =================
func event_at(room: String) -> Dictionary:
	for e in S.events:
		if e.room == room: return e
	return {}


func kost_events() -> Array:
	return S.events.filter(func(e): return e.room == "")


func _roll_events() -> void:
	var lv := int(S.lvl)
	for k in Ev.DEF:
		var ev: Dictionary = Ev.DEF[k]
		if lv < int(ev.lv) or S.prevent.has(k): continue
		if ev.has("need_fac") and not S.fac.has(ev.need_fac): continue
		var busy := false
		for e in S.events:
			if e.type == k: busy = true
		if busy: continue
		var pmul := 0.4 if (k == "area_kotor" and has_facil("dapur")) else 1.0
		if season: pmul *= season.event_mul(k)
		if k == "telat_bayar" and has_app("kelolapro"): pmul *= 0.3
		var room := ""
		if ev.scope == "room":
			var pool := []
			var ws := []
			var wsum := 0.0
			for id in D.ROOMS:
				var r: Dictionary = S.rooms[id]
				if not r.built or not event_at(id).is_empty(): continue
				if ev.get("need", "") == "tenant" and r.tenant == null: continue
				var w := 1.0
				if r.tenant != null:
					for tk in r.tenant.get("traits", []):
						if D.TRAITS[tk].get("ev", "") == k: w *= float(D.TRAITS[tk].ev_mul)
				pool.append(id)
				ws.append(w)
				wsum += w
			if pool.is_empty() or wsum <= 0.0: continue
			# Sifat penghuni menaikkan (atau menurunkan) peluang masalah ini.
			if randf() > float(ev.p) * pmul * (wsum / pool.size()): continue
			var pick := randf() * wsum
			room = pool[pool.size() - 1]
			for i in range(pool.size()):
				pick -= float(ws[i])
				if pick <= 0.0:
					room = pool[i]
					break
		elif randf() > float(ev.p) * pmul: continue
		var e := {"id": "e%d" % randi(), "type": k, "room": room, "age": 0, "auto": -1}
		S.events.append(e)
		if wa:
			if room != "": wa.complain(room, "event", ev.n.to_lower())
			else:
				var tt: Array = each_tenant()
				if not tt.is_empty(): wa.complain(tt.pick_random()[0], "event", ev.n.to_lower())
		_log_recent(k, room)
		ui.toast("Masalah: %s%s" % [ev.n, (" di Kamar " + D.room_name(room)) if room != "" else ""], "bad")
		dirty = true
		return    # paling banyak satu masalah baru per hari


func _tick_events_hour() -> void:
	for e in S.events.duplicate():
		var ev: Dictionary = Ev.DEF[e.type]
		if ev.scope == "room" and (not S.rooms[e.room].built or (ev.get("need", "") == "tenant" and S.rooms[e.room].tenant == null)):
			S.events.erase(e); continue
		if ev.has("auto") and S.staff.get(ev.auto[0], false):
			if int(e.auto) < 0:
				e.auto = int(ev.auto[1])
			else:
				e.auto = int(e.auto) - 1
				if int(e.auto) <= 0:
					_resolve_event(e, ev.opts[0][2], 0, true)


func _events_daily_penalty() -> void:
	for e in S.events:
		var ev: Dictionary = Ev.DEF[e.type]
		e.age = int(e.age) + 1
		var pen: Dictionary = ev.pen
		var k := (1.0 + 0.3 * int(e.age)) * (0.6 if has_app("kelolapro") else 1.0)
		if pen.has("rep"): S.rep = clampf(float(S.rep) - float(pen.rep) * k, 1, 5)
		if pen.has("money"): spend(float(pen.money), "other")
		for x in each_tenant():
			var id: String = x[0]
			var t: Dictionary = x[1].tenant
			if pen.has("happy") and (e.room == "" or e.room == id):
				t.happy = clampf(float(t.happy) - float(pen.happy) * k, 0, 100)
			if pen.has("happy_others") and e.room != "" and e.room != id:
				t.happy = clampf(float(t.happy) - float(pen.happy_others) * k, 0, 100)
		if pen.has("clean") and e.room != "":
			S.rooms[e.room].clean = clampf(float(S.rooms[e.room].clean) - float(pen.clean), 0, 100)


func _resolve_event(e: Dictionary, action: String, cost: float, by_staff: bool = false) -> void:
	if cost > 0 and float(S.money) < cost:
		ui.toast("Uang belum cukup (%s)" % D.rp(cost), "bad"); return
	if cost > 0: spend(cost, "other")
	elif cost < 0:
		S.money = float(S.money) - cost
		S.today.other = float(S.today.other) + cost
	var ev: Dictionary = Ev.DEF[e.type]
	var r = S.rooms.get(e.room) if e.room != "" else null
	var t = r.tenant if r != null else null
	match action:
		"tagih":
			if t != null:
				var a := rent_of(r)
				S.money = float(S.money) + a; S.today.rent = float(S.today.rent) + a
				t.happy = clampf(float(t.happy) - 4, 0, 100)
		"bujuk":
			if t != null: t.happy = clampf(float(t.happy) + 12, 0, 100)
		"usir":
			if t != null:
				_sad_leave[t.id] = true
				r.tenant = null
		"tegur":
			if t != null: t.happy = clampf(float(t.happy) - 3, 0, 100)
			S.rep = clampf(float(S.rep) + 0.03, 1, 5)
		"izin":
			S.rep = clampf(float(S.rep) - 0.05, 1, 5)
			if t != null: t.happy = clampf(float(t.happy) + 5, 0, 100)
		"prevent":
			S.prevent[e.type] = true
		"fix", "temp":
			pass
	S.events.erase(e)
	add_xp(10)
	var who := "Karyawan menangani: " if by_staff else "Selesai: "
	ui.toast(who + ev.n + (" (tidak akan terulang)" if action == "prevent" else ""), "gold")
	if e.room != "": float_at(e.room, "Beres!", Color("2f7a2a"))
	dirty = true


func _new_day() -> void:
	_staff_daily()
	if season and season.happy_bonus() > 0.0:
		for e0 in each_tenant():
			e0[1].tenant.happy = clampf(float(e0[1].tenant.happy) + season.happy_bonus(), 0, 100)
	if wa: wa.daily()
	if funny: funny.daily()
	_events_daily_penalty()
	_roll_events()
	_facil_daily()
	var occ := each_tenant().size()
	if occ > 0:
		spend(occ * 15000.0, "util")
	var sum_h := 0.0
	var n := 0
	for e in each_tenant():
		var id: String = e[0]
		var r: Dictionary = e[1]
		var t: Dictionary = r.tenant
		var d: float = 2 + int(D.PRICE[int(S.price)].h) + mini(fac_count(), 5) + (2 if S.staff.get("satpam", false) else 0) + facil_happy()
		# Lantai tinggi tanpa lift: capek naik tangga.
		if D.fl(id) > 5 and not S.fac.has("lift"): d -= (0.15 if stair_lv() >= 4 else 0.5) * (D.fl(id) - 5)
		if float(r.clean) < 45: d -= 6
		if float(r.clean) < 20: d -= 10
		if str(r.broken) != "": d -= 10
		if int(r.lv) < int(t.pref): d -= 3
		if int(r.lv) > int(t.pref): d += 1
		# Tetangga satu lantai: berisik / ramah
		for e2 in each_tenant():
			if e2[0] != id and D.fl(str(e2[0])) == D.fl(id):
				d += _trait_sum(e2[1].tenant, "neigh")
		t.happy = clampf(float(t.happy) + d, 0, 100)
		t.stay = int(t.stay) + 1
		if float(t.happy) < 15:
			ui.toast("%s pindah karena tidak betah di Kamar %s" % [t.name, D.room_name(id)], "bad")
			if wa:
				wa.post(t.name, "Maaf, aku nggak betah. Aku pindah aja.", "chat", id)
				wa.sys("%s keluar dari grup" % t.name)
			_sad_leave[t.id] = true
			r.tenant = null
			S.rep = clampf(float(S.rep) - 0.35, 1, 5)
			continue
		if int(t.stay) >= int(t.days):
			if float(t.happy) >= 75 and randf() < 0.55:
				var x := randi_range(7, 20)
				t.days = int(t.days) + x
				ui.toast("%s memperpanjang sewa %d hari!" % [t.name, x], "gold")
				add_xp(15)
			else:
				ui.toast("%s selesai ngekost dengan senang. Terima kasih!" % t.name)
				if wa:
					wa.post(t.name, "Makasih semua & Mbak Maryam, aku pamit ya. Kost ini terbaik!", "chat", id)
					wa.sys("%s keluar dari grup" % t.name)
				r.tenant = null
				S.total.served = int(S.total.served) + 1
				add_xp(40)
				S.rep = clampf(float(S.rep) + (0.18 if has_app("kostterdekat") else 0.1), 1, 5)
				if has_app("kostterdekat"):
					ui.toast("%s memberi ulasan bintang 5 di KostTerdekat!" % t.name, "gold")
				continue
		if has_trait(t, "kabur") and int(t.stay) >= 3 and randf() < 0.08:
			var loss := rent_of(r) * 3.0
			spend(loss, "other")
			ui.toast("%s kabur tanpa melunasi sewa! Rugi %s" % [t.name, D.rp(loss)], "bad")
			r.clean = minf(float(r.clean), 25.0)
			r.tenant = null
			S.rep = clampf(float(S.rep) - 0.1, 1, 5)
			continue
		if has_trait(t, "ktp") and not t.get("ktp_fined", false) and int(t.stay) >= 2 and randf() < 0.5:
			t.ktp_fined = true
			spend(150000.0, "other")
			S.rep = clampf(float(S.rep) - 0.05, 1, 5)
			ui.toast("Pak RT menegur: %s belum lapor identitas. Denda Rp 150.000" % t.name, "bad")
		if float(t.happy) > 88 and randf() < 0.04:
			S.money = float(S.money) + 50000
			S.today.other = float(S.today.other) - 50000
			ui.toast("%s memberi oleh-oleh senilai Rp 50.000" % t.name, "gold")
		sum_h += float(t.happy)
		n += 1
	if n > 0:
		var target := 1.0 + 4.0 * (sum_h / n) / 100.0
		var wt := 0.35 if has_app("kostterdekat") else 0.25
		S.rep = clampf(float(S.rep) * (1.0 - wt) + target * wt, 1, 5)
	var td: Dictionary = S.today
	var net := float(td.rent) - float(td.salary) - float(td.util) - float(td.other)
	S.last = {"day": int(S.day), "rent": td.rent, "salary": td.salary, "util": td.util, "other": td.other, "net": net}
	# Riwayat harian (untuk laporan KelolaPro)
	var hs := 0.0
	var hn := 0
	for e in each_tenant():
		hs += float(e[1].tenant.happy)
		hn += 1
	if not S.has("hist"): S.hist = []
	S.hist.append({"day": int(S.day), "net": net, "rent": td.rent, "cost": float(td.salary) + float(td.util) + float(td.other), "occ": hn, "happy": hs / maxf(1, hn), "rep": float(S.rep)})
	while S.hist.size() > 14: S.hist.pop_front()
	S.today = {"rent": 0.0, "salary": 0.0, "util": 0.0, "other": 0.0}
	S.day = int(S.day) + 1
	S.min = 0
	ui.toast("Laporan Hari %d: bersih %s" % [int(S.last.day), D.rp(net)], "" if net >= 0 else "bad")
	if float(S.money) < 0:
		ui.toast("Saldo minus! Kurangi karyawan atau naikkan harga.", "bad")
	save_game()
	dirty = true


# ================= NPC =================
func _goal_of(w: Dictionary) -> Dictionary:
	if w.kind == "cand":
		if has_facil("tunggu") and (w.p.get("auto", false) or (int(w.slot) >= 1 and waiting_room_on())):
			var ff := facil_floor("tunggu")
			var off := (float(int(w.slot) - 1) - 1.0) * 52.0
			return {"key": "wait%d" % int(w.slot), "scene": "S%d" % ff, "spot": D.facil_spot(ff) + Vector2(off, 0), "pose": "sit"}
		var slot := mini(int(w.slot), 3)
		return {"key": "q%d" % slot, "scene": "lobby", "spot": Vector2(D.QUEUE_X[slot], D.LOBBY_Y), "pose": "stand"}
	var pr := presence(w.p)
	if pr == "away":
		return {"key": "out"}
	if ojol_for == str(w.p.id) and ojol != null and _ojol_state == "wait":
		return {"key": "ojol", "scene": "lobby", "spot": Vector2(ojol.position.x - 150, D.LOBBY_Y), "pose": "stand"}
	var R: String = w.room
	var sp: Dictionary = D.SPOT[R]
	var furn: Dictionary = S.rooms[R].get("furn", {})
	if pr == "sit" or pr == "work":
		var hr := int(S.min) / 60
		for fk in S.facil:
			var fc: Dictionary = D.FACIL[S.facil[fk]]
			if hr in fc.visit and absi(("%s%d" % [w.p.id, hr]).hash()) % 100 < FACIL_LV_CAP[facil_lv(str(fk))]:
				var ff := int(fk)
				var off := float(absi(str(w.p.id).hash()) % 70) - 35.0
				return {"key": "fac|%s|%d" % [fk, hr], "scene": "S%d" % ff, "spot": D.facil_spot(ff) + Vector2(off, 0), "pose": fc.pose}
	if pr == "sleep" and furn.has("kasur"):
		return {"key": R + "|lie", "scene": R, "spot": bed_spot(R), "pose": "lie"}
	if pr == "work":
		return {"key": R + "|work", "scene": R, "spot": sp.desk if (sp.has("desk") and furn.has("meja")) else sp.seat, "pose": "work"}
	return {"key": R + "|sit", "scene": R, "spot": sp.seat, "pose": "sit"}


## Titik berbaring di atas kasur (dihitung dari sprite kasur yang terpasang).
func bed_spot(R: String) -> Vector2:
	var lv := int(S.rooms[R].furn.get("kasur", 1))
	var tex: Texture2D = load(D.furn_tex(R, "kasur", lv))
	var fr := D.furn_rect(R, "kasur", tex.get_size())
	return Vector2(fr.position.x + fr.size.x * 0.5, fr.position.y + fr.size.y * 0.56)


func _apply_goal(n: Npc, g: Dictionary) -> void:
	if g.key == "out":
		_leave(n)
		return
	n.goal_key = g.key
	n.leaving = false
	n.plan(g.scene, g.spot, g.pose)


func _leave(n: Npc) -> void:
	n.goal_key = "out"
	n.leaving = true
	n.target = ""
	var h := _hub_of_npc(n)
	if h > 0:
		# Penghuni lantai atas keluar lewat Lobi Langit di lantainya, bukan turun ke lobi bawah.
		n.plan("S%d" % h, D.hub_spot(h), "stand", func(x: Npc):
			var tw := x.create_tween()
			tw.tween_property(x, "modulate:a", 0.0, 0.5)
			tw.tween_callback(func(): if is_instance_valid(x): _remove_npc(x)))
		return
	n.plan("lobby", Vector2(D.OUT_X, D.LOBBY_Y), "stand", func(x: Npc): _remove_npc(x))


# ================= Lobi Langit (hub tiap 10 lantai) =================
## Lantai hub terdekat di bawah/di lantai f yang sudah terbuka, 0 kalau tidak ada.
func hub_for(f: int) -> int:
	var h := (f / D.HUB_EVERY) * D.HUB_EVERY
	while h >= D.HUB_EVERY:
		if floor_open(h) and h <= D.TOP_FLOOR: return h
		h -= D.HUB_EVERY
	return 0


func _hub_of_npc(n: Npc) -> int:
	if n.kind != "res": return 0
	for e in each_tenant():
		if str(e[1].tenant.id) == str(n.id): return hub_for(D.fl(e[0]))
	return 0


func _remove_npc(n: Npc) -> void:
	npcs.erase(n.id)
	n.queue_free()


func char_of(p: Dictionary) -> String:
	if not p.has("char") or not D.CHARS.has(str(p.char)):
		var pool := []
		for c in D.CHARS:
			if D.CHARS[c] == str(p.get("g", "l")): pool.append(c)
		p.char = pool[absi(str(p.get("id", "")).hash()) % pool.size()]
	return p.char


## Jaga jarak: NPC yang berjalan berhenti kalau ada NPC lain tepat di depannya (lobi & tangga).
func _separate_npcs() -> void:
	var dt := get_process_delta_time()
	var list: Array = []
	for n in npcs.values():
		if is_instance_valid(n) and n.fade_state == "" and (n.visible or n.culled):
			list.append(n)
	# Hitung dulu semua keputusan dari keadaan frame sebelumnya, baru terapkan sekaligus,
	# dan tahan keputusan minimal sebentar (histeresis) supaya tidak berkedip jalan/diam (gedek).
	var want := {}
	for n in list:
		var b := false
		if n.is_moving():
			var d: Vector2 = n.move_dir()
			if d != Vector2.ZERO:
				var gap := 95.0 if n.scene == "lobby" else 48.0
				for o in list:
					if o == n or o.scene != n.scene: continue
					var rel: Vector2 = o.position - n.position
					var ahead := rel.dot(d)
					var side := absf(rel.cross(d))
					if ahead > 0.0 and ahead < gap and side < gap * 0.6:
						if not o.is_moving() or o.move_dir().dot(d) < 0.5: continue
						# yang paling depan tidak pernah ditahan; yang di belakang mengalah
						if o.blocked and str(o.id) > str(n.id): continue
						b = true
						break
		want[n] = b
	for n in list:
		var hold := float(n.get_meta("bhold", 0.0)) - dt
		if want[n] != n.blocked and hold <= 0.0:
			n.blocked = want[n]
			hold = 0.45 if n.blocked else 0.35
		elif not n.is_moving():
			n.blocked = false
		n.set_meta("bhold", hold)


## NPC di lobi digambar di lapisan lobi (tetap), selain itu di dalam gedung (ikut scroll).
func _reparent_npcs() -> void:
	for n in npcs.values():
		if not is_instance_valid(n): continue
		if _npccheck and Engine.get_process_frames() % 30 == 0:
			var badk: bool = (n.get_parent() == npc_layer and n.k > 0.95) or (n.get_parent() == npc_lobby and (n.scene != "lobby" or n.position.y < 1700.0) and n.fade_state == "")
			if badk: print("NPCBAD ", n.id, " kind=", n.kind, " scene=", n.scene, " k=", n.k, " pos=", n.position, " fade=", n.fade_state, " route=", n.route.size(), " r0=", (n.route[0] if n.route.size() > 0 else {}), " goal=", n.goal_key, " tgt=", n.target)
		var want: Node2D = npc_lobby if n.scene == "lobby" else npc_layer
		if n.get_parent() != want:
			n.reparent(want, false)


func _spawn(pid: String, w: Dictionary, start: Vector2 = Vector2(D.OUT_X, D.LOBBY_Y)) -> Npc:
	var p: Dictionary = w.p
	if not p.has("look"):
		p.look = Spr.random_look(str(p.get("g", "l")))
	var n := Npc.new()
	npc_lobby.add_child(n)
	n.setup(pid, w.kind, p.look, start, font)
	n.art = true
	n.gender = str(p.get("g", "l"))
	n.char_id = char_of(p)
	if not p.has("tint"):
		p.tint = absi(str(p.get("id", "")).hash()) % Npc.TINTS.size()
	n.set_tint(int(p.tint))
	npcs[pid] = n
	return n


## Penghuni "tidur" (dormant): sedang di kamar/fasilitas lantai yang tidak terlihat.
## Mereka hanya data (tanpa node NPC) sampai lantainya muncul di layar lagi.
var _dormant := {}


func _scene_floor(sc: String) -> int:
	if sc == "lobby": return 0
	if sc.begins_with("S"): return int(sc.substr(1))
	return D.fl(sc)


func _scene_visible(sc: String, vr: Vector2i) -> bool:
	var f := _scene_floor(sc)
	return f == 0 or (f >= vr.x and f <= vr.y)


func _sync_npcs() -> void:
	var vr := vis_floors()
	var want := {}
	var q: Array = S.queue
	for i in range(q.size()):
		want[q[i].id] = {"kind": "cand", "p": q[i], "slot": i}
	for e in each_tenant():
		want[e[1].tenant.id] = {"kind": "res", "p": e[1].tenant, "room": e[0]}
	for nid in npcs.keys():
		var n: Npc = npcs[nid]
		if n.kind == "staff" or n.kind == "worker" or n.kind == "keeper" or n.kind == "thief" or n.kind == "preman" or n.kind == "visitor":
			continue
		if not want.has(nid):
			n.set_bubble("")
			if n.goal_key != "out":
				if n.kind == "res":
					n.suitcase = true
					if _sad_leave.has(nid) or n.mood != "":
						n.react("sad", 2.6)
					_sad_leave.erase(nid)
				n.mood = ""
				_leave(n)
			continue
		var w: Dictionary = want[nid]
		if n.kind == "cand" and w.kind == "res":
			n.suitcase = true
			n.react("happy", 2.2)
		n.kind = w.kind
		n.mood = _mood_of(w, n.gender)
		var g := _goal_of(w)
		# Sudah sampai tujuan di lantai yang tak terlihat -> jadikan data saja.
		if w.kind == "res" and g.key != "out" and n.goal_key == g.key and n.route.is_empty() \
				and n.fade_state == "" and not _scene_visible(str(g.scene), vr) and n.scene == str(g.scene) \
				and not (drag.get("npc") == n):
			_dormant[nid] = true
			npcs.erase(nid)
			n.queue_free()
			continue
		if n.goal_key != g.key:
			if str(g.key).begins_with("wait") and not str(n.goal_key).begins_with("wait"):
				keeper_say("Silakan tunggu di Ruang Tunggu ya~")
				ui.toast("%s mengarahkan %s ke Ruang Tunggu (waiting list)" % [D.STAFF.resep.nama, w.p.name])
			_apply_goal(n, g)
		_bubble_for(n, w)
	for pid in want:
		if not npcs.has(pid):
			var w: Dictionary = want[pid]
			var g := _goal_of(w)
			if g.key == "out":
				_dormant.erase(pid)
				continue
			if w.kind == "res" and str(g.scene) != "lobby" and not _scene_visible(str(g.scene), vr):
				_dormant[pid] = true   # tetap data sampai lantainya terlihat
				continue
			if _dormant.has(pid) and str(g.scene) != "lobby":
				# Muncul langsung di tempatnya (tanpa berjalan dari lobi).
				_dormant.erase(pid)
				var dn := _spawn(pid, w, g.spot)
				dn.scene = str(g.scene)
				dn.k = Npc.K_ROOM
				dn.reparent(npc_layer, false)
				dn.position = g.spot
				_apply_goal(dn, g)
				_bubble_for(dn, w)
				continue
			_dormant.erase(pid)
			if str(g.key).begins_with("wait"):
				keeper_say("Silakan tunggu di Ruang Tunggu ya~")
				ui.toast("%s mengarahkan %s ke Ruang Tunggu (waiting list)" % [D.STAFF.resep.nama, w.p.name])
			var hh := hub_for(D.fl(str(w.room))) if w.kind == "res" else 0
			var n := _spawn(pid, w, D.hub_spot(hh) if hh > 0 else Vector2(D.OUT_X, D.LOBBY_Y))
			if hh > 0:
				n.scene = "S%d" % hh
				n.k = Npc.K_ROOM
				n.reparent(npc_layer, false)
				n.modulate.a = 0.0
				n.fade_state = "in"
				n.fade_t = 0.0
			_apply_goal(n, g)
			_bubble_for(n, w)

	for did in _dormant.keys():
		if not want.has(did): _dormant.erase(did)

func _mood_of(w: Dictionary, g: String) -> String:
	var p: Dictionary = w.p
	if w.kind == "cand":
		if int(p.wait) >= 36:
			return "annoyed"
		return ""
	var pr := presence(p)
	if pr != "sit" and pr != "work":
		return ""
	var h := float(p.happy)
	if h < 20:
		return "angry"
	if h < 35:
		return "annoyed"
	if pr == "sit" and int(S.min) >= 20 * 60 and str(p.job) != "Mahasiswa" and absi(str(p.id).hash()) % 3 == 0:
		return "tired"
	return ""


func _bubble_for(n: Npc, w: Dictionary) -> void:
	if w.kind == "cand":
		n.set_bubble(str(w.p.name) if n.scene == "lobby" else "", int(w.slot) == 0)
	elif n.scene == "lobby" and n.fade_state == "":
		# Penghuni yang sedang lewat lobi ditandai dengan kamarnya.
		n.set_bubble("Penghuni " + D.room_name(w.room))
	else:
		n.set_bubble("")


# ================= Pekerjaan: bangun, perbaikan, antar perabot =================
func job_for(room: String, type: String, item: String = "") -> Dictionary:
	for j in S.jobs:
		if j.room == room and j.type == type and (item == "" or j.get("item", "") == item):
			return j
	return {}


func _fix_jobbed(r: Dictionary) -> bool:
	for id in D.ROOMS:
		if S.rooms[id] == r:
			return job_for(id, "fix") != {}
	return false


func add_job(type: String, room: String, item: String = "", lv: int = 0) -> void:
	S.jobs.append({"id": "j%d" % randi(), "type": type, "room": room, "item": item, "lv": lv,
		"t": float(D.WORKER["build" if type == "fbuild" else type].mins), "started": type in ["build", "fbuild"]})
	if type in ["build", "fbuild"]:
		S.jobs[-1].t = float(S.jobs[-1].t) / [1.0, 1.6, 2.5][out_lv("tukang")]
	if type == "deliver" and out_lv("kurir") >= 2:
		S.jobs[-1].t = float(S.jobs[-1].t) * 0.5
	# Pekerjaan besar memakai waktu nyata (tetap jalan walau game ditutup):
	# bangun kamar 12 jam, renovasi kamar gosong 3 jam.
	var real := 0.0
	if type == "build": real = BUILD_SECS
	elif type == "fix" and str(S.rooms.get(room, {}).get("broken", "")) == Funny.GOSONG: real = RENO_ROOM_SECS
	if real > 0.0:
		real /= [1.0, 1.6, 2.5][out_lv("tukang")] if type == "build" else 1.0
		S.jobs[-1].end = Time.get_unix_time_from_system() + real
		if ui: ui.toast("%s selesai dalam %s waktu nyata (tetap jalan walau game ditutup)." % ["Pembangunan kamar" if type == "build" else "Renovasi kamar", fmt_real(real)], "gold")
	dirty = true
	_jobs_brain()


const BUILD_SECS := 12 * 3600.0       # bangun kamar: 12 jam waktu nyata
const RENO_ROOM_SECS := 3 * 3600.0    # renovasi kamar gosong: 3 jam waktu nyata


## Sisa detik nyata untuk pekerjaan berbasis waktu nyata (-1 kalau berbasis waktu game).
func job_left_real(j: Dictionary) -> float:
	if not j.has("end"): return -1.0
	return maxf(0.0, float(j.end) - Time.get_unix_time_from_system())


func _tick_jobs(mins: float) -> void:
	_tick_orders(mins)
	_tick_bags(mins)
	_fire_tick(mins)
	for j in S.jobs.duplicate():
		if not j.started:
			continue
		if j.has("end"):
			# waktu nyata: game minute tidak dipakai; tukang tetap "bekerja" sampai jamnya tiba
			if Time.get_unix_time_from_system() >= float(j.end):
				_finish_job(j)
			else:
				j.t = maxf(float(j.t), 30.0)
			continue
		j.t = float(j.t) - mins
		if j.t <= 0.0:
			_finish_job(j)


func _finish_job(j: Dictionary) -> void:
	S.jobs.erase(j)
	var r: Dictionary = S.rooms.get(j.room, {})
	match j.type:
		"build":
			r.built = true
			r.furn = {}
			r.clean = 100.0
			update_tier(r)
			ui.toast("Kamar %s selesai dibangun!" % D.room_name(j.room), "gold")
			add_xp(20)
		"fbuild":
			S.facil[j.room.substr(1)] = j.item
			ui.toast("%s di lantai %s sudah jadi!" % [D.FACIL[j.item].n, j.room.substr(1)], "gold")
			if wa: wa.post("Maryam", "Pengumuman: %s di lantai %s sudah buka! Silakan dipakai ya" % [D.FACIL[j.item].n, j.room.substr(1)], "chat")
			add_xp(40)
		"fix":
			if str(r.broken) != "":
				float_at(j.room, "Diperbaiki", Color("3f6f96"))
			r.broken = ""
		"deliver":
			r.furn[j.item] = int(j.lv)
			update_tier(r)
			sfx("place" if int(j.lv) == 1 else "upgrade")
			var jr: String = j.room
			var ji: String = j.item
			(func(): _refresh_world(); if room_fx.has(jr): room_fx[jr].pop_item(ji)).call_deferred()
			if r.tenant != null:
				r.tenant.happy = clampf(float(r.tenant.happy) + 4.0 * int(j.lv), 0, 100)
			if int(j.lv) == 1:
				float_at(j.room, "+" + D.FURN[j.item].n, Color("2f7a2a"))
				add_xp(8)
			else:
				float_at(j.room,"%s jadi %s!" % [D.FURN[j.item].n, D.FURN_LV_NAME[int(j.lv)]], Color("b07a10"))
				add_xp(12)
	if j.type == "deliver" and npcs.has("courier"):
		var c: Npc = npcs["courier"]
		var q: Array = c.get_meta("queue", [])
		q.erase(str(j.id))
		c.work = {}
		c.react("react", 1.0)
		_courier_next.call_deferred(c)
		dirty = true
		return
	var nid: String = "job-" + str(j.id)
	if npcs.has(nid):
		var n: Npc = npcs[nid]
		n.work = {}
		n.react("react", 1.6)
		if n.char_id == "kurir":
			n.art_map["walk"] = "walk"
		n.target = ""
		_leave_worker(n)
	dirty = true


func _leave_worker(n: Npc) -> void:
	n.goal_key = "out"
	n.leaving = true
	var to_truck: bool = n.char_id == "kurir"
	var x: float = D.TRUCK_X + 120 if to_truck else D.OUT_X
	n.plan("lobby", Vector2(x, D.LOBBY_Y), "stand", func(m: Npc): _remove_npc(m))


const CARGO_MAX := 6
var ORDER_MINS: float:
	get: return [45.0, 30.0, 15.0][out_lv("kurir")]
const BOX_SLOTS := [Vector2(455, 112), Vector2(560, 112), Vector2(665, 112), Vector2(505, 14), Vector2(610, 14), Vector2(560, -84)]


var _truck_act := 0.0      # detik nyata terakhir ada pembelian / bongkar kotak
const TRUCK_IDLE := 120.0


func truck_touch() -> void:
	_truck_act = Time.get_ticks_msec() / 1000.0


## Pickup datang kalau ada kotak/antaran; pergi kalau 2 menit tidak ada pembelian
## (kotak yang belum dibongkar tetap tersimpan dan ikut datang lagi bersama pembelian berikutnya).
func _need_truck() -> bool:
	for j in S.jobs:
		if j.type == "deliver": return true
	for n in npcs.values():
		if n.char_id == "kurir": return true
	if S.cargo.is_empty(): return false
	return Time.get_ticks_msec() / 1000.0 - _truck_act < TRUCK_IDLE


## Gambar kotak pesanan di bak pickup (anak dari sprite truk, di belakang dinding bak).
func _cargo_sync() -> void:
	if not S.has("cargo_to"): S.cargo_to = []
	while S.cargo_to.size() < S.cargo.size(): S.cargo_to.append("")
	while S.cargo_to.size() > S.cargo.size(): S.cargo_to.pop_back()


func _refresh_cargo() -> void:
	_cargo_sync()
	if box_tex == null:
		box_tex = load("res://assets/box.png")
	for b in box_nodes:
		b.queue_free()
	box_nodes = []
	for i in range(S.cargo.size()):
		var b := Sprite2D.new()
		b.texture = box_tex
		b.centered = false
		b.position = BOX_SLOTS[i]
		var ic := Sprite2D.new()
		var t: Texture2D = load("res://assets/furn/icon/%s.png" % S.cargo[i])
		ic.texture = t
		var sc := minf(62.0 / t.get_width(), 52.0 / t.get_height())
		ic.scale = Vector2(sc, sc)
		ic.position = Vector2(60, 70)
		b.add_child(ic)
		truck.add_child(b)
		box_nodes.append(b)


func _box_at(p: Vector2) -> int:
	if truck_state != "parked":
		return -1
	for i in range(box_nodes.size() - 1, -1, -1):
		var b: Sprite2D = box_nodes[i]
		var tl: Vector2 = truck.to_global(b.position)
		var r := Rect2(tl, Vector2(150, 120) * truck.scale)
		if r.grow(10).has_point(p):
			return i
	return -1


func _tick_orders(mins: float) -> void:
	for o in S.orders.duplicate():
		o.t = float(o.t) - mins
		if o.t <= 0.0 and S.cargo.size() < CARGO_MAX:
			S.orders.erase(o)
			S.cargo.append(o.item)
			_cargo_sync()
			S.cargo_to[S.cargo.size() - 1] = str(o.get("room", ""))
			truck_touch()
			ui.toast("%s sudah datang! Seret kotaknya dari pickup ke kamar." % D.FURN[o.item].n, "gold")
			_refresh_cargo()
			if truck_state == "parked":
				_box_bounce(S.cargo.size() - 1)


func _truck_tick(dt: float) -> void:
	var need := _need_truck()
	var park := D.TRUCK_X - 470 * 0.72 * 1.87 * 0.5
	match truck_state:
		"gone":
			if need:
				driver.visible = true
				truck_state = "coming"
				truck.visible = true
				truck.flip_h = false
				truck.position.x = -700
		"coming":
			truck.position.x = move_toward(truck.position.x, park, 900 * dt)
			truck.position.y = D.LOBBY_Y + 45 - 470 * 0.72 + sin(Time.get_ticks_msec() / 60.0) * 1.5
			if truck.position.x >= park - 0.5:
				truck_state = "parked"
				sfx("arrive", -8.0)
				for bi in range(S.cargo.size()): _box_bounce(bi)
				if not S.cargo.is_empty():
					ui.toast("Pickup sudah sampai. Seret kotaknya ke kamar!", "gold")
		"parked":
			truck.position.y = D.LOBBY_Y + 45 - 470 * 0.72
			driver.visible = false   # parkir: kabin kosong
			if not need:
				truck_state = "going"
				driver.visible = true
		"going":
			truck.position.x = move_toward(truck.position.x, -800, 900 * dt)
			if truck.position.x <= -800:
				truck_state = "gone"
				truck.visible = false


## Penjaga kost: satu orang. Sesekali berkeliling sampai tangga (tidak pernah masuk kamar), lalu kembali ke meja.
func _keeper_tick(dt: float) -> void:
	if not S.staff.get("resep", false) or npcs.has("keeper"):
		return
	_keeper_walk -= dt
	if _keeper_walk > 0.0:
		return
	_keeper_walk = randf_range(35.0, 70.0)
	var floors := [1]
	for f in range(2, D.TOP_FLOOR + 1):
		if S.rooms.get("%dL" % f, {}).get("built", false) or S.rooms.get("%dR" % f, {}).get("built", false):
			floors.append(f)
	var f: int = floors.pick_random()
	var n := Npc.new()
	npc_lobby.add_child(n)
	n.setup("keeper", "keeper", D.STAFF_LOOK.resep, Vector2(1150, D.LOBBY_Y), font)
	n.set_meta("nama", D.STAFF.resep.nama)
	n.art = true
	n.char_id = "penjaga"
	n.art_map = {"walk": "walk", "stand": "idle"}
	npcs["keeper"] = n
	n.plan("S%d" % f, Vector2(773 + randf_range(-40, 40), D.FEET[f]), "stand", func(m: Npc):
		m.work = {"t": randf_range(3.0, 6.0), "pose": "stand", "fn": func(k: Npc):
			k.plan("lobby", Vector2(1150, D.LOBBY_Y), "stand", func(z: Npc): _remove_npc(z))})


## Tiap jenis pekerja jalan sendiri-sendiri (tukang, teknisi, kurir tidak saling menunggu).
func _jobs_brain() -> void:
	var busy := {}
	for n in npcs.values():
		if n.kind == "worker":
			busy[str(n.get_meta("wtype", ""))] = true
	for j in S.jobs:
		var wt: String = "build" if j.type == "fbuild" else str(j.type)
		if busy.has(wt) or npcs.has("job-" + str(j.id)):
			continue
		if wt == "deliver":
			if truck_state == "parked" and not j.get("taken", false):
				_send_courier()
				busy[wt] = true
			continue
		var cfg: Dictionary = D.WORKER[wt]
		var n := Npc.new()
		npc_lobby.add_child(n)
		var nid: String = "job-" + str(j.id)
		n.setup(nid, "worker", D.STAFF_LOOK.teknisi, Vector2(D.OUT_X, D.LOBBY_Y), font)
		n.set_meta("nama", cfg.nama)
		n.set_meta("wtype", wt)
		n.art = true
		n.char_id = cfg.char
		n.art_map = cfg.map.duplicate()
		n.target = j.room
		npcs[nid] = n
		busy[wt] = true
		var jj: Dictionary = j
		n.plan(j.room, _spot_in(j.room), "job", func(m: Npc):
			jj.started = true
			m.idle_pose = "job")


var COURIER_LOAD: int:
	get: return [2, 3, 5][out_lv("kurir")]


## Andi mengangkut beberapa kotak sekaligus (maks 3), mampir ke tiap kamar dari lantai bawah ke atas.
func _send_courier() -> void:
	var list := []
	for j in S.jobs:
		if j.type == "deliver" and not j.get("taken", false):
			list.append(j)
			if list.size() >= COURIER_LOAD: break
	if list.is_empty(): return
	list.sort_custom(func(a, b): return D.fl(a.room) < D.fl(b.room))
	var q := []
	for j in list:
		j.taken = true
		q.append(str(j.id))
	var cfg: Dictionary = D.WORKER.deliver
	var n := Npc.new()
	npc_lobby.add_child(n)
	n.setup("courier", "worker", D.STAFF_LOOK.teknisi, Vector2(D.TRUCK_X + 120, D.LOBBY_Y), font)
	n.set_meta("nama", cfg.nama)
	n.set_meta("wtype", "deliver")
	n.set_meta("queue", q)
	n.art = true
	n.char_id = cfg.char
	n.art_map = cfg.map.duplicate()
	npcs["courier"] = n
	if q.size() > 1:
		n.say("Sekalian bawa %d kotak!" % q.size(), 2.5)
	_courier_next(n)


func _job_by_id(id: String) -> Dictionary:
	for j in S.jobs:
		if str(j.id) == id: return j
	return {}


func _courier_next(n: Npc) -> void:
	var q: Array = n.get_meta("queue", [])
	while not q.is_empty() and _job_by_id(q[0]).is_empty():
		q.pop_front()
	if q.is_empty():
		n.art_map["walk"] = "walk"
		n.target = ""
		_leave_worker(n)
		return
	var jj := _job_by_id(q[0])
	n.target = jj.room
	n.plan(jj.room, _spot_in(jj.room), "job", func(m: Npc):
		jj.started = true
		m.idle_pose = "job")


func _staff_brain() -> void:
	_jobs_brain()
	for role in ["cleaner", "satpam", "teknisi", "laundry", "kantin", "barista", "kasir", "trainer", "tani", "lele", "petshop", "florist", "koperasi", "warteg"]:
		var on: bool = S.staff.get(role, false)
		if D.STAFF[role].has("need") and not has_facil(D.STAFF[role].need):
			on = false
		# Satu personil per cabang fasilitas (cabang ke-2 = karyawan ke-2, dst.)
		var crew := 1
		if on and D.STAFF[role].has("need"): crew = maxi(1, _facil_floors(D.STAFF[role].need).size())
		for xi in range(crew, 6):
			var xid := "staff-%s#%d" % [role, xi]
			if npcs.has(xid) and npcs[xid].goal_key != "out": _leave(npcs[xid])
		for ci in range(crew):
			_spawn_staff(role, on, ci)
	_staff_work()


## Jumlah personil karyawan k (satu per cabang fasilitasnya).
func staff_crew(k: String) -> int:
	if not D.STAFF.has(k) or not D.STAFF[k].has("need"): return 1
	return maxi(1, _facil_floors(D.STAFF[k].need).size())


func _facil_floors(k: String) -> Array:
	var out := []
	for f in S.facil:
		if S.facil[f] == k: out.append(int(f))
	out.sort()
	return out


func _spawn_staff(role: String, on: bool, ci: int) -> void:
		var nid: String = "staff-" + role + ("" if ci == 0 else "#%d" % ci)
		if on and not npcs.has(nid) and _clock - _staff_spawn_t < 2.5:
			return
		if on and not npcs.has(nid):
			_staff_spawn_t = _clock
			var n := Npc.new()
			npc_lobby.add_child(n)
			n.setup(nid, "staff", D.STAFF_LOOK[role], Vector2(D.OUT_X, D.LOBBY_Y), font)
			n.art = true
			n.char_id = "penjaga"
			if role == "cleaner":
				n.char_id = "kebersihan"
				n.art_map = {"walk": "walk", "stand": "happy", "sweep": ["sweep", "sweep", "wring"]}
			elif role == "satpam":
				n.char_id = "satpam"
				n.art_map = {"walk": "walk", "stand": ["idle", "inspect", "idle", "help"]}
			elif role == "trainer":
				n.char_id = "trainer"
				n.art_map = {"walk": "walk", "stand": "idle", "counter": ["curl", "idle", "press", "raise", "clip", "hammer", "lift", "happy"]}
			elif role in ["laundry", "kantin", "barista", "kasir", "tani", "lele", "petshop", "florist", "koperasi", "warteg"]:
				n.char_id = role
				n.art_map = {"walk": "walk", "stand": "happy" if role == "laundry" else "idle", "counter": "happy" if role == "laundry" else ["idle", "happy"]}
			elif role == "teknisi":
				n.char_id = "teknisi"
				n.art_map = D.WORKER.fix.map.duplicate()
				n.art_map["fix"] = ["fix", "idle"]
			n.role = role
			n.set_meta("branch", ci)
			n.set_meta("nama", D.STAFF[role].nama if ci == 0 else _crew_name(role, ci))
			npcs[nid] = n
		elif not on and npcs.has(nid) and npcs[nid].goal_key != "out":
			_leave(npcs[nid])


const CREW_NAMES := ["Bang Thoyib", "Bang Jali", "Mas Ucup", "Mbak Sri", "Kang Ujang"]
func _crew_name(role: String, ci: int) -> String:
	return CREW_NAMES[(role.hash() + ci) % CREW_NAMES.size()]


func _staff_work() -> void:
	for n in npcs.values():
		if n.kind != "staff" or n.route.size() > 0 or not n.work.is_empty() or n.leaving or n.fade_state != "":
			continue
		match n.role:
			"cleaner":
				var R := _pick_room(n, func(r): return r.built and float(r.clean) < 75.0, _smart_score(n, func(r): return float(r.clean)))
				if R != "":
					n.target = R
					n.plan(R, _spot_in(R), "sweep", func(x: Npc): x.work = {"t": _work_t(x, 7.0), "pose": "sweep", "fn": func(y: Npc): _finish_clean(y, R)})
				else:
					_idle_staff(n)
			"teknisi":
				var R := _pick_room(n, func(r): return str(r.broken) != "" and not _fix_jobbed(r), _smart_score(n, func(_r): return 0.0))
				if R != "":
					n.target = R
					n.plan(R, _spot_in(R), "fix", func(x: Npc): x.work = {"t": _work_t(x, 5.0), "pose": "fix", "fn": func(y: Npc): _finish_fix(y, R)})
				else:
					_idle_staff(n)
			"laundry", "kantin", "barista", "kasir", "trainer", "tani", "lele", "petshop", "florist", "koperasi", "warteg":
				var fls := _facil_floors(D.STAFF[n.role].need)
				var bi: int = int(n.get_meta("branch", 0))
				var ff: int = fls[bi] if bi < fls.size() else (fls[0] if not fls.is_empty() else 0)
				if ff > 0:
					n.plan("S%d" % ff, D.facil_spot(ff) + Vector2(-24 if ff % 2 == 0 else 24, -4), "counter", func(m: Npc): m.work = {"t": randf_range(20.0, 40.0), "pose": "counter"})
				else:
					_idle_staff(n)
			_:
				_idle_staff(n)


## Tiap karyawan punya titik santai sendiri di lobi, dan tidak berdiri menumpuk dengan orang lain.
const IDLE_X := {"cleaner": [150, 300], "teknisi": [420, 560], "satpam": [640, 900]}


var _staff_spawn_t := -99.0


func _idle_staff(n: Npc) -> void:
	var rg: Array = IDLE_X.get(n.role, [160, 900])
	var x := randf_range(rg[0], rg[1])
	for _i in range(6):
		var clash := false
		for m in npcs.values():
			if m != n and m.scene == "lobby" and absf(m.position.x - x) < 150.0:
				clash = true
				break
		if not clash: break
		x = randf_range(rg[0], rg[1])
	n.plan("lobby", Vector2(x, D.LOBBY_Y), "stand", func(m: Npc): m.work = {"t": randf_range(3.0, 7.0), "pose": "stand"})


## Lantai tempat NPC berada (lobi = 0).
func npc_floor(n: Npc) -> int:
	var sc := str(n.scene)
	if sc == "lobby" or sc == "": return 0
	if sc.begins_with("S"): return int(sc.substr(1))
	return D.fl(sc)


## Karyawan level 1 memilih kamar paling parah; makin tinggi levelnya makin pintar:
## kamar terdekat dari lantainya dulu (lantai sama → atas/bawah terdekat).
func _smart_score(n: Npc, base: Callable) -> Callable:
	var lv := staff_lv(n.role)
	if lv <= 1: return base
	var f := npc_floor(n)
	return func(r: Dictionary, id: String) -> float:
		var d := absf(float(D.fl(id) - f))
		return d * 1000.0 + float(base.call(r)) * 0.01


## Durasi kerja makin singkat seiring level karyawan.
func _work_t(n: Npc, base: float) -> float:
	return base / staff_perf(n.role)


func _pick_room(self_n: Npc, filter: Callable, score: Callable) -> String:
	var claimed := {}
	for m in npcs.values():
		if m != self_n and m.target != "":
			claimed[m.target] = true
	var best := ""
	var bs := INF
	for id in D.ROOMS:
		if S.get("fire", {}).has(id): continue
		var r: Dictionary = S.rooms[id]
		if claimed.has(id) or not filter.call(r):
			continue
		var s: float = score.call(r, id) if score.get_argument_count() == 2 else score.call(r)
		if s < bs:
			bs = s
			best = id
	return best


func _spot_in(R: String) -> Vector2:
	if R.begins_with("S"):
		return D.facil_spot(int(R.substr(1))) + Vector2(randf_range(-40, 40), 0)
	return Vector2(float(D.CX[D.col(R)]) + randf_range(-80, 80), float(D.FEET[D.fl(R)]))


func _finish_clean(n: Npc, R: String) -> void:
	var r: Dictionary = S.rooms[R]
	r.clean = minf(100.0, float(r.clean) + 60.0)
	float_at(R, "Bersih!", Color("3f6f96"))
	n.target = ""
	dirty = true


func _finish_fix(n: Npc, R: String) -> void:
	var r: Dictionary = S.rooms[R]
	if str(r.broken) != "":
		float_at(R, "Diperbaiki", Color("3f6f96"))
		r.broken = ""
	n.target = ""
	dirty = true


# ================= Aksi pemain =================
func act(a: String, arg: String = "") -> void:
	match a:
		"rename":
			var nm := arg.strip_edges().left(22)
			if nm == "": return
			S.kost_name = nm
			_refresh_sign()
			ui.toast("Nama kost diganti: %s" % nm, "gold")
		"tutorial":
			ui.close_sheet()
			ui.tutorial.start(0)
		"intro":
			play_intro()
			return
		"preman":
			preman_answer(arg)
		"waitroom":
			send_to_waiting(arg)
		"collect":
			collect_due(arg)
		"collect_all":
			for id in D.ROOMS: collect_due(id)
		"sfx":
			S.sfx = not S.get("sfx", true)
		"start":
			S.seen = true
			save_game()
			ui.close_sheet()
			return
		"build":
			var c := build_cost()
			if float(S.money) < c: return
			if S.rooms[arg].built or job_for(arg, "build") != {}: return
			spend(c, "other")
			add_job("build", arg)
			ui.toast("%s menuju lahan %s untuk mulai membangun" % [D.worker_label("build"), D.room_name(arg)])
		"place_furn", "upgrade_furn":
			var parts := arg.split("|")
			var rid: String = parts[0]
			var t: String = parts[1]
			var r: Dictionary = S.rooms[rid]
			if not r.built or not D.furn_has(rid, t): return
			var lv := int(r.furn.get(t, 0))
			if lv >= 3: return
			var c: float = float(D.FURN[t].cost) * maxi(1, lv)
			if float(S.money) < c:
				ui.toast("Uang belum cukup (%s)" % D.rp(c), "bad")
				return
			if job_for(rid, "deliver", t) != {}: return
			spend(c, "other")
			add_job("deliver", rid, t, lv + 1)
			ui.toast("Pickup mengantar %s ke Kamar %s" % [D.FURN[t].n, D.room_name(rid)])
		"dekor":
			set_dekor(not dekor)
			return
		"facil_up":
			facil_upgrade(arg)
		"facil_swap":
			var ps := arg.split("|")
			facil_swap(ps[0], ps[1])
		"facil_build":
			var parts2 := arg.split("|")
			var ff := int(parts2[0])
			var why := facil_ok(ff, parts2[1])
			if why != "":
				ui.toast(why, "bad"); return
			var bn := facil_count(parts2[1])
			spend(facil_cost(parts2[1]), "other")
			add_job("fbuild", "S%d" % ff, parts2[1])
			if bn > 0: ui.toast("Cabang ke-%d %s dibangun!" % [bn + 1, D.FACIL[parts2[1]].n], "gold")
			ui.toast("%s mulai membangun %s di lantai %d" % [D.worker_label("build"), D.FACIL[parts2[1]].n, ff])
			if ui.kind == "facil": ui.close_sheet()
		"event":
			var parts := arg.split("|")
			for e in S.events:
				if e.id == parts[0]:
					var o: Array = Ev.DEF[e.type].opts[int(parts[1])]
					_resolve_event(e, o[2], float(o[1]))
					break
		"buy":
			var bp := arg.split("|")
			arg = bp[0]
			var broom: String = bp[1] if bp.size() > 1 else ""
			var f: Dictionary = D.FURN[arg]
			if int(S.lvl) < int(f.min): return
			if S.orders.size() + S.cargo.size() >= CARGO_MAX:
				ui.toast("Pickup sudah penuh. Antar dulu kotak yang ada.", "bad")
				return
			if float(S.money) < float(f.cost):
				ui.toast("Uang belum cukup (%s)" % D.rp(f.cost), "bad")
				return
			spend(f.cost, "other")
			sfx("buy")
			S.orders.append({"item": arg, "t": ORDER_MINS, "room": broom})
			truck_touch()
			ui.toast("%s dipesan. Pickup datang sebentar lagi." % f.n)
		"clean":
			if float(S.money) < 15000: return
			spend(15000, "other")
			S.rooms[arg].clean = 100.0
			float_at(arg, "Kinclong!", Color("3f6f96"))
		"fix":
			var r: Dictionary = S.rooms[arg]
			if str(r.broken) == "": return
			var c: float = D.ISSUES.get(r.broken, 0)
			if float(S.money) < c or job_for(arg, "fix") != {}: return
			spend(c, "other")
			add_job("fix", arg)
			ui.toast("%s dipanggil ke Kamar %s" % [D.worker_label("fix"), D.room_name(arg)])
		"evict":
			if S.rooms[arg].tenant == null: return
			var t: Dictionary = S.rooms[arg].tenant
			_sad_leave[t.id] = true
			S.rooms[arg].tenant = null
			S.rep = clampf(float(S.rep) - 0.3, 1, 5)
			ui.confirm = ""
			ui.toast("%s telah diminta pindah" % t.name, "bad")
		"assign":
			var parts := arg.split("|")
			var r: Dictionary = S.rooms[parts[1]]
			if r.tenant != null or not r.built: return
			if funny and funny.haunted(parts[1]):
				ui.toast("Calon penyewa menolak: \"Kamar itu berhantu! Hiii...\" Periksa jendelanya dulu.", "bad")
				return
			if str(r.get("broken", "")) == Funny.GOSONG:
				ui.toast("Kamar masih gosong kena petir. Renovasi dulu (panggil teknisi).", "bad")
				return
			var idx := -1
			for i in range(S.queue.size()):
				if S.queue[i].id == parts[0]: idx = i
			if idx < 0: return
			var p: Dictionary = S.queue.pop_at(idx)
			p.happy = clampf(float(p.happy) + (8 if int(r.lv) >= int(p.pref) else -10), 0, 100)
			p.wait = 0
			if not r.get("furn", {}).has("kasur"):
				ui.toast("Kamar %s belum punya kasur" % D.room_name(parts[1]), "bad")
				return
			r.tenant = p
			ui.sel = ""
			ui.toast("%s pindah ke Kamar %s!" % [p.name, D.room_name(parts[1])], "gold")
			if wa:
				wa.sys("%s (Kamar %s) bergabung ke grup" % [p.name, D.room_name(parts[1])])
				wa.post(p.name, ["Halo semua, salam kenal!", "Hai, aku penghuni baru. Mohon bantuannya ya!", "Permisi, numpang kenalan"].pick_random(), "chat", parts[1])
			_next_guest_soon()
			if S.staff.get("resep", false):
				_set_keeper("happy", 2.5)
			add_xp(10)
		"screen":
			var sp2 := arg.split("|")
			_screen(sp2[0], sp2[1])
		"reject":
			for i in range(S.queue.size()):
				if S.queue[i].id == arg:
					ui.toast("%s ditolak dengan sopan" % S.queue[i].name)
					S.queue.remove_at(i)
					_next_guest_soon()
					break
		"hire":
			S.staff[arg] = true
			ui.toast("%s mulai bekerja!" % D.staff_label(arg), "gold")
		"staff_up":
			staff_upgrade(arg)
		"out_up":
			out_upgrade(arg)
		"influ_invite":
			if float(S.money) < 750000.0:
				ui.toast(ui.money_why(750000.0), "bad"); return
			if funny.invite_influencer():
				spend(750000.0, "other")
			else:
				ui.toast("Kak Nisa sedang di kost.")
		"fire":
			if D.STAFF[arg].get("owner", false): return
			S.staff.erase(arg)
			if S.has("strike"): S.strike.erase(arg)
			ui.toast("%s diberhentikan" % D.staff_label(arg))
		"app_on":
			var ap: Dictionary = D.APPS[arg]
			if int(S.lvl) < int(ap.lv) or has_app(arg): return
			S.apps[arg] = true
			ui.toast("%s aktif! %s/bulan (± %s/hari)" % [ap.n, D.rp(ap.month), D.rp(roundi(ap.fee))], "gold")
			add_xp(20)
		"app_off":
			S.apps.erase(arg)
			ui.toast("Langganan %s dihentikan" % D.APPS[arg].n)
		"buy_fac":
			var fc: Dictionary = D.FAC[arg]
			if float(S.money) < float(fc.cost) or S.fac.has(arg): return
			spend(fc.cost, "other")
			S.fac[arg] = true
			ui.toast("%s sudah tersedia!" % fc.n, "gold")
			add_xp(30)
		"price":
			S.price = int(arg)
			ui.toast("Harga sewa: %s" % D.PRICE[int(arg)].n)
		"speed":
			set_speed(int(arg))
		"shop":
			shop_buy(arg)
	_sync_npcs()
	_refresh_world()
	ui.update_hud()
	ui.refresh_sheet()
	save_game()


# ================= Input & hold-and-drop =================
## Titik layar -> koordinat gedung (memperhitungkan scroll).
func to_bld(p: Vector2) -> Vector2:
	return p - Vector2(0, scroll)


func max_scroll() -> float:
	return -float(D.BUILDING_TOP)


func set_scroll(v: float) -> void:
	scroll = clampf(v, 0.0, max_scroll())
	bld.position.y = scroll
	ui.set_scroll(scroll)
	if _floor_nodes.size() > 0 and vis_floors() != _vis_last: _cull()


func room_at(p: Vector2) -> String:
	if p.y >= D.LOBBY_TOP or p.y < 200:
		return ""
	var q := to_bld(p)
	for id in D.ROOMS:
		if D.rect_of(id).has_point(q):
			return id
	return ""


## Mulai menyeret: kind = "guest" (id calon penyewa) | "furn" (tipe perabot) | "build".
## Pengaman: di HP kadang event "jari diangkat" hilang (gestur browser), sehingga barang yang
## diseret menempel di jari dan game terasa macet. Kalau tidak ada jari/tombol yang menekan
## lagi, akhiri seret di posisi terakhir.
var _drag_free_t := 0.0
var _last_ptr := Vector2.ZERO
var _touching := false


func _drag_watchdog(dt: float) -> void:
	if drag.is_empty():
		_drag_free_t = 0.0
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or _touching:
		_drag_free_t = 0.0
		return
	_drag_free_t += dt
	if _drag_free_t > 0.3:
		_drag_free_t = 0.0
		if drag.get("active", false): _end_drag(_last_ptr)
		else: drag = {}


func begin_drag(kind: String, item: String, start: Vector2, active: bool) -> void:
	_last_ptr = start
	_touching = true
	drag = {"kind": kind, "item": item, "start": start, "active": false}
	if active:
		_activate_drag()


func _box_tag(b: Node2D, text: String) -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_color = D.C_LINE
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", D.C_INK)
	p.add_child(l)
	p.z_index = 60
	lobby_root.add_child(p)
	p.reset_size()
	p.position = truck.to_global(b.position) + Vector2(54 - p.size.x / 2.0, -80)
	var t := p.create_tween()
	t.tween_property(p, "position:y", p.position.y - 40, 1.6)
	t.parallel().tween_property(p, "modulate:a", 0.0, 1.6).set_delay(0.8)
	t.tween_callback(p.queue_free)


## Kotak yang baru tiba melompat kecil di bak pickup.
func _box_bounce(i: int) -> void:
	if i < 0 or i >= box_nodes.size(): return
	var b: Node2D = box_nodes[i]
	var y0 := b.position.y
	var t := create_tween()
	t.tween_property(b, "position:y", y0 - 60, 0.18).set_delay(0.08 * i).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(b, "position:y", y0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)


func _activate_drag() -> void:
	drag.active = true
	if drag.kind == "cargo":
		sfx("pop", -6.0)
		if int(drag.item) < S.cargo.size(): ui.ghost_label(D.FURN[S.cargo[int(drag.item)]].n)
	elif drag.kind == "furn": ui.ghost_label(D.FURN[drag.item].n)
	else: ui.ghost_label("")
	var tex: Texture2D
	var sc := 1.0
	match drag.kind:
		"guest":
			var n: Npc = npcs.get(drag.item)
			if n:
				n.modulate.a = 0.3
				tex = load("res://assets/chars/%s/idle_L.png" % n.char_id)
				ui.ghost.material = n._sp.material
			sc = 0.75
		"furn":
			tex = load("res://assets/furn/icon/%s.png" % drag.item)
			sc = 0.9
		"bag":
			tex = load("res://assets/bag.png")
			sc = 1.1
			var bb := _bag(drag.item)
			if not bb.is_empty(): ui.ghost_label("%s · %s" % [bb.food, bb.name])
		"cargo":
			box_nodes[int(drag.item)].modulate.a = 0.3
			tex = load("res://assets/box.png")
			sc = 0.85
		"build":
			var at := AtlasTexture.new()
			at.atlas = shell_tex
			at.region = D.rect_of("3R")
			tex = at
			sc = 0.45
		"facil":
			tex = load("res://assets/facil/%s.png" % drag.item)
			sc = 0.42
	ui.show_ghost(tex, sc)
	ui.show_hints(_drop_validity())


func _drop_validity() -> Dictionary:
	var out := {}
	if drag.get("kind", "") == "facil":
		for f in range(1, D.TOP_FLOOR + 1):
			out["S%d" % f] = facil_ok(f, drag.item) == ""
		return out
	if drag.get("kind", "") == "guest" and has_facil("tunggu"):
		out["S%d" % facil_floor("tunggu")] = true
	if drag.get("kind", "") == "bag":
		# Paper bag: hanya kamar penerima yang disorot (salah antar tetap bisa, tapi penghuni marah).
		var b := _bag(str(drag.item))
		for id in D.ROOMS: out[id] = id == str(b.get("room", ""))
		if has_lift(): out["LIFT"] = true
		return out
	for id in D.ROOMS:
		out[id] = _drop_ok(id) == ""
	if drag.get("kind", "") == "cargo" and has_lift(): out["LIFT"] = true
	return out


## Kembalikan "" kalau boleh di-drop, atau alasan penolakan.
func _drop_ok(id: String) -> String:
	var r: Dictionary = S.rooms[id]
	match drag.get("kind", ""):
		"guest":
			if not r.built: return "Kamar %s belum dibangun" % D.room_name(id)
			if r.tenant != null: return "Kamar %s sudah ada penghuninya" % D.room_name(id)
			if not r.furn.has("kasur"): return "Kamar %s belum punya kasur. Beli kasur dulu lewat tombol Beli." % D.room_name(id)
			return ""
		"furn", "cargo":
			var t: String = drag.item if drag.kind == "furn" else S.cargo[int(drag.item)]
			if not r.built: return "Bangun kamarnya dulu"
			if job_for(id, "deliver", t) != {}: return "%s untuk Kamar %s sedang diantar" % [D.FURN[t].n, D.room_name(id)]
			if not D.furn_has(id, t): return "Kamar %s tidak punya tempat untuk %s" % [D.room_name(id), D.FURN[t].n]
			if int(r.furn.get(t, 0)) >= 3: return "%s di Kamar %s sudah level maksimal" % [D.FURN[t].n, D.room_name(id)]
			if int(S.lvl) < int(D.FURN[t].min): return "%s terbuka di Level %d" % [D.FURN[t].n, int(D.FURN[t].min)]
			return ""
		"bag":
			if not r.built or r.tenant == null: return "Kamar %s kosong, tidak ada yang pesan" % D.room_name(id)
			return ""
		"build":
			if r.built: return "Kamar %s sudah dibangun" % D.room_name(id)
			if job_for(id, "build") != {}: return "Kamar %s sedang dibangun" % D.room_name(id)
			if not floor_open(D.fl(id)): return floor_lock_text(D.fl(id))
			return ""
	return "?"


func _end_drag(p: Vector2) -> void:
	var d := drag
	drag = {}
	ui.hide_ghost()
	ui.ghost.material = null
	ui.show_hints({})
	for id in room_fx:
		room_fx[id].set_preview("")
	_hover_room = ""
	if d.kind == "guest" and npcs.has(d.item):
		npcs[d.item].modulate.a = 1.0
	if d.kind == "cargo" and int(d.item) < box_nodes.size():
		box_nodes[int(d.item)].modulate.a = 1.0
		if not d.active and int(d.item) < S.cargo.size():
			# Ketuk kotak (tanpa diseret): tunjukkan isinya.
			var it: String = S.cargo[int(d.item)]
			var b: Node2D = box_nodes[int(d.item)]
			_box_tag(b, D.FURN[it].n)
			ui.toast("Kotak berisi %s. Tahan & seret ke kamar." % D.FURN[it].n)
			return
	if not d.active and d.kind == "bag":
		var b0 := _bag(d.item)
		if not b0.is_empty():
			ui.toast("Pesanan %s untuk %s (Kamar %s). Tahan & seret ke kamarnya." % [b0.food, b0.name, D.room_name(_room_of_tenant(str(b0.for)))])
		return
	if not d.active:
		if d.kind == "guest":
			ui.open_sheet("tenants")
		elif d.kind == "cargo":
			ui.toast("Tahan & seret kotak %s ke kamar tujuan" % D.FURN[S.cargo[int(d.item)]].n)
		return
	if d.kind == "facil":
		var f := stair_at(p)
		if f == 0: return
		var why2 := facil_ok(f, d.item)
		if why2 != "":
			ui.toast(why2, "bad")
			return
		act("facil_build","%d|%s" % [f, d.item])
		return
	if (d.kind == "cargo" or d.kind == "bag") and lift_at(p):
		lift_send(d)
		return
	var id := room_at(p)
	if id == "" and d.kind == "guest":
		var sg := stair_at(p)
		if sg > 0 and sg == facil_floor("tunggu"):
			send_to_waiting(str(d.item))
		return
	if id == "":
		return
	drag = d
	var why := _drop_ok(id)
	drag = {}
	if why != "":
		ui.toast(why, "bad")
		return
	match d.kind:
		"guest": act("assign","%s|%s" % [d.item, id])
		"furn": act("upgrade_furn" if S.rooms[id].furn.has(d.item) else "place_furn","%s|%s" % [id, d.item])
		"build": act("build", id)
		"bag": deliver_bag(str(d.item), id)
		"cargo":
			var t: String = S.cargo.pop_at(int(d.item))
			_cargo_sync()
			S.cargo_to.pop_at(int(d.item))
			truck_touch()
			var r: Dictionary = S.rooms[id]
			add_job("deliver", id, t, int(r.furn.get(t, 0)) + 1)
			ui.toast("%s mengangkut %s ke Kamar %s" % [D.worker_label("deliver"), D.FURN[t].n, D.room_name(id)])
			_refresh_cargo()
			save_game()


## Di HP, browser kadang mengirim klik mouse tiruan setelah sentuhan. Abaikan event ganda itu
## supaya panel tidak langsung tertutup lagi (layar berkedip gelap) dan tombol tidak tertekan dua kali.
func _is_dup(e: InputEventMouseButton) -> bool:
	var now := Time.get_ticks_msec()
	var prev = _last_btn.get(e.pressed)
	_last_btn[e.pressed] = [now, e.position]
	return prev != null and now - int(prev[0]) < 450 and e.position.distance_to(prev[1]) < 60.0


func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and music and not music.playing and S.get("music", true):
		music.play()
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and _is_dup(e):
		get_viewport().set_input_as_handled()
		return
	var p := get_global_mouse_position()
	if e is InputEventScreenTouch and e.index == 0:
		_touching = e.pressed
		if not e.pressed and not drag.is_empty():
			# Jari diangkat: akhiri seret walau event mouse tiruan tidak datang.
			_end_drag(drag.get("last", p) if drag.get("active", false) else p)
			get_viewport().set_input_as_handled()
			return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_touching = e.pressed
	if e is InputEventMouseMotion or e is InputEventScreenDrag: _last_ptr = p
	if not _lswipe.is_empty():
		if e is InputEventMouseMotion and not _lswipe.done:
			var d: Vector2 = p - _lswipe.start
			if absf(d.x) > 170.0 and absf(d.x) > absf(d.y) * 2.0:
				_lswipe.done = true
				_try_side(-1 if d.x < 0 else 1)
		elif e is InputEventMouseButton and not e.pressed:
			if not _lswipe.done and D.GROUND_RECT.has_point(_lswipe.start) and (p - _lswipe.start).length() < 30:
				ui.open_sheet("tenants")
			_lswipe = {}
	if not pan.is_empty():
		if e is InputEventMouseMotion:
			var dy: float = p.y - pan.last
			pan.last = p.y
			if absf(p.y - pan.start.y) > 18.0:
				pan.moved = true
			if pan.moved:
				set_scroll(scroll + dy)
				scroll_v = dy / maxf(get_process_delta_time(), 0.001)
			get_viewport().set_input_as_handled()
		elif e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if not pan.moved and not place.is_empty():
				scroll_v = 0.0
				_place_at(pan.start)
				pan = {}
				get_viewport().set_input_as_handled()
				return
			if not pan.moved:
				scroll_v = 0.0
				var id := room_at(pan.start)
				if id != "" and room_fx.has(id) and room_fx[id].coin_hit(room_fx[id].get_global_transform().affine_inverse() * pan.start):
					collect_due(id)
				elif id != "":
					ui.open_sheet("room", id)
				else:
					var sf := stair_at(pan.start)
					if sf > 0 and floor_open(sf):
						ui.open_sheet("facil", str(sf))
			pan = {}
			get_viewport().set_input_as_handled()
		return
	if drag.is_empty():
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and drag.get("active", false):
		# Seret sebelumnya tidak pernah "dilepas" (event hilang): ketukan baru menjatuhkannya.
		_end_drag(drag.get("last", p))
		get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseMotion:
		if not drag.active and p.distance_to(drag.start) > 18.0:
			_activate_drag()
		if drag.active:
			drag.last = p
			ui.move_ghost(p)
			var id := room_at(p)
			if drag.kind == "facil" or (drag.kind == "guest" and id == ""):
				var sf := stair_at(p)
				id = "S%d" % sf if sf > 0 else ""
			if id != _hover_room:
				for rid in room_fx:
					room_fx[rid].set_preview("")
				_hover_room = id
				if id != "" and room_fx.has(id) and not id.begins_with("S") and (drag.kind == "furn" or drag.kind == "cargo") and _drop_ok(id) == "":
					room_fx[id].set_preview(drag.item if drag.kind == "furn" else S.cargo[int(drag.item)])
			ui.hover_hint(id)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_end_drag(p)
		get_viewport().set_input_as_handled()


# ---------- Mode pilih lokasi (kamar baru / ruang fasilitas) ----------
var place := {}


func start_place(kind: String, item: String) -> void:
	ui.close_sheet()
	place = {"kind": kind, "item": item}
	drag = {"kind": kind, "item": item}
	var valid := _drop_validity()
	drag = {}
	var any := false
	for k in valid:
		if valid[k]: any = true
	if not any:
		place = {}
		ui.toast("Belum ada tempat yang bisa dipakai.", "bad")
		return
	ui.show_hints(valid)
	ui.toast("Ketuk tempat yang bertanda hijau. Ketuk di luar gedung untuk batal.", "gold")


func cancel_place() -> void:
	if place.is_empty(): return
	place = {}
	ui.show_hints({})


func _place_at(p: Vector2) -> void:
	var pl := place
	cancel_place()
	if pl.kind == "facil":
		var f := stair_at(p)
		if f == 0:
			ui.toast("Batal memilih lokasi."); return
		var why := facil_ok(f, pl.item)
		if why != "":
			ui.toast(why, "bad"); return
		act("facil_build","%d|%s" % [f, pl.item])
		return
	var id := room_at(p)
	if id == "":
		ui.toast("Batal memilih lokasi."); return
	drag = {"kind": "build", "item": ""}
	var why2 := _drop_ok(id)
	drag = {}
	if why2 != "":
		ui.toast(why2, "bad"); return
	act("build", id)


func set_dekor(on: bool) -> void:
	dekor = on
	ui.close_tray()
	if on:
		ui.open_sheet("beli")
	elif ui.kind == "beli":
		ui.close_sheet()
	_refresh_world()


func _guest_at(p: Vector2) -> String:
	var best := ""
	var bd := 1e9
	for n in npcs.values():
		if n.kind != "cand" or n.scene != "lobby" or n.fade_state != "":
			continue
		var r := Rect2(n.position.x - 75, n.position.y - 390, 150, 395)
		if r.has_point(p):
			var d: float = absf(p.x - n.position.x)
			if d < bd:
				bd = d
				best = n.id
	return best


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		set_scroll(scroll + (120.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -120.0))
		scroll_v = 0.0
		return
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if not place.is_empty() and (p.y >= D.LOBBY_TOP or p.y < 200):
		cancel_place()
		ui.toast("Batal memilih lokasi.")
	if D.PILL_CLOCK.has_point(p):
		set_speed([1, 2, 0][clampi(int(S.speed), 0, 2)])
		return
	if D.PILL_MONEY.has_point(p):
		ui.open_sheet("manage")
		return
	if D.PILL_LV.has_point(p):
		ui.toast("Level %d · XP %d/%d" % [int(S.lvl), int(S.xp), int(xp_need(int(S.lvl)))])
		return
	for nv in D.NAV:
		if nv[1].has_point(p):
			if nv[0] == "upgrade":
				cancel_place()
				ui.open_sheet("beli")
			else:
				ui.open_sheet(nv[0])
			return
	if (funny and funny.game and funny.tap(p)) or _preman_tap(p) or _thief_tap(p) or fire_tap(room_at(p)):
		get_viewport().set_input_as_handled()
		return
	var bgid := _bag_at(p)
	if bgid != "":
		begin_drag("bag", bgid, p, false)
		get_viewport().set_input_as_handled()
		return
	var bi := _box_at(p)
	if bi >= 0:
		begin_drag("cargo", str(bi), p, false)
		get_viewport().set_input_as_handled()
		return
	var g := _guest_at(p)
	if g != "":
		begin_drag("guest", g, p, false)
		get_viewport().set_input_as_handled()
		return
	if p.y < D.LOBBY_TOP and p.y > 200:
		# Gedung: geser untuk scroll, ketuk untuk buka kamar.
		pan = {"start": p, "last": p.y, "moved": false}
		scroll_v = 0.0
		get_viewport().set_input_as_handled()
		return
	if cat_rect().grow(30).has_point(p):
		pet_cat()
		return
	if p.y >= D.LOBBY_TOP and p.y < D.NAV_Y:
		_lswipe = {"start": p, "done": false}


# ---------- Si Mpus: tidur di depan meja; naik ke meja kalau lobi ramai ----------
const CAT_S := 0.25
const CAT_POSES := ["sleep", "eat", "jump", "stretch", "walk", "kaget"]
var cat_tex := {}
var cat_state := "sleep"
var _cat_t := 12.0
var _cat_to := 1000.0
const CAT_X := [780.0, 1240.0]
const CAT_BOWL_X := 1180.0
const CAT_FLOOR := Vector2(1000, 2322)
const CAT_DESK := Vector2(1060, 2130)
var cat_on_desk := false
var _cat_acc := 0.0


func cat_rect() -> Rect2:
	var sz: Vector2 = cat_spr.texture.get_size() * CAT_S
	return Rect2(cat_spr.position - Vector2(sz.x / 2.0, sz.y), sz)


func _cat_pose(k: String) -> void:
	cat_spr.texture = cat_tex[k]
	cat_spr.offset = Vector2(-cat_spr.texture.get_width() / 2.0, -cat_spr.texture.get_height())


## Mpus punya rutinitas: tidur → menggeliat → jalan-jalan → makan → tidur lagi.
func _cat_life(dt: float) -> void:
	if not cat_spr.visible or cat_on_desk and cat_state != "kaget": return
	_cat_t -= dt
	match cat_state:
		"walk":
			var d := signf(_cat_to - cat_spr.position.x)
			cat_spr.flip_h = d > 0
			cat_spr.position.x = move_toward(cat_spr.position.x, _cat_to, 90.0 * dt)
			# langkah kecil: badan naik-turun
			cat_spr.position.y = CAT_FLOOR.y - absf(sin(Time.get_ticks_msec() / 90.0)) * 5.0
			if absf(cat_spr.position.x - _cat_to) < 1.0:
				cat_spr.position.y = CAT_FLOOR.y
				if absf(_cat_to - CAT_BOWL_X) < 2.0:
					_cat_set("eat", randf_range(5.0, 8.0))
				else:
					_cat_set("sleep" if randf() < 0.6 else "stretch", randf_range(15.0, 30.0))
		_:
			if _cat_t > 0.0: return
			match cat_state:
				"sleep":
					_cat_set("stretch", 1.8)
				"stretch", "eat", "kaget":
					if cat_on_desk:
						_cat_set("sleep", 20.0)
						return
					_cat_to = CAT_BOWL_X if randf() < 0.35 and cat_state != "eat" else randf_range(CAT_X[0], CAT_X[1])
					_cat_set("walk", 0.0)


func _cat_set(k: String, secs: float) -> void:
	cat_state = k
	_cat_t = secs
	_cat_pose(k)
	if k == "eat": cat_spr.flip_h = false


## Kucing kaget (maling, preman, kebakaran): bulu berdiri & badan gemetar.
func cat_startle() -> void:
	if cat_spr == null or not cat_spr.visible: return
	_cat_set("kaget", 2.2)
	sfx("meow2", -6.0)
	var t := create_tween()
	for i in range(4):
		t.tween_property(cat_spr, "rotation", 0.08 * (1 if i % 2 == 0 else -1), 0.06)
	t.tween_property(cat_spr, "rotation", 0.0, 0.06)


func _cat_tick(dt: float) -> void:
	_cat_life(dt)
	_cat_acc += dt
	if _cat_acc < 1.0 or not cat_spr.visible: return
	_cat_acc = 0.0
	var crowd := 0
	for n in npcs.values():
		if n.scene == "lobby" and n.kind in ["cand", "res", "visitor", "preman", "thief"]:
			crowd += 1
	if not cat_on_desk and crowd >= 3:
		_cat_jump(true)
	elif cat_on_desk and crowd <= 1:
		_cat_jump(false)


func _cat_jump(up: bool) -> void:
	cat_on_desk = up
	if up: lobby_root.move_child(cat_spr, recep_art.get_index() + 1)
	else: lobby_root.move_child(cat_spr, recep_art.get_index())
	var to: Vector2 = CAT_DESK if up else Vector2(CAT_FLOOR.x, CAT_FLOOR.y)
	var from: Vector2 = cat_spr.position
	_cat_pose("jump")
	cat_spr.flip_h = to.x > from.x
	var t := create_tween()
	t.tween_method(func(k: float):
		cat_spr.position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 90.0), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_property(cat_spr, "scale", Vector2(1.1, 0.88) * CAT_S, 0.08)
	t.tween_property(cat_spr, "scale", Vector2.ONE * CAT_S, 0.12)
	t.tween_callback(func(): _cat_set("sleep" if up else "stretch", 10.0 if up else 1.5))
	if up:
		sfx("meow2", -10.0)


var _lswipe := {}


## Maryam jalan-jalan: hanya kalau dia sedang di meja depan (tidak sedang keliling).
func _try_side(dir: int) -> void:
	if npcs.has("keeper"):
		ui.toast("Maryam sedang keliling kost. Tunggu dia kembali ke meja dulu.")
		return
	if ui.kind != "" or not drag.is_empty() or cutscene_on or int(S.get("tut", -1)) >= 0:
		return
	ui.side.start(dir)


func pet_cat() -> void:
	_cat_pets += 1
	if cat_state == "sleep" and not cat_on_desk: _cat_set("stretch", 1.6)
	sfx(["meow", "meow2", "purr"][_cat_pets % 3], -4.0)
	var t := create_tween()
	t.tween_property(cat_spr, "scale", Vector2(1.12, 0.86) * CAT_S, 0.09)
	t.tween_property(cat_spr, "scale", Vector2(0.94, 1.12) * CAT_S, 0.1)
	t.tween_property(cat_spr, "scale", Vector2.ONE * CAT_S, 0.16).set_trans(Tween.TRANS_BACK)
	for i in range(3):
		# Hati digambar sebagai poligon (font web tidak punya glyph ).
		var h := Polygon2D.new()
		var hp := PackedVector2Array()
		for k in range(24):
			var a := TAU * k / 24.0
			hp.append(Vector2(16.0 * pow(sin(a), 3), -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))) * 1.6)
		h.polygon = hp
		h.color = Color("ff7a8a")
		h.position = cat_spr.position + Vector2(randf_range(-50, 40), -130)
		h.z_index = 45
		lobby_root.add_child(h)
		var ht := h.create_tween()
		ht.tween_property(h, "position:y", h.position.y - 120, 1.0).set_delay(i * 0.12)
		ht.parallel().tween_property(h, "modulate:a", 0.0, 1.0).set_delay(i * 0.12 + 0.3)
		ht.tween_callback(h.queue_free)
	var lines := ["Meong~", "Purrr...", "Meooong!", "Nyaa~"]
	ui.toast("Mpus: " + lines.pick_random())
	# Penghuni di lobi ikut senang melihat kucing.
	if _cat_pets % 5 == 0:
		for n in npcs.values():
			if n.kind == "res" and n.scene == "lobby":
				n.say("Lucunya Mpus!", 2.0)
				n.react("happy", 1.5)
				break


# ================= Mode uji (screenshot dari baris perintah) =================
func _selftest() -> void:
	S.money = 50000000.0
	add_xp(2000)
	for id in D.ROOMS:
		if not S.rooms[id].built:
			act("build", id)
	act("place_furn", "1L|lampu")
	act("upgrade_furn", "1L|kasur")
	act("upgrade_furn", "1L|kasur")
	act("upgrade_furn", "1L|kasur")
	for id in D.ROOMS:
		act("place_furn", id + "|kasur")
	act("dekor")
	act("dekor")
	for k in D.STAFF:
		act("hire", k)
	for k in D.FAC:
		act("buy_fac", k)
	for i in range(4):
		_spawn_cand()
	if S.queue.size() > 0:
		act("reject", S.queue[0].id)
	while S.queue.size() > 0 and empty_rooms().size() > 0:
		act("assign","%s|%s" % [S.queue[0].id, empty_rooms()[0]])
	S.rooms["3L"].broken = "AC rusak"
	act("fix", "3L")
	S.rooms["3R"].clean = 10.0
	act("clean", "3R")
	S.lvl = 8
	act("app_on", "kostterdekat")
	act("app_on", "kelolapro")
	S.next_cand = 0
	if S.queue.is_empty(): _spawn_cand()
	for ck in D.CHECK_ORDER: act("screen","%s|%s" % [S.queue[0].id, ck])
	ui.open_sheet("tenants")
	S.lvl = 8
	var fi := 1
	for k in D.FACIL_ORDER:
		act("facil_build","%d|%s" % [fi, k])
		fi += 1
	for j in S.jobs.duplicate():
		if j.type == "fbuild": _finish_job(j)
	for k in ["laundry", "kantin", "barista"]: act("hire", k)
	_facil_daily()
	ui.open_sheet("facil", "1")
	ui.open_sheet("facil", "8")
	ui.open_sheet("upgrade")
	ui.refresh_sheet()
	_staff_brain()
	for k in Ev.DEF:
		var ex := {"id": "t" + k, "type": k, "room": "" if Ev.DEF[k].scope == "kost" else "1L", "age": 0, "auto": -1}
		S.events.append(ex)
		_events_daily_penalty()
		_tick_events_hour()
		if S.events.has(ex):
			act("event","%s|%d" % [ex.id, Ev.DEF[k].opts.size() - 1])
	for k in ["telat_bayar"]:
		S.events.append({"id": "tz", "type": k, "room": "2L", "age": 0, "auto": -1})
	_collect_rent()
	for i in range(30): _roll_events()
	ui.open_sheet("manage")
	act("price", "2")
	act("price", "0")
	for k in ["room", "tenants", "staff", "upgrade", "manage"]:
		ui.open_sheet(k, "1L")
		ui.tab = "fas" if k == "upgrade" else ui.tab
		ui.refresh_sheet()
	ui.close_sheet()
	act("evict", "1L")
	act("fire", "satpam")
	act("speed", "3")
	print("SELFTEST actions OK. Money=", S.money," lvl=", S.lvl)



func _handle_cli(args: PackedStringArray) -> void:
	var shot := ""
	var wait := 2.0
	for a in args:
		if a.begins_with("--shot="): shot = a.substr(7)
		elif a.begins_with("--wait="): wait = float(a.substr(7))
		elif a.begins_with("--at="):
			var hm := a.substr(5).split(":")
			S.min = int(hm[0]) * 60 + int(hm[1])
		elif a.begins_with("--staff") and not a.begins_with("--stafftab"):
			for k in D.STAFF: S.staff[k] = true
			S.rooms["1L"].clean = 20.0
			S.rooms["2R"].broken = "AC rusak"
		elif a.begins_with("--speed="): S.speed = int(a.substr(8))
		elif a.begins_with("--open="):
			S.seen = true
			ui.close_sheet()
			var parts := a.substr(7).split(",")
			ui.open_sheet(parts[0], parts[1] if parts.size() > 1 else "")
		elif a.begins_with("--scroll="):
			set_scroll.call_deferred(float(a.substr(9)))
		elif a == "--jobs":
			S.seen = true
			ui.close_sheet()
			S.money = 9000000.0
			act("build", "3L")
			S.rooms["2L"].broken = "AC rusak"
			act("fix", "2L")
			act("place_furn", "1R|karpet")
			act("place_furn", "2L|tanaman")
		elif a == "--boxdbg":
			S.cargo = ["kasur", "tanaman"]
			_refresh_cargo()
			truck.visible = true
			truck_state = "coming"
			await get_tree().create_timer(3.0).timeout
			print("truck ", truck.position," ", truck.scale," state ", truck_state)
			for b in box_nodes: print("box ", truck.to_global(b.position))
			for y in range(2100, 2240, 20): print(y," ", _box_at(Vector2(400, y)))
		elif a == "--paint":
			var combos := [{"wall": "biru", "motif": "garis", "floor": "keramik"}, {"wall": "pink", "motif": "polkadot", "floor": "kayu_gelap"},
				{"wall": "mint", "motif": "bata", "floor": "karpet_hijau"}, {"wall": "kuning", "motif": "wajik", "floor": "catur"},
				{"wall": "lavender", "motif": "kotak", "floor": "keramik_abu"}, {"wall": "toska", "motif": "polos", "floor": "kayu_putih"},
				{"wall": "terakota", "motif": "polos", "floor": "asli"}, {"wall": "abu", "motif": "garis", "floor": "karpet_biru"}]
			var i := 0
			for id in D.ROOMS:
				if S.rooms[id].built:
					S.rooms[id].paint = combos[i % combos.size()]
					i += 1
			dirty = true
		elif a == "--allfurn":
			for id in D.ROOMS:
				S.rooms[id].built = true
				S.rooms[id].tenant = null
				for t in D.ITEM_LAYOUT:
					S.rooms[id].furn[t] = 1 + (D.ROOMS.find(id) + D.ITEM_LAYOUT.keys().find(t)) % 3
				update_tier(S.rooms[id])
			S.queue = []
			dirty = true
		elif a == "--lineup":
			S.seen = true
			ui.close_sheet()
			S.speed = 0
			var chars := ["kutu", "kakek", "siswi", "flanel", "nenek", "kupluk"]
			for ci in range(chars.size()):
				for ti in range(Npc.TINTS.size()):
					var n := Npc.new()
					fx_layer.add_child(n)
					n.setup("lu%d_%d" % [ci, ti], "x", D.STAFF_LOOK.resep, Vector2(110 + ti * 170, 560 + ci * 390), font)
					n.art = true
					n.char_id = chars[ci]
					n.k = 2.0
					n.idle_pose = "stand"
					n.set_tint(ti)
					n.tick(0.01)
		elif a == "--events":
			S.lvl = 5
			for k in ["air_mati", "telat_bayar", "atap_bocor"]:
				S.events.append({"id": "x" + k, "type": k, "room": "" if Ev.DEF[k].scope == "kost" else ("1R" if k == "telat_bayar" else "2L"), "age": 1, "auto": -1})
			dirty = true
		elif a.begins_with("--tut="):
			S.seen = true
			ui.close_sheet()
			S.tut = int(a.substr(6))
		elif a.begins_with("--name="):
			S.kost_name = a.substr(7)
		elif a == "--poptest":
			S.seen = true
			ui.close_sheet()
			add_job("deliver", "1L", "tanaman", 1)
			_finish_job(S.jobs[S.jobs.size() - 1])
		elif a == "--desksay":
			S.seen = true
			S.tut = -1
			ui.close_sheet()
			S.staff["resep"] = true
			(func(): keeper_say("Istirahat dulu. Nanti saya bikinin teh hangat.", 30.0)).call_deferred()
		elif a == "--cctv":
			S.fac["cctv"] = true
		elif a == "--guard":
			S.staff["satpam"] = true
		elif a.begins_with("--traytab="):
			S.seen = true
			S.tut = -1
			ui.close_sheet()
			ui.tray_tab = a.substr(10)
			set_dekor.call_deferred(true)
		elif a == "--ojol":
			S.seen = true
			S.tut = -1
			ui.close_sheet()
			(func(): spawn_ojol(each_tenant()[0][1].tenant)).call_deferred()
		elif a == "--galon":
			S.seen = true
			S.tut = -1
			ui.close_sheet()
			spawn_galon.call_deferred()
		elif a.begins_with("--floors="):
			S.seen = true
			S.tut = -1
			ui.close_sheet()
			S.open_floor = int(a.substr(9)) - 1
			S.lvl = int(a.substr(9))
			S.rep = 4.3
			S.money = 30000000.0
			for id in D.ROOMS:
				if D.fl(id) <= int(S.open_floor) and D.fl(id) >= 8:
					S.rooms[id].built = true
					S.rooms[id].furn = {"kasur": 1, "lampu": 2}
			dirty = true
		elif a.begins_with("--buyconf="):
			ui.buy_confirm = a.substr(10)
		elif a == "--place":
			S.seen = true
			S.tut = -1
			S.lvl = 3
			start_place.call_deferred("build", "")
		elif a == "--dragbox":
			S.seen = true
			S.tut = -1
			S.cargo = ["kasur"]
			truck_state = "parked"
			truck.visible = true
			truck.position.x = D.TRUCK_X - 470 * 0.72 * 1.87 * 0.5
			_refresh_cargo()
			(func():
				begin_drag("cargo", "0", Vector2(600, 2200), true)
				ui.move_ghost(Vector2(700, 1500))).call_deferred()
		elif a == "--lift":
			S.seen = true
			S.tut = -1
			ui.close_sheet()
			S.fac["lift"] = true
			S.lvl = 5
			S.facil = {"2": "laundry", "3": "kantin"}
			S.slv = {"cleaner": 1}
			S.tired = {"cleaner": 78.0}
			S.staff["cleaner"] = true
			S.apps = {"kelolapro": true}
			dirty = true
		elif a == "--apps":
			S.seen = true
			S.tut = -1
			ui.close_sheet()
			S.apps = {"kelolapro": true, "kostterdekat": true}
			S.lvl = 3
			S.staff["satpam"] = true
			for id in ["1L", "1R", "2L"]:
				S.rooms[id].furn["kipas"] = [1, 2, 3][["1L", "1R", "2L"].find(id)]
			dirty = true
		elif a == "--truck":
			S.seen = true
			S.tut = -1
			ui.close_sheet()
			S.cargo = ["lampu", "kasur"]
		elif a == "--renovtest":
			S.lvl = 9; S.rep = 5.0; S.money = 99000000.0
			renovate_floor(9)
		elif a.begins_with("--funny="):
			var fk := a.substr(8)
			get_tree().create_timer(0.5).timeout.connect(func(): funny.start(fk))
		elif a.begins_with("--beli="):
			ui.tray_tab = a.get_slice("=", 1)
			ui.open_sheet("beli")
		elif a == "--manage":
			ui.open_sheet("manage")
		elif a.begins_with("--sheetscroll="):
			var sv := int(a.get_slice("=", 1))
			get_tree().create_timer(1.0).timeout.connect(func(): ui.scroll.scroll_vertical = sv)
		elif a.begins_with("--stafftab="):
			ui.staff_tab = a.substr(11)
		elif a == "--sampah":
			S.out = {"sampah": 2}
			get_tree().create_timer(0.5).timeout.connect(spawn_sampah)
		elif a == "--sip":
			get_tree().create_timer(1.5).timeout.connect(func(): ui.side._sip())
		elif a.begins_with("--cat="):
			var cp := a.substr(6)
			get_tree().create_timer(0.3).timeout.connect(func():
				_cat_acc = -100.0
				cat_on_desk = false
				cat_spr.position = CAT_FLOOR
				lobby_root.move_child(cat_spr, recep_art.get_index())
				if cp == "kaget": cat_startle()
				elif cp == "walk": _cat_to = 820.0; _cat_set("walk", 0.0)
				else: _cat_set(cp, 30.0))
		elif a == "--crew":
			S.lvl = 10
			S.facil = {"1": "laundry", "2": "kantin", "3": "laundry", "4": "laundry"}
			S.staff["laundry"] = true; S.staff["kantin"] = true
			if not S.has("slv"): S.slv = {}
			S.slv["laundry"] = 6
			_refresh_world()
		elif a == "--branch":
			# uji cabang: laundry di lantai 1, petugas laundry Lv 3 -> boleh cabang ke-2
			S.lvl = 8
			S.facil = {"1": "laundry"}
			S.staff["laundry"] = true
			if not S.has("slv"): S.slv = {}
			S.slv["laundry"] = 3
			print("BRANCH why2=", branch_why("laundry")," cost=", facil_cost("laundry"))
			S.money = 9000000.0
			print("BRANCH ok2=", facil_ok(2, "laundry"))
			act("facil_build", "2|laundry")
			print("BRANCH count=", facil_count("laundry")," why3=", branch_why("laundry"))
			S.slv["laundry"] = 12
			print("BRANCH perf12=", staff_perf("laundry")," rank=", staff_rank("laundry")," cost13=", staff_up_cost("laundry")," sal=", staff_sal("laundry")," cap=", staff_cap("laundry"))
		elif a == "--tired":
			play_secs = TIRED_SECS - 1.0
		elif a.begins_with("--side="):
			var sv := a.substr(7)
			get_tree().create_timer(0.3).timeout.connect(func():
				ui.side.visible = true
				ui.set_nav_visible(false)
				if sv == "walk": ui.side._walk(-1)
				elif sv == "park": ui.side.loc = "cafe"; ui.side._walk(-1)
				elif sv == "gunung": ui.side.loc = "padel"; ui.side._walk(-1)
				elif sv == "cafe": ui.side._arrive("cafe")
				elif sv == "padelplay": ui.side.loc = "padel"; S.side = {"padel_intro": true, "padel_tut": true}; ui.side._show_padel()
				elif sv == "padelnew": ui.side.loc = "padel"; S.side = {}; ui.side._show_padel()
				elif sv == "cafein": ui.side.loc = "cafe"; ui.side._show_cafe_in()
				else: ui.side.loc = "padel"; ui.side._arrive("padel"))
		elif a.begins_with("--fire"):
			get_tree().create_timer(0.5).timeout.connect(func():
				if a.begins_with("--fire="):
					if not S.has("out"): S.out = {}
					S.out["damkar"] = int(a.split("=")[1])
				var e: Array = each_tenant()
				if not e.is_empty(): start_fire(e[0][0]))
		elif a == "--police":
			get_tree().create_timer(0.5).timeout.connect(func():
				if not S.has("out"): S.out = {}
				S.out["polisi"] = 1
				spawn_preman()
				get_tree().create_timer(4.0).timeout.connect(func(): preman_answer("police")))
		elif a == "--bag":
			get_tree().create_timer(0.4).timeout.connect(func():
				for e in each_tenant():
					drop_bag(str(e[1].tenant.id), str(e[1].tenant.name), e[0], "nasi padang"))
		elif a.begins_with("--stair="):
			S.stair_lv = int(a.substr(8))
			_refresh_stairs()
		elif a == "--liftsend":
			S.fac["lift"] = true
			_refresh_lift()
			S.cargo = ["kasur", "lampu"]
			_refresh_cargo()
			get_tree().create_timer(0.5).timeout.connect(func():
				lift_send({"kind": "cargo", "item": "0"})
				lift_send({"kind": "cargo", "item": "0"}))
		elif a == "--loadinfo":
			print("LOADINFO lvl=", S.lvl," day=", S.day," restored=", restored_from," ver=", S.get("ver"))
		elif a.begins_with("--econsim="):
			S.seen = true
			ui.close_sheet()
			var nd := int(a.substr(10))
			get_tree().create_timer(1.0).timeout.connect(func():
				var es := EconSim.new(self)
				es.run(nd)
				get_tree().quit())
		elif a == "--bagdrag":
			_bagdrag_test.call_deferred()
		elif a == "--ktapp":
			S.apps["kostterdekat"] = true
			S.lvl = 5
			S.kt_filter = {"g": "p", "job": "", "clean": true}
		elif a == "--watest":
			get_tree().create_timer(0.5).timeout.connect(func():
				var tt: Array = each_tenant()
				wa.sys("%s (Kamar %s) bergabung ke grup" % [tt[0][1].tenant.name, D.room_name(tt[0][0])])
				wa.post(tt[0][1].tenant.name, "Halo semua, salam kenal!", "chat", tt[0][0])
				for h in range(6): S.min = 600 + h * 60; wa.hourly(12) if randf() < 2 else null
				var conv: Array = WaGroup.GOSSIP[0]
				wa.post(tt[1][1].tenant.name, conv[0], "chat", tt[1][0])
				wa.post(tt[0][1].tenant.name, conv[1], "chat", tt[0][0])
				wa.complain(tt[1][0], "dirty")
				wa.post("Penghuni", "Ada preman minta-minta duit di depan. Hati-hati semua!", "alert")
				if a == "--watest": ui.update_hud())
		elif a == "--monkey":
			_monkey.call_deferred()
		elif a.begins_with("--stafftab="):
			ui.staff_tab = a.get_slice("=", 1)
			ui.open_sheet("staff")
		elif a == "--hubgal":
			# Galeri debug: kelima Lobi Langit berdampingan.
			var cl := CanvasLayer.new(); cl.layer = 50; add_child(cl)
			var bgc := ColorRect.new(); bgc.color = Color("f3e6cf"); bgc.size = Vector2(D.IW, 2600); cl.add_child(bgc)
			for i in range(5):
				var hn := _HubSign.new()
				hn.f = (i + 1) * 10
				hn.font = font
				hn.info = D.hub_info(hn.f)
				hn.fixed = Rect2(0, 0, 10, 367)
				hn.position = Vector2(0, 40 + i * 470)
				cl.add_child(hn)
		elif a.begins_with("--stress="):
			var nf := int(a.get_slice("=", 1))
			S.seen = true; S.tut = -1; ui.close_sheet()
			S.lvl = maxi(40, nf); S.money = 2000000000.0; S.speed = 2; W.turbo_min = 99999
			S.open_floor = nf - 1
			for k in D.STAFF: S.staff[k] = true
			for k in D.FAC: S.fac[k] = true
			for id in D.ROOMS:
				S.rooms[id].built = true
				S.rooms[id].furn = {"kasur": 2, "lampu": 2, "kipas": 2, "tanaman": 1}
				if S.rooms[id].tenant == null: S.rooms[id].tenant = gen_person(["p", "l"].pick_random())
			S.stair_lv = 4
			save_game()
			_refresh_stairs(); _refresh_lift(); _refresh_world(); _sync_npcs()
			if args.has("--sweep"):
				var sw := Timer.new(); sw.wait_time = 0.15; sw.autostart = true; add_child(sw)
				sw.timeout.connect(func(): set_scroll(randf() * max_scroll() if randf() < 0.2 else scroll + randf_range(-900, 900)))
			var perf_t := Timer.new(); perf_t.wait_time = 4.0; perf_t.autostart = true; add_child(perf_t)
			perf_t.timeout.connect(func():
				var vis := 0
				for n in npcs.values():
					if is_instance_valid(n) and n.visible: vis += 1
				print("PERF top=%d rooms=%d npcs=%d vis=%d nodes=%d fps=%d proc_ms=%.1f mem_mb=%.0f" % [D.TOP_FLOOR, D.ROOMS.size(), npcs.size(), vis,
					Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.TIME_FPS),
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0]))
		elif a == "--big24":
			S.seen = true; S.tut = -1; ui.close_sheet()
			S.lvl = 24; S.money = 200000000.0; S.speed = 2; W.turbo_min = 99999
			S.open_floor = 12
			for k in D.STAFF: S.staff[k] = true
			for k in D.FAC: S.fac[k] = true
			var fi := 1
			for k in D.FACIL_ORDER:
				if fi <= D.TOP_FLOOR: S.facil[str(fi)] = k; fi += 1
			for id in D.ROOMS:
				S.rooms[id].built = true
				S.rooms[id].furn = {"kasur": 2, "lampu": 2, "kipas": 2, "tanaman": 1}
				S.rooms[id].tenant = gen_person(["p", "l"].pick_random())
			S.stair_lv = 4
			_refresh_stairs(); _refresh_lift(); _refresh_world(); _sync_npcs()
			season = Season.new(self); season.start("hujan")
			_probe = true
		elif a == "--codetest":
			var c := export_code()
			var parts := c.split(":")
			var raw := Marshalls.base64_to_raw(parts[2]).decompress(int(parts[1]), FileAccess.COMPRESSION_GZIP)
			var d = JSON.parse_string(raw.get_string_from_utf8())
			print("CODE len=", c.length()," ok=", typeof(d) == TYPE_DICTIONARY and d.S.has("rooms")," lvl=", d.S.lvl)
		elif a == "--newfac":
			S.lvl = 8
			S.facil = {"1": "hidroponik", "2": "lele", "3": "petshop", "4": "bunga", "5": "koperasi", "6": "warteg"}
			for k in ["tani", "lele", "petshop", "florist", "koperasi", "warteg"]: S.staff[k] = true
			_refresh_world()
		elif a == "--hpaint":
			S.hall_paint = {}
			for f in range(1, D.TOP_FLOOR + 1):
				S.hall_paint[str(f)] = [{"wall": "biru", "motif": "garis", "floor": "keramik"}, {"wall": "pink", "motif": "polkadot", "floor": "kayu_gelap"}, {"wall": "mint", "motif": "bata", "floor": "catur"}][f % 3]
			_refresh_hall_paint()
		elif a == "--rich":
			W.diamonds = 500
		elif a == "--stats":
			S.seen = true
			S.tut = -1
			S.apps = {"kelolapro": true}
			S.hist = []
			for i in range(7):
				S.hist.append({"day": i + 1, "net": [120000, 80000, -40000, 150000, 210000, 90000, 260000][i], "rent": 0, "cost": 0, "occ": 3, "happy": 70, "rep": 3.5})
		elif a == "--preman":
			S.seen = true
			S.tut = -1
			ui.close_sheet()
			spawn_preman.call_deferred()
		elif a == "--thief":
			S.seen = true
			S.tut = -1
			ui.close_sheet()
			spawn_thief.call_deferred()
		elif a == "--sad":
			S.seen = true
			S.tut = -1
			ui.close_sheet()
			S.staff["resep"] = true
			for e in each_tenant(): e[1].tenant.happy = 25.0
			dirty = true
		elif a == "--due":
			S.seen = true
			ui.close_sheet()
			S.tut = -1
			for id in ["1L", "2R"]: S.rooms[id].due = 150000.0
			dirty = true
		elif a.begins_with("--tapat="):
			var xy := a.substr(8).split(",")
			_tapat.call_deferred(Vector2(float(xy[0]), float(xy[1])), float(xy[2]) if xy.size() > 2 else 1.5)
		elif a == "--clicktest":
			_clicktest.call_deferred()
		elif a == "--waitlist":
			S.seen = true
			ui.close_sheet()
			S.lvl = 3
			S.staff["resep"] = true
			S.facil["1"] = "tunggu"
			S.queue = []
			for i in range(4):
				S.queue.append(gen_person(["p", "l"][i % 2]))
			dirty = true
		elif a == "--cands":
			S.seen = true
			S.lvl = 3
			S.apps = {"kostterdekat": true}
			S.queue = []
			for i in range(2):
				var p := gen_person(["p", "l"][i])
				p.traits = [["bayar_seret", "perokok", "rapi"], ["tepat", "ramah"]][i]
				if i == 1: p.via = "KostTerdekat"
				S.queue.append(p)
			for ck in D.CHECK_ORDER: _screen(S.queue[0].id, ck)
			S.queue[1].checked["kerja"] = true
			dirty = true
		elif a == "--emptyrooms":
			S.seen = true
			ui.close_sheet()
			S.lvl = 8
			for id in D.ROOMS:
				S.rooms[id].built = true
				S.rooms[id].tenant = null
				S.rooms[id].furn = {}
			S.queue = []
			dirty = true
		elif a == "--facil":
			S.seen = true
			ui.close_sheet()
			S.lvl = 8
			var fi := 1
			for k in D.FACIL_ORDER:
				S.facil[str(fi)] = k
				fi += 1
			for k in ["laundry", "kantin", "barista"]: S.staff[k] = true
			dirty = true
		elif a == "--keeper":
			_keeper_walk = 0.5
		elif a == "--play":
			S.seen = true
			ui.close_sheet()
		elif a == "--moods":
			var i := 0
			for e in each_tenant():
				e[1].tenant.happy = [15.0, 30.0, 90.0][i % 3]
				i += 1
			for q in S.queue:
				q.wait = 9
		elif a == "--selftest":
			S.seen = true
			ui.close_sheet()
			_selftest()
	if shot == "":
		return
	_refresh_world()
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	for n in npcs.values():
		print("NPC ", n.id," ", n.kind," ", n.scene," ", n.pose," ", n.position," route=", n.route.size()," goal=", n.goal_key)
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot)
	get_tree().quit()


# ---------------- Tangga & eskalator ----------------
var stair_nodes: Array = []


func stair_lv() -> int:
	return clampi(int(S.get("stair_lv", 1)), 1, D.STAIRS.size() - 1)


func _refresh_stairs() -> void:
	var lv := stair_lv()
	Npc.stair_mul = float(D.STAIRS[lv].spd)
	Npc.escalator = lv >= 4
	for st in stair_nodes:
		if st == null: continue
		st.lv = lv
		st.queue_redraw()


func stair_upgrade() -> void:
	var lv := stair_lv()
	if lv >= D.STAIRS.size() - 1: return
	var nx: Dictionary = D.STAIRS[lv + 1]
	if int(S.lvl) < int(nx.lv):
		ui.toast("%s terbuka di Level %d" % [nx.n, int(nx.lv)], "bad"); return
	if float(S.money) < float(nx.cost):
		ui.toast(ui.money_why(float(nx.cost)), "bad"); return
	spend(float(nx.cost), "other")
	S.stair_lv = lv + 1
	_refresh_stairs()
	sfx("upgrade")
	add_xp(30)
	ui.toast("Tangga di-upgrade jadi %s! Sewa semua kamar +%d%%." % [nx.n, roundi(float(nx.bonus) * 100.0)], "gold")
	keeper_say("Wah, %s! Nenek pasti bangga." % nx.n, 3.5)
	dirty = true


## Gambar ulang anak tangga sesuai level (1 = gambar asli, 4 = eskalator bergerak).
class _Stairs extends Node2D:
	var variant := 3
	var lv := 1
	var long := 0.0   # lantai Lobi Langit: tangga diperpanjang sampai lantai lobi
	var t := 0.0
	const N := 9
	func _process(dt: float) -> void:
		if lv >= 4:
			t += dt
			queue_redraw()
	func _edges() -> Array:
		# [kiri atas, kanan atas, kanan bawah, kiri bawah] dalam koordinat gambar ruang tangga
		var e: Array
		if variant == 3:
			e = [Vector2(233, 0), Vector2(331, 0), Vector2(357, 277), Vector2(233, 277)]
		else:
			e = [Vector2(57, 0), Vector2(158, 0), Vector2(146, 284), Vector2(27, 284)]
		if long > 0.0:
			var h0: float = e[3].y
			var k2 := (h0 + long) / h0
			e[2] = e[1].lerp(e[2], k2)
			e[3] = e[0].lerp(e[3], k2)
		return e
	func _xs(e: Array, y: float) -> Vector2:
		var k: float = y / float(e[3].y)
		return Vector2(lerpf(e[0].x, e[3].x, k), lerpf(e[1].x, e[2].x, k))
	func _band(e: Array, y0: float, y1: float, col: Color) -> void:
		var a := _xs(e, y0)
		var b := _xs(e, y1)
		draw_colored_polygon(PackedVector2Array([Vector2(a.x, y0), Vector2(a.y, y0), Vector2(b.y, y1), Vector2(b.x, y1)]), col)
	func _draw() -> void:
		if lv <= 1 and long <= 0.0: return
		var e := _edges()
		var h: float = float(e[3].y)
		var ink := Color("3d2a1e")
		if lv < 4:
			var tread := Color("efe9df") if lv == 2 else Color("e9e2d6")
			var riser := Color("cfc4b4")
			if lv <= 1:
				tread = Color("e6cfaa"); riser = Color("c7a57c")
			var sh := h / N
			for i in range(N):
				var y0 := i * sh
				_band(e, y0, y0 + sh * 0.38, tread)
				_band(e, y0 + sh * 0.38, y0 + sh, riser)
				var a := _xs(e, y0 + sh * 0.38)
				draw_line(Vector2(a.x, y0 + sh * 0.38), Vector2(a.y, y0 + sh * 0.38), Color(ink, 0.55), 2.5)
				var c := _xs(e, y0 + sh)
				draw_line(Vector2(c.x, y0 + sh), Vector2(c.y, y0 + sh), ink, 3.0)
			if lv == 3:
				# Karpet merah di tengah + batang kuningan
				for i in range(N):
					var y0 := i * sh
					var m := _xs(e, y0 + sh * 0.5)
					var w := (m.y - m.x) * 0.56
					var cx := (m.x + m.y) * 0.5
					draw_rect(Rect2(cx - w / 2, y0, w, sh), Color("b8433a"))
					draw_rect(Rect2(cx - w / 2, y0 + sh * 0.36, w, sh * 0.1), Color("8f2f29"))
					draw_line(Vector2(cx - w / 2 - 6, y0 + sh - 3), Vector2(cx + w / 2 + 6, y0 + sh - 3), Color("e2b54a"), 4.0)
			draw_polyline(PackedVector2Array([e[0], e[3]]), ink, 4.0)
			draw_polyline(PackedVector2Array([e[1], e[2]]), ink, 4.0)
			return
		# Eskalator: badan baja, anak tangga beralur yang bergerak naik, kaca & pegangan karet.
		_band(e, 0, h, Color("8f959c"))
		var sh2 := h / N
		var off := fmod(t * 34.0, sh2)
		for i in range(-1, N + 1):
			var y0 := i * sh2 - off
			var ya := clampf(y0, 0.0, h)
			var yb := clampf(y0 + sh2 * 0.62, 0.0, h)
			if yb > ya: _band(e, ya, yb, Color("c3c8ce"))
			var yc := clampf(y0 + sh2 * 0.62, 0.0, h)
			var yd := clampf(y0 + sh2, 0.0, h)
			if yd > yc: _band(e, yc, yd, Color("7b8189"))
			for g in range(1, 7):
				var yy := y0 + sh2 * 0.62 * g / 7.0
				if yy > 0 and yy < h:
					var a := _xs(e, yy)
					draw_line(Vector2(a.x + 6, yy), Vector2(a.y - 6, yy), Color("a7adb4"), 1.5)
			var yl := y0 + sh2 * 0.62
			if yl > 0 and yl < h:
				var c := _xs(e, yl)
				draw_line(Vector2(c.x + 4, yl), Vector2(c.y - 4, yl), Color("f2c94c"), 3.0)   # garis kuning tepi
		# Kaca pembatas & pegangan karet hitam di dua sisi
		for side in [[e[0], e[3], 1.0], [e[1], e[2], -1.0]]:
			var p0: Vector2 = side[0]
			var p1: Vector2 = side[1]
			var dx: float = side[2] * 16.0
			draw_colored_polygon(PackedVector2Array([p0, p0 + Vector2(dx, 0), p1 + Vector2(dx, 0), p1]), Color(0.72, 0.88, 0.97, 0.55))
			draw_line(p0, p1, Color("1f2226"), 7.0)
			draw_line(p0 + Vector2(dx, 0), p1 + Vector2(dx, 0), Color(1, 1, 1, 0.6), 2.0)
		# Tapak bawah (landing) logam
		var b := _xs(e, h)
		draw_rect(Rect2(b.x - 4, h - 12, b.y - b.x + 8, 14), Color("b9bec4"))
		draw_line(Vector2(b.x - 4, h - 12), Vector2(b.y + 4, h - 12), Color("3d4148"), 3.0)


## Gelembung bicara sementara di lobi (untuk karakter non-NPC seperti induk beruang).
func npc_say_at(pos: Vector2, text: String, dur: float = 3.0) -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffaf0")
	sb.border_color = D.C_LINE
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(26)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 10
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", D.C_INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 520
	p.add_child(l)
	p.z_index = 46
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby_root.add_child(p)
	p.reset_size()
	p.position = Vector2(clampf(pos.x - p.size.x / 2.0, 20, D.IW - p.size.x - 20), pos.y - p.size.y)
	var t := p.create_tween()
	t.tween_interval(dur)
	t.tween_property(p, "modulate:a", 0.0, 0.4)
	t.tween_callback(p.queue_free)


## Samping kiri gedung: pipa talang dari atap ke tanah, dan unit AC outdoor (kipasnya berputar)
## di tiap lantai yang punya kamar ber-AC (kipas angin level 2 ke atas).
class _SideDecor extends Node2D:
	var game: Node
	var t := 0.0
	const INK := Color("3e2b1d")
	var _rd := 0.0
	func _process(dt: float) -> void:
		t += dt
		_rd += dt
		if _rd > 0.066:   # cukup ~15 fps untuk kipas AC
			_rd = 0.0
			queue_redraw()
	func _has_ac(f: int) -> bool:
		for c in ["L", "R"]:
			var r: Dictionary = game.S.rooms.get("%d%s" % [f, c], {})
			if r.get("built", false) and int(r.get("furn", {}).get("kipas", 0)) >= 2:
				return true
		return false
	func _draw() -> void:
		var top := D.BUILDING_TOP + 200.0
		var bot := D.LOBBY_TOP
		# Pipa talang
		draw_rect(Rect2(70, top, 14, bot - top), Color("98a2ab"))
		draw_rect(Rect2(70, top, 14, bot - top), INK, false, 3.0)
		draw_line(Vector2(74, top), Vector2(74, bot), Color(1, 1, 1, 0.45), 2.0)
		var y := top + 60.0
		while y < bot:
			draw_rect(Rect2(66, y, 22, 10), Color("7d8790"))
			draw_rect(Rect2(66, y, 22, 10), INK, false, 2.0)
			y += 180.0
		draw_rect(Rect2(58, top - 14, 40, 18), Color("98a2ab"))
		draw_rect(Rect2(58, top - 14, 40, 18), INK, false, 3.0)
		# Unit AC luar
		var vr: Vector2i = game.vis_floors()
		for f in range(maxi(1, vr.x), mini(D.TOP_FLOOR, vr.y) + 1):
			if not _has_ac(f): continue
			var yy: float = D.ROWS[f].x + 170.0
			var box := Rect2(6, yy, 60, 52)
			draw_line(Vector2(66, yy + 22), Vector2(92, yy + 22), Color("f2f2f2"), 6.0)
			draw_line(Vector2(66, yy + 22), Vector2(92, yy + 22), Color(INK, 0.5), 1.5)
			draw_rect(box, Color("ececE6"))
			draw_rect(box, INK, false, 4.0)
			var c := Vector2(34, yy + 26)
			draw_circle(c, 18, Color("cfcfca"))
			draw_arc(c, 18, 0, TAU, 24, INK, 3.0)
			var a := t * 9.0 + f
			for k in range(3):
				var ang := a + TAU * k / 3.0
				draw_line(c, c + Vector2(cos(ang), sin(ang)) * 15.0, Color("8d8d88"), 4.0)
			draw_circle(c, 4, INK)
			for k in range(3):
				draw_line(Vector2(56, yy + 10 + k * 12), Vector2(62, yy + 10 + k * 12), Color("9a9a95"), 2.0)
			draw_line(Vector2(10, yy + 52), Vector2(10, yy + 64), INK, 4.0)
			draw_line(Vector2(62, yy + 52), Vector2(62, yy + 64), INK, 4.0)
			draw_line(Vector2(4, yy + 64), Vector2(68, yy + 64), INK, 4.0)


func _lobby_mask(nd: Node) -> void:
	if nd is CanvasItem:
		(nd as CanvasItem).light_mask = 2
	for c in nd.get_children():
		_lobby_mask(c)


# ---------------- Mang Ujang, petugas sampah (outsource) ----------------
var sampah: Npc


func _maybe_sampah(h: int) -> void:
	var lv := out_lv("sampah")
	if lv == 0 or sampah != null or h != 7: return
	if lv == 1 and int(S.day) % 3 != 0: return
	spawn_sampah()


func spawn_sampah() -> void:
	var n := Npc.new()
	npc_lobby.add_child(n)
	n.setup("sampah", "visitor", D.STAFF_LOOK.teknisi, Vector2(-260, D.LOBBY_Y), font)
	n.art = true
	n.char_id = "sampah"
	n.art_map = {"walk": "walk", "stand": "idle", "pick": "cart", "happy": "wave"}
	n.set_meta("nama", D.OUTSRC.sampah.nama)
	npcs["sampah"] = n
	sampah = n
	n.plan("lobby", Vector2(560, D.LOBBY_Y), "stand", func(m: Npc):
		m.say(["Sampaaah! Permisi, Mbak Maryam~", "Pagi! Mang Ujang ambil sampah ya.", "Sampahnya sudah dipilah? Mantap!"].pick_random(), 2.8)
		m.work = {"t": 3.0, "pose": "pick", "fn": func(k: Npc):
			if out_lv("sampah") >= 3:
				for e in each_tenant():
					e[1].tenant.happy = clampf(float(e[1].tenant.happy) + 1.0, 0, 100)
			k.work = {"t": 1.6, "pose": "happy", "fn": func(z: Npc):
				z.plan("lobby", Vector2(-300, D.LOBBY_Y), "stand", func(y: Npc):
					_remove_npc(y)
					sampah = null)}})


# ---------------- Interaksi penghuni dengan fasilitas & karyawannya ----------------
const FACIL_TALK := {
	"laundry": [["Mas Budi, cuci kilat bisa?", "Bisa! Sore udah wangi."], ["Titip seprai ya, Mas.", "Siap, sekalian disetrika."]],
	"kantin": [["Bu Sari, nasi rames satu ya!", "Siap, Nak. Pakai telur?"], ["Bu, sayur asemnya masih?", "Masih anget, baru matang!"]],
	"cafe": [["Kak Nadia, es kopi susu satu!", "Oke! Gula aren atau biasa?"], ["Kak, matcha latte ya.", "Siap, less sugar?"]],
	"minimart": [["Kak Sinta, ada mi instan?", "Ada, rak kedua ya."], ["Bayar pakai QRIS bisa?", "Bisa dong, scan di sini."]],
	"gym": [["Kak Ray, spot aku ya!", "Ayo, satu lagi! Kamu pasti bisa!"], ["Kak, plank berapa lama?", "Satu menit. Tahan... jangan curang!"]],
	"hidroponik": [["Kang Dedi, seladanya udah panen?", "Besok pagi, segar-segar!"], ["Kang, pakcoy sekilo berapa?", "Buat anak kost, harga teman!"]],
	"lele": [["Pak Darto, lelenya gede-gede!", "Pakannya rutin, Nak."], ["Pak, bisa pesan lele goreng?", "Bisa, nanti saya antar ke Warteg."]],
	"petshop": [["Mbak Lala, pasir kucing ada?", "Ada, yang wangi lavender ya?"], ["Mbak, makanan kucing anak?", "Ini, buat kitten. Lucu banget pasti!"]],
	"bunga": [["Mbak Rosa, buket buat pacar dong.", "Mawar merah? Romantis!"], ["Mbak, tanaman yang gampang dirawat?", "Lidah mertua, tahan banting!"]],
	"koperasi": [["Bu Wati, mau nabung lima puluh ribu.", "Siap, ini bukunya ya."], ["Bu, beras lima kilo masih?", "Masih, harga anggota!"]],
	"warteg": [["Bu Tini, nasi orek tempe ya!", "Pakai kuah sayur lodeh?"], ["Bu, es teh manis satu!", "Siap, gulanya dikit kan?"]],
}
const FACIL_SOLO := {
	"mushola": ["Adem banget di sini.", "Alhamdulillah, tenang rasanya."],
	"dapur": ["Masak mi dulu ah.", "Wangi bawang goreng~"],
	"tunggu": ["Duduk sebentar ah.", "Sofanya empuk."],
	"laundry": ["Mesinnya kupakai sendiri deh."],
	"gym": ["Treadmill dulu 10 menit."],
	"hidroponik": ["Seger lihat yang hijau-hijau.", "Wah, tomatnya mulai merah."],
	"lele": ["Lelenya lincah banget!", "Kasih pakan ah."],
	"bunga": ["Wangi banget mawarnya.", "Beli satu buat kamar ah."],
}
var _fac_acc := 0.0


func _facil_tick(dt: float) -> void:
	_fac_acc += dt
	if _fac_acc < 1.0: return
	_fac_acc = 0.0
	for n in npcs.values():
		if n.kind != "res" or not str(n.goal_key).begins_with("fac|") or n.is_moving():
			continue
		if n.get_meta("fac_done", "") == n.goal_key: continue
		n.set_meta("fac_done", n.goal_key)
		var fk: String = str(n.goal_key).split("|")[1]
		var k: String = S.facil.get(fk, "")
		if k == "": continue
		var fc: Dictionary = D.FACIL[k]
		var t := _tenant_by_id(n.id)
		if fc.has("staff"):
			var st: Npc = npcs.get("staff-" + str(fc.staff))
			if st != null and is_instance_valid(st) and st.scene == n.scene and not st.is_moving():
				var ln: Array = FACIL_TALK.get(k, [["Halo!", "Halo, Kak!"]]).pick_random()
				n.say(ln[0], 2.4)
				get_tree().create_timer(1.6).timeout.connect(func():
					if is_instance_valid(st):
						st.say(ln[1], 2.4)
						st.react("happy", 1.8)
					if is_instance_valid(n): n.react("happy", 1.8))
				if not t.is_empty(): t.happy = clampf(float(t.happy) + 2.0, 0, 100)
				continue
			elif not S.staff.get(fc.staff, false):
				if randf() < 0.5: n.say("Yah, %s belum ada yang jaga..." % fc.n, 2.4)
				continue
		if FACIL_SOLO.has(k) and randf() < 0.5:
			n.say(FACIL_SOLO[k].pick_random(), 2.2)
			if not t.is_empty(): t.happy = clampf(float(t.happy) + 1.0, 0, 100)


func _tenant_by_id(id: String) -> Dictionary:
	for e in each_tenant():
		if str(e[1].tenant.id) == id: return e[1].tenant
	return {}


# ---------------- Rating Google Play (In-App Review) ----------------
const PLAY_URL := "https://play.google.com/store/apps/details?id=com.kelolapro.cozykost"


## Dipanggil di momen menyenangkan (naik level, menang padel, selesai baca buku).
## Hanya di Android, minimal hari ke-3, paling sering 7 hari sekali, maksimal 3 kali.
func maybe_review(_why: String) -> void:
	if not OS.has_feature("android"): return
	var rv: Dictionary = S.get("review", {})
	if rv.get("done", false) or int(rv.get("n", 0)) >= 3: return
	if int(S.day) < 3 or int(S.day) - int(rv.get("day", -99)) < 7: return
	if ui.kind != "": return
	rv.n = int(rv.get("n", 0)) + 1
	rv.day = int(S.day)
	S.review = rv
	get_tree().create_timer(1.5).timeout.connect(func():
		if ui.kind == "": ui.open_sheet("review"))


func open_review(user: bool) -> void:
	var rv: Dictionary = S.get("review", {})
	rv.done = true
	S.review = rv
	for nm in ["GodotGooglePlayInAppReview", "AndroidInAppReview", "InappReviewPlugin"]:
		if Engine.has_singleton(nm):
			var pl = Engine.get_singleton(nm)
			if pl.has_method("launch_review_flow"): pl.launch_review_flow(); return
			if pl.has_method("launchReviewFlow"): pl.launchReviewFlow(); return
	if OS.has_feature("android"):
		OS.shell_open(PLAY_URL)
	elif user:
		ui.toast("Rating Google Play tersedia di aplikasi Android (segera hadir). Terima kasih!", "gold")


# ---------------- Cat dinding & lantai ruang tengah (tangga) ----------------
var hall_paint_sp := {}


func hall_tpl(f: int) -> String:
	return "1S" if f % 2 == 1 else "3S"


func _refresh_hall_paint() -> void:
	for f in hall_paint_sp:
		var p: Dictionary = S.get("hall_paint", {}).get(str(f), {})
		if hall_preview.has(f): p = hall_preview[f]
		var sp: Sprite2D = hall_paint_sp[f]
		var on: bool = p.get("wall", "asli") != "asli" or p.get("motif", "polos") != "polos" or p.get("floor", "asli") != "asli"
		sp.visible = on
		if on:
			sp.material = D.paint_mat(hall_tpl(f), p, art.get_size(), sp.material as ShaderMaterial)


var hall_preview := {}


func hall_paint_cost(f: int, sel: Dictionary) -> float:
	var cur: Dictionary = S.get("hall_paint", {}).get(str(f), {})
	var c := 0.0
	if sel.get("wall", "asli") != cur.get("wall", "asli") or sel.get("motif", "polos") != cur.get("motif", "polos"):
		c += D.PAINT_PRICE + float(D.MOTIFS[sel.get("motif", "polos")].p)
	if sel.get("floor", "asli") != cur.get("floor", "asli"):
		c += maxf(100000.0, float(D.FLOORS[sel.get("floor", "asli")].p))
	return c


func buy_hall_paint(f: int, sel: Dictionary) -> void:
	var c := hall_paint_cost(f, sel)
	if c <= 0.0:
		ui.toast("Belum ada yang diubah.", "bad"); return
	if float(S.money) < c:
		ui.toast(ui.money_why(c), "bad"); return
	spend(c, "other")
	if not S.has("hall_paint"): S.hall_paint = {}
	S.hall_paint[str(f)] = sel.duplicate()
	hall_preview.erase(f)
	S.rep = clampf(float(S.rep) + 0.02, 1.0, 5.0)
	_refresh_hall_paint()
	sfx("upgrade")
	add_xp(6)
	ui.toast("Ruang tengah lantai %d didekorasi ulang!" % f, "gold")
	dirty = true


# ---------------- Paper bag pesanan ojol ----------------
var bag_nodes: Array = []
const BAG_LATE := 60.0        # menit game sebelum penghuni mulai kesal


func _room_of_tenant(tid: String) -> String:
	for e in each_tenant():
		if str(e[1].tenant.id) == tid: return e[0]
	return ""


func drop_bag(tid: String, tname: String, rid: String, food: String) -> void:
	if not S.has("bags"): S.bags = []
	if S.bags.size() >= 4: return
	S.bags.append({"id": "b%d" % randi(), "for": tid, "name": tname, "room": rid, "food": food, "age": 0.0, "warn": false})
	_refresh_bags()
	sfx("pop", -6.0)
	ui.toast("Kantong %s untuk %s ditaruh di lobi. Seret ke kamarnya!" % [food, tname])


func _refresh_bags() -> void:
	for b in bag_nodes: b.queue_free()
	bag_nodes = []
	var tex: Texture2D = load("res://assets/bag.png")
	var i := 0
	for bg in S.get("bags", []):
		if bg.get("lift", false): continue
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
		# Ditaruh di atas meja lobi (sebelah kanan kucing), maksimal 3 per baris.
		sp.position = Vector2(1130 + (i % 3) * 62, CAT_DESK.y + 4 - float(i / 3) * 46)
		sp.scale = Vector2.ONE * 0.8
		var tag := Label.new()
		tag.text = str(bg.name)
		tag.add_theme_font_override("font", font)
		tag.add_theme_font_size_override("font_size", 26)
		tag.add_theme_color_override("font_color", D.C_INK)
		tag.add_theme_color_override("font_outline_color", Color.WHITE)
		tag.add_theme_constant_override("outline_size", 8)
		tag.position = Vector2(-60, -tex.get_height() - 34)
		tag.size = Vector2(120, 30)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sp.add_child(tag)
		sp.set_meta("bid", bg.id)
		lobby_root.add_child(sp)
		lobby_root.move_child(sp, recep_art.get_index() + 1)
		bag_nodes.append(sp)
		i += 1


func _bag_at(p: Vector2) -> String:
	for sp in bag_nodes:
		var r := Rect2(sp.position + Vector2(-45, -125), Vector2(90, 135))
		if r.has_point(p): return str(sp.get_meta("bid"))
	return ""


func _bag(bid: String) -> Dictionary:
	for b in S.get("bags", []):
		if b.id == bid: return b
	return {}


func _tick_bags(mins: float) -> void:
	for b in S.get("bags", []).duplicate():
		b.age = float(b.age) + mins
		var rid := _room_of_tenant(str(b.for))
		if rid == "":
			S.bags.erase(b)
			_refresh_bags()
			continue
		if float(b.age) > BAG_LATE:
			var t: Dictionary = S.rooms[rid].tenant
			t.happy = maxf(0.0, float(t.happy) - mins * 0.05)
			if not b.warn:
				b.warn = true
				if npcs.has(t.id): npcs[t.id].say("Makananku kok belum sampai?!", 3.0)
				ui.toast("%s menunggu pesanannya terlalu lama!" % t.name, "bad")
				if wa: wa.complain(rid, "bag")


func deliver_bag(bid: String, rid: String) -> void:
	var b := _bag(bid)
	if b.is_empty(): return
	S.bags.erase(b)
	_refresh_bags()
	var r: Dictionary = S.rooms[rid]
	var right := _room_of_tenant(str(b.for))
	if rid == right:
		var late := float(b.age) > BAG_LATE
		r.tenant.happy = clampf(float(r.tenant.happy) + (2.0 if late else [5.0, 7.0, 9.0][out_lv("ojol")]), 0, 100)
		if npcs.has(r.tenant.id):
			npcs[r.tenant.id].say("Akhirnya! Makasih Mbak Maryam~" if late else "Wah, %s-ku! Makasih!" % b.food, 2.6)
			npcs[r.tenant.id].react("happy", 2.0)
		sfx("pop", -4.0)
		ui.toast("%s sampai ke Kamar %s%s" % [b.food.capitalize(), D.room_name(rid)," (agak telat)" if late else "!"], "" if late else "gold")
		add_xp(3)
	else:
		# Salah kamar: penerima bingung, pemilik asli makin kesal.
		if npcs.has(r.tenant.id): npcs[r.tenant.id].say("Lho, ini bukan pesananku...", 2.6)
		if right != "":
			var t: Dictionary = S.rooms[right].tenant
			t.happy = maxf(0.0, float(t.happy) - 15.0)
			if npcs.has(t.id):
				npcs[t.id].say("Pesananku malah dikasih ke kamar lain?!", 3.0)
				npcs[t.id].react("angry", 2.5)
		ui.toast("Salah kamar! Ini pesanan %s (Kamar %s). %s jadi kesal." % [b.name, D.room_name(right) if right != "" else "-", b.name], "bad")
	dirty = true


# ---------------- Polisi (outsource) ----------------
const POLICE_LINES := {"preman": ["Selamat siang. Ada laporan pungli di sini?", "Bapak ikut kami ke kantor, ya.", "Pungli itu melanggar hukum!"],
	"thief": ["Berhenti! Polisi!", "Angkat tangan!", "Kembalikan barangnya!"]}


func _police_come(why: String) -> void:
	if npcs.has("polisi"): return
	var n := Npc.new()
	npc_lobby.add_child(n)
	n.setup("polisi", "visitor", D.STAFF_LOOK.teknisi, Vector2(D.IW + 220, D.LOBBY_Y), font)
	n.art = true
	n.char_id = "polisi"
	n.art_map = {"walk": "walk", "stand": "idle", "stop": "stop", "happy": "happy"}
	n.set_meta("nama", D.OUTSRC.polisi.nama)
	n.set_meta("spd", 1.6)
	npcs["polisi"] = n
	sfx("arrive", -8.0)
	keeper_say("Pak Polisi, tolong!", 2.5)
	var target: Npc = preman if why == "preman" else thief
	if target == null or not is_instance_valid(target):
		_remove_npc(n); return
	target.work = {"t": 30.0, "pose": "caught" if why == "thief" else "demand"}
	n.plan("lobby", Vector2(target.position.x + 150, D.LOBBY_Y), "stand", func(m: Npc):
		m.dir = -1
		m.work = {"t": 2.4, "pose": "stop", "fn": func(k: Npc):
			k.say(POLICE_LINES[why].pick_random(), 2.6)
			if is_instance_valid(target):
				target.say("Ampun, Pak! Ampun!" if why == "preman" else "Iya, Pak, saya nyerah...", 2.4)
				target.art_map["walk"] = "walk"
				target.work = {"t": 2.2, "pose": "caught"}
			get_tree().create_timer(2.4).timeout.connect(func(): _police_drag(k, target, why))}
		m.say(POLICE_LINES[why].pick_random(), 2.4))


## Polisi menyeret pelaku keluar: pelaku berjalan di depan, polisi menyusul di belakangnya.
func _police_drag(pol: Npc, target: Npc, why: String) -> void:
	if is_instance_valid(target):
		target.set_meta("spd", 0.9)
		target.work = {}
		target.plan("lobby", Vector2(D.OUT_X - 260, D.LOBBY_Y), "stand", func(z: Npc):
			_remove_npc(z)
			if why == "preman": preman = null
			else: thief = null)
	if why == "preman":
		S.preman_next = int(S.day) + (14 if out_lv("polisi") >= 2 else 10)
		S.preman_paid = 0
		S.rep = clampf(float(S.rep) + 0.05, 1, 5)
		ui.toast("Pak Bambang menyeret preman ke kantor polisi. Kost aman!", "gold")
	else:
		_thief_state = ""
		ui.toast("Maling ditangkap polisi! Tidak ada barang yang hilang.", "gold")
	add_xp(12)
	pol.set_meta("spd", 0.9)
	pol.plan("lobby", Vector2(D.OUT_X - 120, D.LOBBY_Y), "stand", func(m: Npc):
		m.say("Tugas selesai. Selamat siang!", 2.0)
		m.work = {"t": 1.5, "pose": "happy", "fn": func(z: Npc):
			z.plan("lobby", Vector2(D.OUT_X - 360, D.LOBBY_Y), "stand", func(y: Npc): _remove_npc(y))})


# ---------------- Kebakaran & pemadam (outsource) ----------------
var fire_fx := {}
var _fire_called := {}


func _maybe_fire(h: int) -> void:
	if not S.get("fire", {}).is_empty() or int(S.lvl) < 3: return
	if each_tenant().size() < 3: return
	if int(S.day) - int(S.get("fire_day", -99)) < 20: return
	if randf() > 0.004: return
	var pool := []
	for e in each_tenant(): pool.append(e[0])
	start_fire(pool.pick_random())


func start_fire(rid: String) -> void:
	if not S.has("fire"): S.fire = {}
	if S.fire.has(rid): return
	pengacau_seen("fire")
	S.fire[rid] = 0.0
	if wa:
		var fn = S.rooms[rid].tenant
		wa.post(str(fn.name) if fn != null else "Penghuni ", "KEBAKARAN DI KAMAR %s!!! SEMUA KELUAR!" % D.room_name(rid), "alert", rid)
	cat_startle()
	S.fire_day = int(S.day)
	_refresh_fire()
	sfx("thunder", -8.0)
	jump_to_floor(D.fl(rid))
	ui.toast("KEBAKARAN di Kamar %s! %s" % [D.room_name(rid), "Damkar sedang menuju ke sini." if out_lv("damkar") >= 1 else "Ketuk kamarnya untuk panggil Damkar!"], "bad")
	var r: Dictionary = S.rooms[rid]
	if r.tenant != null and npcs.has(r.tenant.id):
		npcs[r.tenant.id].say("Kebakaran! Tolong!", 3.0)
	keeper_say("Ya Allah, ada api! Semua keluar dulu!", 3.0)
	_fire_flee(rid)
	if out_lv("damkar") >= 1: _call_damkar(rid)


## Semua orang di kamar terbakar (penghuni & karyawan) lari panik ke lobi.
const PANIC_LINES := ["Kebakaran!!", "Tolong! Api!", "Lari! Lari!", "Panas! Keluar!", "Aaaa! Apinya besar!"]
func _fire_flee(rid: String) -> void:
	var k := 0
	for n in npcs.values():
		if not is_instance_valid(n) or n.scene != rid: continue
		if str(n.id).begins_with("damkar"): continue
		k += 1
		n.work = {}
		n.say(PANIC_LINES.pick_random(), 2.5)
		n.set_meta("spd", 2.2)
		n.set_meta("panic", true)
		var x := 260.0 + 120.0 * k
		n.plan("lobby", Vector2(x, D.LOBBY_Y), "stand", func(m: Npc):
			m.set_meta("spd", 1.0)
			m.remove_meta("panic")
			m.dir = 1
			m.say(["Huft... selamat.", "Semoga cepat padam...", "Barangku gimana ya..."].pick_random(), 2.6)
			m.work = {"t": 6.0, "pose": "stand"})
	if k > 0: ui.toast("Penghuni & karyawan di Kamar %s berlarian keluar!" % D.room_name(rid), "bad")


func _fire_tick(mins: float) -> void:
	if S.get("fire", {}).is_empty(): return
	var spread := 500.0 * (1.6 if out_lv("damkar") >= 2 else 1.0)
	for rid in S.fire.keys():
		S.fire[rid] = float(S.fire[rid]) + mins
		var r: Dictionary = S.rooms[rid]
		if r.tenant != null:
			r.tenant.happy = maxf(0.0, float(r.tenant.happy) - mins * 0.02)
		if float(S.fire[rid]) >= spread and not S.has("fire_spread_" + rid):
			S["fire_spread_" + rid] = true
			for nb in _fire_neighbors(rid):
				if not S.fire.has(nb) and S.rooms[nb].built:
					start_fire(nb)
					ui.toast("Api menjalar ke Kamar %s!" % D.room_name(nb), "bad")
					break
		if float(S.fire[rid]) >= 1300.0:
			# Terlalu lama: kamar rusak berat.
			_fire_out(rid, true)


func _fire_neighbors(rid: String) -> Array:
	var f := D.fl(rid)
	var c := D.col(rid)
	var out := ["%d%s" % [f, "R" if c == "L" else "L"]]
	out.shuffle()
	if f + 1 <= D.TOP_FLOOR: out.append("%d%s" % [f + 1, c])
	if f - 1 >= 1: out.append("%d%s" % [f - 1, c])
	return out


func _fire_out(rid: String, burnt: bool) -> void:
	if not S.get("fire", {}).has(rid): return
	S.fire.erase(rid)
	S.erase("fire_spread_" + rid)
	_fire_called.erase(rid)
	var r: Dictionary = S.rooms[rid]
	r.broken = Funny.GOSONG
	if burnt:
		for t in r.get("furn", {}).keys():
			r.furn[t] = maxi(1, int(r.furn[t]) - 1)
		ui.toast("Kamar %s terbakar habis! Perabot rusak, perlu renovasi." % D.room_name(rid), "bad")
	_refresh_fire()
	dirty = true


func fire_tap(rid: String) -> bool:
	if not S.get("fire", {}).has(rid): return false
	if _fire_called.has(rid):
		ui.toast("Damkar sedang dalam perjalanan. Sabar ya!")
		return true
	ui.open_sheet("fire", rid)
	return true


func _call_damkar(rid: String) -> void:
	if _fire_called.has(rid): return
	_fire_called[rid] = true
	var delay: float = [9.0, 4.0, 2.0][out_lv("damkar")]
	get_tree().create_timer(delay).timeout.connect(func(): _damkar_go(rid))


func call_damkar_paid(rid: String) -> void:
	ui.close_sheet()
	if float(S.money) < 500000:
		ui.toast(ui.money_why(500000), "bad"); return
	spend(500000, "other")
	ui.toast("Damkar dihubungi (Rp 500rb). Mereka segera datang!")
	_call_damkar(rid)


func _damkar_go(rid: String) -> void:
	if not S.get("fire", {}).has(rid): return
	var nid := "damkar-" + rid
	if npcs.has(nid): return
	var n := Npc.new()
	npc_lobby.add_child(n)
	n.setup(nid, "worker", D.STAFF_LOOK.teknisi, Vector2(D.OUT_X, D.LOBBY_Y), font)
	n.art = true
	n.char_id = "damkar"
	n.art_map = {"walk": "walk", "stand": "idle", "spray": "spray", "happy": "happy", "job": "spray"}
	n.set_meta("nama", D.OUTSRC.damkar.nama)
	n.set_meta("spd", 2.0)
	n.target = rid
	npcs[nid] = n
	sfx("arrive", -6.0)
	n.say("Damkar datang! Minggir semua!", 2.6)
	n.plan(rid, _spot_in(rid), "spray", func(m: Npc):
		m.say(["Semprot!", "Tenang, apinya kecil!", "Air, air!"].pick_random(), 2.2)
		m.work = {"t": 4.0, "pose": "spray", "fn": func(k: Npc):
			_fire_out(rid, false)
			k.say("Api padam! Aman sekarang.", 2.6)
			add_xp(10)
			ui.toast("Api di Kamar %s berhasil dipadamkan. Kamar perlu dibersihkan dari jelaga." % D.room_name(rid), "gold")
			# Masih ada api lain? langsung ke sana.
			var nxt := ""
			for o in S.get("fire", {}).keys():
				nxt = o
				break
			if nxt != "":
				_fire_called[nxt] = true
				k.target = nxt
				k.plan(nxt, _spot_in(nxt), "spray", func(z: Npc):
					z.work = {"t": 4.0, "pose": "spray", "fn": func(y: Npc):
						_fire_out(nxt, false)
						y.say("Semua padam!", 2.4)
						_leave_worker(y)})
			else:
				k.work = {"t": 1.8, "pose": "happy", "fn": func(z: Npc): _leave_worker(z)}})


func _refresh_fire() -> void:
	for rid in fire_fx.keys():
		if not S.get("fire", {}).has(rid):
			fire_fx[rid].queue_free()
			fire_fx.erase(rid)
	for rid in S.get("fire", {}):
		if fire_fx.has(rid) or not room_fx.has(rid): continue
		var fx := _FireFx.new()
		fx.sz = D.rect_of(rid).size
		room_fx[rid].add_child(fx)
		fire_fx[rid] = fx


class _FireFx extends Node2D:
	var sz := Vector2(420, 367)
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.9, 0.35, 0.1, 0.18 + 0.06 * sin(t * 8.0)))
		for i in range(7):
			var x := sz.x * (0.12 + 0.13 * i)
			var h := 90.0 + 50.0 * sin(t * 6.0 + i * 1.7)
			var base := Vector2(x, sz.y - 30)
			var pts := PackedVector2Array([base + Vector2(-34, 0), base + Vector2(-16, -h * 0.6), base + Vector2(0, -h), base + Vector2(16, -h * 0.55), base + Vector2(34, 0)])
			draw_colored_polygon(pts, Color("f2662f"))
			var pts2 := PackedVector2Array([base + Vector2(-18, 0), base + Vector2(-6, -h * 0.45), base + Vector2(0, -h * 0.7), base + Vector2(8, -h * 0.4), base + Vector2(18, 0)])
			draw_colored_polygon(pts2, Color("ffd25a"))
		for i in range(5):
			var k := fmod(t * 0.3 + i * 0.2, 1.0)
			draw_circle(Vector2(sz.x * (0.2 + 0.15 * i), sz.y * 0.6 - k * sz.y * 0.6), 20 + k * 40, Color(0.3, 0.3, 0.3, 0.4 * (1.0 - k)))


var hub_nodes := {}
const HUB_STAIR_LONG := 62.0


func _refresh_hubs() -> void:
	if bld == null: return
	for f in range(D.HUB_EVERY, D.TOP_FLOOR + 1, D.HUB_EVERY):
		var on := floor_open(f)
		if on:
			for side in ["L", "R"]:
				var hid := "%d%s" % [f, side]
				var hr: Dictionary = S.rooms.get(hid, {})
				if hr.is_empty() or not hr.get("built", false): continue
				var tn = hr.get("tenant")
				hr.built = false
				hr.tenant = null
				hr.furn = {}
				S.money = float(S.money) + build_cost()
				if tn != null:
					var moved := false
					for id2 in D.ROOMS:
						var r2: Dictionary = S.rooms[id2]
						if r2.built and r2.tenant == null:
							r2.tenant = tn; moved = true; break
					if not moved:
						S.queue.push_front(tn)
				ui.toast("Kamar %s dibongkar untuk %s (biaya dikembalikan)." % [hid, D.hub_info(f).n])
		if on and S.facil.has(str(f)):
			var k: String = S.facil[str(f)]
			S.facil.erase(str(f))
			var nf := free_facil_floor()
			if nf > 0:
				S.facil[str(nf)] = k
				ui.toast("%s dipindah ke lantai %d karena lantai %d jadi %s." % [D.FACIL[k].n, nf, f, D.hub_info(f).n])
			else:
				S.money = float(S.money) + facil_cost(k)
				ui.toast("%s dibongkar (lantai %d jadi %s), biayanya dikembalikan." % [D.FACIL[k].n, f, D.hub_info(f).n])
			_refresh_facil.call_deferred()
		if on and not hub_nodes.has(f):
			var hn := _HubSign.new()
			hn.f = f
			hn.font = font
			hn.info = D.hub_info(f)
			hn.rect = D.rect_of("%dS" % f)
			bld.add_child(hn)
			bld.move_child(hn, L_stairs.get_index())   # tangga tetap di atas lobi
			if f - 1 < stair_nodes.size() and stair_nodes[f - 1] != null:
				stair_nodes[f - 1].long = HUB_STAIR_LONG
				stair_nodes[f - 1].queue_redraw()
			hub_nodes[f] = hn
		elif not on and hub_nodes.has(f):
			hub_nodes[f].queue_free()
			hub_nodes.erase(f)


## Lobi Langit: satu lantai penuh (tanpa kamar) berisi stasiun/parkiran/tol/helipad/roket.
## Kolom tangga dibiarkan terlihat supaya penghuni tetap naik-turun lewat tangga.
class _HubSign extends Node2D:
	var f := 10
	var fixed := Rect2()
	var font: Font
	var info := {}
	var rect := Rect2()
	var t := 0.0
	const INK := Color("4a3426")
	const L0 := 131.0
	const L1 := 792.0
	const R0 := 996.0
	const R1 := 1405.0
	const SKY := Color(0.82, 0.86, 0.82)
	var VIS := [Vector2(0, L1), Vector2(R0, 1438)]   # area terlihat untuk benda tinggi (di luar badan tangga)
	var quad := []   # 4 sudut badan tangga (dibiarkan terbuka agar tangga tetap terlihat)
	var y0 := 0.0
	var fy := 0.0

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		if fixed.size.x > 0:
			y0 = fixed.position.y; fy = y0 + 349.0
		else:
			y0 = D.ROWS[f].x; fy = D.FEET[f]
		var c: Color = info.get("c", Color("6a8fb3"))
		var k := String(info.get("n", "")).split(" ")[0]
		var space := String(info.get("n", "")).find("Angkasa") >= 0
		_calc_quad()
		_outside(space, k)
		var key: String = {"Lobi": "parkir", "Gerbang": "tol", "Helipad": "heli"}.get(k, "roket" if space else "kereta")
		var bgt := _tex("hub_" + key)
		if bgt:
			# Ilustrasi lantai penuh + kendaraan bergerak (sprite)
			draw_texture_rect(bgt, Rect2(0, y0, 1438, fy + 18 - y0), false)
			match key:
				"parkir": _a_parkir()
				"tol": _a_tol()
				"kereta": _a_kereta()
				"heli": _a_heli()
				"roket": _a_roket()
			_people(key)
			return
		_stair_col(space, c)
		for reg in [Vector2(L0, L1), Vector2(R0, R1)]:
			var r := Rect2(reg.x, y0, reg.y - reg.x, fy - y0 + 18)
			draw_rect(r, Color("1f2448") if space else c.lightened(0.62))
			var ft: float = quad[3].y   # lantai lobi setinggi kaki tangga
			draw_rect(Rect2(reg.x, ft, reg.y - reg.x, fy + 18 - ft), Color("3b3f52") if space else Color("cfc6b8"))
			draw_line(Vector2(reg.x, ft), Vector2(reg.y, ft), Color(0, 0, 0, 0.15), 3)
			draw_rect(Rect2(reg.x, y0, reg.y - reg.x, 16), c.darkened(0.2))
			draw_line(r.position, Vector2(r.end.x, r.position.y), INK, 4)
			draw_line(Vector2(r.position.x, r.end.y), r.end, INK, 4)
		# dinding luar gedung berlubang (jalur tembus)
		for wx in [L0, R1]:
			draw_rect(Rect2(wx - 8, y0, 16, 120), Color("c9a27e"))
			draw_rect(Rect2(wx - 8, y0, 16, 120), INK, false, 3)
		match k:
			"Lobi": _parkir(c)
			"Gerbang": _tol(c)
			"Stasiun":
				if space: _roket(c)
				else: _kereta(c)
			"Helipad": _heli(c)
		# papan nama
		var w := 330.0
		var box := Rect2((L0 + L1) / 2.0 - w / 2.0, y0 + 26, w, 54)
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.border_color = INK
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(14)
		draw_style_box(sb, box)
		if font:
			draw_string(font, box.position + Vector2(0, 38), str(info.get("n", "")), HORIZONTAL_ALIGNMENT_CENTER, w, 28, Color.WHITE)

	# ---------- versi ilustrasi (gambar dari Rin) ----------
	static var _texc := {}
	func _tex(n: String) -> Texture2D:
		if not _texc.has(n):
			var path := ("res://assets/chars/%s_L.png" % n) if n.contains("/") else ("res://assets/hub/%s.png" % n)
			_texc[n] = load(path) if ResourceLoader.exists(path) else null
		return _texc[n]

	## Koordinat y pada gambar asli lantai (tinggi 412) -> layar.
	func Y(cy: float) -> float:
		return y0 + cy * (fy + 18.0 - y0) / 412.0

	## Gambar sprite (alas di tengah-bawah = p), bisa dicermin, dipotong agar tidak menutupi badan tangga.
	func _spr(n: String, p: Vector2, h: float, flip := false, clip := false, a := 1.0) -> void:
		var tx := _tex(n)
		if tx == null: return
		var sz := tx.get_size()
		var w := sz.x * h / sz.y
		var r := Rect2(p.x - w / 2.0, p.y - h, w, h)
		var parts := [Vector2(r.position.x, r.end.x)]
		if clip:
			var q0: float = quad[0].x
			var q1: float = quad[2].x
			parts = [Vector2(r.position.x, minf(r.end.x, q0)), Vector2(maxf(r.position.x, q1), r.end.x)]
		for pt in parts:
			if pt.y <= pt.x: continue
			var u0: float = (float(pt.x) - r.position.x) / w
			var u1: float = (float(pt.y) - r.position.x) / w
			if flip:
				var t0: float = 1.0 - u1
				u1 = 1.0 - u0
				u0 = t0
			var src := Rect2(u0 * sz.x, 0, (u1 - u0) * sz.x, sz.y)
			var dst := Rect2(pt.x, r.position.y, pt.y - pt.x, h)
			if flip:
				draw_set_transform(Vector2(dst.position.x * 2.0 + dst.size.x, 0), 0.0, Vector2(-1, 1))
				draw_texture_rect_region(tx, dst, src, Color(1, 1, 1, a))
				draw_set_transform(Vector2.ZERO)
			else:
				draw_texture_rect_region(tx, dst, src, Color(1, 1, 1, a))

	## Orang-orang di lobi (penumpang, pengunjung, petugas).
	func _walker(ch: String, x0: float, x1: float, cy: float, period: float, off := 0.0) -> void:
		var u := fmod(t + off, period) / period
		var k := u * 2.0 if u < 0.5 else (1.0 - u) * 2.0   # bolak-balik
		var x := lerpf(x0, x1, k)
		var fr := "walk" if fmod(t * 4.0, 2.0) < 1.0 else "walk2"
		_spr("%s/%s" % [ch, fr], Vector2(x, Y(cy)), 150, u >= 0.5, true)

	func _stand(ch: String, pose: String, x: float, cy: float, flip := false) -> void:
		_spr("%s/%s" % [ch, pose], Vector2(x, Y(cy)), 150, flip, true)

	func _people(key: String) -> void:
		match key:
			"parkir":
				_walker("kupluk", 330, 760, 400, 14.0)
				_stand("satpam", "idle", 1180, 404, true)
				_walker("siswi", 980, 1180, 410, 10.0, 3.0)
			"tol":
				_stand("satpam", "inspect", 430, 330)
				_walker("flanel", 980, 1100, 336, 9.0)
			"kereta":
				var cyc := fmod(t, 16.0)
				if cyc < 4.5 or cyc > 9.0:   # penumpang menunggu; saat kereta berhenti mereka naik
					_stand("nenek", "idle", 300, 402)
					_stand("kutu", "idle", 420, 404, true)
					_stand("siswi", "happy", 620, 400)
				else:
					_walker("kakek", 980, 1150, 404, 8.0)
				_stand("flanel", "idle", 1350, 404, true)
			"heli":
				_stand("kakek", "idle", 260, 404)
				_stand("siswi", "idle", 700, 404, true)
				var cyc2 := fmod(t, 14.0)
				if cyc2 > 4.5 and cyc2 < 8.5:
					_walker("kupluk", 980, 1110, 404, 8.0, 0.0)
			"roket":
				_stand("teknisi", "idle", 1090, 404, false)
				_stand("teknisi", "fix", 1250, 404, true)
				_walker("kutu", 160, 330, 404, 9.0)

	func _a_parkir() -> void:
		# petak parkir: mobil lebih besar dari orang
		for lx in [130.0, 350.0, 570.0, 790.0]:
			draw_line(Vector2(lx, Y(330)), Vector2(lx, Y(410)), Color.WHITE, 5)
		_spr("car_red", Vector2(240, Y(408)), 132)
		_spr("car_blue", Vector2(460, Y(408)), 132, true)
		_spr("car_green", Vector2(680, Y(408)), 132)
		# mobil datang dari kanan, berhenti di depan palang, lalu mundur keluar
		var cyc := fmod(t, 13.0)
		var x := 990.0
		if cyc < 4.0: x = lerpf(1560.0, 990.0, ease(cyc / 4.0, 0.5))
		elif cyc > 8.0: x = lerpf(990.0, 1560.0, ease(clampf((cyc - 8.0) / 4.0, 0, 1), 2.0))
		_spr("car_white", Vector2(x, Y(414)), 140, true)

	func _a_tol() -> void:
		var cars := ["car_red", "car_blue", "car_green", "car_white"]
		for i in range(4):
			var right := i % 2 == 0
			var x := fmod(t * 170.0 + i * 430.0, 1800.0) - 180.0
			if not right: x = 1438.0 - x
			_spr(cars[i], Vector2(x, Y(382) if right else Y(414)), 128, not right)

	func _a_kereta() -> void:
		var cyc := fmod(t, 16.0)
		var hx := 0.0   # tepi kanan kepala kereta
		if cyc < 4.0: hx = lerpf(-200.0, 1060.0, ease(cyc / 4.0, 0.4))
		elif cyc < 9.0: hx = 1060.0
		else: hx = lerpf(1060.0, 3400.0, ease((cyc - 9.0) / 7.0, 2.2))
		var h := 190.0
		var by := Y(330)
		var head := _tex("train_head")
		var mid := _tex("train_mid")
		if head == null or mid == null: return
		var hw := head.get_size().x * h / head.get_size().y
		var mw := mid.get_size().x * h / mid.get_size().y
		var xs := [hx - hw / 2.0]
		var cur := hx - hw
		for i in range(3):
			xs.append(cur - mw / 2.0 + 6)
			cur -= mw - 6
		for i in range(xs.size() - 1, -1, -1):
			var cx: float = xs[i]
			if i == 0: _spr("train_head", Vector2(cx, by), h, false, true)
			else: _spr("train_mid", Vector2(cx, by), h, false, true)
		# roda bogie
		for i in range(xs.size()):
			var cx2: float = xs[i]
			for dx in [-0.3, 0.3]:
				var wx: float = cx2 + dx * (hw if i == 0 else mw)
				if wx > quad[0].x - 20 and wx < quad[2].x + 20: continue
				draw_rect(Rect2(wx - 34, by - 2, 68, 12), Color("4a4f57"))
				draw_circle(Vector2(wx - 18, by + 10), 9, Color("2e3a4a"))
				draw_circle(Vector2(wx + 18, by + 10), 9, Color("2e3a4a"))

	func _a_heli() -> void:
		var cyc := fmod(t, 14.0)
		var hy := 0.0
		if cyc < 4.0: hy = lerpf(-280.0, 0.0, ease(cyc / 4.0, 0.4))
		elif cyc > 9.0: hy = lerpf(0.0, -340.0, ease((cyc - 9.0) / 5.0, 2.0))
		var p := Vector2(1228, Y(376) + hy)
		var a := clampf((p.y - 110.0 - y0) / 60.0, 0.0, 1.0)
		if a <= 0.0: return
		_spr("heli", p, 140, true, false, a)
		if cyc < 4.0 or cyc > 8.0:
			var rw := 150.0 * absf(cos(t * 18.0)) + 40.0
			draw_line(Vector2(p.x - rw, p.y - 134), Vector2(p.x + rw, p.y - 134), Color(0.3, 0.3, 0.3, 0.5 * a), 6)

	func _a_roket() -> void:
		var cyc := fmod(t, 15.0)
		var ry := 0.0
		if cyc > 8.0: ry = -pow((cyc - 8.0) * 1.6, 2.2) * 10.0
		var a := 1.0
		if cyc < 1.0: a = cyc
		var base := Vector2(480, Y(333) + ry)
		a *= clampf((base.y - 180.0 - (y0 - 60.0)) / 60.0, 0.0, 1.0)
		if a <= 0.0: return
		if cyc > 7.0:
			var fl := 50.0 + sin(t * 30.0) * 12.0
			draw_colored_polygon(PackedVector2Array([base + Vector2(-22, -6), base + Vector2(22, -6), base + Vector2(0, fl)]), Color(1.0, 0.64, 0.23, a))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-11, -6), base + Vector2(11, -6), base + Vector2(0, fl * 0.6)]), Color(1.0, 0.92, 0.5, a))
			for i in range(4):
				draw_circle(Vector2(380 + i * 70, Y(330)) + Vector2(sin(t * 5 + i) * 10, 0), 26 + (cyc - 7.0) * 4, Color(1, 1, 1, 0.35))
		_spr("rocket", base, 200, false, false, a)

	## Sudut badan tangga lantai genap (gambar ruang tangga "3S").
	func _calc_quad() -> void:
		var src := D.rect_of("3S")
		var sc := Vector2.ONE
		if fixed.size.x <= 0:
			sc = D.rect_of("%dS" % f).size / src.size
		var ed := [Vector2(233, 0), Vector2(331, 0), Vector2(357, 277), Vector2(233, 277)]
		quad = []
		for e in ed:
			quad.append(Vector2(src.position.x + e.x * sc.x, y0 + e.y * sc.y))
		VIS = [Vector2(0, quad[0].x), Vector2(quad[2].x, 1438)]

	## Ruang tangga ikut diwarnai lobi (lantai & dinding menyambung), badan tangga dibiarkan.
	func _stair_col(space: bool, c: Color) -> void:
		var bg := Color("1f2448") if space else c.lightened(0.62)
		var yb := fy + 18.0
		var q0: Vector2 = quad[0]; var q1: Vector2 = quad[1]; var q2: Vector2 = quad[2]; var q3: Vector2 = quad[3]
		draw_rect(Rect2(L1 - 4, y0, q0.x - L1 + 4, yb - y0), bg)
		draw_colored_polygon(PackedVector2Array([q1, Vector2(R0 + 4, y0), Vector2(R0 + 4, yb), Vector2(q2.x, yb), q2]), bg)
		draw_rect(Rect2(q3.x, q3.y, q2.x - q3.x, yb - q3.y), bg)
		draw_rect(Rect2(L1 - 4, q3.y, R0 - L1 + 8, yb - q3.y), Color("3b3f52") if space else Color("cfc6b8"))
		draw_line(Vector2(L1 - 4, q3.y), Vector2(R0 + 4, q3.y), Color(0, 0, 0, 0.15), 3)
		draw_rect(Rect2(L1 - 4, y0, R0 - L1 + 8, 16), c.darkened(0.2))
		draw_line(Vector2(L1, y0), Vector2(R0, y0), INK, 4)
		draw_line(Vector2(L1, yb), Vector2(R0, yb), INK, 4)

	## Area di luar gedung (kiri & kanan): langit + jembatan layang yang menyambung ke dalam.
	func _outside(space: bool, k: String) -> void:
		for reg in [Vector2(0, L0), Vector2(R1, 1438)]:
			var w: float = reg.y - reg.x
			if w <= 0: continue
			var r := Rect2(reg.x, y0, w, fy - y0 + 18)
			draw_rect(r, Color("1f2448") if space else SKY)
			if space:
				for i in range(4):
					draw_circle(Vector2(reg.x + fmod(i * 47.0, w), y0 + 40 + i * 70), 2.5, Color.WHITE)
			elif k == "Helipad":
				draw_circle(Vector2(reg.x + w * 0.5 + sin(t * 0.2) * 20, y0 + 120), 22, Color(1, 1, 1, 0.8))
			# jembatan layang + tiang penyangga
			if k != "Helipad":
				draw_rect(Rect2(reg.x, fy - 40, w, 58), Color("8c8f94"))
				draw_line(Vector2(reg.x, fy + 18), Vector2(reg.y, fy + 18), INK, 3)
				draw_rect(Rect2(reg.x, fy - 52, w, 12), Color("b9bcc0"))
				for px in range(int(reg.x) + 30, int(reg.y), 160):
					draw_rect(Rect2(px, fy + 18, 22, 260), Color("a8abaf"))
					draw_rect(Rect2(px, fy + 18, 22, 260), INK, false, 2)

	## Gambar persegi panjang terpotong pada area terlihat (luar + dalam, kecuali kolom tangga).
	func _clip_rect(r: Rect2, col: Color) -> void:
		for v in VIS:
			var q := r.intersection(Rect2(v.x, y0 - 400, v.y - v.x, 1200))
			if q.size.x > 0: draw_rect(q, col)

	func _visible_x(x: float, half: float) -> bool:
		for v in VIS:
			if x - half > v.x and x + half < v.y: return true
		return false

	# ---------- bagian umum ----------
	func _box(r: Rect2, col: Color, bw := 3.0) -> void:
		draw_rect(r, col)
		draw_rect(r, INK, false, bw)

	func _car(p: Vector2, col: Color, flip := false, sc := 1.0) -> void:
		var d := -1.0 if flip else 1.0
		_box(Rect2(p + Vector2(-60, -34) * sc, Vector2(120, 30) * sc), col)
		var top := PackedVector2Array([p + Vector2(-38 * d, -34) * sc, p + Vector2(-26 * d, -58) * sc, p + Vector2(22 * d, -58) * sc, p + Vector2(40 * d, -34) * sc])
		draw_colored_polygon(top, col)
		top.append(top[0]); draw_polyline(top, INK, 3)
		draw_rect(Rect2(p + Vector2(-22, -54) * sc, Vector2(40, 16) * sc), Color("cfe8f7"))
		draw_circle(p + Vector2(-34, -4) * sc, 13 * sc, INK)
		draw_circle(p + Vector2(34, -4) * sc, 13 * sc, INK)
		draw_circle(p + Vector2(-34, -4) * sc, 5 * sc, Color("bbbbbb"))
		draw_circle(p + Vector2(34, -4) * sc, 5 * sc, Color("bbbbbb"))
		draw_rect(Rect2(p + Vector2(54 * d - 4, -28) * sc, Vector2(8, 8) * sc), Color("ffe08a"))

	func _person(p: Vector2, col: Color, sc := 1.0) -> void:
		draw_rect(Rect2(p + Vector2(-9, -50) * sc, Vector2(18, 34) * sc), col)
		draw_circle(p + Vector2(0, -60) * sc, 11 * sc, Color("f1c9a5"))
		draw_rect(Rect2(p + Vector2(-8, -16) * sc, Vector2(6, 16) * sc), Color("3b3f52"))
		draw_rect(Rect2(p + Vector2(2, -16) * sc, Vector2(6, 16) * sc), Color("3b3f52"))

	func _bench(x: float) -> void:
		_box(Rect2(x - 50, fy - 34, 100, 10), Color("b98a5c"), 2)
		draw_rect(Rect2(x - 44, fy - 24, 6, 24), INK)
		draw_rect(Rect2(x + 38, fy - 24, 6, 24), INK)

	func _plant(x: float) -> void:
		_box(Rect2(x - 16, fy - 34, 32, 34), Color("d07a4f"), 2)
		for i in range(5):
			var a := -PI / 2 + (i - 2) * 0.45
			draw_line(Vector2(x, fy - 34), Vector2(x, fy - 34) + Vector2(cos(a), sin(a)) * 40, Color("5d8a4a"), 8)

	func _lights() -> void:
		for x in [L0 + 80, L0 + 330, L0 + 580, R0 + 100, R0 + 300]:
			draw_line(Vector2(x, y0 + 16), Vector2(x, y0 + 34), INK, 2)
			draw_rect(Rect2(x - 26, y0 + 34, 52, 8), Color("fff3c4"))

	# ---------- Stasiun Kereta: kereta menembus gedung ----------
	func _kereta(c: Color) -> void:
		_lights()
		var ty := fy - 92.0
		# rel & dinding peron
		draw_rect(Rect2(0, ty + 40, 1438, 10), Color("6b6f73"))
		for i in range(0, 1438, 34):
			draw_rect(Rect2(i, ty + 50, 14, 6), Color("8a6a4a"))
		draw_rect(Rect2(L0, fy - 40, R1 - L0, 8), Color("f2c14e"))
		# kereta: datang dari kiri, berhenti, lalu lanjut ke kanan
		var cyc := fmod(t, 16.0)
		var x := 0.0
		if cyc < 4.0: x = lerpf(-1500.0, 120.0, ease(cyc / 4.0, 0.4))
		elif cyc < 9.0: x = 120.0
		else: x = lerpf(120.0, 2700.0, ease((cyc - 9.0) / 7.0, 2.2))
		var cars := 4
		for i in range(cars):
			var cx := L0 + x - i * 330.0
			for reg in VIS:
				var body := Rect2(cx, ty - 110, 320, 140).intersection(Rect2(reg.x, y0, reg.y - reg.x, 400))
				if body.size.x <= 0: continue
				draw_rect(body, Color("eef2f5"))
				var stripe := Rect2(cx, ty - 20, 320, 16).intersection(body)
				if stripe.size.x > 0: draw_rect(stripe, c)
				for wdx in range(4):
					var wr := Rect2(cx + 22 + wdx * 74, ty - 92, 54, 44).intersection(body)
					if wr.size.x > 0: draw_rect(wr, Color("8fb9d6"))
				var door := Rect2(cx + 140, ty - 92, 40, 106).intersection(body)
				if door.size.x > 0 and cyc > 4.0 and cyc < 9.0: draw_rect(door, Color("2e3a4a"))
				draw_rect(body, INK, false, 3)
		# penumpang menunggu & bangku
		if cyc < 4.5 or cyc > 9.0:
			_person(Vector2(L0 + 260, fy - 4), Color("e07a5f"), 0.9)
			_person(Vector2(L0 + 300, fy - 4), Color("5b8e7d"), 0.9)
		_bench(R0 + 120)
		_bench(R0 + 290)
		# papan jadwal & jam
		_box(Rect2(R0 + 70, y0 + 60, 270, 70), Color("2e3a4a"))
		if font:
			draw_string(font, Vector2(R0 + 84, y0 + 92), "KRL  08:15  Tepat", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffd36b"))
			draw_string(font, Vector2(R0 + 84, y0 + 120), "Ekspres  08:30", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("9fe0a5"))
		draw_circle(Vector2(L1 - 60, y0 + 110), 30, Color.WHITE)
		draw_arc(Vector2(L1 - 60, y0 + 110), 30, 0, TAU, 24, INK, 3)
		draw_line(Vector2(L1 - 60, y0 + 110), Vector2(L1 - 60, y0 + 88), INK, 3)
		draw_line(Vector2(L1 - 60, y0 + 110), Vector2(L1 - 60, y0 + 110) + Vector2(cos(t * 0.5), sin(t * 0.5)) * 18, INK, 3)

	# ---------- Lobi Parkiran ----------
	func _parkir(c: Color) -> void:
		_lights()
		var cols := [Color("e0533d"), Color("3a6fb0"), Color("f2c14e"), Color("5fae4f"), Color("eceff3")]
		# jalan masuk dari jembatan layang di luar (kiri)
		draw_rect(Rect2(0, fy - 40, L0 + 20, 58), Color("6b6f73"))
		for i in range(4):
			var x := L0 + 90 + i * 150
			draw_line(Vector2(x - 75, fy - 40), Vector2(x - 75, fy + 14), Color.WHITE, 4)
			if i != 2: _car(Vector2(x, fy - 2), cols[i], i % 2 == 1, 0.95)
		draw_line(Vector2(L0 + 90 + 4 * 150 - 75, fy - 40), Vector2(L0 + 90 + 4 * 150 - 75, fy + 14), Color.WHITE, 4)
		# mobil masuk ke slot kosong
		var cyc := fmod(t, 12.0)
		var px := L0 + 390.0
		var mx := px
		if cyc < 4.0: mx = lerpf(-160.0, px, ease(cyc / 4.0, 0.5))
		elif cyc >= 9.0: mx = lerpf(px, -160.0, ease(clampf((cyc - 9.0) / 3.0, 0, 1), 2.0))
		if _visible_x(mx, 60):
			_car(Vector2(mx, fy - 2), cols[4], cyc >= 9.0, 0.95)
		# pos tiket + palang
		_box(Rect2(R0 + 220, fy - 150, 110, 150), Color("eceff3"))
		_box(Rect2(R0 + 236, fy - 130, 78, 46), Color("8fb9d6"))
		if font: draw_string(font, Vector2(R0 + 228, fy - 160), "P · TIKET", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, INK)
		var a := -1.3 * clampf(sin(t * 0.8) * 2.0, 0.0, 1.0)
		draw_line(Vector2(R0 + 210, fy - 70), Vector2(R0 + 210, fy - 70) + Vector2(-cos(a), sin(a)) * 180, Color("e0533d"), 10)
		draw_line(Vector2(R0 + 210, fy - 70), Vector2(R0 + 210, fy - 70) + Vector2(-cos(a), sin(a)) * 180, Color.WHITE, 3)
		_plant(R1 - 40)
		# panah jalur
		for i in range(3):
			var ax := R0 + 40 + i * 50 + fmod(t * 30.0, 50.0)
			draw_colored_polygon(PackedVector2Array([Vector2(ax, fy + 2), Vector2(ax + 22, fy + 8), Vector2(ax, fy + 14)]), Color.WHITE)

	# ---------- Gerbang Tol ----------
	func _tol(c: Color) -> void:
		_lights()
		draw_rect(Rect2(0, fy - 40, 1438, 58), Color("6b6f73"))
		for reg in [Vector2(0, 1438)]:
			var x: float = reg.x
			while x < reg.y:
				draw_rect(Rect2(x, fy - 12, minf(40.0, reg.y - x), 6), Color.WHITE)
				x += 80
		# dua gardu tol
		for i in range(2):
			var gx := L0 + 200 + i * 300
			_box(Rect2(gx - 40, fy - 200, 80, 160), Color("eceff3"))
			_box(Rect2(gx - 30, fy - 180, 60, 50), Color("8fb9d6"))
			_box(Rect2(gx - 70, fy - 236, 140, 36), c)
			if font: draw_string(font, Vector2(gx - 70, fy - 210), "e-TOL" if i == 0 else "TUNAI", HORIZONTAL_ALIGNMENT_CENTER, 140, 24, Color.WHITE)
			var open := clampf(sin(t * 0.9 + i * 2.0) * 2.0, 0.0, 1.0)
			var a := -1.3 * open
			draw_line(Vector2(gx + 44, fy - 70), Vector2(gx + 44, fy - 70) + Vector2(cos(a), sin(a)) * 120, Color("e0533d"), 9)
		# mobil lewat terus-menerus
		for i in range(3):
			var x2 := fmod(t * 160.0 + i * 560.0, 1800.0) - 150.0
			if x2 > -80 and x2 < 1520:
				_car(Vector2(x2, fy + 6), [Color("3a6fb0"), Color("f2c14e"), Color("e0533d")][i], false, 0.85)
		_box(Rect2(R0 + 80, y0 + 60, 250, 70), Color("2f7d4f"))
		if font: draw_string(font, Vector2(R0 + 80, y0 + 105), "TOL LANGIT  Rp 12rb", HORIZONTAL_ALIGNMENT_CENTER, 250, 24, Color.WHITE)

	# ---------- Helipad ----------
	func _heli(c: Color) -> void:
		_lights()
		# dinding kaca kanan: langit + landasan
		var sky := Rect2(R0 + 8, y0 + 20, R1 - R0 - 16, fy - y0 - 60)
		draw_rect(sky, Color("9fc7e6"))
		for i in range(3):
			draw_circle(Vector2(R0 + 60 + i * 110 + fmod(t * 8.0, 50.0), y0 + 80 + (i % 2) * 30), 24, Color(1, 1, 1, 0.8))
		draw_rect(Rect2(R0, fy - 40, R1 - R0, 58), Color("8c8f94"))
		var pc := Vector2((R0 + R1) / 2.0, fy - 14)
		draw_ellipse_h(pc, 150, 22, Color("d6d6d6"))
		var ring := PackedVector2Array()
		for i in range(33):
			var an := TAU * i / 32.0
			ring.append(pc + Vector2(cos(an) * 120, sin(an) * 16))
		draw_polyline(ring, Color("f2c14e"), 4)
		if font: draw_string(font, pc + Vector2(-16, 12), "H", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("e0533d"))
		var cyc := fmod(t, 14.0)
		var hy := 0.0
		if cyc < 4.0: hy = lerpf(-260.0, 0.0, ease(cyc / 4.0, 0.4))
		elif cyc < 9.0: hy = 0.0
		else: hy = lerpf(0.0, -320.0, ease((cyc - 9.0) / 5.0, 2.0))
		var hp := pc + Vector2(0, -40 + hy)
		if hp.y > y0 + 40:
			_box(Rect2(hp + Vector2(-60, -50), Vector2(120, 56)), c)
			_box(Rect2(hp + Vector2(-34, -42), Vector2(44, 28)), Color("cfe8f7"), 2)
			draw_line(hp + Vector2(60, -30), hp + Vector2(130, -36), c, 10)
			draw_line(hp + Vector2(-50, 12), hp + Vector2(50, 12), INK, 4)
			var a2 := t * (14.0 if cyc < 4.0 or cyc > 8.0 else 3.0)
			draw_line(hp + Vector2(-120 * cos(a2), -60), hp + Vector2(120 * cos(a2), -60), INK, 5)
			draw_line(hp + Vector2(0, -50), hp + Vector2(0, -60), INK, 4)
		# windsock
		draw_line(Vector2(R1 - 40, fy - 40), Vector2(R1 - 40, y0 + 120), INK, 4)
		draw_colored_polygon(PackedVector2Array([Vector2(R1 - 40, y0 + 120), Vector2(R1 - 100, y0 + 128 + sin(t * 3.0) * 6), Vector2(R1 - 100, y0 + 146 + sin(t * 3.0) * 6), Vector2(R1 - 40, y0 + 144)]), Color("f28c3a"))
		# ruang tunggu kiri
		_bench(L0 + 120); _bench(L0 + 260); _bench(L0 + 400)
		_person(Vector2(L0 + 110, fy - 30), Color("8a6ad9"), 0.85)
		_box(Rect2(L0 + 390, y0 + 100, 240, 90), Color("2e3a4a"))
		if font:
			draw_string(font, Vector2(L0 + 404, y0 + 136), "Heli 01 · Bandara", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffd36b"))
			draw_string(font, Vector2(L0 + 404, y0 + 168), "Heli 02 · Puncak", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("9fe0a5"))
		_plant(L1 - 40)

	# ---------- Stasiun Luar Angkasa ----------
	func _roket(c: Color) -> void:
		for reg in [Vector2(L0, L1), Vector2(R0, R1)]:
			for i in range(14):
				var sx: float = reg.x + fmod(i * 97.0, reg.y - reg.x)
				var sy := y0 + 30 + fmod(i * 61.0, fy - y0 - 90)
				draw_circle(Vector2(sx, sy), 2.0 + (1.0 if fmod(t + i, 2.0) < 1.0 else 0.0), Color.WHITE)
		draw_circle(Vector2(R1 - 90, y0 + 110), 44, Color("e5a96b"))
		draw_arc(Vector2(R1 - 90, y0 + 110), 64, -0.3, PI + 0.3, 24, Color("f1d3a8"), 5)
		# landasan + menara
		var rx := L0 + 330.0
		_box(Rect2(rx - 120, fy - 40, 240, 30), Color("6b6f73"))
		draw_rect(Rect2(rx + 90, y0 + 90, 16, fy - y0 - 130), Color("c9ced2"))
		for i in range(6):
			draw_line(Vector2(rx + 90, y0 + 100 + i * 40), Vector2(rx + 106, y0 + 120 + i * 40), INK, 2)
		var cyc := fmod(t, 15.0)
		var ry := 0.0
		var a := 1.0
		if cyc > 8.0: ry = -pow((cyc - 8.0) * 1.6, 2.2) * 10.0
		if cyc > 13.0: a = 0.0
		if cyc < 1.0: a = cyc
		var base := Vector2(rx, fy - 40 + ry)
		if a > 0.0 and base.y - 220 > y0 - 40:
			var col := Color(1, 1, 1, a)
			draw_colored_polygon(PackedVector2Array([base + Vector2(0, -230), base + Vector2(30, -170), base + Vector2(-30, -170)]), c * col)
			draw_rect(Rect2(base + Vector2(-30, -170), Vector2(60, 150)), Color("eceff3") * col)
			draw_circle(base + Vector2(0, -130), 14, Color("8fb9d6") * col)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-30, -60), base + Vector2(-56, -10), base + Vector2(-30, -20)]), c * col)
			draw_colored_polygon(PackedVector2Array([base + Vector2(30, -60), base + Vector2(56, -10), base + Vector2(30, -20)]), c * col)
			if cyc > 7.0:
				var fl := 40.0 + sin(t * 30.0) * 10.0
				draw_colored_polygon(PackedVector2Array([base + Vector2(-20, -20), base + Vector2(20, -20), base + Vector2(0, -20 + fl + 30)]), Color("f2a33a"))
				for i in range(4):
					draw_circle(Vector2(rx - 120 + i * 80, fy - 50) + Vector2(sin(t * 5 + i) * 10, 0), 30 + (cyc - 7.0) * 4, Color(1, 1, 1, 0.35))
		# panel kendali di kanan
		for i in range(3):
			var px := R0 + 40 + i * 110
			_box(Rect2(px, fy - 120, 90, 80), Color("2e3a4a"))
			for j in range(6):
				var on := fmod(t * 2.0 + i + j * 0.7, 2.0) < 1.0
				draw_circle(Vector2(px + 16 + (j % 3) * 28, fy - 100 + (j / 3) * 26), 7, Color("5fd38a") if on else Color("e0533d"))
		if font: draw_string(font, Vector2(R0 + 40, fy - 140), "T-%02d" % int(maxf(0.0, 8.0 - cyc)), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("ffd36b"))

	func draw_ellipse_h(cn: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in range(24):
			var an := TAU * i / 24.0
			pts.append(cn + Vector2(cos(an) * rx, sin(an) * ry))
		draw_colored_polygon(pts, col)

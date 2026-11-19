extends Node2D
## Kost Simulator — logika utama: waktu, ekonomi, penyewa, NPC, cahaya, input.

const SAVE_PATH := "user://kost_save.json"
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
	_build_world()
	_setup_music()
	ui = Ui.new()
	add_child(ui)
	ui.setup(self, art, font, font_m)
	var args := OS.get_cmdline_user_args()
	if not args.has("--fresh"):
		S = _load_game()
	if S.is_empty():
		_new_game()
	_refresh_world()
	_sync_npcs()
	_refresh_cargo()
	ui.update_hud()
	if not S.get("seen", false):
		ui.open_sheet("welcome")
	_handle_cli(args)


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
	# Lantai tambahan (5-8): salinan lantai 3 yang ditumpuk ke atas, lalu atap.
	for f in range(5, D.TOP_FLOOR + 1):
		_sprite(bld, Rect2(0, 627, D.IW, D.EXTRA_PITCH), Vector2(0, 242 - (f - 4) * D.EXTRA_PITCH))
	_sprite(bld, Rect2(0, 0, D.IW, 242), Vector2(0, D.BUILDING_TOP))
	for f in range(1, D.TOP_FLOOR + 1):
		var src := D.rect_of("1S") if f % 2 == 1 else D.rect_of("3S")
		var dst := D.rect_of("%dS" % f)
		var sp := _sprite(bld, src, dst.position)
		sp.scale = dst.size / src.size
	var rooms_root := Node2D.new()
	bld.add_child(rooms_root)
	for id in D.ROOMS:
		var fx := RoomFx.new()
		rooms_root.add_child(fx)
		fx.setup(self, id, shell_tex, null, font)
		room_fx[id] = fx
	for f in range(1, D.TOP_FLOOR + 1):
		var sp := Sprite2D.new()
		sp.centered = false
		var fr := D.facil_rect(f)
		sp.position = fr.position
		sp.visible = false
		bld.add_child(sp)
		facil_sp[f] = sp
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
	npc_lobby = Node2D.new()
	npc_lobby.y_sort_enabled = true
	lobby_root.add_child(npc_lobby)
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
	for id in D.ROOMS:
		var r := D.rect_of(id)
		var arr := []
		for l in D.LAMPS[id]:
			arr.append(_mk_light(Vector2(r.position.x + l[0] * r.size.x, r.position.y + l[1] * r.size.y), l[2], bld))
		room_lights[id] = arr
	for f in range(1, D.TOP_FLOOR + 1):
		var fr := D.facil_rect(f)
		var pl := _mk_light(fr.position + Vector2(fr.size.x / 2.0, 70), 95, bld)
		facil_lights[f] = pl
	for l in D.STAIR_LAMPS:
		fixed_lights.append(_mk_light(Vector2(l[0], l[1]), l[2], bld))
	for l in D.GROUND_LAMPS:
		fixed_lights.append(_mk_light(Vector2(l[0], l[1]), l[2], lobby_root))
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
	npc_lobby.add_child(recep_art)


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


func _refresh_world() -> void:
	for id in D.ROOMS:
		room_fx[id].dekor = dekor
		room_fx[id].building = job_for(id, "build") != {}
	_refresh_facil()
	for id in D.ROOMS:
		pass
		var ev_id := event_at(id)
		S.rooms[id]["_ev"] = "" if ev_id.is_empty() else str(ev_id.type)
		room_fx[id].refresh(S.rooms[id], int(S.lvl), build_cost(), font)
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
	for id in D.ROOMS:
		var r: Dictionary = S.rooms[id]
		var on: bool = gl > 0.02 and r.built and r.tenant != null and r.furn.has("lampu") and str(r.broken) != "Lampu mati" and presence(r.tenant) != "away"
		for pl in room_lights[id]:
			pl.enabled = on
			pl.energy = gl * 1.15
	for f in facil_lights:
		facil_lights[f].enabled = gl > 0.02 and S.facil.has(str(f))
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
		"total": {"rent": 0.0, "served": 0}, "seen": false, "jobs": [], "orders": [], "cargo": [], "events": [], "prevent": {}, "facil": {}}
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
	for j in D.JOBS:
		if int(D.JOBS[j].min) <= lv:
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
		"stay": 0, "happy": randi_range(62, 80), "wait": 0}


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(S))


func _load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY or not d.has("rooms"):
		return {}
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
		d.jobs = d.jobs.filter(func(j): return D.ROOMS.has(j.room))
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
	if not d.has("cargo"): d.cargo = []
	for o in d.orders: o.t = float(o.t)
	for j in d.jobs:
		j.t = float(j.t)
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
	return c


func update_tier(r: Dictionary) -> void:
	var c := comfort(r)
	r.lv = 1 if c < 5.0 else (2 if c < 10.0 else 3)


func rent_of(r: Dictionary) -> float:
	var v: float = (30000.0 + comfort(r) * 9000.0) * D.PRICE[int(S.price)].m * (1.0 + 0.04 * fac_count() + (0.05 if has_facil("cafe") else 0.0))
	return round(v / 1000.0) * 1000.0


func can_rent(id: String) -> bool:
	var r: Dictionary = S.rooms[id]
	return r.built and r.tenant == null and r.get("furn", {}).has("kasur")


func build_cost() -> float:
	var n := 0
	for id in D.ROOMS:
		if S.rooms[id].built:
			n += 1
	return 600000.0 + n * 250000.0


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
		for f in D.FLOOR_LV:
			if D.FLOOR_LV[f] == int(S.lvl):
				ui.toast("Lantai %d terbuka untuk dibangun" % f, "gold")
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
func _process(dt: float) -> void:
	var sp := int(S.speed)
	if not ui.is_welcome_open() and sp > 0:
		_acc += dt
		var guard := 0
		while _acc >= 0.1 and guard < 10:
			_acc -= 0.1
			guard += 1
			for i in range(sp):
				_step()
	_separate_npcs()
	_chat_tick(dt)
	if sp > 0:
		for n in npcs.values().duplicate():
			if is_instance_valid(n):
				n.speed_mul = 1.0 + (sp - 1) * 0.5
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
	if _save_acc > 10.0:
		_save_acc = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if not S.is_empty():
			save_game()


func _step() -> void:
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


func _spawn_cand() -> void:
	var base := 330.0 * (1.4 - float(S.rep) * 0.15) * (0.7 if S.staff.get("resep", false) else 1.0) \
		* float(D.PRICE[int(S.price)].c) * pow(0.96, fac_count()) * (0.8 if has_facil("tunggu") else 1.0)
	S.next_cand = base * randf_range(0.7, 1.3)
	if S.queue.size() >= 1:
		return
	var p := gen_person(["p", "l"].pick_random())
	S.queue.append(p)
	ui.toast("Calon penyewa datang: %s (%s)" % [p.name, p.job])
	dirty = true


func _hourly() -> void:
	_tick_events_hour()
	var h := int(S.min) / 60
	for id in D.ROOMS:
		var r: Dictionary = S.rooms[id]
		if not r.built:
			continue
		r.clean = clampf(float(r.clean) - (0.6 if r.tenant != null else 0.08) * (0.85 if S.fac.has("jemur") else 1.0) * (0.75 if has_facil("laundry") else 1.0), 0, 100)
		if r.tenant != null and str(r.broken) == "" and randf() < 0.003:
			r.broken = D.ISSUES.keys().pick_random()
			ui.toast("%s di Kamar %s!" % [r.broken, D.room_name(id)], "bad")
	var pat := (72 if S.staff.get("resep", false) else 48) + (36 if has_facil("tunggu") else 0)
	var keep := []
	for p in S.queue:
		p.wait = int(p.wait) + 1
		if int(p.wait) > pat:
			ui.toast("%s lelah menunggu dan pergi" % p.name)
		else:
			keep.append(p)
	S.queue = keep
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
		if float(t.happy) < 30 and randf() < 0.4:
			float_at(id, "Telat bayar", Color("b5543c"))
			continue
		var a := rent_of(r)
		tot += a
		if npcs.has(t.id) and float(t.happy) > 80 and presence(t) != "away" and randf() < 0.5:
			npcs[t.id].react("happy", 1.8)
		float_at(id, "+" + D.short(a), Color("2f7a2a"))
	if tot > 0:
		S.money = float(S.money) + tot
		S.today.rent = float(S.today.rent) + tot
		S.total.rent = float(S.total.rent) + tot
		add_xp(round(tot / 2500.0))


func _pay_salary() -> void:
	var s := 0.0
	for k in S.staff:
		if S.staff[k]:
			s += D.STAFF[k].sal
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
	"barista": [["Kopi susu satu ya, Kak!", "Siap, ditunggu sebentar.", "Wangi banget kopinya.", "Gula arennya asli lho."]],
	"kantin": [["Bu, nasi goreng satu.", "Pedas atau nggak, Nak?", "Pedas dong, Bu!", "Siap, sebentar ya."]],
	"laundry": [["Mas, titip cucian ya.", "Oke, besok sore beres.", "Sekalian disetrika ya, Mas.", "Beres!"]],
	"keeper": [
		["Mbak, paketku udah datang?", "Sudah, ada di meja depan.", "Makasih, Mbak!"],
		["Mbak, airnya lancar kan?", "Aman, baru dicek tadi pagi.", "Sip, makasih!"],
	],
}
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
	if n == null or not is_instance_valid(n) or not n.visible: return false
	if n.kind not in ["res", "cand", "staff", "keeper"]: return false
	if n.leaving or n.fade_state != "" or n.chat_with != null: return false
	if n.pose == "lie" or n.pose == "climb": return false
	return float(_chat_cd.get(n.id, 0.0)) <= _clock


func _idle(n: Npc) -> bool:
	return n.route.size() == 0 and (n.work.is_empty() or str(n.work.get("pose", "")) in ["stand", "counter", "sit"])


func _chat_tick(dt: float) -> void:
	_clock += dt
	for n in npcs.values():
		n.chat_tick(dt)
	for c in _convos.duplicate():
		var a: Npc = c.n[0]
		var b: Npc = c.n[1]
		if not is_instance_valid(a) or not is_instance_valid(b) or a.leaving or b.leaving or a.scene != b.scene \
				or (c.long and (a.route.size() > 0 or b.route.size() > 0)):
			_end_chat(c)
			continue
		c.t -= dt
		if c.t > 0.0: continue
		if c.i >= c.lines.size():
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
			var both_idle: bool = _idle(a) and _idle(b)
			if both_idle and randf() < 0.35 and _convos.filter(func(c): return c.long).size() < 3:
				_start_long(a, b)
			elif not both_idle and dist < near * 0.6 and randf() < 0.5:
				_start_chat(a, b, [_greet(), CHAT_REPLY[randi() % CHAT_REPLY.size()]], false)
			break


func _start_long(a: Npc, b: Npc) -> void:
	var key := "res"
	for m in [a, b]:
		if m.kind == "staff" and CHAT_LONG.has(m.role): key = m.role
		elif m.kind == "keeper": key = "keeper"
	if key == "res" and a.kind == "cand" and b.kind == "cand": key = "cand"
	# Pembeli/penghuni yang memulai, petugas yang menjawab.
	if a.kind in ["staff", "keeper"]:
		var t := a
		a = b
		b = t
	var sets: Array = CHAT_LONG[key]
	var lines: Array = sets[randi() % sets.size()]
	_start_chat(a, b, lines, true)


func _start_chat(a: Npc, b: Npc, lines: Array, long: bool) -> void:
	a.chat_with = b
	b.chat_with = a
	_convos.append({"n": [a, b], "lines": lines, "i": 0, "t": 0.0, "long": long})


func _end_chat(c: Dictionary) -> void:
	_convos.erase(c)
	for m in c.n:
		if is_instance_valid(m):
			m.chat_with = null
			_chat_cd[m.id] = _clock + (45.0 if c.long else 14.0) + randf() * 20.0


# ================= Ruang fasilitas =================
func has_facil(k: String) -> bool:
	for f in S.facil:
		if S.facil[f] == k: return true
	return false


func facil_floor(k: String) -> int:
	for f in S.facil:
		if S.facil[f] == k: return int(f)
	return 0


func _refresh_facil() -> void:
	for f in facil_sp:
		var sp: Sprite2D = facil_sp[f]
		var k: String = S.facil.get(str(f), "")
		var j := job_for("S%d" % f, "fbuild")
		if j.is_empty() and k == "":
			sp.visible = false
			continue
		var key: String = k if k != "" else str(j.item)
		var tex: Texture2D = load("res://assets/facil/%s.png" % key)
		sp.texture = tex
		var fr := D.facil_draw_rect(int(f))
		sp.position = fr.position
		sp.scale = fr.size / tex.get_size()
		sp.visible = true
		sp.modulate = Color(1, 1, 1, 1) if k != "" else Color(1, 1, 1, 0.35)


func facil_ok(f: int, k: String) -> String:
	var fc: Dictionary = D.FACIL[k]
	if int(S.lvl) < int(fc.lv): return "%s terbuka di Level %d" % [fc.n, int(fc.lv)]
	if int(S.lvl) < int(D.FLOOR_LV[f]): return "Lantai %d terbuka di Level %d" % [f, int(D.FLOOR_LV[f])]
	if S.facil.has(str(f)) or job_for("S%d" % f, "fbuild") != {}: return "Sisi tangga lantai %d sudah terpakai" % f
	if has_facil(k): return "%s sudah ada di kost" % fc.n
	for j in S.jobs:
		if j.type == "fbuild" and j.item == k: return "%s sedang dibangun" % fc.n
	if float(S.money) < float(fc.cost): return "Uang belum cukup (%s)" % D.rp(fc.cost)
	return ""


## Lantai terendah yang sisi tangganya masih kosong & sudah terbuka.
func free_facil_floor() -> int:
	for f in range(1, D.TOP_FLOOR + 1):
		if int(S.lvl) < int(D.FLOOR_LV[f]): continue
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
	for f in S.facil:
		var fc: Dictionary = D.FACIL[S.facil[f]]
		var mult := 1.0
		if fc.has("staff"):
			var on: bool = S.staff.get(fc.staff, false)
			if S.facil[f] == "laundry": mult = 2.0 if on else 1.0
			else: mult = 1.0 if on else 0.0
		inc += float(fc.inc) * mult * occ
	if has_facil("rooftop"): S.rep = clampf(float(S.rep) + 0.02, 1, 5)
	if has_facil("mushola"): S.rep = clampf(float(S.rep) + 0.01, 1, 5)
	if inc > 0:
		S.money = float(S.money) + inc
		S.today.rent = float(S.today.rent) + inc
		ui.toast("Pemasukan fasilitas: %s" % D.rp(inc), "gold")


func facil_happy() -> int:
	var h := 0
	for f in S.facil: h += int(D.FACIL[S.facil[f]].happy)
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
		if randf() > float(ev.p) * pmul: continue
		var room := ""
		if ev.scope == "room":
			var pool := []
			for id in D.ROOMS:
				var r: Dictionary = S.rooms[id]
				if not r.built or not event_at(id).is_empty(): continue
				if ev.get("need", "") == "tenant" and r.tenant == null: continue
				pool.append(id)
			if pool.is_empty(): continue
			room = pool.pick_random()
		var e := {"id": "e%d" % randi(), "type": k, "room": room, "age": 0, "auto": -1}
		S.events.append(e)
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
		var k := 1.0 + 0.3 * int(e.age)
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
		if float(r.clean) < 45: d -= 6
		if float(r.clean) < 20: d -= 10
		if str(r.broken) != "": d -= 10
		if int(r.lv) < int(t.pref): d -= 3
		if int(r.lv) > int(t.pref): d += 1
		t.happy = clampf(float(t.happy) + d, 0, 100)
		t.stay = int(t.stay) + 1
		if float(t.happy) < 15:
			ui.toast("%s pindah karena tidak betah di Kamar %s" % [t.name, D.room_name(id)], "bad")
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
				r.tenant = null
				S.total.served = int(S.total.served) + 1
				add_xp(40)
				S.rep = clampf(float(S.rep) + 0.1, 1, 5)
				continue
		if float(t.happy) > 88 and randf() < 0.04:
			S.money = float(S.money) + 50000
			S.today.other = float(S.today.other) - 50000
			ui.toast("%s memberi oleh-oleh senilai Rp 50.000" % t.name, "gold")
		sum_h += float(t.happy)
		n += 1
	if n > 0:
		var target := 1.0 + 4.0 * (sum_h / n) / 100.0
		S.rep = clampf(float(S.rep) * 0.75 + target * 0.25, 1, 5)
	if not S.staff.get("satpam", false) and occ >= 3 and randf() < (0.04 if S.fac.has("cctv") else 0.09):
		var loss := minf(maxf(float(S.money) * 0.05, 100000), 600000)
		spend(loss, "other")
		ui.toast("Ada pencurian! Hilang %s. Pertimbangkan Satpam/CCTV." % D.rp(loss), "bad")
	var td: Dictionary = S.today
	var net := float(td.rent) - float(td.salary) - float(td.util) - float(td.other)
	S.last = {"day": int(S.day), "rent": td.rent, "salary": td.salary, "util": td.util, "other": td.other, "net": net}
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
		var slot := mini(int(w.slot), 3)
		return {"key": "q%d" % slot, "scene": "lobby", "spot": Vector2(D.QUEUE_X[slot], D.LOBBY_Y), "pose": "stand"}
	var pr := presence(w.p)
	if pr == "away":
		return {"key": "out"}
	var R: String = w.room
	var sp: Dictionary = D.SPOT[R]
	var furn: Dictionary = S.rooms[R].get("furn", {})
	if pr == "sit" or pr == "work":
		var hr := int(S.min) / 60
		for fk in S.facil:
			var fc: Dictionary = D.FACIL[S.facil[fk]]
			if hr in fc.visit and absi(("%s%d" % [w.p.id, hr]).hash()) % 100 < 45:
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
	var p := D.furn_pos(R, "kasur", lv)
	return Vector2(p.x + tex.get_width() * 0.5, p.y + tex.get_height() * 0.62)


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
	n.plan("lobby", Vector2(D.OUT_X, D.LOBBY_Y), "stand", func(x: Npc): _remove_npc(x))


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
	var list: Array = []
	for n in npcs.values():
		if is_instance_valid(n) and n.fade_state == "" and n.visible:
			list.append(n)
	for n in list:
		n.blocked = false
		if not n.is_moving():
			continue
		var d: Vector2 = n.move_dir()
		if d == Vector2.ZERO:
			continue
		var gap := 95.0 if n.scene == "lobby" else 48.0
		for o in list:
			if o == n or o.scene != n.scene:
				continue
			var rel: Vector2 = o.position - n.position
			var ahead := rel.dot(d)
			var side := absf(rel.cross(d))
			if ahead > 0.0 and ahead < gap and side < gap * 0.6:
				# Hanya antre di belakang orang yang berjalan searah (yang diam/berlawanan dilewati).
				if not o.is_moving() or o.move_dir().dot(d) < 0.5:
					continue
				if o.blocked and str(o.id) > str(n.id):
					continue
				n.blocked = true
				break


## NPC di lobi digambar di lapisan lobi (tetap), selain itu di dalam gedung (ikut scroll).
func _reparent_npcs() -> void:
	for n in npcs.values():
		if not is_instance_valid(n): continue
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


func _sync_npcs() -> void:
	var want := {}
	var q: Array = S.queue
	for i in range(q.size()):
		want[q[i].id] = {"kind": "cand", "p": q[i], "slot": i}
	for e in each_tenant():
		want[e[1].tenant.id] = {"kind": "res", "p": e[1].tenant, "room": e[0]}
	for nid in npcs.keys():
		var n: Npc = npcs[nid]
		if n.kind == "staff" or n.kind == "worker" or n.kind == "keeper":
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
		if n.goal_key != g.key:
			_apply_goal(n, g)
		_bubble_for(n, w)
	for pid in want:
		if not npcs.has(pid):
			var w: Dictionary = want[pid]
			var g := _goal_of(w)
			if g.key == "out":
				continue
			var n := _spawn(pid, w)
			_apply_goal(n, g)
			_bubble_for(n, w)


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
		n.set_bubble(str(w.p.name), int(w.slot) == 0)
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
		"t": float(D.WORKER["build" if type == "fbuild" else type].mins), "started": false})
	dirty = true
	_jobs_brain()


func _tick_jobs(mins: float) -> void:
	_tick_orders(mins)
	for j in S.jobs.duplicate():
		if not j.started:
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
			add_xp(40)
		"fix":
			if str(r.broken) != "":
				float_at(j.room, "Diperbaiki", Color("3f6f96"))
			r.broken = ""
		"deliver":
			r.furn[j.item] = int(j.lv)
			update_tier(r)
			if r.tenant != null:
				r.tenant.happy = clampf(float(r.tenant.happy) + 4.0 * int(j.lv), 0, 100)
			if int(j.lv) == 1:
				float_at(j.room, "+ " + D.FURN[j.item].n, Color("2f7a2a"))
				add_xp(8)
			else:
				float_at(j.room, "%s jadi %s!" % [D.FURN[j.item].n, D.FURN_LV_NAME[int(j.lv)]], Color("b07a10"))
				add_xp(12)
	var nid: String = "job-" + str(j.id)
	if npcs.has(nid):
		var n: Npc = npcs[nid]
		n.work = {}
		n.react("react", 1.6)
		if n.char_id == "kurir":
			n.art_map["walk"] = "idle"
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
const ORDER_MINS := 45.0
const BOX_SLOTS := [Vector2(455, 112), Vector2(560, 112), Vector2(665, 112), Vector2(505, 14), Vector2(610, 14), Vector2(560, -84)]


func _need_truck() -> bool:
	if not S.cargo.is_empty(): return true
	for j in S.jobs:
		if j.type == "deliver": return true
	for n in npcs.values():
		if n.char_id == "kurir": return true
	return false


## Gambar kotak pesanan di bak pickup (anak dari sprite truk, di belakang dinding bak).
func _refresh_cargo() -> void:
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
			ui.toast("%s sudah datang! Seret kotaknya dari pickup ke kamar." % D.FURN[o.item].n, "gold")
			_refresh_cargo()


func _truck_tick(dt: float) -> void:
	var need := _need_truck()
	var park := D.TRUCK_X - 470 * 0.72 * 1.87 * 0.5
	match truck_state:
		"gone":
			if need:
				truck_state = "coming"
				truck.visible = true
				truck.flip_h = false
				truck.position.x = -700
		"coming":
			truck.position.x = move_toward(truck.position.x, park, 900 * dt)
			truck.position.y = D.LOBBY_Y + 45 - 470 * 0.72 + sin(Time.get_ticks_msec() / 60.0) * 1.5
			if truck.position.x >= park - 0.5:
				truck_state = "parked"
				if not S.cargo.is_empty():
					ui.toast("Pickup sudah sampai. Seret kotaknya ke kamar!", "gold")
		"parked":
			truck.position.y = D.LOBBY_Y + 45 - 470 * 0.72
			if not need:
				truck_state = "going"
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
	n.art = true
	n.char_id = "penjaga"
	n.art_map = {"walk": "walk", "stand": "idle"}
	npcs["keeper"] = n
	n.plan("S%d" % f, Vector2(773 + randf_range(-40, 40), D.FEET[f]), "stand", func(m: Npc):
		m.work = {"t": randf_range(3.0, 6.0), "pose": "stand", "fn": func(k: Npc):
			k.plan("lobby", Vector2(1150, D.LOBBY_Y), "stand", func(z: Npc): _remove_npc(z))})


func _jobs_brain() -> void:
	for n in npcs.values():
		if n.kind == "worker":
			return
	for j in S.jobs:
		var nid: String = "job-" + str(j.id)
		if npcs.has(nid):
			continue
		if j.type == "deliver" and truck_state != "parked":
			return
		var cfg: Dictionary = D.WORKER["build" if j.type == "fbuild" else j.type]
		var n := Npc.new()
		npc_lobby.add_child(n)
		var start := Vector2(D.TRUCK_X + 120, D.LOBBY_Y) if j.type == "deliver" else Vector2(D.OUT_X, D.LOBBY_Y)
		n.setup(nid, "worker", D.STAFF_LOOK.teknisi, start, font)
		n.art = true
		n.char_id = cfg.char
		n.art_map = cfg.map.duplicate()

		n.target = j.room
		npcs[nid] = n
		var jj: Dictionary = j
		n.plan(j.room, _spot_in(j.room), "job", func(m: Npc):
			jj.started = true
			m.idle_pose = "job")
		return


func _staff_brain() -> void:
	_jobs_brain()
	for role in ["cleaner", "satpam", "teknisi", "laundry", "kantin", "barista"]:
		var on: bool = S.staff.get(role, false)
		if D.STAFF[role].has("need") and not has_facil(D.STAFF[role].need):
			on = false
		var nid: String = "staff-" + role
		if on and not npcs.has(nid):
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
			elif role in ["laundry", "kantin", "barista"]:
				n.char_id = role
				n.art_map = {"walk": "walk", "stand": "happy" if role == "laundry" else "idle", "counter": "happy" if role == "laundry" else ["idle", "happy"]}
			elif role == "teknisi":
				n.char_id = "teknisi"
				n.art_map = D.WORKER.fix.map.duplicate()
				n.art_map["fix"] = ["fix", "idle"]
			n.role = role
			npcs[nid] = n
		elif not on and npcs.has(nid) and npcs[nid].goal_key != "out":
			_leave(npcs[nid])
	for n in npcs.values():
		if n.kind != "staff" or n.route.size() > 0 or not n.work.is_empty() or n.leaving or n.fade_state != "":
			continue
		match n.role:
			"cleaner":
				var R := _pick_room(n, func(r): return r.built and float(r.clean) < 75.0, func(r): return float(r.clean))
				if R != "":
					n.target = R
					n.plan(R, _spot_in(R), "sweep", func(x: Npc): x.work = {"t": 7.0, "pose": "sweep", "fn": func(y: Npc): _finish_clean(y, R)})
				else:
					_idle_staff(n)
			"teknisi":
				var R := _pick_room(n, func(r): return str(r.broken) != "" and not _fix_jobbed(r), func(_r): return 0.0)
				if R != "":
					n.target = R
					n.plan(R, _spot_in(R), "fix", func(x: Npc): x.work = {"t": 5.0, "pose": "fix", "fn": func(y: Npc): _finish_fix(y, R)})
				else:
					_idle_staff(n)
			"laundry", "kantin", "barista":
				var ff := facil_floor(D.STAFF[n.role].need)
				if ff > 0:
					n.plan("S%d" % ff, D.facil_spot(ff) + Vector2(-24 if ff % 2 == 0 else 24, -4), "counter", func(m: Npc): m.work = {"t": randf_range(20.0, 40.0), "pose": "counter"})
				else:
					_idle_staff(n)
			_:
				_idle_staff(n)


func _idle_staff(n: Npc) -> void:
	var x := randf_range(260, 1080) if n.role == "satpam" else randf_range(160, 380)
	n.plan("lobby", Vector2(x, D.LOBBY_Y), "stand", func(m: Npc): m.work = {"t": randf_range(3.0, 7.0), "pose": "stand"})


func _pick_room(self_n: Npc, filter: Callable, score: Callable) -> String:
	var claimed := {}
	for m in npcs.values():
		if m != self_n and m.target != "":
			claimed[m.target] = true
	var best := ""
	var bs := INF
	for id in D.ROOMS:
		var r: Dictionary = S.rooms[id]
		if claimed.has(id) or not filter.call(r):
			continue
		var s: float = score.call(r)
		if s < bs:
			bs = s
			best = id
	return best


func _spot_in(R: String) -> Vector2:
	if R.begins_with("S"):
		return D.facil_spot(int(R.substr(1))) + Vector2(randf_range(-40, 40), 0)
	return Vector2(float(D.CX[R[1]]) + randf_range(-80, 80), float(D.FEET[int(R[0])]))


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
			ui.toast("Tukang menuju lahan %s untuk mulai membangun" % D.room_name(arg))
		"place_furn", "upgrade_furn":
			var parts := arg.split("|")
			var rid: String = parts[0]
			var t: String = parts[1]
			var r: Dictionary = S.rooms[rid]
			if not r.built or not D.FURN_POS[rid].has(t): return
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
		"facil_build":
			var parts2 := arg.split("|")
			var ff := int(parts2[0])
			var why := facil_ok(ff, parts2[1])
			if why != "":
				ui.toast(why, "bad"); return
			spend(float(D.FACIL[parts2[1]].cost), "other")
			add_job("fbuild", "S%d" % ff, parts2[1])
			ui.toast("Tukang mulai membangun %s di lantai %d" % [D.FACIL[parts2[1]].n, ff])
			if ui.kind == "facil": ui.close_sheet()
		"event":
			var parts := arg.split("|")
			for e in S.events:
				if e.id == parts[0]:
					var o: Array = Ev.DEF[e.type].opts[int(parts[1])]
					_resolve_event(e, o[2], float(o[1]))
					break
		"buy":
			var f: Dictionary = D.FURN[arg]
			if int(S.lvl) < int(f.min): return
			if S.orders.size() + S.cargo.size() >= CARGO_MAX:
				ui.toast("Pickup sudah penuh. Antar dulu kotak yang ada.", "bad")
				return
			if float(S.money) < float(f.cost):
				ui.toast("Uang belum cukup (%s)" % D.rp(f.cost), "bad")
				return
			spend(f.cost, "other")
			S.orders.append({"item": arg, "t": ORDER_MINS})
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
			ui.toast("Teknisi dipanggil ke Kamar %s" % D.room_name(arg))
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
			_next_guest_soon()
			if S.staff.get("resep", false):
				_set_keeper("happy", 2.5)
			add_xp(10)
		"reject":
			for i in range(S.queue.size()):
				if S.queue[i].id == arg:
					ui.toast("%s ditolak dengan sopan" % S.queue[i].name)
					S.queue.remove_at(i)
					_next_guest_soon()
					break
		"hire":
			S.staff[arg] = true
			ui.toast("%s mulai bekerja!" % D.STAFF[arg].n, "gold")
		"fire":
			S.staff.erase(arg)
			ui.toast("%s diberhentikan" % D.STAFF[arg].n)
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
			S.speed = int(arg)
		"reset":
			_new_game()
			ui.confirm = ""
			ui.open_sheet("welcome")
			ui.toast("Game dimulai ulang")
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


func room_at(p: Vector2) -> String:
	if p.y >= D.LOBBY_TOP or p.y < 200:
		return ""
	var q := to_bld(p)
	for id in D.ROOMS:
		if D.rect_of(id).has_point(q):
			return id
	return ""


## Mulai menyeret: kind = "guest" (id calon penyewa) | "furn" (tipe perabot) | "build".
func begin_drag(kind: String, item: String, start: Vector2, active: bool) -> void:
	drag = {"kind": kind, "item": item, "start": start, "active": false}
	if active:
		_activate_drag()


func _activate_drag() -> void:
	drag.active = true
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
	for id in D.ROOMS:
		out[id] = _drop_ok(id) == ""
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
			if not D.FURN_POS[id].has(t): return "Kamar %s tidak punya tempat untuk %s" % [D.room_name(id), D.FURN[t].n]
			if int(r.furn.get(t, 0)) >= 3: return "%s di Kamar %s sudah level maksimal" % [D.FURN[t].n, D.room_name(id)]
			if int(S.lvl) < int(D.FURN[t].min): return "%s terbuka di Level %d" % [D.FURN[t].n, int(D.FURN[t].min)]
			return ""
		"build":
			if r.built: return "Kamar %s sudah dibangun" % D.room_name(id)
			if job_for(id, "build") != {}: return "Kamar %s sedang dibangun" % D.room_name(id)
			if int(S.lvl) < int(D.FLOOR_LV[int(id[0])]): return "Lantai %s terbuka di Level %d" % [id[0], int(D.FLOOR_LV[int(id[0])])]
			return ""
	return "?"


func _end_drag(p: Vector2) -> void:
	var d := drag
	drag = {}
	ui.hide_ghost()
	ui.ghost.material = null
	ui.show_hints({})
	for id in D.ROOMS:
		room_fx[id].set_preview("")
	_hover_room = ""
	if d.kind == "guest" and npcs.has(d.item):
		npcs[d.item].modulate.a = 1.0
	if d.kind == "cargo" and int(d.item) < box_nodes.size():
		box_nodes[int(d.item)].modulate.a = 1.0
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
		act("facil_build", "%d|%s" % [f, d.item])
		return
	var id := room_at(p)
	if id == "":
		return
	drag = d
	var why := _drop_ok(id)
	drag = {}
	if why != "":
		ui.toast(why, "bad")
		return
	match d.kind:
		"guest": act("assign", "%s|%s" % [d.item, id])
		"furn": act("upgrade_furn" if S.rooms[id].furn.has(d.item) else "place_furn", "%s|%s" % [id, d.item])
		"build": act("build", id)
		"cargo":
			var t: String = S.cargo.pop_at(int(d.item))
			var r: Dictionary = S.rooms[id]
			add_job("deliver", id, t, int(r.furn.get(t, 0)) + 1)
			ui.toast("Supir mengangkut %s ke Kamar %s" % [D.FURN[t].n, D.room_name(id)])
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
			if not pan.moved:
				scroll_v = 0.0
				var id := room_at(pan.start)
				if id != "":
					ui.open_sheet("room", id)
				else:
					var sf := stair_at(pan.start)
					if sf > 0 and int(S.lvl) >= int(D.FLOOR_LV[sf]):
						ui.open_sheet("facil", str(sf))
			pan = {}
			get_viewport().set_input_as_handled()
		return
	if drag.is_empty():
		return
	if e is InputEventMouseMotion:
		if not drag.active and p.distance_to(drag.start) > 18.0:
			_activate_drag()
		if drag.active:
			ui.move_ghost(p)
			var id := room_at(p)
			if drag.kind == "facil":
				var sf := stair_at(p)
				id = "S%d" % sf if sf > 0 else ""
			if id != _hover_room:
				for rid in D.ROOMS:
					room_fx[rid].set_preview("")
				_hover_room = id
				if id != "" and not id.begins_with("S") and (drag.kind == "furn" or drag.kind == "cargo") and _drop_ok(id) == "":
					room_fx[id].set_preview(drag.item if drag.kind == "furn" else S.cargo[int(drag.item)])
			ui.hover_hint(id)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_end_drag(p)
		get_viewport().set_input_as_handled()


func set_dekor(on: bool) -> void:
	dekor = on
	if on:
		ui.open_tray()
	else:
		ui.close_tray()
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
	if D.PILL_CLOCK.has_point(p):
		S.speed = [1, 2, 3, 0][int(S.speed)]
		ui.toast("Kecepatan %dx" % int(S.speed) if int(S.speed) > 0 else "Waktu dijeda")
		if ui.kind == "manage": ui.refresh_sheet()
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
				set_dekor(not dekor)
			else:
				ui.open_sheet(nv[0])
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
	if D.CAT_RECT.has_point(p):
		ui.toast(["Meong~ Si Oyen minta dielus", "Oyen menguap lalu tidur lagi", "Purrr... Oyen senang dielus"].pick_random())
		return
	if D.GROUND_RECT.has_point(p):
		ui.open_sheet("tenants")


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
		act("assign", "%s|%s" % [S.queue[0].id, empty_rooms()[0]])
	S.rooms["3L"].broken = "AC rusak"
	act("fix", "3L")
	S.rooms["3R"].clean = 10.0
	act("clean", "3R")
	S.lvl = 8
	var fi := 1
	for k in D.FACIL_ORDER:
		act("facil_build", "%d|%s" % [fi, k])
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
			act("event", "%s|%d" % [ex.id, Ev.DEF[k].opts.size() - 1])
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
	print("SELFTEST actions OK. Money=", S.money, " lvl=", S.lvl)



func _handle_cli(args: PackedStringArray) -> void:
	var shot := ""
	var wait := 2.0
	for a in args:
		if a.begins_with("--shot="): shot = a.substr(7)
		elif a.begins_with("--wait="): wait = float(a.substr(7))
		elif a.begins_with("--at="):
			var hm := a.substr(5).split(":")
			S.min = int(hm[0]) * 60 + int(hm[1])
		elif a.begins_with("--staff"):
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
			print("truck ", truck.position, " ", truck.scale, " state ", truck_state)
			for b in box_nodes: print("box ", truck.to_global(b.position))
			for y in range(2100, 2240, 20): print(y, " ", _box_at(Vector2(400, y)))
		elif a == "--allfurn":
			for id in D.ROOMS:
				S.rooms[id].built = true
				S.rooms[id].tenant = null
				for t in D.FURN_POS[id]:
					S.rooms[id].furn[t] = 1
				update_tier(S.rooms[id])
			S.queue = []
			dirty = true
		elif a == "--lineup":
			S.seen = true
			ui.close_sheet()
			S.speed = 0
			var chars := ["kutu", "kakek", "siswi", "flanel", "nenek"]
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
		print("NPC ", n.id, " ", n.kind, " ", n.scene, " ", n.pose, " ", n.position, " route=", n.route.size(), " goal=", n.goal_key)
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot)
	get_tree().quit()

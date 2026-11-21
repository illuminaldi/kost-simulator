class_name Npc
extends Node2D
## Satu karakter yang bisa berjalan, berpindah lantai (fade lewat tangga), duduk, tidur, dan bekerja.

const K_LOBBY := 2.2
const K_ROOM := 0.8
const SPEED_LOBBY := 150.0
const SPEED_ROOM := 105.0
const FADE := 0.3

var id := ""
var kind := ""          # "cand" | "res" | "staff"
var role := ""          # untuk staff: cleaner / satpam / teknisi
var look := {}
var scene := "lobby"
var route: Array = []
var idle_pose := "stand"
var pose := "stand"
var anim := 0.0
var dir := 1
var k := K_LOBBY
var fade_state := ""     # "" | "out" | "in"
var fade_t := 0.0
var fade_to := ""
var fade_pos = null
var goal_key := ""
var leaving := false
var on_done: Callable = Callable()
var work: Dictionary = {}
var target := ""
var speed_mul := 1.0
var blocked := false     # ada NPC lain tepat di depan -> tunggu sebentar
var bub_lift := 0.0
var art := false        # true = pakai sprite ilustrasi (penghuni & calon penyewa)
var gender := "l"
var suitcase := false
var char_id := "kutu"
var art_map := {}        # pose -> nama file khusus (pekerja)
var size_mul := 1.0
static var stair_mul := 1.0     # tangga lebih bagus = naik-turun lebih cepat
static var escalator := false
static var _exists := {}  # karakter ilustrasi (folder di assets/chars)

var mood := ""          # emosi saat diam: angry / annoyed / tired
var react_pose := ""    # reaksi sesaat: happy / sad / tired
var react_t := 0.0

static var _art_cache := {}
static var _tint_shader: Shader

const TINT_SHADER := """
shader_type canvas_item;
uniform float hue_shift = 0.0;
uniform float sat_mul = 1.0;
uniform float val_mul = 1.0;
vec3 rgb2hsv(vec3 c){
	vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y); float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c){
	vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
uniform float target_hue = 0.0;
uniform float hue_width = 0.1;
uniform float min_sat = 0.2;
uniform float min_val = 0.2;
uniform float max_val = 1.0;
uniform float sat_boost = 1.0;
void fragment(){
	vec4 col = COLOR;
	vec3 h = rgb2hsv(col.rgb);
	float dh = abs(h.x - target_hue);
	dh = min(dh, 1.0 - dh);
	if (dh < hue_width && h.y > min_sat && h.z > min_val && h.z < max_val) {
		h.x = fract(h.x + hue_shift);
		h.y = clamp(h.y * sat_mul * sat_boost, 0.0, 1.0);
		h.z = clamp(h.z * val_mul, 0.0, 1.0);
		col.rgb = hsv2rgb(h);
	}
	COLOR = col;
}
"""
const TINTS := [[0.0, 1.0, 1.0], [0.3, 0.8, 1.0], [0.55, 0.75, 1.0], [0.72, 0.7, 1.0], [0.13, 0.85, 1.05], [0.88, 0.75, 1.0], [0.45, 0.7, 1.0], [0.0, 0.3, 1.1]]


## Material warna baju untuk varian ke-i (0 = warna asli).
# Warna pakaian utama tiap karakter: [hue, lebar, sat min, val min].
const GARMENT := {
	"kutu": [0.40, 0.15, 0.1, 0.1, 1.0, 1.9], "kakek": [0.22, 0.09, 0.15, 0.3], "siswi": [0.055, 0.035, 0.55, 0.42],
	"flanel": [0.0, 0.05, 0.5, 0.22, 0.86, 1.0], "nenek": [0.985, 0.05, 0.35, 0.18],
	"kupluk": [0.58, 0.07, 0.1, 0.15],
}


static func tint_material(i: int, ch: String = "") -> Material:
	if i <= 0 or not GARMENT.has(ch):
		return null
	if _tint_shader == null:
		_tint_shader = Shader.new()
		_tint_shader.code = TINT_SHADER
	var t: Array = TINTS[i % TINTS.size()]
	var m := ShaderMaterial.new()
	m.shader = _tint_shader
	m.set_shader_parameter("hue_shift", t[0])
	m.set_shader_parameter("sat_mul", t[1])
	m.set_shader_parameter("val_mul", t[2])
	var g: Array = GARMENT[ch]
	m.set_shader_parameter("target_hue", g[0])
	m.set_shader_parameter("hue_width", g[1])
	m.set_shader_parameter("min_sat", g[2])
	m.set_shader_parameter("min_val", g[3])
	m.set_shader_parameter("max_val", g[4] if g.size() > 4 else 1.0)
	m.set_shader_parameter("sat_boost", g[5] if g.size() > 5 else 1.0)
	return m


func set_tint(i: int) -> void:
	_sp.material = tint_material(i, char_id)
const ART_POSES := ["stand", "walk", "climb", "sit", "work", "lie", "react", "mood", "sweep", "fix", "counter", "job", "place", "steal", "caught", "demand", "count", "happy", "angry", "carry", "lift", "hold"]

var _sp: Sprite2D
var _bub: PanelContainer
var _bub_lbl: Label
var _zz: Label
var _tex_key := ""


func setup(p_id: String, p_kind: String, p_look: Dictionary, start: Vector2, font: Font) -> void:
	id = p_id
	kind = p_kind
	look = p_look
	position = start
	_sp = Sprite2D.new()
	_sp.centered = false
	add_child(_sp)
	_bub = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_color = D.C_LINE
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(26)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0.24, 0.16, 0.1, 0.22)
	sb.shadow_offset = Vector2(0, 5)
	_bub.add_theme_stylebox_override("panel", sb)
	_bub_lbl = Label.new()
	_bub_lbl.add_theme_font_override("font", font)
	_bub_lbl.add_theme_font_size_override("font_size", 28)
	_bub_lbl.add_theme_color_override("font_color", D.C_INK)
	_bub.add_child(_bub_lbl)
	_bub.visible = false
	_bub.z_index = 50
	add_child(_bub)
	_zz = Label.new()
	_zz.text = "z z"
	_zz.add_theme_font_override("font", font)
	_zz.add_theme_font_size_override("font_size", 30)
	_zz.add_theme_color_override("font_color", Color("7a8ab8"))
	_zz.visible = false
	add_child(_zz)
	_refresh()


func _has(file: String) -> bool:
	var path := "res://assets/chars/%s/%s_R.png" % [char_id, file]
	if not _exists.has(path):
		_exists[path] = ResourceLoader.exists(path)
	return _exists[path]


func _art_tex(p: String) -> Texture2D:
	var variant := absi(id.hash()) % 2
	var base := "idle"
	if p == "climb" and art_map.has("walk") and not art_map.has("climb"):
		p = "walk"
	if art_map.has(p):
		var m = art_map[p]
		base = m[int(anim / 3.5) % m.size()] if m is Array else m
	else:
		match p:
			"walk":
				base = "run" if speed_mul > 1.6 else "walk"
				if base == "walk" and int(anim * 4.0) % 2 == 1 and _has("walk2"):
					base = "walk2"
			"climb": base = "walk"
			"sit": base = "floor" if (variant == 0 or not _has("chair")) else "chair"
			"work": base = "chair" if _has("chair") else "floor"
			"lie": base = "sleep"
			"sweep", "fix": base = "floor"
			"counter": base = "idle"
			"react": base = react_pose
			"mood": base = mood
	if not _has(base):
		base = "idle"
		for fb in ["idle", "happy", "stand", "walk"]:
			if _has(fb):
				base = fb
				break
	# Siklus langkah: bergantian kaki depan & kaki berpapasan.
	if (p == "walk" or p == "climb") and _has(base + "2") and int(anim * (4.0 if p == "walk" else 3.0)) % 2 == 1:
		base = base + "2"
	var path := "res://assets/chars/%s/%s_%s.png" % [char_id, base, "L" if k > 1.5 else "R"]
	if not _art_cache.has(path):
		_art_cache[path] = load(path)
	return _art_cache[path]


var _hmul := 1.0


func _art_ref_h(k: float) -> float:
	var path := "res://assets/chars/%s/idle_%s.png" % [char_id, "L" if k > 1.5 else "R"]
	if not _art_cache.has(path):
		_art_cache[path] = load(path) if ResourceLoader.exists(path) else null
	var t: Texture2D = _art_cache[path]
	return t.get_height() if t else 0.0


var _base_bub := ["", false]
var chat_t := 0.0
var chat_with: Npc = null


## Bubble nama/label tetap; tidak menimpa dialog yang sedang tampil.
func set_bubble(text: String, hi: bool = false) -> void:
	_base_bub = [text, hi]
	if chat_t <= 0.0:
		_show_bub(text, hi)


## Tampilkan kalimat dialog selama `dur` detik (waktu nyata), lalu kembali ke bubble semula.
func say(text: String, dur: float) -> void:
	chat_t = dur
	_show_bub(text, false, true)


func chat_tick(dt: float) -> void:
	if chat_t > 0.0:
		chat_t -= dt
		if chat_t <= 0.0:
			_show_bub(_base_bub[0], _base_bub[1])


func _show_bub(text: String, hi: bool = false, talk: bool = false) -> void:
	_bub.visible = text != ""
	_bub_lbl.add_theme_font_size_override("font_size", 30 if talk else 28)
	var sb: StyleBoxFlat = _bub.get_theme_stylebox("panel")
	sb.bg_color = Color("fff1b8") if hi else (Color("eaf5ff") if talk else Color.WHITE)
	if _bub_lbl.text != text:
		_bub_lbl.text = text
		_bub.reset_size()


## Rencanakan rute ke scene tujuan lalu jalan ke titik `spot`.
func plan(to: String, spot: Vector2, p_pose: String, done: Callable = Callable()) -> void:
	# Kalau sedang menghilang di tangga, selesaikan dulu perpindahannya agar rute baru dihitung dari scene tujuan.
	if fade_state == "out":
		scene = fade_to
		position = D.scene_pos(scene)
		k = K_LOBBY if scene == "lobby" else K_ROOM
		fade_state = "in"
		fade_t = 0.0
	var path := D.bfs(scene, to)
	route = []
	if path.is_empty() and to != scene:
		# Tujuan tak terjangkau (mis. lantai berubah): jangan jalan menembus lantai, selesaikan saja.
		idle_pose = p_pose
		on_done = done
		work = {}
		return
	var cur := scene
	for i in range(1, path.size()):
		var nxt: String = path[i]
		if cur.begins_with("S") and nxt.begins_with("S"):
			var fc := int(cur.substr(1))
			var fn := int(nxt.substr(1))
			if fn > fc:
				# Naik: jalan ke kaki tangga, menaiki anak tangga sambil menghilang.
				var sx := D.stair_x(fc)
				route.append({"walk": Vector2(sx, D.FEET[fc])})
				route.append({"stair": Vector2(sx, D.stair_top(fc)), "a0": 1.0, "a1": 0.1, "pose": "climb"})
				route.append({"warp": nxt})
			else:
				# Turun: muncul di puncak tangga lantai bawah, lalu menuruni anak tangga.
				var sx2 := D.stair_x(fn)
				route.append({"walk": D.scene_pos(cur)})
				route.append({"warp": nxt, "pos": Vector2(sx2, D.stair_top(fn))})
				route.append({"stair": Vector2(sx2, D.FEET[fn]), "a0": 1.0, "a1": 1.0, "pose": "walk"})
		else:
			route.append({"walk": D.scene_pos(cur)})
			route.append({"warp": nxt})
		cur = nxt
	route.append({"walk": spot})
	idle_pose = p_pose
	on_done = done
	work = {}


func react(p: String, secs: float) -> void:
	react_pose = p
	react_t = secs


func tick(dt: float) -> void:
	anim += dt
	if react_t > 0.0 and fade_state == "":
		react_t -= dt
		pose = "react"
		_refresh()
		return
	if fade_state != "":
		fade_t += dt
		if fade_state == "out":
			modulate.a = minf(modulate.a, maxf(0.0, 1.0 - fade_t / FADE))
			if fade_t >= FADE:
				scene = fade_to
				position = fade_pos if fade_pos != null else D.scene_pos(scene)
				fade_pos = null
				k = K_LOBBY if scene == "lobby" else K_ROOM
				fade_state = "in"
				fade_t = 0.0
		else:
			modulate.a = minf(1.0, fade_t / FADE)
			if fade_t >= FADE:
				modulate.a = 1.0
				fade_state = ""
		_refresh()
		return
	if route.size() > 0:
		var s: Dictionary = route[0]
		if s.has("warp"):
			route.pop_front()
			fade_state = "out"
			fade_t = 0.0
			fade_to = s.warp
			fade_pos = s.get("pos")
		elif s.has("stair"):
			var tgt2: Vector2 = s.stair
			if not s.has("d0"):
				s.d0 = maxf(1.0, position.distance_to(tgt2))
			var d2 := tgt2 - position
			var step2 := 0.0 if blocked else SPEED_ROOM * 0.6 * dt * speed_mul * stair_mul
			if d2.length() <= step2:
				position = tgt2
				modulate.a = s.a1
				route.pop_front()
			else:
				position += d2.normalized() * step2
				var prog: float = 1.0 - d2.length() / float(s.d0)
				modulate.a = lerpf(s.a0, s.a1, clampf(prog, 0.0, 1.0))
			pose = "idle" if escalator and s.pose == "climb" else s.pose
		else:
			var tgt: Vector2 = s.walk
			var d := tgt - position
			var dist := d.length()
			var step := (SPEED_LOBBY if scene == "lobby" else SPEED_ROOM) * dt * speed_mul
			if blocked:
				step = 0.0
			if dist <= step:
				position = tgt
				route.pop_front()
			else:
				position += d / dist * step
				# Arah hadap hanya berubah kalau gerak horizontal cukup jelas (cegah balik-balik di tempat).
				if absf(d.x) > 6.0 and absf(d.x) > absf(d.y) * 0.3:
					dir = -1 if d.x < 0 else 1
			pose = "stand" if blocked else "walk"
	else:
		suitcase = false
		if on_done.is_valid():
			var f := on_done
			on_done = Callable()
			f.call(self)
			if not is_inside_tree() or is_queued_for_deletion():
				return
		if not work.is_empty():
			work.t -= dt
			pose = work.pose
			if work.t <= 0.0:
				var fn: Callable = work.get("fn", Callable())
				work = {}
				if fn.is_valid():
					fn.call(self)
		else:
			pose = idle_pose
			if mood != "" and art and (idle_pose == "sit" or idle_pose == "stand"):
				pose = "mood"
	_refresh()


## Di luar layar: logika tetap jalan, tapi gambar tidak diperbarui (hemat CPU).
var culled := false
func set_culled(c: bool) -> void:
	if c == culled: return
	culled = c
	visible = not c
	if not c:
		_tex_key = ""
		_refresh()


func _refresh() -> void:
	if culled: return
	var frame := 0
	if pose == "walk":
		frame = int(anim * 6.0) % 2
	elif pose == "sweep" or pose == "fix":
		frame = int(anim * 3.0) % 2
	var use_art := art   # karakter ilustrasi selalu pakai gambar; pose tak dikenal -> idle
	var key := "%s|%d|%.1f|%s|%s|%s|%s|%s|%d|%d" % [pose, frame, k, use_art, char_id, mood, react_pose, speed_mul > 1.6, int(anim * 4.0) % 2, int(anim / 3.5) % 6]
	if key != _tex_key:
		_tex_key = key
		var t: Texture2D
		if use_art:
			t = _art_tex(pose)
		else:
			t = Spr.tex(look, pose, frame, k if pose != "lie" else 0.95)
		if t == null: return
		_sp.texture = t
		var sz := t.get_size()
		_sp.offset = Vector2(-sz.x / 2.0, -sz.y)
		# Pose berdiri ekspresi (senang/kesal/pusing...) digambar lebih pendek dari idle:
		# samakan tingginya supaya karakter tidak tiba-tiba menyusut.
		_hmul = 1.0
		if use_art and pose != "lie" and pose != "sit" and pose != "work" and pose != "sweep" and pose != "fix":
			var bn := t.resource_path.get_file().get_basename().trim_suffix("_L").trim_suffix("_R")
			if bn in ["happy", "angry", "annoyed", "sad", "tired", "run", "shock", "cheer"]:
				var ref := _art_ref_h(k)
				if ref > 0.0 and sz.y < ref * 0.97: _hmul = clampf(ref / sz.y, 1.0, 1.2)
	if pose == "lie":
		# Kepala di sisi sandaran kasur: kamar kanan -> kepala di kanan.
		_sp.flip_h = scene.length() == 2 and scene.ends_with("R")
	else:
		_sp.flip_h = dir < 0
	_sp.position = Vector2.ZERO
	_sp.rotation = 0.0
	# Sedikit "napas" saat diam agar terasa hidup.
	if pose == "stand" or pose == "sit" or pose == "work" or pose == "counter":
		_sp.scale = Vector2(1, 1.0 + sin(anim * 2.4 + float(id.hash() % 7)) * 0.012)
	elif use_art and pose == "climb":
		_sp.scale = Vector2.ONE
		_sp.rotation = -0.08 * float(dir)
		_sp.position.y = -absf(sin(anim * 9.5)) * 4.0 * k
	elif use_art and pose == "walk" and _has("walk2"):
		# 2 frame bergantian + ayunan badan: naik-turun tiap langkah, sedikit condong ke depan & bergoyang.
		var ph2 := anim * 4.0 * PI
		_sp.scale = Vector2(1.0 + absf(sin(ph2)) * 0.015, 1.0 - absf(sin(ph2)) * 0.02)
		_sp.position.y = -absf(sin(ph2)) * 5.0 * k
		_sp.rotation = (0.03 + sin(ph2) * 0.025) * float(dir)
	elif use_art and pose == "walk":
		# Sprite ilustrasi hanya satu frame: beri ayunan langkah agar terasa berjalan.
		var ph := anim * 9.0
		_sp.scale = Vector2.ONE
		_sp.position.y = -absf(sin(ph)) * 7.0 * k
		_sp.rotation = sin(ph) * 0.035
	else:
		_sp.scale = Vector2.ONE
	if pose == "lie" and use_art:
		_sp.scale = Vector2(1.45, 1.45)
	_sp.scale *= size_mul * _hmul
	_zz.visible = pose == "lie" and not use_art
	if _zz.visible:
		_zz.position = Vector2(-20, -100 + sin(anim * 2.0) * 8.0)
		_zz.modulate.a = 0.6 + 0.4 * sin(anim * 2.0)
	if _bub.visible:
		_bub.position = Vector2(-_bub.size.x / 2.0, -172.0 * k - 26.0 - bub_lift - _bub.size.y + sin(anim * 3.0) * 6.0)


func is_moving() -> bool:
	return route.size() > 0 and fade_state == ""


## Arah gerak saat ini (untuk mendeteksi NPC di depan).
func move_dir() -> Vector2:
	if route.is_empty():
		return Vector2.ZERO
	var s: Dictionary = route[0]
	var tgt = s.get("walk", s.get("stair"))
	if tgt == null:
		return Vector2.ZERO
	return ((tgt as Vector2) - position).normalized()

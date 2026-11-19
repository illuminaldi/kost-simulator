class_name Ui
extends CanvasLayer
## HUD (uang, level, jam), bar navigasi, toast, dan panel bawah (sheet) untuk semua menu.

var game: Node
var font: Font
var font_m: Font

var money_lbl: Label
var lv_lbl: Label
var xp_fill: ColorRect
var clock1: Label
var clock2: Label
var spd_lbl: Label
var spd_sb: StyleBoxFlat
var clock_icon: ClockIcon
var nav_badge: PanelContainer
var ev_badge: PanelContainer
var ev_badge_lbl: Label
var nav_badge_lbl: Label
var toasts: VBoxContainer

var overlay: Control
var sheet: PanelContainer
var scroll: ScrollContainer
var tutorial: Tutorial
var box: VBoxContainer
var kind := ""
var arg := ""
var tab := "antre"
var sel := ""
var confirm := ""
var _anim_in := false
var _opened_at := 0
var tray: PanelContainer
var tray_row: HBoxContainer
var tray_box: VBoxContainer
var floor_btn: Button
var tray_tab := "perabot"
var ghost: Sprite2D
var hints := {}
var hint_root: Control


class ClockIcon:
	extends Node2D
	var night := 0.0
	var dusk := 0.0

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 78, Color("6b4f3a"))
		draw_circle(Vector2.ZERO, 72, Color("c9a27e"))
		var sky := Color("f6ecd8").lerp(Color("f5c896"), dusk).lerp(Color("3e4b7c"), night)
		draw_circle(Vector2.ZERO, 62, sky)
		if night < 0.5:
			var sun := Color("f2c14e")
			draw_circle(Vector2(0, 8), 26, sun)
			for i in range(5):
				var a := PI + PI * (i + 0.5) / 5.0
				draw_line(Vector2(cos(a), sin(a)) * 34 + Vector2(0, 8), Vector2(cos(a), sin(a)) * 44 + Vector2(0, 8), Color("e0a83a"), 5, true)
		else:
			draw_circle(Vector2(6, -6), 24, Color("f7e6a2"))
			draw_circle(Vector2(18, -14), 21, sky)
			for p in [Vector2(-30, -26), Vector2(30, -36), Vector2(-20, 4)]:
				draw_circle(p, 3, Color("f7e6a2"))
		# Laut di bagian bawah lingkaran.
		var sea := PackedVector2Array()
		for i in range(0, 181, 10):
			var a := deg_to_rad(float(i))
			sea.append(Vector2(cos(a) * 62, sin(a) * 62))
		sea.append(Vector2(-62, 12))
		sea.append(Vector2(62, 12))
		var pts := PackedVector2Array([Vector2(62, 12)])
		for i in range(0, 181, 10):
			var a := deg_to_rad(float(i))
			var v := Vector2(cos(a) * 62, sin(a) * 62)
			if v.y >= 12:
				pts.append(v)
		pts.append(Vector2(-62, 12))
		var sea_col := Color("b9d3c4").lerp(Color("2f3a5e"), night)
		draw_colored_polygon(pts, sea_col)
		draw_line(Vector2(-40, 26), Vector2(40, 26), Color("8fb3a8").lerp(Color("55648f"), night), 4, true)


func setup(p_game: Node, art: Texture2D, p_font: Font, p_font_m: Font) -> void:
	game = p_game
	font = p_font
	font_m = p_font_m
	layer = 10
	# Bar navigasi bawah (diambil dari ilustrasi, tidak ikut gelap saat malam).
	var band := ColorRect.new()
	band.color = Color("b98a5e")
	band.position = Vector2(0, D.NAV_Y - 22)
	band.size = Vector2(D.IW, D.IH - D.NAV_Y + 22)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var edge := ColorRect.new()
	edge.color = Color("6b4f3a")
	edge.position = band.position
	edge.size = Vector2(D.IW, 8)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)
	var cols := {"upgrade": [D.C_GREEN, "Beli"], "tenants": [D.C_PINK, "Penyewa"], "staff": [D.C_YELLOW, "Karyawan"], "manage": [D.C_CREAM, "Kelola"]}
	for nv in D.NAV:
		var r: Rect2 = nv[1]
		var pc := PanelContainer.new()
		var sb := _sb(cols[nv[0]][0], 6, 46, 0, 0)
		sb.shadow_color = D.C_LINE
		sb.shadow_offset = Vector2(0, 9)
		sb.shadow_size = 1
		pc.add_theme_stylebox_override("panel", sb)
		pc.position = r.position
		pc.size = r.size - Vector2(0, 10)
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lb := _label(cols[nv[0]][1], 58 if nv[0] != "staff" else 52)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pc.add_child(lb)
		add_child(pc)
	# Panel HUD digambar ulang persis di atas pil pada ilustrasi.
	_pill(D.PILL_MONEY)
	_pill(D.PILL_LV)
	_pill(Rect2(1040, 60, 372, 123))
	var coin := Sprite2D.new()
	coin.texture = art
	coin.region_enabled = true
	coin.region_rect = Rect2(58, 70, 100, 100)
	coin.position = Vector2(108, 120)
	add_child(coin)
	var star := Sprite2D.new()
	star.texture = art
	star.region_enabled = true
	star.region_rect = Rect2(568, 70, 100, 100)
	star.position = Vector2(618, 120)
	add_child(star)
	clock_icon = ClockIcon.new()
	clock_icon.position = Vector2(1020, 120)
	add_child(clock_icon)

	money_lbl = _hud_label(Rect2(172, 70, 320, 100), 60)
	lv_lbl = _hud_label(Rect2(700, 66, 180, 84), 58)
	var xpbg := ColorRect.new()
	xpbg.color = Color("eadfcd")
	xpbg.position = Vector2(704, 150)
	xpbg.size = Vector2(170, 12)
	xpbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(xpbg)
	xp_fill = ColorRect.new()
	xp_fill.color = Color("f08a5d")
	xp_fill.position = xpbg.position
	xp_fill.size = Vector2(0, 12)
	xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(xp_fill)
	clock1 = _hud_label(Rect2(1100, 68, 300, 56), 48)
	clock1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock2 = _hud_label(Rect2(1100, 118, 300, 56), 48)
	clock2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spd := PanelContainer.new()
	spd_sb = _sb(D.C_YELLOW, 4, 40, 12, 2)
	spd.add_theme_stylebox_override("panel", spd_sb)
	spd_lbl = _label("1x", 28)
	spd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spd.add_child(spd_lbl)
	spd.position = Vector2(1036, 160)
	spd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spd)

	nav_badge = PanelContainer.new()
	nav_badge.add_theme_stylebox_override("panel", _sb(Color("e0533d"), 5, 40, 14, 2, Color.WHITE))
	nav_badge_lbl = _label("0", 32, Color.WHITE)
	nav_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_badge.add_child(nav_badge_lbl)
	nav_badge.position = Vector2(670, 2350)
	nav_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nav_badge)
	ev_badge = PanelContainer.new()
	ev_badge.add_theme_stylebox_override("panel", _sb(Color("e0533d"), 5, 40, 14, 2, Color.WHITE))
	ev_badge_lbl = _label("0", 32, Color.WHITE)
	ev_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev_badge.add_child(ev_badge_lbl)
	ev_badge.position = Vector2(1380, 2350)
	ev_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ev_badge)

	toasts = VBoxContainer.new()
	toasts.position = Vector2(80, 225)
	toasts.size = Vector2(1278, 10)
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.add_theme_constant_override("separation", 12)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toasts)

	var hint_clip := Control.new()
	hint_clip.clip_contents = true
	hint_clip.size = Vector2(D.IW, D.LOBBY_TOP)
	hint_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_clip)
	hint_root = Control.new()
	hint_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_clip.add_child(hint_root)
	for id in D.ROOMS:
		var r := D.rect_of(id)
		var h := Panel.new()
		var hs := StyleBoxFlat.new()
		hs.bg_color = Color(0.5, 0.85, 0.45, 0.16)
		hs.border_color = Color("5fae4f")
		hs.set_border_width_all(8)
		hs.set_corner_radius_all(10)
		h.add_theme_stylebox_override("panel", hs)
		h.position = r.position
		h.size = r.size
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.visible = false
		hint_root.add_child(h)
		hints[id] = h
	for f in range(1, D.TOP_FLOOR + 1):
		var r2 := D.facil_rect(f)
		var h2 := Panel.new()
		var hs2 := StyleBoxFlat.new()
		hs2.bg_color = Color(0.5, 0.85, 0.45, 0.16)
		hs2.border_color = Color("5fae4f")
		hs2.set_border_width_all(8)
		hs2.set_corner_radius_all(10)
		h2.add_theme_stylebox_override("panel", hs2)
		h2.position = r2.position
		h2.size = r2.size
		h2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h2.visible = false
		hint_root.add_child(h2)
		hints["S%d" % f] = h2

	floor_btn = _btn("Lantai", D.C_CREAM, func(): open_sheet("floors"))
	floor_btn.add_theme_font_size_override("font_size", 30)
	floor_btn.position = Vector2(1250, 215)
	add_child(floor_btn)

	tray = PanelContainer.new()
	var tsb := _sb(D.C_PAPER, 6, 40, 22, 16)
	tsb.shadow_color = Color(0.24, 0.16, 0.1, 0.35)
	tsb.shadow_offset = Vector2(0, -6)
	tsb.shadow_size = 1
	tray.add_theme_stylebox_override("panel", tsb)
	tray.position = Vector2(14, 1700)
	tray.size = Vector2(1410, 690)
	tray.visible = false
	tray_box = VBoxContainer.new()
	tray_box.add_theme_constant_override("separation", 10)
	tray.add_child(tray_box)
	add_child(tray)

	ghost = Sprite2D.new()
	ghost.visible = false
	ghost.modulate = Color(1, 1, 1, 0.85)
	ghost.z_index = 100
	add_child(ghost)

	overlay = Control.new()
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(D.IW, D.IH)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.1, 0.06, 0.45)
	dim.size = overlay.size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and kind != "welcome" and Time.get_ticks_msec() - _opened_at > 450:
			close_sheet())
	overlay.add_child(dim)
	sheet = PanelContainer.new()
	var ssb := _sb(D.C_PAPER, 6, 0, 44, 34)
	ssb.corner_radius_top_left = 56
	ssb.corner_radius_top_right = 56
	ssb.border_width_bottom = 0
	ssb.content_margin_bottom = 60
	sheet.add_theme_stylebox_override("panel", ssb)
	overlay.add_child(sheet)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 18)
	scroll.add_child(box)
	add_child(overlay)
	tutorial = Tutorial.new()
	add_child(tutorial)
	tutorial.setup(game, self, font)
	tutorial.visible = false


# ---------- Helper gaya ----------
func _sb(bg: Color, border: int, radius: int, mx: int, my: int, border_col: Color = D.C_LINE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border_col
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.anti_aliasing = true
	return s


func _pill(r: Rect2) -> void:
	var p := Panel.new()
	var s := _sb(Color("fbf3ea"), 5, 24, 0, 0)
	s.shadow_color = Color(0.24, 0.16, 0.1, 0.35)
	s.shadow_offset = Vector2(0, 7)
	s.shadow_size = 1
	p.add_theme_stylebox_override("panel", s)
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)


func _label(t: String, size: int = 40, col: Color = D.C_INK, medium: bool = false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font_m if medium else font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _hud_label(r: Rect2, size: int) -> Label:
	var l := _label("", size)
	l.position = r.position
	l.size = r.size
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	return l


func _text(t: String, size: int = 38, col: Color = D.C_INK, medium: bool = true) -> Label:
	var l := _label(t, size, col, medium)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Tombol besar (≥100 px) supaya tidak salah pencet. Tombol "nonaktif" tetap bisa diketuk
## dan menjelaskan alasannya (mis. "Kamar sudah bersih", "Uang belum cukup").
func _btn(t: String, col: Color, cb: Callable, disabled: bool = false, expand: bool = false, why: String = "") -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size.y = 100
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 38)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(st, Color("3e2b1d"))
	var n := _sb(col, 5, 60, 36, 20)
	n.shadow_color = D.C_LINE
	n.shadow_offset = Vector2(0, 7)
	n.shadow_size = 1
	var h := n.duplicate()
	h.bg_color = col.lightened(0.12)
	var p := n.duplicate()
	p.shadow_offset = Vector2(0, 2)
	p.bg_color = col.darkened(0.06)
	var d := n.duplicate()
	d.bg_color = col.lerp(Color.WHITE, 0.55)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if expand:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if disabled:
		for s in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(s, d)
		b.add_theme_color_override("font_color", Color("9a8a7a"))
		b.add_theme_color_override("font_hover_color", Color("9a8a7a"))
		b.add_theme_color_override("font_pressed_color", Color("9a8a7a"))
		var msg := why if why != "" else "Belum bisa sekarang"
		b.pressed.connect(func(): toast(msg, "bad"))
	else:
		b.pressed.connect(cb)
	return b


func money_why(cost: float) -> String:
	return "Uang tidak cukup. Butuh %s, kas kamu %s." % [D.rp(cost), D.rp(game.S.money)]


func _card() -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color.WHITE, 5, 36, 30, 24, Color("e2d3bd")))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	box.add_child(p)
	return v


func _row(parent: Control, left: Control, right: Control = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	if right:
		h.add_child(right)
	parent.add_child(h)
	return h


func _flow(parent: Control) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 26)
	f.add_theme_constant_override("v_separation", 22)
	parent.add_child(f)
	return f


func _bar(parent: Control, v: float, col: Color = Color.TRANSPARENT) -> void:
	var pb := ProgressBar.new()
	pb.min_value = 0
	pb.max_value = 100
	pb.value = clampf(v, 0, 100)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 22)
	var c := col
	if c == Color.TRANSPARENT:
		c = Color("8cc47e") if v > 60 else (Color("f2c35a") if v > 30 else Color("e5765f"))
	pb.add_theme_stylebox_override("background", _sb(Color("eadfcd"), 3, 14, 0, 0, Color("e0cfb6")))
	pb.add_theme_stylebox_override("fill", _sb(c, 0, 14, 0, 0))
	parent.add_child(pb)


func _header(title: String, closable: bool = true) -> void:
	var h := HBoxContainer.new()
	var t := _label(title, 50)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(t)
	if closable:
		var xb := _btn("✕", Color.WHITE, close_sheet)
		xb.custom_minimum_size = Vector2(120, 110)
		h.add_child(xb)
	box.add_child(h)


func _tabs(items: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	for it in items:
		var b := _btn(it[1], D.C_PINK if tab == it[0] else Color.WHITE, func(): tab = it[0]; sel = ""; refresh_sheet(), false, true)
		h.add_child(b)
	box.add_child(h)


func _room_pic(parent: Control, id: String, h: float = 620.0) -> void:
	var at := AtlasTexture.new()
	at.atlas = game.art if game.S.rooms[id].built else game.shell_tex
	at.region = D.src_rect(id)
	var tr := TextureRect.new()
	tr.texture = at
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(h * 1.1, h)
	parent.add_child(tr)


## Gambar kamar sesuai perabot yang terpasang (gedung kosong + sprite perabot).
func _room_live(parent: Control, id: String, sc: float) -> void:
	var rect := D.rect_of(id)
	var holder := CenterContainer.new()
	var c := Control.new()
	c.custom_minimum_size = rect.size * sc
	var at := AtlasTexture.new()
	at.atlas = game.shell_tex
	at.region = D.src_rect(id)
	var bg := TextureRect.new()
	bg.texture = at
	bg.size = rect.size * sc
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c.add_child(bg)
	var furn: Dictionary = game.S.rooms[id].get("furn", {})
	for t in D.ITEM_DRAW_ORDER:
		if furn.has(t):
			var flv := int(furn[t])
			var tx: Texture2D = load(D.furn_tex(id, t, flv))
			var fr := D.furn_rect(id, t, tx.get_size(), flv)
			var tr := TextureRect.new()
			tr.texture = tx
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.flip_h = D.furn_flip(id)
			tr.position = (fr.position - rect.position) * sc
			tr.size = fr.size * sc
			c.add_child(tr)
	var frame := Panel.new()
	var fs := StyleBoxFlat.new()
	fs.draw_center = false
	fs.border_color = D.C_LINE
	fs.set_border_width_all(6)
	fs.set_corner_radius_all(18)
	frame.add_theme_stylebox_override("panel", fs)
	frame.size = rect.size * sc
	c.add_child(frame)
	holder.add_child(c)
	parent.add_child(holder)


func _event_card(e: Dictionary) -> void:
	var ev: Dictionary = Ev.DEF[e.type]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color("fff1e6"), 5, 36, 30, 22, Color("e98b7a")))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	box.add_child(p)
	var where := ("Kamar " + D.room_name(e.room)) if e.room != "" else "Seluruh kost"
	_row(v, _label("! " + ev.n, 40, Color("b5543c")), _label(where, 32, D.C_MUTED, true))
	v.add_child(_text(ev.d + (" (sudah %d hari)" % int(e.age) if int(e.age) > 0 else ""), 32, D.C_MUTED))
	if ev.has("auto"):
		var st: Dictionary = D.STAFF[ev.auto[0]]
		if game.S.staff.get(ev.auto[0], false):
			v.add_child(_text("%s sedang menangani (±%d jam)." % [st.nama, maxi(1, int(e.auto))], 32, Color("3f6f96")))
		else:
			v.add_child(_text("Bisa ditangani otomatis oleh %s (%s)." % [st.nama, st.n], 30, D.C_MUTED))
	var f := _flow(v)
	for i in range(ev.opts.size()):
		var o: Array = ev.opts[i]
		var c := float(o[1])
		var lbl: String = o[0] + ("" if c == 0 else (" (+%s)" % D.short(-c) if c < 0 else " (%s)" % D.short(c)))
		f.add_child(_btn(lbl, D.C_YELLOW if i == 0 else D.C_CREAM, func(): _do("event", "%s|%d" % [e.id, i]), c > 0 and float(game.S.money) < c))


func _furn_card(id: String) -> void:
	var S: Dictionary = game.S
	var r: Dictionary = S.rooms[id]
	var v := _card()
	_row(v, _label("Perabot", 42), _label("Kenyamanan %.1f · %s" % [game.comfort(r), D.RLV[int(r.lv)].n], 32, D.C_MUTED, true))
	if not r.furn.has("kasur"):
		v.add_child(_text("Kamar ini belum punya kasur, jadi belum bisa disewakan.", 32, Color("c0392b")))
	if game.job_for(id, "fix") != {}:
		v.add_child(_text("%s sedang memperbaiki kamar ini." % D.worker_label("fix"), 32, Color("3f6f96")))
	for t in D.FURN_ORDER:
		if not D.furn_has(id, t):
			continue
		var f: Dictionary = D.FURN[t]
		var lv := int(r.furn.get(t, 0))
		var right: Control
		if game.job_for(id, "deliver", t) != {}:
			right = _label("Sedang diantar...", 32, Color("3f6f96"), true)
		elif int(S.lvl) < int(f.min) and lv == 0:
			right = _label("Lv %d" % int(f.min), 32, D.C_MUTED, true)
		elif lv == 0:
			right = _btn("Beli " + D.short(f.cost), D.C_GREEN, func(): _do("buy", t), float(S.money) < float(f.cost), false, money_why(float(f.cost)))
		elif lv < 3:
			var nxt: String = f.lv_names[lv + 1] if f.has("lv_names") else "Lv %d" % (lv + 1)
			right = _btn("Upgrade ke %s · %s" % [nxt, D.short(f.cost)], D.C_YELLOW, func(): _do("buy", t), float(S.money) < float(f.cost), false, money_why(float(f.cost)))
		else:
			right = _label("Level maks", 32, Color("2f7a2a"), true)
		var nm: String = f.n if lv == 0 else ("%s (Lv %d)" % [f.lv_names[lv], lv] if f.has("lv_names") else "%s Lv %d · %s" % [f.n, lv, D.FURN_LV_NAME[lv]])
		_row(v, _label(nm, 36, D.C_INK if lv > 0 else D.C_MUTED, lv == 0), right)
	v.add_child(_text("Pesanan datang dengan pickup. Seret kotaknya ke kamar ini; kalau perabotnya sudah ada, kotak itu meng-upgrade ke level berikutnya (maks Lv 3).", 30, D.C_MUTED))


func _avatar(parent: Control, p: Dictionary) -> void:
	var tr := TextureRect.new()
	tr.texture = load("res://assets/chars/%s/idle_L.png" % game.char_of(p))
	tr.material = Npc.tint_material(int(p.get("tint", 0)), game.char_of(p))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(120, 220)
	parent.add_child(tr)


func set_scroll(s: float) -> void:
	hint_root.position.y = s


# ---------- Mode Dekor & seret ----------
func open_tray() -> void:
	close_sheet()
	_build_tray()
	tray.visible = true
	nav_badge.visible = false


func close_tray() -> void:
	tray.visible = false


func _build_tray() -> void:
	for c in tray_box.get_children():
		c.queue_free()
	var S: Dictionary = game.S
	# Judul + saldo + tutup
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	var tl := _label("Beli", 46)
	th.add_child(tl)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(sp)
	th.add_child(_label("Kas: " + D.rp(S.money), 34, Color("2f7a2a"), true))
	th.add_child(_btn("Tutup", D.C_CREAM, func(): game.set_dekor(false)))
	tray_box.add_child(th)
	# Tab
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	for t in [["perabot", "Perabot"], ["ruang", "Kamar & Ruang"], ["layanan", "Layanan"]]:
		var key: String = t[0]
		tabs.add_child(_btn(t[1], D.C_YELLOW if tray_tab == key else Color.WHITE, func(): tray_tab = key; _build_tray(), false, true))
	tray_box.add_child(tabs)
	# Petunjuk + status pengiriman
	var info := ""
	match tray_tab:
		"perabot":
			var otw: int = S.orders.size()
			var inbox: int = S.cargo.size()
			var eta := ""
			if otw > 0:
				var mn := 9999.0
				for o in S.orders: mn = minf(mn, float(o.t))
				eta = " (tiba ± %d menit)" % maxi(1, roundi(mn))
			info = "Ketuk untuk memesan. Kotak datang dengan pickup, lalu seret ke kamar; barang yang sama = naik level.\nDalam perjalanan: %d%s · Di pickup: %d · Slot: %d/%d" % [otw, eta, inbox, otw + inbox, game.CARGO_MAX]
		"ruang": info = "Tahan & seret kartu ke lahan kosong (kamar) atau ke sisi kosong tangga (ruang fasilitas). Tukang yang membangun."
		"layanan": info = "Fasilitas kost, aplikasi, dan Toko Diamond."
	var il := _label(info, 28, D.C_MUTED, true)
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	il.custom_minimum_size.x = 1360
	tray_box.add_child(il)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(1366, 380)
	tray_box.add_child(sc)
	tray_row = HBoxContainer.new()
	tray_row.add_theme_constant_override("separation", 12)
	sc.add_child(tray_row)
	_fix_tray.call_deferred()
	match tray_tab:
		"perabot":
			for t in D.FURN_ORDER:
				var f: Dictionary = D.FURN[t]
				var ok := int(S.lvl) >= int(f.min)
				var have := 0
				var built := 0
				for id in D.ROOMS:
					if S.rooms[id].built:
						built += 1
						if S.rooms[id].furn.has(t): have += 1
				var sub: String = f.d + "\nTerpasang %d/%d kamar" % [have, built] if ok else "Terbuka di Level %d" % int(f.min)
				tray_row.add_child(_tray_card(load("res://assets/furn/icon/%s.png" % t), f.n, D.short(f.cost) if ok else "Lv %d" % int(f.min), "furn", t, ok, sub, "Pesan"))
		"ruang":
			var at := AtlasTexture.new()
			at.atlas = game.shell_tex
			at.region = D.rect_of("3R")
			var empty := 0
			for id in D.ROOMS:
				if not S.rooms[id].built and game.floor_open(D.fl(id)): empty += 1
			tray_row.add_child(_tray_card(at, "Kamar Baru", D.short(game.build_cost()), "build", "", empty > 0, "Lahan siap dibangun: %d" % empty, "Seret"))
			for k in D.FACIL_ORDER:
				var fc: Dictionary = D.FACIL[k]
				var owned: bool = game.has_facil(k)
				var ok2 := int(S.lvl) >= int(fc.lv) and not owned
				var sub2: String = ("Sudah dibangun di lantai %d" % game.facil_floor(k)) if owned else (fc.d if int(S.lvl) >= int(fc.lv) else "Terbuka di Level %d" % int(fc.lv))
				var price: String = "Dimiliki" if owned else (D.short(fc.cost) if int(S.lvl) >= int(fc.lv) else "Lv %d" % int(fc.lv))
				tray_row.add_child(_tray_card(load("res://assets/facil/%s.png" % k), fc.n, price, "facil", k, ok2, sub2, "Seret"))
		"layanan":
			for k in D.FAC:
				var f2: Dictionary = D.FAC[k]
				var own2: bool = S.fac.has(k)
				var ok3 := int(S.lvl) >= int(f2.min)
				var ic: Texture2D = load("res://assets/fac/%s.svg" % k) if ResourceLoader.exists("res://assets/fac/%s.svg" % k) else null
				tray_row.add_child(_tray_card(ic, f2.n, "Dimiliki" if own2 else (D.short(f2.cost) if ok3 else "Lv %d" % int(f2.min)), "fac", k, ok3 and not own2, f2.d if f2.d != "" else "Fasilitas kost", "Beli"))
			for k in D.APP_ORDER:
				var ap: Dictionary = D.APPS[k]
				var on: bool = game.has_app(k)
				tray_row.add_child(_tray_card(load("res://assets/fac/%s.svg" % k), ap.n, ("Aktif" if on else D.short(ap.month) + "/bln"), "app", k, int(S.lvl) >= int(ap.lv) and not on, ap.tag, "Pasang"))
			tray_row.add_child(_tray_card(load("res://assets/ui/diamond.svg"), "Toko Diamond", "%d Diamond" % int(game.W.diamonds), "toko", "", true, "Tiket Ngebut 2x & uang kas", "Buka"))


func _fix_tray() -> void:
	tray.size = Vector2(1410, 690)
	tray.position = Vector2(14, 1700)


func _tray_card(tex: Texture2D, title: String, price: String, kind: String, item: String, ok: bool, sub := "", verb := "") -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color.WHITE if ok else Color("efe6d6"), 4, 26, 14, 10, Color("e2d3bd")))
	p.custom_minimum_size = Vector2(250, 370)
	p.clip_contents = true
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(220, 140)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not ok:
		tr.modulate = Color(1, 1, 1, 0.45)
	v.add_child(tr)
	var l := _label(title, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var pl := _label(price, 30, Color("2f7a2a") if ok else D.C_MUTED, true)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pl)
	if sub != "":
		var sl := _label(sub, 22, D.C_MUTED)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.custom_minimum_size = Vector2(222, 0)
		sl.max_lines_visible = 4
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(sl)
	if verb != "" and ok:
		var vb := PanelContainer.new()
		vb.add_theme_stylebox_override("panel", _sb(D.C_YELLOW if verb != "Seret" else D.C_GREEN, 4, 20, 10, 2))
		var vl := _label(verb, 26, D.C_INK, true)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(vl)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(vb)
	p.add_child(v)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			match kind:
				"toko": open_sheet("toko"); return
				"fac", "app":
					open_sheet("upgrade"); return
			if not ok:
				if kind == "build": toast("Belum ada lahan kosong yang terbuka.", "bad")
				elif kind == "facil" and game.has_facil(item): toast("%s sudah dibangun." % title)
				else:
					var need: int = int(D.FACIL[item].lv) if kind == "facil" else int(D.FURN[item].min)
					toast("%s terbuka di Level %d" % [title, need], "bad")
				return
			if kind == "furn":
				game.act("buy", item)
				_build_tray()
			else:
				game.begin_drag(kind, item, game.get_global_mouse_position(), true)
				move_ghost(game.get_global_mouse_position()))
	return p


func show_ghost(tex: Texture2D, sc: float) -> void:
	ghost.texture = tex
	ghost.scale = Vector2(sc, sc)
	ghost.visible = tex != null


var ghost_tag: PanelContainer


## Label nama barang yang sedang diseret (mis. kotak dari pickup).
func ghost_label(t: String) -> void:
	if ghost_tag == null:
		ghost_tag = PanelContainer.new()
		ghost_tag.add_theme_stylebox_override("panel", _sb(Color.WHITE, 5, 24, 18, 4))
		ghost_tag.add_child(_label("", 38, D.C_INK, true))
		ghost_tag.z_index = 101
		ghost_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ghost_tag)
	(ghost_tag.get_child(0) as Label).text = t
	ghost_tag.visible = t != ""
	ghost_tag.reset_size()


func move_ghost(p: Vector2) -> void:
	ghost.position = p + Vector2(0, -60)
	if ghost_tag and ghost_tag.visible:
		ghost_tag.position = p + Vector2(-ghost_tag.size.x / 2.0, -230)


func hide_ghost() -> void:
	ghost.visible = false
	if ghost_tag: ghost_tag.visible = false


func show_hints(valid: Dictionary) -> void:
	for id in hints:
		var h: Panel = hints[id]
		h.visible = valid.has(id)
		if h.visible:
			var hs: StyleBoxFlat = h.get_theme_stylebox("panel")
			hs.border_color = Color("5fae4f") if valid[id] else Color("d9604c")
			hs.bg_color = Color(0.5, 0.85, 0.45, 0.14) if valid[id] else Color(0.9, 0.35, 0.3, 0.10)
			hs.set_border_width_all(6)


func hover_hint(id: String) -> void:
	for k in hints:
		var hs: StyleBoxFlat = hints[k].get_theme_stylebox("panel")
		hs.set_border_width_all(14 if k == id else 6)


# ---------- HUD ----------
func update_hud() -> void:
	var S: Dictionary = game.S
	var m := float(S.money)
	var t := D.dots(absi(roundi(m)))
	if m < 0: t = "-" + t
	money_lbl.text = t
	money_lbl.add_theme_font_size_override("font_size", 60 if t.length() <= 10 else (52 if t.length() <= 11 else 46))
	money_lbl.add_theme_color_override("font_color", Color("c0392b") if m < 0 else D.C_INK)
	lv_lbl.text = "Lv. %d" % int(S.lvl)
	xp_fill.size.x = 170.0 * clampf(float(S.xp) / game.xp_need(int(S.lvl)), 0, 1)
	var mins := int(S.min)
	clock1.text = "%02d:%02d WIB /" % [(mins / 60) % 24, mins % 60]
	clock2.text = "Hari %d" % int(S.day)
	var sp := int(S.speed)
	spd_lbl.text = ("%dx" % sp if sp > 0 else "Jeda")
	spd_sb.bg_color = D.C_YELLOW if sp > 0 else D.C_PINK
	clock_icon.night = game.glow_level()
	var h := mins / 60.0
	clock_icon.dusk = clampf(1.0 - absf(h - 17.6) / 1.4, 0, 1) + clampf(1.0 - absf(h - 6.2) / 1.0, 0, 1)
	clock_icon.queue_redraw()
	var q: int = S.queue.size()
	nav_badge.visible = q > 0 and not tray.visible
	ev_badge.visible = S.events.size() > 0 and not tray.visible
	ev_badge_lbl.text = str(S.events.size())
	nav_badge_lbl.text = str(q)


func toast(msg: String, style: String = "") -> void:
	var col := Color("fffaf0")
	if style == "gold": col = Color("fff1b8")
	elif style == "bad": col = Color("ffe0d6")
	var p := PanelContainer.new()
	var s := _sb(col, 4, 30, 30, 14)
	s.shadow_color = Color(0.24, 0.16, 0.1, 0.25)
	s.shadow_offset = Vector2(0, 6)
	s.shadow_size = 1
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(msg, 34, D.C_INK, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if msg.length() > 46:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 1150
	p.add_child(l)
	toasts.add_child(p)
	while toasts.get_child_count() > 3:
		var old := toasts.get_child(0)
		toasts.remove_child(old)
		old.queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


# ---------- Sheet ----------
func is_welcome_open() -> bool:
	return overlay.visible and kind == "welcome"


func open_sheet(k: String, a: String = "") -> void:
	kind = k
	arg = a
	sel = ""
	confirm = ""
	if k == "tenants":
		tab = "antre" if game.S.queue.size() > 0 else "huni"
	elif k == "upgrade":
		tab = "kmr"
	overlay.visible = true
	_opened_at = Time.get_ticks_msec()
	sheet.position.y = D.IH
	_anim_in = true
	refresh_sheet(false)


func close_sheet() -> void:
	kind = ""
	overlay.visible = false


func refresh_sheet(keep: bool = true) -> void:
	if kind == "":
		return
	var sv := scroll.scroll_vertical
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	match kind:
		"welcome": _sheet_welcome()
		"rename": _sheet_rename()
		"preman": _sheet_preman()
		"toko": _sheet_toko()
		"floors": _sheet_floors()
		"beli": _sheet_beli()
		"room": _sheet_room()
		"tenants": _sheet_tenants()
		"staff": _sheet_staff()
		"upgrade": _sheet_upgrade()
		"manage": _sheet_manage()
		"facil": _sheet_facil()
	_fit.call_deferred(sv if keep else 0)


func _fit(sv: int) -> void:
	var w := float(D.IW)
	var opening := _anim_in
	if opening:
		sheet.modulate.a = 0.0
	# Tunggu teks selesai di-layout, tanpa mengecilkan panel (mencegah kedip).
	scroll.custom_minimum_size.x = w - 88
	sheet.size.x = w
	await get_tree().process_frame
	if opening:
		await get_tree().process_frame
	var content_h := box.get_combined_minimum_size().y
	var h := minf(content_h, D.IH * 0.72)
	if kind == "beli": h = D.IH * 0.8
	if absf(scroll.custom_minimum_size.y - h) > 1.0 or opening:
		scroll.custom_minimum_size = Vector2(w - 88, h)
		sheet.size = Vector2(w, 0)
		sheet.reset_size()
		sheet.size.x = w
	scroll.scroll_vertical = sv
	var ty := D.IH - sheet.size.y
	if opening:
		_anim_in = false
		sheet.position = Vector2(0, D.IH)
		sheet.modulate.a = 1.0
		var tw := create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(sheet, "position:y", ty, 0.22)
	elif not _tweening():
		sheet.position = Vector2(0, ty)


func _tweening() -> bool:
	return sheet.position.y > D.IH - sheet.size.y + 2.0 and Time.get_ticks_msec() - _opened_at < 400


func _do(action: String, a: String = "") -> void:
	game.act(action, a)


func ask_rename() -> void:
	if OS.has_feature("web"):
		var r = JavaScriptBridge.eval("window.prompt('Nama kost kamu?', %s)" % JSON.stringify(str(game.S.get("kost_name", ""))))
		if r != null and str(r).strip_edges() != "":
			_do("rename", str(r))
		return
	open_sheet("rename")


## Laporan lengkap: hanya dengan aplikasi KelolaPro.
func _kelolapro_stats(occ: int, tot: int) -> void:
	var S: Dictionary = game.S
	var v := _card()
	if not game.has_app("kelolapro"):
		v.add_child(_label("Laporan KelolaPro", 40))
		v.add_child(_text("Grafik untung-rugi 7 hari, rincian biaya, proyeksi bulanan & kondisi tiap kamar tersedia dengan aplikasi KelolaPro (Rp 99rb/bulan).", 32, D.C_MUTED))
		v.add_child(_btn("Lihat KelolaPro", D.C_GREEN, func(): open_sheet("upgrade")))
		return
	v.add_child(_label("Laporan KelolaPro", 40))
	var hist: Array = S.get("hist", [])
	var last7: Array = hist.slice(maxi(0, hist.size() - 7))
	if last7.is_empty():
		v.add_child(_text("Grafik muncul setelah hari pertama selesai.", 30, D.C_MUTED))
	else:
		v.add_child(_label("Untung bersih 7 hari terakhir", 32, D.C_MUTED, true))
		var ch := _Bars.new()
		ch.font = font
		ch.vals = last7.map(func(h): return float(h.net))
		ch.labels = last7.map(func(h): return "H%d" % int(h.day))
		ch.custom_minimum_size = Vector2(0, 300)
		v.add_child(ch)
		var avg := 0.0
		for h in last7: avg += float(h.net)
		avg /= last7.size()
		_row(v, _label("Rata-rata per hari", 34, D.C_INK, true), _label(D.rp(avg), 36, Color("2f7a2a") if avg >= 0 else Color("9b2f1c")))
		_row(v, _label("Proyeksi 30 hari", 34, D.C_INK, true), _label(D.rp(avg * 30.0), 36, Color("2f7a2a") if avg >= 0 else Color("9b2f1c")))
	var td: Dictionary = S.today
	v.add_child(_label("Hari ini", 32, D.C_MUTED, true))
	_row(v, _label("Sewa & pemasukan", 32, D.C_INK, true), _label(D.rp(td.rent), 34, Color("2f7a2a")))
	_row(v, _label("Gaji & aplikasi", 32, D.C_INK, true), _label("- " + D.rp(td.salary), 34, Color("9b2f1c")))
	_row(v, _label("Listrik & air", 32, D.C_INK, true), _label("- " + D.rp(td.util), 34, Color("9b2f1c")))
	_row(v, _label("Lain-lain", 32, D.C_INK, true), _label("- " + D.rp(td.other), 34, Color("9b2f1c")))
	var hs := 0.0
	for e in game.each_tenant(): hs += float(e[1].tenant.happy)
	_row(v, _label("Tingkat hunian", 32, D.C_INK, true), _label("%d%%" % roundi(100.0 * occ / maxf(1, tot)), 34))
	_row(v, _label("Rata-rata kebahagiaan", 32, D.C_INK, true), _label("%d%%" % roundi(hs / maxf(1, occ)), 34))
	v.add_child(_label("Kondisi kamar", 32, D.C_MUTED, true))
	for id in D.ROOMS:
		var r: Dictionary = S.rooms[id]
		if not r.built: continue
		var t = r.tenant
		var info := "%s · %s/hari · bersih %d%%" % [t.name if t != null else "Kosong", D.short(game.rent_of(r)), roundi(float(r.clean))]
		if t != null: info += " · senang %d%%" % roundi(float(t.happy))
		var col := D.C_INK
		if t != null and float(t.happy) < 35: col = Color("9b2f1c")
		_row(v, _label(D.room_name(id), 32, D.C_INK), _label(info, 28, col, true))


class _Bars extends Control:
	var vals: Array = []
	var labels: Array = []
	var font: Font
	func _draw() -> void:
		if vals.is_empty(): return
		var mx := 1.0
		for x in vals: mx = maxf(mx, absf(float(x)))
		var n := vals.size()
		var w := size.x / n
		var base := size.y * 0.5 if vals.any(func(x): return float(x) < 0) else size.y - 46
		var top := 30.0
		draw_line(Vector2(0, base), Vector2(size.x, base), Color("c9b49a"), 3)
		for i in range(n):
			var vv := float(vals[i])
			var hgt := (base - top) * absf(vv) / mx
			var r := Rect2(i * w + w * 0.18, base - hgt if vv >= 0 else base, w * 0.64, hgt)
			draw_rect(r, Color("8fc77a") if vv >= 0 else Color("e9a08f"))
			if font:
				draw_string(font, Vector2(i * w, size.y - 8), str(labels[i]), HORIZONTAL_ALIGNMENT_CENTER, w, 26, Color("8a7a68"))
				var t := "%drb" % roundi(vv / 1000.0)
				draw_string(font, Vector2(i * w, (base - hgt - 6) if vv >= 0 else (base + hgt + 26)), t, HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color("5a3d2b"))


var buy_confirm := ""


## Halaman Beli: daftar ke bawah, setiap pembelian dikonfirmasi dulu.
func _sheet_beli() -> void:
	var S: Dictionary = game.S
	_header("Beli")
	var top := HBoxContainer.new()
	top.add_child(_label("Kas: " + D.rp(S.money), 38, Color("2f7a2a"), true))
	box.add_child(top)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	for t in [["perabot", "Perabot"], ["ruang", "Kamar & Ruang"], ["layanan", "Layanan"]]:
		var key: String = t[0]
		tabs.add_child(_btn(t[1], D.C_YELLOW if tray_tab == key else Color.WHITE, func(): tray_tab = key; buy_confirm = ""; refresh_sheet(), false, true))
	box.add_child(tabs)
	match tray_tab:
		"perabot":
			var otw: int = S.orders.size()
			var inbox: int = S.cargo.size()
			var eta := ""
			if otw > 0:
				var mn := 9999.0
				for o in S.orders: mn = minf(mn, float(o.t))
				eta = " (tiba ± %d menit)" % maxi(1, roundi(mn))
			var st := _card()
			st.add_child(_text("Pesanan dikirim pakai pickup. Setelah datang, tutup halaman ini lalu seret kotaknya ke kamar (kalau kamar sudah punya barangnya = upgrade ke level berikutnya).", 30, D.C_MUTED))
			st.add_child(_label("Dalam perjalanan: %d%s · Di pickup: %d · Slot %d/%d" % [otw, eta, inbox, otw + inbox, game.CARGO_MAX], 30, D.C_INK, true))
			for t in D.FURN_ORDER:
				var f: Dictionary = D.FURN[t]
				var ok := int(S.lvl) >= int(f.min)
				var have := 0
				var built := 0
				for id in D.ROOMS:
					if S.rooms[id].built:
						built += 1
						if S.rooms[id].furn.has(t): have += 1
				_buy_row("furn:" + t, load("res://assets/furn/icon/%s.png" % t), f.n, f.d, "Terpasang di %d/%d kamar" % [have, built] if ok else "Terbuka di Level %d" % int(f.min), float(f.cost), ok, "Pesan", func(): game.act("buy", t))
		"ruang":
			var at := AtlasTexture.new()
			at.atlas = game.shell_tex
			at.region = D.rect_of("3R")
			var empty := 0
			for id in D.ROOMS:
				if not S.rooms[id].built and game.floor_open(D.fl(id)): empty += 1
			_buy_row("build", at, "Kamar Baru", "Dibangun tukang di lahan kosong. Setelah jadi, beli kasur supaya bisa disewa.", "Lahan siap dibangun: %d" % empty, game.build_cost(), empty > 0, "Pilih lahan", func(): game.start_place("build", ""), false)
			for k in D.FACIL_ORDER:
				var fc: Dictionary = D.FACIL[k]
				var owned: bool = game.has_facil(k)
				var lvok := int(S.lvl) >= int(fc.lv)
				var sub: String = ("Sudah dibangun di lantai %d" % game.facil_floor(k)) if owned else ("" if lvok else "Terbuka di Level %d" % int(fc.lv))
				_buy_row("facil:" + k, load("res://assets/facil/%s.png" % k), fc.n, fc.d, sub, float(fc.cost), lvok and not owned, "Pilih tempat", func(): game.start_place("facil", k), false)
		"layanan":
			for k in D.FAC:
				var f2: Dictionary = D.FAC[k]
				var own2: bool = S.fac.has(k)
				var ok3 := int(S.lvl) >= int(f2.min)
				var ic: Texture2D = load("res://assets/fac/%s.svg" % k) if ResourceLoader.exists("res://assets/fac/%s.svg" % k) else null
				_buy_row("fac:" + k, ic, f2.n, f2.d, "Sudah dimiliki" if own2 else ("" if ok3 else "Terbuka di Level %d" % int(f2.min)), float(f2.cost), ok3 and not own2, "Beli", func(): game.act("buy_fac", k))
			for k in D.APP_ORDER:
				var ap: Dictionary = D.APPS[k]
				var on: bool = game.has_app(k)
				_buy_row("app:" + k, load("res://assets/fac/%s.svg" % k), ap.n, ap.tag + " · " + D.short(ap.month) + "/bulan", "Aktif" if on else ("" if int(S.lvl) >= int(ap.lv) else "Terbuka di Level %d" % int(ap.lv)), float(ap.fee), int(S.lvl) >= int(ap.lv) and not on, "Pasang", func(): game.act("app_on", k), true, "/hari")
			var dv := _card()
			_row(dv, _label("Toko Diamond · %d Diamond" % int(game.W.diamonds), 38), _btn("Buka", D.C_CREAM, func(): open_sheet("toko")))


func _buy_row(key: String, tex: Texture2D, title: String, desc: String, sub: String, price: float, ok: bool, verb: String, fn: Callable, money_now := true, unit := "") -> void:
	var S: Dictionary = game.S
	var v := _card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(190, 160)
	if not ok: tr.modulate = Color(1, 1, 1, 0.45)
	h.add_child(tr)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(_label(title, 40))
	if desc != "": mid.add_child(_text(desc, 28, D.C_MUTED))
	if sub != "": mid.add_child(_label(sub, 28, Color("8a5a3a"), true))
	h.add_child(mid)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 8)
	var pl := _label(D.rp(price) + unit, 34, Color("2f7a2a") if ok else D.C_MUTED, true)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(pl)
	if ok:
		var poor0: bool = money_now and float(S.money) < price
		right.add_child(_btn(verb, D.C_YELLOW, func(): buy_confirm = key; refresh_sheet(), poor0, false, money_why(price)))
	elif sub != "":
		right.add_child(_btn("Terkunci", D.C_CREAM, func(): pass, true, false, sub))
	h.add_child(right)
	v.add_child(h)
	if buy_confirm == key:
		var cf := _card()
		var poor: bool = money_now and float(S.money) < price
		cf.add_child(_label(("Uang belum cukup untuk %s." % title) if poor else ("Beli %s seharga %s%s?" % [title, D.rp(price), unit]), 34, Color("9b2f1c") if poor else D.C_INK, true))
		var f := _flow(cf)
		f.add_child(_btn("Batal", D.C_CREAM, func(): buy_confirm = ""; refresh_sheet()))
		if not poor:
			f.add_child(_btn("Ya, " + verb.to_lower(), D.C_GREEN, func():
				buy_confirm = ""
				fn.call()
				if kind == "beli": refresh_sheet()))
		v.add_child(cf)


func _sheet_floors() -> void:
	var S: Dictionary = game.S
	_header("Pindah ke lantai")
	box.add_child(_text("Gedung bisa terus ditinggikan. Lantai 9 ke atas dibuka dengan renovasi.", 30, D.C_MUTED))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	box.add_child(g)
	for f in range(D.TOP_FLOOR, 0, -1):
		var occ := 0
		for c in ["L", "R"]:
			var r = S.rooms.get("%d%s" % [f, c])
			if r and r.tenant != null: occ += 1
		var lbl := "Lantai %d" % f + (" (%d)" % occ if occ > 0 else "")
		var ff := f
		var col := D.C_YELLOW if game.floor_open(f) else Color("e2d9cc")
		var b := _btn(lbl, col, func(): game.jump_to_floor(ff))
		b.custom_minimum_size = Vector2(300, 90)
		g.add_child(b)
	box.add_child(_btn("Ke lobi (bawah)", D.C_GREEN, func(): game.set_scroll(0.0); close_sheet()))


func _sheet_toko() -> void:
	var Wl: Dictionary = game.W
	_header("Toko")
	var top := _card()
	_row(top, _label("Diamond kamu", 38), _label("%d" % int(Wl.diamonds), 44, Color("2f5d7c"), true))
	_row(top, _label("Tiket Ngebut", 38), _label("%d" % int(Wl.tickets), 44, D.C_INK, true))
	var tt: String = game.turbo_text()
	if tt != "": top.add_child(_text("Mode 2x masih aktif: sisa %s di game." % tt, 30, Color("2f7a2a")))
	for k in game.SHOP:
		var it: Dictionary = game.SHOP[k]
		var v := _card()
		var desc: String = it.d
		if it.has("money"): desc = "+%s ke kas kost" % D.rp(game.shop_money(k))
		_row(v, _label(it.n, 38), _btn("%d Diamond" % int(it.cost), D.C_YELLOW, func(): _do("shop", k), int(Wl.diamonds) < int(it.cost)))
		v.add_child(_text(desc, 30, D.C_MUTED))
	var dv := _card()
	dv.add_child(_label("Beli Diamond", 40))
	for pk in game.DIAMOND_PACKS:
		_row(dv, _label("%s Diamond" % pk[0], 34), _label(pk[1], 34, D.C_MUTED, true))
	dv.add_child(_text("Pembelian Diamond lewat Google Play tersedia di aplikasi Android (segera hadir). Di versi web ini belum bisa membeli.", 30, D.C_MUTED))


func _sheet_preman() -> void:
	var amt: float = game.preman_amount()
	_header("Preman minta pungli")
	var tr := TextureRect.new()
	tr.texture = load("res://assets/chars/preman/demand_L.png")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(0, 300)
	box.add_child(tr)
	box.add_child(_text("\"Bos, uang keamanan bulan ini %s. Biar kost-nya aman, ngerti kan?\"" % D.rp(amt), 36, D.C_INK))
	var on: bool = game.S.staff.get("satpam", false)
	var opts := [
		["Bayar " + D.short(amt), D.C_YELLOW, "pay", "Aman untuk sekarang, tapi preman akan datang lagi lebih sering & minta lebih banyak."],
		["Tolak", D.C_CREAM, "refuse", "Aji (Satpam) akan mengusirnya." if on else "Tanpa Satpam, preman marah & menakuti penghuni."],
		["Lapor polisi · Rp 50rb", D.C_GREEN, "police", "Preman ditangkap & tidak datang lama. Rating naik."],
	]
	for o in opts:
		var v := _card()
		var arg: String = o[2]
		v.add_child(_btn(o[0], o[1], func(): _do("preman", arg)))
		v.add_child(_text(o[3], 30, D.C_MUTED))


func _sheet_rename() -> void:
	_header("Ganti nama kost")
	var le := LineEdit.new()
	le.text = str(game.S.get("kost_name", "Kost Harmoni"))
	le.max_length = 22
	le.add_theme_font_override("font", font)
	le.add_theme_font_size_override("font_size", 52)
	le.custom_minimum_size = Vector2(0, 100)
	var ls := _sb(Color.WHITE, 5, 22, 26, 0)
	le.add_theme_stylebox_override("normal", ls)
	le.add_theme_stylebox_override("focus", ls)
	le.add_theme_color_override("font_color", D.C_INK)
	box.add_child(le)
	var f := _flow(box)
	f.add_child(_btn("Simpan", D.C_YELLOW, func(): _do("rename", le.text); close_sheet()))


func _sheet_welcome() -> void:
	_header("Selamat datang, Juragan Kost!", false)
	box.add_child(_text("Kamu baru mewarisi " + str(game.S.get("kost_name", "Kost Harmoni")) + ". Kelola kamar, terima penyewa, dan jadikan kost ini yang paling nyaman se-kota!", 40))
	var tips := [
		"Tahan & seret calon penyewa dari lobi ke kamar kosong yang sudah ada kasurnya.",
		"Tombol Beli: ketuk perabot untuk memesan. Pickup datang membawa kotaknya, lalu tahan & seret kotak ke kamar. Seret kartu Kamar Baru ke lahan kosong untuk membangun.",
		"Makin lengkap & bagus perabotnya, makin nyaman kamarnya dan makin mahal sewanya.",
		"Sewa ditagih pukul 09:00, gaji karyawan pukul 17:00, listrik & air tiap tengah malam.",
		"Penghuni punya rutinitas: berangkat kuliah/kerja, pulang, santai, dan tidur di kamarnya.",
		"Ketuk jam di kanan atas untuk mempercepat atau menjeda waktu."]
	for t in tips:
		box.add_child(_text("•  " + t, 36))
	var f := _flow(box)
	f.add_child(_btn("Mulai Main", D.C_YELLOW, func(): _do("start")))


func _cand_card(p: Dictionary, room_ctx: String = "") -> void:
	var S: Dictionary = game.S
	var v := _card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	_avatar(h, p)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_label("%s  ·  %s" % [p.name, p.job], 42))
	var pref: String = D.RLV[int(p.pref)].n
	var fit := ""
	if room_ctx != "":
		fit = "  ·  Cocok" if int(S.rooms[room_ctx].lv) >= int(p.pref) else "  ·  Ingin kamar lebih bagus"
	info.add_child(_text("Ingin kamar %s · %d hari%s" % [pref, int(p.days), fit], 34, D.C_MUTED))
	var where := ""
	var qi: int = S.queue.find(p)
	if p.get("auto", false):
		where = "  ·  di Ruang Tunggu, otomatis masuk kamar kosong"
	elif qi >= 1 and game.waiting_room_on():
		where = "  ·  di Ruang Tunggu (antrean %d)" % qi
	info.add_child(_text("Menunggu %d jam%s%s" % [int(p.wait), "  ·  dari KostTerdekat" if p.get("via", "") != "" else "", where], 34, D.C_MUTED))
	h.add_child(info)
	v.add_child(h)
	_screen_box(v, p)
	var f := _flow(v)
	if room_ctx == "" and not p.get("auto", false):
		f.add_child(_btn("Ke Ruang Tunggu", D.C_CREAM, func(): _do("waitroom", str(p.id)), not game.has_facil("tunggu"), false, "Bangun Ruang Tunggu dulu (menu Beli › Kamar & Ruang)."))
	if room_ctx != "":
		f.add_child(_btn("Terima di " + D.room_name(room_ctx), D.C_GREEN, func(): _do("assign", "%s|%s" % [p.id, room_ctx])))
	elif sel == p.id:
		var er: Array = game.empty_rooms()
		if er.is_empty():
			f.add_child(_text("Tidak ada kamar kosong. Bangun kamar baru di menu Beli.", 34, D.C_MUTED))
		for rid in er:
			var r: Dictionary = S.rooms[rid]
			var ok := int(r.lv) >= int(p.pref)
			f.add_child(_btn("%s · %s%s" % [D.room_name(rid), D.RLV[int(r.lv)].n, " ✓" if ok else ""], D.C_YELLOW, func(): _do("assign", "%s|%s" % [p.id, rid])))
		f.add_child(_btn("Batal", D.C_CREAM, func(): sel = ""; refresh_sheet()))
	else:
		f.add_child(_btn("Terima", D.C_GREEN, func(): sel = p.id; refresh_sheet()))
		f.add_child(_btn("Tolak", D.C_RED, func(): _do("reject", p.id)))


## Hasil & tombol pemeriksaan latar belakang calon penyewa.
func _screen_box(v: Control, p: Dictionary) -> void:
	var S: Dictionary = game.S
	var chk: Dictionary = p.get("checked", {})
	v.add_child(_label("Cek latar belakang", 34, Color("8a5a3a"), true))
	for ck in D.CHECK_ORDER:
		var c: Dictionary = D.CHECKS[ck]
		if chk.has(ck):
			var found: Array = game.found_traits(p, ck)
			var row := _flow(v)
			row.add_child(_label("%s:" % c.n, 30, D.C_INK))
			if found.is_empty():
				row.add_child(_chip("Aman", Color("dff0d6"), Color("2f6a24")))
			for k in found:
				var tr: Dictionary = D.TRAITS[k]
				row.add_child(_chip(tr.n, Color("f8d9d2") if tr.bad else Color("dff0d6"), Color("9b2f1c") if tr.bad else Color("2f6a24")))
			for k in found:
				if D.TRAITS[k].bad:
					v.add_child(_text("• " + D.TRAITS[k].d, 28, Color("9b2f1c")))
		elif int(S.lvl) >= int(c.lv):
			var row2 := _flow(v)
			var free: bool = int(c.cost) == 0 or (ck == "riwayat" and game.has_app("kelolapro"))
			var price := "gratis" if free else D.short(c.cost)
			row2.add_child(_btn("%s · %s" % [c.n, price], D.C_CREAM, func(): _do("screen", "%s|%s" % [p.id, ck]), not free and float(S.money) < float(c.cost)))
			row2.add_child(_label(c.d, 26, D.C_MUTED))


func _chip(t: String, bg: Color, fg: Color) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _sb(bg, 0, 20, 14, 4))
	pc.add_child(_label(t, 28, fg, true))
	return pc


func _sheet_room() -> void:
	var S: Dictionary = game.S
	var id := arg
	var r: Dictionary = S.rooms[id]
	if not r.built:
		var fln := D.fl(id)
		_header("Lahan Kamar " + D.room_name(id))
		_room_pic(box, id)
		var v := _card()
		if int(S.lvl) < fln:
			v.add_child(_text("Lantai %d terbuka di Level %d." % [fln, fln], 38))
		elif not game.floor_open(fln):
			v.add_child(_label("Renovasi lantai %d" % fln, 40))
			v.add_child(_text("Lantai di atas 8 perlu direnovasi sebelum kamarnya dibangun. Syarat: Level %d, rating minimal %.1f." % [fln, D.floor_rep(fln)], 32, D.C_MUTED))
			v.add_child(_text("Kamar makin tinggi = sewa makin mahal (+3%%/lantai). Tanpa Lift, penghuni lantai atas cepat capek.", 30, D.C_MUTED))
			var nxt: int = int(S.get("open_floor", 8)) + 1
			if fln == nxt:
				v.add_child(_btn("Renovasi " + D.short(D.floor_cost(fln)), D.C_YELLOW, func(): game.renovate_floor(fln), float(S.rep) < D.floor_rep(fln) or float(S.money) < D.floor_cost(fln), false, ("Rating kost harus minimal %.1f" % D.floor_rep(fln)) if float(S.rep) < D.floor_rep(fln) else money_why(D.floor_cost(fln))))
			else:
				v.add_child(_text("Renovasi lantai %d dulu." % nxt, 32, D.C_MUTED))
		else:
			var c: float = game.build_cost()
			if game.job_for(id, "build") != {}:
				v.add_child(_text("%s sedang membangun kamar ini." % D.worker_label("build"), 38))
				return
			v.add_child(_text("Bangun kamar Standar baru di sini.", 38))
			_row(v, _label(D.rp(c), 42), _btn("Bangun", D.C_GREEN, func(): _do("build", id), float(S.money) < c, false, money_why(c)))
		return
	_header("Kamar %s · %s" % [D.room_name(id), D.RLV[int(r.lv)].n])
	var evr: Dictionary = game.event_at(id)
	if not evr.is_empty():
		_event_card(evr)
	_room_live(box, id, 1.55)
	var v := _card()
	_row(v, _label("Sewa", 38, D.C_INK, true), _label(D.rp(game.rent_of(r)) + "/hari", 40))
	_row(v, _label("Kebersihan", 38, D.C_INK, true), _label("%d%%" % roundi(float(r.clean)), 36, D.C_MUTED))
	_bar(v, float(r.clean))
	if str(r.broken) != "":
		var cost: int = D.ISSUES[r.broken]
		_row(v, _label("Kerusakan: " + str(r.broken), 38), (_label("%s datang..." % D.WORKER.fix.nama, 34, Color("3f6f96"), true) if game.job_for(id, "fix") != {} else _btn("Panggil Teknisi " + D.short(cost), D.C_YELLOW, func(): _do("fix", id), float(S.money) < cost, false, money_why(cost))))
	else:
		v.add_child(_label("Semua fasilitas berfungsi", 34, D.C_MUTED, true))
	var f := _flow(v)
	f.add_child(_btn("Bersihkan (Rp 15rb)", D.C_GREEN, func(): _do("clean", id), float(r.clean) >= 99 or float(S.money) < 15000, false, "Kamar sudah bersih (%d%%)." % roundi(float(r.clean)) if float(r.clean) >= 99 else money_why(15000)))
	_furn_card(id)
	if r.tenant != null:
		var t: Dictionary = r.tenant
		var pr: String = game.presence(t)
		var st: String = {"away": "Sedang di luar", "sleep": "Sedang tidur", "work": "Sedang kerja di kamar", "sit": "Sedang santai di kamar"}[pr]
		var tv := _card()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 22)
		_avatar(h, t)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label("%s  ·  %s" % [t.name, t.job], 42))
		info.add_child(_text("%s · sisa %d hari · ingin kamar %s" % [st, maxi(0, int(t.days) - int(t.stay)), D.RLV[int(t.pref)].n], 34, D.C_MUTED))
		h.add_child(info)
		tv.add_child(h)
		_row(tv, _label("Kebahagiaan", 38, D.C_INK, true), _label("%d%%" % roundi(float(t.happy)), 36, D.C_MUTED))
		_bar(tv, float(t.happy))
		var ff := _flow(tv)
		if confirm == "evict" + id:
			ff.add_child(_btn("Yakin usir? (rating turun)", D.C_RED, func(): _do("evict", id)))
			ff.add_child(_btn("Batal", D.C_CREAM, func(): confirm = ""; refresh_sheet()))
		else:
			ff.add_child(_btn("Usir penyewa", D.C_CREAM, func(): confirm = "evict" + id; refresh_sheet()))
	else:
		box.add_child(_text("Kamar kosong. Pilih dari antrean:", 36, D.C_MUTED))
		if S.queue.is_empty() and game.is_sepi():
			var sv := _card()
			sv.add_child(_label("Kost sedang sepi", 40, Color("9b2f1c")))
			sv.add_child(_text("Sejak Level %d, calon penyewa jauh lebih jarang datang. Promosikan kost di aplikasi KostTerdekat supaya ramai lagi." % game.SEPI_LV, 32, D.C_MUTED))
			sv.add_child(_btn("Buka Fasilitas Kost", D.C_GREEN, func(): open_sheet("upgrade")))
		elif S.queue.is_empty():
			_card().add_child(_text("Belum ada calon penyewa. Tunggu sebentar, atau naikkan rating kost.", 36, D.C_MUTED))
		for p in S.queue:
			_cand_card(p, id)


func _sheet_tenants() -> void:
	var S: Dictionary = game.S
	_header("Penyewa")
	var ten := []
	for rid in D.ROOMS:
		if S.rooms[rid].tenant != null:
			ten.append(rid)
	var due: float = game.due_total()
	if due > 0:
		var dv := _card()
		_row(dv, _label("Sewa belum ditagih: " + D.rp(due), 36, Color("8a5a10"), true), _btn("Tagih semua", D.C_YELLOW, func(): _do("collect_all")))
		if not game.has_app("kelolapro"):
			dv.add_child(_text("Pasang KelolaPro supaya sewa ditagih otomatis setiap pagi.", 28, D.C_MUTED))
	_tabs([["antre", "Antrean (%d)" % S.queue.size()], ["huni", "Penghuni (%d)" % ten.size()]])
	if tab == "antre":
		if S.queue.is_empty():
			_card().add_child(_text("Belum ada calon penyewa. Rating tinggi, harga terjangkau, fasilitas lengkap & resepsionis membuat tamu lebih sering datang.", 36, D.C_MUTED))
		for p in S.queue:
			_cand_card(p)
	else:
		if ten.is_empty():
			_card().add_child(_text("Belum ada penghuni.", 36, D.C_MUTED))
		for rid in ten:
			var t: Dictionary = S.rooms[rid].tenant
			var v := _card()
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 22)
			_avatar(h, t)
			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_child(_label("%s  ·  Kamar %s" % [t.name, D.room_name(rid)], 42))
			info.add_child(_text("%s · %s · sisa %d hari" % [t.job, {"away": "di luar", "sleep": "tidur", "work": "kerja", "sit": "santai"}[game.presence(t)], maxi(0, int(t.days) - int(t.stay))], 34, D.C_MUTED))
			_bar(info, float(t.happy))
			h.add_child(info)
			v.add_child(h)
			var known := []
			for ck in t.get("checked", {}):
				known += game.found_traits(t, ck)
			if not known.is_empty():
				var tf := _flow(v)
				for k in known:
					var tr: Dictionary = D.TRAITS[k]
					tf.add_child(_chip(tr.n, Color("f8d9d2") if tr.bad else Color("dff0d6"), Color("9b2f1c") if tr.bad else Color("2f6a24")))
			var f := _flow(v)
			f.add_child(_btn("Lihat kamar", D.C_CREAM, func(): open_sheet("room", rid)))


const STAFF_PIC := {"cleaner": "kebersihan/happy", "resep": "penjaga/happy", "teknisi": "teknisi/idle", "satpam": "satpam/idle",
	"laundry": "laundry/happy", "kantin": "kantin/idle", "barista": "barista/idle", "kasir": "kasir/idle"}


func _sheet_staff() -> void:
	var S: Dictionary = game.S
	_header("Karyawan")
	var tot := 0
	for k in S.staff:
		if S.staff[k]:
			tot += int(D.STAFF[k].sal)
	var appfee := 0
	for k in S.get("apps", {}):
		appfee += roundi(D.APPS[k].fee)
	box.add_child(_text("Total gaji: %s/hari%s (dibayar pukul 17:00)" % [D.rp(tot), (" + aplikasi " + D.rp(appfee)) if appfee > 0 else ""], 36, D.C_MUTED))
	for k in D.STAFF:
		var st: Dictionary = D.STAFF[k]
		var on: bool = S.staff.get(k, false)
		var v := _card()
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 24)
		var pic := TextureRect.new()
		pic.texture = load("res://assets/chars/%s_L.png" % STAFF_PIC.get(k, "penjaga/happy"))
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(170, 250)
		if int(S.lvl) < int(st.min): pic.modulate = Color(0.3, 0.3, 0.3, 0.6)
		hb.add_child(pic)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(col)
		v.add_child(hb)
		_row(col, _label(st.nama, 42), _label(D.rp(st.sal) + "/hari", 32, D.C_MUTED, true))
		col.add_child(_label(st.n, 32, Color("8a5a3a"), true))
		col.add_child(_text(st.d, 30, D.C_MUTED))
		var f := _flow(col)
		if int(S.lvl) < int(st.min):
			f.add_child(_label("Terbuka di Level %d" % int(st.min), 34, D.C_MUTED, true))
		elif st.has("need") and not game.has_facil(st.need) and not on:
			f.add_child(_label("Butuh ruang %s dulu" % D.FACIL[st.need].n, 34, D.C_MUTED, true))
		elif on:
			f.add_child(_btn("Berhentikan", D.C_RED, func(): _do("fire", k)))
			f.add_child(_label("  Sedang bekerja", 34, Color("2f7a2a"), true))
		else:
			f.add_child(_btn("Rekrut", D.C_YELLOW, func(): _do("hire", k)))


func _sheet_facil() -> void:
	var S: Dictionary = game.S
	var f := int(arg)
	var k: String = S.facil.get(arg, "")
	var j: Dictionary = game.job_for("S%d" % f, "fbuild")
	if k != "":
		var fc: Dictionary = D.FACIL[k]
		_header("%s · lantai %d" % [fc.n, f])
		_fac_pic(box, k, 520)
		var v := _card()
		v.add_child(_text(fc.d, 34, D.C_MUTED))
		if int(fc.happy) > 0: v.add_child(_text("+%d kebahagiaan harian untuk semua penghuni" % int(fc.happy), 32, Color("2f7a2a")))
		if fc.has("staff"):
			var st: Dictionary = D.STAFF[fc.staff]
			var on: bool = S.staff.get(fc.staff, false)
			_row(v, _label("%s · %s" % [st.nama, st.n], 36), _label("Sedang bekerja", 32, Color("2f7a2a"), true) if on else _btn("Rekrut " + D.short(st.sal) + "/hari", D.C_YELLOW, func(): _do("hire", fc.staff)))
		return
	if not j.is_empty():
		_header("Lantai %d · sedang dibangun" % f)
		_fac_pic(box, str(j.item), 520)
		box.add_child(_text("%s sedang membangun %s." % [D.worker_label("build"), D.FACIL[j.item].n], 36, D.C_MUTED))
		return
	_header("Sisi tangga lantai %d" % f)
	box.add_child(_text("Bangun satu ruang fasilitas di sini. Bisa juga diseret dari menu Beli.", 34, D.C_MUTED))
	for key in D.FACIL_ORDER:
		var fc2: Dictionary = D.FACIL[key]
		if game.has_facil(key): continue
		var v2 := _card()
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 20)
		_fac_pic(hb, key, 170)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_label(fc2.n, 40))
		col.add_child(_text(fc2.d, 30, D.C_MUTED))
		var why: String = game.facil_ok(f, key)
		if int(S.lvl) < int(fc2.lv):
			col.add_child(_label("Terbuka di Level %d" % int(fc2.lv), 32, D.C_MUTED, true))
		else:
			col.add_child(_btn("Bangun " + D.short(fc2.cost), D.C_GREEN, func(): _do("facil_build", "%d|%s" % [f, key]), why != ""))
		hb.add_child(col)
		v2.add_child(hb)


func _fac_pic(parent: Control, k: String, h: float) -> void:
	var tr := TextureRect.new()
	tr.texture = load("res://assets/facil/%s.png" % k)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(h * 0.55, h)
	parent.add_child(tr)


func _sheet_upgrade() -> void:
	var S: Dictionary = game.S
	_header("Fasilitas Kost")
	box.add_child(_text("Setiap fasilitas: +kebahagiaan harian, +4% harga sewa, dan tamu lebih sering datang. Perabot kamar dibeli lewat tombol Beli.", 34, D.C_MUTED))
	for k in D.FAC:
		var fc: Dictionary = D.FAC[k]
		var v := _card()
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 20)
		var ic := TextureRect.new()
		ic.texture = load("res://assets/fac/%s.svg" % k)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(170, 144)
		head.add_child(ic)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		head.add_child(col)
		v.add_child(head)
		v = col
		var right: Control
		if S.fac.get(k, false):
			right = _label("Dimiliki", 34, Color("2f7a2a"), true)
		elif int(S.lvl) < int(fc.min):
			right = _label("Level %d" % int(fc.min), 34, D.C_MUTED, true)
		else:
			right = _btn(D.short(fc.cost), D.C_GREEN, func(): _do("buy_fac", k), float(S.money) < float(fc.cost), false, money_why(float(fc.cost)))
		_row(v, _label(fc.n, 40), right)
		if fc.d != "":
			v.add_child(_text(fc.d, 32, D.C_MUTED))
	# Aplikasi langganan
	box.add_child(_label("Aplikasi", 44))
	box.add_child(_text("Langganan bulanan, ditagih per hari bersama gaji pukul 17:00. Bisa dihentikan kapan saja.", 32, D.C_MUTED))
	for k in D.APP_ORDER:
		var ap: Dictionary = D.APPS[k]
		var v := _card()
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 20)
		var ic := TextureRect.new()
		ic.texture = load("res://assets/fac/%s.svg" % k)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(150, 170)
		hb.add_child(ic)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(col)
		v.add_child(hb)
		var right: Control
		var on: bool = game.has_app(k)
		if on:
			right = _btn("Berhenti", D.C_RED, func(): _do("app_off", k))
		elif int(S.lvl) < int(ap.lv):
			right = _label("Level %d" % int(ap.lv), 34, D.C_MUTED, true)
		else:
			right = _btn("Pasang", D.C_GREEN, func(): _do("app_on", k))
		_row(col, _label(ap.n, 40), right)
		col.add_child(_label("%s · %s/bulan (± %s/hari)%s" % [ap.tag, D.short(ap.month), D.rp(roundi(ap.fee)), "  · Aktif" if on else ""], 30, Color("2f7a2a") if on else Color("8a5a3a"), true))
		for perk in ap.perks:
			col.add_child(_text("• " + perk, 30, D.C_MUTED))
	# Ruang fasilitas di samping tangga + karyawannya
	var sec := _label("Ruang Fasilitas", 44)
	box.add_child(sec)
	box.add_child(_text("Dibangun tukang di sisi kosong tangga. Bisa juga diseret dari menu Beli ke lantai pilihanmu.", 32, D.C_MUTED))
	for k in D.FACIL_ORDER:
		var fc: Dictionary = D.FACIL[k]
		var v := _card()
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 20)
		_fac_pic(hb, k, 190)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_child(col)
		v.add_child(hb)
		var right: Control
		var fl: int = game.facil_floor(k)
		var building := false
		for j in S.jobs:
			if j.type == "fbuild" and j.item == k: building = true
		if fl > 0:
			right = _label("Lantai %d" % fl, 34, Color("2f7a2a"), true)
		elif building:
			right = _label("Dibangun", 34, D.C_MUTED, true)
		elif int(S.lvl) < int(fc.lv):
			right = _label("Level %d" % int(fc.lv), 34, D.C_MUTED, true)
		else:
			var ff: int = game.free_facil_floor()
			right = _btn(D.short(fc.cost), D.C_GREEN, func(): _do("facil_build", "%d|%s" % [ff, k]), ff == 0 or float(S.money) < float(fc.cost))
		_row(col, _label(fc.n, 40), right)
		col.add_child(_text(fc.d, 30, D.C_MUTED))
		if fc.has("staff"):
			var st: Dictionary = D.STAFF[fc.staff]
			var on: bool = S.staff.get(fc.staff, false)
			var sr: Control
			if on:
				sr = _btn("Berhentikan", D.C_RED, func(): _do("fire", fc.staff))
			elif fl == 0:
				sr = _label("Bangun dulu", 30, D.C_MUTED, true)
			elif int(S.lvl) < int(st.min):
				sr = _label("Level %d" % int(st.min), 30, D.C_MUTED, true)
			else:
				sr = _btn("Rekrut", D.C_YELLOW, func(): _do("hire", fc.staff))
			_row(col, _label("%s (%s) · %s/hari" % [st.nama, st.n, D.short(st.sal)], 30, D.C_INK), sr)


func _sheet_manage() -> void:
	var S: Dictionary = game.S
	_header("Kelola " + str(S.get("kost_name", "Kost Harmoni")))
	var nv := _card()
	_row(nv, _label(str(S.get("kost_name", "Kost Harmoni")), 40), _btn("Ganti nama", D.C_CREAM, func(): ask_rename()))
	var nf := _flow(nv)
	nf.add_child(_btn("Ulangi tutorial", D.C_CREAM, func(): _do("tutorial")))
	nf.add_child(_btn("Putar cerita awal", D.C_CREAM, func(): _do("intro")))
	if S.events.is_empty():
		_card().add_child(_text("Tidak ada masalah. Kost aman & tenteram.", 34, Color("2f7a2a")))
	for e in S.events:
		_event_card(e)
	var occ := 0
	var tot := 0
	for id in D.ROOMS:
		if S.rooms[id].built:
			tot += 1
			if S.rooms[id].tenant != null:
				occ += 1
	var v := _card()
	_row(v, _label("Rating", 38, D.C_INK, true), _label("%.1f / 5" % float(S.rep), 40))
	_row(v, _label("Hunian", 38, D.C_INK, true), _label("%d/%d kamar" % [occ, tot], 40))
	_row(v, _label("Total pendapatan sewa", 38, D.C_INK, true), _label(D.rp(S.total.rent), 40))
	_row(v, _label("Penghuni selesai", 38, D.C_INK, true), _label("%d orang" % int(S.total.served), 40))
	var fl := []
	for k in S.fac:
		fl.append(D.FAC[k].n)
	if fl.size() > 0:
		v.add_child(_text("Fasilitas: " + ", ".join(fl), 34, D.C_MUTED))
	_kelolapro_stats(occ, tot)
	var pv := _card()
	pv.add_child(_label("Harga sewa", 42))
	pv.add_child(_text("Murah: penghuni lebih senang & tamu lebih sering. Mahal: untung besar, tapi kurang disukai.", 32, D.C_MUTED))
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 14)
	for i in range(3):
		var pr: Dictionary = D.PRICE[i]
		ph.add_child(_btn("%s %d%%" % [pr.n, roundi(pr.m * 100)], D.C_YELLOW if int(S.price) == i else Color.WHITE, func(): _do("price", str(i)), false, true))
	pv.add_child(ph)
	var mv := _card()
	var mon: bool = S.get("music", true)
	_row(mv, _label("Musik lofi", 42), _btn("Nyala" if mon else "Mati", D.C_GREEN if mon else Color.WHITE, func(): game.set_music(not mon); refresh_sheet()))
	var son: bool = S.get("sfx", true)
	_row(mv, _label("Efek suara", 42), _btn("Nyala" if son else "Mati", D.C_GREEN if son else Color.WHITE, func(): _do("sfx")))
	for vk in [["music", "Volume musik"], ["sfx", "Volume efek suara"]]:
		var key: String = vk[0]
		var cur: int = game.vol(key)
		var vr := HBoxContainer.new()
		vr.add_theme_constant_override("separation", 22)
		var vl := _label(vk[1], 36)
		vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vr.add_child(vl)
		var mb := _btn("−", D.C_CREAM, func(): game.set_vol(key, cur - 10); refresh_sheet(), cur <= 0, false, "Sudah paling pelan")
		mb.custom_minimum_size.x = 110
		vr.add_child(mb)
		var pl := _label("%d%%" % cur, 38, D.C_INK, true)
		pl.custom_minimum_size.x = 120
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vr.add_child(pl)
		var pb := _btn("+", D.C_CREAM, func(): game.set_vol(key, cur + 10); refresh_sheet(), cur >= 100, false, "Sudah paling keras")
		pb.custom_minimum_size.x = 110
		vr.add_child(pb)
		mv.add_child(vr)
	var sv := _card()
	sv.add_child(_label("Kecepatan waktu", 42))
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 14)
	for s in [[0, "Jeda"], [1, "1x"], [2, "2x"]]:
		sh.add_child(_btn(s[1], D.C_YELLOW if int(S.speed) == s[0] else Color.WHITE, func(): _do("speed", str(s[0])), false, true))
	sv.add_child(sh)
	var tt: String = game.turbo_text()
	sv.add_child(_text(("Sisa 2x: %s · " % tt if tt != "" else "") + "Tiket Ngebut: %d (1 tiket = 2x selama 7 hari di game)" % int(game.W.tickets), 30, D.C_MUTED))
	sv.add_child(_btn("Toko Diamond", D.C_CREAM, func(): open_sheet("toko")))
	var lv := _card()
	var L = S.get("last")
	if L == null:
		lv.add_child(_label("Laporan kemarin", 42))
		lv.add_child(_text("Belum ada laporan. Tunggu sampai tengah malam.", 34, D.C_MUTED))
	else:
		lv.add_child(_label("Laporan Hari %d" % int(L.day), 42))
		_row(lv, _label("Sewa masuk", 34, D.C_MUTED, true), _label(D.rp(L.rent), 34, D.C_MUTED, true))
		_row(lv, _label("Gaji karyawan", 34, D.C_MUTED, true), _label("-" + D.rp(L.salary), 34, D.C_MUTED, true))
		_row(lv, _label("Listrik & air", 34, D.C_MUTED, true), _label("-" + D.rp(L.util), 34, D.C_MUTED, true))
		_row(lv, _label("Lain-lain", 34, D.C_MUTED, true), _label(("-" if float(L.other) > 0 else "+") + D.rp(absf(float(L.other))), 34, D.C_MUTED, true))
		_row(lv, _label("Bersih", 40), _label(D.rp(L.net), 40, Color("2f7a2a") if float(L.net) >= 0 else Color("c0392b")))
	var f := _flow(box)
	if confirm == "reset":
		f.add_child(_btn("Ya, mulai ulang dari awal", D.C_RED, func(): _do("reset")))
		f.add_child(_btn("Batal", D.C_CREAM, func(): confirm = ""; refresh_sheet()))
	else:
		f.add_child(_btn("Mulai Ulang Game", D.C_CREAM, func(): confirm = "reset"; refresh_sheet()))


# ---------- Geser untuk menggulir panel (HP) ----------
# Sentuhan di atas kartu/tombol tidak sampai ke ScrollContainer, jadi gulir ditangani di sini.
var _sdrag := {}
var _svel := 0.0
var _cancelling := false


func _input(e: InputEvent) -> void:
	if not overlay.visible or _cancelling:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_svel = 0.0
			if sheet.get_global_rect().has_point(e.position):
				_sdrag = {"y": e.position.y, "last": e.position.y, "t": Time.get_ticks_msec(), "sv": float(scroll.scroll_vertical), "on": false}
			else:
				_sdrag = {}
		else:
			if _sdrag.get("on", false):
				get_viewport().set_input_as_handled()
			_sdrag = {}
	elif e is InputEventMouseMotion and not _sdrag.is_empty():
		var dy: float = e.position.y - float(_sdrag.y)
		if not _sdrag.on and absf(dy) > 16.0:
			_sdrag.on = true
			_cancel_press()
		if _sdrag.on:
			var now := Time.get_ticks_msec()
			var dt := maxf(1.0, float(now - int(_sdrag.t)))
			_svel = lerpf(_svel, (e.position.y - float(_sdrag.last)) / dt * 1000.0, 0.5)
			_sdrag.last = e.position.y
			_sdrag.t = now
			scroll.scroll_vertical = int(float(_sdrag.sv) - dy)
			get_viewport().set_input_as_handled()


## Lepas tekanan tombol yang sedang ditekan (di luar layar) supaya tidak terpencet saat menggeser.
func _cancel_press() -> void:
	_cancelling = true
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = Vector2(-5000, -5000)
	rel.global_position = rel.position
	get_viewport().push_input(rel)
	_cancelling = false


func _process(delta: float) -> void:
	if _sdrag.is_empty() and absf(_svel) > 30.0 and overlay.visible:
		scroll.scroll_vertical = int(scroll.scroll_vertical - _svel * delta)
		_svel *= pow(0.04, delta)
	elif _sdrag.is_empty():
		_svel = 0.0

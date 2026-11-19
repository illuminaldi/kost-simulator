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
	var nav := Sprite2D.new()
	nav.texture = art
	nav.centered = false
	nav.region_enabled = true
	nav.region_rect = Rect2(0, 2386, 1438, 190)
	nav.position = Vector2(0, 2386)
	add_child(nav)
	var beli := PanelContainer.new()
	var bs := _sb(D.C_GREEN, 5, 70, 0, 0)
	beli.add_theme_stylebox_override("panel", bs)
	beli.position = Vector2(52, 2422)
	beli.size = Vector2(304, 112)
	beli.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := _label("Beli", 62)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	beli.add_child(bl)
	add_child(beli)
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
	nav_badge.position = Vector2(668, 2384)
	nav_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nav_badge)
	ev_badge = PanelContainer.new()
	ev_badge.add_theme_stylebox_override("panel", _sb(Color("e0533d"), 5, 40, 14, 2, Color.WHITE))
	ev_badge_lbl = _label("0", 32, Color.WHITE)
	ev_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev_badge.add_child(ev_badge_lbl)
	ev_badge.position = Vector2(1350, 2384)
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

	tray = PanelContainer.new()
	var tsb := _sb(D.C_PAPER, 6, 40, 20, 14)
	tsb.shadow_color = Color(0.24, 0.16, 0.1, 0.35)
	tsb.shadow_offset = Vector2(0, -6)
	tsb.shadow_size = 1
	tray.add_theme_stylebox_override("panel", tsb)
	tray.position = Vector2(14, 2060)
	tray.size = Vector2(1410, 330)
	tray.visible = false
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	tray.add_child(tv)
	var th := HBoxContainer.new()
	var tt := _label("Ketuk perabot untuk membeli. Pesanan datang dengan pickup; seret kotaknya ke kamar (perabot yang sama = upgrade). Seret Kamar Baru ke lahan kosong.", 28, D.C_MUTED, true)
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	th.add_child(tt)
	th.add_child(_btn("Fasilitas", D.C_YELLOW, func(): open_sheet("upgrade")))
	th.add_child(_btn("Selesai", D.C_GREEN, func(): game.set_dekor(false)))
	tv.add_child(th)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(1370, 220)
	tv.add_child(sc)
	tray_row = HBoxContainer.new()
	tray_row.add_theme_constant_override("separation", 8)
	sc.add_child(tray_row)
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


func _btn(t: String, col: Color, cb: Callable, disabled: bool = false, expand: bool = false) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 36)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(st, Color("3e2b1d"))
	var n := _sb(col, 5, 60, 34, 16)
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
	b.disabled = disabled
	if expand:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


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
	h.add_theme_constant_override("separation", 16)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	if right:
		h.add_child(right)
	parent.add_child(h)
	return h


func _flow(parent: Control) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 16)
	f.add_theme_constant_override("v_separation", 16)
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
		h.add_child(_btn("X", Color.WHITE, close_sheet))
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
			var fr := D.furn_rect(id, t, tx.get_size())
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
			v.add_child(_text("%s sedang menangani (±%d jam)." % [st.n, maxi(1, int(e.auto))], 32, Color("3f6f96")))
		else:
			v.add_child(_text("Bisa ditangani otomatis oleh %s." % st.n, 30, D.C_MUTED))
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
		v.add_child(_text("Teknisi sedang memperbaiki kamar ini.", 32, Color("3f6f96")))
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
			right = _btn("Beli " + D.short(f.cost), D.C_GREEN, func(): _do("buy", t), float(S.money) < float(f.cost))
		elif lv < 3:
			var c: float = float(f.cost) * lv
			right = _btn("Beli lagi " + D.short(f.cost), D.C_YELLOW, func(): _do("buy", t), float(S.money) < float(f.cost))
		else:
			right = _label("Maks", 32, Color("2f7a2a"), true)
		var nm: String = f.n if lv == 0 else "%s · %s" % [f.n, D.FURN_LV_NAME[lv]]
		_row(v, _label(nm, 36, D.C_INK if lv > 0 else D.C_MUTED, lv == 0), right)
	v.add_child(_text("Perabot yang dibeli datang dengan pickup. Seret kotaknya ke kamar ini; perabot yang sama akan naik level.", 30, D.C_MUTED))


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
	for c in tray_row.get_children():
		c.queue_free()
	var S: Dictionary = game.S
	# Kartu kamar baru
	var at := AtlasTexture.new()
	at.atlas = game.shell_tex
	at.region = D.rect_of("3R")
	tray_row.add_child(_tray_card(at, "Kamar Baru", D.short(game.build_cost()), "build", "", true))
	for t in D.FURN_ORDER:
		var f: Dictionary = D.FURN[t]
		var ok := int(S.lvl) >= int(f.min)
		tray_row.add_child(_tray_card(load("res://assets/furn/icon/%s.png" % t), f.n, D.short(f.cost) if ok else "Lv %d" % int(f.min), "furn", t, ok))
	for k in D.FACIL_ORDER:
		var fc: Dictionary = D.FACIL[k]
		if game.has_facil(k): continue
		var ok2 := int(S.lvl) >= int(fc.lv)
		tray_row.add_child(_tray_card(load("res://assets/facil/%s.png" % k), fc.n, D.short(fc.cost) if ok2 else "Lv %d" % int(fc.lv), "facil", k, ok2))


func _tray_card(tex: Texture2D, title: String, price: String, kind: String, item: String, ok: bool) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color.WHITE if ok else Color("efe6d6"), 4, 26, 12, 8, Color("e2d3bd")))
	p.custom_minimum_size = Vector2(156, 210)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(130, 110)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not ok:
		tr.modulate = Color(1, 1, 1, 0.4)
	v.add_child(tr)
	var l := _label(title, 25)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var pl := _label(price, 26, Color("2f7a2a") if ok else D.C_MUTED, true)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pl)
	p.add_child(v)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if not ok:
				var need: int = int(D.FACIL[item].lv) if kind == "facil" else int(D.FURN[item].min)
				toast("%s terbuka di Level %d" % [title, need], "bad")
				return
			if kind == "furn":
				game.act("buy", item)
			else:
				game.begin_drag(kind, item, game.get_global_mouse_position(), true)
				move_ghost(game.get_global_mouse_position()))
	return p


func show_ghost(tex: Texture2D, sc: float) -> void:
	ghost.texture = tex
	ghost.scale = Vector2(sc, sc)
	ghost.visible = tex != null


func move_ghost(p: Vector2) -> void:
	ghost.position = p + Vector2(0, -60)


func hide_ghost() -> void:
	ghost.visible = false


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
	spd_lbl.text = "%dx" % sp if sp > 0 else "Jeda"
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


func _sheet_welcome() -> void:
	_header("Selamat datang, Juragan Kost!", false)
	box.add_child(_text("Kamu baru mewarisi Kost Harmoni. Kelola kamar, terima penyewa, dan jadikan kost ini yang paling nyaman se-kota!", 40))
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
	info.add_child(_text("Menunggu %d jam" % int(p.wait), 34, D.C_MUTED))
	h.add_child(info)
	v.add_child(h)
	var f := _flow(v)
	if room_ctx != "":
		f.add_child(_btn("Terima di " + D.room_name(room_ctx), D.C_GREEN, func(): _do("assign", "%s|%s" % [p.id, room_ctx])))
	elif sel == p.id:
		var er: Array = game.empty_rooms()
		if er.is_empty():
			f.add_child(_text("Tidak ada kamar kosong. Bangun kamar baru di menu Upgrade.", 34, D.C_MUTED))
		for rid in er:
			var r: Dictionary = S.rooms[rid]
			var ok := int(r.lv) >= int(p.pref)
			f.add_child(_btn("%s · %s%s" % [D.room_name(rid), D.RLV[int(r.lv)].n, " ✓" if ok else ""], D.C_YELLOW, func(): _do("assign", "%s|%s" % [p.id, rid])))
		f.add_child(_btn("Batal", D.C_CREAM, func(): sel = ""; refresh_sheet()))
	else:
		f.add_child(_btn("Terima", D.C_GREEN, func(): sel = p.id; refresh_sheet()))
		f.add_child(_btn("Tolak", D.C_RED, func(): _do("reject", p.id)))


func _sheet_room() -> void:
	var S: Dictionary = game.S
	var id := arg
	var r: Dictionary = S.rooms[id]
	if not r.built:
		var need: int = D.FLOOR_LV[int(id[0])]
		_header("Lahan Kamar " + D.room_name(id))
		_room_pic(box, id)
		var v := _card()
		if int(S.lvl) < need:
			v.add_child(_text("Lantai %s terbuka di Level %d." % [id[0], need], 38))
		else:
			var c: float = game.build_cost()
			if game.job_for(id, "build") != {}:
				v.add_child(_text("Tukang sedang membangun kamar ini.", 38))
				return
			v.add_child(_text("Bangun kamar Standar baru di sini.", 38))
			_row(v, _label(D.rp(c), 42), _btn("Bangun", D.C_GREEN, func(): _do("build", id), float(S.money) < c))
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
		_row(v, _label("Kerusakan: " + str(r.broken), 38), (_label("Teknisi datang...", 34, Color("3f6f96"), true) if game.job_for(id, "fix") != {} else _btn("Panggil Teknisi " + D.short(cost), D.C_YELLOW, func(): _do("fix", id), float(S.money) < cost)))
	else:
		v.add_child(_label("Semua fasilitas berfungsi", 34, D.C_MUTED, true))
	var f := _flow(v)
	f.add_child(_btn("Bersihkan (Rp 15rb)", D.C_GREEN, func(): _do("clean", id), float(r.clean) >= 99 or float(S.money) < 15000))
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
		if S.queue.is_empty():
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
			var f := _flow(v)
			f.add_child(_btn("Lihat kamar", D.C_CREAM, func(): open_sheet("room", rid)))


func _sheet_staff() -> void:
	var S: Dictionary = game.S
	_header("Karyawan")
	var tot := 0
	for k in S.staff:
		if S.staff[k]:
			tot += int(D.STAFF[k].sal)
	box.add_child(_text("Total gaji: %s/hari (dibayar pukul 17:00)" % D.rp(tot), 36, D.C_MUTED))
	for k in D.STAFF:
		var st: Dictionary = D.STAFF[k]
		var on: bool = S.staff.get(k, false)
		var v := _card()
		_row(v, _label(st.n, 42), _label(D.rp(st.sal) + "/hari", 34, D.C_MUTED, true))
		v.add_child(_text(st.d, 34, D.C_MUTED))
		var f := _flow(v)
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
			_row(v, _label(st.n, 36), _label("Sedang bekerja", 32, Color("2f7a2a"), true) if on else _btn("Rekrut " + D.short(st.sal) + "/hari", D.C_YELLOW, func(): _do("hire", fc.staff)))
		return
	if not j.is_empty():
		_header("Lantai %d · sedang dibangun" % f)
		_fac_pic(box, str(j.item), 520)
		box.add_child(_text("Tukang sedang membangun %s." % D.FACIL[j.item].n, 36, D.C_MUTED))
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
			right = _btn(D.short(fc.cost), D.C_GREEN, func(): _do("buy_fac", k), float(S.money) < float(fc.cost))
		_row(v, _label(fc.n, 40), right)
		if fc.d != "":
			v.add_child(_text(fc.d, 32, D.C_MUTED))
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
			_row(col, _label("%s · %s/hari" % [st.n, D.short(st.sal)], 30, D.C_INK), sr)


func _sheet_manage() -> void:
	var S: Dictionary = game.S
	_header("Kelola Kost Harmoni")
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
	var sv := _card()
	sv.add_child(_label("Kecepatan waktu", 42))
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 14)
	for s in [[0, "Jeda"], [1, "1x"], [2, "2x"], [3, "3x"]]:
		sh.add_child(_btn(s[1], D.C_YELLOW if int(S.speed) == s[0] else Color.WHITE, func(): _do("speed", str(s[0])), false, true))
	sv.add_child(sh)
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

class_name RoomFx
extends Node2D
## Lapisan di atas tiap kamar: sketsa "rencana bangun", label Kamar Kosong, papan bangun, debu, dan lencana status.

var rid := ""
var rect: Rect2
var game: Node
var _plan: Sprite2D
var _sign: PanelContainer
var _sign_lbl: Label
var _sign_sb: StyleBoxFlat
var _empty: PanelContainer
var _tag: Label
var _badges: HBoxContainer
var _coin: PanelContainer
var _lock := ""
var _coin_amt := 0.0
var _ct := 0.0
var _furn := {}          # tipe -> Sprite2D
var _furn_lv := {}
var _stars: Node2D
var _preview := ""
var dekor := false
var building := false
var _built := false
var _clean := 100.0
var _lv := 1


func setup(p_game: Node, id: String, art: Texture2D, plan_mat: Material, font: Font) -> void:
	game = p_game
	rid = id
	rect = D.rect_of(id)
	position = rect.position
	_plan = Sprite2D.new()
	_plan.texture = art
	_plan.centered = false
	_plan.region_enabled = true
	_plan.region_rect = D.src_rect(id)
	_plan.material = plan_mat
	add_child(_plan)
	# Sprite perabot (urutan gambar: belakang -> depan).
	for t in D.ITEM_DRAW_ORDER:
		var sp := Sprite2D.new()
		sp.centered = false
		sp.flip_h = D.furn_flip(id)
		_set_item(sp, t, 1)
		sp.visible = false
		add_child(sp)
		_furn[t] = sp

	_tag = _mk_label(font, 26, D.C_INK)
	var tsb := _box(Color(0.984, 0.96, 0.918, 0.92), 3, 12, 10, 2)
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", tsb)
	tp.add_child(_tag)
	tp.position = Vector2(10, 10)
	tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tp)
	_tag.set_meta("panel", tp)

	_empty = PanelContainer.new()
	_empty.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.9), 3, 16, 12, 2))
	var el := _mk_label(font, 21, Color("3e2b1d"))
	el.text = "Kamar Kosong · Bisa Diisi"
	el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_child(el)
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_empty)

	_sign = PanelContainer.new()
	var ssb := _box(Color("b88a5f"), 5, 18, 26, 12)
	_sign_sb = ssb
	ssb.shadow_color = D.C_LINE
	ssb.shadow_offset = Vector2(0, 7)
	ssb.shadow_size = 1
	_sign.add_theme_stylebox_override("panel", ssb)
	_sign_lbl = _mk_label(font, 36, Color("fff6e6"))
	_sign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign.add_child(_sign_lbl)
	_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sign)

	_stars = Node2D.new()
	_stars.draw.connect(_draw_stars)
	add_child(_stars)

	_coin = PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color("f7d36e")
	csb.border_color = Color("6b4f3a")
	csb.set_border_width_all(5)
	csb.set_corner_radius_all(30)
	csb.content_margin_left = 22
	csb.content_margin_right = 22
	csb.content_margin_top = 4
	csb.content_margin_bottom = 8
	_coin.add_theme_stylebox_override("panel", csb)
	_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cl := Label.new()
	cl.add_theme_font_override("font", font)
	cl.add_theme_font_size_override("font_size", 34)
	cl.add_theme_color_override("font_color", Color("4a3626"))
	_coin.add_child(cl)
	_coin.visible = false
	add_child(_coin)
	_badges = HBoxContainer.new()
	_badges.add_theme_constant_override("separation", 6)
	_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badges)


func _box(bg: Color, border: int, radius: int, mx: int, my: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = D.C_LINE
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb


func _mk_label(font: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func refresh(r: Dictionary, player_lv: int, cost: float, font: Font) -> void:
	_built = r.built
	_clean = float(r.clean)
	_lv = int(r.lv)
	_plan.visible = not _built
	var furn: Dictionary = r.get("furn", {})
	_furn_lv = {}
	for t in _furn:
		var on: bool = _built and furn.has(t)
		_furn[t].visible = on or (_preview == t)
		_furn[t].modulate = Color(1, 1, 1, 0.5) if (_preview == t and not on) else Color.WHITE
		if on:
			_furn_lv[t] = int(furn[t])
		var want := int(furn[t]) if on else 1
		if int(_furn[t].get_meta("lv")) != want:
			_set_item(_furn[t], t, want)
	_stars.queue_redraw()
	var tp: PanelContainer = _tag.get_meta("panel")
	tp.visible = _built
	_tag.text = D.room_name(rid)
	var has_tenant: bool = r.tenant != null
	_empty.visible = _built and not has_tenant
	var el: Label = _empty.get_child(0)
	el.text = "Kamar Kosong · Bisa Diisi" if r.get("furn", {}).has("kasur") else "Belum Ada Kasur\n(Beli Kasur)"
	if _empty.visible:
		_empty.reset_size()
		_empty.position = Vector2((rect.size.x - _empty.size.x) / 2.0, rect.size.y - _empty.size.y - 6)
	_sign.visible = not _built
	if not _built:
		var need: int = D.fl(rid)
		if building:
			_sign_lbl.text = "Sedang\nDibangun"
			_sign_sb.bg_color = Color("e0a83a")
		elif _lock != "":
			_sign_lbl.text = _lock
			_sign_sb.bg_color = Color("8f7a9c")
		elif player_lv < need:
			_sign_lbl.text = "Terkunci\nLevel %d" % need
			_sign_sb.bg_color = Color("a69a8c")
		else:
			_sign_lbl.text = "Bangun\n%s" % D.short(cost)
			_sign_sb.bg_color = Color("b88a5f")
		_sign.reset_size()
		_sign.position = (rect.size - _sign.size) / 2.0
	for c in _badges.get_children():
		c.queue_free()
	if _built:
		if str(r.broken) != "":
			_badges.add_child(_badge(font, "Rusak", Color("ffd9c7")))
		if r.get("_ev", "") != "":
			_badges.add_child(_badge(font, "Masalah!", Color("ffc9a8")))
		if _clean < 35.0:
			_badges.add_child(_badge(font, "Kotor", Color("f2e2c4")))
		if has_tenant and float(r.tenant.happy) < 35.0:
			_badges.add_child(_badge(font, "Kesal", Color("f4a7a8")))
	_coin_amt = float(r.get("due", 0.0)) if _built else 0.0
	_coin.visible = _coin_amt > 0.0
	if _coin.visible:
		(_coin.get_child(0) as Label).text = "Tagih " + D.short(_coin_amt)
		_coin.reset_size()
		_coin.position = Vector2((rect.size.x - _coin.size.x) / 2.0, 14)
	_badges.reset_size()
	_badges.position = Vector2(rect.size.x - _badges.size.x - 10, 10)
	queue_redraw()


func has_slot(t: String) -> bool:
	return _furn.has(t)


## Pratinjau perabot transparan saat sedang diseret ke kamar ini.
func set_preview(t: String) -> void:
	if t == _preview:
		return
	if _preview != "" and _furn.has(_preview) and not _furn_lv.has(_preview):
		_furn[_preview].visible = false
	_preview = t
	if t != "" and _furn.has(t) and _built:
		_furn[t].visible = true
		if not _furn_lv.has(t):
			_furn[t].modulate = Color(1, 1, 1, 0.5)
		else:
			_furn[t].modulate = Color(1.25, 1.2, 0.9)
	for k in _furn:
		if k != t and _furn_lv.has(k):
			_furn[k].modulate = Color.WHITE


func _draw_stars() -> void:
	if not dekor:
		return
	for t in _furn_lv:
		var sp: Sprite2D = _furn[t]
		var tl := sp.position + Vector2(sp.texture.get_width() - 14, 14)
		var lv: int = _furn_lv[t]
		for i in range(lv):
			_star_on(_stars, tl + Vector2(-i * 26, 0), 12.0)


func _star_on(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, Color("f2c14e"))
	pts.append(pts[0])
	ci.draw_polyline(pts, D.C_LINE, 2.5)


func _badge(font: Font, text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _box(col, 3, 20, 12, 3)
	p.add_theme_stylebox_override("panel", sb)
	var l := _mk_label(font, 24, D.C_INK)
	l.text = text
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _process(_dt: float) -> void:
	# Lencana sedikit memantul agar menarik perhatian.
	if _badges.get_child_count() > 0:
		_badges.position.y = 10 + sin(Time.get_ticks_msec() / 220.0) * 4.0
	if _coin and _coin.visible:
		_coin.position.y = 14 + sin(Time.get_ticks_msec() / 160.0) * 6.0
		_coin.rotation = sin(Time.get_ticks_msec() / 300.0) * 0.04


func _draw() -> void:
	if not _built:
		_dashed_rect(Rect2(Vector2(6, 6), rect.size - Vector2(12, 12)), Color(0.42, 0.31, 0.23, 0.35), 4.0, 18.0)
		return
	# Bintang level kamar di samping label nomor.
	var tp: PanelContainer = _tag.get_meta("panel")
	for i in range(_lv - 1):
		_star(Vector2(tp.position.x + tp.size.x + 18 + i * 28, tp.position.y + tp.size.y / 2.0), 13.0)
	# Debu / noda di lantai saat kotor.
	if _clean < 70.0:
		var k := (70.0 - _clean) / 70.0
		var spots := [[0.18, 0.86, 30], [0.70, 0.92, 34], [0.88, 0.82, 26], [0.40, 0.95, 38], [0.55, 0.84, 22], [0.28, 0.78, 22], [0.80, 0.96, 26]]
		var n := 2 + int(round(k * 5.0))
		for i in range(mini(n, spots.size())):
			var s: Array = spots[i]
			var c := Vector2(rect.size.x * s[0], rect.size.y * s[1])
			draw_set_transform(c, 0.0, Vector2(1.0, 0.4))
			draw_circle(Vector2.ZERO, float(s[2]), Color(0.48, 0.35, 0.2, 0.16 + 0.3 * k))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _star(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, Color("e9a923"))
	pts.append(pts[0])
	draw_polyline(pts, D.C_LINE, 2.0)


func _dashed_rect(r: Rect2, col: Color, w: float, dash: float) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in range(4):
		draw_dashed_line(corners[i], corners[i + 1], col, w, dash)


func _set_item(sp: Sprite2D, t: String, lv: int) -> void:
	var tex: Texture2D = load(D.furn_tex(rid, t, lv))
	sp.texture = tex
	var fr := D.furn_rect(rid, t, tex.get_size())
	sp.position = fr.position - rect.position
	sp.scale = fr.size / tex.get_size()
	sp.set_meta("lv", lv)


## Animasi perabot baru/naik level: muncul memantul dari alasnya + kilauan bintang.
func pop_item(t: String) -> void:
	if not _furn.has(t): return
	var sp: Sprite2D = _furn[t]
	var base_s := sp.scale
	var base_p := sp.position
	var sz: Vector2 = sp.texture.get_size() * base_s
	var setk := func(k: float):
		sp.scale = base_s * k
		sp.position = base_p + Vector2(sz.x * (1.0 - k) * 0.5, sz.y * (1.0 - k))
	var tw := create_tween()
	tw.tween_method(setk, 0.2, 1.18, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(setk, 1.18, 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	var center := base_p + sz * Vector2(0.5, 0.45)
	var glow := _Glow.new()
	glow.position = center
	add_child(glow)
	var gt := create_tween()
	gt.tween_property(glow, "scale", Vector2(2.2, 2.2), 0.6).from(Vector2(0.3, 0.3))
	gt.parallel().tween_property(glow, "modulate:a", 0.0, 0.6).from(0.9)
	gt.tween_callback(glow.queue_free)
	for i in range(9):
		var st := _Star.new()
		st.position = center
		add_child(st)
		var ang := TAU * i / 9.0 + randf() * 0.4
		var dist := randf_range(70, 130)
		var t2 := create_tween().set_parallel(true)
		t2.tween_property(st, "position", center + Vector2(cos(ang), sin(ang)) * dist, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t2.tween_property(st, "rotation", randf_range(-2, 2), 0.7)
		t2.tween_property(st, "modulate:a", 0.0, 0.7).set_delay(0.25)
		t2.chain().tween_callback(st.queue_free)


class _Star extends Node2D:
	func _draw() -> void:
		var pts := PackedVector2Array()
		for k in range(8):
			var rr := 16.0 if k % 2 == 0 else 6.0
			pts.append(Vector2(cos(k * PI / 4.0), sin(k * PI / 4.0)) * rr)
		draw_colored_polygon(pts, Color("ffd76a"))


class _Glow extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 60, Color(1, 0.93, 0.6, 0.55))


## Ketukan di tombol koin "Tagih" (koordinat lokal kamar, area diperbesar untuk jari).
func coin_hit(p: Vector2) -> bool:
	return _coin != null and _coin.visible and _coin.get_rect().grow(30).has_point(p)



func set_floor_lock(t: String) -> void:
	if t != _lock:
		_lock = t
		if not _built and _sign.visible and t != "":
			_sign_lbl.text = t
			_sign_sb.bg_color = Color("8f7a9c")
			_sign.reset_size()
			_sign.position = (rect.size - _sign.size) / 2.0

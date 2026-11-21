class_name Spr
extends RefCounted
## Pembuat sprite karakter dari SVG (dirender oleh Godot menjadi tekstur, lalu di-cache).
## Semua pose digambar dengan gaya garis cokelat lembut agar senada dengan ilustrasi.

static var _cache := {}

const SHOE := "#6b4f3a"


static func random_look(g: String) -> Dictionary:
	return {
		"skin": D.SKINS.pick_random(), "hair": D.HAIRS.pick_random(),
		"style": (["long", "bun", "short"] if g == "p" else ["short", "beanie", "short"]).pick_random(),
		"shirt": D.SHIRTS.pick_random(), "pants": D.PANTS.pick_random(), "bag": randf() < 0.35,
		"bagc": D.BAGC.pick_random(), "blanket": D.BLANKETS.pick_random(), "hat": D.HATS.pick_random(),
	}


static func look_key(L: Dictionary) -> String:
	return "%s%s%s%s%s%s%s%s" % [L.skin, L.hair, L.style, L.shirt, L.pants, L.bag, L.blanket, L.hat]


## Ambil tekstur untuk pose tertentu. k = skala (lobi 2.2, kamar 0.8).
static func tex(L: Dictionary, pose: String, frame: int, k: float) -> Texture2D:
	var key := "%s|%s|%d|%.2f" % [look_key(L), pose, frame, k]
	if _cache.has(key):
		return _cache[key]
	var svg := ""
	if pose == "lie":
		svg = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="-70 -50 140 70">%s</svg>' % [
			roundi(140 * k), roundi(70 * k), _sleep(L)]
	else:
		svg = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="-40 -200 80 200">%s</svg>' % [
			roundi(80 * k), roundi(200 * k), _fig(L, pose, frame)]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	if err != OK:
		push_warning("SVG gagal dirender: %s" % pose)
		img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var t := ImageTexture.create_from_image(img)
	if _cache.size() > 300: _cache.clear()   # batasi memori (HP)
	_cache[key] = t
	return t


static func _arm(x: float, s: float, sh: String, sk: String) -> String:
	var hx := x + s * 4.0
	return ('<path d="M%s -110 L%s -72" stroke="#4b3427" stroke-width="13" stroke-linecap="round" fill="none"/>' % [x, hx]
		+ '<path d="M%s -110 L%s -72" stroke="%s" stroke-width="8" stroke-linecap="round" fill="none"/>' % [x, hx, sh]
		+ '<circle cx="%s" cy="-67" r="4.6" fill="%s" stroke="#4b3427" stroke-width="2"/>' % [hx, sk])


static func _bent(d: String, sh: String) -> String:
	return ('<path d="%s" fill="none" stroke="#4b3427" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>' % d
		+ '<path d="%s" fill="none" stroke="%s" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>' % [d, sh])


static func _legs_straight(pn: String) -> String:
	return ('<rect x="-14" y="-64" width="11" height="62" rx="5" fill="%s" stroke="#4b3427" stroke-width="2.5"/><rect x="3" y="-64" width="11" height="62" rx="5" fill="%s" stroke="#4b3427" stroke-width="2.5"/>' % [pn, pn]
		+ '<ellipse cx="-9" cy="-2" rx="8" ry="4.5" fill="%s" stroke="#4b3427" stroke-width="2.5"/><ellipse cx="9" cy="-2" rx="8" ry="4.5" fill="%s" stroke="#4b3427" stroke-width="2.5"/>' % [SHOE, SHOE])


static func _fig(L: Dictionary, pose: String, f: int) -> String:
	var sk: String = L.skin
	var hr: String = L.hair
	var sh: String = L.shirt
	var pn: String = L.pants
	var legs := ""
	var arms := ""
	var extra := ""
	var torso := '<rect x="-21" y="-120" width="42" height="62" rx="16" fill="%s" stroke="#4b3427" stroke-width="2.5"/>' % sh
	torso += '<path d="M-8 -119 L0 -110 L8 -119" fill="none" stroke="#fff" stroke-opacity=".55" stroke-width="2.5" stroke-linecap="round"/>'
	match pose:
		"walk":
			var a := 16 if f == 1 else -16
			legs = ('<g transform="rotate(%d -8 -62)"><rect x="-14" y="-64" width="11" height="62" rx="5" fill="%s" stroke="#4b3427" stroke-width="2.5"/><ellipse cx="-9" cy="-2" rx="8" ry="4.5" fill="%s" stroke="#4b3427" stroke-width="2.5"/></g>' % [a, pn, SHOE]
				+ '<g transform="rotate(%d 8 -62)"><rect x="3" y="-64" width="11" height="62" rx="5" fill="%s" stroke="#4b3427" stroke-width="2.5"/><ellipse cx="9" cy="-2" rx="8" ry="4.5" fill="%s" stroke="#4b3427" stroke-width="2.5"/></g>' % [-a, pn, SHOE])
			arms = ('<g transform="rotate(%d -19 -110)">%s</g>' % [-a, _arm(-19, -1, sh, sk)]
				+ '<g transform="rotate(%d 19 -110)">%s</g>' % [a, _arm(19, 1, sh, sk)])
			extra = _bag(L)
		"sit", "work":
			legs = ('<rect x="-16" y="-36" width="11" height="33" rx="5" fill="%s" stroke="#4b3427" stroke-width="2.5"/><rect x="5" y="-36" width="11" height="33" rx="5" fill="%s" stroke="#4b3427" stroke-width="2.5"/>' % [pn, pn]
				+ '<rect x="-19" y="-50" width="38" height="20" rx="9" fill="%s" stroke="#4b3427" stroke-width="2.5"/>' % pn
				+ '<ellipse cx="-10" cy="-3" rx="8" ry="4.5" fill="%s" stroke="#4b3427" stroke-width="2.5"/><ellipse cx="10" cy="-3" rx="8" ry="4.5" fill="%s" stroke="#4b3427" stroke-width="2.5"/>' % [SHOE, SHOE])
			if pose == "work":
				arms = (_bent("M-19 -108 L-12 -84 L2 -84", sh)
					+ _bent("M19 -108 L12 -84 L-2 -84", sh)
					+ '<rect x="-17" y="-80" width="34" height="5" rx="2" fill="#cfd5dc" stroke="#4b3427" stroke-width="1.2"/>'
					+ '<rect x="-15" y="-98" width="30" height="18" rx="2" fill="#dfe8f2" stroke="#4b3427" stroke-width="1.2"/>'
					+ '<circle cx="0" cy="-83" r="4.5" fill="%s"/>' % sk)
			else:
				arms = (_bent("M-19 -110 L-12 -82 L-2 -84", sh)
					+ _bent("M19 -110 L12 -82 L2 -84", sh)
					+ '<rect x="-6" y="-98" width="12" height="14" rx="3" fill="#fbf5ea" stroke="#4b3427" stroke-width="1.4"/>'
					+ '<path d="M6 -94 q5 2 0 7" fill="none" stroke="#4b3427" stroke-width="1.4"/>'
					+ '<circle cx="-3" cy="-85" r="4.2" fill="%s"/><circle cx="3" cy="-85" r="4.2" fill="%s"/>' % [sk, sk])
		"sweep":
			legs = _legs_straight(pn)
			arms = (_arm(-19, -1, sh, sk)
				+ _bent("M19 -110 L26 -68", sh)
				+ '<path d="M%d -66 L%d -4" stroke="#b8895a" stroke-width="3.5" stroke-linecap="round"/>' % [26, 48 + f * 6]
				+ '<path d="M%d -5 L%d -5" stroke="#e0b24f" stroke-width="8" stroke-linecap="round"/>' % [38 + f * 6, 60 + f * 6]
				+ '<circle cx="26" cy="-66" r="5" fill="%s"/>' % sk)
		"fix":
			legs = _legs_straight(pn)
			arms = (_arm(-19, -1, sh, sk)
				+ _bent("M19 -110 L28 -%d" % [96 + f * 8], sh)
				+ '<circle cx="28" cy="-%d" r="5" fill="%s"/>' % [92 + f * 8, sk]
				+ '<path d="M28 -%d l12 -10" stroke="#8a8f96" stroke-width="5" stroke-linecap="round"/>' % [92 + f * 8]
				+ '<rect x="-46" y="-30" width="30" height="20" rx="3" fill="#c0392b" stroke="#4b3427" stroke-width="1.5"/>')
		"counter":
			arms = _arm(-19, -1, sh, sk) + _arm(19, 1, sh, sk)
		_:
			legs = _legs_straight(pn)
			arms = _arm(-19, -1, sh, sk) + _arm(19, 1, sh, sk)
			extra = _bag(L)
	if pose == "sit" or pose == "work":
		return legs + '<g transform="translate(0 16)">' + torso + arms + extra + _head(L) + '</g>'
	return legs + torso + arms + extra + _head(L)


static func _bag(L: Dictionary) -> String:
	if not L.bag:
		return ""
	return ('<path d="M-40 -74 Q-40 -86 -30 -86" fill="none" stroke="#4b3427" stroke-width="2"/>'
		+ '<rect x="-48" y="-74" width="18" height="22" rx="4" fill="%s" stroke="#4b3427" stroke-width="1.5"/>' % L.bagc)


static func _head(L: Dictionary) -> String:
	var sk: String = L.skin
	var hr: String = L.hair
	var back := ""
	var front := '<path d="M-23 -146 Q-22 -170 0 -171 Q22 -170 23 -146 Q12 -158 -4 -152 Q-14 -156 -23 -146Z" fill="%s" stroke="#4b3427" stroke-width="2.2" stroke-linejoin="round"/>' % hr
	var hat := ""
	match L.style:
		"long":
			back = '<path d="M-25 -150 Q-31 -110 -23 -94 L23 -94 Q31 -110 25 -150 Z" fill="%s" stroke="#4b3427" stroke-width="2.2" stroke-linejoin="round"/>' % hr
		"bun":
			front += '<circle cx="0" cy="-171" r="9" fill="%s" stroke="#4b3427" stroke-width="2.2"/>' % hr
		"beanie":
			front = ""
			hat = ('<path d="M-24 -150 Q-24 -178 0 -178 Q24 -178 24 -150 Z" fill="%s" stroke="#4b3427" stroke-width="2.2"/>' % L.hat
				+ '<rect x="-25" y="-155" width="50" height="7" rx="3.5" fill="%s" stroke="#4b3427" stroke-width="2.2"/>' % L.hat)
		"cap":
			hat = ('<path d="M-22 -152 Q-22 -174 0 -174 Q22 -174 22 -152 Z" fill="%s"/>' % L.hat
				+ '<path d="M-24 -152 L30 -152 Q30 -147 22 -147 L-24 -147 Z" fill="#1f2a40"/><circle cx="0" cy="-163" r="3.5" fill="#e9c35a"/>')
	var face := ('<circle cx="-8" cy="-144" r="2.7" fill="#3b2a20"/><circle cx="8" cy="-144" r="2.7" fill="#3b2a20"/>'
		+ '<ellipse cx="-14" cy="-136" rx="4.2" ry="2.6" fill="#f2a58a" opacity=".55"/><ellipse cx="14" cy="-136" rx="4.2" ry="2.6" fill="#f2a58a" opacity=".55"/>'
		+ '<path d="M-4 -135 Q0 -131 4 -135" stroke="#6b4f3a" stroke-width="1.7" fill="none" stroke-linecap="round"/>')
	var head := '<circle cx="0" cy="-146" r="20.5" fill="%s" stroke="#4b3427" stroke-width="2.5"/>' % sk
	return back + head + front + hat + face


static func _sleep(L: Dictionary) -> String:
	return ('<rect x="-64" y="-42" width="30" height="20" rx="8" fill="#ffffff" stroke="#cdbfa8" stroke-width="1.2"/>'
		+ '<circle cx="-36" cy="-26" r="16" fill="%s" stroke="#4b3427" stroke-width="2"/>' % L.skin
		+ '<path d="M-52 -28 Q-50 -48 -34 -46 Q-20 -44 -20 -28 Q-34 -36 -52 -28Z" fill="%s"/>' % L.hair
		+ '<path d="M-42 -25 q3 2 6 0 M-30 -25 q3 2 6 0" stroke="#3b2a20" stroke-width="1.5" fill="none" stroke-linecap="round"/>'
		+ '<path d="M-22 -44 Q6 -50 34 -44 Q58 -42 60 -30 L60 -14 Q30 -12 -22 -14 Z" fill="%s" stroke="#9c8668" stroke-width="1.5"/>' % L.blanket
		+ '<path d="M-10 -38 Q20 -42 50 -36" fill="none" stroke="#ffffff" stroke-opacity=".5" stroke-width="2"/>')

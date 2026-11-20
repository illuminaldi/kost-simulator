class_name SideQuest
extends Control
## Jalan-jalan Maryam: geser lobi ke kiri/kanan saat Maryam ada di meja.
## Kiri: Kost → jalan kota → Cafe Book → taman → Lapangan Padel → (kota) → Kost.
## Kanan: urutan sebaliknya. Di Cafe Book & Padel ada permainan kecil.

const RING := ["kost", "cafe", "padel"]
# Pemandangan di antara dua tujuan, searah "kiri" (indeks naik).
const SCENERY := {"kost>cafe": "kota", "cafe>padel": "taman", "padel>kost": "kota"}
const NAMES := {"kost": "Kost", "cafe": "Cafe Book", "padel": "Lapangan Padel", "kota": "Jalan Kota", "taman": "Taman Kota"}

var game: Node
var ui: Node
var font: Font
var loc := "kost"
var view := ""             # walk / cafe_ext / cafe_in / padel
var _layer: Control
var _press := Vector2.ZERO
var _pressed := false
var _swiped := false


func setup(g: Node, u: Node, f: Font) -> void:
	game = g
	ui = u
	font = f
	position = Vector2.ZERO
	size = Vector2(D.IW, D.IH)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func active() -> bool:
	return visible


## dir: -1 = geser ke kiri (jalan ke kiri), +1 = geser ke kanan.
func start(dir: int) -> void:
	visible = true
	loc = "kost"
	ui.set_nav_visible(false)
	_walk(dir)


func _close() -> void:
	_clear()
	visible = false
	view = ""
	loc = "kost"
	ui.set_nav_visible(true)


func _clear() -> void:
	if _layer: _layer.queue_free()
	_layer = Control.new()
	_layer.size = size
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)


func _next(dir: int) -> String:
	var i := RING.find(loc)
	return RING[(i + (1 if dir < 0 else -1) + RING.size()) % RING.size()]


# ---------------- Berjalan ----------------
func _walk(dir: int) -> void:
	var to := _next(dir)
	var key: String = ("%s>%s" % [loc, to]) if dir < 0 else ("%s>%s" % [to, loc])
	var theme: String = SCENERY.get(key, "kota")
	_clear()
	view = "walk"
	var w := _Walk.new()
	w.theme = theme
	w.dir = dir
	w.font = font
	w.dest = NAMES[to]
	w.from = NAMES[loc]
	_layer.add_child(w)
	w.done.connect(func(): _arrive(to))
	game.sfx("pop", -12.0)


func _arrive(to: String) -> void:
	loc = to
	match to:
		"kost":
			_close()
			game.keeper_say("Sudah pulang! Kost aman kan?", 2.5)
		"cafe": _show_cafe_ext()
		"padel": _show_padel()


# ---------------- Tampilan bantu ----------------
func _bg(path: String) -> void:
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.size = size
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(tr)


func _hit(r: Rect2, cb: Callable) -> void:
	var b := Button.new()
	b.flat = true
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	var e := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, e)
	b.pressed.connect(cb)
	b.button_down.connect(func(): b.modulate = Color(0.85, 0.85, 0.85))
	b.button_up.connect(func(): b.modulate = Color.WHITE)
	_layer.add_child(b)


func _panel(r: Rect2, col := Color("fbf3e6")) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = r.position
	p.size = r.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = D.C_LINE
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(26)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(p)
	return p


func _lbl(t: String, sz: int, col := D.C_INK, wrap := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Tombol bawah bergaya sama dengan navigasi kost (pil besar, bayangan bawah, teks tebal).
func _bottom(btns: Array, band_y: float = D.NAV_Y - 22) -> void:
	var band := ColorRect.new()
	band.color = Color("b98a5e")
	band.position = Vector2(0, band_y)
	band.size = Vector2(D.IW, D.IH - band_y)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(band)
	var edge := ColorRect.new()
	edge.color = Color("6b4f3a")
	edge.position = band.position
	edge.size = Vector2(D.IW, 8)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(edge)
	var n := btns.size()
	var gap := 26.0
	var w := (D.IW - 52.0 - gap * (n - 1)) / n
	for i in range(n):
		var b: Array = btns[i]
		var r := Rect2(26 + i * (w + gap), D.NAV_Y, w, 170)
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = b[1]
		sb.border_color = D.C_LINE
		sb.set_border_width_all(6)
		sb.set_corner_radius_all(46)
		sb.shadow_color = D.C_LINE
		sb.shadow_offset = Vector2(0, 9)
		sb.shadow_size = 1
		pc.add_theme_stylebox_override("panel", sb)
		pc.position = r.position
		pc.size = r.size - Vector2(0, 10)
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_child(_lbl(b[0], 50 if n <= 3 else 44))
		_layer.add_child(pc)
		_hit(r, b[2])


func _toast_once(key: String) -> bool:
	var S: Dictionary = game.S
	if not S.has("side"): S.side = {}
	if int(S.side.get(key, -1)) == int(S.day): return false
	S.side[key] = int(S.day)
	return true


# ---------------- Cafe Book: tampak luar ----------------
func _show_cafe_ext() -> void:
	_clear()
	view = "cafe_ext"
	_bg("res://assets/side/cafe_ext.jpg")
	var m := TextureRect.new()
	m.texture = load("res://assets/chars/penjaga/happy_L.png")
	m.size = m.texture.get_size() * 1.32
	m.position = Vector2(522 - m.size.x / 2.0, 2095 - m.size.y)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(m)
	var tip := _panel(Rect2(250, 2160, 940, 110), Color(1, 0.98, 0.94, 0.92))
	tip.add_child(_lbl("Geser kiri: ke Lapangan Padel · Geser kanan: pulang", 32, D.C_MUTED, true))
	_bottom([["Masuk Cafe", D.C_GREEN, _show_cafe_in], ["Lanjut ke Padel", D.C_YELLOW, func(): _walk(-1)], ["Balik ke Kost", D.C_PINK, func(): _walk(1)]])


# ---------------- Cafe Book: membaca ----------------
# Buku = karya klasik; isi halaman berupa intisari/ringkasan bahasa Indonesia (bukan kutipan teks asli).
const BOOKS := [
	{"t": "The Art of War", "src": "Sun Tzu · intisari bebas (domain publik)", "p": [
		["Perang adalah urusan hidup dan mati sebuah negeri. Karena itu, Sun Tzu mengajarkan: pikirkan matang-matang sebelum bertindak.", "Lima hal menentukan kemenangan: tujuan yang menyatukan semua orang, waktu dan cuaca, medan, kepemimpinan, serta aturan yang jelas."],
		["Kemenangan terbaik adalah menang tanpa bertempur. Mematahkan rencana lawan lebih bijak daripada menghancurkan pasukannya.", "Kenali dirimu dan kenali lawanmu, maka kamu tidak perlu takut pada seratus pertempuran. Kenal salah satunya saja, peluangmu separuh."],
		["Jadilah seperti air: mengikuti bentuk wadahnya. Air menghindari tempat tinggi dan mengalir ke tempat rendah.", "Begitu juga strategi: hindari kekuatan lawan, serang kelemahannya, dan selalu siap berubah mengikuti keadaan."],
		["Pemimpin yang baik memperlakukan pasukannya seperti anak sendiri, sehingga mereka setia sampai akhir.", "Pelajaran untuk sehari-hari: rencanakan dengan tenang, pahami situasi, dan pilih pertarungan yang memang layak. TAMAT"]]},
	{"t": "Meditations", "src": "Marcus Aurelius · intisari bebas (domain publik)", "p": [
		["Buku ini adalah catatan pribadi seorang kaisar Romawi. Ia menulisnya untuk dirinya sendiri, bukan untuk dibaca orang lain.", "Setiap pagi ia mengingatkan diri: hari ini aku akan bertemu orang yang menyebalkan. Tapi mereka juga saudaraku, dan aku tidak akan terpancing."],
		["Yang membuat kita gelisah bukan kejadiannya, tapi penilaian kita tentang kejadian itu. Ubah penilaianmu, maka gelisahnya pun hilang.", "Ada hal yang bisa kita kendalikan, ada yang tidak. Pikiran dan tindakan kita milik kita; sisanya, terima dengan lapang dada."],
		["Hidup itu singkat. Jangan habiskan waktu menebak-nebak isi kepala orang lain.", "Lakukan setiap pekerjaan seolah itu yang terakhir: dengan tenang, sungguh-sungguh, dan tanpa pura-pura."],
		["Saat lelah dan ingin menyerah, ingatlah: kita lahir untuk bekerja sama, seperti kaki, tangan, dan mata dalam satu tubuh.", "Pelajaran: kuasai pikiranmu, bukan keadaan. Di situlah ketenangan sejati. TAMAT"]]},
	{"t": "Think and Grow Rich", "src": "Napoleon Hill, 1937 · intisari bebas", "p": [
		["Napoleon Hill mewawancarai ratusan orang sukses di zamannya. Ia ingin tahu: pola pikir apa yang mereka miliki bersama?", "Jawabannya dimulai dari keinginan yang membara. Bukan sekadar berharap, tapi benar-benar tahu apa yang dicari."],
		["Tuliskan tujuanmu dengan jelas: apa yang kamu inginkan, kapan, dan apa yang siap kamu berikan sebagai gantinya.", "Baca tujuan itu setiap pagi dan malam. Keyakinan tumbuh lewat pengulangan, sampai tujuan terasa nyata."],
		["Pengetahuan baru berguna jika diatur dan dipakai. Cari orang-orang yang mau bekerja sama; Hill menyebutnya kelompok 'mastermind'.", "Kegagalan sementara bukan kekalahan. Banyak orang berhenti justru satu langkah sebelum berhasil."],
		["Musuh terbesar adalah rasa takut: takut miskin, takut dikritik, takut gagal. Kenali, lalu lawan pelan-pelan.", "Pelajaran: tujuan jelas, rencana nyata, dan ketekunan mengalahkan bakat yang dibiarkan menganggur. TAMAT"]]},
	{"t": "As a Man Thinketh", "src": "James Allen, 1903 · intisari bebas (domain publik)", "p": [
		["Buku tipis ini punya satu gagasan besar: kita adalah hasil dari apa yang kita pikirkan setiap hari.", "Pikiran ibarat kebun. Kalau tidak ditanami bunga, rumput liar akan tumbuh sendiri."],
		["Keadaan hidup tidak selalu bisa kita pilih, tapi cara kita menanggapinya mencerminkan isi pikiran kita.", "Orang yang membiasakan pikiran bersih dan jujur, perlahan akan menemukan hidupnya ikut tertata."],
		["Pikiran juga memengaruhi tubuh. Cemas berlebihan membuat lelah; pikiran tenang membuat tubuh lebih segar.", "Tujuan yang jelas membuat pikiran tidak mudah goyah. Tanpa tujuan, kita mudah terseret rasa khawatir."],
		["Ketenangan adalah buah dari latihan panjang menguasai diri, dan itulah kekuatan yang sesungguhnya.", "Pelajaran: rawat pikiranmu seperti kebun. Apa yang kamu tanam, itulah yang kamu tuai. TAMAT"]]},
	{"t": "1984", "src": "George Orwell · ringkasan cerita (bukan kutipan)", "p": [
		["Winston Smith tinggal di negeri Oseania. Di mana-mana ada layar yang mengawasi warga, dan wajah Bung Besar menatap dari poster.", "Winston bekerja di Kementerian Kebenaran. Tugasnya justru mengubah catatan sejarah agar sesuai kemauan Partai."],
		["Diam-diam Winston menulis buku harian. Di negeri itu, sekadar berpikir berbeda sudah dianggap kejahatan.", "Ia bertemu Julia, dan keduanya mulai melawan dengan cara kecil: bertemu sembunyi-sembunyi dan bermimpi tentang kebebasan."],
		["Bahasa pun dipangkas. Partai membuat kata-kata baru yang makin sedikit, supaya orang makin sulit memikirkan perlawanan.", "Sayang, orang yang Winston percaya ternyata bagian dari Partai. Winston dan Julia ditangkap."],
		["Winston dipaksa menerima apa pun yang dikatakan Partai, bahkan hal yang jelas keliru.", "Pesan buku ini: kebebasan berpikir dan kejujuran tentang fakta adalah hal berharga yang perlu dijaga. TAMAT"]]},
	{"t": "The Adventures of Sherlock Holmes", "src": "Arthur Conan Doyle · intisari bebas (domain publik)", "p": [
		["Di Baker Street, London, tinggal detektif Sherlock Holmes bersama sahabatnya, dokter Watson, yang mencatat semua kasusnya.", "Holmes bisa menebak dari mana seseorang datang hanya dari debu di sepatunya atau bekas tinta di jarinya."],
		["Seorang raja datang meminta tolong: ia takut sebuah foto lama mempermalukannya. Holmes menyamar untuk mencari foto itu.", "Tapi lawannya, Irene Adler, ternyata sama cerdasnya. Dialah satu-satunya orang yang berhasil mengecoh Holmes."],
		["Di kasus lain, seorang pria berambut merah dibayar hanya untuk menyalin ensiklopedia. Aneh, bukan?", "Holmes curiga ada yang menggali terowongan ke bank di sebelahnya. Benar saja, pencurinya tertangkap basah."],
		["Rahasia Holmes sederhana: amati detail kecil, singkirkan yang mustahil, dan yang tersisa pasti kebenarannya.", "Pelajaran: jangan buru-buru menyimpulkan. Lihat, catat, pikirkan, baru putuskan. TAMAT"]]},
	{"t": "Letters from a Stoic", "src": "Seneca · intisari bebas (domain publik)", "p": [
		["Seneca menulis surat-surat untuk sahabatnya, Lucilius, berisi nasihat cara hidup yang tenang dan bijak.", "Nasihat pertama: jagalah waktumu. Harta yang hilang bisa dicari lagi, tapi waktu yang terbuang tidak akan kembali."],
		["Jangan membaca terlalu banyak buku sekaligus. Lebih baik sedikit, tapi benar-benar dipahami dan dipraktikkan.", "Pilih teman dengan hati-hati. Kebiasaan orang di sekitar kita lambat laun akan menular."],
		["Sesekali, latihlah hidup sederhana: makan seadanya, berpakaian biasa. Kamu akan sadar bahwa kekurangan tidak semenakutkan bayangan.", "Kita sering lebih menderita dalam khayalan daripada dalam kenyataan."],
		["Orang kaya sejati bukan yang punya banyak, tapi yang merasa cukup.", "Pelajaran: hargai waktu, pilih teman baik, dan latih hati agar tidak mudah takut. TAMAT"]]},
	{"t": "The Little Prince", "src": "Antoine de Saint-Exupéry · ringkasan cerita (bukan kutipan)", "p": [
		["Seorang pilot jatuh di gurun Sahara. Esok paginya, seorang anak kecil berambut keemasan memintanya menggambar seekor domba.", "Anak itu adalah Pangeran Kecil, yang datang dari sebuah asteroid mungil dengan tiga gunung berapi dan setangkai mawar."],
		["Ia meninggalkan mawarnya yang manja, lalu mengunjungi planet-planet lain berisi orang dewasa yang aneh.", "Ada raja yang ingin memerintah semua hal, pengusaha yang sibuk menghitung bintang, dan pemabuk yang minum agar lupa rasa malunya."],
		["Di Bumi, ia bertemu seekor rubah. Rubah memintanya menjinakkan dirinya, yaitu membangun ikatan pelan-pelan, hari demi hari.", "Dari rubah ia belajar: mawarnya istimewa bukan karena berbeda, tapi karena waktu dan perhatian yang telah ia berikan."],
		["Sang pangeran pun rindu pulang. Si pilot tidak pernah melupakannya setiap kali menatap bintang.", "Pesan cerita: hal paling penting sering tidak terlihat oleh mata, hanya bisa dirasakan oleh hati. TAMAT"]]},
	{"t": "How to Live on 24 Hours a Day", "src": "Arnold Bennett, 1908 · intisari bebas (domain publik)", "p": [
		["Setiap orang mendapat jatah yang sama setiap hari: 24 jam. Orang kaya tidak dapat lebih, orang miskin tidak dapat kurang.", "Masalahnya, banyak orang merasa waktunya habis untuk bekerja, lalu sisanya terbuang begitu saja."],
		["Bennett menyarankan: anggap jam di luar kerja sebagai 'hari kedua' milikmu sendiri, bukan sisa yang tak berarti.", "Mulailah kecil. Pakai 90 menit, tiga malam seminggu, untuk belajar sesuatu yang benar-benar kamu minati."],
		["Waktu di perjalanan pun bisa dipakai: melatih fokus, merenung, atau membaca.", "Jangan terlalu ambisius di awal. Rencana yang terlalu berat cepat membuat kita menyerah."],
		["Yang terpenting adalah konsisten, bukan sempurna. Sedikit demi sedikit, lama-lama hidup terasa lebih penuh.", "Pelajaran: kamu tidak butuh waktu lebih banyak, kamu butuh cara memakai waktu yang lebih baik. TAMAT"]]},
	{"t": "Journey to the West", "src": "Wu Cheng'en · intisari bebas (domain publik)", "p": [
		["Dari sebuah batu ajaib lahirlah Sun Wukong, si Raja Kera. Ia sakti, bisa berubah wujud dan terbang di atas awan.", "Karena sombong, ia mengacau di kahyangan. Akhirnya ia dihukum, ditindih gunung selama lima ratus tahun."],
		["Seorang biksu, Tang Sanzang, diutus ke barat untuk mengambil kitab suci. Sun Wukong dibebaskan untuk menjadi pengawalnya.", "Ikut pula Zhu Bajie si babi yang rakus dan Sha Wujing yang pendiam namun setia."],
		["Di sepanjang jalan, siluman-siluman ingin menangkap sang biksu. Sun Wukong berkali-kali menyelamatkannya dengan akal dan kesaktian.", "Mereka sering bertengkar, tapi tetap saling menolong. Ada delapan puluh satu rintangan yang harus dilewati."],
		["Akhirnya mereka tiba di barat dan membawa pulang kitab suci. Semua anggota rombongan ikut tumbuh menjadi lebih baik.", "Pelajaran: perjalanan panjang mengubah kita, apalagi bila ditempuh bersama teman yang setia. TAMAT"]]},
]
const BOOK_R := Rect2(170, 920, 1110, 940)
var book := 0
var page := 0
var focus := 1.0
var coffee := 1.0
var _bk: _Book
var _mug: _Mug
var _coffee_bar: ColorRect
var _cup_bar: ColorRect
var _cafe_hint: PanelContainer
var _cafe_hint_lbl: Label
var _lt_dim: ColorRect
var _rt_dim: ColorRect


func _show_cafe_in() -> void:
	_clear()
	view = "cafe_in"
	page = 0
	_bg("res://assets/side/cafe_in.jpg")
	_bk = _Book.new()
	_bk.font = font
	_layer.add_child(_bk)
	var life := _CafeLife.new()
	life.font = font
	_layer.add_child(life)
	_layer.move_child(life, 1)
	_mug = _Mug.new()
	_layer.add_child(_mug)
	# Meter fokus & isi gelas
	var cp := _panel(Rect2(30, 1960, 560, 170), Color(1, 0.98, 0.94, 0.95))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	cp.add_child(vb)
	_coffee_bar = _meter(vb, "Fokus", Color("7aa86b"))
	_cup_bar = _meter(vb, "Kopi", Color("8a5a3a"))
	# Tombol panah & gelas (gambar di ilustrasi; area ketuk asli)
	_hit(Rect2(70, 1125, 152, 150), func(): _flip(-1))
	_hit(Rect2(1218, 1125, 152, 150), func(): _flip(1))
	_hit(Rect2(1160, 2020, 230, 190), _sip)
	_hit(Rect2(900, 1690, 330, 330), _sip)
	_lt_dim = _dim(Rect2(70, 1125, 152, 150))
	_rt_dim = _dim(Rect2(1218, 1125, 152, 150))
	_cafe_hint = _panel(Rect2(360, 2150, 760, 96), Color("5a4434"))
	_cafe_hint_lbl = _lbl("", 32, Color("fff6e6"))
	_cafe_hint.add_child(_cafe_hint_lbl)
	_bottom([["Keluar Cafe", D.C_GREEN, _show_cafe_ext], ["Order Minuman", D.C_PINK, _order],
		["Baca Buku Lain", D.C_YELLOW, func():
			book = (book + 1) % BOOKS.size()
			page = 0
			game.sfx("pop", -6.0)
			game.ui.toast("Membuka \"%s\"" % BOOKS[book].t)
			_render_book()]], 2262)
	_layer.move_child(_mug, _layer.get_child_count() - 1)
	_render_book()


func _meter(parent: Control, name: String, col: Color) -> ColorRect:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	parent.add_child(hb)
	var l := _lbl(name, 32)
	l.custom_minimum_size = Vector2(110, 0)
	hb.add_child(l)
	var bg := ColorRect.new()
	bg.color = Color("e6d8c2")
	bg.custom_minimum_size = Vector2(380, 30)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(bg)
	var f := ColorRect.new()
	f.color = col
	f.size = Vector2(380, 30)
	bg.add_child(f)
	return f


func _dim(r: Rect2) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.95, 0.92, 0.86, 0.6)
	c.position = r.position + Vector2(8, 8)
	c.size = r.size - Vector2(16, 16)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(c)
	return c


func _render_book() -> void:
	var b: Dictionary = BOOKS[book]
	var n: int = b.p.size()
	_bk.set_pages(b.t, b.src, b.p[page][0], b.p[page][1], page, n)
	_coffee_bar.size.x = 380.0 * clampf(focus, 0, 1)
	_cup_bar.size.x = 380.0 * clampf(coffee, 0, 1)
	_mug.level = coffee
	_lt_dim.visible = page == 0
	_rt_dim.visible = page >= n - 1
	if focus <= 0.15:
		_cafe_hint_lbl.text = "Maryam ngantuk... ketuk kopinya" if coffee > 0.01 else "Kopi habis! Order minuman dulu"
	elif page >= n - 1:
		_cafe_hint_lbl.text = "Tamat! Ketuk Baca Buku Lain"
	else:
		_cafe_hint_lbl.text = "Geser halaman ke kiri / ketuk > (hal. %d dari %d)" % [page * 2 + 3, n * 2]


func _flip(d: int) -> void:
	var n: int = BOOKS[book].p.size()
	if d > 0 and focus <= 0.15:
		game.ui.toast("Maryam mulai ngantuk... minum kopinya dulu!", "bad")
		_mug.wiggle()
		return
	var np := clampi(page + d, 0, n - 1)
	if np == page:
		if d > 0: game.ui.toast("Buku ini sudah tamat. Coba buku lain!")
		return
	page = np
	if d > 0: focus = maxf(0.0, focus - 0.2)
	_bk.turn(d)
	game.sfx("pop", -8.0)
	if page == n - 1 and _toast_once("baca%d" % book):
		game.add_xp(15)
		for e in game.each_tenant():
			e[1].tenant.happy = clampf(float(e[1].tenant.happy) + 2.0, 0, 100)
		game.maybe_review("baca")
		game.ui.toast("Maryam selesai membaca \"%s\"! +15 XP, penghuni ikut senang (+2)." % BOOKS[book].t, "gold")
	_render_book()


func _sip() -> void:
	if coffee <= 0.01:
		game.ui.toast("Gelasnya sudah kosong. Ketuk Order Minuman!", "bad")
		_mug.wiggle()
		return
	coffee = maxf(0.0, coffee - 0.25)
	focus = minf(1.0, focus + 0.45)
	_mug.sip()
	game.sfx("pop", -10.0)
	game.ui.toast(["Sruput~ Hangat dan wangi.", "Hmm, kopi susunya pas.", "Ahh, segar lagi!"].pick_random())
	_render_book()


func _order() -> void:
	var c := 25000.0
	if coffee >= 0.99:
		game.ui.toast("Kopinya masih penuh, diminum dulu!")
		return
	if float(game.S.money) < c:
		game.ui.toast(game.ui.money_why(c), "bad"); return
	game.spend(c, "other")
	coffee = 1.0
	_mug.refill()
	game.sfx("buy", -6.0)
	game.ui.toast("Kopi susu gula aren datang! (%s)" % D.rp(c), "gold")
	_render_book()


## Buku terbuka di ilustrasi: halaman ditimpa kertas bersih lalu diisi teks sungguhan,
## mengikuti sudut miring halaman. Bisa dianimasikan saat dibalik.
class _Book extends Node2D:
	var font: Font
	# Sudut halaman pada ilustrasi
	const LP := [Vector2(192, 1196), Vector2(606, 1108), Vector2(792, 1682), Vector2(298, 1852)]
	const RP := [Vector2(610, 1106), Vector2(978, 922), Vector2(1268, 1542), Vector2(798, 1682)]
	var _lt: Label
	var _rt: Label
	var _lh: Node2D
	var _rh: Node2D
	var _flip := 0.0
	var _dir := 1
	var _ln: Label
	var _rn: Label

	func _ready() -> void:
		_lh = _holder(LP, Vector2(420, 560))
		_rh = _holder(RP, Vector2(410, 560))
		_lt = _text(_lh, Vector2(420, 560), 27)
		_rt = _text(_rh, Vector2(410, 560), 27)
		_ln = _num(_lh, Vector2(420, 560))
		_rn = _num(_rh, Vector2(410, 560))

	func _holder(q: Array, sz: Vector2) -> Node2D:
		var h := Node2D.new()
		var xa: Vector2 = (q[1] - q[0]) / sz.x
		var ya: Vector2 = (q[3] - q[0]) / sz.y
		h.transform = Transform2D(xa, ya, q[0])
		add_child(h)
		return h

	func _text(h: Node2D, sz: Vector2, fs: int) -> Label:
		var l := Label.new()
		l.position = Vector2(34, 46)
		l.size = Vector2(sz.x - 68, sz.y - 100)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", Color("4a3626"))
		l.add_theme_constant_override("line_spacing", 4)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l)
		return l

	func _num(h: Node2D, sz: Vector2) -> Label:
		var l := Label.new()
		l.position = Vector2(0, sz.y - 48)
		l.size = Vector2(sz.x, 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color("9a8068"))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l)
		return l

	func set_pages(title: String, src: String, left: String, right: String, pg: int, n: int) -> void:
		_lt.text = ("%s\n" % title.to_upper() if pg == 0 else "") + left
		_rt.text = right + ("\n\n— %s" % src if pg == n - 1 else "")
		_ln.text = str(pg * 2 + 1)
		_rn.text = str(pg * 2 + 2)

	func turn(d: int) -> void:
		_dir = d
		_flip = 1.0

	func _process(dt: float) -> void:
		if _flip > 0.0:
			_flip = maxf(0.0, _flip - dt * 2.6)
			var a := 1.0 - _flip
			_lt.modulate.a = a
			_rt.modulate.a = a
			queue_redraw()

	func _draw() -> void:
		var paper := Color("fdf0d2")
		for q in [LP, RP]:
			var pts := PackedVector2Array()
			for i in range(4):
				var c: Vector2 = (q[0] + q[1] + q[2] + q[3]) / 4.0
				pts.append(q[i].lerp(c, 0.035))
			draw_colored_polygon(pts, paper)
		# Lipatan tengah buku
		draw_line(LP[1], LP[2], Color(0.6, 0.48, 0.35, 0.35), 10)
		# Halaman yang sedang dibalik (lengkung melayang)
		if _flip > 0.0:
			var k := 1.0 - _flip
			var spine0: Vector2 = LP[1]
			var spine1: Vector2 = LP[2]
			var src0: Vector2 = RP[1] if _dir > 0 else LP[0]
			var src1: Vector2 = RP[2] if _dir > 0 else LP[3]
			var dst0: Vector2 = LP[0] if _dir > 0 else RP[1]
			var dst1: Vector2 = LP[3] if _dir > 0 else RP[2]
			var lift := sin(k * PI) * 160.0
			var e0 := src0.lerp(dst0, k) + Vector2(0, -lift)
			var e1 := src1.lerp(dst1, k) + Vector2(0, -lift * 0.6)
			draw_colored_polygon(PackedVector2Array([spine0, e0, e1, spine1]), Color("f6e6c0"))
			draw_polyline(PackedVector2Array([spine0, e0, e1, spine1]), Color(0.45, 0.35, 0.25, 0.5), 3)


## Gelas kopi + tangan (dipotong dari ilustrasi). Saat diseruput gelas mendekat ke
## kamera (membesar & naik), isi kopinya turun, lalu kembali ke meja.
class _Mug extends Node2D:
	var level := 1.0
	var _shown := 1.0
	var _a := 0.0          # 0..1 progres animasi minum
	var _wig := 0.0
	var t := 0.0
	var _tex: Texture2D = preload("res://assets/side/cafe_mug.png")
	const ORG := Vector2(880, 1630)
	const PIV := Vector2(1130, 1870)
	const C := Vector2(1060, 1768)
	const RX := 138.0
	const RY := 56.0
	const DUR := 1.5

	func sip() -> void: _a = 0.001
	func wiggle() -> void: _wig = 1.0
	func refill() -> void: _shown = 0.0

	func _process(dt: float) -> void:
		t += dt
		if _a > 0.0:
			_a += dt / DUR
			if _a >= 1.0: _a = 0.0
		var lift := _lift()
		# isi turun saat gelas sedang di bibir; isi ulang naik perlahan
		if level < _shown:
			if lift > 0.6: _shown = move_toward(_shown, level, dt * 0.6)
		else:
			_shown = move_toward(_shown, level, dt * 0.8)
		_wig = maxf(0.0, _wig - dt * 2.5)
		queue_redraw()

	func _lift() -> float:
		if _a <= 0.0: return 0.0
		# naik 0..0.3, tahan 0.3..0.7, turun 0.7..1
		var k := 1.0
		if _a < 0.3: k = _a / 0.3
		elif _a > 0.7: k = (1.0 - _a) / 0.3
		return k * k * (3.0 - 2.0 * k)

	func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in range(36):
			var a := TAU * i / 36.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, col)

	func _draw() -> void:
		var e := _lift()
		var z := 1.0 + 0.5 * e
		var piv := PIV + Vector2(-10, -25) * e + Vector2(sin(t * 40.0) * 8.0 * _wig, 0)
		draw_set_transform(piv, -0.08 * e, Vector2(z, z))
		var o := -PIV
		draw_texture(_tex, ORG + o)
		var c := C + o
		_ell(c, RX - 6, RY - 4, Color("d9c3a6"))
		var lv := _shown
		if lv > 0.01:
			var drop := (1.0 - lv) * 48.0
			var s := 1.0 - (1.0 - lv) * 0.2
			_ell(c + Vector2(0, drop), (RX - 14) * s, (RY - 12) * s, Color("6e4632"))
			_ell(c + Vector2(-20, drop - 6), (RX - 60) * s, (RY - 34) * s, Color(1, 1, 1, 0.12))
			if e > 0.5:
				draw_arc(c + Vector2(0, drop), (RX - 40) * (0.6 + 0.4 * sin(t * 9.0)), 0, TAU, 32, Color(1, 1, 1, 0.3), 4)
			for i in range(3):
				var k := fmod(t * 0.35 + i * 0.33, 1.0)
				var a := (1.0 - k) * 0.4 * clampf(lv * 2.0, 0.2, 1.0) * (1.0 - e * 0.7)
				var pts := PackedVector2Array()
				for j in range(10):
					pts.append(c + Vector2(-40 + i * 40 + sin(t * 2.0 + j * 0.7 + i) * 18, -40 - k * 260 - j * 18))
				draw_polyline(pts, Color(1, 1, 1, a), 12)
		else:
			draw_arc(c + Vector2(0, 20), RX - 40, 0.3, PI - 0.3, 16, Color(0.43, 0.27, 0.2, 0.5), 6)
		draw_set_transform(Vector2.ZERO)


## Suasana cafe: pengunjung lalu-lalang di teras & meja-meja saling mengobrol.
class _CafeLife extends Node2D:
	var font: Font
	var t := 0.0
	var walkers: Array = []
	var _spawn := 1.0
	var _chat_t := 0.0
	var _chat_i := 0
	var bubble := {}   # {"p": Vector2, "s": String, "t": float}
	const PATH_Y := 478.0
	const WALK_CHARS := ["barista", "siswi", "kupluk", "flanel", "nenek", "kakek", "kasir"]
	# Posisi kepala orang-orang di ilustrasi + percakapan bergiliran.
	const TALKS := [
		[[Vector2(70, 540), Vector2(150, 515), Vector2(285, 540)], ["Eh, tugas kelompok udah?", "Belum, nanti malam ya!", "Aku traktir kopi deh.", "Serius? Asyik!"]],
		[[Vector2(600, 410), Vector2(765, 385)], ["Kopinya enak banget.", "Iya, gula arennya pas.", "Minggu depan ke sini lagi?", "Boleh, bawa buku ya."]],
		[[Vector2(1000, 470), Vector2(1170, 490)], ["Gimana kerjaan?", "Lagi sibuk, tapi seru.", "Jangan lupa istirahat.", "Siap, makanya ngopi dulu."]],
		[[Vector2(1365, 350)], ["Satu kopi susu, siap!", "Pesanan meja 3 ya!", "Latte art-nya bentuk hati~"]],
	]

	func _process(dt: float) -> void:
		t += dt
		_spawn -= dt
		if _spawn <= 0.0 and walkers.size() < 2:
			_spawn = randf_range(4.0, 8.0)
			_add_walker()
		for w in walkers.duplicate():
			if w.pause > 0.0:
				w.pause -= dt
				continue
			w.x += w.dir * 70.0 * dt
			if not w.paused and absf(w.x - w.stop) < 4.0:
				w.paused = true
				w.pause = 2.2
				bubble = {"p": Vector2(w.x, PATH_Y - 230), "s": ["Permisi~", "Halo!", "Antre dulu ah.", "Wah, ramai ya."].pick_random(), "t": 2.2}
			if w.x < -150 or w.x > 900: walkers.erase(w)
		_chat_t -= dt
		if _chat_t <= 0.0:
			_chat_t = 2.8
			_chat_i += 1
			var g: Array = TALKS[int(_chat_i / 4.0) % TALKS.size()]
			var heads: Array = g[0]
			var lines: Array = g[1]
			bubble = {"p": heads[_chat_i % heads.size()], "s": lines[_chat_i % lines.size()], "t": 2.5}
		if not bubble.is_empty():
			bubble.t -= dt
			if bubble.t <= 0.0: bubble = {}
		queue_redraw()

	func _add_walker() -> void:
		var ch: String = WALK_CHARS.pick_random()
		var d := 1 if randf() < 0.5 else -1
		var f: Array = []
		for k in ["walk", "walk2", "idle"]:
			f.append(load("res://assets/chars/%s/%s_L.png" % [ch, k]))
		walkers.append({"f": f, "x": -120.0 if d > 0 else 880.0, "dir": d, "stop": randf_range(120, 520), "pause": 0.0, "paused": false, "ph": randf()})

	func _draw() -> void:
		for w in walkers:
			var tex: Texture2D = w.f[2] if w.pause > 0.0 else w.f[int((t + w.ph) * 4.0) % 2]
			var sc := 0.5
			var sz := tex.get_size() * sc
			var bob := 0.0 if w.pause > 0.0 else absf(sin((t + w.ph) * 12.0)) * 4.0
			# Sprite _L menghadap kiri; balik bila berjalan ke kanan.
			var r := Rect2(Vector2(w.x - sz.x / 2.0, PATH_Y - sz.y - bob), sz)
			if w.dir > 0:
				r.position.x += sz.x
				r.size.x = -sz.x
			draw_texture_rect(tex, r, false)
		if not bubble.is_empty() and font:
			var fs := 30
			var tw := font.get_string_size(bubble.s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var a := clampf(bubble.t * 3.0, 0.0, 1.0)
			var p: Vector2 = bubble.p
			var box := Rect2(p.x - tw / 2.0 - 18, p.y - 74, tw + 36, 52)
			box.position.x = clampf(box.position.x, 8, 1430 - box.size.x)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1, 0.98, 0.94, 0.95 * a)
			sb.border_color = Color(0.36, 0.27, 0.2, a)
			sb.set_border_width_all(3)
			sb.set_corner_radius_all(22)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-12, -24), p + Vector2(12, -24), p + Vector2(0, -6)]), Color(1, 0.98, 0.94, 0.95 * a))
			draw_style_box(sb, box)
			draw_string(font, Vector2(box.position.x + 18, box.position.y + 36), bubble.s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.29, 0.21, 0.15, a))


# ---------------- Lapangan Padel ----------------
# Maryam melawan Ryan atau Aji; Kak Ray jadi pelatih di pinggir lapangan.
const FOES := [["Ryan", 0.55, "padel_ryan"], ["Aji", 0.75, "padel_aji"]]
var foe := 0
var pts := [0, 0]
var _score_lbl: Label
var _foe_lbl: Label
var _ball: _Ball
var _msg: Label
var _hint: Label
var _ray_lbl: Label
var _ray_box: PanelContainer
var _mar: TextureRect
var _opp: TextureRect
var _ray: TextureRect
var _tut := 0          # 0 sapa, 1 lihat bola, 2 tunggu lingkaran, 3 pukul!, 4 selesai
var _rally := 0


func _sprite(path: String, sc: float, feet: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.size = tr.texture.get_size() * sc
	tr.position = feet - Vector2(tr.size.x / 2.0, tr.size.y)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.pivot_offset = Vector2(tr.size.x / 2.0, tr.size.y)
	_layer.add_child(tr)
	return tr


func _show_padel() -> void:
	_clear()
	view = "padel"
	_bg("res://assets/side/padel.jpg")
	_opp = _sprite("res://assets/chars/%s/ready_L.png" % FOES[foe][2], 0.6, Vector2(800, 1060))
	_ball = _Ball.new()
	_layer.add_child(_ball)
	_ray = _sprite("res://assets/chars/trainer/clip_L.png", 1.15, Vector2(185, 2140))
	_mar = _sprite("res://assets/chars/padel_back/ready_L.png", 1.7, Vector2(820, 2130))
	_ball.player = _mar
	_ball.missed.connect(_point.bind(1))
	_ball.foe_missed.connect(_point.bind(0))
	_ball.hit_ok.connect(_on_hit)
	# Papan skor
	var sp := _panel(Rect2(420, 210, 600, 120))
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 22)
	sp.add_child(hb)
	hb.add_child(_lbl("Maryam", 36))
	_score_lbl = _lbl("0 - 0", 54)
	_score_lbl.custom_minimum_size = Vector2(200, 0)
	hb.add_child(_score_lbl)
	_foe_lbl = _lbl("", 36)
	hb.add_child(_foe_lbl)
	# Pesan besar di tengah lapangan
	_msg = _lbl("", 64, Color("fff6e6"))
	_msg.add_theme_color_override("font_outline_color", D.C_LINE)
	_msg.add_theme_constant_override("outline_size", 16)
	_msg.position = Vector2(0, 1480)
	_msg.size = Vector2(D.IW, 120)
	_layer.add_child(_msg)
	# Gelembung Kak Ray
	_ray_box = _panel(Rect2(40, 1440, 640, 220), Color("fffaf0"))
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	_ray_box.add_child(rv)
	var rn := _lbl("Kak Ray · Pelatih", 30, Color("8a5a3a"))
	rn.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rv.add_child(rn)
	_ray_lbl = _lbl("", 36, D.C_INK, true)
	_ray_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_ray_lbl.custom_minimum_size = Vector2(590, 0)
	rv.add_child(_ray_lbl)
	# Petunjuk yang mengikuti keadaan bola
	_hint = _lbl("", 44, Color("fff6e6"))
	_hint.add_theme_color_override("font_outline_color", D.C_LINE)
	_hint.add_theme_constant_override("outline_size", 12)
	_hint.position = Vector2(0, 2165)
	_hint.size = Vector2(D.IW, 70)
	_layer.add_child(_hint)
	_bottom([["Balik ke Kost", D.C_GREEN, func(): _walk(-1)],
		["Ganti Lawan", D.C_PINK, func():
			foe = (foe + 1) % FOES.size()
			_opose("ready")
			_ray_say("Lawan baru: %s! %s" % [FOES[foe][0], "Dia santai, cocok buat pemanasan." if foe == 0 else "Pak Aji pukulannya keras, fokus ya!"])
			_new_match()],
		["Main Lagi", D.C_YELLOW, func():
			_ray_say("Ulang dari nol. Atur napas dulu, Mbak!")
			_new_match()]], 2248)
	var S: Dictionary = game.S
	if not S.has("side"): S.side = {}
	_tut = 4 if S.side.get("padel_tut", false) else 0
	if _tut == 0:
		_ray_say("Halo Mbak Maryam! Aku Kak Ray. Hari ini lawanmu %s. Perhatikan bola dari seberang net, ya." % FOES[foe][0])
	else:
		_ray_say("Selamat datang lagi! Lawanmu %s. Ingat: pukul saat bola masuk lingkaran putih." % FOES[foe][0])
	_new_match()


func _ray_say(t: String) -> void:
	_ray_lbl.text = t
	_ray_box.modulate.a = 1.0
	_ray.texture = load("res://assets/chars/trainer/%s_L.png" % ("happy" if t.find("!") >= 0 else "clip"))


func _new_match() -> void:
	pts = [0, 0]
	_rally = 0
	_foe_lbl.text = FOES[foe][0]
	_ball.skill = float(FOES[foe][1])
	_render_score()
	_ball.serve(2.2 if _tut < 4 else 1.4)


const PT := ["0", "15", "30", "40"]


func _render_score() -> void:
	if pts[0] >= 3 and pts[1] >= 3:
		_score_lbl.text = "Deuce" if pts[0] == pts[1] else ("Adv M" if pts[0] > pts[1] else "Adv " + FOES[foe][0].substr(0, 1))
	else:
		_score_lbl.text = "%s - %s" % [PT[mini(pts[0], 3)], PT[mini(pts[1], 3)]]


func _say(t: String) -> void:
	_msg.text = t
	_msg.modulate.a = 1.0
	var tw := _msg.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_msg, "modulate:a", 0.0, 0.4)


func _process(_dt: float) -> void:
	if view != "padel" or _ball == null: return
	if _op_t > 0.0:
		_op_t -= _dt
		if _op_t <= 0.0: _opose("ready")
	elif _ball.state == "out" and _ball.t > _ball.dur * 0.55 and _opp.texture.resource_path.find("swing") < 0:
		_opose("swing", 0.5)
	elif _ball.state == "idle" and _ball._wait > 0.0 and _ball._wait < 0.6 and _opp.texture.resource_path.find("serve") < 0 and ResourceLoader.exists("res://assets/chars/%s/serve_L.png" % FOES[foe][2]):
		_opose("serve", 0.7)
	if _mp_t > 0.0:
		_mp_t -= _dt
		if _mp_t <= 0.0: _mpose("ready")
	elif _ball.state == "in" and _ball.in_zone() and _mar.texture.resource_path.find("back_L") < 0:
		_mpose("back")
	elif _ball.state == "in" and not _ball.in_zone() and _ball.t > _ball.dur * 0.3 and _mar.texture.resource_path.find("ready") >= 0:
		_mpose("run" if randf() < 0.5 else "run2", 0.5)
	elif _ball.state == "idle" and _mar.texture.resource_path.find("back_L") >= 0:
		_mpose("ready")
	# Lawan bergerak mengikuti bola
	var tx := clampf(_ball.a.x if _ball.state == "in" else _ball.b.x, 520, 1060)
	_opp.position.x = lerpf(_opp.position.x, tx - _opp.size.x / 2.0, 0.08)
	# Petunjuk sesuai keadaan bola (bukan teks hiasan)
	var zone := _ball.in_zone()
	if _ball.state == "in" and zone:
		_hint.text = "SEKARANG! Geser ke atas!"
		_hint.add_theme_color_override("font_color", Color("ffe28a"))
	elif _ball.state == "in":
		_hint.text = "Bola datang... tunggu lingkaran putih"
		_hint.add_theme_color_override("font_color", Color("fff6e6"))
	elif _ball.state == "out":
		_hint.text = "Bagus! Bola menuju %s" % FOES[foe][0]
		_hint.add_theme_color_override("font_color", Color("fff6e6"))
	else:
		_hint.text = "%s bersiap servis..." % FOES[foe][0]
		_hint.add_theme_color_override("font_color", Color("fff6e6"))
	# Tutorial Kak Ray mengikuti apa yang terjadi di lapangan
	if _tut == 0 and _ball.state == "in":
		_tut = 1
		_ray_say("Itu bolanya datang! Jangan buru-buru, tunggu sampai bola turun ke dekatmu.")
	elif _tut == 1 and zone:
		_tut = 2
		_ray_say("Lingkaran putih muncul = zona pukul. Geser jarimu ke ATAS sekarang!")
	_ball.show_guide = _tut < 4


func _on_hit() -> void:
	_rally += 1
	game.sfx("pop", -4.0)
	_mpose("follow", 0.7)
	if _tut < 4:
		_tut = 4
		game.S.side["padel_tut"] = true
		_ray_say("Mantap! Itu pukulan pertamamu. Sekarang lanjutkan sampai menang satu game!")
	elif _rally >= 3:
		_ray_say("Reli %d pukulan! Pertahankan ritmenya!" % _rally)


var _mp_t := 0.0
var _op_t := 0.0


func _opose(p: String, secs: float = 0.0) -> void:
	var tex: Texture2D = load("res://assets/chars/%s/%s_L.png" % [FOES[foe][2], p])
	var feet := _opp.position + Vector2(_opp.size.x / 2.0, _opp.size.y)
	_opp.texture = tex
	_opp.size = tex.get_size() * 0.6
	_opp.position = feet - Vector2(_opp.size.x / 2.0, _opp.size.y)
	_op_t = secs


## Ganti pose Maryam (tampak belakang), kembali ke "ready" setelah `secs`.
func _mpose(p: String, secs: float = 0.0) -> void:
	var tex: Texture2D = load("res://assets/chars/padel_back/%s_L.png" % p)
	var feet := _mar.position + Vector2(_mar.size.x / 2.0, _mar.size.y)
	_mar.texture = tex
	_mar.size = tex.get_size() * 1.7
	_mar.position = feet - Vector2(_mar.size.x / 2.0, _mar.size.y)
	_mp_t = secs


func _point(who: int) -> void:
	pts[who] += 1
	_rally = 0
	game.sfx("pop" if who == 0 else "arrive", -6.0)
	_opose("cheer" if who == 1 else "tired", 1.3)
	_mpose("cheer" if who == 0 else "tired", 1.2)
	if pts[who] >= 4 and pts[who] - pts[1 - who] >= 2:
		if who == 0:
			_say("GAME! Maryam menang!")
			_mpose("cheer", 2.2)
			_ray_say("Hebat, Mbak Maryam menang! %s minta tanding ulang tuh." % FOES[foe][0])
			if _toast_once("padel"):
				game.add_xp(25)
				for e in game.each_tenant():
					e[1].tenant.happy = clampf(float(e[1].tenant.happy) + 3.0, 0, 100)
				game.maybe_review("padel")
				game.ui.toast("Maryam menang lawan %s! Badan segar, semangat mengurus kost (+25 XP, penghuni +3 senang)." % FOES[foe][0], "gold")
			else:
				game.ui.toast("Menang lagi! Hadiah harian sudah diambil, main santai saja~")
		else:
			_say("%s menang game ini." % FOES[foe][0])
			_ray_say("Nggak apa-apa! Pukul sedikit lebih lambat, pas bola di tengah lingkaran.")
		pts = [0, 0]
		_render_score()
		_ball.serve(2.4)
		return
	if who == 0:
		_say("Poin Maryam!")
		if _tut >= 4: _ray_say(["%s nggak sempat mengejar. Bagus!" % FOES[foe][0], "Pukulan yang rapi!", "Terus tekan, Mbak!"].pick_random())
	else:
		_say("Bola lolos...")
		if _tut >= 4: _ray_say(["Terlalu cepat menggesek. Tunggu lingkaran putih.", "Bola lolos. Tetap tenang, fokus ke bayangan bola.", "Hampir! Geser ke atas tepat saat lingkaran muncul."].pick_random())
	_render_score()
	_ball.serve(1.6)


# ---------------- Input: geser ----------------
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = e.position
			_pressed = true
			_swiped = false
		else:
			_pressed = false
			if view == "cafe_in" and not _swiped and BOOK_R.has_point(e.position) and e.position.distance_to(_press) < 30.0:
				_flip(1)   # ketuk halaman = balik
	elif e is InputEventMouseMotion and _pressed and not _swiped:
		var d: Vector2 = e.position - _press
		if view == "padel":
			if d.y < -70.0 or d.length() > 110.0:
				_swiped = true
				_ball.swing()
		elif view == "cafe_in" and absf(d.x) > 120.0 and absf(d.x) > absf(d.y) * 1.5 and BOOK_R.has_point(_press):
			_swiped = true
			_flip(1 if d.x < 0 else -1)
		elif view == "cafe_ext" and absf(d.x) > 160.0 and absf(d.x) > absf(d.y) * 2.0:
			_swiped = true
			_walk(-1 if d.x < 0 else 1)
		elif view == "walk" and absf(d.x) > 160.0:
			_swiped = true
			for c in _layer.get_children():
				if c is _Walk: c.t = c.dur


## Pemandangan berjalan: langit, gedung/pohon, trotoar bergerak; Maryam melangkah di tengah.
class _Walk extends Node2D:
	signal done
	var theme := "kota"
	var dir := -1
	var font: Font
	var dest := ""
	var from := ""
	var t := 0.0
	var dur := 4.2
	var _fired := false
	var _frames: Array = []
	var _city: Texture2D
	var _city_f: Texture2D
	var _sky := Color("cfe3ee")
	var _veh: Array = []      # [tex_kanan, tex_kiri, x_awal, kecepatan, skala, jalur]

	func _flip_tex(t: Texture2D) -> Texture2D:
		var im := t.get_image()
		im.flip_x()
		return ImageTexture.create_from_image(im)

	## Lalu lintas: kendaraan di jalan kota, sepeda di jalan taman.
	func _make_traffic() -> void:
		var kinds := ["car_yellow", "motor_red", "bus", "car_green", "motor_grey", "angkot", "car_sedan", "truck", "car_suv", "pickup"] if theme == "kota" else ["bike_hijab", "bike_kid", "bike_man"]
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in range(kinds.size()):
			var t: Texture2D = load("res://assets/traffic/%s.png" % kinds[i])
			var right := i % 2 == 0
			var sp := rng.randf_range(260, 420) if theme == "kota" else rng.randf_range(120, 200)
			if kinds[i].begins_with("bus") or kinds[i].begins_with("truck"): sp *= 0.8
			var sc := 0.85 if theme == "kota" else 0.62
			if kinds[i].begins_with("motor"): sc = 0.75
			var x0 := rng.randf_range(-2600, 2600) + i * 520.0 * (1 if right else -1)
			_veh.append([t, _flip_tex(t), x0, sp * (1 if right else -1), sc, 0 if right else 1])
	const INK := Color("4a3626")

	func _ready() -> void:
		_city = load("res://assets/side/kota.jpg" if theme == "kota" else "res://assets/side/taman.png")
		var ci := _city.get_image()
		_sky = ci.get_pixel(ci.get_width() / 2, 4)
		ci.flip_x()
		_city_f = ImageTexture.create_from_image(ci)
		_make_traffic()
		if theme != "kota": _init_park()
		for f in ["walk", "walk2"]:
			var tx: Texture2D = load("res://assets/chars/penjaga/%s_L.png" % f)
			if dir < 0:
				var img := tx.get_image()
				img.flip_x()
				tx = ImageTexture.create_from_image(img)
			_frames.append(tx)

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
		if t >= dur and not _fired:
			_fired = true
			done.emit()

	func _draw() -> void:
		var W := float(D.IW)
		var H := float(D.IH)
		var off := t * 420.0 * float(-dir)   # pemandangan bergeser berlawanan arah langkah
		var kota := theme == "kota"
		if _city:
			_draw_city(off)
			return
		# Langit
		var top := Color("bfe0ee") if kota else Color("cfe9e3")
		var bot := Color("fbeedd")
		for i in range(24):
			var y0 := H * 0.75 * i / 24.0
			draw_rect(Rect2(0, y0, W, H * 0.75 / 24.0 + 2), top.lerp(bot, i / 24.0))
		# Awan
		for i in range(5):
			var cx := fposmod(i * 420.0 + off * 0.15, W + 400) - 200
			var cy := 420.0 + (i % 3) * 140
			for k in range(3):
				draw_circle(Vector2(cx + k * 70, cy - (k % 2) * 30), 70, Color(1, 1, 1, 0.85))
		var ground := 2050.0
		if kota:
			_row(off * 0.4, 0.7, ground - 150, [Color("c8b9a6"), Color("b9c7cf"), Color("d4c3b0")], 380, 2000, false)
			_row(off, 1.0, ground, [Color("e8cfae"), Color("f2dcc0"), Color("d9b896"), Color("cfe0d6")], 360, 1350, true)
		else:
			_trees(off * 0.4, 1.1, ground - 150, Color("9cc49a"))
			_trees(off, 1.8, ground, Color("7fb07a"))
		# Trotoar
		draw_rect(Rect2(0, ground, W, 260), Color("d9d6cf") if kota else Color("e6d9b8"))
		var x := fposmod(off, 220.0) - 220
		while x < W:
			draw_line(Vector2(x, ground), Vector2(x - 60, ground + 260), Color("bdb9b0"), 4)
			x += 220
		draw_line(Vector2(0, ground), Vector2(W, ground), INK, 6)
		draw_rect(Rect2(0, ground + 260, W, H - ground - 260), Color("8e8a85") if kota else Color("a9c98f"))
		_draw_traffic(off, ground + 110.0, 60.0)
		# Maryam
		var tex: Texture2D = _frames[int(t * 6.0) % 2]
		var s := 1.4
		var sz := tex.get_size() * s
		var bob := -absf(sin(t * 12.0)) * 8.0
		var r := Rect2(W / 2.0 - sz.x / 2.0, ground + 170 - sz.y + bob, sz.x, sz.y)
		draw_texture_rect(tex, r, false)
		# Papan keterangan
		if font:
			var txt := "%s  →  %s" % [from, dest] if dir > 0 else "%s  ←  %s" % [dest, from]
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
			var pr := Rect2(W / 2.0 - tw / 2.0 - 40, 300, tw + 80, 100)
			draw_rect(pr, Color("fbf3e6"))
			draw_rect(pr, INK, false, 6)
			draw_string(font, pr.position + Vector2(40, 68), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, INK)
			var hint := "Geser untuk lewati"
			draw_string(font, Vector2(W / 2.0 - 160, 2350), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(INK, 0.7))
		# Progres
		draw_rect(Rect2(200, 2420, W - 400, 18), Color(1, 1, 1, 0.6))
		draw_rect(Rect2(200, 2420, (W - 400) * clampf(t / dur, 0, 1), 18), Color("e98b7a"))

	## Jalan kota bergambar (dari ilustrasi), disambung bergantian dengan cerminannya agar mulus.
	## Taman: satu gambar utuh (tanpa cermin) diperbesar, digeser pelan sekali lintas.
	## Langit transparan: awan & burung digambar di belakang pepohonan.
	const PARK_S := 1.35
	func _draw_park() -> void:
		var W := float(D.IW)
		var H := float(D.IH)
		var tw := _city.get_width() * PARK_S
		var th := _city.get_height() * PARK_S
		var top := 2080.0 - 2150.0 * PARK_S   # kaki Maryam di trotoar (garis ubin kuning)
		var k := clampf(t / dur, 0.0, 1.0)
		# jalan ke kiri → pemandangan bergeser ke kanan
		var x := lerpf(W - tw, 0.0, k) if dir < 0 else lerpf(0.0, W - tw, k)
		var off := x * 3.0
		var c0 := Color8(157, 222, 226)
		var c1 := Color8(205, 236, 232)
		for i in range(16):
			draw_rect(Rect2(0, H * 0.45 * i / 16.0, W, H * 0.45 / 16.0 + 2), c0.lerp(c1, i / 15.0))
		_draw_sky_life(off)
		draw_texture_rect(_city, Rect2(x, top, tw, th), false)
		if top + th < H: draw_rect(Rect2(0, top + th - 1, W, H - top - th + 1), Color8(82, 85, 90))
		_draw_traffic(x, 2565.0, 60.0)
		_draw_leaves(x)
		var tex: Texture2D = _frames[int(t * 6.0) % 2]
		var sz := tex.get_size() * 1.4
		var bob := -absf(sin(t * 12.0)) * 8.0
		draw_texture_rect(tex, Rect2(W / 2.0 - sz.x / 2.0, 2080.0 - sz.y + bob, sz.x, sz.y), false)
		_label_draw()

	func _draw_city(off: float) -> void:
		var W := float(D.IW)
		var kota := theme == "kota"
		if not kota:
			_draw_park()
			return
		var sc := 1.25 if kota else 1.0
		var tw := _city.get_width() * sc
		var th := _city.get_height() * sc
		var top := (2320.0 - th) if kota else 0.0
		draw_rect(Rect2(0, 0, W, top + 4), _sky)
		var start := floori(-off / tw) - 1
		for i in range(start, start + int(W / tw) + 3):
			var x := i * tw + off
			draw_texture_rect(_city if posmod(i, 2) == 0 else _city_f, Rect2(x, top, tw, th), false)
		if kota:
			draw_rect(Rect2(0, 2320, W, D.IH - 2320), Color("d9d6cf"))
			_draw_traffic(off, top + 1300.0 * sc, 70.0)
		else:
			_draw_sky_life(off)
			_draw_traffic(off, 2150.0, 55.0)
		var tex: Texture2D = _frames[int(t * 6.0) % 2]
		var s := 1.4
		var sz := tex.get_size() * s
		var bob := -absf(sin(t * 12.0)) * 8.0
		var feet := (top + (1940.0 - 470.0) * sc) if kota else 2350.0
		draw_texture_rect(tex, Rect2(W / 2.0 - sz.x / 2.0, feet - sz.y + bob, sz.x, sz.y), false)
		_label_draw()
		if not kota: _draw_leaves(off)

	# ---- Taman: awan berarak, burung terbang, daun berguguran ----
	var _clouds: Array = []
	var _leaves: Array = []
	const LEAF_COLS := [Color("7fae5a"), Color("9cc46a"), Color("6a9a4c"), Color("b7cf6e")]

	func _init_park() -> void:
		var pos := [Vector2(100, 250), Vector2(515, 120), Vector2(1020, 300), Vector2(1500, 190)]
		for i in range(4):
			_clouds.append({"tex": load("res://assets/side/cloud%d.png" % (i % 3)), "x": pos[i].x, "y": pos[i].y, "v": randf_range(10, 22), "s": randf_range(0.85, 1.1)})
		for i in range(16):
			_leaves.append(_new_leaf(true))

	func _new_leaf(anywhere: bool) -> Dictionary:
		return {"x": randf_range(-100, D.IW + 200), "y": randf_range(250, 2000) if anywhere else randf_range(250, 800),
			"vx": randf_range(-70, -30), "vy": randf_range(40, 90), "r": randf() * TAU, "vr": randf_range(-2.5, 2.5),
			"ph": randf() * TAU, "sz": randf_range(20, 34), "c": LEAF_COLS.pick_random()}

	func _draw_sky_life(off: float) -> void:
		var W := float(D.IW)
		for c in _clouds:
			var tex: Texture2D = c.tex
			var sz: Vector2 = tex.get_size() * float(c.s)
			var x := fposmod(float(c.x) + float(c.v) * t + off * 0.06, W + sz.x + 200) - sz.x - 100
			draw_texture_rect(tex, Rect2(x, float(c.y), sz.x, sz.y), false)
		# Kawanan burung: sayap mengepak (huruf V yang naik-turun)
		for f in range(2):
			var fx := fposmod(t * (90.0 + f * 30.0) + f * 900.0 + off * 0.1, W + 600) - 300
			var fy := 260.0 + f * 110.0 + sin(t * 0.8 + f) * 25.0
			for b in range(4):
				var p := Vector2(fx - b * 55 - (b % 2) * 20, fy + absf(b - 1.5) * 26)
				var flap := sin(t * 9.0 + b * 1.3 + f) * 10.0
				var w := 18.0
				var col := Color("6f7d99")
				draw_polyline(PackedVector2Array([p + Vector2(-w, -flap), p + Vector2(-w * 0.45, -flap * 0.3 + 3), p, p + Vector2(w * 0.45, -flap * 0.3 + 3), p + Vector2(w, -flap)]), col, 4.0, true)

	func _draw_leaves(off: float) -> void:
		var dt := get_process_delta_time()
		var mv := 120.0 * float(-dir) * dt   # ikut bergeser bersama pemandangan
		for i in range(_leaves.size()):
			var l: Dictionary = _leaves[i]
			l.x = float(l.x) + (float(l.vx) + sin(t * 2.0 + float(l.ph)) * 40.0) * dt + mv * 0.9
			l.y = float(l.y) + float(l.vy) * dt
			l.r = float(l.r) + float(l.vr) * dt
			if float(l.y) > 2250.0 or float(l.x) < -150.0 or float(l.x) > D.IW + 250.0:
				var n := _new_leaf(false)
				n.x = randf_range(150, D.IW + 150) if dir < 0 else randf_range(-150, D.IW - 150)
				_leaves[i] = n
				continue
			var c := Vector2(float(l.x), float(l.y))
			var sz := float(l.sz)
			var flip := cos(t * 3.0 + float(l.ph))   # daun berputar seperti melayang
			var ax := Vector2(cos(float(l.r)), sin(float(l.r))) * sz
			var ay := Vector2(-sin(float(l.r)), cos(float(l.r))) * sz * 0.45 * flip
			var pts := PackedVector2Array([c - ax, c - ax * 0.3 + ay, c + ax, c - ax * 0.3 - ay])
			draw_colored_polygon(pts, l.c)
			draw_polyline(PackedVector2Array([c - ax, c - ax * 0.3 + ay, c + ax, c - ax * 0.3 - ay, c - ax]), Color("4a5d32"), 2.5, true)
			draw_line(c - ax * 0.8, c + ax * 0.8, Color("4a5d32", 0.7), 1.5)

	func _draw_traffic(off: float, base_y: float, lane_gap: float) -> void:
		var W := float(D.IW)
		var span := W + 4200.0
		# jalur jauh (ke kiri) dulu, lalu jalur dekat (ke kanan)
		for lane in [1, 0]:
			for v in _veh:
				if int(v[5]) != lane: continue
				var tex: Texture2D = v[0] if float(v[3]) > 0 else v[1]
				var sz: Vector2 = tex.get_size() * float(v[4])
				var x := fposmod(float(v[2]) + float(v[3]) * t + off, span) - 2100.0
				var y: float = base_y - float(lane) * lane_gap - sz.y
				draw_texture_rect(tex, Rect2(x, y, sz.x, sz.y), false)

	func _label_draw() -> void:
		var W := float(D.IW)
		if font:
			var txt := "%s  →  %s" % [from, dest] if dir > 0 else "%s  ←  %s" % [dest, from]
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
			var pr := Rect2(W / 2.0 - tw / 2.0 - 40, 300, tw + 80, 100)
			draw_rect(pr, Color("fbf3e6"))
			draw_rect(pr, INK, false, 6)
			draw_string(font, pr.position + Vector2(40, 68), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, INK)
			draw_string(font, Vector2(W / 2.0 - 160, 2400), "Geser untuk lewati", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, (Color(1, 1, 1, 0.85) if theme != "kota" else Color(INK, 0.7)))
		draw_rect(Rect2(200, 2460, W - 400, 18), Color(1, 1, 1, 0.6))
		draw_rect(Rect2(200, 2460, (W - 400) * clampf(t / dur, 0, 1), 18), Color("e98b7a"))

	func _row(off: float, sc: float, base: float, cols: Array, wmin: float, hmax: float, shops: bool) -> void:
		var unit := 460.0 * sc
		var start: float = floor(-off / unit) - 1
		for i in range(int(start), int(start) + int(D.IW / unit) + 3):
			var rng := RandomNumberGenerator.new()
			rng.seed = i * 7919 + int(sc * 10)
			var w := rng.randf_range(wmin, unit - 30) * (1.0 if shops else 0.9)
			var h := rng.randf_range(hmax * 0.55, hmax) * sc
			var x := i * unit + off
			var c: Color = cols[absi(i) % cols.size()]
			var r := Rect2(x, base - h, w, h)
			draw_rect(r, c)
			draw_rect(r, INK, false, 5 * sc)
			# jendela
			var wy := r.position.y + 50 * sc
			while wy < base - (260 if shops else 80) * sc:
				var wx := r.position.x + 40 * sc
				while wx < r.end.x - 90 * sc:
					draw_rect(Rect2(wx, wy, 60 * sc, 70 * sc), Color("cfe3ee"))
					draw_rect(Rect2(wx, wy, 60 * sc, 70 * sc), INK, false, 3 * sc)
					wx += 110 * sc
				wy += 130 * sc
			if shops:
				# kanopi bergaris & pintu toko
				var aw := Rect2(r.position.x - 10, base - 260, w + 20, 60)
				var stripe := Color("e98b7a") if absi(i) % 2 == 0 else Color("8fb3c9")
				var k := 0.0
				while k < aw.size.x:
					draw_rect(Rect2(aw.position.x + k, aw.position.y, minf(40, aw.size.x - k), aw.size.y), stripe if int(k / 40) % 2 == 0 else Color("fbf3e6"))
					k += 40
				draw_rect(aw, INK, false, 4)
				draw_rect(Rect2(r.position.x + w * 0.35, base - 180, w * 0.3, 180), Color("a8774f"))
				draw_rect(Rect2(r.position.x + w * 0.35, base - 180, w * 0.3, 180), INK, false, 4)

	func _trees(off: float, sc: float, base: float, col: Color) -> void:
		var unit := 300.0 * sc
		var start: float = floor(-off / unit) - 1
		for i in range(int(start), int(start) + int(D.IW / unit) + 3):
			var rng := RandomNumberGenerator.new()
			rng.seed = i * 104729 + int(sc * 10)
			var x := i * unit + off + rng.randf_range(-40, 40)
			var h := rng.randf_range(260, 420) * sc
			draw_rect(Rect2(x - 14 * sc, base - h * 0.45, 28 * sc, h * 0.45), Color("8a6142"))
			for k in range(3):
				draw_circle(Vector2(x + (k - 1) * 55 * sc, base - h * 0.55 - (k % 2) * 60 * sc), 95 * sc, col.darkened(0.08 * k))
			draw_circle(Vector2(x, base - h * 0.75), 90 * sc, col.lightened(0.08))
			if sc >= 1.5 and absi(i) % 3 == 0:
				# bangku taman
				draw_rect(Rect2(x + 90, base - 70, 160, 20), Color("b0784c"))
				draw_rect(Rect2(x + 100, base - 50, 12, 50), INK)
				draw_rect(Rect2(x + 226, base - 50, 12, 50), INK)
			if absi(i) % 2 == 0:
				for f in range(4):
					draw_circle(Vector2(x - 60 + f * 30, base - 10), 10, [Color("f4a7b9"), Color("f7d36e"), Color("c9b6ea")][f % 3])


## Bola padel: dipukul lawan ke arah Maryam; geser ke atas saat bola di zona pukul.
class _Ball extends Node2D:
	signal missed
	signal foe_missed
	signal hit_ok
	var skill := 0.6
	var state := "idle"     # idle / in / out
	var t := 0.0
	var dur := 1.2
	var a := Vector2(800, 1000)
	var b := Vector2(900, 1720)
	var player: TextureRect
	var show_guide := false
	var _wait := 0.0
	var _swing_t := 0.0
	var _clock := 0.0

	func serve(delay: float) -> void:
		state = "idle"
		_wait = delay

	func in_zone() -> bool:
		return state == "in" and t >= dur * 0.72 and t <= dur + 0.2

	func _process(dt: float) -> void:
		_clock += dt
		_swing_t = maxf(0.0, _swing_t - dt)
		if state == "idle":
			if _wait > 0.0:
				_wait -= dt
				if _wait <= 0.0:
					_incoming()
			queue_redraw()
			return
		t += dt
		if state == "in" and t > dur + 0.2:
			state = "idle"
			missed.emit()
		elif state == "out" and t >= dur:
			if randf() < skill:
				_incoming()
			else:
				state = "idle"
				foe_missed.emit()
		queue_redraw()

	func _incoming() -> void:
		state = "in"
		t = 0.0
		dur = randf_range(1.25, 1.55) - skill * 0.3
		a = Vector2(randf_range(640, 980), 1010)
		var px := player.position.x + player.size.x * 0.8 if player else 980.0
		b = Vector2(px + randf_range(-30, 40), 1730)

	func swing() -> void:
		_swing_t = 0.28
		if in_zone():
			state = "out"
			t = 0.0
			dur = 1.0
			a = _pos()
			b = Vector2(randf_range(600, 1000), 1000)
			hit_ok.emit()

	func _pos() -> Vector2:
		var k := clampf(t / dur, 0.0, 1.0)
		var p := a.lerp(b, k)
		p.y -= sin(k * PI) * 240.0
		return p

	func _draw() -> void:
		# Raket Maryam
		if player and false:
			var hand := player.position + Vector2(player.size.x * 0.82, player.size.y * 0.5)
			var ang := -0.5 - (sin((0.28 - _swing_t) / 0.28 * PI) * 1.6 if _swing_t > 0 else 0.0)
			var dir := Vector2(cos(ang), sin(ang))
			var head := hand + dir * 120.0
			draw_line(hand, hand + dir * 55.0, Color("2e2a2a"), 14)
			draw_set_transform(head, ang + PI / 2.0, Vector2.ONE)
			draw_circle(Vector2.ZERO, 58, Color("4f6378"))
			draw_arc(Vector2.ZERO, 58, 0, TAU, 28, Color("2e2a2a"), 6)
			for i in range(-2, 3):
				for j in range(-2, 3):
					if i * i + j * j <= 5: draw_circle(Vector2(i * 18, j * 18), 4, Color("2e3a48"))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		if state == "idle": return
		var k := clampf(t / dur, 0.0, 1.0)
		var near := k if state == "in" else 1.0 - k
		var r := lerpf(12.0, 30.0, near)
		var p := _pos()
		var ground := a.lerp(b, k)
		draw_circle(ground + Vector2(0, 8), r * 0.9, Color(0, 0, 0, 0.18))
		if in_zone():
			draw_arc(b, 80, 0, TAU, 36, Color(1, 1, 1, 0.85), 8)
			draw_arc(b, 80 + fmod(_clock * 120.0, 30.0), 0, TAU, 36, Color(1, 1, 1, 0.35), 4)
			if show_guide:
				# Tangan & panah petunjuk: geser ke atas
				var hp := b + Vector2(130, 140 - fmod(_clock * 220.0, 120.0))
				draw_line(b + Vector2(130, 160), b + Vector2(130, 10), Color(1, 1, 1, 0.8), 10)
				draw_colored_polygon(PackedVector2Array([b + Vector2(105, 20), b + Vector2(155, 20), b + Vector2(130, -20)]), Color(1, 1, 1, 0.85))
				draw_circle(hp, 26, Color("fbe9d8"))
				draw_arc(hp, 26, 0, TAU, 20, Color("6b4f3a"), 4)
		draw_circle(p, r, Color("e6e85a"))
		draw_arc(p, r, 0, TAU, 20, Color("6b6a20"), 3)

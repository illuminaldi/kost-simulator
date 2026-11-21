class_name D
extends RefCounted
## Semua data statis game: koordinat ilustrasi, kamar, pekerjaan, karyawan, fasilitas.

const IW := 1438
const IH := 2576

# Kolom & baris kamar pada ilustrasi (piksel gambar asli).
const COLS := {"L": Vector2(131, 551), "M": Vector2(576, 970), "R": Vector2(996, 1405)}
# Data lantai dibuat otomatis (tanpa batas). Lantai 1-4 dari ilustrasi, 5+ salinan lantai 3/4.
static var TOP_FLOOR := 8
static var ROWS := {}
static var FEET := {}
static var ROOMS: Array = []
static var EDGES: Array = []
static var SPOT := {}
static var LAMPS := {}
static var FLOOR_LV := {}
static var BUILDING_TOP := -1568


static func setup_floors(top: int) -> void:
	TOP_FLOOR = maxi(8, top)
	ROWS = {4: Vector2(266, 626), 3: Vector2(651, 1018), 2: Vector2(1043, 1410), 1: Vector2(1436, 1800)}
	FEET = {4: 600.0, 3: 1000.0, 2: 1392.0, 1: 1778.0}
	SPOT = BASE_SPOT.duplicate(true)
	LAMPS = BASE_LAMPS.duplicate(true)
	for f in range(5, TOP_FLOOR + 1):
		var y0 := 266.0 - (f - 4) * EXTRA_PITCH
		ROWS[f] = Vector2(y0, y0 + 367)
		FEET[f] = y0 + 349
		SPOT["%dL" % f] = {"seat": Vector2(330, y0 + 337)}
		SPOT["%dR" % f] = {"seat": Vector2(1170, y0 + 341), "bed": Vector2(1215, y0 + 287)}
		LAMPS["%dL" % f] = BASE_LAMPS["3L"]
		LAMPS["%dR" % f] = BASE_LAMPS["3R"]
	ROOMS = []
	for f in range(TOP_FLOOR, 0, -1):
		if is_hub(f): continue   # lantai Lobi Langit: satu lantai penuh, tanpa kamar
		ROOMS.append("%dL" % f)
		ROOMS.append("%dR" % f)
	EDGES = [["lobby", "S1"]]
	for f in range(1, TOP_FLOOR + 1):
		if f < TOP_FLOOR: EDGES.append(["S%d" % f, "S%d" % (f + 1)])
		if is_hub(f): continue   # lantai lobi: tangga tetap tersambung, tanpa kamar
		EDGES.append(["S%d" % f, "%dL" % f])
		EDGES.append(["S%d" % f, "%dR" % f])
	FLOOR_LV = {}
	for f in range(1, TOP_FLOOR + 1): FLOOR_LV[f] = f
	BUILDING_TOP = -(TOP_FLOOR - 4) * EXTRA_PITCH


## Lantai dari id kamar/scene ("12L" -> 12, "S12" -> 12).
static func fl(id: String) -> int:
	return int(id.substr(1)) if id.begins_with("S") else int(id.left(id.length() - 1))


static func col(id: String) -> String:
	return "S" if id.begins_with("S") else id.right(1)


## Biaya bangun lantai f (lantai 9 ke atas): naik linear 3%/lantai, sejalan dengan kenaikan sewa per lantai.
static func floor_cost(f: int) -> float:
	return roundf(30000000.0 * (1.0 + 0.03 * (f - 9)) / 500000.0) * 500000.0


static func floor_rep(f: int) -> float:
	return minf(4.0 + 0.05 * (f - 9), 4.6)


## Warna penanda tiap 5 lantai (lantai 5+).
static func floor_tint(f: int) -> Color:
	var band := (f - 1) / 5
	return [Color(1, 1, 1), Color(1, 1, 1), Color(1.0, 0.95, 0.9), Color(0.93, 0.98, 0.94), Color(0.95, 0.95, 1.02), Color(1.02, 0.94, 0.96), Color(1.0, 1.0, 0.9)][band % 7]


const CX := {"L": 341.0, "M": 773.0, "R": 1200.0}
const LOBBY_Y := 2335.0
const LOBBY_X := 700.0
const OUT_X := -90.0
const QUEUE_X := [600.0, 740.0, 880.0, 1030.0]

# Titik aktivitas di tiap kamar (posisi kaki / alas sprite).
const BASE_SPOT := {
	"4L": {"seat": Vector2(300, 582), "bed": Vector2(345, 538)},
	"4M": {"seat": Vector2(790, 578), "bed": Vector2(795, 529)},
	"4R": {"seat": Vector2(1150, 586), "bed": Vector2(1232, 522)},
	"3L": {"seat": Vector2(330, 988)},
	"3R": {"seat": Vector2(1170, 992), "bed": Vector2(1215, 938)},
	"2L": {"seat": Vector2(290, 1390), "bed": Vector2(335, 1338)},
	"2M": {"seat": Vector2(705, 1398), "desk": Vector2(705, 1398)},
	"2R": {"seat": Vector2(1150, 1395), "bed": Vector2(1235, 1325)},
	"1L": {"seat": Vector2(300, 1782), "bed": Vector2(330, 1708)},
	"1R": {"seat": Vector2(1160, 1782), "bed": Vector2(1300, 1700)},
	"5L": {"seat": Vector2(330, 211)},
	"5R": {"seat": Vector2(1170, 215), "bed": Vector2(1215, 161)},
	"6L": {"seat": Vector2(330, -181)},
	"6R": {"seat": Vector2(1170, -177), "bed": Vector2(1215, -231)},
	"7L": {"seat": Vector2(330, -573)},
	"7R": {"seat": Vector2(1170, -569), "bed": Vector2(1215, -623)},
	"8L": {"seat": Vector2(330, -965)},
	"8R": {"seat": Vector2(1170, -961), "bed": Vector2(1215, -1015)},
}

# Lampu di tiap kamar (relatif terhadap kotak kamar: x, y, radius).
const BASE_LAMPS := {
	"4L": [[0.09, 0.72, 85]], "4M": [[0.53, 0.24, 120]], "4R": [[0.60, 0.33, 75], [0.89, 0.70, 70]],
	"3L": [[0.35, 0.18, 85], [0.34, 0.38, 60], [0.10, 0.68, 60]], "3R": [[0.47, 0.17, 115]],
	"2L": [[0.33, 0.22, 95]], "2M": [[0.22, 0.33, 85]], "2R": [[0.93, 0.73, 60]],
	"1L": [[0.29, 0.25, 95]], "1R": [[0.62, 0.13, 75], [0.93, 0.78, 60]],
	"5L": [[0.35, 0.18, 85], [0.34, 0.38, 60], [0.10, 0.68, 60]],
	"5R": [[0.47, 0.17, 115]],
	"6L": [[0.35, 0.18, 85], [0.34, 0.38, 60], [0.10, 0.68, 60]],
	"6R": [[0.47, 0.17, 115]],
	"7L": [[0.35, 0.18, 85], [0.34, 0.38, 60], [0.10, 0.68, 60]],
	"7R": [[0.47, 0.17, 115]],
	"8L": [[0.35, 0.18, 85], [0.34, 0.38, 60], [0.10, 0.68, 60]],
	"8R": [[0.47, 0.17, 115]],
}
const STAIR_LAMPS := [[841, 716, 65], [910, 706, 60]]
const GROUND_LAMPS := [[673, 1912, 65], [780, 1915, 65], [837, 1905, 55], [1052, 1950, 65], [1122, 1915, 55],
	[1195, 1920, 55], [1268, 1990, 75], [168, 1968, 60], [280, 1965, 60], [358, 1968, 60]]

# Area HUD & tombol yang sudah tergambar di ilustrasi.
const PILL_MONEY := Rect2(31, 60, 465, 123)
const PILL_LV := Rect2(545, 60, 351, 123)
const PILL_CLOCK := Rect2(943, 43, 470, 154)
# Tombol navigasi bawah: besar (176 px) & berjarak 26 px supaya tidak salah pencet.
const NAV_Y := 2372.0
const NAV_H := 180.0
const NAV := [["upgrade", Rect2(20, 2372, 330, 180)], ["tenants", Rect2(376, 2372, 330, 180)],
	["staff", Rect2(732, 2372, 330, 180)], ["manage", Rect2(1088, 2372, 330, 180)]]
const GROUND_RECT := Rect2(380, 1860, 980, 512)
const CAT_RECT := Rect2(400, 2195, 155, 110)

# ---------- Perabot ----------
# Setiap kamar punya tempat perabotnya sendiri (diambil dari ilustrasi). Posisi = pojok kiri-atas sprite.
const FURN_POS := {
	"4L": {"lampu": Vector2(150, 490), "tanaman": Vector2(491, 384), "dekor": Vector2(147, 283), "kasur": Vector2(137, 399), "karpet": Vector2(245, 527)},
	"4M": {"kasur": Vector2(626, 420), "lampu": Vector2(748, 208), "tanaman": Vector2(650, 208), "karpet": Vector2(653, 527)},
	"4R": {"lampu": Vector2(1222, 354), "tanaman": Vector2(1038, 446), "rak": Vector2(1301, 301), "kasur": Vector2(1105, 421), "karpet": Vector2(1056, 544)},
	"3L": {"lampu": Vector2(155, 646), "tanaman": Vector2(474, 784), "rak": Vector2(137, 706), "kasur": Vector2(140, 815), "karpet": Vector2(260, 914)},
	"3R": {"kasur": Vector2(1105, 800), "lampu": Vector2(1118, 617), "tanaman": Vector2(1027, 771), "dekor": Vector2(1332, 691), "rak": Vector2(1314, 919), "karpet": Vector2(1066, 914)},
	"2L": {"lampu": Vector2(251, 1039), "dekor": Vector2(97, 1056), "rak": Vector2(462, 1105), "tanaman": Vector2(136, 1284), "kasur": Vector2(149, 1181), "karpet": Vector2(254, 1304)},
	"2M": {"kasur": Vector2(675, 1205), "tanaman": Vector2(583, 1215), "meja": Vector2(542, 1163), "dekor": Vector2(606, 1047)},
	"2R": {"dekor": Vector2(1233, 1089), "rak": Vector2(1301, 1093), "lampu": Vector2(1346, 1276), "kasur": Vector2(1129, 1214), "karpet": Vector2(1036, 1292)},
	"1L": {"rak": Vector2(97, 1475), "lampu": Vector2(230, 1497), "tanaman": Vector2(136, 1675), "kasur": Vector2(147, 1584), "karpet": Vector2(233, 1688)},
	"1R": {"lampu": Vector2(1245, 1430), "rak": Vector2(1322, 1475), "dekor": Vector2(1232, 1535), "tanaman": Vector2(1025, 1599), "kasur": Vector2(1134, 1572), "karpet": Vector2(1033, 1682)},
	"5L": {"lampu": Vector2(155, -131), "tanaman": Vector2(474, 7), "rak": Vector2(137, -71), "kasur": Vector2(140, 38), "karpet": Vector2(260, 137)},
	"5R": {"kasur": Vector2(1105, 23), "lampu": Vector2(1118, -160), "tanaman": Vector2(1027, -6), "dekor": Vector2(1332, -86), "rak": Vector2(1314, 142), "karpet": Vector2(1066, 137)},
	"6L": {"lampu": Vector2(155, -523), "tanaman": Vector2(474, -385), "rak": Vector2(137, -463), "kasur": Vector2(140, -354), "karpet": Vector2(260, -255)},
	"6R": {"kasur": Vector2(1105, -369), "lampu": Vector2(1118, -552), "tanaman": Vector2(1027, -398), "dekor": Vector2(1332, -478), "rak": Vector2(1314, -250), "karpet": Vector2(1066, -255)},
	"7L": {"lampu": Vector2(155, -915), "tanaman": Vector2(474, -777), "rak": Vector2(137, -855), "kasur": Vector2(140, -746), "karpet": Vector2(260, -647)},
	"7R": {"kasur": Vector2(1105, -761), "lampu": Vector2(1118, -944), "tanaman": Vector2(1027, -790), "dekor": Vector2(1332, -870), "rak": Vector2(1314, -642), "karpet": Vector2(1066, -647)},
	"8L": {"lampu": Vector2(155, -1307), "tanaman": Vector2(474, -1169), "rak": Vector2(137, -1247), "kasur": Vector2(140, -1138), "karpet": Vector2(260, -1039)},
	"8R": {"kasur": Vector2(1105, -1153), "lampu": Vector2(1118, -1336), "tanaman": Vector2(1027, -1182), "dekor": Vector2(1332, -1262), "rak": Vector2(1314, -1034), "karpet": Vector2(1066, -1039)},
}
# Posisi versi mewah (level 2-3) dari sheet perabot kedua.
const FURN_POS2 := {
	"4L": {"lampu": Vector2(150, 490), "tanaman": Vector2(491, 383), "dekor": Vector2(146, 283), "kasur": Vector2(136, 402), "karpet": Vector2(245, 526)},
	"4M": {"kasur": Vector2(626, 420), "lampu": Vector2(748, 208), "tanaman": Vector2(650, 208), "karpet": Vector2(653, 451)},
	"4R": {"lampu": Vector2(1222, 353), "tanaman": Vector2(1038, 445), "rak": Vector2(1301, 300), "kasur": Vector2(1105, 421), "karpet": Vector2(1056, 544)},
	"3L": {"lampu": Vector2(154, 646), "tanaman": Vector2(474, 784), "rak": Vector2(97, 705), "kasur": Vector2(139, 815), "karpet": Vector2(260, 912)},
	"3R": {"kasur": Vector2(1105, 800), "lampu": Vector2(1117, 617), "tanaman": Vector2(1027, 770), "dekor": Vector2(1322, 690), "rak": Vector2(1314, 919), "karpet": Vector2(1066, 914)},
	"2L": {"lampu": Vector2(251, 1039), "dekor": Vector2(97, 1056), "rak": Vector2(457, 1097), "tanaman": Vector2(136, 1284), "kasur": Vector2(149, 1181), "karpet": Vector2(254, 1304)},
	"2M": {"kasur": Vector2(675, 1205), "tanaman": Vector2(584, 1214), "meja": Vector2(542, 1163), "dekor": Vector2(606, 1046)},
	"2R": {"dekor": Vector2(1122, 1087), "rak": Vector2(1301, 1091), "lampu": Vector2(1346, 1276), "kasur": Vector2(1129, 1214), "karpet": Vector2(1037, 1292)},
	"1L": {"rak": Vector2(97, 1474), "lampu": Vector2(230, 1496), "tanaman": Vector2(135, 1675), "kasur": Vector2(146, 1584), "karpet": Vector2(233, 1687)},
	"1R": {"lampu": Vector2(1245, 1428), "rak": Vector2(1322, 1474), "dekor": Vector2(1232, 1534), "tanaman": Vector2(1025, 1597), "kasur": Vector2(1134, 1572), "karpet": Vector2(1032, 1682)},
	"5L": {"lampu": Vector2(154, -131), "tanaman": Vector2(474, 7), "rak": Vector2(97, -72), "kasur": Vector2(139, 38), "karpet": Vector2(260, 135)},
	"5R": {"kasur": Vector2(1105, 23), "lampu": Vector2(1117, -160), "tanaman": Vector2(1027, -7), "dekor": Vector2(1322, -87), "rak": Vector2(1314, 142), "karpet": Vector2(1066, 137)},
	"6L": {"lampu": Vector2(154, -523), "tanaman": Vector2(474, -385), "rak": Vector2(97, -464), "kasur": Vector2(139, -354), "karpet": Vector2(260, -257)},
	"6R": {"kasur": Vector2(1105, -369), "lampu": Vector2(1117, -552), "tanaman": Vector2(1027, -399), "dekor": Vector2(1322, -479), "rak": Vector2(1314, -250), "karpet": Vector2(1066, -255)},
	"7L": {"lampu": Vector2(154, -915), "tanaman": Vector2(474, -777), "rak": Vector2(97, -856), "kasur": Vector2(139, -746), "karpet": Vector2(260, -649)},
	"7R": {"kasur": Vector2(1105, -761), "lampu": Vector2(1117, -944), "tanaman": Vector2(1027, -791), "dekor": Vector2(1322, -871), "rak": Vector2(1314, -642), "karpet": Vector2(1066, -647)},
	"8L": {"lampu": Vector2(154, -1307), "tanaman": Vector2(474, -1169), "rak": Vector2(97, -1248), "kasur": Vector2(139, -1138), "karpet": Vector2(260, -1041)},
	"8R": {"kasur": Vector2(1105, -1153), "lampu": Vector2(1117, -1336), "tanaman": Vector2(1027, -1183), "dekor": Vector2(1322, -1263), "rak": Vector2(1314, -1034), "karpet": Vector2(1066, -1039)},
}
const FURN_TEX := {}
const FURN := {
	"kasur": {"n": "Kasur", "cost": 600000, "c": 3.0, "min": 1, "icon": "4L_kasur", "d": "Wajib ada supaya kamar bisa disewa."},
	"lampu": {"n": "Lampu", "cost": 100000, "c": 1.0, "min": 1, "icon": "4R_lampu", "d": "Kamar terang & hangat di malam hari."},
	"tanaman": {"n": "Tanaman", "cost": 60000, "c": 1.0, "min": 1, "icon": "4L_tanaman", "d": "Bikin kamar terasa segar."},
	"karpet": {"n": "Karpet", "cost": 150000, "c": 1.0, "min": 1, "icon": "2L_karpet", "d": "Lantai lebih nyaman."},
	"dekor": {"n": "Hiasan Dinding", "cost": 100000, "c": 1.0, "min": 2, "icon": "4L_dekor", "d": "Lukisan, poster, atau jemuran."},
	"rak": {"n": "Rak Buku", "cost": 250000, "c": 2.0, "min": 2, "icon": "2L_rak", "d": "Tempat menyimpan buku & barang."},
	"kipas": {"n": "Kipas Angin", "cost": 250000, "c": 2.0, "min": 2, "icon": "", "d": "Kamar sejuk. Naik level jadi AC, lalu AC Inverter.", "lv_names": ["", "Kipas Angin", "AC", "AC Inverter"], "lv_cost": [250000, 1500000, 2500000]},
	"meja": {"n": "Meja Kerja", "cost": 350000, "c": 2.0, "min": 3, "icon": "2M_meja", "d": "Disukai freelancer & mahasiswa."},
}
# ---------- Ruang fasilitas di samping tangga ----------
# happy: +kebahagiaan harian semua penghuni; inc: pemasukan per penghuni per hari; flat: pemasukan tetap/hari dari pengunjung luar
# (keduanya butuh karyawan kalau ada "staff").
# visit: jam-jam penghuni mampir.
const FACIL := {
	"tunggu": {"n": "Ruang Tunggu", "lv": 1, "cost": 1000000, "happy": 0, "inc": 0, "flat": 0, "visit": [], "pose": "stand",
		"d": "Waiting list: Penjaga Kost mengarahkan hingga 3 tamu menunggu di sini. Calon penyewa lebih sabar & lebih sering datang."},
	"laundry": {"n": "Laundry", "lv": 2, "cost": 2000000, "happy": 1, "inc": 5000, "flat": 30000, "staff": "laundry", "visit": [9, 19], "pose": "stand",
		"d": "Kamar lebih lambat kotor. Jasa cuci menambah pemasukan (2x dengan Petugas Laundry)."},
	"mushola": {"n": "Mushola", "lv": 3, "cost": 2000000, "happy": 2, "inc": 0, "flat": 0, "visit": [5, 12, 15, 18], "pose": "stand",
		"d": "Tempat ibadah yang tenang. Penghuni lebih betah & rating naik pelan."},
	"dapur": {"n": "Dapur Bersama", "lv": 3, "cost": 2000000, "happy": 2, "inc": 0, "flat": 0, "visit": [7, 19], "pose": "stand",
		"d": "Penghuni bisa masak sendiri. Masalah area kotor lebih jarang."},
	"kantin": {"n": "Kantin", "lv": 4, "cost": 2500000, "happy": 2, "inc": 6000, "flat": 50000, "staff": "kantin", "visit": [12, 18], "pose": "stand",
		"d": "Makan murah tanpa keluar kost. Pemasukan harian kalau ada Ibu Kantin."},
	"cafe": {"n": "Cafe", "lv": 5, "cost": 12000000, "happy": 2, "inc": 8000, "flat": 120000, "staff": "barista", "visit": [15, 20], "pose": "stand",
		"d": "Tempat nongkrong & kerja. Harga sewa +5%; pemasukan harian kalau ada Barista."},
	"gym": {"n": "Gym", "lv": 6, "cost": 10000000, "happy": 3, "inc": 6000, "flat": 100000, "staff": "trainer", "visit": [6, 17], "pose": "stand",
		"d": "Penghuni olahraga pagi & sore. Kebahagiaan naik; pemasukan kelas latihan kalau ada Personal Trainer."},
	"lift": {"n": "Lift", "lv": 6, "cost": 25000000, "happy": 0, "inc": 0, "visit": [], "pose": "stand",
		"d": "Penghuni lantai atas tidak perlu naik tangga panjang: tidak cepat capek & tetap betah."},
	"minimart": {"n": "Minimart", "lv": 7, "cost": 15000000, "happy": 2, "inc": 6000, "flat": 150000, "staff": "kasir", "visit": [10, 16, 21], "pose": "stand",
		"d": "Belanja kebutuhan harian tanpa keluar kost. Pemasukan harian kalau ada Kasir."},
	"hidroponik": {"n": "Kebun Hidroponik", "lv": 4, "cost": 1500000, "happy": 2, "inc": 4000, "flat": 40000, "staff": "tani", "visit": [7, 17], "pose": "stand",
		"d": "Sayur segar dari pipa hidroponik. Penghuni lebih sehat & betah; panen dijual kalau ada Petani."},
	"lele": {"n": "Kolam Lele", "lv": 5, "cost": 1500000, "happy": 1, "inc": 2000, "flat": 70000, "staff": "lele", "visit": [8, 16], "pose": "stand",
		"d": "Budidaya lele di kolam terpal. Panen rutin jadi pemasukan kalau ada Peternak Lele."},
	"petshop": {"n": "Pet Shop", "lv": 6, "cost": 5000000, "happy": 2, "inc": 4000, "flat": 70000, "staff": "petshop", "visit": [10, 17], "pose": "stand",
		"d": "Pakan & perlengkapan hewan. Penghuni pecinta kucing makin betah; pemasukan harian kalau ada Penjaga Pet Shop."},
	"bunga": {"n": "Toko Bunga", "lv": 6, "cost": 3000000, "happy": 2, "inc": 3000, "flat": 70000, "staff": "florist", "visit": [9, 18], "pose": "stand",
		"d": "Buket & tanaman hias. Kost terasa wangi dan cantik; pemasukan harian kalau ada Florist."},
	"koperasi": {"n": "Koperasi", "lv": 7, "cost": 3000000, "happy": 3, "inc": 5000, "flat": 50000, "staff": "koperasi", "visit": [10, 19], "pose": "stand",
		"d": "Simpan pinjam & sembako murah untuk penghuni. Penghuni jarang telat bayar; pemasukan kalau ada Pengurus Koperasi."},
	"warteg": {"n": "Warteg", "lv": 5, "cost": 4000000, "happy": 2, "inc": 8000, "flat": 90000, "staff": "warteg", "visit": [7, 12, 19], "pose": "stand",
		"d": "Nasi + lauk murah meriah sepanjang hari. Pemasukan harian besar kalau ada Ibu Warteg."},
	"rooftop_old": {"n": "Taman Rooftop", "lv": 99, "cost": 3500000, "happy": 3, "inc": 0, "visit": [], "pose": "stand",
		"d": "Taman hijau untuk santai sore. Rating kost naik setiap hari."},
}
const FACIL_ORDER := ["tunggu", "laundry", "mushola", "dapur", "kantin", "hidroponik", "cafe", "lele", "warteg", "gym", "petshop", "bunga", "minimart", "koperasi"]


## Sisi kosong ruang tangga (lantai ganjil: kanan, genap: kiri).
static func facil_rect(f: int) -> Rect2:
	var r := rect_of("%dS" % f)
	var half := r.size.x / 2.0
	return Rect2(r.position.x + (half if f % 2 == 1 else 0.0), r.position.y, half, r.size.y)


# Area aman untuk perabot fasilitas: tidak menutupi pintu (dekat x 580-600 & 930-970) & tangga.
const FACIL_W := 140.0
const FACIL_SVG_FLOOR := 0.78   # posisi alas perabot pada gambar (0..1)


## Tengah-tengah antara tangga dan tembok samping.
static func facil_center_x(f: int) -> float:
	return 850.0 if f % 2 == 1 else 712.0


const FACIL_BACK := 30.0       # digeser ke arah tembok belakang (lebih jauh dari kamera)


## Kotak gambar fasilitas (diperkecil & digeser menjauhi pintu), alas perabot tetap di lantai.
static func facil_draw_rect(f: int) -> Rect2:
	var r := rect_of("%dS" % f)
	var w := FACIL_W * 0.92
	var h := w * 367.0 / 200.0
	var floor_y := r.position.y + r.size.y * FACIL_SVG_FLOOR - FACIL_BACK
	return Rect2(facil_center_x(f) - w / 2.0, floor_y - h * FACIL_SVG_FLOOR, w, h)


static func facil_spot(f: int) -> Vector2:
	return Vector2(facil_center_x(f), FEET[f] - FACIL_BACK)


# ---------- Screening calon penyewa ----------
# via: pemeriksaan yang bisa mengungkap sifat ini. ev/ev_mul: pengaruh ke peluang masalah di kamarnya.
const TRAITS := {
	"bayar_seret": {"n": "Kemampuan bayar kurang", "bad": true, "via": "kerja", "p": 0.14, "ev": "telat_bayar", "ev_mul": 4.0,
		"d": "Penghasilan tidak sebanding harga sewa; sering telat bayar."},
	"ktp": {"n": "Identitas tidak lengkap", "bad": true, "via": "kerja", "p": 0.08,
		"d": "KTP/surat domisili tidak ada. Bisa ditegur Pak RT & kena denda."},
	"kabur": {"n": "Pernah kabur tanpa bayar", "bad": true, "via": "riwayat", "p": 0.07,
		"d": "Di kost lama pergi diam-diam tanpa melunasi sewa."},
	"perokok": {"n": "Merokok di dalam kamar", "bad": true, "via": "riwayat", "p": 0.12, "ev": "bau_rokok", "ev_mul": 5.0, "dirt": 1.2,
		"d": "Kamar cepat bau & kotor; tetangga terganggu."},
	"berisik": {"n": "Suka berisik malam-malam", "bad": true, "via": "riwayat", "p": 0.12, "ev": "berisik", "ev_mul": 5.0, "neigh": -2,
		"d": "Penghuni lain di lantai yang sama jadi kurang betah."},
	"tamu": {"n": "Sering bawa tamu menginap", "bad": true, "via": "riwayat", "p": 0.1, "ev": "tamu_inap", "ev_mul": 5.0,
		"d": "Melanggar aturan kost; tamu menginap tanpa izin."},
	"jorok": {"n": "Kurang menjaga kebersihan", "bad": true, "via": "wawancara", "p": 0.14, "dirt": 1.7,
		"d": "Kamar jauh lebih cepat kotor."},
	"hewan": {"n": "Bawa hewan peliharaan", "bad": true, "via": "wawancara", "p": 0.08, "dirt": 1.3,
		"d": "Kucing/anjing di kamar: bulu & bau, kamar lebih cepat kotor."},
	"sebentar": {"n": "Cuma mau tinggal sebentar", "bad": true, "via": "wawancara", "p": 0.1, "ev": "pindah_mendadak", "ev_mul": 5.0,
		"d": "Bisa tiba-tiba pindah sebelum masa sewa habis."},
	"tepat": {"n": "Selalu bayar tepat waktu", "bad": false, "via": "kerja", "p": 0.25, "ev": "telat_bayar", "ev_mul": 0.0,
		"d": "Penghasilan tetap & disiplin."},
	"rapi": {"n": "Rapi & bersih", "bad": false, "via": "wawancara", "p": 0.25, "dirt": 0.7,
		"d": "Kamar lebih lambat kotor."},
	"ramah": {"n": "Ramah ke tetangga", "bad": false, "via": "riwayat", "p": 0.2, "neigh": 1,
		"d": "Penghuni lain di lantai yang sama lebih betah."},
}
const CHECKS := {
	"wawancara": {"n": "Wawancara", "cost": 0, "lv": 1, "d": "Kebersihan, hewan peliharaan & rencana lama tinggal."},
	"kerja": {"n": "Cek KTP & slip gaji", "cost": 25000, "lv": 1, "d": "Kemampuan bayar & kelengkapan identitas."},
	"riwayat": {"n": "Hubungi kost lama", "cost": 50000, "lv": 2, "d": "Riwayat sewa, rokok, berisik & tamu menginap."},
}
const CHECK_ORDER := ["wawancara", "kerja", "riwayat"]


const FURN_ORDER := ["kasur", "lampu", "kipas", "tanaman", "karpet", "dekor", "rak"]
const FURN_MULT := [0.0, 1.0, 1.6, 2.3]


## Harga perabot t untuk naik dari level lv ke lv+1 (lv 0 = beli baru).
static func furn_cost(t: String, lv: int) -> float:
	var f: Dictionary = FURN[t]
	if f.has("lv_cost"): return float(f.lv_cost[clampi(lv, 0, 2)])
	return float(f.cost) * maxi(1, lv)
const FURN_LV_NAME := ["", "Biasa", "Bagus", "Mewah"]
const RLV := [{}, {"n": "Standar", "rent": 60000}, {"n": "Nyaman", "rent": 100000}, {"n": "Premium", "rent": 140000}]
const UPG := [0, 0, 3000000, 6000000]
const PRICE := [{"n": "Murah", "m": 0.8, "h": 3, "c": 0.8}, {"n": "Normal", "m": 1.0, "h": 0, "c": 1.0},
	{"n": "Mahal", "m": 1.3, "h": -4, "c": 1.35}]
const JOBS := {
	"Mahasiswa": {"away": [8, 15], "pref": 1, "min": 1},
	"Karyawan": {"away": [7, 17], "pref": 2, "min": 1},
	"Freelancer": {"away": [], "pref": 2, "min": 2},
	"Perawat": {"away": [14, 22], "pref": 2, "min": 2},
	"Manajer": {"away": [8, 18], "pref": 3, "min": 3},
	"Pensiunan": {"away": [6, 9], "pref": 2, "min": 1, "tua": true},
	"Pedagang Pasar": {"away": [4, 12], "pref": 1, "min": 1, "tua": true},
}
const CHAR_TUA := ["kakek", "nenek"]
const STAFF := {
	"cleaner": {"nama": "Mustofa", "n": "Petugas Kebersihan", "sal": 80000, "min": 1, "d": "Membersihkan kamar kotor; menangani sampah, area bersama kotor & hama."},
	"resep": {"nama": "Maryam", "n": "Pemilik & Penjaga Kost", "sal": 0, "min": 1, "owner": true, "d": "Cucu Nenek dan pewaris kost. Mantan eksekutif yang memilih pulang. Berjaga di meja depan: tamu lebih sabar, menagih sewa, urus kunci hilang & tegur penghuni berisik."},
	"teknisi": {"nama": "Boy", "n": "Teknisi", "sal": 110000, "min": 3, "d": "Memperbaiki kerusakan gratis; menangani air mati, WiFi lemot, listrik jeglek & atap bocor."},
	"laundry": {"nama": "Budi", "n": "Petugas Laundry", "sal": 75000, "min": 2, "need": "laundry", "d": "Mengurus mesin cuci. Pemasukan Laundry jadi 2x."},
	"kantin": {"nama": "Bu Sari", "n": "Ibu Kantin", "sal": 85000, "min": 4, "need": "kantin", "d": "Memasak di Kantin. Membuka pemasukan harian Kantin."},
	"barista": {"nama": "Nadia", "n": "Barista", "sal": 100000, "min": 5, "need": "cafe", "d": "Meracik kopi di Cafe. Membuka pemasukan harian Cafe."},
	"kasir": {"nama": "Sinta", "n": "Kasir Minimart", "sal": 90000, "min": 7, "need": "minimart", "d": "Menjaga kasir Minimart. Membuka pemasukan harian Minimart."},
	"trainer": {"nama": "Kak Ray", "n": "Personal Trainer", "sal": 120000, "min": 6, "need": "gym", "d": "Melatih penghuni di Gym. Membuka pemasukan kelas latihan & penghuni lebih bugar (kebahagiaan ekstra)."},
	"tani": {"nama": "Kang Dedi", "n": "Petani Hidroponik", "sal": 75000, "min": 4, "need": "hidroponik", "d": "Merawat & memanen sayur hidroponik. Membuka pemasukan Kebun Hidroponik."},
	"lele": {"nama": "Pak Darto", "n": "Peternak Lele", "sal": 80000, "min": 5, "need": "lele", "d": "Memberi pakan & memanen lele. Membuka pemasukan Kolam Lele."},
	"petshop": {"nama": "Mbak Lala", "n": "Penjaga Pet Shop", "sal": 85000, "min": 6, "need": "petshop", "d": "Melayani pembeli pakan & aksesoris hewan. Membuka pemasukan Pet Shop."},
	"florist": {"nama": "Mbak Rosa", "n": "Florist", "sal": 85000, "min": 6, "need": "bunga", "d": "Merangkai buket bunga. Membuka pemasukan Toko Bunga."},
	"koperasi": {"nama": "Bu Wati", "n": "Pengurus Koperasi", "sal": 95000, "min": 7, "need": "koperasi", "d": "Mengurus simpan pinjam & sembako. Membuka pemasukan Koperasi."},
	"warteg": {"nama": "Bu Tini", "n": "Ibu Warteg", "sal": 90000, "min": 5, "need": "warteg", "d": "Memasak & melayani di Warteg. Membuka pemasukan harian Warteg."},
	"satpam": {"nama": "John", "n": "Satpam", "sal": 110000, "min": 3, "d": "Patroli di depan kost. Mencegah pencurian; urus tamu menginap & paket hilang."},
}
const FAC := {
	"wifi": {"n": "WiFi Kencang", "cost": 800000, "min": 1, "d": ""},
	"cctv": {"n": "CCTV", "cost": 2500000, "min": 3, "d": "Peluang pencurian turun separuh."},
	"lift": {"n": "Lift Barang", "cost": 25000000, "min": 6, "d": "Lift barang di sisi gedung. Seret kotak perabot atau paper bag ke lift, otomatis diantar ke kamar tujuan. Penghuni lantai atas juga tidak cepat capek."},
}
# ---------- Aplikasi (langganan bulanan, ditagih per hari = bulanan/30 bersama gaji pukul 17:00) ----------
const APPS := {
	"kostterdekat": {"n": "KostTerdekat", "tag": "Aplikasi cari kost", "month": 178000, "fee": 178000.0 / 30.0, "lv": 2,
		"perks": ["Kost tampil di aplikasi: calon penyewa lebih sering datang & antrean bisa 2 orang",
			"Calon dari aplikasi sudah terverifikasi KTP & penghasilan (cek otomatis)",
			"Ulasan penghuni yang betah menaikkan rating lebih cepat"]},
	"kelolapro": {"n": "KelolaPro", "tag": "Aplikasi manajemen kost", "month": 99000, "fee": 99000.0 / 30.0, "lv": 3,
		"perks": ["Tagihan & pengingat bayar otomatis: telat bayar jauh berkurang",
			"Keluhan penghuni masuk lebih cepat: dampak masalah kost berkurang",
			"Data riwayat penyewa: cek \"Hubungi kost lama\" gratis"]},
}
const APP_ORDER := ["kostterdekat", "kelolapro"]
const ISSUES := {"AC rusak": 250000, "Keran bocor": 120000, "Lampu mati": 60000, "Kasur jebol": 300000, "Gosong tersambar petir": 900000}
const RANDOM_ISSUES := ["AC rusak", "Keran bocor", "Lampu mati", "Kasur jebol"]
# Karakter penghuni (folder di assets/chars) -> jenis kelamin untuk nama.
const CHARS := {"kutu": "l", "kakek": "l", "siswi": "p", "flanel": "p", "nenek": "p", "kupluk": "l"}
# Pekerja: pose -> file (Array = bergantian tiap 3.5 detik).
const WORKER := {
	"build": {"nama": "Pak Joko", "role": "Tukang", "char": "tukang", "map": {"walk": "walk", "stand": "hold", "job": ["repair", "repair", "carry"], "react": "hold"}, "mins": 240},
	"fix": {"nama": "Boy", "role": "Teknisi", "char": "teknisi", "map": {"walk": "walk", "stand": "idle", "job": ["idle", "fix", "fix"], "react": "happy"}, "mins": 90},
	"deliver": {"nama": "Bang Jali", "role": "Kurir", "char": "kurir", "map": {"walk": "carry", "stand": "idle", "job": "back", "react": "idle"}, "mins": 20},
}
## "Mustofa (Petugas Kebersihan)"
static func staff_label(k: String) -> String:
	return "%s (%s)" % [STAFF[k].nama, STAFF[k].n]


static func worker_label(t: String) -> String:
	return "%s (%s)" % [WORKER[t].nama, WORKER[t].role]


const TRUCK_X := 330.0
const NAMES_P := ["Sari", "Dewi", "Putri", "Nadia", "Intan", "Citra", "Laras", "Ayu", "Tiara", "Wulan", "Mega", "Rina",
	"Fitri", "Lina", "Salsa", "Anisa", "Dinda", "Maya",
	"Alexandra", "Ani", "Camelia", "Dara", "Diana", "Elora", "Isabella", "Jamilah", "Juminten", "Karmila", "Kirana",
	"Nina", "Nurlela", "Sephia", "Tatiana", "Widuri"]
const NAMES_L := ["Andi", "Budi", "Rizky", "Fajar", "Yoga", "Bayu", "Dimas", "Reza", "Gilang", "Hendra", "Arif", "Joko",
	"Eko", "Agus", "Bima", "Rafi", "Iqbal", "Dodi", "Arjuna", "Bento", "Jodi"]

# Palet karakter (diambil dari warna ilustrasi).
const SKINS := ["#f6d3b3", "#ecc29b", "#d6a378", "#b98058"]
const HAIRS := ["#3b2a20", "#1f1a17", "#6b4a2b", "#8a5a3b"]
const SHIRTS := ["#c9a14a", "#b5654a", "#7d9a6b", "#6f8fb0", "#d98c8c", "#9a7bb0", "#e0b24f", "#8fb3a8"]
const PANTS := ["#5d5a66", "#6b5a48", "#3f4a5a", "#8a7560", "#d8c9b0"]
const BLANKETS := ["#e6d3a3", "#cfd9e6", "#f0c9c0", "#d9e6cf"]
const HATS := ["#d98c6a", "#7d9a6b", "#6f8fb0", "#b5654a", "#c9a14a"]
const BAGC := ["#a0764e", "#c79a5b", "#8f6a4a"]

const STAFF_LOOK := {
	"trainer": {"skin": "#c98d62", "hair": "#2a1d18", "style": "short", "shirt": "#2b2b30", "pants": "#2b2b30", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#fff"},
	"laundry": {"skin": "#ecc29b", "hair": "#3b2a20", "style": "short", "shirt": "#8fb3c9", "pants": "#3f4a5a", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#6f8fb0"},
	"kantin": {"skin": "#d6a378", "hair": "#2f2320", "style": "bun", "shirt": "#e9a35a", "pants": "#6b5a48", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#fff"},
	"tani": {"skin": "#e9b98f", "hair": "#2f2320", "style": "short", "shirt": "#7fae5a", "pants": "#4f5d4a", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#7fae5a"},
	"lele": {"skin": "#d9a27a", "hair": "#2f2320", "style": "short", "shirt": "#3f5a4a", "pants": "#3f4a5a", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#3f5a4a"},
	"petshop": {"skin": "#f2c7a5", "hair": "#6b4a2b", "style": "bun", "shirt": "#f2a7b6", "pants": "#3f4a5a", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#fff"},
	"florist": {"skin": "#f2c7a5", "hair": "#2f2320", "style": "bun", "shirt": "#b48ad6", "pants": "#3f4a5a", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#fff"},
	"koperasi": {"skin": "#f2c7a5", "hair": "#2f2320", "style": "bun", "shirt": "#7fae5a", "pants": "#3f4a5a", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#fff"},
	"warteg": {"skin": "#e9b98f", "hair": "#4a3426", "style": "bun", "shirt": "#e07a5f", "pants": "#4f5d4a", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#fff"},
	"kasir": {"skin": "#f2c7a5", "hair": "#2f2320", "style": "bun", "shirt": "#e0533a", "pants": "#3f4a5a", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#fff"},
	"barista": {"skin": "#f2c7a5", "hair": "#6b4a2b", "style": "cap", "shirt": "#3f4a44", "pants": "#2f3a33", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#2f3833"},
	"cleaner": {"skin": "#f6d3b3", "hair": "#6b4a2b", "style": "bun", "shirt": "#7d9a6b", "pants": "#4f5d4a", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#7d9a6b"},
	"satpam": {"skin": "#d6a378", "hair": "#1f1a17", "style": "cap", "shirt": "#3d4f7a", "pants": "#2f3a52", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#2f3a52"},
	"teknisi": {"skin": "#ecc29b", "hair": "#3b2a20", "style": "beanie", "shirt": "#e09a4a", "pants": "#5d5a66", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#c9a14a"},
	"resep": {"skin": "#f2c7a5", "hair": "#2f2320", "style": "long", "shirt": "#a0644a", "pants": "#fff", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#fff"},
}

# Warna UI.
const C_INK := Color("4a3626")
const C_LINE := Color("6b4f3a")
const C_PAPER := Color("fbf5ea")
const C_GREEN := Color("a8d5a2")
const C_PINK := Color("f4a7a8")
const C_YELLOW := Color("f7d36e")
const C_CREAM := Color("f6ecd2")
const C_RED := Color("e98b7a")
const C_MUTED := Color("8a6f58")


static func rect_of(id: String) -> Rect2:
	var cc: Vector2 = COLS["M" if col(id) == "S" else col(id)]
	var row: Vector2 = ROWS[fl(id)]
	return Rect2(cc.x, row.x, cc.y - cc.x, row.y - row.x)


const EXTRA_PITCH := 392

# ---- Dekorasi kamar: cat tembok, motif, lantai ----
# Garis lantai (px dari atas kotak kamar) tiap gambar kamar acuan.
const ROOM_FLOOR_Y := {"1S": 206, "3S": 229, "4L": 272, "4R": 272, "3L": 256, "3R": 256, "2L": 243, "2R": 243, "1L": 232, "1R": 232}
const PAINTS := {
	"asli": {"n": "Krem Asli", "c": "f2dcc0"},
	"putih": {"n": "Putih Susu", "c": "f7f3ea"},
	"biru": {"n": "Biru Langit", "c": "bfd9ec"},
	"mint": {"n": "Hijau Mint", "c": "c9e6cf"},
	"pink": {"n": "Pink Salem", "c": "f3c9c6"},
	"kuning": {"n": "Kuning Mentega", "c": "f6e3a4"},
	"lavender": {"n": "Lavender", "c": "d9cdea"},
	"toska": {"n": "Toska", "c": "9fd3cf"},
	"abu": {"n": "Abu Kalem", "c": "d3d0cb"},
	"terakota": {"n": "Terakota", "c": "e2a98c"},
}
const PAINT_ORDER := ["asli", "putih", "biru", "mint", "pink", "kuning", "lavender", "toska", "abu", "terakota"]
const MOTIFS := {
	"polos": {"n": "Polos", "p": 0, "id": 0},
	"garis": {"n": "Garis", "p": 100000, "id": 1},
	"polkadot": {"n": "Polkadot", "p": 120000, "id": 2},
	"kotak": {"n": "Kotak-kotak", "p": 120000, "id": 3},
	"bata": {"n": "Bata", "p": 160000, "id": 4},
	"wajik": {"n": "Wajik", "p": 140000, "id": 5},
}
const MOTIF_ORDER := ["polos", "garis", "polkadot", "kotak", "bata", "wajik"]
const PAINT_PRICE := 150000.0

# Tangga: bisa di-upgrade sampai eskalator. bonus = tambahan sewa, spd = kecepatan naik-turun.
const STAIRS := [
	{},
	{"n": "Tangga Kayu", "d": "Tangga kayu bawaan Nenek.", "cost": 0, "lv": 1, "bonus": 0.0, "spd": 1.0},
	{"n": "Tangga Keramik", "d": "Anak tangga dilapisi keramik, bersih dan tidak berderit.", "cost": 2000000, "lv": 3, "bonus": 0.02, "spd": 1.15},
	{"n": "Tangga Karpet", "d": "Karpet merah dengan batang kuningan. Kesan kost jadi mewah.", "cost": 5000000, "lv": 5, "bonus": 0.04, "spd": 1.3},
	{"n": "Eskalator", "d": "Tangga berjalan! Penghuni naik-turun tanpa capek, kost makin bergengsi.", "cost": 60000000, "lv": 8, "bonus": 0.08, "spd": 1.8},
]
const FLOORS := {
	"asli": {"n": "Kayu Asli", "k": 0, "c": "d2b48f", "c2": "d2b48f", "p": 0},
	"kayu_gelap": {"n": "Kayu Gelap", "k": 1, "c": "9a6a45", "c2": "9a6a45", "p": 300000},
	"kayu_putih": {"n": "Kayu Putih", "k": 1, "c": "efe6d6", "c2": "efe6d6", "p": 300000},
	"keramik": {"n": "Keramik Putih", "k": 2, "c": "f4f1ea", "c2": "e6e1d6", "p": 450000},
	"keramik_abu": {"n": "Keramik Abu", "k": 2, "c": "c9c7c2", "c2": "b6b3ad", "p": 450000},
	"catur": {"n": "Keramik Catur", "k": 2, "c": "f2efe8", "c2": "4a4a52", "p": 550000},
	"karpet_biru": {"n": "Karpet Biru", "k": 3, "c": "7d9cc4", "c2": "7d9cc4", "p": 400000},
	"karpet_hijau": {"n": "Karpet Hijau", "k": 3, "c": "8fb58a", "c2": "8fb58a", "p": 400000},
}
const FLOOR_ORDER := ["asli", "kayu_gelap", "kayu_putih", "keramik", "keramik_abu", "catur", "karpet_biru", "karpet_hijau"]


## Material shader cat untuk kamar `rid` dengan pilihan `p` {wall, motif, floor}.
static func paint_mat(rid: String, p: Dictionary, tex_size: Vector2, mat: ShaderMaterial = null) -> ShaderMaterial:
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/paint.gdshader")
		mat.set_shader_parameter("mask", load("res://assets/paint_mask.png"))
	var sr := src_rect(rid)
	mat.set_shader_parameter("region_uv", Vector4(sr.position.x / tex_size.x, sr.position.y / tex_size.y, sr.size.x / tex_size.x, sr.size.y / tex_size.y))
	mat.set_shader_parameter("room_size", sr.size)
	mat.set_shader_parameter("floor_y", float(ROOM_FLOOR_Y.get(tpl(rid), 256)))
	var w: String = p.get("wall", "asli")
	mat.set_shader_parameter("wall_on", w != "asli" or p.get("motif", "polos") != "polos")
	var wc := Color(PAINTS[w].c)
	mat.set_shader_parameter("wall_col", wc)
	mat.set_shader_parameter("wall_col2", wc.lerp(Color.WHITE, 0.45) if wc.get_luminance() < 0.85 else wc.darkened(0.12))
	mat.set_shader_parameter("motif", int(MOTIFS[p.get("motif", "polos")].id))
	var fd: Dictionary = FLOORS[p.get("floor", "asli")]
	mat.set_shader_parameter("floor_kind", int(fd.k))
	mat.set_shader_parameter("floor_col", Color(fd.c))
	mat.set_shader_parameter("floor_col2", Color(fd.c2))
	return mat
const LOBBY_TOP := 1800.0

## Kamar lantai 5+ meminjam gambar dari kamar lantai 3 (tata letak sama).
static func tpl(rid: String) -> String:
	return ("3" + col(rid)) if fl(rid) > 4 else rid


static func src_rect(id: String) -> Rect2:
	return rect_of(tpl(id))


# Perabot berdiri sendiri (assets/furn/item/<jenis>_<level>.png), tata letak sama di semua kamar.
# Nilai: [pusat x, alas y, lebar] sebagai pecahan kotak kamar, untuk kamar kiri (A).
# Kamar kanan (C) dicerminkan supaya kasur menghadap ke kiri.
const ITEM_LAYOUT := {
	"kasur": [0.31, 0.97, 0.60],
	"karpet": [0.69, 0.91, 0.42],
	"lampu": [0.66, 0.72, 0.14],
	"tanaman": [0.92, 0.97, 0.11],
	"rak": [0.87, 0.65, 0.22],
	"dekor": [0.345, 0.34, 0.165],
	"kipas": [0.80, 0.80, 0.11],
}
# Posisi khusus per level (kipas berdiri di lantai, AC menempel di dinding).
const ITEM_LAYOUT_LV := {"kipas": {2: [0.395, 0.19, 0.2], 3: [0.395, 0.19, 0.2]}}
const ITEM_DRAW_ORDER := ["karpet", "dekor", "rak", "kasur", "lampu", "kipas", "tanaman"]


static func furn_has(_rid: String, t: String) -> bool:
	return ITEM_LAYOUT.has(t)


static func furn_tex(_rid: String, t: String, lv: int = 1) -> String:
	return "res://assets/furn/item/%s_%d.png" % [t, clampi(lv, 1, 3)]


static func furn_flip(rid: String) -> bool:
	return rid.ends_with("R")


## Kotak gambar perabot (koordinat gedung) untuk ukuran tekstur tertentu.
static func furn_rect(rid: String, t: String, tex_size: Vector2, lv: int = 1) -> Rect2:
	var r := rect_of(rid)
	var lay: Array = ITEM_LAYOUT_LV[t][lv] if ITEM_LAYOUT_LV.has(t) and ITEM_LAYOUT_LV[t].has(lv) else ITEM_LAYOUT[t]
	var cx: float = lay[0]
	if furn_flip(rid):
		cx = 1.0 - cx
	var w: float = r.size.x * float(lay[2])
	var h := w * tex_size.y / tex_size.x
	var bottom: float = r.position.y + r.size.y * float(lay[1])
	return Rect2(r.position.x + r.size.x * cx - w / 2.0, bottom - h, w, h)


static func room_name(id: String) -> String:
	if id.length() < 2: return "-"
	return str(fl(id)) + {"L": "A", "R": "B"}.get(col(id), "")


## Tangga di kolom tengah: lantai ganjil di sisi kiri, lantai genap di sisi kanan.
static func stair_x(f: int) -> float:
	return 666.0 if f % 2 == 1 else 870.0


static func stair_top(f: int) -> float:
	return float(ROWS[f].x) + 95.0


# ---------- Lobi Langit: tiap 10 lantai ada pintu masuk sendiri ----------
const HUB_EVERY := 10
const HUBS := [
	{"k": "parkir", "n": "Lobi Parkiran", "d": "Penghuni lantai atas parkir & masuk dari sini.", "c": Color("6a8fb3")},
	{"k": "tol", "n": "Gerbang Tol", "d": "Mobil & bus keluar-masuk lewat jalan layang.", "c": Color("d9a43a")},
	{"k": "kereta", "n": "Stasiun Kereta", "d": "Kereta menembus gedung, penghuni turun langsung.", "c": Color("5fae4f")},
	{"k": "heli", "n": "Helipad", "d": "Helikopter antar-jemput penghuni lantai tinggi.", "c": Color("e0533d")},
	{"k": "roket", "n": "Stasiun Luar Angkasa", "d": "Roket ulang-alik untuk penghuni paling atas.", "c": Color("8a6ad9")},
	{"k": "galaksi", "n": "Terminal Antar-Galaksi", "d": "UFO parkir, alien & astronaut transit di sini.", "c": Color("7a52c7")},
	{"k": "blackhole", "n": "Stasiun Portal Black Hole", "d": "Kereta kapsul menembus black hole ke multiverse.", "c": Color("3e4f8f")},
	{"k": "dimensi", "n": "Gerbang Tol Dimensi", "d": "Kapal penjelajah waktu bayar tol antar-dimensi.", "c": Color("e07a2e")},
	{"k": "imigrasi", "n": "Imigrasi Langit", "d": "Malaikat memeriksa berkas jiwa di loket amal.", "c": Color("d9606a")},
	{"k": "langit7", "n": "Terminal Akhir Langit ke-7", "d": "Gerbang cahaya, ujung perjalanan penghuni.", "c": Color("d8ad3c")},
]
const HUB_SPACE := ["roket", "galaksi", "blackhole", "dimensi"]
const HUB_HEAVEN := ["imigrasi", "langit7"]


static func is_hub(f: int) -> bool:
	return f >= HUB_EVERY and f % HUB_EVERY == 0


static func hub_info(f: int) -> Dictionary:
	# Tiap jenis lobi dipakai 10 kali (lt 10-100 parkir, 110-200 tol, dst.), jenis terakhir seterusnya.
	var i: int = f / HUB_EVERY - 1
	var ti: int = mini(i / HUB_EVERY, HUBS.size() - 1)
	var h: Dictionary = HUBS[ti].duplicate()
	var no: int = i - ti * HUB_EVERY + 1
	if no > 1: h.n = "%s %d" % [h.n, no]
	h.space = h.k in HUB_SPACE
	h.heaven = h.k in HUB_HEAVEN
	return h


static func hub_spot(f: int) -> Vector2:
	if f <= 0: return Vector2(OUT_X, LOBBY_Y)
	# pintu peron/gerbang di sisi kiri lantai hub
	return Vector2(300, FEET[f])


static func scene_pos(s: String) -> Vector2:
	if s == "lobby":
		return Vector2(LOBBY_X, LOBBY_Y)
	if s.begins_with("S"):
		return Vector2(773, FEET[fl(s)])
	return Vector2(CX[col(s)], FEET[fl(s)])


static func bfs(a: String, b: String) -> Array:
	if a == b:
		return [a]
	var adj := {}
	for e in EDGES:
		if not adj.has(e[0]): adj[e[0]] = []
		if not adj.has(e[1]): adj[e[1]] = []
		adj[e[0]].append(e[1])
		adj[e[1]].append(e[0])
	var prev := {a: ""}
	var q := [a]
	while q.size() > 0:
		var c: String = q.pop_front()
		for nx in adj.get(c, []):
			if not prev.has(nx):
				prev[nx] = c
				if nx == b:
					var path := [b]
					var x: String = b
					while prev[x] != "":
						x = prev[x]
						path.push_front(x)
					return path
				q.append(nx)
	return [a]


static func rp(n: float) -> String:
	return ("-" if n < 0 else "") + "Rp " + dots(absi(roundi(n)))


static func dots(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return out


static func short(n: float) -> String:
	var a := absf(n)
	var sign := "-" if n < 0 else ""
	if a >= 1000000.0:
		var v := a / 1000000.0
		var t := str(snappedf(v, 0.1)).replace(".", ",")
		if t.ends_with(",0"): t = t.substr(0, t.length() - 2)
		return sign + t + "jt"
	return sign + str(roundi(a / 1000.0)) + "rb"


# ---- Outsource: jasa luar yang bisa di-upgrade ----
const OUTSRC := {
	"kurir": {"nama": "Bang Jali", "n": "Kurir Perabot", "pic": "kurir/idle", "lv": [
		{"n": "Kurir Motor", "cost": 0, "d": "Angkut 2 kotak sekali jalan. Barang tiba ± 45 menit."},
		{"n": "Kurir Pickup", "cost": 750000, "d": "Angkut 3 kotak sekali jalan. Barang tiba ± 30 menit."},
		{"n": "Ekspedisi Kilat", "cost": 2000000, "d": "Angkut 5 kotak sekaligus, barang tiba ± 15 menit, antar lebih cepat."}]},
	"galon": {"nama": "Kang Asep", "n": "Kang Galon", "pic": "galon/happy", "lv": [
		{"n": "Depot Isi Ulang", "cost": 0, "d": "Antar air ke Kantin 2 hari sekali, Rp 6rb/galon."},
		{"n": "Air Mineral Bermerek", "cost": 600000, "d": "Rp 22rb/galon, penghuni +2 kebahagiaan tiap antar."},
		{"n": "Langganan Harian", "cost": 1500000, "d": "Antar tiap hari, penghuni +3 kebahagiaan."}]},
	"ojol": {"nama": "Bang Thoyib", "n": "Ojek Online", "pic": "ojol/thumb", "lv": [
		{"n": "Ojol Biasa", "cost": 0, "d": "Kadang mengantar makanan pesanan penghuni (+4 senang)."},
		{"n": "Ojol Prioritas", "cost": 500000, "d": "Lebih sering datang, penghuni +6 senang."},
		{"n": "Mitra Resmi Kost", "cost": 1200000, "d": "Hampir tiap jam makan datang, penghuni +8 senang."}]},
	"sampah": {"nama": "Mang Ujang", "n": "Petugas Sampah", "pic": "sampah/wave", "lv": [
		{"n": "Belum Langganan", "cost": 0, "fee": 0, "d": "Sampah menumpuk: semua kamar 30% lebih cepat kotor."},
		{"n": "Angkut 3 Hari Sekali", "cost": 250000, "fee": 5000, "d": "Kamar kotor normal. Iuran Rp 5rb/hari."},
		{"n": "Angkut Harian", "cost": 600000, "fee": 8000, "d": "Kamar 15% lebih lambat kotor. Iuran Rp 8rb/hari."},
		{"n": "Pilah & Daur Ulang", "cost": 1500000, "fee": 12000, "d": "Kamar 25% lebih lambat kotor, penghuni +1 senang tiap hari. Iuran Rp 12rb/hari."}]},
	"tukang": {"nama": "Pak Joko", "n": "Tukang Bangunan", "pic": "tukang/hold", "dia": true, "lv": [
		{"n": "Tukang Harian", "cost": 0, "d": "Bangun kamar & ruang fasilitas dengan kecepatan normal."},
		{"n": "Tukang + Kenek", "cost": 25, "d": "Pembangunan 60% lebih cepat."},
		{"n": "Kontraktor Profesional", "cost": 80, "d": "Pembangunan 2,5x lebih cepat."}]},
	"polisi": {"nama": "Pak Bambang", "n": "Polisi Patroli", "pic": "polisi/idle", "lv": [
		{"n": "Belum Kerja Sama", "cost": 0, "d": "Lapor polisi manual (Rp 50rb) saat ada preman. Maling tidak ditangkap."},
		{"n": "Patroli Rutin", "cost": 800000, "d": "Polisi otomatis datang menyeret preman. Lapor gratis."},
		{"n": "Pos Polisi Dekat Kost", "cost": 2500000, "d": "Preman jarang datang, maling langsung ditangkap & barang kembali."}]},
	"damkar": {"nama": "Bu Rina", "n": "Pemadam Kebakaran", "pic": "damkar/idle", "lv": [
		{"n": "Panggil Darurat", "cost": 0, "d": "Kebakaran harus dilaporkan manual (Rp 100rb), damkar tiba agak lama."},
		{"n": "Langganan Damkar", "cost": 1000000, "d": "Damkar otomatis datang cepat & gratis saat kebakaran."},
		{"n": "Alarm & Sprinkler", "cost": 3000000, "d": "Api padam sendiri lebih lambat menjalar; damkar tiba sangat cepat."}]},
	"influencer": {"nama": "Kak Nisa", "n": "Influencer", "pic": "influencer/cam", "lv": [
		{"n": "Belum Kerja Sama", "cost": 0, "d": "Sesekali datang sendiri merekam kost-mu. Bisa diundang sekali (Rp 750rb)."},
		{"n": "Endorse Bulanan", "cost": 2000000, "d": "Datang tiap ± 12 hari bikin konten. Kost viral 2 hari, calon penyewa membludak."},
		{"n": "Brand Ambassador", "cost": 8000000, "d": "Datang tiap ± 6 hari, viral 3 hari, rating +0,1 tiap konten."}]},
}
const OUTSRC_ORDER := ["kurir", "galon", "ojol", "sampah", "tukang", "polisi", "damkar", "influencer"]

# Pengacau: kejadian yang mengganggu kost. Ditampilkan di Karyawan > Pengacau.
const PENGACAU := [
	{"k": "maling", "n": "Maling", "pic": "maling/idle", "lv": 2,
		"d": "Masuk diam-diam lewat lobi atau memanjat dinding luar, mencuri barang kamar.",
		"lawan": "Ketuk malingnya secepatnya. Polisi Patroli/Pos Polisi menangkap & mengembalikan barang. Satpam mempersulit maling."},
	{"k": "preman", "n": "Preman Pungli", "pic": "preman/demand", "lv": 3,
		"d": "Siang hari datang ke lobi minta \"uang keamanan\". Makin sering dibayar, makin besar mintanya.",
		"lawan": "Tolak, bayar, atau lapor polisi. Langganan Polisi bikin preman diseret otomatis."},
	{"k": "beruang", "n": "Anak Beruang Nyasar", "pic": "", "icon": "beruang", "lv": 1,
		"d": "Anak beruang tertukar dengan Mpus. Induknya datang menjemput, tamu kabur ketakutan.",
		"lawan": "Rawat anak beruangnya sampai induknya datang. Jangan diusir."},
	{"k": "zombie", "n": "Serbuan Zombie", "pic": "zombie/idle", "lv": 1,
		"d": "Rombongan \"zombie\" menyerbu lobi. Penghuni panik.",
		"lawan": "Ketuk zombienya satu per satu sebelum masuk ke kamar."},
	{"k": "fire", "n": "Kebakaran", "pic": "", "icon": "api", "lv": 1,
		"d": "Korsleting atau kompor lupa dimatikan. Api menjalar, penghuni & karyawan kabur panik.",
		"lawan": "Panggil damkar secepatnya. Langganan Damkar / Alarm & Sprinkler membuatnya otomatis."},
	{"k": "petir", "n": "Gledek (Petir)", "pic": "", "icon": "petir", "lv": 1,
		"d": "Petir menyambar satu kamar saat hujan badai. Kamar gosong dan harus direnovasi 3 jam.",
		"lawan": "Renovasi kamarnya lewat tukang. Bisa dipercepat pakai Diamond."},
	{"k": "hantu", "n": "Hantu Kamar Kosong", "pic": "", "icon": "hantu", "lv": 1,
		"d": "\"Hantu\" muncul di jendela kamar kosong (ternyata gorden). Calon penyewa menolak kamar itu.",
		"lawan": "Ketuk jendelanya untuk membongkar hantunya, atau isi kamarnya."},
	{"k": "durian", "n": "Salah Kirim Durian", "pic": "", "icon": "durian", "lv": 1,
		"d": "Pickup salah kirim sekotak durian. Lobi bau seharian, sebagian penghuni kesal.",
		"lawan": "Ketuk kotaknya: buang, atau adakan pesta durian."},
]

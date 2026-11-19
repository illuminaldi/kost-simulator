class_name D
extends RefCounted
## Semua data statis game: koordinat ilustrasi, kamar, pekerjaan, karyawan, fasilitas.

const IW := 1438
const IH := 2576

# Kolom & baris kamar pada ilustrasi (piksel gambar asli).
const COLS := {"L": Vector2(131, 551), "M": Vector2(576, 970), "R": Vector2(996, 1405)}
const ROWS := {8: Vector2(-1302, -935), 7: Vector2(-910, -543), 6: Vector2(-518, -151), 5: Vector2(-126, 241), 4: Vector2(242, 626), 3: Vector2(651, 1018), 2: Vector2(1043, 1410), 1: Vector2(1436, 1800)}
const SLOTS := ["8L", "8S", "8R", "7L", "7S", "7R", "6L", "6S", "6R", "5L", "5S", "5R", "4L", "4S", "4R", "3L", "3S", "3R", "2L", "2S", "2R", "1L", "1S", "1R"]
const ROOMS := ["8L", "8R", "7L", "7R", "6L", "6R", "5L", "5R", "4L", "4R", "3L", "3R", "2L", "2R", "1L", "1R"]

# Garis lantai (posisi kaki NPC) & pusat kolom.
const FEET := {8: -953.0, 7: -561.0, 6: -169.0, 5: 223.0, 4: 600.0, 3: 1000.0, 2: 1392.0, 1: 1778.0}
const CX := {"L": 341.0, "M": 773.0, "R": 1200.0}
const LOBBY_Y := 2335.0
const LOBBY_X := 700.0
const OUT_X := -90.0
const QUEUE_X := [600.0, 740.0, 880.0, 1030.0]

# Titik aktivitas di tiap kamar (posisi kaki / alas sprite).
const SPOT := {
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
const LAMPS := {
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
const NAV := [["upgrade", Rect2(22, 2405, 340, 145)], ["tenants", Rect2(392, 2405, 314, 145)],
	["staff", Rect2(733, 2405, 315, 145)], ["manage", Rect2(1074, 2405, 316, 145)]]
const GROUND_RECT := Rect2(380, 1860, 980, 512)
const CAT_RECT := Rect2(400, 2195, 155, 110)

# Graf perpindahan antar "scene" (lobi, tangga, kamar).
const EDGES := [["lobby", "S1"], ["S1", "S2"], ["S2", "S3"], ["S3", "S4"], ["S1", "1L"], ["S1", "1R"],
	["S2", "2L"], ["S2", "2R"], ["S3", "3L"], ["S3", "3R"], ["S4", "4L"], ["S4", "4R"], ["S4", "S5"], ["S5", "5L"], ["S5", "5R"], ["S5", "S6"], ["S6", "6L"], ["S6", "6R"], ["S6", "S7"], ["S7", "7L"], ["S7", "7R"], ["S7", "S8"], ["S8", "8L"], ["S8", "8R"]]

const FLOOR_LV := {1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 7: 7, 8: 8}

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
	"kasur": {"n": "Kasur", "cost": 400000, "c": 3.0, "min": 1, "icon": "4L_kasur", "d": "Wajib ada supaya kamar bisa disewa."},
	"lampu": {"n": "Lampu", "cost": 150000, "c": 1.0, "min": 1, "icon": "4R_lampu", "d": "Kamar terang & hangat di malam hari."},
	"tanaman": {"n": "Tanaman", "cost": 120000, "c": 1.0, "min": 1, "icon": "4L_tanaman", "d": "Bikin kamar terasa segar."},
	"karpet": {"n": "Karpet", "cost": 200000, "c": 1.0, "min": 1, "icon": "2L_karpet", "d": "Lantai lebih nyaman."},
	"dekor": {"n": "Hiasan Dinding", "cost": 180000, "c": 1.0, "min": 2, "icon": "4L_dekor", "d": "Lukisan, poster, atau jemuran."},
	"rak": {"n": "Rak Buku", "cost": 300000, "c": 2.0, "min": 2, "icon": "2L_rak", "d": "Tempat menyimpan buku & barang."},
	"meja": {"n": "Meja Kerja", "cost": 350000, "c": 2.0, "min": 3, "icon": "2M_meja", "d": "Disukai freelancer & mahasiswa."},
}
# ---------- Ruang fasilitas di samping tangga ----------
# happy: +kebahagiaan harian semua penghuni; inc: pemasukan per penghuni per hari (butuh karyawan kalau ada "staff").
# visit: jam-jam penghuni mampir.
const FACIL := {
	"tunggu": {"n": "Ruang Tunggu", "lv": 1, "cost": 800000, "happy": 0, "inc": 0, "visit": [], "pose": "stand",
		"d": "Sofa nyaman di dekat lobi. Calon penyewa lebih sabar & lebih sering datang."},
	"laundry": {"n": "Laundry", "lv": 2, "cost": 1200000, "happy": 1, "inc": 4000, "staff": "laundry", "visit": [9, 19], "pose": "stand",
		"d": "Kamar lebih lambat kotor. Jasa cuci menambah pemasukan (2x dengan Petugas Laundry)."},
	"mushola": {"n": "Mushola", "lv": 3, "cost": 1000000, "happy": 2, "inc": 0, "visit": [5, 12, 15, 18], "pose": "stand",
		"d": "Tempat ibadah yang tenang. Penghuni lebih betah & rating naik pelan."},
	"dapur": {"n": "Dapur Bersama", "lv": 3, "cost": 1500000, "happy": 2, "inc": 0, "visit": [7, 19], "pose": "stand",
		"d": "Penghuni bisa masak sendiri. Masalah area kotor lebih jarang."},
	"kantin": {"n": "Kantin", "lv": 4, "cost": 2000000, "happy": 2, "inc": 6000, "staff": "kantin", "visit": [12, 18], "pose": "stand",
		"d": "Makan murah tanpa keluar kost. Pemasukan harian kalau ada Ibu Kantin."},
	"cafe": {"n": "Cafe", "lv": 5, "cost": 2500000, "happy": 2, "inc": 8000, "staff": "barista", "visit": [15, 20], "pose": "stand",
		"d": "Tempat nongkrong & kerja. Harga sewa +5%; pemasukan harian kalau ada Barista."},
	"gym": {"n": "Gym", "lv": 6, "cost": 3000000, "happy": 3, "inc": 0, "visit": [6, 17], "pose": "stand",
		"d": "Penghuni olahraga pagi & sore. Kebahagiaan naik."},
	"rooftop": {"n": "Taman Rooftop", "lv": 7, "cost": 3500000, "happy": 3, "inc": 0, "visit": [16, 20], "pose": "stand",
		"d": "Taman hijau untuk santai sore. Rating kost naik setiap hari."},
}
const FACIL_ORDER := ["tunggu", "laundry", "mushola", "dapur", "kantin", "cafe", "gym", "rooftop"]


## Sisi kosong ruang tangga (lantai ganjil: kanan, genap: kiri).
static func facil_rect(f: int) -> Rect2:
	var r := rect_of("%dS" % f)
	var half := r.size.x / 2.0
	return Rect2(r.position.x + (half if f % 2 == 1 else 0.0), r.position.y, half, r.size.y)


# Area aman untuk perabot fasilitas: tidak menutupi pintu (dekat x 580-600 & 930-970) & tangga.
const FACIL_W := 140.0
const FACIL_SVG_FLOOR := 0.78   # posisi alas perabot pada gambar (0..1)


static func facil_center_x(f: int) -> float:
	return 850.0 if f % 2 == 1 else 680.0


## Kotak gambar fasilitas (diperkecil & digeser menjauhi pintu), alas perabot tetap di lantai.
static func facil_draw_rect(f: int) -> Rect2:
	var r := rect_of("%dS" % f)
	var h := FACIL_W * 367.0 / 200.0
	var floor_y := r.position.y + r.size.y * FACIL_SVG_FLOOR
	return Rect2(facil_center_x(f) - FACIL_W / 2.0, floor_y - h * FACIL_SVG_FLOOR, FACIL_W, h)


static func facil_spot(f: int) -> Vector2:
	return Vector2(facil_center_x(f), FEET[f])


const FURN_ORDER := ["kasur", "lampu", "tanaman", "karpet", "dekor", "rak"]
const FURN_MULT := [0.0, 1.0, 1.6, 2.3]
const FURN_LV_NAME := ["", "Biasa", "Bagus", "Mewah"]
const RLV := [{}, {"n": "Standar", "rent": 60000}, {"n": "Nyaman", "rent": 100000}, {"n": "Premium", "rent": 160000}]
const UPG := [0, 0, 1200000, 2500000]
const PRICE := [{"n": "Murah", "m": 0.8, "h": 3, "c": 0.8}, {"n": "Normal", "m": 1.0, "h": 0, "c": 1.0},
	{"n": "Mahal", "m": 1.3, "h": -4, "c": 1.35}]
const JOBS := {
	"Mahasiswa": {"away": [8, 15], "pref": 1, "min": 1},
	"Karyawan": {"away": [7, 17], "pref": 2, "min": 1},
	"Freelancer": {"away": [], "pref": 2, "min": 2},
	"Perawat": {"away": [14, 22], "pref": 2, "min": 2},
	"Manajer": {"away": [8, 18], "pref": 3, "min": 3},
}
const STAFF := {
	"cleaner": {"n": "Petugas Kebersihan", "sal": 50000, "min": 1, "d": "Membersihkan kamar kotor; menangani sampah, area bersama kotor & hama."},
	"resep": {"n": "Penjaga Kost", "sal": 60000, "min": 1, "d": "Berjaga di meja depan. Tamu lebih sering & sabar; menagih sewa, urus kunci hilang & tegur penghuni berisik."},
	"teknisi": {"n": "Teknisi", "sal": 80000, "min": 3, "d": "Memperbaiki kerusakan gratis; menangani air mati, WiFi lemot, listrik jeglek & atap bocor."},
	"laundry": {"n": "Petugas Laundry", "sal": 45000, "min": 2, "need": "laundry", "d": "Mengurus mesin cuci. Pemasukan Laundry jadi 2x."},
	"kantin": {"n": "Ibu Kantin", "sal": 55000, "min": 4, "need": "kantin", "d": "Memasak di Kantin. Membuka pemasukan harian Kantin."},
	"barista": {"n": "Barista", "sal": 60000, "min": 5, "need": "cafe", "d": "Meracik kopi di Cafe. Membuka pemasukan harian Cafe."},
	"satpam": {"n": "Satpam", "sal": 70000, "min": 3, "d": "Patroli di depan kost. Mencegah pencurian; urus tamu menginap & paket hilang."},
}
const FAC := {
	"wifi": {"n": "WiFi Kencang", "cost": 800000, "min": 1, "d": ""},
	"jemur": {"n": "Area Jemuran", "cost": 900000, "min": 2, "d": "Kamar lebih lambat kotor."},
	"cctv": {"n": "CCTV", "cost": 1000000, "min": 3, "d": "Peluang pencurian turun separuh."},
	"parkir": {"n": "Parkir Motor", "cost": 1500000, "min": 4, "d": ""},
}
const ISSUES := {"AC rusak": 250000, "Keran bocor": 120000, "Lampu mati": 60000, "Kasur jebol": 300000}
# Karakter penghuni (folder di assets/chars) -> jenis kelamin untuk nama.
const CHARS := {"kutu": "l", "kakek": "l", "siswi": "p", "flanel": "p", "nenek": "p"}
# Pekerja: pose -> file (Array = bergantian tiap 3.5 detik).
const WORKER := {
	"build": {"char": "tukang", "map": {"walk": "walk", "stand": "hold", "job": ["repair", "repair", "carry"], "react": "hold"}, "mins": 240},
	"fix": {"char": "teknisi", "map": {"walk": "walk", "stand": "idle", "job": ["idle", "fix", "fix"], "react": "happy"}, "mins": 90},
	"deliver": {"char": "kurir", "map": {"walk": "carry", "stand": "idle", "job": "back", "react": "idle"}, "mins": 40},
}
const TRUCK_X := 330.0
const NAMES_P := ["Sari", "Dewi", "Putri", "Nadia", "Intan", "Citra", "Laras", "Ayu", "Tiara", "Wulan", "Mega", "Rina",
	"Fitri", "Lina", "Salsa", "Anisa", "Dinda", "Maya"]
const NAMES_L := ["Andi", "Budi", "Rizky", "Fajar", "Yoga", "Bayu", "Dimas", "Reza", "Gilang", "Hendra", "Arif", "Joko",
	"Eko", "Agus", "Bima", "Rafi", "Iqbal", "Dodi"]

# Palet karakter (diambil dari warna ilustrasi).
const SKINS := ["#f6d3b3", "#ecc29b", "#d6a378", "#b98058"]
const HAIRS := ["#3b2a20", "#1f1a17", "#6b4a2b", "#8a5a3b"]
const SHIRTS := ["#c9a14a", "#b5654a", "#7d9a6b", "#6f8fb0", "#d98c8c", "#9a7bb0", "#e0b24f", "#8fb3a8"]
const PANTS := ["#5d5a66", "#6b5a48", "#3f4a5a", "#8a7560", "#d8c9b0"]
const BLANKETS := ["#e6d3a3", "#cfd9e6", "#f0c9c0", "#d9e6cf"]
const HATS := ["#d98c6a", "#7d9a6b", "#6f8fb0", "#b5654a", "#c9a14a"]
const BAGC := ["#a0764e", "#c79a5b", "#8f6a4a"]

const STAFF_LOOK := {
	"laundry": {"skin": "#ecc29b", "hair": "#3b2a20", "style": "short", "shirt": "#8fb3c9", "pants": "#3f4a5a", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#6f8fb0"},
	"kantin": {"skin": "#d6a378", "hair": "#2f2320", "style": "bun", "shirt": "#e9a35a", "pants": "#6b5a48", "bag": false, "bagc": "#000", "blanket": "#fff", "hat": "#fff"},
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
	var col: Vector2 = COLS["M" if id[1] == "S" else id[1]]
	var row: Vector2 = ROWS[int(id[0])]
	return Rect2(col.x, row.x, col.y - col.x, row.y - row.x)


const EXTRA_PITCH := 392
const TOP_FLOOR := 8
const BUILDING_TOP := -1568   # y atap lantai teratas (koordinat gedung)
const LOBBY_TOP := 1800.0

## Kamar lantai 5+ meminjam gambar dari kamar lantai 3 (tata letak sama).
static func tpl(rid: String) -> String:
	return ("3" + rid.substr(1)) if int(rid[0]) > 4 else rid


static func src_rect(id: String) -> Rect2:
	return rect_of(tpl(id))


static func furn_tex(rid: String, t: String, lv: int = 1) -> String:
	rid = tpl(rid)
	if lv >= 2 and FURN_POS2.get(rid, {}).has(t):
		return "res://assets/furn/%s_%s_2.png" % [rid, t]
	return "res://assets/furn/%s_%s.png" % [rid, t]


static func furn_pos(rid: String, t: String, lv: int = 1) -> Vector2:
	if lv >= 2 and FURN_POS2.get(rid, {}).has(t):
		return FURN_POS2[rid][t]
	return FURN_POS[rid][t]


static func room_name(id: String) -> String:
	return id[0] + {"L": "A", "M": "B", "R": "C"}[id[1]]


## Tangga di kolom tengah: lantai ganjil di sisi kiri, lantai genap di sisi kanan.
static func stair_x(f: int) -> float:
	return 666.0 if f % 2 == 1 else 870.0


static func stair_top(f: int) -> float:
	return float(ROWS[f].x) + 95.0


static func scene_pos(s: String) -> Vector2:
	if s == "lobby":
		return Vector2(LOBBY_X, LOBBY_Y)
	if s[0] == "S":
		return Vector2(773, FEET[int(s[1])])
	return Vector2(CX[s[1]], FEET[int(s[0])])


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

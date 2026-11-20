extends RefCounted
class_name WaGroup
## Grup WhatsApp penghuni: obrolan, gosip, keluhan, dan reaksi atas kejadian di kost.
## Maryam (admin) bisa menanggapi keluhan untuk menambah rasa senang penghuni.

var g
const MAX := 80

const GOSSIP := [
	["Ada yang punya charger type-C? Punyaku rusak", "Aku ada, ambil aja di kamar {r2}.", "Makasih {n2}!"],
	["Siapa yang masak mi tengah malam? Wanginya sampai lantai atas", "Hehe aku, maaf ya.", "Bagi dong lain kali!"],
	["Besok ada yang mau nitip beli gorengan?", "Aku! Bakwan 3 ya.", "Aku tahu isi 2."],
	["WiFi kencang banget hari ini, mantap!", "Iya, nonton drakor lancar jaya."],
	["Ada yang lihat sandal jepit biru? Hilang di depan kamar.", "Kayaknya dipakai kucing kost tidur deh"],
	["Info: galon di dapur udah diganti ya.", "Makasih infonya!"],
	["Selamat pagi semua! Semangat kerja & kuliahnya", "Pagi! Semangat juga!"],
	["Ada yang mau joging bareng sore ini?", "Ikut! Jam 5 di lobi ya."],
	["Mpus (kucing kost) tidur di depan kamarku lagi", "Lucu banget, jangan diusir ya."],
	["Malam ini nonton bola bareng di lobi?", "Gas! Aku bawa kacang.", "Aku bawa kopi sachet."],
	["Siapa yang suka nyanyi di kamar mandi? Suaranya bagus juga", "Ketahuan deh..."],
]
const COMPLAIN := {
	"dirty": ["Mbak Maryam, kamarku udah kotor banget nih", "Tolong kamarku dibersihin dong, Mbak."],
	"broken": ["Mbak, di kamar {r} ada yang rusak: {x}.", "Mbak Maryam, {x} di kamarku belum dibenerin"],
	"bag": ["Pesananku kok belum sampai ya? Udah lapar nih"],
	"event": ["Mbak, ada {x} nih!", "Admin, tolong dicek: {x}."],
}
const REPLY := ["Siap, segera saya tangani!", "Maaf ya, langsung saya urus sekarang.", "Terima kasih infonya, ditunggu sebentar ya!"]


func _init(game) -> void:
	g = game


func list() -> Array:
	if not g.S.has("wa"): g.S.wa = []
	return g.S.wa


func unread() -> int:
	return int(g.S.get("wa_unread", 0))


func post(who: String, text: String, kind := "chat", room := "") -> void:
	var L := list()
	var m := int(g.S.min)
	L.append({"who": who, "t": text, "k": kind, "r": room, "d": int(g.S.day), "h": "%02d:%02d" % [(m / 60) % 24, m % 60], "ok": false})
	while L.size() > MAX: L.pop_front()
	if who != "Maryam": g.S.wa_unread = unread() + 1


func sys(text: String) -> void:
	post("", text, "sys")


func _name(rid: String) -> String:
	var t = g.S.rooms[rid].tenant
	return str(t.name) if t != null else ""


## Obrolan acak tiap jam (dipanggil dari _hourly).
func hourly(h: int) -> void:
	var ten: Array = g.each_tenant()
	if ten.size() < 2 or h < 6 or h > 23: return
	if randf() > 0.12: return
	ten.shuffle()
	var a: String = ten[0][0]
	var b: String = ten[1][0]
	var conv: Array = GOSSIP.pick_random()
	for i in range(conv.size()):
		var rid: String = a if i % 2 == 0 else b
		var txt: String = str(conv[i]).replace("{r2}", D.room_name(a)).replace("{n2}", _name(a))
		post(_name(rid), txt, "chat", rid)


## Keluhan penghuni yang bisa ditanggapi Maryam (tanggapan = penghuni sedikit lebih senang).
func complain(rid: String, kind: String, x := "") -> void:
	var nm := _name(rid)
	if nm == "": return
	# jangan spam: satu keluhan sejenis per kamar yang belum ditanggapi
	for m in list():
		if m.k == "complain" and m.r == rid and not m.ok and m.get("c", "") == kind: return
	var txt: String = str(COMPLAIN[kind].pick_random()).replace("{r}", D.room_name(rid)).replace("{x}", x)
	post(nm, txt, "complain", rid)
	list()[-1].c = kind


func reply(i: int) -> void:
	var L := list()
	if i < 0 or i >= L.size() or L[i].ok: return
	L[i].ok = true
	var rid: String = L[i].r
	post("Maryam", "@%s %s" % [L[i].who, REPLY.pick_random()], "chat")
	var t = g.S.rooms.get(rid, {}).get("tenant") if rid != "" else null
	if t != null and str(t.name) == str(L[i].who):
		t.happy = clampf(float(t.happy) + 3.0, 0, 100)
		post(str(t.name), ["Makasih Mbak Maryam!", "Sip, ditunggu ya Mbak.", "Admin fast response"].pick_random(), "chat", rid)
	g.dirty = true


## Pengecekan harian: kamar kotor / rusak memicu keluhan di grup.
func daily() -> void:
	for e in g.each_tenant():
		var rid: String = e[0]
		var r: Dictionary = e[1]
		if float(r.clean) < 40.0 and randf() < 0.5: complain(rid, "dirty")
		if str(r.broken) != "" and randf() < 0.6: complain(rid, "broken", str(r.broken))

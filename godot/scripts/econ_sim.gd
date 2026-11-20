extends RefCounted
class_name EconSim
## Simulasi ekonomi tanpa layar (alat uji, bukan bagian permainan).
## Bot bermain rakus-wajar: isi kamar, bangun kamar, beli/upgrade perabot, rekrut & upgrade
## karyawan, bangun fasilitas. Mencatat waktu nyata (1x) per level dan jeda antar pembelian.

var g
var S: Dictionary
var steps := 0
var last_buy := 0
var gaps: Array = []          # [level, menit nyata menunggu]
var lv_at := {}
var log_lines: Array = []


func _init(game) -> void:
	g = game
	S = g.S


func real_min() -> float:
	return steps * 0.1 / 60.0


func run(days: int) -> void:
	S.speed = 1
	S.seen = true
	S.tut = -1
	var target := days * 720       # 720 langkah = 1 hari
	var cur_lv := int(S.lvl)
	lv_at[cur_lv] = 0.0
	while steps < target:
		g._step()
		steps += 1
		if steps % 30 == 0: _brain()
		if int(S.lvl) != cur_lv:
			cur_lv = int(S.lvl)
			lv_at[cur_lv] = real_min()
			var L: Dictionary = S.get("last", {})
			var hs := 0.0
			for e in g.each_tenant(): hs += float(e[1].tenant.happy)
			log_lines.append("LV %2d @%6.1f mnt hari %3d uang %s kamar %d huni %d | sewa/hr %s gaji %s util %s lain %s net %s | senang %.0f rating %.1f ev %d antre %d" % [cur_lv, real_min(), int(S.day), D.short(float(S.money)), _built(), g.each_tenant().size(),
				D.short(float(L.get("rent", 0))), D.short(float(L.get("salary", 0))), D.short(float(L.get("util", 0))), D.short(float(L.get("other", 0))), D.short(float(L.get("net", 0))),
				hs / maxf(1, g.each_tenant().size()), float(S.rep), S.events.size(), S.queue.size()])
		if int(S.lvl) >= 25: break
	_report()


func _built() -> int:
	var n := 0
	for id in D.ROOMS:
		if S.rooms[id].built: n += 1
	return n


func _spend(c: float) -> bool:
	if float(S.money) < c: return false
	g.spend(c, "other")
	var gap := (steps - last_buy) * 0.1 / 60.0
	gaps.append([int(S.lvl), gap])
	last_buy = steps
	return true


func _brain() -> void:
	# Pemain menagih sewa (ketuk koin) beberapa kali sehari
	for id in D.ROOMS:
		if float(S.rooms[id].get("due", 0.0)) > 0.0: g.collect_due(id)
	# Isi kamar kosong dengan antrean
	for p in S.queue.duplicate():
		var er: Array = g.empty_rooms()
		if er.is_empty(): break
		g.act("assign", "%s|%s" % [p.id, er[0]])
	# Pekerjaan karyawan disimulasikan langsung (tidak ada NPC berjalan di uji ini)
	var cap_c: int = int(g.staff_cap("cleaner")) if S.staff.get("cleaner", false) else 0
	var cleaned := 0
	for id in D.ROOMS:
		var r: Dictionary = S.rooms[id]
		if not r.built: continue
		if float(r.clean) < 60.0:
			if cleaned < cap_c / 6 + 1 and S.staff.get("cleaner", false):
				r.clean = 100.0
				cleaned += 1
			elif float(S.money) > 15000 and float(r.clean) < 40.0:
				g.spend(15000, "other")
				r.clean = 100.0
		if str(r.broken) != "":
			if S.staff.get("teknisi", false) or float(S.money) > 400000:
				if not S.staff.get("teknisi", false): g.spend(float(D.ISSUES.get(str(r.broken), 200000)), "other")
				r.broken = ""
	for e in S.events.duplicate():
		var ev: Dictionary = Ev.DEF[e.type]
		var o: Array = ev.opts[0]
		if float(S.money) > float(o[1]) * 2.0: g._resolve_event(e, o[2], float(o[1]))
	_buy()


func _buy() -> void:
	var m := float(S.money)
	var reserve: float = float(g._salary_total()) * 2.0 + 100000.0
	# 1) kamar tanpa kasur
	for id in D.ROOMS:
		var r: Dictionary = S.rooms[id]
		if r.built and not r.furn.has("kasur") and g.job_for(id, "deliver", "kasur") == {}:
			if _spend(float(D.FURN.kasur.cost)):
				r.furn["kasur"] = 1
				g.update_tier(r)
			return
	# 2) rekrut karyawan penting
	for k in ["cleaner", "teknisi", "satpam"]:
		if not S.staff.get(k, false) and int(S.lvl) >= int(D.STAFF[k].min) and m > reserve + float(D.STAFF[k].sal) * 10:
			S.staff[k] = true
			gaps.append([int(S.lvl), (steps - last_buy) * 0.1 / 60.0])
			last_buy = steps
			return
	# 2b) karyawan kewalahan -> upgrade dulu (pemain diberi peringatan "mulai kecapekan")
	for k in S.staff:
		if S.staff[k] and not D.STAFF[k].get("owner", false) and int(g.staff_cap(k)) < _built() + 1:
			var uc := float(g.staff_up_cost(k))
			if m - uc >= reserve:
				g.staff_upgrade(k)
				gaps.append([int(S.lvl), (steps - last_buy) * 0.1 / 60.0])
				last_buy = steps
			return
	# 3) pilih pembelian termurah yang berguna
	var opts: Array = []   # [biaya, Callable]
	var free_room := ""
	for id in D.ROOMS:
		if not S.rooms[id].built and g.floor_open(D.fl(id)) and g.job_for(id, "build") == {}:
			free_room = id
			break
	if free_room != "" and g.empty_rooms().is_empty() and S.rooms.values().filter(func(r): return r.built).size() < 6 + int(S.lvl) * 2:
		# Prioritas: kamar penuh -> tabung untuk bangun kamar baru.
		var c := float(g.build_cost())
		if m - c >= reserve:
			g.act("build", free_room)
			gaps.append([int(S.lvl), (steps - last_buy) * 0.1 / 60.0])
			last_buy = steps
		return
	for id in D.ROOMS:
		var r: Dictionary = S.rooms[id]
		if not r.built: continue
		for t in D.FURN_ORDER:
			if int(S.lvl) < int(D.FURN[t].min) or not D.furn_has(id, t): continue
			var lv := int(r.furn.get(t, 0))
			if lv >= 3: continue
			var rr := r
			var tt: String = t
			opts.append([float(D.FURN[t].cost), func():
				g.spend(float(D.FURN[tt].cost), "other")
				rr.furn[tt] = int(rr.furn.get(tt, 0)) + 1
				g.update_tier(rr)])
			break
	for k in D.FACIL_ORDER:
		var fc: Dictionary = D.FACIL[k]
		if int(S.lvl) < int(fc.lv) or g.facil_count(k) > 0: continue
		var ff: int = g.free_facil_floor()
		if ff == 0: break
		var kk: String = k
		opts.append([float(fc.cost), func():
			g.act("facil_build", "%d|%s" % [ff, kk])
			if fc.has("staff"): S.staff[fc.staff] = true])
		break
	for k in D.FAC:
		if not S.fac.has(k) and int(S.lvl) >= int(D.FAC[k].min):
			var kf: String = k
			opts.append([float(D.FAC[k].cost), func(): g.act("buy_fac", kf)])
	for k in S.staff:
		if S.staff[k] and not D.STAFF[k].get("owner", false) and g.staff_lv(k) < int(S.lvl):
			var kk2: String = k
			opts.append([g.staff_up_cost(k), func(): g.staff_upgrade(kk2)])
	if opts.is_empty(): return
	opts.sort_custom(func(a, b): return a[0] < b[0])
	var best: Array = opts[0]
	if m - float(best[0]) < reserve: return
	if best[1] is Callable:
		# act() untuk build/facil memotong uang sendiri; selain itu potong di sini.
		best[1].call()
		gaps.append([int(S.lvl), (steps - last_buy) * 0.1 / 60.0])
		last_buy = steps


func _report() -> void:
	print("ECON ===== hasil simulasi (%.0f menit nyata, hari %d) =====" % [real_min(), int(S.day)])
	for l in log_lines: print("ECON ", l)
	var per := {}
	for gp in gaps:
		var L: int = gp[0]
		if not per.has(L): per[L] = []
		per[L].append(gp[1])
	for L in per.keys():
		var a: Array = per[L]
		var mx := 0.0
		var sm := 0.0
		for x in a:
			mx = maxf(mx, x)
			sm += x
		print("ECON jeda beli Lv %2d: %3d pembelian, rata2 %.1f mnt, terlama %.1f mnt" % [L, a.size(), sm / a.size(), mx])
	print("ECON akhir: uang %s, Lv %d, kamar %d, penghuni %d, rating %.1f" % [D.short(float(S.money)), int(S.lvl), _built(), g.each_tenant().size(), float(S.rep)])

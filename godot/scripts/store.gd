class_name Store
extends Node
## Pembelian Diamond lewat Google Play Billing (plugin GodotGooglePlayBilling).
## Alur: beli -> Google Play -> token dikirim ke server verifikasi -> server cek ke Google Play
## Developer API & catat token (anti dipakai ulang) -> Diamond ditambah -> pembelian di-consume.
## Diamond TIDAK pernah ditambah tanpa jawaban "ok" dari server.

## URL Cloud Function verifikasi (lihat server/functions/index.js). Ganti setelah deploy.
const VERIFY_URL := "https://asia-southeast2-cozy-kost.cloudfunctions.net/verifyCozyPurchase"
## Kunci sederhana agar endpoint tidak dipanggil sembarangan (bukan pengganti verifikasi Google).
const CLIENT_KEY := "cozykost-android-v1"

const PRODUCTS := {"diamond_60": 60, "diamond_330": 330, "diamond_700": 700}

signal changed

var game: Node
var billing: BillingClient
var prices := {}            # product_id -> "Rp 15.000" (harga lokal dari Google Play)
var _busy := {}             # purchase_token -> true (sedang diverifikasi)
var status := ""


func setup(g: Node) -> void:
	game = g
	if not available(): return
	billing = BillingClient.new()
	add_child(billing)
	billing.connected.connect(_on_connected)
	billing.disconnected.connect(func(): status = "Terputus dari Google Play"; changed.emit())
	billing.connect_error.connect(func(code: int, msg: String): status = "Google Play belum siap (%d)" % code; changed.emit())
	billing.query_product_details_response.connect(_on_details)
	billing.query_purchases_response.connect(_on_purchases)
	billing.on_purchase_updated.connect(_on_purchases)
	billing.consume_purchase_response.connect(_on_consumed)
	billing.set_obfuscated_account_id(account_id())
	billing.start_connection()


## Hanya di aplikasi Android yang memuat plugin billing.
static func available() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton("GodotGooglePlayBilling")


func ready_to_buy() -> bool:
	return billing != null and billing.is_ready() and not prices.is_empty()


## ID acak per instalasi (disimpan di dompet), ikut dikirim ke Google & server.
func account_id() -> String:
	var W: Dictionary = game.W
	if str(W.get("uid", "")) == "":
		var c := Crypto.new()
		W.uid = c.generate_random_bytes(16).hex_encode()
		game.save_wallet()
	return str(W.uid)


func price(pid: String, fallback: String) -> String:
	return str(prices.get(pid, fallback))


func buy(pid: String) -> void:
	if not ready_to_buy():
		game.ui.toast("Google Play belum siap. Coba lagi sebentar.", "bad")
		if billing: billing.start_connection()
		return
	var r: Dictionary = billing.purchase(pid)
	if int(r.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		game.ui.toast("Tidak bisa membuka pembayaran (%s)" % str(r.get("debug_message", r.get("response_code", "?"))), "bad")


func _on_connected() -> void:
	status = ""
	billing.query_product_details(PackedStringArray(PRODUCTS.keys()), BillingClient.ProductType.INAPP)
	# Pembelian yang belum selesai (mis. aplikasi tertutup sebelum verifikasi) diproses ulang.
	billing.query_purchases(BillingClient.ProductType.INAPP)


func _on_details(res: Dictionary) -> void:
	if int(res.get("response_code", -1)) != BillingClient.BillingResponseCode.OK: return
	for d in res.get("product_details", []):
		var offers = d.get("one_time_purchase_offer_details_list")
		if offers is Array and offers.size() > 0:
			prices[str(d.product_id)] = str(offers[0].get("formatted_price", ""))
	changed.emit()


func _on_purchases(res: Dictionary) -> void:
	var code := int(res.get("response_code", -1))
	if code == BillingClient.BillingResponseCode.USER_CANCELED:
		game.ui.toast("Pembelian dibatalkan.")
		return
	if code != BillingClient.BillingResponseCode.OK: return
	for p in res.get("purchases", []):
		var pid := ""
		for x in p.get("product_ids", []):
			if PRODUCTS.has(str(x)): pid = str(x)
		if pid == "": continue
		match int(p.get("purchase_state", 0)):
			BillingClient.PurchaseState.PURCHASED:
				_verify(pid, p)
			BillingClient.PurchaseState.PENDING:
				game.ui.toast("Pembayaran %s masih menunggu. Diamond masuk setelah pembayaran selesai." % pid.replace("diamond_", "") + " Diamond")


func _verify(pid: String, p: Dictionary) -> void:
	var token := str(p.get("purchase_token", ""))
	if token == "" or _busy.has(token): return
	_busy[token] = true
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		_busy.erase(token)
		var data = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS else null
		if code == 200 and data is Dictionary and data.get("ok", false):
			var n := int(data.get("diamonds", 0))
			if n > 0:
				game.W.diamonds = int(game.W.diamonds) + n
				game.save_wallet()
				game.sfx("buy")
				game.ui.toast("+%d Diamond masuk! Terima kasih sudah mendukung Cozy Kost." % n, "gold")
			billing.consume_purchase(token)
			changed.emit()
		elif data is Dictionary and str(data.get("reason", "")) == "already_granted":
			billing.consume_purchase(token)   # sudah pernah diberikan; selesaikan di Google Play
		elif data is Dictionary and str(data.get("reason", "")) == "invalid":
			game.ui.toast("Pembelian tidak valid menurut Google Play.", "bad")
		else:
			# Jaringan/server bermasalah: pembelian TIDAK di-consume, dicoba lagi saat aplikasi dibuka.
			game.ui.toast("Pembayaran berhasil, tapi verifikasi tertunda. Diamond masuk otomatis saat online.", "bad"))
	var payload := {"packageName": "com.kelolapro.cozykost", "productId": pid, "purchaseToken": token,
		"orderId": str(p.get("order_id", "")), "accountId": account_id()}
	var err := http.request(VERIFY_URL, ["Content-Type: application/json", "X-Client-Key: " + CLIENT_KEY], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http.queue_free()
		_busy.erase(token)


func _on_consumed(_res: Dictionary) -> void:
	changed.emit()

/**
 * Cozy Kost - verifikasi pembelian Diamond (Google Play Billing).
 *
 * Aplikasi mengirim { packageName, productId, purchaseToken, orderId, accountId }.
 * Fungsi ini:
 *  1. Mengecek token langsung ke Google Play Developer API (purchases.products.get).
 *  2. Memastikan statusnya "purchased", produknya dikenal, dan accountId cocok
 *     (obfuscatedExternalAccountId yang diset aplikasi saat membeli).
 *  3. Mencatat token di Firestore dalam transaksi -> satu token hanya bisa ditukar sekali.
 *  4. Mengembalikan jumlah Diamond. Aplikasi baru menambah Diamond setelah jawaban ok.
 */
const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { google } = require("googleapis");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

const PACKAGE = "com.kelolapro.cozykost";
const CLIENT_KEY = "cozykost-android-v1";
const PRODUCTS = { diamond_60: 60, diamond_330: 330, diamond_700: 700 };

const auth = new google.auth.GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/androidpublisher"],
});
const publisher = google.androidpublisher({ version: "v3", auth });

exports.verifyCozyPurchase = onRequest(
  { region: "asia-southeast2", maxInstances: 10, timeoutSeconds: 30 },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ ok: false, reason: "method" });
    if (req.get("X-Client-Key") !== CLIENT_KEY) return res.status(403).json({ ok: false, reason: "key" });

    const { packageName, productId, purchaseToken, orderId, accountId } = req.body || {};
    if (packageName !== PACKAGE || !PRODUCTS[productId] || typeof purchaseToken !== "string" ||
        purchaseToken.length < 20 || purchaseToken.length > 4096) {
      return res.status(400).json({ ok: false, reason: "bad_request" });
    }

    // 1) Tanya Google Play.
    let p;
    try {
      const r = await publisher.purchases.products.get({ packageName, productId, token: purchaseToken });
      p = r.data;
    } catch (e) {
      const code = e.code || (e.response && e.response.status);
      logger.warn("Google Play menolak token", { productId, code, msg: e.message });
      if (code === 400 || code === 404 || code === 410) return res.status(400).json({ ok: false, reason: "invalid" });
      return res.status(502).json({ ok: false, reason: "google_unavailable" });
    }

    // purchaseState: 0 = dibeli, 1 = dibatalkan, 2 = pending
    if (p.purchaseState !== 0) return res.status(400).json({ ok: false, reason: p.purchaseState === 2 ? "pending" : "invalid" });
    if (p.obfuscatedExternalAccountId && accountId && p.obfuscatedExternalAccountId !== accountId) {
      logger.warn("accountId tidak cocok", { productId, orderId: p.orderId });
      return res.status(400).json({ ok: false, reason: "invalid" });
    }

    // 2) Satu token = satu kali hadiah (transaksi Firestore).
    const id = crypto.createHash("sha256").update(purchaseToken).digest("hex");
    const ref = db.collection("cozykost_purchases").doc(id);
    const diamonds = PRODUCTS[productId];
    try {
      const fresh = await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (snap.exists) return false;
        tx.set(ref, {
          productId,
          diamonds,
          orderId: p.orderId || orderId || "",
          accountId: accountId || "",
          purchaseTimeMillis: Number(p.purchaseTimeMillis || 0),
          test: p.purchaseType === 0, // 0 = pembelian uji (license tester)
          grantedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (!fresh) return res.status(409).json({ ok: false, reason: "already_granted" });
    } catch (e) {
      logger.error("Firestore gagal", e);
      return res.status(500).json({ ok: false, reason: "db" });
    }

    logger.info("Diamond diberikan", { productId, diamonds, orderId: p.orderId });
    return res.status(200).json({ ok: true, diamonds, productId });
  }
);

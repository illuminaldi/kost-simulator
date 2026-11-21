/**
 * Cozy Kost - verifikasi pembelian Diamond (Google Play Billing) di Cloudflare Workers (gratis).
 *
 * Aplikasi mengirim { packageName, productId, purchaseToken, orderId, accountId }.
 * Worker ini:
 *  1. Mengecek token langsung ke Google Play Developer API (purchases.products.get),
 *     memakai service account Google (secret GOOGLE_SA_JSON).
 *  2. Memastikan statusnya "purchased", produknya dikenal, dan accountId cocok
 *     (obfuscatedExternalAccountId yang diset aplikasi saat membeli).
 *  3. Meng-consume pembelian langsung di Google Play -> satu token hanya bisa ditukar sekali
 *     (pembelian yang sudah di-consume ditolak sebagai "already_granted"). Tidak butuh database.
 *  4. Mengembalikan jumlah Diamond. Aplikasi baru menambah Diamond setelah jawaban ok.
 */
const PACKAGE = "kelolapro.cozykost";
const CLIENT_KEY = "cozykost-android-v1";
const PRODUCTS = { diamond_60: 60, diamond_330: 330, diamond_700: 700 };

const json = (status, body) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

const b64url = (buf) =>
  btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const b64urlStr = (s) => b64url(new TextEncoder().encode(s));

// Token akses Google (OAuth2 JWT bearer) dari service account; disimpan sementara di memori.
let cached = { token: "", exp: 0 };
async function googleToken(env) {
  const now = Math.floor(Date.now() / 1000);
  if (cached.token && cached.exp - 60 > now) return cached.token;
  const sa = JSON.parse(env.GOOGLE_SA_JSON);
  const header = b64urlStr(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64urlStr(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claim}`));
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${header}.${claim}.${b64url(sig)}`,
  });
  const t = await r.json();
  if (!r.ok || !t.access_token) throw new Error("google_auth: " + JSON.stringify(t));
  cached = { token: t.access_token, exp: now + (t.expires_in || 3600) };
  return cached.token;
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (req.method === "GET" && url.pathname === "/") return json(200, { ok: true, service: "cozy-kost-verify" });
    if (req.method !== "POST") return json(405, { ok: false, reason: "method" });
    if (req.headers.get("X-Client-Key") !== CLIENT_KEY) return json(403, { ok: false, reason: "key" });

    let body;
    try { body = await req.json(); } catch { return json(400, { ok: false, reason: "bad_request" }); }
    const { packageName, productId, purchaseToken, orderId, accountId } = body || {};
    if (packageName !== PACKAGE || !PRODUCTS[productId] || typeof purchaseToken !== "string" ||
        purchaseToken.length < 20 || purchaseToken.length > 4096) {
      return json(400, { ok: false, reason: "bad_request" });
    }

    // 1) Tanya Google Play.
    const api = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/purchases/products/${productId}/tokens/${encodeURIComponent(purchaseToken)}`;
    let p, at;
    try {
      at = await googleToken(env);
      const r = await fetch(api, { headers: { Authorization: `Bearer ${at}` } });
      if (r.status === 400 || r.status === 404 || r.status === 410) return json(400, { ok: false, reason: "invalid" });
      if (!r.ok) {
        console.warn("Google Play error", r.status, await r.text());
        return json(502, { ok: false, reason: "google_unavailable" });
      }
      p = await r.json();
    } catch (e) {
      console.error(e);
      return json(502, { ok: false, reason: "google_unavailable" });
    }

    // purchaseState: 0 = dibeli, 1 = dibatalkan, 2 = pending
    if (p.purchaseState !== 0) return json(400, { ok: false, reason: p.purchaseState === 2 ? "pending" : "invalid" });
    if (p.obfuscatedExternalAccountId && accountId && p.obfuscatedExternalAccountId !== accountId) {
      return json(400, { ok: false, reason: "invalid" });
    }

    // 2) Satu token = satu kali hadiah: sudah di-consume berarti sudah pernah ditukar.
    if (p.consumptionState === 1) return json(409, { ok: false, reason: "already_granted" });
    const c = await fetch(`${api}:consume`, { method: "POST", headers: { Authorization: `Bearer ${at}` } });
    if (!c.ok) {
      console.warn("consume gagal", c.status, await c.text());
      // Kemungkinan permintaan lain sudah meng-consume lebih dulu.
      return json(409, { ok: false, reason: "already_granted" });
    }
    const diamonds = PRODUCTS[productId];
    console.log("Diamond diberikan", productId, diamonds, p.orderId || orderId || "", p.purchaseType === 0 ? "(uji)" : "");
    return json(200, { ok: true, diamonds, productId });
  },
};

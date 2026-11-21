# Cozy Kost — Panduan Rilis Android (Google Play)

Package: `kelolapro.cozykost` · Target API 36 · min API 24 · format AAB (gradle build).

## 1. Sekali saja di komputer build

1. Godot 4.7 + **Android export templates** (Editor > Manage Export Templates).
2. Android SDK (platform 36, build-tools, cmdline-tools) + **JDK 17**. Isi path-nya di
   Editor Settings > Export > Android.
3. Buka proyek > **Project > Install Android Build Template** (membuat folder `android/`).
4. **Plugin billing**: unduh rilis `GodotGooglePlayBilling` 3.3.0 dari
   https://github.com/godot-sdk-integrations/godot-google-play-billing/releases, lalu salin
   **hanya** isi `bin/` ke `addons/GodotGooglePlayBilling/bin/`
   (`debug/GodotGooglePlayBilling-debug.aar` dan `release/GodotGooglePlayBilling-release.aar`).
   Skrip addon (`BillingClient.gd`, `export_plugin.gd`, `plugin.cfg`) sudah ada dan plugin sudah aktif.
5. **Keystore rilis** (SIMPAN & BACKUP, jangan di-commit):
   ```
   keytool -genkeypair -v -keystore cozykost-release.keystore -alias cozykost \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
   Isi lewat environment variable supaya password tidak tersimpan di proyek:
   ```
   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/cozykost-release.keystore
   export GODOT_ANDROID_KEYSTORE_RELEASE_USER=cozykost
   export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=********
   ```
   Di Play Console aktifkan **Play App Signing** (keystore ini jadi *upload key*).

## 2. Build

```
godot --headless --path . --export-release "Android" build/android/CozyKost.aab
```
Naikkan `version/code` (1, 2, 3, …) di export_presets.cfg setiap upload baru.

## 3. Play Console

1. Buat aplikasi "Cozy Kost", kategori **Game > Simulasi**, gratis, berisi pembelian dalam aplikasi.
2. **Produk dalam aplikasi** (Monetize > Products > In-app products), tipe consumable:
   | ID | Isi | Harga saran |
   |---|---|---|
   | `diamond_60` | 60 Diamond | Rp 15.000 |
   | `diamond_330` | 330 Diamond | Rp 75.000 |
   | `diamond_700` | 700 Diamond | Rp 150.000 |
3. **License testing**: tambahkan email penguji supaya bisa beli tanpa ditagih.
4. Isi **Data safety**, **Content rating (IARC)**, **Target audience: 13+**, **Privacy policy URL**
   (teks ada di `store/privacy_policy.md`), dan listing toko dari folder `store/`.
5. Upload AAB ke Internal testing → Closed testing (12 tester × 14 hari kalau akun personal baru) → Production.

## 4. Server verifikasi pembelian (wajib sebelum jual Diamond)

Kode di `server/` (Firebase Cloud Functions, Node 20).

1. Proyek Firebase (paket **Blaze**), aktifkan **Firestore** dan
   **Google Play Android Developer API** di Google Cloud Console proyek yang sama.
2. Deploy:
   ```
   cd server/functions && npm install && cd ..
   firebase deploy --only functions,firestore:rules --project <PROJECT_ID>
   ```
3. Ambil email service account fungsi (biasanya `<PROJECT_NUMBER>-compute@developer.gserviceaccount.com`),
   lalu di Play Console > **Users and permissions** undang email itu dengan izin
   *View app information*, *View financial data* dan *Manage orders and subscriptions* untuk aplikasi Cozy Kost.
   (Izin baru bisa butuh beberapa jam sampai aktif.)
4. Salin URL fungsi `verifyCozyPurchase` ke `VERIFY_URL` di `scripts/store.gd`, lalu build ulang.

Cara kerja: aplikasi tidak pernah menambah Diamond sendiri. Token pembelian dikirim ke server,
server mengecek ke Google Play, mencatat token di Firestore (`cozykost_purchases`, satu token = satu kali),
baru aplikasi menambah Diamond dan meng-*consume* pembelian. Kalau jaringan putus, pembelian tidak di-consume
dan diproses ulang otomatis saat aplikasi dibuka lagi.

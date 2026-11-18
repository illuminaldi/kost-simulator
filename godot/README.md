# Kost Simulator (Godot 4.7)

Game simulasi juragan kost bergaya cozy. Kelola kamar, terima penyewa, rekrut karyawan, dan lihat setiap NPC menjalani rutinitasnya: datang mengantre, naik tangga ke kamar, berangkat kuliah atau kerja, pulang, santai, lalu tidur.

## Menjalankan

1. Pasang **Godot 4.7** (versi standar, bukan .NET).
2. Buka Godot, klik **Import**, lalu pilih file `project.godot` di folder ini.
3. Tekan **F5** untuk main. Jendela desktop berukuran 430×770 (rasio HP potret).

Progress tersimpan otomatis di `user://kost_save.json`. Di Android lokasinya ada di folder data aplikasi.

## Ekspor ke Android (APK)

1. Pasang template ekspor lewat **Editor → Manage Export Templates → Download and Install**.
2. Pasang **JDK 17** dan **Android SDK**, lalu isi path-nya di **Editor Settings → Export → Android**.
3. Buka **Project → Export → Android**. Ganti `package/unique_name` (sekarang masih `com.example.kostsimulator`) dengan ID paketmu sendiri.
4. Klik **Export Project**. Untuk debug, Godot memakai debug keystore otomatis.
5. Untuk rilis ke Play Store dalam format AAB: aktifkan `gradle_build/use_gradle_build`, jalankan **Project → Install Android Build Template**, isi release keystore, lalu ekspor sebagai AAB.

Preset **Web** juga tersedia, sudah diset tanpa thread supaya bisa jalan di hosting biasa tanpa header COOP/COEP.

## Struktur

```
project.godot          konfigurasi (viewport 1438×2576 = ukuran ilustrasi, renderer Compatibility)
main.tscn              scene utama (Node2D + game.gd)
assets/kost-art.jpg    ilustrasi kost tanpa karakter (karakter dihapus agar NPC bisa bergerak)
assets/fonts/          Fredoka (SIL OFL)
scripts/data.gd        semua angka & koordinat: kamar, titik duduk/tidur, lampu, harga, pekerjaan, staf
scripts/game.gd        loop waktu, ekonomi, otak NPC, cahaya siang/malam, input, aksi
scripts/npc.gd         satu NPC: jalan, pindah lantai (fade lewat tangga), duduk, tidur, kerja
scripts/spr.gd         pembuat sprite karakter dari SVG (dirender Godot jadi tekstur, di-cache)
scripts/room_fx.gd     lapisan tiap kamar: sketsa "rencana", label Kamar Kosong, papan Bangun, debu, lencana
scripts/ui.gd          HUD, bar navigasi, toast, dan semua panel menu
```

Koordinat di semua skrip memakai piksel ilustrasi asli (1438×2576), jadi posisi di game sama persis dengan posisi di gambar.

## Gameplay hold & drop

- **Tamu:** tahan calon penyewa di lobi, lalu seret ke kamar. Kamar yang bisa ditempati disorot hijau, yang tidak bisa disorot merah. Ketuk tanpa menyeret untuk membuka daftar antrean.
- **Perabot:** tombol **Upgrade** membuka mode Dekor. Seret perabot (kasur, lampu, tanaman, karpet, hiasan, rak, meja) ke kamar. Selama diseret, pratinjau transparan muncul di posisinya.
- **Upgrade perabot:** seret perabot yang sama ke kamar yang sudah punya perabot itu. Levelnya naik dari Biasa ke Bagus lalu Mewah, dengan harga x1, x2, x3.
- **Tambah kamar:** seret kartu **Kamar Baru** ke lahan kosong yang lantainya sudah terbuka.
- **Kenyamanan:** total nilai perabot menentukan tier kamar (Standar, Nyaman, Premium) dan harga sewa. Kamar wajib punya kasur sebelum bisa disewa. Lampu kamar hanya menyala kalau ada perabot lampu.

Posisi tiap perabot per kamar ada di `D.FURN_POS` (`data.gd`), dan sprite-nya ada di `assets/furn/`.

## Gedung, pekerja & pickup

- **Gedung punya 8 lantai** dan bisa digeser naik-turun. Lobi tetap di tempat. Lantai 5–8 terbuka di Level 5–8 (tata letak kamarnya menyalin lantai 3).
- **Bangun kamar:** tukang datang dan membangun selama 4 jam game. Selama itu lahannya bertanda "Sedang Dibangun".
- **Perbaikan:** teknisi datang ke kamar yang rusak (1,5 jam game).
- **Perabot:** setelah dibeli atau di-upgrade, pickup parkir di lobi dan kurir mengantar barangnya ke kamar. Perabot baru terpasang setelah kurir sampai.
- Semua pekerjaan ini disimpan di `S.jobs`, dan durasinya diatur di `D.WORKER` (`data.gd`).

## Cara kerja NPC

- **Calon penyewa** datang dari kiri, berjalan ke posisi antrean di lobi, dan menampilkan balon nama. Kalau diterima, mereka naik ke kamar. Kalau ditolak atau kelamaan menunggu, mereka pergi.
- **Penghuni** mengikuti jam kerja di `data.gd` (`JOBS.away`). Saat jam keluar, mereka turun dan meninggalkan kost. Mereka pulang setelah jam kerja selesai, duduk santai atau kerja di kamar, lalu tidur pukul 22.00–06.00.
- **Karyawan:**
  - Petugas kebersihan mendatangi kamar kotor dan menyapu sampai bersih.
  - Teknisi mendatangi kamar rusak dan memperbaikinya.
  - Satpam berpatroli di lobi.
  - Resepsionis berjaga di meja depan.
- **Rute** antarlantai dihitung lewat graf `lobby → S1 → S2 → S3 → S4 → kamar` (`D.EDGES`). Saat pindah scene, NPC menghilang lalu muncul lagi di tujuan (efek naik tangga).
- **Malam hari** memakai `CanvasModulate` dan lampu `PointLight2D` sungguhan. Lampu kamar hanya menyala kalau penghuninya ada di kamar.

## Mengubah tampilan

- **Ganti ilustrasi:** timpa `assets/kost-art.jpg`. Kalau tata letaknya berubah, sesuaikan `COLS`, `ROWS`, `FEET`, `SPOT`, dan `LAMPS` di `data.gd`.
- **Ganti karakter:** ubah palet di `data.gd` (`SKINS`, `SHIRTS`, dll.) atau bentuknya di `spr.gd`. Kalau kamu punya sprite sheet buatan tangan, cukup ganti isi `Spr.tex()` supaya mengembalikan frame dari sprite sheet. Sisa sistem tidak perlu diubah.

## Mode uji (opsional)

Argumen setelah `--` saat menjalankan dari terminal:

```
godot --path . -- --fresh --play --at=19:30 --speed=3 --staff --wait=10 --shot=hasil.png
godot --headless --path . --quit-after 4000 -- --fresh --selftest
```

- `--fresh`: mulai baru tanpa memuat save.
- `--at`: set jam.
- `--staff`: rekrut semua karyawan dan buat kamar kotor/rusak.
- `--shot`: simpan screenshot lalu keluar.
- `--selftest`: jalankan semua aksi game sekali.

## Catatan

- Karakter asli di ilustrasi dihapus dengan inpainting (model LaMa) supaya NPC bisa bergerak bebas. Lantai lobi masih menyisakan sedikit noda samar. Kalau mau benar-benar bersih, lukis ulang bagian itu atau minta ilustrasi versi tanpa orang.
- Teks di game sengaja tidak memakai emoji supaya tampil sama di Android, desktop, dan web.
- Font Fredoka berlisensi SIL Open Font License (lihat `assets/fonts/OFL-Fredoka.txt`).

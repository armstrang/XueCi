# XueCi Mandarin

Aplikasi belajar kosakata HSK 1–6 (silabus HSK 3.0, terbit November 2025) bergaya *Liquid Glass*: daftar kata, kartu hafalan, kuis, dan progres pemahaman per kata (20 tingkat, dari merah ke hijau). Tersedia dalam bahasa Indonesia, English, ไทย, dan Tiếng Việt, dengan tema terang, gelap, dan true black. Berjalan sepenuhnya offline.

by Armstrang

## Pasang di Android

1. Buka halaman **[Releases](../../releases/latest)** dari HP.
2. Unduh `XueCiMandarin.apk`.
3. Buka file itu. Jika diminta, izinkan "Instal aplikasi tidak dikenal" untuk browser atau file manager yang dipakai.

Versi baru dipasang dengan cara yang sama, langsung di atas versi sebelumnya. Progres belajar tidak hilang.

**Pindah dari versi lama (v1.2 atau sebelumnya).** Mulai v1.3 aplikasinya memakai nama paket baru (`com.armstrang.xueci`), jadi terpasang sebagai aplikasi terpisah.
Untuk memindahkan progres: perbarui aplikasi lama ke v1.2, buka **Statistik → Cadangkan → Salin**, lalu di aplikasi baru buka **Statistik → Pulihkan → Tempel → Periksa kode → Ganti progres**.
Setelah itu aplikasi lama boleh di-uninstall.

## Struktur

- `web/src/` — sumber halaman aplikasi: `base.css.html` (tata letak), `app.html` (tampilan + logika), `i18n.js` (teks antarmuka 4 bahasa), `glass.css.html` dan `glass.js.html` (tampilan dan interaksi Liquid Glass).
- `web/data/vocab.json` — kosakata HSK 1–6 beserta arti dan contoh kalimat dalam 4 bahasa (satu kata per baris).
- `web/build.py` — menggabungkan semuanya menjadi satu file HTML di `app/src/main/assets/index.html`.
- `app/` — aplikasi Android (satu layar WebView yang memuat halaman tadi).
- `tests/smoke.py` — uji otomatis halaman aplikasi di browser (`python3 tests/smoke.py`).
- `art/` — gambar ikon; `docs/play-store.md` — rencana rilis di Google Play.

Setelah mengubah sesuatu di `web/`, jalankan `python3 web/build.py`. GitHub Actions juga menjalankannya di setiap push ke `main`, lalu membangun APK dan menerbitkannya di Releases (v1.0, v1.1, …).
APK ditandatangani dengan kunci di `keystore/` supaya setiap versi bisa memperbarui versi sebelumnya.

## Sumber data

Daftar kata dan pinyin dari [harukicoder/hsk30](https://github.com/harukicoder/hsk30). Arti, contoh kalimat, dan terjemahannya ditulis oleh Claude.

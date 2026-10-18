# XueCi Mandarin

Aplikasi belajar kosakata HSK 1–6 (silabus HSK 3.0, terbit November 2025) bergaya *Liquid Glass*: daftar kata, kartu hafalan dengan cek kilat, kuis terarah, simulasi ujian, dan progres pemahaman per kata (20 tingkat, dari merah ke hijau). Aplikasi menyusun rencana harian dari tujuan belajarmu (target level dan tanggal, ujian HSK, atau tanpa target) dengan model memori [FSRS](https://github.com/open-spaced-repetition) yang disesuaikan dengan pola ingatanmu. Level ditentukan lewat tes dan ditampilkan sebagai ranah kultivasi (凡人 → 炼气 → … → 飞升): tes penempatan adalah pintu masuk, setelah itu ranah hanya naik lewat terobosan *雷劫* (beberapa sambaran: arti, ketik pinyin, dengar, kalimat, kecepatan) yang menentukan mutu fondasi (道基), dan ranah bisa goyah kalau kata di bawahnya mulai pudar. Ada juga halaman *Lautan Jiwa* (bola jaringan kata dan lima elemen), ujian harian, serta jeda istirahat dan hari meditasi, karena istirahat juga bagian dari belajar. Semua perhitungan dilakukan di HP. Tersedia dalam bahasa Indonesia, English, ไทย, dan Tiếng Việt, dengan tema terang, gelap, dan true black. Berjalan sepenuhnya offline.

Apa yang berubah di setiap versi ada di [CHANGELOG.md](CHANGELOG.md).

by Armstrang

## Pasang di Android

1. Buka halaman **[Releases](../../releases/latest)** dari HP.
2. Unduh `XueCiMandarin.apk`.
3. Buka file itu. Jika diminta, izinkan "Instal aplikasi tidak dikenal" untuk browser atau file manager yang dipakai.

Versi baru dipasang dengan cara yang sama, langsung di atas versi sebelumnya. Progres belajar tidak hilang.

**Pindah dari versi lama (v1.2 atau sebelumnya).** Mulai v1.3 aplikasinya memakai nama paket baru (`com.armstrang.xueci`), jadi terpasang sebagai aplikasi terpisah.
Untuk memindahkan progres: perbarui aplikasi lama ke v1.2, buka **Statistik → Cadangkan → Salin**, lalu di aplikasi baru ketuk **Cadangan** (di Home, di samping tombol warna nada) **→ Pulihkan → Tempel → Periksa kode → Ganti progres**.
Setelah itu aplikasi lama boleh di-uninstall.

## Struktur

- `web/src/` — sumber halaman aplikasi: `base.css.html` (tata letak), `app.html` (tampilan), `app/*.js` (logika aplikasi, satu file per layar atau fitur), `store.js` (penyimpanan progres: IndexedDB dengan nomor versi skema dan migrasi), `boot.js` (memuat data kata lalu menjalankan aplikasi), `learn.js` (mesin belajar: model memori, riwayat jawaban, rencana harian, pemilihan soal, ranah, angka istirahat), `soul.js` (bola jiwa dan cincin lima elemen), `i18n.js`, `i18n-app.js` dan `i18n-learn.js` (teks antarmuka 4 bahasa), `glass.css.html` dan `glass.js` (tampilan dan interaksi Liquid Glass). Kode JavaScript dirapikan dengan Prettier (`.prettierrc.json`).
- `web/data/vocab.json` — kosakata beserta arti dan contoh kalimat dalam 4 bahasa (satu kata per baris). Saat build dipecah menjadi `data/core.json` (hanzi, pinyin, contoh, level) dan satu file arti per bahasa, yang dimuat hanya saat bahasanya dipakai.
- `web/tools/` — `sentence_pinyin.py` (pinyin contoh kalimat) dan `word_freq.py` (frekuensi kata dan jenis kata dari kamus jieba).
- `web/build.py` — menggabungkan sumbernya menjadi `app/src/main/assets/index.html` plus file data di `app/src/main/assets/data/`.
- `app/` — aplikasi Android (satu layar WebView yang memuat halaman tadi).
- `tests/smoke.py` — uji otomatis halaman aplikasi di browser (`python3 tests/smoke.py`); `tests/engine.js` — uji mesin belajar dan migrasi data di Node (`node tests/engine.js`).
- `store/` — bahan halaman Google Play: teks (`listing.md`), screenshot, dan feature graphic (`python3 store/make_store_assets.py` membuatnya ulang).
- `art/` — gambar ikon (`python3 art/make_icons.py` membuat semua ukuran ikon dari `art/icon-source.jpg`); `docs/play-store.md` — rencana rilis di Google Play.

Setelah mengubah sesuatu di `web/`, jalankan `python3 web/build.py`. GitHub Actions juga menjalankannya di setiap push ke `main`, menjalankan kedua uji otomatis (APK hanya dibuat kalau semuanya lulus), lalu membangun APK dan menerbitkannya di Releases (v1.0, v1.1, …) dengan catatan rilis dari bagian versinya di `CHANGELOG.md`.
APK ditandatangani dengan kunci di `keystore/` supaya setiap versi bisa memperbarui versi sebelumnya.

## Sumber data

Daftar kata dan pinyin dari [harukicoder/hsk30](https://github.com/harukicoder/hsk30). Arti, contoh kalimat, dan terjemahannya ditulis oleh Claude.
Pinyin kalimat dibuat dengan [pypinyin](https://github.com/mozillazg/python-pinyin) dan [jieba](https://github.com/fxsjy/jieba); frekuensi dan jenis kata (untuk tingkat kesulitan kata) dari kamus jieba (`dict.txt`). Keduanya berlisensi MIT.

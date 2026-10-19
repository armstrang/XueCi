# XueCi Mandarin

Aplikasi belajar kosakata HSK 1–6 (silabus HSK 3.0, terbit November 2025) bergaya *Liquid Glass*: daftar kata, kartu hafalan dengan cek kilat, kuis terarah, simulasi ujian, dan progres pemahaman per kata (20 tingkat, dari merah ke hijau). Aplikasi menyusun rencana harian dari tujuan belajarmu (target level dan tanggal, ujian HSK, atau tanpa target) dengan model memori [FSRS](https://github.com/open-spaced-repetition) yang disesuaikan dengan pola ingatanmu. Level ditentukan lewat tes dan ditampilkan sebagai ranah kultivasi (凡人 → 炼气 → … → 飞升): tes penempatan adalah pintu masuk, setelah itu ranah hanya naik lewat terobosan *雷劫* (beberapa sambaran: arti, ketik pinyin, dengar, kalimat, kecepatan) yang menentukan mutu fondasi (道基), dan ranah bisa goyah kalau kata di bawahnya mulai pudar. Ada juga halaman *Lautan Jiwa* (bola jaringan kata dan lima elemen), ujian harian, serta jeda istirahat dan hari meditasi, karena istirahat juga bagian dari belajar. Semua perhitungan dilakukan di HP. Tersedia dalam bahasa Indonesia, English, ไทย, dan Tiếng Việt, dengan tema terang, gelap, dan true black. Berjalan sepenuhnya offline.

Apa yang berubah di setiap versi ada di [CHANGELOG.md](CHANGELOG.md).

by Armstrang

## Pasang di Android

1. Buka halaman **[Releases](../../releases/latest)** dari HP.
2. Unduh `XueCiMandarin.apk`.
3. Buka file itu. Jika diminta, izinkan "Instal aplikasi tidak dikenal" untuk browser atau file manager yang dipakai.

Versi baru dipasang dengan cara yang sama, langsung di atas versi sebelumnya. Progres belajar tidak hilang.

**Pindah dari Merdeka Mandarin (aplikasi lama, nama paket `com.jorgi.merdekamandarin`).** Aplikasi itu terpasang terpisah dari XueCi.
Untuk memindahkan progres: perbarui Merdeka Mandarin ke versi terakhirnya (v1.2), buka **Statistik → Cadangkan → Salin**, lalu di XueCi buka **Pengaturan → Cadangan → Pulihkan → Tempel → Periksa kode → Ganti progres**.
Setelah itu aplikasi lama boleh di-uninstall.

## Struktur

Aplikasinya dibuat dengan **Flutter** (Dart) di `mobile/` dan mulai lagi dari v1.0 (Oktober 2026). Versi WebView lama (v1.0–v1.17, halaman web di dalam WebView) kini ada di [armstrang/Merdeka-Mandarin](https://github.com/armstrang/Merdeka-Mandarin); `web/` di sini tetap menjadi sumber kosakata dan teks antarmuka.

- `mobile/lib/` — aplikasi: `engine/` (mesin belajar: model memori FSRS, rencana harian, pemilihan soal, ranah, tes), `data/` (penyimpanan progres dengan nama kunci yang sama seperti versi WebView, kosakata, pinyin), `i18n/` (teks 4 bahasa), `app/` (keadaan aplikasi, sesi latihan, kode cadangan, jembatan ke Android), `ui/` (semua layar dan lembar).
- `mobile/android/` — sisi Android: pengucapan (TextToSpeech), pengingat harian, widget layar utama, berbagi, dan pemindahan progres versi WebView saat aplikasi ini pertama kali dibuka.
- `mobile/tool/` — `make_assets.py` (data kata dan teks dari `web/` untuk aplikasi), `make_fonts.py` (font yang dipotong ke karakter yang dipakai).
- `mobile/test/` — uji otomatis (`flutter test`): mesin belajar dibandingkan jawaban demi jawaban dengan mesin JavaScript versi WebView, penyimpanan dan migrasi, kode cadangan, kontras teks di setiap layar, serta screenshot setiap layar.
- `web/data/vocab.json` — kosakata beserta arti dan contoh kalimat dalam 4 bahasa (satu kata per baris).
- `web/src/` — teks antarmuka 4 bahasa (`i18n*.js`), serta mesin JavaScript (`learn.js`, `store.js`) sebagai acuan uji mesin Dart.
- `web/tools/` — `sentence_pinyin.py` (pinyin contoh kalimat) dan `word_freq.py` (frekuensi kata dan jenis kata dari kamus jieba).
- `store/` — bahan halaman Google Play: teks (`listing.md`), screenshot, dan feature graphic.
- `art/` — gambar ikon (`python3 art/make_icons.py` membuat semua ukuran ikon dari `art/icon-source-square.png` dan `art/icon-source-round.png`); `docs/play-store.md` — rencana rilis di Google Play.

GitHub Actions membuat data aplikasi, menjalankan analisis dan semua uji di setiap push ke `main` (APK hanya dibuat kalau semuanya lulus), lalu membangun APK dan bundle Play dan menerbitkannya di Releases (v1.0, v1.1, …) dengan catatan rilis dari bagian versinya di `CHANGELOG.md`.
APK ditandatangani dengan kunci di `keystore/` supaya setiap versi bisa memperbarui versi sebelumnya (termasuk dari versi WebView ke aplikasi Flutter).

## Sumber data

Daftar kata dan pinyin dari [harukicoder/hsk30](https://github.com/harukicoder/hsk30). Arti, contoh kalimat, dan terjemahannya ditulis oleh Claude.
Pinyin kalimat dibuat dengan [pypinyin](https://github.com/mozillazg/python-pinyin) dan [jieba](https://github.com/fxsjy/jieba); frekuensi dan jenis kata (untuk tingkat kesulitan kata) dari kamus jieba (`dict.txt`). Keduanya berlisensi MIT.

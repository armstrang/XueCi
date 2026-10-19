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
Untuk memindahkan progres: perbarui aplikasi lama ke v1.2, buka **Statistik → Cadangkan → Salin**, lalu di aplikasi baru buka **Pengaturan → Cadangan → Pulihkan → Tempel → Periksa kode → Ganti progres**.
Setelah itu aplikasi lama boleh di-uninstall.

## Struktur

Sejak v2.0 aplikasinya dibuat dengan **Flutter** (Dart) di `mobile/`. Versi 1.x (halaman web di dalam WebView) dibekukan; `web/` tetap menjadi sumber kosakata dan teks antarmuka.

- `mobile/lib/` — aplikasi: `engine/` (mesin belajar: model memori FSRS, rencana harian, pemilihan soal, ranah, tes), `data/` (penyimpanan progres dengan nama kunci yang sama seperti v1.x, kosakata, pinyin), `i18n/` (teks 4 bahasa), `app/` (keadaan aplikasi, sesi latihan, kode cadangan, jembatan ke Android), `ui/` (semua layar dan lembar).
- `mobile/android/` — sisi Android: pengucapan (TextToSpeech), pengingat harian, widget layar utama, berbagi, dan pemindahan progres v1.x saat v2.0 pertama kali dibuka.
- `mobile/tool/` — `make_assets.py` (data kata dan teks dari `web/` untuk aplikasi), `make_fonts.py` (font yang dipotong ke karakter yang dipakai).
- `mobile/test/` — uji otomatis (`flutter test`): mesin belajar dibandingkan jawaban demi jawaban dengan mesin JavaScript v1.x, penyimpanan dan migrasi, kode cadangan, serta screenshot setiap layar.
- `web/data/vocab.json` — kosakata beserta arti dan contoh kalimat dalam 4 bahasa (satu kata per baris).
- `web/src/` — sumber v1.x; teks antarmuka (`i18n*.js`) dan mesin JavaScript (`learn.js`, acuan untuk mesin Dart) masih dipakai.
- `web/tools/` — `sentence_pinyin.py` (pinyin contoh kalimat) dan `word_freq.py` (frekuensi kata dan jenis kata dari kamus jieba).
- `app/`, `web/build.py`, `tests/` — aplikasi Android v1.x dan ujinya (dibekukan).
- `store/` — bahan halaman Google Play: teks (`listing.md`), screenshot, dan feature graphic.
- `art/` — gambar ikon (`python3 art/make_icons.py` membuat semua ukuran ikon dari `art/icon-source-square.png` dan `art/icon-source-round.png`); `docs/play-store.md` — rencana rilis di Google Play.

GitHub Actions membuat data aplikasi, menjalankan analisis dan semua uji di setiap push ke `main` (APK hanya dibuat kalau semuanya lulus), lalu membangun APK dan bundle Play dan menerbitkannya di Releases (v2.0, v2.1, …) dengan catatan rilis dari bagian versinya di `CHANGELOG.md`.
APK ditandatangani dengan kunci di `keystore/` supaya setiap versi bisa memperbarui versi sebelumnya (termasuk dari v1.x ke v2.0).

## Sumber data

Daftar kata dan pinyin dari [harukicoder/hsk30](https://github.com/harukicoder/hsk30). Arti, contoh kalimat, dan terjemahannya ditulis oleh Claude.
Pinyin kalimat dibuat dengan [pypinyin](https://github.com/mozillazg/python-pinyin) dan [jieba](https://github.com/fxsjy/jieba); frekuensi dan jenis kata (untuk tingkat kesulitan kata) dari kamus jieba (`dict.txt`). Keduanya berlisensi MIT.

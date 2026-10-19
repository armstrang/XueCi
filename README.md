# XueCi Mandarin

Aplikasi belajar kosakata HSK 1–6 (silabus HSK 3.0, terbit November 2025) bergaya *Liquid Glass*: daftar kata, kartu hafalan dengan cek kilat, kuis, simulasi ujian HSK, dan progres pemahaman per kata (20 tingkat, dari merah ke hijau). Aplikasi menyusun rencana harian dari tujuan belajarmu (target level dan tanggal, ujian HSK, atau tanpa target) dengan model memori [FSRS](https://github.com/open-spaced-repetition) yang disesuaikan dengan pola ingatanmu. Level ditentukan lewat tes dan ditampilkan sebagai ranah kultivasi (凡人 → 炼气 → … → 飞升): tes penempatan adalah pintu masuk, setelah itu ranah hanya naik lewat terobosan *雷劫* (beberapa sambaran: arti, ketik pinyin, dengar, kalimat, kecepatan) yang menentukan mutu fondasi (道基), dan ranah bisa goyah kalau kata di bawahnya mulai pudar. Ada juga halaman *Lautan Jiwa* (bola jaringan kata dan lima elemen), ujian harian, serta jeda istirahat dan hari meditasi, karena istirahat juga bagian dari belajar. Semua perhitungan dilakukan di HP. Tersedia dalam bahasa Indonesia, English, ไทย, dan Tiếng Việt, dengan tema terang, gelap, dan true black. Berjalan sepenuhnya offline.

Apa yang berubah di setiap versi ada di [CHANGELOG.md](CHANGELOG.md).

by Armstrang

## Pasang di Android

Aplikasi ini masih dalam pengujian (**1.0-alpha**), belum rilis resmi.

1. Buka halaman **[Releases](../../releases)** dari HP.
2. Pada rilis alpha terbaru, unduh `XueCiMandarin-alpha.apk`.
3. Buka file itu. Jika diminta, izinkan "Instal aplikasi tidak dikenal" untuk browser atau file manager yang dipakai.

Versi baru dipasang dengan cara yang sama, langsung di atas versi sebelumnya. Progres belajar tidak hilang.

## Struktur

Aplikasinya dibuat dengan **Flutter** (Dart).

- `mobile/lib/` — aplikasi: `engine/` (mesin belajar: model memori FSRS, rencana harian, pemilihan soal, ranah, tes), `data/` (penyimpanan progres, kosakata, pinyin), `i18n/` (teks 4 bahasa), `app/` (keadaan aplikasi, sesi latihan, kode cadangan, jembatan ke Android), `ui/` (semua layar dan lembar).
- `mobile/android/` — sisi Android: pengucapan (TextToSpeech), pengingat harian, widget layar utama, berbagi.
- `mobile/tool/` — `make_assets.py` (data kata dan teks dari `content/` untuk aplikasi), `make_fonts.py` (font yang dipotong ke karakter yang dipakai).
- `mobile/test/` — uji otomatis (`flutter test`): mesin belajar (diputar ulang dari rekaman jalannya mesin), penyimpanan dan migrasi, kode cadangan, kontras teks di setiap layar, serta screenshot setiap layar.
- `content/vocab.json` — kosakata beserta arti dan contoh kalimat dalam 4 bahasa (satu kata per baris).
- `content/i18n/` — teks antarmuka 4 bahasa.
- `content/tools/` — `sentence_pinyin.py` (pinyin contoh kalimat) dan `word_freq.py` (frekuensi kata dan jenis kata dari kamus jieba).
- `store/` — bahan halaman Google Play (`listing.md`).
- `art/` — gambar ikon (`python3 art/make_icons.py` membuat semua ukuran ikon dari `art/icon-source-square.png` dan `art/icon-source-round.png`); `docs/play-store.md` — rencana rilis di Google Play.

GitHub Actions membuat data aplikasi, menjalankan analisis dan semua uji di setiap push. Build uji yang lulus terbit sebagai pre-release `v1.0-alpha-N`; rilis resmi (v1.0, v1.1, …) dibuat dari `main` dengan catatan rilis dari bagian versinya di `CHANGELOG.md`.
APK ditandatangani dengan kunci di `keystore/` supaya setiap versi bisa memperbarui versi sebelumnya.

## Sumber data

Daftar kata dan pinyin dari [harukicoder/hsk30](https://github.com/harukicoder/hsk30). Arti, contoh kalimat, dan terjemahannya ditulis oleh Claude.
Pinyin kalimat dibuat dengan [pypinyin](https://github.com/mozillazg/python-pinyin) dan [jieba](https://github.com/fxsjy/jieba); frekuensi dan jenis kata (untuk tingkat kesulitan kata) dari kamus jieba (`dict.txt`). Keduanya berlisensi MIT.

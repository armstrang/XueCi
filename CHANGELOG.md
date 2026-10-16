# Catatan perubahan

Setiap push perubahan aplikasi ke `main` membuat rilis baru di [GitHub Releases](https://github.com/armstrang/XueCi/releases)
(v1.0, v1.1, …). Bagian `## v1.N` di bawah dipakai CI sebagai catatan rilis untuk versi itu, jadi tulis bagiannya
sebelum push.

## v1.8 — 16 Oktober 2026

**Belajar terarah.** Aplikasi kini menyusun rencana harian dari tujuanmu, menguji setiap "Saya tahu", dan memilih
soal sesuai kelemahanmu. Semua perhitungan dilakukan di HP; tidak ada data yang dikirim ke mana pun.

### Baru
- **Tujuan belajar.** Pilih *Capai level* (misalnya HSK 3 sebelum tanggal tertentu), *Ujian HSK*, atau *Tanpa target*,
  lalu porsi harian dalam menit atau jumlah kata baru (atau otomatis). Aplikasi langsung menghitung apakah target
  realistis. Kalau belum, ada tombol saran: tambah menit, tambah kata per hari, atau mundurkan tanggal. Ditanyakan sekali
  saat aplikasi pertama dibuka (bisa dilewati), dan bisa diubah kapan saja dari Home.
- **Rencana "Hari ini" di Home**: jumlah ulangan dan kata baru hari ini, perkiraan menit, status (*sesuai jadwal* atau
  *tertinggal*), dan tombol **Mulai sesi**.
- **Sesi hari ini**: ulangan kata yang paling berisiko terlupa, kata baru (dikenalkan lewat kartu), dan konfirmasi kata
  hijau lama, dicampur dalam satu sesi. Jawaban yang salah muncul lagi beberapa soal kemudian. Kalau absen beberapa
  hari, rencana disusun ulang tanpa tumpukan utang. Setelah selesai ada **Latihan tambahan**.
- **Kartu dirombak**: *Belum tahu* atau *Saya tahu*. "Saya tahu" harus dibuktikan dengan cek kilat (pilih arti atau
  pinyin yang benar) sebelum kartu dibalik. *Yakin tapi keliru* dihitung lebih berat daripada jujur bilang belum tahu.
  Cek ini adaptif: pengguna yang terbukti jujur lebih jarang dicek, dan setelah klaim yang tidak dicek ada tombol
  **Ternyata keliru**.
- **Kuis terarah** (bawaan): aplikasi memilih kata dan jenis soal sesuai kelemahanmu. Ada lima jenis soal, berurutan
  seperti tangga: *Kenali* (hanzi → arti), *Ingat* (arti → hanzi), *Nada* (pilih pinyin yang benar), *Dengar*
  (suara → hanzi; hanya kalau suara Mandarin tersedia di HP), dan *Kalimat* (isi kata yang hilang). Pilihan jawaban
  makin mirip saat kata makin dikuasai, supaya tingkat benar tetap sekitar 80–85%. Satu ronde berisi 12 soal dan
  diakhiri ringkasan. Setiap jenis soal juga bisa dipilih manual.
- **Simulasi ujian**: 20 soal campuran dari HSK 1 sampai level yang dipilih, dengan batas waktu 5 menit. Skornya
  dikoreksi dari peluang menebak.
- **Wawasan belajar** di Statistik: ingatan saat ini, jumlah jawaban 7 hari terakhir, ketepatan "Saya tahu",
  akurasi per jenis soal (yang paling lemah ditandai dan lebih sering dilatih), dan kata yang sering tertukar.
  Ketuk sebuah kata untuk melihat tingkat arti, hanzi, dan nadanya, serta kapan kata itu diulang lagi.
- **Model memori FSRS** (open source) menghitung kapan setiap kata perlu diulang. Setelah 400 ulangan berjarak,
  parameternya disesuaikan otomatis dengan pola ingatanmu sendiri, di HP.

### Berubah
- **Arti tingkat 0–20 berubah.** Tingkat kini menunjukkan berapa lama kata itu diperkirakan tetap kamu ingat
  (sekitar 1 bulan = hijau, 4 bulan = 20). Mengulang kata yang sama berkali-kali di hari yang sama tidak lagi bisa
  membuatnya hijau. Untuk hijau, kata juga harus lulus soal *Ingat* dan *Nada*.
- **Progres lama tetap utuh.** Setiap kata tetap di tingkatnya. Kata yang sudah hijau ditandai *perlu dikonfirmasi*
  dan diuji singkat (soal Ingat dan Nada) di sesi-sesi berikutnya.
- Tombol **Tahu/Belum** di halaman Statistik dihapus, karena memberi tingkat tanpa bukti.
- **Kode cadangan** kini juga membawa model memori, tujuan, dan parameter yang sudah disesuaikan (tanpa riwayat
  jawaban). Kode dari versi lama tetap bisa dipulihkan.
- Ubin Kartu dan Kuis di Home punya keterangan baru.

### Privasi
- Riwayat jawaban (kata, waktu, jenis soal, benar/salah, pilihan yang keliru, lama menjawab) dan tujuan belajar
  disimpan **hanya di HP**. Riwayatnya bisa dihapus lewat **Statistik → Hapus riwayat jawaban**; progres kata tetap ada.
- [Kebijakan privasi](https://armstrang.github.io/XueCi/privacy/) diperbarui.

## v1.7 — 15 Oktober 2026
- Pinyin untuk setiap contoh kalimat, dengan kata yang dipelajari disorot. Pinyin dibaca sesuai konteks, termasuk
  perubahan nada 一/不, 得/地/着, kata satuan, dan erhua; nama orang dan tempat ditulis dengan huruf kapital.
- Perbaikan pinyin 11 kata: 目的 mùdì, 充分 chōngfèn, 更换 gēnghuàn, 尽力 jìnlì, 牛仔裤 niúzǎikù, 适当 shìdàng,
  水分 shuǐfèn, 挑战 tiǎozhàn, 相册 xiàngcè, 行业 hángyè, 背包 bēibāo.

## v1.6 — 15 Oktober 2026
- Uji coba suara pelafalan: tombol speaker di Kartu, Daftar, dan Kuis, untuk kata dan contoh kalimat. Memakai mesin
  suara (TTS) bawaan HP. Kalau suara Mandarin belum terpasang, aplikasi membuka pengaturan TTS.

## v1.5 — 15 Oktober 2026
- Font dibundel di dalam aplikasi (Plus Jakarta Sans, Noto Sans/Serif SC, Noto Sans Thai), jadi aplikasi tidak lagi
  memakai internet.
- Ukuran huruf mengikuti pengaturan HP (85–160%). Hanzi besar dan bagian ringkas membesar setengahnya supaya tata
  letak tetap rapi.

## v1.4 — 15 Oktober 2026
- Tombol **Cadangan** pindah ke Home, di samping tombol warna nada.
- Ikon baru 学词.

## v1.3 — 15 Oktober 2026
- Target Android 16 (API 36) dengan tampilan *edge-to-edge*: warna status bar dan navigation bar mengikuti tema, dan
  ikut naik saat keyboard muncul.
- Nama paket baru `com.armstrang.xueci` untuk Google Play, sehingga terpasang sebagai aplikasi terpisah. Pindahkan
  progres dari aplikasi lama lewat **Cadangan → Pulihkan**.

## v1.2 — 15 Oktober 2026
- **Cadangkan dan pulihkan progres** sebagai satu kode teks untuk disalin atau dibagikan. Ini versi terakhir dengan
  nama paket lama (`com.jorgi.merdekamandarin`).

## v1.1 — 15 Oktober 2026
- Kebijakan privasi (bahasa Indonesia dan English) dan tautannya di bagian Tentang.

## v1.0 — 15 Oktober 2026
- Nama baru **XueCi Mandarin** (sebelumnya Merdeka Mandarin) di repository baru.
- Hanya versi Liquid Glass yang dipertahankan, dan nomor versi dimulai lagi dari 1.0.

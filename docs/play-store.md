# Rencana rilis XueCi Mandarin di Google Play

Status per 20 Oktober 2026: akun Play Console, GitHub Pages, email kontak, 12 tester dan uji di HP sudah siap (Josh). Aplikasi (Flutter) sedang diuji sebagai **1.0-alpha** (pre-release `v1.0-alpha-N` di
GitHub Releases). Centang item di bawah saat selesai.

## 1. Keputusan

- [x] **Nama paket: `com.armstrang.xueci`.** Tidak bisa diganti setelah terbit di Play.
- [x] **Jenis akun developer: pribadi.** Akun yang dibuat setelah 13 November 2023 wajib uji tertutup dengan
  **minimal 12 tester selama 14 hari berturut-turut** sebelum boleh rilis ke publik. Kumpulkan calon tester dari sekarang.
- [x] **Model bisnis: gratis, tanpa iklan** (Josh, 19 Okt 2026). Pembelian sekali bayar "Pendukung" yang tidak mengunci
  materi belajar bisa dipertimbangkan setelah akun Play aktif.
- [x] **Izin `INTERNET` tetap ada** untuk jaga-jaga (Josh, 19 Okt 2026). Aplikasi tidak memakainya, jadi Data safety
  tetap "tidak mengumpulkan data".
- [x] **Login Google / sinkron Drive: tidak dibuat** (Josh, Okt 2026). Kode cadangan + Android Auto Backup sudah cukup.
- [ ] **APK di GitHub tetap dibagikan setelah ada versi Play?** Mulai 30 September 2026 Indonesia mewajibkan aplikasi
  didaftarkan oleh developer terverifikasi (cek detailnya di Android Developer Console). Kalau APK GitHub tetap
  dibagikan, daftarkan nama paketnya juga.

## 2. Kunci tanda tangan

`keystore/xueci.jks` dan kata sandinya ada di repo publik, jadi hanya untuk APK uji di GitHub. Untuk Play:

- [ ] **Josh: buat upload key** di komputer sendiri (jangan di repo, jangan kirim ke siapa pun), simpan baik-baik:

  ```
  keytool -genkeypair -v -keystore xueci-upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000
  base64 -w0 xueci-upload.jks > upload.b64      # Windows: certutil -encode xueci-upload.jks upload.b64
  ```
- [ ] Isi di repo → **Settings → Secrets and variables → Actions**: `XC_UPLOAD_KEYSTORE_B64` (isi `upload.b64`),
  `XC_UPLOAD_STORE_PASSWORD`, `XC_UPLOAD_KEY_ALIAS` (`upload`), `XC_UPLOAD_KEY_PASSWORD`. Bundle (.aab) rilis berikutnya
  ditandatangani dengan kunci ini; tanpa secret itu, bundle memakai kunci uji dan jangan diunggah ke Play.
- [ ] Di Play Console pilih **Play App Signing**.

## 3. Pekerjaan teknis

- [x] Target SDK 36 (Android 16), edge-to-edge, splash screen.
- [x] Android App Bundle (.aab) dibuat CI bersama APK.
- [x] Font dibundel, aplikasi sepenuhnya offline; kebijakan privasi di `docs/privacy/index.html` (ID + EN).
- [x] Kontras teks diuji otomatis di setiap layar dan tema.
- [x] **Uji di HP sungguhan** (alpha, Josh 20 Okt 2026): pindah progres dari versi sebelumnya, tampilan dan kelancaran, notifikasi
  pengingat (jam yang dipilih, diam setelah latihan, tetap ada setelah restart), widget, berbagi kartu, Android 15/16
  (gesture dan 3 tombol, keyboard, lanskap).
- [x] **GitHub Pages** untuk kebijakan privasi: repo → **Settings → Pages** → *Deploy from a branch* → `main`, folder
  `/docs`. Alamatnya: **https://armstrang.github.io/XueCi/privacy/** (diisi di Play Console).
- [x] **Lisensi data.** `harukicoder/hsk30`: tabel level MIT, korpus CC BY 4.0. Daftar kata kita berasal dari tabel level
  (MIT): teks lisensinya ada di aplikasi (Bantuan → Tentang → Lisensi, bersama lisensi font OFL) dan di
  `content/LICENSE-hsk30.txt`.

## 4. Halaman toko (Play Console → Store listing)

Teks ada di `store/listing.md`.

- [x] Nama aplikasi: **XueCi Mandarin**; deskripsi singkat dan lengkap (ID + EN).
- [x] Ikon 512×512: `art/play-icon-512.png`.
- [x] Feature graphic 1024×500 (`store/feature-*.png`) dan 12 screenshot HP 1080×1920 per bahasa (`store/shots/`).
- [x] Email kontak di Play Console (wajib, tampil di halaman toko).
- [ ] Kuesioner rating konten (IARC), target usia 13+, Data safety "tidak mengumpulkan data" (jawaban di `store/listing.md`).

## 5. Bundle untuk uji Play

Workflow **Play test bundle** (Actions → *Play test bundle* → *Run workflow* di `main`) membuat `.aab` bertanda tangan
upload key, versi `1.0.0-beta.N` (versionCode 1500 + run). Tidak menerbitkan apa pun di GitHub: unduh `.aab` dari
*Artifacts* di halaman run itu, lalu unggah di Play Console → Testing. Gagal dengan pesan jelas kalau secret
`XC_UPLOAD_*` belum diisi.

## 6. Urutan

1. Buat akun Play Console dan selesaikan verifikasi identitas (bisa beberapa hari).
2. Selesaikan uji alpha di HP, buat upload key, lalu unggah AAB ke *internal testing*.
3. *Closed testing* dengan ≥12 tester selama 14 hari.
4. Ajukan akses produksi, tunggu review, lalu rilis v1.0.

## Sumber

- [Target API level requirements — Android Developers](https://developer.android.com/google/play/requirements/target-sdk)
- [Testing requirements for new personal developer accounts — Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Android developer verification, 30 Sept 2026 — Malaysian Wireless](https://www.malaysianwireless.com/2026/06/google-android-developer-verification-sept-30/)

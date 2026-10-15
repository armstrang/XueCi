# Rencana rilis XueCi Mandarin di Google Play

Status per 15 Oktober 2026. Aplikasi sudah jalan sebagai APK di GitHub Releases, tapi belum memenuhi syarat Play Store.
Centang item di bawah saat selesai.

## 1. Keputusan dulu (sebelum kode diubah)

- [x] **Nama paket (application ID): `com.armstrang.xueci`** (diputuskan 15 Okt 2026). Nama paket di Play Store tidak bisa diganti setelah terbit.
  - Versi Play terpasang sebagai aplikasi terpisah dari APK GitHub (`com.jorgi.merdekamandarin`), jadi progres tidak pindah otomatis.
  - Karena itu, ganti ID **bersamaan** dengan fitur cadangkan/pulihkan progres (tugas teknis 4), jangan sebelumnya.
- [ ] **Kunci tanda tangan.** `keystore/merdeka.jks` beserta kata sandinya ada di repo publik, jadi siapa pun bisa menandatangani APK atas nama aplikasi ini. Untuk Play:
  - buat *upload key* baru;
  - simpan di GitHub Secrets, jangan di repo;
  - aktifkan Play App Signing.

  Kunci lama hanya untuk jalur APK GitHub, dan sebaiknya jalur itu dihentikan setelah versi Play terbit.
- [x] **Jenis akun developer: pribadi.** Ada biaya pendaftaran sekali dan verifikasi identitas. Karena akunnya dibuat setelah 13 November 2023, wajib uji tertutup dengan **minimal 12 tester selama 14 hari berturut-turut** sebelum boleh rilis ke publik. Kumpulkan calon tester dari sekarang.
- [x] **Kebijakan privasi** sudah dibuat di `docs/privacy/index.html` (bahasa Indonesia + English). Tautannya juga ada di aplikasi, di bagian Tentang.
  - [ ] Aktifkan GitHub Pages: repo XueCi → **Settings → Pages** → *Deploy from a branch* → `main` dan folder `/docs` → Save. Alamatnya nanti: **https://armstrang.github.io/XueCi/privacy/**. Alamat ini yang diisi di Play Console.
  - [ ] Perbarui halaman itu setiap kali perilaku data berubah. Contohnya setelah font dibundel: hapus bagian Google Fonts dan izin Internet, lalu ganti tanggal berlakunya.
- [ ] **APK di GitHub tetap dibagikan atau tidak?** Mulai 30 September 2026, Indonesia termasuk negara yang mewajibkan aplikasi didaftarkan oleh developer terverifikasi. Itu menurut berita; cek detailnya di Android Developer Console. Kalau APK GitHub tetap dibagikan, daftarkan nama paketnya juga.

## 2. Pekerjaan teknis

- [ ] **Target SDK 36.** Sejak 31 Agustus 2026, aplikasi baru wajib menargetkan Android 16 (API 36). Sekarang `targetSdk 34`.
  - Naikkan `compileSdk`/`targetSdk` ke 36, dan Android Gradle Plugin/Gradle kalau perlu.
  - Android 15+ memaksa tampilan *edge-to-edge*. Isi WebView harus diberi jarak dari status bar dan navigation bar (window insets ke padding WebView, atau ke variabel CSS).
  - `setStatusBarColor` sudah tidak berlaku. Warna bar mengikuti latar halaman, dan ikon terang/gelap diatur lewat `WindowInsetsControllerCompat`.
  - Uji di emulator Android 15 dan 16.
- [ ] **Android App Bundle (.aab).** Play hanya menerima AAB untuk aplikasi baru. CI menjalankan `bundleRelease`, ditandatangani dengan upload key dari GitHub Secrets. Kata sandi dibaca dari environment, tidak ditulis di `build.gradle`.
- [ ] **ID baru** (kalau diputuskan begitu): ganti `applicationId` dan `namespace`/paket Java. `versionCode` untuk ID baru boleh mulai dari 1.
- [ ] **Cadangkan/pulihkan progres.** Ekspor progres (`mm_stats` dan pengaturan) ke file atau kode teks, lalu impor di aplikasi lain. Ini untuk pindah dari APK GitHub ke versi Play, dan juga berguna untuk ganti HP.
- [ ] **Font dibundel di dalam aplikasi.** Sekarang font diambil dari Google Fonts saat online. Kalau dibundel, izin `INTERNET` bisa dihapus, tampilan sama saat offline, dan formulir Data safety bisa diisi "tidak mengumpulkan data" dengan yakin. Cek lisensi font (umumnya OFL, boleh dibundel).
- [ ] **Splash screen** dengan SplashScreen API (Android 12+), supaya tidak ada layar kosong saat aplikasi dibuka.
- [ ] **Performa** (dari diskusi sebelumnya):
  - latar WebView solid (bukan transparan);
  - data kosakata dimuat per bahasa;
  - titik di Statistik dibuat bertahap;
  - blur dikurangi di HP lemah.
- [ ] **Lisensi data.** Cek lisensi repo `harukicoder/hsk30` (sumber daftar kata dan pinyin), lalu cantumkan atribusinya di aplikasi/README sesuai lisensi.
- [ ] Jalankan `python3 tests/smoke.py` dan uji di HP sungguhan sebelum unggah.

## 3. Halaman toko (Play Console → Store listing)

- [ ] Nama aplikasi (maks. 30 karakter): **XueCi Mandarin**
- [ ] Deskripsi singkat (maks. 80 karakter) dan deskripsi lengkap (maks. 4.000 karakter), bahasa Indonesia, plus terjemahan English/ไทย/Tiếng Việt kalau mau.
- [x] Ikon 512×512: `art/play-icon-512.png`
- [ ] Feature graphic 1024×500
- [ ] Screenshot HP, minimal 2 (sebaiknya 4–8): Home, Kartu, Kuis, Statistik, Warna nada; tema terang dan gelap.
- [ ] Kategori: Pendidikan (Education). Email kontak. URL kebijakan privasi.
- [ ] Kuesioner rating konten (IARC).
- [ ] Target usia. Kalau memilih anak di bawah 13 tahun, berlaku aturan Families yang lebih ketat. Pilih 13+ kecuali memang ditujukan untuk anak.
- [ ] Data safety: tidak mengumpulkan/membagikan data (setelah font dibundel dan tanpa analitik).
- [ ] Iklan: tidak ada. Akses aplikasi: tanpa login.

## 4. Urutan dan perkiraan waktu

1. Buat akun Play Console dan selesaikan verifikasi identitas (bisa beberapa hari). Ambil keputusan di bagian 1.
2. Kerjakan bagian 2 (beberapa sesi kerja), lalu unggah AAB ke *internal testing* untuk dicoba sendiri.
3. Untuk akun pribadi: buka *closed testing* dengan ≥12 tester yang ikut terus selama 14 hari.
4. Ajukan akses produksi, tunggu review, lalu rilis.

Paling cepat sekitar 3–4 minggu untuk akun pribadi, karena masa uji 14 hari.

## Sumber

- [Target API level requirements — Android Developers](https://developer.android.com/google/play/requirements/target-sdk)
- [Testing requirements for new personal developer accounts — Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Android developer verification, 30 Sept 2026 — Malaysian Wireless](https://www.malaysianwireless.com/2026/06/google-android-developer-verification-sept-30/)

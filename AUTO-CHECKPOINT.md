# AUTO-CHECKPOINT — XueCi

24 November 2026 (Asia/Makassar), ChatGPT/Codex.

## Tujuan proyek

XueCi Mandarin adalah aplikasi Android Flutter untuk belajar Mandarin. Bicara BCT melatih percakapan bisnis luring. Mesin perlu memahami beberapa tindakan dalam satu ucapan serta membedakan janji, keputusan, permintaan, kutipan, dan dugaan. Skor singkat ditampilkan saat latihan dan koreksi kosakata di akhir. Target evaluasi terbaru adalah F1 minimal 97% dan salah terima di bawah 3% pada putaran yang sama.

## Titik lanjut di GitHub

- Repo `armstrang/XueCi`, branch `main`. Commit kode acuan `08748d4`.
- Mesin dan model Bicara BCT sudah terintegrasi ke layar suara. Pintu masuk ada di halaman BCT. Layar memakai transkrip, kartu konfirmasi, dan laporan akhir. Baca `mobile/lib/ui/talk.dart`, `mobile/lib/ui/bct_study.dart`, dan `mobile/lib/app/talk/`.
- Model aktif berasal dari `content/talk/model/talk_model.json`. Aset Flutter digenerasi dengan `mobile/tool/make_assets.py`.
- Setelah sesi berganti, checkout yang tersedia hanya memuat perubahan lokal sampai v11. Patch, model, dan kode kandidat putaran berikutnya tidak ditemukan di checkout itu. Penyimpanan ini hanya memperbarui `AUTO-CHECKPOINT.md` dan memakai `[skip ci]`. Eksperimen ini belum dipasang di aplikasi. PR cleanup #2 dan #3 bukan tugas aktif.

## Hasil putaran verifikasi bukti ucapan

Putaran terakhir menambah 960 contoh sintetis berpasangan untuk membedakan konfirmasi langsung dari dugaan, rujukan ucapan orang lain, penyelidikan, dan penawaran yang belum diputuskan. Pelatihan memakai 17.179 transkrip sumber dan 8.741 varian homofon. Kelima set di bawah dikeluarkan dari pelatihan kandidat baru. Pengecekan setelah normalisasi menemukan nol transkrip yang cocok persis. Bobot kandidat v11 lama pernah melihat 493 dari 493 baris `blind_val`. Angka kalibrasi bobot v11 lama tidak dipakai sebagai bukti independen.

| Set historis | F1 kandidat | Salah terima |
|---|---:|---:|
| `blind4_all` | 91,9% | 0,0% (0/152) |
| `asr_sim_light` | 90,5% | 1,3% (2/152) |
| `asr_sim_heavy` | 88,7% | 1,3% (2/152) |
| `blind_val` (kalibrasi) | 85,6% | 2,6% (5/195) |
| `blind_final` (pembanding) | 84,0% | 7,5% (15/201) |

Pada `blind_final`, putaran sebelumnya melaporkan 11,4% (23/201). Aset aktif dengan kode lokal v11 menghasilkan F1 83,7% dan 16,9% salah terima (34/201). Profil eksperimental yang lebih ketat menghasilkan 3,5% salah terima (7/201), dengan F1 72,3%. Target belum tercapai. Pengurangan skor kepercayaan pada konteks berisiko juga membuang 16 tindakan yang benar pada pembanding, termasuk tujuh penjelasan sebab. Empat bingkai penyebab, empat pengakuan tanggung jawab, dan tiga permintaan maaf muncul di antara deteksi positif keliru yang masih tersisa.

Pada sesi uji tersebut, `dart analyze` bersih dan 231 tes lulus dari `test/talk_*_test.dart`, `test/i18n_test.dart`, dan `test/secret_test.dart`. Kedua set simulasi derau berasal dari teks korpus utama. Uji suara asli dari penutur baru di Android belum dilakukan. Tidak ada APK yang dibuat pada putaran pelatihan atau penyimpanan ini.

## Berkas eksperimen dan cara mereproduksi setelah dipulihkan

Putaran yang menghasilkan angka di atas mengubah `mobile/lib/app/talk/nlu.dart`, `mobile/tool/talk_eval.dart`, dan `mobile/test/talk_verification_test.dart`. Perbaikan homofon melindungi `致歉` (meminta maaf) agar tidak terbaca `之前` (sebelumnya). Mode bukti diterapkan per klausa dan aktif hanya untuk eksperimen. Contohnya, konfirmasi pengiriman terpisah dapat diterima ketika pengembalian dana masih bersyarat.

Berkas tambahan yang perlu dipulihkan adalah `mobile/tool/make_talk_evidence_corpus.py`, `content/talk/corpus/evidence_train.jsonl`, dan `mobile/tool/talk_risk_eval.dart`. Nama patch terakhir `XueCi-Uji-Salah-Terima-BCT.patch`. Nama bobot kandidat `xueci-evidence-candidate.json` dengan SHA-256 `a8579a533807c52f2a453b5b901f42ea8434cb5acca8c06237ae90f4090d2138`. Kedua artefak belum tersimpan di GitHub.

- Data latih: `train5_all`, `context_v5_train`, `billing_v8_train`, `composition_v9_train`, `scope_v10_train`, `verification_v11_train`, dan `evidence_train` di `content/talk/corpus/`.
- Latih dengan `mobile/tool/make_talk_model.py`, opsi `--full --scope-features --min_df 3 --C 5 --prune .14 --asr-augment .06`. Keluarkan kelima set evaluasi melalui `--exclude` dan simpan probabilitas antarlipatan melalui `--oof`.
- Ekspor keluaran aturan dengan `mobile/tool/talk_rules_dump.dart` dan kalibrasi bobot dengan `mobile/tool/fit_talk_stack.py` memakai probabilitas antarlipatan dan data latih. Baca `content/talk/ADJUDICATION.md` untuk aturan evaluasi.
- Profil `guard+new_weights` menimbang mesin dengan aset aktif 55% dan kandidat 45%, keduanya dengan pemeriksaan bukti. Bingkai yang absen memakai kepercayaan 0,37 saat digabung. Penalti sebesar 0,25 berlaku pada bingkai positif di ucapan yang memuat tanda risiko seperti pengandaian, kutipan, pertanyaan, atau negasi. Penalti dipilih pada `blind_val`. Jalankan `STRICT=1 dart run tool/talk_risk_eval.dart KANDIDAT.json` dari `mobile/` setelah alat dipulihkan.

## Keputusan menuju rilis final

- Pengguna menunda pelatihan lanjutan dan memilih memakai kandidat terbaru jika berhasil dipulihkan. Target lanjutan tetap F1 minimal 97% dan salah terima di bawah 3%.
- Pengguna melaporkan pengenal suara cukup baik pada uji sendiri. Versi APK yang diuji belum diidentifikasi, sehingga hasil tersebut belum mengonfirmasi bobot kandidat 7,5%.
- Tahap rilis mencakup pemulihan kandidat, commit dan push sumber ke GitHub, lalu build APK dan AAB bertanda tangan. Artefak untuk GitHub dan Play Console harus berasal dari commit rilis yang sama.
- Patch dan bobot 7,5% masih belum ditemukan. Checkout berisi perubahan lokal sampai v11. Verifikasi kembali kandidat sebelum membuat APK atau AAB rilis agar versi yang dipilih pengguna dapat dipastikan.

## Rekaman dan rincian skor Bicara BCT

Paket gabungan sebelumnya dipulihkan di checkout terpisah berbasis `cd2616b`. Kontrol audio menampilkan gelombang dan timeline, putar/jeda, rekam ulang, serta kirim. Setelah memilih level, satu skenario tetap ditarik dari 10 skenario A atau 10 skenario B. Perekam berhenti saat tap kedua atau 30 detik. Pada Android yang mendukung input audio ke pengenal luring, jawaban baru diproses saat dikirim. Jika pengenal gagal membaca rekaman, pengguna dapat beralih ke Bicara langsung. HSKK memakai jalur lama. Rekaman sementara dihapus setelah pemrosesan sukses, rekam ulang, atau keluar. Laporan memberi skor /10 untuk ungkapan yang memiliki aturan evaluasi berdasarkan transkrip, bukan pengukuran pelafalan untuk setiap kata.

Berkas baru `mobile/android/app/src/main/kotlin/com/armstrang/xueci/TalkRecording.kt`. Perubahan terpusat di `MainActivity.kt`, `Listen.kt`, `mobile/lib/app/native.dart`, `mobile/lib/ui/talk.dart`, `mobile/lib/app/talk/coach.dart`, tes coach dan layar Bicara, serta `docs/privacy/index.html`. Analyzer, 234 tes terarah, enam tes layar terpilih, dan kompilasi Kotlin dengan dependensi Android/Flutter lulus. APK belum dibuat. Uji perangkat untuk izin mikrofon, bunyi, playback, seek, pengiriman rekaman, dan fallback masih menunggu. GitHub masih tertahan oleh penolakan unggahan dua berkas inti dari paket awal. Bobot aktif tidak diganti. Target F1 97% dan salah terima di bawah 3% tetap ditunda. Terapkan patch gabungan ini pada `cd2616b` dan tunggu otorisasi sebelum build atau rilis.

## Paket gabungan BCT

Paket ini mempertahankan tampilan Claude dan memuat perbaikan splash, navbar Bicara, pemilih BCT A/B dengan 10 skenario per tingkat, batas rekam 30 detik, filter kosakata, statistik, tombol beranda dan kartu, serta kuis ala HSK dengan Arti, Recall pilihan Hanzi, Dengar, Tone, dan Sentence. Opsi Ketik Pinyin di HSK dihapus. Durasi ujian HSKK tetap memakai jalur lama. Generator teks memuat teks konfirmasi transkrip dari berkas publik tersendiri.

Berkas inti: `mobile/lib/ui/{shell,splash,talk,bct_study,bct_words,bct_stats,run_view}.dart`, `mobile/lib/app/talk/{dialog,practice,coach}.dart`, `mobile/lib/app/app.dart`, dan `mobile/android/app/src/main/kotlin/com/armstrang/xueci/Listen.kt`. Analyzer bersih, 232 tes Flutter terarah lulus, dan Kotlin pengenal suara berhasil dikompilasi. Kontrol timeline, penyimpanan sementara audio, pemutaran ulang, kirim, dan penilaian angka per kosakata belum selesai. Uji bunyi mikrofon pada perangkat belum dilakukan.

Model aktif tetap memakai bobot lama. Target F1 97% dan salah terima di bawah 3% ditunda sesuai arahan. Kandidat 7,5% masih belum dipulihkan. Commit ini memakai `[skip ci]` karena pengguna meminta push dan instruksi build tetap terpisah. Jangan menyatakan APK atau rilis tersedia sebelum verifikasi.

## Metode kerja untuk sesi berikutnya

1. Mulai dari `main` terbaru dan baca checkpoint ini. Acuan kode paket gabungan Bicara BCT adalah `ad99fac`. Cocokkan kode dengan daftar keputusan, termasuk pembahasan sebelum pesan terakhir.
2. Sebelum implementasi, build, push, atau rilis, rangkum seluruh cakupan dan tunggu konfirmasi pengguna. Izin untuk satu tindakan tidak sekaligus mengizinkan tindakan lain. Pisahkan pekerjaan yang selesai, tertunda, dan belum teruji.
3. Setelah perubahan penting, perbarui checkpoint dengan daftar berkas, hasil tes yang benar-benar dijalankan, bug tersisa, langkah berikutnya, dan instruksi handoff. Simpan sumber lengkap pada commit GitHub yang dapat diambil kembali. Bila push tertahan, simpan patch lengkap dengan commit basis dan bagikan tautannya. Workspace sementara dapat kembali ke versi lama.
4. Jika ChatGPT tertahan saat push, gunakan paket lengkap yang telah diverifikasi untuk handoff ke sesi Claude yang punya akses GitHub. Setelah Claude push, cek HEAD dan isi commit di GitHub sebelum menandai pekerjaan tersimpan. Kasus acuan `ad99fac` memuat seluruh paket, dengan symlink lokal `node_modules` dikeluarkan.
5. Build harus memakai commit yang sudah diverifikasi dan mencakup semua fitur yang dikonfirmasi. Catat versi, tanda tangan, tautan APK atau AAB, dan status uji perangkat. Push dengan `[skip ci]` ketika pengguna hanya mengizinkan penyimpanan atau push.
6. Pertahankan desain Claude dan jalur ujian HSKK panjang. Model aktif tetap dipakai. Target F1 97% dan salah terima di bawah 3% tetap ditunda sampai pengguna meminta pelatihan dilanjutkan.

## Langkah berikutnya

1. Baca `CLAUDE.md`, periksa HEAD dan file lokal, dan pulihkan artefak jika salinannya ditemukan. Jangan mengulang pelatihan sebelum memastikan eksperimen terdahulu tersedia.
2. Perbaiki pembedaan antara penyebab yang sudah dipastikan dan alasan yang sedang diselidiki. Prioritaskan juga pengakuan tanggung jawab ketika ucapan hanya mengutip atau menyangkal pendapat pihak lain.
3. Siapkan transkrip dan audio dari penutur baru. Pisahkan data latihan, kalibrasi, dan uji penerimaan berdasarkan penutur dan keluarga kalimat. Laporkan kedua metrik pada uji baru dan pertahankan angka historis sebagai pembanding.
4. Tunggu **Simpan** sebelum commit/push dan **build sekarang** sebelum membuat APK. Pertahankan aturan proyek, termasuk data pengguna dan konten yang dirahasiakan.

## Aturan kolaborasi pengguna (ChatGPT dan Claude)
1. Lanjutkan progres AI sebelumnya dan jangan ulang pekerjaan yang selesai.
2. Pertahankan struktur proyek dan kode yang sudah dibuat.
3. Jika menemukan bug, perbaiki dalam lingkup tugas dan jelaskan perubahan.
4. Jangan mengklaim diuji tanpa benar-benar menjalankannya.
5. Setelah setiap fitur/perubahan penting, buat AUTO-CHECKPOINT: tujuan, fitur selesai, file dibuat/diubah, bug tersisa, langkah berikutnya, instruksi pengganti. Tambahkan branch/commit serta status tes.
6. Saat pengguna mengetik HANDOFF, buat ringkasan lengkap dengan kode atau referensi file untuk melanjutkan.
7. Gunakan checkpoint AI lain bila diberikan, sambil mencocokkannya dengan Git terkini.
8. AI lain tidak dapat diasumsikan membaca percakapan. Semua konteks penting harus tertulis di checkpoint atau referensi yang dapat diakses.
9. Hanya klaim tersimpan setelah operasi simpan berhasil. Pekerjaan yang hanya lokal atau ada di chat harus diberi status jelas.
10. Checkpoint berkala mengurangi kehilangan progres; tidak menjamin ada kesempatan menulis setelah limit mendadak tercapai.

## Instruksi praktis bagi AI pengganti
Baca file ini dan CLAUDE.md terlebih dahulu. Periksa branch, HEAD, perubahan belum di-commit, dan checkpoint yang lebih baru. Hormati kunci progres, migrasi, package Android, desain dan aturan konten proyek. Jangan membocorkan konten yang sengaja disembunyikan lewat dokumentasi pengguna. Jangan merilis resmi, menghapus branch/tag/rilis, atau menggabungkan PR cleanup hanya karena tercantum di sini. Balas pengguna dalam bahasa Indonesia. Perbarui file ini setelah perubahan penting, lalu berikan tautan file/commit yang benar-benar berhasil disimpan.

## AUTO-CHECKPOINT · 25 November 2026 · Umpan balik BCT
- Tujuan: memperbaiki latihan BCT sambil mengikuti tampilan XueCi yang sudah dipakai.
- Basis Git: `1d8fb5a` dari `main`, perubahan ini masih di worktree tanpa commit. APK yang memberi umpan balik dibangun dari `ad99fac`.
- Selesai: beranda BCT menampilkan jadwal FSRS tujuh hari untuk buku yang dipilih dengan tunggakan masuk ke hari ini. Daftar memakai kartu bergaya HSK dengan pencarian dan kategori BCT. Bicara BCT menampilkan Hanzi hasil pengenal sebelum kirim dan skor. Saat pengenal gagal membaca berkas, rekaman masih bisa diputar dan Bicara langsung bisa dipakai untuk mencoba lagi.
- File: `mobile/lib/app/bct_prog.dart`, `mobile/lib/ui/{bct_study,bct_words,talk}.dart`, `mobile/test/{screens_test,talk_recognition_screen_test}.dart`, `docs/privacy/index.html`, dan checkpoint ini.
- Verifikasi: `dart analyze` bersih. 235 tes terarah lulus, serta dua tes layar BCT lulus dengan acuan visual lokal yang dibuat ulang. Belum diuji di HP yang menolak transkripsi berkas.
- Berikutnya: untuk melanjutkan dari basis Git, terapkan patch inkremental `XueCi-BCT-Jadwal-Kartu-Transkrip.patch` dan cek status. Tunggu persetujuan build dan push, lalu uji alur rekaman dan alur Bicara langsung di HP pengguna. Target model F1 97% dan salah terima di bawah 3% tetap ditunda.

## AUTO-CHECKPOINT · 25 November 2026 · Revisi tata letak BCT
- Tujuan: dekatkan empat kotak tindakan ke grafik dan buat Daftar dari beranda BCT menjadi halaman penuh seperti Daftar HSK.
- Selesai: Daftar, Kartu, Kuis, dan Tata Bahasa kini mengikuti kartu jadwal dengan spasi 14 dp. Halaman Daftar memiliki tombol kembali, pilihan A/B dan kategori, pencarian, dan daftar kartu yang dimuat saat digulir. Tautan referensi dari mode ujian masih memakai panel agar sesi ujian tetap terbuka. Tampilan Bicara BCT mengikuti revisi sebelumnya.
- File tambahan yang diubah: `mobile/lib/ui/bct_study.dart`, `mobile/lib/ui/bct_words.dart`, serta checkpoint ini.
- Verifikasi: analisis Dart UI bersih. Tes widget Flutter memeriksa jarak kotak, pembukaan halaman tanpa panel, dan penggantian BCT A ke B. Screenshot diambil dengan jadwal contoh. Belum ada build APK.
- Lanjutan: gunakan patch kumulatif `XueCi-BCT-UI-Revisi.patch` pada basis `1d8fb5a` atau tinjau diff sebelum menerapkan bila patch sebelumnya sudah masuk. Tunggu persetujuan terpisah untuk build atau push.

## AUTO-CHECKPOINT · 25 November 2026 · Latihan terjadwal dan kontrol kaca BCT
- Tujuan: buka latihan ulang langsung dari grafik beranda BCT dan samakan kontrol Daftar dengan gaya kaca XueCi.
- Selesai: tombol Ulangi menghitung kata yang jatuh tempo pada level aktif, memakai jadwal FSRS BCT. Sesi kartu dimulai dari tenggat terlama, menyimpan jawaban dengan alur BCT yang sudah ada, dan kembali ke jadwal yang dihitung ulang. Grafik tetap mencakup jadwal tujuh hari, termasuk kata yang belum jatuh tempo saat ini. Pemilih level, filter kategori, dan pencarian halaman penuh memakai komponen Glass.
- File perubahan putaran ini: `mobile/lib/app/bct_prog.dart`, `mobile/lib/ui/bct_study.dart`, `mobile/lib/ui/bct_words.dart`, dan checkpoint.
- Verifikasi: `dart analyze lib` bersih. Tes widget memeriksa pemisahan A/B, urutan tunggakan, pembaruan setelah latihan, dan merender dua screenshot dengan data contoh. Bicara BCT tetap mengikuti revisi sebelumnya.
- Lanjutan: pakai patch kumulatif `XueCi-BCT-Jadwal-Glass.patch` pada basis `1d8fb5a`. Verifikasi patch yang sudah terpasang sebelum menimpa perubahan. Tunggu konfirmasi build atau push dan uji di perangkat setelah APK tersedia.

## AUTO-CHECKPOINT · 25 November 2026 · Alpha BCT
- Tujuan: rilis uji Android dari main dengan jadwal ulang BCT, daftar kaca layar penuh, dan pratinjau Hanzi sebelum pengiriman.
- Perubahan yang diuji sebelum penggabungan: alur pengulangan, pemisahan A/B, grafis dan kontrol Daftar, serta pengenalan suara tiruan. Sembilan tes Flutter lulus dan analisis Dart kode aplikasi bersih.
- Rilis: push yang disetujui pengguna memicu workflow Flutter untuk pre-release alpha. Tempatkan hasil verifikasi commit, workflow, dan APK di laporan penyerahan. Versi Play Store dan pelatihan model tetap di luar rilis uji ini.
- Lanjutan: uji pengenal suara rekaman di HP yang sebelumnya gagal membacanya dan pastikan progres BCT tetap tersimpan setelah pemasangan.

## AUTO-CHECKPOINT · 25 November 2026 · Final v1.13
- Tujuan: rilis APK final dan bundel upload Play setelah memperbaiki alur Kartu dan Bicara BCT.
- Kartu BCT membuka Hanzi dan audio dahulu. Cek arti/nada pada sebagian klaim, umpan balik dan tombol Lanjut, serta satu pengulangan dalam sesi untuk tiap kata yang salah. FSRS memberi bobot berbeda pada jawaban diperiksa dan klaim. Data BCT lama tetap kompatibel.
- Bicara BCT menilai setiap transkrip yang dikirim pada skala 0–10. Alur aplikasi mencegah pertanyaan yang sama muncul kembali, menyelesaikan percakapan yang buntu, dan menampilkan laporan akhir.
- Perubahan kode ada di `mobile/lib/{app/bct_prog.dart,app/talk/dialog.dart,ui/bct_study.dart,ui/talk.dart}`. Tes regresi ada di `mobile/test/{screens,talk_dialog,talk_recognition_screen}_test.dart`. Catatan versi dan pemisahan CI final ada di `CHANGELOG.md` dan workflow GitHub.
- Basis: `dd373ce`. Analisis Dart bersih. Verifikasi set tes penuh, status rilis, aset APK, dan bundel terenkripsi sesuai hasil workflow.
- Handoff: finalisasi hanya untuk versi v1.13 yang diizinkan. Periksa commit di main dan jalankan rilis `Build APK` hanya bila run final belum ada. Ambil bundel dari `aab-out` memakai prosedur enkripsi repo. Unggahan atau publikasi Google Play memerlukan instruksi tersendiri.

## AUTO-CHECKPOINT · 25 November 2026 · Perbaikan kontras rilis
- Tes lengkap lokal menemukan tiga kegagalan kontras HSK. Perbaikan di `mobile/lib/ui/shell.dart` dan `mobile/lib/ui/tests.dart` membuat 51 tes kontras lulus.
- Kandidat final v1.13.1 menyertakan perbaikan ini di atas v1.13. Rilis sebelumnya dipertahankan. Verifikasi commit, APK, dan AAB terenkripsi dari run v1.13.1.

## AUTO-CHECKPOINT · 26 November 2026 · Audit audio dan penghapusan suara latar
- Tujuan: audit XueCi berbasis `main` (`f7042c8`), hilangkan suara latar, dan tinjau penyebab transkrip Speak BCT meleset.
- Selesai: pilihan Suara latar, setting lama, pemutar Android, channel, pengait lifecycle, generator, dan delapan aset OGG dihapus. Setting lama diabaikan. Pelafalan, prompt HSKK dan jalur rekam/putar tetap ada. Catatan Speak BCT di empat bahasa menyebut bahwa pengenal dalam Bicara langsung mungkin memerlukan internet.
- File: `mobile/lib/app/{app,native}.dart`, `mobile/lib/ui/{settings,shell}.dart`, `mobile/lib/i18n/keys.g.dart`, `content/i18n/{id,en,th,vi}.js`, `MainActivity.kt`, penghapusan `Bgm.kt`, aset `res/raw/bgm_*.ogg`, dan `art/make_bgm.py`. `CLAUDE.md` dan `CHANGELOG.md` diperbarui.
- Temuan: cek ketersediaan ASR rekaman bersifat umum dan belum membuktikan dukungan input berkas Mandarin. Android dapat memilih jalur berbeda untuk rekaman dan Bicara langsung. Flutter menampilkan kandidat pertama yang dipilih pengenal tanpa pemilih alternatif. Penyebab transkrip yang meleset belum direproduksi pada HP pengguna. Penilaian BCT dan model yang dipakai di main tetap berlaku.
- Verifikasi: analisis Dart bersih, kompilasi Kotlin Android berhasil, tes pembentukan kandidat ASR lulus, dan 14 tes terarah Speak BCT, i18n, serta backup lulus. Suite Flutter `--update-goldens`: 518 lulus, 130 dilewati.
- Handoff: terapkan `XueCi-Audit-Hapus-Suara-Latar.patch` pada basis di atas setelah cek status main. Uji rekaman dan Bicara langsung dengan kalimat referensi yang sama di HP pengguna. Kumpulkan hasil mentah transkrip sebelum kirim untuk menentukan apakah masalah ada pada audio, layanan, atau pemilihan kandidat. Tunggu izin terpisah untuk push dan build paket.

## AUTO-CHECKPOINT · 26 November 2026 · Optimasi desain XueCi
- Tujuan: menindaklanjuti audit desain lintas layar dan menggabungkan penghapusan suara latar serta perbaikan efek jawaban dari patch sebelumnya.
- Speak BCT: kartu level besar di tengah yang bertumpuk saat ruang sempit, alternatif transkrip dipilih sebelum Kirim bila pengenal menyediakan lebih dari satu, tombol Putar/Rekam ulang/Kirim berlabel, prompt berhenti saat mikrofon aktif, serta halaman hasil yang bisa kembali ke riwayat. Teks pratinjau dipakai langsung sehingga tidak menjalankan NLU ulang setiap pembaruan posisi audio. Penilaian dilakukan pada transkrip pilihan pengguna.
- Layar lain: kelompok Simulasi dan Progres Ranah di Ujian, indikator siap diulang terpisah dari prakiraan BCT, statistik inti tampil lebih awal, filter Daftar menyesuaikan lebar, kartu merespons ukuran layar dan teks, judul HSKK dapat membungkus, pengaturan Bahasa dan Cadangan lebih awal. Beranda HSK, tata bahasa, splash, akses cadangan, dan tema diperiksa melalui tes layar/fungsi yang tersedia.
- Patch gabungan menghapus Suara latar dari UI dan Android. Efek jawaban Tes Penempatan, Tes Ranah, dan kuis dibetulkan. Perubahan terdapat di `mobile/lib/ui/`, jembatan Android `MainActivity.kt`, lokalisasi empat bahasa, dan tes layar/suara.
- Verifikasi: suite Flutter dengan pembaruan golden mencatat 521 tes lulus dan 130 dilewati. Pemeriksaan kontras mencatat 51 tes lulus. Analisis Dart bersih dan kompilasi Kotlin Android berhasil.
- Handoff: basis `f7042c8`. Terapkan `XueCi-Optimasi-Desain.patch` dan cek perbedaan bila salah satu patch lama telah masuk. Jalankan tes dan build rilis hanya setelah persetujuan. Belum ada pengukuran jangkauan jempol atau akurasi pengenal asli di HP pengguna.

## AUTO-CHECKPOINT · 26 November 2026 · Rilis v1.13.2
- Tujuan: menyiapkan APK final dan AAB bertanda tangan Play dari optimasi desain yang telah diverifikasi.
- Perubahan rilis: catatan versi di `CHANGELOG.md`. Perubahan aplikasi dan status pengujian ada pada bagian optimasi desain di atas.
- Handoff: gunakan workflow `Build APK` pada commit persis rilis ini. Verifikasi hasil workflow, APK yang diterbitkan, dan checksum AAB dari transport terenkripsi sebelum mengirim. Belum ada validasi pengenal suara di perangkat pengguna. Publikasi ke Google Play memerlukan instruksi terpisah.

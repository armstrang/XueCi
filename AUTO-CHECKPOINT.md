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

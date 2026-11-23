# AUTO-CHECKPOINT — XueCi
Diperbarui: 24 November 2026 (Asia/Makassar), oleh ChatGPT/Codex.

## Tujuan proyek
XueCi Mandarin: aplikasi Android Flutter untuk belajar Mandarin, kosakata HSK dan BCT, latihan serta progres belajar. Pertahankan struktur, desain, data pengguna, dan keputusan proyek dalam `CLAUDE.md`. Tujuan rilis Google Play dan keputusan terkait ada di `docs/play-store.md`.

## Titik lanjut yang diperiksa
- Repositori: https://github.com/armstrang/XueCi
- Branch kerja: `main`, mengikuti aturan proyek.
- Commit kode acuan: `c2a1317d114a83523085507a6b4b41e0e05ce9db`.
- Commit tersebut: "Talk: simulated recognizer noise sets and robustness results [skip ci]".
- Checkpoint ini adalah dokumentasi awal kolaborasi, bukan implementasi fitur baru. Periksa HEAD terbaru sebelum mulai karena AI lain mungkin sudah bekerja.
- PR terbuka saat pemeriksaan: #2 cleanup/old-releases dan #3 cleanup/old-branches. Bukan bukti tugas aktif; jangan merge atau hapus tanpa instruksi pengguna.

## Fitur/progres yang sudah ada
Berdasarkan README, catatan proyek dan riwayat commit; bukan klaim sudah diuji ulang:
- Aplikasi Flutter beserta mesin belajar, kosakata, kartu, kuis, ujian, tata bahasa, latihan berbicara, progres, cadangan dan dukungan Android.
- Commit `5581251f53ba5f6ed177c4d3e271e00633f92b51` mencatat perpindahan mode HSK/BCT, peringkat/statistik BCT, dan contoh untuk 4.579 kata.
- Mesin Bicara BCT: NLU aturan + model kecil luring, dialog klien, coach, data latih, spesifikasi label dan alat evaluasi sudah masuk Git.
- Ronde 4/model terbaru dan simulasi derau tersimpan. Menurut laporan, mesin belum dipasang ke layar mana pun.
- Model sumber: `content/talk/model/talk_model.json`. Aset aplikasi dihasilkan; jangan hanya mengedit salinan generated.

## File dibuat/diubah pada sesi checkpoint ini
- Dibuat: `AUTO-CHECKPOINT.md`.
- Tidak ada kode aplikasi yang diubah.

## Referensi file untuk AI pengganti
- Aturan, struktur, desain, migrasi, build: `CLAUDE.md`.
- Gambaran aplikasi: `README.md`; rilis: `CHANGELOG.md`, `docs/play-store.md`.
- Progres mesin terbaru: `content/talk/REPORT.md` (baca sampai bagian Ronde 4 dan simulasi).
- Label dan penilaian terkini: `content/talk/SPEC_v4.md`, `content/talk/ADJUDICATION_v4.md`.
- Mesin: `mobile/lib/app/talk/{nlu,lexicon,model,dialog,coach,sound.g}.dart`.
- Tes: `mobile/test/talk_nlu_test.dart`, `mobile/test/talk_dialog_test.dart`, `mobile/test/talk_coach_test.dart`; evaluasi: `mobile/test/talk/eval.dart`.
- Alat: `mobile/tool/talk_eval.dart`, `make_talk_model.py`, `fit_talk_stack.py`, `make_asr_sim.py`, `talk_web.dart`.
- Data: `content/talk/corpus/`; model: `content/talk/model/`.
- CI: `.github/workflows/flutter.yml`.

## Bug/kekurangan yang belum selesai
- Target F1 >=90% belum tercapai. REPORT mencatat ronde 4: presisi 85,5%, recall 92,0%, F1 88,7%; angka ini hasil AI sebelumnya, belum direproduksi sesi ini.
- Salah terima terbesar menurut laporan: deny_fault, cause, promise_time; negasi dan slot waktu rentan terhadap derau.
- Simulasi derau bukan bukti kinerja pengenal suara asli. Rekaman/uji HP pengguna masih belum dilakukan menurut laporan.
- Integrasi layar Bicara BCT belum selesai menurut laporan dan pesan commit.
- REPORT mengandung status historis "belum di-commit"; riwayat Git membuktikan file sudah di-commit pada titik acuan. Baca urutan laporan dan Git, jangan menganggap status lama sebagai keadaan terkini.
- Belum ada bug aplikasi yang direproduksi pada sesi ini.

## Pengujian dan bukti
- Sesi ini hanya membaca repositori, riwayat commit, dan file dokumentasi/kode terkait.
- Tidak menjalankan Flutter/Dart, analyzer, unit test, evaluasi model, build APK, atau uji perangkat.
- Klaim hasil tes dan metrik dalam REPORT adalah catatan sebelumnya, bukan hasil baru.
- Perubahan checkpoint memakai commit [skip ci]; tidak meminta build atau rilis.
- Setelah perubahan kode: jalankan pemeriksaan relevan sesuai CLAUDE.md; catat perintah, hasil, serta keterbatasan lingkungan secara nyata.

## Langkah berikutnya
1. Pengguna belum menentukan fitur/perbaikan berikutnya. Minta arah kerja sebelum memilih implementasi besar (misalnya meningkatkan akurasi atau integrasi layar).
2. Baca ulang checkpoint, CLAUDE.md, HEAD dan diff sejak commit acuan. Jika ada checkpoint baru dari Claude, cocokkan dengan kode terkini.
3. Untuk melanjutkan mesin Bicara: reproduksi baseline dan periksa spesifikasi/aturan evaluasi sebelum mengubah model. Jangan menyebut set yang telah dilihat sebagai uji buta baru.
4. Selesaikan dalam perubahan kecil; perbarui checkpoint setelah setiap fitur/perubahan penting bersama referensi commit dan status tes.

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

# Bicara BCT: laporan mesin v2 (23 Nov 2026)

Status: **belum lulus target 9/10.** Belum dipasang ke layar mana pun, belum di-commit.

## Yang dibangun (mobile/lib/app/talk/)
- `nlu.dart` + `lexicon.dart`: pemahaman luring. Mencakup 16 aksi, polaritas, negasi dan negasi ganda, pertanyaan, pengandaian, kutipan, rencana yang dibatalkan, slot (diskon %, hari, sebab), salah dengar homofon (`sound.g.dart` dari `mobile/tool/make_talk.py`), dan perbaikan bunyi kata kunci.
- `dialog.dart`: klien yang bernalar. Ia punya kebutuhan berurutan, suasana hati, kesabaran, tenggat Jumat, batas diskon 10%, dan tiga akhir.
- `coach.dart`: skor per bagian dengan alasan, 10 pola salah ucap pelajar, dan kalimat contoh.
- Tes: `mobile/test/talk_nlu_test.dart`, `talk_dialog_test.dart`, `talk_coach_test.dart` (20 tes, lulus).
- Alat: `mobile/tool/talk_eval.dart` (metrik) dan `mobile/tool/talk_web.dart` (mock browser via `dart compile js`).

## Korpus (content/talk/corpus/)
- `dev.jsonl`: 197 ucapan tulisan Claude, dipakai untuk menyetel.
- `blind_val.jsonl`: 493 ucapan. Sudah dilihat dan dipakai untuk perbaikan.
- `blind_final.jsonl`: 507 ucapan. Ditulis empat agen terpisah (pemula, profesional, santai, serangan) yang tidak melihat mesin, lalu diukur satu kali.
- Aturan penilaian ada di `ADJUDICATION.md` (dikunci sebelum pengukuran), spesifikasi label di `SPEC.md`.

## Hasil

| Set | Presisi | Perolehan | F1 | Salah terima di ucapan sulit |
|---|---|---|---|---|
| dev | 99,6 % | 99,1 % | 99,3 % | 0,0 % |
| validasi (sudah dilihat) | 96,3 % | 91,8 % | 94,0 % | 3,1 % |
| **uji buta final (resmi)** | **87,5 %** | **75,5 %** | **81,1 %** | **11,4 %** |
| final + salah dengar (simulasi) | 85,9 % | 70,3 % | 77,3 % | 10,9 % |

- **Kesepakatan antarpenilai:** penilai keenam melabel ulang 200 ucapan final secara independen dan mencapai F1 97,6 %. Pada ucapan yang sama, mesin 80,2 %. Jadi labelnya dapat dipercaya, dan kekurangannya ada di mesin.
- **Slot (final):** diskon 90 %, hari 95 %, sebab 89 %.
- **Kecepatan:** < 1 ms per ucapan.
- **Dialog:** 3.000 percakapan acak semuanya selesai dalam ≤ 12 giliran, dan ketiga akhir tercapai.

## Kenapa belum lulus
Dari 45 kegagalan final yang diperiksa:
- **Sekitar separuh: ungkapan tak terduga** (电脑坏了, 贴错标签, 换我也急, 退你一半). Aturan tulisan tangan tidak bisa menutup semua cara orang berbicara.
- **Sekitar sepertiga: aturan yang keliru** (pengandaian, pertanyaan sopan dengan 不知道, kutipan dari subjek yang tidak terduga).

## Jalan ke ≥ 90 %
1. Panduan label v2 untuk kasus abu-abu yang tersisa.
2. Korpus latih 8.000–10.000 ucapan dari banyak penulis.
3. Pengklasifikasi kecil di perangkat (n-gram hanzi + pinyin, beberapa ratus KB), digabung dengan aturan untuk negasi, pengandaian, dan slot.
4. Uji buta baru di setiap tahap, diukur sekali.
5. Rekaman suara Josh sebagai uji pengenal suara asli.


---

# Ronde 2 (23 Nov 2026, sore): model yang dilatih

Status: **masih belum lulus target 9/10.** Belum dipasang ke layar, belum di-commit.

## Yang ditambahkan
- `SPEC_v3.md`: 18 keputusan untuk kasus abu-abu; `ADJUDICATION_v2.md`: penilaian ketat, dikunci sebelum pengukuran.
- Korpus latih `corpus/train_all.jsonl`: 7.989 ucapan dari 10 penulis berpersona berbeda (125 label kompensasi dirapikan dari `discount` ke `compensate`).
- `mobile/lib/app/talk/model.dart` + `mobile/assets/data/talk_model.json` (909 KB): regresi logistik per aksi atas n-gram hanzi 1–4 dan n-gram bunyi (homofon dilipat). Dibaca < 1 ms.
- Campuran aturan + model per aksi (`mobile/tool/fit_talk_stack.py`, dilatih dari prediksi di luar lipatan), pemulihan slot untuk bingkai yang hanya dilihat model, dan penyelesaian bingkai yang bertentangan (ada dan disangkal sekaligus).

## Hasil
| Set | Presisi | Perolehan | F1 |
|---|---|---|---|
| ditahan dari data latih (801, distribusi sama) | 85,3 % | 86,4 % | 85,8 % |
| **uji buta kedua, resmi, ketat (994 ucapan, empat penulis baru)** | **84,0 %** | **79,2 %** | **81,5 %** |
| uji buta kedua, aturan saja | 81,4 % | 60,0 % | 69,1 % |
| uji buta kedua + salah dengar | 83,5 % | 75,5 % | 79,3 % |
| uji buta kedua, aturan longgar lama | 84,2 % | 80,3 % | 82,2 % |

Perbandingan dengan ronde 1 (blind_final: 81,1 %) tidak setara: set dan aturan penilaian berbeda, dan set ini jauh lebih keras (ada `expedite`, `compensate`, idiom). Yang bisa dikatakan: **model menaikkan F1 dari 69,1 % ke 81,5 % pada set yang sama**, perolehan dari 60 % ke 79 %. Slot: diskon 81 %, hari 79 %, sebab 70 %.

## Di mana kekurangannya
- **`compensate`: 45 benar, 82 terlewat.** Penyebab terbesar. Penulis korpus latih tidak tahu daftar act lengkap, jadi kompensasi hampir tidak ada di data latih (125 contoh hasil perapian otomatis).
- **`expedite`: 25 terlewat, 15 salah.** Tidak ada sama sekali di data latih, jadi hanya aturan yang menanganinya.
- Dua act itu menyumbang sekitar separuh kegagalan. Tanpa keduanya F1 sekitar 85,7 %: masih di bawah 90 %, jadi bukan hanya itu.
- Negasi (bingkai `-`) hanya 55,7 % tertangkap dari 122.
- Kegagalan lain: label yang bisa diperdebatkan antarpenulis (tawaran berbentuk tanya, "退款可以" sebagai setuju atau kompensasi).

## Langkah berikutnya (butuh persetujuan)
1. Masukkan uji buta kedua ke data latih (kini sudah dilihat, tidak bersih lagi) dan tulis ±2.500 ucapan baru yang memuat `compensate`, `expedite`, dan negasi, oleh penulis yang tahu daftar act lengkap.
2. Latih ulang, lalu uji buta ketiga (500 ucapan, penulis baru), diukur sekali.
3. Penilai independen melabel ulang 200 ucapan untuk mengukur batas atas akibat label tidak konsisten.
4. Rekaman suara Josh (±30) sebagai uji pengenal suara asli.


---

# Ronde 3 (23 Nov 2026, malam): data kompensasi, percepatan, negasi

Status: **hampir, belum lulus.** F1 uji buta resmi 89,4 % (target ≥ 90 %). Belum dipasang ke layar, belum di-commit.

## Yang berubah
- Data latih: 11.191 ucapan (ronde 1, uji buta kedua, dan 5 korpus baru berfokus pada kompensasi, percepatan, negasi, penutur Taiwan/HK/SG, pelajar). Korpus ke-6 sebagian besar disusun dari kumpulan frasa; hanya 77 ucapan tulisan tangan + 150 sampel acak yang dipakai.
- Model 829 KB (`mobile/assets/data/talk_model.json`), 21 label termasuk `expedite±` dan `compensate±`; campuran per aksi dilatih ulang.
- Uji buta ketiga: 510 ucapan dari tiga penulis baru (pengusaha Thailand, Hong Kong, pedagang daring muda), dikunci dengan `ADJUDICATION_v3.md`, diukur sekali.

## Hasil uji buta ketiga (ketat)
| Konfigurasi | Presisi | Perolehan | F1 |
|---|---|---|---|
| aturan saja | 84,5 % | 71,0 % | 77,2 % |
| **aturan + model (resmi)** | **86,7 %** | **92,3 %** | **89,4 %** |
| + salah dengar (simulasi) | 86,3 % | 90,0 % | 88,1 % |

- Negasi tertangkap 88,9 % (ronde 2: 55,7 %). Slot: diskon 80 % (25 contoh), hari 86 %, sebab 79 %. 0,86 ms per ucapan.
- Kekurangan terbesar kini presisi: `resend` (13 salah terima), `compensate` (12), `cause` (11), `deny_fault` (10). Salah terima di ucapan sulit 17,3 %.
- Peringatan: uji buta ketiga lebih kecil (510) dan tiga penulisnya berbeda dari ronde 2, jadi selisih ±2 poin masih dalam rentang ketidakpastian. Uji buta kedua kini bagian dari data latih dan tidak bersih lagi.

## Belum dilakukan
- Penilai independen untuk batas atas akibat label tidak konsisten.
- Rekaman suara Josh (±30) sebagai uji pengenal suara asli di HP.
- Mock di artifact masih versi ronde 1.

## Round 4 (uji buta keempat, 510 ucapan, STRICT, diukur sekali)
Model dilatih ulang pada train5_all (12.890 baris: train3 + blind3 + 1.200 data presisi tulis tangan), 911 KB.
Set buta 4 (penulis H/I/J, aturan SPEC_v4) tidak dipakai untuk melatih.

| | Presisi | Perolehan | F1 |
|---|---|---|---|
| Model ronde 4 | 85,5 | 92,0 | **88,7** |
| Model ronde 3 (di set yang sama) | 83,6 | 90,9 | 87,1 |
| Aturan saja | 83,0 | 69,4 | 75,6 |
| Model ronde 4 + derau | 87,1 | 87,8 | 87,5 |

Tepat seluruhnya 79,2 %; negasi tertangkap 76,5 % (dari 51); salah terima di ucapan sulit 19,1 %; slot pct 91,7 %, when 87,7 %, reason 81,3 %; 0,83 ms/ucapan.
Salah terima terbanyak: deny_fault (14), cause (14), promise_time (11). Set ini lebih sulit (sengaja berisi pasangan minimal), jadi 88,7 tidak sebanding langsung dengan 89,4 di blind3; perbandingan yang adil adalah baris model ronde 3 di set yang sama (+1,6 poin).
Belum diuji: ucapan hasil pengenal suara sungguhan.

## Simulasi pengenal suara (BUKAN suara asli; hanya uji ketahanan)
`mobile/tool/make_asr_sim.py` menulis ulang blind4 (510) seperti keluaran pengenal suara: tanpa tanda baca, hanzi tertukar dengan suku kata sama (nada lain / nada sama) atau mirip (zh/z, sh/s, n/l, in/ing, an/ang), sebagian hanzi hilang. Bunyi hanzi diambil dari daftar kata, bukan dari lipatan homofon mesin. Model ronde 4, STRICT:

| | F1 | negasi | when |
|---|---|---|---|
| bersih | 88,7 | 76,5 | 87,7 |
| ringan (3 % hanzi) | 86,3 | 70,6 | 74,0 |
| berat (8 % hanzi) | 84,3 | 62,7 | 76,7 |
| berat, aturan saja | 68,3 | | |

Kelemahan: negasi dan slot waktu paling rentan. Ini tebakan saya tentang jenis kesalahan; hanya rekaman asli yang membuktikan.

## Iterasi v7 (24 November 2026)

Interpretasi membedakan waktu keluar gudang, waktu tiba, waktu paling awal, batas akhir, dan janji yang hanya dikutip. Untuk jendela tanggal, tenggat diuji terhadap ujung paling akhir. Hari kerja dalam skenario melewati Sabtu dan Minggu. Revisi serta pengiriman susulan diproses tanpa mengganti komitmen yang masih berlaku pada bagian mendesak. Pada skenario barang salah, kutipan dari gudang hanya memberi informasi, dan pernyataan tentang kemampuan mengganti memerlukan tindak lanjut yang tegas untuk dihitung sebagai solusi.

Model mendampingi aturan per klausa. Janji dari pengklasifikasi disaring ketika kalimat menjelaskan penolakan, pertanyaan, pengiriman, atau jadwal administratif. Penyangkalan waktu tiba yang eksplisit dibedakan dari komitmen. Diskon dan kompensasi dipisah, termasuk perbaikan arti `五五折` menjadi potongan 45%.

| Tolok ukur | v6 | v7 |
|---|---:|---:|
| F1 `blind4_all` (510 transkrip) | 88,7% | **90,2%** |
| F1 simulasi derau ringan | 86,3% | 87,1% |
| F1 simulasi derau berat | 84,3% | 84,5% |
| F1 `blind_final` setelah menyisihkan 1 tumpang tindih persis dari 507 transkrip | 83,5% | 83,6% |
| Salah terima pada 152 ucapan sulit di `blind4_all` | 19,1% | 15,1% |
| Keputusan benar pada 32 kasus regresi dialog baru | 16 | 32 |

Angka transkrip memakai `STRICT=1`. Korpus lama sudah dikenal dari iterasi sebelumnya. Kasus dialog sengaja menargetkan kegagalan pemrosesan waktu dan status barang. F1 90,2% berlaku pada satu tolok ukur teks. Target 9/10 untuk keseluruhan pengalaman Bicara BCT masih memerlukan pengukuran baru dengan rekaman nyata, penutur berbeda, dan penilai manusia.

Dua kandidat dilatih ulang dari 13.571 ucapan sumber bersih dengan 6.343 dan 4.831 varian homofon sintetis. Varian mewarisi partisi ucapan sumber saat prediksi di luar lipatan dan sampel evaluasi persis dikeluarkan. Model v7 yang dipilih memakai bobot ronde 4. Dalam evaluasi `blind4_all` dengan aturan v7, kandidat ringkas memperoleh F1 89,1% dan salah terima 18,4%. Kandidat kedua memperoleh F1 89,5% dan salah terima 19,7%.

## Iterasi v8 (24 November 2026)

Skenario tagihan salah menambahkan latihan selisih pembayaran dan penerbitan faktur. Klien mengecek pengembalian 200 yuan dan faktur yang benar (1.000 yuan) sebagai dua komitmen independen. Pengguna dapat menyelesaikan keduanya dalam satu ucapan atau beberapa giliran. Klien bisa menjawab pertanyaan tentang nominal serta nomor faktur, meminta nominal yang tepat, dan menerima pelunasan eksplisit yang dicicil. Angka desimal, satuan 毛/分, dan bentuk lisan seperti 两百五 diproses sebagai jumlah uang. Ucapan yang dikutip, transaksi yang menunggu persetujuan, keterangan dokumen, diskon, voucher, dan mata uang berbeda tidak menyelesaikan janji pengembalian.

Korpus bertambah 599 teks terlabel hasil penyusunan keluarga contoh. Variasi mencakup pengembalian sebenarnya, usulan dan laporan pihak ketiga, penolakan kompensasi, sapaan dengan nomor pesanan, serta diskon yang terpisah dari pengembalian. Kandidat memakai 14.168 teks sumber setelah pengecualian evaluasi, ditambah 4.217 varian homofon sintetis, total 18.385 contoh. Fixture skenario dikecualikan saat membangkitkan korpus. Pengujian skenario memakai 41 kasus sintetis terarah. Angka ini tidak mewakili pengujian pada penutur baru.

| Tolok ukur | Bobot aktif | Kandidat v8 |
|---|---:|---:|
| F1 transkrip `blind4_all` | 90,2% | 90,1% |
| Salah terima pada 152 ucapan sulit | 15,1% | 17,1% |
| F1 simulasi derau ringan | 87,1% | 87,0% |
| F1 simulasi derau berat | 84,5% | 84,0% |

Bobot ronde 4 masih aktif. Model kandidat dilatih kembali, tetapi hasil uji tidak mendukung mengganti bobot bawaan. Perlu uji suara nyata pada versi Android dan contoh dari penutur independen untuk menilai cakupan pengetahuan bahasa di luar keluarga yang sudah diuji.

## Iterasi v9 (24 November 2026)

Pemrosesan klausa bisnis menangani peralihan penutur, perubahan topik tagihan, dan revisi penawaran ketika pengenal suara tidak menuliskan tanda baca. Parser yang sama digunakan untuk jadwal, pengganti barang, faktur, pengembalian, potongan harga, dan biaya lain. Diskon terbaru menggantikan diskon lama, sedangkan pengembalian dan tanggungan ongkos diproses sebagai kewajiban tersendiri. Syarat pembayaran diproses di bagian tagihan yang relevan. Tawaran bersyarat untuk kasus pengiriman tetap mengikuti aturan NLU sebelumnya.

Generator per klausa menyusun 1.272 ucapan tambahan dari blok positif dan negatif untuk penyebab, kedatangan, pengiriman, ungkapan sosial, diskon, dan kompensasi. Setiap blok membawa label dan slotnya. Generator mengubah urutan dan tanda baca untuk menguji kombinasi. Dataset kandidat setelah deduplikasi dan pengecualian evaluasi berisi 15.440 teks sumber dan 5.562 varian homofon, total 21.002 contoh. Ini data sintetis dengan keluarga blok berulang.

| Tolok ukur | v8/bobot aktif | v9/kandidat |
|---|---:|---:|
| Keputusan dialog pada 27 kasus sintetis terarah | 15/27 (v8) | 27/27 (v9 dengan bobot aktif) |
| F1 `blind4_all` | 90,2% | 90,1% |
| Salah terima pada 152 ucapan sulit `blind4_all` | 15,1% | 17,1% |
| F1 derau simulasi berat | 84,5% | 84,1% |
| F1 `blind_final` tanpa satu duplikat latih persis | 83,6% | 83,4% |

Kandidat berukuran 3.745.691 byte. Bobot yang aktif dipertahankan karena hasil lintas korpus dan derau lebih baik. Kasus keputusan dialog disusun untuk iterasi ini. Setelah normalisasi, 27 teks tersebut tidak cocok persis dengan hasil generator baru. Tidak ada putaran uji buta baru atau pengukuran dari mikrofon Android.

## Iterasi v10 (24 November 2026)

Mesin memisahkan rencana bersyarat dari komitmen yang sudah berlaku. Ketika syarat menyangkut stok, izin atasan, atau persetujuan pihak ketiga, klien menunggu keputusan yang tegas. Koreksi penjual dapat memperbarui tanggal, nominal, atau persentase tanpa membawa kutipan lama. Permintaan konfirmasi dan tindak lanjut ke kurir tidak dianggap penjelasan penyebab. Negasi tentang diskon atau pengiriman tidak otomatis mengubah permintaan maaf yang muncul kemudian dalam transkrip tanpa tanda baca.

Ditambahkan 480 contoh sintetis berpasangan. Dua kandidat memakai 15.919 dan 16.413 contoh sumber yang lolos pengecualian, ditambah masing-masing 8.161 dan 7.088 variasi homofon. Keduanya belajar fitur hubungan antara penanda lingkup dan n-gram pada klausa yang sama. Kandidat kedua juga memakai korpus validasi historis `blind_val` sebagai sumber tambahan. Korpus evaluasi keputusan dan korpus pembanding lama tidak dijadikan sumber label untuk kedua hasil akhir. Kalibrasi gabungan dua model juga diuji terpisah dan menurunkan hasil lintas korpus.

| Ukuran | v9 | v10 dengan bobot aktif | Kandidat 3,61 MB | Kandidat 4,64 MB |
|---|---:|---:|---:|---:|
| F1 `blind4_all`, 510 transkrip | 90,2% | 90,6% | 90,5% | 90,2% |
| F1 simulasi derau ringan | 87,1% | 88,8% | 88,3% | 88,6% |
| F1 simulasi derau berat | 84,5% | 86,0% | 85,4% | 85,8% |
| Salah terima, 152 ucapan sulit `blind4_all` | 15,1% | 13,2% | 14,5% | 15,1% |
| F1 `blind_final` tanpa satu duplikat latih persis | 83,6% | 83,4% | 83,0% | 84,1% |
| Keputusan pada 18 kasus sintetis terarah | 12/18 | 18/18 | — | — |

Bobot yang aktif dipertahankan karena hasil bersih, derau, dan kesalahan pada ucapan sulit lebih andal. Kenaikan pada pengujian keputusan hanya terukur untuk kasus yang dibuat pada iterasi ini. Tolok ukur utama masih di bawah 95%; opsi `target=.95` membuat evaluator gagal bila F1 kurang dari target. Uji suara pengguna dengan Android dan penilaian oleh penutur independen belum tersedia.

## Iterasi v11 (24 November 2026)

Sesudah pemahaman awal, mesin mengecek apakah pembicara sendiri mengonfirmasi tindakan. Tawaran yang masih meminta persetujuan, ucapan pihak ketiga, pengandaian, contoh kalimat, dan penolakan tidak diperlakukan sebagai janji. Jika konteks menolaknya secara jelas, mesin mempertahankan tindakan negatif seperti menolak kirim ulang. Pemeriksaan konfirmasi tawaran juga dipakai parser kompensasi agar dialog tidak memberi kredit ulang pada tawaran yang belum disepakati.

| Ukuran | v10 | v11 |
|---|---:|---:|
| F1 `blind4_all`, 510 transkrip | 90,6% | 92,8% |
| Salah terima sulit pada transkrip bersih | 13,2% | 0,7% (1/152) |
| F1 simulasi derau ringan | 88,8% | 90,8% |
| Salah terima sulit pada simulasi derau ringan | 14,5% | 3,3% (5/152) |
| F1 simulasi derau berat | 86,0% | 88,8% |
| Salah terima sulit pada simulasi derau berat | 16,4% | 2,0% (3/152) |
| F1 korpus lama lain, 506 transkrip | 83,4% | 83,7% |
| Salah terima sulit pada korpus lama lain | 21,4% | 16,9% (34/201) |
| Kasus regresi tuturan terarah | 14/20 | 20/20 |

Ketiga set yang berasal dari corpus utama lulus batas salah terima di bawah 5%. Ketiganya dan korpus pembanding masih gagal pada F1 minimal 95%. Versi derau berasal dari teks utama yang sama. Angka tersebut belum menunjukkan kinerja pada penutur baru atau suara Android sungguhan. `target=.95 false-max=.05` memakai rasio asli tanpa pembulatan dan mengecek kedua sasaran secara terpisah.

Ditambahkan 300 contoh sintetis berlabel untuk membedakan kutipan, pertanyaan, opsi belum dipilih, keputusan, dan penolakan. Kandidat 4,32 MB dilatih pada 16.713 teks sumber dan 7.752 variasi homofon. Pada bobot kandidat, F1 bersih 92,3%, derau ringan 90,5%, dan derau berat 88,2%. Salah terima bersih 3,9%, ringan 5,3%, dan berat 5,9%. Korpus pembanding naik ke F1 84,3% dan salah terima 14,4%. Bobot aktif yang lama dipertahankan karena hasil utama dan simulasi lebih andal. Percobaan menurunkan ambang pengakuan juga masih di bawah target dan menambah salah terima pada korpus pembanding.

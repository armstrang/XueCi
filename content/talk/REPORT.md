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

# Aturan penilaian uji buta ketiga (dikunci sebelum mesin diukur, 23 Nov 2026)

Berlaku untuk `corpus/blind3_all.jsonl` (1.000 ucapan dari tiga penulis baru; 5 ucapan yang sama dengan korpus latih dibuang dari data latih).
Mesin, model (`mobile/assets/data/talk_model.json`) dan campurannya dibekukan sebelum satu pun ucapan ini dibaca mesin.
Diukur sekali; angka itulah yang dilaporkan.

Beda dengan ADJUDICATION.md (uji buta pertama): SPEC_v3 sudah memutuskan kasus abu-abu, jadi penilaian ketat.
1. Bingkai `none` diabaikan. Yang dinilai hanya aksi dan polaritasnya.
2. Tawaran bersyarat adalah tawaran nyata (SPEC_v3 no. 1): tidak ada bingkai opsional.
3. Mengakui salah tanpa kata maaf = `acknowledge`, dengan kata maaf = `apologize` (SPEC_v3 no. 4): keduanya tidak saling menggantikan.
4. `refuse+` dari mesin tidak dihitung salah bila emas memuat bingkai tawaran yang disangkal (X-), dan sebaliknya (SPEC_v3 no. 9).
5. Slot: `when` hanya bila nilai emas ada di today, tomorrow, dayafter, nama hari, N_days; `pct` bila emas bilangan; `reason` untuk setiap `cause+` yang cocok.
6. Mesin dianggap "mengucapkan" bingkai bila kepercayaan >= 0,60.
7. Dilaporkan juga: skor dengan aturan longgar lama (untuk perbandingan dengan uji buta pertama) dan skor dengan salah dengar (noiser seed 7).

# Spesifikasi label korpus uji (domain: keluhan pengiriman terlambat, percakapan bisnis lisan)

Situasi: Anda adalah PENJUAL/staf layanan pelanggan yang berbicara lewat voice note kepada pembeli yang marah karena pesanan terlambat tiga hari. Teks yang Anda tulis adalah hasil transkripsi ucapan lisan (boleh tanpa tanda baca sempurna).

Setiap ucapan diberi label berupa daftar "bingkai". Satu bingkai = {act, pol, slot...}.
pol = "+" (dinyatakan/ditawarkan) atau "-" (disangkal, dibatalkan, atau ditolak untuk dilakukan, misalnya "kami tidak akan minta maaf").
Pertanyaan, pengandaian ("kalau ... mungkin"), dan kutipan ucapan orang lain BUKAN pernyataan: beri act "none" untuk bagian itu, kecuali kalimat itu memang melakukan aksi (misalnya "Bolehkah saya minta maaf?" tetap none; "Saya minta maaf" apologize+).

Daftar act (hanya ini yang boleh dipakai):
- apologize: meminta maaf / menyatakan menyesal.
- acknowledge: mengakui perasaan atau keluhan pembeli ("saya mengerti kekesalan Anda").
- cause: menyebut penyebab keterlambatan. slot reason ∈ {weather, customs, factory, logistics, stock, other}.
- deny_fault: menyangkal kesalahan pihak sendiri / melempar kesalahan ("ini bukan salah kami"). (pol selalu "+")
- resend: menawarkan mengirim ulang / kirim sekarang. slot when (opsional): hari/waktu dalam teks, mis. "today","tomorrow","dayafter","friday","N_days" atau null.
- expedite: menawarkan percepatan / jalur cepat / kirim udara.
- discount: menawarkan potongan harga. slot pct = bilangan bulat potongan persen (9折 = 10; 8折 = 20; 95折 = 5; "10%"=10; "百分之二十"=20) atau null bila tak disebut.
- compensate: kompensasi selain diskon (voucher, ganti rugi, hadiah).
- ask_deadline: bertanya kapan pembeli butuh barang.
- ask_order: meminta nomor pesanan / nomor resi untuk dicek.
- promise_time: berjanji waktu tiba. slot when seperti pada resend.
- thanks: berterima kasih.
- agree: menyetujui / menerima usulan pembeli.
- refuse: menolak permintaan pembeli (diskon, pengembalian, dll.).
- closing: penutup sopan (mohon kerja sama, semoga lanjut bekerja sama, sampai jumpa dengan sopan).
- greet: salam pembuka.
- none: tidak ada aksi di atas (di luar topik, pertanyaan murni, pengandaian, basa-basi tak relevan).

Aturan penting:
1. Satu ucapan boleh punya beberapa bingkai (urutan sesuai ucapan).
2. Negasi: "我们不会给折扣" => discount pol "-". "我们不是不想道歉" (kami bukan tidak mau minta maaf) => apologize pol "+" (negasi ganda, perhatikan makna). Beri catatan di field "note" bila makna tidak sederhana.
3. Jangan menulis label dari kata kunci saja; nilai MAKNA kalimat.
4. Ucapan tak terduga yang tetap benar secara makna tetap diberi label benar (itu justru yang kami uji).

Format keluaran: JSONL, satu objek per baris:
{"text":"对不起，货物在路上耽误了","frames":[{"act":"apologize","pol":"+"},{"act":"cause","pol":"+","reason":"logistics"}],"tags":["fluent"],"note":""}
Hanya hanzi Mandarin untuk "text" (angka boleh digit atau hanzi). Tag bebas dari: beginner, fluent, casual, angry, long, short, negation, hypothetical, question, quote, offtopic, numbers, asr_error, grammar_error, mixed.

# Panduan label v4 (= v3 + keputusan 19–24) (korpus latih dan uji buta kedua)

Berlaku untuk semua penulis baru. Menggantikan SPEC.md pada kasus abu-abu. Daftar act, slot, dan format JSONL sama dengan SPEC.md.

Situasi: kamu adalah PENJUAL atau staf layanan pelanggan. Lewat voice note kamu membalas pembeli yang marah karena pesanan terlambat. Teks yang kamu tulis adalah hasil transkripsi suara, jadi boleh pendek, berantakan, atau salah tata bahasa.

## Daftar act LENGKAP (jangan pakai nama lain)

greet, apologize, acknowledge, cause, deny_fault, resend, **expedite** (menawarkan percepatan: 加急, 走空运, 优先发, 换快递, 尽快处理dengan jalur cepat), discount (potongan harga dengan angka atau "优惠"), **compensate** (kompensasi selain diskon: voucher, hadiah, bebas ongkir, ganti rugi, refund, 赔偿), ask_deadline, ask_order, promise_time, agree, refuse, thanks, closing, none. Refund/ganti rugi/hadiah = `compensate`, BUKAN discount. 加急/空运/优先 = `expedite`.

## Keputusan untuk kasus abu-abu (ikuti persis)

1. **Tawaran bersyarat dari penjual** ("如果您现在确认，我们打九折", "只要您同意，明天就发"): tawaran itu NYATA. Beri bingkai tawaran, pol "+". Tambahkan tag `conditional`.
2. **Pengandaian tentang hal yang tidak dilakukan** ("如果货早到就好了", "要是没下雨就不会晚"): `none`.
3. **Pertanyaan**: "要不要我给您打折?" atau "您什么时候要?" Pertanyaan tentang kapan pembeli butuh barang = `ask_deadline`; tentang nomor pesanan/resi = `ask_order`. Pertanyaan lain, termasuk menawarkan dalam bentuk tanya, = `none`.
4. **Mengakui salah tanpa kata maaf** ("是我们的错", "我们没做好", "责任在我们"): `acknowledge`. Dengan kata maaf (对不起, 抱歉, 道歉, 不好意思, 歉意, 原谅, 见谅, 谅解) = `apologize`. Dua-duanya bila ada keduanya.
5. **Menyebut penyebab dengan menunjuk pihak lain** ("海关扣了货"): `cause` dengan reason. Melempar kesalahan ("不是我们的问题, 是物流的错"): `deny_fault` + `cause` bila penyebab disebut.
6. **Janji waktu tiba** ("周四到", "后天一定送到", "三天内到"): `promise_time` + when. Kalimat yang berisi kirim ulang DAN waktu tiba menghasilkan dua bingkai.
7. **Kirim ulang** ("今天重新发货", "我们马上补发"): `resend`. when = waktu pengirimannya bila disebut.
8. **Menolak dengan sopan** ("这个我们恐怕做不到", "实在没办法", "公司规定不允许"): `refuse` +.
9. **Menyangkal tawaran** ("我们不会给折扣", "没有补偿的规定"): bingkai tawaran itu dengan pol "-". Tidak perlu tambah `refuse`.
10. **Menenangkan** ("请放心", "您别着急") tanpa janji nyata: `none`. "请放心, 明天一定到" = `promise_time`.
11. **Kutipan ucapan pembeli atau orang lain** ("您说我们没发货", "客服说今天到"): `none` untuk bagian kutipan. Bagian lain dinilai sendiri.
12. **Perbuatan pihak ketiga** ("快递公司已经发出了"): `cause` (logistics) bila menjelaskan kenapa terlambat, selain itu `none`.
13. **Setuju**: "好的, 没问题", "可以, 就按您说的" = `agree`. Setuju yang jelas menjawab usulan pembeli.
14. **Salam dan penutup**: "您好" = `greet`. "谢谢理解, 期待继续合作" = `thanks` + `closing`.
15. **Di luar topik** (cuaca hari ini, film, makan siang): `none`.
16. **Diskon**: pct = bilangan bulat persen potongan (9折=10, 8折=20, 95折=5, 八五折=15, 10%=10, 百分之二十=20, 减一半=50). Tidak disebut = null. "优惠" tanpa angka = null.
17. **Slot when** nilai: today, tomorrow, dayafter, monday, tuesday, wednesday, thursday, friday, saturday, sunday, N_days (mis. "3_days"), atau null. Hari ini Selasa.
18. Satu ucapan boleh punya banyak bingkai, urutannya mengikuti ucapan. Jangan memberi bingkai ganda untuk hal yang sama.


## Tambahan v4 (keputusan 19–24, hasil analisis ketidakkonsistenan antarpenulis)

19. **"不是我们不X, 是Y"** (membantah bahwa pihak sendiri enggan, lalu menyebut penyebab): hanya `cause` (kalau Y penyebab). Jangan tambah `deny_fault` kecuali ada kata tegas tentang kesalahan/tanggung jawab (不是我们的错, 与我们无关, 责任不在我们). Jangan tambah aksi X.
20. **Diskon yang disebut sebagai "補償/赔礼/赔罪/表示歉意"** ("九五折, 补偿您"): hanya `discount` bila kompensasinya memang potongan harga itu. Tambah `compensate` hanya bila ada bentuk kompensasi LAIN (voucher, hadiah, ongkir, refund).
21. **Membayar ongkos/biaya sebagai kompensasi** ("快递钱我出", "运费算我们的", "空运费我们承担"): `compensate`, bukan resend. Bila bersama "加急/空运" tambah `expedite`.
22. **Menyebut penyebab di luar topik** (cerita pribadi yang tidak menjelaskan keterlambatan: "昨天下大雨我家都淹了"): `none`. Penyebab hanya bila menjelaskan keterlambatan pesanan ini.
23. **Kalimat yang hanya mengungkapkan emosi** ("哎呀这快递, 真是…"): `none`.
24. **Mengakui tanggung jawab** ("我们要负责", "您讲得对, 货迟到"): `acknowledge`, bukan `deny_fault` (deny_fault hanya untuk menyangkal salah).

## Cara menulis ucapan

- Tulis seperti orang sungguhan di voice note, bukan seperti buku pelajaran. Campur: pendek dan panjang, sopan dan santai, jelas dan setengah jelas.
- **Variasi kata adalah tujuan utama.** Jangan mengulang kerangka kalimat. Hindari memakai kata yang sama untuk hal yang sama dalam banyak ucapan. Pakai sinonim, idiom, cara tak langsung, dialek penutur (kamu tahu cara orang Tiongkok dan orang Indonesia/Thailand/Vietnam yang belajar Mandarin menulisnya).
- Sertakan juga: kesalahan tata bahasa pelajar, urutan kata yang janggal, kalimat terpotong, bahasa campuran sedikit, kata isian (嗯, 那个, 就是), dan kalimat yang memuat negasi, pertanyaan, pengandaian, atau kutipan.
- Sertakan ucapan yang SULIT dan menjebak (negasi ganda, "不是不想", "本来想...但是...", mengutip pembeli lalu menjawab) dengan label yang benar menurut makna.
- Hanzi saja. Angka boleh digit atau hanzi.
- Distribusi target: sekitar 15 % none, 20 % negatif atau menjebak, sisanya aksi biasa. Kurang dari 40 % ucapan boleh punya lebih dari satu bingkai.

## Format

JSONL, satu objek per baris, tanpa komentar:

{"text":"…","frames":[{"act":"apologize","pol":"+"},{"act":"resend","pol":"+","when":"today"}],"tags":["fluent"],"note":""}

- `none` ditulis {"act":"none","pol":"+"} dan hanya dipakai bila TIDAK ada aksi lain.
- discount: tambah "pct". cause: tambah "reason" (weather, customs, factory, logistics, stock, other). resend dan promise_time: tambah "when".
- `note` hanya bila labelnya tidak jelas, isi satu kalimat pendek alasan.

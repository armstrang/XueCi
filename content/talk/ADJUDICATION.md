# Aturan penilaian korpus bicara (dikunci sebelum mesin diukur pada set buta)

Ditulis oleh supervisor (Claude) setelah membaca laporan keempat penulis korpus, sebelum hasil mesin pada set buta
dilihat. Tujuannya menyelesaikan label yang tidak konsisten antarpenulis tanpa menyesuaikan diri dengan mesin.

Pembagian: 1.000 ucapan buta dibagi dua dengan hash SHA-256 teks (genap = `blind_val`, ganjil = `blind_final`).
`blind_val` boleh dilihat untuk menemukan kelemahan umum. `blind_final` diukur sekali di akhir dan itulah angka yang
dilaporkan. Frasa dari set buta tidak boleh disalin ke leksikon.

1. Bingkai `none` diabaikan: yang dinilai hanya aksi.
2. Pengakuan salah tanpa kata maaf (我们的错/没做好/责任在我们/怪我们 tanpa 对不起/抱歉/道歉/歉意/不好意思/原谅/谅解/见谅):
   penulis berbeda pendapat (acknowledge atau apologize). Keduanya diterima: salah satu memenuhi yang lain.
3. Penolakan tawaran: bila emas memuat X- (tawaran yang disangkal), `refuse+` dari mesin tidak dihitung salah; bila
   emas memuat `refuse+` bersama X-, mesin tidak wajib menebak `refuse+`.
4. Tawaran bersyarat (ucapan memuat 如果/要是/假如/假设/万一/只要/的话/前提/倘若/除非): penulis berbeda pendapat
   (tawaran nyata atau none). Bingkai tawaran (resend, expedite, discount, compensate, promise_time) di ucapan itu
   bersifat opsional: tidak dihitung benar maupun salah. Jumlah bingkai opsional dilaporkan terpisah.
5. Slot `when` dinilai hanya bila nilai emas ada di kosakata bersama: today, tomorrow, dayafter, monday…sunday, N_days.
   `pct` dinilai bila emas berupa bilangan. `reason` dinilai untuk setiap `cause+` yang cocok.
6. Kepercayaan mesin >= 0,60 dihitung sebagai "diucapkan". Zona 0,45–0,60 (konfirmasi) dilaporkan terpisah dan
   tidak dihitung sebagai benar.

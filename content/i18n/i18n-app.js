/* strings for the home screen and focused screens */
Object.assign(I18N.id, {
  memoWord: 'penguasaan',
  matureWord: 'matang',
  lvlWord: 'tingkat',
  weak: 'Belum matang',
  lvCount: (k, t) => `<b>${k}</b> / ${t} kata matang`,
  allLv: (k, t) => `Semua level · <b>${k}</b> / ${t} kata matang`,
  matureOf: (k, n) => `${k}/${n} matang`,
  matureN: k => `${k} matang`,
  stTxt: (s, a, b) => `Tingkat ${s}/20 · ${a} benar, ${b} salah`,
  rsNote:
    'Setiap jawaban benar (Kartu, Kuis, atau tombol Tahu) menaikkan kata 1 tingkat, sampai 20. Jawaban salah menurunkan 3 tingkat. Warnanya bergeser dari merah ke kuning ke hijau: warna muda berarti belum matang, warna pekat berarti matang.',
});
Object.assign(I18N.en, {
  memoWord: 'mastery',
  matureWord: 'mastered',
  lvlWord: 'level',
  weak: 'Not mastered',
  lvCount: (k, t) => `<b>${k}</b> / ${t} words mastered`,
  allLv: (k, t) => `All levels · <b>${k}</b> / ${t} words mastered`,
  matureOf: (k, n) => `${k}/${n} mastered`,
  matureN: k => `${k} mastered`,
  stTxt: (s, a, b) => `Level ${s}/20 · ${a} right, ${b} wrong`,
  rsNote:
    'Each right answer (Cards, Quiz, or the Know it button) moves a word up 1 level, up to 20. A wrong answer moves it down 3. Colors shift from red to yellow to green: a light shade means still young, a deep shade means mature.',
});
Object.assign(I18N.th, {
  memoWord: 'ความชำนาญ',
  matureWord: 'ชำนาญ',
  lvlWord: 'ระดับ',
  weak: 'ยังไม่ชำนาญ',
  lvCount: (k, t) => `ชำนาญ <b>${k}</b> / ${t} คำ`,
  allLv: (k, t) => `ทุกระดับ · ชำนาญ <b>${k}</b> / ${t} คำ`,
  matureOf: (k, n) => `ชำนาญ ${k}/${n}`,
  matureN: k => `ชำนาญ ${k} คำ`,
  stTxt: (s, a, b) => `ระดับ ${s}/20 · ถูก ${a} ผิด ${b}`,
  rsNote:
    'ตอบถูกแต่ละครั้ง (บัตรคำ แบบทดสอบ หรือปุ่มรู้แล้ว) คำนั้นจะขึ้น 1 ระดับ สูงสุด 20 ตอบผิดจะลดลง 3 ระดับ สีจะค่อย ๆ เปลี่ยนจากแดงเป็นเหลืองเป็นเขียว สีอ่อนหมายถึงยังไม่ชำนาญ สีเข้มหมายถึงชำนาญแล้ว',
});
Object.assign(I18N.vi, {
  memoWord: 'mức thuộc',
  matureWord: 'thuộc hẳn',
  lvlWord: 'mức',
  weak: 'Chưa thuộc hẳn',
  lvCount: (k, t) => `đã thuộc hẳn <b>${k}</b> / ${t} từ`,
  allLv: (k, t) => `Tất cả cấp · đã thuộc hẳn <b>${k}</b> / ${t} từ`,
  matureOf: (k, n) => `${k}/${n} thuộc hẳn`,
  matureN: k => `${k} thuộc hẳn`,
  stTxt: (s, a, b) => `Mức ${s}/20 · ${a} đúng, ${b} sai`,
  rsNote:
    'Mỗi câu trả lời đúng (Thẻ, Kiểm tra hoặc nút Biết) nâng từ lên 1 mức, tối đa 20. Trả lời sai giảm 3 mức. Màu chuyển dần từ đỏ sang vàng rồi xanh: màu nhạt là còn non, màu đậm là đã thuộc hẳn.',
});
I18N.id.credit =
  'Kosakata HSK 1–6 dari silabus ujian HSK terbitan November 2025 (data terbuka {src}). Progres tersimpan di perangkat ini saja.';
I18N.en.credit =
  'HSK 1–6 vocabulary from the HSK exam syllabus published in November 2025 (open data {src}). Progress is saved on this device only.';
I18N.th.credit =
  'คำศัพท์ HSK 1–6 จากหลักสูตรการสอบ HSK ฉบับพฤศจิกายน 2025 (ข้อมูลเปิด {src}) ความคืบหน้าบันทึกไว้ในอุปกรณ์นี้เท่านั้น';
I18N.vi.credit =
  'Từ vựng HSK 1–6 theo đề cương thi HSK ban hành tháng 11/2025 (dữ liệu mở {src}). Tiến độ chỉ được lưu trên thiết bị này.';
I18N.id.th.black = 'Hitam pekat';
I18N.en.th.black = 'True black';
I18N.th.th.black = 'ดำสนิท';
I18N.vi.th.black = 'Đen tuyền';
Object.assign(I18N.id, {
  back: 'Kembali',
  statsShort: 'Statistik',
  subList: 'Lihat & cari kata',
  subCard: 'Latihan menghafal',
  subQuiz: 'Uji pemahaman',
});
Object.assign(I18N.en, {
  back: 'Back',
  statsShort: 'Stats',
  subList: 'Browse & search',
  subCard: 'Practice recall',
  subQuiz: 'Test yourself',
});
Object.assign(I18N.th, {
  back: 'กลับ',
  statsShort: 'สถิติ',
  subList: 'ดูและค้นหาคำ',
  subCard: 'ฝึกจำคำศัพท์',
  subQuiz: 'ทดสอบความเข้าใจ',
});
Object.assign(I18N.id, {
  infoBtn: 'Warna nada & info',
  infoTitle: 'Warna nada',
  infoLead: 'Warna hanzi dan pinyin menunjukkan nadanya. Ucapkan sesuai warnanya:',
  aboutT: 'Tentang',
  privacy: 'Kebijakan privasi',
  about: 'XueCi Mandarin dibuat oleh Armstrang.',
  tones: [
    ['Nada 1', 'Tinggi dan datar', 'ibu'],
    ['Nada 2', 'Naik, seperti bertanya', 'rami'],
    ['Nada 3', 'Turun lalu naik', 'kuda'],
    ['Nada 4', 'Turun tajam, tegas', 'memarahi'],
    ['Netral', 'Ringan dan pendek', 'partikel tanya'],
  ],
  dMean: 'Lihat hanzi, pilih artinya',
  dHz: 'Lihat arti, pilih hanzinya',
  dCloze: 'Isi kata yang hilang di kalimat',
});
Object.assign(I18N.en, {
  infoBtn: 'Tone colours & info',
  infoTitle: 'Tone colours',
  infoLead: 'The colour of each hanzi and its pinyin shows the tone. Say it the way the colour tells you:',
  aboutT: 'About',
  privacy: 'Privacy policy',
  about: 'XueCi Mandarin is made by Armstrang.',
  tones: [
    ['Tone 1', 'High and level', 'mother'],
    ['Tone 2', 'Rising, like a question', 'hemp'],
    ['Tone 3', 'Dips, then rises', 'horse'],
    ['Tone 4', 'Sharp fall, firm', 'to scold'],
    ['Neutral', 'Light and short', 'question particle'],
  ],
  dMean: 'See the hanzi, pick its meaning',
  dHz: 'See the meaning, pick the hanzi',
  dCloze: 'Fill the missing word in a sentence',
});
Object.assign(I18N.th, {
  infoBtn: 'สีวรรณยุกต์และข้อมูล',
  infoTitle: 'สีวรรณยุกต์',
  infoLead: 'สีของอักษรจีนและพินอินบอกวรรณยุกต์ ออกเสียงตามสีที่เห็น:',
  aboutT: 'เกี่ยวกับ',
  privacy: 'นโยบายความเป็นส่วนตัว',
  about: 'XueCi Mandarin สร้างโดย Armstrang',
  tones: [
    ['เสียง 1', 'สูงและเรียบ', 'แม่'],
    ['เสียง 2', 'ขึ้น เหมือนถามคำถาม', 'ป่าน'],
    ['เสียง 3', 'ลงแล้วขึ้น', 'ม้า'],
    ['เสียง 4', 'ลงเร็วและหนักแน่น', 'ดุด่า'],
    ['เสียงเบา', 'เบาและสั้น', 'คำช่วยคำถาม'],
  ],
  dMean: 'ดูอักษรจีน เลือกความหมาย',
  dHz: 'ดูความหมาย เลือกอักษรจีน',
  dCloze: 'เติมคำที่หายไปในประโยค',
});
Object.assign(I18N.vi, {
  infoBtn: 'Màu thanh điệu & thông tin',
  infoTitle: 'Màu thanh điệu',
  infoLead: 'Màu của chữ Hán và pinyin cho biết thanh điệu. Hãy đọc theo màu:',
  aboutT: 'Giới thiệu',
  privacy: 'Chính sách quyền riêng tư',
  about: 'XueCi Mandarin do Armstrang thực hiện.',
  tones: [
    ['Thanh 1', 'Cao và ngang', 'mẹ'],
    ['Thanh 2', 'Đi lên, như khi hỏi', 'cây gai'],
    ['Thanh 3', 'Xuống rồi lên', 'ngựa'],
    ['Thanh 4', 'Rơi mạnh, dứt khoát', 'mắng'],
    ['Thanh nhẹ', 'Nhẹ và ngắn', 'trợ từ nghi vấn'],
  ],
  dMean: 'Xem chữ Hán, chọn nghĩa',
  dHz: 'Xem nghĩa, chọn chữ Hán',
  dCloze: 'Điền từ còn thiếu vào câu',
});
Object.assign(I18N.vi, {
  back: 'Quay lại',
  statsShort: 'Thống kê',
  subList: 'Xem & tìm từ',
  subCard: 'Luyện ghi nhớ',
  subQuiz: 'Tự kiểm tra',
});
/* progress backup / restore */
Object.assign(I18N.id, {
  listen: 'Dengarkan',
  ttsMissing: 'Pasang suara Mandarin di pengaturan TTS',
  ttsNone: 'HP ini tidak punya mesin suara',
  bkBtn: 'Cadangan',
  bkMakeSub: 'Buat kode dari progres di perangkat ini',
  bkRestoreSub: 'Masukkan kode dari aplikasi atau HP lain',
  bkT: 'Cadangan progres',
  bkNote: 'Simpan progres sebagai kode untuk dipindah ke aplikasi atau HP lain.',
  bkMake: 'Cadangkan',
  bkRestore: 'Pulihkan',
  bkTitleMake: 'Kode cadangan',
  bkLeadMake: n =>
    `${n} kata sudah dilatih. Salin atau bagikan kode ini, lalu tempel di menu Pulihkan pada aplikasi atau HP lain.`,
  bkCopy: 'Salin',
  bkShare: 'Bagikan',
  bkCopied: 'Kode disalin',
  bkTitleRestore: 'Pulihkan progres',
  bkLeadRestore: 'Tempel kode cadangan di bawah.',
  bkPaste: 'Tempel',
  bkCheck: 'Periksa kode',
  bkBad: 'Kode tidak dikenali. Pastikan kode tersalin lengkap.',
  bkConfirm: (n, dt, m) => `Cadangan ${dt}: ${n} kata dilatih. Progres di perangkat ini (${m} kata) akan diganti.`,
  bkApply: 'Ganti progres',
  bkDone: 'Progres dipulihkan',
  bkShareText: dt => `Cadangan progres XueCi Mandarin (${dt})`,
});
Object.assign(I18N.en, {
  listen: 'Listen',
  ttsMissing: 'Install a Chinese voice in TTS settings',
  ttsNone: 'No text-to-speech engine on this phone',
  bkBtn: 'Backup',
  bkMakeSub: 'Make a code from the progress on this device',
  bkRestoreSub: 'Enter a code from another app or phone',
  bkT: 'Progress backup',
  bkNote: 'Save your progress as a code to move it to another app or phone.',
  bkMake: 'Back up',
  bkRestore: 'Restore',
  bkTitleMake: 'Backup code',
  bkLeadMake: n =>
    `${n} words practised. Copy or share this code, then paste it under Restore in the other app or phone.`,
  bkCopy: 'Copy',
  bkShare: 'Share',
  bkCopied: 'Code copied',
  bkTitleRestore: 'Restore progress',
  bkLeadRestore: 'Paste your backup code below.',
  bkPaste: 'Paste',
  bkCheck: 'Check code',
  bkBad: 'This code isn’t recognised. Make sure you copied all of it.',
  bkConfirm: (n, dt, m) =>
    `Backup from ${dt}: ${n} words practised. The progress on this device (${m} words) will be replaced.`,
  bkApply: 'Replace progress',
  bkDone: 'Progress restored',
  bkShareText: dt => `XueCi Mandarin progress backup (${dt})`,
});
Object.assign(I18N.th, {
  listen: 'ฟังเสียง',
  ttsMissing: 'ติดตั้งเสียงภาษาจีนในการตั้งค่า TTS',
  ttsNone: 'เครื่องนี้ไม่มีระบบอ่านออกเสียง',
  bkBtn: 'สำรองข้อมูล',
  bkMakeSub: 'สร้างรหัสจากความคืบหน้าในเครื่องนี้',
  bkRestoreSub: 'ใส่รหัสจากแอปหรือโทรศัพท์เครื่องอื่น',
  bkT: 'สำรองความคืบหน้า',
  bkNote: 'บันทึกความคืบหน้าเป็นรหัส เพื่อย้ายไปยังแอปหรือโทรศัพท์เครื่องอื่น',
  bkMake: 'สำรอง',
  bkRestore: 'กู้คืน',
  bkTitleMake: 'รหัสสำรอง',
  bkLeadMake: n => `ฝึกแล้ว ${n} คำ คัดลอกหรือแชร์รหัสนี้ แล้ววางในเมนูกู้คืนของแอปหรือโทรศัพท์อีกเครื่อง`,
  bkCopy: 'คัดลอก',
  bkShare: 'แชร์',
  bkCopied: 'คัดลอกรหัสแล้ว',
  bkTitleRestore: 'กู้คืนความคืบหน้า',
  bkLeadRestore: 'วางรหัสสำรองด้านล่าง',
  bkPaste: 'วาง',
  bkCheck: 'ตรวจสอบรหัส',
  bkBad: 'ไม่รู้จักรหัสนี้ ตรวจสอบว่าคัดลอกครบทั้งหมด',
  bkConfirm: (n, dt, m) => `ข้อมูลสำรองวันที่ ${dt}: ฝึกแล้ว ${n} คำ ความคืบหน้าในเครื่องนี้ (${m} คำ) จะถูกแทนที่`,
  bkApply: 'แทนที่ความคืบหน้า',
  bkDone: 'กู้คืนความคืบหน้าแล้ว',
  bkShareText: dt => `ข้อมูลสำรองความคืบหน้า XueCi Mandarin (${dt})`,
});
Object.assign(I18N.vi, {
  listen: 'Nghe',
  ttsMissing: 'Hãy cài giọng tiếng Trung trong cài đặt TTS',
  ttsNone: 'Máy này không có công cụ đọc văn bản',
  bkBtn: 'Sao lưu',
  bkMakeSub: 'Tạo mã từ tiến độ trên thiết bị này',
  bkRestoreSub: 'Nhập mã từ ứng dụng hoặc điện thoại khác',
  bkT: 'Sao lưu tiến độ',
  bkNote: 'Lưu tiến độ thành một mã để chuyển sang ứng dụng hoặc điện thoại khác.',
  bkMake: 'Sao lưu',
  bkRestore: 'Khôi phục',
  bkTitleMake: 'Mã sao lưu',
  bkLeadMake: n =>
    `Đã luyện ${n} từ. Sao chép hoặc chia sẻ mã này, rồi dán vào mục Khôi phục ở ứng dụng hoặc điện thoại kia.`,
  bkCopy: 'Sao chép',
  bkShare: 'Chia sẻ',
  bkCopied: 'Đã sao chép mã',
  bkTitleRestore: 'Khôi phục tiến độ',
  bkLeadRestore: 'Dán mã sao lưu vào bên dưới.',
  bkPaste: 'Dán',
  bkCheck: 'Kiểm tra mã',
  bkBad: 'Không nhận ra mã này. Hãy chắc rằng bạn đã sao chép đầy đủ.',
  bkConfirm: (n, dt, m) =>
    `Bản sao lưu ngày ${dt}: đã luyện ${n} từ. Tiến độ trên thiết bị này (${m} từ) sẽ bị thay thế.`,
  bkApply: 'Thay thế tiến độ',
  bkDone: 'Đã khôi phục tiến độ',
  bkShareText: dt => `Sao lưu tiến độ XueCi Mandarin (${dt})`,
});

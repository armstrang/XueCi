import 'dart:math';

import 'dialog.dart';

enum PracticeLevel { a, b }

class PracticeGoal {
  final Line prompt, example;
  final String hint;
  final RegExp action, detail;
  PracticeGoal(
    this.prompt,
    this.example,
    this.hint,
    String action,
    String detail,
  ) : action = RegExp(action),
      detail = RegExp('(?<![0-9零一二两三四五六七八九十百千万])(?:$detail)');
}

typedef Recipe = (
  String,
  String,
  String,
  String,
  String,
  String,
  List<(String, String, String)>,
);

const _a = <Recipe>[
  (
    'Cek stok',
    '我们想订{x}，请问现在有现货吗？',
    'Kami ingin memesan {x}. Apakah stoknya ada?',
    '您好，{x}有现货。',
    '现货 · xiànhuò · stok tersedia',
    '有现货|库存充足|有货|可以供货',
    [('二十箱', '20 kotak', '二十箱|20箱'), ('三十箱', '30 kotak', '三十箱|30箱')],
  ),
  (
    'Konfirmasi pesanan',
    '请确认一下，我们订的是{x}，对吗？',
    'Tolong konfirmasi pesanan {x}.',
    '请放心，我们确认订单是{x}。',
    '确认订单 · quèrèn dìngdān · konfirmasi pesanan',
    '订单|订购|确认',
    [('五十件', '50 unit', '五十件|50件'), ('八十件', '80 unit', '八十件|80件')],
  ),
  (
    'Harga grosir',
    '采购预算是每件{x}，你们可以按这个批发价报价吗？',
    'Bisa beri harga grosir {x} per unit?',
    '可以，批发价是每件{x}。',
    '批发价 · pīfājià · harga grosir',
    '批发价|报价|每件|单价',
    [('二十元', '20 yuan', '二十元|20元'), ('三十五元', '35 yuan', '三十五元|35元')],
  ),
  (
    'Jadwal pengambilan',
    '我们想改到{x}取货。能确认吗？',
    'Bisa kami ambil barang hari {x}?',
    '可以改到{x}取货。',
    '取货 · qǔhuò · ambil barang',
    '取货|提货|自提',
    [('星期三', 'Rabu', '星期三|周三'), ('星期五', 'Jumat', '星期五|周五')],
  ),
  (
    'Contoh produk',
    '下单以前，我们想看看{x}，你能寄给我们吗？',
    'Bisa kirim {x} sebelum kami memesan?',
    '您好，我们可以寄{x}。',
    '寄样品 · jì yàngpǐn · kirim sampel',
    '寄|发|送',
    [
      ('蓝色样品', 'sampel biru', '蓝色样品|蓝色的样品|蓝色款'),
      ('白色样品', 'sampel putih', '白色样品|白色的样品|白色款'),
    ],
  ),
  (
    'Konfirmasi pembayaran',
    '我们刚转了{x}。请帮我确认你们收到了没有。',
    'Kami baru transfer {x}. Tolong konfirmasi penerimaannya.',
    '谢谢，已经收到{x}。',
    '收到款项 · shōudào kuǎnxiàng · menerima pembayaran',
    '收到|到账',
    [('六百元', '600 yuan', '六百元|600元'), ('九百元', '900 yuan', '九百元|900元')],
  ),
  (
    'Janji temu bisnis',
    '我想来拜访贵公司，{x}见面方便吗？',
    'Bisa bertemu {x}?',
    '可以，我们{x}见面。',
    '见面 · jiànmiàn · bertemu',
    '见面|会面|安排|方便',
    [
      ('星期二下午', 'Selasa sore', '(?:星期二|周二)下午'),
      ('星期四上午', 'Kamis pagi', '(?:星期四|周四)上午'),
    ],
  ),
];

const _b = <Recipe>[
  (
    'Pengiriman bertahap',
    '请确认能先发{x}。',
    '',
    '我们先发{x}，余货随后补发。',
    '',
    '先发|分批|先寄',
    [('四十件', '', '四十件|40件'), ('六十件', '', '六十件|60件')],
  ),
  (
    'Retur sebagian',
    '其他货没问题，只有{x}需要退回。请安排退货。',
    '',
    '我们同意退回{x}。',
    '',
    '退货|退回|安排退',
    [('八件', '', '八件|8件'), ('十二件', '', '十二件|12件')],
  ),
  (
    'Sengketa tagihan',
    '这笔运费不在合同范围内。请确认会退回{x}。',
    '',
    '核实后，我们会退回{x}。',
    '',
    '退回|退款|退给|退还',
    [('三百元', '', '三百元|300元'), ('五百元', '', '五百元|500元')],
  ),
  (
    'Alternatif saat stok habis',
    '原来的型号缺货。我能接受{x}，请确认替代型号。',
    '',
    '我们可以换成{x}。',
    '',
    '换|替代|改用',
    [('A型', '', '[Aa]型|甲型'), ('C型', '', '[Cc]型|丙型')],
  ),
  (
    'Perubahan pesanan',
    '订单还没发货。请把数量调整到{x}。',
    '',
    '我们把数量改成{x}，价格保持原样。',
    '',
    '改|调整|变更',
    [('七十件', '', '七十件|70件'), ('九十件', '', '九十件|90件')],
  ),
  (
    'Negosiasi harga',
    '采购量会增加。请明确答复是否同意打{x}。',
    '',
    '同意，这批订单可以打{x}。',
    '',
    '打|同意|给您',
    [('九折', '', '九折|9折'), ('八五折', '', '八五折|85折|8[.]5折')],
  ),
  (
    'Tenggat produksi',
    '原来的交付安排已经来不及，最迟得{x}完工。能保证吗？',
    '',
    '我们保证{x}完工。',
    '',
    '完工|完成生产|生产完',
    [('星期三', '', '星期三|周三'), ('星期五', '', '星期五|周五')],
  ),
  (
    'Komplain kualitas',
    '抽检结果不合格。请确认会复检{x}。',
    '',
    '我们会安排复检{x}。',
    '',
    '复检|重新检验|重新检查',
    [('整批产品', '', '整批|全批|全部产品'), ('第二批产品', '', '第二批|第2批')],
  ),
  (
    'Termin pembayaran',
    '我们希望在收货后{x}内付款，请确认是否同意这个账期。',
    '',
    '我们同意收货后{x}内付款。',
    '',
    '付款|账期|结款',
    [('三十天', '', '三十天|30天|一个月'), ('四十五天', '', '四十五天|45天')],
  ),
  (
    'Koordinasi keluhan pemasok',
    '供应商和客户给出的说法不一致。请先联系{x}核实。',
    '',
    '我们先联系{x}核实。',
    '',
    '联系|核实|确认',
    [('供应商', '', '供应商|供货商'), ('客户', '', '客户|买方')],
  ),
];

List<(Scenario, String)> practicePool(PracticeLevel level, Random random) => [
  if (level == PracticeLevel.a) ...[
    (lateDelivery, '送到 · sòngdào · tiba | 道歉 · dàoqiàn · minta maaf'),
    (wrongBatch, '换货 · huànhuò · tukar barang | 蓝色 · lánsè · biru'),
    (invoiceMismatch, '退款 · tuìkuǎn · pengembalian | 发票 · fāpiào · faktur'),
  ],
  for (final (index, (title, prompt, meaning, answer, hint, action, details))
      in (level == PracticeLevel.a ? _a : _b).indexed)
    () {
      final (word, translation, pattern) =
          details[random.nextInt(details.length)];
      return (
        Scenario(
          id: '${level.name}-${index + 1}',
          title: title,
          client: '',
          today: 0,
          deadline: 0,
          deadlineZh: '',
          deadlineId: '',
          minPct: 0,
          patience: 3,
          lines: const {},
          practice: PracticeGoal(
            Line(
              prompt.replaceAll('{x}', word),
              meaning.replaceAll('{x}', translation),
            ),
            Line(answer.replaceAll('{x}', word), ''),
            hint,
            action,
            pattern,
          ),
        ),
        hint,
      );
    }(),
];

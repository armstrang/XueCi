/// Opening the sealed part (assets/data/s0.bin, `s-<lang>.bin`): a short readable header, a zero byte, then deflated
/// JSON under a xoshiro128** keystream seeded by SHA-256 of a phrase, the HSK 6 words and the file name
/// (written by tool/make_assets.py).
library;

import 'dart:convert';
import 'dart:io' show ZLibDecoder;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

Object? unseal(Uint8List buf, String name, String hsk6) {
  final z = buf.indexOf(0);
  final x = Uint8List.fromList(buf.sublist(z + 1));
  final sd = crypto.sha256.convert(utf8.encode('天外有天|$hsk6|$name')).bytes;
  int u32(int i) => sd[i] | (sd[i + 1] << 8) | (sd[i + 2] << 16) | (sd[i + 3] << 24);
  var a = u32(0), b = u32(4), c = u32(8), d = u32(12);
  const m = 0xFFFFFFFF;
  int rotl(int v, int k) => ((v << k) | (v >> (32 - k))) & m;
  for (var i = 0; i < x.length; i += 4) {
    final o = (rotl((b * 5) & m, 7) * 9) & m;
    final t = (b << 9) & m;
    c ^= a;
    d ^= b;
    b ^= c;
    a ^= d;
    c ^= t;
    d = rotl(d, 11);
    for (var k = 0; k < 4 && i + k < x.length; k++) {
      x[i + k] ^= (o >> (8 * k)) & 255;
    }
  }
  return json.decode(utf8.decode(ZLibDecoder().convert(x)));
}

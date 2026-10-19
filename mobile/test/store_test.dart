// The progress store: v1.x's data moves in on the first start, and again when an earlier move failed.
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/data/store.dart';

void main() {
  test('v1.x data fills an empty store and gets migrated', () {
    final be = MemoryBackend({});
    final s = Store(be)..open(legacy: {'mm_stats': '{"1:爱":[3,1]}', 'hsk16_theme': '"dark"'});
    expect(s.version(), 1);
    s.migrate({'1:爱'});
    expect(s.get('xc_schema', 0), Store.schema);
    expect((s.get('mm_stats', {}) as Map)['1:爱'], hasLength(3));
    s.flush();
    expect(be.loadAll()['hsk16_theme'], '"dark"');
  });

  test('a store that already moved ignores v1.x data', () {
    final be = MemoryBackend({'xc_schema': '3', 'mm_stats': '{"1:八":[1,0,2]}'});
    final s = Store(be)..open(legacy: {'mm_stats': '{"1:爱":[3,1,4]}'});
    expect((s.get('mm_stats', {}) as Map).keys, ['1:八']);
  });

  test('after a failed move, v1.x data is adopted and its own schema decides', () {
    final be = MemoryBackend({'xc_schema': '3', 'xc_onb': '1', 'mm_stats': '{}'});
    final s = Store(be)..open(legacy: {'mm_stats': '{"1:爱":[3,1]}'}, adopt: true);
    expect(s.version(), 1); // recognised from the v1.7 keys, not the new store's schema
    s.migrate({'1:爱'});
    expect((s.get('mm_stats', {}) as Map)['1:爱'], hasLength(3));
    expect(s.get('xc_onb', 0), 0); // the near-empty start is replaced
  });
}

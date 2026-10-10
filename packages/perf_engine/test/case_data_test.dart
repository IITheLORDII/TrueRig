import 'package:perf_engine/perf_engine.dart';
import 'package:test/test.dart';

void main() {
  final catalog = PartCatalog.seed();
  final cases = catalog.byCategory(PartCategory.pcCase).cast<PcCase>();
  PcCase byId(String id) => catalog.byId(id)! as PcCase;

  test('fans in the box match the makers\' spec sheets', () {
    expect(byId('lianli-o11-evo').fans.total, 0); // sold without fans
    expect(byId('lianli-o11-evo').style, CaseStyle.aquarium);
    expect(byId('montech-air100').fans.front, 3);
    expect(byId('montech-air100').fans.rear, 1);
    expect(byId('montech-air100').rgbFans, isTrue);
    expect(byId('fractal-north').fans.front, 2);
    expect(byId('fractal-north').fans.rear, 0);
    expect(byId('cm-nr200p').fans.top, 2);
    expect(byId('fractal-terra').fans.total, 0);
  });

  test('mounts match the spec sheets and hold the included fans', () {
    final o11 = byId('lianli-o11-evo').mounts;
    expect((o11.top, o11.side, o11.bottom, o11.rear), (3, 3, 3, 1));
    final nr = byId('cm-nr200p').mounts;
    expect((nr.top, nr.bottom, nr.side, nr.rear), (2, 2, 2, 1));
    expect(byId('fractal-terra').mounts.bottom, 1);
    expect(byId('corsair-4000d').mounts.front, 3);
    for (final c in cases) {
      final f = c.fans;
      final m = c.mounts;
      expect(m.total, greaterThan(0), reason: '${c.id} has no mounts');
      expect(f.front <= m.front, isTrue, reason: c.id);
      expect(f.rear <= m.rear, isTrue, reason: c.id);
      expect(f.top <= m.top, isTrue, reason: c.id);
      expect(f.bottom <= m.bottom, isTrue, reason: c.id);
      expect(f.side <= m.side, isTrue, reason: c.id);
    }
  });

  test('only small cases are drawn as compact', () {
    for (final c in cases) {
      if (c.style == CaseStyle.compact) {
        expect(c.largestBoard, FormFactor.miniItx, reason: c.id);
      }
    }
  });

  test('every liquid cooler has a radiator size', () {
    final coolers = catalog.byCategory(PartCategory.cooler).cast<Cooler>();
    for (final c in coolers.where((c) => c.isLiquid)) {
      expect([240, 280, 360, 420], contains(c.radiatorMm), reason: c.id);
    }
  });
}

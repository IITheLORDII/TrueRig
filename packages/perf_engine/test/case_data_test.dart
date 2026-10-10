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

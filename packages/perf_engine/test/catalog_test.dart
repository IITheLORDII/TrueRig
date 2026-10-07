import 'package:perf_engine/perf_engine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('every part id is unique across the catalog', () {
    final ids = catalog.all.map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('catalog is broad', () {
    expect(catalog.cpus.length, greaterThanOrEqualTo(100));
    expect(catalog.gpus.length, greaterThanOrEqualTo(90));
    expect(catalog.motherboards.length, greaterThanOrEqualTo(60));
    expect(catalog.rams.length, greaterThanOrEqualTo(40));
    expect(catalog.psus.length, greaterThanOrEqualTo(15));
  });

  test('GPU raster ordering within families is sane', () {
    double r(String id) => part<Gpu>(id).rasterScore;
    expect(r('rtx-4090'), greaterThan(r('rtx-4080')));
    expect(r('rtx-4080'), greaterThan(r('rtx-4070ti')));
    expect(r('rtx-4070'), greaterThan(r('rtx-4060ti')));
    expect(r('rtx-3080'), greaterThan(r('rtx-3070')));
    expect(r('rtx-4060'), greaterThan(r('rtx-4060-laptop')));
    expect(r('rx-7900xtx'), greaterThan(r('rx-6950xt')));
    expect(r('gtx-1080ti'), greaterThan(r('gtx-1070')));
  });

  test('CPU gaming ordering is sane', () {
    double g(String id) => part<Cpu>(id).gamingScore;
    expect(g('r7-9800x3d'), greaterThan(g('r7-7800x3d')));
    expect(g('r7-7800x3d'), greaterThan(g('r7-5800x3d')));
    expect(g('i9-13900k'), greaterThan(g('i5-12400f')));
    expect(g('i7-8700k'), greaterThan(g('i5-8400')));
  });

  test('every CPU and board socket pairs with at least one board / CPU', () {
    final cpuSockets = catalog.cpus.map((c) => c.socket).toSet();
    final boardSockets = catalog.motherboards.map((m) => m.socket).toSet();
    for (final s in boardSockets) {
      expect(cpuSockets, contains(s), reason: 'board socket $s has no CPU');
    }
    for (final s in [
      'AM4',
      'AM5',
      'LGA1151',
      'LGA1200',
      'LGA1700',
      'LGA1851'
    ]) {
      expect(boardSockets, contains(s));
    }
  });

  test('generic entries are compatible with matching CPUs', () {
    final b = PcBuild(
      cpu: part<Cpu>('r5-7600'),
      motherboard: part<Motherboard>('mb-b650-atx'),
      ram: part<Ram>('ram-ddr5-6000-2x16'),
      psu: part<Psu>('psu-650-gold'),
      pcCase: part<PcCase>('case-atx-mid'),
      cooler: part<Cooler>('cooler-tower-120'),
    );
    expect(const CompatibilityChecker().check(b).isCompatible, isTrue);
  });

  test('generic DDR4 B760 rejects DDR5 RAM', () {
    final b = PcBuild(
      motherboard: part<Motherboard>('mb-b760-atx-ddr4'),
      ram: part<Ram>('ram-ddr5-6000-2x16'),
    );
    expect(const CompatibilityChecker().check(b).isCompatible, isFalse);
  });
}

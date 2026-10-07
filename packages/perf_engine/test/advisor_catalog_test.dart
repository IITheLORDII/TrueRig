import 'package:perf_engine/perf_engine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('UpgradeAdvisor', () {
    const advisor = UpgradeAdvisor();

    test('CPU-bound AM4 build gets AM4 CPU upgrades only', () {
      final b = PcBuild(
        cpu: part<Cpu>('r5-5600'),
        gpu: part<Gpu>('rtx-4080s'),
        motherboard: part<Motherboard>('asus-b550-plus'),
        ram: part<Ram>('gskill-ddr4-3600-32'),
      );
      final advice =
          advisor.advise(build: b, catalog: catalog, game: game('cyberpunk'));
      expect(advice.current.limiter, Limiter.cpu);
      expect(advice.options, isNotEmpty);
      for (final o in advice.options) {
        expect(o.part, isA<Cpu>());
        expect((o.part as Cpu).socket, 'AM4');
        expect(o.gainPercent, greaterThanOrEqualTo(kMinUsefulGainPercent));
      }
      expect(advice.freeTips.first, contains('1440p'));
    });

    test('GPU-bound build gets GPU upgrades ranked by value and respects case',
        () {
      final b = PcBuild(
        cpu: part<Cpu>('r7-7800x3d'),
        gpu: part<Gpu>('rtx-4060'),
        ram: part<Ram>('kingston-ddr5-5600-16x1'),
        psu: part<Psu>('corsair-cx650'),
        pcCase: part<PcCase>('montech-air100'),
      );
      final advice = advisor.advise(
          build: b,
          catalog: catalog,
          game: game('rdr2'),
          resolution: Resolution.p1440);
      expect(advice.current.limiter, Limiter.gpu);
      expect(advice.options.every((o) => o.part is Gpu), isTrue);
      expect(
          advice.options.every((o) => (o.part as Gpu).lengthMm <= 330), isTrue);
      final values = advice.options.map((o) => o.fpsPer100Usd ?? 0).toList();
      for (var i = 1; i < values.length; i++) {
        expect(values[i], lessThanOrEqualTo(values[i - 1]));
      }
      expect(advice.freeTips.any((t) => t.contains('Tek RAM')), isTrue);
    });

    test('budget filter and PSU flag', () {
      final b = PcBuild(
        cpu: part<Cpu>('r7-7800x3d'),
        gpu: part<Gpu>('rtx-4060'),
        psu: part<Psu>('cm-mwe-550'),
      );
      final advice = advisor.advise(
          build: b,
          catalog: catalog,
          game: game('cyberpunk'),
          resolution: Resolution.p2160,
          budgetUsd: 2000,
          limit: 50);
      expect(advice.options.every((o) => o.part.refPriceUsd! <= 2000), isTrue);
      final big = advice.options.firstWhere((o) => o.part.id == 'rtx-5090');
      expect(big.needsPsuUpgrade, isTrue);
    });

    test('laptops get no hardware upgrades, only a tip', () {
      final b = PcBuild(
        cpu: part<Cpu>('i5-12450h'),
        gpu: part<Gpu>('rtx-4060-laptop'),
      );
      final advice = advisor.advise(
          build: b, catalog: catalog, game: game('cyberpunk'), limit: 50);
      expect(advice.options, isEmpty);
      expect(advice.freeTips.first, contains('Dizüstü'));
    });

    test('desktop builds are never offered laptop parts', () {
      final b =
          PcBuild(cpu: part<Cpu>('r7-7800x3d'), gpu: part<Gpu>('gtx-1650'));
      final advice = advisor.advise(
          build: b, catalog: catalog, game: game('rdr2'), limit: 200);
      expect(advice.options.any((o) => o.part.id.endsWith('-laptop')), isFalse);
    });

    test('throws without CPU and GPU', () {
      expect(
        () => advisor.advise(
            build: const PcBuild(), catalog: catalog, game: game('cs2')),
        throwsArgumentError,
      );
    });
  });

  group('PartCatalog search', () {
    test('exact MPN lookup ranks first', () {
      final r = catalog.search('CMK32GX5M2B6000Z30');
      expect(r.first.id, 'corsair-ddr5-6000-32');
    });

    test('MPN with separators still matches', () {
      expect(catalog.search('100-100000910wof').first.id, 'r7-7800x3d');
    });

    test('fuzzy name tokens match regardless of spacing', () {
      expect(catalog.search('4070 super').first.id, 'rtx-4070s');
      expect(catalog.search('rtx4090').map((p) => p.id), contains('rtx-4090'));
    });

    test('category filter and empty query', () {
      expect(catalog.search('ryzen', category: PartCategory.gpu), isEmpty);
      expect(catalog.search('   '), isEmpty);
    });

    test('Turkish characters are folded', () {
      expect(PartCatalog.normalize('İŞLEMCİ Güç'), 'islemci guc');
    });

    test('byCategory and byId', () {
      for (final c in PartCategory.values) {
        expect(catalog.byCategory(c), isNotEmpty);
      }
      expect(catalog.byId('nope'), isNull);
    });
  });

  group('PcBuild', () {
    test('withPart is immutable and without clears a slot', () {
      const empty = PcBuild();
      final withCpu = empty.withPart(part<Cpu>('r5-7600'));
      expect(empty.cpu, isNull);
      expect(withCpu.cpu?.id, 'r5-7600');
      expect(withCpu.without(PartCategory.cpu).cpu, isNull);
      expect(withCpu.parts, hasLength(1));
    });
  });
}

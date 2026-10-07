import 'package:perf_engine/perf_engine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const parser = SpecTextParser;
  final p = SpecTextParser(catalog);

  group('prebuilt catalog', () {
    test('every variant points to existing laptop-appropriate parts', () {
      expect(kPrebuilts.map((s) => s.id).toSet(), hasLength(kPrebuilts.length));
      for (final s in kPrebuilts) {
        expect(s.variants, isNotEmpty, reason: s.id);
        for (final v in s.variants) {
          expect(catalog.byId(v.cpuId), isA<Cpu>(),
              reason: '${s.id} ${v.cpuId}');
          final gpu = catalog.byId(v.gpuId);
          expect(gpu, isA<Gpu>(), reason: '${s.id} ${v.gpuId}');
          expect(catalog.byId(v.ramId), isA<Ram>(),
              reason: '${s.id} ${v.ramId}');
          if (s.isLaptop) {
            expect(isLaptopGpu(gpu! as Gpu), isTrue,
                reason: '${s.id} ${v.gpuId}');
          }
        }
      }
    });

    test('Casper Excalibur G770 is present with several configurations', () {
      final g770 = kPrebuilts.firstWhere((s) => s.id == 'casper-g770');
      expect(g770.displayName, 'Casper Excalibur G770');
      expect(g770.variants.length, greaterThanOrEqualTo(3));
    });

    test('G770 covers older generations and the GTX 1650 models', () {
      final g770 = kPrebuilts.firstWhere((s) => s.id == 'casper-g770');
      final cpus = g770.variants.map((v) => v.cpuId).toSet();
      expect(cpus,
          containsAll(['i5-10300h', 'i5-11400h', 'i5-12450h', 'i7-13700h']));
      expect(g770.variants.where((v) => v.gpuId == 'gtx-1650-laptop'),
          hasLength(greaterThanOrEqualTo(2)));
      expect(g770.variants.every((v) => v.year != null), isTrue);
    });

    test('every model lists its generations with a year', () {
      for (final s in kPrebuilts) {
        expect(s.variants.length, greaterThanOrEqualTo(3), reason: s.id);
        for (final v in s.variants) {
          expect(v.year, isNotNull, reason: '${s.id} ${v.cpuId}');
        }
      }
    });

    test('catalog spans many brands, years and desktops', () {
      expect(kPrebuilts.length, greaterThanOrEqualTo(50));
      expect(kPrebuilts.map((s) => s.brand).toSet().length,
          greaterThanOrEqualTo(8));
      expect(kPrebuilts.any((s) => !s.isLaptop), isTrue);
      final years = kPrebuilts
          .expand((s) => s.variants)
          .map((v) => v.year)
          .whereType<int>();
      expect(years.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(2018));
    });
  });

  group('SpecTextParser ($parser)', () {
    test('desktop store title with KF suffix and Super GPU', () {
      final r = p.parse(
        'Zeiron Mirage X15 Intel Core i7-14700KF 32 GB RAM 512 GB M.2 SSD '
        '1 TB HDD GeForce RTX 4070 Super FreeDOS Masaüstü Oyun Bilgisayarı',
      );
      expect(r.cpu?.id, 'i7-14700k');
      expect(r.gpu?.id, 'rtx-4070s');
      expect(r.ram?.totalGb, 32);
      expect(r.isLaptop, isFalse);
    });

    test('laptop title maps GPU to the laptop chip and glued tokens', () {
      final r = p.parse(
        'Casper Excalibur G770.1245 Intel Core i5 12450H 16GB RAM 500GB SSD '
        'RTX3050 4GB Windows 11',
      );
      expect(r.isLaptop, isTrue);
      expect(r.cpu?.id, 'i5-12450h');
      expect(r.gpu?.id, 'rtx-3050-laptop');
      expect(r.ram?.totalGb, 16);
      expect(r.ram?.type, MemoryType.ddr4);
    });

    test('AMD build with DDR5 and speed', () {
      final r = p.parse(
        'AMD Ryzen 5 7600 RX 7600 16GB DDR5 6000MHz 1TB NVMe Gaming PC',
      );
      expect(r.cpu?.id, 'r5-7600');
      expect(r.gpu?.id, 'rx-7600');
      expect(r.ram?.type, MemoryType.ddr5);
      expect(r.ram?.speedMts, 6000);
    });

    test('unrelated text yields nothing', () {
      expect(p.parse('Kablosuz oyuncu mouse RGB').isEmpty, isTrue);
    });

    test('parsed build is valid input for the estimator', () {
      final b =
          p.parse('Ryzen 7 7800X3D RTX 4070 Ti Super 32GB DDR5').toBuild();
      expect(b.cpu?.id, 'r7-7800x3d');
      expect(b.gpu?.id, 'rtx-4070tis');
    });
  });
}

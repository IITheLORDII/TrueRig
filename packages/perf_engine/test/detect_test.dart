import 'dart:convert';

import 'package:perf_engine/perf_engine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

String encode(Map<String, Object?> json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

void main() {
  final matcher = HardwareMatcher(catalog);

  group('HardwareMatcher GPU (WebGL renderer strings)', () {
    final cases = {
      'ANGLE (NVIDIA, NVIDIA GeForce RTX 4070 SUPER Direct3D11 vs_5_0 ps_5_0, D3D11)':
          'rtx-4070s',
      'ANGLE (NVIDIA, NVIDIA GeForce RTX 4070 Ti SUPER Direct3D11 vs_5_0 ps_5_0, D3D11)':
          'rtx-4070tis',
      'ANGLE (NVIDIA, NVIDIA GeForce RTX 4070 Direct3D11 vs_5_0 ps_5_0, D3D11)':
          'rtx-4070',
      'ANGLE (AMD, AMD Radeon RX 7900 XTX Direct3D11 vs_5_0 ps_5_0, D3D11)':
          'rx-7900xtx',
      'ANGLE (AMD, AMD Radeon RX 7800 XT Direct3D11 vs_5_0 ps_5_0, D3D11)':
          'rx-7800xt',
      'NVIDIA GeForce RTX 3060': 'rtx-3060-12',
      'Intel(R) Arc(TM) B580 Graphics': 'arc-b580',
    };
    cases.forEach((raw, id) {
      test(raw, () => expect(matcher.matchGpu(raw)?.id, id));
    });

    test('integrated / unknown GPUs do not match', () {
      expect(
          matcher.matchGpu('ANGLE (Intel, Intel(R) UHD Graphics 770)'), isNull);
      expect(matcher.matchGpu('Apple M3'), isNull);
      expect(matcher.matchGpu(''), isNull);
    });
  });

  group('HardwareMatcher CPU (OS names)', () {
    final cases = {
      'AMD Ryzen 7 7800X3D 8-Core Processor': 'r7-7800x3d',
      'AMD Ryzen 5 5600 6-Core Processor': 'r5-5600',
      'AMD Ryzen 5 5600X 6-Core Processor': 'r5-5600x',
      '13th Gen Intel(R) Core(TM) i5-13600K': 'i5-13600k',
      'Intel(R) Core(TM) Ultra 9 285K': 'cu9-285k',
      '12th Gen Intel(R) Core(TM) i5-12400F': 'i5-12400f',
    };
    cases.forEach((raw, id) {
      test(raw, () => expect(matcher.matchCpu(raw)?.id, id));
    });
  });

  test('displayName cleans ANGLE renderer strings', () {
    expect(
      HardwareMatcher.displayName(
        'ANGLE (Intel, Intel(R) UHD Graphics (0x000046A3) Direct3D11 vs_5_0 ps_5_0, D3D11)',
      ),
      'Intel(R) UHD Graphics',
    );
    expect(
      HardwareMatcher.displayName(
        'ANGLE (NVIDIA, NVIDIA GeForce RTX 4070 SUPER Direct3D11 vs_5_0 ps_5_0, D3D11)',
      ),
      'NVIDIA GeForce RTX 4070 SUPER',
    );
    expect(HardwareMatcher.displayName('NVIDIA GeForce GTX 1650'),
        'NVIDIA GeForce GTX 1650');
  });

  test('isIntegratedGpu', () {
    expect(HardwareMatcher.isIntegratedGpu('Intel(R) UHD Graphics'), isTrue);
    expect(HardwareMatcher.isIntegratedGpu('AMD Radeon(TM) Graphics'), isTrue);
    expect(HardwareMatcher.isIntegratedGpu('NVIDIA GeForce GTX 1650'), isFalse);
    expect(HardwareMatcher.isIntegratedGpu('AMD Radeon RX 7800 XT'), isFalse);
  });

  test('motherboard product names match', () {
    expect(
      matcher.matchMotherboard('ROG STRIX B650E-F GAMING WIFI')?.id,
      'asus-b650e-f',
    );
  });

  test('cpu candidates by thread count', () {
    final c = matcher.cpuCandidatesForThreads(16).map((c) => c.id);
    expect(c, containsAll(['r7-7800x3d', 'r7-9700x', 'r7-5800x3d']));
    expect(c, isNot(contains('r5-7600')));
  });

  group('HardwareReport.decode', () {
    test('decodes the Windows helper payload', () {
      final r = HardwareReport.decode(encode({
        'v': 1,
        'cpu': 'AMD Ryzen 7 7800X3D 8-Core Processor',
        'cores': 8,
        'threads': 16,
        'gpus': ['AMD Radeon(TM) Graphics', 'NVIDIA GeForce RTX 4070 SUPER'],
        'ram': [
          {'gb': 16, 'mts': 6000, 'type': 34},
          {'gb': 16, 'mts': 6000, 'type': 34},
        ],
        'board': 'ROG STRIX B650E-F GAMING WIFI',
      }))!;
      expect(r.source, 'windows-helper');
      expect(r.totalRamGb, 32);
      expect(r.ramModules.first.type, MemoryType.ddr5);
    });

    test('rejects malformed, oversize or wrong-version input', () {
      expect(HardwareReport.decode('not base64 !!'), isNull);
      expect(HardwareReport.decode(encode({'v': 2})), isNull);
      expect(HardwareReport.decode(encode({'v': 1, 'gpus': 'x'})), isNull);
      expect(HardwareReport.decode('A' * 5000), isNull);
      expect(HardwareReport.decode(''), isNull);
    });
  });

  group('HardwareDetector', () {
    final detector = HardwareDetector(matcher);

    test('full helper report resolves CPU, discrete GPU, board and RAM', () {
      final res = detector.resolve(const HardwareReport(
        cpuName: 'AMD Ryzen 7 7800X3D 8-Core Processor',
        threads: 16,
        gpuNames: ['AMD Radeon(TM) Graphics', 'NVIDIA GeForce RTX 4070 SUPER'],
        ramModules: [
          RamModule(sizeGb: 16, speedMts: 6000, type: MemoryType.ddr5),
          RamModule(sizeGb: 16, speedMts: 6000, type: MemoryType.ddr5),
        ],
        boardName: 'ROG STRIX B650E-F GAMING WIFI',
      ));
      expect(res.build.cpu?.id, 'r7-7800x3d');
      expect(res.build.gpu?.id, 'rtx-4070s');
      expect(res.build.motherboard?.id, 'asus-b650e-f');
      expect(res.build.ram?.totalGb, 32);
      expect(res.build.ram?.moduleCount, 2);
      expect(res.build.ram?.speedMts, 6000);
      expect(res.cpuCandidates, isEmpty);
      expect(res.unmatched, isEmpty);
      // Detected RAM is a valid input for the compatibility checker.
      expect(
          const CompatibilityChecker().check(res.build).isCompatible, isTrue);
    });

    test('browser report: GPU only, CPU candidates from threads', () {
      final res = detector.resolve(const HardwareReport(
        threads: 12,
        gpuNames: [
          'ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 Direct3D11 vs_5_0 ps_5_0, D3D11)',
        ],
        source: 'browser',
      ));
      expect(res.build.cpu, isNull);
      expect(res.build.gpu?.id, 'rtx-4060');
      expect(res.cpuCandidates.every((c) => c.threads == 12), isTrue);
      expect(res.cpuCandidates, isNotEmpty);
    });

    test('real laptop report (helper output) resolves fully', () {
      final r = HardwareReport.decode(encode({
        'v': 1,
        'cpu': '12th Gen Intel(R) Core(TM) i5-12450H',
        'cores': 8,
        'threads': 12,
        'gpus': ['NVIDIA GeForce GTX 1650', 'Intel(R) UHD Graphics'],
        'ram': [
          {'gb': 16, 'mts': 3200, 'type': 26},
          {'gb': 16, 'mts': 3200, 'type': 26},
        ],
        'board': 'CASPER BILGISAYAR SISTEMLERI NLAK 001',
      }))!;
      final res = detector.resolve(r);
      expect(res.build.cpu?.id, 'i5-12450h');
      expect(res.build.gpu?.id, 'gtx-1650');
      expect(res.build.ram?.type, MemoryType.ddr4);
      expect(res.build.ram?.totalGb, 32);
      expect(res.build.motherboard, isNull);
      // And it produces a usable estimate.
      final fps = const FpsEstimator().estimate(
        game: game('cs2'),
        cpu: res.build.cpu!,
        gpu: res.build.gpu!,
        ram: res.build.ram,
      );
      expect(fps.avgFps, greaterThan(60));
    });

    test('tier words never fall back to the base card', () {
      expect(
          matcher.matchGpu('NVIDIA GeForce GTX 1650 SUPER')?.id, 'gtx-1650s');
      expect(matcher.matchGpu('NVIDIA GeForce RTX 3050 Ti Laptop GPU')?.id,
          'rtx-3050ti-laptop');
      // No RTX 4060 Super exists: must not become a plain 4060.
      expect(matcher.matchGpu('NVIDIA GeForce RTX 4060 Super'), isNull);
    });

    test('laptop and desktop GPUs are told apart', () {
      expect(
        matcher.matchGpu('NVIDIA GeForce RTX 4060 Laptop GPU')?.id,
        'rtx-4060-laptop',
      );
      expect(matcher.matchGpu('NVIDIA GeForce RTX 4060')?.id, 'rtx-4060');
      expect(
        matcher
            .matchGpu(
              'ANGLE (NVIDIA, NVIDIA GeForce RTX 4070 Laptop GPU (0x00002820) '
              'Direct3D11 vs_5_0 ps_5_0, D3D11)',
            )
            ?.id,
        'rtx-4070-laptop',
      );
    });

    test('unknown parts are reported, not guessed', () {
      final res = detector.resolve(const HardwareReport(
        cpuName: 'Intel(R) Pentium(R) Gold G7400',
        gpuNames: ['Intel(R) UHD Graphics 710'],
      ));
      expect(res.build.parts, isEmpty);
      expect(res.unmatched, hasLength(2));
    });
  });
}

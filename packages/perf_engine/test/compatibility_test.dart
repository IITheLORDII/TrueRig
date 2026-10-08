import 'package:perf_engine/perf_engine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const checker = CompatibilityChecker();

  Set<String> codes(PcBuild b) =>
      checker.check(b).issues.map((i) => i.code).toSet();

  final goodBuild = PcBuild(
    cpu: part<Cpu>('r7-7800x3d'),
    gpu: part<Gpu>('rtx-4070s'),
    motherboard: part<Motherboard>('asrock-x870e-taichi'),
    ram: part<Ram>('corsair-ddr5-6000-32'),
    psu: part<Psu>('corsair-rm750e'),
    pcCase: part<PcCase>('lianli-o11-evo'),
    cooler: part<Cooler>('thermalright-pa120se'),
  );

  test('a correct AM5 build has no errors or warnings', () {
    final report = checker.check(goodBuild);
    expect(report.isCompatible, isTrue);
    expect(report.bySeverity(IssueSeverity.error), isEmpty);
    expect(report.bySeverity(IssueSeverity.warning), isEmpty);
  });

  test('AM4 CPU on AM5 board is a socket error', () {
    final b = goodBuild.withPart(part<Cpu>('r7-5800x3d'));
    expect(codes(b), contains('socket_mismatch'));
    expect(checker.check(b).isCompatible, isFalse);
  });

  test('DDR4 RAM on DDR5 board is an error', () {
    final b = goodBuild.withPart(part<Ram>('kingston-ddr4-3200-32'));
    expect(codes(b), contains('ram_type_mismatch'));
  });

  test('650W PSU with RTX 4090 is flagged and recommends 900W', () {
    final b = goodBuild
        .withPart(part<Gpu>('rtx-4090'))
        .withPart(part<Psu>('corsair-cx650'));
    final report = checker.check(b);
    expect(
      report.issues.map((i) => i.code),
      anyOf(contains('psu_insufficient'), contains('psu_low_headroom')),
    );
    expect(report.recommendedPsuW, 900);
    expect(codes(b), contains('psu_connector'));
  });

  test('550W PSU with RTX 5090 is insufficient', () {
    final b = goodBuild
        .withPart(part<Gpu>('rtx-5090'))
        .withPart(part<Psu>('cm-mwe-550'));
    expect(codes(b), contains('psu_insufficient'));
  });

  test('ATX board in ITX case and long GPU are errors', () {
    final b = goodBuild
        .withPart(part<Motherboard>('msi-b650-tomahawk'))
        .withPart(part<PcCase>('fractal-terra'))
        .withPart(part<Gpu>('rtx-4090'));
    expect(codes(b),
        containsAll(['case_form_factor', 'gpu_too_long', 'cooler_too_tall']));
  });

  test('Zen 5 on early B650 board warns about BIOS', () {
    final b = goodBuild
        .withPart(part<Cpu>('r7-9800x3d'))
        .withPart(part<Motherboard>('msi-b650-tomahawk'));
    expect(codes(b), contains('bios_update'));
    expect(checker.check(b).isCompatible, isTrue);
  });

  test('single RAM stick warns about single channel', () {
    final b = goodBuild.withPart(part<Ram>('kingston-ddr5-5600-16x1'));
    expect(codes(b), contains('ram_single_channel'));
  });

  test('stock cooler on a 253W CPU warns, wrong socket errors', () {
    final intel = PcBuild(
      cpu: part<Cpu>('i9-14900k'),
      cooler: part<Cooler>('amd-wraith-stealth'),
    );
    expect(codes(intel), containsAll(['cooler_socket', 'cooler_weak']));
  });

  test('CPU without iGPU and no GPU cannot display', () {
    final b = PcBuild(cpu: part<Cpu>('i5-12400f'));
    expect(codes(b), contains('no_display_output'));
  });

  test('RAM faster than board limit and PCIe downgrade are info only', () {
    final b = PcBuild(
      cpu: part<Cpu>('r7-7800x3d'),
      motherboard: part<Motherboard>('msi-b650-tomahawk'),
      ram: part<Ram>('corsair-ddr5-6000-32'),
    );
    final report = checker.check(b);
    expect(report.isCompatible, isTrue);
    expect(codes(b), contains('pcie_downgrade'));
  });

  test('too many modules for a 2-slot ITX board is an error', () {
    const quad = Ram(
        id: 'quad',
        brand: 'X',
        model: 'Quad kit',
        type: MemoryType.ddr5,
        speedMts: 6000,
        moduleCount: 4,
        moduleSizeGb: 16,
        casLatency: 30);
    final b =
        PcBuild(motherboard: part<Motherboard>('msi-b650i-edge'), ram: quad);
    expect(codes(b), contains('ram_slots'));
  });

  group('memory without a motherboard', () {
    PcBuild build(String cpu, String ram, [String? gpu]) {
      var b = PcBuild(cpu: part<Cpu>(cpu), ram: part<Ram>(ram));
      if (gpu != null) b = b.withPart(part<Gpu>(gpu));
      return b;
    }

    test('DDR4-only CPU with DDR5 memory is an error', () {
      final b = build('r5-5600', 'ram-ddr5-6000-2x16');
      expect(codes(b), contains('ram_cpu_type'));
      final msg = checker
          .check(b)
          .issues
          .firstWhere((i) => i.code == 'ram_cpu_type')
          .message;
      expect(msg, contains('DDR4'));
    });

    test('laptop CPU with desktop DIMM memory is an error', () {
      expect(codes(build('i5-10300h', 'ram-ddr4-3200-2x8')),
          contains('ram_form_laptop'));
    });

    test('laptop CPU with matching SO-DIMM memory is fine', () {
      final c =
          codes(build('i5-10300h', 'ram-so-ddr4-3200-2x8', 'gtx-1650-laptop'));
      expect(
          c.intersection(
              {'ram_cpu_type', 'ram_form_laptop', 'ram_form_desktop'}),
          isEmpty);
    });

    test('desktop CPU with SO-DIMM memory is an error', () {
      expect(codes(build('i5-13400f', 'ram-so-ddr4-3200-2x8')),
          contains('ram_form_desktop'));
    });

    test('DDR3 platform: DDR3 fits, DDR4 does not', () {
      final ok = codes(build('i7-4790k', 'ram-ddr3-1600-2x8'));
      expect(ok.intersection({'ram_cpu_type', 'ram_form_desktop'}), isEmpty);
      expect(codes(build('i7-4790k', 'ram-ddr4-3200-2x8')),
          contains('ram_cpu_type'));
    });

    test('with a board the existing board rule reports it once', () {
      final b = goodBuild.withPart(part<Ram>('ram-ddr4-3200-2x16'));
      final c = checker.check(b).issues.map((i) => i.code).toList();
      expect(c, contains('ram_type_mismatch'));
      expect(c, isNot(contains('ram_cpu_type')));
    });
  });
}

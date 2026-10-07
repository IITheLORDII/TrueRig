import 'package:flutter_test/flutter_test.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/features/analysis/plain_verdict.dart';

void main() {
  final parts = PartCatalog.seed();
  final mobile = MobileCatalog.seed();
  const analyzer = SystemBottleneckAnalyzer();

  SystemBottleneck pc(String cpu, String gpu) => analyzer.analyze(
    cpu: parts.byId(cpu)! as Cpu,
    gpu: parts.byId(gpu)! as Gpu,
    resolution: Resolution.p1080,
  );

  PhoneSpec phone(String id) {
    final p = mobile.phone(id)!;
    return PhoneSpec(
      phone: p,
      soc: mobile.soc(p.socId)!,
      ramGb: p.defaultRamGb,
    );
  }

  group('pcVerdict', () {
    test('weak CPU with a top GPU names the CPU', () {
      final v = pcVerdict(pc('r5-3600', 'rtx-4090'));
      expect(v.title, contains('İşlemcin'));
      expect(v.tone, isNot(Tone.good));
      expect(v.detail, contains('FPS'));
    });

    test('weak GPU with a top CPU is judged by FPS', () {
      final v = pcVerdict(pc('r7-9800x3d', 'gtx-1650'));
      // "Oyunlar oynanır, ekran kartı sınırda" or "Ekran kartın ... zayıf".
      expect(v.title, contains('kran kart'));
      expect(v.tone, isNot(Tone.good));
    });

    test('a normal mid-range pair is called good, not weak', () {
      final v = pcVerdict(pc('r5-7600', 'rtx-4060'));
      expect(v.title, 'Bilgisayarın oyunlar için iyi');
      expect(v.tone, Tone.good);
    });

    test('FPS words', () {
      expect(fpsWord(144), 'akıcı');
      expect(fpsWord(45), 'oynanır');
      expect(fpsWord(20), 'takılır');
    });
  });

  test('phoneVerdict speaks in tiers and battery hours', () {
    final s = phone('pixel-8');
    final v = phoneVerdict(
      const PhoneEstimator().summarize(s),
      const PhoneInsightEstimator().analyze(s, currentYear: 2026),
    );
    expect(v.title, endsWith('telefon'));
    expect(v.detail, contains('saat'));
  });

  group('watchVerdict', () {
    final watch = mobile.watches.firstWhere(
      (w) =>
          w.worksWith.length == 1 && w.worksWith.single == MobilePlatform.ios,
    );
    const compat = WatchCompatibility();

    test('no phone asks for one', () {
      expect(watchVerdict(compat.check(watch, null)).title, 'Telefonunu seç');
    });

    test('Apple Watch with an Android phone is incompatible', () {
      final v = watchVerdict(compat.check(watch, mobile.phone('pixel-8')));
      expect(v.tone, Tone.bad);
      expect(v.title, contains('çalışmaz'));
    });

    test('Apple Watch with an iPhone is compatible', () {
      final v = watchVerdict(compat.check(watch, mobile.phone('iphone-15')));
      expect(v.tone, isNot(Tone.bad));
    });
  });
}

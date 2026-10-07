import 'package:perf_engine/perf_engine.dart';
import 'package:test/test.dart';

void main() {
  final m = MobileCatalog.seed();
  const est = PhoneEstimator();

  PhoneSpec spec(String id, {int? ram, String? code}) {
    final p = m.phone(id)!;
    return PhoneSpec(
      phone: p,
      soc: m.soc(p.socIdFor(code))!,
      ramGb: ram ?? p.defaultRamGb,
    );
  }

  MobileGameProfile game(String id) =>
      kMobileGames.firstWhere((g) => g.id == id);

  group('catalog integrity', () {
    test('ids are unique and every phone has a known chip', () {
      expect(m.phones.map((p) => p.id).toSet(), hasLength(m.phones.length));
      expect(m.watches.map((w) => w.id).toSet(), hasLength(m.watches.length));
      expect(m.socs.map((s) => s.id).toSet(), hasLength(m.socs.length));
      for (final p in m.phones) {
        expect(m.soc(p.socId), isNotNull, reason: p.id);
        for (final v in p.socVariants.values) {
          expect(m.soc(v), isNotNull, reason: '${p.id} variant $v');
        }
        expect(p.ramOptionsGb, isNotEmpty, reason: p.id);
      }
    });

    test('catalog covers both platforms and many brands', () {
      expect(m.phones.length, greaterThanOrEqualTo(100));
      expect(
          m.phoneBrands, containsAll(['Apple', 'Samsung', 'Google', 'Xiaomi']));
      expect(m.watches.length, greaterThanOrEqualTo(30));
    });

    test('chip ordering is sane', () {
      double gpu(String id) => m.soc(id)!.gpuScore;
      expect(gpu('a18-pro'), greaterThan(gpu('a16')));
      expect(gpu('a16'), greaterThan(gpu('a15-5gpu')));
      expect(gpu('sd-8-elite'), greaterThan(gpu('sd-8g3')));
      expect(gpu('sd-8g3'), greaterThan(gpu('sd-8g2')));
      expect(gpu('sd-7sg2'), greaterThan(gpu('sd-685')));
    });
  });

  group('matchPhone', () {
    test('iOS machine identifiers', () {
      expect(m.matchPhone('iPhone16,1')?.phone.id, 'iphone-15-pro');
      expect(m.matchPhone('iPhone16,2')?.phone.id, 'iphone-15-pro-max');
      expect(m.matchPhone('iPhone12,8')?.phone.id, 'iphone-se-2');
    });

    test('Android model codes with regional chips', () {
      final eu = m.matchPhone('SM-S921B')!;
      final us = m.matchPhone('SM-S921U')!;
      expect(eu.phone.id, 'galaxy-s24');
      expect(eu.socId, 'exynos-2400');
      expect(us.socId, 'sd-8g3');
      expect(m.matchPhone('SM-S928B/DS')?.phone.id, 'galaxy-s24-ultra');
    });

    test('marketing names respect tier words', () {
      expect(m.matchPhone('Galaxy S24 Ultra')?.phone.id, 'galaxy-s24-ultra');
      expect(m.matchPhone('Galaxy S24+')?.phone.id, 'galaxy-s24-plus');
      expect(m.matchPhone('Galaxy S24')?.phone.id, 'galaxy-s24');
      expect(m.matchPhone('Pixel 8 Pro')?.phone.id, 'pixel-8-pro');
      expect(m.matchPhone('Pixel 8a')?.phone.id, 'pixel-8a');
      expect(m.matchPhone('Redmi Note 13 Pro+')?.phone.id,
          'redmi-note-13-pro-plus');
      expect(m.matchPhone('Galaxy S99 Turbo'), isNull);
    });
  });

  test('search filters by brand and tokens, newest first', () {
    final r = m.searchPhones('pro max', brand: 'Apple');
    expect(r.first.id, 'iphone-17-pro-max');
    expect(r.every((p) => p.brand == 'Apple'), isTrue);
    expect(m.searchPhones('s24').map((p) => p.id), contains('galaxy-s24-fe'));
  });

  group('PhoneEstimator', () {
    test('flagship vs entry tiers', () {
      expect(est.summarize(spec('iphone-16-pro')).tier, PhoneTier.flagship);
      expect(est.summarize(spec('iphone-15-pro')).tier, PhoneTier.flagship);
      expect(est.summarize(spec('galaxy-s25')).tier, PhoneTier.flagship);
      expect(est.summarize(spec('galaxy-s23')).tier, PhoneTier.upper);
      expect(est.summarize(spec('galaxy-a55')).tier, PhoneTier.mid);
      expect(est.summarize(spec('galaxy-a16', ram: 4)).tier, PhoneTier.entry);
      expect(
        est.summarize(spec('iphone-17-pro')).score,
        greaterThan(est.summarize(spec('iphone-13')).score),
      );
    });

    test('Genshin on iPhone 15 Pro sits near the 60 FPS cap at high', () {
      final e = est.game(game('genshin'), spec('iphone-15-pro'));
      expect(e.limitFps, 60);
      expect(e.peakFps, inInclusiveRange(52, 60));
      expect(e.sustainedFps, lessThan(e.peakFps));
    });

    test('Redmi Note 13 needs low settings in Genshin', () {
      final e = est.game(game('genshin'), spec('redmi-note-13', ram: 6));
      expect(e.recommendedPreset, GraphicsPreset.low);
      expect(e.peakFps, lessThan(20));
      final low = est.game(game('genshin'), spec('redmi-note-13', ram: 6),
          preset: GraphicsPreset.low);
      expect(low.peakFps, greaterThan(e.peakFps * 2.5));
    });

    test('light games hold the cap when warm and recommend max settings', () {
      final e = est.game(game('clash-royale'), spec('pixel-8'));
      expect(e.sustainedFps, 60);
      expect(e.recommendedPreset, GraphicsPreset.ultra);
    });

    test('display refresh rate caps FPS (60 Hz iPhone 15)', () {
      final e = est.game(game('codm'), spec('iphone-15'));
      expect(e.limitFps, 60);
      expect(e.peakFps, lessThanOrEqualTo(60));
    });

    test('too little RAM is flagged', () {
      final e = est.game(game('wuwa'), spec('galaxy-a15', ram: 4));
      expect(e.ramShort, isTrue);
    });

    test('apps: multitasking depends on RAM', () {
      final multi = kMobileApps.firstWhere((a) => a.id == 'multitask');
      final small = est.app(multi, spec('galaxy-a15', ram: 4));
      final big = est.app(multi, spec('galaxy-a15', ram: 8));
      expect(big.score, greaterThan(small.score));
      // A fast phone with little RAM: RAM is the weak link.
      expect(est.app(multi, spec('iphone-13')).weakestComponent, 'RAM');
    });

    test('on-device LLM: 4B fits on 8 GB phone, 8B does not', () {
      final q4 = kMobileLlmModels.firstWhere((x) => x.id == 'qwen3-4b-m');
      final q8 = kMobileLlmModels.firstWhere((x) => x.id == 'qwen3-8b-m');
      final s = spec('iphone-16-pro');
      final ok = est.llm(q4, Quantization.q4km, s);
      expect(ok.placement, LlmPlacement.fullGpu);
      expect(ok.tokensPerSecond, inInclusiveRange(10, 25));
      expect(
          est.llm(q8, Quantization.q4km, s).placement, LlmPlacement.doesNotFit);
      expect(
        est.llm(q8, Quantization.q4km, spec('iphone-17-pro')).placement,
        LlmPlacement.fullGpu,
      );
    });
  });

  group('WatchCompatibility', () {
    const wc = WatchCompatibility();

    test('Apple Watch + Android phone is an error', () {
      final r = wc.check(m.watch('aw-s10')!, m.phone('galaxy-s24')!);
      expect(r.isCompatible, isFalse);
      expect(r.issues.first.code, 'watch_platform');
      expect(r.availableFeatures, isEmpty);
    });

    test('Apple Watch + iPhone is compatible', () {
      final r = wc.check(m.watch('aw-ultra-2')!, m.phone('iphone-15-pro')!);
      expect(r.isCompatible, isTrue);
      expect(r.availableFeatures, contains(WatchFeature.ecg));
    });

    test('Galaxy Watch ECG needs a Samsung phone', () {
      final pixel = wc.check(m.watch('gw-7')!, m.phone('pixel-8')!);
      expect(pixel.isCompatible, isTrue);
      expect(pixel.issues.map((i) => i.code), contains('watch_samsung_only'));
      expect(pixel.availableFeatures, isNot(contains(WatchFeature.ecg)));
      final samsung = wc.check(m.watch('gw-7')!, m.phone('galaxy-s24')!);
      expect(samsung.availableFeatures, contains(WatchFeature.ecg));
    });

    test('Android version requirement is enforced', () {
      final ok = wc.check(m.watch('gw-8')!, m.phone('redmi-12')!);
      expect(ok.issues.map((i) => i.code), isNot(contains('watch_os_version')));
      const oldPhone = Phone(
        id: 'old',
        brand: 'Test',
        model: 'Eski',
        platform: MobilePlatform.android,
        socId: 'helio-g85',
        ramOptionsGb: [3],
        storageOptionsGb: [32],
        displayHz: 60,
        batteryMah: 4000,
        year: 2019,
        maxOsMajor: 10,
      );
      final old = wc.check(m.watch('gw-8')!, oldPhone);
      expect(old.isCompatible, isFalse);
      expect(old.issues.map((i) => i.code), contains('watch_os_version'));
    });

    test('Huawei watch with iPhone works with limits; no phone = info', () {
      final r = wc.check(m.watch('huawei-watch-gt5')!, m.phone('iphone-13')!);
      expect(r.isCompatible, isTrue);
      expect(r.issues.map((i) => i.code), contains('watch_ios_limited'));
      final none = wc.check(m.watch('huawei-watch-gt5')!, null);
      expect(none.isCompatible, isFalse);
      expect(none.batteryDays, 14);
    });
  });
}

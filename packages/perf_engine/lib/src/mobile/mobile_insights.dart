import 'dart:math' as math;

import 'package:perf_engine/src/mobile/mobile_models.dart';
import 'package:perf_engine/src/mobile/phone_estimator.dart';

/// How well a phone handles one everyday scenario (0..100).
class UsageRating {
  const UsageRating(this.name, this.score);

  final String name;
  final double score;

  String get verdict => score >= 80
      ? 'Mükemmel'
      : score >= 60
          ? 'İyi'
          : score >= 40
              ? 'Yeterli'
              : 'Zayıf';
}

/// Phone-only facts that do not exist on a PC: battery, heat, updates.
class PhoneInsights {
  const PhoneInsights({
    required this.screenOnHours,
    required this.gamingHours,
    required this.sustainedPercent,
    required this.supportUntilYear,
    required this.supportYearsLeft,
    required this.usage,
  });

  /// Typical mixed use (social, video, browsing) on one charge.
  final double screenOnHours;

  /// Heavy 3D gaming on one charge.
  final double gamingHours;

  /// Share of peak performance kept after ~20 min of gaming.
  final double sustainedPercent;

  /// Year the last major OS update arrives.
  final int supportUntilYear;
  final int supportYearsLeft;
  final List<UsageRating> usage;
}

class PhoneInsightEstimator {
  const PhoneInsightEstimator({this.estimator = const PhoneEstimator()});

  final PhoneEstimator estimator;

  /// iOS 26 and Android 16 both shipped in 2025.
  static const int _iosBase = 26;
  static const int _androidBase = 16;
  static const int _baseYear = 2025;

  /// Battery voltage used to turn mAh into Wh.
  static const double _cellVolts = 3.85;

  /// Average draw in mixed use and in 3D gaming at 60 Hz, 4 nm (watts).
  static const double _mixedWatts = 1.9;
  static const double _gamingWatts = 5.0;

  PhoneInsights analyze(PhoneSpec spec, {required int currentYear}) {
    final phone = spec.phone;
    final soc = spec.soc;
    final wh = phone.batteryMah / 1000 * _cellVolts;
    final efficiency = _processEfficiency(soc.processNm) *
        (phone.platform == MobilePlatform.ios ? 1.12 : 1.0);
    final hz = _refreshFactor(phone.displayHz);
    final summary = estimator.summarize(spec);

    final base = phone.platform == MobilePlatform.ios ? _iosBase : _androidBase;
    final untilYear = _baseYear + (phone.maxOsMajor - base);

    final c = summary.components;
    double comp(String key) => (c[key] ?? 0).toDouble();
    final st = comp('Tek çekirdek');
    final mt = comp('Çok çekirdek');
    final gpu = comp('Grafik (GPU)');
    final ram = comp('RAM');
    final sustained = summary.sustainedPercent / 100;

    return PhoneInsights(
      screenOnHours: wh / (_mixedWatts * hz / efficiency),
      gamingHours: wh / (_gamingWatts / efficiency),
      sustainedPercent: summary.sustainedPercent,
      supportUntilYear: untilYear,
      supportYearsLeft: math.max(0, untilYear - currentYear),
      usage: [
        UsageRating('Günlük kullanım', _cap(st * 0.8 + ram * 0.2 + 15)),
        UsageRating('Sosyal medya & video', _cap(st * 0.6 + ram * 0.4 + 10)),
        UsageRating('Çoklu görev', _cap(ram * 0.7 + mt * 0.3)),
        UsageRating('Fotoğraf / video düzenleme', _cap(mt * 0.5 + gpu * 0.5)),
        UsageRating('Ağır oyun (uzun süre)', _cap(gpu * sustained)),
      ],
    );
  }

  static double _cap(double v) => v.clamp(0, 100).toDouble();

  static double _processEfficiency(int nm) => nm <= 3
      ? 1.0
      : nm <= 4
          ? 0.92
          : nm <= 5
              ? 0.85
              : nm <= 7
                  ? 0.75
                  : 0.65;

  static double _refreshFactor(int hz) => hz >= 144
      ? 1.2
      : hz >= 120
          ? 1.15
          : hz >= 90
              ? 1.08
              : 1.0;
}

/// Watch-only facts: battery in different modes and health / sport kit.
class WatchInsights {
  const WatchInsights({
    required this.typicalDays,
    required this.alwaysOnDays,
    required this.gpsHours,
    required this.healthFeatures,
    required this.sportFeatures,
  });

  final double typicalDays;
  final double alwaysOnDays;

  /// Continuous GPS workout on one charge.
  final double gpsHours;
  final List<WatchFeature> healthFeatures;
  final List<WatchFeature> sportFeatures;
}

class WatchInsightEstimator {
  const WatchInsightEstimator();

  /// Always-on display roughly costs a third of the battery life.
  static const double _alwaysOnShare = 0.65;

  /// GPS tracking drains about 4x faster than mixed use (24 h → ~6 h on
  /// smartwatches; long-life watches scale the same way).
  static const double _gpsShare = 0.25;

  static const _health = [
    WatchFeature.ecg,
    WatchFeature.spo2,
    WatchFeature.bloodPressure,
    WatchFeature.skinTemp,
  ];
  static const _sport = [
    WatchFeature.gps,
    WatchFeature.lte,
    WatchFeature.nfcPay,
    WatchFeature.appStore,
  ];

  WatchInsights analyze(Watch w) => WatchInsights(
        typicalDays: w.batteryHours / 24,
        alwaysOnDays: w.batteryHours * _alwaysOnShare / 24,
        gpsHours: w.features.contains(WatchFeature.gps)
            ? w.batteryHours * _gpsShare
            : 0,
        healthFeatures: [
          for (final f in _health)
            if (w.features.contains(f)) f,
        ],
        sportFeatures: [
          for (final f in _sport)
            if (w.features.contains(f)) f,
        ],
      );
}

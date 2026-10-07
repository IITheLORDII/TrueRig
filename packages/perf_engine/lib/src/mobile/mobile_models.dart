/// Phone / smartwatch models. Scores are relative indices:
/// - [Soc.cpuSt] / [Soc.cpuMt]: Apple A18 Pro = 100 (Geekbench 6 class)
/// - [Soc.gpuScore]: Apple A18 Pro = 100 (3DMark Wild Life Extreme class)
library;

enum MobilePlatform { ios, android }

extension MobilePlatformLabel on MobilePlatform {
  String get label => switch (this) {
        MobilePlatform.ios => 'iOS',
        MobilePlatform.android => 'Android',
      };
}

/// Phone / watch system-on-chip.
class Soc {
  const Soc({
    required this.id,
    required this.name,
    required this.vendor,
    required this.cpuSt,
    required this.cpuMt,
    required this.gpuScore,
    required this.npuTops,
    required this.memBandwidthGbs,
    required this.processNm,
    required this.year,
    this.sustained = 0.75,
  });

  final String id;
  final String name;
  final String vendor;
  final double cpuSt;
  final double cpuMt;
  final double gpuScore;
  final double npuTops;
  final double memBandwidthGbs;
  final int processNm;
  final int year;

  /// Share of peak performance kept after ~20 min of gaming (throttling).
  final double sustained;
}

class Phone {
  const Phone({
    required this.id,
    required this.brand,
    required this.model,
    required this.platform,
    required this.socId,
    required this.ramOptionsGb,
    required this.storageOptionsGb,
    required this.displayHz,
    required this.batteryMah,
    required this.year,
    required this.maxOsMajor,
    this.refPriceUsd,
    this.identifiers = const [],
    this.socVariants = const {},
  });

  final String id;
  final String brand;
  final String model;
  final MobilePlatform platform;

  /// Default (Turkey / global) chip.
  final String socId;
  final List<int> ramOptionsGb;
  final List<int> storageOptionsGb;
  final int displayHz;
  final int batteryMah;
  final int year;

  /// Last major OS version the phone gets (iOS 26, Android 16 ...).
  final int maxOsMajor;
  final double? refPriceUsd;

  /// iOS machine ids ("iPhone16,1") and Android model codes ("SM-S928B").
  final List<String> identifiers;

  /// Model-code prefix -> chip, for regional variants (e.g. SM-S921U ->
  /// Snapdragon while SM-S921B uses Exynos).
  final Map<String, String> socVariants;

  String get displayName => '$brand $model';

  int get defaultRamGb => ramOptionsGb.last;

  /// Chip for a specific model code, falling back to [socId].
  String socIdFor(String? modelCode) {
    if (modelCode == null) return socId;
    final code = modelCode.toUpperCase();
    for (final e in socVariants.entries) {
      if (code.startsWith(e.key.toUpperCase())) return e.value;
    }
    return socId;
  }
}

enum WatchOs { watchOs, wearOs, harmonyOs, garminOs, zeppOs, other }

extension WatchOsLabel on WatchOs {
  String get label => switch (this) {
        WatchOs.watchOs => 'watchOS',
        WatchOs.wearOs => 'Wear OS',
        WatchOs.harmonyOs => 'HarmonyOS',
        WatchOs.garminOs => 'Garmin OS',
        WatchOs.zeppOs => 'Zepp OS',
        WatchOs.other => 'Diğer',
      };
}

enum WatchFeature {
  ecg,
  spo2,
  bloodPressure,
  skinTemp,
  gps,
  lte,
  nfcPay,
  appStore
}

extension WatchFeatureLabel on WatchFeature {
  String get label => switch (this) {
        WatchFeature.ecg => 'EKG',
        WatchFeature.spo2 => 'Kan oksijeni',
        WatchFeature.bloodPressure => 'Tansiyon',
        WatchFeature.skinTemp => 'Cilt sıcaklığı',
        WatchFeature.gps => 'GPS',
        WatchFeature.lte => 'LTE (e-SIM)',
        WatchFeature.nfcPay => 'Temassız ödeme',
        WatchFeature.appStore => 'Uygulama mağazası',
      };
}

class Watch {
  const Watch({
    required this.id,
    required this.brand,
    required this.model,
    required this.os,
    required this.chip,
    required this.chipScore,
    required this.ramGb,
    required this.storageGb,
    required this.batteryHours,
    required this.year,
    required this.features,
    required this.worksWith,
    this.minIos,
    this.minAndroid,
    this.samsungOnly = const {},
    this.iosLimited = false,
    this.refPriceUsd,
  });

  final String id;
  final String brand;
  final String model;
  final WatchOs os;
  final String chip;

  /// Relative app/UI performance, Apple S9 SiP = 100.
  final double chipScore;
  final double ramGb;
  final int storageGb;

  /// Typical mixed-use battery life.
  final int batteryHours;
  final int year;
  final Set<WatchFeature> features;

  /// Phone platforms this watch can pair with.
  final Set<MobilePlatform> worksWith;
  final int? minIos;
  final int? minAndroid;

  /// Features that only work when paired with a Samsung phone.
  final Set<WatchFeature> samsungOnly;

  /// Pairs with iPhone but without notifications replies / 3rd-party apps.
  final bool iosLimited;
  final double? refPriceUsd;

  String get displayName => '$brand $model';
}

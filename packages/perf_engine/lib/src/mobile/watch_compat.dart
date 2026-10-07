import 'dart:math' as math;

import 'package:perf_engine/src/compatibility/compatibility_checker.dart';
import 'package:perf_engine/src/mobile/mobile_models.dart';

class WatchReport {
  const WatchReport({
    required this.watch,
    required this.phone,
    required this.issues,
    required this.availableFeatures,
    required this.smoothness,
    required this.batteryDays,
  });

  final Watch watch;
  final Phone? phone;
  final List<CompatibilityIssue> issues;

  /// Features that actually work with the paired phone.
  final Set<WatchFeature> availableFeatures;

  /// 0..100 UI / app smoothness.
  final double smoothness;
  final double batteryDays;

  bool get isCompatible =>
      phone != null && !issues.any((i) => i.severity == IssueSeverity.error);
}

/// Smartwatch <-> phone pairing rules.
class WatchCompatibility {
  const WatchCompatibility();

  WatchReport check(Watch w, Phone? phone) {
    final issues = <CompatibilityIssue>[];
    var features = {...w.features};

    if (phone == null) {
      issues.add(const CompatibilityIssue(
        code: 'watch_no_phone',
        severity: IssueSeverity.info,
        message: 'Uyumluluk için saatin bağlanacağı telefonu seç.',
        involved: [],
      ));
    } else {
      final platformOk = w.worksWith.contains(phone.platform);
      if (!platformOk) {
        final needs = w.worksWith.contains(MobilePlatform.ios)
            ? 'iPhone'
            : 'Android telefon';
        issues.add(CompatibilityIssue(
          code: 'watch_platform',
          severity: IssueSeverity.error,
          message: '${w.displayName} yalnızca $needs ile çalışır; '
              '${phone.displayName} ile eşleşmez.',
          involved: const [],
        ));
        features = {};
      } else {
        final minOs =
            phone.platform == MobilePlatform.ios ? w.minIos : w.minAndroid;
        if (minOs != null && phone.maxOsMajor < minOs) {
          final os = phone.platform.label;
          issues.add(CompatibilityIssue(
            code: 'watch_os_version',
            severity: IssueSeverity.error,
            message: '${w.displayName} için en az $os $minOs gerekiyor; '
                '${phone.displayName} en fazla $os ${phone.maxOsMajor} alıyor.',
            involved: const [],
          ));
        }
        final samsungOnly = w.samsungOnly.intersection(features);
        if (samsungOnly.isNotEmpty && phone.brand != 'Samsung') {
          issues.add(CompatibilityIssue(
            code: 'watch_samsung_only',
            severity: IssueSeverity.warning,
            message: '${samsungOnly.map((f) => f.label).join(' ve ')} '
                'ölçümü yalnızca Samsung telefonla çalışır.',
            involved: const [],
          ));
          features = features.difference(samsungOnly);
        }
        if (w.iosLimited && phone.platform == MobilePlatform.ios) {
          issues.add(const CompatibilityIssue(
            code: 'watch_ios_limited',
            severity: IssueSeverity.info,
            message: 'iPhone ile bildirimlere hızlı yanıt ve üçüncü parti '
                'uygulamalar sınırlıdır.',
            involved: [],
          ));
        }
      }
    }

    return WatchReport(
      watch: w,
      phone: phone,
      issues: List.unmodifiable(issues),
      availableFeatures: Set.unmodifiable(features),
      smoothness: math.min(100, w.chipScore),
      batteryDays: w.batteryHours / 24,
    );
  }
}

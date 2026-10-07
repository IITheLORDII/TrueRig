import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/widgets/common.dart';

/// One-sentence answer to "so is it good?" for people who do not know
/// what a bottleneck or FPS is.
@immutable
class PlainVerdict {
  const PlainVerdict({
    required this.title,
    required this.detail,
    required this.tone,
  });

  final String title;
  final String detail;
  final Tone tone;
}

/// 60+ smooth, 30–60 playable, below 30 stutters.
String fpsWord(double fps) => fps >= 60
    ? 'akıcı'
    : fps >= 30
    ? 'oynanır'
    : 'takılır';

/// Typical FPS over the game library (geometric mean: one very light game
/// does not hide a struggling system).
double typicalFps(List<FpsEstimate> games) {
  if (games.isEmpty) return 0;
  final logSum = games.fold<double>(0, (s, e) => s + math.log(e.avgFps));
  return math.exp(logSum / games.length);
}

/// A graphics card that sets the frame rate is normal in games; only a
/// processor holding the card back is a real bottleneck. So GPU-limited
/// systems are judged by their FPS, CPU-limited ones by the gap.
PlainVerdict pcVerdict(SystemBottleneck general) {
  final pct = general.bottleneckPercent;
  final fps = typicalFps(general.perGame);
  final fpsLine =
      'Oyunlarda ortalama ~${fps.round()} FPS alırsın: '
      '${fpsWord(fps)}.';
  final cpuLimited = general.limiter == Limiter.cpu && pct >= 10;

  if (cpuLimited) {
    final strong = pct >= 20;
    return PlainVerdict(
      title: strong
          ? 'İşlemcin ekran kartını yavaşlatıyor'
          : 'İşlemcin biraz geride kalıyor',
      detail:
          '$fpsLine Ekran kartın gücünün bir kısmını kullanamıyor; aşağıda '
          'daha uygun işlemci önerileri var.',
      tone: strong ? Tone.bad : Tone.warn,
    );
  }
  if (fps >= 60) {
    return PlainVerdict(
      title: 'Bilgisayarın oyunlar için iyi',
      detail:
          '$fpsLine Parçaların birbirini yavaşlatmıyor; daha yüksek FPS '
          'istersen ekran kartı yükseltmek en çok fark yaratır.',
      tone: Tone.good,
    );
  }
  if (fps >= 30) {
    return PlainVerdict(
      title: 'Oyunlar oynanır, ekran kartı sınırda',
      detail:
          '$fpsLine Yeni oyunlarda ayarları biraz düşürmen gerekebilir; en '
          'çok fark ekran kartı yükseltmesiyle olur.',
      tone: Tone.warn,
    );
  }
  return PlainVerdict(
    title: 'Ekran kartın yeni oyunlar için zayıf',
    detail:
        '$fpsLine Düşük ayarlarda ve hafif oyunlarda daha iyi sonuç alırsın; '
        'aşağıda yükseltme önerileri var.',
    tone: Tone.bad,
  );
}

PlainVerdict phoneVerdict(PhoneSummary s, PhoneInsights i) {
  final games = switch (s.tier) {
    PhoneTier.flagship => 'Oyunların hepsini yüksek ayarda akıcı oynar.',
    PhoneTier.upper => 'Çoğu oyunu yüksek ayarda akıcı oynar.',
    PhoneTier.mid => 'Oyunları orta ayarda rahat oynar.',
    PhoneTier.entry => 'Günlük kullanım için yeterli, ağır oyunlarda zorlanır.',
  };
  final support = i.supportYearsLeft == 0
      ? ' Yazılım güncellemeleri bitti.'
      : '';
  return PlainVerdict(
    title: '${s.tier.label} telefon',
    detail:
        '$games Pil karışık kullanımda ~${i.screenOnHours.round()} saat '
        'gider.$support',
    tone: switch (s.tier) {
      PhoneTier.flagship || PhoneTier.upper => Tone.good,
      PhoneTier.mid => Tone.brand,
      PhoneTier.entry => Tone.warn,
    },
  );
}

PlainVerdict watchVerdict(WatchReport r) {
  final phone = r.phone;
  if (phone == null) {
    return const PlainVerdict(
      title: 'Telefonunu seç',
      detail:
          'Saatin telefonunla çalışıp çalışmadığını görmek için telefonunu '
          'ekle.',
      tone: Tone.warn,
    );
  }
  if (!r.isCompatible) {
    final reason = r.issues.isEmpty ? '' : ' ${r.issues.first.message}';
    return PlainVerdict(
      title: 'Bu saat ${phone.displayName} ile çalışmaz',
      detail: 'Başka bir saat ya da telefon seçmelisin.$reason',
      tone: Tone.bad,
    );
  }
  final all = r.watch.features.length;
  final ok = r.availableFeatures.length;
  final days = r.batteryDays;
  final battery = days >= 1
      ? 'Pil ~${days.round()} gün gider.'
      : 'Pil ~${r.watch.batteryHours} saat gider.';
  return PlainVerdict(
    title: ok == all
        ? 'Telefonunla tam uyumlu'
        : 'Uyumlu, bazı özellikler çalışmaz',
    detail: ok == all
        ? 'Tüm özellikler çalışır. $battery'
        : '$all özellikten $ok tanesi bu telefonla çalışır. $battery',
    tone: ok == all ? Tone.good : Tone.warn,
  );
}

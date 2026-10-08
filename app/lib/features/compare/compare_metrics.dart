import 'package:perf_engine/perf_engine.dart';

/// One comparison line. Numeric rows mark the better side; text rows don't.
class CompareRow {
  const CompareRow(
    this.label,
    this.a,
    this.b, {
    this.unit = '',
    this.higherIsBetter = true,
    this.decimals = 0,
  }) : aText = null,
       bText = null;

  const CompareRow.text(this.label, String this.aText, String this.bText)
    : a = null,
      b = null,
      unit = '',
      higherIsBetter = true,
      decimals = 0;

  final String label;
  final double? a;
  final double? b;
  final String? aText;
  final String? bText;
  final String unit;
  final bool higherIsBetter;
  final int decimals;

  /// -1: A better, 1: B better, 0: tie / not comparable.
  int get winner {
    final x = a;
    final y = b;
    if (x == null || y == null) return 0;
    // Within 3% counts as a tie (estimates are not that precise).
    final hi = x > y ? x : y;
    if (hi == 0 || (x - y).abs() / hi < 0.03) return 0;
    final aBetter = higherIsBetter ? x > y : x < y;
    return aBetter ? -1 : 1;
  }

  String format(double? v) =>
      v == null ? '–' : '${v.toStringAsFixed(decimals)}$unit';

  String get aDisplay => aText ?? format(a);
  String get bDisplay => bText ?? format(b);
}

class CompareSection {
  const CompareSection(this.title, this.rows);
  final String title;
  final List<CompareRow> rows;
}

// ---------------------------------------------------------------- PC ------

const _pcApps = ['solidworks', 'blender', 'premiere', 'unreal5'];
const _pcLlms = ['qwen3-8b', 'qwen3-14b', 'qwen3-30b-a3b'];

List<CompareSection> comparePcs(
  PcBuild a,
  PcBuild b, {
  required Resolution resolution,
  required GraphicsPreset preset,
}) {
  const fps = FpsEstimator();
  double? gameFps(PcBuild x, GameProfile g) {
    final cpu = x.cpu;
    final gpu = x.gpu;
    if (cpu == null || gpu == null) return null;
    return fps
        .estimate(
          game: g,
          cpu: cpu,
          gpu: gpu,
          ram: x.ram,
          resolution: resolution,
          preset: preset,
        )
        .avgFps;
  }

  const apps = AppEstimator();
  const llm = LlmEstimator();
  double? tok(PcBuild x, LlmModel m) {
    final e = llm.estimate(
      model: m,
      quant: Quantization.q4km,
      cpu: x.cpu,
      gpu: x.gpu,
      ram: x.ram,
    );
    return e.placement == LlmPlacement.doesNotFit ? 0 : e.tokensPerSecond;
  }

  return [
    CompareSection('Performans', [
      CompareRow.text('İşlemci', a.cpu?.model ?? '–', b.cpu?.model ?? '–'),
      CompareRow.text('Ekran kartı', a.gpu?.model ?? '–', b.gpu?.model ?? '–'),
      CompareRow.text(
        'RAM',
        a.ram == null ? '–' : '${a.ram!.totalGb} GB',
        b.ram == null ? '–' : '${b.ram!.totalGb} GB',
      ),
      CompareRow('İşlemci (oyun)', a.cpu?.gamingScore, b.cpu?.gamingScore),
      CompareRow('Ekran kartı', a.gpu?.rasterScore, b.gpu?.rasterScore),
      CompareRow(
        'VRAM',
        a.gpu?.vramGb.toDouble(),
        b.gpu?.vramGb.toDouble(),
        unit: ' GB',
      ),
    ]),
    CompareSection('Oyun FPS (${resolution.label} ${preset.label})', [
      for (final g in kGames) CompareRow(g.name, gameFps(a, g), gameFps(b, g)),
    ]),
    CompareSection('Uygulamalar (puan)', [
      for (final id in _pcApps)
        if (kApps.where((x) => x.id == id).firstOrNull case final app?)
          CompareRow(
            app.name,
            apps.estimate(app, a).score,
            apps.estimate(app, b).score,
          ),
    ]),
    CompareSection('Yapay zekâ (LLM-local) · kelime/sn', [
      for (final id in _pcLlms)
        if (kLlmModels.where((x) => x.id == id).firstOrNull case final m?)
          CompareRow(m.name, tok(a, m), tok(b, m), decimals: 1),
    ]),
  ];
}

// ------------------------------------------------------------- Phone ------

List<CompareSection> comparePhones(
  PhoneSpec a,
  PhoneSpec b, {
  required int currentYear,
}) {
  const est = PhoneEstimator();
  const ins = PhoneInsightEstimator();
  final sa = est.summarize(a);
  final sb = est.summarize(b);
  final ia = ins.analyze(a, currentYear: currentYear);
  final ib = ins.analyze(b, currentYear: currentYear);

  return [
    CompareSection('Performans', [
      CompareRow.text('İşlemci', a.soc.name, b.soc.name),
      CompareRow('Genel puan', sa.score, sb.score),
      CompareRow('Tek çekirdek', a.soc.cpuSt, b.soc.cpuSt),
      CompareRow('Çok çekirdek', a.soc.cpuMt, b.soc.cpuMt),
      CompareRow('Grafik (GPU)', a.soc.gpuScore, b.soc.gpuScore),
      CompareRow(
        'Isınınca korunan',
        sa.sustainedPercent,
        sb.sustainedPercent,
        unit: '%',
      ),
      CompareRow('RAM', a.ramGb.toDouble(), b.ramGb.toDouble(), unit: ' GB'),
    ]),
    CompareSection('Mobil · pil, ekran, destek', [
      CompareRow(
        'Pil (karışık kullanım)',
        ia.screenOnHours,
        ib.screenOnHours,
        unit: ' sa',
        decimals: 1,
      ),
      CompareRow(
        'Pil (ağır oyun)',
        ia.gamingHours,
        ib.gamingHours,
        unit: ' sa',
        decimals: 1,
      ),
      CompareRow(
        'Ekran yenileme',
        a.phone.displayHz.toDouble(),
        b.phone.displayHz.toDouble(),
        unit: ' Hz',
      ),
      CompareRow(
        'Güncelleme desteği',
        ia.supportUntilYear.toDouble(),
        ib.supportUntilYear.toDouble(),
      ),
    ]),
    CompareSection('Günlük kullanım', [
      for (var i = 0; i < ia.usage.length; i++)
        CompareRow(ia.usage[i].name, ia.usage[i].score, ib.usage[i].score),
    ]),
    CompareSection('Oyun FPS (Yüksek, ısınınca)', [
      for (final g in kMobileGames)
        CompareRow(
          g.name,
          est.game(g, a).sustainedFps,
          est.game(g, b).sustainedFps,
        ),
    ]),
  ];
}

// ------------------------------------------------------------- Watch ------

List<CompareSection> compareWatches(WatchReport a, WatchReport b) {
  const ins = WatchInsightEstimator();
  final wa = ins.analyze(a.watch);
  final wb = ins.analyze(b.watch);
  String compat(WatchReport r) => r.phone == null
      ? 'Telefon seçilmedi'
      : (r.isCompatible ? 'Uyumlu' : 'Uyumsuz');
  return [
    CompareSection('Genel', [
      CompareRow.text('Sistem', a.watch.os.label, b.watch.os.label),
      CompareRow.text('Telefonunla', compat(a), compat(b)),
      CompareRow('Akıcılık', a.smoothness, b.smoothness),
      CompareRow(
        'Kullanılabilir özellik',
        a.availableFeatures.length.toDouble(),
        b.availableFeatures.length.toDouble(),
      ),
      CompareRow(
        'Depolama',
        a.watch.storageGb.toDouble(),
        b.watch.storageGb.toDouble(),
        unit: ' GB',
      ),
    ]),
    CompareSection('Mobil · pil', [
      CompareRow(
        'Normal kullanım',
        wa.typicalDays,
        wb.typicalDays,
        unit: ' gün',
        decimals: 1,
      ),
      CompareRow(
        'Ekran hep açık',
        wa.alwaysOnDays,
        wb.alwaysOnDays,
        unit: ' gün',
        decimals: 1,
      ),
      CompareRow('GPS ile antrenman', wa.gpsHours, wb.gpsHours, unit: ' sa'),
    ]),
    CompareSection('Özellikler', [
      for (final f in WatchFeature.values)
        if (a.watch.features.contains(f) || b.watch.features.contains(f))
          CompareRow.text(
            f.label,
            a.availableFeatures.contains(f) ? '✓' : '–',
            b.availableFeatures.contains(f) ? '✓' : '–',
          ),
    ]),
  ];
}

/// Rows where each side is ahead (ties and text rows are not counted).
({int a, int b}) countWins(List<CompareSection> sections) {
  var a = 0;
  var b = 0;
  for (final r in sections.expand((s) => s.rows)) {
    if (r.winner == -1) a++;
    if (r.winner == 1) b++;
  }
  return (a: a, b: b);
}

/// Numeric rows with the biggest relative gap (ties excluded), largest
/// first: the "why" behind the winner in plain words.
List<CompareRow> topDifferences(
  List<CompareSection> sections, {
  int count = 3,
}) {
  double gap(CompareRow r) {
    final x = r.a!;
    final y = r.b!;
    final lo = x < y ? x : y;
    final hi = x > y ? x : y;
    return lo <= 0 ? 1 : hi / lo - 1;
  }

  final rows = [
    for (final r in sections.expand((s) => s.rows))
      if (r.winner != 0) r,
  ]..sort((p, q) => gap(q).compareTo(gap(p)));
  return rows.take(count).toList();
}

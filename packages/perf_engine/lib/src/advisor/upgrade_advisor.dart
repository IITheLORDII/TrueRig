import 'dart:math' as math;

import 'package:perf_engine/src/bottleneck/system_bottleneck.dart';
import 'package:perf_engine/src/compatibility/compatibility_checker.dart';
import 'package:perf_engine/src/data/part_catalog.dart';
import 'package:perf_engine/src/fps/fps_estimator.dart';
import 'package:perf_engine/src/fps/game_profile.dart';
import 'package:perf_engine/src/models/parts.dart';
import 'package:perf_engine/src/models/pc_build.dart';

class UpgradeOption {
  const UpgradeOption({
    required this.part,
    required this.newEstimate,
    required this.fpsGain,
    required this.gainPercent,
    required this.newBottleneckPercent,
    required this.needsPsuUpgrade,
  });

  final Part part;
  final FpsEstimate newEstimate;
  final double fpsGain;
  final double gainPercent;
  final double newBottleneckPercent;

  /// True when the current PSU would be below the estimated peak load.
  final bool needsPsuUpgrade;

  /// FPS gained per 100 USD; null when no reference price is known.
  double? get fpsPer100Usd {
    final price = part.refPriceUsd;
    if (price == null || price <= 0) return null;
    return fpsGain / price * 100;
  }
}

class UpgradeAdvice {
  const UpgradeAdvice({
    required this.current,
    required this.options,
    required this.freeTips,
  });

  final FpsEstimate current;

  /// Ranked best value first.
  final List<UpgradeOption> options;

  /// No-cost suggestions (settings, RAM config, resolution).
  final List<String> freeTips;
}

/// Ignore upgrades that improve FPS by less than this.
const double kMinUsefulGainPercent = 3;

class UpgradeAdvisor {
  const UpgradeAdvisor({this.fps = const FpsEstimator()});

  final FpsEstimator fps;

  UpgradeAdvice advise({
    required PcBuild build,
    required PartCatalog catalog,
    required GameProfile game,
    Resolution resolution = Resolution.p1080,
    GraphicsPreset preset = GraphicsPreset.ultra,
    double? budgetUsd,
    int limit = 5,
  }) {
    final cpu = build.cpu;
    final gpu = build.gpu;
    if (cpu == null || gpu == null) {
      throw ArgumentError('Upgrade advice needs both a CPU and a GPU.');
    }
    final current = fps.estimate(
      game: game,
      cpu: cpu,
      gpu: gpu,
      ram: build.ram,
      resolution: resolution,
      preset: preset,
    );

    FpsEstimate run(PcBuild b) => fps.estimate(
          game: game,
          cpu: b.cpu!,
          gpu: b.gpu!,
          ram: b.ram,
          resolution: resolution,
          preset: preset,
        );

    final candidates = <Part>[
      if (current.limiter != Limiter.gpu)
        ...catalog.cpus.where((c) => _cpuFits(c, build)),
      if (current.limiter != Limiter.cpu)
        ...catalog.gpus.where((g) => _gpuFits(g, build)),
    ].where(
      (p) =>
          p.refPriceUsd != null &&
          (budgetUsd == null || p.refPriceUsd! <= budgetUsd),
    );

    final options = <UpgradeOption>[];
    for (final part in candidates) {
      final next = build.withPart(part);
      final est = run(next);
      final gainPct = (est.avgFps / current.avgFps - 1) * 100;
      if (gainPct < kMinUsefulGainPercent) continue;
      final load = CompatibilityChecker.estimatedLoadW(next) ?? 0;
      options.add(UpgradeOption(
        part: part,
        newEstimate: est,
        fpsGain: est.avgFps - current.avgFps,
        gainPercent: gainPct,
        newBottleneckPercent: est.bottleneckPercent,
        needsPsuUpgrade: build.psu != null && build.psu!.watts < load,
      ));
    }
    options.sort(_byValue);

    return UpgradeAdvice(
      current: current,
      options: List.unmodifiable(options.take(limit)),
      freeTips: List.unmodifiable(_freeTips(build, current)),
    );
  }

  /// Game-independent advice: candidates are ranked by the average FPS gain
  /// over the general game library (geometric mean of FPS ratios).
  GeneralUpgradeAdvice adviseGeneral({
    required PcBuild build,
    required PartCatalog catalog,
    Resolution resolution = Resolution.p1080,
    GraphicsPreset preset = GraphicsPreset.high,
    int limit = 5,
  }) {
    final cpu = build.cpu;
    final gpu = build.gpu;
    if (cpu == null || gpu == null) {
      throw ArgumentError('Upgrade advice needs both a CPU and a GPU.');
    }
    final analyzer = SystemBottleneckAnalyzer(fps: fps);
    SystemBottleneck run(PcBuild b) => analyzer.analyze(
          cpu: b.cpu!,
          gpu: b.gpu!,
          ram: b.ram,
          resolution: resolution,
          preset: preset,
        );
    final current = run(build);

    final candidates = <Part>[
      if (current.limiter != Limiter.gpu)
        ...catalog.cpus.where((c) => _cpuFits(c, build)),
      if (current.limiter != Limiter.cpu)
        ...catalog.gpus.where((g) => _gpuFits(g, build)),
    ].where((p) => p.refPriceUsd != null && p.refPriceUsd! > 0);

    final options = <GeneralUpgradeOption>[];
    for (final part in candidates) {
      final next = build.withPart(part);
      final after = run(next);
      var logGain = 0.0;
      for (var i = 0; i < after.perGame.length; i++) {
        logGain += math.log(
          after.perGame[i].avgFps / current.perGame[i].avgFps,
        );
      }
      final gainPct = (math.exp(logGain / after.perGame.length) - 1) * 100;
      if (gainPct < kMinUsefulGainPercent) continue;
      final load = CompatibilityChecker.estimatedLoadW(next) ?? 0;
      options.add(GeneralUpgradeOption(
        part: part,
        gainPercent: gainPct,
        after: after,
        needsPsuUpgrade: build.psu != null && build.psu!.watts < load,
      ));
    }
    options.sort((a, b) {
      final cmp = b.gainPer100Usd.compareTo(a.gainPer100Usd);
      return cmp != 0 ? cmp : b.gainPercent.compareTo(a.gainPercent);
    });

    final worstVram =
        current.perGame.map((e) => e.vramShortfallGb).fold<double>(0, math.max);
    return GeneralUpgradeAdvice(
      current: current,
      options: List.unmodifiable(options.take(limit)),
      freeTips: List.unmodifiable(
        _tips(build, current.limiter, resolution, preset, worstVram),
      ),
    );
  }

  static int _byValue(UpgradeOption a, UpgradeOption b) {
    final va = a.fpsPer100Usd ?? 0;
    final vb = b.fpsPer100Usd ?? 0;
    final cmp = vb.compareTo(va);
    return cmp != 0 ? cmp : b.fpsGain.compareTo(a.fpsGain);
  }

  bool _cpuFits(Cpu c, PcBuild b) {
    final current = b.cpu!;
    // Laptop CPUs are soldered: no CPU upgrade path.
    if (isSolderedCpu(current) || isSolderedCpu(c)) return false;
    if (c.gamingScore <= current.gamingScore) return false;
    final mb = b.motherboard;
    if (mb != null) {
      return c.socket == mb.socket && c.memoryTypes.contains(mb.memoryType);
    }
    return c.socket == current.socket;
  }

  bool _gpuFits(Gpu g, PcBuild b) {
    // Laptop GPUs are built in (length 0): neither upgradable nor installable.
    if (isLaptopGpu(b.gpu!) || isLaptopGpu(g)) return false;
    if (g.rasterScore <= b.gpu!.rasterScore) return false;
    final pcCase = b.pcCase;
    return pcCase == null || g.lengthMm <= pcCase.maxGpuLengthMm;
  }

  List<String> _freeTips(PcBuild b, FpsEstimate e) =>
      _tips(b, e.limiter, e.resolution, e.preset, e.vramShortfallGb);

  List<String> _tips(
    PcBuild b,
    Limiter limiter,
    Resolution resolution,
    GraphicsPreset preset,
    double vramShortfallGb,
  ) =>
      [
        if (isLaptopGpu(b.gpu!) || isSolderedCpu(b.cpu!))
          'Dizüstü bilgisayarlarda işlemci ve ekran kartı değiştirilemez. '
              "Şarj aletini takıp performans modunu seçmek ve RAM'i çift "
              'kanala çıkarmak en etkili iyileştirmedir.',
        if (limiter == Limiter.cpu && resolution == Resolution.p1080)
          'İşlemci darboğazı var: çözünürlüğü 1440p\'ye veya ayarları '
              'yükseltmek FPS\'i neredeyse hiç düşürmeden görüntüyü iyileştirir.',
        if (limiter == Limiter.gpu && preset != GraphicsPreset.low)
          'Ekran kartı darboğazı var: DLSS/FSR/XeSS "Kalite" modu ya da bir '
              'kademe düşük ayar %20-40 FPS kazandırır.',
        if (vramShortfallGb > 0)
          'VRAM yetersiz (${vramShortfallGb.toStringAsFixed(1)} GB eksik): '
              'doku kalitesini bir kademe düşürün, takılmalar azalır.',
        if (b.ram != null && b.ram!.moduleCount == 1)
          'Tek RAM modülü var: aynı modülden bir tane daha takıp çift kanala '
              'geçmek CPU darboğazını belirgin azaltır.',
        if (b.ram != null &&
            b.ram!.type == MemoryType.ddr5 &&
            b.ram!.speedMts >= 6000)
          'BIOS\'ta EXPO/XMP profilini açtığınızdan emin olun; kapalıysa RAM '
              '4800 MT/s\'de çalışır.',
      ];
}

class GeneralUpgradeOption {
  const GeneralUpgradeOption({
    required this.part,
    required this.gainPercent,
    required this.after,
    required this.needsPsuUpgrade,
  });

  final Part part;

  /// Average FPS gain over the game library.
  final double gainPercent;
  final SystemBottleneck after;
  final bool needsPsuUpgrade;

  double get gainPer100Usd => gainPercent / part.refPriceUsd! * 100;
}

class GeneralUpgradeAdvice {
  const GeneralUpgradeAdvice({
    required this.current,
    required this.options,
    required this.freeTips,
  });

  final SystemBottleneck current;
  final List<GeneralUpgradeOption> options;
  final List<String> freeTips;
}

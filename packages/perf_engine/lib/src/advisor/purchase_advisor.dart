import 'dart:math' as math;

import 'package:perf_engine/src/app_perf/app_estimator.dart';
import 'package:perf_engine/src/data/part_catalog.dart';
import 'package:perf_engine/src/data/prebuilt_catalog.dart';
import 'package:perf_engine/src/data/workload_catalog.dart';
import 'package:perf_engine/src/fps/fps_estimator.dart';
import 'package:perf_engine/src/fps/game_profile.dart';
import 'package:perf_engine/src/llm/llm_estimator.dart';
import 'package:perf_engine/src/models/parts.dart';
import 'package:perf_engine/src/models/pc_build.dart';

/// What the computer is for.
enum Usage { office, gaming, media, engineering, ai, coding }

extension UsageLabel on Usage {
  String get label => switch (this) {
        Usage.office => 'İnternet, ofis ve ders',
        Usage.gaming => 'Oyun',
        Usage.media => 'Video ve fotoğraf düzenleme',
        Usage.engineering => 'Mühendislik ve çizim (SolidWorks, AutoCAD)',
        Usage.ai => 'Yapay zekâ (bilgisayarda çalışan modeller)',
        Usage.coding => 'Yazılım geliştirme',
      };
}

enum GameLevel { light, medium, heavy }

extension GameLevelLabel on GameLevel {
  String get label => switch (this) {
        GameLevel.light => 'Hafif oyunlar (LoL, Valorant, CS2)',
        GameLevel.medium => 'Popüler oyunlar (GTA V, Fortnite, PUBG)',
        GameLevel.heavy => 'Yeni ve ağır oyunlar (Cyberpunk, RDR2)',
      };

  List<String> get gameIds => switch (this) {
        GameLevel.light => const ['cs2', 'valorant'],
        GameLevel.medium => const ['gtav', 'fortnite', 'pubg'],
        GameLevel.heavy => const ['cyberpunk', 'rdr2', 'wukong'],
      };
}

enum FormChoice { laptop, desktop, any }

/// The buyer's answers.
class UsageProfile {
  const UsageProfile({
    required this.uses,
    this.gameLevel = GameLevel.medium,
    this.highFps = false,
    this.form = FormChoice.any,
    this.budgetTry,
  });

  final Set<Usage> uses;
  final GameLevel gameLevel;

  /// 144 FPS (competitive) instead of 60.
  final bool highFps;
  final FormChoice form;

  /// Upper limit in Turkish lira; null = "bilmiyorum".
  final double? budgetTry;
}

/// One system the buyer could get.
class PurchaseOption {
  const PurchaseOption({
    required this.label,
    required this.name,
    required this.build,
    required this.isLaptop,
    required this.priceTry,
    required this.why,
    required this.score,
  });

  /// "En uygun", "Dengeli", "Uzun ömürlü".
  final String label;
  final String name;
  final PcBuild build;
  final bool isLaptop;

  /// Rough street price estimate (list price × rate × Turkish taxes).
  final double priceTry;

  /// Plain sentence: what it does for the chosen uses.
  final String why;

  /// Relative power (for ordering only).
  final double score;
}

class PurchaseAdvice {
  const PurchaseAdvice({
    required this.options,
    required this.cautions,
    required this.overBudget,
  });

  final List<PurchaseOption> options;

  /// "Dikkat et": traps for this kind of use.
  final List<String> cautions;

  /// Nothing that does the job fits the budget (options are the closest).
  final bool overBudget;
}

/// Street price in Turkey vs US list price × rate (taxes, import, margin).
const double kTurkeyPriceFactor = 1.35;

/// Motherboard, case, power supply, SSD for a desktop (USD).
const double kDesktopPlatformUsd = 250;

/// Rough new laptop prices by graphics class (USD), for comparison only.
const Map<String, double> kLaptopTierUsd = {
  'igpu': 550,
  'mx': 650,
  'gtx-1650-laptop': 700,
  'rtx-2050-laptop': 700,
  'rtx-3050-laptop': 800,
  'rtx-3050ti-laptop': 850,
  'rtx-4050-laptop': 1000,
  'rtx-4060-laptop': 1200,
  'rtx-5060-laptop': 1300,
  'rx-7600s-laptop': 1100,
  'rtx-4070-laptop': 1500,
  'rtx-5070-laptop': 1600,
  'rtx-5070ti-laptop': 2100,
  'rtx-4080-laptop': 2400,
  'rtx-5080-laptop': 2800,
  'rtx-4090-laptop': 3200,
  'rtx-5090-laptop': 3800,
};

/// Desktop processors / graphics cards built into suggestions (current,
/// widely sold). APUs carry their integrated graphics.
const _desktopCpus = [
  'i3-12100f',
  'i5-12400f',
  'i5-13400f',
  'i5-14600k',
  'i7-14700k',
  'r5-5600',
  'r5-7600',
  'r7-7800x3d',
  'r7-9800x3d',
  'cu5-245k',
];
const _apus = {
  'r5-5600g': 'vega8-igpu',
  'r5-8600g': 'radeon-680m-igpu',
  'r7-8700g': 'radeon-780m-igpu',
  // Intel desktop chips with built-in (UHD 730/770) graphics.
  'i5-12400': 'uhd-igpu',
  'i5-14600k': 'uhd-igpu',
  'i7-14700k': 'uhd-igpu',
};
const _desktopGpus = [
  'rtx-3050',
  'rx-7600',
  'rtx-4060',
  'rtx-5060',
  'arc-b580',
  'rtx-4060ti',
  'rx-9060xt-16',
  'rtx-5060ti-16',
  'rx-7800xt',
  'rtx-4070s',
  'rtx-5070',
  'rx-9070xt',
  'rtx-5070ti',
  'rtx-5080',
];

class _Candidate {
  _Candidate(this.name, this.build, this.isLaptop, this.priceUsd);

  final String name;
  final PcBuild build;
  final bool isLaptop;
  final double priceUsd;
}

class PurchaseAdvisor {
  const PurchaseAdvisor({
    this.fps = const FpsEstimator(),
    this.apps = const AppEstimator(),
    this.llm = const LlmEstimator(),
  });

  final FpsEstimator fps;
  final AppEstimator apps;
  final LlmEstimator llm;

  PurchaseAdvice advise(
    UsageProfile p,
    PartCatalog catalog, {
    required double usdTry,
  }) {
    final uses = p.uses.isEmpty ? {Usage.office} : p.uses;
    final ramNeed = ramNeededGb(uses);
    final all = [
      if (p.form != FormChoice.desktop) ..._laptops(catalog),
      if (p.form != FormChoice.laptop) ..._desktops(catalog, ramNeed),
    ];
    double tryOf(_Candidate c) => c.priceUsd * usdTry * kTurkeyPriceFactor;

    final graphicsWork = needsGraphics(uses);
    final passing = [
      for (final c in all)
        if (_meets(c.build, uses, p, ramNeed) &&
            // No gaming graphics card for office / coding: it only adds cost.
            (graphicsWork || (c.build.gpu?.rasterScore ?? 0) < 15))
          c,
    ]..sort((a, b) => a.priceUsd.compareTo(b.priceUsd));
    double powerOf(PcBuild b) => power(b, graphics: graphicsWork);

    final budget = p.budgetTry;
    final inBudget = budget == null
        ? passing
        : passing.where((c) => tryOf(c) <= budget * 1.05).toList();
    final overBudget = budget != null && inBudget.isEmpty && passing.isNotEmpty;
    final pool = inBudget.isEmpty ? passing : inBudget;

    final picks = <(String, _Candidate)>[];
    if (pool.isNotEmpty) {
      final cheapest = pool.first;
      picks.add(('En uygun', cheapest));
      final base = powerOf(cheapest.build);
      final balanced = pool.firstWhereOrNull(
        (c) =>
            c.priceUsd >= cheapest.priceUsd * 1.15 &&
            powerOf(c.build) >= base * 1.25,
      );
      if (balanced != null) picks.add(('Dengeli', balanced));
      final lasting = pool.firstWhereOrNull(
        (c) =>
            powerOf(c.build) >= base * 1.6 &&
            (balanced == null || c.priceUsd > balanced.priceUsd),
      );
      if (lasting != null) picks.add(('Uzun ömürlü', lasting));
    }

    return PurchaseAdvice(
      options: [
        for (final (label, c) in picks)
          PurchaseOption(
            label: label,
            name: c.name,
            build: c.build,
            isLaptop: c.isLaptop,
            priceTry: tryOf(c),
            why: _why(c.build, uses, p),
            score: powerOf(c.build),
          ),
      ],
      cautions: _cautions(uses, p, passing, all, tryOf),
      overBudget: overBudget,
    );
  }

  /// RAM the chosen uses need (GB).
  static int ramNeededGb(Set<Usage> uses) {
    var need = 8;
    if (uses.contains(Usage.gaming) || uses.contains(Usage.coding)) need = 16;
    if (uses.contains(Usage.media) ||
        uses.contains(Usage.engineering) ||
        uses.contains(Usage.ai)) {
      need = 32;
    }
    return need;
  }

  /// Uses that need a real graphics card.
  static bool needsGraphics(Set<Usage> uses) =>
      uses.contains(Usage.gaming) ||
      uses.contains(Usage.media) ||
      uses.contains(Usage.engineering) ||
      uses.contains(Usage.ai);

  /// Relative power for ordering suggestions: graphics + processor for
  /// graphics work, otherwise the processor (multi-core first).
  static double power(PcBuild b, {bool graphics = true}) => graphics
      ? (b.gpu?.rasterScore ?? 0) * 2 + (b.cpu?.gamingScore ?? 0)
      : (b.cpu?.mtScore ?? 0) * 2 + (b.cpu?.stScore ?? 0);

  List<GameProfile> _games(GameLevel level) => [
        for (final id in level.gameIds)
          if (kGames.where((g) => g.id == id).firstOrNull case final g?) g,
      ];

  /// Typical FPS over the chosen games (1080p; High, Medium for 144 FPS).
  double gameFps(PcBuild b, UsageProfile p) {
    final cpu = b.cpu;
    final gpu = b.gpu;
    if (cpu == null || gpu == null) return 0;
    final games = _games(p.gameLevel);
    if (games.isEmpty) return 0;
    final preset = p.highFps ? GraphicsPreset.medium : GraphicsPreset.high;
    final logSum = games.fold<double>(
      0,
      (s, g) =>
          s +
          math.log(
            fps
                .estimate(
                  game: g,
                  cpu: cpu,
                  gpu: gpu,
                  ram: b.ram,
                  resolution: Resolution.p1080,
                  preset: preset,
                )
                .avgFps,
          ),
    );
    return math.exp(logSum / games.length);
  }

  double aiTokensPerSec(PcBuild b) {
    final model = kLlmModels.firstWhere((m) => m.id == 'qwen3-8b');
    return llm
        .estimate(
          model: model,
          quant: Quantization.q4km,
          cpu: b.cpu,
          gpu: b.gpu,
          ram: b.ram,
        )
        .tokensPerSecond;
  }

  bool _appsOk(PcBuild b, List<String> ids) => ids.every((id) {
        final app = kApps.where((a) => a.id == id).firstOrNull;
        return app == null ||
            apps.estimate(app, b).rating != AppRating.struggles;
      });

  bool _meets(PcBuild b, Set<Usage> uses, UsageProfile p, int ramNeed) {
    final cpu = b.cpu;
    if (cpu == null || b.gpu == null) return false;
    if ((b.ram?.totalGb ?? 0) < ramNeed) return false;
    if (cpu.stScore < 40) return false; // even office work feels slow
    if (uses.contains(Usage.gaming) && gameFps(b, p) < (p.highFps ? 144 : 60)) {
      return false;
    }
    if (uses.contains(Usage.media) &&
        !_appsOk(b, const ['premiere', 'photoshop', 'davinci'])) {
      return false;
    }
    if (uses.contains(Usage.engineering) &&
        !_appsOk(b, const ['solidworks', 'autocad', 'revit'])) {
      return false;
    }
    if (uses.contains(Usage.ai) &&
        ((b.gpu?.vramGb ?? 0) < 8 || aiTokensPerSec(b) < 15)) {
      return false;
    }
    if (uses.contains(Usage.coding) && cpu.mtScore < 25) return false;
    return true;
  }

  String _why(PcBuild b, Set<Usage> uses, UsageProfile p) {
    final parts = <String>[];
    if (uses.contains(Usage.gaming)) {
      final f = gameFps(b, p);
      parts.add('seçtiğin oyunlarda ortalama ~${f.round()} FPS');
    }
    if (uses.contains(Usage.media) || uses.contains(Usage.engineering)) {
      parts.add('düzenleme ve çizim programlarını rahat açar');
    }
    if (uses.contains(Usage.ai)) {
      parts.add(
        'yapay zekâ modelleri saniyede ~${aiTokensPerSec(b).round()} kelime',
      );
    }
    if (parts.isEmpty) parts.add('ofis, internet ve dersler için yeterli');
    final text = parts.join(', ');
    return '${text[0].toUpperCase()}${text.substring(1)}.';
  }

  List<String> _cautions(
    Set<Usage> uses,
    UsageProfile p,
    List<_Candidate> passing,
    List<_Candidate> all,
    double Function(_Candidate) tryOf,
  ) {
    final out = <String>[];
    final gaming = uses.contains(Usage.gaming);
    final heavyWork = uses.contains(Usage.media) ||
        uses.contains(Usage.engineering) ||
        uses.contains(Usage.ai);
    if (gaming && p.gameLevel != GameLevel.light) {
      out.add(
        'Ekran kartı olmayan (sadece "dahili grafik" yazan) bilgisayar alma; '
        'oyunlar çok takılır ya da hiç açılmaz. Kasanın ya da laptopun '
        'görüntüsüne değil, ekran kartı modeline bak.',
      );
    }
    if (gaming) {
      out.add(
        'Oyunda en çok fark ekran kartından gelir. "i7 işlemci" yazması tek '
        'başına oyunda iyi olduğu anlamına gelmez.',
      );
    }
    if (!gaming && !heavyWork) {
      final gamingCheapest = all
          .where((c) => (c.build.gpu?.rasterScore ?? 0) >= 18)
          .map(tryOf)
          .fold<double?>(null, (m, v) => m == null || v < m ? v : m);
      final ours = passing.isEmpty ? null : tryOf(passing.first);
      final saving =
          gamingCheapest != null && ours != null ? gamingCheapest - ours : null;
      out.add(
        'Oyuncu bilgisayarına gerek yok: harici ekran kartı fiyatı artırır ama '
        'ofis ve ders işini hızlandırmaz.'
        '${saving != null && saving > 0 ? ' Böylece ~${_round(saving)} TL tasarruf edersin.' : ''}',
      );
      out.add(
        'Pahalı her zaman daha iyi değildir; senin işin için hızlı bir SSD ve '
        'yeterli RAM daha önemli.',
      );
    }
    if (uses.contains(Usage.ai)) {
      out.add(
        'Yapay zekâ için ekran kartı belleği (VRAM) en az 8 GB, tercihen 12–16 '
        'GB olmalı; işlemci tek başına yavaş kalır.',
      );
    }
    final need = ramNeededGb(uses);
    out.add('En az $need GB RAM al; daha azı bu kullanımda yavaşlatır.');
    if (p.form != FormChoice.desktop && (gaming || heavyWork)) {
      out.add(
        'Laptopta ekran kartı aynı isimli masaüstü kartından daha yavaştır; '
        'aynı parayla masaüstü daha güçlü olur.',
      );
    }
    final budget = p.budgetTry;
    if (budget != null &&
        passing.isNotEmpty &&
        tryOf(passing.first) > budget * 1.05) {
      out.add(
        'Bütçen bu kullanım için düşük. İşi görebilen en uygun seçenek '
        '~${_round(tryOf(passing.first))} TL civarında.',
      );
    }
    return out;
  }

  static String _round(double v) {
    final r = (v / 1000).round() * 1000;
    final s = r.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  // ------------------------------------------------------------ candidates

  Iterable<_Candidate> _laptops(PartCatalog catalog) sync* {
    for (final s in kPrebuilts.where((s) => s.isLaptop)) {
      for (final v in s.variants) {
        // Only what is still sold new.
        if ((v.year ?? 0) < 2023) continue;
        final cpu = catalog.byId(v.cpuId);
        final gpu = catalog.byId(v.gpuId);
        final ram = catalog.byId(v.ramId);
        if (cpu is! Cpu || gpu is! Gpu || ram is! Ram) continue;
        final usd = _laptopUsd(gpu);
        if (usd == null) continue;
        yield _Candidate(
          '${s.displayName} · ${cpu.model.replaceAll('Core ', '')} · '
          '${gpu.model.replaceAll('GeForce ', '').replaceAll(' Laptop GPU', '')}',
          PcBuild(cpu: cpu, gpu: gpu, ram: ram),
          true,
          usd + (ram.totalGb >= 32 ? 80 : 0),
        );
      }
    }
  }

  static double? _laptopUsd(Gpu gpu) {
    if (isIntegratedGpu(gpu)) return kLaptopTierUsd['igpu'];
    if (gpu.id.startsWith('mx')) return kLaptopTierUsd['mx'];
    return kLaptopTierUsd[gpu.id];
  }

  Iterable<_Candidate> _desktops(PartCatalog catalog, int ramGb) sync* {
    Ram? ramFor(Cpu cpu) {
      final type = cpu.memoryTypes.contains(MemoryType.ddr5)
          ? MemoryType.ddr5
          : MemoryType.ddr4;
      final speed = type == MemoryType.ddr5 ? 6000 : 3200;
      final kit = catalog.byId(
        'ram-${type.name}-$speed-2x${ramGb ~/ 2}',
      );
      return kit is Ram ? kit : null;
    }

    for (final e in _apus.entries) {
      final cpu = catalog.byId(e.key);
      final gpu = catalog.byId(e.value);
      if (cpu is! Cpu || gpu is! Gpu || cpu.refPriceUsd == null) continue;
      final ram = ramFor(cpu);
      if (ram == null) continue;
      yield _Candidate(
        'Masaüstü · ${cpu.model} (ekran kartsız, dahili grafik)',
        PcBuild(cpu: cpu, gpu: gpu, ram: ram),
        false,
        cpu.refPriceUsd! + (ram.refPriceUsd ?? 0) + kDesktopPlatformUsd,
      );
    }
    for (final cpuId in _desktopCpus) {
      final cpu = catalog.byId(cpuId);
      if (cpu is! Cpu || cpu.refPriceUsd == null) continue;
      final ram = ramFor(cpu);
      if (ram == null) continue;
      for (final gpuId in _desktopGpus) {
        final gpu = catalog.byId(gpuId);
        if (gpu is! Gpu || gpu.refPriceUsd == null) continue;
        // Skip pairs where one part wastes the other.
        final ratio = gpu.rasterScore / math.max(1, cpu.gamingScore);
        if (ratio > 1.4 || ratio < 0.12) continue;
        yield _Candidate(
          'Masaüstü · ${cpu.model} + ${gpu.model.replaceAll('GeForce ', '')}',
          PcBuild(cpu: cpu, gpu: gpu, ram: ram),
          false,
          cpu.refPriceUsd! +
              gpu.refPriceUsd! +
              (ram.refPriceUsd ?? 0) +
              kDesktopPlatformUsd,
        );
      }
    }
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

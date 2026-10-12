import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/explain.dart';
import 'package:darbogaz/core/widgets/flow.dart';
import 'package:darbogaz/core/widgets/page_nav.dart';
import 'package:darbogaz/features/analysis/fps_detail_widgets.dart';
import 'package:darbogaz/features/builder/pc_case_shape.dart';
import 'package:darbogaz/features/sandbox/sandbox_state.dart';

/// "Detaylı inceleme": each part's own frame rate in one game or across
/// all games, the result, what an upgrade would bring, and whether the
/// parts that do not change FPS (power supply, cooler, case) are enough.
class FpsDetailPage extends ConsumerStatefulWidget {
  const FpsDetailPage({super.key, this.gameId, this.fromSandbox = false});

  /// Opened from one game's card; null = average of all games.
  final String? gameId;

  /// Use the scratch-area PC instead of the user's own.
  final bool fromSandbox;

  @override
  ConsumerState<FpsDetailPage> createState() => _FpsDetailPageState();
}

class _FpsDetailPageState extends ConsumerState<FpsDetailPage> {
  late String? _gameId = widget.gameId;
  late Resolution _res = ref.read(analysisSettingsProvider).resolution;
  GraphicsPreset _preset = GraphicsPreset.high;

  PcBuild get _build => widget.fromSandbox
      ? ref.watch(sandboxProvider).pcs[0].build
      : ref.watch(buildProvider);

  FpsBreakdown _breakdown(Cpu cpu, Gpu gpu, Ram? ram) {
    const fps = FpsEstimator();
    FpsBreakdown one(GameProfile g) => fps.breakdown(
      game: g,
      cpu: cpu,
      gpu: gpu,
      ram: ram,
      resolution: _res,
      preset: _preset,
    );
    final game = kGames.where((g) => g.id == _gameId).firstOrNull;
    if (game != null) return one(game);
    return FpsBreakdown.average([for (final g in generalGameSet) one(g)]);
  }

  Future<void> _pickGame() async {
    final picked = await showOptionSheet<String>(
      context: context,
      title: 'Hangi oyun?',
      options: ['', for (final g in kGames) g.id],
      labelOf: (id) => id.isEmpty
          ? 'Tüm oyunlar (ortalama)'
          : kGames.firstWhere((g) => g.id == id).name,
      selected: _gameId ?? '',
    );
    if (picked == null) return;
    setState(() => _gameId = picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final b = _build;
    final cpu = b.cpu;
    final gpu = b.gpu;
    return Scaffold(
      bottomNavigationBar: const InnerNavBar(),
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const BrandTitle('Detaylı inceleme'),
      ),
      body: cpu == null || gpu == null
          ? StatView.empty(
              icon: Icons.query_stats_rounded,
              message:
                  'Parça parça FPS için işlemci ve ekran kartı seçmelisin.',
              actionLabel: 'Parça seç',
              onAction: () => context.go('/devices?kind=pc'),
            )
          : _body(b, cpu, gpu),
    );
  }

  Widget _body(PcBuild build, Cpu cpu, Gpu gpu) {
    final theme = Theme.of(context);
    final d = _breakdown(cpu, gpu, build.ram);
    final top = [
      d.cpuFps,
      d.cpuWithRamFps,
      d.gpuFps,
      d.resultFps,
    ].reduce((a, b) => a > b ? a : b);
    final cpuLimits = !d.engineCapped && d.limiter == Limiter.cpu;
    final gpuLimits = !d.engineCapped && d.limiter == Limiter.gpu;
    final gameName = d.game?.name ?? 'Tüm oyunlar (ortalama)';
    return ListView(
      padding: Insets.page,
      children: [
        Text(
          '${cpu.model} + ${gpu.model}'
          '${build.ram == null ? '' : ' · ${build.ram!.totalGb} GB'}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: Space.m),
        // Game, resolution and graphics setting.
        Card(
          child: ListTile(
            leading: const Icon(Icons.sports_esports_rounded),
            title: Text(gameName),
            subtitle: const Text('Oyunu değiştirmek için dokun'),
            trailing: const Icon(Icons.expand_more_rounded),
            onTap: _pickGame,
          ),
        ),
        const SizedBox(height: Space.s),
        AppSegmented<Resolution>(
          values: Resolution.values,
          selected: _res,
          labelOf: (r) => r.label,
          onChanged: (r) => setState(() => _res = r),
        ),
        const SizedBox(height: Space.s),
        AppSegmented<GraphicsPreset>(
          values: GraphicsPreset.values,
          selected: _preset,
          labelOf: (p) => p.label,
          onChanged: (p) => setState(() => _preset = p),
        ),
        const SizedBox(height: Space.cardGap),
        FpsResultCard(b: d),
        const SizedBox(height: Space.cardGap),
        SectionCard(
          title: 'Parça parça FPS',
          icon: Icons.view_list_rounded,
          child: Column(
            children: [
              PartFpsRow(
                icon: Icons.memory_rounded,
                title: 'İşlemci',
                subtitle: cpu.model,
                fps: d.cpuFps,
                maxFps: top,
                limiting: cpuLimits && d.ramDeltaFps.round() == 0,
                sentence:
                    'İşlemcin saniyede en fazla ${d.cpuFps.round()} kare '
                    'hazırlayabilir.',
              ),
              PartFpsRow(
                icon: Icons.developer_board_rounded,
                title: 'RAM',
                subtitle: build.ram?.displayName ?? 'Seçilmedi',
                fps: d.cpuWithRamFps,
                maxFps: top,
                badge: deltaText(d.ramDeltaFps),
                badgeTone: d.ramDeltaFps.round() < 0
                    ? Tone.bad
                    : (d.ramDeltaFps.round() > 0 ? Tone.good : Tone.neutral),
                limiting: cpuLimits && d.ramDeltaFps.round() != 0,
                sentence: ramSentence(d, build.ram),
              ),
              PartFpsRow(
                icon: Icons.videogame_asset_rounded,
                title: 'Ekran kartı',
                subtitle: gpu.model,
                fps: d.gpuFps,
                maxFps: top,
                limiting: gpuLimits && d.vramDeltaFps.round() == 0,
                sentence:
                    'Ekran kartın bu ayarda saniyede en fazla '
                    '${d.gpuFps.round()} kare çizebilir.',
              ),
              PartFpsRow(
                icon: Icons.sd_card_rounded,
                title: 'Ekran kartı belleği',
                subtitle:
                    'Oyun ~${d.vramNeedGb.toStringAsFixed(1)} GB istiyor, '
                    'kartında ${d.vramGb.round()} GB var',
                fps: d.vramDeltaFps.round() == 0 ? null : d.gpuWithVramFps,
                maxFps: top,
                badge: d.vramDeltaFps.round() == 0
                    ? '✓ Yeterli'
                    : deltaText(d.vramDeltaFps),
                badgeTone: d.vramDeltaFps.round() == 0 ? Tone.good : Tone.bad,
                limiting: gpuLimits && d.vramDeltaFps.round() != 0,
                sentence: d.vramDeltaFps.round() == 0
                    ? 'Bellek yetiyor; FPS kaybı yok.'
                    : 'Bellek yetmediği için kart ${-d.vramDeltaFps.round()} '
                          'FPS kaybediyor ve ara ara takılma olabilir.',
              ),
              if (d.engineCapFps != null)
                PartFpsRow(
                  icon: Icons.lock_rounded,
                  title: 'Oyunun kendi sınırı',
                  fps: d.engineCapFps,
                  maxFps: top,
                  limiting: d.engineCapped,
                  sentence:
                      'Bu oyun ${d.engineCapFps!.round()} FPS\'in üstüne '
                      'çıkmaz; parçalar ne kadar güçlü olsa da.',
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.cardGap),
        _UpgradeCard(d: d),
        const SizedBox(height: Space.cardGap),
        _SupportCard(pc: build, cpu: cpu),
        const SizedBox(height: Space.cardGap),
        const Explain(
          question: 'Bu sayılar nasıl hesaplanıyor?',
          answer:
              'Her parçanın gücü bağımsız testlerden alınır. İşlemcinin '
              'hazırlayabildiği ve ekran kartının çizebildiği kare sayıları '
              'ayrı hesaplanır; RAM işlemciyi, ekran kartı belleği ekran '
              'kartını etkiler. Sonuç ikisinin birleşimidir.',
        ),
        const SizedBox(height: Space.s),
        const AccuracyNote(),
      ],
    );
  }
}

/// What removing each limit would bring (shows what is worth upgrading).
class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.d});

  final FpsBreakdown d;

  @override
  Widget build(BuildContext context) {
    final cpuGain = d.fpsWithoutCpuLimit - d.resultFps;
    final gpuGain = d.fpsWithoutGpuLimit - d.resultFps;
    return SectionCard(
      title: 'Yükseltirsen ne olur?',
      icon: Icons.trending_up_rounded,
      child: Column(
        children: [
          PartFpsRow(
            icon: Icons.memory_rounded,
            title: 'Çok daha güçlü bir işlemciyle',
            badge: deltaText(cpuGain),
            badgeTone: cpuGain.round() > 0 ? Tone.good : Tone.neutral,
            sentence: cpuGain.round() > 0
                ? 'En fazla ~${d.fpsWithoutCpuLimit.round()} FPS olur.'
                : 'Bu oyunda işlemci yükseltmesi FPS\'i artırmaz.',
          ),
          PartFpsRow(
            icon: Icons.videogame_asset_rounded,
            title: 'Çok daha güçlü bir ekran kartıyla',
            badge: deltaText(gpuGain),
            badgeTone: gpuGain.round() > 0 ? Tone.good : Tone.neutral,
            sentence: gpuGain.round() > 0
                ? 'En fazla ~${d.fpsWithoutGpuLimit.round()} FPS olur.'
                : 'Bu oyunda ekran kartı yükseltmesi FPS\'i artırmaz.',
          ),
        ],
      ),
    );
  }
}

/// Parts that do not change FPS, checked for being enough.
class _SupportCard extends ConsumerWidget {
  const _SupportCard({required this.pc, required this.cpu});

  final PcBuild pc;
  final Cpu cpu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = const CompatibilityChecker().check(pc);
    final need = report.recommendedPsuW;
    final psu = pc.psu;
    final cooler = pc.cooler;
    final shape = BuildShape.of(pc);
    return SectionCard(
      title: 'FPS\'i değiştirmeyenler',
      icon: Icons.inventory_2_rounded,
      child: Column(
        children: [
          SupportRow(
            icon: Icons.power_rounded,
            title: 'Güç kaynağı',
            tone: psu == null
                ? Tone.neutral
                : (need == null || psu.watts >= need ? Tone.good : Tone.bad),
            status: psu == null
                ? 'Seçilmedi'
                : (need == null || psu.watts >= need ? '✓ Yeterli' : '✕ Zayıf'),
            sentence: psu == null
                ? 'Önerilen: ${need ?? '-'} W.'
                : '${psu.watts} W; bu sisteme önerilen ${need ?? '-'} W.',
          ),
          SupportRow(
            icon: Icons.ac_unit_rounded,
            title: 'Soğutucu',
            tone: cooler == null
                ? Tone.neutral
                : (cooler.tdpRatingW >= cpu.tdpW ? Tone.good : Tone.warn),
            status: cooler == null
                ? 'Seçilmedi'
                : (cooler.tdpRatingW >= cpu.tdpW ? '✓ Yeterli' : '! Sınırda'),
            sentence: cooler == null
                ? 'İşlemcin ${cpu.tdpW} W ısı üretir.'
                : '${cooler.tdpRatingW} W soğutur; işlemcin ${cpu.tdpW} W '
                      'ısı üretir. Yetmezse işlemci ısınıp yavaşlar.',
          ),
          if (pc.pcCase != null)
            SupportRow(
              icon: Icons.dns_rounded,
              title: 'Kasa',
              tone: shape.gpuTooLong || shape.coolerTooTall
                  ? Tone.bad
                  : Tone.good,
              status: shape.gpuTooLong || shape.coolerTooTall
                  ? '✕ Sığmıyor'
                  : '✓ Sığıyor',
              sentence: shape.gpuTooLong
                  ? 'Ekran kartı bu kasaya sığmıyor.'
                  : shape.coolerTooTall
                  ? 'Soğutucu bu kasaya sığmıyor.'
                  : 'Parçalar kasaya sığıyor. ${caseFansText(pc.pcCase!)}',
            ),
          SupportRow(
            icon: Icons.fact_check_rounded,
            title: 'Uyumluluk',
            tone: report.isCompatible ? Tone.good : Tone.bad,
            status: report.isCompatible ? '✓ Uyumlu' : '✕ Uyumsuz',
            sentence: report.isCompatible
                ? 'Parçalar birlikte çalışır.'
                : 'Bazı parçalar birlikte çalışmaz; ayrıntı Analiz '
                      'sayfasında.',
          ),
        ],
      ),
    );
  }
}

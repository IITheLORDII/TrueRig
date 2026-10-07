import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/devices.dart';

/// Read-only part catalog. Will be backed by Supabase sync later; the seed
/// catalog keeps the app fully usable offline.
final catalogProvider = Provider<PartCatalog>((ref) => PartCatalog.seed());

/// The build the user is assembling.
final buildProvider = NotifierProvider<BuildController, PcBuild>(
  BuildController.new,
);

const _buildKey = 'pc.build';

/// The PC build; part ids are persisted so the build survives restarts.
class BuildController extends Notifier<PcBuild> {
  @override
  PcBuild build() {
    final ids = ref.read(prefsProvider)?.getStringList(_buildKey) ?? const [];
    final catalog = ref.read(catalogProvider);
    var build = const PcBuild();
    for (final id in ids) {
      final part = catalog.byId(id);
      if (part != null) build = build.withPart(part);
    }
    return build;
  }

  void setPart(Part part) => _save(state.withPart(part));

  void clear(PartCategory category) => _save(state.without(category));

  void reset() => _save(const PcBuild());

  /// Replaces the whole build (ready-made system, parsed listing title).
  void replace(PcBuild b) => _save(b);

  void _save(PcBuild b) {
    state = b;
    ref.read(prefsProvider)?.setStringList(_buildKey, [
      for (final p in b.parts) p.id,
    ]);
  }
}

/// Game / resolution / preset the analysis is computed for.
@immutable
class AnalysisSettings {
  const AnalysisSettings({
    this.gameId = 'cyberpunk',
    this.resolution = Resolution.p1080,
    this.preset = GraphicsPreset.ultra,
  });

  final String gameId;
  final Resolution resolution;
  final GraphicsPreset preset;

  AnalysisSettings copyWith({
    String? gameId,
    Resolution? resolution,
    GraphicsPreset? preset,
  }) => AnalysisSettings(
    gameId: gameId ?? this.gameId,
    resolution: resolution ?? this.resolution,
    preset: preset ?? this.preset,
  );

  GameProfile get game =>
      kGames.firstWhere((g) => g.id == gameId, orElse: () => kGames.first);
}

final analysisSettingsProvider =
    NotifierProvider<AnalysisSettingsController, AnalysisSettings>(
      AnalysisSettingsController.new,
    );

class AnalysisSettingsController extends Notifier<AnalysisSettings> {
  @override
  AnalysisSettings build() => const AnalysisSettings();

  void update(AnalysisSettings Function(AnalysisSettings s) change) =>
      state = change(state);
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void set(ThemeMode mode) => state = mode;
}

final compatibilityProvider = Provider<CompatibilityReport>((ref) {
  final build = ref.watch(buildProvider);
  return const CompatibilityChecker().check(build);
});

/// Current FPS estimate, or null until both CPU and GPU are chosen.
final fpsEstimateProvider = Provider<FpsEstimate?>((ref) {
  final build = ref.watch(buildProvider);
  final s = ref.watch(analysisSettingsProvider);
  final cpu = build.cpu;
  final gpu = build.gpu;
  if (cpu == null || gpu == null) return null;
  return const FpsEstimator().estimate(
    game: s.game,
    cpu: cpu,
    gpu: gpu,
    ram: build.ram,
    resolution: s.resolution,
    preset: s.preset,
  );
});

final upgradeAdviceProvider = Provider<UpgradeAdvice?>((ref) {
  final build = ref.watch(buildProvider);
  if (build.cpu == null || build.gpu == null) return null;
  final s = ref.watch(analysisSettingsProvider);
  return const UpgradeAdvisor().advise(
    build: build,
    catalog: ref.watch(catalogProvider),
    game: s.game,
    resolution: s.resolution,
    preset: s.preset,
  );
});

/// The ready-made system the PC build came from ("Casper Excalibur G770 ·
/// i5-12450H / RTX 4050"), if any. Cleared when a part is changed by hand.
@immutable
class PrebuiltSelection {
  const PrebuiltSelection({required this.label, required this.isLaptop});

  final String label;
  final bool isLaptop;
}

const _prebuiltKey = 'pc.prebuilt';

final prebuiltProvider =
    NotifierProvider<PrebuiltController, PrebuiltSelection?>(
      PrebuiltController.new,
    );

class PrebuiltController extends Notifier<PrebuiltSelection?> {
  @override
  PrebuiltSelection? build() {
    final raw = ref.read(prefsProvider)?.getStringList(_prebuiltKey);
    if (raw == null || raw.length != 2) return null;
    return PrebuiltSelection(label: raw[0], isLaptop: raw[1] == '1');
  }

  /// Fills the PC build from a ready-made system and remembers its name.
  void apply(PrebuiltSelection selection, PcBuild build) {
    ref.read(buildProvider.notifier).replace(build);
    state = selection;
    ref.read(prefsProvider)?.setStringList(_prebuiltKey, [
      selection.label,
      selection.isLaptop ? '1' : '0',
    ]);
  }

  void clear() {
    state = null;
    ref.read(prefsProvider)?.remove(_prebuiltKey);
  }

  /// A part was changed by hand: keep laptop mode, flag the name.
  void markEdited() {
    final s = state;
    if (s == null || s.label.endsWith(_editedSuffix)) return;
    final edited = PrebuiltSelection(
      label: '${s.label}$_editedSuffix',
      isLaptop: s.isLaptop,
    );
    state = edited;
    ref.read(prefsProvider)?.setStringList(_prebuiltKey, [
      edited.label,
      edited.isLaptop ? '1' : '0',
    ]);
  }
}

const _editedSuffix = ' (düzenlendi)';

/// Short label for a factory configuration: "i5-12450H · RTX 4050 · 16 GB".
String variantLabel(PartCatalog catalog, PrebuiltVariant v) {
  String short(String id) {
    final p = catalog.byId(id);
    if (p == null) return id;
    return p.model
        .replaceAll('Core ', '')
        .replaceAll('GeForce ', '')
        .replaceAll(' Laptop GPU', '')
        .replaceAll('Radeon ', '');
  }

  final ram = catalog.byId(v.ramId);
  return '${short(v.cpuId)} · ${short(v.gpuId)}'
      '${ram is Ram ? ' · ${ram.totalGb} GB' : ''}';
}

/// Builds a PcBuild from a factory configuration.
PcBuild buildFromVariant(PartCatalog catalog, PrebuiltVariant v) {
  var b = const PcBuild();
  for (final id in [v.cpuId, v.gpuId, v.ramId]) {
    final p = catalog.byId(id);
    if (p != null) b = b.withPart(p);
  }
  return b;
}

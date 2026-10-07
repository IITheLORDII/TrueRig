import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/features/detect/browser_probe.dart';

/// Result of the last detection, with the CPU the user picked (if the probe
/// could not identify it).
@immutable
class DetectionState {
  const DetectionState({required this.result, this.chosenCpu});

  final DetectionResult result;
  final Cpu? chosenCpu;

  PcBuild get build {
    final cpu = chosenCpu;
    return cpu == null ? result.build : result.build.withPart(cpu);
  }

  /// Gaming resolution implied by the physical screen size.
  Resolution? get suggestedResolution {
    final w = result.report.screenWidth;
    if (w == null) return null;
    if (w >= 3800) return Resolution.p2160;
    if (w >= 2500) return Resolution.p1440;
    return Resolution.p1080;
  }

  DetectionState withCpu(Cpu cpu) =>
      DetectionState(result: result, chosenCpu: cpu);
}

final detectionProvider =
    NotifierProvider<DetectionController, DetectionState?>(
      DetectionController.new,
    );

class DetectionController extends Notifier<DetectionState?> {
  @override
  DetectionState? build() => null;

  HardwareDetector get _detector =>
      HardwareDetector(HardwareMatcher(ref.read(catalogProvider)));

  /// Reads the browser after the user consented. Returns false off-web.
  bool detectFromBrowser() {
    final report = probeBrowser();
    if (report == null) return false;
    state = DetectionState(result: _detector.resolve(report));
    return true;
  }

  /// Applies a code produced by the Windows helper. Returns false if invalid.
  bool detectFromCode(String code) {
    final report = HardwareReport.decode(code.trim());
    if (report == null) return false;
    state = DetectionState(result: _detector.resolve(report));
    return true;
  }

  void chooseCpu(Cpu cpu) {
    final s = state;
    if (s != null) state = s.withCpu(cpu);
  }

  /// Replaces the current build with the detected one.
  void applyToBuild() {
    final s = state;
    if (s == null) return;
    final builds = ref.read(buildProvider.notifier)..reset();
    for (final part in s.build.parts) {
      builds.setPart(part);
    }
    final res = s.suggestedResolution;
    if (res != null) {
      ref
          .read(analysisSettingsProvider.notifier)
          .update((a) => a.copyWith(resolution: res));
    }
  }
}

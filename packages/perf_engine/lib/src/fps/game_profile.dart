enum Resolution { p1080, p1440, p2160 }

enum GraphicsPreset { low, medium, high, ultra }

extension ResolutionLabel on Resolution {
  String get label => switch (this) {
        Resolution.p1080 => '1080p',
        Resolution.p1440 => '1440p',
        Resolution.p2160 => '4K',
      };
}

extension GraphicsPresetLabel on GraphicsPreset {
  String get label => switch (this) {
        GraphicsPreset.low => 'Düşük',
        GraphicsPreset.medium => 'Orta',
        GraphicsPreset.high => 'Yüksek',
        GraphicsPreset.ultra => 'Ultra',
      };
}

/// Calibration data for one game.
///
/// All reference FPS values are averages at Ultra/max preset measured (or, for
/// [isProjection] titles, projected) on the reference platform:
/// a CPU with gamingScore 100 and a GPU with rasterScore 100.
class GameProfile {
  const GameProfile({
    required this.id,
    required this.name,
    required this.cpuRefFps,
    required this.gpuRefFps,
    required this.vramNeedGb,
    this.threadSensitivity = 0.15,
    this.minCores = 4,
    this.engineFpsCap,
    this.isProjection = false,
    this.isEsports = false,
  });

  final String id;
  final String name;

  /// FPS the reference CPU can feed regardless of GPU.
  final double cpuRefFps;

  /// FPS the reference GPU renders per resolution when not CPU-limited.
  final Map<Resolution, double> gpuRefFps;

  /// VRAM needed at Ultra per resolution.
  final Map<Resolution, double> vramNeedGb;

  /// 0..1: how much the CPU limit follows multi-thread instead of gaming score.
  final double threadSensitivity;
  final int minCores;
  final double? engineFpsCap;

  /// True when the game is not yet released on PC and values are projected.
  final bool isProjection;
  final bool isEsports;
}

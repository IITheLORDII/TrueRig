import 'package:perf_engine/src/llm/llm_estimator.dart';

/// Mobile game calibration at "Yüksek" (high) settings on a chip with
/// gpuScore 100 / cpuSt 100 (Apple A18 Pro class).
class MobileGameProfile {
  const MobileGameProfile({
    required this.id,
    required this.name,
    required this.gpuRefFps,
    required this.cpuRefFps,
    required this.fpsCap,
    required this.minRamGb,
    this.heavy = false,
  });

  final String id;
  final String name;
  final double gpuRefFps;
  final double cpuRefFps;

  /// Highest frame rate the game offers.
  final int fpsCap;
  final int minRamGb;

  /// Sustained GPU load: thermal throttling applies fully.
  final bool heavy;
}

const List<MobileGameProfile> kMobileGames = [
  MobileGameProfile(
      id: 'pubg-mobile',
      name: 'PUBG Mobile',
      gpuRefFps: 160,
      cpuRefFps: 200,
      fpsCap: 120,
      minRamGb: 4,
      heavy: true),
  MobileGameProfile(
      id: 'codm',
      name: 'Call of Duty: Mobile',
      gpuRefFps: 170,
      cpuRefFps: 220,
      fpsCap: 120,
      minRamGb: 4),
  MobileGameProfile(
      id: 'genshin',
      name: 'Genshin Impact',
      gpuRefFps: 70,
      cpuRefFps: 110,
      fpsCap: 60,
      minRamGb: 6,
      heavy: true),
  MobileGameProfile(
      id: 'hsr',
      name: 'Honkai: Star Rail',
      gpuRefFps: 65,
      cpuRefFps: 110,
      fpsCap: 60,
      minRamGb: 6,
      heavy: true),
  MobileGameProfile(
      id: 'wuwa',
      name: 'Wuthering Waves',
      gpuRefFps: 55,
      cpuRefFps: 100,
      fpsCap: 60,
      minRamGb: 8,
      heavy: true),
  MobileGameProfile(
      id: 'mlbb',
      name: 'Mobile Legends',
      gpuRefFps: 280,
      cpuRefFps: 300,
      fpsCap: 120,
      minRamGb: 3),
  MobileGameProfile(
      id: 'free-fire',
      name: 'Free Fire',
      gpuRefFps: 300,
      cpuRefFps: 300,
      fpsCap: 90,
      minRamGb: 2),
  MobileGameProfile(
      id: 'brawl-stars',
      name: 'Brawl Stars',
      gpuRefFps: 400,
      cpuRefFps: 400,
      fpsCap: 120,
      minRamGb: 3),
  MobileGameProfile(
      id: 'clash-royale',
      name: 'Clash Royale',
      gpuRefFps: 400,
      cpuRefFps: 400,
      fpsCap: 60,
      minRamGb: 2),
  MobileGameProfile(
      id: 'asphalt',
      name: 'Asphalt Legends',
      gpuRefFps: 100,
      cpuRefFps: 160,
      fpsCap: 120,
      minRamGb: 4,
      heavy: true),
  MobileGameProfile(
      id: 'ea-fc',
      name: 'EA SPORTS FC Mobile',
      gpuRefFps: 140,
      cpuRefFps: 160,
      fpsCap: 60,
      minRamGb: 4),
  MobileGameProfile(
      id: 'roblox',
      name: 'Roblox',
      gpuRefFps: 200,
      cpuRefFps: 140,
      fpsCap: 60,
      minRamGb: 3),
  MobileGameProfile(
      id: 'minecraft',
      name: 'Minecraft',
      gpuRefFps: 220,
      cpuRefFps: 120,
      fpsCap: 120,
      minRamGb: 3),
];

/// Phone app workload. Weights sum to 1; targets are "fully sufficient".
class MobileAppProfile {
  const MobileAppProfile({
    required this.id,
    required this.name,
    required this.category,
    required this.singleThreadWeight,
    required this.multiThreadWeight,
    required this.gpuWeight,
    required this.ramWeight,
    required this.recommendedRamGb,
    required this.tip,
  });

  final String id;
  final String name;
  final String category;
  final double singleThreadWeight;
  final double multiThreadWeight;
  final double gpuWeight;
  final double ramWeight;
  final int recommendedRamGb;
  final String tip;
}

const List<MobileAppProfile> kMobileApps = [
  MobileAppProfile(
      id: 'capcut',
      name: 'CapCut (4K dışa aktarma)',
      category: 'Video',
      singleThreadWeight: 0.1,
      multiThreadWeight: 0.4,
      gpuWeight: 0.3,
      ramWeight: 0.2,
      recommendedRamGb: 8,
      tip:
          '4K60 dışa aktarmada telefon ısınır; uzun projelerde 8 GB+ RAM rahatlatır.'),
  MobileAppProfile(
      id: 'lumafusion',
      name: 'LumaFusion / KineMaster',
      category: 'Video',
      singleThreadWeight: 0.15,
      multiThreadWeight: 0.35,
      gpuWeight: 0.3,
      ramWeight: 0.2,
      recommendedRamGb: 8,
      tip: 'Çok katmanlı kurguda GPU ve RAM belirleyici.'),
  MobileAppProfile(
      id: 'lightroom',
      name: 'Lightroom / Snapseed',
      category: 'Fotoğraf',
      singleThreadWeight: 0.3,
      multiThreadWeight: 0.3,
      gpuWeight: 0.2,
      ramWeight: 0.2,
      recommendedRamGb: 6,
      tip: 'RAW düzenlemede tek çekirdek hızı akıcılığı belirler.'),
  MobileAppProfile(
      id: 'camera-4k',
      name: 'Kamera (4K60 video)',
      category: 'Kamera',
      singleThreadWeight: 0.15,
      multiThreadWeight: 0.4,
      gpuWeight: 0.25,
      ramWeight: 0.2,
      recommendedRamGb: 6,
      tip: 'Uzun 4K kayıtta ısınma süreyi sınırlayabilir.'),
  MobileAppProfile(
      id: 'multitask',
      name: 'Çoklu görev',
      category: 'Günlük',
      singleThreadWeight: 0.2,
      multiThreadWeight: 0.2,
      gpuWeight: 0,
      ramWeight: 0.6,
      recommendedRamGb: 8,
      tip:
          'RAM ne kadar fazlaysa uygulamalar arka planda o kadar uzun açık kalır.'),
  MobileAppProfile(
      id: 'social',
      name: 'Sosyal medya ve web',
      category: 'Günlük',
      singleThreadWeight: 0.7,
      multiThreadWeight: 0.1,
      gpuWeight: 0,
      ramWeight: 0.2,
      recommendedRamGb: 4,
      tip: 'Sayfa açılış hızı tek çekirdek performansına bağlıdır.'),
];

/// Small models that realistically run on phones (MLC / llama.cpp / Apple
/// Foundation-style runtimes).
const List<LlmModel> kMobileLlmModels = [
  LlmModel(
      id: 'qwen3-0.6b', name: 'Qwen3 0.6B', family: 'Qwen', totalParamsB: 0.6),
  LlmModel(
      id: 'gemma3-1b', name: 'Gemma 3 1B', family: 'Gemma', totalParamsB: 1),
  LlmModel(
      id: 'llama3.2-1b',
      name: 'Llama 3.2 1B',
      family: 'Llama',
      totalParamsB: 1.2),
  LlmModel(
      id: 'qwen3-1.7b', name: 'Qwen3 1.7B', family: 'Qwen', totalParamsB: 1.7),
  LlmModel(
      id: 'gemma3n-e2b',
      name: 'Gemma 3n E2B',
      family: 'Gemma',
      totalParamsB: 2),
  LlmModel(
      id: 'llama3.2-3b',
      name: 'Llama 3.2 3B',
      family: 'Llama',
      totalParamsB: 3.2),
  LlmModel(
      id: 'phi4-mini',
      name: 'Phi-4 mini 3.8B',
      family: 'Phi',
      totalParamsB: 3.8),
  LlmModel(id: 'qwen3-4b-m', name: 'Qwen3 4B', family: 'Qwen', totalParamsB: 4),
  LlmModel(
      id: 'gemma3n-e4b',
      name: 'Gemma 3n E4B',
      family: 'Gemma',
      totalParamsB: 4),
  LlmModel(
      id: 'qwen3-8b-m', name: 'Qwen3 8B', family: 'Qwen', totalParamsB: 8.2),
];

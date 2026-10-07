import 'package:perf_engine/src/data/part_catalog.dart';
import 'package:perf_engine/src/detect/spec_text_parser.dart';
import 'package:perf_engine/src/models/parts.dart';

/// Maps raw hardware names (WebGL renderer strings, WMI/OS names) to catalog
/// parts by whole-token matching, so "RTX 4070" never matches "4070 Ti".
class HardwareMatcher {
  const HardwareMatcher(this.catalog);

  final PartCatalog catalog;

  /// Words in raw OS / driver strings that carry no model information.
  static const _noise = {
    'angle',
    'direct3d11',
    'direct3d',
    'd3d11',
    'd3d12',
    'vulkan',
    'opengl',
    'vs',
    'ps',
    'r',
    'tm',
    'processor',
    'cpu',
    'gpu',
    'graphics',
    'with',
    'radeon(tm)',
    'gen',
    'core',
  };

  Gpu? matchGpu(String raw) =>
      _best(catalog.gpus, raw, tierGuard: true) as Gpu?;

  /// Also accepts Intel "13th Gen Intel(R) Core(TM) i5-13600K" style names.
  Cpu? matchCpu(String raw) => _best(catalog.cpus, raw) as Cpu?;

  Motherboard? matchMotherboard(String raw) =>
      _best(catalog.motherboards, raw) as Motherboard?;

  /// CPUs plausible for a browser-reported logical thread count.
  List<Cpu> cpuCandidatesForThreads(int threads) =>
      catalog.cpus.where((c) => c.threads == threads).toList(growable: false);

  /// [tierGuard]: reject a candidate when the text has a tier word (Ti,
  /// Super, XT) the candidate lacks. Only meaningful for GPUs: a listing
  /// title mentions the GPU's "Super" next to the CPU name.
  Part? _best(List<Part> parts, String raw, {bool tierGuard = false}) {
    final have = expandTokens(tokens(raw));
    if (have.isEmpty) return null;
    Part? best;
    var bestScore = 0;
    for (final p in parts) {
      final need = _required(p.model);
      if (need.isEmpty || !need.every(have.contains)) continue;
      // "GTX 1650 SUPER" must not fall back to a plain "GTX 1650".
      if (tierGuard &&
          _tierWords.any((t) => have.contains(t) && !need.contains(t))) {
        continue;
      }
      // Prefer the most specific model ("4070 super" over "4070").
      if (need.length > bestScore) {
        best = p;
        bestScore = need.length;
      }
    }
    return best;
  }

  /// Model tokens that must all be present. Marketing words (GeForce, Radeon,
  /// Core) and memory sizes ("16gb") are optional because drivers omit them.
  static Set<String> _required(String model) => tokens(model)
      .where((t) => !_optional.contains(t) && !RegExp(r'^\d+gb$').hasMatch(t))
      .toSet();

  static const _tierWords = {'ti', 'super', 'xt', 'xtx'};

  static const _optional = {'geforce', 'radeon', 'core', 'arc', 'ryzen'};

  /// Human-readable name from a WebGL/ANGLE renderer string, e.g.
  /// "ANGLE (Intel, Intel(R) UHD Graphics (0x000046A3) Direct3D11 vs_5_0
  /// ps_5_0, D3D11)" -> "Intel(R) UHD Graphics".
  static String displayName(String raw) {
    var s = raw.trim();
    final angle =
        RegExp(r'^ANGLE \(([^,]*),\s*(.*?)(,[^,]*)?\)$').firstMatch(s);
    if (angle != null) s = angle.group(2) ?? s;
    return s
        .replaceAll(RegExp(r'\s*\(0x[0-9A-Fa-f]+\)'), '')
        .replaceAll(
          RegExp(r'\s+(Direct3D|D3D|OpenGL|Vulkan|vs_|ps_).*$',
              caseSensitive: false),
          '',
        )
        .trim();
  }

  /// True for integrated graphics, which browsers on laptops often report
  /// instead of the discrete GPU.
  static bool isIntegratedGpu(String raw) => RegExp(
        r'UHD Graphics|Iris|HD Graphics|Radeon\(TM\) Graphics|Radeon Graphics|'
        r'Vega \d+ Graphics|Intel\(R\) Graphics|Arc\(TM\) Graphics',
        caseSensitive: false,
      ).hasMatch(raw);

  /// Lowercase alphanumeric tokens; splits "i5-13600K" into {i5, 13600k}.
  static Set<String> tokens(String s) => PartCatalog.normalize(s)
      .split(' ')
      .where((t) => t.isNotEmpty && !_noise.contains(t))
      .toSet();
}

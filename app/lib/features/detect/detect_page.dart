import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/images/part_images.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/part_labels.dart';
import 'package:darbogaz/core/widgets/part_thumb.dart';
import 'package:darbogaz/features/detect/browser_probe.dart';
import 'package:darbogaz/features/detect/detection_controller.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';

/// Where the Windows helper script is served (next to the web app).
const String kHelperScriptPath = 'detect.ps1';

class DetectPage extends ConsumerStatefulWidget {
  const DetectPage({super.key, this.initialCode});

  /// `hw` code from `#/detect?hw=...` (opened by the Windows helper).
  final String? initialCode;

  @override
  ConsumerState<DetectPage> createState() => _DetectPageState();
}

class _DetectPageState extends ConsumerState<DetectPage> {
  final _code = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final code = widget.initialCode;
    if (code != null && code.isNotEmpty) {
      // The URL itself is the user's consent: they ran the helper.
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyCode(code));
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _applyCode(String code) {
    final ok = ref.read(detectionProvider.notifier).detectFromCode(code);
    setState(() => _error = ok ? null : 'Kod okunamadı. Tekrar kopyalayın.');
  }

  void _detectBrowser() {
    final ok = ref.read(detectionProvider.notifier).detectFromBrowser();
    if (!ok) setState(() => _error = 'Bu cihazda tarayıcı algılaması yok.');
  }

  void _continue() {
    final hasGpu = ref.read(detectionProvider)?.build.gpu != null;
    ref.read(detectionProvider.notifier).applyToBuild();
    // Bottleneck analysis needs a GPU; otherwise let the user pick one.
    ref.read(activeDeviceProvider.notifier).set(DeviceKind.pc);
    context.go(hasGpu ? '/analysis' : '/devices?kind=pc');
  }

  @override
  Widget build(BuildContext context) {
    final detection = ref.watch(detectionProvider);
    return Scaffold(
      appBar: AppBar(title: const BrandTitle('Sistemini Algıla')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (detection == null)
            _ConsentCard(
              onDetect: _detectBrowser,
              onSkip: () => context.go('/devices'),
            )
          else
            _ResultCard(state: detection, onContinue: _continue),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: context.palette.bad)),
          ],
          if (kIsWeb) ...[
            const SizedBox(height: 12),
            _HelperCard(
              controller: _code,
              onApply: () => _applyCode(_code.text),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.onDetect, required this.onSkip});

  final VoidCallback onDetect;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Donanımını otomatik tanıyalım',
      icon: Icons.radar_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            canProbeBrowser
                ? 'İzin verirsen tarayıcının paylaştığı bilgileri okuyacağız: '
                      'ekran kartı modeli, işlemci iş parçacığı sayısı ve ekran '
                      'çözünürlüğü. Bilgiler cihazından çıkmaz, sunucuya '
                      'gönderilmez.'
                : 'Bilgisayarının donanımını okumak için uygulamanın web '
                      'sürümünü o bilgisayarda aç ya da aşağıdaki Windows '
                      'aracının verdiği kodu yapıştır.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (canProbeBrowser)
            FilledButton.icon(
              onPressed: onDetect,
              icon: const Icon(Icons.check_rounded),
              label: const Text('İzin ver ve algıla'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          TextButton(
            onPressed: onSkip,
            child: const Text('Atla, parçaları kendim seçeceğim'),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends ConsumerWidget {
  const _ResultCard({required this.state, required this.onContinue});

  final DetectionState state;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = state.result;
    final build = state.build;
    final palette = context.palette;
    final muted = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: palette.muted);
    final fromBrowser = r.report.source == 'browser';
    final integrated = r.unmatched
        .where(HardwareMatcher.isIntegratedGpu)
        .firstOrNull;
    final otherUnmatched = r.unmatched
        .where((n) => !HardwareMatcher.isIntegratedGpu(n))
        .toList();

    return SectionCard(
      title: 'Algılanan sistem',
      icon: Icons.memory_rounded,
      trailing: StatusPill(
        text: fromBrowser ? 'Tarayıcı' : 'Tam algılama',
        color: fromBrowser ? palette.warn : palette.good,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in [
            PartCategory.gpu,
            PartCategory.cpu,
            PartCategory.motherboard,
            PartCategory.ram,
          ])
            if (build.partFor(c) case final part?)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: PartThumb(
                  imageUrl: ref.watch(partImageProvider(part)),
                  fallbackIcon: c.icon,
                ),
                title: Text(part.displayName),
                subtitle: Text(c.label),
                trailing: Icon(Icons.check_circle_rounded, color: palette.good),
              ),
          if (build.cpu == null && r.cpuCandidates.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Tarayıcı işlemci modelini paylaşmıyor. '
              '${r.report.threads} iş parçacıklı işlemcilerden seninkini seç:',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cpu in r.cpuCandidates)
                  ChoiceChip(
                    label: Text(cpu.model),
                    selected: state.chosenCpu?.id == cpu.id,
                    onSelected: (_) =>
                        ref.read(detectionProvider.notifier).chooseCpu(cpu),
                  ),
              ],
            ),
          ],
          if (state.suggestedResolution case final res?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Ekran: ${r.report.screenWidth}×${r.report.screenHeight} → '
                'analiz ${res.label} ile yapılacak.',
                style: muted,
              ),
            ),
          if (build.gpu == null && integrated != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Tarayıcı tümleşik ekran kartını gösteriyor '
                '(${HardwareMatcher.displayName(integrated)}). Dizüstülerde '
                'tarayıcı genelde enerji tasarrufu için bunu kullanır. Harici '
                'ekran kartın varsa tam algılamayı kullan ya da kartını seç.',
                style: muted?.copyWith(color: palette.warn),
              ),
            ),
          if (otherUnmatched.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Katalogda henüz olmayan: '
                '${otherUnmatched.map(HardwareMatcher.displayName).join(', ')}',
                style: muted,
              ),
            ),
          if (fromBrowser)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'RAM ve anakart tarayıcıdan okunamaz; aşağıdaki Windows '
                'aracıyla tam algılama yapabilir ya da Kur ekranından '
                'ekleyebilirsin.',
                style: muted,
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: build.parts.isEmpty ? null : onContinue,
            icon: const Icon(Icons.speed_rounded),
            label: Text(
              build.gpu == null
                  ? 'Devam et, ekran kartını seç'
                  : 'Bu sistemle analiz et',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/devices'),
            child: const Text('Başka bir sistemi sorgula'),
          ),
        ],
      ),
    );
  }
}

class _HelperCard extends StatelessWidget {
  const _HelperCard({required this.controller, required this.onApply});

  final TextEditingController controller;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: context.palette.muted);
    return SectionCard(
      title: 'Tam algılama (Windows)',
      icon: Icons.terminal_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'İşlemci, RAM (hız ve modül sayısı) ve anakart için küçük aracı '
            'indir, sağ tıklayıp "PowerShell ile çalıştır" de. Araç yalnızca '
            'donanım bilgisini okur; hiçbir şey yüklemez, internete bir şey '
            'göndermez. Bitince bu sayfayı bilgilerinle açar ve kodu panoya '
            'kopyalar.',
            style: muted,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.base.resolve(kHelperScriptPath),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Algılama aracını indir (detect.ps1)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLength: HardwareReport.maxEncodedLength,
            decoration: const InputDecoration(
              counterText: '',
              hintText: 'Araçtan gelen kodu yapıştır',
              prefixIcon: Icon(Icons.key_rounded),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: onApply,
            child: const Text('Kodu uygula'),
          ),
        ],
      ),
    );
  }
}

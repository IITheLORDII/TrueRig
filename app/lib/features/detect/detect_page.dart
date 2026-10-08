import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:darbogaz/core/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:darbogaz/core/widgets/page_nav.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/images/part_images.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/widgets/buttons.dart';
import 'package:darbogaz/core/widgets/cards.dart';
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

  /// Web only: read from this browser, or paste the Windows helper's code.
  _Method _method = _Method.browser;

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
    setState(
      () => _error = ok ? null : 'Kod okunamadı. Araçtan yeniden kopyala.',
    );
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
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const BrandTitle('Sistemini Algıla'),
        actions: const [HomeButton()],
      ),
      body: ListView(
        padding: Insets.page,
        children: [
          if (detection != null)
            _ResultCard(state: detection, onContinue: _continue)
          else ...[
            if (kIsWeb) ...[
              AppSegmented<_Method>(
                values: _Method.values,
                selected: _method,
                labelOf: (m) => m.label,
                onChanged: (m) => setState(() {
                  _method = m;
                  _error = null;
                }),
              ),
              const SizedBox(height: Space.cardGap),
            ],
            if (_method == _Method.browser)
              _ConsentCard(onDetect: _detectBrowser)
            else
              _HelperCard(
                controller: _code,
                onApply: () => _applyCode(_code.text),
              ),
            const SizedBox(height: Space.s),
            TertiaryButton(
              label: 'Atla, parçaları kendim seçeceğim',
              onPressed: () => context.go('/devices'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: Space.cardGap),
            Notice(title: _error!, tone: Tone.bad),
          ],
        ],
      ),
    );
  }
}

enum _Method {
  browser('Bu tarayıcıdan'),
  windows('Windows aracı');

  const _Method(this.label);
  final String label;
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.onDetect});

  final VoidCallback onDetect;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Donanımını otomatik tanıyalım',
      icon: Icons.radar_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canProbeBrowser) ...[
            const BulletRow(
              'Ekran kartı modelini, işlemci çekirdek sayısını ve ekran '
              'çözünürlüğünü okuruz.',
              icon: Icons.check_rounded,
            ),
            const BulletRow(
              'Bilgiler cihazından çıkmaz, hiçbir yere gönderilmez.',
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: Space.m),
            PrimaryButton(
              label: 'İzin ver ve algıla',
              icon: Icons.radar_rounded,
              onPressed: onDetect,
            ),
          ] else
            const BulletRow(
              'Bilgisayarının donanımını okumak için TrueRig\'in web '
              'sürümünü o bilgisayarda aç.',
              icon: Icons.computer_rounded,
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
            const SizedBox(height: Space.s),
            Text(
              'Tarayıcı işlemci modelini paylaşmıyor. '
              '${r.report.threads} iş parçacıklı işlemcilerden seninkini seç:',
            ),
            const SizedBox(height: Space.s),
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
              padding: const EdgeInsets.only(top: Space.s),
              child: Text(
                'Ekran: ${r.report.screenWidth}×${r.report.screenHeight} → '
                'analiz ${res.label} ile yapılacak.',
                style: muted,
              ),
            ),
          if (build.gpu == null && integrated != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.s),
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
              padding: const EdgeInsets.only(top: Space.s),
              child: Text(
                'Katalogda henüz olmayan: '
                '${otherUnmatched.map(HardwareMatcher.displayName).join(', ')}',
                style: muted,
              ),
            ),
          if (fromBrowser)
            Padding(
              padding: const EdgeInsets.only(top: Space.s),
              child: Text(
                'RAM ve anakart tarayıcıdan okunamaz. Windows aracıyla tam '
                'algılama yapabilir ya da Cihazlarım\'dan ekleyebilirsin.',
                style: muted,
              ),
            ),
          const SizedBox(height: Space.l),
          PrimaryButton(
            onPressed: build.parts.isEmpty ? null : onContinue,
            icon: Icons.speed_rounded,
            label: build.gpu == null
                ? 'Devam et, ekran kartını seç'
                : 'Bu sistemle analiz et',
          ),
          const SizedBox(height: Space.s),
          TertiaryButton(
            onPressed: () => context.go('/devices'),
            label: 'Başka bir sistem seç',
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
    return SectionCard(
      title: 'Tam algılama (Windows)',
      icon: Icons.terminal_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BulletRow('1. Aracı indir.', icon: Icons.download_rounded),
          const BulletRow(
            '2. Sağ tıkla, "PowerShell ile çalıştır" de.',
            icon: Icons.mouse_rounded,
          ),
          const BulletRow(
            '3. Bu sayfa kendiliğinden açılır. Açılmazsa panodaki kodu '
            'aşağıya yapıştır.',
            icon: Icons.content_paste_rounded,
          ),
          const Footnote(
            'Araç yalnızca işlemci, RAM ve anakart bilgisini okur. Hiçbir şey '
            'yüklemez, internete bir şey göndermez.',
          ),
          const SizedBox(height: Space.m),
          SecondaryButton(
            expand: true,
            icon: Icons.download_rounded,
            label: 'Aracı indir (detect.ps1)',
            onPressed: () => launchUrl(
              Uri.base.resolve(kHelperScriptPath),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: controller,
            maxLength: HardwareReport.maxEncodedLength,
            decoration: const InputDecoration(
              counterText: '',
              hintText: 'Araçtan gelen kodu yapıştır',
              prefixIcon: Icon(Icons.key_rounded),
            ),
          ),
          const SizedBox(height: Space.m),
          PrimaryButton(label: 'Kodu uygula', onPressed: onApply),
        ],
      ),
    );
  }
}

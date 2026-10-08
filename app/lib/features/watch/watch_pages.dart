import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/widgets/page_nav.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/features/phone/phone_picker_page.dart';
import 'package:darbogaz/features/watch/pairing_card.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';

/// "Saatim" section of Cihazlarım.
class WatchPanel extends ConsumerWidget {
  const WatchPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(watchReportProvider);
    if (report == null) {
      return EmptyHint(
        icon: Icons.watch_rounded,
        message:
            'Akıllı saatini seç; telefonunla uyumunu, pil ömrünü ve '
            'özelliklerini gösterelim.',
        action: FilledButton.icon(
          onPressed: () => context.push('/pick/watch'),
          icon: const Icon(Icons.search_rounded),
          label: const Text('Saat seç'),
        ),
      );
    }
    final w = report.watch;
    final theme = Theme.of(context);
    final palette = context.palette;
    final explicitPair = ref.watch(watchSelectionProvider)?.pairedPhoneId;
    final phone = report.phone;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Card(
          child: ListTile(
            leading: Icon(
              Icons.watch_rounded,
              size: 36,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              w.displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${w.os.label} · ${w.chip} · '
              '~${batteryLabel(report.watch.batteryHours)} pil',
            ),
          ),
        ),
        const SizedBox(height: 8),
        PairingCard(
          onChangePhone: () async {
            final picked = await context.push<Phone>('/pick/phone?mode=pair');
            if (picked != null) {
              ref.read(watchSelectionProvider.notifier).pairWith(picked);
            }
          },
        ),
        if (explicitPair == null && phone != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Telefonum bölümündeki telefonun kullanılıyor.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(color: palette.muted),
            ),
          ),
        const SizedBox(height: 12),
        ActionRow(
          secondary: TextButton.icon(
            onPressed: () => context.push('/pick/watch'),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Değiştir'),
          ),
          primary: FilledButton.icon(
            onPressed: () => context.go('/analysis'),
            icon: const Icon(Icons.insights_rounded),
            label: const Text('Ayrıntılar'),
          ),
        ),
      ],
    );
  }
}

class WatchPickerPage extends ConsumerStatefulWidget {
  const WatchPickerPage({super.key, this.returnMode = false});

  /// Pop with the chosen watch (comparison) instead of selecting it.
  final bool returnMode;

  @override
  ConsumerState<WatchPickerPage> createState() => _WatchPickerPageState();
}

class _WatchPickerPageState extends ConsumerState<WatchPickerPage> {
  String _query = '';
  String? _brand;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(mobileCatalogProvider);
    final watches = catalog.searchWatches(_query, brand: _brand);
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const BrandTitle('Saat seç'),
        actions: const [HomeButton()],
      ),
      body: Column(
        children: [
          PickerSearchField(
            hint: 'Model ara (ör. Watch Ultra, Galaxy Watch7)',
            onChanged: (v) => setState(() => _query = v),
          ),
          BrandChips(
            brands: catalog.watchBrands,
            selected: _brand,
            onSelected: (b) => setState(() => _brand = b),
          ),
          Expanded(
            child: watches.isEmpty
                ? const Center(child: Text('Sonuç bulunamadı'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    itemCount: watches.length,
                    itemBuilder: (context, i) {
                      final w = watches[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.watch_rounded),
                        title: Text(w.displayName),
                        subtitle: Text(
                          '${w.os.label} · ${w.year} · '
                          '${w.worksWith.map((p) => p.label).join(' + ')}',
                        ),
                        onTap: () {
                          if (widget.returnMode) {
                            context.pop(w);
                            return;
                          }
                          ref.read(watchSelectionProvider.notifier).select(w);
                          ref
                              .read(activeDeviceProvider.notifier)
                              .set(DeviceKind.watch);
                          context.pop();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// "~18 saat" under two days, otherwise "~14 gün".
String batteryLabel(int hours) =>
    hours < 48 ? '$hours saat' : '${(hours / 24).round()} gün';

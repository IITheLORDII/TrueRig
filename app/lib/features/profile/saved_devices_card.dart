import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/saved_devices.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/cards.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/flow.dart';
import 'package:darbogaz/core/widgets/device_chip.dart';

/// "Kayıtlı sistemler": every saved PC / phone / watch on this device.
class SavedDevicesCard extends ConsumerWidget {
  const SavedDevicesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedDevicesProvider);
    final ctl = ref.read(savedDevicesProvider.notifier);
    final theme = Theme.of(context);
    final rows = [
      for (final k in DeviceKind.values)
        for (var i = 0; i < saved.of(k).length; i++)
          if (!saved.of(k)[i].isEmpty) (kind: k, index: i),
    ];

    return SectionCard(
      title: 'Kayıtlı sistemler',
      icon: Icons.bookmarks_rounded,
      trailing: rows.isEmpty
          ? null
          : IconButton(
              tooltip: 'Listeyi paylaş',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => _share(context, ref, rows),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rows.isEmpty)
            Text(
              "Henüz kayıtlı cihaz yok. Cihazlarım'dan bilgisayar, telefon "
              've saat ekleyebilirsin.',
              style: theme.textTheme.bodyMedium,
            ),
          for (final r in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(deviceIcon(r.kind)),
              title: Text(
                ctl.labelOf(r.kind, r.index),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                r.kind.label +
                    (saved.activeIndex(r.kind) == r.index ? ' · aktif' : ''),
              ),
              trailing: IconButton(
                tooltip: 'Sil',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  final name = ctl.labelOf(r.kind, r.index);
                  final ok = await confirmAction(
                    context,
                    title: '$name silinsin mi?',
                    message: 'Bu cihaz kayıtlı listeden çıkarılır.',
                  );
                  if (ok) ctl.remove(r.kind, r.index);
                },
              ),
              onTap: () {
                ctl.switchTo(r.kind, r.index);
                ref.read(activeDeviceProvider.notifier).set(r.kind);
                context.go('/devices?kind=${r.kind.name}');
              },
            ),
          const SizedBox(height: Space.xs),
          const Footnote('Bu telefonda saklanır, hiçbir yere gönderilmez.'),
        ],
      ),
    );
  }

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    List<({DeviceKind kind, int index})> rows,
  ) async {
    final ctl = ref.read(savedDevicesProvider.notifier);
    final text = [
      '$kAppName cihazlarım:',
      for (final r in rows)
        '• ${r.kind.label}: ${ctl.labelOf(r.kind, r.index)}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Liste panoya kopyalandı.')));
    }
  }
}

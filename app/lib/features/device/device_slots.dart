import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:darbogaz/features/device/add_device_sheet.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/saved_devices.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/widgets/buttons.dart';
import 'package:darbogaz/core/widgets/flow.dart';

/// Chips for every saved device of [kind] + "Ekle", and a "⋯" menu to
/// rename or delete the selected one (long press on a chip works too).
class DeviceSlotBar extends ConsumerWidget {
  const DeviceSlotBar({super.key, required this.kind});

  final DeviceKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedDevicesProvider);
    final ctl = ref.read(savedDevicesProvider.notifier);
    final list = saved.of(kind);
    final active = saved.activeIndex(kind);
    final hasActive = active < list.length && !list[active].isEmpty;
    return SizedBox(
      height: kMinTap,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < list.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: Space.xs),
                    child: GestureDetector(
                      onLongPress: () => _menu(context, ref, i),
                      child: ChoiceChip(
                        label: Text(ctl.labelOf(kind, i)),
                        selected: i == active,
                        onSelected: (_) => ctl.switchTo(kind, i),
                      ),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: Text('${kind.label} ekle'),
                  onPressed: () {
                    ctl.addNew(kind);
                    showAddDeviceSheet(context, ref, kind);
                  },
                ),
              ],
            ),
          ),
          if (hasActive)
            IconButton(
              tooltip: 'Adlandır ya da sil',
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: () => _menu(context, ref, active),
            ),
        ],
      ),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, int index) async {
    final ctl = ref.read(savedDevicesProvider.notifier);
    final action = await showOptionSheet<String>(
      context: context,
      title: ctl.labelOf(kind, index),
      options: const ['rename', 'delete'],
      labelOf: (o) => o == 'rename' ? 'Yeniden adlandır' : 'Sil',
    );
    if (!context.mounted || action == null) return;
    if (action == 'delete') {
      final ok = await confirmAction(
        context,
        title: '${ctl.labelOf(kind, index)} silinsin mi?',
        message: 'Bu cihaz ve seçtiğin parçaları listeden çıkarılır.',
      );
      if (ok) ctl.remove(kind, index);
      return;
    }
    final name = await showRenameDialog(context, ctl.labelOf(kind, index));
    if (name != null) ctl.rename(kind, index, name);
  }
}

/// Asks for a device name; null when cancelled.
Future<String?> showRenameDialog(BuildContext context, String current) =>
    showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(current: current),
    );

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.current});

  final String current;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cihaz adı'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 40,
      decoration: const InputDecoration(hintText: 'Örn. İş laptopu'),
      onSubmitted: (v) => Navigator.of(context).pop(v),
    ),
    actions: [
      TertiaryButton(
        label: 'Vazgeç',
        onPressed: () => Navigator.of(context).pop(),
      ),
      SecondaryButton(
        label: 'Kaydet',
        onPressed: () => Navigator.of(context).pop(_controller.text),
      ),
    ],
  );
}

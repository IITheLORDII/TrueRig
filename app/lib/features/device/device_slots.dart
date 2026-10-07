import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/saved_devices.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';

/// Chips for every saved device of [kind] + "Ekle". Long press: rename or
/// delete.
class DeviceSlotBar extends ConsumerWidget {
  const DeviceSlotBar({super.key, required this.kind});

  final DeviceKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedDevicesProvider);
    final ctl = ref.read(savedDevicesProvider.notifier);
    final list = saved.of(kind);
    final active = saved.activeIndex(kind);
    return SizedBox(
      height: 40,
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
            onPressed: () => ctl.addNew(kind),
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
      ctl.remove(kind, index);
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
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Kaydet'),
      ),
    ],
  );
}

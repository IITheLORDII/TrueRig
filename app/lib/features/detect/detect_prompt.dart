import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:darbogaz/core/widgets/buttons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/features/detect/detection_controller.dart';

const _askedKey = 'detect.asked';

/// Website only, once, and only while no PC has been added.
bool shouldAskDetect(WidgetRef ref) =>
    kIsWeb &&
    !(ref.read(prefsProvider)?.getBool(_askedKey) ?? false) &&
    ref.read(buildProvider).parts.isEmpty;

/// Small "shall we recognise this computer?" popup instead of a full page.
/// With CPU and GPU found it goes straight to the analysis; otherwise the
/// detection page opens to finish the rest.
Future<void> showDetectPrompt(BuildContext context, WidgetRef ref) async {
  ref.read(prefsProvider)?.setBool(_askedKey, true);
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        icon: Icon(
          Icons.radar_rounded,
          size: 36,
          color: theme.colorScheme.primary,
        ),
        title: const Text('Bilgisayarını tanıyalım mı?'),
        content: Text(
          'Tarayıcının paylaştığı bilgileri okuruz. Hiçbir şey gönderilmez.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: ctx.palette.muted),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.l),
        actions: [
          TertiaryButton(
            label: 'Şimdi değil',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          SecondaryButton(
            label: 'Tanı',
            icon: Icons.radar_rounded,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      );
    },
  );
  if (yes != true || !context.mounted) return;

  final detection = ref.read(detectionProvider.notifier);
  if (!detection.detectFromBrowser()) {
    context.push('/detect');
    return;
  }
  final build = ref.read(detectionProvider)?.build;
  ref.read(activeDeviceProvider.notifier).set(DeviceKind.pc);
  if (build?.cpu != null && build?.gpu != null) {
    detection.applyToBuild();
    context.go('/analysis');
  } else {
    // Something is missing (often the exact CPU): finish on the full page.
    context.push('/detect');
  }
}

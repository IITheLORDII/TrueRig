import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:darbogaz/core/theme/tokens.dart';

// One shared look on iOS, Android and web: no platform branching.

/// Compact sliding segmented control.
class AppSegmented<T extends Object> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: selected,
        thumbColor: scheme.primary,
        backgroundColor: scheme.surfaceContainerHigh,
        children: {
          for (final v in values)
            v: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              // 48 px tall tap target; wraps to two lines instead of
              // shrinking large text.
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kMinTap),
                child: Center(
                  child: Text(
                    labelOf(v),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: v == selected
                          ? scheme.onPrimary
                          : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
        },
        onValueChanged: (v) {
          if (v == null || v == selected) return;
          HapticFeedback.selectionClick();
          onChanged(v);
        },
      ),
    );
  }
}

/// Bottom sheet picker with a check mark on the current value.
Future<T?> showOptionSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, scroll) => ListView(
        controller: scroll,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.s),
            child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
          ),
          for (final o in options)
            ListTile(
              title: Text(labelOf(o)),
              trailing: o == selected
                  ? Icon(
                      Icons.check_rounded,
                      color: Theme.of(ctx).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.of(ctx).pop(o),
            ),
        ],
      ),
    ),
  );
}

/// Bottom navigation item.
class AppTab {
  const AppTab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// The five main sections, in bottom bar order, with their addresses.
const kAppTabs = [
  AppTab('Ana Sayfa', Icons.home_outlined, Icons.home_rounded),
  AppTab('Cihazlarım', Icons.devices_outlined, Icons.devices_rounded),
  AppTab('Analiz', Icons.insights_outlined, Icons.insights_rounded),
  AppTab(
    'Karşılaştır',
    Icons.compare_arrows_outlined,
    Icons.compare_arrows_rounded,
  ),
  AppTab('Parça Ara', Icons.sell_outlined, Icons.sell_rounded),
];

const kTabPaths = ['/home', '/devices', '/analysis', '/compare', '/prices'];

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AppTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: currentIndex,
    onDestinationSelected: (i) {
      HapticFeedback.selectionClick();
      onTap(i);
    },
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    destinations: [
      for (final t in tabs)
        NavigationDestination(
          icon: Icon(t.icon),
          selectedIcon: Icon(t.activeIcon),
          label: t.label,
        ),
    ],
  );
}

/// Same scroll feel everywhere (iOS-style bounce on Android too).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

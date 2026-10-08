import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:darbogaz/core/router/tab_back.dart';
import 'package:darbogaz/core/widgets/app_controls.dart';

/// Back arrow that is always there: pops when there is a page behind,
/// otherwise (page opened from a link or after a refresh) goes home.
class PageBackButton extends StatelessWidget {
  const PageBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (Navigator.of(context).canPop()) return const BackButton();
    return IconButton(
      tooltip: 'Geri',
      icon: const BackButtonIcon(),
      onPressed: () => context.go('/home'),
    );
  }
}

/// The bottom menu on pages opened over the tabs (pickers, cart, advisor…),
/// so the main sections are always one tap away. The tab the page was
/// opened from stays highlighted.
class InnerNavBar extends ConsumerWidget {
  const InnerNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(tabHistoryProvider);
    return AppBottomBar(
      tabs: kAppTabs,
      currentIndex: history.isEmpty ? 0 : history.last,
      onTap: (i) => context.go(kTabPaths[i]),
    );
  }
}

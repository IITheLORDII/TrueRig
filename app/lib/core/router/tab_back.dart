import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Visited bottom tabs (branch indexes), most recent last. Ana Sayfa (0)
/// is the root every back step eventually returns to.
final tabHistoryProvider = NotifierProvider<TabHistory, List<int>>(
  TabHistory.new,
);

class TabHistory extends Notifier<List<int>> {
  @override
  List<int> build() => const [0];

  /// Records that [tab] is now shown (moves it to the end).
  void visit(int tab) {
    if (state.isNotEmpty && state.last == tab) return;
    state = List.unmodifiable([...state.where((t) => t != tab), tab]);
  }

  /// Leaves the current tab; returns the tab to show instead.
  int back() {
    final rest = state.length > 1
        ? state.sublist(0, state.length - 1)
        : const <int>[];
    final target = rest.isEmpty ? 0 : rest.last;
    state = List.unmodifiable(rest.isEmpty ? [0] : rest);
    return target;
  }
}

/// Goes back from the current tab: previous tab, else Ana Sayfa.
void goBackFromTab(WidgetRef ref, void Function(int index) goBranch) {
  goBranch(ref.read(tabHistoryProvider.notifier).back());
}

/// Back arrow for the tab pages' app bars (hidden on Ana Sayfa).
class TabBackButton extends ConsumerWidget {
  const TabBackButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell == null || shell.currentIndex == 0) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: 'Geri',
      icon: const BackButtonIcon(),
      onPressed: () => goBackFromTab(ref, (i) => shell.goBranch(i)),
    );
  }
}

/// Wraps the tab area: Android back and an iOS-style swipe from the left
/// edge go back a tab; on Ana Sayfa the system back leaves the app.
class TabBackScope extends ConsumerStatefulWidget {
  const TabBackScope({super.key, required this.shell, required this.child});

  final StatefulNavigationShell shell;
  final Widget child;

  @override
  ConsumerState<TabBackScope> createState() => _TabBackScopeState();
}

class _TabBackScopeState extends ConsumerState<TabBackScope> {
  /// Width of the left edge that starts a back swipe (like iOS).
  static const double _edge = 24;

  /// Distance or speed that completes it.
  static const double _distance = 80;
  static const double _velocity = 400;

  double _dragged = 0;

  void _back() => goBackFromTab(ref, (i) => widget.shell.goBranch(i));

  @override
  Widget build(BuildContext context) {
    final index = widget.shell.currentIndex;
    // Keep the history in step with tab changes made by links (context.go).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(tabHistoryProvider.notifier).visit(index);
    });
    final onRoot = index == 0;
    return PopScope(
      canPop: onRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Stack(
        children: [
          widget.child,
          if (!onRoot)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _edge,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) => _dragged = 0,
                onHorizontalDragUpdate: (d) => _dragged += d.delta.dx,
                onHorizontalDragEnd: (d) {
                  if (_dragged > _distance ||
                      (d.primaryVelocity ?? 0) > _velocity) {
                    _back();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

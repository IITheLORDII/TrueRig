import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

/// Straight back to Ana Sayfa from any inner page.
class HomeButton extends StatelessWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Ana Sayfa',
    icon: const Icon(Icons.home_rounded),
    onPressed: () => context.go('/home'),
  );
}

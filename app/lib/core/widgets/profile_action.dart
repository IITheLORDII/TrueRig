import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Profile / settings entry shown at the right of every tab's app bar.
class ProfileAction extends StatelessWidget {
  const ProfileAction({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Profil ve ayarlar',
    icon: const Icon(Icons.account_circle_outlined),
    onPressed: () => context.push('/profile'),
  );
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/buttons.dart';

/// Welcome card at the top of Ana Sayfa: what the app does in one line,
/// the three steps (each opens its tab) and the two ways to start.
class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = context.palette;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: p.outline),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              kBrandCyan.withValues(alpha: 0.10),
              scheme.surfaceContainer,
            ),
            scheme.surfaceContainer,
            Color.alphaBlend(
              kBrandViolet.withValues(alpha: 0.16),
              scheme.surfaceContainer,
            ),
          ],
          stops: const [0, 0.5, 1],
        ),
      ),
      child: Stack(
        children: [
          // Large faint chip in the corner.
          Positioned(
            right: -6,
            top: 4,
            child: ExcludeSemantics(
              child: Icon(
                Icons.memory_rounded,
                size: 96,
                color: scheme.onSurface.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KARAR VERMEK ARTIK DAHA KOLAY',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: Space.s),
                Text(
                  'Doğru parçayı bul.\nDengeli sistemi kur.',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: Space.m),
                Text(
                  'Uyumluluğu kontrol et, gerçek kullanım performansını gör '
                  've mağaza fiyatlarını tek yerde karşılaştır.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                ),
                const SizedBox(height: Space.l),
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    _Step(
                      icon: Icons.handyman_rounded,
                      label: '1 · Topla',
                      onTap: () => context.go('/devices?kind=pc'),
                    ),
                    _Step(
                      icon: Icons.monitor_heart_rounded,
                      label: '2 · Analiz et',
                      onTap: () => context.go('/analysis'),
                    ),
                    _Step(
                      icon: Icons.sell_rounded,
                      label: '3 · Fiyat bul',
                      onTap: () => context.go('/prices'),
                    ),
                  ],
                ),
                const SizedBox(height: Space.l),
                Wrap(
                  spacing: Space.m,
                  runSpacing: Space.s,
                  children: [
                    PrimaryButton(
                      label: 'PC toplamaya başla',
                      icon: Icons.add_rounded,
                      expand: false,
                      onPressed: () => context.go('/devices?kind=pc'),
                    ),
                    SecondaryButton(
                      label: 'Hazır sistem seç',
                      icon: Icons.laptop_rounded,
                      onPressed: () => context.push('/pick/prebuilt'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One step of "Topla → Analiz et → Fiyat bul"; opens its tab.
class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 18),
    label: Text(label),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    shape: const StadiumBorder(),
    onPressed: onTap,
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/widgets/page_nav.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/features/prices/store_list.dart';
import 'package:darbogaz/features/sandbox/sandbox_state.dart';

/// "~28.200 TL": estimates rounded to hundreds (no false precision).
String _roughTl(double v) =>
    '~${formatPrice((v / 100).round() * 100.0, 'TRY').replaceAll(' TRY', '')} TL';

/// Budget steps offered (upper limits, TL); null = "Bilmiyorum".
const _budgets = <double?>[20000, 35000, 55000, 80000, 120000, null];

String _budgetLabel(double? b) => b == null
    ? 'Bilmiyorum / fark etmez'
    : '${formatPrice(b, 'TRY').replaceAll(' TRY', '')} TL\'ye kadar';

/// "Bilgisayarı ne için alıyorsun?": a few plain questions, then systems
/// that really fit the job and the traps to avoid. Nothing is saved.
class AdvisorPage extends ConsumerStatefulWidget {
  const AdvisorPage({super.key});

  @override
  ConsumerState<AdvisorPage> createState() => _AdvisorPageState();
}

class _AdvisorPageState extends ConsumerState<AdvisorPage> {
  int _step = 0;
  final Set<Usage> _uses = {};
  GameLevel _level = GameLevel.medium;
  bool _highFps = false;
  FormChoice _form = FormChoice.any;
  double? _budget;

  bool get _gaming => _uses.contains(Usage.gaming);

  /// Steps shown: uses, (games), form, budget, result.
  List<int> get _steps => [0, if (_gaming) 1, 2, 3, 4];

  void _next() {
    final i = _steps.indexOf(_step);
    setState(() => _step = _steps[i + 1]);
  }

  void _back() {
    final i = _steps.indexOf(_step);
    setState(() => _step = _steps[i - 1]);
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final position = steps.indexOf(_step);
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const PageBackButton(),
          title: const BrandTitle('Sana uygun bilgisayar'),
          actions: const [HomeButton()],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_step != 4)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.page,
                  0,
                  Space.page,
                  Space.s,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < steps.length - 1; i++)
                      Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.only(right: Space.xs),
                          decoration: BoxDecoration(
                            color: i <= position
                                ? Theme.of(context).colorScheme.primary
                                : context.palette.surfaceAlt,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.normal,
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _usesStep(),
                    1 => _gamesStep(),
                    2 => _formStep(),
                    3 => _budgetStep(),
                    _ => _AdvisorResult(
                      profile: UsageProfile(
                        uses: _uses,
                        gameLevel: _level,
                        highFps: _highFps,
                        form: _form,
                        budgetTry: _budget,
                      ),
                      onRestart: () => setState(() {
                        _step = 0;
                        _uses.clear();
                      }),
                    ),
                  },
                ),
              ),
            ),
            if (_step != 4)
              Padding(
                padding: const EdgeInsets.all(Space.page),
                child: Row(
                  children: [
                    if (_step != 0)
                      TextButton(onPressed: _back, child: const Text('Geri')),
                    const Spacer(),
                    FilledButton(
                      onPressed: _step == 0 && _uses.isEmpty ? null : _next,
                      child: Text(_step == 3 ? 'Önerileri göster' : 'Devam'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _question(String title, String? hint, List<Widget> choices) =>
      ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.page,
          Space.s,
          Space.page,
          Space.l,
        ),
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (hint != null) ...[
            const SizedBox(height: Space.xs),
            Text(hint, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: Space.l),
          ...choices,
        ],
      );

  Widget _usesStep() =>
      _question('Bilgisayarda ne yapacaksın?', 'Birden fazla seçebilirsin.', [
        for (final (u, icon) in const [
          (Usage.office, Icons.description_rounded),
          (Usage.gaming, Icons.sports_esports_rounded),
          (Usage.media, Icons.movie_edit),
          (Usage.engineering, Icons.architecture_rounded),
          (Usage.coding, Icons.code_rounded),
          (Usage.ai, Icons.psychology_rounded),
        ])
          _Choice(
            icon: icon,
            title: u.label,
            selected: _uses.contains(u),
            multi: true,
            onTap: () => setState(
              () => _uses.contains(u) ? _uses.remove(u) : _uses.add(u),
            ),
          ),
      ]);

  Widget _gamesStep() => _question('Hangi oyunları oynayacaksın?', null, [
    for (final l in GameLevel.values)
      _Choice(
        icon: Icons.sports_esports_rounded,
        title: l.label,
        selected: _level == l,
        onTap: () => setState(() => _level = l),
      ),
    const SizedBox(height: Space.s),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Rekabetçi oynayacağım (144 FPS)'),
      subtitle: const Text('Normalde 60 FPS yeterli ve akıcıdır.'),
      value: _highFps,
      onChanged: (v) => setState(() => _highFps = v),
    ),
  ]);

  Widget _formStep() => _question('Laptop mu, masaüstü mü?', null, [
    for (final (f, icon, title, hint) in const [
      (
        FormChoice.laptop,
        Icons.laptop_chromebook_rounded,
        'Laptop',
        'Taşıyacağım, okula ya da işe götüreceğim',
      ),
      (
        FormChoice.desktop,
        Icons.desktop_windows_rounded,
        'Masaüstü',
        'Masada kalacak; aynı paraya daha güçlü',
      ),
      (FormChoice.any, Icons.help_outline_rounded, 'Fark etmez', null),
    ])
      _Choice(
        icon: icon,
        title: title,
        hint: hint,
        selected: _form == f,
        onTap: () => setState(() => _form = f),
      ),
  ]);

  Widget _budgetStep() => _question('Bütçen ne kadar?', null, [
    for (final b in _budgets)
      _Choice(
        icon: Icons.payments_rounded,
        title: _budgetLabel(b),
        selected: _budget == b,
        onTap: () => setState(() => _budget = b),
      ),
  ]);
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.hint,
    this.multi = false,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: selected ? scheme.primary.withValues(alpha: 0.15) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          side: BorderSide(
            color: selected ? scheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Space.l,
            vertical: Space.xs,
          ),
          leading: Icon(icon, color: scheme.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: hint == null ? null : Text(hint!),
          trailing: Icon(
            multi
                ? (selected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded)
                : (selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded),
            color: selected ? scheme.primary : null,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _AdvisorResult extends ConsumerWidget {
  const _AdvisorResult({required this.profile, required this.onRestart});

  final UsageProfile profile;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(usdTryProvider);
    return rate.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _body(context, ref, kFallbackUsdTry),
      data: (r) => _body(context, ref, r),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, double usdTry) {
    final advice = const PurchaseAdvisor().advise(
      profile,
      ref.read(catalogProvider),
      usdTry: usdTry,
    );
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.page,
        Space.xs,
        Space.page,
        Space.xl,
      ),
      children: [
        Text(
          advice.options.isEmpty
              ? 'Uygun bir sistem bulamadık'
              : 'Sana uygun ${advice.options.length} seçenek',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          [
            for (final u in profile.uses) u.label,
            if (profile.uses.contains(Usage.gaming)) profile.gameLevel.label,
            _budgetLabel(profile.budgetTry),
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.palette.muted,
          ),
        ),
        const SizedBox(height: Space.m),
        if (advice.overBudget)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: Text(
              'Bütçene uyan ve işini gören bir sistem yok; en yakın '
              'seçenekleri gösteriyoruz.',
              style: TextStyle(color: context.palette.warn),
            ),
          ),
        for (final o in advice.options) ...[
          _OptionCard(option: o),
          const SizedBox(height: Space.s),
        ],
        SectionCard(
          title: 'Dikkat et',
          icon: Icons.warning_amber_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in advice.cautions)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: context.palette.warn,
                      ),
                      const SizedBox(width: Space.s),
                      Expanded(child: Text(c)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.s),
        Text(
          'Fiyatlar tahminidir (liste fiyatı × güncel kur, vergiler dahil); '
          'mağaza fiyatlarına dokunarak bakabilirsin.',
          style: theme.textTheme.labelSmall?.copyWith(
            color: context.palette.muted,
          ),
        ),
        const SizedBox(height: Space.s),
        OutlinedButton.icon(
          onPressed: onRestart,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Baştan başla'),
        ),
      ],
    );
  }
}

class _OptionCard extends ConsumerWidget {
  const _OptionCard({required this.option});

  final PurchaseOption option;

  void _toSandbox(WidgetRef ref) {
    ref.read(sandboxProvider.notifier)
      ..setKind(DeviceKind.pc)
      ..setPc(0, SandboxPc(label: option.name, build: option.build));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tone = switch (option.label) {
      'En uygun' => Tone.good,
      'Dengeli' => Tone.brand,
      _ => Tone.neutral,
    };
    return SectionCard(
      hero: option.label == 'En uygun',
      title: option.label,
      icon: option.isLaptop
          ? Icons.laptop_chromebook_rounded
          : Icons.desktop_windows_rounded,
      trailing: VerdictChip(_roughTl(option.priceTry), tone: tone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            option.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(option.why, style: theme.textTheme.bodyMedium),
          const SizedBox(height: Space.s),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _toSandbox(ref);
                    context.push('/sandbox?tab=pc');
                  },
                  child: const Text('Analiz et'),
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    _toSandbox(ref);
                    context.push('/cart?src=sandbox');
                  },
                  child: const Text('Fiyatlara bak'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

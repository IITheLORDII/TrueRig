import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/widgets/page_nav.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/buttons.dart';
import 'package:darbogaz/core/widgets/cards.dart';
import 'package:darbogaz/core/widgets/flow.dart';
import 'package:darbogaz/features/advisor/advisor_result.dart';

/// Budget steps offered (upper limits, TL); null = "Bilmiyorum".
const _budgets = <double?>[20000, 35000, 55000, 80000, 120000, null];

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
        bottomNavigationBar: _step == 4
            ? null
            : StickyActionBar(
                secondary: _step == 0
                    ? null
                    : TertiaryButton(label: 'Geri', onPressed: _back),
                primary: PrimaryButton(
                  label: _step == 3 ? 'Önerileri göster' : 'Devam',
                  onPressed: _step == 0 && _uses.isEmpty ? null : _next,
                ),
              ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_step != 4)
              Padding(
                padding: Insets.pageHeader,
                child: StepProgress(
                  step: position + 1,
                  total: steps.length - 1,
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
                    _ => AdvisorResult(
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
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (hint != null) ...[
            const SizedBox(height: Space.xs),
            Text(hint, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: Space.l),
          for (final c in choices)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: c,
            ),
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
          SelectCard(
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
      SelectCard(
        icon: Icons.sports_esports_rounded,
        title: l.label,
        selected: _level == l,
        onTap: () => setState(() => _level = l),
      ),
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
      SelectCard(
        icon: icon,
        title: title,
        subtitle: hint,
        selected: _form == f,
        onTap: () => setState(() => _form = f),
      ),
  ]);

  Widget _budgetStep() => _question('Bütçen ne kadar?', null, [
    for (final b in _budgets)
      SelectCard(
        icon: Icons.payments_rounded,
        title: budgetLabel(b),
        selected: _budget == b,
        onTap: () => setState(() => _budget = b),
      ),
  ]);
}

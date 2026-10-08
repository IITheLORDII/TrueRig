import 'package:flutter/material.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/term_info.dart';

/// A question-shaped button ("Darboğaz nedir?", "Neden bu önerildi?") that
/// opens its answer in place. Keeps explanations out of sight until the
/// reader asks for them, so screens stay short and calm.
class Explain extends StatefulWidget {
  const Explain({
    super.key,
    required this.question,
    this.answer,
    this.points,
    this.child,
    this.icon = Icons.help_outline_rounded,
    this.color,
    this.initiallyOpen = false,
  });

  /// Explains a technical word with its everyday text.
  Explain.term(Term term, {Key? key})
    : this(key: key, question: term.title, answer: term.body);

  final String question;

  /// Plain answer text.
  final String? answer;

  /// Answer as a short list (one reason per line).
  final List<String>? points;

  /// Any other content as the answer.
  final Widget? child;
  final IconData icon;

  /// Accent colour (defaults to primary; e.g. warn for cautions).
  final Color? color;
  final bool initiallyOpen;

  @override
  State<Explain> createState() => _ExplainState();
}

class _ExplainState extends State<Explain> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.color ?? theme.colorScheme.primary;
    final points = widget.points;
    return Container(
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.m),
              onTap: () => setState(() => _open = !_open),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kMinTap),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.m,
                    vertical: Space.s,
                  ),
                  child: Row(
                    children: [
                      Icon(widget.icon, size: IconSizes.s, color: c),
                      const SizedBox(width: Space.s),
                      Expanded(
                        child: Text(
                          widget.question,
                          style: theme.textTheme.titleSmall?.copyWith(color: c),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: Motion.fast,
                        child: Icon(Icons.expand_more_rounded, color: c),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.normal,
            curve: Motion.curve,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.m,
                      0,
                      Space.m,
                      Space.m,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.answer != null)
                          Text(
                            widget.answer!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        if (points != null)
                          for (final p in points) _Point(p, color: c),
                        ?widget.child,
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.check_rounded, size: 16, color: color),
        ),
        const SizedBox(width: Space.s),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

/// Muted variant used for "how was this calculated?" notes.
class ExplainNote extends StatelessWidget {
  const ExplainNote({super.key, required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) => Explain(
    question: question,
    answer: answer,
    icon: Icons.info_outline_rounded,
    color: context.palette.muted,
  );
}

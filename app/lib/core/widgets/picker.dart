import 'package:flutter/material.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/theme/tokens.dart';
import 'package:darbogaz/core/widgets/cards.dart';
import 'package:darbogaz/core/widgets/flow.dart';

/// Shared pieces of every "pick a part / phone / watch / system" screen so
/// they look and behave the same.

/// Search box under the app bar, with a clear button.
class PickerSearchField extends StatefulWidget {
  const PickerSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.multiline = false,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  /// Grows to three lines (pasting a listing title).
  final bool multiline;

  @override
  State<PickerSearchField> createState() => _PickerSearchFieldState();
}

class _PickerSearchFieldState extends State<PickerSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Space.page,
      Space.xs,
      Space.page,
      Space.s,
    ),
    child: TextField(
      controller: _controller,
      minLines: 1,
      maxLines: widget.multiline ? 3 : 1,
      textInputAction: TextInputAction.search,
      onChanged: (v) {
        setState(() {});
        widget.onChanged(v);
      },
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: widget.hint,
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Temizle',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _controller.clear();
                  setState(() {});
                  widget.onChanged('');
                },
              ),
      ),
    ),
  );
}

/// Horizontal brand filter ("Tümü" + brands), 48 px tap targets.
class BrandChips extends StatelessWidget {
  const BrandChips({
    super.key,
    required this.brands,
    required this.selected,
    required this.onSelected,
  });

  final List<String> brands;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: kMinTap + Space.s,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.page),
      children: [
        for (final b in [null, ...brands])
          Padding(
            padding: const EdgeInsets.only(right: Space.s),
            child: ChoiceChip(
              showCheckmark: false,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              label: Text(b ?? 'Tümü'),
              selected: selected == b,
              onSelected: (_) => onSelected(b),
            ),
          ),
      ],
    ),
  );
}

/// One row of a picker list: picture / icon, name, short specs, optional
/// price, a warning line when it does not fit, and a "Seçili" mark.
class PickerTile extends StatelessWidget {
  const PickerTile({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.icon,
    this.trailingText,
    this.warning,
    this.selected = false,
    this.showChevron = false,
  });

  final String title;
  final String? subtitle;

  /// Custom leading (e.g. a product photo); otherwise [icon] in a tile.
  final Widget? leading;
  final IconData? icon;

  /// Small text at the end, such as "~$199".
  final String? trailingText;

  /// Why this choice will not work with the rest (shown in red with an
  /// icon, so colour is not the only signal).
  final String? warning;
  final bool selected;

  /// Opens more choices (configurations) instead of picking directly.
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;
    final lead = leading ?? (icon == null ? null : IconTile(icon!, size: 40));
    return Semantics(
      button: true,
      selected: selected,
      label: [
        title,
        ?subtitle,
        if (selected) 'seçili',
        if (warning != null) 'uyumsuz: $warning',
      ].join('. '),
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: selected
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.l),
                side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              )
            : null,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.l,
                vertical: Space.m,
              ),
              child: Row(
                children: [
                  if (lead != null) ...[lead, const SizedBox(width: Space.m)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: p.muted,
                            ),
                          ),
                        if (warning != null)
                          Padding(
                            padding: const EdgeInsets.only(top: Space.xs),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: p.bad,
                                ),
                                const SizedBox(width: Space.xs),
                                Expanded(
                                  child: Text(
                                    warning!,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(color: p.bad),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailingText != null) ...[
                    const SizedBox(width: Space.s),
                    Text(
                      trailingText!,
                      style: numberStyle(context, size: 13, color: p.muted),
                    ),
                  ],
                  if (selected) ...[
                    const SizedBox(width: Space.s),
                    Icon(
                      Icons.check_circle_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ] else if (showChevron) ...[
                    const SizedBox(width: Space.s),
                    Icon(Icons.chevron_right_rounded, color: p.muted),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// List body of a picker: empty state when nothing matches.
class PickerList extends StatelessWidget {
  const PickerList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.emptyMessage = 'Sonuç bulunamadı. Başka bir ad ya da kısaltma dene.',
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return StatView.empty(
        icon: Icons.search_off_rounded,
        message: emptyMessage,
      );
    }
    return ListView.separated(
      padding: Insets.page,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: Space.s),
      itemBuilder: itemBuilder,
    );
  }
}

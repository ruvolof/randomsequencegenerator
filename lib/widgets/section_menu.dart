import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/section_label.dart';
import '../models/app_section.dart';
import '../screens/toss_screen.dart';

/// The section switcher in the top right of every section's app bar: a button
/// naming where you are, and a menu listing everywhere you can go.
///
/// It replaced a one-way `Coin` action. With more than two sections a button
/// per section would fill the bar, and none of them would say which one is on
/// screen — so the label carries the answer and the menu carries the choices.
///
/// **The menu owns the navigation**, so a section drops it in and knows nothing
/// about routing. The rules, in one place:
///
/// | from | to | |
/// |---|---|---|
/// | any | itself | nothing |
/// | [AppSection.strings] | a toss section | push |
/// | a toss section | [AppSection.strings] | pop |
/// | a toss section | another toss section | push*Replacement* |
///
/// Replacing rather than stacking is what keeps the stack at root + one however
/// long the user wanders between sections, so the system back gesture always
/// lands on the generator rather than walking back through a history of them.
class SectionMenu extends StatelessWidget {
  const SectionMenu({required this.current, super.key});

  /// The section this menu is being shown in.
  final AppSection current;

  void _go(BuildContext context, AppSection target) {
    if (target == current) return;

    final navigator = Navigator.of(context);
    final kind = target.kind;

    // A null kind is the generator, which is the route below every other
    // section rather than one that can be pushed on top of them.
    if (kind == null) {
      navigator.pop();
      return;
    }

    final route = MaterialPageRoute<void>(
      builder: (_) => TossScreen(kind: kind),
    );
    if (current.kind == null) {
      navigator.push(route);
    } else {
      navigator.pushReplacement(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The same colour the neighbouring text actions take, so the label reads as
    // one of them rather than as a title that happens to sit on the right.
    final color = Theme.of(context).colorScheme.primary;

    return PopupMenuButton<AppSection>(
      // No tooltip of its own: the default is MaterialLocalizations'
      // showMenuTooltip, already localized, and the label says the rest.
      position: PopupMenuPosition.under,
      onSelected: (section) => _go(context, section),
      itemBuilder: (context) => [
        for (final section in AppSection.values)
          CheckedPopupMenuItem(
            value: section,
            // Marks where you are, which is the other half of what the button
            // label says — with the menu open the label is covered.
            checked: section == current,
            child: Text(section.label(l10n)),
          ),
      ],
      child: Padding(
        // Vertical padding rather than a SizedBox: it grows the InkWell the
        // PopupMenuButton puts around this child, so the tap target is 48dp
        // tall and not just the line of text.
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.label(l10n),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: color),
            ),
            Icon(Icons.arrow_drop_down, size: 20, color: color),
          ],
        ),
      ),
    );
  }
}

/// Custom bottom bar (C-W4a) — design-token chrome replacing the stock
/// Material NavigationBar.
///
/// · surface color container with a hairline top border (no stock M3
///   elevation overlay)
/// · active destination: pill indicator (primaryContainer) behind the icon,
///   primary-colored label — an AnimatedContainer morph on SLMotion.fast
/// · every destination is a 44 dp-tall target (full-width column) with
///   always-visible localized labels (the tab_* l10n keys — unchanged, the
///   rtl/smoke tests ride on them)
/// · selection haptic (HapticFeedback.selectionClick — the app's existing
///   haptics pattern from the amal controls)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/design_tokens.dart';

class SLBottomBarItem {
  const SLBottomBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class SLBottomBar extends StatelessWidget {
  const SLBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<SLBottomBarItem> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SLSpacing.s4,
              vertical: 6,
            ),
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(child: _destination(context, i)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _destination(BuildContext context, int index) {
    final item = destinations[index];
    final selected = index == selectedIndex;
    return SLBottomDestination(
      icon: item.icon,
      selectedIcon: item.selectedIcon,
      label: item.label,
      selected: selected,
      onTap: () {
        if (index == selectedIndex) return;
        HapticFeedback.selectionClick();
        onDestinationSelected(index);
      },
    );
  }
}

/// One destination cell — public so widget tests can assert on it.
class SLBottomDestination extends StatelessWidget {
  const SLBottomDestination({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: SLRadius.brMd,
        child: SizedBox(
          height: SLSpacing.minTapTarget + 16,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pill indicator — the token-colored active state.
              AnimatedContainer(
                duration: SLMotion.fast,
                curve: SLMotion.standard,
                padding: const EdgeInsets.symmetric(
                  horizontal: SLSpacing.s16,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: SLRadius.brPill,
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: 22,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

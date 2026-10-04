/// W4e — the madu (downline) tree: the API's flat depth-ordered downline
/// rendered as a vertical indented tree with connector rails (CustomPainter
/// hairlines in token border color), avatar-initial nodes with a subtle
/// gender tint, a gold-soft level chip and a relative last-active label.
///
/// HONEST structure note: GET /api/dawah returns a FLAT list (depth-major
/// sorted, depth 1..3, no parentId, no child-fetch endpoint) — so the tree
/// renders depth as indentation rails and stays READ-ONLY. It deliberately
/// does NOT fabricate per-node parentage (elbows drawn to "the row above"
/// would claim a parent the payload never names).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync_policy.dart' show formatAgoBn;
import '../../design/design_tokens.dart';
import '../../models/dawah.dart';
import '../../models/user.dart' show Gender, Level, LevelJson;
import '../../state/providers.dart';
import '../shared/widgets.dart' show AppCard, L10nX;

/// The madu tree over [nodes] — one card, one row per node.
class MaduTree extends ConsumerWidget {
  const MaduTree({super.key, required this.nodes});

  final List<DownlineNode> nodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // headerNowProvider: the injectable app clock — goldens pin it so the
    // relative last-active labels never drift across capture days.
    final now = ref.watch(headerNowProvider);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final node in nodes) _MaduNodeRow(node: node, now: now),
        ],
      ),
    );
  }
}

class _MaduNodeRow extends StatelessWidget {
  const _MaduNodeRow({required this.node, required this.now});

  final DownlineNode node;
  final DateTime now;

  /// Horizontal distance between two tree levels (3 × the 8-pt unit).
  static const double _unit = 24;

  /// Avatar diameter.
  static const double _avatar = 40;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final indent = (node.depth - 1).clamp(0, 8) * _unit;

    // Subtle gender tint (muted, never saturated): green family for the
    // brothers, gold family for the sisters — the token soft surfaces.
    final (avatarBg, avatarFg) = switch (node.gender) {
      Gender.f =>
        dark
            ? (SLColors.darkGoldSoft, SLColors.darkGoldText)
            : (SLColors.goldSoftLight, SLColors.lightGoldText),
      _ =>
        dark
            ? (SLColors.darkPrimarySoft, SLColors.darkPrimary)
            : (SLColors.primarySoftLight, SLColors.primary),
    };

    final lastActive = DateTime.tryParse(node.lastActiveAt);
    final ago = lastActive == null
        ? null
        : formatAgoBn(now.difference(lastActive), bengali: context.isBn);

    return Container(
      key: ValueKey('maduRow_${node.id}'),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsetsDirectional.only(
        start: SLSpacing.s12,
        end: SLSpacing.s12,
        top: SLSpacing.s8,
        bottom: SLSpacing.s8,
      ),
      child: Stack(
        children: [
          // Connector rails for every ancestor level (see the painter for
          // why they sit under the avatar centers of that level).
          if (indent > 0)
            Positioned.fill(
              child: CustomPaint(
                painter: _ConnectorPainter(
                  depth: node.depth,
                  unit: _unit,
                  avatar: _avatar,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsetsDirectional.only(start: indent),
            child: Row(
              children: [
                Container(
                  key: ValueKey('maduAvatar_${node.id}'),
                  width: _avatar,
                  height: _avatar,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: node.name.isEmpty
                      ? null
                      : Text(
                          maduInitial(node.name),
                          maxLines: 1,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: avatarFg,
                          ),
                        ),
                ),
                const SizedBox(width: SLSpacing.s12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (ago != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          context.t('madu_active_ago').replaceAll('%t%', ago),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: SLSpacing.s8),
                // the level on the right edge; on a deep indent at a large
                // text size it shrinks a little instead of crowding the name
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SLSpacing.s8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: node.level == Level.none
                            ? (dark
                                  ? SLColors.darkGoldSoft
                                  : SLColors.goldSoftLight)
                            : theme.colorScheme.primaryContainer,
                        borderRadius: SLRadius.brPill,
                      ),
                      child: Text(
                        context.t(node.level.labelKey),
                        maxLines: 1,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: node.level == Level.none
                              ? (dark
                                    ? SLColors.darkGoldText
                                    : SLColors.lightGoldText)
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin connector rails (token border color, 1 px strokes — never emoji,
/// never box glyphs).
///
/// Coordinates follow the tree geometry: a level-[a] node's avatar center
/// sits at `startPad + (a-1)*unit + avatar/2` from the row's start edge,
/// so the ancestor rail for level [a] runs down that x through the whole
/// row (the depth-major payload means deeper rows come consecutively — the
/// rails read as continuous generation lines), and this node's own elbow
/// joins its parent-level rail to the left edge of its avatar.
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.depth,
    required this.unit,
    required this.avatar,
    required this.color,
  });

  final int depth;
  final double unit;
  final double avatar;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Offset rail(int level) =>
        Offset(SLSpacing.s12 + (level - 1) * unit + avatar / 2, 0);

    // Rails under every ancestor level's avatar center.
    for (var level = 1; level < depth; level++) {
      final x = rail(level).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    if (depth > 1) {
      // This node's elbow: parent-level rail → own avatar's left edge, at
      // the row's vertical center.
      final y = size.height / 2;
      final from = rail(depth - 1).dx;
      final to = SLSpacing.s12 + (depth - 1) * unit;
      canvas.drawLine(Offset(from, y), Offset(to, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) =>
      oldDelegate.depth != depth ||
      oldDelegate.unit != unit ||
      oldDelegate.avatar != avatar ||
      oldDelegate.color != color;
}

/// The avatar letter for a name: honorific prefixes (মোঃ, মো., মুহাম্মদ,
/// Md., Mohammad …) are skipped, so "মোঃ সাইফুল ইসলাম" shows সা, not মো.
/// The first grapheme cluster keeps a conjunct or vowel sign intact.
String maduInitial(String name) {
  const honorifics = {
    'মোঃ',
    'মো:',
    'মো.',
    'মোহাম্মদ',
    'মুহাম্মদ',
    'মোহাম্মাদ',
    'মুহাম্মাদ',
    'md',
    'md.',
    'mohammad',
    'muhammad',
    'mohammed',
  };
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  final word = words.firstWhere(
    (w) => !honorifics.contains(w.toLowerCase()),
    orElse: () => words.first,
  );
  return word.characters.first;
}

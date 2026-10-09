// LIVE-01..03: the Live screen always shows its three sections, a live
// program can be watched, a past one replayed — and livePlaybackUrl decides
// what plays (it used to be nothing: youtubeId/recordingUrl were unused).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sunnah_life/core/external_urls.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/more/live_screen.dart';
import 'package:sunnah_life/l10n/app_strings.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/remote_state.dart' show liveProvider;

LiveProgramItem _program(String id, String status, {String? youtubeId, String? recordingUrl}) =>
    LiveProgramItem.fromJson({
      'id': id,
      'titleBn': 'প্রোগ্রাম $id',
      'startsAt': '2026-10-03T14:30:00.000Z',
      'status': status,
      'gender': 'M',
      'youtubeId': ?youtubeId,
      'recordingUrl': ?recordingUrl,
    });

Future<void> _pump(WidgetTester tester, List<LiveProgramItem> programs) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [liveProvider.overrideWith((ref) async => programs)],
      child: MaterialApp(theme: buildSunnahLightTheme(), home: const LiveScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('livePlaybackUrl', () {
    test('a recording link wins over the stream id', () {
      expect(
        livePlaybackUrl(youtubeId: 'abc123', recordingUrl: 'https://youtu.be/rec'),
        'https://youtu.be/rec',
      );
    });
    test('a bare id becomes a YouTube watch link; a pasted link is kept', () {
      expect(livePlaybackUrl(youtubeId: 'abc123'), 'https://www.youtube.com/watch?v=abc123');
      expect(
        livePlaybackUrl(youtubeId: 'https://www.youtube.com/live/xyz'),
        'https://www.youtube.com/live/xyz',
      );
    });
    test('nothing playable → null (no watch button)', () {
      expect(livePlaybackUrl(), isNull);
      expect(livePlaybackUrl(youtubeId: '  ', recordingUrl: 'javascript:alert(1)'), isNull);
    });
  });

  testWidgets('no programs at all: one calm empty state, not three', (
    tester,
  ) async {
    await _pump(tester, const []);
    expect(find.text(S.tr(Lang.bn, 'live_none_all')), findsOneWidget);
    expect(find.text('এখন কোনো লাইভ কার্যক্রম নেই'), findsNothing);
  });

  testWidgets('some programs: each empty section still says so in words', (
    tester,
  ) async {
    await _pump(tester, [_program('u1', 'upcoming')]);
    expect(find.text('এখন কোনো লাইভ কার্যক্রম নেই'), findsOneWidget);
    expect(find.text('এখনো কোনো রেকর্ডিং নেই'), findsOneWidget);
  });

  testWidgets('live → লাইভ দেখুন, past → রেকর্ডিং দেখুন, upcoming → remind-me', (tester) async {
    await _pump(tester, [
      _program('l1', 'live', youtubeId: 'abc123'),
      _program('u1', 'upcoming'),
      _program('p1', 'past', recordingUrl: 'https://youtu.be/rec'),
      _program('p2', 'past'), // nothing recorded: no button
    ]);
    expect(find.byKey(const ValueKey('live_watch_l1')), findsOneWidget);
    expect(find.text('লাইভ দেখুন'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('live_watch_p1')), 200);
    expect(find.text('রেকর্ডিং দেখুন'), findsOneWidget);
    expect(find.byKey(const ValueKey('live_watch_p2')), findsNothing);
    expect(find.byKey(const ValueKey('live_watch_u1')), findsNothing);
  });
}

/// লাইভ কুইজ — the live usrah quiz room over the API's own socket.io
/// gateway (B9). Join = mint an HMAC room token via GET /api/quiz/live-token
/// (own-usrah + gender checks happen there), then connect to the SAME API
/// process at path /socket.io: the usrah head runs the quiz (host:*), the
/// members answer (player:answer). Rooms are single-gender usrahs; the
/// leaderboard carries first names + member codes only.
///
/// Wire protocol (source of truth: apps/api/src/engagement/quiz.gateway.ts):
///   in:  room:state · quiz:started · quiz:question · quiz:reveal ·
///        quiz:ended · quiz:error · player:accepted · connect/disconnect
///   out: player:answer · host:start · host:next · host:end
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../../api/api_client.dart';
import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart';
import '../more/usrah_join_sheet.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

// ── wire types (JSON payloads from quiz.gateway.ts) ─────────────────────────

class _RoomPlayer {
  const _RoomPlayer({
    required this.name,
    required this.memberCode,
    required this.online,
  });
  final String name;
  final String? memberCode;
  final bool online;

  factory _RoomPlayer.fromJson(Map<String, dynamic> j) => _RoomPlayer(
    name: j['name'] as String? ?? '',
    memberCode: j['memberCode'] as String?,
    online: j['online'] as bool? ?? true,
  );
}

class _ScoreRowData {
  const _ScoreRowData({
    required this.name,
    required this.memberCode,
    required this.score,
    this.lastPoints,
  });
  final String name;
  final String? memberCode;
  final int score;
  final int? lastPoints;

  factory _ScoreRowData.fromJson(Map<String, dynamic> j) => _ScoreRowData(
    name: j['name'] as String? ?? '',
    memberCode: j['memberCode'] as String?,
    score: (j['score'] as num?)?.toInt() ?? 0,
    lastPoints: (j['lastPoints'] as num?)?.toInt(),
  );
}

class _LiveQuestion {
  const _LiveQuestion({
    required this.index,
    required this.questionBn,
    required this.options,
    required this.seconds,
    required this.endsAtMs,
  });
  final int index;
  final String questionBn;
  final List<String> options;
  final int seconds;
  final int endsAtMs;

  factory _LiveQuestion.fromJson(Map<String, dynamic> j) => _LiveQuestion(
    index: (j['index'] as num?)?.toInt() ?? 0,
    questionBn: j['questionBn'] as String? ?? '',
    options: ((j['options'] as List?) ?? []).map((e) => e.toString()).toList(),
    seconds: (j['seconds'] as num?)?.toInt() ?? 20,
    endsAtMs: (j['endsAt'] as num?)?.toInt() ?? 0,
  );
}

class _RevealData {
  const _RevealData({
    required this.index,
    required this.answerIndex,
    this.explanationBn,
    required this.tally,
    required this.scoreboard,
  });
  final int index;
  final int answerIndex;
  final String? explanationBn;
  final List<int> tally;
  final List<_ScoreRowData> scoreboard;

  factory _RevealData.fromJson(Map<String, dynamic> j) => _RevealData(
    index: (j['index'] as num?)?.toInt() ?? 0,
    answerIndex: (j['answerIndex'] as num?)?.toInt() ?? 0,
    explanationBn: j['explanationBn'] as String?,
    tally: ((j['tally'] as List?) ?? [])
        .map((e) => (e as num?)?.toInt() ?? 0)
        .toList(),
    scoreboard: ((j['scoreboard'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => _ScoreRowData.fromJson(e.cast<String, dynamic>()))
        .toList(),
  );
}

Map<String, dynamic> _asMap(dynamic d) =>
    d is Map ? d.cast<String, dynamic>() : const <String, dynamic>{};

// ── screen ───────────────────────────────────────────────────────────────────

class LiveQuizScreen extends ConsumerStatefulWidget {
  const LiveQuizScreen({super.key});

  @override
  ConsumerState<LiveQuizScreen> createState() => _LiveQuizScreenState();
}

class _LiveQuizScreenState extends ConsumerState<LiveQuizScreen> {
  socket_io.Socket? _socket;
  bool _connected = false;

  String _role = 'player'; // from the minted token, echoed by room:state
  String _phase = 'lobby'; // lobby | question | reveal | ended
  String? _quizTitle;
  int _questionCount = 0;
  _LiveQuestion? _question;
  _RevealData? _reveal;
  List<_RoomPlayer> _players = const [];
  List<_ScoreRowData> _scoreboard = const [];
  int? _myChoice;
  bool _joining = false;

  Timer? _ticker;
  int _nowMs = 0;
  String _selectedQuizId = '';

  bool get _isHost => _role == 'host';

  /// Bengali digits when the app language is Bangla, ASCII otherwise.
  String _num(BuildContext context, Object v) =>
      context.isBn ? toBn(v) : v.toString();

  /// Seconds left on the live question (clamped to 0…seconds).
  int _remainingSecs(_LiveQuestion q) {
    final left = ((q.endsAtMs - _nowMs) / 1000).ceil();
    return left.clamp(0, q.seconds);
  }

  void _pickQuiz(String id) {
    if (_selectedQuizId == id) return;
    setState(() => _selectedQuizId = id);
  }

  // ── lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _stopTicker();
    // Drops the room (ephemeral server state; scores die with the room when
    // everybody leaves — by design, nothing durable is written here).
    _socket?.dispose();
    _socket = null;
    super.dispose();
  }

  // ── countdown ticker (250ms, question phase only) ──────────────────────────

  void _startTicker() {
    _ticker?.cancel();
    _nowMs = DateTime.now().millisecondsSinceEpoch;
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) {
        setState(() => _nowMs = DateTime.now().millisecondsSinceEpoch);
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  // ── join / leave ───────────────────────────────────────────────────────────

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      final res = await ref.read(apiProvider).quizLiveToken('');
      final base = ApiClient.baseUrl.startsWith('http')
          ? ApiClient.baseUrl
          : 'https://${ApiClient.baseUrl}';
      final socket = socket_io.io(
        base,
        socket_io.OptionBuilder()
            .setPath('/socket.io')
            .setAuth({'token': res.token})
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            // a dropped connection (a lift, a weak signal) comes back by
            // itself — it used to strand the player on "বিচ্ছিন্ন"
            .enableReconnection()
            .setReconnectionAttempts(8)
            .setReconnectionDelay(1500)
            .build(),
      );
      _wire(socket);
      setState(() => _role = res.role);
      _socket = socket;
      socket.connect();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _leave() {
    _stopTicker();
    _socket?.dispose();
    _socket = null;
    if (!mounted) return;
    setState(() {
      _connected = false;
      _role = 'player';
      _phase = 'lobby';
      _quizTitle = null;
      _questionCount = 0;
      _question = null;
      _reveal = null;
      _players = const [];
      _scoreboard = const [];
      _myChoice = null;
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── socket wiring ──────────────────────────────────────────────────────────

  void _wire(socket_io.Socket socket) {
    socket.on('connect', (_) {
      if (mounted) setState(() => _connected = true);
    });
    socket.on('disconnect', (_) {
      if (mounted) setState(() => _connected = false);
    });

    // {room, role, phase, quizId, quizTitle, questionCount, currentIndex,
    //  players, scoreboard} — broadcast on every join/leave/phase change.
    socket.on('room:state', (d) {
      final m = _asMap(d);
      if (!mounted) return;
      setState(() {
        _phase = (m['phase'] as String?) ?? _phase;
        _quizTitle = (m['quizTitle'] as String?) ?? _quizTitle;
        final count = (m['questionCount'] as num?)?.toInt() ?? 0;
        if (count > 0) _questionCount = count;
        _players = ((m['players'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => _RoomPlayer.fromJson(e.cast<String, dynamic>()))
            .toList();
        _scoreboard = ((m['scoreboard'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => _ScoreRowData.fromJson(e.cast<String, dynamic>()))
            .toList();
      });
    });

    // {quizId, titleBn, questionCount} — a fresh quiz was started.
    socket.on('quiz:started', (d) {
      final m = _asMap(d);
      if (!mounted) return;
      setState(() {
        _quizTitle = (m['titleBn'] as String?) ?? _quizTitle;
        _questionCount = (m['questionCount'] as num?)?.toInt() ?? 0;
        _reveal = null;
        _myChoice = null;
      });
    });

    // {index, questionBn, options, seconds, endsAt(epoch ms)}
    socket.on('quiz:question', (d) {
      final m = _asMap(d);
      if (!mounted) return;
      setState(() {
        _question = _LiveQuestion.fromJson(m);
        _reveal = null;
        _myChoice = null;
        _phase = 'question';
      });
      _startTicker();
    });

    // {index, answerIndex, explanationBn, tally, scoreboard}
    socket.on('quiz:reveal', (d) {
      final m = _asMap(d);
      _stopTicker();
      final reveal = _RevealData.fromJson(m);
      if (!mounted) return;
      setState(() {
        _reveal = reveal;
        _phase = 'reveal';
        if (reveal.scoreboard.isNotEmpty) _scoreboard = reveal.scoreboard;
      });
    });

    // {scoreboard} — final standings.
    socket.on('quiz:ended', (d) {
      final m = _asMap(d);
      _stopTicker();
      final rows = ((m['scoreboard'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => _ScoreRowData.fromJson(e.cast<String, dynamic>()))
          .toList();
      if (!mounted) return;
      setState(() {
        _phase = 'ended';
        _question = null;
        _reveal = null;
        if (rows.isNotEmpty) _scoreboard = rows;
      });
    });

    // {messageBn} — Bengali error straight from the gateway.
    socket.on('quiz:error', (d) {
      final m = _asMap(d);
      _snack(
        (m['messageBn'] as String?) ?? context.t('live_quiz_connect_failed'),
      );
    });

    socket.on('connect_error', (_) {
      _snack(context.t('live_quiz_connect_failed'));
    });

    // {index, choice} — ack for my answer (optimistic UI already locked in).
    socket.on('player:accepted', (d) {
      final m = _asMap(d);
      final choice = (m['choice'] as num?)?.toInt();
      if (choice == null || !mounted || _myChoice != null) return;
      setState(() => _myChoice = choice);
    });
  }

  // ── actions ────────────────────────────────────────────────────────────────

  void _answer(int choice) {
    final socket = _socket;
    final q = _question;
    if (socket == null ||
        q == null ||
        _phase != 'question' ||
        _myChoice != null ||
        _isHost) {
      return;
    }
    setState(() => _myChoice = choice);
    socket.emit('player:answer', {'index': q.index, 'choice': choice});
  }

  void _hostStart(String quizId) =>
      _socket?.emit('host:start', {'quizId': quizId});
  void _hostNext() => _socket?.emit('host:next');
  void _hostEnd() => _socket?.emit('host:end');

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Signing out mid-room drops the socket (the room lives on the server).
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (!next.signedIn && _socket != null) _leave();
    });

    final auth = ref.watch(authProvider);

    Widget body;
    if (auth.status == AuthStatus.loading) {
      body = const Skeleton(height: 96, count: 3);
    } else if (!auth.signedIn) {
      body = _Gate(
        icon: PhosphorIconsRegular.usersThree,
        title: context.t('live_quiz_for_usrah'),
        hint: context.t('live_quiz_signin_hint'),
        actionLabel: context.t('onb_signin'),
        onAction: () => context.push('/auth'),
      );
    } else if (_socket == null && auth.user?.usrahId == null) {
      // the room is per usrah: say so and offer the way in, instead of an
      // "Enter" that ends in a 400
      body = _Gate(
        icon: PhosphorIconsRegular.usersThree,
        title: context.t('live_quiz_for_usrah'),
        hint: context.t('live_quiz_no_usrah_hint'),
        actionLabel: context.t('more_usrah_join'),
        onAction: () => showUsrahJoinSheet(context),
      );
    } else if (_socket == null) {
      body = ListView(
        padding: const EdgeInsets.all(SLSpacing.s16),
        children: [_IntroCard(joining: _joining, onJoin: _join)],
      );
    } else {
      body = _roomBody(context);
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('ilm_live_quiz')),
        actions: _socket == null
            ? null
            : [
                _StatusPill(
                  connected: _connected,
                  label: context.t(
                    _connected
                        ? 'live_quiz_connected'
                        : 'live_quiz_disconnected',
                  ),
                ),
              ],
      ),
      body: body,
    );
  }

  Widget _roomBody(BuildContext context) {
    final pack = ref.watch(quizPackProvider).value ?? const <Quiz>[];
    final liveQuizzes = pack.where((q) => q.live).toList();

    return ListView(
      padding: const EdgeInsets.all(SLSpacing.s16),
      children: [
        if (_isHost) _HostCard(state: this, liveQuizzes: liveQuizzes),
        if (_isHost) const SizedBox(height: SLSpacing.s12),
        AnimatedSwitcher(
          duration: SLMotion.base,
          child: KeyedSubtree(
            key: ValueKey('$_phase-${_question?.index ?? ''}'),
            child: _phaseCard(context),
          ),
        ),
        if (_phase != 'ended' && _scoreboard.isNotEmpty) ...[
          SectionHeader(
            context.t('live_quiz_leaderboard'),
            icon: PhosphorIconsRegular.medal,
          ),
          for (var i = 0; i < _scoreboard.length; i++)
            _LeaderRow(rank: i + 1, row: _scoreboard[i]),
        ],
        const SizedBox(height: SLSpacing.s24),
      ],
    );
  }

  Widget _phaseCard(BuildContext context) {
    switch (_phase) {
      case 'question':
        return _question == null
            ? const SizedBox.shrink()
            : _QuestionCard(state: this, question: _question!);
      case 'reveal':
        return _RevealCard(state: this, reveal: _reveal);
      case 'ended':
        return _EndedCard(state: this);
      default:
        return _LobbyCard(state: this);
    }
  }
}

// ── signed-out gate ──────────────────────────────────────────────────────────

class _Gate extends StatelessWidget {
  const _Gate({
    required this.icon,
    required this.title,
    required this.hint,
    required this.actionLabel,
    required this.onAction,
  });
  final IconData icon;
  final String title;
  final String hint;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SLSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: SLSpacing.s16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SLSpacing.s8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SLSpacing.s16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(PhosphorIconsRegular.signIn, size: 18),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

// ── status pill (header) ─────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.connected, required this.label});
  final bool connected;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = connected
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    return Container(
      margin: const EdgeInsetsDirectional.only(end: SLSpacing.s16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: SLRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connected
                ? PhosphorIconsRegular.wifiHigh
                : PhosphorIconsRegular.wifiSlash,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── intro (not connected yet) ────────────────────────────────────────────────

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.joining, required this.onJoin});
  final bool joining;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(SLSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIconsRegular.broadcast,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: SLSpacing.s12),
              Expanded(
                child: Text(
                  context.t('live_quiz_desc'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.7,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SLSpacing.s16),
          FilledButton.icon(
            onPressed: joining ? null : onJoin,
            icon: joining
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(PhosphorIconsRegular.broadcast, size: 18),
            label: Text(
              context.t(joining ? 'live_quiz_joining' : 'live_quiz_enter'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── host control card (gold border, above the phases) ────────────────────────

class _HostCard extends StatelessWidget {
  const _HostCard({required this.state, required this.liveQuizzes});
  final _LiveQuizScreenState state;
  final List<Quiz> liveQuizzes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.tertiary;

    // Selection defaults to the first live quiz until the host taps one.
    final selected = state._selectedQuizId.isNotEmpty || liveQuizzes.isEmpty
        ? state._selectedQuizId
        : liveQuizzes.first.id;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: SLRadius.brLg,
        side: BorderSide(color: gold.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SLSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIconsRegular.medal, size: 18, color: gold),
                const SizedBox(width: SLSpacing.s8),
                Expanded(
                  child: Text(
                    context.t('live_quiz_host_controls'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            if (state._phase == 'lobby') ...[
              const SizedBox(height: SLSpacing.s12),
              for (final q in liveQuizzes)
                Padding(
                  padding: const EdgeInsets.only(bottom: SLSpacing.s8),
                  child: _QuizPickRow(
                    quiz: q,
                    selected: selected == q.id,
                    onTap: () => state._pickQuiz(q.id),
                  ),
                ),
              const SizedBox(height: SLSpacing.s4),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selected.isEmpty
                      ? null
                      : () => state._hostStart(selected),
                  icon: const Icon(PhosphorIconsRegular.play, size: 18),
                  label: Text(context.t('live_quiz_start')),
                ),
              ),
            ] else ...[
              const SizedBox(height: SLSpacing.s8),
              Text(
                state._quizTitle ?? context.t('live_quiz_host_controls'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${state._num(context, state._questionCount)} '
                '${context.t('quiz_questions')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // ended → the final card below already carries the leave button
              if (state._phase == 'question' || state._phase == 'reveal') ...[
                const SizedBox(height: SLSpacing.s12),
                Row(
                  children: [
                    Expanded(
                      child: state._phase == 'question'
                          ? FilledButton.icon(
                              onPressed: state._hostNext,
                              icon: const Icon(
                                PhosphorIconsRegular.lightning,
                                size: 18,
                              ),
                              label: Text(context.t('live_quiz_reveal_now')),
                            )
                          : FilledButton.icon(
                              onPressed: state._hostNext,
                              icon: const DirectionalIcon(
                                PhosphorIconsRegular.skipForward,
                                size: 18,
                              ),
                              label: Text(context.t('live_quiz_next')),
                            ),
                    ),
                    const SizedBox(width: SLSpacing.s8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: state._hostEnd,
                        icon: const Icon(
                          PhosphorIconsRegular.stopCircle,
                          size: 18,
                        ),
                        label: Text(context.t('live_quiz_end')),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizPickRow extends StatelessWidget {
  const _QuizPickRow({
    required this.quiz,
    required this.selected,
    required this.onTap,
  });
  final Quiz quiz;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: SLRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: SLRadius.brMd,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: SLSpacing.s12,
            vertical: SLSpacing.s8,
          ),
          decoration: BoxDecoration(
            borderRadius: SLRadius.brMd,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                PhosphorIconsRegular.question,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: SLSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      quiz.titleBn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${context.isBn ? toBn(quiz.questions.length) : quiz.questions.length}'
                      ' ${context.t('quiz_questions')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  PhosphorIconsFill.checkCircle,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── lobby phase ──────────────────────────────────────────────────────────────

class _LobbyCard extends StatelessWidget {
  const _LobbyCard({required this.state});
  final _LiveQuizScreenState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(SLSpacing.s16),
      child: Column(
        children: [
          Icon(
            PhosphorIconsRegular.usersThree,
            size: 36,
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: SLSpacing.s8),
          Text(
            context.t(
              state._isHost ? 'live_quiz_lobby_host' : 'live_quiz_lobby_player',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SLSpacing.s12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              context.t('live_quiz_players'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: SLSpacing.s8),
          if (state._players.isEmpty)
            Text(
              '—',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in state._players)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(
                        alpha: p.online ? 0.10 : 0.04,
                      ),
                      borderRadius: SLRadius.brPill,
                    ),
                    child: Text(
                      p.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── question phase ───────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.state, required this.question});
  final _LiveQuizScreenState state;
  final _LiveQuestion question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = state._remainingSecs(question);
    final urgent = remaining <= 5;

    return AppCard(
      padding: const EdgeInsets.all(SLSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: SLRadius.brPill,
                ),
                child: Text(
                  '${context.t('quiz_question_of')} '
                  '${state._num(context, question.index + 1)}'
                  '${state._questionCount > 0 ? '/${state._num(context, state._questionCount)}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    state._num(context, remaining),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: urgent
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      context.t('live_quiz_secs'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: urgent
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: SLSpacing.s12),
          Text(
            question.questionBn,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: SLSpacing.s16),
          for (var i = 0; i < question.options.length; i++)
            _OptionTile(state: state, question: question, index: i),
          const SizedBox(height: SLSpacing.s4),
          Center(
            child: Text(
              state._isHost
                  ? context.t('live_quiz_host_hint')
                  : state._myChoice != null
                  ? context.t('live_quiz_answered')
                  : context.t('quiz_choose_option'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.state,
    required this.question,
    required this.index,
  });
  final _LiveQuizScreenState state;
  final _LiveQuestion question;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picked = state._myChoice == index;
    final locked = state._myChoice != null || state._isHost;

    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s8),
      child: Material(
        color: picked
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: SLRadius.brMd,
        child: InkWell(
          onTap: locked ? null : () => state._answer(index),
          borderRadius: SLRadius.brMd,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: SLSpacing.s12,
              vertical: SLSpacing.s8,
            ),
            decoration: BoxDecoration(
              borderRadius: SLRadius.brMd,
              border: Border.all(
                color: picked
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                width: picked ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: picked
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: picked
                      ? Icon(
                          PhosphorIconsRegular.check,
                          size: 16,
                          color: theme.colorScheme.onPrimary,
                        )
                      : Text(
                          context.isBn ? toBn(index + 1) : '${index + 1}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(width: SLSpacing.s12),
                Expanded(
                  child: Text(
                    question.options[index],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: picked ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── reveal phase (gold tone) ─────────────────────────────────────────────────

class _RevealCard extends StatelessWidget {
  const _RevealCard({required this.state, required this.reveal});
  final _LiveQuizScreenState state;
  final _RevealData? reveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.tertiary;
    final r = reveal;
    if (r == null) return const SizedBox.shrink();

    final q = state._question;
    final answerText =
        (q != null && r.answerIndex >= 0 && r.answerIndex < q.options.length)
        ? q.options[r.answerIndex]
        : null;

    return Container(
      padding: const EdgeInsets.all(SLSpacing.s16),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.10),
        borderRadius: SLRadius.brLg,
        border: Border.all(color: gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.16),
              borderRadius: SLRadius.brPill,
            ),
            child: Text(
              '${context.t('live_quiz_reveal_title')} — '
              '${context.t('quiz_question_of')} ${state._num(context, r.index + 1)}',
              style: theme.textTheme.bodySmall?.copyWith(
                // the gold TEXT ink (the gold fill as text was ~2.3:1)
                color: theme.brightness == Brightness.dark
                    ? SLColors.darkGoldText
                    : SLColors.lightGoldText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // the player's own result first (it was never said)
          if (!state._isHost) ...[
            const SizedBox(height: SLSpacing.s12),
            _MyResult(choice: state._myChoice, correct: r.answerIndex),
          ],
          if (answerText != null) ...[
            const SizedBox(height: SLSpacing.s12),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${context.t('quiz_correct_was')}: ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: answerText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (r.explanationBn != null && r.explanationBn!.isNotEmpty) ...[
            const SizedBox(height: SLSpacing.s4),
            Text(
              r.explanationBn!,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: SLSpacing.s12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var i = 0; i < r.tally.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: SLRadius.brPill,
                  ),
                  child: Text(
                    '${q != null && i < q.options.length ? q.options[i] : state._num(context, i + 1)}: '
                    '${state._num(context, r.tally[i])} '
                    '${context.t('live_quiz_people')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "আপনার উত্তর সঠিক / ভুল / দেননি" on the reveal.
class _MyResult extends StatelessWidget {
  const _MyResult({required this.choice, required this.correct});
  final int? choice;
  final int correct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (IconData icon, Color color, String key) = choice == null
        ? (
            PhosphorIconsRegular.hourglass,
            cs.onSurfaceVariant,
            'live_quiz_you_skipped',
          )
        : choice == correct
        ? (PhosphorIconsFill.checkCircle, cs.primary, 'live_quiz_you_right')
        : (PhosphorIconsRegular.xCircle, cs.error, 'live_quiz_you_wrong');
    return Container(
      key: const ValueKey('live_quiz_my_result'),
      width: double.infinity,
      padding: const EdgeInsets.all(SLSpacing.s12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: SLRadius.brMd,
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: SLSpacing.s8),
          Expanded(
            child: Text(
              context.t(key),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ended phase ──────────────────────────────────────────────────────────────

class _EndedCard extends StatelessWidget {
  const _EndedCard({required this.state});
  final _LiveQuizScreenState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(SLSpacing.s16),
      child: Column(
        children: [
          Icon(
            PhosphorIconsRegular.medal,
            size: 40,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(height: SLSpacing.s8),
          Text(
            context.t('live_quiz_final'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SLSpacing.s12),
          for (var i = 0; i < state._scoreboard.length; i++)
            _LeaderRow(rank: i + 1, row: state._scoreboard[i]),
          const SizedBox(height: SLSpacing.s8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: state._leave,
              icon: const Icon(PhosphorIconsRegular.signOut, size: 18),
              label: Text(context.t('live_quiz_leave')),
            ),
          ),
        ],
      ),
    );
  }
}

// ── leaderboard row (rank 1 gold) ────────────────────────────────────────────

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.rank, required this.row});
  final int rank;
  final _ScoreRowData row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.tertiary;
    final top = rank == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: SLSpacing.s8),
      padding: const EdgeInsets.symmetric(
        horizontal: SLSpacing.s12,
        vertical: SLSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: top ? gold.withValues(alpha: 0.14) : null,
        borderRadius: SLRadius.brMd,
        border: Border.all(
          color: top ? gold.withValues(alpha: 0.5) : theme.colorScheme.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: top ? gold : theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Text(
              context.isBn ? toBn(rank) : '$rank',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: top
                    ? theme.colorScheme.onTertiary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: SLSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (row.memberCode != null && row.memberCode!.isNotEmpty)
                  Text(
                    row.memberCode!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                context.isBn ? toBn(row.score) : '${row.score}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (row.lastPoints != null && row.lastPoints! > 0)
                Text(
                  '+${context.isBn ? toBn(row.lastPoints!) : row.lastPoints}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

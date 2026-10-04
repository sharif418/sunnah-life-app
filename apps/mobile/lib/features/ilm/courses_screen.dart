/// কোর্স — catalog with per-course progress + the lesson player sheet (B9).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

/// Digit formatter following the app language (bn → Bengali numerals).
String _n(BuildContext context, Object value) =>
    context.isBn ? toBn(value) : value.toString();

/// GET /api/courses/:id — with the bundled pack as the offline fallback so
/// the reading experience survives without a connection. Auto-disposed with
/// the route: re-entering always re-reads enrollment progress from the source.
final courseDetailProvider = FutureProvider.autoDispose
    .family<CourseDetailResponse, String>((ref, id) async {
      try {
        return await ref.watch(apiProvider).courseDetail(id);
      } on ApiException {
        final bundled = await loadBundledCourses();
        final match = bundled.where((c) => c.id == id).firstOrNull;
        if (match == null) rethrow;
        return CourseDetailResponse(course: match, enrolledCount: 0);
      }
    });

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursePackProvider);
    final enrollmentsAsync = ref.watch(enrollmentsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('ilm_courses')),
      ),
      body: coursesAsync.when(
        loading: () => const Skeleton(height: 132, count: 4),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: SLSpacing.s24),
            ErrorState(
              message: e is ApiException
                  ? e.message
                  : context.t('courses_load_failed'),
              onRetry: () => ref.invalidate(coursePackProvider),
            ),
          ],
        ),
        data: (courses) {
          if (courses.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: SLSpacing.s24),
                EmptyState(
                  message:
                      '${context.t('courses_empty_title')}\n'
                      '${context.t('courses_empty_hint')}',
                  icon: PhosphorIconsRegular.graduationCap,
                ),
              ],
            );
          }
          final enrollments = enrollmentsAsync.valueOrNull;
          EnrollmentItem? enr(CourseSummary c) =>
              enrollments?.where((e) => e.courseId == c.id).firstOrNull;
          // BNAV-03: চলমান (started, not finished) · সম্পন্ন · the rest
          bool finished(CourseSummary c) =>
              c.lessonCount > 0 && (enr(c)?.done.length ?? 0) >= c.lessonCount;
          final ongoing = [
            for (final c in courses)
              if (enr(c) != null && !finished(c)) c,
          ];
          final done = [for (final c in courses) if (finished(c)) c];
          final rest = [
            for (final c in courses)
              if (enr(c) == null) c,
          ];
          Widget section(String key, IconData icon, List<CourseSummary> list) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(context.t(key), icon: icon),
                  for (final c in list) _courseCard(context, c, enr(c)),
                ],
              );
          return ListView(
            key: const ValueKey('courses_sections'),
            padding: const EdgeInsets.all(SLSpacing.s16),
            children: [
              if (ongoing.isNotEmpty)
                section('courses_ongoing', PhosphorIconsRegular.playCircle, ongoing),
              if (rest.isNotEmpty)
                section(
                  ongoing.isEmpty && done.isEmpty ? 'courses_all' : 'courses_more',
                  PhosphorIconsRegular.graduationCap,
                  rest,
                ),
              if (done.isNotEmpty)
                section('courses_done', PhosphorIconsRegular.sealCheck, done),
            ],
          );
        },
      ),
    );
  }

  Widget _courseCard(
    BuildContext context,
    CourseSummary c,
    EnrollmentItem? enrollment,
  ) {
    final theme = Theme.of(context);
    final done = enrollment?.done.length ?? 0;
    final value = c.lessonCount == 0
        ? 0.0
        : (done / c.lessonCount).clamp(0.0, 1.0).toDouble();
    final meta = [
      '${_n(context, c.lessonCount)} ${context.t('course_lessons_unit')}',
      '${_n(context, c.totalMinutes)} ${context.t('quiz_minutes')}',
      if (c.enrolledCount > 0)
        '${_n(context, c.enrolledCount)} ${context.t('course_enrolled_unit')}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s12),
      child: AppCard(
        onTap: () => context.push('/ilm/courses/${c.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.level.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: SLRadius.brPill,
                ),
                child: Text(
                  c.level,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: SLSpacing.s8),
            Text(
              c.titleBn,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SLSpacing.s4),
            Text(
              c.descBn,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: SLSpacing.s4),
            Text(meta, style: theme.textTheme.bodySmall),
            if (done > 0) ...[
              const SizedBox(height: SLSpacing.s8),
              ClipRRect(
                borderRadius: SLRadius.brPill,
                child: LinearProgressIndicator(value: value, minHeight: 4),
              ),
              const SizedBox(height: SLSpacing.s4),
              Text(
                '${_n(context, done)}/${_n(context, c.lessonCount)} '
                '${context.t('course_progress_of')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: SLSpacing.s12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push('/ilm/courses/${c.id}'),
                child: Text(
                  context.t(done > 0 ? 'course_continue' : 'course_start'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CourseDetailScreen extends ConsumerStatefulWidget {
  const CourseDetailScreen({
    super.key,
    required this.courseId,
    this.openLessonId,
  });

  final String courseId;
  final String? openLessonId;

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  List<String> _done = const [];
  bool _enrolledLocally = false;
  bool _enrolling = false;
  bool _autoOpened = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = courseDetailProvider(widget.courseId);
    ref.listen<AsyncValue<CourseDetailResponse>>(provider, (_, next) {
      next.whenData((resp) {
        if (mounted) setState(() => _applyData(resp));
      });
    });
    final async = ref.watch(provider);
    final signedIn = ref.watch(authProvider).signedIn;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          async.valueOrNull?.course.titleBn ?? context.t('ilm_courses'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: async.when(
        loading: () => const Skeleton(height: 132, count: 4),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: SLSpacing.s24),
            ErrorState(
              message: e is ApiException
                  ? e.message
                  : context.t('courses_load_failed'),
              onRetry: () => ref.invalidate(provider),
            ),
          ],
        ),
        data: (resp) {
          final course = resp.course;
          final enrolled = resp.myEnrollment != null || _enrolledLocally;
          final lessonIds = course.lessons.map((l) => l.id).toSet();
          final doneCount = _done.where(lessonIds.contains).length;
          final total = course.lessons.length;
          final lessons = List.of(course.lessons)
            ..sort((a, b) => a.order.compareTo(b.order));

          return ListView(
            padding: const EdgeInsets.all(SLSpacing.s16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.titleBn, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: SLSpacing.s8),
                    Text(
                      course.descBn,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: SLSpacing.s12),
                    ClipRRect(
                      borderRadius: SLRadius.brPill,
                      child: LinearProgressIndicator(
                        value: total == 0 ? null : doneCount / total,
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: SLSpacing.s4),
                    Text(
                      '${_n(context, doneCount)}/${_n(context, total)} '
                      '${context.t('course_progress_of')}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: SLSpacing.s12),
                    if (!signedIn)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(PhosphorIconsRegular.signIn, size: 18),
                          label: Text(context.t('course_signin_to_enroll')),
                          onPressed: () => context.push('/auth'),
                        ),
                      )
                    else if (!enrolled)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _enrolling ? null : _enroll,
                          child: Text(
                            context.t(
                              _enrolling ? 'course_enrolling' : 'course_enroll',
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          icon: const Icon(
                            PhosphorIconsRegular.checkCircle,
                            size: 18,
                          ),
                          label: Text(context.t('course_enrolled')),
                          onPressed: null,
                        ),
                      ),
                  ],
                ),
              ),
              for (final (i, lesson) in lessons.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: SLSpacing.s12),
                  child: _lessonRow(context, course, lesson, i),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Server progress always wins on load; local edits live only until the
  /// next successful sync (offline edits stay until then).
  void _applyData(CourseDetailResponse resp) {
    _done = List<String>.of(resp.myEnrollment?.done ?? const <String>[]);
    if (!_autoOpened && widget.openLessonId != null) {
      final lesson = resp.course.lessons
          .where((l) => l.id == widget.openLessonId)
          .firstOrNull;
      if (lesson != null) {
        _autoOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openLessonSheet(resp.course, lesson);
        });
      }
    }
  }

  Future<void> _persist(List<String> done) async {
    if (!ref.read(authProvider).signedIn) return; // guest/offline: local only
    try {
      await ref.read(apiProvider).saveCourseProgress(widget.courseId, done);
      // Refresh the catalog's progress rows (invisible beneath this route).
      ref.invalidate(enrollmentsProvider);
    } catch (_) {
      // Offline — keep the local state; the next save retries the sync.
    }
  }

  Future<void> _toggleLesson(CourseLesson lesson) async {
    final done = List<String>.of(_done);
    final wasDone = done.remove(lesson.id);
    if (!wasDone) done.add(lesson.id);
    setState(() => _done = done);
    await _persist(done);
  }

  Future<void> _enroll() async {
    setState(() => _enrolling = true);
    try {
      await ref.read(apiProvider).enroll(widget.courseId);
      if (!mounted) return;
      setState(() => _enrolledLocally = true);
      ref.invalidate(enrollmentsProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  void _openLessonSheet(CourseDetail course, CourseLesson lesson) {
    final lessons = course.lessons;
    final index = lessons.indexOf(lesson);
    final next = index >= 0 && index + 1 < lessons.length
        ? lessons[index + 1]
        : null;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _LessonSheet(
        lesson: lesson,
        next: next,
        initiallyDone: _done.contains(lesson.id),
        onToggle: () => _toggleLesson(lesson),
        onAdvance: () {
          Navigator.of(sheetContext).pop();
          if (next != null) _openLessonSheet(course, next);
        },
      ),
    );
  }

  Widget _lessonRow(
    BuildContext context,
    CourseDetail course,
    CourseLesson lesson,
    int index,
  ) {
    final theme = Theme.of(context);
    final isDone = _done.contains(lesson.id);
    return AppCard(
      onTap: () => _openLessonSheet(course, lesson),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
            ),
            child: Center(
              child: isDone
                  ? Icon(
                      PhosphorIconsRegular.check,
                      size: 20,
                      color: theme.colorScheme.onPrimary,
                    )
                  : Text(
                      _n(context, index + 1),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: SLSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.titleBn,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_n(context, lesson.minutes)} ${context.t('quiz_minutes')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const DirectionalIcon(PhosphorIconsRegular.caretRight, size: 24),
        ],
      ),
    );
  }
}

/// Lesson player — scrollable body with a pinned action area. Marking a
/// lesson complete keeps the sheet open to offer the next lesson; unmarking
/// (or completing the final lesson) closes it.
class _LessonSheet extends StatefulWidget {
  const _LessonSheet({
    required this.lesson,
    required this.next,
    required this.initiallyDone,
    required this.onToggle,
    required this.onAdvance,
  });

  final CourseLesson lesson;
  final CourseLesson? next;
  final bool initiallyDone;
  final Future<void> Function() onToggle;
  final VoidCallback onAdvance;

  @override
  State<_LessonSheet> createState() => _LessonSheetState();
}

class _LessonSheetState extends State<_LessonSheet> {
  late bool _done = widget.initiallyDone;

  Future<void> _handleToggle() async {
    final wasDone = _done;
    setState(() => _done = !wasDone);
    await widget.onToggle();
    if (!mounted) return;
    if (wasDone || widget.next == null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paragraphs = widget.lesson.bodyBn
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + SLSpacing.s16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  SLSpacing.s16,
                  0,
                  SLSpacing.s16,
                  SLSpacing.s16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.lesson.titleBn,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: SLSpacing.s4),
                    Text(
                      '${_n(context, widget.lesson.minutes)} '
                      '${context.t('quiz_minutes')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: SLSpacing.s12),
                    for (final p in paragraphs) ...[
                      Text(
                        p,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
                      ),
                      const SizedBox(height: SLSpacing.s12),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_done)
                    FilledButton.tonal(
                      onPressed: _handleToggle,
                      child: Text(context.t('lesson_unmark')),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _handleToggle,
                      icon: const Icon(PhosphorIconsRegular.check),
                      label: Text(context.t('lesson_complete')),
                    ),
                  if (_done && widget.next != null) ...[
                    const SizedBox(height: SLSpacing.s8),
                    FilledButton.icon(
                      onPressed: widget.onAdvance,
                      icon: const DirectionalIcon(PhosphorIconsRegular.arrowRight),
                      label: Text(context.t('lesson_next')),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

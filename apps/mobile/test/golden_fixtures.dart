// Deterministic fixtures shared by the screen goldens (font_golden_test.dart)
// and the on-demand screen renderer (render_screens_test.dart): a pinned
// clock, a frozen PrayerNow, a signed-in da'ee and a fake ApiClient with
// Bengali-rich payloads — no network, no ticking timers.
import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/api/fallback_catalog.dart' show fallbackDefinitions;
import 'package:sunnah_life/core/date_keys.dart';
import 'package:sunnah_life/core/prayer_engine.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';

/// The pinned instant (a Sunday — mon/thu fast + kahf stay hidden).
final DateTime kGoldenNow = DateTime(2025, 6, 15, 14, 30);
final String kGoldenToday = dateKey(kGoldenNow);

class GoldenPinnedPrayer extends PrayerNotifier {
  @override
  PrayerNow? build() {
    final times = PrayerEngine.compute(
      kGoldenToday,
      lat: 23.8103,
      lng: 90.4125,
      tz: 6,
      method: CalcMethod.karachi,
      madhhab: Madhhab.hanafi,
    );
    final nowMinutes = 14 * 60.0 + 30;
    final (nextKey, mins) = PrayerEngine.nextPrayer(times, nowMinutes);
    return PrayerNow(
      dateKey: kGoldenToday,
      times: times,
      nowMinutes: nowMinutes,
      currentWaqt: PrayerEngine.currentWaqt(times, nowMinutes),
      nextKey: nextKey,
      minutesToNext: mins,
      forbiddenLabel: PrayerEngine.inForbiddenWindow(times, nowMinutes),
      postPrayerKey: PrayerEngine.activePostPrayerPrompt(times, nowMinutes),
    );
  }
}

class GoldenSignedInDaee extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.signedIn,
    user: User(
      id: 'u-font-daee',
      name: 'রাফিউল ইসলাম',
      gender: Gender.m,
      role: Role.daee,
      category: UserCategory.general,
      memberCode: 'DS-000004',
      level: Level.muhibbusSunnah,
      createdAt: '2025-01-01T00:00:00.000Z',
      lastActiveAt: '2025-01-01T00:00:00.000Z',
    ),
  );
}

/// Deterministic remote payloads — no network, Bengali-rich on purpose
/// (the tofu guard only means anything when Bengali actually renders).
class GoldenApi extends ApiClient {
  /// The More §4.3 golden's fixed remote surface: ONE contact + ONE group +
  /// detox on — fed via a configProvider override ONLY for the /more
  /// iteration, so the other four tab goldens stay byte-identical (a
  /// non-empty contacts list would mount the floating ContactFab on every
  /// root tab, changing those pixels too).
  static const AppConfig moreEnrichedConfig = AppConfig(
    donationUrl: 'https://as-sunnah.org/donation',
    domain: 'sunnahlife.app',
    hijriAdjust: 0,
    goldPerGramBdt: 16500,
    silverPerGramBdt: 220,
    contacts: [
      ConfigContact(
        org: 'আস-সুন্নাহ ফাউন্ডেশন',
        descBn: 'মূল সংস্থা — দাওয়াত, শিক্ষা ও সমাজকল্যাণমূলক কার্যক্রম।',
        website: 'https://as-sunnah.org',
        email: 'info@as-sunnah.org',
      ),
    ],
    groups: [
      ConfigGroup(
        titleBn: 'সুন্নাহ লাইফ অ্যাপ গ্রুপ (টেলিগ্রাম)',
        url: 'https://t.me/sunnahlife',
        descBn: 'নিয়মিত আপডেট ও ঘোষণা',
      ),
    ],
    detoxEnabled: true,
  );

  @override
  Future<AppConfig> config() async => const AppConfig(
    donationUrl: 'https://as-sunnah.org/donation',
    domain: 'sunnahlife.app',
    hijriAdjust: 0,
    goldPerGramBdt: 16500,
    silverPerGramBdt: 220,
  );

  @override
  Future<List<AmalDefinition>> amalDefinitions() async => fallbackDefinitions();

  @override
  Future<ApiCached<DawahOverview>> dawahOverview({String? scope}) async =>
      ApiCached(
        DawahOverview(
          memberCode: 'DS-000004',
          referralLink: 'https://sunnahlife.app/join/DS-000004',
          invitedCount: 3,
          downline: [
            DownlineNode(
              id: 'm1',
              name: 'আব্দুল্লাহ আল মামুন',
              gender: Gender.m,
              level: Level.none,
              depth: 1,
              lastActiveAt: '2025-06-10',
            ),
            DownlineNode(
              id: 'm2',
              name: 'মোঃ সাইফুল ইসলাম',
              gender: Gender.m,
              level: Level.none,
              depth: 1,
              lastActiveAt: '2025-06-12',
            ),
          ],
          level: Level.muhibbusSunnah,
          monthsInLevel: 2,
          requirements: [
            const LevelRequirement(
              key: 'r1',
              label: 'সাপ্তাহিক রিভিউ অংশগ্রহণ',
              done: true,
              detail: 'টানা ৪ সপ্তাহ',
            ),
            const LevelRequirement(
              key: 'r2',
              label: 'প্রতিদিন ১ পৃষ্ঠা কুরআন তিলাওয়াত',
              done: true,
              detail: '৩০ দিনের মধ্যে ২৫ দিন',
            ),
            const LevelRequirement(
              key: 'r3',
              label: '২ জনকে দাওয়াত',
              done: false,
              detail: '১/২ সম্পন্ন',
            ),
          ],
          nextLevel: Level.farzeAin1,
          assessments: const [],
        ),
        fetchedAt: kGoldenNow,
      );

  @override
  Future<ApiCached<(Usrah?, List<Announcement>)>> usrah({
    String? scope,
  }) async => ApiCached((
    Usrah(
      id: 'u1',
      name: 'আল-হুদা উসরা',
      gender: Gender.m,
      headName: 'উসরা প্রধান',
      memberCount: 5,
      members: [
        UsrahMember(id: 'm1', name: 'রাফিউল ইসলাম', gender: Gender.m),
        UsrahMember(id: 'm2', name: 'আব্দুল্লাহ আল মামুন', gender: Gender.m),
        UsrahMember(id: 'm3', name: 'সাইফুল ইসলাম', gender: Gender.m),
        UsrahMember(id: 'm4', name: 'মাহমুদ হাসান', gender: Gender.m),
      ],
    ),
    [
      const Announcement(
        id: 'a1',
        authorId: 'h1',
        kind: 'announcement',
        body: 'আগামী শুক্রবার বাদ জুমা উসরার সাপ্তাহিক মজলিস অনুষ্ঠিত হবে, ইনশাআল্লাহ।',
        pinned: true,
        createdAt: '2025-06-10',
        authorName: 'উসরা প্রধান',
      ),
    ],
  ), fetchedAt: kGoldenNow);

  @override
  Future<ApiCached<List<WeeklyReview>>> reviews({String? scope}) async =>
      ApiCached([
        WeeklyReview(
          id: 'r1',
          userId: 'u-font-daee',
          reviewerId: 'h1',
          weekStart: '2025-06-09',
          comment: 'আলহামদুলিল্লাহ, এই সপ্তাহে নিয়মিত আমল হয়েছে।',
          rating: 4,
          status: 'done',
          createdAt: '2025-06-13',
          completedAt: '2025-06-13',
          userName: 'রাফিউল ইসলাম',
          reviewerName: 'উসরা প্রধান',
        ),
      ], fetchedAt: kGoldenNow);

  @override
  Future<List<LiveProgramItem>> live() async => const [];

  @override
  Future<List<CourseSummary>> courses() async => const [];

  @override
  Future<List<Quiz>> quizPack() async => const [];
}

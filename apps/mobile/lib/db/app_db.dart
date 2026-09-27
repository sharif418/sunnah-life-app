/// Spec-path alias for the Drift database — the implementation lives in
/// `lib/db/database.dart` (kept there because tests import
/// `package:sunnah_life/db/database.dart`).
///
/// Tables: AmalEntries (natural key amalKey+date), Outbox, GuestProfiles,
/// SettingsTable (KV), LastRead, AyahBookmarks.
/// DAOs: upsertEntry/writeEntry, entry, entriesForDates, entriesBetween,
/// pendingEntries, markSynced, pendingSyncCount, mergeServerEntries,
/// guestProfile/saveGuestProfile, setting/setSetting, lastReadEntry/
/// saveLastRead, bookmarks/toggleBookmark.
library;

export 'database.dart';

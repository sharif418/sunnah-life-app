/// Sync provider (spec path) — canonical implementation in
/// `lib/state/amal_state.dart`:
///
///  · [syncProvider] — outbox flush to POST /api/amal/entries.
///    Runs every 60 s while the app is alive (attempt = connectivity probe;
///    failures are caught and surfaced as `lastMessage`), plus:
///    - debounced flush (600 ms) after every optimistic amal write, and
///    - manual `flush()` trigger (used by the SyncBadge in the UI).
///  · Merge rule: latest `clientUpdatedAt` wins (pure functions
///    `mergeEntry`/`mergeLists` in `lib/core/sync_merge.dart`, unit-tested).
library;

export '../state/amal_state.dart'
    show
        SyncState,
        SyncNotifier,
        syncProvider,
        AmalState,
        AmalNotifier,
        amalProvider,
        amalDefinitionsProvider;

/// Pure sync-merge rules — the offline-first conflict resolver.
/// Mirror of the server rule in src/app/api/amal/entries: latest
/// clientUpdatedAt wins; on exact ties the remote (already persisted) copy
/// wins so the client converges instead of oscillating.
library;

import '../models/domain.dart';

/// Merge a single (amalKey, date) pair. Returns the winning entry.
AmalEntry mergeEntry(AmalEntry local, AmalEntry remote) {
  final lc = DateTime.tryParse(local.clientUpdatedAt);
  final rc = DateTime.tryParse(remote.clientUpdatedAt);
  if (lc == null) return remote;
  if (rc == null) return local;
  return lc.isAfter(rc) ? local : remote;
}

/// Merge a batch: `remote` entries win only when strictly newer.
List<AmalEntry> mergeLists(List<AmalEntry> local, List<AmalEntry> remote) {
  final byKey = <String, AmalEntry>{};
  for (final e in local) {
    byKey['${e.amalKey}|${e.date}'] = e;
  }
  for (final r in remote) {
    final key = '${r.amalKey}|${r.date}';
    final existing = byKey[key];
    byKey[key] = existing == null ? r : mergeEntry(existing, r);
  }
  return byKey.values.toList();
}

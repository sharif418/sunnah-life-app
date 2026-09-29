/// Drift-backed [ApiCacheStore] (W4-fix4) — the last-good envelope of the
/// Da'wah GET reads lives in the same sqlite file as the amal engine, so a
/// network drop renders the cached overview/usrah/reviews/requirements
/// instead of an error wall. Rows are keyed `endpoint:userId` — the scope
/// makes cross-user leakage structurally impossible.
library;

import 'dart:convert';

import '../api/api_client.dart';
import 'database.dart';

class DriftApiCacheStore implements ApiCacheStore {
  DriftApiCacheStore(this._db);

  final AppDatabase _db;

  @override
  Future<void> write(
    String key,
    Map<String, dynamic> payload,
    DateTime fetchedAt,
  ) async {
    // The envelope is stored verbatim — reading back re-parses through the
    // model factories, so no toJson is ever needed on the models.
    await _db.saveRemoteCache(
      key: key,
      payload: jsonEncode(payload),
      fetchedAt: fetchedAt,
    );
  }

  @override
  Future<({Map<String, dynamic> payload, DateTime fetchedAt})?> read(
    String key,
  ) async {
    final row = await _db.remoteCache(key);
    if (row == null) return null;
    final parsed = jsonDecode(row.payload);
    return (
      payload: parsed is Map<String, dynamic> ? parsed : <String, dynamic>{},
      fetchedAt: row.fetchedAt,
    );
  }
}

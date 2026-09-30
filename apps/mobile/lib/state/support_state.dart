/// W4d member-support remote state — live support threads + the usrah
/// join request (the two W4d member surfaces). Providers follow the
/// remote_state.dart shape: null while a guest (the UI shows the sign-in
/// gate), ApiException swallowed into null/empty so an offline phone shows
/// the empty state, never a crash.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/domain.dart'
    show SupportMessage, SupportThread, UsrahJoinRequest;
import 'providers.dart';

/// Own support threads (GET /api/support — newest activity first).
/// Empty while a guest.
final supportThreadsProvider = FutureProvider.autoDispose<List<SupportThread>>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  if (!auth.signedIn) return const [];
  try {
    return await ref.watch(apiProvider).supportThreads();
  } on ApiException {
    return const [];
  }
});

/// One thread + its messages (GET /api/support/:id — asc).
final supportThreadProvider = FutureProvider.autoDispose
    .family<(SupportThread, List<SupportMessage>), String>((ref, id) async {
      return ref.watch(apiProvider).supportThread(id);
    });

/// Own current/last usrah join request (GET /api/usrah/join-request —
/// null while a guest or when none was ever sent).
final joinRequestProvider = FutureProvider.autoDispose<UsrahJoinRequest?>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  if (!auth.signedIn) return null;
  try {
    return await ref.watch(apiProvider).joinRequestStatus();
  } on ApiException {
    return null;
  }
});

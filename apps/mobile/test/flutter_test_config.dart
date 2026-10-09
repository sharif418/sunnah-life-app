// Runs before every test file. The platform keystore (flutter_secure_storage)
// has no implementation in the test engine — its calls never complete under
// the fake-async zone — so the session store keeps tokens in the mocked
// SharedPreferences instead.
import 'dart:async';

import 'package:sunnah_life/services/session_store.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SessionStore.forcePrefsForTesting = true;
  await testMain();
}

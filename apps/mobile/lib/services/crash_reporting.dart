/// Crash reports from release builds (Firebase Crashlytics) — so a crash on
/// a tester's or member's phone reaches us without anyone having to describe
/// it. Attached by PushService right after Firebase.initializeApp succeeds;
/// without Firebase (tests, a phone without Play services) nothing changes.
///
/// What goes: the error, its stack trace, the app version and the device
/// model/OS that Crashlytics adds. No user id, name or phone is attached.
/// Debug builds never send (collection is off outside release).
library;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashReporting {
  CrashReporting._();
  static bool _attached = false;

  /// Route uncaught Flutter-framework and platform/async errors to
  /// Crashlytics. Safe to call more than once; never throws.
  static Future<void> attach() async {
    if (_attached) return;
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode);
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        previous?.call(details);
        crashlytics.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };
      _attached = true;
    } catch (e) {
      debugPrint('[crash] Crashlytics unavailable: $e');
    }
  }
}

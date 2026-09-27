// FirebaseOptions — PLACEHOLDER (Task B2).
//
// ⚠️ This file mirrors the exact structure `flutterfire configure`
//    generates, but every value is a FAKE placeholder that pairs with
//    android/app/google-services.example.json. With these values the app
//    builds everywhere (CI has no real google-services.json) and
//    Firebase.initializeApp succeeds structurally, but FCM getToken fails
//    gracefully — PushService catches it and runs local-notification-only.
//
// PRODUCTION: run `flutterfire configure` (see docs/RELEASE.md §Firebase)
// to overwrite this file with the real project's options, then place the
// real google-services.json / GoogleService-Info.plist (docs/IOS_BUILD.md).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions — web is not a Sunnah Life target.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions — macOS is not a Sunnah Life target.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions — unsupported platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-PLACEHOLDER-REPLACE-VIA-flutterfire-configure-000000',
    appId: '1:000000000000:android:placeholder0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'sunnah-life-placeholder',
    storageBucket: 'sunnah-life-placeholder.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA-PLACEHOLDER-REPLACE-VIA-flutterfire-configure-000000',
    appId: '1:000000000000:ios:placeholder00000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'sunnah-life-placeholder',
    storageBucket: 'sunnah-life-placeholder.appspot.com',
    iosBundleId: 'bd.asunnah.sunnahLife',
  );
}

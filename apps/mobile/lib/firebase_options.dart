// FirebaseOptions — Firebase project `sunnah-life-ad79e`.
//
// ANDROID: real values (from the project's google-services.json). These are
// client identifiers, not secrets — Firebase ships them inside every APK;
// access is controlled by the API-key restrictions in Google Cloud and by
// server-side credentials (the FCM service account lives only on the API).
//
// iOS: still a PLACEHOLDER until the Mac step (docs/IOS_BUILD.md) registers
// the iOS app and `flutterfire configure` rewrites that block.
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
    apiKey: 'AIzaSyC4c7veUxyqrPn2unyTmjbTsG_KIeZgqAo',
    appId: '1:56502386040:android:96fd239a5de12e30565c8d',
    messagingSenderId: '56502386040',
    projectId: 'sunnah-life-ad79e',
    storageBucket: 'sunnah-life-ad79e.firebasestorage.app',
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

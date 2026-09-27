/// Social sign-in adapters (Task B5) — Google (google_sign_in 7.x) and Apple
/// (sign_in_with_apple 8.x), each returning the provider id_token for
/// POST /api/auth/social. The plugins' platform-channel calls hang forever
/// under the `flutter test` binding (same class of issue B2 hit with
/// firebase_core), so everything here is guarded and inert in tests.
///
/// Configuration (build time, via --dart-define — these are PUBLIC client
/// ids, not secrets; the server holds the authoritative audience list):
///   GOOGLE_SERVER_CLIENT_ID — the OAuth *web* client id of the same Google
///     Cloud project the API verifies (GOOGLE_CLIENT_ID env). Android's id
///     token audience is exactly this value; on iOS GIDSignIn also uses it
///     as serverClientID.
///   GOOGLE_IOS_CLIENT_ID — optional iOS client id (falls back to
///     GoogleService-Info.plist when omitted).
///
/// Apple: iOS-only by design — the native ASAuthorization flow needs the
/// Sign in with Apple entitlement (see docs/IOS_BUILD.md). On Android the
/// button stays hidden (the web-flow path needs a redirect on our domain).
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../api/api_client.dart';

/// `flutter test` sets FLUTTER_TEST=true — plugin channels never resolve
/// there, so the social adapters report themselves unavailable (B2 pattern).
bool get _runningInFlutterTest =>
    !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';

/// The provider slug the API expects (POST /api/auth/social).
enum SocialProvider { google, apple }

/// The user closed the provider sheet — not an error, just stop the flow.
class SocialSignInCanceled implements Exception {
  @override
  String toString() => 'social sign-in canceled';
}

class SocialSignInService {
  SocialSignInService._();
  static final SocialSignInService instance = SocialSignInService._();

  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const String _iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  bool _googleInitialized = false;

  /// Google button: needs the server client id (the id_token audience) and a
  /// non-test runtime. Android + iOS.
  bool get googleAvailable =>
      !_runningInFlutterTest && _serverClientId.isNotEmpty;

  /// Apple button: iOS only (entitlement-gated native flow), never in tests.
  bool get appleAvailable =>
      !_runningInFlutterTest &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Runs the Google sign-in flow and returns the verified-audience id_token.
  /// Throws [SocialSignInCanceled] when the user backs out.
  Future<String> googleIdToken() async {
    if (!googleAvailable) {
      throw ApiException(400, 'Google সাইন-ইন চালু নেই');
    }
    try {
      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId: _serverClientId,
          clientId: _iosClientId.isEmpty ? null : _iosClientId,
        );
        _googleInitialized = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw ApiException(400, 'Google সাইন-ইন ব্যর্থ হয়েছে — আবার চেষ্টা করুন');
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw SocialSignInCanceled();
      }
      throw ApiException(400, 'Google সাইন-ইন ব্যর্থ হয়েছে — আবার চেষ্টা করুন');
    }
  }

  /// Runs the native Apple sign-in sheet and returns the id_token (aud = the
  /// app bundle id — the API accepts it via APPLE_IOS_BUNDLE_ID).
  Future<String> appleIdToken() async {
    if (!appleAvailable) {
      throw ApiException(400, 'Apple সাইন-ইন চালু নেই');
    }
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw ApiException(400, 'Apple সাইন-ইন ব্যর্থ হয়েছে — আবার চেষ্টা করুন');
      }
      return idToken;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw SocialSignInCanceled();
      }
      throw ApiException(400, 'Apple সাইন-ইন ব্যর্থ হয়েছে — আবার চেষ্টা করুন');
    } on SignInWithAppleNotSupportedException {
      throw ApiException(400, 'এই ডিভাইসে Apple সাইন-ইন নেই');
    }
  }
}

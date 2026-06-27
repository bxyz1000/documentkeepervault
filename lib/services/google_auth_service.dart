import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/drive.appdata',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  static bool get isSignedIn => currentUser != null;

  /// Restore previous login
  static Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e, s) {
      debugPrint("===== Silent Sign-In Error =====");
      debugPrint(e.toString());
      debugPrint(s.toString());
      return null;
    }
  }

  /// Interactive Google Sign-In
  static Future<GoogleSignInAccount?> signIn() async {
  debugPrint("STEP 1");

  final account = await _googleSignIn.signIn();

  debugPrint("STEP 2");

  if (account == null) {
    debugPrint("User cancelled");
    return null;
  }

  debugPrint("STEP 3 ${account.email}");

  await _storage.write(
    key: "google_signed_in",
    value: "true",
  );

  debugPrint("STEP 4");

  return account;
}
  static Future<Map<String, String>> getAuthHeaders() async {
    final account = currentUser;
    if (account == null) {
      throw Exception("No Google account signed in.");
    }

    final auth = await account.authentication;

    return {
      "Authorization": "Bearer ${auth.accessToken}",
      "Content-Type": "application/json",
    };
  }

  static Future<String?> getAccessToken() async {
    final account = currentUser;
    if (account == null) return null;

    final auth = await account.authentication;
    return auth.accessToken;
  }

  /// Disconnect Google account completely
  static Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}

    await _storage.delete(key: "google_signed_in");
  }

  /// Only sign out
  static Future<void> signOutOnly() async {
    await _googleSignIn.signOut();
  }
}
import 'package:flutter/material.dart';
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

  static final _storage = const FlutterSecureStorage();

  static GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
  static bool get isSignedIn => _googleSignIn.currentUser != null;

  /// Silently restore previous session (call on app start)
  static Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (_) {
      return null;
    }
  }

  /// Interactive sign-in
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        await _storage.write(key: 'google_signed_in', value: 'true');
      }
      return account;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return null;
    }
  }

  /// Get fresh auth headers for API calls
  static Future<Map<String, String>> getAuthHeaders() async {
    final account = _googleSignIn.currentUser;
    if (account == null) throw Exception('Not signed in');
    final auth = await account.authentication;
    return {
      'Authorization': 'Bearer ${auth.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  /// Get access token
  static Future<String?> getAccessToken() async {
    final account = _googleSignIn.currentUser;
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.accessToken;
  }

  /// Revoke and sign out completely
  static Future<void> signOut() async {
    await _googleSignIn.disconnect();
    await _storage.delete(key: 'google_signed_in');
  }

  /// Just sign out (keep account linkage)
  static Future<void> signOutOnly() async {
    await _googleSignIn.signOut();
  }
}

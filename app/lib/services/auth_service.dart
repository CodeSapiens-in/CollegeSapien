import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_models.dart';
import '../providers/app_state_notifier.dart';
import 'api_service.dart';
// import 'app_capability_service.dart'; // mod: moved to web admin panel

// Web OAuth client ID from google-services.json (client_type: 3).
// Required for Google Sign-In on Android to return an idToken.
const _googleWebClientId =
    '186941997391-uhmgsim9eq2pfttpk9ihk6so83q5na0l.apps.googleusercontent.com';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  User? get currentUser => _auth.currentUser;

  Future<AuthSyncResult> syncProfile() async {
    final timezoneOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    final json = await ApiService.instance
            .post('/auth/sync?timezoneOffsetMinutes=$timezoneOffsetMinutes')
        as Map<String, dynamic>;
    return AuthSyncResult.fromJson(json);
  }

  Future<AuthSyncResult> signInWithEmailPassword(
      String email, String password) async {
    await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    return syncProfile();
  }

  Future<void> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name.trim());
    await credential.user?.getIdToken(true);
    await ApiService.instance.post('/auth/signup', {'name': name.trim()});
    await credential.user?.sendEmailVerification();
  }

  Future<AuthSyncResult> signInWithGoogle() async {
    if (kIsWeb) {
      try {
        await _auth.signInWithPopup(GoogleAuthProvider());
        await _auth.currentUser?.getIdToken(true);
        return syncProfile();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          throw ApiException(499, 'Google sign-in was cancelled');
        }
        throw ApiException(
          500,
          'Google sign-in failed: ${e.message ?? e.code}',
        );
      } catch (e) {
        throw ApiException(500, 'Google sign-in failed: ${e.toString()}');
      }
    }

    final GoogleSignInAccount googleUser;
    try {
      await _googleSignIn.initialize(
        serverClientId: _googleWebClientId,
      );
      googleUser = await _googleSignIn.authenticate();
    } catch (e) {
      throw ApiException(500, 'Google sign-in failed: ${e.toString()}');
    }

    final googleAuth = googleUser.authentication;

    if (googleAuth.idToken == null) {
      throw ApiException(500,
          'Google sign-in failed: could not obtain credentials. Ensure your SHA-1 fingerprint is registered in Firebase Console.');
    }

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    await _auth.signInWithCredential(credential);
    return syncProfile();
  }

  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<void> deleteAccount() async {
    await ApiService.instance.delete('/auth/me');
    await _auth.signOut();
    AppStateNotifier.instance.invalidateAll();
  }

  Future<UserProfile> onboard({
    required String name,
    required String collegeId,
    required String department,
    required int semester,
  }) async {
    final json = await ApiService.instance.post('/auth/onboard', {
      'name': name.trim(),
      'collegeId': collegeId,
      'department': department,
      'semester': semester,
    }) as Map<String, dynamic>;

    return UserProfile.fromJson(json['user'] as Map<String, dynamic>);
  }

  static const _pendingCollegeKey = 'pending_onboard_collegeId';
  static const _pendingDeptKey = 'pending_onboard_department';
  static const _pendingSemKey = 'pending_onboard_semester';

  /// Caches onboarding details collected at signup time — /auth/onboard
  /// rejects unverified accounts, so this bridges the gap until the user
  /// clicks the verification link and logs back in.
  static Future<void> savePendingOnboarding({
    required String collegeId,
    required String department,
    required int semester,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingCollegeKey, collegeId);
    await prefs.setString(_pendingDeptKey, department);
    await prefs.setInt(_pendingSemKey, semester);
  }

  /// Returns and clears the cached onboarding details, if any.
  static Future<({String collegeId, String department, int semester})?>
      consumePendingOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final collegeId = prefs.getString(_pendingCollegeKey);
    final department = prefs.getString(_pendingDeptKey);
    final semester = prefs.getInt(_pendingSemKey);
    if (collegeId == null || department == null || semester == null) {
      return null;
    }
    await prefs.remove(_pendingCollegeKey);
    await prefs.remove(_pendingDeptKey);
    await prefs.remove(_pendingSemKey);
    return (collegeId: collegeId, department: department, semester: semester);
  }

  /// Maps a caught auth error to a message safe to show the user.
  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'too-many-requests':
          return 'Too many attempts. Please wait a few minutes and try again.';
        case 'email-already-in-use':
          return 'An account with this email already exists.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'Password is too weak. Please choose a stronger one.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        default:
          return e.message ?? 'Something went wrong. Please try again.';
      }
    }
    if (e is ApiException) return e.message;
    return 'Something went wrong. Please try again.';
  }

  Future<void> signOut() async {
    // AppCapabilityService.instance.invalidate(); // mod: moved to web admin panel
    try {
      await ApiService.instance
          .post('/auth/logout')
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Local sign-out should still complete if the API is unreachable.
    }
    try {
      await _googleSignIn.signOut().timeout(const Duration(seconds: 2));
    } catch (_) {}
    await _auth.signOut();
    // Must clear the cached profile/attendance/timetable/etc. here — a
    // second account signing in on the same device would otherwise inherit
    // this account's stale cached data until each field's TTL expires.
    AppStateNotifier.instance.invalidateAll();
  }
}

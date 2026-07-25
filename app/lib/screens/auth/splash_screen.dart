import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../providers/app_state_notifier.dart';
import '../../providers/session_action.dart';
import '../home/main_navigation.dart';
import '../onboarding/onboarding_screen.dart';
import 'college_selection_screen.dart';

/// Splash Screen - App launch screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Minimum time the branded splash stays visible, purely cosmetic — real
  // work (cache hydration) runs concurrently with this, not after it.
  static const _minDwell = Duration(milliseconds: 700);
  Timer? _dwellTimer;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    // Start animation
    _controller.forward();

    _init();
  }

  Future<void> _init() async {
    final appState = AppStateNotifier.instance;
    await Future.wait([
      _dwell(),
      appState.loadFromLocalCache(),
    ]);
    if (!mounted) return;
    await _navigateToNext(appState);
  }

  // A cancelable stand-in for Future.delayed — dispose() cancels the
  // underlying Timer so no pending timer outlives this widget.
  Future<void> _dwell() {
    final completer = Completer<void>();
    _dwellTimer = Timer(_minDwell, () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> _navigateToNext(AppStateNotifier appState) async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      _replaceWith(const CollegeSelectionScreen());
      return;
    }

    final cachedProfile = appState.userProfileStale;
    final hasUsableSession = cachedProfile != null &&
        cachedProfile.collegeId != null &&
        cachedProfile.department != null;

    if (hasUsableSession) {
      // We already know who this user is — show Home immediately and
      // reconcile with the backend in the background. If reconciliation
      // finds the session is no longer valid, SessionGuard will redirect.
      _replaceWith(const MainNavigation());
      unawaited(_reconcile(user, appState, blocking: false));
      return;
    }

    // No usable local cache (first launch, cleared data, or logged out
    // elsewhere) — we have to wait for the network before we know where
    // to send the user.
    await _reconcile(user, appState, blocking: true);
  }

  Future<void> _reconcile(
    User user,
    AppStateNotifier appState, {
    required bool blocking,
  }) async {
    try {
      // Independent Firebase SDK calls — neither depends on the other's
      // result, so run them concurrently instead of sequentially.
      await Future.wait([
        user.reload(),
        user.getIdToken(true),
      ]);
      final result = await AuthService.instance.syncProfile();
      _applySyncResult(appState, result);

      if (!blocking) {
        if (!result.emailVerified) {
          appState.requestSessionAction(SessionAction.requireLogin);
        } else if (result.onboardingRequired) {
          appState.requestSessionAction(SessionAction.requireOnboarding);
        }
        return;
      }

      if (!mounted) return;
      if (!result.emailVerified) {
        _replaceWith(const CollegeSelectionScreen());
      } else if (result.onboardingRequired) {
        _replaceWith(const OnboardingScreen());
      } else {
        _replaceWith(const MainNavigation());
      }
    } on FirebaseAuthException catch (e) {
      // e.g. user-not-found / user-disabled — the account itself is no
      // longer valid, not merely offline. Must not fall back to stale
      // cached Home.
      debugPrint('SplashScreen auth error: $e');
      _routeToLogin(blocking: blocking, appState: appState);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        debugPrint('SplashScreen auth rejected by server: $e');
        _routeToLogin(blocking: blocking, appState: appState);
      } else {
        _handleOfflineFallback(appState, blocking: blocking);
      }
    } catch (e) {
      debugPrint('SplashScreen reconciliation error: $e');
      _handleOfflineFallback(appState, blocking: blocking);
    }
  }

  void _applySyncResult(AppStateNotifier appState, AuthSyncResult result) {
    if (result.user != null) {
      appState.setUserProfile(result.user);
    }
    // Persist the rest of the sync payload too, so the home screen finds
    // fresh cached data on mount instead of hitting /auth/sync again.
    if (result.attendanceSummary != null) {
      appState.setAttendanceSummary(result.attendanceSummary!);
    }
    if (result.timetableSubjects != null) {
      appState.setTimetableSubjects(result.timetableSubjects!);
    }
    final savedSubjects = result.savedSubjects?.subjects;
    if (savedSubjects != null && savedSubjects.isNotEmpty) {
      appState.setSavedSubjects(savedSubjects);
    }
  }

  void _routeToLogin({required bool blocking, required AppStateNotifier appState}) {
    if (blocking) {
      if (mounted) _replaceWith(const CollegeSelectionScreen());
    } else {
      appState.requestSessionAction(SessionAction.requireLogin);
    }
  }

  void _handleOfflineFallback(AppStateNotifier appState, {required bool blocking}) {
    // Background reconciliation failing offline is a no-op — Home is
    // already showing from cache, nothing to change.
    if (!blocking) return;
    if (!mounted) return;
    final profile = appState.userProfileStale;
    if (profile != null &&
        profile.collegeId != null &&
        profile.department != null) {
      _replaceWith(const MainNavigation());
    } else {
      _replaceWith(const CollegeSelectionScreen());
    }
  }

  void _replaceWith(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEEEC3),
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo/Icon
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD966),
                      border: Border.all(color: Colors.black, width: 3),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          offset: Offset(8, 8),
                          color: Colors.black,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.school,
                        size: 80,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // App Name
                  const Text(
                    'CollegeSapien',
                    style: TextStyle(
                      fontFamily: 'Lexend Mega',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2.0,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tagline
                  Text(
                    'Your College Companion',
                    style: TextStyle(
                      fontFamily: 'Public Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Open Source • For Students, By Students',
                    style: TextStyle(
                      fontFamily: 'Public Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 52),

                  // Loading indicator
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

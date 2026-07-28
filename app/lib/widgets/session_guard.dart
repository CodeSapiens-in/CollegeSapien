import 'package:flutter/material.dart';

import '../providers/app_state_notifier.dart';
import '../providers/session_action.dart';
import '../screens/auth/college_selection_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../services/app_navigation.dart';

/// Wraps the app and listens for [AppStateNotifier.pendingSessionAction], so
/// background work (e.g. splash screen's post-navigation reconciliation
/// sync) can redirect the user to Login/Onboarding no matter what screen is
/// currently on top — one reusable redirect path instead of every call site
/// needing its own navigation logic.
class SessionGuard extends StatefulWidget {
  const SessionGuard({required this.child, super.key});

  final Widget child;

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  @override
  void initState() {
    super.initState();
    AppStateNotifier.instance.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    AppStateNotifier.instance.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    final action = AppStateNotifier.instance.pendingSessionAction;
    if (action == SessionAction.none) return;
    AppStateNotifier.instance.clearSessionAction();

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    final target = action == SessionAction.requireOnboarding
        ? const OnboardingScreen()
        : const CollegeSelectionScreen();
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => target),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

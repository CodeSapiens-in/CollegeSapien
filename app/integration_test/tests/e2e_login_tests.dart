import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codesapiens/screens/auth/auth_screen.dart';
import 'package:codesapiens/screens/home/home_screen.dart';
import 'package:codesapiens/screens/home/main_navigation.dart';
import 'package:codesapiens/screens/attendance_screen.dart';
import 'package:codesapiens/screens/timetable_list_screen.dart';
import 'package:codesapiens/screens/resources/resources_hub_screen.dart';
import 'package:codesapiens/screens/profile/profile_screen.dart';
import 'package:codesapiens/services/auth_service.dart';

import '../helpers/test_credentials.dart';

/// Real end-to-end test: signs in against the live Firebase project with
/// the credentials in `app/.env`, then walks every main-nav screen. Unlike
/// the rest of the suite this hits real Firebase Auth and the real
/// backend — no mocks.
void runE2ELoginTests() {
  group('End-to-End Login (real backend)', () {
    setUpAll(() async {
      await AuthService.instance.signOut();
    });

    tearDown(() async {
      await AuthService.instance.signOut();
    });

    testWidgets('Sign in with test account reaches every main screen',
        (WidgetTester tester) async {
      TestCredentials.ensureLoaded();

      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      await tester.pumpAndSettle();

      // AuthScreen opens on Sign Up. The E2E path intentionally uses the
      // dedicated test account from app/.env and never creates a user.
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), TestCredentials.email);
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'),
          TestCredentials.password);

      await tester.tap(find.text('Login'));

      // Real network round trip (Firebase Auth + backend /auth/sync).
      await tester.pumpAndSettle(const Duration(seconds: 15));

      expect(find.byType(MainNavigation), findsOneWidget);
      expect(AuthService.instance.currentUser, isNotNull);
      expect(AuthService.instance.currentUser!.email,
          TestCredentials.email.trim());
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(AttendanceScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(TimetableListScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.library_books_outlined));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(ResourcesHubScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(HomeScreen), findsOneWidget);

      // No rail at default test width — Profile is reached via HomeScreen's
      // profile button (Icons.person), not the bottom nav.
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });
}

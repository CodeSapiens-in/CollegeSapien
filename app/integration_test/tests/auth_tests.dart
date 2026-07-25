import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codesapiens/models/api_models.dart';
import 'package:codesapiens/screens/auth/splash_screen.dart';
import 'package:codesapiens/screens/auth/college_selection_screen.dart';
import 'package:codesapiens/screens/auth/auth_screen.dart';
import 'package:codesapiens/screens/onboarding/onboarding_screen.dart';
import 'package:codesapiens/screens/onboarding/user_details_screen.dart';

final _testCollege =
    College(id: 'col_test', name: 'Test Institute of Technology', code: 'TIT');

void runAuthTests() {
  group('Authentication & Onboarding Flow', () {
    testWidgets('Verify Splash Screen & Navigation to College Selection',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pumpAndSettle();

      // Verify splash screen contents
      expect(find.text('CollegeSapien'), findsOneWidget);
      expect(find.text('Your College Companion'), findsOneWidget);
      expect(find.byIcon(Icons.school), findsOneWidget);

      // Wait for splash navigation timer to trigger
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Should transition to CollegeSelectionScreen (no signed-in user)
      expect(find.byType(CollegeSelectionScreen), findsOneWidget);
      expect(find.text('Find Your College'), findsOneWidget);
    });

    testWidgets('Verify Sign In Tab Validation', (WidgetTester tester) async {
      await tester.pumpWidget(
          MaterialApp(home: AuthScreen(college: _testCollege)));
      await tester.pumpAndSettle();

      // Defaults to Sign Up — switch to Sign In
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);

      // Tap Login without credentials to trigger validation
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);

      // Enter invalid email
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'invalid-email');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('Verify Sign Up Tab Is the Default', (WidgetTester tester) async {
      await tester.pumpWidget(
          MaterialApp(home: AuthScreen(college: _testCollege)));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Full Name'), findsOneWidget);
      expect(find.text(_testCollege.name), findsOneWidget);
    });

    testWidgets('Verify Onboarding Carousel Swipe Flow', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pumpAndSettle();

      // Verify first onboarding slide
      expect(find.text('Track Attendance'), findsOneWidget);

      // Swipe left to go to next page
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Verify second onboarding slide
      expect(find.text('CGPA Calculator'), findsOneWidget);

      // Tap "Skip" to skip onboarding
      final skipButton = find.text('Skip');
      expect(skipButton, findsOneWidget);
      await tester.tap(skipButton);
      await tester.pumpAndSettle();
    });

    testWidgets('Verify User Details Form Inputs', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: UserDetailsScreen()));
      await tester.pumpAndSettle();

      // Verify form fields
      expect(find.widgetWithText(TextFormField, 'Full Name'), findsOneWidget);
      expect(find.text('College'), findsOneWidget);
      expect(find.text('Department'), findsOneWidget);
      expect(find.text('Current Semester'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Full Name'), 'John Doe');
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsOneWidget);
    });
  });
}

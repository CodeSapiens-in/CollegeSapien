import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:codesapiens/firebase_options.dart';

import 'tests/auth_tests.dart';
import 'tests/navigation_tests.dart';
import 'tests/attendance_tests.dart';
import 'tests/timetable_tests.dart';
import 'tests/resources_tests.dart';
import 'tests/utility_tests.dart';
import 'tests/profile_tests.dart';
import 'tests/e2e_login_tests.dart';

void main() {
  // Initialize the integration test binding
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Every screen under test (starting with SplashScreen) touches
  // FirebaseAuth.instance, which throws if no Firebase app exists yet.
  setUpAll(() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  });

  group('CollegeSapien Integration Test Suite', () {
    runAuthTests();
    runNavigationTests();
    runAttendanceTests();
    runTimetableTests();
    runResourcesTests();
    runUtilityTests();
    runProfileTests();
    runE2ELoginTests();
  });
}

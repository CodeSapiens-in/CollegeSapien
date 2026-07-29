import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codesapiens/screens/cgpa/cgpa_calculator_screen.dart';
import 'package:codesapiens/screens/ai_features/resume_roast_screen.dart';
import 'package:codesapiens/screens/pomodoro/pomodoro_timer_screen.dart';

void runUtilityTests() {
  group('Student Utilities Flow', () {
    testWidgets('Verify CGPA Calculator Manual Input & AI Trigger', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: CgpaCalculatorScreen()));
      await tester.pumpAndSettle();

      // Verify title
      expect(find.text('CGPA Calculator'), findsOneWidget);

      // Verify the AI Scan button exists
      expect(find.text('Scan Grade Sheet with AI'), findsOneWidget);

      // Verify manual entry button exists (e.g., Add Semester)
      final addSemesterButton = find.text('Add Semester');
      if (addSemesterButton.evaluate().isNotEmpty) {
        await tester.tap(addSemesterButton);
        await tester.pumpAndSettle();

        // Verify add semester dialog fields
        expect(find.widgetWithText(TextFormField, 'GPA'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, 'Credits'), findsOneWidget);
      }
    });

    testWidgets('Verify Resume Roast File Upload UI', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ResumeRoastScreen()));
      await tester.pumpAndSettle();

      // Verify screen title and description
      expect(find.text('Resume Roast'), findsOneWidget);
      expect(find.text('Upload your resume and let Gemini roast it!'), findsOneWidget);

      // Verify Upload button exists
      expect(find.text('Select Resume (PDF/DOCX)'), findsOneWidget);

      // Verify Roast button exists but is disabled or waiting
      expect(find.text('Roast Me!'), findsOneWidget);
    });

    testWidgets('Verify Pomodoro Timer Modes & Task List', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PomodoroTimerScreen(timerId: 'test-timer')),
      );
      await tester.pumpAndSettle();

      // Verify timer title
      expect(find.text('Pomodoro Timer'), findsOneWidget);

      // Verify default mode is Pomodoro and time is 25:00
      expect(find.text('25:00'), findsOneWidget);

      // Verify Pomodoro Mode buttons exist
      expect(find.text('Pomodoro'), findsOneWidget);
      expect(find.text('Short Break'), findsOneWidget);
      expect(find.text('Long Break'), findsOneWidget);

      // Switch to Short Break mode
      await tester.tap(find.text('Short Break'));
      await tester.pumpAndSettle();

      // Verify time changes to 05:00
      expect(find.text('05:00'), findsOneWidget);

      // Test task checklist: Add a task
      final taskField = find.widgetWithText(TextField, 'Add a task...');
      expect(taskField, findsOneWidget);

      await tester.enterText(taskField, 'Complete Integration Tests');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify task was added
      expect(find.text('Complete Integration Tests'), findsOneWidget);
    });
  });
}

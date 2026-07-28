import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codesapiens/screens/resources/resources_hub_screen.dart';
import 'package:codesapiens/screens/resources/syllabus_browser_screen.dart';
import 'package:codesapiens/screens/resources/notes_hub_screen.dart';
import 'package:codesapiens/screens/resources/qp_hub_screen.dart';

void runResourcesTests() {
  group('Academic Resources Flow', () {
    testWidgets('Verify Resources Hub Navigation Options', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ResourcesHubScreen()));
      await tester.pumpAndSettle();

      // Verify hub title
      expect(find.text('Resources Hub'), findsOneWidget);
      expect(find.text('Access syllabus, notes, and question papers'), findsOneWidget);

      // Verify the three main resource cards exist
      expect(find.text('Syllabus Browser'), findsOneWidget);
      expect(find.text('Notes Hub'), findsOneWidget);
      expect(find.text('Question Papers'), findsOneWidget);
    });

    testWidgets('Verify Syllabus Browser Search & Filter', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SyllabusBrowserScreen()));
      await tester.pumpAndSettle();

      // Verify browser title
      expect(find.text('Syllabus Browser'), findsOneWidget);

      // Verify search field exists
      expect(find.widgetWithText(TextField, 'Search syllabus...'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.widgetWithText(TextField, 'Search syllabus...'), 'Computer Science');
      await tester.pumpAndSettle();

      expect(find.text('Computer Science'), findsOneWidget);
    });

    testWidgets('Verify Notes Hub Gating & Upload Flow', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: NotesHubScreen()));
      await tester.pumpAndSettle();

      // Verify Notes Hub title
      expect(find.text('Notes Hub'), findsOneWidget);

      // Verify "Give-to-Get" locked state message is shown initially
      expect(find.text('Get 1 upload approved to unlock Notes and Question Papers.'), findsOneWidget);

      // Verify upload action button exists (e.g. Floating Action Button or upload button)
      final uploadFAB = find.byType(FloatingActionButton);
      if (uploadFAB.evaluate().isNotEmpty) {
        await tester.tap(uploadFAB);
        await tester.pumpAndSettle();

        // Verify Upload dialog is shown
        expect(find.text('Upload Note'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, 'Title'), findsOneWidget);
        expect(find.text('Select Subject'), findsOneWidget);
      }
    });

    testWidgets('Verify QP Hub Content Gating', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: QpHubScreen()));
      await tester.pumpAndSettle();

      // Verify QP Hub title
      expect(find.text('QP Hub'), findsOneWidget);

      // Verify locked state message
      expect(find.text('Get 1 upload approved to unlock Notes and Question Papers.'), findsOneWidget);
    });
  });
}

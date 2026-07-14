import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../widgets/responsive_layout.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      q: 'How do I add a timetable?',
      a: 'Tap the + button on the Timetable screen and enter your subjects manually.',
    ),
    (
      q: 'How is attendance calculated?',
      a: 'Attendance percentage is calculated per subject based on the classes you mark as present divided by the total classes held.',
    ),
    (
      q: 'How do I mark attendance?',
      a: 'Go to the Attendance screen and tap the + button. You\'ll see today\'s classes and can mark each one as present or absent.',
    ),
    (
      q: 'How does Resume Roast work?',
      a: 'Upload your resume as a PDF or DOC file on the AI screen. Our AI will give you honest, college-friendly feedback on it.',
    ),
    (
      q: 'How is CGPA calculated?',
      a: 'CGPA is a weighted average of your semester GPAs. Add each semester\'s GPA and credit count in the CGPA Calculator and it will compute the weighted average automatically.',
    ),
    (
      q: 'Why can\'t I download notes?',
      a: 'You need to upload at least one document before downloading. This keeps the community fair — everyone contributes.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Expanded(
          child: Text(
            'Help & Support',
            style: TextStyle(
              fontFamily: 'Lexend Mega',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              letterSpacing: 0,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      body: SafeArea(
        child: MaxWidthContent(
          maxWidth: 600,
          child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration:
                  AppTheme.cardDecoration(color: AppColors.primaryYellow),
              child: const Row(
                children: [
                  Icon(Icons.help_outline, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Frequently Asked Questions',
                      style: TextStyle(
                        fontFamily: 'Lexend Mega',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ..._faqs.map(
              (faq) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration(color: Colors.white),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        faq.q,
                        style: const TextStyle(
                          fontFamily: 'Public Sans',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        faq.a,
                        style: TextStyle(
                          fontFamily: 'Public Sans',
                          fontSize: 14,
                          color: Colors.black.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

import 'package:codesapiens/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/app_theme.dart';
import '../../widgets/responsive_layout.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
            'About',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: MaxWidthContent(
            maxWidth: 600,
            child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                width: 100,
                height: 100,
                decoration: AppTheme.cardDecoration(
                  color: AppColors.primaryYellow,
                  shadowOffset: const Offset(4, 4),
                ),
                child: const Icon(Icons.school, size: 50, color: Colors.black),
              ),
              const SizedBox(height: 24),
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  fontFamily: 'Lexend Mega',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontFamily: 'Public Sans',
                  fontSize: 14,
                  color: Colors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'An open source university companion — attendance tracking, timetable management, and AI-powered tools.\nFor students, by students.',
                style: TextStyle(
                  fontFamily: 'Public Sans',
                  fontSize: 15,
                  color: Colors.black,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/CodeSapiens-in/CollegeSapien'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: AppTheme.cardDecoration(color: Colors.white),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.string(
                        '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z" fill="currentColor"/></svg>',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                            Colors.black, BlendMode.srcIn),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'View on GitHub',
                        style: TextStyle(
                          fontFamily: 'Public Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildInfoCard(
                'Features',
                AppColors.accentBlue,
                [
                  'Attendance tracking per subject',
                  'CGPA calculator with credits',
                  'Notes & Question Paper hub',
                  'Pomodoro timer with tasks',
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoCard(
                'Built with',
                AppColors.accentGreen,
                [
                  'Flutter (iOS & Android)',
                  'Firebase Cloud Functions',
                  'Google Gemini Vision API',
                  'Firebase Firestore & Storage',
                ],
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, Color color, List<String> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Lexend Mega',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.black),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

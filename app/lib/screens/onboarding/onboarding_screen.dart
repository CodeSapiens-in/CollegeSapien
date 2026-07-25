import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/responsive_layout.dart';
import 'user_details_screen.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  /// Screen to land on once the intro carousel finishes or is skipped.
  /// Defaults to the standalone college/department/semester form for
  /// callers (e.g. SessionGuard) that don't already have that data.
  final Widget nextScreen;

  const OnboardingScreen({super.key, this.nextScreen = const UserDetailsScreen()});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.calendar_today,
      title: 'Track Attendance',
      description:
          'Never miss a class! Track your attendance and get Tanglish notifications when it drops below 75%.',
      color: AppColors.accentGreen,
    ),
    OnboardingPage(
      icon: Icons.calculate,
      title: 'CGPA Calculator',
      description:
          'Upload your grade sheet and let AI calculate your CGPA automatically with fun memes!',
      color: AppColors.accentBlue,
    ),
    OnboardingPage(
      icon: Icons.library_books,
      title: 'Resources Hub',
      description:
          'Access syllabus, notes, and question papers. Upload to download!',
      color: AppColors.accentPurple,
    ),
    OnboardingPage(
      icon: Icons.timer,
      title: 'Pomodoro Timer',
      description:
          'Stay productive with built-in Pomodoro timer for focused study sessions.',
      color: AppColors.primaryYellow,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => widget.nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: MaxWidthContent(
          maxWidth: 480,
          child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontFamily: 'Public Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Page Indicator
            SmoothPageIndicator(
              controller: _pageController,
              count: _pages.length,
              effect: ExpandingDotsEffect(
                dotHeight: 12,
                dotWidth: 12,
                activeDotColor: Colors.black,
                dotColor: Colors.black.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 40),

            // Next/Get Started Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: AppTheme.cardDecoration(
              color: page.color,
              shadowOffset: const Offset(8, 8),
            ),
            child: Icon(
              page.icon,
              size: 70,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 50),
          Text(
            page.title,
            style: const TextStyle(
              fontFamily: 'Lexend Mega',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            page.description,
            style: TextStyle(
              fontFamily: 'Public Sans',
              fontSize: 16,
              height: 1.5,
              color: Colors.black.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

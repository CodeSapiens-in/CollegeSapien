import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/api_models.dart';
import '../../services/college_service.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_theme.dart';
import '../../widgets/responsive_layout.dart';
import 'auth_screen.dart';

/// First screen a student sees — pick a college before signing up or
/// logging in. Selection carries forward into onboarding so it isn't
/// asked again.
class CollegeSelectionScreen extends StatefulWidget {
  const CollegeSelectionScreen({super.key});

  @override
  State<CollegeSelectionScreen> createState() =>
      _CollegeSelectionScreenState();
}

class _CollegeSelectionScreenState extends State<CollegeSelectionScreen> {
  final _collegeService = CollegeService();
  final _searchCtrl = TextEditingController();
  List<College> _colleges = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final colleges = await _collegeService.listColleges();
      colleges.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _colleges = colleges;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<College> get _filtered {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _colleges;
    return _colleges
        .where((c) => c.name.toLowerCase().contains(query))
        .toList();
  }

  void _selectCollege(College college) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthScreen(college: college),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveLayout(
          mobile: (_) => SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: w * 0.06, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerRight, child: _signInLink()),
                const SizedBox(height: 16),
                if (kIsWeb) ...[_playStoreBanner(), const SizedBox(height: 20)],
                _content(),
              ],
            ),
          ),
          desktop: (_) => _desktopLanding(),
        ),
      ),
    );
  }

  /// Split-screen marketing layout — this is the first page a browser visitor
  /// lands on, so the left half carries the pitch while the right half is
  /// the same search/list flow as mobile.
  Widget _desktopLanding() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            color: AppColors.primaryYellow,
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _brandMark(),
                const Spacer(),
                Container(
                  width: 140,
                  height: 140,
                  decoration: AppTheme.cardDecoration(
                    color: AppColors.background,
                    shadowOffset: const Offset(8, 8),
                  ),
                  child: const Center(
                    child: Icon(Icons.sentiment_satisfied_alt, size: 72),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Every syllabus.\nEvery college.\nOne place.',
                  style: TextStyle(
                    fontFamily: 'Lexend Mega',
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.0,
                    height: 1.15,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Find your college, get your subjects, and stay on top of '
                  'your semester — built by students, for students.',
                  style: TextStyle(
                    fontFamily: 'Public Sans',
                    fontSize: 15,
                    color: Colors.black.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(flex: 2),
                if (kIsWeb) _playStoreBanner(),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerRight, child: _signInLink()),
                const SizedBox(height: 24),
                Center(
                  child: SizedBox(width: 440, child: _content()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _brandMark() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text(
              'C',
              style: TextStyle(
                fontFamily: 'Lexend Mega',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          AppConstants.appName,
          style: const TextStyle(
            fontFamily: 'Lexend Mega',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _signInLink() {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Public Sans',
          fontSize: 14,
          color: Colors.black.withValues(alpha: 0.6),
        ),
        children: [
          const TextSpan(text: 'Already have an account?  '),
          TextSpan(
            text: 'Sign In',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _playStoreBanner() {
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse(
            'https://play.google.com/store/apps/details?id=com.collegesapien.app'),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryYellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.play_arrow, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'GET THE APP',
                    style: TextStyle(
                      fontFamily: 'Public Sans',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const Text(
                    'Download on Google Play',
                    style: TextStyle(
                      fontFamily: 'Public Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.primaryYellow),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: AppTheme.cardDecoration(
              color: AppColors.primaryYellow,
              shadowOffset: const Offset(6, 6),
            ),
            child: const Center(
              child: Icon(Icons.sentiment_satisfied_alt, size: 48),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'Find Your College',
            style: TextStyle(
              fontFamily: 'Lexend Mega',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.0,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Search below to get started',
            style: TextStyle(
              fontFamily: 'Public Sans',
              fontSize: 15,
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Search your college...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 20),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_filtered.isEmpty)
          _notFoundCard(_searchCtrl.text.trim())
        else
          ..._filtered.map(_collegeTile),
      ],
    );
  }

  // Deterministic pick so a college keeps the same avatar color across
  // rebuilds/scrolls instead of flickering on every relayout.
  Color _avatarColor(String collegeId) {
    final palette = [
      AppColors.primaryYellow,
      AppColors.lightBlue,
      AppColors.accentGreen,
      AppColors.tagPurple,
      AppColors.accentPink,
    ];
    return palette[collegeId.hashCode.abs() % palette.length];
  }

  Widget _collegeTile(College college) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => _selectCollege(college),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: AppTheme.cardDecoration(color: Colors.white),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: AppTheme.badgeDecoration(
                    color: _avatarColor(college.id)),
                child: Center(
                  child: Text(
                    college.name.isNotEmpty
                        ? college.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontFamily: 'Lexend Mega', fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      college.name,
                      style: const TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (college.code.isNotEmpty)
                      Text(
                        college.code,
                        style: TextStyle(
                          fontFamily: 'Public Sans',
                          fontSize: 13,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notFoundCard(String query) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(color: Colors.white),
      child: Column(
        children: [
          Text(
            query.isEmpty ? "Can't find your college?" : "Can't find \"$query\"?",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Public Sans',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Raise a PR and add it yourself, or open an issue with your college details — we'll get it added.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Public Sans',
              fontSize: 14,
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 18),
          _outlineButton(
            label: 'Raise a PR (Add Yourself)',
            filled: true,
            onTap: () => launchUrl(
              Uri.parse(
                  'https://github.com/CodeSapiens-in/CollegeSapien/blob/main/CONTRIBUTING.md'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 12),
          _outlineButton(
            label: 'Raise a Request',
            filled: false,
            onTap: () => launchUrl(
              Uri.parse(
                  'https://github.com/CodeSapiens-in/CollegeSapien/issues/new'
                  '?title=${Uri.encodeComponent('Add college: $query')}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlineButton(
      {required String label, required bool filled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: filled ? AppColors.primaryYellow : Colors.white,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(offset: Offset(3, 3), color: Colors.black)],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Public Sans',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

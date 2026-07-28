import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/api_models.dart';
import '../../providers/reference_data_store.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_theme.dart';
import '../../widgets/responsive_layout.dart';
import 'auth_screen.dart';

const _githubMarkSvg = '''
<svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
<path fill-rule="evenodd" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/>
</svg>
''';

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
      final colleges = await ReferenceDataStore.instance.listColleges();
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

  MascotMood get _mood {
    if (_searchCtrl.text.trim().isEmpty) return MascotMood.normal;
    if (!_loading && _filtered.isEmpty) return MascotMood.sad;
    return MascotMood.curious;
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
                if (kIsWeb) ...[_ctaRow(), const SizedBox(height: 20)],
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
                const SizedBox(height: 36),
                Container(
                  width: 88,
                  height: 88,
                  decoration: AppTheme.cardDecoration(
                    color: AppColors.background,
                    shadowOffset: const Offset(6, 6),
                  ),
                  child: const Center(child: _LogoHeadMascot(size: 70)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'The super app for students.\nThe companion you need.',
                  style: TextStyle(
                    fontFamily: 'Lexend Mega',
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.0,
                    height: 1.15,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Find your college, get your subjects, and stay on top of '
                  'your semester — built by students, for students.',
                  style: TextStyle(
                    fontFamily: 'Public Sans',
                    fontSize: 15,
                    color: Colors.black.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 32),
                _featureList(),
                const Spacer(),
                if (kIsWeb) _ctaRow(),
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

  // Desktop-only: mirrors the app's post-signup onboarding carousel, so a
  // browser visitor sees the same pitch a new mobile user gets.
  Widget _featureList() {
    final features = [
      (
        icon: Icons.calendar_today,
        color: AppColors.accentGreen,
        title: 'Attendance Tracker',
        desc: 'Never miss a class, get notified when it drops below 75%.',
      ),
      (
        icon: Icons.calculate,
        color: AppColors.accentBlue,
        title: 'CGPA Calculator',
        desc: 'Upload your grade sheet, get your CGPA instantly.',
      ),
      (
        icon: Icons.library_books,
        color: AppColors.accentPurple,
        title: 'Syllabus, Notes & Papers',
        desc: 'Every resource for your semester, in one place.',
      ),
      (
        icon: Icons.timer,
        color: AppColors.primaryYellow,
        title: 'Pomodoro Timer',
        desc: 'Stay focused with built-in study sessions.',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in features)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: f.color,
                    border: Border.all(color: Colors.black, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(f.icon, size: 18, color: Colors.black),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.title,
                        style: const TextStyle(
                          fontFamily: 'Public Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        f.desc,
                        style: TextStyle(
                          fontFamily: 'Public Sans',
                          fontSize: 12.5,
                          color: Colors.black.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Text(
          '+ much more',
          style: TextStyle(
            fontFamily: 'Public Sans',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black.withValues(alpha: 0.5),
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

  Widget _ctaRow() {
    return Row(
      children: [
        Expanded(child: _playStoreBanner()),
        const SizedBox(width: 12),
        Expanded(child: _githubBanner()),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.primaryYellow,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.play_arrow, size: 16),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Google Play',
                style: const TextStyle(
                  fontFamily: 'Public Sans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _githubBanner() {
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse('https://github.com/CodeSapiens-in/CollegeSapien'),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(7),
              ),
              padding: const EdgeInsets.all(5),
              child: SvgPicture.string(
                _githubMarkSvg,
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'GitHub',
                style: const TextStyle(
                  fontFamily: 'Public Sans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
            child: Center(
              child: _LogoHeadMascot(size: 78, mood: _mood),
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

enum MascotMood {
  normal('assets/images/mascot_normal.png'),
  curious('assets/images/mascot_curious.png'),
  sad('assets/images/mascot_sad.png');

  const MascotMood(this.asset);
  final String asset;
}

/// A small, intentionally quiet mascot treatment for auth: it bobs, blinks, and
/// reacts to the search — curious while typing, sad when nothing matches.
class _LogoHeadMascot extends StatefulWidget {
  const _LogoHeadMascot({required this.size, this.mood = MascotMood.normal});

  final double size;
  final MascotMood mood;

  @override
  State<_LogoHeadMascot> createState() => _LogoHeadMascotState();
}

class _LogoHeadMascotState extends State<_LogoHeadMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bobController;
  final _random = math.Random();
  Timer? _blinkTimer;
  bool _blinking = false;

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _scheduleBlink();
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    final delay = 2800 + _random.nextInt(3900);
    _blinkTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() => _blinking = true);
      _blinkTimer = Timer(const Duration(milliseconds: 170), () {
        if (!mounted) return;
        setState(() => _blinking = false);
        _scheduleBlink();
      });
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _bobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bobController,
      builder: (context, child) {
        final bob = math.sin(_bobController.value * math.pi * 2) * 2.2;
        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.scale(
            alignment: Alignment.center,
            scaleY: _blinking ? 0.91 : 1,
            child: child,
          ),
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Image.asset(
          widget.mood.asset,
          key: ValueKey(widget.mood),
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/api_models.dart';
import '../../services/auth_service.dart';
import '../../services/college_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/department_constants.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/searchable_dropdown.dart';
import '../home/main_navigation.dart';
import '../onboarding/onboarding_screen.dart';
import '../onboarding/user_details_screen.dart';
import 'college_selection_screen.dart';

enum _AuthTab { signUp, signIn }

/// Combined signup/signin screen shown after a college is picked. Signup
/// also collects department + semester up front, so the old separate
/// onboarding form is skipped for accounts created here.
class AuthScreen extends StatefulWidget {
  /// Null when reached via the "Already have an account? Sign In" shortcut
  /// (no college picked yet) — signup needs a college to onboard into, so
  /// the screen falls back to sign-in only in that case.
  final College? college;

  const AuthScreen({super.key, this.college});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  late _AuthTab _tab;
  bool _loading = false;
  bool _obscurePass = true;

  // Set once "Continue with Google" turns out to be a brand-new account —
  // name/email come from Google, password drops out of the form.
  bool _googleFlow = false;

  List<Department> _departments = [];
  String? _selectedDepartment;
  int? _selectedSemester;
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.college == null ? _AuthTab.signIn : _AuthTab.signUp;
    CollegeService().listDepartments().then((depts) {
      if (!mounted) return;
      depts.sort((a, b) => a.name.compareTo(b.name));
      setState(() => _departments = depts);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ─── Actions ────────────────────────────────────────────────────────────

  Future<void> _createAccount() async {
    final college = widget.college;
    if (college == null) return; // signup tab isn't reachable without one
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDepartment == null || _selectedSemester == null) {
      _snack('Please select your department and semester', error: true);
      return;
    }
    if (!_agreedToTerms) {
      _snack('Please agree to the Terms & Conditions', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      if (_googleFlow) {
        // Google email is already verified — onboard immediately.
        await AuthService.instance.onboard(
          name: _nameCtrl.text.trim(),
          collegeId: college.id,
          department: _selectedDepartment!,
          semester: _selectedSemester!,
        );
        if (!mounted) return;
        setState(() => _loading = false);
        _replaceWith(OnboardingScreen(nextScreen: const MainNavigation()));
        return;
      }

      await AuthService.instance.signUpWithEmailPassword(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await AuthService.savePendingOnboarding(
        collegeId: college.id,
        department: _selectedDepartment!,
        semester: _selectedSemester!,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Verification email sent — check your inbox then log in.');
      _replaceWith(OnboardingScreen(
        nextScreen: AuthScreen(college: college),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(AuthService.friendlyError(e), error: true);
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result = await AuthService.instance
          .signInWithEmailPassword(_emailCtrl.text, _passCtrl.text);
      if (!mounted) return;
      if (!result.emailVerified) {
        setState(() => _loading = false);
        await AuthService.instance.sendEmailVerification();
        _snack('Verify your email first. We resent the link.');
        return;
      }
      await _routeAfterAuth(result.onboardingRequired);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(AuthService.friendlyError(e), error: true);
      }
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final result = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      if (!result.onboardingRequired) {
        setState(() => _loading = false);
        _replaceWith(const MainNavigation());
        return;
      }
      if (widget.college == null) {
        // Brand-new account, but this screen was reached without a college
        // (the "Sign In" shortcut) — send them to pick one first.
        setState(() => _loading = false);
        _snack('Please select your college to finish creating your account.');
        _replaceWith(const CollegeSelectionScreen());
        return;
      }
      // Brand-new (or never-finished) account — collect department/semester
      // below instead of the old separate onboarding form.
      final user = AuthService.instance.currentUser;
      setState(() {
        _loading = false;
        _tab = _AuthTab.signUp;
        _googleFlow = true;
        _nameCtrl.text = user?.displayName ?? '';
        _emailCtrl.text = user?.email ?? '';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(AuthService.friendlyError(e), error: true);
      }
    }
  }

  /// Applies onboarding details cached at signup time, if any; falls back
  /// to the standalone college/department/semester form otherwise.
  Future<void> _routeAfterAuth(bool onboardingRequired) async {
    if (!onboardingRequired) {
      setState(() => _loading = false);
      _replaceWith(const MainNavigation());
      return;
    }
    final pending = await AuthService.consumePendingOnboarding();
    if (pending == null) {
      setState(() => _loading = false);
      _replaceWith(UserDetailsScreen(collegeId: widget.college?.id));
      return;
    }
    try {
      await AuthService.instance.onboard(
        name: AuthService.instance.currentUser?.displayName ?? '',
        collegeId: pending.collegeId,
        department: pending.department,
        semester: pending.semester,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      _replaceWith(const MainNavigation());
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(AuthService.friendlyError(e), error: true);
      _replaceWith(UserDetailsScreen(collegeId: pending.collegeId));
    }
  }

  Future<void> _forgotPassword() async {
    final ctrl = TextEditingController(text: _emailCtrl.text.trim());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Reset Password',
            style: TextStyle(fontFamily: 'Lexend Mega', fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("We'll send a reset link to your email.",
                style: TextStyle(fontFamily: 'Public Sans', fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryYellow),
            onPressed: () async {
              final email = ctrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (mounted) _snack('Reset link sent to $email');
              } catch (e) {
                if (mounted) _snack(AuthService.friendlyError(e), error: true);
              }
            },
            child:
                const Text('Send Link', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _replaceWith(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  // ─── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveLayout(
          mobile: (_) => SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: w * 0.06, vertical: 20),
            child: Form(key: _formKey, child: _content()),
          ),
          desktop: (_) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Container(
                width: 460,
                padding: const EdgeInsets.all(32),
                decoration: AppTheme.cardDecoration(
                  color: Colors.white,
                  shadowOffset: const Offset(6, 6),
                ),
                child: Form(key: _formKey, child: _content()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(offset: Offset(2, 2), color: Colors.black)
                ],
              ),
              child: const Icon(Icons.arrow_back, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (widget.college != null) ...[
          _collegeBanner(widget.college!),
          const SizedBox(height: 20),
          _tabToggle(),
          const SizedBox(height: 24),
        ],
        _googleButton(),
        const SizedBox(height: 20),
        _orDivider(),
        const SizedBox(height: 20),
        if (_tab == _AuthTab.signUp) ..._signUpFields() else ..._signInFields(),
        const SizedBox(height: 16),
        _primaryButton(
          label: _tab == _AuthTab.signUp ? 'Create Account' : 'Login',
          onTap: _loading
              ? null
              : (_tab == _AuthTab.signUp ? _createAccount : _login),
        ),
        if (widget.college == null) ...[
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: () => _replaceWith(const CollegeSelectionScreen()),
              child: const Text(
                "New here? Find your college to sign up →",
                style: TextStyle(
                  fontFamily: 'Public Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _termsFooter(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _collegeBanner(College college) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AppTheme.cardDecoration(color: AppColors.accentGreen),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: AppTheme.badgeDecoration(color: AppColors.primaryYellow),
            child: Center(
              child: Text(
                college.name.isNotEmpty ? college.name[0].toUpperCase() : '?',
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
                  'YOUR COLLEGE',
                  style: TextStyle(
                    fontFamily: 'Public Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  college.name,
                  style: const TextStyle(
                    fontFamily: 'Public Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              'Change',
              style: TextStyle(
                fontFamily: 'Public Sans',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabToggle() {
    return Container(
      height: 56,
      decoration: AppTheme.cardDecoration(color: Colors.white),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(child: _tabButton('Sign Up', _AuthTab.signUp)),
          Expanded(child: _tabButton('Sign In', _AuthTab.signIn)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, _AuthTab tab) {
    final selected = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() {
        _tab = tab;
        _googleFlow = false;
      }),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  List<Widget> _signUpFields() {
    return [
      if (_googleFlow) ...[
        _readOnlyField(Icons.person_outline, _nameCtrl.text),
        const SizedBox(height: 14),
        _readOnlyField(Icons.email_outlined, _emailCtrl.text),
      ] else ...[
        TextFormField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Enter your email';
            if (!v.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passCtrl,
          obscureText: _obscurePass,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePass ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Enter a password';
            if (v.length < 6) return 'At least 6 characters';
            return null;
          },
        ),
      ],
      const SizedBox(height: 14),
      SearchableDropdown<Department>(
        items: _departments,
        value: _selectedDepartment != null
            ? _departments
                .where((d) => d.name == _selectedDepartment)
                .firstOrNull
            : null,
        labelBuilder: (d) => d.name,
        decoration: const InputDecoration(
          labelText: 'Department',
          prefixIcon: Icon(Icons.engineering_outlined),
        ),
        onChanged: (d) => setState(() => _selectedDepartment = d?.name),
      ),
      const SizedBox(height: 18),
      Text(
        'SEMESTER',
        style: TextStyle(
          fontFamily: 'Public Sans',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Colors.black.withValues(alpha: 0.6),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: semesters.map((sem) {
          final selected = _selectedSemester == sem;
          return GestureDetector(
            onTap: () => setState(() => _selectedSemester = sem),
            child: Container(
              width: 52,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.black : Colors.white,
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$sem',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.black,
                ),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 18),
      GestureDetector(
        onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _agreedToTerms ? AppColors.accentGreen : Colors.white,
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(offset: Offset(3, 3), color: Colors.black)],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _agreedToTerms ? Colors.black : Colors.transparent,
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _agreedToTerms
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'I agree to the Terms of Service and Privacy Policy',
                  style: TextStyle(
                    fontFamily: 'Public Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _readOnlyField(IconData icon, String value) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 12),
          Text(value,
              style: const TextStyle(fontFamily: 'Public Sans', fontSize: 15)),
        ],
      ),
    );
  }

  List<Widget> _signInFields() {
    return [
      TextFormField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.email_outlined),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Enter your email';
          if (!v.contains('@')) return 'Enter a valid email';
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _passCtrl,
        obscureText: _obscurePass,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _loading ? null : _login(),
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
          ),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Enter your password';
          if (v.length < 6) return 'At least 6 characters';
          return null;
        },
      ),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _forgotPassword,
          child: const Text(
            'Forgot Password?',
            style: TextStyle(
              fontFamily: 'Public Sans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _termsFooter() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'Public Sans',
            fontSize: 12,
            color: Colors.black.withValues(alpha: 0.5),
          ),
          children: [
            const TextSpan(text: 'By continuing, you agree to our '),
            TextSpan(
              text: 'Terms of Service',
              style: const TextStyle(
                decoration: TextDecoration.underline,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => launchUrl(
                      Uri.parse('https://college.codesapiens.in/terms.html'),
                      mode: LaunchMode.externalApplication,
                    ),
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: const TextStyle(
                decoration: TextDecoration.underline,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => launchUrl(
                      Uri.parse('https://college.codesapiens.in/privacy.html'),
                      mode: LaunchMode.externalApplication,
                    ),
            ),
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primaryYellow,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(offset: Offset(4, 4), color: Colors.black)],
        ),
        child: Center(
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.black),
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _googleButton() {
    return GestureDetector(
      onTap: _loading ? null : _googleSignIn,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(offset: Offset(3, 3), color: Colors.black)],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.g_mobiledata, size: 28, color: Colors.black),
            SizedBox(width: 8),
            Text(
              'Continue with Google',
              style: TextStyle(
                fontFamily: 'Public Sans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 2, color: Colors.black)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              fontFamily: 'Public Sans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
        ),
        Expanded(child: Container(height: 2, color: Colors.black)),
      ],
    );
  }
}

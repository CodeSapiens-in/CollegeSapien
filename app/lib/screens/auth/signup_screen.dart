import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/responsive_layout.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/main_navigation.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _snack('Please agree to the Terms & Conditions', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.instance.signUpWithEmailPassword(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Verification email sent — check your inbox then log in.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e.toString(), error: true);
      }
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final result = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => result.onboardingRequired
              ? const OnboardingScreen()
              : const MainNavigation(),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e.toString(), error: true);
      }
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
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
            child: Form(key: _formKey, child: _formColumn()),
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
                child: Form(key: _formKey, child: _formColumn()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formColumn() {
    return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back button
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

                // Logo
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: AppTheme.cardDecoration(
                      color: AppColors.primaryYellow,
                      shadowOffset: const Offset(6, 6),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/images/codesapiens_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Heading
                const Center(
                  child: Text(
                    'Create Account',
                    style: TextStyle(
                      fontFamily: 'Lexend Mega',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2.0,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Join the community',
                    style: TextStyle(
                      fontFamily: 'Public Sans',
                      fontSize: 15,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Name
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 14),

                // Email
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

                // Password
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Confirm password
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your password';
                    if (v != _passCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Terms checkbox — neo-brutalist row
                GestureDetector(
                  onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          _agreedToTerms ? AppColors.accentGreen : Colors.white,
                      border: Border.all(color: Colors.black, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(offset: Offset(3, 3), color: Colors.black)
                      ],
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _agreedToTerms
                                ? Colors.black
                                : Colors.transparent,
                            border: Border.all(color: Colors.black, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: _agreedToTerms
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: 'Public Sans',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: const TextStyle(
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => launchUrl(
                                          Uri.parse(
                                              'https://college.codesapiens.in/terms.html'),
                                          mode: LaunchMode.externalApplication,
                                        ),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => launchUrl(
                                          Uri.parse(
                                              'https://college.codesapiens.in/privacy.html'),
                                          mode: LaunchMode.externalApplication,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Sign up button
                _primaryButton(
                    label: 'Sign Up', onTap: _loading ? null : _signup),
                const SizedBox(height: 20),

                // OR divider
                _orDivider(),
                const SizedBox(height: 20),

                // Google
                _googleButton(),
                const SizedBox(height: 24),

                // Already have account
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(offset: Offset(3, 3), color: Colors.black)
                      ],
                    ),
                    child: Center(
                      child: RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Already have an account?  ',
                              style: TextStyle(
                                fontFamily: 'Public Sans',
                                fontSize: 14,
                                color: Color(0xFF666666),
                              ),
                            ),
                            TextSpan(
                              text: 'Login →',
                              style: TextStyle(
                                fontFamily: 'Public Sans',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
    );
  }

  // ─── Shared widgets ────────────────────────────────────────────────────────

  Widget _primaryButton({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primaryYellow,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(offset: Offset(4, 4), color: Colors.black)
          ],
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
          boxShadow: const [
            BoxShadow(offset: Offset(3, 3), color: Colors.black)
          ],
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

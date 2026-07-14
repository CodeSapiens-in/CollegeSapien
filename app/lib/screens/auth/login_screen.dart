import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/responsive_layout.dart';
import 'signup_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result = await AuthService.instance
          .signInWithEmailPassword(_emailCtrl.text, _passCtrl.text);
      if (!mounted) return;
      setState(() => _loading = false);
      if (!result.emailVerified) {
        await AuthService.instance.sendEmailVerification();
        _snack('Verify your email first. We resent the link.');
        return;
      }
      _route(result.onboardingRequired);
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
      _route(result.onboardingRequired);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e.toString(), error: true);
      }
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
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);
                if (mounted) _snack('Reset link sent to $email');
              } catch (e) {
                if (mounted) _snack(e.toString(), error: true);
              }
            },
            child:
                const Text('Send Link', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _route(bool onboarding) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            onboarding ? const OnboardingScreen() : const MainNavigation(),
      ),
    );
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
            padding: EdgeInsets.symmetric(horizontal: w * 0.06, vertical: 32),
            child: Form(key: _formKey, child: _formColumn()),
          ),
          // Desktop: the form becomes a centered card on the page background
          // instead of an edge-to-edge column stretched across the window.
          desktop: (_) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Container(
                width: 440,
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
                const SizedBox(height: 24),

                // Logo
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
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
                const SizedBox(height: 24),

                // Heading
                const Center(
                  child: Text(
                    'Welcome Back!',
                    style: TextStyle(
                      fontFamily: 'Lexend Mega',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2.0,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Login to continue',
                    style: TextStyle(
                      fontFamily: 'Public Sans',
                      fontSize: 15,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

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
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _loading ? null : _login(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your password';
                    if (v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 4),

                // Forgot password
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
                const SizedBox(height: 12),

                // Login button
                _primaryButton(
                  label: 'Login',
                  onTap: _loading ? null : _login,
                ),
                const SizedBox(height: 14),

                // Create account button — visible without scrolling
                _secondaryButton(
                  label: "Don't have an account?  Sign Up →",
                  onTap: _loading
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SignupScreen()),
                          ),
                ),
                const SizedBox(height: 28),

                // OR divider
                _orDivider(),
                const SizedBox(height: 20),

                // Google
                _googleButton(),
                const SizedBox(height: 24),

                // Terms & Privacy
                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                      children: [
                        const TextSpan(
                            text: 'By continuing, you agree to our '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
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
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => launchUrl(
                                  Uri.parse(
                                      'https://college.codesapiens.in/privacy.html'),
                                  mode: LaunchMode.externalApplication,
                                ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
    );
  }

  // ─── Shared button widgets ─────────────────────────────────────────────────

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

  Widget _secondaryButton({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(offset: Offset(3, 3), color: Colors.black)
          ],
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

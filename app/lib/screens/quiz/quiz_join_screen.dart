import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/quiz_service.dart';
import '../../utils/app_theme.dart';
import 'quiz_participant_screen.dart';

class QuizJoinScreen extends StatefulWidget {
  final String? initialCode;
  const QuizJoinScreen({super.key, this.initialCode});

  @override
  State<QuizJoinScreen> createState() => _QuizJoinScreenState();
}

class _QuizJoinScreenState extends State<QuizJoinScreen> {
  late final _codeController = TextEditingController(text: widget.initialCode ?? '');
  final _nickController = TextEditingController();
  bool _asGuest = AuthService.instance.currentUser == null;
  bool _joining = false;
  String? _error;

  bool get _canJoin =>
      _codeController.text.trim().length == 6 &&
      (!_asGuest || _nickController.text.trim().isNotEmpty);

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final code = _codeController.text.trim();
      final session = await QuizService.instance.findSessionByCode(code);
      if (session == null) {
        setState(() => _error = "No live quiz found for code $code");
        return;
      }
      final participant = _asGuest
          ? await QuizService.instance.joinAsGuest(session.id, _nickController.text.trim())
          : await QuizService.instance.joinAsAccount(session.id);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizParticipantScreen(
            sessionId: session.id,
            me: participant,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Could not join: $e');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = AuthService.instance.currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Join a quiz')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('CODE',
                    style: TextStyle(
                        fontFamily: 'Public Sans',
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Lexend Mega', fontSize: 28, letterSpacing: 2),
                  decoration: const InputDecoration(counterText: '', hintText: '6 digits'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                const Text('HOW YOU\'LL SHOW UP',
                    style: TextStyle(
                        fontFamily: 'Public Sans',
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                if (loggedIn != null)
                  _identityTile(
                    selected: !_asGuest,
                    title: loggedIn.displayName ?? 'Your account',
                    subtitle: 'Your CollegeSapien account',
                    onTap: () => setState(() => _asGuest = false),
                  ),
                if (loggedIn != null) const SizedBox(height: 8),
                _identityTile(
                  selected: _asGuest,
                  title: 'Join as a guest',
                  subtitle: 'Nickname only — no account shown',
                  onTap: () => setState(() => _asGuest = true),
                  extra: _asGuest
                      ? Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: TextField(
                            controller: _nickController,
                            decoration: const InputDecoration(hintText: 'Pick a nickname'),
                            onChanged: (_) => setState(() {}),
                          ),
                        )
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _canJoin && !_joining ? _join : null,
                  child: _joining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Join quiz'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _identityTile({
    required bool selected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? extra,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentBlue : Colors.white,
          border: Border.all(color: Colors.black, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? const [BoxShadow(offset: Offset(3, 3), color: Colors.black)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontFamily: 'Public Sans', fontWeight: FontWeight.w800)),
                      Text(subtitle,
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Colors.black.withValues(alpha: 0.55))),
                    ],
                  ),
                ),
              ],
            ),
            if (extra != null) extra,
          ],
        ),
      ),
    );
  }
}

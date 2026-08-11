import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/quiz_service.dart';
import '../../utils/app_theme.dart';
import 'quiz_host_screen.dart';
import 'quiz_join_screen.dart';

/// Entry point for the live quiz feature — host a new quiz or join one with
/// a code. Stands alone today; slots under the rooms module once that exists.
class QuizLandingScreen extends StatefulWidget {
  const QuizLandingScreen({super.key});

  @override
  State<QuizLandingScreen> createState() => _QuizLandingScreenState();
}

class _QuizLandingScreenState extends State<QuizLandingScreen> {
  bool _creating = false;

  Future<void> _hostQuiz() async {
    final title = await _promptTitle();
    if (title == null) return;
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    setState(() => _creating = true);
    try {
      final session = await QuizService.instance.createSession(
        hostUid: user.uid,
        hostName: user.displayName ?? 'Host',
        title: title,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuizHostScreen(sessionId: session.id)),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<String?> _promptTitle() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name your quiz'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. DBMS — quick check'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              ctx,
              controller.text.trim().isEmpty ? 'Untitled quiz' : controller.text.trim(),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Live Quiz')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionCard(
                  icon: Icons.cast,
                  color: AppColors.accentBlue,
                  title: 'Host a quiz',
                  subtitle: 'Create a session, invite others, run it live.',
                  loading: _creating,
                  onTap: _creating ? null : _hostQuiz,
                ),
                const SizedBox(height: 16),
                _actionCard(
                  icon: Icons.qr_code,
                  color: AppColors.accentGreen,
                  title: 'Join a quiz',
                  subtitle: 'Enter a code or scan a QR to join.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuizJoinScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(color: color),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(icon, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'Public Sans',
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

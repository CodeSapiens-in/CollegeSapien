import 'package:flutter/material.dart';
import '../../models/pomodoro_models.dart';
import '../../services/pomodoro_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/responsive_layout.dart';
import 'pomodoro_timer_detail_screen.dart';

class PomodoroHomeScreen extends StatefulWidget {
  const PomodoroHomeScreen({super.key});

  @override
  State<PomodoroHomeScreen> createState() => _PomodoroHomeScreenState();
}

class _PomodoroHomeScreenState extends State<PomodoroHomeScreen> {
  final _service = PomodoroService();
  Future<List<PomodoroTimerSummary>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _future = _service.getTimers());

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }

  Future<void> _createTimer() async {
    final controller = TextEditingController();
    final purpose = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
        title: const Text('New Timer',
            style: TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. DSA Assignment'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Create')),
        ],
      ),
    );

    final trimmed = purpose?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    try {
      final id = await _service.createTimer(trimmed);
      _refresh();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PomodoroTimerDetailScreen(timerId: id)),
        );
      }
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Pomodoro',
          style: TextStyle(
            fontFamily: 'Lexend Mega',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTimer,
        backgroundColor: AppColors.primaryYellow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(screenWidth * 0.045),
            child: MaxWidthContent(
              maxWidth: 560,
              child: FutureBuilder<List<PomodoroTimerSummary>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('Could not load timers: ${snapshot.error}'),
                    );
                  }
                  final timers = snapshot.data!;
                  if (timers.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.cardDecoration(color: Colors.white),
                      child: const Text(
                        'No timers yet. Tap + to create one and start focusing.',
                        style: TextStyle(fontFamily: 'Public Sans', fontSize: 14),
                      ),
                    );
                  }
                  return Column(children: timers.map(_timerCard).toList());
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timerCard(PomodoroTimerSummary timer) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PomodoroTimerDetailScreen(timerId: timer.id)),
      ).then((_) => _refresh()),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(color: AppColors.accentPurple),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 32, color: Colors.black),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(timer.purpose,
                      style: const TextStyle(
                          fontFamily: 'Lexend Mega', fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '${timer.memberCount} member${timer.memberCount == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 13,
                        color: Colors.black.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black),
          ],
        ),
      ),
    );
  }
}

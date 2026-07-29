import 'package:flutter/material.dart';
import '../../models/pomodoro_models.dart';
import '../../services/pomodoro_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/responsive_layout.dart';
import 'dart:async';

class PomodoroTimerScreen extends StatefulWidget {
  final String timerId;
  final PomodoroMode initialMode;

  const PomodoroTimerScreen({
    super.key,
    required this.timerId,
    this.initialMode = PomodoroMode.focus,
  });

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> {
  static const _modeLabels = {
    PomodoroMode.focus: 'Pomodoro',
    PomodoroMode.shortBreak: 'Short Break',
    PomodoroMode.longBreak: 'Long Break',
  };

  final _pomodoroService = PomodoroService();

  late int _timeLeft;
  bool _isRunning = false;
  Timer? _timer;
  int _sessionsCompleted = 0;
  late String _selectedMode;

  // Tracks the currently-running session doc so a mode switch or early exit
  // can cancel it — natural completion needs no call (status is time-derived).
  bool _sessionStarted = false;
  String? _currentSessionId;

  final List<Map<String, dynamic>> _tasks = [];
  final TextEditingController _taskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedMode = _modeLabels[widget.initialMode]!;
    _timeLeft = widget.initialMode.defaultDurationSec;
  }

  PomodoroMode _modeFromLabel(String label) =>
      _modeLabels.entries.firstWhere((e) => e.value == label).key;

  void _cancelActiveSessionIfAny() {
    if (_sessionStarted && _currentSessionId != null) {
      _pomodoroService.cancelSession(_currentSessionId!).catchError((_) {});
    }
    _sessionStarted = false;
    _currentSessionId = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_isRunning) _cancelActiveSessionIfAny();
    _taskController.dispose();
    super.dispose();
  }

  void _setMode(String mode) {
    _timer?.cancel();
    _cancelActiveSessionIfAny();
    setState(() {
      _selectedMode = mode;
      _isRunning = false;
      _timeLeft = _modeFromLabel(mode).defaultDurationSec;
    });
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _onTimerComplete();
        }
      });
    });
    if (!_sessionStarted) {
      _sessionStarted = true;
      _beginSession();
    }
  }

  Future<void> _beginSession() async {
    try {
      _currentSessionId = await _pomodoroService.startSession(
          widget.timerId, _modeFromLabel(_selectedMode), _timeLeft);
    } catch (_) {}
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _onTimerComplete() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      if (_selectedMode == 'Pomodoro') _sessionsCompleted++;
    });
    _sessionStarted = false;
    _currentSessionId = null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _selectedMode == 'Pomodoro'
              ? 'Work session complete! Take a break!'
              : 'Break complete! Time to work!',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatTime() {
    final minutes = (_timeLeft / 60).floor();
    final seconds = _timeLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color _getModeColor() {
    switch (_selectedMode) {
      case 'Pomodoro':
        return const Color(0xFFFDD835);
      case 'Short Break':
        return AppColors.accentGreen;
      case 'Long Break':
        return AppColors.accentBlue;
      default:
        return AppColors.primaryYellow;
    }
  }

  void _addTask() {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _tasks.add({'title': title, 'done': false});
    });
    _taskController.clear();
  }

  void _toggleTask(int index) {
    setState(() => _tasks[index]['done'] = !_tasks[index]['done']);
  }

  void _deleteTask(int index) {
    setState(() => _tasks.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Pomodoro Timer',
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenWidth * 0.045),
          child: MaxWidthContent(
            maxWidth: 560,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Mode Tabs
              Row(
                children: [
                  Expanded(child: _buildModeTab('Pomodoro')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildModeTab('Short Break')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildModeTab('Long Break')),
                ],
              ),
              const SizedBox(height: 30),

              // Timer Display
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                decoration: BoxDecoration(
                  color: _getModeColor(),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black,
                        offset: Offset(8, 8),
                        blurRadius: 0),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      _formatTime(),
                      style: const TextStyle(
                        fontFamily: 'Lexend Mega',
                        fontSize: 96,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isRunning ? _pauseTimer : _startTimer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side:
                                const BorderSide(color: Colors.black, width: 2),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        child: Text(
                          _isRunning ? 'PAUSE' : 'START',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _getModeColor() == const Color(0xFFFDD835)
                                ? const Color(0xFFD32F2F)
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Session Counter
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration:
                    AppTheme.cardDecoration(color: AppColors.accentPurple),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 28, color: Colors.black),
                    const SizedBox(width: 12),
                    Text(
                      '$_sessionsCompleted session${_sessionsCompleted == 1 ? '' : 's'} completed',
                      style: const TextStyle(
                        fontFamily: 'Lexend Mega',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Task Checklist
              const Text(
                'Tasks',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF191C1E),
                ),
              ),
              const SizedBox(height: 12),

              // Add task input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _taskController,
                      onSubmitted: (_) => _addTask(),
                      decoration: InputDecoration(
                        hintText: 'Add a task...',
                        hintStyle: TextStyle(
                          fontFamily: 'Public Sans',
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Colors.black, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Colors.black, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _addTask,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: AppTheme.cardDecoration(
                        color: AppColors.primaryYellow,
                        shadowOffset: const Offset(2, 2),
                      ),
                      child:
                          const Icon(Icons.add, size: 24, color: Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_tasks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration(color: Colors.white),
                  child: Center(
                    child: Text(
                      'No tasks yet. Add something to focus on!',
                      style: TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 14,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                )
              else
                ...List.generate(_tasks.length, (i) => _buildTaskItem(i)),

              const SizedBox(height: 40),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem(int index) {
    final task = _tasks[index];
    final isDone = task['done'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppTheme.cardDecoration(
        color: isDone
            ? AppColors.accentGreen.withValues(alpha: 0.6)
            : Colors.white,
        shadowOffset: const Offset(2, 2),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleTask(index),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isDone ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              task['title'] as String,
              style: TextStyle(
                fontFamily: 'Public Sans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                decoration: isDone ? TextDecoration.lineThrough : null,
                decorationColor: Colors.black,
                decorationThickness: 2,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _deleteTask(index),
            child: Icon(Icons.close,
                size: 18, color: Colors.black.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(String mode) {
    final isSelected = _selectedMode == mode;

    return GestureDetector(
      onTap: () => _setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _getModeColor()
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                      color: Colors.black, offset: Offset(3, 3), blurRadius: 0)
                ]
              : [],
        ),
        child: Text(
          mode,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Public Sans',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

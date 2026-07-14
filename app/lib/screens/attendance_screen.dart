import 'package:flutter/material.dart';

import '../models/api_models.dart';
import '../providers/app_state_notifier.dart';
import '../services/attendance_service.dart';
import '../utils/app_theme.dart';
import '../utils/breakpoints.dart';
import '../utils/app_spacing.dart';
import '../widgets/responsive_layout.dart';
import 'attendance/mark_attendance_screen.dart';
import 'timetable_list_screen.dart';

class AttendanceScreen extends StatefulWidget {
  final int refreshToken;

  const AttendanceScreen({super.key, this.refreshToken = 0});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _attendanceService = AttendanceService();
  List<AttendanceSummary> _summaries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Instant paint from the same cache AppStateNotifier already maintains —
    // no separate copy of this data to keep in sync.
    final cached = AppStateNotifier.instance.attendanceSummary;
    if (cached != null) {
      _summaries = cached;
      _isLoading = false;
    }
    _loadSummary();
  }

  @override
  void didUpdateWidget(covariant AttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadSummary();
    }
  }

  Future<void> _loadSummary() async {
    try {
      final fresh = await _attendanceService.getSummary();
      AppStateNotifier.instance.setAttendanceSummary(fresh);
      if (mounted) {
        setState(() {
          _summaries = fresh;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _refresh() => _loadSummary();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final summaries = _summaries;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryYellow,
        foregroundColor: Colors.black,
        onPressed: () async {
          if (summaries.isEmpty) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const TimetableListScreen()),
            );
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const MarkAttendanceScreen()),
            );
          }
          _refresh();
        },
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (_isLoading && summaries.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_error != null && summaries.isEmpty) {
              return _ErrorState(message: _error!, onRetry: _refresh);
            }

            final average = summaries.isEmpty
                ? 0.0
                : summaries
                        .map((item) => item.percentage)
                        .reduce((a, b) => a + b) /
                    summaries.length;

            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ResponsiveLayout(
                mobile: (_) => _mobileList(screenWidth, average, summaries),
                desktop: (_) => _desktopGrid(context, average, summaries),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _mobileList(
      double screenWidth, double average, List<AttendanceSummary> summaries) {
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.045,
        vertical: 20,
      ),
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildAverageCard(average, summaries),
        const SizedBox(height: 24),
        const Text(
          'SUBJECT WISE ANALYSIS',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF191C1E),
          ),
        ),
        const SizedBox(height: 16),
        if (summaries.isEmpty)
          _buildEmptyState()
        else
          ...summaries.map(_buildSubjectCard),
        const SizedBox(height: 8),
        _buildTipCard(),
        const SizedBox(height: 80),
      ],
    );
  }

  // Desktop: subject cards render as a 2–3 column grid instead of one per
  // row, sized off the available width via LayoutBuilder inside ResponsiveLayout.
  Widget _desktopGrid(
      BuildContext context, double average, List<AttendanceSummary> summaries) {
    final width = MediaQuery.of(context).size.width;
    final columns = Breakpoints.isWide(width) ? 3 : 2;
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.pagePadding(width)),
      child: MaxWidthContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: AppSpacing.sectionGap(width)),
            _buildAverageCard(average, summaries),
            SizedBox(height: AppSpacing.sectionGap(width)),
            const Text(
              'SUBJECT WISE ANALYSIS',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF191C1E),
              ),
            ),
            const SizedBox(height: 16),
            if (summaries.isEmpty)
              _buildEmptyState()
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: summaries.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: AppSpacing.lg,
                  crossAxisSpacing: AppSpacing.lg,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (_, i) =>
                    _buildSubjectCard(summaries[i], includeMargin: false),
              ),
            const SizedBox(height: 24),
            _buildTipCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final canPop = Navigator.canPop(context);
    return Row(
      children: [
        if (canPop)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, size: 24, color: Colors.black),
          )
        else
          const Icon(Icons.check_circle_outline, size: 24, color: Colors.black),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Attendance',
            style: TextStyle(
              fontFamily: 'Lexend Mega',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAverageCard(double average, List<AttendanceSummary> summaries) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: AppTheme.cardDecoration(
        color: AppColors.primaryYellow,
        shadowOffset: const Offset(6, 6),
      ),
      child: Column(
        children: [
          Text(
            '${average.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontFamily: 'Lexend Mega',
              fontSize: 54,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summaries.isEmpty
                ? 'Upload your timetable, then start marking attendance'
                : 'Average across ${summaries.length} subjects',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Public Sans',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(AttendanceSummary summary,
      {bool includeMargin = true}) {
    final color =
        summary.percentage >= 75 ? AppColors.accentGreen : AppColors.accentPink;
    return Container(
      margin: includeMargin ? const EdgeInsets.only(bottom: 16) : null,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.subjectName.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Lexend Mega',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(summary.subjectCode,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: (summary.percentage / 100).clamp(0, 1),
            minHeight: 10,
            backgroundColor: Colors.white,
            color: Colors.black,
          ),
          const SizedBox(height: 12),
          Text(
            '${summary.percentage.toStringAsFixed(1)}% · ${summary.attended}/${summary.total} attended · Safe skips: ${summary.safeToSkip}',
            style: const TextStyle(
                fontFamily: 'Public Sans', fontWeight: FontWeight.w600),
          ),
          if (summary.requiredToReachThreshold > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Attend ${summary.requiredToReachThreshold} more classes to recover.',
              style: const TextStyle(
                  fontFamily: 'Public Sans', fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(color: AppColors.accentBlue),
      child: const Text(
        'No attendance summary yet. Save your timetable first so subjects can be tracked.',
        textAlign: TextAlign.center,
        style:
            TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(color: Colors.white),
      child: const Text(
        'Tip: Attendance marked before a class ends is saved now and counted after the slot end time.',
        style: TextStyle(
          fontFamily: 'Public Sans',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

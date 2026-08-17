import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/cgpa_models.dart';
import '../../services/auth_service.dart';
import '../../services/resource_service.dart';
import '../../providers/app_state_notifier.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../widgets/responsive_layout.dart';
import '../attendance_screen.dart';
import '../auth/college_selection_screen.dart';
import '../resources/resources_hub_screen.dart';
import '../syllabus/syllabus_selection_screen.dart';
import 'about_screen.dart';
import 'edit_profile_screen.dart';
import '../cgpa/cgpa_calculator_screen.dart';
import 'help_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final void Function(int)? onTabSwitch;

  const ProfileScreen({super.key, this.onTabSwitch});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _semesterPrefsKey = 'last_semester';

  String _attendanceStat = '--';
  String _cgpaStat = '--';
  String _semesterStat = '--';
  int? _subjectCount;
  num? _totalCredits;
  String _filesUploaded = '--';
  String? _collegeName;
  String? _department;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final appState = Provider.of<AppStateNotifier>(context, listen: false);

    // Paint straight from the shared app-state cache (populated by
    // /auth/sync on app launch) instead of always hitting the network.
    final cachedProfile = appState.userProfile;
    if (cachedProfile != null) {
      if (cachedProfile.semester > 0) {
        _semesterStat = cachedProfile.semester.toString();
      }
      _collegeName = cachedProfile.collegeName;
      _department = cachedProfile.department;
    }
    final cachedAttendance = appState.attendanceSummary;
    if (cachedAttendance != null && cachedAttendance.isNotEmpty) {
      final avg =
          cachedAttendance.map((s) => s.percentage).reduce((a, b) => a + b) /
              cachedAttendance.length;
      _attendanceStat = '${avg.toStringAsFixed(1)}%';
    }
    final cachedSubjects = appState.savedSubjects;
    if (cachedSubjects != null && cachedSubjects.isNotEmpty) {
      final credits =
          cachedSubjects.fold<num>(0, (sum, s) => sum + (s.credits ?? 0));
      _subjectCount = cachedSubjects.length;
      _totalCredits = credits > 0 ? credits : null;
    }

    // CGPA/files-uploaded aren't part of /auth/sync — CGPA is derived from
    // its own source-of-truth box (shared with the CGPA calculator screen),
    // files-uploaded is cached as its own short-TTL stat.
    if (!appState.cgpaSemestersBox.hasValue) {
      await appState.cgpaSemestersBox.hydrate();
    }
    _applyCgpaStat(appState.cgpaSemestersBox.staleValueOrNull);
    if (!appState.filesUploadedStatBox.hasValue) {
      await appState.filesUploadedStatBox.hydrate();
    }
    final cachedFilesUploaded = appState.filesUploadedStatBox.staleValueOrNull;
    if (cachedFilesUploaded != null) _filesUploaded = cachedFilesUploaded;

    if (mounted) setState(() {});

    // Background refresh — only hit the network for pieces whose cache is
    // stale/missing, so reopening this screen doesn't always re-sync.
    if (appState.userProfile == null ||
        appState.attendanceSummary == null ||
        appState.savedSubjects == null) {
      try {
        final result = await AuthService.instance.syncProfile();
        final profile = result.user;
        if (profile != null) {
          appState.setUserProfile(profile);
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(_semesterPrefsKey, profile.semester);
          } catch (_) {}
          if (mounted) {
            setState(() {
              if (profile.semester > 0) {
                _semesterStat = profile.semester.toString();
              }
              if (profile.collegeName != null) {
                _collegeName = profile.collegeName;
              }
              if (profile.department != null) _department = profile.department;
            });
          }
        }

        final freshAttendance = result.attendanceSummary;
        if (freshAttendance != null) {
          appState.setAttendanceSummary(freshAttendance);
          if (freshAttendance.isNotEmpty && mounted) {
            final avg = freshAttendance
                    .map((s) => s.percentage)
                    .reduce((a, b) => a + b) /
                freshAttendance.length;
            setState(() => _attendanceStat = '${avg.toStringAsFixed(1)}%');
          }
        }

        final freshSubjects = result.savedSubjects?.subjects;
        if (freshSubjects != null && freshSubjects.isNotEmpty) {
          appState.setSavedSubjects(freshSubjects);
          if (mounted) {
            final credits =
                freshSubjects.fold<num>(0, (sum, s) => sum + (s.credits ?? 0));
            setState(() {
              _subjectCount = freshSubjects.length;
              _totalCredits = credits > 0 ? credits : null;
            });
          }
        }
      } catch (_) {}
    }

    // Files uploaded by this user
    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid != null) {
        final results = await Future.wait([
          ResourceService().listHubResources('Notes'),
          ResourceService().listHubResources('QP'),
        ]);
        final count = results
            .expand((list) => list)
            .where((r) => r.uploadedBy == uid)
            .length;
        final countStr = count.toString();
        appState.filesUploadedStatBox.set(countStr);
        if (mounted) setState(() => _filesUploaded = countStr);
      }
    } catch (_) {}
  }

  void _applyCgpaStat(List<CgpaSemesterEntry>? entries) {
    if (entries == null || entries.isEmpty) return;
    final totalCredits = entries.fold<int>(0, (sum, e) => sum + e.credits);
    if (totalCredits == 0) return;
    final cgpa =
        entries.fold<double>(0, (sum, e) => sum + e.gpa * e.credits) /
            totalCredits;
    _cgpaStat = cgpa.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveLayout(
          mobile: (_) => _mobileBody(context, user),
          desktop: (_) => _desktopBody(context, user),
        ),
      ),
    );
  }

  Widget _mobileBody(BuildContext context, User? user) {
    final screenWidth = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.045,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _headerRow(context),
          const SizedBox(height: 20),
          _profileCard(user),
          const SizedBox(height: 20),
          _statsGrid(context),
          const SizedBox(height: 30),
          _menuColumn(context),
          const SizedBox(height: 30),
          _logoutButton(context),
        ],
      ),
    );
  }

  Widget _desktopBody(BuildContext context, User? user) {
    final width = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.pagePadding(width)),
      child: MaxWidthContent(
        maxWidth: 960,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerRow(context),
            SizedBox(height: AppSpacing.sectionGap(width)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 340,
                  child: Column(
                    children: [
                      _profileCard(user),
                      const SizedBox(height: 20),
                      _statsGrid(context),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _menuColumn(context),
                      const SizedBox(height: 24),
                      _logoutButton(context),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerRow(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: AppTheme.cardDecoration(
              color: Colors.white,
              shadowOffset: const Offset(2, 2),
            ),
            child: const Icon(
              Icons.chevron_left,
              size: 28,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Text(
          'Profile',
          style: TextStyle(
            fontFamily: 'Lexend Mega',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _profileCard(User? user) {
    return Container(
                width: double.infinity,
                decoration: AppTheme.cardDecoration(
                  color: AppColors.primaryYellow,
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 76, 16),
                          child: Row(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.black, width: 2),
                                  color: Colors.grey[300],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: user?.photoURL != null
                                    ? Image.network(
                                        user!.photoURL!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.black54,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.black54,
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.displayName?.isNotEmpty == true
                                          ? user!.displayName!
                                          : 'Student',
                                      style: const TextStyle(
                                        fontFamily: 'Lexend Mega',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.email_outlined,
                                            size: 14,
                                            color: Colors.black
                                                .withValues(alpha: 0.6)),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            user?.email ?? '',
                                            style: TextStyle(
                                              fontFamily: 'Public Sans',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black
                                                  .withValues(alpha: 0.7),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_department != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _department!.toUpperCase(),
                                          style: TextStyle(
                                            fontFamily: 'Lexend Mega',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primaryYellow,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: IconButton(
                              tooltip: 'Edit profile',
                              padding: EdgeInsets.zero,
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen(),
                                ),
                              ).then((_) => _loadStats()),
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 24,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_collegeName != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INSTITUTION',
                              style: TextStyle(
                                fontFamily: 'Public Sans',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.black.withValues(alpha: 0.45),
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.home_outlined,
                                    size: 18,
                                    color: Colors.black.withValues(alpha: 0.6)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _collegeName!,
                                    style: const TextStyle(
                                      fontFamily: 'Public Sans',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _statsGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Attendance',
                _attendanceStat,
                AppColors.accentGreen,
                onTap: () {
                  if (widget.onTabSwitch != null) {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                    widget.onTabSwitch!(1);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AttendanceScreen()),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'CGPA',
                _cgpaStat,
                AppColors.accentBlue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CgpaCalculatorScreen()),
                ).then((_) => _loadStats()),
                emptyHint: 'Tap to\ncalculate',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSemesterCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SyllabusSelectionScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Files Uploaded',
                _filesUploaded,
                AppColors.accentPurple,
                onTap: () {
                  if (widget.onTabSwitch != null) {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                    widget.onTabSwitch!(3);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ResourcesHubScreen()),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _menuColumn(BuildContext context) {
    return Column(
      children: [
        _buildMenuItem(
          context,
          'Settings',
          Icons.settings,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _buildMenuItem(
          context,
          'Help & Support',
          Icons.help_outline,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HelpScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _buildMenuItem(
          context,
          'About',
          Icons.info_outline,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AboutScreen()),
          ),
        ),
      ],
    );
  }

  Widget _logoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () async {
          try {
            await AuthService.instance.signOut();
          } catch (_) {}
          if (!context.mounted) return;
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const CollegeSelectionScreen()),
            (_) => false,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.black, width: 2),
          ),
        ),
        icon: const Icon(Icons.logout, color: Colors.black),
        label: const Text(
          'Logout',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildSemesterCard({VoidCallback? onTap}) {
    final parts = <String>[];
    if (_subjectCount != null) parts.add('$_subjectCount subjects');
    if (_totalCredits != null) parts.add('$_totalCredits credits');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(color: AppColors.primaryYellow),
        child: Column(
          children: [
            Text(
              _semesterStat,
              style: const TextStyle(
                fontFamily: 'Lexend Mega',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Semester',
              style: TextStyle(
                fontFamily: 'Public Sans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            if (parts.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                parts.join('  •  '),
                style: TextStyle(
                  fontFamily: 'Public Sans',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color, {
    VoidCallback? onTap,
    String? emptyHint,
  }) {
    final isEmpty = value == '--' && emptyHint != null && emptyHint.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(color: color),
        child: Column(
          children: [
            if (isEmpty) ...[
              const Text(
                '--',
                style: TextStyle(
                  fontFamily: 'Lexend Mega',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ] else
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Lexend Mega',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Public Sans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(color: Colors.white),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.black),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Public Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black),
          ],
        ),
      ),
    );
  }
}

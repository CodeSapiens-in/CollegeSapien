import 'package:codesapiens/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/attendance_notification_service.dart';
import '../../services/app_theme_notifier.dart';
import '../../services/auth_service.dart';
import '../../screens/auth/college_selection_screen.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_color_scheme.dart';
import '../../widgets/responsive_layout.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _classReminders = true;
  bool _attendanceAlerts = true;
  double _attendanceThreshold = 75.0;
  bool _sendingTest = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    });
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This permanently deletes your account and all associated data (attendance, timetables, CGPA). This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AuthService.instance.deleteAccount();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CollegeSelectionScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() => _sendingTest = true);
    try {
      await AttendanceNotificationService.instance.scheduleTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification scheduled — check in 10 seconds!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'Lexend Mega',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            letterSpacing: 0,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListenableBuilder(
        listenable: AppThemeNotifier.instance,
        builder: (context, _) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: MaxWidthContent(
              maxWidth: 600,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF191C1E),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSwitchTile(
                  'Enable Notifications',
                  _notificationsEnabled,
                  (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  'Class Reminders',
                  _classReminders,
                  (value) {
                    setState(() {
                      _classReminders = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  'Attendance Alerts',
                  _attendanceAlerts,
                  (value) {
                    setState(() {
                      _attendanceAlerts = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _sendingTest ? null : _sendTestNotification,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration:
                        AppTheme.cardDecoration(color: AppColors.accentGreen),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined,
                            size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Send Test Notification',
                                style: TextStyle(
                                  fontFamily: 'Public Sans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                _sendingTest
                                    ? 'Firing in 10 s…'
                                    : 'Fires in 10 seconds',
                                style: const TextStyle(
                                  fontFamily: 'Public Sans',
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_sendingTest)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Attendance',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF191C1E),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration(color: Colors.white),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Alert Threshold',
                            style: TextStyle(
                              fontFamily: 'Public Sans',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            '${_attendanceThreshold.toInt()}%',
                            style: const TextStyle(
                              fontFamily: 'Lexend Mega',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _attendanceThreshold,
                        min: 50,
                        max: 90,
                        divisions: 8,
                        activeColor: AppColors.primaryYellow,
                        // inactiveColor: Colors.grey[300],
                        onChanged: (value) {
                          setState(() {
                            _attendanceThreshold = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Theme',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF191C1E),
                  ),
                ),
                const SizedBox(height: 16),
                _buildThemePicker(),
                const SizedBox(height: 30),
                const Text(
                  'Account',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF191C1E),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _confirmDeleteAccount,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration:
                        AppTheme.cardDecoration(color: const Color(0xFFFFCDD2)),
                    child: const Row(
                      children: [
                        Icon(Icons.delete_forever_outlined,
                            color: Colors.red, size: 22),
                        SizedBox(width: 12),
                        Text(
                          'Delete Account',
                          style: TextStyle(
                            fontFamily: 'Public Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'About',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF191C1E),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration:
                      AppTheme.cardDecoration(color: AppColors.accentBlue),
                  child: Column(
                    children: [
                      const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontFamily: 'Lexend Mega',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _appVersion.isEmpty ? ' ' : 'Version $_appVersion',
                        style: TextStyle(
                          fontFamily: 'Public Sans',
                          fontSize: 14,
                          color: Colors.black.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemePicker() {
    final current = AppThemeNotifier.instance.current;
    return Row(
      children: AppThemes.all.map((scheme) {
        final isActive = scheme.id == current.id;
        return Expanded(
          child: GestureDetector(
            onTap: () => AppThemeNotifier.instance.setTheme(scheme),
            child: Container(
              margin: EdgeInsets.only(
                right: scheme == AppThemes.all.last ? 0 : 10,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: scheme.primaryYellow,
                border: Border.all(
                  color: isActive ? Colors.black : Colors.black38,
                  width: isActive ? 2.5 : 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: isActive
                    ? const [
                        BoxShadow(offset: Offset(3, 3), color: Colors.black)
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  // Mini colour swatch row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _swatch(scheme.accentGreen),
                      _swatch(scheme.accentPink),
                      _swatch(scheme.accentBlue),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scheme.name,
                    style: const TextStyle(
                      fontFamily: 'Public Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 4),
                    const Icon(Icons.check_circle_outline, size: 14),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _swatch(Color color) => Container(
        width: 14,
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black45, width: 0.5),
        ),
      );

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: AppTheme.cardDecoration(color: Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Public Sans',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryYellow,
            activeTrackColor: AppColors.primaryYellow.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../models/timetable_models.dart';
import '../../screens/attendance/mark_attendance_screen.dart';
import '../app_navigation.dart';
import '../attendance_service.dart';

const _presentAction = 'attendance_present';
const _absentAction = 'attendance_absent';
const _otherAction = 'attendance_other';
const _pendingActionsKey = 'pending_attendance_actions';
const _testSubjectKey = 'notification_test_subject';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  DartPluginRegistrant.ensureInitialized();
  AttendanceNotificationService.handleNotificationResponse(response);
}

class AttendanceNotificationService {
  AttendanceNotificationService._();

  static final AttendanceNotificationService instance =
      AttendanceNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static Map<String, dynamic>? _pendingNavigationPayload;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    final ios = DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          'attendance_actions',
          actions: [
            DarwinNotificationAction.plain(_presentAction, 'Present'),
            DarwinNotificationAction.plain(_absentAction, 'Absent'),
            DarwinNotificationAction.plain(
              _otherAction,
              'Other',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      settings: InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true && response != null) {
      await handleNotificationResponse(response);
    }

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    bool granted = true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final result = await android.requestNotificationsPermission();
      granted = result ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final result = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = result ?? false;
    }

    return granted;
  }

  Future<bool> hasPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    // On iOS, attempt a silent check via requestPermissions (returns existing grant state)
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final result = await ios.checkPermissions();
      return result?.isEnabled ?? false;
    }
    return true;
  }

  Future<void> scheduleTestNotification() async {
    await initialize();

    final already = await hasPermission();
    if (!already) {
      final granted = await requestPermission();
      if (!granted) return;
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_testSubjectKey);
    String subjectId = 'test-subject';
    String subjectCode = 'TEST101';
    if (cached != null) {
      try {
        final m = jsonDecode(cached) as Map<String, dynamic>;
        subjectId = m['id'] as String? ?? subjectId;
        subjectCode = m['code'] as String? ?? subjectCode;
      } catch (_) {}
    }

    final scheduleMode = await _resolveScheduleMode();
    await _plugin.zonedSchedule(
      id: 9999,
      title: 'Mark $subjectCode attendance',
      body: '09:00 - 10:00',
      scheduledDate:
          tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: scheduleMode,
      payload: jsonEncode({
        'subjectId': subjectId,
        'subjectCode': subjectCode,
        'dateKey': _dateKey(DateTime.now()),
        'slotStartTime': '09:00',
        'slotEndTime': '10:00',
      }),
    );
  }

  /// Returns exact mode if the user has granted the alarm permission,
  /// otherwise opens the system settings page and returns inexact mode
  /// so scheduling still works immediately.
  Future<AndroidScheduleMode> _resolveScheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return AndroidScheduleMode.exactAllowWhileIdle;

    final canExact = await android.canScheduleExactNotifications() ?? false;
    if (!canExact) {
      // Open "Alarms & reminders" in system settings so the user can grant it.
      // Scheduling continues with inexact mode so the notification still fires.
      await android.requestExactAlarmsPermission();
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  Future<void> scheduleForTimetable(List<TimetableSubject> subjects) async {
    await initialize();
    await requestPermission();
    await _plugin.cancelAll();

    final firstReal = subjects.firstWhere(
      (s) => s.classes.any((c) => c.type != 'BREAK'),
      orElse: () => subjects.isNotEmpty
          ? subjects.first
          : TimetableSubject(
              id: 'test-subject', name: 'Test', code: 'TEST101', classes: []),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _testSubjectKey,
      jsonEncode({'id': firstReal.id, 'code': firstReal.code}),
    );

    final scheduleMode = await _resolveScheduleMode();
    final now = DateTime.now();
    var scheduled = 0;
    for (var dayOffset = 0; dayOffset < 14; dayOffset += 1) {
      final date = DateTime(now.year, now.month, now.day).add(
        Duration(days: dayOffset),
      );
      final day = _dayCode(date);
      for (final subject in subjects) {
        for (final slot in subject.classes) {
          if (slot.day != day || slot.type == 'BREAK') continue;
          final scheduledAt = _dateWithTime(date, slot.endTime);
          if (!scheduledAt.isAfter(now)) continue;

          scheduled += 1;
          await _plugin.zonedSchedule(
            id: scheduled,
            title: 'Mark ${subject.code} attendance',
            body: '${slot.startTime} - ${slot.endTime}'
                '${slot.room.isEmpty ? '' : ' · ${slot.room}'}',
            scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
            notificationDetails: _notificationDetails(),
            androidScheduleMode: scheduleMode,
            payload: jsonEncode({
              'subjectId': subject.id,
              'subjectCode': subject.code,
              'dateKey': _dateKey(date),
              'slotStartTime': slot.startTime,
              'slotEndTime': slot.endTime,
            }),
          );
        }
      }
    }
  }

  Future<void> syncPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pendingActionsKey) ?? [];
    if (raw.isEmpty) return;

    final remaining = <String>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        await _markFromPayload(decoded, decoded['status']?.toString());
      } catch (_) {
        remaining.add(item);
      }
    }
    await prefs.setStringList(_pendingActionsKey, remaining);
  }

  void openPendingNavigation() {
    final payload = _pendingNavigationPayload;
    if (payload == null) return;
    _pendingNavigationPayload = null;
    _openMarkAttendance(payload);
  }

  static Future<void> handleNotificationResponse(
    NotificationResponse response,
  ) async {
    if (response.payload == null || response.payload!.isEmpty) return;
    final payload = jsonDecode(response.payload!) as Map<String, dynamic>;

    if (response.actionId == _otherAction || response.actionId == null) {
      _openMarkAttendance(payload);
      return;
    }

    final status = switch (response.actionId) {
      _presentAction => 'Present',
      _absentAction => 'Absent',
      _ => null,
    };
    if (status == null) return;

    try {
      try {
        await Firebase.initializeApp();
      } catch (_) {}
      await _markFromPayload(payload, status);
    } catch (_) {
      await _storePendingAction(payload, status);
    }
  }

  static Future<void> _markFromPayload(
    Map<String, dynamic> payload,
    String? status,
  ) async {
    if (status == null) return;
    await AttendanceService().markAttendance(
      subjectId: payload['subjectId']?.toString() ?? '',
      dateKey: payload['dateKey']?.toString(),
      slotStartTime: payload['slotStartTime']?.toString(),
      slotEndTime: payload['slotEndTime']?.toString(),
      status: status,
    );
  }

  static Future<void> _storePendingAction(
    Map<String, dynamic> payload,
    String status,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingActionsKey) ?? [];
    pending.add(jsonEncode({...payload, 'status': status}));
    await prefs.setStringList(_pendingActionsKey, pending);
  }

  static void _openMarkAttendance(Map<String, dynamic> payload) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      _pendingNavigationPayload = payload;
      return;
    }
    navigator.push(
      MaterialPageRoute(
        builder: (_) => MarkAttendanceScreen(
          preselectedDateKey: payload['dateKey']?.toString(),
          preselectedSubjectId: payload['subjectId']?.toString(),
          preselectedSlotStartTime: payload['slotStartTime']?.toString(),
          preselectedSlotEndTime: payload['slotEndTime']?.toString(),
        ),
      ),
    );
  }

  NotificationDetails _notificationDetails() {
    const android = AndroidNotificationDetails(
      'attendance_slots',
      'Attendance reminders',
      channelDescription: 'Class-end attendance reminders',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      actions: [
        AndroidNotificationAction(_presentAction, 'Present'),
        AndroidNotificationAction(_absentAction, 'Absent'),
        AndroidNotificationAction(
          _otherAction,
          'Other',
          showsUserInterface: true,
        ),
      ],
    );
    const ios =
        DarwinNotificationDetails(categoryIdentifier: 'attendance_actions');
    return const NotificationDetails(android: android, iOS: ios);
  }

  static String _dayCode(DateTime date) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[date.weekday - 1];
  }

  static String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  static DateTime _dateWithTime(DateTime date, String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}

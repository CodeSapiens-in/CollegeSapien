import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../models/api_models.dart';
import '../../models/timetable_models.dart';
import '../../models/event_models.dart';
import '../../services/api_service.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/college_service.dart';
import '../profile/profile_screen.dart';
import '../../models/syllabus_models.dart';
import '../../services/syllabus_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/responsive_layout.dart';
import '../attendance/mark_attendance_screen.dart';
import '../syllabus/syllabus_selection_screen.dart';
import '../timetable_list_screen.dart';
import '../ai_features/resume_roast_screen.dart';
import 'events_all_screen.dart';
import 'create_event_screen.dart';
import '../../providers/app_state_notifier.dart';

// ─── Timetable class entry ────────────────────────────────────────────────────

class _ClassEntry {
  final String subjectId;
  final String subjectCode;
  final String subjectName;
  final String dateKey;
  final String startTime;
  final String endTime;
  final String room;

  const _ClassEntry({
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    required this.dateKey,
    required this.startTime,
    required this.endTime,
    required this.room,
  });
}

// ─── Day helpers ──────────────────────────────────────────────────────────────

String _todayCode() {
  const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  return days[DateTime.now().weekday - 1];
}

String _dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

int _toMin(String t) {
  final p = t.split(':');
  if (p.length < 2) return 0;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

String _fmt(String t) {
  final p = t.split(':');
  if (p.length < 2) return t;
  final h = int.tryParse(p[0]) ?? 0;
  final m = int.tryParse(p[1]) ?? 0;
  final suf = h >= 12 ? 'PM' : 'AM';
  final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
  return '${dh.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $suf';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final Function(int)? onTabSwitch;
  final bool showProfileButton;

  const HomeScreen({
    super.key,
    this.onTabSwitch,
    this.showProfileButton = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AttendanceSummary> _summaries = [];
  List<_ClassEntry> _todayClasses = [];
  List<EventItem> _allEvents = [];
  List<EventItem> _shownEvents = [];
  bool _loadingTimetable = true;
  bool _loadingEvents = true;
  int _semester = 0;
  final Set<String> _markedSlots = {};
  List<SavedSubject> _savedSubjects = [];
  bool _showingCurriculumFallback = false;
  // True once we know whether the user has subjects (from cache or network)
  // — gates the "configure your subjects" empty state so it doesn't flash
  // while the first load is still in flight.
  bool _subjectsResolved = false;
  String _userName = '';
  String _collegeName = '';
  String _department = '';

  static String get _todayMarkedKey =>
      'marked_slots_${_dateKey(DateTime.now())}';

  Future<void> _loadMarkedSlots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_todayMarkedKey) ?? [];
      if (mounted) setState(() => _markedSlots.addAll(saved));

      // Remove entries from previous days to avoid unbounded growth
      final keysToRemove = prefs
          .getKeys()
          .where((k) => k.startsWith('marked_slots_') && k != _todayMarkedKey)
          .toList();
      for (final k in keysToRemove) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  Future<void> _persistMarkedSlot(String slotKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_todayMarkedKey) ?? [];
      if (!saved.contains(slotKey)) {
        saved.add(slotKey);
        await prefs.setStringList(_todayMarkedKey, saved);
      }
    } catch (_) {}
  }

  static final List<Color> _cardColors = [
    AppColors.accentGreen,
    AppColors.accentPink,
    AppColors.accentPurple,
    AppColors.primaryYellow,
    AppColors.accentBlue,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Paint whatever's cached first, then trigger the network refresh.
      _initializeStateFromProvider();
      final appState = Provider.of<AppStateNotifier>(context, listen: false);
      appState.addListener(_onAppStateChanged);
      _load();
    });
  }

  @override
  void dispose() {
    try {
      final appState = Provider.of<AppStateNotifier>(context, listen: false);
      appState.removeListener(_onAppStateChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final appState = Provider.of<AppStateNotifier>(context, listen: false);
    final user = appState.userProfile;
    if (user != null) {
      if (user.semester != _semester ||
          user.name != _userName ||
          (user.collegeName ?? '') != _collegeName ||
          (user.department ?? '') != _department) {
        setState(() {
          _semester = user.semester;
          _userName = user.name;
          _collegeName = user.collegeName ?? '';
          _department = user.department ?? '';
          // Old subjects/attendance may no longer apply — clear until the
          // reload below resolves them for the new profile.
          _savedSubjects = appState.savedSubjects ?? [];
          _showingCurriculumFallback = appState.savedSubjectsFromCurriculum;
          _subjectsResolved = false;
        });
        _load(); // Reload all data for the new semester/college/department
        return;
      }
    }
    _initializeStateFromProvider();
  }

  void _initializeStateFromProvider() {
    if (!mounted) return;
    try {
      final appState = Provider.of<AppStateNotifier>(context, listen: false);

      // Load data from provider if available
      if (appState.attendanceSummary != null) {
        setState(() => _summaries = appState.attendanceSummary!);
      }
      if (appState.timetableSubjects != null) {
        _processTodayClasses(appState.timetableSubjects!);
        setState(() => _loadingTimetable = false);
      }
      if (appState.events != null) {
        setState(() {
          _allEvents = appState.events!;
          _shownEvents = _allEvents.take(2).toList();
          _loadingEvents = false;
        });
      }
      if (appState.userProfile != null) {
        setState(() {
          _semester = appState.userProfile!.semester;
          _userName = appState.userProfile!.name;
          _collegeName = appState.userProfile!.collegeName ?? '';
          _department = appState.userProfile!.department ?? '';
        });
      }
      if (appState.savedSubjects != null) {
        setState(() {
          _savedSubjects = appState.savedSubjects!;
          _showingCurriculumFallback = appState.savedSubjectsFromCurriculum;
          _subjectsResolved = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    // Fire all load methods concurrently in the background
    _loadProfile();
    _loadEvents();
    _loadMarkedSlots();
  }

  Future<void> _loadProfile() async {
    final appState = Provider.of<AppStateNotifier>(context, listen: false);
    var user = appState.userProfileStale;

    if (user != null) {
      if (mounted) {
        setState(() {
          _semester = user.semester;
          _userName = user.name;
          _collegeName = user.collegeName ?? '';
          _department = user.department ?? '';
        });
        if (appState.savedSubjects != null) {
          setState(() {
            _savedSubjects = appState.savedSubjects!;
            _showingCurriculumFallback = appState.savedSubjectsFromCurriculum;
            _subjectsResolved = true;
          });
        }
      }
    }

    // Cache is still fresh (e.g. splash screen just synced) — skip hitting
    // the network again so opening the home screen doesn't always re-sync.
    // Subjects must have been resolved too, or we'd never run the curriculum
    // fallback below.
    if (appState.hasFreshHomeData && appState.savedSubjects != null) return;

    try {
      // One sync call now returns profile + attendance + timetable + saved
      // subjects together, instead of four separate network round trips.
      final result = await AuthService.instance.syncProfile();
      final freshUser = result.user;
      if (freshUser == null) return;

      // Update local state before touching appState: setUserProfile()
      // notifies _onAppStateChanged synchronously, which compares against
      // _semester/_userName — updating those first avoids it seeing a false
      // "semester changed" mismatch and re-triggering _load().
      if (mounted) {
        setState(() {
          _semester = freshUser.semester;
          _userName = freshUser.name;
          _collegeName = freshUser.collegeName ?? '';
          _department = freshUser.department ?? '';
        });
      }
      appState.setUserProfile(freshUser);

      if (result.attendanceSummary != null) {
        appState.setAttendanceSummary(result.attendanceSummary!);
        if (mounted) setState(() => _summaries = result.attendanceSummary!);
      }

      if (result.timetableSubjects != null) {
        appState.setTimetableSubjects(result.timetableSubjects!);
        if (mounted) {
          setState(() {
            _processTodayClasses(result.timetableSubjects!);
            _loadingTimetable = false;
          });
        }
      } else if (mounted) {
        setState(() => _loadingTimetable = false);
      }

      final saved = result.savedSubjects?.subjects;
      if (saved != null && saved.isNotEmpty) {
        appState.setSavedSubjects(saved);
        if (mounted) {
          setState(() {
            _savedSubjects = saved;
            _showingCurriculumFallback = false;
            _subjectsResolved = true;
          });
        }
      } else {
        final syllabusService = SyllabusService();
        // No saved subjects — try curriculum fallback
        var fallbackApplied = false;
        try {
          final collegeService = CollegeService();
          final colleges = await collegeService.listColleges();
          final departmentsList = await collegeService.listDepartments();
          final college =
              colleges.where((c) => c.id == freshUser.collegeId).firstOrNull;
          final collegeCode = college?.code;
          final deptObj = departmentsList
              .where((d) => d.name == freshUser.department)
              .firstOrNull;
          final courseCode = deptObj?.code;
          if (collegeCode != null && courseCode != null) {
            final bundle = await syllabusService.getCurriculum(
              collegeCode: collegeCode,
              courseCode: courseCode,
            );
            final subjects = syllabusService.getSubjectsForSemester(
              bundle,
              semester: freshUser.semester,
            );
            if (subjects.isNotEmpty) {
              final fallbackSubjects = subjects
                  .map((s) => SavedSubject(
                        subjectCode: s.subjectCode,
                        subjectName: s.subjectName,
                        credits: s.credits,
                        isElective: s.isElective,
                        electiveType: s.electiveType,
                        category: s.category,
                      ))
                  .toList();
              appState.setSavedSubjects(fallbackSubjects, fromCurriculum: true);
              fallbackApplied = true;
              if (mounted) {
                setState(() {
                  _savedSubjects = fallbackSubjects;
                  _showingCurriculumFallback = true;
                  _subjectsResolved = true;
                });
              }
            }
          }
        } catch (_) {}
        if (!fallbackApplied && mounted) {
          // Nothing saved and no usable curriculum — show the configure
          // prompt instead of stale subjects from a previous profile.
          setState(() {
            _savedSubjects = [];
            _showingCurriculumFallback = false;
            _subjectsResolved = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadAttendance() async {
    final appState = Provider.of<AppStateNotifier>(context, listen: false);
    if (appState.attendanceSummary != null && _summaries.isEmpty) {
      if (mounted) setState(() => _summaries = appState.attendanceSummary!);
    }

    try {
      final s = await AttendanceService().getSummary();
      appState.setAttendanceSummary(s);
      if (mounted) {
        setState(() => _summaries = s);
      }
    } catch (_) {}
  }

  void _processTodayClasses(List<TimetableSubject> subjects) {
    final today = _todayCode();
    final todayDateKey = _dateKey(DateTime.now());
    final entries = <_ClassEntry>[];
    for (final sub in subjects) {
      for (final cls in sub.classes) {
        if (cls.day == today && cls.type != 'BREAK') {
          entries.add(_ClassEntry(
            subjectId: sub.id,
            subjectCode: sub.code,
            subjectName: sub.name,
            dateKey: todayDateKey,
            startTime: cls.startTime,
            endTime: cls.endTime,
            room: cls.room,
          ));
        }
      }
    }
    entries.sort((a, b) => _toMin(a.startTime).compareTo(_toMin(b.startTime)));
    _todayClasses = entries;
  }

  Future<void> _markSlotPresent(_ClassEntry entry) async {
    final slotKey = '${entry.subjectId}_${entry.startTime}';
    try {
      await AttendanceService().markAttendance(
        subjectId: entry.subjectId,
        dateKey: entry.dateKey,
        slotStartTime: entry.startTime,
        slotEndTime: entry.endTime,
        status: 'Present',
      );
      if (mounted) setState(() => _markedSlots.add(slotKey));
      await _persistMarkedSlot(slotKey);
      await _loadAttendance();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${entry.subjectCode} marked Present'),
          action: SnackBarAction(
            label: 'Change',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MarkAttendanceScreen(
                    preselectedDateKey: entry.dateKey,
                    preselectedSubjectId: entry.subjectId,
                    preselectedSlotStartTime: entry.startTime,
                    preselectedSlotEndTime: entry.endTime,
                  ),
                ),
              ).then((_) => _loadAttendance());
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loadEvents() async {
    final appState = Provider.of<AppStateNotifier>(context, listen: false);
    if (appState.events != null && _allEvents.isEmpty) {
      if (mounted) {
        setState(() {
          _allEvents = appState.events!;
          _shownEvents = _allEvents.take(2).toList();
          _loadingEvents = false;
        });
      }
      return;
    }

    try {
      final raw = await ApiService.instance.get('/events') as List<dynamic>;
      final all = raw
          .map((e) => EventItem.fromJson(e as Map<String, dynamic>))
          .where((e) => e.eventName.isNotEmpty)
          .toList();

      // Only upcoming events (date >= today), earliest first.
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      final shown = all.where((e) {
        final d = DateTime.tryParse(e.eventDate);
        return d != null && !d.isBefore(todayDate);
      }).toList()
        ..sort((a, b) => DateTime.parse(a.eventDate)
            .compareTo(DateTime.parse(b.eventDate)));

      appState.setEvents(shown);
      if (mounted) {
        setState(() {
          _allEvents = shown;
          _shownEvents = shown.take(2).toList();
          _loadingEvents = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  // ─── Computed ──────────────────────────────────────────────────────────────

  bool get _isDayOver {
    if (_todayClasses.isEmpty) return false;
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    return _todayClasses.every((c) => _toMin(c.endTime) < nowMin);
  }

  _ClassEntry? get _nextClass {
    if (_isDayOver || _todayClasses.isEmpty) return null;
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    for (final c in _todayClasses) {
      if (nowMin >= _toMin(c.startTime) && nowMin < _toMin(c.endTime)) return c;
    }
    for (final c in _todayClasses) {
      if (_toMin(c.startTime) > nowMin) return c;
    }
    return null;
  }

  double get _avgPct {
    if (_summaries.isEmpty) return 0;
    return _summaries.map((s) => s.percentage).reduce((a, b) => a + b) /
        _summaries.length;
  }

  int get _totalSkip => _summaries.fold(0, (s, e) => s + e.safeToSkip);

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveLayout(
          mobile: (_) => _mobileBody(context),
          desktop: (_) => _desktopBody(context),
        ),
      ),
    );
  }

  // ─── Mobile layout (unchanged single-column feed) ─────────────────────────

  Widget _mobileBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 24),
          _statCardsRow(),
          const SizedBox(height: 24),
          ..._timetableSection(context),
          ..._subjectsSection(context),
          const SizedBox(height: 24),
          ..._eventsSectionWithHeader(context),
          ..._aiFeaturesSection(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ─── Desktop layout: 2-column dashboard grid ──────────────────────────────
  //
  // Left column carries the "browse" content (timetable/subjects carousels,
  // AI features); right column carries "at a glance" stats (attendance,
  // next-class, events feed) — turning the mobile single feed into an
  // actual dashboard instead of a stretched single column.

  Widget _desktopBody(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.pagePadding(width)),
      child: MaxWidthContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            SizedBox(height: AppSpacing.sectionGap(width)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 65,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._timetableSection(context),
                      ..._subjectsSection(context),
                      ..._aiFeaturesSection(),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.lg),
                Expanded(
                  flex: 35,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statCardsRow(),
                      SizedBox(height: AppSpacing.sectionGap(width)),
                      ..._eventsSectionWithHeader(context),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─── Shared section builders (used by both mobile and desktop layouts) ────

  Widget _statCardsRow() {
    return Row(
      children: [
        Expanded(child: _attendanceCard()),
        const SizedBox(width: 16),
        Expanded(child: _isDayOver ? _dayOverCard() : _nextClassCard()),
      ],
    );
  }

  List<Widget> _timetableSection(BuildContext context) {
    return [
      _sectionHeader("Today's Timetable", onShowAll: () {
        // Switch the persistent bottom nav / rail to the Timetable tab
        // instead of pushing a new route on top of it, so the nav chrome
        // stays visible (same screen MainNavigation already shows at
        // index 2 — see main_navigation.dart's _navItems).
        if (widget.onTabSwitch != null) {
          widget.onTabSwitch!(2);
        } else {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TimetableListScreen()));
        }
      }),
      const SizedBox(height: 12),
      _timetableCarousel(),
    ];
  }

  List<Widget> _subjectsSection(BuildContext context) {
    if (_savedSubjects.isNotEmpty) {
      return [
        const SizedBox(height: 24),
        _sectionHeader(
          "${_semester == 1 ? '1st' : _semester == 2 ? '2nd' : _semester == 3 ? '3rd' : '${_semester}th'} Semester Subjects",
          onShowAll: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SyllabusSelectionScreen())),
        ),
        const SizedBox(height: 12),
        if (_showingCurriculumFallback)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SyllabusSelectionScreen()),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.black.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'These are default subjects for your semester. Tap to update with your electives.',
                        style: TextStyle(
                          fontFamily: 'Public Sans',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        _syllabusCarousel(),
      ];
    } else if (_subjectsResolved && _semester > 0) {
      return [
        const SizedBox(height: 24),
        _sectionHeader(
          "${_semester == 1 ? '1st' : _semester == 2 ? '2nd' : _semester == 3 ? '3rd' : '${_semester}th'} Semester Subjects",
        ),
        const SizedBox(height: 12),
        _configureSubjectsCard(),
      ];
    }
    return const [];
  }

  List<Widget> _eventsSectionWithHeader(BuildContext context) {
    return [
      _sectionHeader(
        "Upcoming Events",
        trailing: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateEventScreen(),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryYellow,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(offset: Offset(2, 2), color: Colors.black)
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.add, size: 10, color: Colors.black),
                SizedBox(width: 2),
                Text(
                  'SUGGEST',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.11,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
        onShowAll: _allEvents.isEmpty
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventsAllScreen(events: _allEvents),
                  ),
                ),
      ),
      const SizedBox(height: 12),
      _eventsSection(),
    ];
  }

  List<Widget> _aiFeaturesSection() {
    if (_semester < 4) return const [];
    return [
      const SizedBox(height: 24),
      _sectionHeader('AI Features'),
      const SizedBox(height: 12),
      _resumeRoastCard(),
    ];
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _userName.isEmpty
                    ? 'Hi there'
                    : 'Hi ${_userName.split(' ').first}',
                style: const TextStyle(
                  fontFamily: 'Lexend Mega',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: Colors.black,
                ),
              ),
            ),
            if (widget.showProfileButton)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(onTabSwitch: widget.onTabSwitch),
                  ),
                ),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue,
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(offset: Offset(1, 1), color: Colors.black)
                    ],
                  ),
                  child: const Icon(Icons.person, size: 22),
                ),
              ),
          ],
        ),
        if (_collegeName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _collegeName.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Public Sans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Colors.black.withValues(alpha: 0.5),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  // ─── Attendance card ───────────────────────────────────────────────────────

  Widget _attendanceCard() {
    final hasData = _summaries.isNotEmpty;
    final pctStr = hasData ? _avgPct.toStringAsFixed(0) : '--';
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.primaryYellow,
        border: Border.all(color: Colors.black, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(offset: Offset(1, 1), color: Colors.black)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6.5),
        child: Stack(
          children: [
            _shineStripes(const Color(0xFFFCD150)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CURRENT ATTENDANCE',
                        style: TextStyle(
                          fontFamily: 'Public Sans',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: pctStr,
                              style: TextStyle(
                                fontFamily: 'Lexend Mega',
                                fontSize: 54,
                                fontWeight: FontWeight.w700,
                                letterSpacing: hasData ? -2.0 : 0,
                                color: Colors.black,
                                height: 1.0,
                              ),
                            ),
                            if (hasData)
                              const TextSpan(
                                text: '%',
                                style: TextStyle(
                                  fontFamily: 'Lexend Mega',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1.0,
                                  color: Colors.black,
                                  height: 1.0,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Safe To Skip : $_totalSkip Classes',
                              style: const TextStyle(
                                fontFamily: 'Public Sans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _progressBar(
                          hasData ? _avgPct / 100 : 0, pctStr, hasData),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressBar(double progress, String label, bool hasData) {
    final clamped = progress.clamp(0.0, 1.0);
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      final fill = (w * clamped).clamp(36.0, w);
      return Container(
        height: 27,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.07), blurRadius: 14)
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              width: fill,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    hasData ? '$label%' : '--',
                    style: const TextStyle(
                      fontFamily: 'Public Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ─── Next class card ───────────────────────────────────────────────────────

  Widget _nextClassCard() {
    final next = _nextClass;
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.primaryYellow,
        border: Border.all(color: Colors.black, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(offset: Offset(1, 1), color: Colors.black)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6.5),
        child: Stack(
          children: [
            _shineStripes(const Color(0xFFFCD150)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEXT CLASS',
                        style: TextStyle(
                          fontFamily: 'Public Sans',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        next?.subjectName ??
                            (_todayClasses.isEmpty
                                ? 'No classes set up'
                                : 'No more classes today'),
                        style: const TextStyle(
                          fontFamily: 'Lexend Mega',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: Colors.black,
                          height: 1.2,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (next != null && next.room.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          next.room,
                          style: TextStyle(
                            fontFamily: 'Public Sans',
                            fontSize: 12,
                            color: Colors.black.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  if (next != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${_fmt(next.startTime)} - ${_fmt(next.endTime)}',
                                style: const TextStyle(
                                  fontFamily: 'Public Sans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayOverCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MarkAttendanceScreen())),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.accentPink,
          border: Border.all(color: Colors.black, width: 1.5),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(offset: Offset(1, 2), color: Colors.black)
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.5),
          child: Stack(
            children: [
              _shineStripes(const Color(0xFFFFAAAA)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DAY IS OVER',
                          style: TextStyle(
                            fontFamily: 'Public Sans',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Mark Your\nAttendance',
                          style: TextStyle(
                            fontFamily: 'Lexend Mega',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: Colors.black,
                            height: 1.2,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Mark Now →',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Timetable carousel ────────────────────────────────────────────────────

  Widget _timetableCarousel() {
    if (_loadingTimetable) {
      return const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_todayClasses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(color: AppColors.accentGreen),
        child: const Text(
          'No classes today — enjoy your free day!',
          style: TextStyle(
              fontFamily: 'Public Sans',
              fontSize: 14,
              fontWeight: FontWeight.w600),
        ),
      );
    }
    return SizedBox(
      height: 115,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _todayClasses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _timetableCard(
            _todayClasses[i], _cardColors[i % _cardColors.length]),
      ),
    );
  }

  Widget _timetableCard(_ClassEntry entry, Color color) {
    final slotKey = '${entry.subjectId}_${entry.startTime}';
    final isMarked = _markedSlots.contains(slotKey);
    return GestureDetector(
      onDoubleTap: () => _markSlotPresent(entry),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color,
            border: Border.all(
              color: isMarked ? const Color(0xFF16A34A) : Colors.black,
              width: isMarked ? 2.5 : 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                offset: const Offset(1, 1),
                color: isMarked ? const Color(0xFF16A34A) : Colors.black,
              ),
              const BoxShadow(
                  offset: Offset(0, 2),
                  blurRadius: 24,
                  color: Color(0x1E003FB1)),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.05,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationZ(48 * math.pi / 180)
                      ..scaleByDouble(1.0, -1.0, 1.0, 1.0),
                    child: Image.asset(
                      'assets/images/halftone.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmt(entry.startTime),
                    style: TextStyle(
                      fontFamily: 'Public Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withValues(alpha: 0.8),
                      letterSpacing: -0.12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.subjectName,
                    style: const TextStyle(
                      fontFamily: 'Lexend Mega',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      color: Colors.black,
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (entry.room.isNotEmpty)
                    Text(
                      entry.room,
                      style: TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
              if (isMarked)
                const Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(Icons.check_circle_outline,
                      size: 18, color: Color(0xFF16A34A)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Configure subjects empty state ────────────────────────────────────────

  Widget _configureSubjectsCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SyllabusSelectionScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accentBlue,
          border: Border.all(color: Colors.black, width: 1.5),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(offset: Offset(1, 1), color: Colors.black),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.menu_book_outlined, size: 32, color: Colors.black),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configure your subjects',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No subjects set up for this semester yet. Tap to add them.',
                    style: TextStyle(
                      fontFamily: 'Public Sans',
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 20, color: Colors.black),
          ],
        ),
      ),
    );
  }

  // ─── Syllabus carousel ─────────────────────────────────────────────────────

  Widget _syllabusCarousel() {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _savedSubjects.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = _savedSubjects[i];
          final color = s.isElective
              ? AppColors.accentPurple
              : _cardColors[i % _cardColors.length];
          final typeLabel = s.isElective ? 'ELECTIVE' : 'THEORY';
          return Container(
            width: 155,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.black, width: 1.5),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(offset: Offset(1, 1), color: Colors.black),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    typeLabel,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    s.subjectName,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: Colors.black,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (s.credits != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${s.credits}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'CR',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Events section ────────────────────────────────────────────────────────

  Widget _eventsSection() {
    if (_loadingEvents) {
      return const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_shownEvents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(color: AppColors.accentBlue),
        child: const Text('No upcoming events found.',
            style: TextStyle(fontFamily: 'Public Sans', fontSize: 14)),
      );
    }
    return Column(
      children: _shownEvents
          .map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _eventCard(e),
              ))
          .toList(),
    );
  }

  String? _formatEventDate(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return null;
    return DateFormat('EEE, d MMM yyyy').format(d);
  }

  Widget _eventCard(EventItem event) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(event.eventLink);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.accentBlue,
            border: Border.all(color: Colors.black, width: 1.5),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(offset: Offset(4, 4), color: Colors.black)
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PolkaDotPainter(
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.tagPurple,
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [
                        BoxShadow(offset: Offset(2, 2), color: Colors.black)
                      ],
                    ),
                    child: Text(
                      event.location.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.14,
                        color: Color(0xFF191C1E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    event.eventName,
                    style: const TextStyle(
                      fontFamily: 'Lexend Mega',
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -1.0, // fixed: was -3.96
                      color: Colors.black,
                      height: 1.2,
                    ),
                  ),
                  if (_formatEventDate(event.eventDate) != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _formatEventDate(event.eventDate)!,
                      style: TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (event.communityLogo.isNotEmpty) ...[
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: const [
                              BoxShadow(
                                  offset: Offset(2, 2), color: Colors.black)
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: CachedNetworkImage(
                              imageUrl: event.communityLogo,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.accentPurple,
                                child: const Icon(Icons.group, size: 16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: RichText(
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'By ',
                                style: TextStyle(
                                  fontFamily: 'Public Sans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.black.withValues(alpha: 0.6),
                                ),
                              ),
                              TextSpan(
                                text: event.communityName,
                                style: const TextStyle(
                                  fontFamily: 'Public Sans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Resume Roast card ─────────────────────────────────────────────────────

  Widget _resumeRoastCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ResumeRoastScreen()),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.accentPink,
            border: Border.all(color: Colors.black, width: 1.5),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(offset: Offset(1, 1), color: Colors.black)
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.local_fire_department, size: 36, color: Colors.black),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resume Roast',
                      style: TextStyle(
                        fontFamily: 'Lexend Mega',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Let AI roast your resume',
                      style: TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 13,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section header ────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, {VoidCallback? onShowAll, Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.14,
            color: Color(0xFF191C1E),
          ),
        ),
        Row(
          children: [
            if (trailing != null) ...[
              trailing,
              if (onShowAll != null) const SizedBox(width: 8),
            ],
            if (onShowAll != null)
              GestureDetector(
                onTap: onShowAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.showAllButton,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(offset: Offset(1, 1), color: Colors.black)
                    ],
                  ),
                  child: const Text(
                    'SHOW ALL',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.11,
                      color: Color(0xFF191C1E),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ─── Shine stripe helpers ──────────────────────────────────────────────────

  Widget _shineStripes(Color color) {
    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _stripe(color, w: 22, l: 67, t: -43),
          _stripe(color, w: 42, l: 100, t: -69),
          _stripe(color, w: 60, l: -113, t: -22),
          _stripe(color, w: 18, l: 219, t: -111),
          _stripe(color, w: 44, l: 332, t: -43),
        ],
      ),
    );
  }

  Widget _stripe(Color c,
      {required double w, required double l, required double t}) {
    return Positioned(
      left: l,
      top: t,
      child: SizedBox(
        width: 280,
        height: 340,
        child: Center(
          child: Transform.rotate(
            angle: -39 * math.pi / 180,
            child: Container(
              width: w,
              height: 416,
              color: c.withValues(alpha: 0.52),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Polka dot painter ────────────────────────────────────────────────────────

class _PolkaDotPainter extends CustomPainter {
  final Color color;

  const _PolkaDotPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const r = 2.5;
    const spacing = 18.0;
    bool odd = false;
    for (double y = 0; y <= size.height + spacing; y += spacing) {
      final xOff = odd ? spacing / 2 : 0.0;
      for (double x = xOff; x <= size.width + spacing; x += spacing) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
      odd = !odd;
    }
  }

  @override
  bool shouldRepaint(_PolkaDotPainter old) => old.color != color;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/breakpoints.dart';
import '../../services/attendance_notification_service.dart';
import '../../services/timetable_service.dart';
import '../../widgets/hoverable.dart';
import 'home_screen.dart';
import '../attendance_screen.dart';
import '../timetable_list_screen.dart';
import '../resources/resources_hub_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _attendanceRefreshToken = 0;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  // Re-created on every tab switch so the nested Navigator below resets its
  // pushed stack (e.g. leaving Profile open) instead of carrying it across
  // tabs, while still giving rail items outside its subtree (_profileRailItem)
  // a stable handle to push onto it imperatively.
  GlobalKey<NavigatorState> _contentNavKey = GlobalKey<NavigatorState>();
  // True while Profile is the screen showing in the content pane, so the
  // rail can highlight "Profile" instead of leaving the last tab active.
  bool _profileActive = false;

  static const _navItems = [
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.check_circle_outline, label: 'Attendance'),
    (icon: Icons.calendar_today_outlined, label: 'Timetable'),
    (icon: Icons.library_books_outlined, label: 'Resources'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.forward();

    _prepareAttendanceNotifications();
  }

  Future<void> _prepareAttendanceNotifications() async {
    try {
      await AttendanceNotificationService.instance.syncPendingActions();
      AttendanceNotificationService.instance.openPendingNavigation();
      // Cache-aside via AppStateNotifier.timetableBox — if splash's
      // /auth/sync already populated it within TTL, this reuses that value
      // instead of firing a second /timetable request.
      final subjects = await TimetableService().getAllSubjects();
      await AttendanceNotificationService.instance
          .scheduleForTimetable(subjects);
    } catch (_) {}
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onTab(int index) {
    if (_currentIndex == index) return;
    _fadeCtrl.value = 0.0;
    setState(() {
      _currentIndex = index;
      _contentNavKey = GlobalKey<NavigatorState>();
      _profileActive = false;
      if (index == 1) _attendanceRefreshToken += 1;
    });
    _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isNestedInNav =
        context.dependOnInheritedWidgetOfExactType<_MainNavigationScope>() != null;
    final width = MediaQuery.of(context).size.width;
    final showRail = !isNestedInNav && Breakpoints.isAtLeastTablet(width);
    final railExpanded = Breakpoints.isAtLeastDesktop(width);

    final screen = FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_fade),
        child: _screenForIndex(_currentIndex, showRail: showRail),
      ),
    );

    // On mobile, screens pushed from within a tab (Profile, subjects editor,
    // etc.) are meant to take over the full screen — same as today. On
    // tablet/desktop, the left rail is persistent chrome, so those pushes
    // must land in this nested Navigator instead of the root one; otherwise
    // Navigator.push (used throughout the app) would cover the rail too.
    final content = showRail
        ? Navigator(
            key: _contentNavKey,
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (_) => screen,
              settings: settings,
            ),
          )
        : screen;

    return _MainNavigationScope(
      child: Scaffold(
        body: showRail
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _navRail(expanded: railExpanded),
                  Expanded(child: content),
                ],
              )
            : content,
        bottomNavigationBar: showRail ? null : _bottomNav(),
      ),
    );
  }

  Widget _screenForIndex(int index, {required bool showRail}) {
    final homeScreen = HomeScreen(
      onTabSwitch: _onTab,
      showProfileButton: !showRail,
    );
    return switch (index) {
      0 => homeScreen,
      1 => AttendanceScreen(refreshToken: _attendanceRefreshToken),
      2 => const TimetableListScreen(),
      3 => const ResourcesHubScreen(),
      _ => homeScreen,
    };
  }

  Widget _bottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryYellow,
        border: const Border(top: BorderSide(color: Colors.black, width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_navItems.length, _navItem),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index) {
    final isActive = _currentIndex == index;
    final item = _navItems[index];

    if (isActive) {
      return GestureDetector(
        onTap: () => _onTab(index),
        child: Container(
          // Outer container owns the border + shadow — drawn OUTSIDE the clip
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(offset: Offset(2, 2), color: Colors.black),
            ],
          ),
          child: ClipRRect(
            // Clip stripes to rounded corners — border is above this clip
            borderRadius: BorderRadius.circular(7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              color: AppColors.navigationBlue,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Shine stripes clipped inside, under the border
                  Positioned.fill(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _navStripe(left: 78, top: -41, width: 12),
                        _navStripe(left: 29, top: -24, width: 12),
                        _navStripe(left: 46, top: -21, width: 6),
                        _navStripe(left: -31, top: -18, width: 14),
                        _navStripe(left: -10, top: -13, width: 7),
                        _navStripe(left: -39, top: -10, width: 7),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, size: 24, color: Colors.black),
                      const SizedBox(width: 8),
                      Text(
                        item.label,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.21,
                          color: Color(0xFF191C1E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTab(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(item.icon, size: 26, color: Colors.black),
      ),
    );
  }

  // ─── Desktop / tablet nav rail ────────────────────────────────────────────

  Widget _navRail({required bool expanded}) {
    return Container(
      width: expanded ? 240 : 76,
      decoration: BoxDecoration(
        color: AppColors.primaryYellow,
        border: const Border(right: BorderSide(color: Colors.black, width: 1.5)),
      ),
      child: SafeArea(
        right: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _navItems.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _railItem(i, expanded: expanded),
              ],
              const Spacer(),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 1.5,
                color: Colors.black.withValues(alpha: 0.15),
              ),
              _profileRailItem(expanded: expanded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileRailItem({required bool expanded}) {
    const icon = Icon(Icons.person_outline, size: 24, color: Colors.black);
    const label = Text(
      'Profile',
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.21,
        color: Color(0xFF191C1E),
      ),
    );
    final rowContent = expanded
        ? const Row(
            mainAxisSize: MainAxisSize.min,
            children: [icon, SizedBox(width: 12), label],
          )
        : const Center(child: icon);

    Widget itemWidget = _profileActive
        ? _activeRailChrome(rowContent)
        : Hoverable(
            builder: (context, hovered) => AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: hovered
                    ? Colors.black.withValues(alpha: 0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: rowContent,
            ),
          );

    if (!expanded) {
      itemWidget = Tooltip(message: 'Profile', child: itemWidget);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // This item sits outside the content pane's own subtree (it's a
          // rail item, a sibling of the nested Navigator in the Row), so
          // Navigator.of(context) here would find the root Navigator, not
          // the nested one — push onto it explicitly via its key instead.
          final nav = _contentNavKey.currentState;
          final route = MaterialPageRoute(
            builder: (_) => ProfileScreen(onTabSwitch: _onTab),
          );
          setState(() => _profileActive = true);
          final pushed = nav != null
              ? nav.push(route)
              : Navigator.push(context, route);
          pushed.then((_) {
            if (mounted) setState(() => _profileActive = false);
          });
        },
        child: itemWidget,
      ),
    );
  }

  Widget _railItem(int index, {required bool expanded}) {
    final isActive = _currentIndex == index && !_profileActive;
    final item = _navItems[index];

    final icon = Icon(item.icon, size: 24, color: Colors.black);
    final label = Text(
      item.label,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.21,
        color: Color(0xFF191C1E),
      ),
    );
    final rowContent = expanded
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [icon, const SizedBox(width: 12), label],
          )
        : Center(child: icon);

    Widget itemWidget = isActive
        ? _activeRailChrome(rowContent)
        : Hoverable(
            builder: (context, hovered) => AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: hovered
                    ? Colors.black.withValues(alpha: 0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: rowContent,
            ),
          );

    if (!expanded) {
      itemWidget = Tooltip(message: item.label, child: itemWidget);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _onTab(index),
        behavior: HitTestBehavior.opaque,
        child: itemWidget,
      ),
    );
  }

  /// Shared shine-stripe "active" chrome used by both the 4 main rail items
  /// and the pinned Profile item, so a pushed Profile screen can highlight
  /// itself the same way an active tab does.
  Widget _activeRailChrome(Widget rowContent) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(offset: Offset(2, 2), color: Colors.black),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          color: AppColors.navigationBlue,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _navStripe(left: 40, top: -34, width: 10),
                    _navStripe(left: -10, top: -18, width: 8),
                    _navStripe(left: 65, top: -20, width: 6),
                  ],
                ),
              ),
              rowContent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _navStripe({
    required double left,
    required double top,
    required double width,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: 71,
        height: 94,
        child: Center(
          child: Transform.rotate(
            angle: -35 * math.pi / 180,
            child: Container(
              width: width,
              height: 106,
              color: AppColors.lightBlue,
            ),
          ),
        ),
      ),
    );
  }
}

class _MainNavigationScope extends InheritedWidget {
  const _MainNavigationScope({required super.child});

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}


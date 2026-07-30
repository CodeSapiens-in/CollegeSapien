import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/friend_models.dart';
import '../../models/pomodoro_models.dart';
import '../../services/friends_service.dart';
import '../../services/pomodoro_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/responsive_layout.dart';
import 'pomodoro_timer_screen.dart';

class PomodoroTimerDetailScreen extends StatefulWidget {
  final String timerId;

  const PomodoroTimerDetailScreen({super.key, required this.timerId});

  @override
  State<PomodoroTimerDetailScreen> createState() => _PomodoroTimerDetailScreenState();
}

class _PomodoroTimerDetailScreenState extends State<PomodoroTimerDetailScreen> {
  final _pomodoroService = PomodoroService();
  final _friendsService = FriendsService();
  Future<PomodoroTimerDetail>? _future;

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() {
        _future = _pomodoroService.getTimerDetail(widget.timerId);
      });

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }

  Future<void> _share(PomodoroTimerDetail detail) async {
    List<Friend> friends;
    try {
      friends = (await _friendsService.getOverview()).friends;
    } catch (e) {
      _showError(e);
      return;
    }

    if (!mounted) return;

    final memberUids = detail.members.map((m) => m.uid).toSet();
    final shareable = friends.where((f) => !memberUids.contains(f.uid)).toList();

    if (shareable.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All your friends are already in this timer.')),
        );
      }
      return;
    }

    final selected = <String>{};
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Share with friends',
                    style: TextStyle(
                        fontFamily: 'Lexend Mega', fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...shareable.map(
                  (friend) => CheckboxListTile(
                    value: selected.contains(friend.uid),
                    onChanged: (checked) => setSheetState(() {
                      if (checked ?? false) {
                        selected.add(friend.uid);
                      } else {
                        selected.remove(friend.uid);
                      }
                    }),
                    title: Text(friend.name),
                    subtitle: Text(friend.email),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selected.isEmpty ? null : () => Navigator.pop(context, true),
                    child: const Text('Share'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true || selected.isEmpty) return;

    try {
      await _pomodoroService.addMembers(widget.timerId, selected.toList());
      _refresh();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _pickModeAndStart() async {
    final mode = await showModalBottomSheet<PomodoroMode>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Start a session',
                  style: TextStyle(
                      fontFamily: 'Lexend Mega', fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              for (final m in PomodoroMode.values)
                ListTile(
                  title: Text(m.label),
                  subtitle: Text('${m.defaultDurationSec ~/ 60} min'),
                  onTap: () => Navigator.pop(context, m),
                ),
            ],
          ),
        ),
      ),
    );

    if (mode == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PomodoroTimerScreen(timerId: widget.timerId, initialMode: mode),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: FutureBuilder<PomodoroTimerDetail>(
          future: _future,
          builder: (context, snapshot) => Text(
            snapshot.data?.purpose ?? 'Timer',
            style: const TextStyle(
              fontFamily: 'Lexend Mega',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          FutureBuilder<PomodoroTimerDetail>(
            future: _future,
            builder: (context, snapshot) {
              final detail = snapshot.data;
              if (detail == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.person_add_alt_1, color: Colors.black),
                tooltip: 'Share',
                onPressed: () => _share(detail),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<PomodoroTimerDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Could not load timer: ${snapshot.error}'));
            }
            final detail = snapshot.data!;
            final active = detail.sessions.where((s) => s.isActive).toList();
            final others = detail.sessions.where((s) => !s.isActive).toList();

            return SingleChildScrollView(
              padding: EdgeInsets.all(screenWidth * 0.045),
              child: MaxWidthContent(
                maxWidth: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _membersRow(detail),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pickModeAndStart,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('START SESSION'),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (active.isNotEmpty) ...[
                      _sectionTitle('Active Now'),
                      const SizedBox(height: 12),
                      ...active.map((s) => _sessionTile(s, detail)),
                      const SizedBox(height: 24),
                    ],
                    _sectionTitle('Sessions'),
                    const SizedBox(height: 12),
                    if (others.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.cardDecoration(color: Colors.white),
                        child: const Text('No sessions yet.',
                            style: TextStyle(fontFamily: 'Public Sans', fontSize: 14)),
                      )
                    else
                      ...others.map((s) => _sessionTile(s, detail)),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.14,
          color: Color(0xFF191C1E),
        ),
      );

  Widget _membersRow(PomodoroTimerDetail detail) {
    return Wrap(
      spacing: -8,
      children: detail.members
          .map((m) => CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryYellow,
                backgroundImage: m.profilePic != null ? NetworkImage(m.profilePic!) : null,
                child: m.profilePic == null
                    ? Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontFamily: 'Lexend Mega', fontWeight: FontWeight.w700))
                    : null,
              ))
          .toList(),
    );
  }

  Widget _sessionTile(PomodoroSession session, PomodoroTimerDetail detail) {
    final match = detail.members.where((m) => m.uid == session.uid);
    final name = session.uid == _myUid
        ? 'You'
        : (match.isNotEmpty ? match.first.name : 'Someone');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(
        color: session.isActive ? AppColors.accentGreen : Colors.white,
        shadowOffset: const Offset(2, 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name · ${session.mode.label}',
                    style: const TextStyle(
                        fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700)),
                Text(_relativeTime(session.startedAt),
                    style: TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.6))),
              ],
            ),
          ),
          if (session.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('LIVE',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

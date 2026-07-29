class PomodoroTimerSummary {
  final String id;
  final String purpose;
  final String ownerUid;
  final int memberCount;

  PomodoroTimerSummary({
    required this.id,
    required this.purpose,
    required this.ownerUid,
    required this.memberCount,
  });

  factory PomodoroTimerSummary.fromJson(Map<String, dynamic> json) => PomodoroTimerSummary(
        id: json['id'] as String? ?? '',
        purpose: json['purpose'] as String? ?? '',
        ownerUid: json['ownerUid'] as String? ?? '',
        memberCount: json['memberCount'] as int? ?? 0,
      );
}

class PomodoroMember {
  final String uid;
  final String name;
  final String? profilePic;

  PomodoroMember({required this.uid, required this.name, this.profilePic});

  factory PomodoroMember.fromJson(Map<String, dynamic> json) => PomodoroMember(
        uid: json['uid'] as String? ?? '',
        name: json['name'] as String? ?? '',
        profilePic: json['profilePic'] as String?,
      );
}

enum PomodoroMode { focus, shortBreak, longBreak }

extension PomodoroModeX on PomodoroMode {
  String get apiValue => switch (this) {
        PomodoroMode.focus => 'focus',
        PomodoroMode.shortBreak => 'short_break',
        PomodoroMode.longBreak => 'long_break',
      };

  String get label => switch (this) {
        PomodoroMode.focus => 'Focus',
        PomodoroMode.shortBreak => 'Short Break',
        PomodoroMode.longBreak => 'Long Break',
      };

  int get defaultDurationSec => switch (this) {
        PomodoroMode.focus => 25 * 60,
        PomodoroMode.shortBreak => 5 * 60,
        PomodoroMode.longBreak => 15 * 60,
      };

  static PomodoroMode fromApi(String value) => switch (value) {
        'short_break' => PomodoroMode.shortBreak,
        'long_break' => PomodoroMode.longBreak,
        _ => PomodoroMode.focus,
      };
}

class PomodoroSession {
  final String id;
  final String uid;
  final PomodoroMode mode;
  final int durationSec;
  final DateTime startedAt;
  // Server-derived: 'active' | 'completed' | 'cancelled'. Refreshed on demand
  // (no polling) — see PomodoroTimerDetailScreen's refresh action.
  final String status;

  PomodoroSession({
    required this.id,
    required this.uid,
    required this.mode,
    required this.durationSec,
    required this.startedAt,
    required this.status,
  });

  bool get isActive => status == 'active';

  factory PomodoroSession.fromJson(Map<String, dynamic> json) => PomodoroSession(
        id: json['id'] as String? ?? '',
        uid: json['uid'] as String? ?? '',
        mode: PomodoroModeX.fromApi(json['mode'] as String? ?? 'focus'),
        durationSec: json['durationSec'] as int? ?? 0,
        startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ?? DateTime.now(),
        status: json['status'] as String? ?? 'completed',
      );
}

class PomodoroTimerDetail {
  final String id;
  final String purpose;
  final String ownerUid;
  final List<PomodoroMember> members;
  final List<PomodoroSession> sessions;

  PomodoroTimerDetail({
    required this.id,
    required this.purpose,
    required this.ownerUid,
    required this.members,
    required this.sessions,
  });

  factory PomodoroTimerDetail.fromJson(Map<String, dynamic> json) {
    final timer = json['timer'] as Map<String, dynamic>? ?? {};
    return PomodoroTimerDetail(
      id: timer['id'] as String? ?? '',
      purpose: timer['purpose'] as String? ?? '',
      ownerUid: timer['ownerUid'] as String? ?? '',
      members: (json['members'] as List<dynamic>? ?? [])
          .map((e) => PomodoroMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      sessions: (json['sessions'] as List<dynamic>? ?? [])
          .map((e) => PomodoroSession.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

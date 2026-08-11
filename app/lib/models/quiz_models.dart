import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Shared option-tile fill colors — used by both the host tally and the
/// participant answer grid so the same option always reads the same color.
const quizOptionFills = [
  Color(0xFF8BDEFF),
  Color(0xFFFFB4B4),
  Color(0xFFD2FFB6),
  Color(0xFFFFD966),
];

enum QuizQuestionType { mcq, trueFalse, text, wordCloud }

QuizQuestionType quizQuestionTypeFromString(String v) {
  switch (v) {
    case 'tf':
      return QuizQuestionType.trueFalse;
    case 'text':
      return QuizQuestionType.text;
    case 'cloud':
      return QuizQuestionType.wordCloud;
    default:
      return QuizQuestionType.mcq;
  }
}

String quizQuestionTypeToString(QuizQuestionType t) {
  switch (t) {
    case QuizQuestionType.trueFalse:
      return 'tf';
    case QuizQuestionType.text:
      return 'text';
    case QuizQuestionType.wordCloud:
      return 'cloud';
    case QuizQuestionType.mcq:
      return 'mcq';
  }
}

class QuizQuestion {
  final String id;
  final QuizQuestionType type;
  final String text;
  final List<String> options;
  final int? correctIndex;
  final int secs;

  const QuizQuestion({
    required this.id,
    required this.type,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.secs,
  });

  bool get hasOptions =>
      type == QuizQuestionType.mcq || type == QuizQuestionType.trueFalse;

  factory QuizQuestion.blank() => QuizQuestion(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: QuizQuestionType.mcq,
        text: '',
        options: const ['', '', '', ''],
        correctIndex: 0,
        secs: 20,
      );

  QuizQuestion copyWith({
    QuizQuestionType? type,
    String? text,
    List<String>? options,
    int? correctIndex,
    bool clearCorrectIndex = false,
    int? secs,
  }) {
    return QuizQuestion(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      options: options ?? this.options,
      correctIndex:
          clearCorrectIndex ? null : (correctIndex ?? this.correctIndex),
      secs: secs ?? this.secs,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': quizQuestionTypeToString(type),
        'text': text,
        'options': options,
        'correctIndex': correctIndex,
        'secs': secs,
      };

  factory QuizQuestion.fromMap(Map<String, dynamic> m) => QuizQuestion(
        id: m['id'] as String,
        type: quizQuestionTypeFromString(m['type'] as String? ?? 'mcq'),
        text: m['text'] as String? ?? '',
        options: (m['options'] as List?)?.cast<String>() ?? const [],
        correctIndex: m['correctIndex'] as int?,
        secs: m['secs'] as int? ?? 20,
      );
}

enum QuizStatus { build, lobby, live, reveal, ended }

QuizStatus quizStatusFromString(String v) =>
    QuizStatus.values.firstWhere((s) => s.name == v, orElse: () => QuizStatus.build);

/// oneByOne: classic Kahoot-style — host pushes one question at a time and
/// controls when the correct answer is revealed on the dashboard.
/// allAtOnce: every question is released together; participants work through
/// them at their own pace, like a self-paced form. No shared clock, so no
/// speed bonus — answers are scored flat as they arrive.
enum QuizHostMode { oneByOne, allAtOnce }

QuizHostMode quizHostModeFromString(String v) =>
    QuizHostMode.values.firstWhere((m) => m.name == v, orElse: () => QuizHostMode.oneByOne);

class QuizSession {
  final String id;
  final String hostUid;
  final String hostName;
  final String title;
  final String joinCode;
  final QuizStatus status;
  final QuizHostMode mode;
  final bool speedBonus;
  final List<QuizQuestion> questions;
  final int currentQuestionIndex;
  final Timestamp? currentQuestionStartedAt;

  const QuizSession({
    required this.id,
    required this.hostUid,
    required this.hostName,
    required this.title,
    required this.joinCode,
    required this.status,
    required this.mode,
    required this.speedBonus,
    required this.questions,
    required this.currentQuestionIndex,
    required this.currentQuestionStartedAt,
  });

  QuizQuestion? get currentQuestion =>
      currentQuestionIndex >= 0 && currentQuestionIndex < questions.length
          ? questions[currentQuestionIndex]
          : null;

  factory QuizSession.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final m = snap.data()!;
    return QuizSession(
      id: snap.id,
      hostUid: m['hostUid'] as String,
      hostName: m['hostName'] as String? ?? 'Host',
      title: m['title'] as String? ?? 'Untitled quiz',
      joinCode: m['joinCode'] as String,
      status: quizStatusFromString(m['status'] as String? ?? 'build'),
      mode: quizHostModeFromString(m['mode'] as String? ?? 'oneByOne'),
      speedBonus: m['speedBonus'] as bool? ?? true,
      questions: ((m['questions'] as List?) ?? const [])
          .map((q) => QuizQuestion.fromMap(q as Map<String, dynamic>))
          .toList(),
      currentQuestionIndex: m['currentQuestionIndex'] as int? ?? 0,
      currentQuestionStartedAt: m['currentQuestionStartedAt'] as Timestamp?,
    );
  }
}

class QuizParticipant {
  final String uid;
  final String name;
  final bool anon;
  final int colorIndex;
  final int score;

  const QuizParticipant({
    required this.uid,
    required this.name,
    required this.anon,
    required this.colorIndex,
    required this.score,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.map((p) => p.isEmpty ? '' : p[0]).take(2).join().toUpperCase();
  }

  factory QuizParticipant.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final m = snap.data()!;
    return QuizParticipant(
      uid: snap.id,
      name: m['name'] as String? ?? 'Player',
      anon: m['anon'] as bool? ?? false,
      colorIndex: m['colorIndex'] as int? ?? 0,
      score: m['score'] as int? ?? 0,
    );
  }
}

class QuizAnswer {
  final String id;
  final String uid;
  final int questionIndex;
  final int? optionIndex;
  final String? text;
  final Timestamp? answeredAt;
  final bool scored;

  const QuizAnswer({
    required this.id,
    required this.uid,
    required this.questionIndex,
    required this.optionIndex,
    required this.text,
    required this.answeredAt,
    required this.scored,
  });

  factory QuizAnswer.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final m = snap.data()!;
    return QuizAnswer(
      id: snap.id,
      uid: m['uid'] as String,
      questionIndex: m['questionIndex'] as int,
      optionIndex: m['optionIndex'] as int?,
      text: m['text'] as String?,
      answeredAt: m['answeredAt'] as Timestamp?,
      scored: m['scored'] as bool? ?? false,
    );
  }
}

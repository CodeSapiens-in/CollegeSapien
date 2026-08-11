import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/quiz_models.dart';
import 'auth_service.dart';

/// Firestore-backed live quiz sessions (Kahoot-style). Realtime fan-out via
/// snapshot listeners; tallying and scoring happen on the host's device from
/// the current question's `answers` — no Cloud Functions needed at this
/// scale (see security rules for the per-write throughput reasoning).
/// ponytail: host device is authoritative for scoring — fine for casual
/// classroom use, add a Cloud Function verifier if this needs anti-cheat.
class QuizService {
  QuizService._();
  static final QuizService instance = QuizService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('quizSessions');

  String _generateJoinCode() {
    final r = Random();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  Future<QuizSession> createSession({
    required String hostUid,
    required String hostName,
    required String title,
  }) async {
    final doc = _sessions.doc();
    final questions = [QuizQuestion.blank()];
    await doc.set({
      'hostUid': hostUid,
      'hostName': hostName,
      'title': title,
      'joinCode': _generateJoinCode(),
      'status': QuizStatus.build.name,
      'mode': QuizHostMode.oneByOne.name,
      'speedBonus': true,
      'questions': questions.map((q) => q.toMap()).toList(),
      'currentQuestionIndex': 0,
      'currentQuestionStartedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap = await doc.get();
    return QuizSession.fromSnap(snap);
  }

  Future<void> saveQuestions(String sessionId, List<QuizQuestion> questions) {
    return _sessions.doc(sessionId).update({
      'questions': questions.map((q) => q.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setSpeedBonus(String sessionId, bool enabled) {
    return _sessions.doc(sessionId).update({'speedBonus': enabled});
  }

  Future<void> setMode(String sessionId, QuizHostMode mode) {
    return _sessions.doc(sessionId).update({'mode': mode.name});
  }

  Future<void> openLobby(String sessionId) {
    return _sessions.doc(sessionId).update({'status': QuizStatus.lobby.name});
  }

  /// oneByOne starts on question 0 with a running clock; allAtOnce has no
  /// single "current" question — every question is already visible to
  /// participants via [QuizSession.questions], so there's no clock to start.
  Future<void> startQuiz(String sessionId, QuizHostMode mode) {
    return _sessions.doc(sessionId).update({
      'status': QuizStatus.live.name,
      'currentQuestionIndex': mode == QuizHostMode.allAtOnce ? -1 : 0,
      'currentQuestionStartedAt':
          mode == QuizHostMode.allAtOnce ? null : FieldValue.serverTimestamp(),
    });
  }

  Future<void> revealQuestion(String sessionId, QuizSession session) async {
    await _sessions.doc(sessionId).update({'status': QuizStatus.reveal.name});
    final snap = await _sessions
        .doc(sessionId)
        .collection('answers')
        .where('questionIndex', isEqualTo: session.currentQuestionIndex)
        .get();
    await _scoreAnswers(
      sessionId,
      questions: session.questions,
      answers: snap.docs.map(QuizAnswer.fromSnap).toList(),
      speedBonus: session.speedBonus,
      questionStartedAt: session.currentQuestionStartedAt,
    );
  }

  /// allAtOnce mode: no reveal step to hang scoring off, so the host screen
  /// calls this whenever its all-answers listener sees new docs — the
  /// `scored` guard on each answer makes it safe to call repeatedly.
  Future<void> scoreNewAnswers(
      String sessionId, List<QuizQuestion> questions, List<QuizAnswer> answers) {
    return _scoreAnswers(sessionId,
        questions: questions, answers: answers, speedBonus: false, questionStartedAt: null);
  }

  Future<void> nextQuestion(String sessionId, int nextIndex) {
    return _sessions.doc(sessionId).update({
      'status': QuizStatus.live.name,
      'currentQuestionIndex': nextIndex,
      'currentQuestionStartedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> finishQuiz(String sessionId) {
    return _sessions.doc(sessionId).update({'status': QuizStatus.ended.name});
  }

  Future<void> backToBuild(String sessionId) {
    return _sessions.doc(sessionId).update({'status': QuizStatus.build.name});
  }

  /// Shared scorer for both host modes. Guards on [QuizAnswer.scored] so it's
  /// safe to call repeatedly (allAtOnce calls this on every answers-stream
  /// update) without double-awarding points on replay/reconnect.
  Future<void> _scoreAnswers(
    String sessionId, {
    required List<QuizQuestion> questions,
    required List<QuizAnswer> answers,
    required bool speedBonus,
    Timestamp? questionStartedAt,
  }) async {
    final unscored = answers.where((a) => !a.scored).toList();
    if (unscored.isEmpty) return;

    final batch = _db.batch();
    for (final answer in unscored) {
      batch.update(
        _sessions.doc(sessionId).collection('answers').doc(answer.id),
        {'scored': true},
      );
      if (answer.questionIndex < 0 || answer.questionIndex >= questions.length) continue;
      final q = questions[answer.questionIndex];
      if (!q.hasOptions || q.correctIndex == null || answer.optionIndex != q.correctIndex) {
        continue;
      }

      var points = 1000;
      if (speedBonus && questionStartedAt != null && answer.answeredAt != null) {
        final elapsedMs =
            answer.answeredAt!.toDate().difference(questionStartedAt.toDate()).inMilliseconds;
        final frac = (elapsedMs / (q.secs * 1000)).clamp(0.0, 1.0);
        points += (500 * (1 - frac)).round();
      }
      batch.update(
        _sessions.doc(sessionId).collection('participants').doc(answer.uid),
        {'score': FieldValue.increment(points)},
      );
    }
    await batch.commit();
  }

  Stream<QuizSession> watchSession(String sessionId) {
    return _sessions.doc(sessionId).snapshots().map(QuizSession.fromSnap);
  }

  Stream<List<QuizParticipant>> watchParticipants(String sessionId) {
    return _sessions
        .doc(sessionId)
        .collection('participants')
        .orderBy('joinedAt')
        .snapshots()
        .map((s) => s.docs.map(QuizParticipant.fromSnap).toList());
  }

  /// Headcount only, via a server-side aggregate — costs ~1 read regardless
  /// of participant count. Use this instead of [watchParticipants] anywhere
  /// that only needs a number: a full-collection listener would push every
  /// participant's doc to every other participant's device on every join.
  Future<int> participantCount(String sessionId) async {
    final agg = await _sessions.doc(sessionId).collection('participants').count().get();
    return agg.count ?? 0;
  }

  /// Bounded leaderboard for participant-facing screens — avoids streaming
  /// the full roster (and its every score update) to every phone at scale.
  Stream<List<QuizParticipant>> watchTopParticipants(String sessionId, {int limit = 10}) {
    return _sessions
        .doc(sessionId)
        .collection('participants')
        .orderBy('score', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(QuizParticipant.fromSnap).toList());
  }

  /// Live score for a single participant — cheap (one doc) regardless of
  /// how many others are in the session.
  Stream<QuizParticipant?> watchParticipant(String sessionId, String uid) {
    return _sessions
        .doc(sessionId)
        .collection('participants')
        .doc(uid)
        .snapshots()
        .map((s) => s.exists ? QuizParticipant.fromSnap(s) : null);
  }

  /// Exact rank via a count aggregate (docs with a strictly higher score),
  /// not by downloading and sorting the whole roster.
  Future<int> rank(String sessionId, int myScore) async {
    final agg = await _sessions
        .doc(sessionId)
        .collection('participants')
        .where('score', isGreaterThan: myScore)
        .count()
        .get();
    return (agg.count ?? 0) + 1;
  }

  Stream<List<QuizAnswer>> watchAnswersForQuestion(
      String sessionId, int questionIndex) {
    return _sessions
        .doc(sessionId)
        .collection('answers')
        .where('questionIndex', isEqualTo: questionIndex)
        .snapshots()
        .map((s) => s.docs.map(QuizAnswer.fromSnap).toList());
  }

  /// allAtOnce mode: every question is live at once, so the host tallies
  /// (and scores) across the whole answers collection, not just one index.
  Stream<List<QuizAnswer>> watchAllAnswers(String sessionId) {
    return _sessions
        .doc(sessionId)
        .collection('answers')
        .snapshots()
        .map((s) => s.docs.map(QuizAnswer.fromSnap).toList());
  }

  /// Looks up a joinable (non-ended) session by its 6-digit code.
  Future<QuizSession?> findSessionByCode(String code) async {
    final result = await _sessions
        .where('joinCode', isEqualTo: code)
        .where('status', isNotEqualTo: QuizStatus.ended.name)
        .limit(1)
        .get();
    if (result.docs.isEmpty) return null;
    return QuizSession.fromSnap(result.docs.first);
  }

  Future<QuizParticipant> joinAsAccount(String sessionId) async {
    final user = AuthService.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    return _join(sessionId, uid: user.uid, name: user.displayName ?? 'Player', anon: false);
  }

  Future<QuizParticipant> joinAsGuest(String sessionId, String nickname) async {
    final user = await AuthService.instance.signInAnonymously();
    return _join(sessionId, uid: user.uid, name: nickname.trim(), anon: true);
  }

  Future<QuizParticipant> _join(String sessionId,
      {required String uid, required String name, required bool anon}) async {
    final ref =
        _sessions.doc(sessionId).collection('participants').doc(uid);
    final existing = await ref.get();
    if (existing.exists) return QuizParticipant.fromSnap(existing);

    await ref.set({
      'name': name,
      'anon': anon,
      'colorIndex': Random().nextInt(6),
      'score': 0,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    return QuizParticipant.fromSnap(await ref.get());
  }

  Future<void> submitAnswer({
    required String sessionId,
    required int questionIndex,
    int? optionIndex,
    String? text,
  }) async {
    final user = AuthService.instance.currentUser ?? FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    final answerId = '${user.uid}_$questionIndex';
    await _sessions.doc(sessionId).collection('answers').doc(answerId).set({
      'uid': user.uid,
      'questionIndex': questionIndex,
      'optionIndex': optionIndex,
      'text': text,
      'answeredAt': FieldValue.serverTimestamp(),
    });
  }

  Future<QuizAnswer?> myAnswer(String sessionId, int questionIndex) async {
    final user = AuthService.instance.currentUser ?? FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await _sessions
        .doc(sessionId)
        .collection('answers')
        .doc('${user.uid}_$questionIndex')
        .get();
    return doc.exists ? QuizAnswer.fromSnap(doc) : null;
  }

  /// All of my answers in one query — used instead of one [myAnswer] call
  /// per question (which was N sequential round-trips for the same N docs).
  Future<Set<int>> myAnsweredQuestionIndexes(String sessionId) async {
    final user = AuthService.instance.currentUser ?? FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final snap = await _sessions
        .doc(sessionId)
        .collection('answers')
        .where('uid', isEqualTo: user.uid)
        .get();
    return snap.docs.map((d) => d.data()['questionIndex'] as int).toSet();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/quiz_models.dart';
import '../../services/quiz_service.dart';
import '../../utils/app_theme.dart';

/// The audience-facing phone screen: waiting room → answer → result → final
/// leaderboard, all driven off [QuizSession.status] via a Firestore listener.
class QuizParticipantScreen extends StatefulWidget {
  final String sessionId;
  final QuizParticipant me;

  const QuizParticipantScreen({super.key, required this.sessionId, required this.me});

  @override
  State<QuizParticipantScreen> createState() => _QuizParticipantScreenState();
}

class _QuizParticipantScreenState extends State<QuizParticipantScreen> {
  Timer? _clock;
  int? _pickedIndex;
  String _textAnswer = '';
  bool _submitted = false;
  int _answeredForIndex = -1;
  final Set<int> _allAtOnceAnswered = {};
  final Map<int, String> _allAtOnceDraft = {};
  bool _allAtOnceChecked = false;

  // Waiting-room headcount: polled via a cheap count aggregate instead of a
  // full-roster listener — the latter would push every participant's doc to
  // every other participant's device on each join (O(n²) at event scale).
  Timer? _countTimer;
  int _waitingCount = 0;

  int? _myRank;
  int _rankForScore = -1;

  // Created once and reused — see the matching comment in quiz_host_screen.
  // A 1s clock tick calling watchSession() fresh inside build() would tear
  // down and re-open the Firestore listener every second.
  late final Stream<QuizSession> _sessionStream =
      QuizService.instance.watchSession(widget.sessionId);
  // Bounded leaderboard + a single-doc watch on my own score — avoids
  // streaming the whole roster (and everyone else's score changes) to this
  // phone just to show a top-10 list and my own rank.
  late final Stream<List<QuizParticipant>> _topParticipantsStream =
      QuizService.instance.watchTopParticipants(widget.sessionId);
  late final Stream<QuizParticipant?> _myParticipantStream =
      QuizService.instance.watchParticipant(widget.sessionId, widget.me.uid);

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock?.cancel();
    _countTimer?.cancel();
    super.dispose();
  }

  void _startCountPolling(String sessionId) {
    if (_countTimer != null) return;
    _refreshCount(sessionId);
    _countTimer = Timer.periodic(const Duration(seconds: 4), (_) => _refreshCount(sessionId));
  }

  Future<void> _refreshCount(String sessionId) async {
    final n = await QuizService.instance.participantCount(sessionId);
    if (mounted) setState(() => _waitingCount = n);
  }

  Future<void> _loadRank(String sessionId, int score) async {
    if (_rankForScore == score) return;
    _rankForScore = score;
    final r = await QuizService.instance.rank(sessionId, score);
    if (mounted) setState(() => _myRank = r);
  }

  void _resetForQuestion(int index) {
    if (_answeredForIndex == index) return;
    _answeredForIndex = index;
    _pickedIndex = null;
    _textAnswer = '';
    _submitted = false;
  }

  Future<void> _pick(QuizSession session, int optionIndex) async {
    if (_submitted) return;
    setState(() {
      _pickedIndex = optionIndex;
      _submitted = true;
    });
    await QuizService.instance.submitAnswer(
      sessionId: session.id,
      questionIndex: session.currentQuestionIndex,
      optionIndex: optionIndex,
    );
  }

  Future<void> _submitText(QuizSession session) async {
    if (_submitted || _textAnswer.trim().isEmpty) return;
    setState(() => _submitted = true);
    await QuizService.instance.submitAnswer(
      sessionId: session.id,
      questionIndex: session.currentQuestionIndex,
      text: _textAnswer.trim(),
    );
  }

  /// allAtOnce mode: every question is open at once, so "already answered"
  /// has to be checked per question rather than driven off a single
  /// session-wide `_submitted` flag. One query (not N), and only runs once
  /// thanks to `_allAtOnceChecked`.
  Future<void> _loadAllAtOnceProgress(QuizSession session) async {
    if (_allAtOnceChecked) return;
    _allAtOnceChecked = true;
    final answered = await QuizService.instance.myAnsweredQuestionIndexes(session.id);
    _allAtOnceAnswered.addAll(answered);
    if (mounted) setState(() {});
  }

  Future<void> _submitAllAtOnce(QuizSession session, int index,
      {int? optionIndex, String? text}) async {
    if (_allAtOnceAnswered.contains(index)) return;
    setState(() => _allAtOnceAnswered.add(index));
    await QuizService.instance.submitAnswer(
      sessionId: session.id,
      questionIndex: index,
      optionIndex: optionIndex,
      text: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<QuizSession>(
          stream: _sessionStream,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final session = snap.data!;
            if (session.mode == QuizHostMode.allAtOnce) {
              switch (session.status) {
                case QuizStatus.build:
                case QuizStatus.lobby:
                  return _waitingBody(session);
                case QuizStatus.live:
                case QuizStatus.reveal:
                  _loadAllAtOnceProgress(session);
                  return _allAtOnceBody(session);
                case QuizStatus.ended:
                  return _finalBody(session);
              }
            }
            switch (session.status) {
              case QuizStatus.build:
              case QuizStatus.lobby:
                return _waitingBody(session);
              case QuizStatus.live:
                _resetForQuestion(session.currentQuestionIndex);
                return _answerBody(session);
              case QuizStatus.reveal:
                return _resultBody(session);
              case QuizStatus.ended:
                return _finalBody(session);
            }
          },
        ),
      ),
    );
  }

  Widget _waitingBody(QuizSession session) {
    _startCountPolling(session.id);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _avatar(widget.me, size: 74),
            const SizedBox(height: 16),
            Text("You're in, ${widget.me.name}",
                style: const TextStyle(
                    fontFamily: 'Public Sans', fontWeight: FontWeight.w800, fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              'Watch the big screen. The first question lands the moment the host starts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Inter', fontSize: 13.5, color: Colors.black.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$_waitingCount waiting',
                  style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _answerBody(QuizSession session) {
    final q = session.currentQuestion;
    if (q == null) return const SizedBox();
    final startedAt = session.currentQuestionStartedAt?.toDate();
    final elapsed = startedAt == null ? 0 : DateTime.now().difference(startedAt).inSeconds;
    final remaining = (q.secs - elapsed).clamp(0, q.secs);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Question ${session.currentQuestionIndex + 1} of ${session.questions.length}',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: Colors.black.withValues(alpha: 0.5))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: remaining <= 5 ? const Color(0xFFFFB4B4) : AppColors.primaryYellow,
                  border: Border.all(color: Colors.black, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$remaining',
                    style: const TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w600, fontSize: 18)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: q.secs == 0 ? 0 : remaining / q.secs,
            color: Colors.red,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 18),
          Text(q.text,
              style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800, fontSize: 21)),
          const SizedBox(height: 18),
          Expanded(
            child: q.hasOptions
                ? _optionsGrid(session, q)
                : _openAnswerBody(session, q),
          ),
        ],
      ),
    );
  }

  // allAtOnce: every question is visible up front, each locks independently
  // once answered — no shared clock, so no countdown here.
  Widget _allAtOnceBody(QuizSession session) {
    const fills = quizOptionFills;
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: session.questions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, i) {
        final q = session.questions[i];
        final answered = _allAtOnceAnswered.contains(i);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Question ${i + 1} of ${session.questions.length}',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Colors.black.withValues(alpha: 0.5))),
              const SizedBox(height: 6),
              Text(q.text.isEmpty ? 'Untitled question' : q.text,
                  style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 12),
              if (answered)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Locked in',
                      style: TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w700)),
                )
              else if (q.hasOptions)
                ...List.generate(q.options.length, (oi) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => _submitAllAtOnce(session, i, optionIndex: oi),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: fills[oi % fills.length],
                          border: Border.all(color: Colors.black, width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(q.options[oi],
                            style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w700)),
                      ),
                    ),
                  );
                })
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                            hintText: q.type == QuizQuestionType.wordCloud ? 'One word' : 'Type your answer'),
                        onChanged: (v) => _allAtOnceDraft[i] = v,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        final v = (_allAtOnceDraft[i] ?? '').trim();
                        if (v.isNotEmpty) _submitAllAtOnce(session, i, text: v);
                      },
                      child: const Text('Send'),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _optionsGrid(QuizSession session, QuizQuestion q) {
    const fills = quizOptionFills;
    if (_submitted) {
      return const Center(
        child: Text('Locked in. Waiting for everyone else…',
            style: TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w700)),
      );
    }
    return ListView.separated(
      itemCount: q.options.length,
      separatorBuilder: (_, __) => const SizedBox(height: 11),
      itemBuilder: (context, i) {
        return GestureDetector(
          onTap: () => _pick(session, i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: fills[i % fills.length],
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(offset: Offset(4, 4), color: Colors.black)],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(String.fromCharCode(65 + i),
                      style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(q.options[i],
                      style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800, fontSize: 17)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _openAnswerBody(QuizSession session, QuizQuestion q) {
    if (_submitted) {
      return Center(
        child: Text(
          q.type == QuizQuestionType.wordCloud
              ? 'Your word joins the cloud on the big screen.'
              : 'The host reviews text answers after the timer.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w700),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
              hintText: q.type == QuizQuestionType.wordCloud ? 'One word' : 'Type your answer'),
          onChanged: (v) => setState(() => _textAnswer = v),
          onSubmitted: (_) => _submitText(session),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => _submitText(session),
          child: const Text('Send answer'),
        ),
      ],
    );
  }

  Widget _resultBody(QuizSession session) {
    final q = session.currentQuestion;
    final hasOpts = q?.hasOptions ?? false;
    final wasRight = hasOpts && _pickedIndex == q!.correctIndex;

    return StreamBuilder<QuizParticipant?>(
      stream: _myParticipantStream,
      builder: (context, snap) {
        final myScore = snap.data?.score ?? widget.me.score;
        _loadRank(session.id, myScore);

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: !hasOpts
                        ? AppColors.lightBlue
                        : (wasRight ? const Color(0xFFD2FFB6) : Colors.white),
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    !hasOpts ? Icons.check : (wasRight ? Icons.check_circle : Icons.close),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  !hasOpts ? 'Answer counted' : (wasRight ? 'Nailed it' : 'Not this time'),
                  style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800, fontSize: 26),
                ),
                const SizedBox(height: 8),
                if (hasOpts && !wasRight)
                  Text('Correct answer: ${q!.options[q.correctIndex ?? 0]}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Inter', color: Colors.black.withValues(alpha: 0.6))),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _statChip(hasOpts ? (wasRight ? '+' : '0') : '—', 'POINTS'),
                    const SizedBox(width: 12),
                    _statChip(_myRank != null ? '#$_myRank' : '—', 'RANK'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _finalBody(QuizSession session) {
    return StreamBuilder<QuizParticipant?>(
      stream: _myParticipantStream,
      builder: (context, meSnap) {
        final myScore = meSnap.data?.score ?? widget.me.score;
        _loadRank(session.id, myScore);

        return StreamBuilder<List<QuizParticipant>>(
          stream: _topParticipantsStream,
          builder: (context, snap) {
            final board = snap.data ?? const [];

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.cardDecoration(color: AppColors.primaryYellow),
                    child: Column(
                      children: [
                        const Text('YOU FINISHED',
                            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 1)),
                        Text(_myRank != null ? '#$_myRank' : '—',
                            style: const TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w600, fontSize: 40)),
                        Text('$myScore points',
                            style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('TOP 10',
                      style: TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: board.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final p = board[i];
                        final isMe = p.uid == widget.me.uid;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? AppColors.primaryYellow : Colors.white,
                            border: Border.all(color: Colors.black, width: isMe ? 1.5 : 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: 30,
                                  child: Text('#${i + 1}',
                                      style: const TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w600))),
                              _avatar(p, size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(p.name,
                                      style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w700))),
                              Text('${p.score}',
                                  style: const TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w600, fontSize: 22)),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  letterSpacing: 1,
                  color: Colors.black.withValues(alpha: 0.45))),
        ],
      ),
    );
  }

  static const _palette = [
    Color(0xFF8BDEFF),
    Color(0xFFD2FFB6),
    Color(0xFFDBE1FF),
    Color(0xFFFFD966),
    Color(0xFFFFB4B4),
    Color(0xFFC8EBFF),
  ];

  Widget _avatar(QuizParticipant p, {double size = 34}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _palette[p.colorIndex % _palette.length],
        border: Border.all(color: Colors.black, width: 1.5),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        p.initials,
        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: size * 0.32),
      ),
    );
  }
}

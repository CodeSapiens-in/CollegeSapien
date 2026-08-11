import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/quiz_models.dart';
import '../../services/quiz_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/responsive_layout.dart';

/// Host console — build the question set, run the lobby, drive the live
/// question/reveal cycle, and show final scores. Desktop gets the wide
/// "projector" two-pane layout from the design; mobile stacks the same
/// panels vertically.
class QuizHostScreen extends StatefulWidget {
  final String sessionId;
  const QuizHostScreen({super.key, required this.sessionId});

  @override
  State<QuizHostScreen> createState() => _QuizHostScreenState();
}

class _QuizHostScreenState extends State<QuizHostScreen> {
  List<QuizQuestion>? _questions; // local edit buffer, seeded once (build phase)
  int _selected = 0;
  bool _speedBonus = true;
  QuizHostMode _mode = QuizHostMode.oneByOne;
  Timer? _clock;

  // Streams are created exactly once per screen instance and reused across
  // rebuilds — recreating them inside build() (e.g. from the 1s clock tick
  // below) would tear down and re-open a fresh Firestore listener every
  // second, which looks like polling on the wire even though the code reads
  // like a realtime listener.
  late final Stream<QuizSession> _sessionStream =
      QuizService.instance.watchSession(widget.sessionId);
  late final Stream<List<QuizParticipant>> _participantsStream =
      QuizService.instance.watchParticipants(widget.sessionId);
  late final Stream<List<QuizAnswer>> _allAnswersStream =
      QuizService.instance.watchAllAnswers(widget.sessionId);

  int? _cachedAnswersIndex;
  Stream<List<QuizAnswer>>? _cachedAnswersStream;
  StreamSubscription<List<QuizAnswer>>? _scorerSub;
  QuizSession? _latestSession;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock?.cancel();
    _scorerSub?.cancel();
    super.dispose();
  }

  void _seedQuestionsIfNeeded(QuizSession session) {
    if (_questions != null) return;
    _questions = session.questions.isEmpty ? [QuizQuestion.blank()] : List.of(session.questions);
    _speedBonus = session.speedBonus;
    _mode = session.mode;
  }

  void _updateSelected(QuizQuestion Function(QuizQuestion) fn) {
    setState(() => _questions![_selected] = fn(_questions![_selected]));
  }

  // Only recreated when the current question index actually changes — not
  // on every 1s clock tick — for the same reason as the fields above.
  Stream<List<QuizAnswer>> _answersStreamFor(int questionIndex) {
    if (_cachedAnswersIndex != questionIndex || _cachedAnswersStream == null) {
      _cachedAnswersIndex = questionIndex;
      _cachedAnswersStream =
          QuizService.instance.watchAnswersForQuestion(widget.sessionId, questionIndex);
    }
    return _cachedAnswersStream!;
  }

  Future<void> _openRoom(QuizSession session) async {
    await QuizService.instance.saveQuestions(session.id, _questions!);
    await QuizService.instance.setSpeedBonus(session.id, _speedBonus);
    await QuizService.instance.setMode(session.id, _mode);
    await QuizService.instance.openLobby(session.id);
  }

  /// allAtOnce has no per-question reveal step to hang scoring off, so a
  /// single subscription (set up once the quiz goes live) scores answers as
  /// they land. `_scoreAnswers`' `scored` guard makes repeat calls free.
  void _ensureAllAtOnceScorer(QuizSession session) {
    _latestSession = session;
    if (_scorerSub != null || session.mode != QuizHostMode.allAtOnce) return;
    _scorerSub = _allAnswersStream.listen((answers) {
      final current = _latestSession;
      if (current == null) return;
      QuizService.instance.scoreNewAnswers(session.id, current.questions, answers);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Host · Quiz Room')),
      body: SafeArea(
        child: StreamBuilder<QuizSession>(
          stream: _sessionStream,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final session = snap.data!;
            _seedQuestionsIfNeeded(session);
            _latestSession = session;

            switch (session.status) {
              case QuizStatus.build:
                return ResponsiveLayout(
                  mobile: (_) => _buildPhase(session, wide: false),
                  desktop: (_) => _buildPhase(session, wide: true),
                );
              case QuizStatus.lobby:
                return _lobbyPhase(session);
              case QuizStatus.live:
              case QuizStatus.reveal:
                _ensureAllAtOnceScorer(session);
                return session.mode == QuizHostMode.allAtOnce
                    ? _allAtOnceLivePhase(session)
                    : _livePhase(session);
              case QuizStatus.ended:
                return _boardPhase(session);
            }
          },
        ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────

  Widget _buildPhase(QuizSession session, {required bool wide}) {
    final editor = _questionEditor();
    final list = _questionList();
    // wide: the list gets its bound straight from the enclosing Expanded, so
    // it can keep its own internal ListView scrolling — only the editor pane
    // (which grows with option count) scrolls. Wrapping the whole Row in a
    // SingleChildScrollView instead (as the stacked/mobile case does) gives
    // list's ListView an unbounded height and crashes the render tree.
    final body = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 300, child: list),
              const SizedBox(width: 20),
              Expanded(child: SingleChildScrollView(child: editor)),
            ],
          )
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 220, child: list),
                const SizedBox(height: 16),
                editor,
              ],
            ),
          );

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: body),
          const SizedBox(height: 12),
          _modePicker(),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _openRoom(session),
            child: const Text('Open the room →'),
          ),
        ],
      ),
    );
  }

  Widget _modePicker() {
    return Row(
      children: [
        const Text('RUN AS',
            style: TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800, fontSize: 11)),
        const SizedBox(width: 10),
        Expanded(
          child: SegmentedButton<QuizHostMode>(
            segments: const [
              ButtonSegment(
                value: QuizHostMode.oneByOne,
                label: Text('One question at a time'),
                icon: Icon(Icons.cast, size: 16),
              ),
              ButtonSegment(
                value: QuizHostMode.allAtOnce,
                label: Text('All at once, self-paced'),
                icon: Icon(Icons.list_alt, size: 16),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
        ),
      ],
    );
  }

  Widget _questionList() {
    return ListView.builder(
      itemCount: _questions!.length + 1,
      itemBuilder: (context, i) {
        if (i == _questions!.length) {
          return OutlinedButton(
            onPressed: () => setState(() {
              _questions!.add(QuizQuestion.blank());
              _selected = _questions!.length - 1;
            }),
            child: const Text('+ Add question'),
          );
        }
        final q = _questions![i];
        final selected = i == _selected;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => setState(() => _selected = i),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? AppColors.lightBlue : Colors.white,
                border: Border.all(color: Colors.black, width: selected ? 1.5 : 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text('${i + 1}', style: const TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(q.text.isEmpty ? 'Untitled question' : q.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _questionEditor() {
    final q = _questions![_selected];
    const types = [
      (QuizQuestionType.mcq, 'Multiple choice'),
      (QuizQuestionType.trueFalse, 'True / false'),
      (QuizQuestionType.text, 'Short text'),
      (QuizQuestionType.wordCloud, 'Word cloud'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: types
              .map((t) => ChoiceChip(
                    label: Text(t.$2),
                    selected: q.type == t.$1,
                    onSelected: (_) => _updateSelected((x) => x.copyWith(
                          type: t.$1,
                          options: t.$1 == QuizQuestionType.trueFalse
                              ? const ['True', 'False']
                              : (t.$1 == QuizQuestionType.mcq
                                  ? (x.options.isEmpty ? const ['', '', '', ''] : x.options)
                                  : const []),
                          correctIndex: t.$1 == QuizQuestionType.trueFalse ? 0 : x.correctIndex,
                          clearCorrectIndex: t.$1 == QuizQuestionType.text || t.$1 == QuizQuestionType.wordCloud,
                        )),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          key: ValueKey('q-${q.id}'),
          controller: TextEditingController(text: q.text)
            ..selection = TextSelection.collapsed(offset: q.text.length),
          decoration: const InputDecoration(hintText: 'Ask something…'),
          style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w700, fontSize: 18),
          onChanged: (v) => _updateSelected((x) => x.copyWith(text: v)),
        ),
        const SizedBox(height: 16),
        if (q.hasOptions)
          ...List.generate(q.options.length, (i) {
            final isTf = q.type == QuizQuestionType.trueFalse;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      q.correctIndex == i ? Icons.check_circle : Icons.radio_button_unchecked,
                    ),
                    onPressed: () => _updateSelected((x) => x.copyWith(correctIndex: i)),
                  ),
                  Expanded(
                    child: isTf
                        ? Text(q.options[i], style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w700))
                        : TextField(
                            key: ValueKey('opt-${q.id}-$i'),
                            controller: TextEditingController(text: q.options[i])
                              ..selection = TextSelection.collapsed(offset: q.options[i].length),
                            decoration: InputDecoration(hintText: 'Option ${String.fromCharCode(65 + i)}'),
                            onChanged: (v) => _updateSelected((x) {
                              final opts = List.of(x.options);
                              opts[i] = v;
                              return x.copyWith(options: opts);
                            }),
                          ),
                  ),
                ],
              ),
            );
          })
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              q.type == QuizQuestionType.wordCloud
                  ? 'Answers are aggregated into a live word cloud on the projector. No right answer, no points.'
                  : 'Short free-text. Answers stack up live on the projector.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.black.withValues(alpha: 0.65)),
            ),
          ),
        Row(
          children: [
            const Text('TIME', style: TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800, fontSize: 11)),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () => _updateSelected((x) => x.copyWith(secs: (x.secs - 5).clamp(5, 120))),
            ),
            Text('${q.secs}s', style: const TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w600, fontSize: 17)),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _updateSelected((x) => x.copyWith(secs: (x.secs + 5).clamp(5, 120))),
            ),
            const Spacer(),
            FilterChip(
              label: Text(_speedBonus ? 'Faster = more points' : 'Flat points'),
              selected: _speedBonus,
              onSelected: (v) => setState(() => _speedBonus = v),
            ),
          ],
        ),
      ],
    );
  }

  // ── LOBBY ──────────────────────────────────────────────────────────────

  Widget _lobbyPhase(QuizSession session) {
    return StreamBuilder<List<QuizParticipant>>(
      stream: _participantsStream,
      builder: (context, snap) {
        final participants = snap.data ?? const [];
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Go to collegesapien.app/q and enter',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: AppTheme.cardDecoration(color: AppColors.primaryYellow),
                          child: Text(session.joinCode,
                              style: const TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w600, fontSize: 30)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text('${participants.length}',
                          style: const TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w600, fontSize: 34)),
                      const Text('in the waiting room', style: TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: participants
                      .map((p) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: p.anon ? Colors.white : AppColors.background,
                              border: Border.all(color: Colors.black, width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(p.name, style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w700)),
                                if (p.anon) ...[
                                  const SizedBox(width: 6),
                                  Text('GUEST',
                                      style: TextStyle(
                                          fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.w700, color: Colors.black.withValues(alpha: 0.45))),
                                ],
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              const Text("Guests join with a nickname only — you'll never see an account behind it.",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => QuizService.instance.startQuiz(session.id, session.mode),
                child: const Text('Start quiz'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── LIVE / REVEAL ────────────────────────────────────────────────────────

  Widget _livePhase(QuizSession session) {
    final q = session.currentQuestion;
    if (q == null) return const SizedBox();
    final reveal = session.status == QuizStatus.reveal;
    final startedAt = session.currentQuestionStartedAt?.toDate();
    final elapsed = startedAt == null ? 0 : DateTime.now().difference(startedAt).inSeconds;
    final remaining = reveal ? 0 : (q.secs - elapsed).clamp(0, q.secs);

    return StreamBuilder<List<QuizAnswer>>(
      stream: _answersStreamFor(session.currentQuestionIndex),
      builder: (context, answerSnap) {
        final answers = answerSnap.data ?? const [];
        return StreamBuilder<List<QuizParticipant>>(
          stream: _participantsStream,
          builder: (context, pSnap) {
            final joined = pSnap.data?.length ?? 0;
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(q.text,
                            style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800, fontSize: 28)),
                      ),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: reveal
                              ? Colors.white
                              : (remaining <= 5 ? const Color(0xFFFFB4B4) : AppColors.primaryYellow),
                          border: Border.all(color: Colors.black, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(reveal ? '0' : '$remaining',
                            style: const TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w600, fontSize: 30)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: q.hasOptions ? _mcqTally(q, answers, reveal) : _openTally(q, answers, reveal)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.red),
                      const SizedBox(width: 6),
                      Text(reveal ? '${answers.length} of $joined answered' : '${answers.length} answered · live',
                          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          if (!reveal) {
                            QuizService.instance.revealQuestion(session.id, session);
                          } else if (session.currentQuestionIndex + 1 < session.questions.length) {
                            QuizService.instance.nextQuestion(session.id, session.currentQuestionIndex + 1);
                          } else {
                            QuizService.instance.finishQuiz(session.id);
                          }
                        },
                        child: Text(reveal
                            ? (session.currentQuestionIndex + 1 < session.questions.length
                                ? 'Next question →'
                                : 'Show final scores →')
                            : 'End question'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // allAtOnce: no single "current" question or shared clock — every question
  // is already open to participants, so the dashboard shows a breakdown per
  // question plus a live leaderboard, and the host ends the quiz whenever.
  Widget _allAtOnceLivePhase(QuizSession session) {
    return StreamBuilder<List<QuizAnswer>>(
      stream: _allAnswersStream,
      builder: (context, answerSnap) {
        final allAnswers = answerSnap.data ?? const [];
        return StreamBuilder<List<QuizParticipant>>(
          stream: _participantsStream,
          builder: (context, pSnap) {
            final participants = pSnap.data ?? const [];
            final board = [...participants]..sort((a, b) => b.score.compareTo(a.score));
            final doneCount = participants
                .where((p) => allAnswers.where((a) => a.uid == p.uid).length >= session.questions.length)
                .length;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('$doneCount of ${participants.length} finished',
                            style: const TextStyle(
                                fontFamily: 'Public Sans', fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.separated(
                            itemCount: session.questions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, i) {
                              final q = session.questions[i];
                              final answers = allAnswers.where((a) => a.questionIndex == i).toList();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('${i + 1}. ${q.text.isEmpty ? 'Untitled question' : q.text}',
                                      style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: q.hasOptions ? q.options.length * 62.0 : 100,
                                    child: q.hasOptions
                                        ? _mcqTally(q, answers, true)
                                        : _openTally(q, answers, true),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Leaderboard',
                            style: TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.separated(
                            itemCount: board.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final p = board[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: i == 0 ? const Color(0xFFD2FFB6) : Colors.white,
                                  border: Border.all(color: Colors.black, width: 1.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Text('#${i + 1}', style: const TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(p.name, style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w700))),
                                    Text('${p.score}', style: const TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => QuizService.instance.finishQuiz(session.id),
                          child: const Text('Finish quiz →'),
                        ),
                      ],
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

  Widget _mcqTally(QuizQuestion q, List<QuizAnswer> answers, bool reveal) {
    const fills = quizOptionFills;
    final counts = List<int>.filled(q.options.length, 0);
    for (final a in answers) {
      if (a.optionIndex != null && a.optionIndex! < counts.length) counts[a.optionIndex!]++;
    }
    final total = counts.fold(0, (a, b) => a + b);
    return ListView.separated(
      itemCount: q.options.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final pct = total == 0 ? 0 : (counts[i] * 100 / total).round();
        final correct = reveal && q.correctIndex == i;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: pct / 100,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: correct ? const Color(0xFFD2FFB6) : (reveal ? Colors.black12 : fills[i % fills.length]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      Text(String.fromCharCode(65 + i), style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800)),
                      const SizedBox(width: 14),
                      Expanded(child: Text(q.options[i], style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w700))),
                      if (correct)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(5)),
                          child: const Text('CORRECT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      const SizedBox(width: 10),
                      Text('$pct%', style: const TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w600, fontSize: 18)),
                      const SizedBox(width: 8),
                      Text('${counts[i]}', style: TextStyle(fontFamily: 'Inter', color: Colors.black.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _openTally(QuizQuestion q, List<QuizAnswer> answers, bool reveal) {
    final counts = <String, int>{};
    for (final a in answers) {
      final t = (a.text ?? '').trim().toLowerCase();
      if (t.isEmpty) continue;
      counts[t] = (counts[t] ?? 0) + 1;
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(20),
      child: entries.isEmpty
          ? const Center(child: Text('Waiting for answers…'))
          : Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 10,
              children: entries.map((e) {
                final size = 16.0 + e.value * 6.0;
                return Text(e.key, style: TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800, fontSize: size.clamp(16, 60)));
              }).toList(),
            ),
    );
  }

  // ── BOARD ──────────────────────────────────────────────────────────────

  Widget _boardPhase(QuizSession session) {
    return StreamBuilder<List<QuizParticipant>>(
      stream: _participantsStream,
      builder: (context, snap) {
        final board = [...(snap.data ?? const [])]..sort((a, b) => b.score.compareTo(a.score));
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Final scores', style: TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800, fontSize: 26)),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: board.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = board[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: i == 0 ? const Color(0xFFD2FFB6) : Colors.white,
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 44, child: Text('#${i + 1}', style: const TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w600, fontSize: 20))),
                          Expanded(child: Text(p.name, style: const TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w800, fontSize: 16))),
                          Text('${p.score}', style: const TextStyle(fontFamily: 'Lexend Mega', fontWeight: FontWeight.w600, fontSize: 20)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() => _questions = null);
                  QuizService.instance.backToBuild(session.id);
                },
                child: const Text('Back to editor'),
              ),
            ],
          ),
        );
      },
    );
  }
}

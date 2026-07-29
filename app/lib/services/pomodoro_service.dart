import '../models/pomodoro_models.dart';
import 'api_service.dart';

class PomodoroService {
  Future<List<PomodoroTimerSummary>> getTimers() async {
    final json = await ApiService.instance.get('/pomodoro/timers') as List<dynamic>;
    return json.map((e) => PomodoroTimerSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> createTimer(String purpose) async {
    final json = await ApiService.instance
        .post('/pomodoro/timers', {'purpose': purpose}) as Map<String, dynamic>;
    return json['id'] as String;
  }

  Future<PomodoroTimerDetail> getTimerDetail(String timerId) async {
    final json =
        await ApiService.instance.get('/pomodoro/timers/$timerId/detail') as Map<String, dynamic>;
    return PomodoroTimerDetail.fromJson(json);
  }

  Future<void> addMembers(String timerId, List<String> uids) =>
      ApiService.instance.patch('/pomodoro/timers/$timerId/members', {'addUids': uids});

  Future<String> startSession(String timerId, PomodoroMode mode, int durationSec) async {
    final json = await ApiService.instance.post('/pomodoro/timers/$timerId/sessions', {
      'mode': mode.apiValue,
      'durationSec': durationSec,
    }) as Map<String, dynamic>;
    return json['id'] as String;
  }

  Future<void> cancelSession(String sessionId) =>
      ApiService.instance.post('/pomodoro/sessions/$sessionId/cancel');
}

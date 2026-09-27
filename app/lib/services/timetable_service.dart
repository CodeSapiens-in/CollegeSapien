import '../models/timetable_models.dart';
import '../providers/app_state_notifier.dart';
import 'attendance_notification_service.dart';
import 'api_service.dart';

class TimetableService {
  AppStateNotifier get _appState => AppStateNotifier.instance;

  Future<List<TimetableSubject>> getAllSubjects({bool forceRefresh = false}) async {
    final timetable = await getTimetable(forceRefresh: forceRefresh);
    return timetable.subjects;
  }

  Future<TimetableData> getTimetable({bool forceRefresh = false}) async {
    final subjects = await _appState.timetableBox.getOrFetch(
      _fetchSubjects,
      forceRefresh: forceRefresh,
    );
    return TimetableData(
      subjects: subjects,
      attendanceTrackingStartDate:
          _appState.timetableTrackingStartDateBox.valueOrNull,
    );
  }

  Future<List<TimetableSubject>> _fetchSubjects() async {
    final data = await _fetchTimetableFromApi();
    if (data.attendanceTrackingStartDate != null) {
      _appState.timetableTrackingStartDateBox.set(data.attendanceTrackingStartDate);
    }
    return data.subjects;
  }

  Future<TimetableData> _fetchTimetableFromApi() async {
    try {
      final json =
          await ApiService.instance.get('/timetable') as Map<String, dynamic>;
      return TimetableData.fromJson(json);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return TimetableData(subjects: []);
      rethrow;
    }
  }

  Future<void> saveSubjects(List<TimetableSubject> subjects) async {
    await ApiService.instance.post('/timetable', {
      'subjects': subjects.map((subject) => subject.toJson()).toList(),
    });
    // Optimistic update — we already know the new value, no need to
    // invalidate and pay for a round trip back to /timetable.
    await _appState.timetableBox.set(subjects);
    await AttendanceNotificationService.instance.scheduleForTimetable(subjects);
  }

  Future<List<TimetableClass>> getClassesForDay(
    String subjectId,
    String day,
  ) async {
    final subject = await getSubjectById(subjectId);
    return subject.classes.where((c) => c.day == day).toList();
  }

  Future<TimetableSubject> getSubjectById(String id) async {
    final subjects = await getAllSubjects();
    try {
      return subjects.firstWhere((s) => s.id == id);
    } on StateError {
      throw ApiException(404, 'Subject not found: $id');
    }
  }
}

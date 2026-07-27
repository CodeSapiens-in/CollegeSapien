import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../models/api_models.dart';
import '../../models/syllabus_models.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/syllabus_service.dart';
import '../../providers/app_state_notifier.dart';
import '../../providers/reference_data_store.dart';
import '../../utils/app_theme.dart';
import '../../utils/department_constants.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/subjects_editor.dart';

/// Regulation tag used when the user saves subjects for a college/department
/// combination that has no curriculum in the system.
const _customRegulation = 'CUSTOM';

/// What the subjects section is currently showing for the selected
/// college/department/semester combination.
enum _SubjectsMode {
  /// Selection incomplete — nothing to show yet.
  none,

  /// The user's own saved subjects for this selection.
  associated,

  /// Default subjects from the curriculum (nothing saved yet).
  curriculum,

  /// No curriculum exists for this college/department.
  unavailable,
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _syllabusService = SyllabusService();
  final _editorController = SubjectsEditorController();

  List<College> _colleges = [];
  List<Department> _departments = defaultDepartments;
  String? _selectedCollegeId;
  String? _selectedDepartment;
  int? _selectedSemester;
  String? _initialCollegeId;
  String? _initialDepartment;
  int? _initialSemester;
  bool _isSaving = false;
  bool _isLoading = true;

  // Subjects preview state
  _SubjectsMode _subjectsMode = _SubjectsMode.none;
  bool _subjectsLoading = false;
  SavedSyllabus? _previewSaved;
  CurriculumBundle? _previewBundle;
  String? _previewCollegeCode;
  String? _previewCourseCode;
  int _subjectsRequestId = 0;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    // Prefill instantly from the cache /auth/sync already populated (splash,
    // home screen, ...) instead of blocking this screen on a fresh sync.
    _applyProfile(
      Provider.of<AppStateNotifier>(context, listen: false).userProfileStale,
      markAsInitial: true,
    );
    _loadProfile();
  }

  void _applyProfile(UserProfile? profile, {required bool markAsInitial}) {
    if (profile == null) return;
    _selectedCollegeId = profile.collegeId;
    final deptMatch = _departments.any((d) => d.name == profile.department);
    _selectedDepartment = deptMatch ? profile.department : null;
    _selectedSemester =
        profile.semester > 0 && profile.semester <= 8 ? profile.semester : null;
    if (markAsInitial) {
      _initialCollegeId = _selectedCollegeId;
      _initialDepartment = _selectedDepartment;
      _initialSemester = _selectedSemester;
    }
  }

  Future<void> _loadProfile() async {
    // Colleges list gates the dropdowns (an id/name alone can't render a
    // selection without it) — that's the only thing worth a loading state.
    try {
      _colleges = await ReferenceDataStore.instance.listColleges();
      _colleges.sort((a, b) => a.name.compareTo(b.name));
      _departments = await ReferenceDataStore.instance.listDepartments();
      _departments.sort((a, b) => a.name.compareTo(b.name));
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
    _loadSubjectsPreview();

    // Background refresh so the cache (and this form, if the user hasn't
    // started editing yet) stays current — never blocks the UI.
    try {
      final result = await AuthService.instance.syncProfile();
      if (!mounted) return;
      final profile = result.user;
      if (profile == null) return;
      Provider.of<AppStateNotifier>(context, listen: false)
          .setUserProfile(profile);

      final untouched = _selectedCollegeId == _initialCollegeId &&
          _selectedDepartment == _initialDepartment &&
          _selectedSemester == _initialSemester;
      if (untouched) {
        final before =
            (_selectedCollegeId, _selectedDepartment, _selectedSemester);
        setState(() => _applyProfile(profile, markAsInitial: true));
        if (before !=
            (_selectedCollegeId, _selectedDepartment, _selectedSemester)) {
          _loadSubjectsPreview();
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Resolves what to show in the subjects section for the current
  /// college/department/semester selection:
  /// saved subjects (only meaningful while college+department are unchanged)
  /// → curriculum defaults → "curriculum unavailable".
  Future<void> _loadSubjectsPreview() async {
    final collegeId = _selectedCollegeId;
    final dept = _selectedDepartment;
    final sem = _selectedSemester;
    final reqId = ++_subjectsRequestId;

    if (collegeId == null || dept == null || sem == null) {
      setState(() {
        _subjectsMode = _SubjectsMode.none;
        _subjectsLoading = false;
      });
      return;
    }

    setState(() => _subjectsLoading = true);

    SavedSyllabus? saved;
    CurriculumBundle? bundle;
    final college = _colleges.where((c) => c.id == collegeId).firstOrNull;
    final courseCode =
        _departments.where((d) => d.name == dept).firstOrNull?.code;

    // Saved subjects belong to the current college+department — for a new
    // college/department they'd be cleared on save, so don't show them.
    final sameCollegeDept =
        collegeId == _initialCollegeId && dept == _initialDepartment;
    if (sameCollegeDept) {
      try {
        saved = await _syllabusService.getSavedSyllabus(sem);
      } catch (_) {}
    }

    if (college != null && courseCode != null) {
      try {
        bundle = await _syllabusService.getCurriculum(
          collegeCode: college.code,
          courseCode: courseCode,
        );
      } catch (_) {}
    }

    // A newer selection superseded this load — drop the result.
    if (!mounted || reqId != _subjectsRequestId) return;

    final hasSaved = saved != null && saved.subjects.isNotEmpty;
    final curriculumSubjects = bundle == null
        ? const <CurriculumSubject>[]
        : _syllabusService.getSubjectsForSemester(bundle, semester: sem);

    setState(() {
      _subjectsLoading = false;
      _previewSaved = hasSaved ? saved : null;
      _previewBundle = bundle;
      _previewCollegeCode = college?.code;
      _previewCourseCode = courseCode;
      _subjectsMode = hasSaved
          ? _SubjectsMode.associated
          : curriculumSubjects.isNotEmpty
              ? _SubjectsMode.curriculum
              : _SubjectsMode.unavailable;
    });
  }

  Future<void> _refreshSubjects() async {
    final collegeId = _selectedCollegeId;
    final dept = _selectedDepartment;
    if (collegeId == null || dept == null) return;

    final college = _colleges.where((c) => c.id == collegeId).firstOrNull;
    final courseCode =
        _departments.where((d) => d.name == dept).firstOrNull?.code;

    try {
      if (college != null && courseCode != null) {
        await _syllabusService.clearCurriculumCache(
          collegeCode: college.code,
          courseCode: courseCode,
        );
      }
      await _loadSubjectsPreview();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Curriculum cache refreshed and subjects reloaded!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _confirmAcademicDataReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
        title: const Text(
          'Change college or department?',
          style: TextStyle(
            fontFamily: 'Lexend Mega',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Changing your college or department will permanently clear your '
          'attendance records, timetable and saved subjects. This cannot be '
          'undone.',
          style: TextStyle(fontFamily: 'Public Sans', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear & Continue'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final collegeChanged = _selectedCollegeId != _initialCollegeId;
    final departmentChanged = _selectedDepartment != _initialDepartment;
    final semesterChanged = _selectedSemester != _initialSemester;

    if (collegeChanged || departmentChanged) {
      if (!await _confirmAcademicDataReset()) return;
      if (!mounted) return;
    }

    setState(() => _isSaving = true);

    final appState = Provider.of<AppStateNotifier>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final body = <String, dynamic>{};
      if (_nameController.text.trim().isNotEmpty) {
        body['name'] = _nameController.text.trim();
      }
      if (_selectedCollegeId != null) {
        body['collegeId'] = _selectedCollegeId;
      }
      if (_selectedDepartment != null) {
        body['department'] = _selectedDepartment;
      }
      if (_selectedSemester != null) {
        body['semester'] = _selectedSemester;
      }

      final response = await ApiService.instance.patch('/auth/me', body);
      final clearedAcademicData = response is Map<String, dynamic> &&
          response['clearedAcademicData'] == true;

      if (_nameController.text.trim().isNotEmpty) {
        await FirebaseAuth.instance.currentUser
            ?.updateDisplayName(_nameController.text.trim());
      }

      if (clearedAcademicData) {
        // The server wiped attendance, timetables and saved subjects for the
        // old college/department — drop every local trace of them too.
        appState.invalidateAcademicData();
        await _syllabusService.clearCache();
      } else if (semesterChanged) {
        // Timetable and attendance are per-semester; force a refetch so the
        // home screen doesn't keep showing the old semester's data.
        appState.invalidateAttendanceSummary();
        appState.invalidateTimetableSubjects();
      }

      // Reflect the subjects section into the app state (and, when the user
      // configured them here, onto the server) so home is correct on return.
      if (_selectedSemester != null && _editorController.hasEntries) {
        final subjects = _editorController.buildSubjects();
        if (_editorController.isDirty ||
            _subjectsMode == _SubjectsMode.unavailable) {
          // Manually-added subjects (no curriculum) always need saving —
          // there's no "untouched default" to fall back to.
          final regulation = _editorController.regulation ?? _customRegulation;
          await _syllabusService.saveSubjects(
            semester: _selectedSemester!,
            regulation: regulation,
            subjects: subjects,
          );
          appState.setSavedSubjects(subjects);
        } else if (_subjectsMode == _SubjectsMode.associated &&
            !clearedAcademicData) {
          appState.setSavedSubjects(subjects);
        } else {
          // Untouched curriculum defaults — cache them for the home screen
          // with the "tap to update with your electives" hint, but don't
          // claim them as the user's saved selection on the server.
          appState.setSavedSubjects(subjects, fromCurriculum: true);
        }
      } else if (_subjectsMode == _SubjectsMode.unavailable) {
        appState.invalidateSavedSubjects();
      }

      // Refresh local user profile via sync
      final syncResult = await AuthService.instance.syncProfile();
      final updatedProfile = syncResult.user;
      if (updatedProfile != null) {
        appState.setUserProfile(updatedProfile);
      }

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Profile updated!'), backgroundColor: Colors.green),
        );
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontFamily: 'Lexend Mega',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            letterSpacing: 0,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.grey.shade200,
                  color: Colors.black,
                  minHeight: 2,
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: MaxWidthContent(
            maxWidth: 600,
            child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration(color: Colors.white),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v != null &&
                                v.trim().isNotEmpty &&
                                v.trim().length < 2
                            ? 'Name must be at least 2 characters'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      SearchableDropdown<College>(
                        items: _colleges,
                        value: _selectedCollegeId != null
                            ? _colleges
                                .where((c) => c.id == _selectedCollegeId)
                                .firstOrNull
                            : null,
                        labelBuilder: (c) => c.name,
                        decoration: const InputDecoration(
                          labelText: 'College',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (college) {
                          setState(() => _selectedCollegeId = college?.id);
                          _loadSubjectsPreview();
                        },
                      ),
                      const SizedBox(height: 16),
                      SearchableDropdown<Department>(
                        items: _departments,
                        value: _selectedDepartment != null
                            ? _departments
                                .where((d) => d.name == _selectedDepartment)
                                .firstOrNull
                            : null,
                        labelBuilder: (d) => d.name,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (dept) {
                          setState(() => _selectedDepartment = dept?.name);
                          _loadSubjectsPreview();
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedSemester,
                        decoration: const InputDecoration(
                          labelText: 'Semester',
                          border: OutlineInputBorder(),
                        ),
                        items: semesters.map((sem) {
                          return DropdownMenuItem(
                            value: sem,
                            child: Text('Semester $sem'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedSemester = value);
                          _loadSubjectsPreview();
                        },
                      ),
                    ],
                  ),
                ),
                if ((_selectedCollegeId != _initialCollegeId ||
                        _selectedDepartment != _initialDepartment) &&
                    _initialCollegeId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accentPink.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.black.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Changing college or department clears your '
                            'attendance, timetable and subjects.',
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
                ],
                ..._subjectsSection(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isSaving || _isLoading) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryYellow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  List<Widget> _subjectsSection() {
    if (_subjectsMode == _SubjectsMode.none && !_subjectsLoading) {
      return const [];
    }

    final showEditor = !_subjectsLoading && _subjectsMode != _SubjectsMode.none;

    return [
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: Text(
              _selectedSemester != null
                  ? 'Semester $_selectedSemester Subjects'
                  : 'Subjects',
              style: const TextStyle(
                fontFamily: 'Lexend Mega',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          if (showEditor) ...[
            IconButton(
              onPressed: _refreshSubjects,
              icon: const Icon(Icons.refresh, color: Colors.black),
              tooltip: 'Refresh subjects',
            ),
            IconButton(
              onPressed: _editorController.showAddSubjectSheet,
              icon: const Icon(Icons.add_circle_outline, color: Colors.black),
              tooltip: 'Add subject',
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      if (_subjectsLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        )
      else ...[
        if (_subjectsMode == _SubjectsMode.unavailable) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(color: AppColors.accentPink),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.menu_book_outlined,
                        size: 22, color: Colors.black),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Syllabus not available in system',
                        style: TextStyle(
                          fontFamily: 'Lexend Mega',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'No curriculum found for college code '
                  '"${_previewCollegeCode ?? 'unknown'}" and course code '
                  '"${_previewCourseCode ?? 'unknown'}". '
                  'Add your subjects manually using the + button.',
                  style:
                      const TextStyle(fontFamily: 'Public Sans', fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accentBlue.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _subjectsMode == _SubjectsMode.associated
                      ? 'Your saved subjects for this semester. Tap a subject '
                          'to edit it — changes are applied when you save.'
                      : 'These are the default subjects from the curriculum. '
                          'Pick your electives and adjust them, then save.',
                  style: const TextStyle(
                    fontFamily: 'Public Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SubjectsEditor(
          semester: _selectedSemester ?? 0,
          bundle: _previewBundle,
          saved: _previewSaved,
          collegeCode: _previewCollegeCode,
          courseCode: _previewCourseCode,
          controller: _editorController,
          showSummaryHeader: false,
        ),
      ],
    ];
  }
}

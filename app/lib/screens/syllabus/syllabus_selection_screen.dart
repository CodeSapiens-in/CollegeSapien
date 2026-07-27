import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/api_models.dart';
import '../../models/syllabus_models.dart';
import '../../providers/app_state_notifier.dart';
import '../../providers/reference_data_store.dart';
import '../../services/auth_service.dart';
import '../../services/syllabus_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/subjects_editor.dart';
import '../home/main_navigation.dart';

/// Regulation tag used when the user saves subjects for a college/department
/// combination that has no curriculum in the system.
const _customRegulation = 'CUSTOM';

class SyllabusSelectionScreen extends StatefulWidget {
  const SyllabusSelectionScreen({super.key});

  @override
  State<SyllabusSelectionScreen> createState() =>
      _SyllabusSelectionScreenState();
}

class _SyllabusSelectionScreenState extends State<SyllabusSelectionScreen> {
  final _syllabusService = SyllabusService();
  final _editorController = SubjectsEditorController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  UserProfile? _profile;
  SavedSyllabus? _saved;
  CurriculumBundle? _bundle;
  String? _collegeCode;
  String? _courseCode;

  /// True once loading finishes and neither saved subjects nor a curriculum
  /// were found — the editor still shows (empty), just with a nudge to add
  /// subjects manually instead of a hard error.
  bool _curriculumUnavailable = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _curriculumUnavailable = false;
    });

    try {
      final syncResult = await AuthService.instance.syncProfile();
      final profile = syncResult.user;
      if (profile == null) {
        setState(() {
          _error = 'Profile not found';
          _isLoading = false;
        });
        return;
      }
      _profile = profile;

      // Saved subjects are the source of truth — fetch them first so a
      // missing curriculum can never hide subjects the user already saved.
      SavedSyllabus? saved;
      try {
        saved = await _syllabusService.getSavedSyllabus(profile.semester);
      } catch (_) {}

      // Resolve college/course and curriculum. Needed for the first-time
      // subject list and elective dropdowns, but optional once the user has
      // saved subjects.
      String? collegeCode;
      String? courseCode;
      CurriculumBundle? bundle;
      try {
        final colleges = await ReferenceDataStore.instance.listColleges();
        final departmentsList =
            await ReferenceDataStore.instance.listDepartments();
        final college =
            colleges.where((c) => c.id == profile.collegeId).firstOrNull;
        collegeCode = college?.code;

        final deptObj =
            departmentsList.where((d) => d.name == profile.department).firstOrNull;
        courseCode = deptObj?.code;

        if (collegeCode != null && courseCode != null) {
          bundle = await _syllabusService.getCurriculum(
            collegeCode: collegeCode,
            courseCode: courseCode,
          );
        }
      } catch (_) {}

      final hasSaved = saved != null && saved.subjects.isNotEmpty;
      var curriculumUnavailable = false;
      if (!hasSaved) {
        final curriculumSubjects = bundle == null
            ? <CurriculumSubject>[]
            : _syllabusService.getSubjectsForSemester(
                bundle,
                semester: profile.semester,
              );
        curriculumUnavailable = bundle == null || curriculumSubjects.isEmpty;
      }

      setState(() {
        _saved = saved;
        _bundle = bundle;
        _collegeCode = collegeCode;
        _courseCode = courseCode;
        _curriculumUnavailable = curriculumUnavailable;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_profile == null || !_editorController.hasEntries) return;
    final regulation = _editorController.regulation ?? _customRegulation;

    setState(() => _isSaving = true);
    try {
      final subjects = _editorController.buildSubjects();

      await _syllabusService.saveSubjects(
        semester: _profile!.semester,
        regulation: regulation,
        subjects: subjects,
      );

      if (mounted) {
        // Keep home in sync immediately — these are now the user's own
        // subjects, not a curriculum fallback.
        Provider.of<AppStateNotifier>(context, listen: false)
            .setSavedSubjects(subjects);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'Your Subjects',
          style: TextStyle(letterSpacing: 0),
        ),
        backgroundColor: AppColors.background,
        actions: [
          if (!_isLoading && _error == null)
            IconButton(
              onPressed: _editorController.showAddSubjectSheet,
              icon: const Icon(Icons.add_circle_outline, color: Colors.black),
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: (!_isLoading && _error == null)
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : _save,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSaving ? 'Saving...' : 'Save Subjects'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration:
                    AppTheme.cardDecoration(color: AppColors.accentPink),
                child: Column(
                  children: [
                    const Icon(Icons.menu_book_outlined,
                        size: 48, color: Colors.black),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Lexend Mega',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MainNavigation()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Continue to Home'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: MaxWidthContent(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_curriculumUnavailable) ...[
              _curriculumUnavailableBanner(),
              const SizedBox(height: 16),
            ],
            SubjectsEditor(
              semester: _profile?.semester ?? 0,
              bundle: _bundle,
              saved: _saved,
              collegeCode: _collegeCode,
              courseCode: _courseCode,
              controller: _editorController,
            ),
          ],
        ),
      ),
    );
  }

  Widget _curriculumUnavailableBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(color: AppColors.accentPink),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 22, color: Colors.black),
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
            'No curriculum found for college code "${_collegeCode ?? 'unknown'}" '
            'and course code "${_courseCode ?? 'unknown'}". '
            'Add your subjects manually using the + button.',
            style: const TextStyle(fontFamily: 'Public Sans', fontSize: 13),
          ),
        ],
      ),
    );
  }
}

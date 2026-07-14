import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/syllabus_models.dart';
import '../services/syllabus_service.dart';
import '../utils/app_theme.dart';
import 'searchable_dropdown.dart';

/// Handle for the host screen to pull the edited subject list out of a
/// [SubjectsEditor] (e.g. when saving) and to inspect its state.
class SubjectsEditorController {
  _SubjectsEditorState? _state;

  bool get hasEntries => _state?._entries.isNotEmpty ?? false;

  /// True once the user has modified anything (elective choice, edit,
  /// add or delete) since the editor was (re)seeded.
  bool get isDirty => _state?._dirty ?? false;

  String? get regulation => _state?._regulation;

  /// Opens the add-subject bottom sheet on the attached editor.
  void showAddSubjectSheet() => _state?.showAddSubjectSheet();

  /// Snapshot of the current entries as [SavedSubject]s, ready for
  /// SyllabusService.saveSubjects.
  List<SavedSubject> buildSubjects() {
    final entries = _state?._entries ?? const <_SubjectEntry>[];
    return entries.map((e) {
      final opt = e.selectedOption;
      final src = opt ?? e.subject;
      return SavedSubject(
        subjectCode: src.subjectCode,
        subjectName: opt?.subjectName ?? e.editedName ?? e.subject.subjectName,
        credits: e.editedCredits ?? src.credits,
        electiveType: e.subject.electiveType,
        isElective: e.subject.isElective,
        category: src.category.isNotEmpty ? src.category : null,
      );
    }).toList();
  }
}

/// Editable subject list for one semester. Seeds itself from the user's
/// saved subjects when available, otherwise from the curriculum bundle.
/// Renders as a shrink-wrapped column so hosts embed it in their own
/// scroll view.
class SubjectsEditor extends StatefulWidget {
  final CurriculumBundle? bundle;
  final SavedSyllabus? saved;
  final int semester;
  final String? collegeCode;
  final String? courseCode;
  final SubjectsEditorController? controller;
  final VoidCallback? onChanged;
  final bool showSummaryHeader;

  const SubjectsEditor({
    super.key,
    required this.semester,
    this.bundle,
    this.saved,
    this.collegeCode,
    this.courseCode,
    this.controller,
    this.onChanged,
    this.showSummaryHeader = true,
  });

  @override
  State<SubjectsEditor> createState() => _SubjectsEditorState();
}

class _SubjectsEditorState extends State<SubjectsEditor> {
  final _syllabusService = SyllabusService();

  List<_SubjectEntry> _entries = [];
  Map<String, List<CurriculumSubject>> _electiveOptions = {};
  String? _regulation;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _seed();
  }

  @override
  void didUpdateWidget(SubjectsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller?._state = this;
    if (oldWidget.bundle != widget.bundle ||
        oldWidget.saved != widget.saved ||
        oldWidget.semester != widget.semester) {
      setState(_seed);
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) {
      widget.controller?._state = null;
    }
    super.dispose();
  }

  void _markDirty() {
    _dirty = true;
    widget.onChanged?.call();
  }

  void _seed() {
    final bundle = widget.bundle;
    final saved = widget.saved;
    _dirty = false;
    _regulation = saved?.regulation ?? bundle?.regulation;

    var curriculumSubjects = <CurriculumSubject>[];
    final optionsMap = <String, List<CurriculumSubject>>{};
    if (bundle != null) {
      curriculumSubjects = _syllabusService.getSubjectsForSemester(
        bundle,
        semester: widget.semester,
      );
      final optionPools = curriculumSubjects
          .where((s) => s.isElectiveSlot && s.electiveType != null)
          .map((s) => s.electiveType!)
          .toSet();
      for (final pool in optionPools) {
        optionsMap[pool] = _syllabusService.getElectiveOptions(
          bundle,
          electiveType: pool,
        );
      }
    }

    final entries = <_SubjectEntry>[];
    if (saved != null && saved.subjects.isNotEmpty) {
      // User has saved subjects — show exactly those
      for (final sv in saved.subjects) {
        final subject = CurriculumSubject(
          collegeCode: widget.collegeCode ?? '',
          courseCode: widget.courseCode ?? '',
          regulation: _regulation ?? '',
          semester: widget.semester,
          subjectCode: sv.subjectCode,
          subjectName: sv.subjectName,
          credits: sv.credits,
          category: sv.category ?? '',
          electiveType: sv.electiveType,
          recordType: sv.isElective ? 'elective' : 'core',
        );
        CurriculumSubject? matchedOption;
        if (sv.isElective && sv.electiveType != null) {
          final pool = optionsMap[sv.electiveType] ?? [];
          matchedOption =
              pool.where((o) => o.subjectName == sv.subjectName).firstOrNull;
        }
        entries
            .add(_SubjectEntry(subject: subject, selectedOption: matchedOption));
      }
    } else {
      // First time — seed from curriculum
      for (final s in curriculumSubjects) {
        entries.add(_SubjectEntry(subject: s));
      }
    }

    _electiveOptions = optionsMap;
    _entries = entries;
  }

  void showAddSubjectSheet() {
    final nameCtrl = TextEditingController();
    final creditsCtrl = TextEditingController();
    bool isElective = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Subject',
                style: TextStyle(
                  fontFamily: 'Lexend Mega',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Subject Name',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: creditsCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Credits',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Type:',
                      style: TextStyle(
                          fontFamily: 'Public Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Core'),
                    selected: !isElective,
                    onSelected: (_) => setSheetState(() => isElective = false),
                    selectedColor: AppColors.accentGreen,
                    side: const BorderSide(color: Colors.black),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Elective'),
                    selected: isElective,
                    onSelected: (_) => setSheetState(() => isElective = true),
                    selectedColor: AppColors.accentPurple,
                    side: const BorderSide(color: Colors.black),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final credits = int.tryParse(creditsCtrl.text.trim());
                      if (name.isEmpty) return;
                      final newSubject = CurriculumSubject(
                        collegeCode: '',
                        courseCode: '',
                        regulation: _regulation ?? '',
                        semester: widget.semester,
                        subjectCode: '',
                        subjectName: name,
                        credits: credits,
                        category: '',
                        recordType: 'core',
                      );
                      setState(() {
                        _entries.add(_SubjectEntry(subject: newSubject));
                        _markDirty();
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(int index) {
    final entry = _entries[index];
    final currentName = entry.selectedOption?.subjectName ??
        entry.editedName ??
        entry.subject.subjectName;
    final currentCredits = entry.editedCredits ??
        entry.selectedOption?.credits ??
        entry.subject.credits;
    final nameCtrl = TextEditingController(text: currentName);
    final creditsCtrl = TextEditingController(text: '${currentCredits ?? ''}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Subject',
              style: TextStyle(
                fontFamily: 'Lexend Mega',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Subject Name',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: creditsCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Credits',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _entries.removeAt(index);
                      _markDirty();
                    });
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  label:
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final newName = nameCtrl.text.trim();
                    final newCredits = int.tryParse(creditsCtrl.text.trim());
                    setState(() {
                      _entries[index] = _SubjectEntry(
                        subject: entry.subject,
                        selectedOption: null,
                        editedName: newName.isNotEmpty ? newName : null,
                        editedCredits: newCredits,
                      );
                      _markDirty();
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCredits = _entries.fold<num>(
        0, (sum, e) => sum + (e.editedCredits ?? e.subject.credits ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showSummaryHeader) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(color: AppColors.primaryYellow),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Semester ${widget.semester}'
                  '${_regulation != null ? '  •  $_regulation' : ''}',
                  style: const TextStyle(
                    fontFamily: 'Lexend Mega',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_entries.length} subjects  •  $totalCredits credits',
                  style: TextStyle(
                    fontFamily: 'Public Sans',
                    fontSize: 13,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (var i = 0; i < _entries.length; i++) _buildSubjectCard(_entries[i], i),
      ],
    );
  }

  Widget _buildSubjectCard(_SubjectEntry entry, int index) {
    final subject = entry.subject;
    final isElectiveSlot = subject.isElectiveSlot;
    final hasOptions = isElectiveSlot &&
        subject.electiveType != null &&
        (_electiveOptions[subject.electiveType]?.isNotEmpty ?? false);
    final color =
        subject.isElective ? AppColors.accentPurple : AppColors.accentGreen;
    final displayName = entry.selectedOption?.subjectName ??
        entry.editedName ??
        subject.subjectName;
    final displayCredits =
        entry.editedCredits ?? entry.selectedOption?.credits ?? subject.credits;
    final isEdited = entry.editedName != null ||
        entry.editedCredits != null ||
        entry.selectedOption != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subject.isElective && subject.electiveType != null)
            Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subject.electiveType!,
                    style: const TextStyle(
                      fontFamily: 'Public Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (isEdited) ...[
                  const SizedBox(width: 8),
                  _editedBadge(),
                ],
              ],
            )
          else if (isEdited)
            _editedBadge(),
          if (hasOptions)
            _buildElectiveDropdown(entry, index)
          else
            Text(
              displayName,
              style: const TextStyle(
                fontFamily: 'Lexend Mega',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (displayCredits != null) _chip('$displayCredits credits'),
                     if (entry.selectedOption?.category != null && entry.selectedOption!.category.isNotEmpty)
                       _chip(entry.selectedOption!.category),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showEditSheet(index),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: Colors.black.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      size: 16, color: Colors.black54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _editedBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryYellow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: const Text(
        'edited',
        style: TextStyle(
          fontFamily: 'Public Sans',
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildElectiveDropdown(_SubjectEntry entry, int index) {
    final options = _electiveOptions[entry.subject.electiveType] ?? [];
    final currentValue =
        entry.selectedOption ?? _findMatchingOption(entry, options);

    return SearchableDropdown<CurriculumSubject>(
      items: options,
      value: currentValue,
      labelBuilder: (opt) =>
          '${opt.subjectName}${opt.category.isNotEmpty ? '  (${opt.category})' : ''}',
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.black, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.black, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.7),
        hintText: 'Type or select a subject',
        hintStyle: const TextStyle(
          fontFamily: 'Public Sans',
          fontSize: 13,
          color: Colors.black54,
        ),
      ),
      onChanged: (selected) {
        setState(() {
          _entries[index] = _SubjectEntry(
            subject: entry.subject,
            selectedOption: selected,
          );
          _markDirty();
        });
      },
    );
  }

  CurriculumSubject? _findMatchingOption(
      _SubjectEntry entry, List<CurriculumSubject> options) {
    final name = entry.editedName ?? entry.subject.subjectName;
    return options.where((o) => o.subjectName == name).firstOrNull;
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Public Sans',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _SubjectEntry {
  final CurriculumSubject subject;
  final String? editedName;
  final int? editedCredits;
  final CurriculumSubject? selectedOption;

  _SubjectEntry({
    required this.subject,
    this.editedName,
    this.editedCredits,
    this.selectedOption,
  });
}

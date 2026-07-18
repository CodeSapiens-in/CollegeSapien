import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/api_models.dart';
import '../../models/syllabus_models.dart';
import '../../services/auth_service.dart';
import '../../services/college_service.dart';
import '../../services/resource_service.dart';
import '../../services/syllabus_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/department_constants.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/searchable_dropdown.dart';

class SyllabusBrowserScreen extends StatefulWidget {
  const SyllabusBrowserScreen({super.key});

  @override
  State<SyllabusBrowserScreen> createState() => _SyllabusBrowserScreenState();
}

class _SyllabusBrowserScreenState extends State<SyllabusBrowserScreen> {
  final _resourceService = ResourceService();
  final _collegeService = CollegeService();
  final _syllabusService = SyllabusService();
  late Future<List<HubResource>> _future;
  double? _uploadProgress;
  String? _filterCollege;
  String? _filterDepartment;
  String? _filterRegulation;

  List<College> _colleges = [];
  List<Department> _departments = defaultDepartments;
  UserProfile? _userProfile;

  List<String> _regulationOptions = [];
  bool _curriculumLoading = false;
  String? _curriculumError;
  CurriculumBundle? _curriculumBundle;

  @override
  void initState() {
    super.initState();
    _future = _resourceService.listSyllabus();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final results = await Future.wait([
        _collegeService.listColleges(),
        _collegeService.listDepartments(),
        AuthService.instance.syncProfile(),
      ]);
      if (!mounted) return;
      final colleges = results[0] as List<College>
        ..sort((a, b) => a.name.compareTo(b.name));
      final departments = results[1] as List<Department>
        ..sort((a, b) => a.name.compareTo(b.name));
      setState(() {
        _colleges = colleges;
        _departments = departments;
        _userProfile = (results[2] as AuthSyncResult).user;
      });
    } catch (_) {}
  }

  void _refresh() {
    setState(() {
      _future = _resourceService.listSyllabus();
    });
  }

  String? get _selectedDepartmentCode => _departments
      .where((d) => d.name == _filterDepartment)
      .firstOrNull
      ?.code;

  void _onCollegeChanged(String? code) {
    setState(() {
      _filterCollege = code;
      _regulationOptions = [];
      _filterRegulation = null;
      _curriculumBundle = null;
    });
    _loadRegulations();
  }

  void _onDepartmentChanged(String? name) {
    setState(() {
      _filterDepartment = name;
      _regulationOptions = [];
      _filterRegulation = null;
      _curriculumBundle = null;
    });
    _loadRegulations();
  }

  Future<void> _loadRegulations() async {
    final collegeCode = _filterCollege;
    final courseCode = _selectedDepartmentCode;
    if (collegeCode == null || courseCode == null) return;
    try {
      final bundle = await _syllabusService.getCurriculum(
        collegeCode: collegeCode,
        courseCode: courseCode,
      );
      if (!mounted) return;
      setState(() => _regulationOptions = bundle.availableRegulations);
    } catch (_) {
      if (!mounted) return;
      setState(() => _regulationOptions = []);
    }
  }

  Future<void> _loadCurriculum() async {
    final collegeCode = _filterCollege;
    final courseCode = _selectedDepartmentCode;
    final regulation = _filterRegulation;
    if (collegeCode == null || courseCode == null || regulation == null) {
      return;
    }
    setState(() {
      _curriculumLoading = true;
      _curriculumError = null;
    });
    try {
      final bundle = await _syllabusService.getCurriculum(
        collegeCode: collegeCode,
        courseCode: courseCode,
        regulation: regulation,
      );
      if (!mounted) return;
      setState(() {
        _curriculumBundle = bundle;
        _curriculumLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _curriculumError = e.toString();
        _curriculumLoading = false;
      });
    }
  }

  HubResource? _findProfileSyllabus(List<HubResource> items) {
    final profile = _userProfile;
    if (profile == null || profile.department == null) return null;
    return items
        .where((r) => r.department == profile.department)
        .firstOrNull;
  }

  Future<void> _pickAndUpload() async {
    String? uploadCollegeId = _userProfile?.collegeId;
    String? uploadDepartment = _userProfile?.department;
    String? uploadRegulation;

    final uploadData = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final college =
              _colleges.where((c) => c.id == uploadCollegeId).firstOrNull;
          final deptObj = _departments
              .where((d) => d.name == uploadDepartment)
              .firstOrNull;
          final autoTitle =
              (college != null && deptObj != null && uploadRegulation != null)
                  ? '${college.code}_${deptObj.code}_$uploadRegulation'
                  : null;

          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Upload Syllabus',
                    style: TextStyle(
                        fontFamily: 'Lexend Mega',
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                SearchableDropdown<College>(
                  items: _colleges,
                  value: uploadCollegeId != null
                      ? _colleges
                          .where((c) => c.id == uploadCollegeId)
                          .firstOrNull
                      : null,
                  labelBuilder: (c) => c.name,
                  decoration: InputDecoration(
                    labelText: 'College',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (c) =>
                      setSheetState(() => uploadCollegeId = c?.id),
                ),
                const SizedBox(height: 12),
                SearchableDropdown<Department>(
                  items: _departments,
                  value: uploadDepartment != null
                      ? _departments
                          .where((d) => d.name == uploadDepartment)
                          .firstOrNull
                      : null,
                  labelBuilder: (d) => d.name,
                  decoration: InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (d) =>
                      setSheetState(() => uploadDepartment = d?.name),
                ),
                const SizedBox(height: 12),
                SearchableDropdown<String>(
                  items: regulations,
                  value: uploadRegulation,
                  labelBuilder: (r) => r,
                  decoration: InputDecoration(
                    labelText: 'Regulation',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (r) =>
                      setSheetState(() => uploadRegulation = r),
                ),
                if (autoTitle != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'File name: $autoTitle',
                    style: TextStyle(
                      fontFamily: 'Public Sans',
                      fontSize: 13,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: (uploadCollegeId != null &&
                              uploadDepartment != null &&
                              uploadRegulation != null)
                          ? () => Navigator.pop(ctx, {
                                'collegeId': uploadCollegeId!,
                                'department': uploadDepartment!,
                                'regulation': uploadRegulation!,
                                'title': autoTitle!,
                              })
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    if (uploadData == null) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    final file = result?.files.single;
    if (file == null) return;

    final ext = file.extension ?? 'pdf';
    final storageName = '${uploadData['title']}.$ext';

    if (mounted) setState(() => _uploadProgress = 0.0);
    try {
      await _resourceService.uploadLocalFile(
        file: file,
        title: uploadData['title']!,
        category: 'Syllabus',
        mimeType: ext == 'pdf' ? 'application/pdf' : 'image/$ext',
        regulation: uploadData['regulation'],
        overrideFileName: storageName,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );

      if (mounted) setState(() => _uploadProgress = null);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Uploaded for moderation.'),
            backgroundColor: Colors.green),
      );
      _refresh();
    } catch (e) {
      if (mounted) setState(() => _uploadProgress = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'Syllabus Browser',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(letterSpacing: 0),
        ),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.black),
            onPressed: _pickAndUpload,
          ),
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: _refresh),
        ],
      ),
      body: Column(
        children: [
          if (_uploadProgress != null)
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: Colors.grey.shade200,
              color: Colors.black,
              minHeight: 4,
            ),
          Expanded(
            child: SafeArea(
              child: FutureBuilder<List<HubResource>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }

                  final allItems = snapshot.data ?? [];
                  final profileMatch = _findProfileSyllabus(allItems);

                  return MaxWidthContent(
                    maxWidth: 1000,
                    child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (profileMatch != null) ...[
                        const Text(
                          'Your Syllabus',
                          style: TextStyle(
                            fontFamily: 'Lexend Mega',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSyllabusCard(profileMatch, highlighted: true),
                        const Divider(height: 32),
                      ],
                      if (_colleges.isNotEmpty) ...[
                        SearchableDropdown<College>(
                          items: _colleges,
                          value: _filterCollege != null
                              ? _colleges
                                  .where((c) => c.code == _filterCollege)
                                  .firstOrNull
                              : null,
                          labelBuilder: (c) => c.name,
                          decoration: InputDecoration(
                            labelText: 'College',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (c) => _onCollegeChanged(c?.code),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SearchableDropdown<Department>(
                        items: _departments,
                        value: _filterDepartment != null
                            ? _departments
                                .where((d) => d.name == _filterDepartment)
                                .firstOrNull
                            : null,
                        labelBuilder: (d) => d.name,
                        decoration: InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (d) => _onDepartmentChanged(d?.name),
                      ),
                      const SizedBox(height: 12),
                      SearchableDropdown<String>(
                        items: _regulationOptions,
                        value: _filterRegulation,
                        labelBuilder: (r) => r,
                        decoration: InputDecoration(
                          labelText: 'Regulation',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (r) {
                          setState(() => _filterRegulation = r);
                          _loadCurriculum();
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildCurriculumSection(),
                    ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurriculumSection() {
    if (_filterCollege == null || _filterDepartment == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(color: AppColors.accentGreen),
        child: const Text('Select a college and department to view the curriculum.'),
      );
    }
    if (_filterRegulation == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(color: AppColors.accentGreen),
        child: Text(_regulationOptions.isEmpty
            ? 'No curriculum found for this college and department.'
            : 'Select a regulation to view the curriculum.'),
      );
    }
    if (_curriculumLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_curriculumError != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(color: AppColors.accentPink),
        child: Text(_curriculumError!),
      );
    }
    final bundle = _curriculumBundle;
    if (bundle == null || bundle.subjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(color: AppColors.accentGreen),
        child: const Text('No subjects found for this curriculum.'),
      );
    }

    final core = bundle.subjects.where((s) => !s.isOption).toList();
    final electives = bundle.subjects.where((s) => s.isOption).toList();

    final bySemester = <int, List<CurriculumSubject>>{};
    for (final subject in core) {
      bySemester.putIfAbsent(subject.semester ?? 0, () => []).add(subject);
    }
    final semesters = bySemester.keys.toList()..sort();

    final byElectiveType = <String, List<CurriculumSubject>>{};
    for (final subject in electives) {
      final type = subject.electiveType?.trim();
      byElectiveType
          .putIfAbsent(type?.isNotEmpty == true ? type! : 'Electives', () => [])
          .add(subject);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final semester in semesters)
          _buildSubjectGroup(
            semester == 0 ? 'Unassigned' : 'Semester $semester',
            bySemester[semester]!,
          ),
        for (final type in byElectiveType.keys)
          _buildSubjectGroup(type, byElectiveType[type]!),
      ],
    );
  }

  Widget _buildSubjectGroup(String title, List<CurriculumSubject> subjects) {
    // ListTile (inside ExpansionTile) paints its background/ink splashes on
    // the nearest Material ancestor — a colored Container in between hides
    // them, so the fill color lives on a Material here instead.
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(offset: const Offset(4, 4), color: AppColors.shadow),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Material(
          color: AppColors.accentGreen,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Lexend Mega',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                for (final subject in subjects) _buildSubjectTile(subject),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectTile(CurriculumSubject subject) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(color: AppColors.accentGreen),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.subjectName,
                  style: const TextStyle(
                    fontFamily: 'Lexend Mega',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${subject.subjectCode} · ${subject.category}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (subject.credits != null)
            Text('${subject.credits} cr',
                style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSyllabusCard(HubResource item,
      {bool highlighted = false, bool includeMargin = true}) {
    final url = item.fileUrl;
    return Container(
      margin: includeMargin ? const EdgeInsets.only(bottom: 16) : null,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(
          color: highlighted ? AppColors.primaryYellow : AppColors.accentGreen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: const TextStyle(
              fontFamily: 'Lexend Mega',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          if (item.department != null) ...[
            const SizedBox(height: 8),
            Text(item.department!),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: url == null
                ? null
                : () => launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.download, size: 18, color: Colors.black),
            label: const Text('Open', style: TextStyle(color: Colors.black)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Colors.black, width: 2),
            ),
          ),
        ],
      ),
    );
  }
}

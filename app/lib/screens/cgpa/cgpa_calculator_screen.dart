import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/cgpa_models.dart';
import '../../providers/app_state_notifier.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/responsive_layout.dart';
import '../../services/academic_service.dart';
import '../../services/api_service.dart';

class CgpaCalculatorScreen extends StatefulWidget {
  const CgpaCalculatorScreen({super.key});

  @override
  State<CgpaCalculatorScreen> createState() => _CgpaCalculatorScreenState();
}

class _CgpaCalculatorScreenState extends State<CgpaCalculatorScreen> {
  bool _isScanning = false;
  final _academicService = AcademicService();
  final List<CgpaSemesterEntry> _semesters = [];

  @override
  void initState() {
    super.initState();
    _loadSemesters();
  }

  final List<Color> _semesterColors = [
    AppColors.accentGreen,
    AppColors.accentBlue,
    AppColors.accentPurple,
    AppColors.primaryYellow,
    AppColors.accentPink,
    AppColors.accentGreen,
    AppColors.accentBlue,
    AppColors.accentPurple,
  ];

  double get _computedCgpa {
    if (_semesters.isEmpty) return 0.0;
    final totalCredits = _semesters.fold(0, (s, e) => s + e.credits);
    if (totalCredits == 0) return 0.0;
    return _semesters.fold(0.0, (s, e) => s + e.gpa * e.credits) / totalCredits;
  }

  List<CgpaSemesterEntry> _parseSemesterList(List<dynamic> list) {
    return list
        .map((item) =>
            CgpaSemesterEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _loadSemesters() async {
    final box = AppStateNotifier.instance.cgpaSemestersBox;

    // Try API first; fall back to the local cache.
    try {
      final json = await ApiService.instance.get('/cgpa/semesters')
          as Map<String, dynamic>;
      final list = json['semesters'] as List<dynamic>? ?? [];
      final entries = _parseSemesterList(list);
      if (!mounted) return;
      setState(() {
        _semesters
          ..clear()
          ..addAll(entries);
      });
      box.set(entries.map((e) => e.copy()).toList());
      return;
    } catch (_) {}

    // Fallback: local cache, even if stale (offline-tolerant).
    if (!box.hasValue) await box.hydrate();
    final cached = box.staleValueOrNull;
    if (cached == null || !mounted) return;
    setState(() {
      _semesters
        ..clear()
        ..addAll(cached.map((e) => e.copy()));
    });
  }

  Future<void> _saveCgpa() async {
    final snapshot = _semesters.map((e) => e.copy()).toList();

    // Persist locally first (instant, no network).
    await AppStateNotifier.instance.cgpaSemestersBox.set(snapshot);

    // Sync to Firebase (fire-and-forget; failures are silent).
    ApiService.instance.post('/cgpa/semesters', {
      'semesters': snapshot.map((e) => e.toJson()).toList(),
    }).catchError((_) {});
  }

  Future<void> _uploadGradeSheet() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isScanning = true);

    try {
      final bytes = await image.readAsBytes();
      final result = await _academicService.calculateCgpaFromImage(bytes);
      final cgpa =
          (result['cgpa'] as num? ?? result['gpa'] as num? ?? 0).toDouble();
      if (!mounted) return;

      // If AI returns a CGPA, add it as a single entry if list is empty
      if (cgpa > 0 && _semesters.isEmpty) {
        setState(() {
          _semesters.add(CgpaSemesterEntry(semester: 1, gpa: cgpa, credits: 25));
          _isScanning = false;
        });
        await _saveCgpa();
      } else {
        setState(() => _isScanning = false);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cgpa > 0
                ? 'AI scanned CGPA: ${cgpa.toStringAsFixed(2)}. Adjust credits if needed.'
                : 'Could not extract CGPA from image. Add semesters manually.',
          ),
          backgroundColor: cgpa > 0 ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showAddSemesterDialog() async {
    final gpaController = TextEditingController();
    final creditsController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Semester ${_semesters.length + 1}',
          style: const TextStyle(fontFamily: 'Lexend Mega', fontSize: 16),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: gpaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'GPA (e.g. 8.5)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null || val < 0 || val > 10) {
                    return 'Enter a valid GPA (0–10)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: creditsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total Credits',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final val = int.tryParse(v ?? '');
                  if (val == null || val <= 0) {
                    return 'Enter total credits for this semester';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryYellow),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              setState(() {
                _semesters.add(CgpaSemesterEntry(
                  semester: _semesters.length + 1,
                  gpa: double.parse(gpaController.text),
                  credits: int.parse(creditsController.text),
                ));
              });
              _saveCgpa();
              Navigator.pop(ctx);
            },
            child: const Text('Add', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _removeSemester(int index) {
    setState(() {
      _semesters.removeAt(index);
      // Renumber remaining semesters
      for (var i = 0; i < _semesters.length; i++) {
        _semesters[i].semester = i + 1;
      }
    });
    _saveCgpa();
  }

  String _getMotivationalMessage() {
    final cgpa = _computedCgpa;
    if (cgpa >= 8.5) return AppConstants.highCGPAMessages[0];
    if (cgpa >= 6.0) return AppConstants.averageCGPAMessages[0];
    if (cgpa > 0) return AppConstants.lowCGPAMessages[0];
    return 'Add your semester scores to calculate CGPA';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cgpa = _computedCgpa;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'CGPA Calculator',
          style: TextStyle(
            fontFamily: 'Lexend Mega',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ResponsiveLayout(
              mobile: (_) => _mobileBody(screenWidth, cgpa),
              desktop: (_) => _desktopBody(context, cgpa),
            ),
            if (_isScanning) _loadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _mobileBody(double screenWidth, double cgpa) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.045),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _summaryCard(cgpa),
          const SizedBox(height: 30),
          _uploadButton(),
          const SizedBox(height: 30),
          _semesterBreakdownHeader(),
          const SizedBox(height: 16),
          _semesterList(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // Desktop: entries (upload button + semester list) scroll on the left;
  // the computed CGPA stays as a persistent, non-scrolling summary panel on
  // the right instead of requiring a scroll back to the top to see it.
  Widget _desktopBody(BuildContext context, double cgpa) {
    final width = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.all(AppSpacing.pagePadding(width)),
      child: MaxWidthContent(
        maxWidth: 960,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _uploadButton(),
                    const SizedBox(height: 30),
                    _semesterBreakdownHeader(),
                    const SizedBox(height: 16),
                    _semesterList(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            SizedBox(width: AppSpacing.xl),
            SizedBox(width: 320, child: _summaryCard(cgpa)),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(double cgpa) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: AppTheme.cardDecoration(
        color: AppColors.primaryYellow,
        shadowOffset: const Offset(8, 8),
      ),
      child: Column(
        children: [
          const Icon(Icons.stars, size: 60),
          const SizedBox(height: 20),
          Text(
            _semesters.isEmpty ? '--' : cgpa.toStringAsFixed(2),
            style: const TextStyle(
              fontFamily: 'Lexend Mega',
              fontSize: 60,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Current CGPA',
            style: TextStyle(
              fontFamily: 'Public Sans',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: AppTheme.badgeDecoration(color: AppColors.accentGreen),
            child: Text(
              _getMotivationalMessage(),
              style: const TextStyle(
                fontFamily: 'Public Sans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isScanning ? null : _uploadGradeSheet,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.black, width: 2),
          ),
        ),
        icon: const Icon(Icons.camera_alt, color: Colors.black),
        label: const Text(
          'Scan Grade Sheet with AI',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _semesterBreakdownHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Semester Breakdown',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF191C1E),
          ),
        ),
        GestureDetector(
          onTap: _showAddSemesterDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: AppTheme.cardDecoration(
              color: AppColors.accentGreen,
              shadowOffset: const Offset(2, 2),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 16),
                SizedBox(width: 4),
                Text(
                  'Add Semester',
                  style: TextStyle(
                    fontFamily: 'Public Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _semesterList() {
    if (_semesters.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.cardDecoration(color: AppColors.accentBlue),
        child: const Text(
          'No semesters yet. Add your semester GPA and credits to calculate your CGPA.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Public Sans', fontWeight: FontWeight.w600),
        ),
      );
    }
    return Column(
      children:
          List.generate(_semesters.length, (i) => _buildSemesterCard(i)),
    );
  }

  Widget _loadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.primaryYellow),
            ),
            const SizedBox(height: 16),
            const Text(
              'Analyzing grade sheet...\nGemini AI is working...',
              style: TextStyle(
                fontFamily: 'Public Sans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSemesterCard(int index) {
    final entry = _semesters[index];
    final color = _semesterColors[index % _semesterColors.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(color: color),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Semester ${entry.semester}',
                  style: const TextStyle(
                    fontFamily: 'Public Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  '${entry.credits} credits',
                  style: TextStyle(
                    fontFamily: 'Public Sans',
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            entry.gpa.toStringAsFixed(2),
            style: const TextStyle(
              fontFamily: 'Lexend Mega',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _removeSemester(index),
            child: const Icon(Icons.close, size: 20, color: Colors.black),
          ),
        ],
      ),
    );
  }
}

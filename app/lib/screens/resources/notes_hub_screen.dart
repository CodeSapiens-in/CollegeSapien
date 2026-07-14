import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/api_models.dart';
// import '../../services/api_service.dart'; // mod: mod endpoints removed
import '../../providers/resources_cache_store.dart';
import '../../services/app_capability_service.dart';
import '../../services/resource_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/resource_grid_section.dart';

class NotesHubScreen extends StatefulWidget {
  const NotesHubScreen({super.key});

  @override
  State<NotesHubScreen> createState() => _NotesHubScreenState();
}

class _NotesHubScreenState extends State<NotesHubScreen> {
  static const _unlockPrefsKey = 'has_approved_hub_upload';

  final _resourceService = ResourceService();
  final _capabilityService = AppCapabilityService.instance;
  final _searchController = TextEditingController();
  late Future<List<HubResource>> _future;
  bool _isUnlocked = false;
  bool _canBypassUnlock = false;
  // mod: _isMod + _pending removed — moderation moved to web admin panel
  // bool _isMod = false;
  // List<HubResource> _pending = [];
  double? _uploadProgress;
  String? _selectedSubjectId;
  final _subjectNameController = TextEditingController();
  final _subjectCodeController = TextEditingController();
  final _titleController = TextEditingController();

  bool get _downloadsUnlocked => _canBypassUnlock || _isUnlocked;

  @override
  void initState() {
    super.initState();
    _future = _initialLoad();
    _loadMeta();
    _fetchFresh();
  }

  Future<List<HubResource>> _initialLoad() async {
    final box = ResourcesCacheStore.instance.notesBox;
    if (!box.hasValue) await box.hydrate();
    final cached = box.valueOrNull;
    if (cached != null) return cached;
    return _resourceService.listHubResources('Notes');
  }

  Future<void> _fetchFresh() async {
    try {
      final fresh = await _resourceService.listHubResources('Notes');
      ResourcesCacheStore.instance.notesBox.set(fresh);
      if (mounted) {
        setState(() {
          _future = Future.value(fresh);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMeta() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _isUnlocked = prefs.getBool(_unlockPrefsKey) ?? false);
    }

    try {
      final capabilities = await _capabilityService.resolveCapabilities();
      if (mounted) {
        setState(() {
          _canBypassUnlock = capabilities.bypassResourceUnlock;
          // mod: _isMod removed — pending queue moved to web admin panel
          // _isMod = capabilities.canModerateResources;
        });
      }

      // mod: pending resource fetch removed — moderation moved to web admin panel
      // if (isMod) {
      //   final raw = await ApiService.instance
      //       .get('/admin/resources/pending?category=Notes') as List<dynamic>;
      //   if (mounted) {
      //     setState(() {
      //       _pending = raw
      //           .map((item) =>
      //               HubResource.fromJson(item as Map<String, dynamic>))
      //           .toList();
      //     });
      //   }
      // } else {
      final isUnlocked = await _resourceService.hasApprovedHubContribution();
      await prefs.setBool(_unlockPrefsKey, isUnlocked);
      if (mounted) {
        setState(() => _isUnlocked = isUnlocked);
      }
      // }
    } catch (_) {}
  }

  void _refresh() {
    ResourcesCacheStore.instance.notesBox.invalidate();
    setState(() {
      _future = _resourceService.listHubResources('Notes');
    });
    _future
        .then((fresh) => ResourcesCacheStore.instance.notesBox.set(fresh))
        .ignore();
    _loadMeta();
  }

  Future<void> _pickAndUpload() async {
    _subjectNameController.clear();
    _subjectCodeController.clear();
    _titleController.clear();

    final uploadData = await showModalBottomSheet<Map<String, String>>(
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
              const Text('Upload Notes',
                  style: TextStyle(
                      fontFamily: 'Lexend Mega',
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: _subjectNameController,
                decoration: InputDecoration(
                  labelText: 'Subject Name',
                  hintText: 'e.g., Data Structures',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subjectCodeController,
                decoration: InputDecoration(
                  labelText: 'Subject Code',
                  hintText: 'e.g., CS3401',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Document Title',
                  hintText: 'e.g., Unit 1 Notes',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, {
                      'subjectName': _subjectNameController.text.trim(),
                      'subjectCode': _subjectCodeController.text.trim(),
                      'title': _titleController.text.trim(),
                    }),
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
        ),
      ),
    );

    if (uploadData == null) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    final file = result?.files.single;
    if (file == null) return;

    if (mounted) setState(() => _uploadProgress = 0.0);
    try {
      await _resourceService.uploadLocalFile(
        file: file,
        title: uploadData['title'] ?? file.name,
        category: 'Notes',
        mimeType: file.extension == 'pdf'
            ? 'application/pdf'
            : 'image/${file.extension}',
        subjectId: uploadData['subjectCode'],
        subjectName: uploadData['subjectName'],
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

  // mod: approve/reject/archive methods removed — moderation moved to web admin panel
  // Future<void> _approveResource(String id) async { ... }
  // Future<void> _rejectResource(String id) async { ... }
  // Future<void> _archiveResource(String id) async { ... }

  @override
  void dispose() {
    _searchController.dispose();
    _subjectNameController.dispose();
    _subjectCodeController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'Notes Hub',
          style: TextStyle(
            fontFamily: 'Lexend Mega',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            letterSpacing: 0,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.black),
            onPressed: _pickAndUpload,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _refresh,
          ),
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
                    return _ErrorState(
                        message: snapshot.error.toString(), onRetry: _refresh);
                  }

                  final allResources = snapshot.data ?? [];
                  final subjects = allResources
                      .map((r) => r.subjectId)
                      .whereType<String>()
                      .toSet()
                      .toList()
                    ..sort();

                  final query = _searchController.text.toLowerCase();
                  final resources = allResources.where((r) {
                    final matchesSubject = _selectedSubjectId == null ||
                        r.subjectId == _selectedSubjectId;
                    final matchesSearch = query.isEmpty ||
                        r.name.toLowerCase().contains(query) ||
                        r.keywords.any((k) => k.toLowerCase().contains(query));
                    return matchesSubject && matchesSearch;
                  }).toList();

                  return MaxWidthContent(
                    maxWidth: 1000,
                    child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Search field
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search notes...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (subjects.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          initialValue: _selectedSubjectId,
                          decoration: InputDecoration(
                            labelText: 'Subject',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Subjects'),
                            ),
                            ...subjects.map(
                              (code) {
                                final matchingResources = allResources
                                    .where((r) => r.subjectId == code)
                                    .toList();
                                final subjectName = matchingResources
                                    .firstWhere(
                                      (r) => r.subjectName != null,
                                      orElse: () => matchingResources.first,
                                    )
                                    .subjectName;
                                final label = subjectName != null
                                    ? '$subjectName ($code)'
                                    : code;
                                return DropdownMenuItem<String?>(
                                  value: code,
                                  child: Text(label,
                                      overflow: TextOverflow.ellipsis),
                                );
                              },
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedSubjectId = v),
                        ),
                      ],
                      const SizedBox(height: 16),

                      _buildInfoBanner(),
                      const SizedBox(height: 24),

                      // mod: pending approval section removed — moderation moved to web admin panel
                      // if (_isMod && _pending.isNotEmpty) ...[
                      //   Container(
                      //     padding: const EdgeInsets.all(16),
                      //     decoration: AppTheme.cardDecoration(color: AppColors.accentPink),
                      //     child: const Row(
                      //       children: [
                      //         Icon(Icons.pending_actions, size: 20),
                      //         SizedBox(width: 8),
                      //         Text('Pending Approval', ...),
                      //       ],
                      //     ),
                      //   ),
                      //   ..._pending.map((r) => _buildPendingCard(r)),
                      // ],

                      if (resources.isEmpty)
                        _buildEmptyState()
                      else
                        ResourceGridSection(
                          items: resources,
                          cardBuilder: _buildResourceCard,
                        ),
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

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(color: AppColors.primaryYellow),
      child: Row(
        children: [
          const Icon(Icons.verified_user, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _canBypassUnlock
                  ? 'Staff access: downloads are unlocked.'
                  : _isUnlocked
                      ? 'Downloads are unlocked. You have at least one approved upload.'
                      : 'Get 1 upload approved to unlock Notes and Question Papers.',
              style: const TextStyle(
                fontFamily: 'Public Sans',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(color: AppColors.accentBlue),
      child: const Text('No approved notes yet.'),
    );
  }

  Widget _buildResourceCard(HubResource resource, {bool includeMargin = true}) {
    return Container(
      margin: includeMargin ? const EdgeInsets.only(bottom: 16) : null,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(color: AppColors.accentBlue),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resource.name,
            style: const TextStyle(
              fontFamily: 'Lexend Mega',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text('Uploaded by: ${resource.uploaderName}'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _downloadsUnlocked && resource.fileUrl != null
                      ? () => launchUrl(Uri.parse(resource.fileUrl!),
                          mode: LaunchMode.externalApplication)
                      : null,
                  icon: const Icon(Icons.download, size: 18),
                  label: Text(_downloadsUnlocked ? 'Open' : 'Locked'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black, width: 2),
                    disabledBackgroundColor: Colors.grey.shade200,
                  ),
                ),
              ),
              if (_downloadsUnlocked) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showReportSheet(resource.id),
                  icon: const Icon(Icons.flag_outlined, size: 14),
                  label: const Text(''),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    textStyle: const TextStyle(fontSize: 12),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
          // mod: Archive button removed — moderation moved to web admin panel
          // if (_isMod) ...[
          //   const SizedBox(height: 10),
          //   OutlinedButton.icon(
          //     onPressed: () => _archiveResource(resource.id),
          //     ...
          //   ),
          // ],
        ],
      ),
    );
  }

  Future<void> _showReportSheet(String resourceId) async {
    String? selectedType;
    final reasonController = TextEditingController();

    await showModalBottomSheet(
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
              const Text('Report document',
                  style: TextStyle(
                      fontFamily: 'Lexend Mega',
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: InputDecoration(
                  labelText: 'Reason type',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'spam', child: Text('Spam')),
                  DropdownMenuItem(
                      value: 'incorrect', child: Text('Incorrect content')),
                  DropdownMenuItem(value: 'abusive', child: Text('Abusive')),
                  DropdownMenuItem(
                      value: 'low_quality', child: Text('Low quality')),
                ],
                onChanged: (v) => setSheetState(() => selectedType = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Details',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: selectedType == null ||
                            reasonController.text.trim().length < 5
                        ? null
                        : () => Navigator.pop(ctx, {
                              'type': selectedType,
                              'reason': reasonController.text.trim(),
                            }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((result) async {
      if (result == null) return;
      try {
        await _resourceService.reportResource(
          resourceId: resourceId,
          type: result['type'] as String,
          reason: result['reason'] as String,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Report submitted. Thank you.'),
              backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    });
  }

  // mod: _buildPendingCard removed — moderation moved to web admin panel
  // Widget _buildPendingCard(HubResource resource) { ... }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

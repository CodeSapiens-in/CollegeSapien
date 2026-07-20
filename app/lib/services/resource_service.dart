import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/api_models.dart';
import 'api_service.dart';
import 'platform/file_uploader.dart';

class ResourceService {
  final _uuid = const Uuid();

  Future<bool> hasApprovedHubContribution() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final results = await Future.wait([
      listHubResources('Notes'),
      listHubResources('QP'),
    ]);

    return results
        .expand((items) => items)
        .any((item) => item.uploadedBy == uid);
  }

  Future<List<HubResource>> listHubResources(
    String category, {
    String? regulation,
    String? subjectCode,
  }) async {
    final params = <String, String>{'category': category};
    if (regulation != null) params['regulation'] = regulation;
    if (subjectCode != null) params['subjectId'] = subjectCode;

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final json =
        await ApiService.instance.get('/resources/hub?$query') as List<dynamic>;
    return json
        .map((item) => HubResource.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<HubResource>> listSyllabus({
    String? department,
    String? regulation,
    String? subjectCode,
  }) async {
    final params = <String, String>{};
    if (department != null) params['department'] = department;
    if (regulation != null) params['regulation'] = regulation;
    if (subjectCode != null) params['subjectId'] = subjectCode;

    final query = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
        : '';
    final json = await ApiService.instance.get('/resources/syllabus$query')
        as List<dynamic>;
    return json
        .map((item) => HubResource.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<String> uploadResourceMetadata({
    String? id,
    required String name,
    required String category,
    String? department,
    String? storagePath,
    String? fileUrl,
    String? fileName,
    String? mimeType,
    int? sizeBytes,
    String? subjectId,
    String? subjectName,
    String? regulation,
  }) async {
    final resourceId = id ?? _uuid.v4();
    final json = await ApiService.instance.post('/resources/upload', {
      'id': resourceId,
      'name': name,
      'category': category,
      if (department != null) 'department': department,
      if (storagePath != null) 'storagePath': storagePath,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (mimeType != null) 'mimeType': mimeType,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
      if (subjectId != null) 'subjectId': subjectId,
      if (subjectName != null) 'subjectName': subjectName,
      if (regulation != null) 'regulation': regulation,
    }) as Map<String, dynamic>;
    return json['id'] as String;
  }

  Future<String> uploadLocalFile({
    required PlatformFile file,
    required String title,
    required String category,
    String? mimeType,
    String? subjectId,
    String? subjectName,
    String? regulation,
    String? overrideFileName,
    void Function(double)? onProgress,
  }) async {
    final id = _uuid.v4();
    final fileSize = file.size;
    final fileName = overrideFileName ?? file.name;

    // Create Firestore doc first so storage read rule can verify uploadedBy
    final resourceId = await uploadResourceMetadata(
      id: id,
      name: title,
      category: category,
      storagePath: 'resources/$id/$fileName',
      fileName: fileName,
      mimeType: mimeType,
      sizeBytes: fileSize,
      subjectId: subjectId,
      subjectName: subjectName,
      regulation: regulation,
    );

    // Upload to Storage with progress tracking (resumable by default)
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
    final ref = resourceFileRef(resourceId, fileName);
    final metadata =
        SettableMetadata(contentType: mimeType ?? 'application/pdf');

    await PlatformFileUploader.uploadFile(
      ref: ref,
      file: file,
      metadata: metadata,
      onProgress: onProgress,
    );

    final downloadUrl = await ref.getDownloadURL();

    // Update Firestore doc with the final download URL
    await ApiService.instance
        .patch('/resources/$resourceId', {'fileUrl': downloadUrl});

    return resourceId;
  }

  Future<void> renameResource({
    required String resourceId,
    required String name,
  }) async {
    await ApiService.instance.patch('/resources/$resourceId', {'name': name});
  }

  Future<void> reportResource({
    required String resourceId,
    required String type,
    required String reason,
  }) async {
    await ApiService.instance.post('/resources/report', {
      'resourceId': resourceId,
      'type': type,
      'reason': reason,
    });
  }

  Reference resourceFileRef(String resourceId, String fileName) {
    return FirebaseStorage.instance.ref('resources/$resourceId/$fileName');
  }
}

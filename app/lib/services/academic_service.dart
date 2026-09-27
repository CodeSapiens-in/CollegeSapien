import 'dart:convert';
import 'dart:typed_data';

import 'api_service.dart';

const _maxImageBytes = 4 * 1024 * 1024; // 4 MB — safe for Cloud Functions 10 MB limit after base64 inflation

class AcademicService {
  Future<Map<String, dynamic>> calculateCgpaFromImage(Uint8List bytes) async {
    final payload = bytes;
    if (payload.length > _maxImageBytes) {
      throw ApiException(413, 'Image too large (${(payload.length / 1024 / 1024).toStringAsFixed(1)} MB). Please use an image under 4 MB.');
    }
    return await ApiService.instance.post('/cgpa/calculate', {
      'imageBase64': base64Encode(payload),
    }) as Map<String, dynamic>;
  }

  Future<String> roastResumeText(String resumeText) async {
    final json = await ApiService.instance.post('/ai/roast-resume', {
      'resumeText': resumeText,
    }) as Map<String, dynamic>;
    return json['roast'] as String? ?? 'No roast generated.';
  }

  Future<String> roastResumeFile(String fileBase64, String mimeType) async {
    final json = await ApiService.instance.post('/ai/roast-resume', {
      'fileBase64': fileBase64,
      'mimeType': mimeType,
    }) as Map<String, dynamic>;
    return json['roast'] as String? ?? 'No roast generated.';
  }
}

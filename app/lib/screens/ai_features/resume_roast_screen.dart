import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../utils/app_theme.dart';
import '../../services/academic_service.dart';
import '../../widgets/responsive_layout.dart';

class ResumeRoastScreen extends StatefulWidget {
  const ResumeRoastScreen({super.key});

  @override
  State<ResumeRoastScreen> createState() => _ResumeRoastScreenState();
}

class _ResumeRoastScreenState extends State<ResumeRoastScreen> {
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  String? _selectedMimeType;
  bool _isUploading = false;
  String? _roastText;
  final _academicService = AcademicService();

  String _mimeTypeFor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );

      if (result != null) {
        final file = result.files.single;
        final ext = file.extension ?? 'pdf';
        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = file.bytes;
          _selectedMimeType = _mimeTypeFor(ext);
          _roastText = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRoastPopup() async {
    if (_selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a document first!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String roast;
      if (_selectedFileBytes != null) {
        final base64Data = base64Encode(_selectedFileBytes!);
        roast = await _academicService.roastResumeFile(
          base64Data,
          _selectedMimeType ?? 'application/pdf',
        );
      } else {
        roast = await _academicService.roastResumeText(
          'Resume file: $_selectedFileName',
        );
      }
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _roastText = roast;
      });
      _showRoastDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  void _showRoastDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentPink,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black,
                  offset: Offset(8, 8),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  size: 50,
                  color: Colors.black,
                ),
                const SizedBox(height: 8),
                const Text(
                  'ROASTED!',
                  style: TextStyle(
                    fontFamily: 'Lexend Mega',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: MarkdownBody(
                      data: _roastText ?? 'No roast generated.',
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          fontFamily: 'Public Sans',
                          fontSize: 15,
                          color: Colors.black,
                          height: 1.5,
                        ),
                        strong: const TextStyle(
                          fontFamily: 'Public Sans',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryYellow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                      elevation: 0,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Got it!',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Resume Roast',
          style: TextStyle(
            fontFamily: 'Lexend Mega',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            letterSpacing: 0,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: MaxWidthContent(
            maxWidth: 560,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Fire Icon
              Container(
                width: 120,
                height: 120,
                decoration: AppTheme.cardDecoration(
                  color: AppColors.accentPink,
                  shadowOffset: const Offset(6, 6),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  size: 60,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 30),

              // Description
              const Text(
                'Upload Your Resume',
                style: TextStyle(
                  fontFamily: 'Lexend Mega',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Let AI roast your resume and give you some tough love!',
                style: TextStyle(
                  fontFamily: 'Public Sans',
                  fontSize: 16,
                  color: Colors.black.withValues(alpha: 0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Upload Button
              GestureDetector(
                onTap: _pickDocument,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.cardDecoration(
                    color: AppColors.accentBlue,
                    shadowOffset: const Offset(6, 6),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_upload,
                        size: 48,
                        color: Colors.black,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedFileName ?? 'Tap to select PDF or DOC',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_selectedFileName != null) ...[
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 24,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Roast Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _showRoastPopup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                    elevation: 0,
                    shadowColor: Colors.black,
                  ).copyWith(
                    shadowColor: WidgetStateProperty.all(Colors.black),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black,
                            ),
                          ),
                        )
                      : const Text(
                          'ROAST MY RESUME!',
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
    );
  }
}

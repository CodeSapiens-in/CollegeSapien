import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/app_theme.dart';
import '../../widgets/responsive_layout.dart';

class SeasonalContentScreen extends StatelessWidget {
  const SeasonalContentScreen({super.key});

  Future<void> _uploadResume(BuildContext context, String feature) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryYellow),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (!context.mounted) return;
    Navigator.pop(context);

    String result = feature == 'roast'
        ? "Dei! Engineering graduate ah? Skills list romba long iruku, but project section empty! 'Team player' nu solra, aana GitHub la solo projects mattum than! LinkedIn ku than indha resume upload panra pola!"
        : "Machaan! Resume vida meme content better ah iruku!";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.accentPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
        title: Text(
          feature == 'roast' ? 'Resume Roast' : 'Result',
          style: const TextStyle(
            fontFamily: 'Lexend Mega',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          result,
          style: const TextStyle(
            fontFamily: 'Public Sans',
            fontSize: 16,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Features'),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenWidth * 0.045),
          child: MaxWidthContent(
            maxWidth: 700,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              const Text(
                'Seasonal Content',
                style: TextStyle(
                  fontFamily: 'Lexend Mega',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fun AI-powered features!',
                style: TextStyle(
                  fontFamily: 'Public Sans',
                  fontSize: 14,
                  color: Colors.black.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 30),

              // Resume Roast
              _buildFeatureCard(
                context,
                'Resume Roast',
                'Let AI roast your resume in Tanglish!',
                Icons.local_fire_department,
                AppColors.accentPink,
                () => _uploadResume(context, 'roast'),
              ),
              const SizedBox(height: 16),

              // Resume to Meme
              _buildFeatureCard(
                context,
                'Resume to Tamil Meme',
                'Convert your resume to a funny Tamil meme!',
                Icons.emoji_emotions,
                AppColors.accentPurple,
                () => _uploadResume(context, 'meme'),
              ),
              const SizedBox(height: 16),

              // Single Prediction
              _buildFeatureCard(
                context,
                'Will You Stay Single?',
                'Find out based on your resume!',
                Icons.favorite,
                AppColors.accentBlue,
                () => _uploadResume(context, 'single'),
              ),
              const SizedBox(height: 30),

              // Info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(
                  color: AppColors.primaryYellow,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 30),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'All features use Google Gemini AI for fun, harmless roasts and predictions!',
                        style: TextStyle(
                          fontFamily: 'Public Sans',
                          fontSize: 14,
                          color: Colors.black.withValues(alpha: 0.8),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.cardDecoration(color: color),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.black),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Lexend Mega',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: 'Public Sans',
                      fontSize: 13,
                      color: Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 20),
          ],
        ),
      ),
    );
  }
}

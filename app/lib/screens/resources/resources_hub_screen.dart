import 'package:flutter/material.dart';
// import '../../services/app_capability_service.dart'; // mod: moved to web admin panel
import '../../utils/app_theme.dart';
import '../../widgets/hoverable.dart';
import '../../widgets/responsive_layout.dart';
// import '../profile/admin_management_screen.dart'; // mod: moved to web admin panel
import 'syllabus_browser_screen.dart';
import 'notes_hub_screen.dart';
import 'qp_hub_screen.dart';

class ResourcesHubScreen extends StatefulWidget {
  const ResourcesHubScreen({super.key});

  @override
  State<ResourcesHubScreen> createState() => _ResourcesHubScreenState();
}

class _ResourcesHubScreenState extends State<ResourcesHubScreen> {
  // mod: admin tools entry point removed — moderation moved to web admin panel
  // bool _showAdminTools = false;

  @override
  void initState() {
    super.initState();
    // mod: _loadCapabilities() removed — no mod-gating needed in mobile app
    // _loadCapabilities();
  }

  // mod: capability loading removed — admin features moved to web admin panel
  // Future<void> _loadCapabilities() async {
  //   try {
  //     final capabilities =
  //         await AppCapabilityService.instance.resolveCapabilities();
  //     if (mounted) {
  //       setState(() => _showAdminTools = capabilities.canModerateResources);
  //     }
  //   } catch (_) {}
  // }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenWidth * 0.045),
          child: MaxWidthContent(
            maxWidth: 800,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.library_books, size: 24, color: Colors.black),
                  SizedBox(width: 10),
                  Text(
                    'Resources Hub',
                    style: TextStyle(
                      fontFamily: 'Lexend Mega',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Text(
                'Access syllabus, notes, and question papers',
                style: TextStyle(
                  fontFamily: 'Public Sans',
                  fontSize: 14,
                  color: Colors.black.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 30),

              // Syllabus Browser
              _buildResourceCard(
                context,
                'Syllabus Browser',
                'Browse and download syllabus from various colleges',
                Icons.menu_book,
                AppColors.accentGreen,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SyllabusBrowserScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Notes Hub
              _buildResourceCard(
                context,
                'Notes Hub',
                'Unlock with 1 approved upload',
                Icons.note,
                AppColors.accentBlue,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotesHubScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Question Papers
              _buildResourceCard(
                context,
                'Question Papers',
                'Same unlock rule as Notes Hub',
                Icons.quiz,
                AppColors.accentPurple,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QpHubScreen(),
                    ),
                  );
                },
              ),

              // mod: Admin Management card removed — moderation moved to web admin panel
              // if (_showAdminTools) ...[
              //   const SizedBox(height: 16),
              //   _buildResourceCard(
              //     context,
              //     'Admin Management',
              //     'Review reports and run moderator/superadmin actions',
              //     Icons.admin_panel_settings_outlined,
              //     AppColors.accentPink,
              //     () {
              //       Navigator.push(
              //         context,
              //         MaterialPageRoute(
              //           builder: (_) => const AdminManagementScreen(),
              //         ),
              //       );
              //     },
              //   ),
              // ],

              const SizedBox(height: 30),

              // Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(
                  color: AppColors.primaryYellow,
                ),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Community Access Rules',
                      style: TextStyle(
                        fontFamily: 'Lexend Mega',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Students unlock downloads after 1 approved upload. All uploads go through moderation.',
                      style: TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 14,
                        color: Colors.black.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
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

  Widget _buildResourceCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Hoverable(
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cardDecoration(
            color: color,
            shadowOffset:
                hovered ? const Offset(6, 6) : const Offset(4, 4),
          ),
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
      ),
    );
  }
}

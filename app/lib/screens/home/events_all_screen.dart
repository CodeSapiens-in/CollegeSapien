import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/app_theme.dart';
import '../../utils/app_spacing.dart';
import '../../utils/breakpoints.dart';
import '../../widgets/responsive_layout.dart';
import '../../models/event_models.dart';
import 'create_event_screen.dart';

class EventsAllScreen extends StatelessWidget {
  final List<EventItem> events;

  const EventsAllScreen({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(offset: Offset(2, 2), color: Colors.black)
                        ],
                      ),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'ALL EVENTS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.16,
                      color: Color(0xFF191C1E),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateEventScreen(),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryYellow,
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(offset: Offset(2, 2), color: Colors.black)
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 16, color: Colors.black),
                          SizedBox(width: 4),
                          Text(
                            'SUGGEST',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ResponsiveLayout(
                mobile: (_) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, i) => _eventCard(events[i]),
                ),
                desktop: (_) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: MaxWidthContent(
                    maxWidth: 1000,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            Breakpoints.isWide(constraints.maxWidth) ? 3 : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: events.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: AppSpacing.lg,
                            crossAxisSpacing: AppSpacing.lg,
                            childAspectRatio: 1.3,
                          ),
                          itemBuilder: (_, i) => _eventCard(events[i]),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventCard(EventItem event) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(event.eventLink);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.accentBlue,
            border: Border.all(color: Colors.black, width: 1.5),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(offset: Offset(4, 4), color: Colors.black)
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PolkaDotPainter(
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.tagPurple,
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [
                        BoxShadow(offset: Offset(2, 2), color: Colors.black)
                      ],
                    ),
                    child: Text(
                      event.location.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF191C1E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event.eventName,
                    style: const TextStyle(
                      fontFamily: 'Lexend Mega',
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -1.5,
                      color: Colors.black,
                      height: 1.2,
                    ),
                  ),
                  if (event.eventDate.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.eventDate,
                      style: TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (event.communityLogo.isNotEmpty) ...[
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: const [
                              BoxShadow(
                                  offset: Offset(2, 2), color: Colors.black)
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: CachedNetworkImage(
                              imageUrl: event.communityLogo,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.accentPurple,
                                child: const Icon(Icons.group, size: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          event.communityName,
                          style: const TextStyle(
                            fontFamily: 'Public Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolkaDotPainter extends CustomPainter {
  final Color color;

  const _PolkaDotPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const r = 2.5;
    const spacing = 18.0;
    bool odd = false;
    for (double y = 0; y <= size.height + spacing; y += spacing) {
      final xOff = odd ? spacing / 2 : 0.0;
      for (double x = xOff; x <= size.width + spacing; x += spacing) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
      odd = !odd;
    }
  }

  @override
  bool shouldRepaint(_PolkaDotPainter old) => old.color != color;
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/api_models.dart';
import '../../providers/app_state_notifier.dart';
import '../../services/api_service.dart';
import '../../services/college_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_theme.dart';
import '../../widgets/searchable_dropdown.dart';

enum _OrganizerType { community, college }

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _communityController = TextEditingController();
  final _logoController = TextEditingController();
  final _linkController = TextEditingController();
  final _dateController = TextEditingController();
  final _collegeService = CollegeService();

  _OrganizerType _organizerType = _OrganizerType.community;
  List<College> _colleges = [];
  College? _selectedCollege;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadColleges();
  }

  Future<void> _loadColleges() async {
    try {
      final colleges = await _collegeService.listColleges();
      if (!mounted) return;
      colleges.sort((a, b) => a.name.compareTo(b.name));
      setState(() => _colleges = colleges);
    } catch (_) {
      // Community-name entry still works if colleges fail to load.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _communityController.dispose();
    _logoController.dispose();
    _linkController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryYellow,
              onPrimary: Colors.black,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final y = picked.year.toString();
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      setState(() {
        _dateController.text = "$y-$m-$d";
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final String communityName;
    if (_organizerType == _OrganizerType.college) {
      if (_selectedCollege == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a college')),
        );
        return;
      }
      communityName = _selectedCollege!.name;
    } else {
      communityName = _communityController.text.trim();
    }

    setState(() => _isSubmitting = true);

    try {
      final body = {
        'eventName': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'communityName': communityName,
        'communityLogo': _logoController.text.trim(),
        'eventLink': _linkController.text.trim(),
        'eventDate': _dateController.text.trim(),
      };

      await ApiService.instance.post('/events', body);

      if (mounted) {
        // Invalidate cached events so home and all events list reloads them
        Provider.of<AppStateNotifier>(context, listen: false).invalidateEvents();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Text(
                'Event submitted successfully! Pending admin approval.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
            backgroundColor: AppColors.accentBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.black, width: 2),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error submitting event: $e',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Navigation Header
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
                    'SUGGEST AN EVENT',
                    style: TextStyle(
                      fontFamily: 'Lexend Mega',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF191C1E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.cardDecoration(color: Colors.white),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Event Details',
                              style: TextStyle(
                                fontFamily: 'Lexend Mega',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Event Name',
                                hintText: 'e.g., HackChennai 2026',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Please enter the event name'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                labelText: 'Venue / Location',
                                hintText: 'e.g., Main Auditorium, IIT Madras',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Please enter the location'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _dateController,
                              readOnly: true,
                              onTap: _selectDate,
                              decoration: InputDecoration(
                                labelText: 'Event Date',
                                hintText: 'YYYY-MM-DD',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today, color: Colors.black),
                                  onPressed: _selectDate,
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Please select the event date'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _linkController,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'Registration / Event Link',
                                hintText: 'https://example.com/register',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter the event link';
                                }
                                if (!v.trim().startsWith('http://') &&
                                    !v.trim().startsWith('https://')) {
                                  return 'Must be a valid URL starting with http/https';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.cardDecoration(color: Colors.white),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Organizer / Community',
                              style: TextStyle(
                                fontFamily: 'Lexend Mega',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('Community'),
                                  selected:
                                      _organizerType == _OrganizerType.community,
                                  onSelected: (_) => setState(() {
                                    _organizerType = _OrganizerType.community;
                                  }),
                                  selectedColor: AppColors.accentGreen,
                                  side: const BorderSide(color: Colors.black),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('College'),
                                  selected:
                                      _organizerType == _OrganizerType.college,
                                  onSelected: (_) => setState(() {
                                    _organizerType = _OrganizerType.college;
                                  }),
                                  selectedColor: AppColors.accentBlue,
                                  side: const BorderSide(color: Colors.black),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_organizerType == _OrganizerType.community)
                              TextFormField(
                                controller: _communityController,
                                decoration: const InputDecoration(
                                  labelText: 'Community Name',
                                  hintText: 'e.g., Google Developer Groups',
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Please enter the community name'
                                    : null,
                              )
                            else
                              SearchableDropdown<College>(
                                items: _colleges,
                                value: _selectedCollege,
                                labelBuilder: (c) => c.name,
                                decoration: const InputDecoration(
                                  labelText: 'College',
                                  hintText: 'Search for your college',
                                ),
                                onChanged: (college) =>
                                    setState(() => _selectedCollege = college),
                              ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _logoController,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'Community Logo URL (Optional)',
                                hintText: 'https://example.com/logo.png',
                              ),
                              validator: (v) {
                                if (v != null && v.trim().isNotEmpty) {
                                  if (!v.trim().startsWith('http://') &&
                                      !v.trim().startsWith('https://')) {
                                    return 'Must be a valid URL starting with http/https';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryYellow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.black, width: 2),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Text(
                                  'Submit for Approval',
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
          ],
        ),
      ),
    );
  }
}

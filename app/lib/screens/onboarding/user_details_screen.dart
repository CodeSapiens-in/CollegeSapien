import 'package:flutter/material.dart';
import '../../models/api_models.dart';
import '../../providers/reference_data_store.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/department_constants.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/searchable_dropdown.dart';
import '../home/main_navigation.dart';

class UserDetailsScreen extends StatefulWidget {
  final String? collegeId;

  const UserDetailsScreen({super.key, this.collegeId});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  List<College> _colleges = [];
  List<Department> _departments = [];
  String? _selectedCollegeId;
  String? _selectedDepartment;
  int? _selectedSemester;
  bool _isLoading = false;
  late AnimationController _animationController;


  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    _nameController.text = AuthService.instance.currentUser?.displayName ?? '';
    _selectedCollegeId = widget.collegeId;
    _loadColleges();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadColleges() async {
    try {
      final colleges = await ReferenceDataStore.instance.listColleges();
      final departments = await ReferenceDataStore.instance.listDepartments();
      if (!mounted) return;
      colleges.sort((a, b) => a.name.compareTo(b.name));
      departments.sort((a, b) => a.name.compareTo(b.name));
      setState(() {
        _colleges = colleges;
        _departments = departments;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load options: $e')),
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCollegeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your college')),
      );
      return;
    }

    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a department')),
      );
      return;
    }

    if (_selectedSemester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a semester')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.onboard(
        name: _nameController.text,
        collegeId: _selectedCollegeId!,
        department: _selectedDepartment!,
        semester: _selectedSemester!,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Animated Background Blocks
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Stack(
                  children: List.generate(8, (index) {
                    final double startX = -200 + (index * 150.0);
                    final double currentX = startX +
                        (_animationController.value * screenWidth * 1.5);
                    final double yPosition = 100 + (index * 80.0);

                    final List<Color> colors = [
                      const Color(0xFFFF6B6B),
                      const Color(0xFF4ECDC4),
                      const Color(0xFFFFE66D),
                      const Color(0xFF95E1D3),
                      const Color(0xFFF38181),
                      const Color(0xFFAA96DA),
                      const Color(0xFFFCBF49),
                      const Color(0xFF06FFA5),
                    ];

                    return Positioned(
                      left: currentX % (screenWidth + 400) - 200,
                      top: yPosition,
                      child: Transform.rotate(
                        angle: 0.785398, // 45 degrees in radians
                        child: Container(
                          width: 60 + (index % 3) * 20,
                          height: 60 + (index % 3) * 20,
                          decoration: BoxDecoration(
                            color: colors[index % colors.length]
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06,
                vertical: 40,
              ),
              child: MaxWidthContent(
                maxWidth: 480,
                child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Tell us about yourself',
                      style: TextStyle(
                        fontFamily: 'Lexend Mega',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We need this info to personalize your experience',
                      style: TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 14,
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // College Searchable Dropdown
                    SearchableDropdown<College>(
                      items: _colleges,
                      value: _selectedCollegeId != null
                          ? _colleges
                              .where((c) => c.id == _selectedCollegeId)
                              .firstOrNull
                          : null,
                      labelBuilder: (c) => c.name,
                      decoration: const InputDecoration(
                        labelText: 'College',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      onChanged: (college) {
                        setState(() {
                          _selectedCollegeId = college?.id;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Department Searchable Dropdown
                    SearchableDropdown<Department>(
                      items: _departments,
                      value: _selectedDepartment != null
                          ? _departments
                              .where((d) => d.name == _selectedDepartment)
                              .firstOrNull
                          : null,
                      labelBuilder: (d) => d.name,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        prefixIcon: Icon(Icons.engineering_outlined),
                      ),
                      onChanged: (dept) {
                        setState(() {
                          _selectedDepartment = dept?.name;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Semester Dropdown
                    DropdownButtonFormField<int>(
                      initialValue: _selectedSemester,
                      decoration: const InputDecoration(
                        labelText: 'Current Semester',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      items: semesters.map((sem) {
                        return DropdownMenuItem(
                          value: sem,
                          child: Text('Semester $sem'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSemester = value;
                        });
                      },
                    ),
                    const SizedBox(height: 40),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryYellow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side:
                                const BorderSide(color: Colors.black, width: 2),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
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
                                'Continue',
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

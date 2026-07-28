import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'package:intl/intl.dart';
import '../../models/timetable_models.dart';
import '../../services/attendance_service.dart';
import '../../services/timetable_service.dart';
import '../../widgets/responsive_layout.dart';

class MarkAttendanceScreen extends StatefulWidget {
  final String? preselectedDateKey;
  final String? preselectedSubjectId;
  final String? preselectedSlotStartTime;
  final String? preselectedSlotEndTime;

  const MarkAttendanceScreen({
    super.key,
    this.preselectedDateKey,
    this.preselectedSubjectId,
    this.preselectedSlotStartTime,
    this.preselectedSlotEndTime,
  });

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _SlotOption {
  final TimetableSubject subject;
  final TimetableClass slot;

  const _SlotOption({required this.subject, required this.slot});

  @override
  bool operator ==(Object other) {
    return other is _SlotOption &&
        other.subject.id == subject.id &&
        other.slot.startTime == slot.startTime &&
        other.slot.endTime == slot.endTime;
  }

  @override
  int get hashCode => Object.hash(subject.id, slot.startTime, slot.endTime);
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  TimetableSubject? _selectedSubject;
  _SlotOption? _selectedSlot;
  String _attendanceStatus = 'Present';
  bool _isLoading = true;
  List<TimetableSubject> _subjects = [];
  DateTime _trackingStartDate = DateTime.now();

  final _attendanceService = AttendanceService();
  final _timetableService = TimetableService();

  @override
  void initState() {
    super.initState();
    if (widget.preselectedDateKey != null) {
      _selectedDate = _dateFromKey(widget.preselectedDateKey!);
    }
    _loadSubjects();
  }

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  DateTime _dateFromKey(String dateKey) {
    final parts = dateKey.split('-').map(int.tryParse).toList();
    if (parts.length != 3 || parts.any((part) => part == null)) {
      return DateTime.now();
    }
    return DateTime(parts[0]!, parts[1]!, parts[2]!);
  }

  String _dayCode(DateTime date) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[date.weekday - 1];
  }

  List<_SlotOption> get _availableSlots {
    final day = _dayCode(_selectedDate);
    final slots = <_SlotOption>[];
    for (final subject in _subjects) {
      for (final slot in subject.classes) {
        if (slot.day == day && slot.type != 'BREAK') {
          slots.add(_SlotOption(subject: subject, slot: slot));
        }
      }
    }
    slots.sort((a, b) => a.slot.startTime.compareTo(b.slot.startTime));
    return slots;
  }

  List<TimetableSubject> get _availableSubjects {
    final seen = <String>{};
    return _availableSlots
        .where((option) => seen.add(option.subject.id))
        .map((option) => option.subject)
        .toList();
  }

  void _selectDefaults() {
    final slots = _availableSlots;
    if (slots.isEmpty) {
      _selectedSubject = null;
      _selectedSlot = null;
      return;
    }

    _selectedSlot = slots.firstWhere(
      (option) =>
          option.subject.id == widget.preselectedSubjectId &&
          option.slot.startTime == widget.preselectedSlotStartTime &&
          option.slot.endTime == widget.preselectedSlotEndTime,
      orElse: () => slots.firstWhere(
        (option) => option.subject.id == widget.preselectedSubjectId,
        orElse: () => slots.first,
      ),
    );
    _selectedSubject = _selectedSlot!.subject;
  }

  Future<void> _loadSubjects() async {
    try {
      final timetable = await _timetableService.getTimetable();
      if (!mounted) return;
      setState(() {
        _subjects = timetable.subjects;
        _trackingStartDate = timetable.attendanceTrackingStartDate == null
            ? DateTime.now()
            : _dateFromKey(timetable.attendanceTrackingStartDate!);
        if (_selectedDate.isBefore(_trackingStartDate)) {
          _selectedDate = _trackingStartDate;
        }
        _selectDefaults();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load timetable subjects: $e')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _trackingStartDate,
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryYellow,
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectDefaults();
      });
    }
  }

  Future<void> _saveAttendance() async {
    if (_selectedSubject == null || _selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a scheduled class slot')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _attendanceService.markAttendance(
        subjectId: _selectedSubject!.id,
        dateKey: _dateKey(_selectedDate),
        slotStartTime: _selectedSlot!.slot.startTime,
        slotEndTime: _selectedSlot!.slot.endTime,
        status: _attendanceStatus,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
      return;
    }

    if (!mounted) return;

    // Show success message in Tanglish
    final messages = {
      'Present': ('Semma! Attendance mark pannita!', Colors.green),
      'Absent': ('Bunk ah? Parava illa, next time attend pannu!', Colors.red),
      'Leave': ('Leave ah? Rest eduthutu vaa da!', Colors.orange),
      'OD_ML': ('OD/ML mark aagudhu! Safe skip la count aavuthu!', Colors.blue),
    };
    final (message, color) =
        messages[_attendanceStatus] ?? ('Saved!', Colors.green);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableSubjects = _availableSubjects;
    final selectedSubjectSlots = _selectedSubject == null
        ? <_SlotOption>[]
        : _availableSlots
            .where((option) => option.subject.id == _selectedSubject!.id)
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mark Attendance',
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
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenWidth * 0.045),
          child: MaxWidthContent(
            maxWidth: 640,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Date Selector
              const Text(
                'Select Date',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF191C1E),
                ),
              ),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration(
                    color: AppColors.accentBlue,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          DateFormat('EEEE, MMM dd, yyyy')
                              .format(_selectedDate),
                          style: const TextStyle(
                            fontFamily: 'Public Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 24),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Subject Selector
              const Text(
                'Select Subject',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF191C1E),
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: AppTheme.cardDecoration(
                  color: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TimetableSubject>(
                    value: _selectedSubject,
                    isExpanded: true,
                    hint: Text(_isLoading
                        ? 'Loading subjects...'
                        : availableSubjects.isEmpty
                            ? 'No scheduled class on this date'
                            : 'Choose a subject'),
                    items: availableSubjects.map((subject) {
                      return DropdownMenuItem(
                        value: subject,
                        child: Text('${subject.code} - ${subject.name}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSubject = value;
                        _selectedSlot = value == null
                            ? null
                            : _availableSlots.firstWhere(
                                (option) => option.subject.id == value.id,
                              );
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),

              const Text(
                'Select Slot',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF191C1E),
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: AppTheme.cardDecoration(
                  color: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<_SlotOption>(
                    value: _selectedSlot,
                    isExpanded: true,
                    hint: const Text('Choose a class slot'),
                    items: selectedSubjectSlots.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Text(
                          '${option.slot.startTime} - ${option.slot.endTime}'
                          '${option.slot.room.isEmpty ? '' : ' · ${option.slot.room}'}',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedSlot = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Attendance Status
              const Text(
                'Mark as',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF191C1E),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildStatusButton(
                      'Present',
                      'Present',
                      Icons.check_circle,
                      AppColors.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatusButton(
                      'Absent',
                      'Bunk',
                      Icons.cancel,
                      AppColors.accentPink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildStatusButton(
                      'Leave',
                      'Leave',
                      Icons.event_busy,
                      AppColors.primaryYellow,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatusButton(
                      'OD_ML',
                      'OD / ML',
                      Icons.verified_outlined,
                      AppColors.accentBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: const Text(
                    'Save Attendance',
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

  Widget _buildStatusButton(
      String status, String label, IconData icon, Color color) {
    final isSelected = _attendanceStatus == status;

    return GestureDetector(
      onTap: () => setState(() => _attendanceStatus = status),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          border: Border.all(
            color: Colors.black,
            width: isSelected ? 3 : 2,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [const BoxShadow(offset: Offset(4, 4), color: Colors.black)]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.black),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Public Sans',
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

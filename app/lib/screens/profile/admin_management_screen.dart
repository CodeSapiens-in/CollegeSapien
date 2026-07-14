import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../models/event_models.dart';
import '../../services/admin_service.dart';
import '../../services/app_capability_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/responsive_layout.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final _adminService = AdminService.instance;
  final _capabilityService = AppCapabilityService.instance;
  final Set<String> _reportActionsInFlight = <String>{};
  final Set<String> _userActionsInFlight = <String>{};
  final Set<String> _eventActionsInFlight = <String>{};

  bool _loading = true;
  String? _error;
  AppCapabilities? _capabilities;
  List<AdminReport> _reports = [];
  List<EventItem> _pendingEvents = [];
  List<AdminUser> _users = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final capabilities = await _capabilityService.resolveCapabilities();
      if (!capabilities.canModerateResources) {
        if (!mounted) return;
        setState(() {
          _capabilities = capabilities;
          _loading = false;
        });
        return;
      }

      final reportsFuture = _adminService.listPendingReports();
      final eventsFuture = _adminService.listPendingEvents();
      final usersFuture = capabilities.isSuperAdmin
          ? _adminService.listUsers()
          : Future.value(<AdminUser>[]);
      final results = await Future.wait([reportsFuture, eventsFuture, usersFuture]);

      if (!mounted) return;
      setState(() {
        _capabilities = capabilities;
        _reports = results[0] as List<AdminReport>;
        _pendingEvents = results[1] as List<EventItem>;
        _users = results[2] as List<AdminUser>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _resolveReport(AdminReport report, String action) async {
    if (_reportActionsInFlight.contains(report.id)) return;

    final actionLabel = _actionLabel(action);
    final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$actionLabel report?'),
            content: Text(
                'This will apply "$actionLabel" for resource ${report.resourceId}.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldContinue) return;

    setState(() => _reportActionsInFlight.add(report.id));
    try {
      await _adminService.resolveReport(reportId: report.id, action: action);
      if (!mounted) return;

      setState(() {
        _reports.removeWhere((item) => item.id == report.id);
      });
      _showSnack('Report resolved: $actionLabel', isError: false);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _reportActionsInFlight.remove(report.id));
      }
    }
  }

  Future<void> _openAssignRoleDialog(AdminUser user) async {
    if (_userActionsInFlight.contains(user.id)) return;
    final update = await _showRoleDialog(user);
    if (update == null) return;

    setState(() => _userActionsInFlight.add(user.id));
    try {
      await _adminService.assignRole(
        uid: user.id,
        role: update.role,
        collegeId: update.collegeId,
      );
      _capabilityService.invalidate();
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere((item) => item.id == user.id);
        if (index != -1) {
          _users[index] = _users[index].copyWith(
            role: update.role,
            collegeId: update.role == 'moderator' ? update.collegeId : null,
          );
        }
      });
      _showSnack('Role updated for ${user.email}', isError: false);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _userActionsInFlight.remove(user.id));
      }
    }
  }

  Future<_RoleUpdateRequest?> _showRoleDialog(AdminUser user) async {
    String selectedRole = user.role;
    final collegeController = TextEditingController(text: user.collegeId ?? '');
    bool showCollegeValidationError = false;

    final result = await showDialog<_RoleUpdateRequest>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Assign role'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: const [
                        DropdownMenuItem(value: 'user', child: Text('User')),
                        DropdownMenuItem(
                            value: 'moderator', child: Text('Moderator')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(
                            value: 'superadmin', child: Text('Superadmin')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedRole = value);
                      },
                    ),
                    if (selectedRole == 'moderator') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: collegeController,
                        decoration: const InputDecoration(
                          labelText:
                              'College ID (required for scoped moderator)',
                        ),
                      ),
                      if (showCollegeValidationError)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'College ID is required when assigning moderator.',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final collegeId = collegeController.text.trim();
                    if (selectedRole == 'moderator' && collegeId.isEmpty) {
                      setDialogState(() => showCollegeValidationError = true);
                      return;
                    }
                    Navigator.pop(
                      context,
                      _RoleUpdateRequest(
                        role: selectedRole,
                        collegeId:
                            selectedRole == 'moderator' ? collegeId : null,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    collegeController.dispose();
    return result;
  }

  Future<void> _approveEvent(EventItem event) async {
    if (event.id == null || _eventActionsInFlight.contains(event.id)) return;

    setState(() => _eventActionsInFlight.add(event.id!));
    try {
      await _adminService.approveEvent(event.id!);
      if (!mounted) return;

      setState(() {
        _pendingEvents.removeWhere((item) => item.id == event.id);
      });
      _showSnack('Event approved successfully', isError: false);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _eventActionsInFlight.remove(event.id!));
      }
    }
  }

  Future<void> _rejectEvent(EventItem event) async {
    if (event.id == null || _eventActionsInFlight.contains(event.id)) return;

    final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reject event?'),
            content: Text('Are you sure you want to reject and archive "${event.eventName}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldContinue) return;

    setState(() => _eventActionsInFlight.add(event.id!));
    try {
      await _adminService.rejectEvent(event.id!);
      if (!mounted) return;

      setState(() {
        _pendingEvents.removeWhere((item) => item.id == event.id);
      });
      _showSnack('Event rejected and archived', isError: false);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _eventActionsInFlight.remove(event.id!));
      }
    }
  }

  void _showSnack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'dismiss':
        return 'Dismiss';
      case 'delete_resource':
        return 'Delete resource';
      case 'ban_user':
        return 'Ban user';
      default:
        return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Admin Management',
          style: TextStyle(
            fontFamily: 'Lexend Mega',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            letterSpacing: 0,
          ),
        ),
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!(_capabilities?.canModerateResources ?? false)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'You do not have access to admin tools.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: MaxWidthContent(
        maxWidth: 700,
        child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(color: AppColors.primaryYellow),
            child: Text(
              (_capabilities?.isSuperAdmin ?? false)
                  ? 'Superadmin access: resolve reports and manage user roles.'
                  : 'Moderator/Admin access: resolve pending reports.',
              style: const TextStyle(
                fontFamily: 'Public Sans',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _buildReportSection(),
          const SizedBox(height: 22),
          _buildEventsSection(),
          if (_capabilities?.isSuperAdmin ?? false) ...[
            const SizedBox(height: 22),
            _buildUserSection(),
          ],
        ],
        ),
      ),
    );
  }

  Widget _buildReportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pending Reports',
          style: TextStyle(
            fontFamily: 'Lexend Mega',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        if (_reports.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(color: AppColors.accentBlue),
            child: const Text('No pending reports right now.'),
          )
        else
          ..._reports.map(_buildReportCard),
      ],
    );
  }

  Widget _buildReportCard(AdminReport report) {
    final isLoading = _reportActionsInFlight.contains(report.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(color: AppColors.accentPink),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reason: ${report.reason}',
            style: const TextStyle(
              fontFamily: 'Public Sans',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text('Type: ${report.type}'),
          Text('Resource: ${report.resourceId}'),
          if (report.reportedBy.isNotEmpty)
            Text('Reporter: ${report.reportedBy}'),
          if (report.collegeId != null && report.collegeId!.isNotEmpty)
            Text('College: ${report.collegeId}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed:
                    isLoading ? null : () => _resolveReport(report, 'dismiss'),
                child: const Text('Dismiss'),
              ),
              OutlinedButton(
                onPressed: isLoading
                    ? null
                    : () => _resolveReport(report, 'delete_resource'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade700),
                ),
                child: const Text('Delete Resource'),
              ),
              ElevatedButton(
                onPressed:
                    isLoading ? null : () => _resolveReport(report, 'ban_user'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ban User'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Role Management',
          style: TextStyle(
            fontFamily: 'Lexend Mega',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        if (_users.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(color: AppColors.accentPurple),
            child: const Text('No users found.'),
          )
        else
          ..._users.map(_buildUserCard),
      ],
    );
  }

  Widget _buildUserCard(AdminUser user) {
    final isLoading = _userActionsInFlight.contains(user.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(color: AppColors.accentPurple),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontFamily: 'Public Sans',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(user.email),
                const SizedBox(height: 6),
                Text('Role: ${user.role}'),
                if (user.collegeId != null && user.collegeId!.isNotEmpty)
                  Text('College: ${user.collegeId}'),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: isLoading ? null : () => _openAssignRoleDialog(user),
            child: Text(isLoading ? 'Saving...' : 'Assign Role'),
          ),
        ],
      ),
    );
  }
  Widget _buildEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pending Events',
          style: TextStyle(
            fontFamily: 'Lexend Mega',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        if (_pendingEvents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(color: AppColors.accentBlue),
            child: const Text('No pending events awaiting approval.'),
          )
        else
          ..._pendingEvents.map(_buildEventCard),
      ],
    );
  }

  Widget _buildEventCard(EventItem event) {
    final isLoading = event.id != null && _eventActionsInFlight.contains(event.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(color: AppColors.accentBlue),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (event.communityLogo.isNotEmpty) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(event.communityLogo),
                  backgroundColor: Colors.transparent,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.eventName,
                      style: const TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'By ${event.communityName}',
                      style: TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Date: ${event.eventDate}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text('Location: ${event.location}'),
          Text('Link: ${event.eventLink}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: isLoading ? null : () => _approveEvent(event),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryYellow,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Approve'),
              ),
              OutlinedButton(
                onPressed: isLoading ? null : () => _rejectEvent(event),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade700, width: 2),
                ),
                child: const Text('Reject'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleUpdateRequest {
  final String role;
  final String? collegeId;

  const _RoleUpdateRequest({
    required this.role,
    this.collegeId,
  });
}

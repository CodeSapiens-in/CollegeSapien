import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

class AppCapabilities {
  final String role;
  final bool isAuthenticated;

  const AppCapabilities._({
    required this.role,
    required this.isAuthenticated,
  });

  const AppCapabilities.unauthenticated()
      : role = 'user',
        isAuthenticated = false;

  factory AppCapabilities.fromRole(
    String role, {
    required bool isAuthenticated,
  }) {
    return AppCapabilities._(
      role: _normalizeRole(role),
      isAuthenticated: isAuthenticated,
    );
  }

  bool get canModerateResources =>
      role == 'moderator' || role == 'admin' || role == 'superadmin';

  bool get bypassResourceUnlock =>
      role == 'ambassador' ||
      role == 'moderator' ||
      role == 'admin' ||
      role == 'superadmin';

  bool get isSuperAdmin => role == 'superadmin';

  bool get isAdminOrAbove => role == 'admin' || role == 'superadmin';

  static String _normalizeRole(String role) {
    final value = role.trim().toLowerCase();
    switch (value) {
      case 'ambassador':
      case 'moderator':
      case 'admin':
      case 'superadmin':
        return value;
      default:
        return 'user';
    }
  }
}

class AppCapabilityService {
  AppCapabilityService._();

  static final AppCapabilityService instance = AppCapabilityService._();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const _cacheTtl = Duration(minutes: 5);
  AppCapabilities? _cached;
  DateTime? _cachedAt;
  final Map<String, Future<AppCapabilities>> _inflight = {};

  void invalidate() {
    _cached = null;
    _cachedAt = null;
    _inflight.clear();
  }

  Future<AppCapabilities> resolveCapabilities(
      {bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      invalidate();
      return const AppCapabilities.unauthenticated();
    }

    final now = DateTime.now();
    if (!forceRefresh &&
        _cached != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _cacheTtl) {
      return _cached!;
    }

    // Deduplicate concurrent calls (forceRefresh bypasses cache only)
    final inflight = _inflight[user.uid];
    if (inflight != null) return inflight;

    final future = _doResolve(user, now);
    _inflight[user.uid] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(user.uid);
    }
  }

  Future<AppCapabilities> _doResolve(User user, DateTime now) async {
    // Force a token refresh on first load or after TTL to pick up claim changes.
    final claimRole = await _resolveRoleFromTokenClaim(user);
    AppCapabilities caps;
    if (claimRole != null) {
      caps = AppCapabilities.fromRole(claimRole, isAuthenticated: true);
    } else {
      final profileRole = await _resolveRoleFromSyncedProfile();
      caps = AppCapabilities.fromRole(profileRole ?? 'user',
          isAuthenticated: true);
    }

    _cached = caps;
    _cachedAt = now;
    return caps;
  }

  Future<String?> _resolveRoleFromTokenClaim(User user) async {
    try {
      final tokenResult = await user.getIdTokenResult(true);
      return _parseRole(tokenResult.claims?['role']);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolveRoleFromSyncedProfile() async {
    try {
      final syncResult = await AuthService.instance.syncProfile();
      return _parseRole(syncResult.user?.role);
    } catch (_) {
      return null;
    }
  }

  String? _parseRole(dynamic value) {
    if (value is! String) return null;
    final role = value.trim().toLowerCase();
    return role.isEmpty ? null : role;
  }
}

import 'package:flutter/foundation.dart';

/// Simple in-memory singleton that caches the current user's role,
/// chapter and district so any screen can filter without extra API calls.
///
/// Extends [ChangeNotifier] so widgets that depend on role-gated logic
/// (e.g. [MessagesScreen] TabController length) can listen and rebuild.
///
/// Populated by [HomeShell] immediately after login, and cleared on sign-out.
class UserState extends ChangeNotifier {
  UserState._();

  static final UserState instance = UserState._();

  String _role = 'member';
  String? _chapterId;
  String? _districtId;
  String? _displayName;

  /// The authenticated user's role: 'admin', 'advisor', or 'member'.
  String get role => _role;

  /// The user's chapter UUID (null until populated from profile).
  String? get chapterId => _chapterId;

  /// The user's district UUID (null until populated from profile).
  String? get districtId => _districtId;

  /// Cached display name for the greeting header.
  String? get displayName => _displayName;

  /// True when the user is an admin.
  bool get isAdmin => _role == 'admin';

  /// True when the user may post announcements and manage events.
  bool get isAdvisorOrAdmin => _role == 'admin' || _role == 'advisor';

  /// Store a fresh role from the backend. Normalises to lowercase.
  /// Notifies listeners so role-gated widgets can rebuild immediately.
  void setRole(String role) {
    final normalised = role.toLowerCase().trim();
    if (_role != normalised) {
      _role = normalised;
      notifyListeners();
    }
  }

  /// Store chapter + district IDs from the user/profile response.
  /// Notifies listeners only when at least one value actually changed —
  /// keeps role-gated screens reactive after advisor verification (which
  /// also assigns a chapter/district).
  void setChapter(String? chapterId, String? districtId) {
    final changed = _chapterId != chapterId || _districtId != districtId;
    _chapterId = chapterId;
    _districtId = districtId;
    if (changed) notifyListeners();
  }

  /// Cache the user's display name.
  void setDisplayName(String? name) {
    if (_displayName == name) return;
    _displayName = name;
    notifyListeners();
  }

  /// Reset all fields on sign-out so stale data is never shown.
  void clear() {
    _role = 'member';
    _chapterId = null;
    _districtId = null;
    _displayName = null;
    notifyListeners();
  }
}

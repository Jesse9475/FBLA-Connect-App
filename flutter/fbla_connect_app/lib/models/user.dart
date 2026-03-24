/// Basic user model with only fields needed by the app.
class AppUser {
  /// Unique identifier from Supabase / backend.
  final String id;

  /// Display name shown in the UI.
  final String? displayName;

  /// Email address for login and contact.
  final String? email;

  AppUser({
    required this.id,
    this.displayName,
    this.email,
  });

  /// Build a user from a JSON map returned by the backend.
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
    );
  }
}


import 'package:fbla_connect_app/models/user.dart';
import 'package:fbla_connect_app/services/api_service.dart';

/// Shapes the response returned by /auth/session on the backend.
class AuthSession {
  /// The authenticated user.
  final AppUser user;

  /// The token that should be stored and attached to future requests.
  final String token;

  AuthSession({
    required this.user,
    required this.token,
  });

  /// Build an AuthSession from the backend JSON payload.
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> userJson =
        (json['user'] as Map<String, dynamic>? ?? <String, dynamic>{});
    return AuthSession(
      user: AppUser.fromJson(userJson),
      token: json['token'] as String? ?? '',
    );
  }
}

/// Service responsible for authentication-related API calls.
class AuthService {
  /// Reference to the shared API client.
  final ApiService _api = ApiService.instance;

  /// Exchange a Supabase access token for a backend session.
  ///
  /// This calls POST /auth/session with the token and, on success:
  /// - stores the token in secure storage
  /// - returns an AuthSession object representing the current user.
  Future<AuthSession> createSession(String supabaseAccessToken) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'token': supabaseAccessToken,
    };

    final AuthSession session = await _api.post<AuthSession>(
      '/auth/session',
      body: body,
      parser: (dynamic data) {
        return AuthSession.fromJson(
          data as Map<String, dynamic>,
        );
      },
    );

    await _api.setToken(session.token);
    return session;
  }
}


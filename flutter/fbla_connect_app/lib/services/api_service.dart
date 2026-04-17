import 'dart:async';

import 'package:dio/dio.dart' hide MultipartFile;
import 'package:dio/dio.dart' as dio_pkg show MultipartFile;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// Base URL for the Flask backend API — reads from config.dart / --dart-define.
const String backendBaseUrl = kBackendBaseUrl;

/// A simple API client that wraps Dio and knows how to:
/// - attach the auth token as a Bearer header
/// - read and write the token from secure storage
/// - normalize and surface backend errors in a friendly way.
class ApiService {
  ApiService._internal()
      : _dio = Dio(
          BaseOptions(
            baseUrl: backendBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            headers: <String, dynamic>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ),
        _secureStorage = const FlutterSecureStorage() {
    // Always attach the most current Supabase session token before every
    // request, so navigating to a new page never triggers invalid_token.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            // Proactive refresh if token expires within 60 seconds.
            // This prevents the 401→retry cycle by refreshing early.
            final expiresAt = session.expiresAt;
            if (expiresAt != null) {
              final expiresTime =
                  DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
              if (expiresTime.difference(DateTime.now()).inSeconds < 60) {
                try {
                  await Supabase.instance.client.auth.refreshSession();
                } catch (_) {
                  // Non-fatal: will retry on 401 as before.
                }
              }
            }
            // Now get the (possibly refreshed) session.
            final freshSession =
                Supabase.instance.client.auth.currentSession;
            if (freshSession != null) {
              options.headers['Authorization'] =
                  'Bearer ${freshSession.accessToken}';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // On 401: try once to recover. The request may have gone out
          // with a token the backend refuses — we give the session one
          // chance to become valid (passive refresh or active refresh)
          // before surfacing the error. Uses a request-level flag so a
          // single 401 can't re-enter the retry branch and loop forever.
          final alreadyRetried =
              error.requestOptions.extra['__retried401'] == true;
          if (error.response?.statusCode == 401 && !alreadyRetried) {
            String? newToken;
            bool refreshThrewAuthError = false;

            // Step 1 — passive: maybe the SDK auto-refreshed while the
            // request was in flight. Cheapest check first.
            final passive =
                Supabase.instance.client.auth.currentSession?.accessToken;
            final oldToken = error.requestOptions.headers['Authorization'];
            if (passive != null && 'Bearer $passive' != oldToken) {
              newToken = passive;
            } else {
              // Step 2 — active: ask Supabase to mint a fresh access
              // token. Only a genuine AuthException means the refresh
              // token is dead — network errors here should NOT force a
              // sign-out, because they're transient and would kick the
              // user back to the login screen for no reason.
              try {
                final res =
                    await Supabase.instance.client.auth.refreshSession();
                newToken = res.session?.accessToken;
              } on AuthException {
                newToken = null;
                refreshThrewAuthError = true;
              } catch (_) {
                // Network / transient error — leave the session alone.
                newToken = null;
              }
            }

            if (newToken != null) {
              _setAuthHeader(newToken);
              final retryOptions = error.requestOptions
                ..headers['Authorization'] = 'Bearer $newToken'
                ..extra['__retried401'] = true;
              try {
                final response = await _dio.fetch<dynamic>(retryOptions);
                handler.resolve(response);
                return;
              } catch (_) {
                // Retry also failed — keep going and sign out below
                // ONLY if Supabase itself said the session is dead.
              }
            }

            // Only sign out when the refresh-token itself is dead
            // (AuthException). A plain 401 from our own backend — e.g.
            // because the dev backend was still booting, had a wrong
            // JWT secret, or couldn't reach Supabase — is NOT sufficient
            // reason to kick the user out. Previous behavior (global
            // sign-out on every 401) caused the "auto sign-out right
            // after signing in" regression reported by users.
            if (refreshThrewAuthError) {
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (_) {
                // Non-fatal: AuthGate will re-evaluate on next build.
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  static final ApiService _instance = ApiService._internal();

  /// Global singleton instance used by all services.
  static ApiService get instance => _instance;

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  static const String _tokenKey = 'auth_token';

  /// Initialise: prefer the live Supabase session token; fall back to storage.
  Future<void> init() async {
    // First try the active Supabase session (available after app restart
    // because supabase_flutter persists sessions natively).
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _setAuthHeader(session.accessToken);
      return;
    }

    // Otherwise check secure storage (legacy path, best-effort).
    try {
      final String? token = await _secureStorage.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) {
        _setAuthHeader(token);
      }
    } catch (_) {
      // Secure storage unavailable (e.g. macOS sandbox without keychain
      // entitlement). Supabase session persistence handles the common case.
    }
  }

  /// Save a new token in secure storage and update Authorization header.
  ///
  /// The header update always succeeds; storage write is best-effort so that
  /// macOS sandbox builds without a keychain entitlement still work.
  Future<void> setToken(String token) async {
    // Always update the in-memory header first.
    _setAuthHeader(token);
    // Persist to Keychain if available (may fail on macOS without the
    // keychain-access-groups entitlement — safe to ignore).
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
    } catch (_) {
      // Non-fatal: Supabase Flutter persists sessions natively.
    }
  }

  /// Remove the token from storage and clear Authorization header.
  Future<void> clearToken() async {
    _dio.options.headers.remove('Authorization');
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (_) {
      // Non-fatal.
    }
  }

  void _setAuthHeader(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Convert raw backend error codes into user-facing copy. Codes we
  /// don't explicitly handle pass through as-is.
  String _friendlyApiError(String raw, int? status) {
    final code = raw.trim().toLowerCase();
    switch (code) {
      case 'invalid_token':
      case 'missing_bearer_token':
      case 'token_expired':
        return 'Your session has expired. Please sign in again.';
      case 'rate_limit_exceeded':
        return 'Too many requests. Please wait a moment and try again.';
      case 'not_found':
        return 'We couldn\'t find what you were looking for.';
      case 'internal_error':
        return 'Something went wrong on our end. Please try again.';
      case 'method_not_allowed':
        return 'That action isn\'t supported here.';
      default:
        return raw;
    }
  }

  /// Centralized handler that turns Flask-style errors into readable messages.
  Never _handleError(DioException error) {
    // Network issues such as no connection or timeout.
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      // Surface the base URL so it's obvious when the backend isn't
      // running or the platform-specific host is wrong (e.g. Android
      // emulator needs 10.0.2.2, not localhost).
      throw Exception(
        'Unable to reach the server at $backendBaseUrl. '
        'Is the Flask backend running? '
        '(Android emulator: use 10.0.2.2; physical device: use your computer\'s LAN IP)',
      );
    }

    final response = error.response;
    if (response != null) {
      final status = response.statusCode;
      final data = response.data;

      // JSON body — most likely shape from our Flask backend.
      if (data is Map<String, dynamic>) {
        final dynamic errorField = data['error'];
        final String raw = switch (errorField) {
          null => 'Request failed with status $status.',
          String s => s,
          _ => 'Request failed with status $status.',
        };
        throw Exception(_friendlyApiError(raw, status));
      }

      // Non-JSON body (HTML 500 page, plain text, etc.) — surface a
      // truncated snippet so the user can see what went wrong instead of
      // a generic message.
      if (data is String && data.isNotEmpty) {
        final snippet =
            data.length > 200 ? '${data.substring(0, 200)}…' : data;
        throw Exception('Server returned $status: $snippet');
      }

      throw Exception('Server returned $status with no body.');
    }

    // No response at all — propagate underlying Dio error message so the
    // user sees the real cause instead of a generic fallback.
    final detail = error.message ?? error.type.toString();
    throw Exception('Request failed: $detail');
  }

  /// Perform a GET request and parse the `data` field from the backend.
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? parser,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      final dynamic data = (response.data as Map<String, dynamic>)['data'];
      if (parser != null) {
        return parser(data);
      }
      return data as T;
    } on DioException catch (error) {
      _handleError(error);
    }
  }

  /// Perform a POST request with a JSON body and parse the backend `data` field.
  Future<T> post<T>(
    String path, {
    dynamic body,
    T Function(dynamic json)? parser,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        path,
        data: body,
      );
      final dynamic data = (response.data as Map<String, dynamic>)['data'];
      if (parser != null) {
        return parser(data);
      }
      return data as T;
    } on DioException catch (error) {
      _handleError(error);
    }
  }

  /// Perform a PATCH request with a JSON body and parse the backend `data` field.
  Future<T> patch<T>(
    String path, {
    dynamic body,
    T Function(dynamic json)? parser,
  }) async {
    try {
      final Response<dynamic> response = await _dio.patch<dynamic>(
        path,
        data: body,
      );
      final dynamic data = (response.data as Map<String, dynamic>)['data'];
      if (parser != null) {
        return parser(data);
      }
      return data as T;
    } on DioException catch (error) {
      _handleError(error);
    }
  }

  /// Perform a DELETE request. Parses the backend `data` field if a parser is provided.
  Future<T> delete<T>(
    String path, {
    dynamic body,
    T Function(dynamic json)? parser,
  }) async {
    try {
      final Response<dynamic> response = await _dio.delete<dynamic>(
        path,
        data: body,
      );
      if (T == Null || parser == null) return null as T;
      final dynamic data = (response.data as Map<String, dynamic>)['data'];
      return parser(data);
    } on DioException catch (error) {
      _handleError(error);
    }
  }

  /// Upload a file to the backend. Returns the parsed upload data (path, etc.).
  ///
  /// Sends a multipart/form-data POST to /uploads. The [xfile] is attached as
  /// the "file" field. Optional [folder] lets the backend organize by type.
  ///
  /// Accepts an [XFile] (from image_picker / file_picker) rather than a
  /// dart:io [File] so the same code path works on mobile, desktop AND web.
  /// On web there is no real filesystem — we read the bytes into memory and
  /// attach via [MultipartFile.fromBytes]. On native that same code path
  /// avoids the `MultipartFile.fromFile(path)` call which can't open Dart:IO
  /// [File]s on web.
  Future<Map<String, dynamic>> uploadFile(
    XFile xfile, {
    String? folder,
    void Function(int sent, int total)? onProgress,
  }) async {
    final fileName = xfile.name.isNotEmpty
        ? xfile.name
        : (xfile.path.split(RegExp(r'[\\/]')).last);
    final bytes = await xfile.readAsBytes();
    final formData = FormData.fromMap({
      'file': dio_pkg.MultipartFile.fromBytes(bytes, filename: fileName),
      if (folder != null) 'folder': folder,
    });

    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/uploads',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: onProgress,
      );
      final dynamic data = (response.data as Map<String, dynamic>)['data'];
      return (data as Map<String, dynamic>?) ?? {};
    } on DioException catch (error) {
      _handleError(error);
    }
  }

  /// Upload a file and return its public URL in Supabase Storage.
  ///
  /// Convenience wrapper around [uploadFile] that extracts the URL from the
  /// backend response. The backend now returns both 'path' and 'url'.
  Future<String?> uploadFileAndGetUrl(
    XFile xfile, {
    String? folder,
    void Function(int sent, int total)? onProgress,
  }) async {
    final result = await uploadFile(xfile, folder: folder, onProgress: onProgress);
    final upload = result['upload'] as Map<String, dynamic>?;

    // Prefer the pre-built URL from the backend
    final url = upload?['url'] as String?;
    if (url != null) return url;

    // Fallback: construct from path
    final path = upload?['path'] as String?;
    if (path == null) return null;
    return '$kSupabaseUrl/storage/v1/object/public/media/$path';
  }
}


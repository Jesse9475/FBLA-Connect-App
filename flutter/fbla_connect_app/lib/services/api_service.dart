import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Base URL for the Flask backend API.
/// Update this to point at your deployed Render (or other) URL.
const String backendBaseUrl = 'https://your-backend-host.com/api';

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
        _secureStorage = const FlutterSecureStorage();

  static final ApiService _instance = ApiService._internal();

  /// Global singleton instance used by all services.
  static ApiService get instance => _instance;

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  static const String _tokenKey = 'auth_token';

  /// Load token from secure storage and set Authorization header.
  Future<void> init() async {
    final String? token = await _secureStorage.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) {
      _setAuthHeader(token);
    }
  }

  /// Save a new token in secure storage and update Authorization header.
  Future<void> setToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
    _setAuthHeader(token);
  }

  /// Remove the token from storage and clear Authorization header.
  Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
    _dio.options.headers.remove('Authorization');
  }

  void _setAuthHeader(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Centralized handler that turns Flask-style errors into readable messages.
  Never _handleError(DioException error) {
    // Network issues such as no connection or timeout.
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      throw Exception('Unable to reach the server. Please check your connection.');
    }

    final response = error.response;
    if (response != null && response.data is Map<String, dynamic>) {
      final Map<String, dynamic> body = response.data as Map<String, dynamic>;
      final dynamic errorField = body['error'];
      final String message = switch (errorField) {
        null => 'Request failed with status ${response.statusCode}.',
        String s => s,
        _ => 'Request failed with status ${response.statusCode}.',
      };
      throw Exception(message);
    }

    // Fallback for unexpected shapes.
    throw Exception('Unexpected error occurred while talking to the server.');
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
}


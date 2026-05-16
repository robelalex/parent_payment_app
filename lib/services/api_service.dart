import 'package:flutter/foundation.dart';
import 'native_http_client.dart';

class ApiService {
  static const String _base =
      'https://felege-selam-payment-system.onrender.com/api';

  String? _authToken;

  // Call this after login to attach the token to all subsequent requests
  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  // ─── Headers ────────────────────────────────────────────────────────────────

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  // ─── Auth endpoints ──────────────────────────────────────────────────────────

  /// Sends OTP to [email]. Returns {'success': true, 'user_id': ...}
  /// or {'success': false, 'error': '...'} on API-level failure.
  Future<Map<String, dynamic>> sendOtp(String email) async {
    final response = await NativeHttpClient.post(
      '$_base/auth/send-otp/',
      headers: _headers,
      body: {'email': email},
    );

    debugPrint('[ApiService] sendOtp → ${response.statusCode}');

    if (response.isSuccess) {
      return {
        'success': true,
        ...?_asMap(response.json),
      };
    }

    // Surface the server's error message if available
    final serverError = _asMap(response.json)?['error']
        ?? _asMap(response.json)?['detail']
        ?? 'Failed to send OTP (${response.statusCode})';

    return {'success': false, 'error': serverError};
  }

  /// Verifies [otp] for [email]. Returns {'success': true, 'token': '...'}
  /// or {'success': false, 'error': '...'}.
  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    final response = await NativeHttpClient.post(
      '$_base/auth/verify-otp/',
      headers: _headers,
      body: {'email': email, 'otp': otp},
    );

    debugPrint('[ApiService] verifyOtp → ${response.statusCode}');

    if (response.isSuccess) {
      final data = _asMap(response.json) ?? {};
      // Persist the token for future requests
      if (data['token'] != null) setAuthToken(data['token'] as String);
      return {'success': true, ...data};
    }

    final serverError = _asMap(response.json)?['error']
        ?? _asMap(response.json)?['detail']
        ?? 'OTP verification failed (${response.statusCode})';

    return {'success': false, 'error': serverError};
  }

  // ─── Payments ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPayments() async {
    final response = await NativeHttpClient.get(
      '$_base/payments/',
      headers: _headers,
    );

    if (response.isSuccess) {
      return {'success': true, 'data': response.json};
    }
    return {
      'success': false,
      'error': 'Failed to load payments (${response.statusCode})',
    };
  }

  Future<Map<String, dynamic>> createPayment(Map<String, dynamic> payload) async {
    final response = await NativeHttpClient.post(
      '$_base/payments/create/',
      headers: _headers,
      body: payload,
    );

    if (response.isSuccess) {
      return {'success': true, ...?_asMap(response.json)};
    }
    return {
      'success': false,
      'error': _asMap(response.json)?['detail'] ?? 'Payment failed',
    };
  }

  // ─── Utility ──────────────────────────────────────────────────────────────

  /// Safely casts [value] to Map<String, dynamic> or returns null.
  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
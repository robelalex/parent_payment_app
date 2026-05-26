import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'native_http_client.dart';

class ApiService {
  static const String _base =
      'https://felege-selam-payment-system.onrender.com/api';

  static const String baseUrl = _base;

  String? _authToken;
  String? _schoolId;

  void setAuthToken(String token) => _authToken = token;
  void clearAuthToken() => _authToken = null;

  Future<Map<String, String>> get _headers async {
    if (_schoolId == null) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('school_id');
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          _schoolId = decoded.toString().replaceAll('"', '');
        } catch (_) {
          _schoolId = raw.replaceAll('"', '');
        }
      }
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      if (_schoolId != null) 'X-School-ID': _schoolId!,
    };
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendOtp(String email) async {
    final res = await NativeHttpClient.post(
      '$_base/parent/send-otp/',
      headers: await _headers,
      body: {'email': email},
    );
    debugPrint('[ApiService] sendOtp → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {
      'success': false,
      'error': _map(res.json)?['error'] ??
          _map(res.json)?['detail'] ??
          'Failed to send OTP (${res.statusCode})',
    };
  }

  Future<Map<String, dynamic>> verifyOtp(dynamic userId, String otp) async {
    final res = await NativeHttpClient.post(
      '$_base/parent/verify/',
      headers: await _headers,
      body: {'user_id': userId.toString(), 'otp_code': otp},
    );
    debugPrint('[ApiService] verifyOtp → ${res.statusCode}');
    if (res.isSuccess) {
      final data = _map(res.json) ?? {};
      if (data['token'] != null) setAuthToken(data['token'] as String);
      return {'success': true, ...data};
    }
    return {
      'success': false,
      'error': _map(res.json)?['error'] ??
          _map(res.json)?['detail'] ??
          'OTP verification failed (${res.statusCode})',
    };
  }

  // ─── Session ──────────────────────────────────────────────────────────────

  Future<void> saveParentSession(String email, dynamic userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parent_email', email);
    await prefs.setString('parent_user_id', userId.toString());
    if (_authToken != null) await prefs.setString('auth_token', _authToken!);
  }

  Future<Map<String, dynamic>?> getParentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('parent_email');
    final userId = prefs.getString('parent_user_id');
    final token = prefs.getString('auth_token');
    if (email == null || userId == null) return null;
    if (token != null) setAuthToken(token);
    return {'email': email, 'user_id': userId, 'token': token};
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('parent_email');
    await prefs.remove('parent_user_id');
    await prefs.remove('auth_token');
    await prefs.remove('school_id');
    await prefs.remove('selected_student');
    clearAuthToken();
    _schoolId = null;
  }

  // ─── Student ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStudentById(String studentId) async {
    if (_authToken == null) await getParentSession();
    final res = await NativeHttpClient.get(
      '$_base/students/?search=$studentId',
      headers: await _headers,
    );
    debugPrint('[ApiService] getStudentById → ${res.statusCode}');
    if (res.isSuccess) {
      final list = res.json;
      if (list is List && list.isNotEmpty) {
        final match = list.firstWhere(
          (s) => s['student_id']?.toString().toUpperCase() ==
              studentId.toUpperCase(),
          orElse: () => list.first,
        );
        return Map<String, dynamic>.from(match as Map);
      }
      return {'success': false, 'error': 'Student not found'};
    }
    return {
      'success': false,
      'error': _map(res.json)?['detail'] ??
          'Student not found (${res.statusCode})',
    };
  }

  Future<void> saveSelectedStudent(Map<String, dynamic> student) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_student', jsonEncode(student));
  }

  Future<Map<String, dynamic>?> getSelectedStudent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('selected_student');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  // ─── School ───────────────────────────────────────────────────────────────

  Future<void> saveSchoolId(dynamic school) async {
    final prefs = await SharedPreferences.getInstance();
    final schoolIdStr = school.toString().replaceAll('"', '');
    await prefs.setString('school_id', schoolIdStr);
    _schoolId = schoolIdStr;
    debugPrint('[ApiService] Saved school ID: $_schoolId');
  }

  // ─── Payments ─────────────────────────────────────────────────────────────

Future<Map<String, dynamic>> getPendingPayments(dynamic studentDbId) async {
  if (_authToken == null) await getParentSession();
  final h = await _headers;
  debugPrint('[ApiService] getPendingPayments headers: $h');
  debugPrint('[ApiService] Student DB ID: $studentDbId');

  // ✅ Direct call to grade-filtered endpoint
  final res = await NativeHttpClient.get(
    '$_base/students/$studentDbId/pending_payments/',
    headers: h,
  );
  debugPrint('[ApiService] pending_payments response → ${res.statusCode}');
  debugPrint('[ApiService] pending_payments body → ${res.body}');

  if (res.isSuccess) {
    if (res.json is List) {
      return {'success': true, 'data': res.json};
    }
    return {'success': true, 'data': []};
  }
  
  return {
    'success': false,
    'error': 'Failed to load payments (${res.statusCode})',
  };
}

Future<Map<String, dynamic>> getPaymentHistory(dynamic studentDbId) async {
  if (_authToken == null) await getParentSession();
  final h = await _headers;

  final res = await NativeHttpClient.get(
    '$_base/students/$studentDbId/payment_history/',
    headers: h,
  );
  debugPrint('[ApiService] payment_history → ${res.statusCode}');

  if (res.isSuccess) {
    if (res.json is List) {
      return {'success': true, 'data': res.json};
    }
    return {'success': true, 'data': []};
  }
  
  return {
    'success': false,
    'error': 'Failed to load payment history (${res.statusCode})',
  };
}

  Future<Map<String, dynamic>> initiatePayment(
      Map<String, dynamic> payload) async {
    if (_authToken == null) await getParentSession();
    final res = await NativeHttpClient.post(
      '$_base/chapa/test-payment/',
      headers: await _headers,
      body: payload,
    );
    debugPrint('[ApiService] initiatePayment → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {
      'success': false,
      'error': _map(res.json)?['detail'] ??
          _map(res.json)?['error'] ??
          'Payment initiation failed (${res.statusCode})',
    };
  }

  // ─── Utility ──────────────────────────────────────────────────────────────

  Map<String, dynamic>? _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;
}
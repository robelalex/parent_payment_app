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
    // ✅ FIX: was hitting /students/?search= — the admin LIST endpoint,
    // which needs a resolvable school and returns nothing for a parent
    // account (parents have no school of their own). The web app already
    // correctly uses this dedicated, unscoped lookup-by-ID endpoint —
    // Flutter just wasn't pointed at it.
    final res = await NativeHttpClient.get(
      '$_base/students/search_by_id/?student_id=$studentId',
      headers: await _headers,
    );
    debugPrint('[ApiService] getStudentById → ${res.statusCode}');
    if (res.isSuccess) {
      final data = _map(res.json);
      if (data != null) return data;
      return {'success': false, 'error': 'Student not found'};
    }
    return {
      'success': false,
      'error': _map(res.json)?['error'] ??
          _map(res.json)?['detail'] ??
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
  
  // ✅ ADD platform for mobile
  final mobilePayload = {
    ...payload,
    'platform': 'mobile',
  };
  
  final res = await NativeHttpClient.post(
    '$_base/chapa/test-payment/',
    headers: await _headers,
    body: mobilePayload,
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

  Future<Map<String, dynamic>> verifyPayment(String txRef) async {
    if (_authToken == null) await getParentSession();
    final res = await NativeHttpClient.get(
      '$_base/chapa/verify/?tx_ref=$txRef',
      headers: await _headers,
    );
    debugPrint('[ApiService] verifyPayment → ${res.statusCode}');
    debugPrint('[ApiService] verifyPayment response → ${res.body}');
    
    if (res.isSuccess) {
      final data = _map(res.json) ?? {};
      return {'success': true, ...data};
    }
    return {
      'success': false,
      'error': 'Payment verification failed',
    };
  }

  // ─── Teacher Auth ─────────────────────────────────────────────────────────
  // Teachers use the same email+password+OTP flow as the web admin panel
  // (StaffMemberViewSet.create_login sets them up for it already) — no
  // separate backend auth system needed.

  Future<Map<String, dynamic>> teacherLogin(String email, String password) async {
    final res = await NativeHttpClient.post(
      '$_base/login/',
      headers: await _headers,
      body: {'email': email, 'password': password},
    );
    debugPrint('[ApiService] teacherLogin → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {
      'success': false,
      'error': _map(res.json)?['error'] ?? 'Login failed (${res.statusCode})',
    };
  }

  Future<Map<String, dynamic>> verifyTeacherOtp(dynamic userId, String otp) async {
    final res = await NativeHttpClient.post(
      '$_base/verify/',
      headers: await _headers,
      body: {'user_id': userId.toString(), 'otp_code': otp},
    );
    debugPrint('[ApiService] verifyTeacherOtp → ${res.statusCode}');
    if (res.isSuccess) {
      final data = _map(res.json) ?? {};
      // ✅ This endpoint returns 'access', not 'token' (JWT via simplejwt) —
      // different field name than the parent OTP flow, same mechanism.
      if (data['access'] != null) setAuthToken(data['access'] as String);
      if (data['user']?['school']?['id'] != null) {
        _schoolId = data['user']['school']['id'].toString();
      }
      return {'success': true, ...data};
    }
    return {
      'success': false,
      'error': _map(res.json)?['error'] ?? 'OTP verification failed (${res.statusCode})',
    };
  }

  Future<void> saveTeacherSession(Map<String, dynamic> user, String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teacher_user', jsonEncode(user));
    await prefs.setString('teacher_access_token', accessToken);
    if (user['school']?['id'] != null) {
      await prefs.setString('school_id', user['school']['id'].toString());
      _schoolId = user['school']['id'].toString();
    }
  }

  Future<Map<String, dynamic>?> getTeacherSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userRaw = prefs.getString('teacher_user');
    final token = prefs.getString('teacher_access_token');
    if (userRaw == null || token == null) return null;
    setAuthToken(token);
    return jsonDecode(userRaw) as Map<String, dynamic>;
  }

  Future<void> clearTeacherSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('teacher_user');
    await prefs.remove('teacher_access_token');
    clearAuthToken();
  }

  // ─── Teacher: my classes ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMyAssignments() async {
    final res = await NativeHttpClient.get('$_base/teacher/my-assignments/', headers: await _headers);
    debugPrint('[ApiService] getMyAssignments → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _map(res.json)?['error'] ?? 'Failed to load your classes'};
  }

  Future<Map<String, dynamic>> getAssessmentTypes(int academicYearId) async {
    final res = await NativeHttpClient.get(
      '$_base/assessment-types/?academic_year_id=$academicYearId',
      headers: await _headers,
    );
    if (res.isSuccess) return {'success': true, 'data': res.json ?? []};
    return {'success': false, 'error': 'Failed to load assessment types'};
  }

  // ─── Teacher: marks ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMarkRoster({
    required int subjectId, required int assessmentTypeId, required int grade, String section = '',
  }) async {
    final res = await NativeHttpClient.get(
      '$_base/marks/roster/?subject_id=$subjectId&assessment_type_id=$assessmentTypeId&grade=$grade&section=$section',
      headers: await _headers,
    );
    debugPrint('[ApiService] getMarkRoster → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _map(res.json)?['error'] ?? 'Failed to load roster'};
  }

  Future<Map<String, dynamic>> saveMarks({
    required int subjectId, required int assessmentTypeId, required int grade, String section = '',
    required List<Map<String, dynamic>> entries,
  }) async {
    final res = await NativeHttpClient.post(
      '$_base/marks/bulk_save/',
      headers: await _headers,
      body: {
        'subject_id': subjectId, 'assessment_type_id': assessmentTypeId,
        'grade': grade, 'section': section, 'entries': entries,
      },
    );
    debugPrint('[ApiService] saveMarks → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _map(res.json)?['error'] ?? 'Failed to save marks'};
  }

  Future<Map<String, dynamic>> submitMarks({
    required int subjectId, required int assessmentTypeId, required int grade, String section = '',
  }) async {
    final res = await NativeHttpClient.post(
      '$_base/marks/submit/',
      headers: await _headers,
      body: {'subject_id': subjectId, 'assessment_type_id': assessmentTypeId, 'grade': grade, 'section': section},
    );
    debugPrint('[ApiService] submitMarks → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _map(res.json)?['error'] ?? 'Failed to submit marks'};
  }

  // ─── Homeroom: review ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getHomeroomPending({required int grade, required String section}) async {
    final res = await NativeHttpClient.get(
      '$_base/marks/homeroom_pending/?grade=$grade&section=$section',
      headers: await _headers,
    );
    debugPrint('[ApiService] getHomeroomPending → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, 'data': res.json ?? []};
    return {'success': false, 'error': _map(res.json)?['error'] ?? 'Failed to load pending marks'};
  }

  Future<Map<String, dynamic>> homeroomDecide({
    required bool accept, required int subjectId, required int assessmentTypeId,
    required int grade, required String section, String note = '',
  }) async {
    final res = await NativeHttpClient.post(
      '$_base/marks/${accept ? 'homeroom_accept' : 'homeroom_reject'}/',
      headers: await _headers,
      body: {
        'subject_id': subjectId, 'assessment_type_id': assessmentTypeId,
        'grade': grade, 'section': section, 'note': note,
      },
    );
    debugPrint('[ApiService] homeroomDecide → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _map(res.json)?['error'] ?? 'Failed to update'};
  }

  // ─── Homeroom: attendance ───────────────────────────────────────────────

  Future<Map<String, dynamic>> getAttendanceRoster({
    required int grade, required String section, required String date,
  }) async {
    final res = await NativeHttpClient.get(
      '$_base/attendance/roster/?grade=$grade&section=$section&date=$date',
      headers: await _headers,
    );
    debugPrint('[ApiService] getAttendanceRoster → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _map(res.json)?['error'] ?? 'Failed to load attendance'};
  }

  Future<Map<String, dynamic>> saveAttendance({
    required int grade, required String section, required String date,
    required List<Map<String, dynamic>> entries,
  }) async {
    final res = await NativeHttpClient.post(
      '$_base/attendance/bulk_save/',
      headers: await _headers,
      body: {'grade': grade, 'section': section, 'date': date, 'entries': entries},
    );
    debugPrint('[ApiService] saveAttendance → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _map(res.json)?['error'] ?? 'Failed to save attendance'};
  }

  // ─── Utility ──────────────────────────────────────────────────────────────

  Map<String, dynamic>? _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;
}
// lib/services/api_service.dart
//
// ✅ FIX APPLIED: ApiService is now a singleton (see the factory
// constructor right below the class declaration). Previously every
// screen did `final _apiService = ApiService();`, which created a
// brand-new object with its own empty _authToken each time. Only the
// login/OTP screens and the two "*Home*" screens (which reload the
// token from SharedPreferences via getParentSession()/getTeacherSession())
// ever populated that field — every other screen (Attendance, Gradebook,
// Mark Entry, Homeroom Review, Subject Attendance, Class Results, Report
// Cards, etc.) created its own token-less instance and sent requests
// with no Authorization header, which the backend correctly rejected
// with "Authentication credentials were not provided."
//
// The fix: `factory ApiService() => _instance;` makes every
// `ApiService()` call anywhere in the app return the SAME object, so
// once the token is set once (right after OTP verification, on either
// the parent or teacher side), every screen sees it. No other code
// changes needed — every existing `final _apiService = ApiService();`
// line keeps working exactly as written.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'native_http_client.dart';

class ApiService {
  ApiService._internal();
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

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

  // ─── Auth (parent) ───────────────────────────────────────────────────────

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

  // ─── Session (parent) ────────────────────────────────────────────────────

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

  // ─── Parent: report cards ───────────────────────────────────────────────
  // Only ever returns released report cards for this one child (enforced
  // server-side by ReportCardViewSet.get_queryset's parent-scoping), same
  // as every other parent-facing endpoint here.
  Future<Map<String, dynamic>> getReportCards(dynamic studentDbId) async {
    if (_authToken == null) await getParentSession();
    final res = await NativeHttpClient.get(
      '$_base/report-cards/?student_id=$studentDbId&status=released',
      headers: await _headers,
    );
    debugPrint('[ApiService] getReportCards → ${res.statusCode}');
    if (res.isSuccess) {
      if (res.json is List) return {'success': true, 'data': res.json};
      return {'success': true, 'data': []};
    }
    return {
      'success': false,
      'error': _errorMessage(res, 'Failed to load report cards'),
    };
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

  Future<Map<String, dynamic>> getChildRecord(dynamic studentDbId) async {
    if (_authToken == null) await getParentSession();
    final h = await _headers;

    final res = await NativeHttpClient.get(
      '$_base/students/$studentDbId/child_record/',
      headers: h,
    );
    debugPrint('[ApiService] child_record → ${res.statusCode}');

    if (res.isSuccess) {
      if (res.json is Map<String, dynamic>) {
        return {'success': true, 'data': res.json};
      }
      return {'success': false, 'error': 'Unexpected response format'};
    }

    return {
      'success': false,
      'error': 'Failed to load attendance/marks (${res.statusCode})',
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

  /// Fast path — checks our own DB first (works for both dashboard and
  /// reminder-link payments), same as the web's PaymentSuccess.js step 1.
  Future<Map<String, dynamic>> getPaymentStatus(String txRef) async {
    final res = await NativeHttpClient.get(
      '$_base/payments/status/$txRef/',
      headers: await _headers,
    );
    debugPrint('[ApiService] getPaymentStatus → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _errorMessage(res, 'Payment not found')};
  }

  /// The real invoice — same public endpoint the web's ReceiptPage.jsx uses.
  Future<Map<String, dynamic>> getReceipt(String receiptToken) async {
    final res = await NativeHttpClient.get(
      '$_base/receipt/$receiptToken/',
      headers: await _headers,
    );
    debugPrint('[ApiService] getReceipt → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _errorMessage(res, 'Receipt not found')};
  }

  /// Same public polling endpoint the web uses after an upload.
  Future<Map<String, dynamic>> getSlipStatus(int slipId) async {
    final res = await NativeHttpClient.get(
      '$_base/slips/$slipId/status/',
      headers: await _headers,
    );
    debugPrint('[ApiService] getSlipStatus → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _errorMessage(res, 'Could not check slip status')};
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
      'error': _errorMessage(res, 'Login failed (${res.statusCode})'),
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
      // ✅ This endpoint returns 'access', not 'token' (JWT via simplejwt).
      if (data['access'] != null) setAuthToken(data['access'] as String);
      if (data['user']?['school']?['id'] != null) {
        _schoolId = data['user']['school']['id'].toString();
      }
      return {'success': true, ...data};
    }
    return {
      'success': false,
      'error': _errorMessage(res, 'OTP verification failed (${res.statusCode})'),
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
    return {'success': false, 'error': _errorMessage(res, 'Failed to load your classes')};
  }

  Future<Map<String, dynamic>> getTerms(int academicYearId) async {
    final res = await NativeHttpClient.get(
      '$_base/terms/?academic_year_id=$academicYearId',
      headers: await _headers,
    );
    debugPrint('[ApiService] getTerms → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, 'data': res.json ?? []};
    return {'success': false, 'error': _errorMessage(res, 'Failed to load terms')};
  }

  /// [grade] is optional — when provided, the backend returns only
  /// assessment types registered for that grade plus ones marked "all
  /// grades" (assessment types are class(grade)-based).
  Future<Map<String, dynamic>> getAssessmentTypes(int academicYearId, {int? grade}) async {
    final gradeParam = grade != null ? '&grade=$grade' : '';
    final res = await NativeHttpClient.get(
      '$_base/assessment-types/?academic_year_id=$academicYearId$gradeParam',
      headers: await _headers,
    );
    debugPrint('[ApiService] getAssessmentTypes → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, 'data': res.json ?? []};
    return {'success': false, 'error': _errorMessage(res, 'Failed to load assessment types')};
  }

  // ─── Gradebook: the shared table for both subject teacher and homeroom ──

  Future<Map<String, dynamic>> getGradebook({
    required int subjectId, required int termId, required int grade, String section = '',
  }) async {
    final res = await NativeHttpClient.get(
      '$_base/marks/gradebook/?subject_id=$subjectId&term_id=$termId&grade=$grade&section=$section',
      headers: await _headers,
    );
    debugPrint('[ApiService] getGradebook → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _errorMessage(res, 'Failed to load gradebook')};
  }

  Future<Map<String, dynamic>> submitStudent({
    required int subjectId, required int termId, required int grade, String section = '', required int studentId,
  }) async {
    final res = await NativeHttpClient.post(
      '$_base/marks/submit_student/',
      headers: await _headers,
      body: {
        'subject_id': subjectId, 'term_id': termId, 'grade': grade,
        'section': section, 'student_id': studentId,
      },
    );
    debugPrint('[ApiService] submitStudent → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _errorMessage(res, 'Failed to submit this student\'s marks')};
  }

  Future<Map<String, dynamic>> getClassAssignments(int grade) async {
    final res = await NativeHttpClient.get(
      '$_base/class-assignments/?grade=$grade',
      headers: await _headers,
    );
    debugPrint('[ApiService] getClassAssignments → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, 'data': res.json ?? []};
    return {'success': false, 'error': _errorMessage(res, 'Failed to load subjects for this class')};
  }

  // ─── Teacher: school info & semesters (Item 7 — quarter/semester) ───────
  // Only used to decide whether the Quarter/Semester toggle should show
  // on the Class Results screen; a semester-structure school (the
  // default) never sees it, exactly like the web app.

  Future<Map<String, dynamic>> getSchoolInfo() async {
    final res = await NativeHttpClient.get('$_base/schools/', headers: await _headers);
    debugPrint('[ApiService] getSchoolInfo → ${res.statusCode}');
    if (res.isSuccess) {
      final data = res.json;
      final school = data is List ? (data.isNotEmpty ? data.first : null) : data;
      return {'success': true, 'data': school};
    }
    return {'success': false, 'error': _errorMessage(res, 'Failed to load school info')};
  }

  Future<Map<String, dynamic>> getSemesters(int academicYearId) async {
    final res = await NativeHttpClient.get(
      '$_base/semesters/?academic_year_id=$academicYearId',
      headers: await _headers,
    );
    debugPrint('[ApiService] getSemesters → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, 'data': res.json ?? []};
    return {'success': false, 'error': _errorMessage(res, 'Failed to load semesters')};
  }

  // ─── Teacher: class results & ranking ("Check Result and Award") ────────
  // Excel export is deliberately NOT included here — see the note in
  // class_results_screen.dart for why.

  Future<Map<String, dynamic>> getClassResults({
    required int termId, required int grade, String section = '',
  }) async {
    final res = await NativeHttpClient.get(
      '$_base/results/class_results/?term_id=$termId&grade=$grade&section=$section',
      headers: await _headers,
    );
    debugPrint('[ApiService] getClassResults → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, 'data': res.json ?? []};
    return {'success': false, 'error': _errorMessage(res, 'Failed to load results')};
  }

  Future<Map<String, dynamic>> getClassResultsByTerms({
    required int grade, String section = '', required int academicYearId,
  }) async {
    final res = await NativeHttpClient.get(
      '$_base/results/class_results_terms/?grade=$grade&section=$section&academic_year_id=$academicYearId',
      headers: await _headers,
    );
    debugPrint('[ApiService] getClassResultsByTerms → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _errorMessage(res, 'Failed to load results')};
  }

  Future<Map<String, dynamic>> getClassResultsBySemesters({
    required int grade, String section = '', required int academicYearId,
  }) async {
    final res = await NativeHttpClient.get(
      '$_base/semester-results/class_results_semesters/?grade=$grade&section=$section&academic_year_id=$academicYearId',
      headers: await _headers,
    );
    debugPrint('[ApiService] getClassResultsBySemesters → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _errorMessage(res, 'Failed to load results')};
  }

  Future<Map<String, dynamic>> getClassResultsBySemester({
    required int semesterId, required int grade, String section = '',
  }) async {
    final res = await NativeHttpClient.get(
      '$_base/semester-results/class_results/?semester_id=$semesterId&grade=$grade&section=$section',
      headers: await _headers,
    );
    debugPrint('[ApiService] getClassResultsBySemester → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, 'data': res.json ?? []};
    return {'success': false, 'error': _errorMessage(res, 'Failed to load results')};
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
    return {'success': false, 'error': _errorMessage(res, 'Failed to load roster')};
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
    return {'success': false, 'error': _errorMessage(res, 'Failed to save marks')};
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
    return {'success': false, 'error': _errorMessage(res, 'Failed to submit marks')};
  }

  // ─── Homeroom: review ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getHomeroomPending({required int grade, required String section}) async {
    final res = await NativeHttpClient.get(
      '$_base/marks/homeroom_pending/?grade=$grade&section=$section',
      headers: await _headers,
    );
    debugPrint('[ApiService] getHomeroomPending → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, 'data': res.json ?? []};
    return {'success': false, 'error': _errorMessage(res, 'Failed to load pending marks')};
  }

  Future<Map<String, dynamic>> homeroomDecide({
    required bool accept, required int subjectId, required int assessmentTypeId,
    required int grade, required String section, String note = '', int? studentId,
  }) async {
    final body = <String, dynamic>{
      'subject_id': subjectId, 'assessment_type_id': assessmentTypeId,
      'grade': grade, 'section': section, 'note': note,
    };
    if (studentId != null) body['student_id'] = studentId;
    final res = await NativeHttpClient.post(
      '$_base/marks/${accept ? 'homeroom_accept' : 'homeroom_reject'}/',
      headers: await _headers,
      body: body,
    );
    debugPrint('[ApiService] homeroomDecide → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _errorMessage(res, 'Failed to update')};
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
    return {'success': false, 'error': _errorMessage(res, 'Failed to load attendance')};
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
    return {'success': false, 'error': _errorMessage(res, 'Failed to save attendance')};
  }

  // ─── Subject teacher: period attendance (separate from homeroom's daily) ─

  Future<Map<String, dynamic>> getSubjectAttendanceRoster({
    required int subjectId, required int grade, required String section, required String date,
  }) async {
    final res = await NativeHttpClient.get(
      '$_base/subject-attendance/roster/?subject_id=$subjectId&grade=$grade&section=$section&date=$date',
      headers: await _headers,
    );
    debugPrint('[ApiService] getSubjectAttendanceRoster → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _errorMessage(res, 'Failed to load attendance')};
  }

  Future<Map<String, dynamic>> saveSubjectAttendance({
    required int subjectId, required int grade, required String section, required String date,
    required List<Map<String, dynamic>> entries,
  }) async {
    final res = await NativeHttpClient.post(
      '$_base/subject-attendance/bulk_save/',
      headers: await _headers,
      body: {'subject_id': subjectId, 'grade': grade, 'section': section, 'date': date, 'entries': entries},
    );
    debugPrint('[ApiService] saveSubjectAttendance → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, ...?_map(res.json)};
    return {'success': false, 'error': _errorMessage(res, 'Failed to save attendance')};
  }

  // ─── Attendance summary (date range) ────────────────────────────────────
  // Reuses the same list endpoints the roster screens already call, just
  // with date_from/date_to instead of a single date — the backend scopes
  // both to the teacher's own class(es), same as the roster endpoints.
  // Grouping into per-student present/absent/late/excused counts happens
  // client-side, mirroring the web.

  Future<Map<String, dynamic>> getAttendanceSummaryRecords({
    required int grade, required String section, required String dateFrom, required String dateTo,
  }) async {
    final res = await NativeHttpClient.get(
      '$_base/attendance/?grade=$grade&section=$section&date_from=$dateFrom&date_to=$dateTo',
      headers: await _headers,
    );
    debugPrint('[ApiService] getAttendanceSummaryRecords → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, 'data': res.json ?? []};
    return {'success': false, 'error': _errorMessage(res, 'Failed to load attendance summary')};
  }

  Future<Map<String, dynamic>> getSubjectAttendanceSummaryRecords({
    required int subjectId, required int grade, required String section,
    required String dateFrom, required String dateTo,
  }) async {
    final res = await NativeHttpClient.get(
      '$_base/subject-attendance/?subject_id=$subjectId&grade=$grade&section=$section&date_from=$dateFrom&date_to=$dateTo',
      headers: await _headers,
    );
    debugPrint('[ApiService] getSubjectAttendanceSummaryRecords → ${res.statusCode}');
    if (res.isSuccess) return {'success': true, 'data': res.json ?? []};
    return {'success': false, 'error': _errorMessage(res, 'Failed to load attendance summary')};
  }

  // ─── Utility ──────────────────────────────────────────────────────────────

  Map<String, dynamic>? _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  /// Builds a useful error message even when the backend didn't return
  /// clean JSON (server crash → HTML error page, wrong URL → 404 page,
  /// etc.) — shows the real HTTP status and a snippet of the raw response
  /// right in the app, so a failure can be diagnosed from the phone alone,
  /// without needing server log access.
  String _errorMessage(NativeHttpResponse res, String fallback) {
    final parsed = _map(res.json)?['error'] ?? _map(res.json)?['detail'];
    if (parsed != null) return parsed.toString();
    final snippet = res.body.length > 300 ? '${res.body.substring(0, 300)}…' : res.body;
    return '$fallback — HTTP ${res.statusCode}: ${snippet.isEmpty ? '(empty response)' : snippet}';
  }
}
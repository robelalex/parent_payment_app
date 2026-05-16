// lib/services/api_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Change from local to production
static const String baseUrl = 'https://216.24.57.7/api';
  
  Future<Map<String, dynamic>> sendOtp(String email) async {
    final url = Uri.parse('$baseUrl/parent/send-otp/');
    print('📤 Sending OTP request to: $url');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      print('❌ Network error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }
  
  Future<Map<String, dynamic>> verifyOtp(int userId, String otpCode) async {
    final url = Uri.parse('$baseUrl/parent/verify/');
    print('📤 Verifying OTP at: $url');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'otp_code': otpCode}),
      );
      
      print('📥 Verify response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Verification failed'};
      }
    } catch (e) {
      print('❌ Verify error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }
  
  Future<Map<String, dynamic>> getStudentById(String studentId) async {
    final url = Uri.parse('$baseUrl/students/search_by_id/?student_id=$studentId');
    print('📤 Fetching student: $url');
    
    try {
      final response = await http.get(url);
      print('📥 Student response status: ${response.statusCode}');
      print('📥 Student response body: ${response.body}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        return {'error': 'Student ID not found'};
      } else {
        return {'error': 'Failed to fetch student: ${response.statusCode}'};
      }
    } catch (e) {
      print('❌ Student fetch error: $e');
      return {'error': 'Network error: $e'};
    }
  }
  
  Future<List<dynamic>> getPendingPayments(int studentDbId) async {
    final url = Uri.parse('$baseUrl/students/$studentDbId/pending_payments/');
    print('📤 Fetching pending payments: $url');
    
    try {
      final response = await http.get(url);
      print('📥 Pending payments status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Pending payments error: $e');
      return [];
    }
  }
  
  Future<List<dynamic>> getPaymentHistory(int studentDbId) async {
    final url = Uri.parse('$baseUrl/students/$studentDbId/payment_history/');
    print('📤 Fetching payment history: $url');
    
    try {
      final response = await http.get(url);
      print('📥 Payment history status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Payment history error: $e');
      return [];
    }
  }
  
  Future<Map<String, dynamic>> initiatePayment({
    required String studentId,
    required int deadlineId,
    required double amount,
    required String paidBy,
    required String paidByPhone,
  }) async {
    final url = Uri.parse('$baseUrl/chapa/test-payment/');
    print('📤 Initiating payment: $url');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'deadline_id': deadlineId,
          'amount': amount,
          'paid_by': paidBy,
          'paid_by_phone': paidByPhone,
        }),
      );
      
      print('📥 Payment response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Payment failed'};
      }
    } catch (e) {
      print('❌ Payment error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }
  
  // ✅ Upload slip method
  Future<Map<String, dynamic>> uploadSlip({
    required String studentId,
    required int deadlineId,
    required double amount,
    required String bankName,
    required String uploadedBy,
    required Uint8List imageBytes,
    required String schoolId,
  }) async {
    final uri = Uri.parse('$baseUrl/slips/upload/');
    
    try {
      final request = http.MultipartRequest('POST', uri);
      
      request.headers.addAll({
        'X-School-ID': schoolId,
      });
      
      request.fields['student_id'] = studentId;
      request.fields['deadline_id'] = deadlineId.toString();
      request.fields['amount'] = amount.toString();
      request.fields['bank_name'] = bankName;
      request.fields['uploaded_by'] = uploadedBy;
      
      final multipartFile = http.MultipartFile.fromBytes(
        'slip_image',
        imageBytes,
        filename: 'slip_${studentId}_${deadlineId}.jpg',
      );
      request.files.add(multipartFile);
      
      print('📤 Uploading slip to: $uri');
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      print('📥 Upload response status: ${response.statusCode}');
      print('📥 Upload response body: $responseBody');
      
      if (response.statusCode == 201) {
        return jsonDecode(responseBody);
      } else {
        return {'success': false, 'error': 'Upload failed: ${response.statusCode}'};
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }
  
  // ✅ NEW: Save school ID to shared preferences
  Future<void> saveSchoolId(int schoolId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('schoolId', schoolId);
    print('✅ Saved school ID: $schoolId');
  }
  
  // ✅ NEW: Get school ID from shared preferences
  Future<int?> getSchoolId() async {
    final prefs = await SharedPreferences.getInstance();
    final schoolId = prefs.getInt('schoolId');
    print('📚 Retrieved school ID: $schoolId');
    return schoolId;
  }
  
  Future<void> saveParentSession(String email, int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parentEmail', email);
    await prefs.setInt('parentUserId', userId);
    await prefs.setBool('isParentLoggedIn', true);
  }
  
  Future<Map<String, dynamic>> getParentSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString('parentEmail'),
      'userId': prefs.getInt('parentUserId'),
      'isLoggedIn': prefs.getBool('isParentLoggedIn') ?? false,
    };
  }
  
  Future<void> saveSelectedStudent(Map<String, dynamic> student) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedStudent', jsonEncode(student));
  }
  
  Future<Map<String, dynamic>?> getSelectedStudent() async {
    final prefs = await SharedPreferences.getInstance();
    final studentJson = prefs.getString('selectedStudent');
    if (studentJson != null) {
      return jsonDecode(studentJson);
    }
    return null;
  }
  
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
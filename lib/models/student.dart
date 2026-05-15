// lib/models/student.dart
class Student {
  final int id;
  final String studentId;
  final String fullName;
  final int grade;
  final String? section;
  final String? academicYear;
  final String? parentEmail;
  final String? parentPhone;
  final double monthlyFee;
  
  Student({
    required this.id,
    required this.studentId,
    required this.fullName,
    required this.grade,
    this.section,
    this.academicYear,
    this.parentEmail,
    this.parentPhone,
    required this.monthlyFee,
  });
  
  factory Student.fromJson(Map<String, dynamic> json) {
    // ✅ Handle monthly_fee as String or number
    double fee = 0;
    if (json['monthly_fee'] != null) {
      if (json['monthly_fee'] is String) {
        fee = double.tryParse(json['monthly_fee']) ?? 0;
      } else if (json['monthly_fee'] is num) {
        fee = (json['monthly_fee'] as num).toDouble();
      }
    }
    
    return Student(
      id: json['id'] ?? 0,
      studentId: json['student_id'] ?? '',
      fullName: json['full_name'] ?? '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim(),
      grade: json['grade'] ?? 0,
      section: json['section'],
      academicYear: json['academic_year'],
      parentEmail: json['parent_email'],
      parentPhone: json['parent_phone'],
      monthlyFee: fee,
    );
  }
}
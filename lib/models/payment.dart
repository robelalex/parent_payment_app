// lib/models/payment.dart
class Payment {
  final int id;
  final String? monthName;
  final double amount;
  final String? dueDate;
  final String? status;
  final String? description;
  
  Payment({
    required this.id,
    this.monthName,
    required this.amount,
    this.dueDate,
    this.status,
    this.description,
  });
  
  factory Payment.fromJson(Map<String, dynamic> json) {
    // ✅ Handle amount as String or number
    double amt = 0;
    if (json['amount'] != null) {
      if (json['amount'] is String) {
        amt = double.tryParse(json['amount']) ?? 0;
      } else if (json['amount'] is num) {
        amt = (json['amount'] as num).toDouble();
      }
    }
    
    return Payment(
      id: json['id'] ?? 0,
      monthName: json['month_name'] ?? json['month'],
      amount: amt,
      dueDate: json['due_date'],
      status: json['status'],
      description: json['description'],
    );
  }
}
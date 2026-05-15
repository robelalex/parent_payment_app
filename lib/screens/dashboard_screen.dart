// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/student.dart';
import '../models/payment.dart';
import 'login_screen.dart';
import 'enter_student_id_screen.dart';
import 'bank_transfer_modal.dart';
import 'upload_slip_modal.dart';


class DashboardScreen extends StatefulWidget {
  final int studentId;
  
  const DashboardScreen({super.key, required this.studentId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _apiService = ApiService();
  Student? _student;
  List<Payment> _pendingPayments = [];
  List<Payment> _paymentHistory = [];
  bool _isLoading = true;
  String? _error;
  int? _processingPaymentId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    
    try {
      final savedStudent = await _apiService.getSelectedStudent();
      print('📊 Saved student from localStorage: $savedStudent');
      
      if (savedStudent != null && savedStudent['id'] != null) {
        _student = Student.fromJson(savedStudent);
        
        final studentDbId = savedStudent['id'];
        final pending = await _apiService.getPendingPayments(studentDbId);
        _pendingPayments = pending.map((p) => Payment.fromJson(p)).toList();
        
        final history = await _apiService.getPaymentHistory(studentDbId);
        _paymentHistory = history.map((p) => Payment.fromJson(p)).toList();
        
        print('✅ Student loaded: ${_student!.fullName}');
        print('✅ Pending payments: ${_pendingPayments.length}');
        print('✅ Payment history: ${_paymentHistory.length}');
      } else {
        setState(() => _error = 'Student data not found');
      }
      
    } catch (e) {
      print('❌ Error loading data: $e');
      setState(() => _error = 'Failed to load data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _makePayment(Payment payment) async {
    setState(() { _processingPaymentId = payment.id; });
    
    try {
      final result = await _apiService.initiatePayment(
        studentId: _student!.studentId,
        deadlineId: payment.id,
        amount: payment.amount,
        paidBy: _student!.parentEmail ?? 'Parent',
        paidByPhone: _student!.parentPhone ?? '0912345678',
      );
      
      print('💰 Payment result: $result');
      
      if (result['checkout_url'] != null) {
        _showPaymentDialog(result['checkout_url']);
      } else if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment initiated successfully!')),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Payment failed')),
        );
      }
    } catch (e) {
      print('❌ Payment error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment initiation failed')),
      );
    } finally {
      setState(() { _processingPaymentId = null; });
    }
  }

  void _showBankTransfer(Payment payment) {
    showDialog(
      context: context,
      builder: (context) => BankTransferModal(
        payment: payment,
        student: _student!,
        onUploadSlip: () => _showUploadSlip(payment),
      ),
    );
  }

  void _showUploadSlip(Payment payment) {
    showDialog(
      context: context,
      builder: (context) => UploadSlipModal(
        student: _student!,
        payment: payment,
        onSuccess: _loadData,
      ),
    );
  }

  void _showPaymentDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Payment'),
        content: const Text('You will be redirected to complete your payment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // ignore: deprecated_member_use
              html.window.open(url, '_blank');
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  int _getDaysRemaining(String? dueDate) {
    if (dueDate == null) return 0;
    try {
      final due = DateTime.parse(dueDate);
      final today = DateTime.now();
      return due.difference(today).inDays;
    } catch (e) {
      return 0;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _student == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error ?? 'Student not found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const EnterStudentIdScreen()),
                  );
                },
                child: const Text('Back to Student ID Entry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_student!.fullName),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _apiService.clearSession();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: Colors.indigo,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student Info Card
              _buildStudentInfoCard(),
              const SizedBox(height: 16),
              
              // Contact Info Card
              _buildContactInfoCard(),
              const SizedBox(height: 24),
              
              // Pending Payments Section
              if (_pendingPayments.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.pending_actions, size: 20, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Pending Payments (${_pendingPayments.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._pendingPayments.map((payment) => _buildPaymentCard(payment)),
                const SizedBox(height: 24),
              ],
              
              // Payment History Section
              if (_paymentHistory.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.history, size: 20, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Payment History (${_paymentHistory.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._paymentHistory.map((payment) => _buildHistoryCard(payment)),
                const SizedBox(height: 24),
              ],
              
              // Payment Options Footer
              _buildPaymentOptionsFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentInfoCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.indigo.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade100,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.indigo, Colors.indigoAccent],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _student!.fullName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _buildInfoChip(Icons.book, 'Grade ${_student!.grade} ${_student!.section ?? ''}'),
                          _buildInfoChip(Icons.qr_code, 'ID: ${_student!.studentId}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Monthly Tuition', style: TextStyle(color: Colors.grey, fontSize: 14)),
                Text(
                  'ETB ${_student!.monthlyFee.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.indigo.shade600),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.indigo.shade700)),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.family_restroom, size: 20, color: Colors.indigo),
                ),
                const SizedBox(width: 12),
                const Text('Parent/Guardian Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.email, size: 18, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(child: Text(_student!.parentEmail ?? 'Not provided', style: const TextStyle(fontSize: 14))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone, size: 18, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(child: Text(_student!.parentPhone ?? 'Not provided', style: const TextStyle(fontSize: 14))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Payment payment) {
    final daysRemaining = _getDaysRemaining(payment.dueDate);
    final showStatus = daysRemaining <= 10;
    final isOverdue = daysRemaining <= 0;
    final statusColor = isOverdue ? Colors.red : (daysRemaining <= 10 ? Colors.orange : Colors.grey);
    final statusText = isOverdue ? 'Overdue' : (daysRemaining > 0 ? '$daysRemaining days reminder' : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    payment.monthName ?? 'Monthly Fee',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                if (showStatus && statusText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: statusColor)),
                  ),
              ],
            ),
            if (payment.dueDate != null) ...[
              const SizedBox(height: 4),
              Text('Due: ${_formatDate(payment.dueDate!)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ETB ${payment.amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                Row(
                  children: [
                    _buildActionButton(
                      icon: Icons.payment,
                      label: 'Pay Now',
                      color: Colors.indigo,
                      onPressed: () => _makePayment(payment),
                      isLoading: _processingPaymentId == payment.id,
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.account_balance,
                      label: 'Bank',
                      color: Colors.blue,
                      onPressed: () => _showBankTransfer(payment),
                      isLoading: false,
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.upload_file,
                      label: 'Slip',
                      color: Colors.grey,
                      onPressed: () => _showUploadSlip(payment),
                      isLoading: false,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required bool isLoading,
  }) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(label, style: const TextStyle(fontSize: 12)),
                ],
              ),
      ),
    );
  }

  Widget _buildHistoryCard(Payment payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.receipt, size: 20, color: Colors.green.shade700),
        ),
        title: Text(payment.monthName ?? 'Payment', style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: payment.dueDate != null ? Text(_formatDate(payment.dueDate!)) : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('ETB ${payment.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (payment.status != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _getStatusColor(payment.status!).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(payment.status!, style: TextStyle(fontSize: 10, color: _getStatusColor(payment.status!))),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified': case 'paid': case 'completed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'failed': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildPaymentOptionsFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.indigo.shade50, Colors.purple.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield, size: 18, color: Colors.indigo.shade700),
              const SizedBox(width: 8),
              Text('Payment Options', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo.shade800)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildOptionIcon(Icons.phone_android, 'Telebirr'),
              _buildOptionIcon(Icons.payment, 'Chapa'),
              _buildOptionIcon(Icons.account_balance, 'Bank Transfer'),
              _buildOptionIcon(Icons.upload_file, 'Bank Slip Upload'),
              _buildOptionIcon(Icons.lock, 'Secure & Encrypted'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionIcon(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.indigo.shade600),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.indigo.shade700)),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class ReceiptScreen extends StatefulWidget {
  final String txRef;
  
  const ReceiptScreen({super.key, required this.txRef});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _paymentDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _verifyPayment();
  }

  Future<void> _verifyPayment() async {
    try {
      final result = await _apiService.verifyPayment(widget.txRef);
      if (result['success'] == true) {
        setState(() {
          _paymentDetails = result;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Payment verification failed';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to verify payment: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Receipt'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context, 
              '/dashboard', 
              (route) => false,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildReceipt(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceipt() {
    final school = _paymentDetails?['school_name'] ?? 'School Name';
    final studentName = _paymentDetails?['student_name'] ?? 'N/A';
    final studentId = _paymentDetails?['student_id'] ?? 'N/A';
    final grade = _paymentDetails?['grade'] ?? 'N/A';
    final amount = _paymentDetails?['amount'] ?? '0';
    final month = _paymentDetails?['month'] ?? 'N/A';
    final transactionRef = _paymentDetails?['transaction_ref'] ?? widget.txRef;
    final date = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.indigo.shade700, Colors.indigo.shade900],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.receipt, size: 60, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  school,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Payment Receipt',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReceiptRow('Student Name:', studentName),
                const Divider(),
                _buildReceiptRow('Student ID:', studentId),
                const Divider(),
                _buildReceiptRow('Grade:', grade),
                const Divider(),
                _buildReceiptRow('Date:', '${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute}'),
                const Divider(),
                _buildReceiptRow('Payment For:', month),
                const Divider(),
                _buildReceiptRow('Amount:', '$amount Birr', isBold: true),
                const Divider(),
                _buildReceiptRow('Method:', 'Chapa'),
                const Divider(),
                _buildReceiptRow('Transaction Ref:', transactionRef),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Thank you for your payment!',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/dashboard',
              (route) => false,
            ),
            icon: const Icon(Icons.dashboard),
            label: const Text('Back to Dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.indigo.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
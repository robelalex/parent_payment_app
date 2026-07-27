// lib/screens/payment_receipt_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

/// The mobile equivalent of the web's ReceiptPage.jsx — same fields, same
/// data source (/api/receipt/{token}/), same "this is your real invoice"
/// framing. Reached after a payment is confirmed; the back button returns
/// to the MOBILE dashboard, not a web page.
class PaymentReceiptScreen extends StatefulWidget {
  final String receiptToken;
  final int studentId;

  const PaymentReceiptScreen({super.key, required this.receiptToken, required this.studentId});

  @override
  State<PaymentReceiptScreen> createState() => _PaymentReceiptScreenState();
}

class _PaymentReceiptScreenState extends State<PaymentReceiptScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _receipt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await _apiService.getReceipt(widget.receiptToken);
      if (response['success'] == true) {
        setState(() { _receipt = response; _isLoading = false; });
      } else {
        setState(() {
          _error = "Receipt not found. It may not exist, or the payment isn't confirmed yet.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection failed. Check your internet and retry.';
        _isLoading = false;
      });
    }
  }

  void _backToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => DashboardScreen(studentId: widget.studentId)),
      (route) => false,
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    final letters = parts.map((p) => p.isNotEmpty ? p[0] : '').join();
    return letters.toUpperCase().substring(0, letters.length > 2 ? 2 : letters.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Payment Receipt'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Couldn't Load Receipt",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                              const SizedBox(height: 6),
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _backToDashboard, child: const Text('Back to Dashboard')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.green.shade100,
                                    child: Text(
                                      (_receipt?['school_name'] ?? '?').toString().substring(0, 1),
                                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_receipt?['school_name']?.toString() ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text('Invoice #${_receipt?['invoice_number'] ?? ''}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              color: Colors.green.shade50,
                              child: Center(
                                child: Text(
                                  '✅ Payment Confirmed',
                                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.green.shade100,
                                        child: Text(
                                          _initials(_receipt?['student_name']?.toString()),
                                          style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_receipt?['student_name']?.toString() ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text(
                                            '${_receipt?['student_id'] ?? ''} • Grade ${_receipt?['grade'] ?? ''}'
                                            '${(_receipt?['section']?.toString().isNotEmpty ?? false) ? ' - ${_receipt?['section']}' : ''}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  Center(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(color: Colors.black87),
                                        children: [
                                          TextSpan(
                                            text: '${_receipt?['amount'] ?? '0'} ',
                                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
                                          ),
                                          TextSpan(
                                            text: _receipt?['currency']?.toString() ?? 'ETB',
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Divider(),
                                  const SizedBox(height: 8),

                                  _receiptRow('Month', _receipt?['month']?.toString()),
                                  _receiptRow('Academic Year', _receipt?['academic_year']?.toString()),
                                  _receiptRow('Payment Method', _receipt?['payment_method']?.toString()),
                                  _receiptRow('Reference', _receipt?['transaction_reference']?.toString(), mono: true),
                                  _receiptRow('Paid By', _receipt?['paid_by']?.toString()),
                                  if (_receipt?['verified_at'] != null)
                                    _receiptRow('Confirmed On', _formatDate(_receipt?['verified_at']?.toString())),

                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade900,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: _backToDashboard,
                                      child: const Text('Back to Dashboard', style: TextStyle(color: Colors.white)),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'This is your official payment receipt.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _receiptRow(String label, String? value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          Text(
            value?.isNotEmpty == true ? value! : '—',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at ${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return iso;
    }
  }
}

// lib/screens/payment_success_handler.dart
//
// Shared "confirming your payment" screen. Reached from two places:
//   1. main.dart's onGenerateRoute, when the OS hands the app a
//      parentpay://payment/success?tx_ref=... deep link.
//   2. ChapaWebViewScreen, when the in-app WebView itself notices the
//      checkout has redirected to our success/mobile-redirect URL — this
//      is the reliable path now, since it doesn't depend on the phone's
//      browser agreeing to bounce back into the app.
//
// Matches the web's PaymentSuccess.js: check our own DB first (fast),
// then ask Chapa directly, retrying for ~34s before giving up and letting
// the person choose what to do next — instead of ever guessing "failed".
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'payment_receipt_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class PaymentSuccessHandler extends StatefulWidget {
  final String txRef;
  const PaymentSuccessHandler({super.key, required this.txRef});

  @override
  State<PaymentSuccessHandler> createState() => _PaymentSuccessHandlerState();
}

class _PaymentSuccessHandlerState extends State<PaymentSuccessHandler> {
  static const int _maxAttempts = 8;
  static const Duration _retryDelay = Duration(seconds: 4);
  static const Duration _initialDelay = Duration(seconds: 2);

  bool _isVerifying = true;
  bool _timedOut = false;
  int _attempt = 0;
  int? _studentId;

  @override
  void initState() {
    super.initState();
    print('🔍 PAYMENT SUCCESS HANDLER INITIALIZED WITH TXREF: ${widget.txRef}');
    _loadStudentIdThenVerify();
  }

  Future<void> _loadStudentIdThenVerify() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_tx_ref', widget.txRef);
    final savedStudent = prefs.getString('selected_student');
    if (savedStudent != null) {
      try {
        final student = Map<String, dynamic>.from(jsonDecode(savedStudent) as Map);
        _studentId = student['id'] as int?;
      } catch (_) {}
    }
    await Future.delayed(_initialDelay);
    _pollForConfirmation();
  }

  Future<void> _pollForConfirmation() async {
    setState(() { _isVerifying = true; _timedOut = false; });
    final apiService = ApiService();

    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      if (!mounted) return;
      setState(() => _attempt = attempt);
      print('🔍 Verification attempt $attempt/$_maxAttempts for ${widget.txRef}');

      try {
        // Fast path first — our own DB, works even if Chapa's own API is slow.
        final statusResult = await apiService.getPaymentStatus(widget.txRef);
        if (statusResult['success'] == true && statusResult['verified'] == true) {
          _goToReceipt(statusResult['receipt_token']?.toString());
          return;
        }

        // Fallback — ask Chapa directly.
        final chapaResult = await apiService.verifyPayment(widget.txRef);
        if (chapaResult['success'] == true && chapaResult['verified'] == true) {
          _goToReceipt(chapaResult['receipt_token']?.toString());
          return;
        }
      } catch (e) {
        print('❌ Verification attempt $attempt exception: $e');
      }

      if (attempt < _maxAttempts) await Future.delayed(_retryDelay);
    }

    // Genuinely still not confirmed after ~34s — stop guessing and let the
    // person choose, rather than silently declaring failure.
    if (mounted) setState(() { _isVerifying = false; _timedOut = true; });
  }

  void _goToReceipt(String? receiptToken) {
    if (!mounted) return;
    if (receiptToken == null || receiptToken.isEmpty) {
      // Verified but no receipt token for some reason — still don't want
      // to leave the person hanging on a spinner forever.
      _navigateToDashboard();
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentReceiptScreen(
          receiptToken: receiptToken,
          studentId: _studentId ?? 0,
        ),
      ),
    );
  }

  void _navigateToDashboard() {
    if (_studentId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen(studentId: _studentId!)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerifying) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Confirming your payment...', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                'This can take a moment ($_attempt/$_maxAttempts)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    if (_timedOut) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_top, size: 56, color: Colors.orange.shade600),
                const SizedBox(height: 16),
                const Text('Still Confirming', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  "Your payment is taking longer than usual to confirm. This doesn't mean it failed — "
                  "it may just need a bit more time. You can check again, or come back to it later from your dashboard.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                    onPressed: _pollForConfirmation,
                    child: const Text('Check Again', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: _navigateToDashboard, child: const Text('Back to Dashboard')),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// lib/screens/otp_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'enter_student_id_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final int userId;
  
  const OtpScreen({super.key, required this.email, required this.userId});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  String? _error;
  int _resendTimer = 0;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          if (_resendTimer > 0) _resendTimer--;
        });
      }
      return _resendTimer > 0 && mounted;
    });
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      setState(() => _error = 'Enter 6-digit code');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final response = await _apiService.verifyOtp(widget.userId, _otpController.text);
      if (response['success'] == true) {
        await _apiService.saveParentSession(widget.email, widget.userId);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EnterStudentIdScreen()),
          );
        }
      } else {
        setState(() => _error = response['error'] ?? 'Invalid OTP');
      }
    } catch (e) {
      setState(() => _error = 'Verification failed. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendTimer > 0) return;
    
    setState(() { _isLoading = true; _error = null; });

    try {
      final response = await _apiService.sendOtp(widget.email);
      if (response['success'] == true) {
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent successfully!')),
        );
      } else {
        setState(() => _error = response['error'] ?? 'Failed to resend OTP');
      }
    } catch (e) {
      setState(() => _error = 'Failed to resend OTP');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green.shade50, Colors.teal.shade50],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield, size: 80, color: Colors.green.shade700),
                const SizedBox(height: 20),
                const Text(
                  'Verify Your Identity',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter 6-digit code sent to ${widget.email}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _otpController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: '000000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    counterText: '',
                  ),
                  style: const TextStyle(fontSize: 32, letterSpacing: 8),
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade700))),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Verify & Continue', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: (_resendTimer > 0 || _isLoading) ? null : _resendOtp,
                  child: Text(
                    _resendTimer > 0
                        ? 'Resend code in ${_resendTimer}s'
                        : 'Resend code',
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('← Back to email'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
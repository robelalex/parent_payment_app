// lib/screens/teacher/teacher_otp_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import 'teacher_home_screen.dart';

class TeacherOtpScreen extends StatefulWidget {
  final String email;
  final int userId;

  const TeacherOtpScreen({super.key, required this.email, required this.userId});

  @override
  State<TeacherOtpScreen> createState() => _TeacherOtpScreenState();
}

class _TeacherOtpScreenState extends State<TeacherOtpScreen> {
  final _otpController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  String? _error;

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final response = await _apiService.verifyTeacherOtp(widget.userId, _otpController.text);
      if (response['success'] == true) {
        final user = response['user'] as Map<String, dynamic>? ?? {};
        await _apiService.saveTeacherSession(user, response['access'] as String);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const TeacherHomeScreen()),
          );
        }
      } else {
        setState(() => _error = response['error'] ?? 'Invalid code');
      }
    } catch (e) {
      setState(() => _error = 'Verification failed. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigo.shade50, Colors.blue.shade50],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield, size: 72, color: Colors.indigo.shade700),
                const SizedBox(height: 20),
                const Text('Verify Your Identity', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  'Enter the 6-digit code sent to ${widget.email}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: _otpController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: '000000',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    counterText: '',
                  ),
                  style: const TextStyle(fontSize: 32, letterSpacing: 8),
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
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
                      backgroundColor: Colors.indigo.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Verify & Continue', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('← Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// lib/screens/teacher/teacher_login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../widgets/language_toggle.dart';
import 'teacher_otp_screen.dart';

class TeacherLoginScreen extends StatefulWidget {
  const TeacherLoginScreen({super.key});

  @override
  State<TeacherLoginScreen> createState() => _TeacherLoginScreenState();
}

class _TeacherLoginScreenState extends State<TeacherLoginScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;
  // ✅ NEW (requested): email or phone as the login identifier, same
  // toggle as the parent login screen. Password is always required
  // either way.
  String _method = 'email';

  Future<void> _login() async {
    if (_method == 'email' && !_emailController.text.contains('@')) {
      setState(() => _error = 'Enter your email');
      return;
    }
    if (_method == 'phone' && _phoneController.text.trim().isEmpty) {
      setState(() => _error = 'Enter your phone number');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your password');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final response = _method == 'phone'
          ? await _apiService.teacherLogin(phone: _phoneController.text.trim(), password: _passwordController.text)
          : await _apiService.teacherLogin(email: _emailController.text.trim(), password: _passwordController.text);
      if (response['success'] == true && response['requires_otp'] == true) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeacherOtpScreen(
                identifier: _method == 'phone' ? _phoneController.text.trim() : _emailController.text.trim(),
                method: _method,
                userId: response['user_id'],
              ),
            ),
          );
        }
      } else {
        setState(() => _error = response['error'] ?? 'Login failed');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          Padding(padding: EdgeInsets.only(right: 8), child: LanguageToggle()),
        ],
      ),
      extendBodyBehindAppBar: true,
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
                Icon(Icons.school, size: 72, color: Colors.indigo.shade700),
                const SizedBox(height: 16),
                Text(
                  lang.t('teacher_login_title'),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 28),
                // ✅ NEW: Email / Phone toggle
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _method = 'email'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _method == 'email' ? Colors.indigo.shade700 : Colors.white,
                          foregroundColor: _method == 'email' ? Colors.white : Colors.grey.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Email'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _method = 'phone'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _method == 'phone' ? Colors.indigo.shade700 : Colors.white,
                          foregroundColor: _method == 'phone' ? Colors.white : Colors.grey.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Phone'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_method == 'phone')
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone),
                      labelText: 'Phone Number',
                      hintText: '09XXXXXXXX',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.phone,
                  )
                else
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email),
                      labelText: lang.t('teacher_email_label'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    labelText: lang.t('teacher_password_label'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
                        Expanded(child: SelectableText(_error!, style: TextStyle(color: Colors.red.shade700))),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(lang.t('teacher_login_button'), style: const TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

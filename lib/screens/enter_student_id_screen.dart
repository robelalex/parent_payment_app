// lib/screens/enter_student_id_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

class EnterStudentIdScreen extends StatefulWidget {
  const EnterStudentIdScreen({super.key});

  @override
  State<EnterStudentIdScreen> createState() => _EnterStudentIdScreenState();
}

class _EnterStudentIdScreenState extends State<EnterStudentIdScreen> {
  final _studentIdController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  String? _error;
  String? _parentEmail;

  @override
  void initState() {
    super.initState();
    _loadParentSession();
  }

  Future<void> _loadParentSession() async {
    final session = await _apiService.getParentSession();
    if (session['isLoggedIn'] == true) {
      setState(() => _parentEmail = session['email']);
    }
  }

Future<void> _verifyStudentId() async {
  final studentId = _studentIdController.text.trim().toUpperCase();
  if (studentId.isEmpty) {
    setState(() => _error = 'Please enter student ID');
    return;
  }

  setState(() { _isLoading = true; _error = null; });

  try {
    final result = await _apiService.getStudentById(studentId);
    
    print('🔍 Student API result: $result');
    
    // Check if there's an error
    if (result.containsKey('error')) {
      setState(() => _error = result['error']);
      setState(() => _isLoading = false);
      return;
    }
    
    // Check if we got a valid student object (has id and parent_email)
    if (result['id'] != null && result['parent_email'] != null) {
      final session = await _apiService.getParentSession();
      
      // Verify the student belongs to this parent
      if (result['parent_email'] != session['email']) {
        setState(() => _error = 'This student ID is not linked to your email');
        setState(() => _isLoading = false);
        return;
      }
      
      // ✅ NEW: Save the school ID
      if (result['school'] != null) {
        await _apiService.saveSchoolId(result['school']);
        print('✅ Saved school ID: ${result['school']}');
      } else {
        print('⚠️ No school ID found in student data');
      }
      
      // Save the student
      await _apiService.saveSelectedStudent(result);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(studentId: result['id']),
          ),
        );
      }
    } else {
      setState(() => _error = 'Student not found. Please check the ID.');
    }
  } catch (e) {
    print('❌ Error in _verifyStudentId: $e');
    setState(() => _error = 'Failed to verify student. Please try again.');
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
                Icon(Icons.school, size: 80, color: Colors.green.shade700),
                const SizedBox(height: 20),
                const Text(
                  'Access Student Portal',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                if (_parentEmail != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Verified: $_parentEmail',
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Enter your child\'s student ID',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _studentIdController,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '',
                    prefixIcon: const Icon(Icons.key),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                        Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade700))),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyStudentId,
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
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Access Dashboard', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward),
                            ],
                          ),
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
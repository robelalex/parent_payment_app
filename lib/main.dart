import 'package:flutter/material.dart';
import 'dart:convert';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parent Payment Portal',
      theme: ThemeData(primarySwatch: Colors.green),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreenWrapper(),
      },
      onGenerateRoute: (settings) {
        print('🔍 DEEP LINK RECEIVED: ${settings.name}');
        
        // Handle deep link: parentpay://payment/success?tx_ref=xxx
        if (settings.name != null && settings.name!.contains('payment/success')) {
          final uri = Uri.parse(settings.name!);
          final txRef = uri.queryParameters['tx_ref'];
          print('🔍 TX_REF EXTRACTED: $txRef');
          if (txRef != null && txRef.isNotEmpty) {
            return MaterialPageRoute(
              builder: (context) => PaymentSuccessHandler(txRef: txRef),
            );
          }
        }
        
        // Also handle regular navigation
        if (settings.name == '/dashboard') {
          return MaterialPageRoute(
            builder: (context) => const DashboardScreenWrapper(),
          );
        }
        
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// Handler for payment success deep link
class PaymentSuccessHandler extends StatefulWidget {
  final String txRef;
  const PaymentSuccessHandler({super.key, required this.txRef});

  @override
  State<PaymentSuccessHandler> createState() => _PaymentSuccessHandlerState();
}

class _PaymentSuccessHandlerState extends State<PaymentSuccessHandler> {
  bool _isVerifying = true;
  Map<String, dynamic>? _paymentResult;

  @override
  void initState() {
    super.initState();
    print('🔍 PAYMENT SUCCESS HANDLER INITIALIZED WITH TXREF: ${widget.txRef}');
    _verifyAndStore();
  }

  Future<void> _verifyAndStore() async {
    print('🔍 STARTING VERIFICATION FOR TXREF: ${widget.txRef}');
    
    final prefs = await SharedPreferences.getInstance();
    
    // Store the tx_ref
    await prefs.setString('pending_tx_ref', widget.txRef);
    
    // Verify the payment
    try {
      final apiService = ApiService();
      final result = await apiService.verifyPayment(widget.txRef);
      
      print('🔍 VERIFICATION RESULT: $result');
      
      setState(() {
        _isVerifying = false;
        _paymentResult = result;
      });
      
      if (result['success'] == true && result['verified'] == true) {
        print('✅ PAYMENT VERIFIED! Showing success dialog');
        if (mounted) {
          _showSuccessDialog(result);
        }
      } else {
        print('⚠️ PAYMENT NOT VERIFIED');
        if (mounted) {
          _showPendingDialog();
        }
      }
    } catch (e) {
      print('❌ VERIFICATION EXCEPTION: $e');
      setState(() => _isVerifying = false);
      if (mounted) {
        _showPendingDialog();
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic> paymentData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Payment Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ETB ${paymentData['amount'] ?? '0'}'),
            const SizedBox(height: 4),
            Text('Student: ${paymentData['student_name'] ?? 'N/A'}'),
            const SizedBox(height: 4),
            Text('Month: ${paymentData['month'] ?? 'N/A'}'),
            const SizedBox(height: 4),
            Text('Transaction: ${widget.txRef}'),
            const SizedBox(height: 16),
            const Text('Receipt has been sent to your email.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToDashboard();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPendingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Processing'),
        content: const Text(
          'Your payment is being processed. It will appear in your payment history shortly.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToDashboard();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStudent = prefs.getString('selected_student');
    if (savedStudent != null) {
      try {
        final Map<String, dynamic> student = Map<String, dynamic>.from(
          jsonDecode(savedStudent) as Map
        );
        final studentId = student['id'];
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(studentId: studentId),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _isVerifying ? 'Verifying your payment...' : 'Please wait...',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardScreenWrapper extends StatefulWidget {
  const DashboardScreenWrapper({super.key});

  @override
  State<DashboardScreenWrapper> createState() => _DashboardScreenWrapperState();
}

class _DashboardScreenWrapperState extends State<DashboardScreenWrapper> {
  int? _studentId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentId();
  }

  Future<void> _loadStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStudent = prefs.getString('selected_student');
    if (savedStudent != null) {
      try {
        final Map<String, dynamic> student = Map<String, dynamic>.from(
          jsonDecode(savedStudent) as Map
        );
        setState(() {
          _studentId = student['id'];
          _loading = false;
        });
      } catch (e) {
        setState(() => _loading = false);
      }
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_studentId != null) {
      return DashboardScreen(studentId: _studentId!);
    }
    return const LoginScreen();
  }
}
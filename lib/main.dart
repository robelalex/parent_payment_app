import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        // Handle deep link: parentpay://payment/success?tx_ref=xxx
        if (settings.name != null && settings.name!.startsWith('/payment/success')) {
          final uri = Uri.parse(settings.name!);
          final txRef = uri.queryParameters['tx_ref'];
          if (txRef != null) {
            // Store tx_ref and navigate to dashboard
            return MaterialPageRoute(
              builder: (context) => DashboardScreenWithTxRef(txRef: txRef),
            );
          }
        }
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// Wrapper to get studentId from SharedPreferences
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

// Screen to handle deep link with tx_ref
class DashboardScreenWithTxRef extends StatelessWidget {
  final String txRef;

  const DashboardScreenWithTxRef({super.key, required this.txRef});

  @override
  Widget build(BuildContext context) {
    // Store tx_ref and navigate to dashboard
    return FutureBuilder(
      future: _storeTxRefAndNavigate(context),
      builder: (context, snapshot) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Future<void> _storeTxRefAndNavigate(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_tx_ref', txRef);
    
    // Get student ID from storage
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
}

// Add this import at the top
import 'dart:convert';
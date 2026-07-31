import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/payment_success_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/language_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => LanguageService(),
      child: const MyApp(),
    ),
  );
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
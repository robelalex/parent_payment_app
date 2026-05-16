import 'package:flutter/material.dart';
import 'services/api_client.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parent Payment Portal',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
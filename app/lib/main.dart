import 'package:flutter/material.dart';

import 'screens/login_screen.dart';

void main() {
  runApp(const GirokontoApp());
}

class GirokontoApp extends StatelessWidget {
  const GirokontoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PHD Kontor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1F6B52),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

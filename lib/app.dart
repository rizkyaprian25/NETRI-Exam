// Root App Shell NETRI Exam (SOP SoftwareEngineer.md Seksi 3.3 & Seksi 7)
// Mengonfigurasi tema adaptif, Global Error Boundary, dan Root Routing

import 'package:flutter/material.dart';
import 'core/errors/error_boundary.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';

class NetriExamApp extends StatelessWidget {
  const NetriExamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GlobalErrorBoundary(
      child: MaterialApp(
        title: 'Exam NETRI',
        debugShowCheckedModeBanner: false,
        theme: NetriTheme.lightTheme,
        darkTheme: NetriTheme.darkTheme,
        themeMode: ThemeMode.system, // Menghormati preferensi tema OS pengguna
        home: const LoginScreen(),
      ),
    );
  }
}

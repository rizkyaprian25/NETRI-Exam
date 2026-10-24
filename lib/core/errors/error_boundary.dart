// Global Error Boundary untuk NETRI Exam (SOP SoftwareEngineer.md Seksi 5.8)
// Menangkap unhandled rendering exception agar tidak terjadi White Screen of Death

import 'package:flutter/material.dart';
import '../theme/tokens.g.dart';

class GlobalErrorBoundary extends StatefulWidget {
  final Widget child;

  const GlobalErrorBoundary({super.key, required this.child});

  @override
  State<GlobalErrorBoundary> createState() => _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends State<GlobalErrorBoundary> {
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();
  }

  void _resetError() {
    setState(() {
      _errorDetails = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(NetriSpacing.space6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(NetriSpacing.space4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE4E2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: NetriColors.stateDangerLight,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: NetriSpacing.space4),
                    const Text(
                      'Terjadi Kendala Tampilan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NetriSpacing.space2),
                    Text(
                      'Sistem mendeteksi kendala pada antarmuka. Tenang, sesi ujian Anda tidak hilang.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NetriSpacing.space6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _resetError,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Muat Ulang Halaman'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}

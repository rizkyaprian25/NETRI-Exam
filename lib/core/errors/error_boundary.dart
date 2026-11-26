// Global Error Boundary untuk NETRI Exam (SOP SoftwareEngineer.md Seksi 5.8)
// Menangkap unhandled rendering exception agar tidak terjadi White/Red Screen of Death

import 'package:flutter/material.dart';
import '../theme/tokens.g.dart';

class GlobalErrorBoundary extends StatefulWidget {
  final Widget child;

  const GlobalErrorBoundary({super.key, required this.child});

  static GlobalErrorBoundaryState? _activeState;

  /// Meneruskan error render global ke state boundary aktif di aplikasi
  static void reportError(FlutterErrorDetails details) {
    _activeState?.captureError(details);
  }

  /// Widget pemulihan fallback saat Flutter ErrorWidget.builder terpanggil
  static Widget buildFallbackErrorWidget(FlutterErrorDetails details) {
    return Material(
      color: NetriColors.bgLight,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(NetriSpacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: NetriColors.stateDangerLight,
                size: 40,
              ),
              const SizedBox(height: NetriSpacing.space2),
              const Text(
                'Terjadi Kendala Komponen Tampilan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: NetriSpacing.space1),
              Text(
                'Sesi ujian Anda tetap aman.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  State<GlobalErrorBoundary> createState() => GlobalErrorBoundaryState();
}

class GlobalErrorBoundaryState extends State<GlobalErrorBoundary> {
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();
    GlobalErrorBoundary._activeState = this;
  }

  @override
  void dispose() {
    if (GlobalErrorBoundary._activeState == this) {
      GlobalErrorBoundary._activeState = null;
    }
    super.dispose();
  }

  /// Menangkap detail error untuk menampilkan layar pemulihan aman
  void captureError(FlutterErrorDetails details) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _errorDetails = details;
      });
    });
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

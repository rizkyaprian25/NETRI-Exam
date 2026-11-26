// Entrypoint Aplikasi NETRI Exam
// Menginisialisasi handler error global tingkat platform dan ErrorWidget.builder sebelum bootstrap widget

import 'dart:ui';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/errors/error_boundary.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Tangkap widget build exception pada mode produksi agar tidak memunculkan layar merah/abu-abu kosong
  ErrorWidget.builder = GlobalErrorBoundary.buildFallbackErrorWidget;

  // Handler kesalahan framework Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[NetriFrameworkError] ${details.exceptionAsString()}');
    GlobalErrorBoundary.reportError(details);
  };

  // Handler kesalahan asynchronous platform
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[NetriAsyncError] $error');
    return true; // Mencegah crash fatal unhandled exception
  };

  runApp(const NetriExamApp());
}

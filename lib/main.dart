// Entrypoint Aplikasi NETRI Exam
// Menginisialisasi handler error global tingkat platform sebelum bootstrap widget

import 'dart:ui';
import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Handler kesalahan framework Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[NetriFrameworkError] ${details.exceptionAsString()}');
  };

  // Handler kesalahan asynchronous platform
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[NetriAsyncError] $error');
    return true; // Mencegah crash fatal unhandled exception
  };

  runApp(const NetriExamApp());
}

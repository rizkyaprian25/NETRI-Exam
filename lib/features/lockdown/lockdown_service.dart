// Service Penguncian Perangkat (Lockdown Engine) & Platform Channel
// Mengontrol FLAG_SECURE, Lock Task Mode, deteksi kehilangan fokus, dan masa tenggang 10 detik

import 'dart:async';
import 'package:flutter/services.dart';
import '../../contracts/models.dart';
import '../../core/storage/offline_queue.dart';

class LockdownService {
  static final LockdownService _instance = LockdownService._internal();
  factory LockdownService() => _instance;
  LockdownService._internal();

  // Platform channel untuk kontrol native Android & iOS
  static const MethodChannel _channel = MethodChannel('com.netri.exam/lockdown');

  // Status penguncian aktif
  bool _isLockdownActive = false;
  String? _currentSessionId;
  DateTime? _appPausedTime;
  int _strikeCount = 0;

  // Callback ke antarmuka ujian (untuk menampilkan dialog strike / lock)
  void Function(int strikeCount, String reason)? onStrikeTriggered;
  void Function()? onLockRequired;

  /// Memulai mode penguncian ujian
  Future<void> enableLockdown(String sessionId) async {
    _currentSessionId = sessionId;
    _isLockdownActive = true;
    _strikeCount = 0;

    try {
      // Mengaktifkan proteksi screenshot & lock task di native Android/iOS
      await _channel.invokeMethod('enableSecureWindow');
    } on MissingPluginException {
      // Fallback anggun jika dijalankan di simulator/platform tanpa native plugin
    } catch (e) {
      // Fail-open
    }
  }

  /// Menonaktifkan mode penguncian setelah ujian selesai
  Future<void> disableLockdown() async {
    _isLockdownActive = false;
    _currentSessionId = null;

    try {
      await _channel.invokeMethod('disableSecureWindow');
    } catch (_) {}
  }

  /// Menangani siklus hidup aplikasi saat berpindah ke latar belakang (Background/Paused)
  void handleAppPaused() {
    if (!_isLockdownActive) return;
    _appPausedTime = DateTime.now();
  }

  /// Menangani saat aplikasi kembali aktif (Resumed)
  Future<void> handleAppResumed() async {
    if (!_isLockdownActive || _appPausedTime == null || _currentSessionId == null) return;

    final resumeTime = DateTime.now();
    final durationSeconds = resumeTime.difference(_appPausedTime!).inSeconds;
    _appPausedTime = null;

    // Evaluasi Masa Tenggang 10 Detik (SOP PRD Seksi 7.7)
    // Durasi < 10 detik dianggap interupsi sah (misal: telepon masuk darurat / panel notifikasi)
    final bool isExcused = durationSeconds <= 10;
    final severity = isExcused ? ViolationSeverity.info : ViolationSeverity.warning;

    if (!isExcused) {
      _strikeCount++;
    }

    // Catat kejadian pelanggaran ke antrean offline
    final event = ViolationEventModel(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: _currentSessionId!,
      type: ViolationType.appExit,
      severity: severity,
      clientTimestamp: resumeTime,
      durationSeconds: durationSeconds,
      isExcused: isExcused,
      notes: isExcused
          ? 'Interupsi sah $durationSeconds detik (di dalam masa tenggang 10s)'
          : 'Aplikasi ditinggalkan selama $durationSeconds detik (Strike $_strikeCount)',
    );

    await OfflineViolationQueue().enqueue(event);

    if (!isExcused) {
      if (_strikeCount >= 2) {
        onLockRequired?.call();
      } else {
        onStrikeTriggered?.call(_strikeCount, 'Aplikasi ujian ditinggalkan selama $durationSeconds detik.');
      }
    }
  }

  /// Mencatat upaya screenshot terdeteksi
  Future<void> recordScreenshotAttempt() async {
    if (!_isLockdownActive || _currentSessionId == null) return;

    _strikeCount++;
    final event = ViolationEventModel(
      id: 'evt_ss_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: _currentSessionId!,
      type: ViolationType.screenshotAttempt,
      severity: ViolationSeverity.danger,
      clientTimestamp: DateTime.now(),
      isExcused: false,
      notes: 'Upaya pengambilan tangkapan layar terdeteksi',
    );

    await OfflineViolationQueue().enqueue(event);
    onStrikeTriggered?.call(_strikeCount, 'Tangkapan layar terdeteksi dan diblokir.');
  }

  int get currentStrikeCount => _strikeCount;
  bool get isLocked => _strikeCount >= 2;

  /// Membuka kunci setelah aksi pengawas
  void unlockByProctor() {
    _strikeCount = 0;
  }
}

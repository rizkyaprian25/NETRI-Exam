// Service Penguncian Perangkat (Exambro Lockdown Engine)
// Mendukung Android (FLAG_SECURE, Immersive Fullscreen, Lock Task)
// dan iOS (Guided Access, Screenshot/Screen Recording Detection, Resign Active Shield)

import 'dart:async';
import 'package:flutter/services.dart';
import '../../contracts/models.dart';
import '../../core/storage/offline_queue.dart';

class LockdownService {
  static final LockdownService _instance = LockdownService._internal();
  factory LockdownService() => _instance;
  LockdownService._internal() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

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

  Future<void> _handleNativeCall(MethodCall call) async {
    if (!_isLockdownActive) return;

    switch (call.method) {
      case 'onUserLeaveHint':
        // Terdeteksi dari Android/iOS saat pengguna mencoba menekan Home, Recent Apps, atau gesture keluar
        await handleAppResignedActive();
        break;
      case 'onScreenshotDetected':
        // Terdeteksi tangkapan layar atau rekam layar dari iOS/Android
        await recordScreenshotAttempt();
        break;
      default:
        break;
    }
  }

  /// Membunyikan suara alarm peringatan keras (looping)
  Future<void> startAlarmSound() async {
    try {
      await _channel.invokeMethod('startAlarmSound');
    } catch (_) {}
  }

  /// Menghentikan suara alarm peringatan
  Future<void> stopAlarmSound() async {
    try {
      await _channel.invokeMethod('stopAlarmSound');
    } catch (_) {}
  }

  /// Memulai mode penguncian ujian ala Exambro
  Future<void> enableLockdown(String sessionId) async {
    _currentSessionId = sessionId;
    _isLockdownActive = true;
    _strikeCount = 0;

    try {
      // Mengaktifkan proteksi screenshot, kecerahan 100%, volume 100%, & immersive lock di Android/iOS
      await _channel.invokeMethod('enableSecureWindow');
    } on MissingPluginException {
      // Fallback jika di desktop simulator
    } catch (_) {}
  }

  /// Menonaktifkan mode penguncian setelah ujian selesai
  Future<void> disableLockdown() async {
    _isLockdownActive = false;
    _currentSessionId = null;
    _strikeCount = 0;
    _appPausedTime = null;
    onLockRequired = null;
    onStrikeTriggered = null;

    try {
      await _channel.invokeMethod('stopAlarmSound');
      await _channel.invokeMethod('disableSecureWindow');
    } catch (_) {}
  }

  /// Terdeteksi saat aplikasi kehilangan fokus atau berpindah ke latar belakang
  Future<void> handleAppResignedActive() async {
    if (!_isLockdownActive || _currentSessionId == null) return;

    _strikeCount++;
    final event = ViolationEventModel(
      id: 'evt_leave_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: _currentSessionId!,
      type: ViolationType.appExit,
      severity: ViolationSeverity.danger,
      clientTimestamp: DateTime.now(),
      isExcused: false,
      notes: 'Terdeteksi berpindah aplikasi atau menekan tombol home (Strike $_strikeCount)',
    );

    await OfflineViolationQueue().enqueue(event);

    // Khas Exambro: Langsung bunyikan alarm suara keras, kunci sesi, dan minta pengawas memasukkan PIN
    await startAlarmSound();
    onLockRequired?.call();
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

    // Evaluasi durasi keluar
    final bool isExcused = durationSeconds <= 3; // Toleransi kilat sistem 3 detik
    final severity = isExcused ? ViolationSeverity.info : ViolationSeverity.warning;

    if (!isExcused) {
      _strikeCount++;
    }

    final event = ViolationEventModel(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: _currentSessionId!,
      type: ViolationType.appExit,
      severity: severity,
      clientTimestamp: resumeTime,
      durationSeconds: durationSeconds,
      isExcused: isExcused,
      notes: isExcused
          ? 'Interupsi kilat $durationSeconds detik'
          : 'Aplikasi ditinggalkan selama $durationSeconds detik (Strike $_strikeCount)',
    );

    await OfflineViolationQueue().enqueue(event);

    if (!isExcused) {
      await startAlarmSound();
      onLockRequired?.call();
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
      notes: 'Upaya pengambilan tangkapan layar terdeteksi dan diblokir',
    );

    await OfflineViolationQueue().enqueue(event);
    await startAlarmSound();
    onLockRequired?.call();
  }

  int get currentStrikeCount => _strikeCount;
  bool get isLocked => _strikeCount >= 1;

  /// Membuka kunci setelah aksi pengawas memasukkan PIN
  Future<void> unlockByProctor() async {
    _strikeCount = 0;
    await stopAlarmSound();
  }
}

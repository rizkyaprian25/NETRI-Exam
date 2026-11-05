// Service Penguncian Perangkat (Exam NETRI Lockdown Engine)
// Mendukung Android (FLAG_SECURE, Immersive Fullscreen, Lock Task)
// dan iOS (Guided Access, Screenshot/Screen Recording Detection, Resign Active Shield)

import 'dart:async';
import 'package:flutter/foundation.dart';
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
  DateTime? _lockdownStartTime;
  int _strikeCount = 0;

  // Callback ke antarmuka ujian (untuk menampilkan dialog strike / lock / tirai pelindung)
  void Function(int strikeCount, String reason)? onStrikeTriggered;
  void Function()? onLockRequired;
  void Function(bool isPinned, bool isObscured, bool isThreeButton)? onLockStateChanged;
  void Function(bool isScreenClear)? onPreExamScreenClearChanged;

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onLockStateChanged') {
      // Pembaruan status Sematkan Layar (Lock Task), kebersihan layar pra-ujian, dan Mode 3 Tombol
      final args = call.arguments;
      if (args is Map) {
        if (args.containsKey('isScreenClear')) {
          onPreExamScreenClearChanged?.call(args['isScreenClear'] == true);
        }
        if (_isLockdownActive) {
          final isPinned = args['isPinned'] == true;
          final isObscured = args['isObscured'] == true;
          final isThreeButton = args['isThreeButton'] == true;
          onLockStateChanged?.call(isPinned, isObscured, isThreeButton);
        }
      }
      return;
    }

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
      case 'onObscuredDetected':
        // Terdeteksi jendela mengambang (floating app) atau overlay di atas layar ujian
        final args = call.arguments;
        final reason = args is Map ? args['reason']?.toString() : null;
        await recordOverlayDetected(reason: reason);
        break;
      default:
        break;
    }
  }

  /// Memeriksa apakah layar bersih dari floating apps / split-screen sebelum ujian dimulai (Fail-Closed di Android)
  Future<bool> checkScreenClear() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkScreenClear');
      return result ?? false;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Melepas sematan layar jika terdeteksi aplikasi mengambang sesaat setelah penyematan
  Future<void> unpinScreen() async {
    try {
      await _channel.invokeMethod('unpinScreen');
    } catch (_) {}
  }

  /// Memeriksa apakah aplikasi sudah terkunci dalam mode Lock Task (Screen Pinning / Kiosk)
  Future<bool> isLockTaskActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isLockTaskActive');
      return result ?? true;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Meminta sistem Android mengaktifkan Lock Task (menutup otomatis floating apps yang aktif)
  Future<bool> requestLockTask() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestLockTask');
      return result ?? true;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Membuka pengaturan Keamanan Android agar pengguna dapat menyalakan fitur Sematkan Layar
  Future<void> openSecuritySettings() async {
    try {
      await _channel.invokeMethod('openSecuritySettings');
    } catch (_) {}
  }

  /// Memeriksa apakah HP siswa menggunakan Mode Tombol (3-Button Navigation) dan BUKAN Mode Gerakan (Gesture)
  Future<bool> isThreeButtonNavigation() async {
    try {
      final result = await _channel.invokeMethod<bool>('isThreeButtonNavigation');
      return result ?? true;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Membuka pengaturan Sistem / Layar HP agar siswa dapat mengganti Mode Gerakan ke Mode 3 Tombol
  Future<void> openNavigationSettings() async {
    try {
      await _channel.invokeMethod('openNavigationSettings');
    } catch (_) {}
  }

  /// Memeriksa apakah izin "Tampilkan di atas aplikasi lain" (Overlay) sudah diaktifkan
  Future<bool> hasOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? true;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Meminta izin "Tampilkan di atas aplikasi lain" agar aplikasi bisa menarik paksa layar jika keluar via gesture
  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  /// Membunyikan suara sirine darurat tajam selama 15 detik (bawaan: 15000 ms)
  Future<void> startAlarmSound({int durationMs = 15000}) async {
    try {
      await _channel.invokeMethod('startAlarmSound', {'durationMs': durationMs});
    } catch (_) {}
  }

  /// Menghentikan suara sirine peringatan
  Future<void> stopAlarmSound() async {
    try {
      await _channel.invokeMethod('stopAlarmSound');
    } catch (_) {}
  }

  /// Memulai mode penguncian ujian ala Exam NETRI
  Future<void> enableLockdown(String sessionId) async {
    _currentSessionId = sessionId;
    _isLockdownActive = true;
    _lockdownStartTime = DateTime.now();
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
    _lockdownStartTime = null;
    _strikeCount = 0;
    _appPausedTime = null;
    onLockRequired = null;
    onStrikeTriggered = null;
    onLockStateChanged = null;

    try {
      await _channel.invokeMethod('stopAlarmSound');
      await _channel.invokeMethod('disableSecureWindow');
    } catch (_) {}
  }

  /// Mencatat upaya membuka aplikasi mengambang (floating app) atau overlay di atas layar ujian
  Future<void> recordOverlayDetected({String? reason}) async {
    if (!_isLockdownActive || _currentSessionId == null) return;

    _strikeCount++;
    final event = ViolationEventModel(
      id: 'evt_ovl_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: _currentSessionId!,
      type: ViolationType.overlayDetected,
      severity: ViolationSeverity.danger,
      clientTimestamp: DateTime.now(),
      isExcused: false,
      notes: reason ?? 'Terdeteksi aplikasi mengambang (floating app) atau overlay di atas layar ujian',
    );

    await OfflineViolationQueue().enqueue(event);
    await startAlarmSound();
    onLockRequired?.call();
  }

  /// Terdeteksi saat aplikasi kehilangan fokus atau berpindah ke latar belakang
  Future<void> handleAppResignedActive() async {
    if (!_isLockdownActive || _currentSessionId == null) return;

    // Abaikan jika masih dalam masa tenggang awal (5 detik pertama) inisialisasi ujian
    if (_lockdownStartTime != null &&
        DateTime.now().difference(_lockdownStartTime!).inSeconds < 5) {
      return;
    }

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

    // Khas Exam NETRI: Langsung bunyikan alarm suara keras, kunci sesi, dan minta pengawas memasukkan PIN
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

    // Abaikan jika masih dalam masa tenggang awal (5 detik pertama) inisialisasi ujian
    if (_lockdownStartTime != null &&
        DateTime.now().difference(_lockdownStartTime!).inSeconds < 5) {
      _appPausedTime = null;
      return;
    }

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

  /// Khusus untuk pengujian otomatis: Memajukan waktu startup agar melewati masa tenggang
  @visibleForTesting
  void expireStartupGracePeriodForTesting() {
    if (_lockdownStartTime != null) {
      _lockdownStartTime = _lockdownStartTime!.subtract(const Duration(seconds: 10));
    }
  }
}

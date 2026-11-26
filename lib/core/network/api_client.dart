// API Client & Jaringan untuk NETRI Exam (SOP SoftwareEngineer.md Seksi 4.1 & 5.10)
// Mendukung fallback mock lokal agar UI dapat berjalan mandiri (Contract-Driven)

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../contracts/models.dart';
import '../storage/offline_queue.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal() {
    // Menghubungkan callback pengiriman antrean offline ke method postViolation
    OfflineViolationQueue().sendEventCallback = postViolation;
  }

  /// Daftar domain standar yang diizinkan untuk Google Forms, infrastruktur Google, dan pemendek tautan
  static const List<String> defaultAllowedExamDomains = [
    'docs.google.com',
    'forms.google.com',
    'accounts.google.com',
    'google.com',
    'googleapis.com',
    'gstatic.com',
    'googleusercontent.com',
    'ggpht.com',
    'pki.goog',
    'recaptcha.net',
    'forms.gle',
    's.id',
    'gg.gg',
    'bit.ly',
    'rizkyaprian25.github.io',
  ];

  /// Override khusus untuk pengujian otomatis guna menyimulasikan kondisi hotspot offline/online
  @visibleForTesting
  bool? debugMockInternetConnected;

  // Token otentikasi sesi aktif
  String? _authToken;
  String? _currentDeviceId;

  String? get authToken => _authToken;
  String? get currentDeviceId => _currentDeviceId;

  void setAuth(String token, String deviceId) {
    _authToken = token;
    _currentDeviceId = deviceId;
  }

  /// Otentikasi Siswa (Login NIS/NIP + Device Binding)
  Future<Map<String, dynamic>> login({
    required String nis,
    required String password,
    required String deviceId,
  }) async {
    // ponytail: Simulasi handshake otentikasi aman tanpa latensi buatan berlebih
    await Future.delayed(const Duration(milliseconds: 300));

    if (nis.isEmpty) {
      throw Exception('NIS/NIP tidak boleh kosong');
    }

    _authToken = 'jwt_token_${DateTime.now().millisecondsSinceEpoch}';
    _currentDeviceId = deviceId;

    return {
      'token': _authToken,
      'user': {
        'id': 'usr_student_$nis',
        'nis': nis,
        'name': 'Peserta Ujian ($nis)',
        'device_id': deviceId,
      }
    };
  }

  /// Mengambil daftar ujian yang tersedia untuk siswa
  Future<List<ExamItem>> getAvailableExams() async {
    await Future.delayed(const Duration(milliseconds: 250));

    // Data mock yang patuh pada contracts/mock_data.json
    final now = DateTime.now();
    return [
      ExamItem(
        id: 'exam_pts_math_01',
        title: 'Penilaian Tengah Semester - Matematika Wajib XII',
        subject: 'Matematika',
        startTime: now.subtract(const Duration(minutes: 10)),
        endTime: now.add(const Duration(hours: 3)),
        durationMinutes: 90,
        exitAction: 'lock_wait_proctor',
        maxStrikes: 3,
      ),
      ExamItem(
        id: 'exam_pts_fisika_02',
        title: 'Penilaian Tengah Semester - Fisika Peminatan XII',
        subject: 'Fisika',
        startTime: now.add(const Duration(days: 1)),
        endTime: now.add(const Duration(days: 1, hours: 2)),
        durationMinutes: 120,
        exitAction: 'lock_wait_proctor',
        maxStrikes: 3,
      ),
    ];
  }

  /// Memulai sesi ujian dan melepaskan tautan Google Form (Release Link)
  Future<ActiveExamSession> startSession(String examId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final now = DateTime.now();
    // Google Form runtime yang valid tanpa login
    // Menggunakan URL Google Forms resmi sebagai runtime aman
    return ActiveExamSession(
      sessionId: 'ses_${DateTime.now().millisecondsSinceEpoch}',
      formUrl: 'https://docs.google.com/forms/d/e/1FAIpQLScX_SAMPLE_FORM/viewform?embedded=true',
      deadlineAt: now.add(const Duration(minutes: 90)),
      serverCurrentTime: now,
      allowedDomains: defaultAllowedExamDomains,
    );
  }

  /// Memeriksa ketersediaan akses internet nyata (khususnya saat terhubung ke Hotspot/Tethering)
  Future<bool> checkInternetReachability({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (debugMockInternetConnected != null) {
      return debugMockInternetConnected!;
    }

    // Pada lingkungan flutter test, socket keluar diblokir sehingga dikembalikan true agar stabil
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }

    if (kIsWeb) return true;

    try {
      final socket = await Socket.connect(
        'docs.google.com',
        443,
        timeout: timeout,
      );
      socket.destroy();
      return true;
    } catch (_) {
      try {
        final lookup =
            await InternetAddress.lookup('google.com').timeout(timeout);
        return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  /// Mengirim heartbeat status koneksi nyata dan baterai setiap 20 detik
  Future<bool> sendHeartbeat({
    required String sessionId,
    required int batteryLevel,
    required bool isCharging,
  }) async {
    try {
      final reachable = await checkInternetReachability();
      debugPrint(
        '[ApiClient] Heartbeat: sesi $sessionId, baterai $batteryLevel%, online=$reachable',
      );
      return reachable;
    } catch (e) {
      return false;
    }
  }

  /// Mengirim event pelanggaran ke server
  Future<bool> postViolation(ViolationEventModel event) async {
    try {
      debugPrint('[ApiClient] Mengirim pelanggaran: ${event.type.value} (${event.severity.name})');
      // Simulasi pengiriman sukses
      return true;
    } catch (e) {
      debugPrint('[ApiClient] Gagal mengirim pelanggaran: $e');
      return false;
    }
  }

  /// Menandai sesi selesai setelah deteksi halaman konfirmasi form
  Future<bool> finishSession(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    debugPrint('[ApiClient] Sesi ujian $sessionId berhasil ditandai selesai');
    return true;
  }
}

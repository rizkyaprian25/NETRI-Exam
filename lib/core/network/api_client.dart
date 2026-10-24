// API Client & Jaringan untuk NETRI Exam (SOP SoftwareEngineer.md Seksi 4.1 & 5.10)
// Mendukung fallback mock lokal agar UI dapat berjalan mandiri (Contract-Driven)

import 'dart:async';
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
      allowedDomains: const [
        'docs.google.com',
        'forms.google.com',
        'google.com',
        'gstatic.com',
        'googleusercontent.com',
      ],
    );
  }

  /// Mengirim heartbeat status koneksi dan baterai setiap 20 detik
  Future<bool> sendHeartbeat({
    required String sessionId,
    required int batteryLevel,
    required bool isCharging,
  }) async {
    try {
      // Heartbeat ringan tanpa blocking
      debugPrint('[ApiClient] Heartbeat terkirim: sesi $sessionId, baterai $batteryLevel%');
      return true;
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

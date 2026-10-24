// Antrean Pelanggaran Offline & Mekanisme Ketahanan Jaringan (Fail-Open)
// Sesuai dengan ADR-0004 & SOP SoftwareEngineer.md Seksi 5.10 & 5.11

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../contracts/models.dart';

/// Service yang mengelola antrean pengiriman event saat sinyal terputus
class OfflineViolationQueue {
  static final OfflineViolationQueue _instance = OfflineViolationQueue._internal();
  factory OfflineViolationQueue() => _instance;
  OfflineViolationQueue._internal();

  // Penyimpanan antrean lokal di memori (dapat diekspansi ke database SQLite)
  final List<ViolationEventModel> _queue = [];
  bool _isFlushing = false;
  final Random _random = Random();

  // Callback transmisi API eksternal (di-inject oleh network client)
  Future<bool> Function(ViolationEventModel event)? sendEventCallback;

  /// Memasukkan event ke antrean dan langsung mencoba mengirim
  Future<void> enqueue(ViolationEventModel event) async {
    _queue.add(event);
    debugPrint('[OfflineQueue] Event dimasukkan ke antrean: ${event.type.value} (Total: ${_queue.length})');
    unawaited(flush());
  }

  /// Mengirim antrean dengan strategi Exponential Backoff dan Jitter
  Future<void> flush() async {
    if (_isFlushing || _queue.isEmpty) return;
    if (sendEventCallback == null) return;

    _isFlushing = true;
    int retryDelayMs = 500; // Delay awal 500ms

    while (_queue.isNotEmpty) {
      final event = _queue.first;
      try {
        final success = await sendEventCallback!(event);
        if (success) {
          _queue.removeAt(0);
          debugPrint('[OfflineQueue] Berhasil mengirim event ${event.id}. Sisa: ${_queue.length}');
          retryDelayMs = 500; // Reset backoff jika sukses
        } else {
          // Gagal upstream: terapkan exponential backoff + jitter
          final jitter = _random.nextInt(200);
          await Future.delayed(Duration(milliseconds: retryDelayMs + jitter));
          retryDelayMs = min(retryDelayMs * 2, 8000); // Maksimal jeda 8 detik
          break; // Berhenti sementara, tunggu siklus berikutnya
        }
      } catch (e) {
        debugPrint('[OfflineQueue] Jaringan offline saat mengirim event: $e');
        break; // Fail-open: biarkan ujian berlanjut tanpa crash
      }
    }

    _isFlushing = false;
  }

  /// Jumlah event yang masih tertahan di lokal
  int get pendingCount => _queue.length;

  /// Membersihkan antrean saat sesi selesai
  void clear() {
    _queue.clear();
  }
}

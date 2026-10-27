// Penyimpanan Konfigurasi Ujian & PIN Pengawas (Admin Store)
// Menyimpan Mapel, Kelas, PIN Pengawas Khusus, dan Link GForm secara persisten di perangkat

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminExamConfig {
  final String id;
  final String mapel;
  final String kelas;
  final String pinPengawas;
  final String linkGForm;
  final int durasiMenit;
  final DateTime createdAt;

  AdminExamConfig({
    required this.id,
    required this.mapel,
    required this.kelas,
    required this.pinPengawas,
    required this.linkGForm,
    this.durasiMenit = 90,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'mapel': mapel,
        'kelas': kelas,
        'pin_pengawas': pinPengawas,
        'link_gform': linkGForm,
        'durasi_menit': durasiMenit,
        'created_at': createdAt.toIso8601String(),
      };

  factory AdminExamConfig.fromJson(Map<String, dynamic> json) => AdminExamConfig(
        id: json['id'] as String,
        mapel: json['mapel'] as String,
        kelas: json['kelas'] as String,
        pinPengawas: json['pin_pengawas'] as String,
        linkGForm: json['link_gform'] as String,
        durasiMenit: (json['durasi_menit'] as int?) ?? 90,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );
}

class AdminConfigStore {
  static const String _storageKey = 'netri_admin_exam_configs';
  static final AdminConfigStore _instance = AdminConfigStore._internal();
  factory AdminConfigStore() => _instance;
  AdminConfigStore._internal();

  /// Mengambil seluruh konfigurasi ujian yang disimpan oleh Admin
  Future<List<AdminExamConfig>> getAllConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonListStr = prefs.getStringList(_storageKey);
      if (jsonListStr == null || jsonListStr.isEmpty) return [];

      return jsonListStr.map((item) {
        final map = jsonDecode(item) as Map<String, dynamic>;
        return AdminExamConfig.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('[AdminConfigStore] Gagal membaca konfigurasi: $e');
      return [];
    }
  }

  /// Menambah atau memperbarui konfigurasi ujian
  Future<void> saveConfig(AdminExamConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final configs = await getAllConfigs();

    // Hapus config lama jika ID sama, lalu tambahkan yang baru di awal
    configs.removeWhere((item) => item.id == config.id);
    configs.insert(0, config);

    final jsonListStr = configs.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_storageKey, jsonListStr);
  }

  /// Menghapus konfigurasi ujian berdasarkan ID
  Future<void> deleteConfig(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final configs = await getAllConfigs();
    configs.removeWhere((item) => item.id == id);

    final jsonListStr = configs.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_storageKey, jsonListStr);
  }

  /// Mencocokkan link Google Form yang diinput siswa dengan database konfigurasi Admin
  /// Menormalisasi URL (menghapus query trailing, http/https, spasi, viewform)
  Future<AdminExamConfig?> findConfigByUrl(String inputUrl) async {
    final cleanInput = normalizeUrl(inputUrl);
    if (cleanInput.isEmpty) return null;

    final configs = await getAllConfigs();

    for (final cfg in configs) {
      final cleanTarget = normalizeUrl(cfg.linkGForm);
      if (cleanTarget.isEmpty) continue;

      // 1. Pencocokan eksak setelah normalisasi
      if (cleanInput == cleanTarget) {
        return cfg;
      }

      // 2. Pencocokan subpath unik (panjang minimal 15 karakter agar tidak false positive pada domain seperti forms.gle)
      if (cleanInput.length >= 15 && cleanTarget.length >= 15) {
        if (cleanInput.contains(cleanTarget) || cleanTarget.contains(cleanInput)) {
          return cfg;
        }
      }
    }
    return null;
  }

  /// Menormalisasi URL ujian untuk perbandingan yang tangguh
  static String normalizeUrl(String raw) {
    var url = raw
        .trim()
        .toLowerCase()
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .replaceAll('www.', '')
        .split('?')[0] // Hapus parameter query seperti ?usp=sf_link
        .replaceAll(RegExp(r'/+$'), ''); // Hapus trailing slash

    // Hilangkan suffix standar Google Form jika ada
    if (url.endsWith('/viewform')) {
      url = url.substring(0, url.length - '/viewform'.length);
    } else if (url.endsWith('/formresponse')) {
      url = url.substring(0, url.length - '/formresponse'.length);
    }

    return url.replaceAll(RegExp(r'/+$'), '');
  }
}

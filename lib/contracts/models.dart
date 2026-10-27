// Single Source of Truth (SSOT) Model Data NETRI Exam untuk Flutter Client
// Sesuai dengan spesifikasi contracts/types.ts dan PRD Seksi 9

import 'package:flutter/foundation.dart';

/// Status Sesi Ujian Siswa
enum SessionStatus {
  scheduled,
  ready,
  active,
  locked,
  finished,
  terminated,
  offline,
}

extension SessionStatusExtension on SessionStatus {
  String get value {
    switch (this) {
      case SessionStatus.scheduled:
        return 'scheduled';
      case SessionStatus.ready:
        return 'ready';
      case SessionStatus.active:
        return 'active';
      case SessionStatus.locked:
        return 'locked';
      case SessionStatus.finished:
        return 'finished';
      case SessionStatus.terminated:
        return 'terminated';
      case SessionStatus.offline:
        return 'offline';
    }
  }

  static SessionStatus fromString(String val) {
    for (final status in SessionStatus.values) {
      if (status.value == val) return status;
    }
    return SessionStatus.scheduled;
  }
}

/// Tingkat Keparahan Pelanggaran
enum ViolationSeverity {
  info,
  warning,
  danger,
}

/// Tipe Kejadian Pelanggaran Terdeteksi
enum ViolationType {
  appExit,
  screenshotAttempt,
  screenRecording,
  splitScreen,
  overlayDetected,
  externalNavigation,
  deviceTamper,
  connectionLost,
}

extension ViolationTypeExtension on ViolationType {
  String get value {
    switch (this) {
      case ViolationType.appExit:
        return 'app_exit';
      case ViolationType.screenshotAttempt:
        return 'screenshot_attempt';
      case ViolationType.screenRecording:
        return 'screen_recording';
      case ViolationType.splitScreen:
        return 'split_screen';
      case ViolationType.overlayDetected:
        return 'overlay_detected';
      case ViolationType.externalNavigation:
        return 'external_navigation';
      case ViolationType.deviceTamper:
        return 'device_tamper';
      case ViolationType.connectionLost:
        return 'connection_lost';
    }
  }

  static ViolationType fromString(String val) {
    for (final t in ViolationType.values) {
      if (t.value == val) return t;
    }
    return ViolationType.appExit;
  }
}

/// Model Entitas Ujian
@immutable
class ExamItem {
  final String id;
  final String title;
  final String subject;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final String exitAction;
  final int maxStrikes;

  const ExamItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.exitAction = 'lock_wait_proctor',
    this.maxStrikes = 3,
  });

  factory ExamItem.fromJson(Map<String, Object?> json) {
    return ExamItem(
      id: json['id']! as String,
      title: json['title']! as String,
      subject: json['subject']! as String,
      startTime: DateTime.parse(json['start_time']! as String),
      endTime: DateTime.parse(json['end_time']! as String),
      durationMinutes: (json['duration_minutes']! as num).toInt(),
      exitAction: (json['exit_action'] as String?) ?? 'lock_wait_proctor',
      maxStrikes: (json['max_strikes'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'duration_minutes': durationMinutes,
      'exit_action': exitAction,
      'max_strikes': maxStrikes,
    };
  }
}

/// Sesi Ujian yang Dilepas oleh Server atau Konfigurasi Mandiri
@immutable
class ActiveExamSession {
  final String sessionId;
  final String formUrl;
  final DateTime deadlineAt;
  final DateTime serverCurrentTime;
  final List<String> allowedDomains;
  final String proctorPin;
  final String? mapel;
  final String? kelas;
  final int durationMinutes;

  const ActiveExamSession({
    required this.sessionId,
    required this.formUrl,
    required this.deadlineAt,
    required this.serverCurrentTime,
    required this.allowedDomains,
    this.proctorPin = '1234',
    this.mapel,
    this.kelas,
    this.durationMinutes = 90,
  });

  factory ActiveExamSession.fromJson(Map<String, Object?> json) {
    final rawDomains = json['allowed_domains'] as List<Object?>? ?? [];
    final domains = rawDomains.map((e) => e.toString()).toList();

    return ActiveExamSession(
      sessionId: json['session_id']! as String,
      formUrl: json['form_url']! as String,
      deadlineAt: DateTime.parse(json['deadline_at']! as String),
      serverCurrentTime: DateTime.parse(json['server_current_time']! as String),
      allowedDomains: domains,
      proctorPin: (json['proctor_pin'] as String?) ?? '1234',
      mapel: json['mapel'] as String?,
      kelas: json['kelas'] as String?,
      durationMinutes: (json['duration_minutes'] as int?) ?? 90,
    );
  }
}

/// Model Kejadian Pelanggaran (Idempoten via UUID lokal)
@immutable
class ViolationEventModel {
  final String id;
  final String sessionId;
  final ViolationType type;
  final ViolationSeverity severity;
  final DateTime clientTimestamp;
  final DateTime? serverTimestamp;
  final int? durationSeconds;
  final bool isExcused;
  final String? notes;

  const ViolationEventModel({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.severity,
    required this.clientTimestamp,
    this.serverTimestamp,
    this.durationSeconds,
    this.isExcused = false,
    this.notes,
  });

  factory ViolationEventModel.fromJson(Map<String, Object?> json) {
    return ViolationEventModel(
      id: json['id']! as String,
      sessionId: json['session_id']! as String,
      type: ViolationTypeExtension.fromString(json['type']! as String),
      severity: _severityFromString(json['severity']! as String),
      clientTimestamp: DateTime.parse(json['client_timestamp']! as String),
      serverTimestamp: json['server_timestamp'] != null
          ? DateTime.parse(json['server_timestamp']! as String)
          : null,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      isExcused: (json['is_excused'] as bool?) ?? false,
      notes: json['notes'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'type': type.value,
      'severity': severity.name,
      'client_timestamp': clientTimestamp.toIso8601String(),
      if (serverTimestamp != null)
        'server_timestamp': serverTimestamp!.toIso8601String(),
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      'is_excused': isExcused,
      if (notes != null) 'notes': notes,
    };
  }

  static ViolationSeverity _severityFromString(String val) {
    switch (val.toLowerCase()) {
      case 'danger':
        return ViolationSeverity.danger;
      case 'warning':
        return ViolationSeverity.warning;
      case 'info':
      default:
        return ViolationSeverity.info;
    }
  }
}

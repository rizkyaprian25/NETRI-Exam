// Smoke-Test Kritis untuk Exam NETRI Lintas Platform (SOP SoftwareEngineer.md Seksi 9)
// Memvalidasi bootstrap antarmuka, inisialisasi tema, dan kontrak data

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netri_exam/app.dart';
import 'package:netri_exam/contracts/models.dart';
import 'package:netri_exam/core/network/api_client.dart';
import 'package:netri_exam/core/storage/admin_config_store.dart';
import 'package:netri_exam/core/theme/tokens.g.dart';
import 'package:netri_exam/features/exam_session/exam_session_screen.dart';
import 'package:netri_exam/features/lockdown/emergency_exit_guard.dart';

void main() {
  group('Exam NETRI Smoke Checks', () {
    testWidgets('App Shell berhasil dimuat dan menampilkan beranda Exam NETRI', (WidgetTester tester) async {
      await tester.pumpWidget(const NetriExamApp());
      await tester.pumpAndSettle();

      // Memastikan logo dan elemen input Exam NETRI muncul tanpa exception
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Aplikasi Ujian Aman (Anti-Curang)'), findsOneWidget);
      expect(find.text('Scan QR Code Soal'), findsOneWidget);
      expect(find.text('Mulai Ujian'), findsOneWidget);
    });

    test('Validasi Desain Token Semantik (Apple HIG Contrast Safety)', () {
      expect(NetriExamMetrics.minTouchTarget, greaterThanOrEqualTo(44.0));
      expect(NetriExamMetrics.examBarHeight, equals(52.0));
      expect(NetriExamMetrics.warningThresholdSeconds, equals(300));
      expect(NetriExamMetrics.dangerThresholdSeconds, equals(60));
    });

    test('Validasi Serialisasi SSOT Kontrak Data (Models)', () {
      final exam = ExamItem(
        id: 'test_exam_01',
        title: 'Ujian Matematika',
        subject: 'Matematika',
        startTime: DateTime.parse('2026-10-24T08:00:00Z'),
        endTime: DateTime.parse('2026-10-24T10:00:00Z'),
        durationMinutes: 90,
      );

      final json = exam.toJson();
      expect(json['id'], equals('test_exam_01'));
      expect(json['duration_minutes'], equals(90));

      final deserialized = ExamItem.fromJson(json);
      expect(deserialized.id, equals(exam.id));
      expect(deserialized.title, equals(exam.title));
    });

    test('Validasi Format Pelanggaran & Idempotensi', () {
      final event = ViolationEventModel(
        id: 'evt_test_uuid_123',
        sessionId: 'ses_001',
        type: ViolationType.appExit,
        severity: ViolationSeverity.warning,
        clientTimestamp: DateTime.parse('2026-10-24T08:30:00Z'),
        durationSeconds: 15,
        isExcused: false,
      );

      final json = event.toJson();
      expect(json['id'], equals('evt_test_uuid_123'));
      expect(json['type'], equals('app_exit'));
      expect(json['duration_seconds'], equals(15));
      expect(json['is_excused'], isFalse);
    });

    test('Validasi AdminExamConfig dan Normalisasi URL Google Form', () {
      final config = AdminExamConfig(
        id: 'cfg_matematika_01',
        mapel: 'Matematika Peminatan',
        kelas: 'XII MIPA 1',
        pinPengawas: '9988',
        linkGForm: 'https://docs.google.com/forms/d/e/1FAIpQLSc_Example/viewform?usp=sf_link',
        durasiMenit: 60,
      );

      final json = config.toJson();
      expect(json['mapel'], equals('Matematika Peminatan'));
      expect(json['pin_pengawas'], equals('9988'));
      expect(json['durasi_menit'], equals(60));

      final parsed = AdminExamConfig.fromJson(json);
      expect(parsed.pinPengawas, equals('9988'));
      expect(parsed.kelas, equals('XII MIPA 1'));
      expect(parsed.durasiMenit, equals(60));

      // Test URL normalization
      final norm1 = AdminConfigStore.normalizeUrl('https://docs.google.com/forms/d/e/1FAIpQLSc_Example/viewform?usp=sf_link');
      final norm2 = AdminConfigStore.normalizeUrl('http://docs.google.com/forms/d/e/1FAIpQLSc_Example/');
      expect(norm1, equals('docs.google.com/forms/d/e/1faipqlsc_example'));
      expect(norm2, equals('docs.google.com/forms/d/e/1faipqlsc_example'));
      expect(norm1, equals(norm2));

      // Test Form ID extraction & entity separation
      final id1 = AdminConfigStore.extractFormId('https://docs.google.com/forms/d/e/1FAIpQLSc_Form1/viewform');
      final id2 = AdminConfigStore.extractFormId('https://forms.gle/Form2Short');
      expect(id1, equals('1faipqlsc_form1'));
      expect(id2, equals('form2short'));
      expect(id1, isNot(equals(id2)));
    });

    test('Validasi Passcode Keluar Darurat SHA-256 & Anti Brute-Force (Rate-Limit)', () {
      final guard = EmergencyExitGuard.instance;
      guard.resetForTesting();

      // Kode salah ditolak hingga 5 kali dan memicu jeda kunci sementara 30 detik
      expect(guard.verifyPasscode('000000'), isFalse);
      expect(guard.verifyPasscode('123456'), isFalse);
      expect(guard.verifyPasscode('999999'), isFalse);
      expect(guard.verifyPasscode('111111'), isFalse);
      expect(guard.isLockedOut, isFalse);

      // Percobaan ke-5 mengaktifkan lockout
      expect(guard.verifyPasscode('222222'), isFalse);
      expect(guard.isLockedOut, isTrue);
      expect(guard.remainingLockoutSeconds, greaterThan(0));

      // Meski kode benar dimasukkan saat masih dalam masa lockout, tetap ditolak
      expect(guard.verifyPasscode('202627'), isFalse);

      // Setelah reset/jeda selesai, kode pengawas yang sah diterima
      guard.resetForTesting();
      expect(guard.verifyPasscode('202627'), isTrue);
      expect(guard.failedAttempts, equals(0));
    });

    test('Validasi Filter Navigasi Hotspot (Subframe Diizinkan & Pencarian Google Diblokir)', () {
      const allowed = ApiClient.defaultAllowedExamDomains;

      // 1. Subframe & about:blank wajib diizinkan agar tidak deadlock saat pakai Hotspot
      expect(
        ExamSessionScreen.isNavigationAllowed('about:blank', isMainFrame: false, allowedDomains: allowed),
        isTrue,
      );
      expect(
        ExamSessionScreen.isNavigationAllowed(
          'https://accounts.youtube.com/accounts/CheckConnection?pmpo=https://docs.google.com',
          isMainFrame: false,
          allowedDomains: allowed,
        ),
        isTrue,
      );
      expect(
        ExamSessionScreen.isNavigationAllowed(
          'https://challenges.cloudflare.com/turnstile/v0/api.js',
          isMainFrame: false,
          allowedDomains: allowed,
        ),
        isTrue,
      );

      // 2. Main-frame Google Forms, s.id, dan FormQR Studio diizinkan
      expect(
        ExamSessionScreen.isNavigationAllowed(
          'https://docs.google.com/forms/d/e/1FAIpQLSc_Test/viewform',
          isMainFrame: true,
          allowedDomains: allowed,
        ),
        isTrue,
      );
      expect(
        ExamSessionScreen.isNavigationAllowed('https://s.id/informatika7', isMainFrame: true, allowedDomains: allowed),
        isTrue,
      );

      // 3. Halaman pencarian Google, situs eksternal main-frame, dan skema aplikasi lain diblokir
      expect(
        ExamSessionScreen.isNavigationAllowed(
          'https://www.google.com/search?q=kunci+jawaban',
          isMainFrame: true,
          allowedDomains: allowed,
        ),
        isFalse,
      );
      expect(
        ExamSessionScreen.isNavigationAllowed('https://www.google.com/', isMainFrame: true, allowedDomains: allowed),
        isFalse,
      );
      expect(
        ExamSessionScreen.isNavigationAllowed('https://youtube.com/watch?v=123', isMainFrame: true, allowedDomains: allowed),
        isFalse,
      );
      expect(
        ExamSessionScreen.isNavigationAllowed('whatsapp://send?text=soal', isMainFrame: true, allowedDomains: allowed),
        isFalse,
      );
    });
  });
}

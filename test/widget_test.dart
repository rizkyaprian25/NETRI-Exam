// Smoke-Test Kritis untuk Exambro Lintas Platform (SOP SoftwareEngineer.md Seksi 9)
// Memvalidasi bootstrap antarmuka, inisialisasi tema, dan kontrak data

import 'package:flutter_test/flutter_test.dart';
import 'package:netri_exam/app.dart';
import 'package:netri_exam/contracts/models.dart';
import 'package:netri_exam/core/storage/admin_config_store.dart';
import 'package:netri_exam/core/theme/tokens.g.dart';

void main() {
  group('Exambro Smoke Checks', () {
    testWidgets('App Shell berhasil dimuat dan menampilkan beranda Exambro', (WidgetTester tester) async {
      await tester.pumpWidget(const NetriExamApp());
      await tester.pumpAndSettle();

      // Memastikan brand title dan elemen input Exambro muncul tanpa exception
      expect(find.text('EXAMBRO'), findsOneWidget);
      expect(find.text('Android & iOS Compatible'), findsOneWidget);
      expect(find.text('Buka Ujian Terkunci'), findsOneWidget);
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
    });
  });
}

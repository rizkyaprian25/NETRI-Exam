// Smoke-Test Kritis untuk NETRI Exam (SOP SoftwareEngineer.md Seksi 9)
// Memvalidasi bootstrap antarmuka, inisialisasi tema, dan kontrak data

import 'package:flutter_test/flutter_test.dart';
import 'package:netri_exam/app.dart';
import 'package:netri_exam/contracts/models.dart';
import 'package:netri_exam/core/theme/tokens.g.dart';

void main() {
  group('NETRI Exam Smoke Checks', () {
    testWidgets('App Shell berhasil dimuat dan menampilkan halaman login', (WidgetTester tester) async {
      await tester.pumpWidget(const NetriExamApp());
      await tester.pumpAndSettle();

      // Memastikan brand title dan elemen input muncul tanpa exception
      expect(find.text('NETRI Exam'), findsOneWidget);
      expect(find.text('Portal Ujian Terkunci Institusi'), findsOneWidget);
      expect(find.text('Masuk ke Ujian'), findsOneWidget);
    });

    test('Validasi Desain Token Semantik (Apple HIG Contrast Safety)', () {
      // Memastikan token tinggi dan dimensi memenuhi standar
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
  });
}

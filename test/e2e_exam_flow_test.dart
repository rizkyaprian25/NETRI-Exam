// Test End-to-End (E2E) Komprehensif Skenario Lengkap Exam NETRI
// Menguji Alur dari Validasi Input, Pengaturan Durasi, Penguncian Layar,
// Pemblokiran Tombol Keluar, Sirine 5 Detik, hingga Penyelesaian Ujian

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netri_exam/app.dart';
import 'package:netri_exam/features/auth/login_screen.dart';
import 'package:netri_exam/features/exam_session/exam_session_screen.dart';
import 'package:netri_exam/features/exam_session/lock_screen_dialog.dart';
import 'package:netri_exam/features/lockdown/lockdown_service.dart';
import 'package:netri_exam/features/result/result_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Daftar pencatat pemanggilan MethodChannel Native
  final List<String> channelCallLog = [];
  final Map<String, dynamic> channelArguments = {};

  setUp(() {
    channelCallLog.clear();
    channelArguments.clear();

    // Mock platform channel native untuk lockdown & sirine
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.netri.exam/lockdown'),
      (MethodCall methodCall) async {
        channelCallLog.add(methodCall.method);
        if (methodCall.arguments is Map) {
          channelArguments.addAll(
            Map<String, dynamic>.from(methodCall.arguments as Map),
          );
        }
        return true;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.netri.exam/lockdown'),
      null,
    );
  });

  group('Uji Alur E2E Ujian NETRI Exam:', () {
    testWidgets(
      'Skenario Lengkap: Input Link -> Pilih Durasi -> Mulai Ujian -> Blokir Keluar & Sirine 5s -> Deteksi Pelanggaran -> Selesai Sah',
      (WidgetTester tester) async {
        // 1. Inisialisasi dan Muat Aplikasi
        await tester.pumpWidget(const NetriExamApp());
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Aplikasi Ujian Aman (Anti-Curang)'), findsOneWidget);

        // 2. Validasi Input: Uji saat tautan kosong
        final startExamButton = find.widgetWithText(ElevatedButton, 'Mulai Ujian');
        expect(startExamButton, findsOneWidget);
        await tester.tap(startExamButton);
        await tester.pumpAndSettle();

        expect(
          find.text('Harap tempel tautan form atau pindai QR Code ujian.'),
          findsOneWidget,
        );

        // 3. Validasi Input: Uji saat tautan bukan Google Form
        final urlField = find.byType(TextField).first;
        await tester.enterText(urlField, 'https://youtube.com/video');
        await tester.tap(startExamButton);
        await tester.pumpAndSettle();

        expect(
          find.text('Tautan harus berupa formulir Google Forms yang sah.'),
          findsOneWidget,
        );

        // 4. Uji Pengaturan Durasi Custom (Ketik bebas, misal 75 Menit)
        final durationField = find.byType(TextField).last;
        await tester.enterText(durationField, '75');
        await tester.pumpAndSettle();

        expect(find.text('75 Menit'), findsOneWidget);

        // 5. Masukkan Tautan Google Form yang Sah
        await tester.enterText(urlField, 'https://forms.gle/sampleExamNetri123');
        await tester.tap(startExamButton);
        await tester.pumpAndSettle();

        // 6. Verifikasi Modal Konfirmasi Bottom Sheet dengan Durasi Custom
        expect(find.text('Mode Ujian Ketat (Anti-Curang)'), findsOneWidget);
        expect(find.textContaining('Durasi: 75 Menit'), findsOneWidget);
        expect(find.textContaining('Mencoba keluar akan membunyikan sirine'), findsOneWidget);

        // 7. Mulai Ujian Secara Resmi
        final confirmStartButton = find.widgetWithText(
          ElevatedButton,
          'Saya Siap & Mulai Mengerjakan',
        );
        expect(confirmStartButton, findsOneWidget);
        await tester.tap(confirmStartButton);
        await tester.pumpAndSettle();

        // Verifikasi Lockdown Engine Aktif di Sisi Native
        expect(channelCallLog, contains('enableSecureWindow'));
        expect(find.byType(ExamSessionScreen), findsOneWidget);

        // 8. Uji Tombol Kembali (Back Navigation): Harus Diblokir & Membunyikan Sirine 5 Detik
        channelCallLog.clear();
        channelArguments.clear();

        // Simulasikan penekanan tombol Back pada perangkat
        final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
        await widgetsAppState.didPopRoute();
        await tester.pumpAndSettle();

        // Pastikan dialog Dilarang Keluar muncul dan sirine 5000ms dipanggil
        expect(find.text('Dilarang Keluar!'), findsOneWidget);
        expect(find.text('Sirine peringatan aktif selama 5 detik!'), findsOneWidget);
        expect(channelCallLog, contains('startAlarmSound'));
        expect(channelArguments['durationMs'], equals(5000));

        // Pastikan TIDAK ADA tombol keluar di dialog back
        expect(find.text('Sudah Selesai, Keluar Ujian'), findsNothing);

        // Tutup dialog peringatan untuk lanjut ujian
        final resumeButton = find.widgetWithText(ElevatedButton, 'Lanjut Mengerjakan Ujian');
        expect(resumeButton, findsOneWidget);
        await tester.tap(resumeButton);
        await tester.pumpAndSettle();

        // Pastikan sirine dihentikan setelah kembali ke ujian
        expect(channelCallLog, contains('stopAlarmSound'));
        expect(find.text('Dilarang Keluar!'), findsNothing);

        // 9. Uji Deteksi Percobaan Berpindah Aplikasi (Home / Recent Apps)
        channelCallLog.clear();
        await LockdownService().handleAppResignedActive();
        await tester.pumpAndSettle();

        // Pastikan LockScreenDialog pelanggaran muncul
        expect(find.byType(LockScreenDialog), findsOneWidget);
        expect(find.text('🚨 PERINGATAN KECURANGAN!'), findsOneWidget);
        expect(channelCallLog, contains('startAlarmSound'));

        // Siswa membaca peringatan dan kembali ke ujian
        final acknowledgeButton = find.widgetWithText(
          ElevatedButton,
          'Saya Mengerti, Kembali ke Ujian',
        );
        expect(acknowledgeButton, findsOneWidget);
        await tester.tap(acknowledgeButton);
        await tester.pumpAndSettle();

        expect(find.byType(LockScreenDialog), findsNothing);

        // 10. Uji Alur Selesai Ujian yang Sah (Via Tombol Selesai di ExamBar)
        final finishEarlyButton = find.widgetWithText(TextButton, 'Selesai');
        expect(finishEarlyButton, findsOneWidget);
        await tester.tap(finishEarlyButton);
        await tester.pumpAndSettle();

        // Verifikasi Dialog Konfirmasi Selesai
        expect(find.text('Selesaikan Ujian?'), findsOneWidget);

        // Uji tombol "Periksa Kembali" jika siswa belum yakin
        final cancelFinishButton = find.widgetWithText(TextButton, 'Periksa Kembali');
        expect(cancelFinishButton, findsOneWidget);
        await tester.tap(cancelFinishButton);
        await tester.pumpAndSettle();
        expect(find.text('Selesaikan Ujian?'), findsNothing);

        // Buka kembali dialog selesai dan konfirmasi penyerahan
        await tester.tap(finishEarlyButton);
        await tester.pumpAndSettle();

        final confirmFinishButton = find.widgetWithText(ElevatedButton, 'Ya, Sudah Selesai');
        expect(confirmFinishButton, findsOneWidget);

        channelCallLog.clear();
        await tester.tap(confirmFinishButton);
        await tester.pumpAndSettle();

        // Verifikasi Mode Lockdown Dilepas & Navigasi ke ResultScreen
        expect(channelCallLog, contains('disableSecureWindow'));
        expect(find.byType(ResultScreen), findsOneWidget);
        expect(find.text('Sesi Ujian Selesai'), findsOneWidget);
        expect(find.text('Terkunci & Sah'), findsOneWidget);

        // 11. Kembali Bersih ke Layar Beranda Login
        final backHomeButton = find.widgetWithText(ElevatedButton, 'Kembali ke Beranda');
        expect(backHomeButton, findsOneWidget);
        await tester.ensureVisible(backHomeButton);
        await tester.pumpAndSettle();
        await tester.tap(backHomeButton);
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );
  });
}

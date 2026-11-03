// Test End-to-End (E2E) Komprehensif Skenario Lengkap Exam NETRI
// Menguji Alur dari Validasi Input, Penguncian Kiosk Layar Penuh (Tanpa Timer),
// Pemblokiran Tombol Keluar, Sirine 5 Detik, hingga Penyelesaian Ujian yang Sah

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netri_exam/app.dart';
import 'package:netri_exam/contracts/models.dart';
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
      'Skenario Lengkap: Input Link -> Mulai Ujian -> Kiosk Terkunci -> Blokir Keluar & Sirine 5s -> Deteksi Pelanggaran -> Selesai Sah',
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

        // 4. Masukkan Tautan Google Form yang Sah
        await tester.enterText(urlField, 'https://forms.gle/sampleExamNetri123');
        await tester.tap(startExamButton);
        await tester.pumpAndSettle();

        // 5. Verifikasi Modal Konfirmasi Bottom Sheet
        expect(find.text('Mode Ujian Ketat (Anti-Curang)'), findsOneWidget);
        expect(find.textContaining('Pengawasan Guru • Layar 100% • Suara 100%'), findsOneWidget);
        expect(find.textContaining('Mencoba keluar akan membunyikan alarm suara'), findsOneWidget);

        // 6. Mulai Ujian Secara Resmi
        final confirmStartButton = find.widgetWithText(
          ElevatedButton,
          'Saya Siap & Mulai Mengerjakan',
        );
        expect(confirmStartButton, findsOneWidget);
        await tester.tap(confirmStartButton);
        await tester.pumpAndSettle();

        // Verifikasi Lockdown Engine Aktif di Sisi Native & Badge Terkunci Muncul
        expect(channelCallLog, contains('enableSecureWindow'));
        expect(find.byType(ExamSessionScreen), findsOneWidget);
        expect(find.text('Exam NETRI (Terkunci)'), findsOneWidget);

        // 7. Uji Tombol Kembali (Back Navigation): Harus Diblokir & Membunyikan Sirine 5 Detik
        channelCallLog.clear();
        channelArguments.clear();

        // Simulasikan penekanan tombol Back pada perangkat
        final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
        await widgetsAppState.didPopRoute();
        await tester.pumpAndSettle();

        // Pastikan dialog Dilarang Keluar muncul dan sirine 5000ms dipanggil
        expect(find.text('Dilarang Keluar!'), findsOneWidget);
        expect(find.text('Alarm suara "Aku Nyontek!" aktif selama 5 detik!'), findsOneWidget);
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

        // Majukan waktu agar melewati masa tenggang startup awal (5 detik)
        await tester.pump(const Duration(seconds: 6));
        LockdownService().expireStartupGracePeriodForTesting();

        // 8. Uji Deteksi Percobaan Berpindah Aplikasi (Home / Recent Apps)
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

        // 9. Verifikasi Tombol 'Selesai' di Top Bar Ditiadakan (Hanya Selesai via Kirim Form)
        expect(find.text('Selesai'), findsNothing);
        expect(find.widgetWithText(TextButton, 'Selesai'), findsNothing);

        // Siswa menyelesaikan pengisian dan menekan tombol Kirim pada Google Form
        final submitFormButton = find.widgetWithText(ElevatedButton, 'Simulasi Kirim Form');
        expect(submitFormButton, findsOneWidget);

        channelCallLog.clear();
        await tester.tap(submitFormButton);
        await tester.pumpAndSettle();

        // Verifikasi Mode Lockdown Dilepas & Navigasi ke ResultScreen
        expect(channelCallLog, contains('disableSecureWindow'));
        expect(find.byType(ResultScreen), findsOneWidget);
        expect(find.text('Sesi Ujian Selesai'), findsOneWidget);
        expect(find.text('Terkunci & Sah'), findsOneWidget);

        // 10. Kembali Bersih ke Layar Beranda Login
        final backHomeButton = find.widgetWithText(ElevatedButton, 'Kembali ke Beranda');
        expect(backHomeButton, findsOneWidget);
        await tester.ensureVisible(backHomeButton);
        await tester.pumpAndSettle();
        await tester.tap(backHomeButton);
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Skenario Kiosk Tanpa Timer Otomatis: Aplikasi Tetap Terkunci Stabil Tanpa Batas Waktu Mendadak',
      (WidgetTester tester) async {
        final now = DateTime.now();
        final session = ActiveExamSession(
          sessionId: 'ses_kiosk_no_timer_test',
          formUrl: 'https://forms.gle/noTimerTest123',
          deadlineAt: now.add(const Duration(hours: 12)),
          durationMinutes: 0,
          serverCurrentTime: now,
          allowedDomains: const ['forms.gle', 'docs.google.com'],
          proctorPin: '',
          mapel: 'Ujian Mandiri Guru',
          kelas: 'Kelas Uji',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ExamSessionScreen(session: session),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ExamSessionScreen), findsOneWidget);
        expect(channelCallLog, contains('enableSecureWindow'));
        expect(find.text('Exam NETRI (Terkunci)'), findsOneWidget);

        // Majukan waktu virtual selama 30 menit pengerjaan
        await tester.pump(const Duration(minutes: 30));
        await tester.pumpAndSettle();

        // Pastikan tidak ada dialog habis waktu yang memotong pengisian siswa
        expect(find.text('Waktu Ujian Habis'), findsNothing);
        expect(find.byType(ExamSessionScreen), findsOneWidget);

        // Pastikan tombol 'Selesai' di top bar tidak ada
        expect(find.text('Selesai'), findsNothing);

        // Siswa menyelesaikan ujian hanya saat form terkirim
        final submitButton = find.widgetWithText(ElevatedButton, 'Simulasi Kirim Form');
        channelCallLog.clear();
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Pastikan lockdown dilepas dan berpindah ke ResultScreen secara sah
        expect(channelCallLog, contains('disableSecureWindow'));
        expect(find.byType(ResultScreen), findsOneWidget);
        expect(find.text('Sesi Ujian Selesai'), findsOneWidget);
      },
    );

    testWidgets(
      'Skenario Anti Floating Apps (Chrome Mengambang): Tolak Masuk Saat Ada Floating App & Tirai Kunci Layar',
      (WidgetTester tester) async {
        bool mockScreenClear = false;
        bool mockPinned = false;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.netri.exam/lockdown'),
          (MethodCall methodCall) async {
            channelCallLog.add(methodCall.method);
            if (methodCall.method == 'checkScreenClear') {
              return mockScreenClear;
            }
            if (methodCall.method == 'isLockTaskActive') {
              return mockPinned;
            }
            if (methodCall.method == 'requestLockTask') {
              mockPinned = true;
              mockScreenClear = true;
              return true;
            }
            return true;
          },
        );

        await tester.pumpWidget(const NetriExamApp());
        await tester.pumpAndSettle();

        final urlField = find.byType(TextField).first;
        await tester.enterText(urlField, 'https://forms.gle/floatingTest123');

        // 1. Coba mulai ujian saat Chrome mengambang masih aktif (mockScreenClear = false)
        final startExamButton = find.widgetWithText(ElevatedButton, 'Mulai Ujian');
        await tester.tap(startExamButton);
        await tester.pumpAndSettle();

        // Pastikan ditolak di layar Login dengan peringatan Floating App
        expect(
          find.textContaining('Terdeteksi aplikasi mengambang (Floating App / Split-Screen)'),
          findsOneWidget,
        );
        expect(find.byType(ExamSessionScreen), findsNothing);

        // 2. Setelah layar bersih di beranda, lanjutkan masuk ke ruang ujian namun belum di-pin (mockPinned = false)
        mockScreenClear = true;
        await tester.tap(startExamButton);
        await tester.pumpAndSettle();

        final confirmStartButton = find.widgetWithText(
          ElevatedButton,
          'Saya Siap & Mulai Mengerjakan',
        );
        await tester.tap(confirmStartButton);
        await tester.pumpAndSettle();

        expect(find.byType(ExamSessionScreen), findsOneWidget);

        // 3. Karena belum di-pin (mockPinned = false), Tirai Pelindung wajib menutupi soal ujian
        expect(
          find.text('Kunci Layar Ujian (Sematkan Layar) Wajib Aktif!'),
          findsOneWidget,
        );
        final lockTaskButton = find.widgetWithText(
          ElevatedButton,
          'Kunci Layar & Tutup Floating Apps',
        );
        expect(lockTaskButton, findsOneWidget);

        // 4. Tekan tombol 'Kunci Layar & Tutup Floating Apps' -> memanggil requestLockTask()
        await tester.tap(lockTaskButton);
        await tester.pumpAndSettle();

        expect(channelCallLog, contains('requestLockTask'));
        expect(
          find.text('Kunci Layar Ujian (Sematkan Layar) Wajib Aktif!'),
          findsNothing,
        );
      },
    );
  });
}

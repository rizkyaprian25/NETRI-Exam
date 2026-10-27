// Layar Beranda NETRI Exam (Mode Bersih, Cepat & Ketat)
// Input URL Manual, Scan QR Code Kamera, dan Mulai Ujian Tanpa PIN

import 'package:flutter/material.dart';
import '../../contracts/models.dart';
import '../../core/theme/tokens.g.dart';
import '../exam_session/exam_session_screen.dart';
import '../qr_scanner/qr_scanner_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _urlController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// Buka Pemindai QR Code untuk mengisi tautan ujian secara otomatis
  Future<void> _scanQrCode() async {
    setState(() => _errorMessage = null);
    try {
      final scannedUrl = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const QrScannerScreen()),
      );

      if (scannedUrl != null && scannedUrl.trim().isNotEmpty) {
        setState(() {
          _urlController.text = scannedUrl.trim();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Tautan QR Code berhasil dipindai!'),
                ],
              ),
              backgroundColor: NetriColors.stateSuccessLight,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Gagal membuka kamera: $e');
    }
  }

  /// Memulai sesi ujian dalam mode ketat
  void _startExam() {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _errorMessage = 'Harap tempel tautan form atau pindai QR Code ujian.');
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (!rawUrl.contains('google.com') && !rawUrl.contains('forms.gle'))) {
      setState(() => _errorMessage = 'Tautan harus berupa formulir Google Forms yang sah.');
      return;
    }

    setState(() => _errorMessage = null);

    _showConfirmationBottomSheet(
      onConfirmed: () {
        final now = DateTime.now();
        const durationMinutes = 120; // 2 Jam standar
        final session = ActiveExamSession(
          sessionId: 'ses_${now.millisecondsSinceEpoch}',
          formUrl: rawUrl,
          deadlineAt: now.add(const Duration(minutes: durationMinutes)),
          durationMinutes: durationMinutes,
          serverCurrentTime: now,
          allowedDomains: const [
            'docs.google.com',
            'forms.google.com',
            'google.com',
            'gstatic.com',
            'googleusercontent.com',
            'forms.gle',
          ],
          proctorPin: '', // Tanpa PIN
          mapel: 'Ujian Google Form',
          kelas: 'Umum',
        );

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExamSessionScreen(session: session),
          ),
        );
      },
    );
  }

  /// Konfirmasi sebelum mengunci layar penuh, kecerahan 100%, dan suara 100%
  void _showConfirmationBottomSheet({required VoidCallback onConfirmed}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NetriRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NetriSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NetriColors.brandLight.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.security_rounded, color: NetriColors.brandLight, size: 28),
                  ),
                  const SizedBox(width: NetriSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mode Ujian Ketat (Anti-Curang)',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'Cahaya 100% • Suara 100% • Sirine Peringatan Aktif',
                          style: TextStyle(fontSize: 12, color: NetriColors.brandLight, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NetriSpacing.space4),

              const Text(
                'Peraturan Selama Ujian Berlangsung:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Text(
                '• Kecerahan layar & volume suara disetel penuh (100%) dan tidak bisa dikecilkan.\n'
                '• Dilarang berpindah aplikasi, meminimalkan layar, atau menekan tombol navigasi.\n'
                '• Upaya keluar atau berpindah aplikasi akan membunyikan sirine peringatan keras selama 5 detik!',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),

              const SizedBox(height: NetriSpacing.space6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NetriColors.brandLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onConfirmed();
                  },
                  label: const Text('Saya Siap & Mulai Mengerjakan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(NetriSpacing.space6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo Resmi NETRI Exam
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 140, maxWidth: 220),
                      padding: const EdgeInsets.symmetric(horizontal: NetriSpacing.space3),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(NetriRadius.md),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: NetriSpacing.space3),

                  // Badge Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: NetriColors.brandLight.withAlpha(20),
                          borderRadius: BorderRadius.circular(NetriRadius.full),
                          border: Border.all(color: NetriColors.brandLight.withAlpha(60)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded, size: 14, color: NetriColors.brandLight),
                            SizedBox(width: 6),
                            Text(
                              'Aplikasi Ujian Aman (Anti-Curang)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: NetriColors.brandLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NetriSpacing.space6),

                  // Kartu Masuk Ujian
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(NetriRadius.lg),
                      side: BorderSide(color: theme.dividerColor.withAlpha(50), width: 1.2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(NetriSpacing.space5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Tautan Formulir Ujian',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pindai QR Code dari pengawas atau tempel tautan Google Form di bawah ini:',
                            style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                          ),
                          const SizedBox(height: NetriSpacing.space3),

                          // Input URL
                          TextField(
                            controller: _urlController,
                            keyboardType: TextInputType.url,
                            decoration: InputDecoration(
                              hintText: 'https://forms.gle/... atau docs.google.com...',
                              prefixIcon: const Icon(Icons.link_rounded),
                              suffixIcon: _urlController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => setState(() => _urlController.clear()),
                                    )
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: NetriSpacing.space3),

                          // Tombol Scan QR Code
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: NetriColors.brandLight),
                            ),
                            onPressed: _scanQrCode,
                            icon: const Icon(Icons.qr_code_scanner_rounded, color: NetriColors.brandLight),
                            label: const Text(
                              'Scan QR Code Soal',
                              style: TextStyle(fontWeight: FontWeight.bold, color: NetriColors.brandLight),
                            ),
                          ),

                          const SizedBox(height: NetriSpacing.space4),

                          // Tombol Mulai Ujian
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: NetriColors.brandLight,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(NetriRadius.md),
                              ),
                            ),
                            onPressed: _startExam,
                            icon: const Icon(Icons.play_arrow_rounded, size: 24),
                            label: const Text(
                              'Mulai Ujian',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Pesan Kesalahan jika ada
                  if (_errorMessage != null) ...[
                    const SizedBox(height: NetriSpacing.space4),
                    Container(
                      padding: const EdgeInsets.all(NetriSpacing.space3),
                      decoration: BoxDecoration(
                        color: NetriColors.stateDangerLight.withAlpha(20),
                        borderRadius: BorderRadius.circular(NetriRadius.sm),
                        border: Border.all(color: NetriColors.stateDangerLight.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 20, color: NetriColors.stateDangerLight),
                          const SizedBox(width: NetriSpacing.space2),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: NetriColors.stateDangerLight, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

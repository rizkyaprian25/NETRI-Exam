// Layar Beranda NETRI Exam (Responsif, Bersih, Anti-Curang)
// Dilengkapi Input Link, Scan QR Kamera, dan Pengaturan Durasi Ujian di Halaman yang Sama

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
  final TextEditingController _durationController = TextEditingController(text: '90');
  int _selectedDurationMinutes = 90;
  String? _errorMessage;

  final List<int> _presetDurations = [30, 45, 60, 90, 120, 180];

  @override
  void dispose() {
    _urlController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  /// Buka Pemindai QR Code kamera untuk mengisi tautan ujian secara instan
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
      setState(() => _errorMessage = 'Gagal mengakses kamera: $e');
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

    // Ambil durasi
    int duration = int.tryParse(_durationController.text.trim()) ?? _selectedDurationMinutes;
    if (duration <= 0) duration = 90;

    setState(() => _errorMessage = null);

    _showConfirmationBottomSheet(
      durationMinutes: duration,
      onConfirmed: () {
        final now = DateTime.now();
        final session = ActiveExamSession(
          sessionId: 'ses_${now.millisecondsSinceEpoch}',
          formUrl: rawUrl,
          deadlineAt: now.add(Duration(minutes: duration)),
          durationMinutes: duration,
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

  /// Lembar konfirmasi ringkas sebelum mengunci layar
  void _showConfirmationBottomSheet({required int durationMinutes, required VoidCallback onConfirmed}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NetriRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NetriSpacing.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NetriColors.brandLight.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_rounded, color: NetriColors.brandLight, size: 26),
                  ),
                  const SizedBox(width: NetriSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mode Ujian Ketat (Anti-Curang)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Durasi: $durationMinutes Menit • Layar 100% • Suara 100%',
                          style: const TextStyle(fontSize: 12, color: NetriColors.brandLight, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NetriSpacing.space4),

              const Text(
                'Peraturan Ujian:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Text(
                '• Kecerahan layar & volume suara otomatis disetel 100% dan tidak dapat dikecilkan.\n'
                '• Notifikasi ditutup dan dilarang membuka aplikasi lain.\n'
                '• Mencoba keluar akan membunyikan sirine peringatan keras 5 detik!',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),

              const SizedBox(height: NetriSpacing.space5),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: NetriColors.brandLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(NetriRadius.md),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onConfirmed();
                },
                label: const Text('Saya Siap & Mulai Mengerjakan', style: TextStyle(fontWeight: FontWeight.bold)),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: NetriSpacing.space4, vertical: NetriSpacing.space5),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Logo
                      Center(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 110, maxWidth: 200),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(NetriRadius.md),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: NetriSpacing.space2),

                      // Status Badge
                      Center(
                        child: Container(
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
                      ),
                      const SizedBox(height: NetriSpacing.space4),

                      // Kartu Pengaturan & Masuk Ujian
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(NetriRadius.lg),
                          side: BorderSide(color: theme.dividerColor.withAlpha(50), width: 1.2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(NetriSpacing.space4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Bagian 1: Tautan Form
                              Text(
                                '1. Tautan Formulir Ujian',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pindai QR Code dari pengawas atau tempel tautan form di sini:',
                                style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                              ),
                              const SizedBox(height: NetriSpacing.space2),

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
                              const SizedBox(height: NetriSpacing.space2),

                              // Tombol Scan QR Code
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  side: const BorderSide(color: NetriColors.brandLight),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(NetriRadius.sm),
                                  ),
                                ),
                                onPressed: _scanQrCode,
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: NetriColors.brandLight),
                                label: const Text(
                                  'Scan QR Code Soal',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: NetriColors.brandLight),
                                ),
                              ),

                              const SizedBox(height: NetriSpacing.space4),
                              const Divider(height: 1),
                              const SizedBox(height: NetriSpacing.space3),

                              // Bagian 2: Pengaturan Durasi Ujian
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '2. Durasi Ujian',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: NetriColors.brandLight.withAlpha(20),
                                      borderRadius: BorderRadius.circular(NetriRadius.sm),
                                    ),
                                    child: Text(
                                      '$_selectedDurationMinutes Menit',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: NetriColors.brandLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Pilih estimasi waktu pengerjaan soal ujian:',
                                style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                              ),
                              const SizedBox(height: NetriSpacing.space2),

                              // Pilihan Chip Waktu Cepat
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _presetDurations.map((mins) {
                                  final isSelected = _selectedDurationMinutes == mins;
                                  return ChoiceChip(
                                    label: Text('$mins Mnt', style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
                                    selected: isSelected,
                                    selectedColor: NetriColors.brandLight,
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() {
                                          _selectedDurationMinutes = mins;
                                          _durationController.text = mins.toString();
                                        });
                                      }
                                    },
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: NetriSpacing.space4),

                              // Tombol Mulai Ujian Utama
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
                        const SizedBox(height: NetriSpacing.space3),
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
            );
          },
        ),
      ),
    );
  }
}

// Layar Beranda NETRI Exam (Responsif, Bersih, Anti-Curang)
// Dilengkapi Input Link Formulir Ujian, Scan QR Kamera, dan Penguncian Kiosk Penuh

import 'package:flutter/material.dart';
import '../../contracts/models.dart';
import '../../core/theme/tokens.g.dart';
import '../exam_session/exam_session_screen.dart';
import '../lockdown/lockdown_service.dart';
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
  void initState() {
    super.initState();
    // Pastikan status penguncian dan suara alarm selalu nonaktif di layar login
    LockdownService().disableLockdown();
  }

  @override
  void dispose() {
    _urlController.dispose();
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

  /// Memulai sesi ujian dalam mode ketat setelah memvalidasi izin overlay dan kebersihan layar
  Future<void> _startExam() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _errorMessage = 'Harap tempel tautan form atau pindai QR Code ujian.';
      });
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (!rawUrl.contains('google.com') && !rawUrl.contains('forms.gle'))) {
      setState(() {
        _errorMessage = 'Tautan harus berupa formulir Google Forms yang sah.';
      });
      return;
    }

    // Lapis 1: Tolak masuk ujian jika terdeteksi ada floating app (misal Chrome mengambang) atau split-screen aktif
    final isClear = await LockdownService().checkScreenClear();
    if (!mounted) return;
    if (!isClear) {
      setState(() {
        _errorMessage =
            'Terdeteksi aplikasi mengambang (Floating App / Split-Screen) aktif di layar! '
            'Harap tutup semua jendela mengambang (seperti Chrome) terlebih dahulu sebelum memulai ujian.';
      });
      return;
    }

    // Lapis 2: Wajibkan izin Overlay ("Tampilkan di atas aplikasi lain") untuk menarik layar jika siswa keluar
    final hasOverlay = await LockdownService().hasOverlayPermission();
    if (!mounted) return;
    if (!hasOverlay) {
      _showOverlayPermissionSheet();
      return;
    }

    // Deteksi apakah HP menggunakan Mode Gerakan (Gesture) untuk menampilkan peringatan khusus
    final isThreeButton = await LockdownService().isThreeButtonNavigation();
    if (!mounted) return;

    setState(() {
      _errorMessage = null;
    });

    _showConfirmationBottomSheet(
      isGestureMode: !isThreeButton,
      onConfirmed: () async {
        final stillClear = await LockdownService().checkScreenClear();
        if (!mounted) return;
        if (!stillClear) {
          setState(() {
            _errorMessage =
                'Terdeteksi aplikasi mengambang (Floating App / Split-Screen) aktif di layar! '
                'Harap tutup semua jendela mengambang terlebih dahulu sebelum memulai ujian.';
          });
          return;
        }

        final now = DateTime.now();
        final session = ActiveExamSession(
          sessionId: 'ses_${now.millisecondsSinceEpoch}',
          formUrl: rawUrl,
          deadlineAt: now.add(const Duration(hours: 12)),
          durationMinutes: 0,
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

  /// Lembar permintaan izin "Tampilkan di atas aplikasi lain" (Overlay) untuk proteksi anti-keluar
  void _showOverlayPermissionSheet() {
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
              const Row(
                children: [
                  Icon(Icons.lock_person_rounded, color: NetriColors.brandLight, size: 28),
                  SizedBox(width: NetriSpacing.space3),
                  Expanded(
                    child: Text(
                      'Izin Penguncian Layar Ujian Diperlukan',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NetriSpacing.space3),
              const Text(
                'Agar lembar ujian tidak dapat ditinggalkan dan tetap terlindungi saat menggunakan navigasi gerakan, harap aktifkan izin "Tampilkan di atas aplikasi lain" untuk Exam NETRI.',
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: NetriSpacing.space4),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: NetriColors.brandLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.verified_user_rounded, size: 20),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  LockdownService().requestOverlayPermission();
                },
                label: const Text(
                  'Aktifkan Izin Kunci Layar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lembar konfirmasi ringkas sebelum mengunci layar
  void _showConfirmationBottomSheet({
    required VoidCallback onConfirmed,
    bool isGestureMode = false,
  }) {
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mode Ujian Ketat (Anti-Curang)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Pengawasan Guru • Layar 100% • Suara 100%',
                          style: TextStyle(fontSize: 12, color: NetriColors.brandLight, fontWeight: FontWeight.w600),
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
                '• Mencoba keluar akan membunyikan alarm suara "Aku Nyontek!" keras selama 5 detik!',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),

              if (isGestureMode) ...[
                const SizedBox(height: NetriSpacing.space3),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(30),
                    borderRadius: BorderRadius.circular(NetriRadius.sm),
                    border: Border.all(color: Colors.amber.shade700.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.swipe_rounded, color: Colors.amber.shade900, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mode Gerakan (Gesture) Terdeteksi:\n'
                          'Layar dijaga oleh pengawal otomatis. Mencoba usap keluar akan membunyikan teriakan "Aku Nyontek!" 5 detik dan ditarik kembali!',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.amber.shade900,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
                              // Bagian: Tautan Form
                              Text(
                                'Tautan Formulir Ujian',
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

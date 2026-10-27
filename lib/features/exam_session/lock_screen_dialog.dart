// Dialog Peringatan & Sirine Kecurangan NETRI Exam
// Membunyikan sirine 5 detik saat mencoba keluar/curang & kembali tanpa PIN

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/tokens.g.dart';
import '../lockdown/lockdown_service.dart';

class LockScreenDialog extends StatefulWidget {
  final int strikeCount;
  final String reason;
  final VoidCallback onDismissed;

  const LockScreenDialog({
    super.key,
    required this.strikeCount,
    required this.reason,
    required this.onDismissed,
  });

  @override
  State<LockScreenDialog> createState() => _LockScreenDialogState();
}

class _LockScreenDialogState extends State<LockScreenDialog> {
  int _secondsLeft = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Hitung mundur visual sirine 5 detik
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _dismissAndResume() {
    LockdownService().stopAlarmSound();
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false, // Dilarang menutup lewat gesture back
      child: Dialog.fullscreen(
        backgroundColor: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(NetriSpacing.space5),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Ikon Sirine Berkedip Merah
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(NetriSpacing.space5),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.red,
                          size: 64,
                        ),
                      ),
                    ),
                    const SizedBox(height: NetriSpacing.space4),

                    // Judul Peringatan Keras
                    const Text(
                      '🚨 PERINGATAN KECURANGAN!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NetriSpacing.space3),

                    // Indikator Sirine 5 Detik
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(20),
                          borderRadius: BorderRadius.circular(NetriRadius.full),
                          border: Border.all(color: Colors.red.withAlpha(80)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.volume_up_rounded, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _secondsLeft > 0
                                  ? 'Sirine Peringatan Berbunyi ($_secondsLeft detik)'
                                  : 'Sirine Telah Berakhir',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: NetriSpacing.space4),

                    // Alasan Pelanggaran
                    Text(
                      widget.reason,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NetriSpacing.space2),
                    Text(
                      'Anda dilarang keras meminimalkan aplikasi, menekan tombol navigasi, atau membuka aplikasi lain selama ujian berlangsung.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: NetriSpacing.space6),

                    // Tombol Kembali Mengerjakan Soal (Tanpa PIN)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NetriColors.brandLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(NetriRadius.md),
                        ),
                      ),
                      onPressed: _dismissAndResume,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text(
                        'Saya Mengerti, Kembali ke Ujian',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

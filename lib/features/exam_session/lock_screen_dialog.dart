// Dialog Peringatan & Layar Terkunci NETRI Exam (Apple HIG Calm Pattern)
// Pesan objektif tidak menuduh (non-accusatory copy) & opsi buka kunci pengawas

import 'package:flutter/material.dart';
import '../../core/theme/tokens.g.dart';

class LockScreenDialog extends StatefulWidget {
  final int strikeCount;
  final String reason;
  final String expectedPin;
  final VoidCallback onProctorUnlocked;
  final VoidCallback? onProctorExitToHome;

  const LockScreenDialog({
    super.key,
    required this.strikeCount,
    required this.reason,
    this.expectedPin = '1234',
    required this.onProctorUnlocked,
    this.onProctorExitToHome,
  });

  @override
  State<LockScreenDialog> createState() => _LockScreenDialogState();
}

class _LockScreenDialogState extends State<LockScreenDialog> {
  final TextEditingController _pinController = TextEditingController();
  bool _isIncorrectPin = false;

  void _verifyPinAndUnlock() {
    // Verifikasi PIN Pengawas untuk membuka kembali lembar ujian
    if (_pinController.text.trim() == widget.expectedPin) {
      widget.onProctorUnlocked();
    } else {
      setState(() {
        _isIncorrectPin = true;
      });
    }
  }

  void _verifyPinAndExit() {
    // Verifikasi PIN Pengawas untuk mengakhiri sesi dan kembali ke beranda
    if (_pinController.text.trim() == widget.expectedPin) {
      widget.onProctorExitToHome?.call();
    } else {
      setState(() {
        _isIncorrectPin = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocked = widget.strikeCount >= 1 || widget.reason.contains('PERINGATAN EXAMBRO');

    return PopScope(
      canPop: false, // Dilarang menutup dialog lewat gesture back
      child: Dialog.fullscreen(
        backgroundColor: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(NetriSpacing.space6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ikon Status
                Container(
                  padding: const EdgeInsets.all(NetriSpacing.space5),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? NetriColors.stateDangerLight.withAlpha(25)
                        : NetriColors.stateWarningLight.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLocked ? Icons.lock_rounded : Icons.info_outline_rounded,
                    color: isLocked
                        ? NetriColors.stateDangerLight
                        : NetriColors.stateWarningLight,
                    size: 56,
                  ),
                ),
                const SizedBox(height: NetriSpacing.space5),

                // Judul
                Text(
                  isLocked ? 'Sesi Ujian Terkunci' : 'Pemberitahuan Sistem Ujian',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: NetriSpacing.space3),

                // Pesan Non-Menuduh
                Text(
                  widget.reason,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.textTheme.bodyMedium?.color),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: NetriSpacing.space2),
                Text(
                  isLocked
                      ? 'Silakan tunjukkan layar ini kepada pengawas ruang untuk membuka kunci sesi ujian.'
                      : 'Catatan: Ujian direkam demi menjaga integritas bersama. Mohon tetap berada di aplikasi.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: NetriSpacing.space6),

                // Jika terkunci: input PIN pengawas
                if (isLocked) ...[
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.text,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'PIN Pengawas',
                        errorText: _isIncorrectPin ? 'PIN Pengawas Salah!' : null,
                      ),
                      onSubmitted: (_) => _verifyPinAndUnlock(),
                    ),
                  ),
                  const SizedBox(height: NetriSpacing.space4),
                  ElevatedButton(
                    onPressed: _verifyPinAndUnlock,
                    child: const Text('Buka Kunci & Lanjut Ujian'),
                  ),
                  if (widget.onProctorExitToHome != null) ...[
                    const SizedBox(height: NetriSpacing.space2),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: NetriColors.stateDangerLight,
                      ),
                      onPressed: _verifyPinAndExit,
                      icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                      label: const Text('Akhiri Sesi & Kembali ke Beranda'),
                    ),
                  ],
                ] else ...[
                  // Jika hanya peringatan (Strike 1)
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Saya Mengerti & Lanjutkan Ujian'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

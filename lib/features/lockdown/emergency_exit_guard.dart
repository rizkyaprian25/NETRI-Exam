// Penjaga Passcode Keluar Darurat Pengawas (SHA-256 & Anti Brute-Force)
// Memverifikasi kode rahasia pengawas untuk memutus Sematkan Aplikasi saat kondisi darurat

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/tokens.g.dart';
import 'lockdown_service.dart';

class EmergencyExitGuard {
  static final EmergencyExitGuard instance = EmergencyExitGuard._internal();
  EmergencyExitGuard._internal();

  // Salt dan hash SHA-256 kode pengawas agar tidak tersimpan sebagai teks polos di biner
  static const String _salt = 'netri_exam_emergency_v1:';
  static const String _expectedSaltedHash =
      '8b0c4cfa9539ac6475347744dbcbc3bc9a18c382ee2adeeabd163fbc94494e04';

  static const int _maxFailedAttempts = 5;
  static const Duration _lockoutDuration = Duration(seconds: 30);

  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  int get failedAttempts => _failedAttempts;

  /// Memeriksa apakah input passcode sedang dikunci sementara akibat terlalu banyak percobaan salah
  bool get isLockedOut =>
      _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  /// Sisa waktu jeda kunci (dalam detik) saat proteksi brute-force aktif
  int get remainingLockoutSeconds {
    if (!isLockedOut) return 0;
    final diff = _lockedUntil!.difference(DateTime.now()).inSeconds;
    return diff < 1 ? 1 : diff;
  }

  /// Membandingkan dua string dalam waktu konstan untuk mencegah timing side-channel
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Memverifikasi passcode darurat pengawas dengan batas percobaan salah maksimal 5 kali
  bool verifyPasscode(String input) {
    if (isLockedOut) return false;

    final cleaned = input.trim();
    if (cleaned.isEmpty) return false;

    final digest = sha256.convert(utf8.encode('$_salt$cleaned')).toString();
    if (_constantTimeEquals(digest, _expectedSaltedHash)) {
      _failedAttempts = 0;
      _lockedUntil = null;
      return true;
    }

    _failedAttempts++;
    if (_failedAttempts >= _maxFailedAttempts) {
      _lockedUntil = DateTime.now().add(_lockoutDuration);
      _failedAttempts = 0;
    }
    return false;
  }

  /// Khusus untuk pengujian otomatis: Mereset penghitung percobaan dan status kunci
  @visibleForTesting
  void resetForTesting() {
    _failedAttempts = 0;
    _lockedUntil = null;
  }
}

/// Menampilkan dialog verifikasi passcode pengawas untuk memutus Sematkan Aplikasi secara darurat
Future<bool?> showEmergencyExitDialog(
  BuildContext context, {
  required Future<void> Function() onVerified,
}) async {
  // Hentikan sementara suara sirine agar dialog pengawas dapat diproses dengan tenang
  await LockdownService().stopAlarmSound();
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => const _EmergencyExitDialog(),
  );

  if (confirmed == true) {
    await onVerified();
  }
  return confirmed;
}

class _EmergencyExitDialog extends StatefulWidget {
  const _EmergencyExitDialog();

  @override
  State<_EmergencyExitDialog> createState() => _EmergencyExitDialogState();
}

class _EmergencyExitDialogState extends State<_EmergencyExitDialog> {
  final TextEditingController _controller = TextEditingController();
  final EmergencyExitGuard _guard = EmergencyExitGuard.instance;
  String? _errorText;
  bool _isProcessing = false;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    if (_guard.isLockedOut) {
      _errorText =
          'Terlalu banyak percobaan salah. Coba lagi dalam ${_guard.remainingLockoutSeconds} detik.';
      _startLockoutTimer();
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startLockoutTimer() {
    if (_lockoutTimer != null && _lockoutTimer!.isActive) return;
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_guard.isLockedOut) {
        timer.cancel();
        _lockoutTimer = null;
        setState(() {
          _errorText = null;
        });
      } else {
        setState(() {
          _errorText =
              'Terlalu banyak percobaan salah. Coba lagi dalam ${_guard.remainingLockoutSeconds} detik.';
        });
      }
    });
  }

  void _submitPasscode() {
    if (_isProcessing) return;
    if (_guard.isLockedOut) {
      _startLockoutTimer();
      setState(() {
        _errorText =
            'Terlalu banyak percobaan salah. Coba lagi dalam ${_guard.remainingLockoutSeconds} detik.';
      });
      return;
    }

    final ok = _guard.verifyPasscode(_controller.text);
    if (!ok) {
      if (_guard.isLockedOut) {
        _startLockoutTimer();
        setState(() {
          _errorText =
              'Terlalu banyak percobaan salah. Coba lagi dalam ${_guard.remainingLockoutSeconds} detik.';
        });
      } else {
        final sisa = 5 - _guard.failedAttempts;
        setState(() {
          _errorText = 'Kode darurat salah. Sisa percobaan: $sisa kali.';
        });
      }
      return;
    }

    _isProcessing = true;
    _lockoutTimer?.cancel();
    _lockoutTimer = null;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NetriRadius.lg),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.admin_panel_settings_rounded,
            color: NetriColors.stateDangerLight,
            size: 26,
          ),
          SizedBox(width: NetriSpacing.space2),
          Expanded(
            child: Text(
              'Keluar Darurat (Pengawas)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Masukkan 6 digit kode darurat pengawas untuk memutus Sematkan Aplikasi dan mengakhiri penguncian layar.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: NetriSpacing.space3),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              autofocus: true,
              maxLength: 6,
              enabled: !_guard.isLockedOut && !_isProcessing,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onSubmitted: (_) => _submitPasscode(),
              decoration: InputDecoration(
                hintText: '6 digit kode pengawas',
                prefixIcon: const Icon(Icons.vpn_key_rounded),
                errorText: _errorText,
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: NetriColors.stateDangerLight,
            foregroundColor: Colors.white,
          ),
          onPressed: (_guard.isLockedOut || _isProcessing)
              ? null
              : _submitPasscode,
          icon: const Icon(Icons.lock_open_rounded, size: 18),
          label: const Text('Buka Kunci & Keluar'),
        ),
      ],
    );
  }
}

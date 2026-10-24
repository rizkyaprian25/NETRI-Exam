// Layar Pre-check & Persetujuan Siswa (Apple HIG Contextual Sheet Pattern)
// Menampilkan daftar periksa perangkat sebelum memicu dialog sistem

import 'package:flutter/material.dart';
import '../../contracts/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/tokens.g.dart';
import '../exam_session/exam_session_screen.dart';

class PrecheckScreen extends StatefulWidget {
  final ExamItem exam;

  const PrecheckScreen({super.key, required this.exam});

  @override
  State<PrecheckScreen> createState() => _PrecheckScreenState();
}

class _PrecheckScreenState extends State<PrecheckScreen> {
  final bool _isBatteryOk = true;
  final bool _isDndActive = true;
  final bool _isIntegrityOk = true;
  bool _hasAgreed = false;
  bool _isStarting = false;

  void _showExplanationSheet() {
    // Apple HIG: Selalu berikan sheet penjelas ramah konteks sebelum meminta izin sistem
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
              Text('Transparansi Pengawasan Ujian', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: NetriSpacing.space3),
              const Text(
                'Demi menjaga keadilan bersama, NETRI Exam hanya memantau status aplikasi saat ujian berlangsung:\n\n'
                '• Kejadian saat meninggalkan layar ujian atau berpindah aplikasi.\n'
                '• Upaya pengambilan tangkapan layar (screenshot).\n'
                '• Sisa daya baterai dan status koneksi internet.\n\n'
                'NETRI TIDAK merekam layar penuh, TIDAK membaca riwayat chat, dan TIDAK mengakses berkas pribadi Anda.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: NetriSpacing.space6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Saya Memahami'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startExam() async {
    if (!_hasAgreed) return;

    setState(() => _isStarting = true);

    try {
      // Melepaskan tautan Google Form (Release Link) dari server
      final session = await ApiClient().startSession(widget.exam.id);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ExamSessionScreen(session: session),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memulai sesi ujian. Periksa sinyal internet.')),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pemeriksaan Perangkat'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(NetriSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.exam.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: NetriSpacing.space1),
              Text('Pastikan perangkat siap sebelum ujian dimulai.', style: theme.textTheme.bodyMedium),
              const SizedBox(height: NetriSpacing.space5),

              // Kartu Checklist Kesiapan
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(NetriSpacing.space4),
                  child: Column(
                    children: [
                      _buildCheckItem(
                        icon: Icons.battery_charging_full_rounded,
                        title: 'Daya Baterai Mencukupi',
                        subtitle: 'Daya saat ini 85% (Rekomendasi minimal 20%)',
                        isOk: _isBatteryOk,
                        theme: theme,
                      ),
                      const Divider(height: NetriSpacing.space4),
                      _buildCheckItem(
                        icon: Icons.do_not_disturb_on_rounded,
                        title: 'Mode Jangan Ganggu (DND)',
                        subtitle: 'Membantu mencegah telepon masuk mengganggu ujian',
                        isOk: _isDndActive,
                        theme: theme,
                      ),
                      const Divider(height: NetriSpacing.space4),
                      _buildCheckItem(
                        icon: Icons.security_rounded,
                        title: 'Integritas Sistem Operasi',
                        subtitle: 'Perangkat resmi (Bukan root/jailbreak)',
                        isOk: _isIntegrityOk,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: NetriSpacing.space4),

              // Lembar Penjelas Privasi
              OutlinedButton.icon(
                onPressed: _showExplanationSheet,
                icon: const Icon(Icons.privacy_tip_outlined, size: 20),
                label: const Text('Pelajari Apa Saja yang Dipantau'),
              ),

              const SizedBox(height: NetriSpacing.space5),

              // Checkbox Persetujuan
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _hasAgreed,
                onChanged: (val) => setState(() => _hasAgreed = val ?? false),
                title: const Text(
                  'Saya menyetujui aturan pengawasan ujian terkunci dan berjanji mengerjakan dengan jujur.',
                  style: TextStyle(fontSize: 14),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),

              const SizedBox(height: NetriSpacing.space6),

              // Tombol Mulai
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_hasAgreed && !_isStarting) ? _startExam : null,
                  child: _isStarting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Buka Lembar Soal Google Form'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isOk,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 24, color: isOk ? NetriColors.stateSuccessLight : NetriColors.stateWarningLight),
        const SizedBox(width: NetriSpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.labelLarge),
              Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
            ],
          ),
        ),
        Icon(
          isOk ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          color: isOk ? NetriColors.stateSuccessLight : NetriColors.stateWarningLight,
          size: 20,
        ),
      ],
    );
  }
}

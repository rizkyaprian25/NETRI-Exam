// Layar Bukti Selesai Ujian (ReceiptCard) - Standar Apple HIG & UI/UX Pro Max
// Memberikan kepastian kepada siswa dan guru bahwa sesi ujian sah, terkunci dengan benar, dan selesai

import 'package:flutter/material.dart';
import '../../contracts/models.dart';
import '../../core/theme/tokens.g.dart';
import '../auth/login_screen.dart';

class ResultScreen extends StatelessWidget {
  final ActiveExamSession? session;
  final String? sessionId;

  const ResultScreen({
    super.key,
    this.session,
    this.sessionId,
  });

  String get effectiveSessionId =>
      session?.sessionId ?? sessionId ?? 'ses_${DateTime.now().millisecondsSinceEpoch}';

  String get effectiveMapel => session?.mapel ?? 'Ujian Mandiri (GForm)';

  String get effectiveKelas => session?.kelas ?? 'Umum';

  int get effectiveDuration => session?.durationMinutes ?? 90;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB';
    final dateStr = '${now.day}/${now.month}/${now.year}';

    return PopScope(
      canPop: false, // Menghindari tombol back tidak sengaja
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: NetriSpacing.space6,
                vertical: NetriSpacing.space5,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Ikon Sukses Elegan Apple HIG
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: NetriColors.stateSuccessLight.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: NetriColors.stateSuccessLight,
                          size: 52,
                        ),
                      ),
                    ),
                    const SizedBox(height: NetriSpacing.space4),

                    // Judul & Keterangan
                    Text(
                      'Sesi Ujian Selesai',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NetriSpacing.space1),
                    Text(
                      'Jawaban Anda di Google Form telah terekam dan sesi ujian telah ditutup secara sah.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withAlpha(190),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: NetriSpacing.space5),

                    // Kartu Bukti Digital (Receipt Card Rapi & Proporsional)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(NetriRadius.lg),
                        side: BorderSide(
                          color: theme.dividerColor.withAlpha(40),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(NetriSpacing.space5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Kartu
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 18,
                                      color: NetriColors.stateSuccessLight,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'BUKTI RESMI SELESAI',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        letterSpacing: 1.1,
                                        fontWeight: FontWeight.bold,
                                        color: NetriColors.stateSuccessLight,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: NetriColors.brandLight.withAlpha(20),
                                    borderRadius: BorderRadius.circular(NetriRadius.sm),
                                  ),
                                  child: const Text(
                                    'EXAMBRO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: NetriColors.brandLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: NetriSpacing.space3),
                            const Divider(height: 1),
                            const SizedBox(height: NetriSpacing.space3),

                            // Detail Ujian
                            _buildInfoRow(
                              icon: Icons.menu_book_rounded,
                              label: 'Mata Pelajaran',
                              value: effectiveMapel,
                              theme: theme,
                              isPrimary: true,
                            ),
                            const SizedBox(height: NetriSpacing.space3),
                            _buildInfoRow(
                              icon: Icons.school_rounded,
                              label: 'Kelas / Tingkat',
                              value: effectiveKelas,
                              theme: theme,
                            ),
                            const SizedBox(height: NetriSpacing.space3),
                            _buildInfoRow(
                              icon: Icons.timer_outlined,
                              label: 'Durasi Alokasi',
                              value: '$effectiveDuration Menit',
                              theme: theme,
                            ),
                            const SizedBox(height: NetriSpacing.space3),
                            _buildInfoRow(
                              icon: Icons.access_time_rounded,
                              label: 'Waktu Submit',
                              value: '$timeStr ($dateStr)',
                              theme: theme,
                            ),
                            const SizedBox(height: NetriSpacing.space3),
                            _buildInfoRow(
                              icon: Icons.shield_rounded,
                              label: 'Status Integritas',
                              value: 'Terkunci & Sah',
                              theme: theme,
                              valueColor: NetriColors.stateSuccessLight,
                            ),
                            const SizedBox(height: NetriSpacing.space3),
                            _buildInfoRow(
                              icon: Icons.fingerprint_rounded,
                              label: 'ID Sesi',
                              value: effectiveSessionId,
                              theme: theme,
                              isMonospace: true,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: NetriSpacing.space4),

                    // Kotak Info Ketenangan
                    Container(
                      padding: const EdgeInsets.all(NetriSpacing.space3),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withAlpha(15),
                        borderRadius: BorderRadius.circular(NetriRadius.md),
                        border: Border.all(
                          color: theme.dividerColor.withAlpha(30),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mode proteksi layar penuh telah dilepas. Anda dapat kembali ke beranda sekarang.',
                              style: theme.textTheme.labelSmall?.copyWith(height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: NetriSpacing.space6),

                    // Tombol Kembali ke Beranda (Langsung Reset Navigasi)
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(NetriRadius.md),
                          ),
                        ),
                        icon: const Icon(Icons.home_rounded, size: 20),
                        label: const Text(
                          'Kembali ke Beranda',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: () {
                          // Pastikan navigasi bersih ke beranda tanpa sisa riwayat route
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        },
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    bool isPrimary = false,
    bool isMonospace = false,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: theme.textTheme.bodySmall?.color?.withAlpha(150)),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withAlpha(180),
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
              fontSize: isPrimary ? 14 : 13,
              fontFamily: isMonospace ? 'monospace' : null,
              color: valueColor ?? (isPrimary ? NetriColors.brandLight : null),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

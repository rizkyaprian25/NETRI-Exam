// Layar Bukti Selesai Ujian (ReceiptCard) - Apple HIG Calm Design
// Memberikan kepastian kepada siswa bahwa sesi ujian telah sah dan tercatat di server

import 'package:flutter/material.dart';
import '../../core/theme/tokens.g.dart';

class ResultScreen extends StatelessWidget {
  final String sessionId;

  const ResultScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(NetriSpacing.space6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ikon Sukses
                Container(
                  padding: const EdgeInsets.all(NetriSpacing.space5),
                  decoration: BoxDecoration(
                    color: NetriColors.stateSuccessLight.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: NetriColors.stateSuccessLight,
                    size: 64,
                  ),
                ),
                const SizedBox(height: NetriSpacing.space5),

                Text(
                  'Ujian Berhasil Diselesaikan',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: NetriSpacing.space2),
                Text(
                  'Jawaban Anda di Google Form telah terekam dan sesi ujian di server telah ditutup secara sah.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: NetriSpacing.space6),

                // Kartu Bukti Digital (Receipt Card)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(NetriSpacing.space4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'BUKTI SELESAI',
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(Icons.verified_outlined, size: 18, color: NetriColors.stateSuccessLight),
                          ],
                        ),
                        const Divider(height: NetriSpacing.space4),
                        _buildRow('ID Sesi', sessionId, theme),
                        const SizedBox(height: NetriSpacing.space2),
                        _buildRow('Waktu Submit', '${now.hour}:${now.minute.toString().padLeft(2, '0')} WIB', theme),
                        const SizedBox(height: NetriSpacing.space2),
                        _buildRow('Status Verifikasi', 'Sah & Tersegel Server', theme),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: NetriSpacing.space8),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Text('Kembali ke Beranda'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ExamBar: Bar Tipis Status Ujian (Apple HIG & UI/UX Pro Max)
// Menampilkan status koneksi nyata, status mode terkunci, muat ulang soal, dan keluar darurat pengawas

import 'package:flutter/material.dart';
import '../../core/theme/tokens.g.dart';

enum ConnectionStatus {
  connected,
  reconnecting,
  offline,
}

class ExamBar extends StatelessWidget implements PreferredSizeWidget {
  final ConnectionStatus connectionStatus;
  final VoidCallback? onReloadForm;
  final VoidCallback onEmergencyExit;

  const ExamBar({
    super.key,
    required this.connectionStatus,
    this.onReloadForm,
    required this.onEmergencyExit,
  });

  @override
  Size get preferredSize => const Size.fromHeight(NetriExamMetrics.examBarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: NetriSpacing.space2),
      decoration: BoxDecoration(
        color: isDark ? NetriColors.surfaceDark : NetriColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? NetriColors.borderDark : NetriColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Status Koneksi Nyata (StatusPill)
            _buildStatusPill(context),

            const SizedBox(width: 6),

            // Indikator Status Ujian Terkunci (dibungkus Flexible agar aman di layar sempit)
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: NetriColors.brandLight.withAlpha(20),
                  borderRadius: BorderRadius.circular(NetriRadius.full),
                  border: Border.all(color: NetriColors.brandLight.withAlpha(50)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 14, color: NetriColors.brandLight),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Exam NETRI (Terkunci)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: NetriColors.brandLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Aksi Muat Ulang Soal & Keluar Darurat Pengawas (area sentuh minimal 44x44)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onReloadForm != null)
                  IconButton(
                    tooltip: 'Muat Ulang Soal',
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    onPressed: onReloadForm,
                    constraints: const BoxConstraints(
                      minWidth: NetriExamMetrics.minTouchTarget,
                      minHeight: NetriExamMetrics.minTouchTarget,
                    ),
                  ),
                IconButton(
                  tooltip: 'Keluar Darurat (Pengawas)',
                  icon: const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 22,
                    color: NetriColors.stateDangerLight,
                  ),
                  onPressed: onEmergencyExit,
                  constraints: const BoxConstraints(
                    minWidth: NetriExamMetrics.minTouchTarget,
                    minHeight: NetriExamMetrics.minTouchTarget,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context) {
    Color dotColor;
    String label;

    switch (connectionStatus) {
      case ConnectionStatus.connected:
        dotColor = NetriColors.stateSuccessLight;
        label = 'Terhubung';
        break;
      case ConnectionStatus.reconnecting:
        dotColor = NetriColors.stateWarningLight;
        label = 'Menyambung';
        break;
      case ConnectionStatus.offline:
        dotColor = NetriColors.stateDangerLight;
        label = 'Offline';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dotColor.withAlpha(30),
        borderRadius: BorderRadius.circular(NetriRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }
}

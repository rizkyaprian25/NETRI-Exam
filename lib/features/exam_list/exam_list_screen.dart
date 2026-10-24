// Layar Daftar Ujian Siswa (ExamListScreen) - Apple HIG & UI/UX Pro Max
// Menyediakan 5 keadaan komponen: default, loading, kosong, error, dan nonaktif

import 'package:flutter/material.dart';
import '../../contracts/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/tokens.g.dart';
import '../precheck/precheck_screen.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  List<ExamItem>? _exams;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchExams();
  }

  Future<void> _fetchExams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final exams = await ApiClient().getAvailableExams();
      if (!mounted) return;
      setState(() {
        _exams = exams;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat daftar ujian. Periksa koneksi internet.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Ujian Saya'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchExams,
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // 1. Keadaan Loading
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Keadaan Error
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(NetriSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: NetriColors.stateDangerLight),
              const SizedBox(height: NetriSpacing.space3),
              Text(_errorMessage!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: NetriSpacing.space4),
              ElevatedButton.icon(
                onPressed: _fetchExams,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Keadaan Kosong (Empty State)
    if (_exams == null || _exams!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(NetriSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_available_rounded, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: NetriSpacing.space3),
              Text('Tidak Ada Ujian Aktif', style: theme.textTheme.titleMedium),
              const SizedBox(height: NetriSpacing.space1),
              Text(
                'Saat ini Anda tidak memiliki jadwal ujian yang sedang berlangsung.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 4. Keadaan Default (Daftar Kartu Ujian)
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: NetriSpacing.space3),
      itemCount: _exams!.length,
      itemBuilder: (context, index) {
        final exam = _exams![index];
        final now = DateTime.now();
        final isAvailable = now.isAfter(exam.startTime) && now.isBefore(exam.endTime);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(NetriSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? NetriColors.stateSuccessLight.withAlpha(20)
                            : Colors.grey.withAlpha(20),
                        borderRadius: BorderRadius.circular(NetriRadius.sm),
                      ),
                      child: Text(
                        isAvailable ? 'SIAP DIKERJAKAN' : 'TERJADWAL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isAvailable ? NetriColors.stateSuccessLight : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Text(
                      '${exam.durationMinutes} Menit',
                      style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: NetriSpacing.space2),
                Text(exam.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: NetriSpacing.space1),
                Text('Mata Pelajaran: ${exam.subject}', style: theme.textTheme.bodyMedium),
                const SizedBox(height: NetriSpacing.space4),

                // Tombol Aksi
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isAvailable
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PrecheckScreen(exam: exam),
                              ),
                            );
                          }
                        : null, // 5. Keadaan Nonaktif (Disabled State) jika belum waktunya
                    child: Text(isAvailable ? 'Mulai Ujian' : 'Belum Dibuka'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

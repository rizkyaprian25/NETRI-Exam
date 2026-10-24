// Layar Beranda Exambro (Scan QR / Input Tautan Form & Login Sekolah)
// Mendukung alur instan khas Exambro (Link/QR) dan alur akun sekolah terpusat

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../contracts/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/tokens.g.dart';
import '../exam_list/exam_list_screen.dart';
import '../exam_session/exam_session_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Controller Mode Tautan / QR Form Langsung
  final TextEditingController _urlController = TextEditingController(
    text: 'https://docs.google.com/forms/d/e/1FAIpQLScX_SAMPLE_FORM/viewform?embedded=true',
  );

  // Controller Mode Akun Sekolah
  final TextEditingController _nisController = TextEditingController(text: '20261001');
  final TextEditingController _passwordController = TextEditingController(text: '123456');

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _nisController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Masuk langsung via Tautan Google Form (Alur Utama Exambro)
  void _startDirectExam() {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _errorMessage = 'Masukkan URL Google Form atau tautan ujian.');
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (!rawUrl.contains('google.com') && !rawUrl.contains('forms.gle'))) {
      setState(() => _errorMessage = 'URL harus berupa tautan Google Forms yang sah.');
      return;
    }

    // Tampilkan panduan persiapan sistem (khusus iOS & Android)
    _showLockdownPreparationDialog(
      onConfirmed: () {
        final now = DateTime.now();
        final session = ActiveExamSession(
          sessionId: 'ses_direct_${now.millisecondsSinceEpoch}',
          formUrl: rawUrl,
          deadlineAt: now.add(const Duration(minutes: 90)),
          serverCurrentTime: now,
          allowedDomains: const [
            'docs.google.com',
            'forms.google.com',
            'google.com',
            'gstatic.com',
            'googleusercontent.com',
            'forms.gle',
          ],
        );

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExamSessionScreen(session: session),
          ),
        );
      },
    );
  }

  /// Masuk dengan Akun Sekolah (NIS)
  Future<void> _handleSchoolLogin() async {
    final nis = _nisController.text.trim();
    final password = _passwordController.text.trim();

    if (nis.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Harap isi NIS dan Kata Sandi.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiClient().login(
        nis: nis,
        password: password,
        deviceId: 'device_${nis}_token',
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ExamListScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Gagal masuk. Periksa kembali NIS atau hubungi proctor.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Dialog persiapan penguncian (Platform Specific: Android Immersive & iOS Guided Access)
  void _showLockdownPreparationDialog({required VoidCallback onConfirmed}) {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NetriColors.brandLight.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_rounded, color: NetriColors.brandLight, size: 28),
                  ),
                  const SizedBox(width: NetriSpacing.space3),
                  Expanded(
                    child: Text(
                      'Mode Ujian Terkunci Exambro',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NetriSpacing.space4),

              if (isIos) ...[
                const Text(
                  'Petunjuk Pengguna iPhone / iPad (iOS):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  '1. Layar ujian akan terkunci secara otomatis.\n'
                  '2. Untuk mengunci tombol home dan notifikasi secara penuh, aktifkan Akses Terpandu (Guided Access) dengan menekan tombol samping 3 kali.\n'
                  '3. Mengambil screenshot atau berpindah aplikasi akan seketika mengunci ujian dan membutuhkan PIN Pengawas.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ] else ...[
                const Text(
                  'Petunjuk Pengguna Android:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  '1. Aplikasi akan masuk ke mode layar penuh (Immersive Kiosk).\n'
                  '2. Fitur tangkapan layar (screenshot) dan rekam layar dinonaktifkan.\n'
                  '3. Menekan tombol Home atau berpindah aplikasi akan seketika mengunci sesi ujian dan memerlukan PIN Pengawas.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],

              const SizedBox(height: NetriSpacing.space6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onConfirmed();
                  },
                  child: const Text('Saya Siap & Kunci Layar Ujian'),
                ),
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(NetriSpacing.space6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Brand Exambro
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: NetriColors.brandLight.withAlpha(25),
                        borderRadius: BorderRadius.circular(NetriRadius.lg),
                      ),
                      child: const Icon(
                        Icons.lock_person_rounded,
                        size: 36,
                        color: NetriColors.brandLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: NetriSpacing.space3),

                  const Text(
                    'EXAMBRO',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: NetriColors.stateSuccessLight.withAlpha(25),
                          borderRadius: BorderRadius.circular(NetriRadius.sm),
                        ),
                        child: const Text(
                          'Android & iOS Compatible',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: NetriColors.stateSuccessLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NetriSpacing.space6),

                  // Tab Pilihan: Tautan Langsung vs Akun Sekolah
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(25),
                      borderRadius: BorderRadius.circular(NetriRadius.md),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Tautan / QR Form'),
                        Tab(text: 'Akun Sekolah'),
                      ],
                    ),
                  ),
                  const SizedBox(height: NetriSpacing.space4),

                  // Pesan Kesalahan jika ada
                  if (_errorMessage != null) ...[
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
                    const SizedBox(height: NetriSpacing.space4),
                  ],

                  // Konten Tab Bar View
                  SizedBox(
                    height: 230,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Alur Tautan Google Form Langsung (Khas Exambro)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('URL Google Form Ujian', style: theme.textTheme.labelLarge),
                            const SizedBox(height: NetriSpacing.space1),
                            TextField(
                              controller: _urlController,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                hintText: 'https://docs.google.com/forms/...',
                                prefixIcon: Icon(Icons.link_rounded),
                              ),
                            ),
                            const SizedBox(height: NetriSpacing.space4),
                            ElevatedButton.icon(
                              onPressed: _startDirectExam,
                              icon: const Icon(Icons.lock_outline_rounded, size: 20),
                              label: const Text('Buka Ujian Terkunci'),
                            ),
                            const SizedBox(height: NetriSpacing.space2),
                            Text(
                              'Tempel link soal yang dibagikan guru untuk langsung mulai.',
                              style: theme.textTheme.labelSmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),

                        // Tab 2: Alur Akun Siswa Terjadwal
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _nisController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Nomor Induk Siswa (NIS)',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: NetriSpacing.space3),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: 'Kata Sandi',
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: NetriSpacing.space4),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _handleSchoolLogin,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Masuk Jadwal Sekolah'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: NetriSpacing.space3),
                  Text(
                    'Didukung di semua perangkat Android 10+ dan iOS 16+',
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

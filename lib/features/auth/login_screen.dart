// Layar Beranda Exambro (Tab 1: Siswa / Ujian, Tab 2: Admin & Custom PIN GForm)
// Menangani URL form default kosong, manajemen Mapel/Kelas/PIN di tab Admin,
// dan pencocokan otomatis PIN pengawas ketika link GForm diisi oleh siswa.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../contracts/models.dart';
import '../../core/storage/admin_config_store.dart';
import '../../core/theme/tokens.g.dart';
import '../exam_session/exam_session_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Controller Tab 1: Siswa (Default kosong agar tidak perlu menghapus)
  final TextEditingController _urlController = TextEditingController();

  // Status autentikasi PIN Guru / Admin
  static const String _masterAdminPin = '20268237';
  bool _isAdminAuthenticated = false;
  final TextEditingController _adminPinInputController = TextEditingController();
  String? _adminPinErrorMessage;

  // Daftar konfigurasi ujian tersimpan dari Admin
  List<AdminExamConfig> _adminConfigs = [];
  AdminExamConfig? _detectedConfig;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAdminConfigs();

    // Deteksi otomatis apakah URL yang diketik/ditempel siswa cocok dengan data Admin
    _urlController.addListener(_checkUrlMatch);
  }

  @override
  void dispose() {
    _urlController.removeListener(_checkUrlMatch);
    _tabController.dispose();
    _urlController.dispose();
    _adminPinInputController.dispose();
    super.dispose();
  }

  void _verifyAdminPin() {
    final input = _adminPinInputController.text.trim();
    if (input == _masterAdminPin) {
      setState(() {
        _isAdminAuthenticated = true;
        _adminPinErrorMessage = null;
        _adminPinInputController.clear();
      });
    } else {
      setState(() {
        _adminPinErrorMessage = 'PIN Guru salah! Silakan coba lagi.';
      });
    }
  }

  void _lockAdmin() {
    setState(() {
      _isAdminAuthenticated = false;
      _adminPinErrorMessage = null;
      _adminPinInputController.clear();
    });
  }

  Future<void> _loadAdminConfigs() async {
    final configs = await AdminConfigStore().getAllConfigs();
    if (mounted) {
      setState(() {
        _adminConfigs = configs;
      });
      _checkUrlMatch();
    }
  }

  Future<void> _checkUrlMatch() async {
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      if (_detectedConfig != null) {
        setState(() => _detectedConfig = null);
      }
      return;
    }

    final matched = await AdminConfigStore().findConfigByUrl(text);
    if (mounted && _detectedConfig?.id != matched?.id) {
      setState(() {
        _detectedConfig = matched;
      });
    }
  }

  /// Memulai ujian terkunci oleh siswa
  void _startStudentExam() {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _errorMessage = 'Harap masukkan atau tempel link Google Form ujian.');
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (!rawUrl.contains('google.com') && !rawUrl.contains('forms.gle'))) {
      setState(() => _errorMessage = 'URL harus berupa tautan Google Forms yang sah.');
      return;
    }

    setState(() => _errorMessage = null);

    // Ambil PIN Pengawas khusus jika link cocok dengan konfigurasi Admin, atau fallback '1234'
    final proctorPin = _detectedConfig?.pinPengawas.trim().isNotEmpty == true
        ? _detectedConfig!.pinPengawas.trim()
        : '1234';

    _showLockdownPreparationDialog(
      onConfirmed: () {
        final now = DateTime.now();
        final durationMinutes = _detectedConfig?.durasiMenit ?? 90;
        final session = ActiveExamSession(
          sessionId: 'ses_${now.millisecondsSinceEpoch}',
          formUrl: rawUrl,
          deadlineAt: now.add(Duration(minutes: durationMinutes)),
          durationMinutes: durationMinutes,
          serverCurrentTime: now,
          allowedDomains: const [
            'docs.google.com',
            'forms.google.com',
            'google.com',
            'gstatic.com',
            'googleusercontent.com',
            'forms.gle',
          ],
          proctorPin: proctorPin,
          mapel: _detectedConfig != null
              ? '${_detectedConfig!.tipeUjian != null && _detectedConfig!.tipeUjian!.isNotEmpty ? "[${_detectedConfig!.tipeUjian}] " : ""}${_detectedConfig!.mapel}'
              : null,
          kelas: _detectedConfig?.kelas,
        );

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExamSessionScreen(session: session),
          ),
        );
      },
    );
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mode Ujian Terkunci Exambro',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (_detectedConfig != null)
                          Text(
                            '${_detectedConfig!.tipeUjian != null && _detectedConfig!.tipeUjian!.isNotEmpty ? "[${_detectedConfig!.tipeUjian}] " : ""}${_detectedConfig!.mapel} (${_detectedConfig!.kelas}) • ⏱️ ${_detectedConfig!.durasiMenit} Menit',
                            style: const TextStyle(fontSize: 13, color: NetriColors.brandLight, fontWeight: FontWeight.w600),
                          ),
                      ],
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
                  '2. Untuk mengunci tombol home dan notifikasi, aktifkan Akses Terpandu (Guided Access) dengan menekan tombol samping 3 kali.\n'
                  '3. Berpindah aplikasi akan seketika mengunci ujian dan membutuhkan PIN Pengawas.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ] else ...[
                const Text(
                  'Petunjuk Pengguna Android:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  '1. Aplikasi akan masuk ke mode layar penuh Kiosk.\n'
                  '2. Fitur tangkapan layar (screenshot) dan rekam layar dinonaktifkan.\n'
                  '3. Berpindah aplikasi akan mengunci sesi ujian dan memerlukan PIN Pengawas.',
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

  /// Dialog Tambah Form Ujian Baru oleh Admin
  void _showAddExamDialog({AdminExamConfig? editConfig}) {
    String selectedTipe = editConfig?.tipeUjian ?? 'UAS';
    final mapelController = TextEditingController(text: editConfig?.mapel ?? '');
    final kelasController = TextEditingController(text: editConfig?.kelas ?? '');
    final pinController = TextEditingController(text: editConfig?.pinPengawas ?? '');
    final linkController = TextEditingController(text: editConfig?.linkGForm ?? '');
    final durasiController = TextEditingController(
      text: editConfig != null ? editConfig.durasiMenit.toString() : '90',
    );
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(editConfig == null ? '+ Tambah Form Ujian' : 'Edit Form Ujian'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (dialogError != null) ...[
                    Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    const SizedBox(height: 8),
                  ],

                  // Pilihan Tipe Ujian (UAS / UTS / dsb)
                  const Text(
                    'Tipe Ujian (UAS / UTS):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: ['UAS', 'UTS', 'Ulangan Harian', 'Ujian Sekolah', 'Latihan'].map((tipe) {
                      final isSel = selectedTipe == tipe;
                      return ChoiceChip(
                        label: Text(
                          tipe,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSel ? Colors.white : null,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: isSel,
                        selectedColor: NetriColors.brandLight,
                        visualDensity: VisualDensity.compact,
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() => selectedTipe = tipe);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: mapelController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Mata Pelajaran (Mapel)',
                      hintText: 'Contoh: Matematika Wajib',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: kelasController,
                    decoration: const InputDecoration(
                      labelText: 'Kelas / Tingkat',
                      hintText: 'Contoh: X IPA 1 / XII RPL',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'PIN Pengawas (Buka Kunci)',
                      hintText: 'Contoh: 7890',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: durasiController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Durasi Ujian (Menit)',
                      hintText: 'Contoh: 60, 90, 120',
                      suffixText: 'Menit',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [30, 45, 60, 90, 120].map((mins) {
                      return ActionChip(
                        label: Text('$mins mnt', style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setDialogState(() {
                            durasiController.text = mins.toString();
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: linkController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Link Google Form Ujian',
                      hintText: 'https://forms.gle/...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final mapel = mapelController.text.trim();
                  final kelas = kelasController.text.trim();
                  final pin = pinController.text.trim();
                  final link = linkController.text.trim();
                  final durasiText = durasiController.text.trim();
                  final durasi = int.tryParse(durasiText) ?? 90;

                  if (mapel.isEmpty || kelas.isEmpty || pin.isEmpty || link.isEmpty) {
                    setDialogState(() => dialogError = 'Semua kolom wajib diisi!');
                    return;
                  }

                  final newConfig = AdminExamConfig(
                    id: editConfig?.id ?? 'exam_${DateTime.now().millisecondsSinceEpoch}',
                    mapel: mapel,
                    kelas: kelas,
                    pinPengawas: pin,
                    linkGForm: link,
                    durasiMenit: durasi > 0 ? durasi : 90,
                    tipeUjian: selectedTipe,
                  );

                  await AdminConfigStore().saveConfig(newConfig);
                  await _loadAdminConfigs();

                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
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
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Brand Header Resmi NETRI Exam
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 140, maxWidth: 220),
                      padding: const EdgeInsets.symmetric(horizontal: NetriSpacing.space3),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(NetriRadius.md),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: NetriSpacing.space3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: NetriColors.stateSuccessLight.withAlpha(20),
                          borderRadius: BorderRadius.circular(NetriRadius.full),
                          border: Border.all(
                            color: NetriColors.stateSuccessLight.withAlpha(60),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.verified_rounded, size: 13, color: NetriColors.stateSuccessLight),
                            SizedBox(width: 5),
                            Text(
                              'Exambro Android & iOS Mode',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: NetriColors.stateSuccessLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NetriSpacing.space5),

                  // Tab Pilihan: Ujian (Siswa) vs Admin (Guru)
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
                        Tab(text: 'Ujian (Siswa)'),
                        Tab(text: 'Admin (Guru)'),
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

                  // Konten Tab
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      return _tabController.index == 0
                          ? _buildStudentExamTab(theme)
                          : _buildAdminTab(theme);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// TAB 1: SISWA (Input Link Kosong & Deteksi Otomatis PIN)
  Widget _buildStudentExamTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tautan Google Form Ujian', style: theme.textTheme.labelLarge),
        const SizedBox(height: NetriSpacing.space1),
        TextField(
          controller: _urlController,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'Tempel link form ujian di sini...',
            prefixIcon: const Icon(Icons.link_rounded),
            suffixIcon: _urlController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => _urlController.clear(),
                  )
                : null,
          ),
        ),
        const SizedBox(height: NetriSpacing.space2),

        // Indikator Deteksi Otomatis Jika Link Cocok dengan Data Admin
        if (_detectedConfig != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: NetriColors.stateSuccessLight.withAlpha(20),
              borderRadius: BorderRadius.circular(NetriRadius.sm),
              border: Border.all(color: NetriColors.stateSuccessLight.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: NetriColors.stateSuccessLight, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Terverifikasi: ${_detectedConfig!.tipeUjian != null && _detectedConfig!.tipeUjian!.isNotEmpty ? "[${_detectedConfig!.tipeUjian}] " : ""}${_detectedConfig!.mapel} - ${_detectedConfig!.kelas} • ⏱️ ${_detectedConfig!.durasiMenit} Menit (PIN Pengawas Terpasang)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: NetriColors.stateSuccessLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NetriSpacing.space3),
        ],

        // Shortcut Daftar Ujian yang Dikonfigurasi Admin (Bisa langsung klik)
        if (_adminConfigs.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text('Atau pilih ujian yang terdaftar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _adminConfigs.map((cfg) {
              final isSelected = _detectedConfig?.id == cfg.id;
              final prefix = cfg.tipeUjian != null && cfg.tipeUjian!.isNotEmpty ? '[${cfg.tipeUjian}] ' : '';
              return ActionChip(
                avatar: Icon(
                  isSelected ? Icons.check_circle : Icons.school_outlined,
                  size: 16,
                  color: isSelected ? Colors.white : NetriColors.brandLight,
                ),
                backgroundColor: isSelected ? NetriColors.brandLight : null,
                label: Text(
                  '$prefix${cfg.mapel} (${cfg.kelas})',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : null,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onPressed: () {
                  _urlController.text = cfg.linkGForm;
                },
              );
            }).toList(),
          ),
          const SizedBox(height: NetriSpacing.space3),
        ],

        const SizedBox(height: NetriSpacing.space2),
        ElevatedButton.icon(
          onPressed: _startStudentExam,
          icon: const Icon(Icons.lock_outline_rounded, size: 20),
          label: const Text('Buka Ujian Terkunci'),
        ),
        const SizedBox(height: NetriSpacing.space2),
        Text(
          'Tempelkan link Google Form dari guru untuk mulai mengerjakan.',
          style: theme.textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// TAB 2: ADMIN / GURU (Dilindungi Gerbang PIN Master)
  Widget _buildAdminTab(ThemeData theme) {
    if (!_isAdminAuthenticated) {
      return _buildAdminPinGate(theme);
    }
    return _buildAdminDashboard(theme);
  }

  /// Gerbang Login Khusus Guru / Admin Menggunakan PIN
  Widget _buildAdminPinGate(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(NetriSpacing.space5),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(NetriRadius.lg),
        border: Border.all(color: theme.dividerColor.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(NetriSpacing.space3),
              decoration: BoxDecoration(
                color: NetriColors.brandLight.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: NetriColors.brandLight,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: NetriSpacing.space3),
          Text(
            'Panel Khusus Guru',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Masukkan PIN Admin untuk mengelola formulir ujian, kelas, dan PIN pengawas.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NetriSpacing.space4),
          TextField(
            controller: _adminPinInputController,
            keyboardType: TextInputType.number,
            obscureText: true,
            textAlign: TextAlign.center,
            maxLength: 8,
            style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '• • • • • • • •',
              hintStyle: const TextStyle(letterSpacing: 4),
              counterText: '',
              prefixIcon: const Icon(Icons.password_rounded, size: 20),
              errorText: _adminPinErrorMessage,
            ),
            onSubmitted: (_) => _verifyAdminPin(),
          ),
          const SizedBox(height: NetriSpacing.space4),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _verifyAdminPin,
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text(
                'Buka Panel Guru',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dashboard Pengelolaan Formulir Ujian oleh Guru
  Widget _buildAdminDashboard(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Panel Guru',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: NetriColors.stateSuccessLight.withAlpha(25),
                        borderRadius: BorderRadius.circular(NetriRadius.sm),
                      ),
                      child: const Text(
                        'Terbuka',
                        style: TextStyle(
                          fontSize: 10,
                          color: NetriColors.stateSuccessLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text('Kelola Mapel UAS/UTS, Kelas, Waktu & PIN', style: theme.textTheme.labelSmall),
              ],
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Kunci Kembali Panel',
                  icon: const Icon(Icons.lock_outline_rounded, size: 20, color: Colors.grey),
                  onPressed: _lockAdmin,
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: () => _showAddExamDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('+ GForm', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: NetriSpacing.space3),

        if (_adminConfigs.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(NetriSpacing.space5),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(15),
              borderRadius: BorderRadius.circular(NetriRadius.md),
              border: Border.all(color: Colors.grey.withAlpha(30)),
            ),
            child: Column(
              children: [
                Icon(Icons.assignment_outlined, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                const Text(
                  'Belum Ada Form Ujian',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Klik tombol "+ GForm" di atas untuk menambahkan Mapel UAS/UTS, Kelas, Durasi, PIN Pengawas, dan Link Form.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ] else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _adminConfigs.length,
            itemBuilder: (context, index) {
              final cfg = _adminConfigs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: NetriSpacing.space2),
                child: Padding(
                  padding: const EdgeInsets.all(NetriSpacing.space3),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: NetriColors.brandLight.withAlpha(20),
                          borderRadius: BorderRadius.circular(NetriRadius.sm),
                        ),
                        child: const Icon(Icons.assignment_rounded, color: NetriColors.brandLight, size: 22),
                      ),
                      const SizedBox(width: NetriSpacing.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (cfg.tipeUjian != null && cfg.tipeUjian!.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: NetriColors.brandLight.withAlpha(25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      cfg.tipeUjian!,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: NetriColors.brandLight,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    cfg.mapel,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kelas: ${cfg.kelas} • ⏱️ ${cfg.durasiMenit} Mnt • PIN: ${cfg.pinPengawas}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              cfg.linkGForm,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: NetriColors.brandLight),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Salin ke Layar Siswa',
                        icon: const Icon(Icons.play_circle_outline_rounded, size: 22, color: NetriColors.stateSuccessLight),
                        onPressed: () {
                          _urlController.text = cfg.linkGForm;
                          _tabController.animateTo(0);
                        },
                      ),
                      IconButton(
                        tooltip: 'Edit Ujian',
                        icon: const Icon(Icons.edit_outlined, size: 20, color: NetriColors.brandLight),
                        onPressed: () => _showAddExamDialog(editConfig: cfg),
                      ),
                      IconButton(
                        tooltip: 'Hapus',
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        onPressed: () async {
                          await AdminConfigStore().deleteConfig(cfg.id);
                          await _loadAdminConfigs();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

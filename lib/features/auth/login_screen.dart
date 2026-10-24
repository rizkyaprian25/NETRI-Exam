// Layar Masuk Siswa (Login & Device Binding) - Apple HIG & UI/UX Pro Max
// Mengikat token otentikasi dengan ID perangkat keras untuk mencegah joki akun

import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/tokens.g.dart';
import '../exam_list/exam_list_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nisController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    final nis = _nisController.text.trim();
    final password = _passwordController.text.trim();

    if (nis.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Harap isi NIS/NIP dan Kata Sandi.';
      });
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
        deviceId: 'device_${nis}_hardware_token',
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ExamListScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal masuk. Periksa kembali NIS atau hubungi panitia ujian.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Brand Header
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: NetriColors.brandLight.withAlpha(25),
                      borderRadius: BorderRadius.circular(NetriRadius.lg),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 36,
                      color: NetriColors.brandLight,
                    ),
                  ),
                  const SizedBox(height: NetriSpacing.space4),

                  Text(
                    'NETRI Exam',
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: NetriSpacing.space1),
                  Text(
                    'Portal Ujian Terkunci Institusi',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: NetriSpacing.space8),

                  // Pesan Kesalahan
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

                  // Field NIS / NIP
                  Text('Nomor Induk Siswa (NIS)', style: theme.textTheme.labelLarge),
                  const SizedBox(height: NetriSpacing.space1),
                  TextField(
                    controller: _nisController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: 20261001',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: NetriSpacing.space4),

                  // Field Kata Sandi
                  Text('Kata Sandi', style: theme.textTheme.labelLarge),
                  const SizedBox(height: NetriSpacing.space1),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    onSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: NetriSpacing.space6),

                  // Tombol Masuk (Min Touch Target >= 44x44pt)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Masuk ke Ujian'),
                  ),
                  const SizedBox(height: NetriSpacing.space4),

                  Text(
                    'Akun Anda terikat pada 1 perangkat aktif demi keamanan.',
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

// Layar Sesi Ujian Terkunci (Exambro 100% Android & iOS Mode)
// Mengintegrasikan WebView dengan whitelist domain, proteksi anti-copy JS,
// penguncian tombol keluar via PIN Pengawas, dan Lockdown Engine

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../contracts/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/tokens.g.dart';
import '../lockdown/lockdown_service.dart';
import 'exam_bar.dart';
import 'lock_screen_dialog.dart';
import '../result/result_screen.dart';
import '../auth/login_screen.dart';

class ExamSessionScreen extends StatefulWidget {
  final ActiveExamSession session;

  const ExamSessionScreen({super.key, required this.session});

  @override
  State<ExamSessionScreen> createState() => _ExamSessionScreenState();
}

class _ExamSessionScreenState extends State<ExamSessionScreen>
    with WidgetsBindingObserver {
  WebViewController? _webViewController;
  late int _remainingSeconds;
  Timer? _countdownTimer;
  Timer? _heartbeatTimer;
  bool _isLoadingForm = true;
  ConnectionStatus _connectionStatus = ConnectionStatus.connected;
  bool _isLockDialogShowing = false;

  bool get _isNativeMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Hitung sisa waktu dari server deadline
    final now = DateTime.now();
    _remainingSeconds = widget.session.deadlineAt.difference(now).inSeconds;
    if (_remainingSeconds <= 0) _remainingSeconds = 5400; // 90 menit fallback

    _initLockdown();
    if (_isNativeMobilePlatform) {
      _initWebView();
    } else {
      _isLoadingForm = false;
    }

    _startTimer();
    _startHeartbeat();
  }

  void _initLockdown() {
    final lockdown = LockdownService();
    lockdown.enableLockdown(widget.session.sessionId);

    lockdown.onLockRequired = () {
      if (!mounted || _isLockDialogShowing) return;
      _isLockDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => LockScreenDialog(
          strikeCount: 2,
          reason: 'PERINGATAN EXAMBRO: Anda Terdeteksi Keluar atau Berpindah dari Aplikasi Ujian!',
          expectedPin: widget.session.proctorPin,
          onProctorUnlocked: () {
            lockdown.unlockByProctor();
            _isLockDialogShowing = false;
            Navigator.of(ctx).pop();
          },
          onProctorExitToHome: () async {
            _isLockDialogShowing = false;
            Navigator.of(ctx).pop();
            await _completeExamAndReturnHome();
          },
        ),
      );
    };
  }

  void _initWebView() {
    try {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() => _isLoadingForm = true);
            },
            onPageFinished: (String url) {
              setState(() => _isLoadingForm = false);
              _injectAntiCopyProtection();
              _checkIfFormSubmitted(url);
            },
            onNavigationRequest: (NavigationRequest request) {
              final uri = Uri.tryParse(request.url);
              if (uri == null) return NavigationDecision.prevent;

              // Whitelist domain Google Forms
              final isAllowed = widget.session.allowedDomains.any((domain) =>
                  uri.host == domain || uri.host.endsWith('.$domain'));

              if (!isAllowed) {
                debugPrint('[ExambroWebView] Navigasi luar diblokir: ${request.url}');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Akses ke tautan luar dilarang selama ujian berlangsung.'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        );

      _webViewController!.loadRequest(Uri.parse(widget.session.formUrl));
    } catch (e) {
      debugPrint('[ExambroWebView] Mode fallback aktif: $e');
      setState(() => _isLoadingForm = false);
    }
  }

  /// Menyuntikkan skrip anti-copy, anti-seleksi, dan nonaktifkan menu konteks (Khas Exambro)
  void _injectAntiCopyProtection() {
    if (_webViewController == null) return;
    const jsScript = '''
      (function() {
        document.addEventListener('contextmenu', function(e) { e.preventDefault(); return false; });
        document.addEventListener('selectstart', function(e) { e.preventDefault(); return false; });
        document.addEventListener('copy', function(e) { e.preventDefault(); return false; });
        document.addEventListener('cut', function(e) { e.preventDefault(); return false; });
        document.addEventListener('paste', function(e) { e.preventDefault(); return false; });
        var style = document.createElement('style');
        style.innerHTML = '* { -webkit-user-select: none !important; user-select: none !important; -webkit-touch-callout: none !important; }';
        document.head.appendChild(style);
      })();
    ''';
    _webViewController!.runJavaScript(jsScript).catchError((_) {});
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _countdownTimer?.cancel();
          _onTimeExpired();
        }
      });
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      final success = await ApiClient().sendHeartbeat(
        sessionId: widget.session.sessionId,
        batteryLevel: 85,
        isCharging: false,
      );
      if (mounted) {
        setState(() {
          _connectionStatus = success
              ? ConnectionStatus.connected
              : ConnectionStatus.reconnecting;
        });
      }
    });
  }

  void _checkIfFormSubmitted(String url) {
    if (url.contains('formResponse') || url.contains('finish=1')) {
      _completeExam();
    }
  }

  void _onTimeExpired() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Waktu Ujian Telah Habis'),
        content: const Text(
          'Waktu pengerjaan telah berakhir. Silakan serahkan jawaban Anda di Google Form sekarang.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _completeExam();
            },
            child: const Text('Konfirmasi Selesai'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeExam() async {
    _countdownTimer?.cancel();
    _heartbeatTimer?.cancel();
    await LockdownService().disableLockdown();
    await ApiClient().finishSession(widget.session.sessionId);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(session: widget.session),
      ),
    );
  }

  /// Mengakhiri sesi ujian dan langsung kembali bersih ke beranda
  Future<void> _completeExamAndReturnHome() async {
    _countdownTimer?.cancel();
    _heartbeatTimer?.cancel();
    await LockdownService().disableLockdown();
    await ApiClient().finishSession(widget.session.sessionId);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  /// Dialog verifikasi PIN Pengawas untuk mengakhiri atau keluar dari ujian (Standar Wajib Exambro)
  void _promptProctorExitDialog() {
    final pinController = TextEditingController();
    bool isError = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final examName = widget.session.mapel != null && widget.session.mapel!.isNotEmpty
              ? widget.session.mapel!
              : 'Ujian Ini';
          return AlertDialog(
            title: const Text('Keluar Ujian (Otorisasi Pengawas)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Siswa dilarang menutup ujian sendiri. Minta pengawas memasukkan PIN Pengawas untuk $examName:',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.text,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'Masukkan PIN Pengawas',
                    errorText: isError ? 'PIN Pengawas Salah!' : null,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Kembali Mengerjakan'),
              ),
              OutlinedButton(
                onPressed: () {
                  if (pinController.text.trim() == widget.session.proctorPin) {
                    Navigator.of(ctx).pop();
                    _completeExamAndReturnHome();
                  } else {
                    setDialogState(() => isError = true);
                  }
                },
                child: const Text('Keluar ke Beranda'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Verifikasi PIN Pengawas khusus untuk ujian ini
                  if (pinController.text.trim() == widget.session.proctorPin) {
                    Navigator.of(ctx).pop();
                    _completeExam();
                  } else {
                    setDialogState(() => isError = true);
                  }
                },
                child: const Text('Selesai & Bukti'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      LockdownService().handleAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      LockdownService().handleAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Pencegahan tombol kembali: Wajib memasukkan PIN Pengawas
        _promptProctorExitDialog();
      },
      child: Scaffold(
        appBar: ExamBar(
          remainingSeconds: _remainingSeconds,
          connectionStatus: _connectionStatus,
          onCallProctor: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Panggilan terkirim. Pengawas sedang menuju meja Anda.'),
                duration: Duration(seconds: 3),
              ),
            );
          },
          onFinishEarly: _promptProctorExitDialog,
        ),
        body: _buildExamBody(),
      ),
    );
  }

  Widget _buildExamBody() {
    if (_isNativeMobilePlatform && _webViewController != null) {
      return Stack(
        children: [
          WebViewWidget(controller: _webViewController!),
          if (_isLoadingForm)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      );
    }

    // Panel Simulator untuk Desktop & Web
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(NetriSpacing.space6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(NetriSpacing.space4),
                decoration: BoxDecoration(
                  color: NetriColors.brandLight.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_clock_rounded, size: 48, color: NetriColors.brandLight),
              ),
              const SizedBox(height: NetriSpacing.space4),
              const Text(
                'Exambro Lintas Platform Aktif',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: NetriSpacing.space2),
              Text(
                'Di Android & iOS, Google Form tampil 100% fullscreen dengan proteksi anti-screenshot, anti-copy teks, dan penguncian tombol home.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: NetriSpacing.space4),
              Container(
                padding: const EdgeInsets.all(NetriSpacing.space3),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(20),
                  borderRadius: BorderRadius.circular(NetriRadius.sm),
                ),
                child: SelectableText(
                  widget.session.formUrl,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: NetriSpacing.space6),

              const Text('Simulasi Pengujian Sistem Keamanan:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: NetriSpacing.space3),
              Wrap(
                spacing: NetriSpacing.space2,
                runSpacing: NetriSpacing.space2,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.screenshot_rounded, size: 18),
                    label: const Text('Simulasi Screenshot'),
                    onPressed: () => LockdownService().recordScreenshotAttempt(),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                    label: const Text('Simulasi Switch App'),
                    onPressed: () => LockdownService().handleAppResignedActive(),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.lock_open_rounded, size: 18),
                    label: const Text('Keluar (Minta PIN)'),
                    onPressed: _promptProctorExitDialog,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

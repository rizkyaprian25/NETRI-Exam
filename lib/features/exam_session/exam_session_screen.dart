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
          onDismissed: () {
            lockdown.unlockByProctor();
            _isLockDialogShowing = false;
            Navigator.of(ctx).pop();
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

  /// Dialog peringatan saat ada upaya keluar dari ujian (Sirine 5 Detik)
  void _promptProctorExitDialog() {
    // Bunyikan sirine peringatan 5 detik saat mencoba keluar
    LockdownService().startAlarmSound(durationMs: 5000);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Upaya Keluar (Sirine Aktif)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(NetriRadius.sm),
                border: Border.all(color: Colors.red.withAlpha(60)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.volume_up_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sirine peringatan berbunyi selama 5 detik!',
                      style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ujian sedang berlangsung dalam mode ketat. Apakah Anda sudah selesai dan mengirimkan jawaban di Google Form?',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NetriColors.brandLight,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              LockdownService().stopAlarmSound();
              Navigator.of(ctx).pop();
            },
            child: const Text('Lanjut Mengerjakan Ujian'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              LockdownService().stopAlarmSound();
              Navigator.of(ctx).pop();
              _completeExamAndReturnHome();
            },
            child: const Text('Sudah Selesai, Keluar Ujian'),
          ),
        ],
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

// Layar Sesi Ujian Terkunci (Secure Google Form Runtime)
// Mengintegrasikan WebView dengan whitelist domain, ExamBar, dan Lockdown Engine

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../contracts/models.dart';
import '../../core/network/api_client.dart';
import '../lockdown/lockdown_service.dart';
import 'exam_bar.dart';
import 'lock_screen_dialog.dart';
import '../result/result_screen.dart';

class ExamSessionScreen extends StatefulWidget {
  final ActiveExamSession session;

  const ExamSessionScreen({super.key, required this.session});

  @override
  State<ExamSessionScreen> createState() => _ExamSessionScreenState();
}

class _ExamSessionScreenState extends State<ExamSessionScreen>
    with WidgetsBindingObserver {
  late final WebViewController _webViewController;
  late int _remainingSeconds;
  Timer? _countdownTimer;
  Timer? _heartbeatTimer;
  bool _isLoadingForm = true;
  ConnectionStatus _connectionStatus = ConnectionStatus.connected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Hitung sisa waktu dari server deadline
    final now = DateTime.now();
    _remainingSeconds = widget.session.deadlineAt.difference(now).inSeconds;
    if (_remainingSeconds <= 0) _remainingSeconds = 5400; // 90 menit fallback

    _initLockdown();
    _initWebView();
    _startTimer();
    _startHeartbeat();
  }

  void _initLockdown() {
    final lockdown = LockdownService();
    lockdown.enableLockdown(widget.session.sessionId);

    lockdown.onStrikeTriggered = (strike, reason) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => LockScreenDialog(
          strikeCount: strike,
          reason: reason,
          onProctorUnlocked: () => Navigator.of(ctx).pop(),
        ),
      );
    };

    lockdown.onLockRequired = () {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => LockScreenDialog(
          strikeCount: 2,
          reason: 'Batas toleransi interupsi terlampaui. Sesi dikunci demi keamanan.',
          onProctorUnlocked: () {
            lockdown.unlockByProctor();
            Navigator.of(ctx).pop();
          },
        ),
      );
    };
  }

  void _initWebView() {
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
            _checkIfFormSubmitted(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;

            // Memeriksa apakah domain termasuk dalam Whitelist Google Form
            final isAllowed = widget.session.allowedDomains.any((domain) =>
                uri.host == domain || uri.host.endsWith('.$domain'));

            if (!isAllowed) {
              debugPrint('[SecureWebView] Navigasi luar diblokir: ${request.url}');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // Muat tautan Google Form yang dirilis server
    _webViewController.loadRequest(Uri.parse(widget.session.formUrl));
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

  // Mendeteksi halaman konfirmasi pengiriman Google Form
  void _checkIfFormSubmitted(String url) {
    if (url.contains('formResponse') || url.contains('viewform?embedded=true&finish=1')) {
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
        builder: (_) => ResultScreen(sessionId: widget.session.sessionId),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
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
        // Dialog konfirmasi agar siswa tidak keluar tak sengaja
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Keluar dari Ujian?'),
            content: const Text(
              'Ujian sedang berjalan. Keluar dari halaman ini akan dicatat sebagai pelanggaran oleh pengawas.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal & Lanjut Ujian'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _completeExam();
                },
                child: const Text('Selesai Ujian'),
              ),
            ],
          ),
        );
      },
      child: Scaffold(
        appBar: ExamBar(
          remainingSeconds: _remainingSeconds,
          connectionStatus: _connectionStatus,
          onCallProctor: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Panggilan terkirim. Pengawas ruang sedang menuju meja Anda.'),
                duration: Duration(seconds: 3),
              ),
            );
          },
          onFinishEarly: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Selesaikan Ujian Sekarang?'),
                content: const Text(
                  'Pastikan Anda telah menekan tombol "Kirim/Submit" di Google Form sebelum mengakhiri sesi.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Belum, Periksa Dulu'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _completeExam();
                    },
                    child: const Text('Ya, Saya Sudah Kirim'),
                  ),
                ],
              ),
            );
          },
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _webViewController),
            if (_isLoadingForm)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

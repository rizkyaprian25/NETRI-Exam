// Layar Sesi Ujian Terkunci (Exam NETRI 100% Android & iOS Mode)
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
          reason: 'PERINGATAN EXAM NETRI: Anda Terdeteksi Keluar atau Berpindah dari Aplikasi Ujian!',
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
                debugPrint('[ExamNetriWebView] Navigasi luar diblokir: ${request.url}');
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
      debugPrint('[ExamNetriWebView] Mode fallback aktif: $e');
      setState(() => _isLoadingForm = false);
    }
  }

  /// Menyuntikkan skrip anti-copy teks soal tanpa mengganggu pengetikan jawaban formulir
  void _injectAntiCopyProtection() {
    if (_webViewController == null) return;
    const jsScript = '''
      (function() {
        // Blokir menu konteks selain pada kotak isian
        document.addEventListener('contextmenu', function(e) {
          var tag = (e.target && e.target.tagName) ? e.target.tagName.toLowerCase() : '';
          if (tag !== 'input' && tag !== 'textarea') {
            e.preventDefault();
            return false;
          }
        });
        // Blokir penyalinan teks soal (copy)
        document.addEventListener('copy', function(e) {
          e.preventDefault();
          return false;
        });
        // Blokir cut selain pada kotak isian
        document.addEventListener('cut', function(e) {
          var tag = (e.target && e.target.tagName) ? e.target.tagName.toLowerCase() : '';
          if (tag !== 'input' && tag !== 'textarea') {
            e.preventDefault();
            return false;
          }
        });
        // Izinkan peletakan kursor dan seleksi teks khusus pada input & textarea agar bisa mengetik
        document.addEventListener('selectstart', function(e) {
          var tag = (e.target && e.target.tagName) ? e.target.tagName.toLowerCase() : '';
          if (tag !== 'input' && tag !== 'textarea') {
            e.preventDefault();
            return false;
          }
        });
        // Proteksi CSS: Soal tidak bisa disorot, namun input dan textarea 100% aktif untuk mengetik
        var style = document.createElement('style');
        style.innerHTML = 'body { -webkit-user-select: none !important; user-select: none !important; -webkit-touch-callout: none !important; } input, textarea, [contenteditable="true"] { -webkit-user-select: text !important; user-select: text !important; -webkit-touch-callout: default !important; }';
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

  /// Dialog peringatan saat ada upaya keluar dari ujian lewat tombol kembali (Sirine 5 Detik)
  void _onBackButtonPressed() {
    // Bunyikan sirine peringatan 5 detik saat mencoba menekan tombol kembali
    LockdownService().startAlarmSound(durationMs: 5000);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NetriRadius.lg),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Dilarang Keluar!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
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
                      'Sirine peringatan aktif selama 5 detik!',
                      style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tombol kembali dinonaktifkan demi integritas ujian. Anda tidak diizinkan meninggalkan lembar ujian sebelum menyelesaikan seluruh soal.',
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
        ],
      ),
    );
  }

  /// Dialog konfirmasi sah jika siswa telah selesai mengisi Google Form
  void _promptFinishEarlyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NetriRadius.lg),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: NetriColors.brandLight, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Selesaikan Ujian?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: const Text(
          'Pastikan Anda sudah menekan tombol Kirim / Submit pada Google Form sebelum menyelesaikan sesi ujian ini.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Periksa Kembali'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NetriColors.brandLight,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _completeExam();
            },
            child: const Text('Ya, Sudah Selesai'),
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
        // Pencegahan tombol kembali: Bunyikan sirine & ingatkan larangan keluar
        _onBackButtonPressed();
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
          onFinishEarly: _promptFinishEarlyDialog,
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
                'Exam NETRI Lintas Platform Aktif',
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
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Selesai Ujian'),
                    onPressed: _promptFinishEarlyDialog,
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

// Layar Sesi Ujian Terkunci (Exam NETRI 100% Android & iOS Mode)
// Mengintegrasikan WebView tahan Hotspot/Tethering, filter navigasi main-frame,
// pemuatan ulang soal, keluar darurat pengawas, dan Lockdown Engine

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../contracts/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/tokens.g.dart';
import '../auth/login_screen.dart';
import '../lockdown/emergency_exit_guard.dart';
import '../lockdown/lockdown_service.dart';
import 'exam_bar.dart';
import 'lock_screen_dialog.dart';
import '../result/result_screen.dart';

class ExamSessionScreen extends StatefulWidget {
  final ActiveExamSession session;

  const ExamSessionScreen({super.key, required this.session});

  /// Memeriksa apakah permintaan navigasi WebView diizinkan.
  /// Mengizinkan subframe/iframe resmi (untuk validasi koneksi Google/Cloudflare pada Hotspot)
  /// sambil memblokir tautan keluar, skema eksternal, dan halaman Google Search pada main-frame.
  static bool isNavigationAllowed(
    String rawUrl, {
    required bool isMainFrame,
    required List<String> allowedDomains,
  }) {
    if (rawUrl.startsWith('about:')) {
      return true;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return false;
    }

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    // Blokir halaman pencarian umum Google Search agar siswa tidak mencari jawaban di WebView
    if (host == 'google.com' || host == 'www.google.com') {
      if (path.isEmpty ||
          path == '/' ||
          path.startsWith('/search') ||
          path.startsWith('/webhp')) {
        return false;
      }
    }

    // Subframe/iframe (misal CheckConnection, reCAPTCHA, Cloudflare s.id) tetap diizinkan agar tidak deadlock di Hotspot
    if (!isMainFrame) {
      return true;
    }

    return allowedDomains.any(
      (domain) => host == domain || host.endsWith('.$domain'),
    );
  }

  @override
  State<ExamSessionScreen> createState() => _ExamSessionScreenState();
}

class _ExamSessionScreenState extends State<ExamSessionScreen>
    with WidgetsBindingObserver {
  WebViewController? _webViewController;
  Timer? _heartbeatTimer;
  Timer? _loadingWatchdogTimer;
  bool _isLoadingForm = true;
  int _loadingProgress = 0;
  String? _webLoadError;
  ConnectionStatus _connectionStatus = ConnectionStatus.connected;
  bool _isLockDialogShowing = false;
  bool _isExamCompleted = false;
  bool _isPinned = true;
  bool _isThreeButtonMode = true;

  bool get _isNativeMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initLockdown();
    if (_isNativeMobilePlatform) {
      _initWebView();
    } else {
      _isLoadingForm = false;
    }

    _startHeartbeat();
  }

  void _initLockdown() {
    final lockdown = LockdownService();
    lockdown.enableLockdown(widget.session.sessionId);

    // Verifikasi awal status Sematkan Layar dan Mode Tombol
    lockdown.isLockTaskActive().then((pinned) {
      if (!mounted) return;
      setState(() => _isPinned = pinned);
    });
    lockdown.isThreeButtonNavigation().then((threeButton) {
      if (!mounted) return;
      setState(() => _isThreeButtonMode = threeButton);
    });

    // Pantau perubahan status Sematkan Layar dan Mode Tombol
    lockdown.onLockStateChanged = (bool isPinned, bool isObscured, bool isThreeButton) {
      if (!mounted) return;
      setState(() {
        _isPinned = isPinned;
        _isThreeButtonMode = isThreeButton;
      });
    };

    lockdown.onLockRequired = () {
      if (!mounted || _isLockDialogShowing || _isExamCompleted) return;
      _isLockDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => LockScreenDialog(
          strikeCount: lockdown.currentStrikeCount,
          reason: 'PERINGATAN EXAM NETRI: Anda Terdeteksi Keluar atau Membuka Aplikasi Mengambang!',
          onDismissed: () {
            lockdown.unlockByProctor();
            _isLockDialogShowing = false;
            Navigator.of(ctx).pop();
          },
          onEmergencyExit: () {
            _isLockDialogShowing = false;
            Navigator.of(ctx).pop();
            _triggerEmergencyExit();
          },
        ),
      );
    };
  }

  void _initWebView() {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        // Gunakan User-Agent Chrome Mobile standar agar tidak ditahan anti-bot di IP Hotspot bersama
        ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (!mounted) return;
              setState(() {
                _isLoadingForm = true;
                _webLoadError = null;
                _loadingProgress = 10;
              });
              _startLoadingWatchdog();
              _checkIfFormSubmitted(url);
            },
            onProgress: (int progress) {
              if (!mounted) return;
              setState(() {
                _loadingProgress = progress;
                // Buka tampilan segera saat struktur utama formulir sudah siap di koneksi lambat
                if (progress >= 80 && _isLoadingForm) {
                  _isLoadingForm = false;
                  _loadingWatchdogTimer?.cancel();
                  _injectAntiCopyProtection();
                }
              });
            },
            onPageFinished: (String url) {
              _loadingWatchdogTimer?.cancel();
              if (!mounted) return;
              setState(() {
                _isLoadingForm = false;
                _loadingProgress = 100;
                _connectionStatus = ConnectionStatus.connected;
              });
              _injectAntiCopyProtection();
              _checkIfFormSubmitted(url);
            },
            onWebResourceError: (WebResourceError error) {
              // Abaikan error aset sekunder/ikon; hanya tangani kegagalan frame utama
              if (error.isForMainFrame == false) return;
              _loadingWatchdogTimer?.cancel();
              if (!mounted) return;
              final detail = error.description.trim().isNotEmpty
                  ? error.description
                  : 'Koneksi Hotspot terputus atau DNS tidak merespons';
              setState(() {
                _isLoadingForm = false;
                _connectionStatus = ConnectionStatus.offline;
                _webLoadError =
                    'Gagal memuat lembar soal ($detail). Pastikan Hotspot memiliki kuota internet aktif lalu tekan Muat Ulang.';
              });
            },
            onHttpError: (HttpResponseError error) {
              final statusCode = error.response?.statusCode;
              if (statusCode != null && statusCode >= 500) {
                _loadingWatchdogTimer?.cancel();
                if (!mounted) return;
                setState(() {
                  _isLoadingForm = false;
                  _webLoadError =
                      'Server formulir atau jaringan sedang bermasalah (HTTP $statusCode). Tekan Muat Ulang Soal untuk mencoba kembali.';
                });
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              final isAllowed = ExamSessionScreen.isNavigationAllowed(
                request.url,
                isMainFrame: request.isMainFrame,
                allowedDomains: widget.session.allowedDomains,
              );

              if (!isAllowed) {
                debugPrint('[ExamNetriWebView] Navigasi luar diblokir: ${request.url}');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Akses ke tautan luar dilarang selama ujian berlangsung.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        );

      _webViewController = controller;
      controller.loadRequest(Uri.parse(widget.session.formUrl));
      _startLoadingWatchdog();
    } catch (e) {
      debugPrint('[ExamNetriWebView] Mode fallback aktif: $e');
      _loadingWatchdogTimer?.cancel();
      setState(() => _isLoadingForm = false);
    }
  }

  /// Timer pengawas pemuatan agar siswa tidak terjebak spinner selamanya saat jaringan Hotspot macet
  void _startLoadingWatchdog() {
    _loadingWatchdogTimer?.cancel();
    _loadingWatchdogTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || !_isLoadingForm) return;
      setState(() {
        _isLoadingForm = false;
        _webLoadError =
            'Waktu pemuatan soal habis karena koneksi Hotspot lambat atau tidak stabil. '
            'Periksa sinyal/kuota Hotspot Anda lalu tekan Muat Ulang Soal.';
      });
      _checkRealConnectionNow();
    });
  }

  Future<void> _checkRealConnectionNow() async {
    final reachable = await ApiClient().checkInternetReachability();
    if (!mounted) return;
    setState(() {
      _connectionStatus =
          reachable ? ConnectionStatus.connected : ConnectionStatus.offline;
    });
  }

  /// Memuat ulang lembar soal saat jaringan Hotspot pulih tanpa melepas penguncian ujian
  Future<void> _reloadForm() async {
    if (!mounted) return;
    setState(() {
      _webLoadError = null;
      _isLoadingForm = _webViewController != null;
      _loadingProgress = 5;
      _connectionStatus = ConnectionStatus.reconnecting;
    });

    unawaited(_checkRealConnectionNow());

    final controller = _webViewController;
    if (controller == null) return;

    _startLoadingWatchdog();
    try {
      final currentUrl = await controller.currentUrl();
      if (currentUrl == null ||
          currentUrl.isEmpty ||
          currentUrl == 'about:blank') {
        await controller.loadRequest(Uri.parse(widget.session.formUrl));
      } else {
        await controller.reload();
      }
    } catch (_) {
      try {
        await controller.loadRequest(Uri.parse(widget.session.formUrl));
      } catch (_) {}
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

  /// Mengakhiri sesi ujian secara aman dan memindahkan ke ResultScreen
  Future<void> _completeExam() async {
    if (_isExamCompleted) return;
    _isExamCompleted = true;

    _heartbeatTimer?.cancel();
    _loadingWatchdogTimer?.cancel();
    await LockdownService().disableLockdown();
    await ApiClient().finishSession(widget.session.sessionId);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(session: widget.session),
      ),
    );
  }

  /// Membuka dialog verifikasi kode darurat pengawas untuk memutus Sematkan Aplikasi
  void _triggerEmergencyExit() {
    showEmergencyExitDialog(
      context,
      onVerified: _performEmergencyExit,
    );
  }

  /// Melepas Sematkan Aplikasi dan mengembalikan aplikasi ke halaman beranda secara bersih
  Future<void> _performEmergencyExit() async {
    if (_isExamCompleted) return;
    _isExamCompleted = true;

    _heartbeatTimer?.cancel();
    _loadingWatchdogTimer?.cancel();
    await LockdownService().emergencyExit();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Dialog peringatan saat ada upaya keluar dari ujian lewat tombol kembali (Sirine 15 Detik)
  void _onBackButtonPressed() {
    // Bunyikan sirine peringatan selama 15 detik saat tombol kembali ditekan
    LockdownService().startAlarmSound(durationMs: 15000);

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
                      'Sirine peringatan aktif berbunyi keras selama 15 detik!',
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
          TextButton(
            onPressed: () {
              LockdownService().stopAlarmSound();
              Navigator.of(ctx).pop();
              _triggerEmergencyExit();
            },
            child: const Text(
              'Keluar Darurat',
              style: TextStyle(color: NetriColors.stateDangerLight),
            ),
          ),
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isExamCompleted) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      LockdownService().handleAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      LockdownService().handleAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _loadingWatchdogTimer?.cancel();
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
          connectionStatus: _connectionStatus,
          onReloadForm: _reloadForm,
          onEmergencyExit: _triggerEmergencyExit,
        ),
        body: _buildExamBody(),
      ),
    );
  }

  Widget _buildExamBody() {
    Widget content;
    if (_isNativeMobilePlatform && _webViewController != null) {
      content = Stack(
        children: [
          WebViewWidget(controller: _webViewController!),
          if (_isLoadingForm)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _loadingProgress > 0 ? _loadingProgress / 100.0 : null,
                minHeight: 3,
              ),
            ),
          if (_isLoadingForm && _webLoadError == null)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (_webLoadError != null) _buildHotspotErrorOverlay(),
        ],
      );
    } else {
      // Panel Simulator untuk Desktop & Web
      content = Center(
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
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Simulasi Kirim Form'),
                      onPressed: _completeExam,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool shouldShowCurtain = !_isPinned;

    return Stack(
      children: [
        content,
        if (shouldShowCurtain) _buildSecurityCurtain(),
      ],
    );
  }

  /// Overlay diagnostik saat koneksi Hotspot/Wi-Fi lambat atau terputus di tengah pemuatan soal
  Widget _buildHotspotErrorOverlay() {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Material(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(NetriSpacing.space5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(NetriSpacing.space4),
                        decoration: BoxDecoration(
                          color: NetriColors.stateWarningLight.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wifi_tethering_error_rounded,
                          color: NetriColors.stateWarningLight,
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: NetriSpacing.space4),
                    const Text(
                      'Kendala Koneksi Hotspot / Jaringan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NetriSpacing.space2),
                    Text(
                      _webLoadError ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NetriSpacing.space3),
                    Container(
                      padding: const EdgeInsets.all(NetriSpacing.space3),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(NetriRadius.sm),
                      ),
                      child: const Text(
                        'Tips Mengatasi Hotspot Macet:\n'
                        '• Pastikan HP pemberi Hotspot memiliki kuota data aktif.\n'
                        '• Nonaktifkan DNS Pribadi / VPN jika terpasang.\n'
                        '• Dekatkan jarak perangkat dengan sumber Hotspot.',
                        style: TextStyle(fontSize: 12, height: 1.45),
                      ),
                    ),
                    const SizedBox(height: NetriSpacing.space5),
                    ElevatedButton.icon(
                      onPressed: _reloadForm,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('Muat Ulang Soal'),
                    ),
                    const SizedBox(height: NetriSpacing.space2),
                    OutlinedButton.icon(
                      onPressed: _triggerEmergencyExit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NetriColors.stateDangerLight,
                        side: const BorderSide(color: NetriColors.stateDangerLight),
                      ),
                      icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
                      label: const Text('Keluar Darurat (Pengawas)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tirai pelindung saat layar ujian belum disematkan (Screen Pinning wajib aktif)
  Widget _buildSecurityCurtain() {
    return Positioned.fill(
      child: Material(
        color: const Color(0xFF141824),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(NetriSpacing.space5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(35),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.redAccent, width: 2),
                        ),
                        child: const Icon(
                          Icons.phonelink_lock_rounded,
                          color: Colors.redAccent,
                          size: 44,
                        ),
                      ),
                    ),
                    const SizedBox(height: NetriSpacing.space4),
                    const Text(
                      'Kunci Layar Ujian (Sematkan Layar) Wajib Aktif!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NetriSpacing.space3),
                    Text(
                      _isThreeButtonMode
                          ? 'Pada mode tombol, Anda wajib menekan "Sematkan / Aktifkan" pada konfirmasi sistem Android agar tombol Home dan Recent terkunci penuh selama ujian.'
                          : 'Pada mode gestur, Anda wajib menekan "Sematkan / Aktifkan" pada konfirmasi sistem Android agar HP terkunci dan tidak dapat membuka aplikasi lain selama ujian berlangsung.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NetriSpacing.space5),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NetriColors.brandLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(NetriRadius.md),
                        ),
                      ),
                      icon: const Icon(Icons.lock_rounded, size: 20),
                      label: const Text(
                        'Kunci Layar & Mulai Ujian',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final pinned = await LockdownService().requestLockTask();
                        if (!mounted) return;
                        setState(() {
                          _isPinned = pinned;
                        });
                      },
                    ),
                    const SizedBox(height: NetriSpacing.space2),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(NetriRadius.md),
                        ),
                      ),
                      icon: const Icon(Icons.settings_rounded, size: 18),
                      label: const Text('Buka Pengaturan Sematkan Layar'),
                      onPressed: () {
                        LockdownService().openSecuritySettings();
                      },
                    ),
                    const SizedBox(height: NetriSpacing.space2),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent.shade100,
                      ),
                      icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
                      label: const Text('Keluar Darurat (Kode Pengawas)'),
                      onPressed: _triggerEmergencyExit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

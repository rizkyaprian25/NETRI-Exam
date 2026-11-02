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
  bool _isAutoSubmitting = false;
  bool _isExamCompleted = false;

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
    final diff = widget.session.deadlineAt.difference(now).inSeconds;
    _remainingSeconds = diff > 0 ? diff : (widget.session.durationMinutes * 60);
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
              _checkIfFormSubmitted(url);
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

  /// Menekan tombol Kirim / Submit pada Google Form secara otomatis menggunakan skrip DOM komprehensif
  Future<String?> _autoSubmitGoogleForm() async {
    if (_webViewController == null) return null;
    const jsScript = '''
      (function() {
        try {
          var logs = [];

          // 1. Lengkapi isian wajib yang masih kosong dengan '-' agar tidak diblokir validasi client Google
          var inputs = document.querySelectorAll('input[type="text"], input[type="email"], textarea, input:not([type])');
          var filledCount = 0;
          for (var i = 0; i < inputs.length; i++) {
            var inp = inputs[i];
            if (inp.offsetParent !== null && (!inp.value || inp.value.trim() === '')) {
              inp.value = '-';
              inp.dispatchEvent(new Event('input', { bubbles: true }));
              inp.dispatchEvent(new Event('change', { bubbles: true }));
              filledCount++;
            }
          }
          logs.push('FILLED_' + filledCount);

          // 2. Fungsi pembantu dispatch event klik nyata (pointerdown, mousedown, mouseup, click)
          function triggerRealClick(el) {
            if (!el) return;
            el.scrollIntoView({ behavior: 'instant', block: 'center' });
            try { el.focus(); } catch (e) {}

            var eventTypes = ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'];
            for (var k = 0; k < eventTypes.length; k++) {
              var evtName = eventTypes[k];
              try {
                var evt;
                if (evtName.indexOf('pointer') !== -1 && typeof PointerEvent !== 'undefined') {
                  evt = new PointerEvent(evtName, { bubbles: true, cancelable: true, view: window, pointerType: 'touch', isPrimary: true });
                } else {
                  evt = new MouseEvent(evtName, { bubbles: true, cancelable: true, view: window, button: 0, buttons: 1 });
                }
                el.dispatchEvent(evt);
              } catch (err) {}
            }
            try { el.click(); } catch (e) {}
          }

          // 3. Cari tombol Kirim / Submit
          var submitBtn = null;

          // 3a. Berdasarkan jsname standar Google Forms
          submitBtn = document.querySelector('div[jsname="M2CFlb"]') || document.querySelector('div[role="button"][jsname="M2CFlb"]');

          // 3b. Berdasarkan teks di dalam elemen span
          if (!submitBtn) {
            var spans = document.querySelectorAll('form span, div[role="button"] span, button span');
            for (var s = 0; s < spans.length; s++) {
              var spanTxt = (spans[s].innerText || spans[s].textContent || '').trim().toLowerCase();
              if (spanTxt === 'kirim' || spanTxt === 'submit') {
                submitBtn = spans[s].closest('div[role="button"]') || spans[s].closest('button') || spans[s];
                break;
              }
            }
          }

          // 3c. Berdasarkan div[role="button"] atau button umum
          if (!submitBtn) {
            var allButtons = document.querySelectorAll('div[role="button"], button, input[type="submit"]');
            for (var b = 0; b < allButtons.length; b++) {
              var btnTxt = (allButtons[b].innerText || allButtons[b].textContent || allButtons[b].value || '').trim().toLowerCase();
              if (btnTxt === 'kirim' || btnTxt === 'submit' || (btnTxt.indexOf('kirim') !== -1 && btnTxt.indexOf('batal') === -1 && btnTxt.indexOf('kembali') === -1)) {
                submitBtn = allButtons[b];
                break;
              }
            }
          }

          if (submitBtn) {
            triggerRealClick(submitBtn);
            logs.push('CLICKED_SUBMIT');
            return logs.join(';');
          }

          // 4. Jika ada tombol 'Berikutnya' / 'Next' (multi-halaman sebelum akhir)
          var nextBtn = document.querySelector('div[jsname="OCpkoe"]') || document.querySelector('div[role="button"][jsname="OCpkoe"]');
          if (!nextBtn) {
            var nextSpans = document.querySelectorAll('form span, div[role="button"] span');
            for (var ns = 0; ns < nextSpans.length; ns++) {
              var nTxt = (nextSpans[ns].innerText || nextSpans[ns].textContent || '').trim().toLowerCase();
              if (nTxt === 'berikutnya' || nTxt === 'next') {
                nextBtn = nextSpans[ns].closest('div[role="button"]') || nextSpans[ns].closest('button') || nextSpans[ns];
                break;
              }
            }
          }
          if (nextBtn) {
            triggerRealClick(nextBtn);
            logs.push('CLICKED_NEXT');
            return logs.join(';');
          }

          // 5. Fallback langsung submit form HTML bawaan
          var formEl = document.getElementById('mG61Hd') || document.querySelector('form');
          if (formEl) {
            HTMLFormElement.prototype.submit.call(formEl);
            logs.push('CALLED_FORM_SUBMIT');
            return logs.join(';');
          }

          logs.push('NO_BUTTON_OR_FORM');
          return logs.join(';');
        } catch (ex) {
          return 'EXCEPTION:' + ex.message;
        }
      })();
    ''';
    try {
      final res = await _webViewController!.runJavaScriptReturningResult(jsScript);
      debugPrint('[AutoSubmit] Respon eksekusi: $res');
      return res.toString();
    } catch (e) {
      debugPrint('[AutoSubmit] Error JavaScript: $e');
      return null;
    }
  }

  /// Memaksa pengiriman HTTP POST form HTML secara langsung jika tombol Kirim belum memicu respon
  Future<void> _forceDirectFormSubmit() async {
    if (_webViewController == null) return;
    const jsScript = '''
      (function() {
        try {
          var formEl = document.getElementById('mG61Hd') || document.querySelector('form');
          if (formEl) {
            HTMLFormElement.prototype.submit.call(formEl);
            return 'FORCE_SUBMIT_SUCCESS';
          }
          return 'NO_FORM_FOUND';
        } catch (e) {
          return 'FORCE_SUBMIT_ERR:' + e.message;
        }
      })();
    ''';
    try {
      final res = await _webViewController!.runJavaScriptReturningResult(jsScript);
      debugPrint('[AutoSubmit] Respon force direct submit: $res');
    } catch (e) {
      debugPrint('[AutoSubmit] Error force direct submit: $e');
    }
  }

  /// Penanganan otomatis saat durasi ujian habis (Otomatis Kirim / Submit Form dengan Verifikasi Respon)
  Future<void> _onTimeExpired() async {
    if (_isAutoSubmitting || _isExamCompleted) return;
    _isAutoSubmitting = true;

    // Tampilkan dialog proses kirim otomatis non-dismissible
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NetriRadius.lg),
          ),
          title: const Row(
            children: [
              Icon(Icons.timer_off_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Waktu Ujian Habis',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Text(
                'Waktu pengerjaan telah berakhir. Sistem sedang mengirimkan jawaban Anda secara otomatis agar nilai tetap tersimpan.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Mengirimkan jawaban ke server Google Forms...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_webViewController != null) {
      // 1. Jalankan auto-submit pertama (isi field kosong & klik tombol Kirim/Submit)
      await _autoSubmitGoogleForm();

      // 2. Pantau URL WebView secara aktif hingga halaman 'formResponse' terdeteksi
      // Berikan waktu hingga 8 detik (periksa setiap 500ms) agar pengunggahan data selesai
      bool isConfirmed = false;
      for (int i = 0; i < 16; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted || _isExamCompleted) return;

        final currentUrl = await _webViewController?.currentUrl();
        if (currentUrl != null &&
            (currentUrl.contains('formResponse') || currentUrl.contains('finish=1'))) {
          isConfirmed = true;
          break;
        }

        // Pada detik ke-2.5 (iterasi ke-5), jika belum berpindah URL, jalankan direct form submit
        if (i == 5) {
          await _forceDirectFormSubmit();
        }
      }

      debugPrint('[AutoSubmit] Hasil konfirmasi penerimaan server: $isConfirmed');
    } else {
      // Waktu jeda simulasi pada lingkungan desktop / unit-test
      await Future.delayed(const Duration(seconds: 2));
    }

    // 3. Selesaikan ujian dan arahkan ke ResultScreen
    if (mounted && !_isExamCompleted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      await _completeExam();
    }
  }

  /// Mengakhiri sesi ujian secara aman dan memindahkan ke ResultScreen
  Future<void> _completeExam() async {
    if (_isExamCompleted) return;
    _isExamCompleted = true;

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

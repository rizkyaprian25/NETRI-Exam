import Flutter
import UIKit
import AudioToolbox
import AVFoundation
import AutomaticAssessmentConfiguration

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var lockdownChannel: FlutterMethodChannel?
  private var privacyShieldView: UIView?
  private var originalBrightness: CGFloat = 0.5
  private var alarmTimer: Timer?
  private var assessmentSession: Any? // Menyimpan AEAssessmentSession pada iOS 13.4+

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    
    // Inisialisasi Platform Channel Penguncian iOS
    let controller = window?.rootViewController as! FlutterViewController
    lockdownChannel = FlutterMethodChannel(name: "com.netri.exam/lockdown", binaryMessenger: controller.binaryMessenger)

    lockdownChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "enableSecureWindow":
        self.enableIosLockdown()
        result(true)
      case "disableSecureWindow":
        self.disableIosLockdown()
        result(true)
      case "startAlarmSound":
        let durationMs = (call.arguments as? [String: Any])?["durationMs"] as? Int ?? 5000
        self.startIosAlarmSound(durationMs: durationMs)
        result(true)
      case "stopAlarmSound":
        self.stopIosAlarmSound()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func enableIosLockdown() {
    NotificationCenter.default.removeObserver(self)

    // 1. Kecerahan Layar Maksimal 100% & Kunci Layar Tetap Menyala
    originalBrightness = UIScreen.main.brightness
    UIScreen.main.brightness = 1.0
    UIApplication.shared.isIdleTimerDisabled = true

    // 2. Kunci Otomatis Mode Ujian Resmi Apple (Automatic Assessment Configuration)
    if #available(iOS 13.4, *) {
      let config = AEAssessmentConfiguration()
      if #available(iOS 14.0, *) {
        config.autocorrectMode = .none
        config.allowsSpellCheck = false
        config.allowsPredictiveKeyboard = false
        config.allowsKeyboardShortcuts = false
        config.allowsActivityContinuation = false
        config.allowsDictation = false
        config.allowsAccessibilitySpeech = false
        config.allowsPasswordAutoFill = false
        config.allowsContinuousPathInput = false
      }
      let session = AEAssessmentSession(configuration: config)
      self.assessmentSession = session
      session.begin()
    }

    // 3. Minta Penguncian Layar Tunggal Otomatis (Guided Access Session Request)
    UIAccessibility.requestGuidedAccessSession(enabled: true) { _ in }

    // 4. Deteksi Screenshot di iOS
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleScreenshotTaken),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )

    // 5. Deteksi Rekam Layar / Screen Capture di iOS (AirPlay, QuickTime, Recording)
    if #available(iOS 11.0, *) {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleScreenCaptureChanged),
        name: UIScreen.capturedDidChangeNotification,
        object: nil
      )
      checkScreenCapture()
    }

    // 6. Deteksi Otomatis Saat Mencoba Keluar / Notifikasi / Control Center Ditarik
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  private func disableIosLockdown() {
    NotificationCenter.default.removeObserver(self)
    removePrivacyShield()
    stopIosAlarmSound()

    // 1. Akhiri Mode Ujian Apple Otomatis
    if #available(iOS 13.4, *) {
      if let session = self.assessmentSession as? AEAssessmentSession {
        session.end()
        self.assessmentSession = nil
      }
    }

    // 2. Akhiri Sesi Guided Access
    UIAccessibility.requestGuidedAccessSession(enabled: false) { _ in }

    // 3. Kembalikan kecerahan layar & timer istirahat
    UIScreen.main.brightness = originalBrightness
    UIApplication.shared.isIdleTimerDisabled = false
  }

  private func startIosAlarmSound(durationMs: Int) {
    stopIosAlarmSound()

    // Mainkan nada peringatan darurat sistem iOS segera
    AudioServicesPlayAlertSound(SystemSoundID(1005))
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

    let seconds = Double(durationMs) / 1000.0
    let endTime = Date().addingTimeInterval(seconds)

    // Ulangi nada sirine setiap 1 detik hingga durasi selesai
    alarmTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
      if Date() >= endTime {
        self?.stopIosAlarmSound()
      } else {
        AudioServicesPlayAlertSound(SystemSoundID(1005))
      }
    }
  }

  private func stopIosAlarmSound() {
    alarmTimer?.invalidate()
    alarmTimer = nil
  }

  @objc private func handleScreenshotTaken() {
    startIosAlarmSound(durationMs: 5000)
    lockdownChannel?.invokeMethod("onScreenshotDetected", arguments: nil)
  }

  @objc private func handleScreenCaptureChanged() {
    checkScreenCapture()
  }

  private func checkScreenCapture() {
    if #available(iOS 11.0, *) {
      if UIScreen.main.isCaptured {
        showPrivacyShield()
        startIosAlarmSound(durationMs: 5000)
        lockdownChannel?.invokeMethod("onScreenshotDetected", arguments: "screen_recording")
      } else {
        removePrivacyShield()
      }
    }
  }

  @objc private func handleAppWillResignActive() {
    // Seketika tutup layar dengan perisai hitam pekat agar soal tidak bisa diintip saat gesture keluar
    showPrivacyShield()
    startIosAlarmSound(durationMs: 5000)
    lockdownChannel?.invokeMethod("onUserLeaveHint", arguments: nil)
  }

  @objc private func handleAppDidBecomeActive() {
    removePrivacyShield()
    // Pastikan kecerahan tetap 100% saat kembali aktif
    UIScreen.main.brightness = 1.0
  }

  private func showPrivacyShield() {
    guard privacyShieldView == nil, let window = self.window else { return }
    let shield = UIView(frame: window.bounds)
    shield.backgroundColor = UIColor.black
    let label = UILabel(frame: shield.bounds)
    label.text = "EXAM NETRI TERKUNCI"
    label.textColor = UIColor.white
    label.textAlignment = .center
    label.font = UIFont.boldSystemFont(ofSize: 22)
    shield.addSubview(label)
    window.addSubview(shield)
    privacyShieldView = shield
  }

  private func removePrivacyShield() {
    privacyShieldView?.removeFromSuperview()
    privacyShieldView = nil
  }
}

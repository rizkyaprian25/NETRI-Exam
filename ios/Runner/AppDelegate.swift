import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var lockdownChannel: FlutterMethodChannel?
  private var privacyShieldView: UIView?

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
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func enableIosLockdown() {
    NotificationCenter.default.removeObserver(self)

    // 1. Deteksi Screenshot di iOS
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleScreenshotTaken),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )

    // 2. Deteksi Rekam Layar / Screen Capture di iOS (AirPlay, QuickTime, Recording)
    if #available(iOS 11.0, *) {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleScreenCaptureChanged),
        name: UIScreen.capturedDidChangeNotification,
        object: nil
      )
      checkScreenCapture()
    }

    // 3. Deteksi saat aplikasi kehilangan fokus (App Switcher, Notifikasi, Control Center)
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
  }

  @objc private func handleScreenshotTaken() {
    lockdownChannel?.invokeMethod("onScreenshotDetected", arguments: nil)
  }

  @objc private func handleScreenCaptureChanged() {
    checkScreenCapture()
  }

  private func checkScreenCapture() {
    if #available(iOS 11.0, *) {
      if UIScreen.main.isCaptured {
        showPrivacyShield()
        lockdownChannel?.invokeMethod("onScreenshotDetected", arguments: "screen_recording")
      } else {
        removePrivacyShield()
      }
    }
  }

  @objc private func handleAppWillResignActive() {
    showPrivacyShield()
    lockdownChannel?.invokeMethod("onUserLeaveHint", arguments: nil)
  }

  @objc private func handleAppDidBecomeActive() {
    removePrivacyShield()
  }

  private func showPrivacyShield() {
    guard privacyShieldView == nil, let window = self.window else { return }
    let shield = UIView(frame: window.bounds)
    shield.backgroundColor = UIColor.black
    let label = UILabel(frame: shield.bounds)
    label.text = "EXAMBRO TERKUNCI"
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

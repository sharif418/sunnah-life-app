import Flutter
import UIKit

/// Sunnah Life iOS surface.
///
/// The Dart side calls these channels through `services/platform_channels.dart`:
///  · "sunnahlife/prayer" — exact alarms + DND. iOS has no AlarmManager;
///    these return `false` and scheduling is handled by
///    flutter_local_notifications (UNUserNotificationCenter) on this platform.
///    DND auto-silent is NOT possible on iOS (no public API) — the Dart
///    layer surfaces the Android-only card and treats `false` as unsupported.
///  · "sunnahlife/widget" — home-widget updates. WidgetKit is the iOS path:
///    see ios/README.md for the (documented) stub status — no macOS host
///    exists in the sandbox, so the widget target is added when signing
///    on a real Mac.
///  · "sunnahlife/system" — UIActivityViewController share sheet.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let registry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: registry)

    guard let messenger = registry.registrar(forPlugin: "SunnahLifeChannels")?.messenger() else {
      return
    }

    // sunnahlife/prayer — exact alarms + DND are Android-only capabilities.
    FlutterMethodChannel(name: "sunnahlife/prayer", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "canScheduleExactAlarms":
          // Notifications themselves are allowed; the exact-alarm concept
          // does not exist on iOS.
          result(true)
        case "setAutoSilent", "isDndGranted":
          result(false)
        default:
          result(false)
        }
      }

    // sunnahlife/widget — WidgetKit extension point (see ios/README.md).
    FlutterMethodChannel(name: "sunnahlife/widget", binaryMessenger: messenger)
      .setMethodCallHandler { _, result in
        result(nil)
      }

    // sunnahlife/system — native share sheet.
    FlutterMethodChannel(name: "sunnahlife/system", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        if call.method == "shareText",
           let args = call.arguments as? [String: Any],
           let text = args["text"] as? String {
          let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
          if let root = UIApplication.shared.connectedScenes
              .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
              .first {
            root.present(vc, animated: true)
            result(true)
            return
          }
        }
        result(nil)
      }
  }
}

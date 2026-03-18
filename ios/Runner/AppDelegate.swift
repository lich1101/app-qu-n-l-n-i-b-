import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let pushEnvironmentChannelName = "vn.clickon.jobnew/push_environment"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: pushEnvironmentChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "getApnsEnvironment":
          result(self?.currentApnsEnvironment())
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func currentApnsEnvironment() -> String? {
    guard let environment = Bundle.main.object(
      forInfoDictionaryKey: "APNS_ENVIRONMENT"
    ) as? String else {
      return nil
    }

    let normalized = environment
      .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
      .lowercased()
    return normalized.isEmpty ? nil : normalized
  }
}

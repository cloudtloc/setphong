import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let ts = ISO8601DateFormatter().string(from: Date())
    let rawKey = (Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String) ?? ""
    let apiKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
    if apiKey.isEmpty || apiKey.hasPrefix("$(") {
      NSLog("ios_maps_init_error peerId=ios seq=-1 timestamp=%@ reason=missing_google_maps_api_key", ts)
    } else {
      GMSServices.provideAPIKey(apiKey)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

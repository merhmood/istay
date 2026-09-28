import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // iOS needs the Maps key handed to the SDK in native code - there is no
    // manifest equivalent to Android's. It is read from Info.plist, which in
    // turn resolves it from Maps.xcconfig, so the key stays out of source
    // control the same way local.properties keeps it out on Android.
    if let key = Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String, !key.isEmpty {
      GMSServices.provideAPIKey(key)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

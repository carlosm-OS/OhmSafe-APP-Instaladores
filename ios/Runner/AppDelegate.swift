import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Route APNs callbacks through UNUserNotificationCenter. FlutterAppDelegate
    // already implements the delegate methods that firebase_messaging hooks
    // into; without this assignment the plugin never receives the APNs token
    // and getToken() returns null forever on a real device.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Puente de cámaras EZVIZ (2026-10-17): conectar la cámara a la Wi-Fi de la casa desde el
    // teléfono del instalador. Sin el pod (OHMSAFE_EZVIZ=0) contesta EZVIZ_NOT_LINKED.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "EzvizPlugin") {
      EzvizPlugin.register(with: registrar)
    }
  }
}

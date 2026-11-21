import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "YouleErpWebView") {
      let binding = FlutterMethodChannel(name: "youle/printer-binding", binaryMessenger: registrar.messenger())
      binding.setMethodCallHandler { call, result in
        switch call.method {
        case "boundName": result(UserDefaults.standard.string(forKey: "connectedPrinterName"))
        case "currentName": result(YouleConnectedPrinter())
        case "cancelConnection": YouleCancelConnection(); result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
      registrar.register(ErpWebFactory(messenger: registrar.messenger()), withId: "youle/erp-web")
    }
  }
}

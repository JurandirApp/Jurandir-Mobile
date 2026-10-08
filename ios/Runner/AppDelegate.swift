import Flutter
import UIKit
import firebase_messaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // iOS 27 / UIScene: a Apple exige que o UNUserNotificationCenter.delegate seja
    // configurado ANTES do didFinishLaunching retornar. Como adotamos o UIScene
    // (plugins registram depois, em didInitializeImplicitFlutterEngine), o
    // firebase_messaging crashava na ABERTURA no iOS 27 ("unrecognized selector
    // synchronize"). Esta chamada faz a config no tempo certo. Ver pub.dev/firebase_messaging.
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

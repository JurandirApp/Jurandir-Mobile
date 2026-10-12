import Flutter
import UIKit
import firebase_messaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Tem que rodar ANTES da cena conectar (é lá que o iOS 27 crashava).
    SynchronizeShim.install()
    // UIScene: o UNUserNotificationCenter.delegate precisa ser configurado antes
    // do didFinishLaunching retornar (plugins registram depois, no engine implícito).
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

/// Rede de segurança do crash de abertura no iOS 27 (builds 24/25 recusados pela
/// Apple): uma dependência (Firebase, pela symbolicação) manda `synchronize` pra
/// um objeto que não tem esse método → NSInvalidArgumentException → abort.
///
/// Adiciona um `synchronize` NO-OP em NSObject via `class_addMethod`, que só vale
/// pra classes que NÃO implementam o seu — NSUserDefaults & cia. continuam usando
/// o próprio. O `synchronize` não faz nada útil hoje (o iOS persiste sozinho).
///
/// Quando dispara, avisa o backend (`/api/public/diag`) com a classe + a pilha, pra
/// identificar o culpado de verdade e trocar este contorno pela correção definitiva.
enum SynchronizeShim {
  private static var reported = false

  static func install() {
    let sel = NSSelectorFromString("synchronize")
    let block: @convention(block) (AnyObject) -> Bool = { obj in
      report(String(describing: type(of: obj)))
      return true
    }
    // class_addMethod NÃO sobrescreve: se NSObject já tivesse, falharia sem efeito.
    class_addMethod(NSObject.self, sel, imp_implementationWithBlock(block), "B@:")
  }

  private static func report(_ cls: String) {
    let frames = Thread.callStackSymbols.prefix(14).joined(separator: " | ")
    NSLog("JUR_SYNC_SHIM class=%@ stack=%@", cls, frames)
    if reported { return }
    reported = true
    var comps = URLComponents(string: "https://jurandir.app.br/api/public/diag")
    let info = Bundle.main.infoDictionary
    comps?.queryItems = [
      URLQueryItem(name: "ev", value: "sync_shim"),
      URLQueryItem(name: "cls", value: cls),
      URLQueryItem(name: "os", value: UIDevice.current.systemVersion),
      URLQueryItem(name: "model", value: UIDevice.current.model),
      URLQueryItem(name: "build", value: info?["CFBundleVersion"] as? String),
      URLQueryItem(name: "stack", value: String(frames.prefix(1800))),
    ]
    guard let url = comps?.url else { return }
    URLSession.shared.dataTask(with: url).resume() // fire-and-forget
  }
}

#if os(iOS)
import UIKit
import Agilis

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let config = WindowConfig(
            title: "Agilis iOS Demo",
            width: 0,     // Ignored on iOS — uses screen bounds
            height: 0,
            targetFPS: 60,
            resizable: false
        )

        let vc = AgilisViewController()
        vc.application = Application(config: config)
        vc.application.sceneManager.push(TouchScene(), app: vc.application)

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()

        return true
    }
}
#endif

#if os(iOS)
import Agilis
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    // swiftlint:disable discouraged_optional_collection
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // swiftlint:enable discouraged_optional_collection
        let config = WindowConfig(
            title: "Agilis iOS Demo",
            width: 0,
            height: 0,
            targetFPS: 60,
            resizable: false
        )

        let app = Application(config: config)
        app.sceneManager.push(MenuScene(), app: app)

        let vc = AgilisViewController()
        vc.application = app

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()

        return true
    }
}
#endif

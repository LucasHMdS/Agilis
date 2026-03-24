#if os(iOS)
import UIKit

/// A UIViewController that drives an Agilis game loop via `CADisplayLink`.
///
/// Set ``application`` before the view appears. The controller initializes
/// the engine in `viewDidAppear` and tears it down on `deinit`.
///
/// ```swift
/// let vc = AgilisViewController()
/// vc.application = Application(config: WindowConfig(title: "My Game", width: 0, height: 0))
/// vc.application.sceneManager.push(MyScene(), app: vc.application)
/// window.rootViewController = vc
/// ```
open class AgilisViewController: UIViewController {
    /// The Agilis application to run. Must be set before the view appears.
    public var application: Application?

    nonisolated(unsafe) private var displayLink: CADisplayLink?
    nonisolated(unsafe) private var started = false

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started, let application else { return }
        started = true
        do {
            try application.start()
        } catch {
            fatalError("Agilis failed to start: \(error)")
        }
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .default)
    }

    @objc private func tick() {
        application?.frame()
    }

    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        displayLink?.invalidate()
        displayLink = nil
        if started {
            application?.stop()
            started = false
        }
    }

    deinit {
        displayLink?.invalidate()
        if started {
            application?.stop()
        }
    }

    override open var prefersStatusBarHidden: Bool { true }

    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }

    override open var shouldAutorotate: Bool { true }
}
#endif

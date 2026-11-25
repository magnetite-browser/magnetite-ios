import Observation
import SwiftUI
import UIKit

/// The app's start. UIKit's life cycle rather than SwiftUI's: only a view
/// controller of our own can set the status bar's style, which follows the
/// colour of the page in front (`RootController`).
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    @MainActor static let browser = Browser()

    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = RootController(browser: AppDelegate.browser)
        window.makeKeyAndVisible()
        self.window = window
        open(options.urlContexts)
    }

    /// A link from another app, Magnetite being the default browser.
    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        open(contexts)
    }

    /// Web pages open as new tabs of the space in front; nothing else does.
    private func open(_ contexts: Set<UIOpenURLContext>) {
        for url in contexts.map(\.url) where ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            AppDelegate.browser.open(url)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AppDelegate.browser.syncIfDue()
    }

    /// The tabs as they are when the app is put away.
    func sceneDidEnterBackground(_ scene: UIScene) {
        Task { await AppDelegate.browser.shareTabs() }
    }
}

/// What the status bar shows its text on, as `RootView` tells it: a dark
/// or a light page; `nil`: the app's own background.
@MainActor @Observable
final class StatusBar {
    var overDarkPage: Bool?
}

/// Hosts `RootView` and gives the status bar light text over a dark page.
final class RootController: UIHostingController<AnyView> {
    private let statusBar = StatusBar()

    init(browser: Browser) {
        super.init(rootView: AnyView(
            RootView().environment(browser).environment(browser.sync).environment(statusBar)
        ))
        follow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        switch statusBar.overDarkPage {
        case true?: .lightContent
        case false?: .darkContent
        case nil: .default
        }
    }

    /// Ask for the style again whenever what it depends on changed.
    private func follow() {
        withObservationTracking {
            _ = statusBar.overDarkPage
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.setNeedsStatusBarAppearanceUpdate()
                self?.follow()
            }
        }
    }
}

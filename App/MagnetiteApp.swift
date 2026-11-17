import SwiftUI

@main
struct MagnetiteApp: App {
    @State private var browser = Browser()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(browser)
                .environment(browser.sync)
                .onChange(of: phase) { _, now in
                    switch now {
                    case .active: browser.syncIfDue()
                    // The tabs as they are when the app is put away.
                    case .background: Task { await browser.shareTabs() }
                    default: break
                    }
                }
        }
    }
}

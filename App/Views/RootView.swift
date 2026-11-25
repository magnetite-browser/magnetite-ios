import SwiftUI

/// On a narrow screen (iPhone, an iPad window beside another app): the page
/// in front, from the status bar down, with the bar floating over its
/// bottom, and the sidebar as the start page and as a sheet. On a wide one
/// (iPad): the sidebar beside the page, as on the desktop, with the bar
/// above the page.
struct RootView: View {
    @Environment(Browser.self) private var browser
    @Environment(Sync.self) private var sync
    @Environment(StatusBar.self) private var statusBar
    @Environment(\.horizontalSizeClass) private var width
    /// Narrow: the sidebar sheet is up. Wide: the sidebar column is shown.
    @State private var sheetShown = false
    @State private var columnShown = true
    /// Narrow: the downloads, from the card over the bar.
    @State private var downloadsShown = false

    var body: some View {
        Group {
            if width == .regular { wide } else { narrow }
        }
        .onChange(of: sync.sidebar) { browser.settle() }
        .onChange(of: overDarkPage, initial: true) { statusBar.overDarkPage = overDarkPage }
        .tint(browser.space.tint)
    }

    /// Whether the status bar is over a dark page; `nil`: over the app's own
    /// background.
    private var overDarkPage: Bool? {
        guard width != .regular, browser.frontTab != nil else { return nil }
        return page?.topColor?.isDark
    }

    private var page: WebPage? { browser.frontTab.map(browser.page(for:)) }

    private var narrow: some View {
        // A ZStack, not a Group: a Group would give each of its views a bar
        // of its own, and switching between page and start page would lose
        // what the bar holds (the keyboard, the text typed).
        ZStack {
            if let tab = browser.frontTab, let page {
                PageView(page: page)
                    .id(tab.id)
                    // Under the bar, which keeps the end of the page clear,
                    // and under the keyboard, which the page makes room for itself.
                    .ignoresSafeArea(edges: .bottom)
                    .onAppear { page.keepClear(bottom: PhoneBar.height) }
                    // What is above the page: its top colour.
                    .background((page.topColor.map(Color.init(uiColor:)) ?? Color(.systemBackground)).ignoresSafeArea())
            } else {
                SidebarView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // The download card sits above the bar, not in it: the bar
            // measures itself to rise onto the keyboard, which then simply
            // covers the card.
            VStack(spacing: 0) {
                DownloadCard { downloadsShown = true }
                    .padding(.horizontal, 14)
                PhoneBar(page: page, sidebarShown: $sheetShown)
            }
            .animation(.smooth(duration: 0.3), value: browser.downloads.recent)
        }
        .sheet(isPresented: $downloadsShown) { DownloadsView() }
        // The bar moves for the keyboard by itself; a page makes room itself.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $sheetShown) {
            SidebarView(dismissable: true)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: browser.front) { sheetShown = false }
    }

    private var wide: some View {
        HStack(spacing: 0) {
            if columnShown {
                SidebarView()
                    .frame(width: 320)
                    .transition(.move(edge: .leading))
                Divider().ignoresSafeArea()
            }
            VStack(spacing: 0) {
                TopBar(page: page, sidebarShown: $columnShown)
                if let tab = browser.frontTab, let page {
                    PageView(page: page).id(tab.id)
                } else {
                    ContentUnavailableView("No Tab Open", systemImage: "square.on.square.dashed",
                                           description: Text("Pick a page from the sidebar, or type an address above."))
                }
            }
        }
        .animation(.default, value: columnShown)
    }
}

/// A page, and what is shown when it cannot be loaded. How far it loaded
/// shows in the address field.
private struct PageView: View {
    let page: WebPage

    var body: some View {
        WebView(page: page)
            .ignoresSafeArea(.container, edges: .horizontal)
            .overlay {
                if let failure = page.failure {
                    ContentUnavailableView {
                        Label("This page cannot be opened", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(failure)
                    } actions: {
                        Button("Try again") { page.reload() }
                            .buttonStyle(.borderedProminent)
                    }
                    .background(.background)
                }
            }
    }
}

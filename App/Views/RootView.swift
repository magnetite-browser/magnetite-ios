import SwiftUI

/// On a narrow screen (iPhone, an iPad window beside another app): the page
/// in front with the bar below it, and the sidebar as the start page and as
/// a sheet. On a wide one (iPad): the sidebar beside the page, as on the
/// desktop, with the bar above the page.
struct RootView: View {
    @Environment(Browser.self) private var browser
    @Environment(Sync.self) private var sync
    @Environment(\.horizontalSizeClass) private var width
    /// Narrow: the sidebar sheet is up. Wide: the sidebar column is shown.
    @State private var sheetShown = false
    @State private var columnShown = true

    var body: some View {
        Group {
            if width == .regular { wide } else { narrow }
        }
        .onChange(of: sync.sidebar) { browser.settle() }
        .tint(browser.space.tint)
    }

    private var page: WebPage? { browser.frontTab.map(browser.page(for:)) }

    private var narrow: some View {
        Group {
            if let tab = browser.frontTab, let page {
                PageView(page: page).id(tab.id)
            } else {
                SidebarView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AddressBar(page: page, sidebarShown: $sheetShown)
        }
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
                AddressBar(page: page, sidebarShown: $columnShown, wide: true)
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

/// A page, its loading bar, and what is shown when it cannot be loaded.
private struct PageView: View {
    let page: WebPage

    var body: some View {
        WebView(page: page)
            .ignoresSafeArea(.container, edges: .horizontal)
            .overlay(alignment: .top) {
                if page.loading {
                    ProgressView(value: page.progress)
                        .progressViewStyle(.linear)
                        .frame(height: 2)
                }
            }
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

extension Space {
    /// The space's colour, for buttons and marks; none: the app's own.
    var tint: Color? {
        accent.map { Color(red: Double($0.red), green: Double($0.green), blue: Double($0.blue)) }
    }

    /// The icon when it is an emoji. The desktop's named icons are not
    /// drawn here.
    var emoji: String? {
        guard let icon, icon.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation || $0.value > 0x238C })
        else { return nil }
        return icon
    }
}

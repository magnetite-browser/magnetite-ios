import SwiftUI

/// Back and forward, the address field, and the way to the sidebar. Below
/// the page on a narrow screen, above it on a wide one (`wide`), where its
/// sidebar button shows and hides the sidebar column.
struct AddressBar: View {
    @Environment(Browser.self) private var browser
    /// The page in front, if a tab is.
    let page: WebPage?
    @Binding var sidebarShown: Bool
    var wide = false

    @State private var text = ""
    @FocusState private var editing: Bool

    var body: some View {
        HStack(spacing: 14) {
            if wide {
                Button("Sidebar", systemImage: "sidebar.left") { sidebarShown.toggle() }
                    .keyboardShortcut("s", modifiers: .command)
            }
            if let page, !editing {
                Button("Back", systemImage: "chevron.backward") { page.view.goBack() }
                    .disabled(!page.canGoBack)
                    .keyboardShortcut("[", modifiers: .command)
                Button("Forward", systemImage: "chevron.forward") { page.view.goForward() }
                    .disabled(!page.canGoForward)
                    .keyboardShortcut("]", modifiers: .command)
            }
            field
            if editing {
                Button("Cancel") { editing = false }
                    .keyboardShortcut(.cancelAction)
            } else if page != nil {
                menu
                if !wide {
                    Button("Tabs", systemImage: "sidebar.left") { sidebarShown = true }
                }
            }
        }
        .labelStyle(.iconOnly)
        .font(.body.weight(.medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
        .background { keys }
        .onChange(of: editing) { _, now in
            if now { text = page?.url?.absoluteString ?? "" }
        }
    }

    /// Keys of a hardware keyboard that have no button of their own.
    private var keys: some View {
        Group {
            Button("Open Address") { editing = true }
                .keyboardShortcut("l", modifiers: .command)
            Button("New Tab") {
                browser.showSidebar()
                editing = true
            }
            .keyboardShortcut("t", modifiers: .command)
            if let tab = browser.frontTab {
                Button("Close Tab") { browser.close(tab) }
                    .keyboardShortcut("w", modifiers: .command)
            }
            if let page {
                Button("Reload") { page.reload() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    private var field: some View {
        HStack(spacing: 6) {
            TextField("Search or enter address", text: $text)
                .focused($editing)
                .keyboardType(.webSearch)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit {
                    browser.go(text)
                    text = ""
                }
                // While not typing, the field shows the site in its place.
                .opacity(editing || page == nil ? 1 : 0)
                .overlay {
                    if let page, !editing {
                        Text(page.url.map(Address.site(of:)) ?? "")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .allowsHitTesting(false)
                    }
                }
            if let page, !editing {
                if page.loading {
                    Button("Stop", systemImage: "xmark") { page.view.stopLoading() }
                } else {
                    Button("Reload", systemImage: "arrow.clockwise") { page.reload() }
                }
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(.quaternary, in: .rect(cornerRadius: 12))
    }

    private var menu: some View {
        Menu("More", systemImage: "ellipsis") {
            // The start page: its address field opens a new tab.
            Button("New Tab", systemImage: "plus") { browser.showSidebar() }
            if let url = page?.url {
                ShareLink(item: url)
                Button("Copy Link", systemImage: "link") { UIPasteboard.general.url = url }
            }
            if let tab = browser.frontTab, browser.sync.joined {
                Button("Send to Desktop", systemImage: "desktopcomputer") { browser.sendToDesktop(tab) }
            }
            if let tab = browser.frontTab {
                Button("Close Tab", systemImage: "xmark", role: .destructive) { browser.close(tab) }
            }
        }
    }
}

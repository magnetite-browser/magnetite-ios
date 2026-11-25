import SwiftUI
import UIKit

// MARK: Narrow screens

/// The bar of a narrow screen, floating over the bottom of the page: back,
/// the address, the page's menu and the way to the sidebar. While the reader
/// scrolls down into a page it shrinks to the site's name.
struct PhoneBar: View {
    @Environment(Browser.self) private var browser
    /// The page in front, if a tab is.
    let page: WebPage?
    @Binding var sidebarShown: Bool

    @State private var text = ""
    @FocusState private var editing: Bool
    /// Where the keyboard begins, in the window; `nil`: no keyboard. It is
    /// the address field's, a page's, or Find on Page's bar (which can stay
    /// up without keys).
    @State private var keyboardTop: CGFloat?
    /// Where the bar ends while it rests at the bottom, in the window.
    @State private var restingBottom: CGFloat = 0
    /// The window's top edge that content keeps clear of (the status bar).
    @State private var topInset: CGFloat = 0
    @State private var historyShown = false

    /// The height the bar keeps clear at the page's bottom edge.
    static let height: CGFloat = 60

    private var small: Bool { page?.reading == true && !editing }

    var body: some View {
        VStack(spacing: 8) {
            // While typing: what the text could mean, just above the field.
            if editing {
                SuggestionList(text: text, maxHeight: room) {
                    editing = false
                    text = ""
                }
            }
            ZStack {
                if small, let page {
                    SiteLabel(page: page)
                        .transition(.blurReplace)
                } else {
                    full
                        .transition(.blurReplace)
                }
            }
        }
        .animation(.smooth(duration: 0.3), value: small)
        .animation(.smooth(duration: 0.25), value: editing)
        .padding(.horizontal, 14)
        .padding(.vertical, small ? 2 : 8)
        .frame(maxWidth: .infinity)
        // Typing in the page or finding in it: the bar steps aside. It stays
        // in place, so that the address field can take the keyboard.
        .opacity(aside ? 0 : 1)
        .allowsHitTesting(!aside)
        .background { HardwareKeys(page: page, editing: $editing, newTab: newTab) { historyShown = true } }
        .sheet(isPresented: $historyShown) { HistoryView() }
        // A page picked while typing ends the typing.
        .onChange(of: browser.front) { _, now in
            if now != nil { editing = false }
        }
        // The bar follows the keyboard by itself (the layout ignores it):
        // SwiftUI's own room for the keyboard stays too large after Find on
        // Page, whose bar leaves without a last keyboard notification.
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { restingBottom = $0 }
        .offset(y: editing ? -lift : 0)
        .animation(.smooth(duration: 0.3), value: editing ? lift : 0)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let window = UIApplication.shared.connectedScenes.lazy
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first
            else { return }
            let top = window.convert(end, from: window.screen.coordinateSpace).minY
            keyboardTop = top < window.bounds.maxY ? top : nil
            topInset = window.safeAreaInsets.top
            page?.watchFind { keyboardTop = nil }
        }
    }

    private var aside: Bool { keyboardTop != nil && !editing }

    /// The start page, typing an address.
    private func newTab() {
        browser.showSidebar()
        editing = true
    }

    /// How far the bar moves up to sit on the keyboard.
    private var lift: CGFloat {
        keyboardTop.map { max(0, restingBottom - $0) } ?? 0
    }

    /// The height between the status bar and the bar on the keyboard.
    private var room: CGFloat {
        max(120, restingBottom - lift - Self.height - topInset - 12)
    }

    private var full: some View {
        GlassGroup {
            HStack(spacing: 8) {
                if let page, !editing {
                    RoundButton("Back", systemImage: "chevron.backward") { page.view.goBack() }
                        .disabled(!page.canGoBack)
                }
                AddressField(page: page, text: $text, editing: $editing)
                if editing {
                    RoundButton("Cancel", systemImage: "xmark") { editing = false }
                } else if let page {
                    PageMenu(page: page, newTab: newTab) { historyShown = true }
                    TabsButton { sidebarShown = true }
                }
            }
        }
    }
}

/// The bar while reading: the site's name, small. A tap brings the bar back.
private struct SiteLabel: View {
    let page: WebPage

    var body: some View {
        Button {
            page.reading = false
        } label: {
            Text(page.url.map(Address.site(of:)) ?? "")
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(height: 30)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glass(in: Capsule())
    }
}

/// The way to the sidebar: the number of tabs open in the space in front,
/// in its colour.
private struct TabsButton: View {
    @Environment(Browser.self) private var browser
    let action: () -> Void

    var body: some View {
        let count = browser.tabs(in: browser.space).count
        Button(action: action) {
            Text(count < 100 ? "\(count)" : "99+")
                .font(.system(size: count < 10 ? 13 : 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.tint)
                .frame(width: 22, height: 22)
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.tint, lineWidth: 2))
        }
        .buttonStyle(BarButtonStyle())
        .glass(in: Circle())
        .accessibilityLabel("Tabs")
        .accessibilityValue("\(count)")
    }
}

// MARK: Wide screens

/// The bar above the page on a wide screen (iPad), beside the sidebar
/// column, which its first button shows and hides.
struct TopBar: View {
    @Environment(Browser.self) private var browser
    let page: WebPage?
    @Binding var sidebarShown: Bool

    @State private var text = ""
    @FocusState private var editing: Bool
    @State private var historyShown = false

    var body: some View {
        HStack(spacing: 6) {
            RoundButton("Sidebar", systemImage: "sidebar.left") { sidebarShown.toggle() }
                .keyboardShortcut("s", modifiers: .command)
            if let page {
                RoundButton("Back", systemImage: "chevron.backward") { page.view.goBack() }
                    .disabled(!page.canGoBack)
                RoundButton("Forward", systemImage: "chevron.forward") { page.view.goForward() }
                    .disabled(!page.canGoForward)
            }
            AddressField(page: page, text: $text, editing: $editing)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            if let page {
                PageMenu(page: page, newTab: newTab) { historyShown = true }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
        // While typing: what the text could mean, over the page below.
        .overlay(alignment: .top) {
            if editing {
                SuggestionList(text: text, maxHeight: 420) {
                    editing = false
                    text = ""
                }
                .frame(maxWidth: 560)
                .offset(y: 62)
            }
        }
        .zIndex(1)
        .background { HardwareKeys(page: page, editing: $editing, newTab: newTab) { historyShown = true } }
        .sheet(isPresented: $historyShown) { HistoryView() }
        // A page picked in the sidebar while typing ends the typing; New Tab
        // (no page in front) keeps it.
        .onChange(of: browser.front) { _, now in
            if now != nil { editing = false }
        }
    }

    /// The start page, typing an address.
    private func newTab() {
        browser.showSidebar()
        editing = true
    }
}

// MARK: Shared

/// The address of the page in front: its site while browsing (reloading is
/// in the page's menu, and pulling the page down), a text field while
/// typing. A tap starts typing, with the address selected so that what is
/// typed replaces it.
struct AddressField: View {
    @Environment(Browser.self) private var browser
    let page: WebPage?
    @Binding var text: String
    var editing: FocusState<Bool>.Binding

    private var typing: Bool { editing.wrappedValue || page == nil }

    var body: some View {
        HStack(spacing: 8) {
            if typing {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
            }
            TextField("Search or enter address", text: $text)
                .focused(editing)
                .keyboardType(.webSearch)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit {
                    browser.go(text)
                    text = ""
                }
                // While not typing, the field shows the site in its place.
                .opacity(typing ? 1 : 0)
                .overlay {
                    if let page, !typing {
                        Button { editing.wrappedValue = true } label: { site(of: page) }
                            .buttonStyle(.plain)
                            .accessibilityHint("Edit the address")
                            .accessibilityIdentifier("address")
                    }
                }
            if let page, !typing, page.loading {
                Button("Stop", systemImage: "xmark") { page.view.stopLoading() }
            } else if editing.wrappedValue, !text.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") {
                    text = ""
                    // The tap may take the keyboard from the field.
                    editing.wrappedValue = true
                }
                    .foregroundStyle(.secondary)
            }
        }
        .labelStyle(.iconOnly)
        .font(.callout)
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .frame(height: 44)
        .overlay(alignment: .bottom) {
            if let page, page.loading { progress(page.progress) }
        }
        .glass(in: Capsule())
        .onChange(of: editing.wrappedValue) { _, now in
            guard now else { return }
            text = page?.url?.absoluteString ?? ""
            // Select it once the field took the keyboard.
            Task { @MainActor in
                UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
            }
        }
    }

    /// The site's name; a page without https says so.
    private func site(of page: WebPage) -> some View {
        HStack(spacing: 4) {
            if page.url?.scheme == "http" {
                Image(systemName: "lock.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Not secure")
            }
            Text(page.url.map(Address.site(of:)) ?? "")
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
    }

    private func progress(_ share: Double) -> some View {
        GeometryReader { space in
            Capsule()
                .fill(.tint)
                .frame(width: max(8, space.size.width * share), height: 2.5)
        }
        .frame(height: 2.5)
        .padding(.horizontal, 20)
        .padding(.bottom, 1)
        .allowsHitTesting(false)
        .animation(.linear(duration: 0.2), value: share)
    }
}

/// What can be done with the page in front. `newTab` goes to the start
/// page and starts typing an address; `history` shows the history.
struct PageMenu: View {
    @Environment(Browser.self) private var browser
    @Bindable var page: WebPage
    let newTab: () -> Void
    let history: () -> Void

    var body: some View {
        Menu {
            ControlGroup {
                Button("Back", systemImage: "chevron.backward") { page.view.goBack() }
                    .disabled(!page.canGoBack)
                Button("Forward", systemImage: "chevron.forward") { page.view.goForward() }
                    .disabled(!page.canGoForward)
                Button("Reload", systemImage: "arrow.clockwise") { page.reload() }
            }
            Section {
                Button("Find on Page", systemImage: "doc.text.magnifyingglass") { page.findOnPage() }
                ControlGroup {
                    Button("Smaller Text", systemImage: "textformat.size.smaller") { page.zoom(by: -1) }
                        .disabled(page.zoom <= 0.5)
                    Button("\(Int((page.zoom * 100).rounded())) %") { page.zoomReset() }
                    Button("Larger Text", systemImage: "textformat.size.larger") { page.zoom(by: 1) }
                        .disabled(page.zoom >= 3)
                }
                Toggle("Desktop Site", systemImage: "desktopcomputer", isOn: $page.desktopSite)
            }
            if let url = page.url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
               let tab = browser.frontTab, browser.sync.joined, browser.sync.sidebar != nil,
               let space = browser.spaces.first(where: { $0.id == tab.space }) {
                // A desktop of the chain makes these (`Sync`).
                Section {
                    if !space.pinned.contains(where: { $0.item.page?.url == url.absoluteString }) {
                        Button("Pin in “\(space.title)”", systemImage: "pin") {
                            browser.change { await $0.pin(url, title: page.title, in: space) }
                        }
                    }
                    if !space.favorites.contains(where: { $0.url == url.absoluteString }) {
                        Button("Add to Favorites", systemImage: "star") {
                            browser.change { await $0.addFavorite(url, title: page.title, in: space) }
                        }
                    }
                }
            }
            Section {
                if let url = page.url {
                    ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                    Button("Copy Link", systemImage: "link") { UIPasteboard.general.url = url }
                }
                if let tab = browser.frontTab, browser.sync.joined {
                    Button("Send to Desktop", systemImage: "laptopcomputer.and.arrow.down") {
                        browser.sendToDesktop(tab)
                    }
                }
            }
            Section {
                Button("History", systemImage: "clock", action: history)
                Button("New Tab", systemImage: "plus", action: newTab)
                if let tab = browser.frontTab {
                    Button("Close Tab", systemImage: "xmark", role: .destructive) { browser.close(tab) }
                }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(BarButtonStyle())
        .glass(in: Circle())
    }
}

/// Keys of a hardware keyboard that have no button of their own.
private struct HardwareKeys: View {
    @Environment(Browser.self) private var browser
    let page: WebPage?
    var editing: FocusState<Bool>.Binding
    let newTab: () -> Void
    let history: () -> Void

    var body: some View {
        Group {
            Button("Open Address") { editing.wrappedValue = true }
                .keyboardShortcut("l", modifiers: .command)
            Button("New Tab", action: newTab)
                .keyboardShortcut("t", modifiers: .command)
            Button("History", action: history)
                .keyboardShortcut("y", modifiers: .command)
            if let tab = browser.frontTab {
                Button("Close Tab") { browser.close(tab) }
                    .keyboardShortcut("w", modifiers: .command)
            }
            if let page {
                Button("Reload") { page.reload() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Find on Page") { page.findOnPage() }
                    .keyboardShortcut("f", modifiers: .command)
                if editing.wrappedValue {
                    Button("Cancel") { editing.wrappedValue = false }
                        .keyboardShortcut(.cancelAction)
                } else {
                    Button("Back") { page.view.goBack() }
                        .keyboardShortcut("[", modifiers: .command)
                    Button("Forward") { page.view.goForward() }
                        .keyboardShortcut("]", modifiers: .command)
                }
            }
        }
        .opacity(0)
        .accessibilityHidden(true)
    }
}

/// A round button of a bar: an icon on glass.
private struct RoundButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(BarButtonStyle())
            .glass(in: Circle())
    }
}

/// An icon button of a bar: 44 points square, dimmed while it does nothing.
private struct BarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(enabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary))
            .frame(width: 44, height: 44)
            .contentShape(.circle)
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

/// Glass on iOS 26 and later, a material with a soft shadow before.
/// `interactive` glass answers a touch (buttons), the other does not (panels).
private struct Glass<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(interactive), in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.separator.opacity(0.5), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        }
    }
}

extension View {
    func glass(in shape: some Shape, interactive: Bool = true) -> some View {
        modifier(Glass(shape: shape, interactive: interactive))
    }
}

/// Glass shapes near each other blend into one on iOS 26 and later.
private struct GlassGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) { content }
        } else {
            content
        }
    }
}

extension UIColor {
    /// Whether text on this colour reads better light.
    var isDark: Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard resolvedColor(with: .current).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return false
        }
        return 0.299 * red + 0.587 * green + 0.114 * blue < 0.5
    }
}


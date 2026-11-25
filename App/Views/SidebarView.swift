import SwiftUI

/// The sidebar: a page per space, swiped through as on the desktop, with the
/// spaces' icons below to pick one. A space's page holds its favorites, the
/// pinned tree, the tabs open here and the Today tabs of the other devices.
/// The start page, and a sheet over a page.
struct SidebarView: View {
    @Environment(Browser.self) private var browser
    @Environment(Sync.self) private var sync
    /// Shown as a sheet over a page.
    var dismissable = false

    @State private var settingsShown = false
    @State private var joinShown = false
    /// Folders folded shut, by id, in every space. Open is the usual state.
    @State private var folded: Set<String> = []

    var body: some View {
        TabView(selection: Binding(get: { browser.space.id }, set: show)) {
            ForEach(browser.spaces, id: \.id) { space in
                SpacePage(space: space, dismissable: dismissable, folded: $folded,
                          settings: { settingsShown = true }, join: { joinShown = true })
                    .tag(space.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background { SpaceTint(space: browser.space) }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if browser.spaces.count > 1 { SpaceSwitcher() }
        }
        .sheet(isPresented: $settingsShown) { SettingsView() }
        .sheet(isPresented: $joinShown) { JoinView() }
    }

    private func show(_ id: String) {
        if let space = browser.spaces.first(where: { $0.id == id }) { browser.show(space: space) }
    }
}

/// A soft wash of the space's colour from the top, as the desktop tints its
/// sidebar.
private struct SpaceTint: View {
    let space: Space
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(colors: [(space.tint ?? .accentColor).opacity(scheme == .dark ? 0.22 : 0.12), .clear],
                       startPoint: .top, endPoint: .init(x: 0.5, y: 0.45))
            .background(Color(.systemBackground))
            .ignoresSafeArea()
            .animation(.smooth, value: space.id)
    }
}

/// The spaces' icons, the one in front marked; a tap shows that space.
private struct SpaceSwitcher: View {
    @Environment(Browser.self) private var browser

    var body: some View {
        // Too many spaces for the width: they scroll, the one in front in view.
        ViewThatFits(in: .horizontal) {
            row
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) { row }
                    .onChange(of: browser.space.id, initial: true) { _, id in
                        withAnimation(.smooth) { proxy.scrollTo(id, anchor: .center) }
                    }
            }
        }
        .padding(4)
        .glass(in: Capsule())
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    private var row: some View {
        HStack(spacing: 2) {
            ForEach(browser.spaces, id: \.id) { space in
                let front = space.id == browser.space.id
                Button {
                    withAnimation(.smooth) { browser.show(space: space) }
                } label: {
                    SpaceIcon(space: space, size: 20)
                        .frame(width: 40, height: 36)
                        .background(front ? (space.tint ?? .accentColor).opacity(0.18) : .clear, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(space.title)
                .accessibilityAddTraits(front ? .isSelected : [])
                .id(space.id)
            }
        }
    }
}

/// One space's page of the sidebar.
private struct SpacePage: View {
    @Environment(Browser.self) private var browser
    @Environment(Sync.self) private var sync
    @Environment(\.dismiss) private var dismiss
    let space: Space
    let dismissable: Bool
    @Binding var folded: Set<String>
    let settings: () -> Void
    let join: () -> Void

    var body: some View {
        let open = browser.tabs(in: space)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                header
                if !sync.joined { invitation }
                if !space.favorites.isEmpty { favorites }
                if !space.pinned.isEmpty { pinned }
                here(open)
                let sent = browser.sent.filter { $0.space == space.id }
                if !sent.isEmpty { self.sent(sent) }
                if !space.today.isEmpty {
                    Part("On your other devices") {
                        ForEach(space.today, id: \.id) { page in
                            PageRow(title: page.title, url: page.url) { browser.open(page) }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable { await browser.syncNow() }
        .tint(space.tint)
    }

    private var header: some View {
        HStack(spacing: 10) {
            SpaceIcon(space: space, size: 26)
            Text(space.title)
                .font(.title.weight(.bold))
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button("Settings", systemImage: "gearshape", action: settings)
                .labelStyle(.iconOnly)
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .glass(in: Circle())
            if dismissable {
                Button("Done", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .glass(in: Circle())
            }
        }
        .padding(.top, 8)
    }

    private var favorites: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 16) {
            ForEach(space.favorites, id: \.id) { page in
                Button {
                    browser.open(page)
                } label: {
                    VStack(spacing: 7) {
                        SiteMark(title: page.title, url: page.url, size: 58)
                        Text(page.title.isEmpty ? site(page.url) : page.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var pinned: some View {
        Part("Pinned") {
            ForEach(visible(space.pinned), id: \.item) { row in
                Group {
                    switch row.item {
                    case let .folder(id, title, smart):
                        FolderRow(title: title, smart: smart, open: !folded.contains(id)) {
                            withAnimation(.smooth(duration: 0.25)) { folded.formSymmetricDifference([id]) }
                        }
                    case let .page(page):
                        PageRow(title: page.title, url: page.url) { browser.open(page) }
                    }
                }
                .padding(.leading, CGFloat(min(row.depth, 6)) * 20)
            }
        }
    }

    /// The rows without those inside a folder that is folded shut.
    private func visible(_ rows: [Row]) -> [Row] {
        var shut: UInt32?
        return rows.filter { row in
            if let depth = shut {
                if row.depth > depth { return false }
                shut = nil
            }
            if case let .folder(id, _, _) = row.item, folded.contains(id) { shut = row.depth }
            return true
        }
    }

    private func here(_ tabs: [Tab]) -> some View {
        Part("Open here") {
            ForEach(tabs) { tab in
                PageRow(title: tab.label, url: tab.url.absoluteString, marked: tab.id == browser.front) {
                    browser.show(tab)
                } close: {
                    withAnimation { browser.close(tab) }
                }
            }
            if tabs.isEmpty {
                Text("No tabs open in this space. Type an address below, or pick a page above.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        } trailing: {
            if tabs.count > 1 {
                Button("Close All", role: .destructive) {
                    withAnimation { browser.closeAll(in: space) }
                }
                .font(.footnote.weight(.medium))
            }
        }
    }

    private func sent(_ tabs: [Tab]) -> some View {
        Part("Sent to your desktop") {
            ForEach(tabs) { tab in
                PageRow(title: tab.label, url: tab.url.absoluteString) {
                    browser.takeBack(tab)
                } close: {
                    withAnimation { browser.forget(sent: tab) }
                }
            }
            Text("These wait for Magnetite on a computer to open them. Tap one to open it here again.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var invitation: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Your spaces from the desktop", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
            Text("Join the sync chain of Magnetite on your computer to see its spaces, favorites and pinned tabs here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Join a Sync Chain", action: join)
                .buttonStyle(.borderedProminent)
                .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 22))
    }
}

/// A part of a space's page: a small heading, maybe with an action at its
/// end, over its rows.
private struct Part<Rows: View, Trailing: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let rows: Rows
    @ViewBuilder let trailing: Trailing

    init(_ title: LocalizedStringResource, @ViewBuilder rows: () -> Rows, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.rows = rows()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                // Verbatim: the capitals are only drawn, VoiceOver reads the
                // words as written (it spells a localized text out in capitals).
                Text(verbatim: String(localized: title))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                trailing
            }
            .padding(.bottom, 4)
            rows
        }
    }
}

extension Part where Trailing == EmptyView {
    init(_ title: LocalizedStringResource, @ViewBuilder rows: () -> Rows) {
        self.init(title, rows: rows, trailing: { EmptyView() })
    }
}

private func site(_ url: String) -> String {
    URL(string: url).map(Address.site(of:)) ?? url
}

/// A page in a list: its mark, title and site; with `close`, a button to
/// close it. `marked`: the tab on screen.
private struct PageRow: View {
    let title: String
    let url: String
    var marked = false
    let open: () -> Void
    var close: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 12) {
                    SiteMark(title: title, url: url, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title.isEmpty ? site(url) : title)
                            .lineLimit(1)
                            .fontWeight(marked ? .semibold : .regular)
                        Text(site(url))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if let close {
                Button("Close", systemImage: "xmark", action: close)
                    .labelStyle(.iconOnly)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.vertical, 6)
        // The tab on screen sits on a wash of the space's colour, which
        // reaches past the rows' edge.
        .padding(.horizontal, 8)
        .background(marked ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 12))
        .padding(.horizontal, -8)
    }
}

private struct FolderRow: View {
    let title: String
    let smart: Bool
    let open: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: smart ? "sparkles.rectangle.stack" : (open ? "folder" : "folder.fill"))
                    .foregroundStyle(.tint)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).lineLimit(1)
                    if smart {
                        Text("Fills itself on the desktop")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if !smart {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(open ? 90 : 0))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
    }
}

/// A site's mark: its icon if one is kept (`Favicons`), else the first
/// letter of its name in a colour of its own, on a light wash of it.
struct SiteMark: View {
    let title: String
    let url: String
    let size: CGFloat
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        if let icon = Favicons.shared.image(for: url) {
            Image(uiImage: icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                // Icons are drawn for a light ground.
                .padding(size * 0.16)
                .frame(width: size, height: size)
                .background(.white, in: shape)
                .overlay(shape.strokeBorder(.quaternary))
        } else {
            let name = site(url)
            // The same site gets the same colour at every start.
            let hue = Double(name.unicodeScalars.reduce(5381) { ($0 &* 33) &+ Int($1.value) } % 360) / 360
            let dark = scheme == .dark
            Text((title.first ?? name.first).map { String($0).uppercased() } ?? "?")
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hue: abs(hue), saturation: dark ? 0.35 : 0.55, brightness: dark ? 0.9 : 0.5))
                .frame(width: size, height: size)
                .background(Color(hue: abs(hue), saturation: dark ? 0.3 : 0.12, brightness: dark ? 0.28 : 0.97), in: shape)
                .overlay(shape.strokeBorder(.quaternary.opacity(0.6)))
        }
    }
}

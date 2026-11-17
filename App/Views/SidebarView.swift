import SwiftUI

/// The sidebar of the space in front: favorites, the pinned tree, the tabs
/// open here, and the Today tabs of the other devices. The start page, and
/// a sheet over a page.
struct SidebarView: View {
    @Environment(Browser.self) private var browser
    @Environment(Sync.self) private var sync
    @Environment(\.dismiss) private var dismiss
    /// Shown as a sheet over a page.
    var dismissable = false

    @State private var settingsShown = false
    @State private var joinShown = false
    /// Folders folded shut, by id. Open is the usual state.
    @State private var folded: Set<String> = []

    var body: some View {
        let space = browser.space
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if browser.spaces.count > 1 { spaces }
                    if !space.favorites.isEmpty { favorites(space.favorites) }
                    if !space.pinned.isEmpty { pinned(space.pinned) }
                    here(browser.tabs(in: space), in: space)
                    if !browser.sent.isEmpty { sent }
                    if !space.today.isEmpty {
                        section("Today on your other devices") {
                            ForEach(space.today, id: \.id) { page in
                                PageRow(title: page.title, url: page.url) { browser.open(page) }
                            }
                        }
                    }
                    if !sync.joined { invitation }
                }
                .padding(16)
            }
            .refreshable { await browser.syncNow() }
            .navigationTitle(space.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { settingsShown = true }
                }
                if dismissable {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .sheet(isPresented: $settingsShown) { SettingsView() }
            .sheet(isPresented: $joinShown) { JoinView() }
        }
    }

    private var spaces: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(browser.spaces, id: \.id) { space in
                    let front = space.id == browser.space.id
                    Button {
                        browser.show(space: space)
                    } label: {
                        HStack(spacing: 6) {
                            if let emoji = space.emoji {
                                Text(emoji)
                            } else {
                                Circle().fill(space.tint ?? .accentColor).frame(width: 10, height: 10)
                            }
                            Text(space.title)
                        }
                        .font(.subheadline.weight(front ? .semibold : .regular))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(front ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.quaternary),
                                    in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .tint(space.tint)
                    .accessibilityLabel(space.title)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func favorites(_ pages: [Page]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 14) {
            ForEach(pages, id: \.id) { page in
                Button {
                    browser.open(page)
                } label: {
                    VStack(spacing: 6) {
                        SiteMark(title: page.title, url: page.url, size: 52)
                        Text(page.title.isEmpty ? site(page.url) : page.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pinned(_ rows: [Row]) -> some View {
        section("Pinned") {
            ForEach(visible(rows), id: \.item) { row in
                Group {
                    switch row.item {
                    case let .folder(id, title, smart):
                        FolderRow(title: title, smart: smart, open: !folded.contains(id)) {
                            folded.formSymmetricDifference([id])
                        }
                    case let .page(page):
                        PageRow(title: page.title, url: page.url) { browser.open(page) }
                    }
                }
                .padding(.leading, CGFloat(min(row.depth, 6)) * 18)
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

    private func here(_ tabs: [Tab], in space: Space) -> some View {
        section("Open here") {
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
                    .padding(.vertical, 6)
            } else if tabs.count > 1 {
                Button("Close All", role: .destructive) {
                    withAnimation { browser.closeAll(in: space) }
                }
                .font(.subheadline)
                .padding(.top, 4)
            }
        }
    }

    private var sent: some View {
        section("Sent to your desktop") {
            ForEach(browser.sent) { tab in
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
        VStack(alignment: .leading, spacing: 8) {
            Label("Your spaces from the desktop", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
            Text("Join the sync chain of Magnetite on your computer to see its spaces, favorites and pinned tabs here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Join a Sync Chain") { joinShown = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 16))
    }

    private func section(_ title: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 4)
            rows()
        }
    }
}

private func site(_ url: String) -> String {
    URL(string: url).map(Address.site(of:)) ?? url
}

/// A page in a list: its mark, title and site; with `close`, a button to
/// close it.
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
                    SiteMark(title: title, url: url, size: 30)
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
                    .frame(width: 30)
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
/// letter of its name on a colour of its own.
struct SiteMark: View {
    let title: String
    let url: String
    let size: CGFloat

    var body: some View {
        if let icon = Favicons.shared.image(for: url) {
            Image(uiImage: icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                // Icons are drawn for a light ground.
                .padding(size * 0.14)
                .frame(width: size, height: size)
                .background(.white, in: .rect(cornerRadius: size * 0.26))
                .overlay(RoundedRectangle(cornerRadius: size * 0.26).strokeBorder(.quaternary))
        } else {
            letter
        }
    }

    private var letter: some View {
        let name = site(url)
        let letter = (title.first ?? name.first).map { String($0).uppercased() } ?? "?"
        // The same site gets the same colour at every start.
        let hue = Double(name.unicodeScalars.reduce(5381) { ($0 &* 33) &+ Int($1.value) } % 360) / 360
        return Text(letter)
            .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(hue: abs(hue), saturation: 0.5, brightness: 0.7), in: .rect(cornerRadius: size * 0.26))
    }
}

import SwiftUI

/// The bookmarks of every space, a section per space in their order, as on
/// the desktop. Folders start closed; the search finds bookmarks by name or
/// address in all spaces, each with the folders it is in. A tap opens one
/// as a new tab of its space, which comes to the front; the bookmark stays.
struct BookmarksView: View {
    @Environment(Browser.self) private var browser
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    /// Folders opened, by id.
    @State private var opened: Set<String> = []

    var body: some View {
        let spaces = browser.spaces.filter { !$0.bookmarks.isEmpty }
        NavigationStack {
            List {
                ForEach(spaces, id: \.id) { space in
                    let rows = query.isEmpty ? visible(space.bookmarks) : found(in: space.bookmarks)
                    if !rows.isEmpty {
                        Section {
                            ForEach(rows, id: \.row.item) { shown in
                                row(shown, in: space)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                SpaceIcon(space: space, size: 15)
                                Text(space.title)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if spaces.isEmpty {
                    ContentUnavailableView("No Bookmarks", systemImage: "book",
                                           description: Text("The bookmarks of your spaces on the desktop show here."))
                } else if !query.isEmpty, spaces.allSatisfy({ found(in: $0.bookmarks).isEmpty }) {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Bookmarks")
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// A row as shown: indented as deep as it is, or, found by the search,
    /// with the folders it is in.
    private struct Shown {
        let row: Row
        var depth: UInt32
        var path = ""
        /// A folder's bookmarks, all levels down.
        var count = 0
    }

    @ViewBuilder private func row(_ shown: Shown, in space: Space) -> some View {
        switch shown.row.item {
        case let .folder(id, title, _, _):
            Button {
                withAnimation(.smooth(duration: 0.25)) { opened.formSymmetricDifference([id]) }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "folder")
                        .foregroundStyle(.tint)
                        .frame(width: 28)
                    Text(title)
                    Spacer()
                    if !opened.contains(id) {
                        Text("\(shown.count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(opened.contains(id) ? 90 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.leading, indent(shown.depth))
            .accessibilityAddTraits(opened.contains(id) ? .isSelected : [])
        case let .page(page):
            let url = URL(string: page.url)
            Button {
                if let url { open(url, in: space) }
            } label: {
                HStack(spacing: 12) {
                    SiteMark(title: page.title, url: page.url, size: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(page.title.isEmpty ? site(page.url) : page.title)
                            .lineLimit(1)
                        Text(shown.path.isEmpty ? site(page.url) : "\(shown.path) · \(site(page.url))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.leading, indent(shown.depth))
            .contextMenu {
                if let url {
                    Button("Open in New Tab", systemImage: "plus.square.on.square") { open(url, in: space) }
                    Button("Open in Background", systemImage: "square.on.square") {
                        browser.open(url, inBackground: true, in: space)
                    }
                    Button("Copy Link", systemImage: "link") { UIPasteboard.general.url = url }
                    ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                }
            }
        }
    }

    private func open(_ url: URL, in space: Space) {
        browser.show(space: space)
        browser.open(url)
        dismiss()
    }

    private func indent(_ depth: UInt32) -> CGFloat { CGFloat(min(depth, 6)) * 18 }

    private func site(_ url: String) -> String {
        URL(string: url).map(Address.site(of:)) ?? url
    }

    /// The rows outside closed folders, folders with how many bookmarks
    /// they hold.
    private func visible(_ rows: [Row]) -> [Shown] {
        var shown: [Shown] = []
        var closed: UInt32?
        for (i, row) in rows.enumerated() {
            if let depth = closed {
                if row.depth > depth { continue }
                closed = nil
            }
            var item = Shown(row: row, depth: row.depth)
            if case let .folder(id, _, _, _) = row.item {
                item.count = rows[(i + 1)...].prefix { $0.depth > row.depth }
                    .filter { if case .page = $0.item { true } else { false } }.count
                if !opened.contains(id) { closed = row.depth }
            }
            shown.append(item)
        }
        return shown
    }

    /// The bookmarks whose name or address holds the query, each with the
    /// folders it is in.
    private func found(in rows: [Row]) -> [Shown] {
        let query = query.trimmingCharacters(in: .whitespaces).lowercased()
        var folders: [String] = []
        var shown: [Shown] = []
        for row in rows {
            folders = Array(folders.prefix(Int(row.depth)))
            switch row.item {
            case let .folder(_, title, _, _):
                folders.append(title)
            case let .page(page):
                guard page.title.lowercased().contains(query) || page.url.lowercased().contains(query) else { continue }
                shown.append(Shown(row: row, depth: 0, path: folders.joined(separator: " / ")))
            }
        }
        return shown
    }
}

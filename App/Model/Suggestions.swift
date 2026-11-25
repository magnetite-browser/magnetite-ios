import Foundation

/// A row the address field offers while typing.
enum Suggestion: Identifiable {
    /// The text is an address: go there.
    case address(URL)
    /// Search for the text.
    case search(URL)
    /// A tab open here: show it.
    case tab(Tab)
    /// A favorite, pinned, Today or bookmarked page of the chain: open it in
    /// its space.
    case page(Page, in: Space)
    /// A page visited before (`BrowsingHistory`): go there.
    case visit(Visit)

    var id: String {
        switch self {
        case let .address(url): "address \(url.absoluteString)"
        case .search: "search"
        case let .tab(tab): "tab \(tab.id)"
        case let .page(page, space): "page \(space.id) \(page.id)"
        case let .visit(visit): "visit \(visit.id)"
        }
    }
}

extension Browser {
    /// What to offer for `text`: the address it is or a search for it first
    /// (the other one next), then the open tabs, the chain's pages and the
    /// pages visited that match, best first. Nothing for an empty text.
    func suggestions(for text: String) -> [Suggestion] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        var rows: [Suggestion] = []
        let search = Address.search(for: text).map(Suggestion.search)
        if let address = Address.address(in: text) {
            rows.append(.address(address))
            if let search { rows.append(search) }
        } else if let search {
            rows.append(search)
        }

        let tabs = tabs
            .compactMap { tab in Self.match(query, title: tab.title, url: tab.url.absoluteString).map { (tab, $0) } }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
        rows += tabs.map { .tab($0.0) }

        // Each page once: the first space that has it, and none a tab here shows.
        var seen = Set(tabs.map { $0.0.url.absoluteString })
        var pages: [(Page, Space, Int)] = []
        for space in spaces {
            let listed = { (rows: [Row]) in
                rows.compactMap { row -> Page? in
                    if case let .page(page) = row.item { page } else { nil }
                }
            }
            for page in space.favorites + listed(space.pinned) + space.today + listed(space.bookmarks)
                where !seen.contains(page.url) {
                guard let score = Self.match(query, title: page.title, url: page.url) else { continue }
                seen.insert(page.url)
                pages.append((page, space, score))
            }
        }
        rows += pages.sorted { $0.2 > $1.2 }.prefix(6).map { .page($0.0, in: $0.1) }
        let visits = history.suggestions(for: query, limit: 8).filter { !seen.contains($0.url) }
        rows += visits.prefix(4).map(Suggestion.visit)
        return rows
    }

    /// How well `query` (lowercased) matches a page: its site starting with
    /// it is best, then a word of its title, then any part of either (for
    /// three letters or more: fewer are inside nearly everything).
    static func match(_ query: String, title: String, url: String) -> Int? {
        let site = URL(string: url).map(Address.site(of:))?.lowercased() ?? ""
        let title = title.lowercased()
        if site.hasPrefix(query) { return 3 }
        if title.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains(where: { $0.hasPrefix(query) }) {
            return 2
        }
        if query.count >= 3, title.contains(query) || url.lowercased().contains(query) { return 1 }
        return nil
    }
}

import SwiftUI

/// What the address field offers while typing (`Browser.suggestions`), on
/// glass. `chosen` runs once a row was picked.
struct SuggestionList: View {
    @Environment(Browser.self) private var browser
    let text: String
    /// The most it may take; it is shorter when it has fewer rows.
    let maxHeight: CGFloat
    let chosen: () -> Void

    /// A row's height, to size the list without measuring it.
    private static let rowHeight: CGFloat = 58

    var body: some View {
        let rows = browser.suggestions(for: text)
        if !rows.isEmpty {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        Button { pick(row) } label: { label(row) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.never)
            .frame(height: min(CGFloat(rows.count) * Self.rowHeight + 12, maxHeight))
            .glass(in: RoundedRectangle(cornerRadius: 26, style: .continuous), interactive: false)
        }
    }

    private func pick(_ row: Suggestion) {
        switch row {
        case let .address(url), let .search(url): browser.load(url)
        case let .visit(visit): visit.page.map(browser.load)
        case let .tab(tab): browser.show(tab)
        case let .page(page, space):
            browser.show(space: space)
            browser.open(page)
        }
        chosen()
    }

    private func label(_ row: Suggestion) -> some View {
        HStack(spacing: 12) {
            switch row {
            case let .address(url):
                symbol("globe")
                lines(text, "Open \(Address.site(of: url))")
            case .search:
                symbol("magnifyingglass")
                lines("“\(text)”", "Search with \(Address.searchEngine)")
            case let .tab(tab):
                SiteMark(title: tab.title, url: tab.url.absoluteString, size: 30)
                lines(tab.label, "\(Address.site(of: tab.url)) · Open here")
            case let .page(page, space):
                SiteMark(title: page.title, url: page.url, size: 30)
                let site = URL(string: page.url).map(Address.site(of:)) ?? page.url
                lines(page.title.isEmpty ? site : page.title, "\(site) · \(space.title)")
            case let .visit(visit):
                SiteMark(title: visit.title, url: visit.url, size: 30)
                lines(visit.label, "\(visit.page.map(Address.site(of:)) ?? visit.url) · \(String(localized: "History"))")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: Self.rowHeight)
        .contentShape(.rect)
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.body.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(width: 30, height: 30)
    }

    private func lines(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .lineLimit(1)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

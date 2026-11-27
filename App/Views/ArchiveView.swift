import SwiftUI

/// The tabs closed on the devices of the sync chain, newest first and by
/// day, with a search over title and address. A tap brings a tab back: it
/// is a Today tab of its space again, on every device, and opens here. A
/// swipe removes it from the archive for good.
struct ArchiveView: View {
    @Environment(Browser.self) private var browser
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let closed = matching(query)
        NavigationStack {
            List {
                ForEach(days(of: closed), id: \.day) { day in
                    Section {
                        ForEach(day.closed) { tab in
                            row(tab)
                        }
                    } header: {
                        Text(title(of: day.day))
                    }
                }
            }
            .listStyle(.plain)
            .overlay { empty(closed.isEmpty) }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search Archive")
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ tab: Archived) -> some View {
        Button {
            bringBack(tab)
        } label: {
            HStack(spacing: 12) {
                SiteMark(title: tab.title, url: tab.url, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tab.label)
                        .lineLimit(1)
                    Text([tab.page.map(Address.site(of:)) ?? tab.url, tab.space].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(tab.date, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button("Remove", systemImage: "trash", role: .destructive) { remove(tab) }
        }
        .contextMenu {
            Button("Reopen Tab", systemImage: "arrow.uturn.backward") { bringBack(tab) }
            if let page = tab.page {
                Button("Copy Link", systemImage: "link") { UIPasteboard.general.url = page }
            }
            Button("Remove", systemImage: "trash", role: .destructive) { remove(tab) }
        }
    }

    /// Back among the Today tabs of its space, for the whole chain, and open
    /// here.
    private func bringBack(_ tab: Archived) {
        browser.change { await $0.restore(tab.id) }
        if let page = tab.page { browser.open(page) }
        dismiss()
    }

    private func remove(_ tab: Archived) {
        browser.change { await $0.forgetArchived(tab.id) }
    }

    @ViewBuilder private func empty(_ isEmpty: Bool) -> some View {
        if !isEmpty {
            EmptyView()
        } else if !query.isEmpty {
            ContentUnavailableView.search(text: query)
        } else if !browser.sync.joined {
            ContentUnavailableView("No Archive", systemImage: "archivebox",
                                   description: Text("With sync on, the tabs you close on your devices show here."))
        } else {
            ContentUnavailableView("No Archived Tabs", systemImage: "archivebox",
                                   description: Text("Tabs closed on your desktop, and pinned tabs and favorites you remove, show here."))
        }
    }

    private func matching(_ query: String) -> [Archived] {
        let words = query.trimmingCharacters(in: .whitespaces)
        guard !words.isEmpty else { return browser.sync.archive }
        return browser.sync.archive.filter {
            $0.title.localizedCaseInsensitiveContains(words) || $0.url.localizedCaseInsensitiveContains(words)
        }
    }

    private func title(of day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: "Today") }
        if calendar.isDateInYesterday(day) { return String(localized: "Yesterday") }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    /// The closed tabs by the day they were closed, newest first.
    private func days(of closed: [Archived]) -> [(day: Date, closed: [Archived])] {
        let calendar = Calendar.current
        var days: [(day: Date, closed: [Archived])] = []
        for tab in closed {
            let day = calendar.startOfDay(for: tab.date)
            if days.last?.day == day {
                days[days.count - 1].closed.append(tab)
            } else {
                days.append((day, [tab]))
            }
        }
        return days
    }
}

extension Archived: Identifiable {
    var page: URL? { URL(string: url) }

    var date: Date { Date(timeIntervalSince1970: TimeInterval(archivedAt)) }

    /// What a row shows: the page's title, or its site while it has none.
    var label: String {
        if !title.isEmpty { return title }
        return page.map(Address.site(of:)) ?? url
    }
}

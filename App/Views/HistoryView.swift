import SwiftUI

/// The pages visited on this device, newest first and by day, with a search
/// over title and address. A tap opens the page in a new tab of the space in
/// front; a swipe removes a visit; "Clear" removes the last hour, today,
/// today and yesterday, or all.
struct HistoryView: View {
    @Environment(Browser.self) private var browser
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var clearing = false

    var body: some View {
        let visits = browser.history.visits(matching: query)
        NavigationStack {
            List {
                ForEach(days(of: visits), id: \.day) { day in
                    Section {
                        ForEach(day.visits) { visit in
                            row(visit)
                        }
                    } header: {
                        Text(title(of: day.day))
                    }
                }
            }
            .listStyle(.plain)
            .overlay { empty(visits.isEmpty) }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search History")
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { clearing = true }
                        .disabled(browser.history.visits(limit: 1).isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Clear History", isPresented: $clearing, titleVisibility: .visible) {
                Button("The Last Hour", role: .destructive) { clear(since: .now.addingTimeInterval(-3600)) }
                Button("Today", role: .destructive) { clear(since: Calendar.current.startOfDay(for: .now)) }
                Button("Today and Yesterday", role: .destructive) {
                    let today = Calendar.current.startOfDay(for: .now)
                    clear(since: Calendar.current.date(byAdding: .day, value: -1, to: today))
                }
                Button("All History", role: .destructive) { clear(since: nil) }
            } message: {
                Text("Open tabs, website data and the sidebar stay as they are.")
            }
        }
    }

    private func row(_ visit: Visit) -> some View {
        Button {
            if let page = visit.page {
                browser.open(page)
                dismiss()
            }
        } label: {
            HStack(spacing: 12) {
                SiteMark(title: visit.title, url: visit.url, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(visit.label)
                        .lineLimit(1)
                    Text(visit.page.map(Address.site(of:)) ?? visit.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(visit.date, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button("Remove", systemImage: "trash", role: .destructive) { browser.history.remove(visit) }
        }
        .contextMenu {
            if let page = visit.page {
                Button("Open in New Tab", systemImage: "plus.square.on.square") {
                    browser.open(page)
                    dismiss()
                }
                Button("Open in Background", systemImage: "square.on.square") {
                    browser.open(page, inBackground: true)
                }
                Button("Copy Link", systemImage: "link") { UIPasteboard.general.url = page }
            }
            Button("Remove", systemImage: "trash", role: .destructive) { browser.history.remove(visit) }
        }
    }

    @ViewBuilder private func empty(_ isEmpty: Bool) -> some View {
        if !isEmpty {
            EmptyView()
        } else if !query.isEmpty {
            ContentUnavailableView.search(text: query)
        } else if browser.history.keepDays == 0 {
            ContentUnavailableView("History Is Off", systemImage: "clock",
                                   description: Text("Settings can keep the pages you visit."))
        } else {
            ContentUnavailableView("No History", systemImage: "clock",
                                   description: Text("Pages you visit show here. They stay on this device and are never synced."))
        }
    }

    private func clear(since: Date?) {
        withAnimation { browser.history.clear(since: since) }
    }

    private func title(of day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: "Today") }
        if calendar.isDateInYesterday(day) { return String(localized: "Yesterday") }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    /// The visits by the day they were made, newest first.
    private func days(of visits: [Visit]) -> [(day: Date, visits: [Visit])] {
        let calendar = Calendar.current
        var days: [(day: Date, visits: [Visit])] = []
        for visit in visits {
            let day = calendar.startOfDay(for: visit.date)
            if days.last?.day == day {
                days[days.count - 1].visits.append(visit)
            } else {
                days.append((day, [visit]))
            }
        }
        return days
    }
}

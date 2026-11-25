import SwiftUI

/// Settings → Content Blocking: on or off, the lists, the sites without
/// blocking.
struct BlockingSection: View {
    @Environment(Browser.self) private var browser

    var body: some View {
        let blocker = browser.blocker
        Section {
            Toggle("Block Ads and Trackers", isOn: Binding(get: { blocker.enabled }, set: blocker.setEnabled))
            if blocker.enabled {
                NavigationLink {
                    FilterListsView()
                } label: {
                    LabeledContent("Filter Lists", value: "\(blocker.lists.count)")
                }
                if !blocker.allowed.isEmpty {
                    NavigationLink {
                        AllowedSitesView()
                    } label: {
                        LabeledContent("Sites Without Blocking", value: "\(blocker.allowed.count)")
                    }
                }
            }
        } header: {
            Text("Content Blocking")
        } footer: {
            if blocker.enabled, blocker.busy {
                Text("Downloading the lists…")
            } else if blocker.enabled, let error = blocker.lastError {
                Text(error).foregroundStyle(.red)
            } else {
                Text("Stops ads and trackers before they load, with the filter lists the desktop uses. A site's menu can turn it off for that site.")
            }
        }
    }
}

/// The lists offered, each to turn on or off, with what it blocks and when
/// it was downloaded.
private struct FilterListsView: View {
    @Environment(Browser.self) private var browser

    var body: some View {
        let blocker = browser.blocker
        Form {
            Section {
                ForEach(blocker.offered, id: \.id) { list in
                    Toggle(isOn: Binding(get: { blocker.lists.contains(list.id) },
                                         set: { blocker.choose(list.id, $0) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(list.name)
                            Text(Self.about(list.id))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            fetched(list)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } footer: {
                Text("Each list is downloaded from its publisher and again every four days. The publisher sees your IP address, as any website would. Which pages you open, and what is blocked, is never sent anywhere.")
            }
        }
        .navigationTitle("Filter Lists")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if blocker.busy { ProgressView().padding(.top, 8) }
        }
    }

    @ViewBuilder private func fetched(_ list: FilterList) -> some View {
        if let at = list.fetchedAt {
            Text("Downloaded \(Date(timeIntervalSince1970: TimeInterval(at)), format: .relative(presentation: .named))")
        } else if browser.blocker.lists.contains(list.id) {
            Text("Downloaded with the next website")
        }
    }

    /// What a list blocks, as the desktop says it.
    private static func about(_ id: String) -> LocalizedStringKey {
        switch id {
        case "easylist": "Ads on most international websites."
        case "easyprivacy": "Trackers and analytics."
        case "easylist-germany": "Ads on German-language websites. Use with EasyList."
        case "peter-lowe": "Servers of ad and tracking companies."
        case "ublock": "Ads, trackers and “turn off your ad blocker” walls, with fixes for sites the other lists break."
        default: ""
        }
    }
}

/// The sites that load everything, each to block again.
private struct AllowedSitesView: View {
    @Environment(Browser.self) private var browser

    var body: some View {
        let blocker = browser.blocker
        List {
            ForEach(blocker.allowed.sorted(), id: \.self) { site in
                HStack {
                    Text(site)
                    Spacer()
                    Button("Block Again") { blocker.allow(site, false) }
                        .buttonStyle(.borderless)
                }
            }
        }
        .navigationTitle("Sites Without Blocking")
        .navigationBarTitleDisplayMode(.inline)
    }
}

import SwiftUI

struct SettingsView: View {
    @Environment(Browser.self) private var browser
    @Environment(Sync.self) private var sync
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Address.searchKey) private var search = Address.engines[0].template

    @AppStorage(Sync.sharesTabsKey) private var sharesTabs = true

    @State private var joinShown = false
    @State private var leaving = false
    @State private var clearing = false
    @State private var historyShown = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Search") {
                    Picker("Search engine", selection: $search) {
                        ForEach(Address.engines, id: \.template) { engine in
                            Text(engine.label).tag(engine.template)
                        }
                    }
                }
                syncSection
                historySection
                Section {
                    Button("Clear Website Data…", role: .destructive) { clearing = true }
                } footer: {
                    Text("Cookies, logins and caches of every space on this device.")
                }
                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settings.done")
                }
            }
            .sheet(isPresented: $joinShown) { JoinView() }
            .sheet(isPresented: $historyShown) { HistoryView() }
            .confirmationDialog("Leave the sync chain on this device?", isPresented: $leaving, titleVisibility: .visible) {
                Button("Leave", role: .destructive) { sync.leave() }
            } message: {
                Text("The chain and your other devices stay as they are. The tabs open here stay too.")
            }
            .confirmationDialog("Clear website data of every space?", isPresented: $clearing, titleVisibility: .visible) {
                Button("Clear", role: .destructive) {
                    Task { await browser.clearWebsiteData() }
                }
            } message: {
                Text("You are signed out of the sites you use here.")
            }
        }
    }

    private var historySection: some View {
        Section {
            Picker("Keep History", selection: Binding(get: { browser.history.keepDays },
                                                      set: { browser.history.keep(days: $0) })) {
                ForEach(BrowsingHistory.periods, id: \.self) { days in
                    Text(Self.period(days)).tag(days)
                }
            }
            Button("Show History") { historyShown = true }
        } header: {
            Text("History")
        } footer: {
            Text("The pages you visit stay on this device and are never synced. Pages of private spaces are not kept.")
        }
    }

    private static func period(_ days: UInt32) -> LocalizedStringKey {
        switch days {
        case 0: "Don’t Keep"
        case 7: "A Week"
        case 30: "A Month"
        case 90: "Three Months"
        case 365: "A Year"
        default: "\(days) Days"
        }
    }

    @ViewBuilder private var syncSection: some View {
        if let server = sync.server {
            Section {
                LabeledContent("Server", value: URL(string: server)?.host ?? server)
                LabeledContent("Last sync") {
                    if sync.busy {
                        ProgressView()
                    } else if let last = sync.lastSync {
                        Text(last, style: .relative) + Text(" ago")
                    } else {
                        Text("Not yet")
                    }
                }
                Button("Sync Now") { Task { await browser.syncNow() } }
                    .disabled(sync.busy)
                Toggle("Show Tabs on Other Devices", isOn: $sharesTabs)
                    .onChange(of: sharesTabs) { Task { await browser.shareTabs() } }
                Button("Leave on This Device…", role: .destructive) { leaving = true }
            } header: {
                Text("Sync")
            } footer: {
                if let error = sync.lastError {
                    Text(error).foregroundStyle(.red)
                } else {
                    Text("What you change in the sidebar here, your computer makes when it syncs. Your other devices can list the tabs open here and take one over; tabs of private spaces are never listed.")
                }
            }
        } else {
            Section {
                Button("Join a Sync Chain…") { joinShown = true }
            } header: {
                Text("Sync")
            } footer: {
                Text("Shows the spaces, favorites and pinned tabs of Magnetite on your computer.")
            }
        }
    }
}

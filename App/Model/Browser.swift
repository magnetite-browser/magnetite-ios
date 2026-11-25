import CryptoKit
import Foundation
import Observation
import UIKit
import WebKit

/// A tab open on this device. Tabs are not synced: the chain's sidebar is
/// what the desktop wrote, and a tab opened from it lives here only.
struct Tab: Identifiable, Codable, Equatable {
    var id = UUID()
    /// The space it was opened in; its pages use that space's profile.
    var space: String
    var url: URL
    var title = ""
    /// The sidebar item it was opened from, so that item shows it again.
    var origin: String?

    /// What a row shows: the page's title, or its site while it has none.
    var label: String { title.isEmpty ? Address.site(of: url) : title }
}

/// The tabs of this device, the space in front, and the pages behind them.
@MainActor @Observable
final class Browser {
    let sync = Sync()
    private(set) var tabs: [Tab] = []
    /// Tabs sent to the desktop that no desktop has opened yet.
    private(set) var sent: [Tab] = []
    /// The tab on screen; none: the sidebar is the start page.
    private(set) var front: Tab.ID?
    private(set) var spaceID: String

    /// The pages loaded right now, by tab. A tab without one loads when shown.
    @ObservationIgnored private var pages: [Tab.ID: WebPage] = [:]
    /// Data stores of private profiles: they live as long as the app runs.
    @ObservationIgnored private var privateStores: [String: WKWebsiteDataStore] = [:]
    @ObservationIgnored private var memoryWarning: NSObjectProtocol?

    /// The space of a device that is in no chain.
    static let home = Space(id: "home", title: "Home", icon: "home", accent: nil, profileId: "home",
                            ephemeral: false, favorites: [], pinned: [], today: [])

    private struct Saved: Codable {
        var tabs: [Tab]
        var front: Tab.ID?
        var space: String
        var sent: [Tab]?
    }

    private static let file = URL.applicationSupportDirectory.appending(path: "tabs.json")

    init() {
        let saved = (try? Data(contentsOf: Self.file)).flatMap { try? JSONDecoder().decode(Saved.self, from: $0) }
        tabs = saved?.tabs ?? []
        sent = saved?.sent ?? []
        front = saved?.front
        spaceID = saved?.space ?? Self.home.id
        settle()
        memoryWarning = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.unloadHidden() }
        }
    }

    // MARK: Spaces

    var spaces: [Space] { sync.sidebar?.spaces ?? [Self.home] }
    var space: Space { spaces.first { $0.id == spaceID } ?? spaces[0] }
    var frontTab: Tab? { tabs.first { $0.id == front } }

    func tabs(in space: Space) -> [Tab] { tabs.filter { $0.space == space.id } }

    func show(space: Space) {
        spaceID = space.id
        save()
    }

    /// After the sidebar changed: tabs of a space that is gone, open or
    /// sent, move to the first one, and the space in front is one that
    /// exists.
    func settle() {
        let known = Set(spaces.map(\.id))
        let first = spaces[0].id
        for i in tabs.indices where !known.contains(tabs[i].space) {
            tabs[i].space = first
            pages[tabs[i].id] = nil
        }
        for i in sent.indices where !known.contains(sent[i].space) {
            sent[i].space = first
        }
        if !known.contains(spaceID) { spaceID = first }
        if frontTab == nil { front = nil }
        save()
    }

    // MARK: Tabs

    /// Open `url` in a new tab of the space in front and show it.
    /// With `inBackground`, the tab opens behind the one in front.
    func open(_ url: URL, origin: String? = nil, inBackground: Bool = false) {
        let tab = Tab(space: space.id, url: url, origin: origin)
        tabs.insert(tab, at: 0)
        if !inBackground { front = tab.id }
        save()
    }

    /// Show the tab of sidebar item `page`, opening one if there is none.
    func open(_ page: Page) {
        if let tab = tabs.first(where: { $0.origin == page.id && $0.space == space.id }) {
            show(tab)
        } else if let url = URL(string: page.url) {
            open(url, origin: page.id)
        }
    }

    /// Go to what the address field holds: in the tab in front, else a new one.
    func go(_ text: String) {
        Address.url(for: text).map(load)
    }

    /// Load `url` in the tab in front, else in a new one.
    func load(_ url: URL) {
        if let tab = frontTab {
            page(for: tab).view.load(URLRequest(url: url))
        } else {
            open(url)
        }
    }

    func show(_ tab: Tab) {
        spaceID = tab.space
        front = tab.id
        save()
    }

    /// Back to the sidebar; the tab stays open.
    func showSidebar() {
        front = nil
        save()
    }

    func close(_ tab: Tab) {
        tabs.removeAll { $0.id == tab.id }
        pages[tab.id] = nil
        if front == tab.id { front = nil }
        save()
    }

    func closeAll(in space: Space) {
        for tab in tabs(in: space) { close(tab) }
    }

    // MARK: Other devices

    /// Hand `url` to the desktop without opening it here, as a tab of
    /// `space`: the space of the page it came from, not the one in front.
    func sendToDesktop(_ url: URL, from space: Space) {
        sent.insert(Tab(space: space.id, url: url), at: 0)
        save()
        Task { await shareTabs() }
    }

    /// Hand `tab` to the desktop: it closes here and waits in `sent` until a
    /// desktop opened it.
    func sendToDesktop(_ tab: Tab) {
        close(tab)
        sent.insert(tab, at: 0)
        save()
        Task { await shareTabs() }
    }

    /// Open a sent tab here again.
    func takeBack(_ tab: Tab) {
        forget(sent: tab)
        tabs.insert(tab, at: 0)
        show(tab)
    }

    func forget(sent tab: Tab) {
        sent.removeAll { $0.id == tab.id }
        save()
    }

    /// Read the chain's sidebar, then tell the chain about the tabs here.
    func syncNow() async {
        await sync.refresh()
        settle()
        await shareTabs()
    }

    func syncIfDue() {
        if sync.due { Task { await syncNow() } }
    }

    /// List the tabs open here in the chain, and close those another device
    /// took over. Tabs of private spaces are never listed.
    func shareTabs() async {
        guard sync.joined else { return }
        // Twice at most: after closing what was taken, the list is sent
        // again without it, so the other device can forget the handover.
        for _ in 0..<2 {
            let taken = Set(await sync.exchange(sync.sharesTabs ? listed() : listed(sentOnly: true)))
            if taken.isEmpty { return }
            for tab in tabs where taken.contains(tab.id.uuidString) { close(tab) }
            sent.removeAll { taken.contains($0.id.uuidString) }
            save()
        }
    }

    private func listed(sentOnly: Bool = false) -> [DeviceTab] {
        let known = Dictionary(uniqueKeysWithValues: (sync.sidebar?.spaces ?? []).map { ($0.id, $0) })
        func entry(_ tab: Tab, later: Bool) -> DeviceTab? {
            if known[tab.space]?.ephemeral == true { return nil }
            return DeviceTab(id: tab.id.uuidString, url: tab.url.absoluteString, title: tab.title,
                             space: known[tab.space]?.id, later: later)
        }
        let open = sentOnly ? [] : tabs.compactMap { entry($0, later: false) }
        return sent.compactMap { entry($0, later: true) } + open
    }

    // MARK: Pages

    /// The page of `tab`, loaded now if it was not.
    func page(for tab: Tab) -> WebPage {
        if let page = pages[tab.id] { return page }
        let space = spaces.first { $0.id == tab.space } ?? spaces[0]
        let page = WebPage(url: tab.url, store: store(for: space))
        let id = tab.id
        page.changed = { [weak self] url, title in self?.note(id, url: url, title: title) }
        page.opensTab = { [weak self] url, inBackground in self?.open(url, inBackground: inBackground) }
        page.sendsToDesktop = { [weak self] url in
            guard let self, sync.joined else { return nil }
            return { self.sendToDesktop(url, from: space) }
        }
        pages[id] = page
        return page
    }

    private func note(_ id: Tab.ID, url: URL?, title: String) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        let before = tabs[i]
        if let url, ["http", "https"].contains(url.scheme ?? "") { tabs[i].url = url }
        tabs[i].title = title
        if tabs[i] != before { save() }
    }

    /// Cookies and logins of a space: one store per profile, so spaces with
    /// the same profile share them, as on the desktop.
    private func store(for space: Space) -> WKWebsiteDataStore {
        if space.ephemeral {
            if let store = privateStores[space.profileId] { return store }
            let store = WKWebsiteDataStore.nonPersistent()
            privateStores[space.profileId] = store
            return store
        }
        return WKWebsiteDataStore(forIdentifier: Self.storeID(of: space.profileId))
    }

    /// The store's name must be a UUID; a profile's id usually is one.
    private static func storeID(of profile: String) -> UUID {
        if let id = UUID(uuidString: profile) { return id }
        let hash = Array(SHA256.hash(data: Data(profile.utf8)).prefix(16))
        return UUID(uuid: (hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7],
                           hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15]))
    }

    /// Erase cookies, logins and caches of every space.
    func clearWebsiteData() async {
        let stores = Set(spaces.map(\.profileId)).compactMap { id in
            spaces.first { $0.profileId == id }.map(store(for:))
        }
        for store in stores {
            await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        }
        for page in pages.values { page.view.reload() }
    }

    /// Under memory pressure only the page on screen stays loaded.
    private func unloadHidden() {
        pages = pages.filter { $0.key == front }
    }

    private func save() {
        let saved = Saved(tabs: tabs, front: front, space: spaceID, sent: sent)
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        try? data.write(to: Self.file, options: .atomic)
    }
}

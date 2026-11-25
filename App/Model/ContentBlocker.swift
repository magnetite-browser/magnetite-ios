import Foundation
import Observation
import WebKit

/// Content blocking with the desktop's filter lists (the core's `blocking`
/// module): on unless turned off, with the lists Settings chooses, and off
/// for the sites the reader allows.
///
/// The lists are downloaded from their publishers once a web page opens,
/// and again when older than four days. They are kept in Caches: the
/// system may clear them, and they are downloaded again. WebKit compiles
/// them into one rule list, which it keeps between starts, so a page
/// restored at start waits for it (`whenReady`) and is blocked from its
/// first request.
@MainActor @Observable
final class ContentBlocker {
    /// Blocking is on.
    private(set) var enabled: Bool
    /// The lists chosen, by id.
    private(set) var lists: [String]
    /// Sites that load everything (`Address.site`).
    private(set) var allowed: Set<String>
    /// The lists offered, with when each was downloaded.
    private(set) var offered: [FilterList] = []
    /// Downloading or compiling.
    private(set) var busy = false
    /// Why the last download or compile failed.
    private(set) var lastError: String?
    /// The compiled rules; `nil` until there are any.
    private(set) var rules: WKContentRuleList?

    @ObservationIgnored private var ready = false
    @ObservationIgnored private var waiting: [() -> Void] = []
    @ObservationIgnored private let pages = NSHashTable<WebPage>.weakObjects()
    @ObservationIgnored private var checkedAt: Date?

    private static let enabledKey = "blocking.enabled"
    private static let listsKey = "blocking.lists"
    private static let allowedKey = "blocking.allowed"
    private static let identifier = "filter-lists"
    private static var dir: String { URL.cachesDirectory.path(percentEncoded: false) }

    init() {
        let defaults = UserDefaults.standard
        enabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        lists = defaults.stringArray(forKey: Self.listsKey)
            ?? recommendedFilterLists(language: Locale.preferredLanguages.first)
        allowed = Set(defaults.stringArray(forKey: Self.allowedKey) ?? [])
        offered = filterLists(dir: Self.dir)
        WKContentRuleListStore.default().lookUpContentRuleList(forIdentifier: Self.identifier) { [weak self] rules, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.rules == nil { self.rules = rules }
                self.ready = true
                for run in self.waiting { run() }
                self.waiting = []
            }
        }
    }

    /// Run `action` once the rules kept from the last start are looked up
    /// (at once, after that).
    func whenReady(_ action: @escaping () -> Void) {
        if ready { action() } else { waiting.append(action) }
    }

    /// `page` takes the rules from now on, and again whenever they change.
    func serve(_ page: WebPage) {
        pages.add(page)
        refreshIfDue()
    }

    /// The rules for a page at `url`: none while blocking is off or for an
    /// allowed site.
    func rules(for url: URL?) -> WKContentRuleList? {
        guard enabled, let rules else { return nil }
        if let url, allowed.contains(Address.site(of: url)) { return nil }
        return rules
    }

    func isAllowed(_ url: URL) -> Bool {
        allowed.contains(Address.site(of: url))
    }

    // MARK: Settings

    func setEnabled(_ on: Bool) {
        enabled = on
        UserDefaults.standard.set(on, forKey: Self.enabledKey)
        servePages()
        if on { refresh(recompile: rules == nil) }
    }

    func choose(_ id: String, _ on: Bool) {
        lists.removeAll { $0 == id }
        if on { lists.append(id) }
        UserDefaults.standard.set(lists, forKey: Self.listsKey)
        refresh(recompile: true)
    }

    /// Let the site of `url` load everything (`allow`), or block there again.
    func allow(_ site: String, _ allow: Bool) {
        if allow { allowed.insert(site) } else { allowed.remove(site) }
        UserDefaults.standard.set(allowed.sorted(), forKey: Self.allowedKey)
        servePages()
    }

    // MARK: Lists

    /// Look for lists to download, at most once an hour (the core downloads
    /// only those older than four days), once a web page was opened: as on
    /// the desktop, a first start downloads nothing before that.
    func refreshIfDue() {
        guard pages.anyObject != nil,
              checkedAt.map({ Date.now.timeIntervalSince($0) > 3600 }) ?? true
        else { return }
        refresh(recompile: false)
    }

    /// Download what is due, then compile the rules again when a list came
    /// or went (`recompile`: in any case).
    func refresh(recompile: Bool) {
        guard enabled, !busy else { return }
        busy = true
        checkedAt = .now
        let (dir, ids) = (Self.dir, lists)
        Task {
            let update = await Task.detached { updateFilterLists(dir: dir, ids: ids) }.value
            lastError = update.error
            if update.changed || recompile || rules == nil {
                await compile(dir: dir, ids: ids)
            }
            offered = filterLists(dir: dir)
            busy = false
            // The lists changed again meanwhile.
            if ids != lists { refresh(recompile: true) }
        }
    }

    private func compile(dir: String, ids: [String]) async {
        let store = WKContentRuleListStore.default()!
        guard let json = await Task.detached(operation: { webkitContentRules(dir: dir, ids: ids) }).value else {
            try? await store.removeContentRuleList(forIdentifier: Self.identifier)
            rules = nil
            servePages()
            return
        }
        do {
            rules = try await store.compileContentRuleList(forIdentifier: Self.identifier, encodedContentRuleList: json)
            servePages()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Give every page the rules for its site, as they are now.
    private func servePages() {
        for page in pages.allObjects {
            page.use(rules(for: page.url))
        }
    }
}

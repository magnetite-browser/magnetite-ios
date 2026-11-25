import Foundation
import Observation

/// The pages visited on this device (the core's `History`): address, title
/// and time, kept for the period Settings chooses and never synced. Pages
/// of private spaces are not recorded (`Browser.page(for:)`).
///
/// The core runs on a queue of its own, so its writes stay off the main
/// thread and in order; a read waits for the changes before it.
@MainActor @Observable
final class BrowsingHistory {
    /// How many days visits stay; 0: none are recorded.
    private(set) var keepDays: UInt32
    /// Goes up with every change, so what lists visits reads them again.
    private var changes = 0

    @ObservationIgnored private let core: History
    @ObservationIgnored private let queue = DispatchQueue(label: "org.magnetitebrowser.history")

    /// The periods Settings offers, in days.
    static let periods: [UInt32] = [7, 30, 90, 365, 0]

    init() {
        core = History(dir: URL.applicationSupportDirectory.path(percentEncoded: false))
        keepDays = core.keepDays()
    }

    /// A page went to `url` (`title`: the one it has then, if any).
    func visit(_ url: URL, title: String) {
        guard keepDays > 0 else { return }
        run { $0.visit(url: url.absoluteString, title: title) }
    }

    /// The page at `url` named itself.
    func name(_ url: URL, title: String) {
        guard keepDays > 0, !title.isEmpty else { return }
        run { $0.name(url: url.absoluteString, title: title) }
    }

    /// The visits whose title or address holds `query`, newest first.
    func visits(matching query: String = "", limit: UInt32 = 500) -> [Visit] {
        _ = changes
        let core = core
        return queue.sync { core.visits(query: query, limit: limit) }
    }

    /// Visited pages for the address field, best match first.
    func suggestions(for query: String, limit: UInt32 = 4) -> [Visit] {
        _ = changes
        let core = core
        return queue.sync { core.suggest(query: query, limit: limit) }
    }

    func remove(_ visit: Visit) {
        run { $0.remove(id: visit.id) }
    }

    /// Remove the visits from `since` on, or all of them.
    func clear(since: Date?) {
        let since = since.map { Int64($0.timeIntervalSince1970) }
        run { $0.clear(since: since) }
    }

    func keep(days: UInt32) {
        keepDays = days
        run { $0.setKeepDays(days: days) }
    }

    /// Write what is not written yet (the app goes to the background).
    func save() {
        let core = core
        queue.async { core.save() }
    }

    private func run(_ change: @escaping @Sendable (History) -> Void) {
        let core = core
        queue.async { change(core) }
        changes += 1
    }
}

extension Visit: Identifiable {
    var page: URL? { URL(string: url) }

    var date: Date { Date(timeIntervalSince1970: TimeInterval(at)) }

    /// What a row shows: the page's title, or its site while it has none.
    var label: String {
        if !title.isEmpty { return title }
        return page.map(Address.site(of:)) ?? url
    }
}

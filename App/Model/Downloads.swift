import Foundation
import Observation
import WebKit

/// The files pages download. They go to Downloads in the app's documents,
/// which the Files app shows under the app's name; the list of them is kept
/// in `downloads.json`, without the addresses they came from (as on the
/// desktop). A running download shows in a card over the page (`recent`).
@MainActor @Observable
final class Downloads: NSObject {
    private struct Source {
        weak var view: WKWebView?
        let url: URL?
    }

    struct Item: Identifiable, Codable, Equatable {
        enum State: String, Codable { case running, finished, failed, canceled }
        var id = UUID()
        /// The file's name in `Downloads.folder`.
        var name: String
        var date = Date.now
        var state = State.running
        /// In bytes, once known.
        var size: Int64?
    }

    /// Newest first.
    private(set) var items: [Item] = []
    /// How far each running download is, 0 to 1; missing while unknown.
    private(set) var progress: [Item.ID: Double] = [:]
    /// The download to show in the card over the page, while it runs and for
    /// a few seconds after.
    private(set) var recent: Item.ID?

    /// What a download needs while it runs, and to be tried again: the
    /// web view that started it (whose cookies it uses) and its address.
    /// Only while the app runs.
    @ObservationIgnored private var running: [ObjectIdentifier: Item.ID] = [:]
    @ObservationIgnored private var tasks: [Item.ID: WKDownload] = [:]
    @ObservationIgnored private var sources: [Item.ID: Source] = [:]
    @ObservationIgnored private var starting: [ObjectIdentifier: Source] = [:]
    @ObservationIgnored private var watching: [Item.ID: NSKeyValueObservation] = [:]
    @ObservationIgnored private var hiding: Task<Void, Never>?

    static let folder = URL.documentsDirectory.appending(path: "Downloads")
    private static let file = URL.applicationSupportDirectory.appending(path: "downloads.json")

    override init() {
        super.init()
        let kept = (try? Data(contentsOf: Self.file)).flatMap { try? JSONDecoder().decode([Item].self, from: $0) }
        // One that ran when the app ended did not finish.
        items = (kept ?? []).map { item in
            var item = item
            if item.state == .running { item.state = .failed }
            return item
        }
    }

    func url(of item: Item) -> URL { Self.folder.appending(path: item.name) }

    /// The file is still there (not deleted in Files since).
    func exists(_ item: Item) -> Bool {
        FileManager.default.fileExists(atPath: url(of: item).path(percentEncoded: false))
    }

    /// Whether `item` can be tried again: the page that started it is still
    /// open.
    func canRetry(_ item: Item) -> Bool { sources[item.id]?.view != nil }

    // MARK: WebKit

    /// A page's navigation became `download`.
    func adopt(_ download: WKDownload, from view: WKWebView) {
        download.delegate = self
        starting[ObjectIdentifier(download)] = Source(view: view, url: download.originalRequest?.url)
    }

    // MARK: Actions

    func cancel(_ item: Item) {
        tasks[item.id]?.cancel()
        update(item.id) { $0.state = .canceled }
    }

    /// Start a failed or canceled download again, from the beginning.
    func retry(_ item: Item) {
        guard let view = sources[item.id]?.view, let url = sources[item.id]?.url else { return }
        remove(item, deleting: true)
        Task { adopt(await view.startDownload(using: URLRequest(url: url)), from: view) }
    }

    /// Take `item` off the list; with `deleting`, its file goes too.
    func remove(_ item: Item, deleting: Bool = false) {
        if item.state == .running { tasks[item.id]?.cancel() }
        if deleting { try? FileManager.default.removeItem(at: url(of: item)) }
        forget(item.id)
        items.removeAll { $0.id == item.id }
        save()
    }

    /// Take finished, failed and canceled downloads off the list; the files
    /// stay.
    func clear() {
        for item in items where item.state != .running { forget(item.id) }
        items.removeAll { $0.state != .running }
        save()
    }

    // MARK: Inside

    private func forget(_ id: Item.ID) {
        tasks[id] = nil
        sources[id] = nil
        watching[id] = nil
        progress[id] = nil
        if recent == id { recent = nil }
    }

    private func update(_ id: Item.ID, _ change: (inout Item) -> Void) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[i])
        save()
    }

    /// The card stays six seconds after the download ended, as on the desktop.
    private func showEnded(_ id: Item.ID) {
        hiding?.cancel()
        hiding = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, let self, recent == id else { return }
            recent = nil
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        try? data.write(to: Self.file, options: .atomic)
    }

    /// `name`, or "name (2).ext" and so on when the folder has that already
    /// or an entry of the list names it: entries find their file by name, so
    /// a new file never takes the name of an old entry, even one whose file
    /// is gone.
    private func free(_ name: String) -> String {
        let listed = Set(items.map(\.name))
        let folder = Self.folder
        let clean = name.replacingOccurrences(of: "/", with: "_").trimmingCharacters(in: .whitespaces)
        let base = clean.isEmpty ? "Download" : clean
        let ext = (base as NSString).pathExtension
        let stem = (base as NSString).deletingPathExtension
        var candidate = base
        var n = 2
        while listed.contains(candidate)
            || FileManager.default.fileExists(atPath: folder.appending(path: candidate).path(percentEncoded: false)) {
            candidate = ext.isEmpty ? "\(stem) (\(n))" : "\(stem) (\(n)).\(ext)"
            n += 1
        }
        return candidate
    }
}

extension Downloads: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String) async -> URL? {
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        let item = Item(name: free(suggestedFilename),
                        size: response.expectedContentLength > 0 ? response.expectedContentLength : nil)
        items.insert(item, at: 0)
        running[ObjectIdentifier(download)] = item.id
        tasks[item.id] = download
        sources[item.id] = starting.removeValue(forKey: ObjectIdentifier(download))
        recent = item.id
        hiding?.cancel()
        watching[item.id] = download.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            let share = progress.fractionCompleted
            Task { @MainActor in
                guard let self, self.tasks[item.id] != nil else { return }
                self.progress[item.id] = share
            }
        }
        save()
        return url(of: item)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let id = running.removeValue(forKey: ObjectIdentifier(download)),
              let item = items.first(where: { $0.id == id })
        else { return }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url(of: item).path(percentEncoded: false))
        let size = (attributes?[.size] as? NSNumber)?.int64Value
        tasks[id] = nil
        sources[id] = nil
        watching[id] = nil
        progress[id] = nil
        update(id) {
            $0.state = .finished
            $0.size = size ?? $0.size
        }
        showEnded(id)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let id = running.removeValue(forKey: ObjectIdentifier(download)) else { return }
        tasks[id] = nil
        watching[id] = nil
        progress[id] = nil
        let canceled = (error as NSError).code == NSURLErrorCancelled
        update(id) { $0.state = canceled ? .canceled : .failed }
        showEnded(id)
    }
}

import Observation
import UIKit
import WebKit

/// Site icons, kept on this device. One is fetched when a page of the site
/// was loaded here, and again after `keep` at the earliest; a row never
/// makes the app contact a site. Private pages leave none.
@MainActor @Observable
final class Favicons {
    static let shared = Favicons()

    /// Goes up when an icon was saved, so rows showing a letter look again.
    private(set) var saved = 0
    @ObservationIgnored private var loaded: [String: UIImage?] = [:]
    @ObservationIgnored private var fetching: Set<String> = []
    /// How long an icon is used before the site is asked again.
    @ObservationIgnored private let keep: TimeInterval = 7 * 24 * 60 * 60
    @ObservationIgnored private let largest = 1_000_000
    @ObservationIgnored private let session = URLSession(configuration: .ephemeral)
    @ObservationIgnored private let dir = URL.cachesDirectory.appending(path: "favicons")

    /// The file name for a page's site: its host in lowercase without
    /// `www.`, as on the desktop.
    static func key(for page: String) -> String? {
        guard let url = URL(string: page), var host = url.host?.lowercased(), !host.isEmpty else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        let safe = host.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-") }
        guard safe, !host.contains("..") else { return nil }
        return url.port.map { "\(host)_\($0)" } ?? host
    }

    /// The icon of `page`'s site, if one is kept.
    func image(for page: String) -> UIImage? {
        _ = saved
        guard let key = Self.key(for: page) else { return nil }
        if let known = loaded[key] { return known }
        let image = UIImage(contentsOfFile: file(key).path(percentEncoded: false))
        loaded[key] = .some(image)
        return image
    }

    private func file(_ key: String) -> URL { dir.appending(path: key + ".png") }

    /// A page finished loading in `view`: fetch its site's icon, unless a
    /// recent one is kept.
    func pageLoaded(in view: WKWebView) {
        guard view.configuration.websiteDataStore.isPersistent,
              let page = view.url, page.scheme == "https",
              let key = Self.key(for: page.absoluteString), !fetching.contains(key) else { return }
        let age = (try? file(key).resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate.map { Date.now.timeIntervalSince($0) }
        if let age, age < keep { return }
        fetching.insert(key)
        Task {
            defer { fetching.remove(key) }
            // The icons the page names, best first, then the usual place.
            let named = (try? await view.evaluateJavaScript(Self.script)) as? [String] ?? []
            let candidates = named.compactMap { URL(string: $0) } + [page.appending(path: "/favicon.ico")]
            for candidate in candidates where candidate.scheme == "https" {
                guard let image = await fetch(candidate) else { continue }
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                guard (try? image.pngData()?.write(to: file(key), options: .atomic)) != nil else { return }
                loaded[key] = .some(image)
                saved += 1
                return
            }
        }
    }

    /// Touch icons first (they are made for a home screen), then the others,
    /// largest first.
    private static let script = """
    (() => {
      const size = l => Math.max(0, ...(l.getAttribute("sizes") || "").split(/\\s+/).map(s => parseInt(s) || 0));
      const links = [...document.querySelectorAll('link[rel~="apple-touch-icon"], link[rel~="icon"]')];
      const touch = l => l.rel.includes("apple-touch-icon") ? 1 : 0;
      return links.sort((a, b) => touch(b) - touch(a) || size(b) - size(a)).map(l => l.href);
    })()
    """

    /// The image at `url`, scaled down to what a row needs.
    private func fetch(_ url: URL) async -> UIImage? {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("image/png,image/*;q=0.8", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200, data.count <= largest,
              let image = UIImage(data: data), image.size.width >= 16 else { return nil }
        let side: CGFloat = 128
        guard max(image.size.width, image.size.height) * image.scale > side else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
    }
}

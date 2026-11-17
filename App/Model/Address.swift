import Foundation

/// What the address field's text means: an address, or a search.
enum Address {
    /// The search engines Settings offers; `%s` stands for the search words.
    /// The same list as on the desktop.
    static let engines: [(label: String, template: String)] = [
        ("DuckDuckGo", "https://duckduckgo.com/?q=%s"),
        ("Startpage", "https://www.startpage.com/do/search?q=%s"),
        ("Ecosia", "https://www.ecosia.org/search?q=%s"),
        ("Brave Search", "https://search.brave.com/search?q=%s"),
        ("Kagi", "https://kagi.com/search?q=%s"),
        ("Google", "https://www.google.com/search?q=%s"),
    ]
    static let searchKey = "search.template"

    static var searchTemplate: String {
        UserDefaults.standard.string(forKey: searchKey) ?? engines[0].template
    }

    /// The page for `text`: the address when it is one (`example.org`,
    /// `localhost:3000`, `https://…`), else a search for it.
    static func url(for text: String, search template: String = searchTemplate) -> URL? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let url = URL(string: text), let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme), url.host != nil {
            return url
        }
        if !text.contains(" "), let url = URL(string: "https://" + text), let host = url.host,
           host.contains(".") || host == "localhost" {
            // Pages on this device rarely have https.
            return host == "localhost" ? URL(string: "http://" + text) : url
        }
        let words = text.addingPercentEncoding(withAllowedCharacters: .urlQueryValue) ?? ""
        return URL(string: template.replacingOccurrences(of: "%s", with: words))
    }

    /// The site's name for a row or the address field: the host without `www.`.
    static func site(of url: URL) -> String {
        let host = url.host ?? url.absoluteString
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

private extension CharacterSet {
    /// What may stand in a query value as it is.
    static let urlQueryValue = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}

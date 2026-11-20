import Foundation

/// What the QR code beside the sync code on a computer holds: the link
/// `magnetite://sync?server=…&words=…` with the chain's server and its 24
/// words (the browser's `docs/spec/sync.md`).
struct JoinLink: Equatable {
    let server: String
    let words: String

    /// `nil` when `text` is not such a link.
    init?(_ text: String) {
        guard let link = URLComponents(string: text), link.scheme == "magnetite", link.host == "sync" else {
            return nil
        }
        let value = { name in link.queryItems?.first { $0.name == name }?.value ?? "" }
        server = value("server")
        words = value("words")
        if server.isEmpty || words.isEmpty { return nil }
    }
}

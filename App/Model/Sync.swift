import Foundation
import Observation
import UIKit

/// This device's place in a sync chain. It reads the chain's sidebar and
/// never writes to it (see the core's notes on why).
@MainActor @Observable
final class Sync {
    private(set) var sidebar: Sidebar?
    private(set) var server: String?
    private(set) var busy = false
    private(set) var lastError: String?
    private(set) var lastSync: Date?

    var joined: Bool { server != nil }

    @ObservationIgnored private let keychain = Keychain(service: "org.magnetitebrowser.ios.sync")
    @ObservationIgnored private let serverKey = "sync.server"
    /// Asked again when the app comes to the front after this long.
    @ObservationIgnored private let interval: TimeInterval = 5 * 60

    /// Where the core keeps the sidebar it last read.
    private var dir: String {
        URL.applicationSupportDirectory.appending(path: "sync").path(percentEncoded: false)
    }

    init() {
        guard let server = UserDefaults.standard.string(forKey: serverKey), keychain.read() != nil else {
            return
        }
        self.server = server
        sidebar = cached(dir: dir)
    }

    /// Join the chain of the 24 `words` on `server`. The caller reads it next.
    func join(server: String, words: String) async {
        busy = true
        lastError = nil
        do {
            let secret = try await Task.detached { try MagnetiteCore.join(server: server, words: words) }.value
            guard keychain.write(secret) else {
                throw SyncError.Storage(message: "The sync code could not be stored on this device.")
            }
            UserDefaults.standard.set(server, forKey: serverKey)
            self.server = server
            busy = false
        } catch {
            lastError = Self.text(of: error)
            busy = false
        }
    }

    /// Forget the code and the sidebar here. The chain and the other devices
    /// stay as they are.
    func leave() {
        keychain.remove()
        UserDefaults.standard.removeObject(forKey: serverKey)
        forget(dir: dir)
        server = nil
        sidebar = nil
        lastError = nil
        lastSync = nil
    }

    func refresh() async {
        guard let server, let secret = keychain.read(), !busy else { return }
        busy = true
        defer { busy = false }
        let dir = dir
        do {
            let newer = try await Task.detached {
                try MagnetiteCore.refresh(server: server, secret: secret, dir: dir)
            }.value
            if let newer { sidebar = newer }
            lastError = nil
            lastSync = .now
        } catch {
            lastError = Self.text(of: error)
        }
    }

    /// Joined, and the last sync is a while ago.
    var due: Bool {
        joined && lastSync.map { Date.now.timeIntervalSince($0) > interval } ?? true
    }

    static let sharesTabsKey = "sync.sharesTabs"
    /// Whether the chain's other devices see the tabs open here.
    var sharesTabs: Bool {
        UserDefaults.standard.object(forKey: Self.sharesTabsKey) as? Bool ?? true
    }

    /// This install, as the chain's other devices see it.
    private var device: Device {
        let key = "device.id"
        let id = UserDefaults.standard.string(forKey: key) ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return Device(id: id, name: UIDevice.current.name)
    }

    /// Tell the chain which `tabs` are open here. Returns the ids of those
    /// another device took over; none when it could not be asked.
    func exchange(_ tabs: [DeviceTab]) async -> [String] {
        guard let server, let secret = keychain.read() else { return [] }
        let device = device
        do {
            return try await Task.detached {
                try MagnetiteCore.exchange(server: server, secret: secret, device: device, tabs: tabs)
            }.value
        } catch {
            lastError = Self.text(of: error)
            return []
        }
    }

    private static func text(of error: Error) -> String {
        guard let error = error as? SyncError else { return error.localizedDescription }
        let message = switch error {
        case let .NotACode(message), let .Address(message), let .NoChain(message), let .Empty(message),
             let .Server(message), let .Unreadable(message), let .Storage(message): message
        }
        return message.prefix(1).uppercased() + message.dropFirst() + "."
    }
}

/// The core's functions under a name, where a method of the same name is
/// in scope.
enum MagnetiteCore {
    static func join(server: String, words: String) throws -> String {
        try Magnetite.join(server: server, words: words)
    }

    static func refresh(server: String, secret: String, dir: String) throws -> Sidebar? {
        try Magnetite.refresh(server: server, secret: secret, dir: dir)
    }

    static func exchange(server: String, secret: String, device: Device, tabs: [DeviceTab]) throws -> [String] {
        try Magnetite.exchange(server: server, secret: secret, device: device, tabs: tabs)
    }
}

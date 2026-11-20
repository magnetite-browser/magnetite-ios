import SwiftUI

/// Join a sync chain: scan the QR code of a computer that syncs, or enter
/// the server and the 24 words.
struct JoinView: View {
    @Environment(Sync.self) private var sync
    @Environment(Browser.self) private var browser
    @Environment(\.dismiss) private var dismiss

    @State private var ownServer = false
    @State private var address = ""
    @State private var words = ""
    @State private var scanning = false

    private var server: String { ownServer ? address : defaultServer() }
    /// A sync code has 24 words.
    private var complete: Bool {
        words.split(whereSeparator: \.isWhitespace).count == 24 && !(ownServer && address.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Scan QR Code", systemImage: "qrcode.viewfinder") { scanning = true }
                        .disabled(sync.busy)
                } footer: {
                    Text("On your computer: Settings → Sync → Show sync code. Or enter its server and words below.")
                }
                Section {
                    Picker("Server", selection: $ownServer) {
                        Text("Magnetite Sync").tag(false)
                        Text("Your own server").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if ownServer {
                        TextField("https://sync.example.org", text: $address)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                Section {
                    TextField("24 words", text: $words, axis: .vertical)
                        .lineLimit(4...8)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                } header: {
                    Text("Sync code")
                } footer: {
                    Text("The words stay on this device, in its key store.")
                }
                Section {
                    Button {
                        Task { await join() }
                    } label: {
                        if sync.busy { ProgressView() } else { Text("Join") }
                    }
                    .disabled(!complete || sync.busy)
                } footer: {
                    if let error = sync.lastError {
                        Text(error).foregroundStyle(.red)
                    } else {
                        Text("This device shows the chain's spaces, favorites and pinned tabs, and does not change them. Your other devices see the tabs open here.")
                    }
                }
            }
            .navigationTitle("Join a Sync Chain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $scanning) {
                ScannerView { link in
                    scanning = false
                    // Shown in the form too, so a join that fails can be looked at.
                    ownServer = link.server != defaultServer()
                    address = ownServer ? link.server : ""
                    words = link.words
                    Task { await join() }
                }
            }
        }
    }

    /// One join at a time: a second one would write over the first one's chain.
    private func join() async {
        guard !sync.busy else { return }
        await sync.join(server: server, words: words)
        if sync.joined {
            await browser.syncNow()
            dismiss()
        }
    }
}

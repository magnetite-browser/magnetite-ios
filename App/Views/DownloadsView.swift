import QuickLook
import SwiftUI
import UniformTypeIdentifiers

/// What the start page, the page's menu and the keys open in a sheet.
enum Library: String, Identifiable {
    case history, downloads
    var id: Self { self }

    @ViewBuilder var view: some View {
        switch self {
        case .history: HistoryView()
        case .downloads: DownloadsView()
        }
    }
}

/// The files pages downloaded, newest first. A tap opens a finished one in
/// Quick Look; holding one offers what fits it as it is.
struct DownloadsView: View {
    @Environment(Browser.self) private var browser
    @Environment(\.dismiss) private var dismiss
    @State private var preview: URL?
    @State private var deleting: Downloads.Item?

    var body: some View {
        let downloads = browser.downloads
        NavigationStack {
            List {
                ForEach(downloads.items) { item in
                    Button { open(item) } label: { DownloadRow(item: item) }
                        .buttonStyle(.plain)
                        .contextMenu { menu(item) }
                        .swipeActions {
                            if item.state == .running {
                                Button("Cancel", systemImage: "xmark") { downloads.cancel(item) }
                            } else {
                                Button("Remove from List", systemImage: "minus.circle", role: .destructive) {
                                    downloads.remove(item)
                                }
                            }
                        }
                }
            }
            .listStyle(.plain)
            .overlay {
                if downloads.items.isEmpty {
                    ContentUnavailableView("No Downloads", systemImage: "arrow.down.circle",
                                           description: Text("Files you download show here and in the Files app."))
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { withAnimation { downloads.clear() } }
                        .disabled(!downloads.items.contains { $0.state != .running })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Show in Files", systemImage: "folder", action: showInFiles)
                        .labelStyle(.titleAndIcon)
                }
            }
            .quickLookPreview($preview)
            .confirmationDialog("Delete “\(deleting?.name ?? "")”?",
                                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                                titleVisibility: .visible, presenting: deleting) { item in
                Button("Delete", role: .destructive) { withAnimation { downloads.remove(item, deleting: true) } }
            } message: { _ in
                Text("The file is deleted from this device.")
            }
        }
    }

    private func open(_ item: Downloads.Item) {
        let downloads = browser.downloads
        switch item.state {
        case .finished where downloads.exists(item): preview = downloads.url(of: item)
        case .failed, .canceled where downloads.canRetry(item): downloads.retry(item)
        default: break
        }
    }

    @ViewBuilder private func menu(_ item: Downloads.Item) -> some View {
        let downloads = browser.downloads
        switch item.state {
        case .running:
            Button("Cancel", systemImage: "xmark") { downloads.cancel(item) }
        case .finished where downloads.exists(item):
            let file = downloads.url(of: item)
            Button("Open", systemImage: "eye") { preview = file }
            ShareLink(item: file) { Label("Share", systemImage: "square.and.arrow.up") }
            Button("Show in Files", systemImage: "folder", action: showInFiles)
            Button("Remove from List", systemImage: "minus.circle") { downloads.remove(item) }
            Button("Delete", systemImage: "trash", role: .destructive) { deleting = item }
        default:
            if downloads.canRetry(item) {
                Button("Try Again", systemImage: "arrow.clockwise") { downloads.retry(item) }
            }
            Button("Remove from List", systemImage: "minus.circle") { downloads.remove(item) }
        }
    }

    /// The Files app, at the downloads.
    private func showInFiles() {
        try? FileManager.default.createDirectory(at: Downloads.folder, withIntermediateDirectories: true)
        let path = Downloads.folder.path(percentEncoded: true)
        if let url = URL(string: "shareddocuments://\(path)") { UIApplication.shared.open(url) }
    }
}

/// A download: its kind of file, its name (cut in the middle, so the
/// extension stays) and how far it is, or its size.
struct DownloadRow: View {
    @Environment(Browser.self) private var browser
    let item: Downloads.Item

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: Self.symbol(for: item.name))
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if item.state == .running {
                    ProgressView(value: browser.downloads.progress[item.id] ?? 0)
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(item.state == .failed ? .red : .secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }

    private var detail: String {
        let size = item.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
        switch item.state {
        case .running:
            let share = browser.downloads.progress[item.id].map { "\(Int($0 * 100)) %" }
            return [share, size].compactMap(\.self).joined(separator: " · ")
        case .finished:
            guard browser.downloads.exists(item) else { return String(localized: "Deleted") }
            return [size, item.date.formatted(date: .abbreviated, time: .shortened)].compactMap(\.self)
                .joined(separator: " · ")
        case .failed: return String(localized: "Failed")
        case .canceled: return String(localized: "Canceled")
        }
    }

    static func symbol(for name: String) -> String {
        guard let type = UTType(filenameExtension: (name as NSString).pathExtension) else { return "doc" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .movie) { return "film" }
        if type.conforms(to: .audio) { return "music.note" }
        if type.conforms(to: .archive) { return "doc.zipper" }
        if type.conforms(to: .text) { return "doc.text" }
        return "doc"
    }
}

/// The download that runs, or just ended, on glass over the page: a tap
/// opens the downloads.
struct DownloadCard: View {
    @Environment(Browser.self) private var browser
    let open: () -> Void

    var body: some View {
        if let id = browser.downloads.recent, let item = browser.downloads.items.first(where: { $0.id == id }) {
            Button(action: open) {
                HStack(spacing: 10) {
                    Image(systemName: icon(item))
                        .font(.title3)
                        .foregroundStyle(item.state == .failed ? .red : .accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if item.state == .running {
                            ProgressView(value: browser.downloads.progress[item.id] ?? 0)
                        } else {
                            Text(item.state == .finished ? "Downloaded" : item.state == .failed ? "Failed" : "Canceled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .glass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityLabel(item.name)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func icon(_ item: Downloads.Item) -> String {
        switch item.state {
        case .running: "arrow.down.circle"
        case .finished: "checkmark.circle"
        case .failed: "exclamationmark.circle"
        case .canceled: "xmark.circle"
        }
    }
}

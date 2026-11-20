import AVFoundation
import SwiftUI
import VisionKit

/// The camera, looking for the QR code that Magnetite on a computer shows
/// beside its sync code. Hands the first one it reads to `onRead`; other QR
/// codes are passed over. Nothing the camera sees is kept or sent.
struct ScannerView: View {
    let onRead: (JoinLink) -> Void

    @Environment(\.dismiss) private var dismiss
    /// Whether the camera may be used; `nil` while the system asks.
    @State private var allowed: Bool?

    var body: some View {
        NavigationStack {
            // Not a Group: while the system asks there is nothing in it, and the
            // title and the task below would have no view to belong to.
            ZStack {
                if allowed == true, DataScannerViewController.isSupported {
                    CodeScanner { text in
                        if let link = JoinLink(text) { onRead(link) }
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .safeAreaInset(edge: .bottom) {
                        Text("On your computer: Settings → Sync → Show sync code")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: .capsule)
                            .padding(.bottom, 24)
                    }
                } else if allowed != nil {
                    ContentUnavailableView(
                        "No Camera to Scan With",
                        systemImage: "camera",
                        description: Text("Allow Magnetite to use the camera in the Settings app, or type the 24 words instead.")
                    )
                }
            }
            .navigationTitle("Scan the QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { allowed = await AVCaptureDevice.requestAccess(for: .video) }
        }
    }
}

/// The system's scanner, set to QR codes.
private struct CodeScanner: UIViewControllerRepresentable {
    let onRead: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onRead: onRead) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])])
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onRead: (String) -> Void

        init(onRead: @escaping (String) -> Void) {
            self.onRead = onRead
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for case .barcode(let code) in addedItems {
                if let text = code.payloadStringValue { onRead(text) }
            }
        }
    }
}

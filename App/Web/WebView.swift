import SwiftUI
import WebKit

/// Puts a page's web view on screen. Give it the tab's id (`.id(…)`) so
/// another tab gets a view of its own.
struct WebView: UIViewRepresentable {
    let page: WebPage

    func makeUIView(context: Context) -> WKWebView { page.view }
    func updateUIView(_ view: WKWebView, context: Context) {}
}

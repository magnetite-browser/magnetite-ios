import Observation
import UIKit
import WebKit

/// One tab's page: the web view and what the bars show of it.
@MainActor @Observable
final class WebPage: NSObject {
    let view: WKWebView
    private(set) var url: URL?
    private(set) var title = ""
    private(set) var progress = 0.0
    private(set) var loading = false
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    /// Why the page could not be loaded, while that is what is shown.
    private(set) var failure: String?

    /// Called when the address or title changed.
    @ObservationIgnored var changed: ((URL?, String) -> Void)?
    /// Called when the page wants `url` in a new tab.
    @ObservationIgnored var opensTab: ((URL) -> Void)?
    @ObservationIgnored private var watching: [NSKeyValueObservation] = []

    init(url: URL, store: WKWebsiteDataStore) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = store
        config.allowsInlineMediaPlayback = true
        // Without Safari's tail, sites take the app for a page inside
        // another app and hold features back.
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        config.applicationNameForUserAgent = "Version/\(major).0 Mobile/15E148 Safari/604.1"
        view = WKWebView(frame: .zero, configuration: config)
        super.init()
        view.allowsBackForwardNavigationGestures = true
        view.navigationDelegate = self
        view.uiDelegate = self
        #if DEBUG
        view.isInspectable = true
        #endif
        let pull = UIRefreshControl()
        pull.addTarget(self, action: #selector(pulled(_:)), for: .valueChanged)
        view.scrollView.refreshControl = pull
        watch()
        self.url = url
        view.load(URLRequest(url: url))
    }

    func reload() {
        failure = nil
        if view.url == nil, let url {
            view.load(URLRequest(url: url))
        } else {
            view.reload()
        }
    }

    @objc private func pulled(_ control: UIRefreshControl) {
        reload()
        control.endRefreshing()
    }

    /// Mirror the web view's state; WebKit reports changes on the main thread.
    private func watch() {
        func on<Value>(_ path: KeyPath<WKWebView, Value>, _ set: @escaping (WebPage, WKWebView) -> Void) {
            watching.append(view.observe(path) { [weak self] view, _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    set(self, view)
                }
            })
        }
        on(\.url) { page, view in
            if let url = view.url { page.url = url }
            page.changed?(page.url, page.title)
        }
        on(\.title) { page, view in
            page.title = view.title ?? ""
            page.changed?(page.url, page.title)
        }
        on(\.estimatedProgress) { $0.progress = $1.estimatedProgress }
        on(\.isLoading) { $0.loading = $1.isLoading }
        on(\.canGoBack) { $0.canGoBack = $1.canGoBack }
        on(\.canGoForward) { $0.canGoForward = $1.canGoForward }
    }
}

extension WebPage: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = action.request.url, let scheme = url.scheme?.lowercased() else { return .allow }
        if ["http", "https", "about", "blob", "data"].contains(scheme) { return .allow }
        // Mail, phone, app links: the system's business, and only when the
        // page itself goes there, not one of its frames.
        if action.targetFrame?.isMainFrame ?? true {
            await UIApplication.shared.open(url)
        }
        return .cancel
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        failure = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Favicons.shared.pageLoaded(in: webView)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let error = error as NSError
        // Stopped by the user, or handed to another app.
        let harmless = (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled)
            || (error.domain == "WebKitErrorDomain" && error.code == 102)
        if !harmless { failure = error.localizedDescription }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        failure = "This page stopped working."
    }
}

extension WebPage: WKUIDelegate {
    /// A link that asks for a new window opens as a new tab.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            opensTab?(url)
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async {
        await withCheckedContinuation { done in
            let alert = dialog(message, from: frame)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in done.resume() })
            show(alert) { done.resume() }
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async -> Bool {
        await withCheckedContinuation { done in
            let alert = dialog(message, from: frame)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in done.resume(returning: false) })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in done.resume(returning: true) })
            show(alert) { done.resume(returning: false) }
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo) async -> String? {
        await withCheckedContinuation { done in
            let alert = dialog(prompt, from: frame)
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in done.resume(returning: nil) })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in
                done.resume(returning: alert?.textFields?.first?.text ?? "")
            })
            show(alert) { done.resume(returning: nil) }
        }
    }

    /// The dialog says which site speaks, so a page cannot pass for the app.
    private func dialog(_ message: String, from frame: WKFrameInfo) -> UIAlertController {
        UIAlertController(title: frame.securityOrigin.host, message: message, preferredStyle: .alert)
    }

    /// Show `alert` over whatever is on screen; `otherwise` runs when
    /// nothing can show it, so the page always gets its answer.
    private func show(_ alert: UIAlertController, otherwise: () -> Void) {
        var top = view.window?.rootViewController
        while let over = top?.presentedViewController { top = over }
        guard let top else { return otherwise() }
        top.present(alert, animated: true)
    }
}

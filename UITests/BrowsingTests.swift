import XCTest

/// Typing an address and following links, on a phone. Needs the demo sync
/// server of magnetite-mobile-core (see `JoinAndBrowseTests`; another port
/// with `TEST_RUNNER_DEMO_SERVER=http://localhost:…`); joins its chain
/// unless the app already did.
final class BrowsingTests: XCTestCase {
    /// The demo chain's sync code (32 zero bytes).
    private let words = Array(repeating: "abandon", count: 23).joined(separator: " ") + " art"
    private let server = ProcessInfo.processInfo.environment["DEMO_SERVER"] ?? "http://localhost:8787"
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad)
        app = XCUIApplication()
        app.launch()
        if app.buttons["Join a Sync Chain"].waitForExistence(timeout: 3) {
            app.buttons["Join a Sync Chain"].firstMatch.tap()
            app.buttons["Your own server"].tap()
            let address = app.textFields["https://sync.example.org"]
            address.tap()
            address.typeText(server)
            let code = app.textFields["24 words"]
            code.tap()
            code.typeText(words)
            app.buttons["Join"].tap()
        }
        // A tab an earlier test left in front: back to the start page.
        if app.buttons["More"].waitForExistence(timeout: 3) {
            app.buttons["More"].tap()
            app.collectionViews.buttons["New Tab"].tap()
            app.buttons.matching(identifier: "xmark").firstMatch.tap()
        }
        XCTAssertTrue(app.staticTexts["Wikipedia"].waitForExistence(timeout: 15))
    }

    /// A word typed in the address field offers the chain's page that
    /// matches, and picking it opens that page.
    func testTypingOffersTheChainsPages() {
        // Over a page, the field shows the site until tapped.
        let site = app.buttons["address"]
        if site.exists { site.tap() } else { app.textFields["Search or enter address"].tap() }
        app.typeText("rust")
        let row = app.buttons.containing(.staticText, identifier: "rust-lang.org · Home").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["rust-lang.org"].waitForExistence(timeout: 30))
    }

    /// Holding a link and picking "Open in Background" adds a tab behind the
    /// one in front.
    func testHoldingALinkOpensItBehind() {
        app.staticTexts["Example"].firstMatch.tap()
        let link = app.webViews.links["Learn more"]
        XCTAssertTrue(link.waitForExistence(timeout: 30))
        let before = Int(app.buttons["Tabs"].value as? String ?? "") ?? 0
        link.press(forDuration: 1.2)
        app.buttons["Open in Background"].tap()
        XCTAssertTrue(app.buttons["example.org"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["Tabs"].value as? String, "\(before + 1)")
    }

    /// A web link another app hands over (Magnetite as the default browser)
    /// opens as a tab.
    func testALinkFromAnotherAppOpensAsATab() {
        app.open(URL(string: "https://example.org/")!)
        XCTAssertTrue(app.buttons["example.org"].waitForExistence(timeout: 30))
    }

    /// A page visited shows in History and, once its tab is closed, is
    /// offered while typing.
    func testAVisitedPageIsInHistoryAndOffered() {
        app.open(URL(string: "https://www.iana.org/help/example-domains")!)
        XCTAssertTrue(app.buttons["iana.org"].waitForExistence(timeout: 30))
        app.buttons["More"].tap()
        app.collectionViews.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Example Domains"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        app.buttons["More"].tap()
        app.collectionViews.buttons["Close Tab"].tap()

        app.textFields["Search or enter address"].tap()
        app.typeText("iana")
        let row = app.buttons.containing(.staticText, identifier: "iana.org · History").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    /// The demo server's page has an image EasyList blocks. Blocked once the
    /// lists are in use (they come with the first web page); loaded on a
    /// site that the page's menu lets load everything.
    func testAnAdIsBlockedUnlessTheSiteIsAllowed() {
        // Typed: a link from another app reaches the app only with https.
        app.textFields["Search or enter address"].tap()
        app.typeText("\(server)/demo/ads\n")
        XCTAssertTrue(app.webViews.staticTexts["Content blocking"].waitForExistence(timeout: 30))
        let blocked = app.webViews.staticTexts["The ad was blocked"]
        // A first start downloads and compiles the lists meanwhile.
        for _ in 0..<12 where !blocked.waitForExistence(timeout: 10) {
            menu("Reload")
        }
        XCTAssertTrue(blocked.exists)

        menu("Block Ads")
        XCTAssertTrue(app.webViews.staticTexts["The ad loaded"].waitForExistence(timeout: 10))
        menu("Block Ads")
        XCTAssertTrue(blocked.waitForExistence(timeout: 10))
    }

    /// A file no page shows is downloaded: the tab opened for it goes
    /// again, a card over the bar shows it, and Downloads lists it.
    func testAFileIsDownloaded() {
        app.textFields["Search or enter address"].tap()
        app.typeText("\(server)/demo/magnetite-demo.bin\n")
        // An earlier run's file is there: this one is "magnetite-demo (2).bin".
        let named = NSPredicate(format: "label BEGINSWITH 'magnetite-demo'")
        let card = app.buttons.matching(named).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Wikipedia"].exists, "back on the start page")
        card.tap()
        let row = app.collectionViews.staticTexts.matching(named).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(app.collectionViews.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '4 KB'"))
            .firstMatch.waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
    }

    /// The chain's bookmarks, from the start page's library: a folder opens,
    /// and a bookmark opens as a tab.
    func testABookmarkOpensAsATab() {
        app.buttons["Library"].firstMatch.tap()
        app.collectionViews.buttons["Bookmarks"].tap()
        let folder = app.staticTexts["Docs"]
        XCTAssertTrue(folder.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["The Rust Programming Language"].exists, "folders start closed")
        folder.tap()
        app.staticTexts["The Rust Programming Language"].tap()
        XCTAssertTrue(app.buttons["doc.rust-lang.org"].waitForExistence(timeout: 30))
    }

    private func menu(_ item: String) {
        app.buttons["More"].tap()
        app.collectionViews.buttons[item].tap()
    }
}

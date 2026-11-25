import XCTest

/// Typing an address and following links, on a phone. Needs the demo sync
/// server of magnetite-mobile-core (see `JoinAndBrowseTests`); joins its
/// chain unless the app already did.
final class BrowsingTests: XCTestCase {
    /// The demo chain's sync code (32 zero bytes).
    private let words = Array(repeating: "abandon", count: 23).joined(separator: " ") + " art"
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
            address.typeText("http://localhost:8787")
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
}

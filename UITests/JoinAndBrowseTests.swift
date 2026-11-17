import XCTest

/// Joins the demo chain and opens a page from it. Needs the demo sync
/// server of magnetite-mobile-core on this machine
/// (`cargo run --example demo_server`) and a fresh install of the app.
final class JoinAndBrowseTests: XCTestCase {
    /// The demo chain's sync code (32 zero bytes).
    private let words = Array(repeating: "abandon", count: 23).joined(separator: " ") + " art"

    override func setUp() {
        continueAfterFailure = false
    }

    func testJoinShowsTheChainsSpacesAndOpensAPage() throws {
        // The steps are those of the narrow layout: the sidebar is a sheet.
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad)
        let app = XCUIApplication()
        app.launch()

        app.buttons["Join a Sync Chain"].tap()
        app.buttons["Your own server"].tap()
        let address = app.textFields["https://sync.example.org"]
        address.tap()
        address.typeText("http://localhost:8787")
        let code = app.textFields["24 words"]
        code.tap()
        code.typeText(words)
        app.buttons["Join"].tap()

        // The chain's first space, with its favorites and pinned tree.
        XCTAssertTrue(app.staticTexts["Wikipedia"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["MDN Web Docs"].exists)
        keep("1-home-space")

        // A folded folder hides what is in it, at every depth.
        app.staticTexts["Reading"].tap()
        XCTAssertFalse(app.staticTexts["MDN Web Docs"].exists)
        app.staticTexts["Reading"].tap()

        app.buttons["Work"].tap()
        XCTAssertTrue(app.staticTexts["magnetite"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Wikipedia"].exists)
        keep("2-work-space")

        app.buttons["Home"].tap()
        app.staticTexts["Example"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Learn more"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["example.org"].exists)
        keep("3-page")

        // The tab is listed as open here, in the space it was opened from.
        app.buttons["Tabs"].tap()
        XCTAssertTrue(app.staticTexts["Open here"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["example.org"].exists)
        keep("4-sidebar-over-page")

        // The chain learns of the tab, a desktop takes it over, and at the
        // next sync it is closed here: the app is back on its start page,
        // Settings and the sidebar over the page are gone.
        openSettings(app)
        app.buttons["Sync Now"].tap()
        sleep(2)
        app.buttons["settings.done"].tap()
        take()
        openSettings(app)
        app.buttons["Sync Now"].tap()
        XCTAssertTrue(app.staticTexts["No tabs open in this space. Type an address below, or pick a page above."]
            .waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Sync Now"].exists)
        keep("5-taken-over")

        // A site whose page was loaded here shows its icon from then on.
        app.staticTexts["Wikipedia"].tap()
        XCTAssertTrue(app.staticTexts["en.wikipedia.org"].waitForExistence(timeout: 30))
        sleep(6)
        app.buttons["Tabs"].tap()
        XCTAssertTrue(app.staticTexts["Open here"].waitForExistence(timeout: 5))
        keep("6-site-icon")
    }

    /// On an iPad the sidebar stays beside the page.
    func testOnAnIPadTheSidebarStaysBesideThePage() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
        let app = XCUIApplication()
        app.launch()

        app.buttons["Join a Sync Chain"].tap()
        app.buttons["Your own server"].tap()
        let address = app.textFields["https://sync.example.org"]
        address.tap()
        address.typeText("http://localhost:8787")
        let code = app.textFields["24 words"]
        code.tap()
        code.typeText(words)
        app.buttons["Join"].tap()
        XCTAssertTrue(app.staticTexts["Wikipedia"].waitForExistence(timeout: 15))
        keep("ipad-1-no-tab")

        app.staticTexts["Example"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Learn more"].waitForExistence(timeout: 30))
        // The page is open and the sidebar still there, listing it.
        XCTAssertTrue(app.staticTexts["Wikipedia"].exists)
        XCTAssertTrue(app.staticTexts["Open here"].exists)
        keep("ipad-2-page")

        app.buttons["Sidebar"].tap()
        XCTAssertTrue(app.staticTexts["Wikipedia"].waitForNonExistence(timeout: 5))
        keep("ipad-3-sidebar-hidden")
    }

    private func openSettings(_ app: XCUIApplication) {
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Sync Now"].waitForExistence(timeout: 5))
    }

    /// The demo server plays a desktop that takes over every listed tab.
    private func take() {
        var request = URLRequest(url: URL(string: "http://localhost:8787/demo/take")!)
        request.httpMethod = "POST"
        let done = expectation(description: "taken")
        var count = ""
        URLSession.shared.dataTask(with: request) { data, _, _ in
            count = String(decoding: data ?? Data(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            done.fulfill()
        }.resume()
        wait(for: [done], timeout: 10)
        // More than one when the server still holds an earlier run's phone.
        XCTAssertGreaterThanOrEqual(Int(count) ?? 0, 1, "the phone listed its tab")
    }

    private func keep(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

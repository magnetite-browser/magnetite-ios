import XCTest

/// The pictures on the App Store page, taken from the demo chain. Run by
/// `scripts/screenshots.sh`, which starts the demo server and collects them.
final class StoreScreenshots: XCTestCase {
    private let words = Array(repeating: "abandon", count: 23).joined(separator: " ") + " art"

    override func setUp() {
        continueAfterFailure = false
    }

    func testStoreScreenshots() {
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

        let pad = UIDevice.current.userInterfaceIdiom == .pad
        if !pad { keep("1-spaces") }

        // Our own site: the one page we may show on the store.
        app.staticTexts["Magnetite"].tap()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 30))
        sleep(8)
        keep(pad ? "1-sidebar-beside-the-page" : "2-page")

        if !pad {
            app.buttons["Tabs"].tap()
            XCTAssertTrue(app.staticTexts["Open here"].waitForExistence(timeout: 5))
            keep("3-sidebar-over-the-page")
        }

        app.buttons["Work"].tap()
        XCTAssertTrue(app.staticTexts["magnetite"].waitForExistence(timeout: 5))
        keep(pad ? "2-another-space" : "4-another-space")
    }

    private func keep(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

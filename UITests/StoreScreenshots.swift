import XCTest

/// The pictures and the preview video on the App Store page, taken from the
/// demo chain. Run by `scripts/screenshots.sh` and `scripts/preview.sh`,
/// which start the demo server and collect them. The only site shown is our
/// own: the store allows no one else's pages.
final class StoreScreenshots: XCTestCase {
    private let words = Array(repeating: "abandon", count: 23).joined(separator: " ") + " art"
    private let server = ProcessInfo.processInfo.environment["DEMO_SERVER"] ?? "http://localhost:8787"
    private let pad = UIDevice.current.userInterfaceIdiom == .pad
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        join()
    }

    /// The pictures, named in the order the store shows them.
    func testStoreScreenshots() {
        if !pad { keep("2-spaces") }

        app.staticTexts["Magnetite"].tap()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 30))
        sleep(8)
        keep(pad ? "1-sidebar-beside-the-page" : "1-page")

        app.buttons["More"].tap()
        XCTAssertTrue(app.collectionViews.buttons["Find on Page"].waitForExistence(timeout: 5))
        keep(pad ? "2-page-menu" : "3-page-menu")
        app.collectionViews.buttons["Reload"].tap()
        sleep(6)

        // On a phone the library is in the sidebar's sheet over the page.
        if !pad {
            app.buttons["Tabs"].tap()
            XCTAssertTrue(app.buttons["Library"].waitForExistence(timeout: 5))
        }
        app.buttons["Library"].firstMatch.tap()
        app.collectionViews.buttons["Bookmarks"].tap()
        let folder = app.staticTexts["Docs"]
        XCTAssertTrue(folder.waitForExistence(timeout: 5))
        folder.tap()
        sleep(1)
        keep(pad ? "3-bookmarks" : "5-bookmarks")
        app.buttons["Done"].firstMatch.tap()

        if !pad {
            app.buttons["Private"].firstMatch.tap()
            XCTAssertTrue(app.staticTexts["Private tabs"].waitForExistence(timeout: 5))
            sleep(1)
            keep("6-private")
            // Back to the page, to type over it.
            app.buttons["Home"].firstMatch.tap()
            app.buttons["Done"].firstMatch.tap()
        }

        XCTAssertTrue(app.buttons["address"].waitForExistence(timeout: 5))
        app.buttons["address"].tap()
        app.typeText("rust")
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        keep("4-suggestions")
    }

    /// The preview video: a walk through the app at a person's pace, while
    /// `scripts/preview.sh` records the screen. The script and the test meet
    /// through files in `PREVIEW_MARKS`: the test writes `ready` once the
    /// page it shows is loaded once, the script `recording` once it records,
    /// and the test `done` at the end.
    func testStorePreview() throws {
        guard let path = ProcessInfo.processInfo.environment["PREVIEW_MARKS"] else {
            throw XCTSkip("run by scripts/preview.sh")
        }
        let marks = URL(fileURLWithPath: path)
        // Once loaded, the page comes from the cache and its icon is known.
        app.staticTexts["Magnetite"].tap()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 30))
        sleep(8)
        app.buttons["More"].tap()
        app.collectionViews.buttons["Close Tab"].tap()
        XCTAssertTrue(app.staticTexts["Wikipedia"].waitForExistence(timeout: 5))
        sleep(2)

        try Data().write(to: marks.appendingPathComponent("ready"))
        let recording = marks.appendingPathComponent("recording")
        for _ in 0..<60 where !FileManager.default.fileExists(atPath: recording.path) { pause(0.5) }

        if pad { padTour() } else { phoneTour() }
        try Data().write(to: marks.appendingPathComponent("done"))
    }

    /// The start page, a swipe to another space and back, typing the page
    /// open, the page with the floating bar and its menu, the sidebar over
    /// the page and the private space.
    private func phoneTour() {
        pause(0.5)
        app.swipeLeft()
        pause(0.8)
        app.swipeRight()

        app.textFields["Search or enter address"].tap()
        app.typeText("magn")
        XCTAssertTrue(ourSite.waitForExistence(timeout: 5))
        pause(0.8)
        ourSite.tap()
        pause(2)
        scroll()

        app.buttons["More"].tap()
        pause(1.2)
        dismissMenu()

        app.buttons["Tabs"].tap()
        XCTAssertTrue(app.buttons["Private"].waitForExistence(timeout: 5))
        pause(0.6)
        app.buttons["Private"].firstMatch.tap()
        pause(1.2)
        app.buttons["Home"].firstMatch.tap()
        app.buttons["Done"].firstMatch.tap()
        pause(1.2)
    }

    /// Typing the page open beside the sidebar, the sidebar hidden and
    /// shown, another space, and the page's menu.
    private func padTour() {
        pause(0.3)
        app.textFields["Search or enter address"].tap()
        app.typeText("magn")
        XCTAssertTrue(ourSite.waitForExistence(timeout: 5))
        pause(0.8)
        ourSite.tap()
        pause(2)
        scroll()

        app.buttons["Sidebar"].tap()
        pause(1.5)
        app.buttons["Sidebar"].tap()
        pause(1)

        app.buttons["Work"].firstMatch.tap()
        pause(1)
        app.buttons["Home"].firstMatch.tap()
        pause(0.8)

        app.buttons["More"].tap()
        pause(1.2)
        dismissMenu()
        pause(1)
    }

    /// Down the page a little, and back.
    private func scroll() {
        app.webViews.firstMatch.swipeUp(velocity: .slow)
        pause(0.5)
        app.webViews.firstMatch.swipeDown()
        pause(0.5)
    }

    /// What typing offers for our site: its pinned tab in Home.
    private var ourSite: XCUIElement {
        app.buttons.containing(NSPredicate(format: "label == 'magnetitebrowser.org · Home'")).firstMatch
    }

    /// What typing "rust" offers first: the pinned page of the chain.
    private var suggestion: XCUIElement {
        app.buttons.containing(.staticText, identifier: "rust-lang.org · Home").firstMatch
    }

    /// Joins the demo chain, unless an earlier test in the run did: the
    /// scripts start each from a fresh install, which shows the invitation.
    private func join() {
        guard app.buttons["Join a Sync Chain"].waitForExistence(timeout: 3) else { return }
        app.buttons["Join a Sync Chain"].firstMatch.tap()
        app.buttons["Your own server"].tap()
        let field = app.textFields["https://sync.example.org"]
        field.tap()
        field.typeText(server)
        let code = app.textFields["24 words"]
        code.tap()
        code.typeText(words)
        app.buttons["Join"].tap()
        XCTAssertTrue(app.staticTexts["Wikipedia"].waitForExistence(timeout: 15))
    }

    /// A tap beside a menu closes it; the page under the tap does not get it.
    private func dismissMenu() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.4)).tap()
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func keep(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

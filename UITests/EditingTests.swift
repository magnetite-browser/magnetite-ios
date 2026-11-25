import XCTest

/// Changing the chain's sidebar from the phone: the change shows at once,
/// marked as waiting, and the mark goes once a desktop made it. The demo
/// server of magnetite-mobile-core plays that desktop (`/demo/apply`); run it
/// on another port with `TEST_RUNNER_DEMO_SERVER=http://localhost:…`.
final class EditingTests: XCTestCase {
    /// The demo chain's sync code (32 zero bytes).
    private let words = Array(repeating: "abandon", count: 23).joined(separator: " ") + " art"
    private let server = ProcessInfo.processInfo.environment["DEMO_SERVER"] ?? "http://localhost:8787"
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad)
        app = XCUIApplication()
        app.launch()
        app.buttons["Join a Sync Chain"].firstMatch.tap()
        app.buttons["Your own server"].tap()
        let address = app.textFields["https://sync.example.org"]
        address.tap()
        address.typeText(server)
        let code = app.textFields["24 words"]
        code.tap()
        code.typeText(words)
        app.buttons["Join"].tap()
        XCTAssertTrue(app.staticTexts["Wikipedia"].waitForExistence(timeout: 15))
    }

    func testAPinAndARenameWaitForADesktop() {
        // Pin the page of a favorite from the page's menu.
        app.staticTexts["Example"].firstMatch.tap()
        XCTAssertTrue(app.webViews.staticTexts["Learn more"].waitForExistence(timeout: 30))
        app.buttons["More"].tap()
        app.collectionViews.buttons["Pin in “Home”"].tap()
        app.buttons["Tabs"].tap()
        let waiting = app.images["Waiting for your computer"]
        XCTAssertTrue(waiting.waitForExistence(timeout: 5))

        // Rename a favorite by holding it.
        app.staticTexts["Wikipedia"].firstMatch.press(forDuration: 1.2)
        app.buttons["Rename…"].tap()
        let name = app.alerts.textFields.firstMatch
        name.tap()
        name.clearAndType("Wiki")
        app.alerts.buttons["Rename"].tap()
        XCTAssertTrue(app.staticTexts["Wiki"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.images.matching(identifier: "Waiting for your computer").count, 2)

        // The chain hears of both; a desktop makes them; the next sync shows them made.
        syncNow()
        // More than two when the server still holds an earlier run's phone.
        XCTAssertGreaterThanOrEqual(Int(demo("apply")) ?? 0, 2, "the phone listed its changes")
        syncNow()
        XCTAssertTrue(waiting.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Wiki"].exists)
        XCTAssertTrue(app.staticTexts["Example Domain"].exists)
    }

    private func syncNow() {
        app.buttons["Settings"].firstMatch.tap()
        let now = app.buttons["Sync Now"]
        XCTAssertTrue(now.waitForExistence(timeout: 5))
        now.tap()
        sleep(2)
        app.buttons["settings.done"].tap()
    }

    /// Ask the demo server to play a desktop: `apply` makes the phones' changes.
    private func demo(_ action: String) -> String {
        var request = URLRequest(url: URL(string: "\(server)/demo/\(action)")!)
        request.httpMethod = "POST"
        let done = expectation(description: action)
        var answer = ""
        URLSession.shared.dataTask(with: request) { data, _, _ in
            answer = String(decoding: data ?? Data(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            done.fulfill()
        }.resume()
        wait(for: [done], timeout: 10)
        return answer
    }
}

private extension XCUIElement {
    func clearAndType(_ text: String) {
        let current = value as? String ?? ""
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
    }
}

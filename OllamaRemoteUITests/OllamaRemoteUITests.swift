import XCTest

final class OllamaRemoteUITests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertTrue(true)
    }

    @MainActor
    func testCaptureOpenClawScreenshots() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsButton = app.navigationBars.buttons["Settings"]
        if !settingsButton.waitForExistence(timeout: 6) {
            let fallback = app.buttons["gear"].firstMatch
            XCTAssertTrue(fallback.waitForExistence(timeout: 3), "Settings button not found")
            fallback.tap()
        } else {
            settingsButton.tap()
        }

        let openClawRow = app.staticTexts["OpenClaw"].firstMatch
        XCTAssertTrue(openClawRow.waitForExistence(timeout: 6), "OpenClaw row not found in Settings")
        openClawRow.tap()

        let connectionHeader = app.staticTexts["Connection"].firstMatch
        XCTAssertTrue(connectionHeader.waitForExistence(timeout: 6), "OpenClaw connection section not visible")
        attachScreenshot(named: "openclaw_provider_config")

        let diagnosticsHeader = app.staticTexts["Diagnostics"].firstMatch
        if !diagnosticsHeader.isHittable {
            app.swipeUp()
            app.swipeUp()
        }

        XCTAssertTrue(diagnosticsHeader.waitForExistence(timeout: 5), "OpenClaw diagnostics section not found")
        attachScreenshot(named: "openclaw_diagnostics")
    }

    private func attachScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

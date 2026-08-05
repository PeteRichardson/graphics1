//
//  graphics1UITestsLaunchTests.swift
//  graphics1UITests
//
//  Created by Peter Richardson on 7/23/25.
//

import XCTest

/// Launch smoke test, run once per target application UI configuration.
///
/// As generated this asserted nothing at all — it launched the app and attached
/// a screenshot, which cannot fail. The screenshot is worth keeping (it is the
/// only visual record a CI run would leave behind), but it needs an assertion
/// beside it, so the app having launched into an unusable state is a failure
/// rather than a nice picture of one.
final class graphics1UITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.buttons["Center"].waitForExistence(timeout: 30),
            "the app launched but never presented its button bar"
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

//
//  graphics1UITests.swift
//  graphics1UITests
//
//  Created by Peter Richardson on 7/23/25.
//

import XCTest

/// UI-level coverage of the parts of the app no unit test can reach.
///
/// The ovals are drawn into a `Canvas`, so they have no accessibility
/// representation at all (#15): XCUITest cannot query them, read their
/// positions, or assert on them directly. Anything about the canvas therefore
/// has to be checked by comparing screenshots either side of an interaction.
/// That is coarse — it proves the canvas *redrew*, not what it drew — but it is
/// the only handle available, and it covers the whole input → state → render
/// path, which is exactly the stretch `graphics1Tests` cannot get at.
///
/// Two things make that comparison trustworthy, and both were arrived at by
/// watching a naive version pass when it should not have:
///
/// - **Screenshots are not deterministic.** Two taken back to back with nothing
///   happening in between differ — in PNG bytes, and in roughly 1,700 of 23.7
///   million raw bitmap bytes. Asserting `before != after` therefore passes no
///   matter what, and did: a mutant that dragged zero distance still passed.
///   So these compare the *magnitude* of the change against noise measured in
///   the same run, rather than testing for inequality.
/// - **The pointer is parked before every screenshot.** A cursor that moved
///   between two shots is itself a difference, which would swamp the signal.
final class graphics1UITests: XCTestCase {
    /// A change has to be this many times larger than the run's own measured
    /// noise floor to count. Generous: a moved or rotated oval shifts on the
    /// order of 1% of the frame, against a noise floor near 0.007%.
    private static let signalToNoise = 20.0

    /// ...and this large in absolute terms, so a run that happens to measure
    /// almost no noise cannot make a trivial difference look significant.
    private static let minimumChange = 0.001

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Launch, and don't return until the controls are actually up.
    @MainActor
    private func launchedApp(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(
            app.buttons["Center"].waitForExistence(timeout: 30),
            "the app launched but its button bar never appeared",
            file: file,
            line: line
        )
        return app
    }

    /// Raw bitmap bytes, so comparisons aren't at the mercy of PNG encoding.
    private func pixels(of screenshot: XCUIScreenshot) throws -> Data {
        let tiff = try XCTUnwrap(screenshot.image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let bytes = try XCTUnwrap(bitmap.bitmapData)
        return Data(bytes: bytes, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
    }

    /// Fraction of bytes that differ between two frames, 0...1.
    private func difference(_ a: Data, _ b: Data) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 1 }
        let differing = zip(a, b).lazy.filter { $0 != $1 }.count
        return Double(differing) / Double(a.count)
    }

    /// Assert `action` visibly changed the canvas.
    ///
    /// Takes two baseline frames first and uses the difference between *those*
    /// as the noise floor, so the threshold calibrates itself to whatever the
    /// machine and display are doing rather than to a constant that happened to
    /// work once. `parkPointer` runs before every capture.
    @MainActor
    private func assertCanvasChanges(
        by action: () -> Void,
        parkingPointerWith parkPointer: () -> Void,
        of app: XCUIApplication,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        parkPointer()
        let first = try pixels(of: app.screenshot())
        let second = try pixels(of: app.screenshot())
        let noise = difference(first, second)

        action()

        parkPointer()
        let afterwards = try pixels(of: app.screenshot())
        let change = difference(second, afterwards)

        let threshold = max(noise * Self.signalToNoise, Self.minimumChange)

        // Logged even on success. These thresholds are empirical, so when one
        // of these eventually goes flaky the margin it had is the first thing
        // worth knowing.
        print(String(
            format: "  [canvas] changed %.4f%%, noise floor %.4f%%, threshold %.4f%%",
            change * 100, noise * 100, threshold * 100
        ))

        XCTAssertGreaterThan(
            change, threshold,
            """
            \(message) \
            Changed \(String(format: "%.4f%%", change * 100)) of the frame; \
            needed more than \(String(format: "%.4f%%", threshold * 100)) \
            (noise floor \(String(format: "%.4f%%", noise * 100))).
            """,
            file: file,
            line: line
        )
    }

    // MARK: - Controls

    /// The bar buttons are the app's only accessible elements, so if the bar
    /// goes missing or stops being clickable nothing else here would notice.
    @MainActor
    func testTheButtonBarIsPresentAndClickable() {
        let app = launchedApp()

        for title in ["Random Color", "Rotate Left", "Rotate Right", "Center"] {
            let button = app.buttons[title]
            XCTAssertTrue(button.exists, "the \(title) button is missing")
            XCTAssertTrue(button.isHittable, "the \(title) button cannot be clicked")
        }
    }

    // MARK: - Canvas

    /// Rotating redraws the canvas — the button → state → render path.
    ///
    /// Rotation changes the rendering at all only because the shape is a
    /// 200×100 ellipse rather than a circle, and a single 15° step is a thin
    /// signal: measured at 0.28% of the frame against a 0.19% threshold, which
    /// is too close to trust. Three clicks sweep the silhouette through 45° and
    /// put the margin somewhere comfortable. If this ever goes flaky, add
    /// clicks rather than lowering the threshold.
    @MainActor
    func testRotatingRedrawsTheCanvas() throws {
        let app = launchedApp()
        let rotate = app.buttons["Rotate Right"]

        try assertCanvasChanges(
            by: {
                for _ in 0 ..< 3 {
                    rotate.click()
                }
            },
            parkingPointerWith: { rotate.hover() },
            of: app,
            "Rotating the selected oval did not visibly change the canvas."
        )
    }

    /// Dragging an oval moves it — the behaviour the whole app exists for, and
    /// the one thing no unit test can reach.
    ///
    /// "Center" is clicked first so the selected oval sits somewhere known
    /// whatever the window size: the middle of the canvas. The drag then starts
    /// from the middle of the *window* and still lands on it — the window frame
    /// includes the title bar, which offsets the two by far less than the
    /// oval's 50pt half-height.
    @MainActor
    func testDraggingAnOvalMovesIt() throws {
        let app = launchedApp()
        let center = app.buttons["Center"]
        center.click()

        let middle = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

        try assertCanvasChanges(
            by: {
                middle.press(
                    forDuration: 0.2,
                    thenDragTo: middle.withOffset(CGVector(dx: -140, dy: -70))
                )
                // Releasing flings the oval, so let friction bring it to rest
                // rather than capturing it mid-flight.
                Thread.sleep(forTimeInterval: 3)
            },
            parkingPointerWith: { center.hover() },
            of: app,
            "Dragging the centred oval did not visibly move it."
        )
    }
}

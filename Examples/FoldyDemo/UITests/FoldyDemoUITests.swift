import XCTest

final class FoldyDemoUITests: XCTestCase {
    /// Each transition example with text that exists only on its source, then only on its destination.
    private let examples: [(name: String, source: String, destination: String)] = [
        ("Wallet", "TAP TO RIDE", "Card Balance"),
        ("Weather", "Melbourne", "10-DAY FORECAST"),
        ("Blue Hour", "Album • 2026", "PLAYING FROM ALBUM"),
        ("Amalfi", "Add to plan", "Reserve"),
        ("Steps", "Activities", "Above Typical Friday"),
        ("Boarding pass", "PASSENGER", "Flight details")
    ]

    @MainActor
    func testEveryExampleOpensAndFoldsBack() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Open Wallet"].waitForExistence(timeout: 5))
        capture(app, name: "Gallery")
        app.buttons["Open Wallet"].tap()
        usleep(450_000)
        capture(app, name: "Gallery fold")
        XCTAssertTrue(app.buttons["Preview options"].waitForExistence(timeout: 6))
        app.buttons["Back to collection"].tap()
        XCTAssertTrue(app.buttons["Open Wallet"].waitForExistence(timeout: 6))
        for example in examples {
            open(example.name, in: app)
            XCTAssertTrue(app.staticTexts[example.source].waitForExistence(timeout: 3), "\(example.name) source")
            capture(app, name: example.name)
            play(app)
            XCTAssertTrue(app.staticTexts[example.destination].waitForExistence(timeout: 6),
                          "\(example.name) did not reach its destination")
            XCTAssertFalse(app.staticTexts[example.source].exists, "\(example.name) source must be hidden at the destination")
            capture(app, name: "\(example.name) destination")
            play(app)
            XCTAssertTrue(app.staticTexts[example.source].waitForExistence(timeout: 6),
                          "\(example.name) did not return to its source")
            app.buttons["Back to collection"].tap()
            XCTAssertTrue(app.buttons["Open \(example.name)"].waitForExistence(timeout: 6))
        }
    }

    @MainActor
    func testMusicRoundTripPreservesSavedState() {
        let app = XCUIApplication()
        app.launch()
        open("Blue Hour", in: app)
        app.buttons["Save album"].tap()
        XCTAssertTrue(app.buttons["Album saved"].exists)
        play(app)
        XCTAssertTrue(app.staticTexts["PLAYING FROM ALBUM"].waitForExistence(timeout: 6))
        capture(app, name: "Now playing")
        play(app)
        XCTAssertTrue(app.buttons["Album saved"].waitForExistence(timeout: 6))
    }

    @MainActor
    func testMidpointsAndSimulatorTilt() {
        let app = XCUIApplication()
        app.launch()
        open("Blue Hour", in: app)
        app.buttons["Preview options"].tap()
        app.buttons["Show midpoint"].tap()
        usleep(400_000)
        capture(app, name: "Midpoint page turn")
        XCTAssertFalse(app.buttons["Save album"].exists, "Content stays suspended during the fold")
        XCTAssertFalse(app.staticTexts["PLAYING FROM ALBUM"].exists)
        app.buttons["Preview options"].tap()
        app.buttons["Reveal"].tap()
        app.buttons["Show midpoint"].tap()
        usleep(400_000)
        capture(app, name: "Midpoint reveal")
        app.buttons["Preview options"].tap()
        app.switches["Tilt device"].coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Drag to tilt. On iPhone, move the device."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Play transition"].exists, "Tilt mode hides the playback panel")
        capture(app, name: "Tilt mode")
        app.buttons["Back to collection"].tap()
        XCTAssertTrue(app.buttons["Open Blue Hour"].waitForExistence(timeout: 6))
    }

    @MainActor
    func testDraggingTheScreenFoldsToTheDestination() {
        let app = XCUIApplication()
        app.launch()
        open("Weather", in: app)
        let surface = app.windows.firstMatch
        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(app.staticTexts["10-DAY FORECAST"].waitForExistence(timeout: 6))
        XCTAssertFalse(app.staticTexts["Melbourne"].exists)
        capture(app, name: "Forecast")
        // From the destination, a swipe in the opposite direction folds back to the source.
        let leftStart = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let leftEnd = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        leftStart.press(forDuration: 0.1, thenDragTo: leftEnd)
        XCTAssertTrue(app.staticTexts["Melbourne"].waitForExistence(timeout: 6))
        // And a vertical swipe from the source folds forward too.
        let upStart = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        let upEnd = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        upStart.press(forDuration: 0.1, thenDragTo: upEnd)
        XCTAssertTrue(app.staticTexts["10-DAY FORECAST"].waitForExistence(timeout: 6))
    }

    @MainActor
    func testDuoFoldsShutAndOpensAgain() {
        let app = XCUIApplication()
        app.launch()
        open("Duo", in: app)
        XCTAssertTrue(app.staticTexts["Good morning"].waitForExistence(timeout: 3))
        capture(app, name: "Duo")
        let slider = app.sliders["Fold progress"]
        slider.adjust(toNormalizedSliderPosition: 0.4)
        usleep(500_000)
        capture(app, name: "Duo folding")
        play(app)
        XCTAssertTrue(app.staticTexts["7:42"].waitForExistence(timeout: 6), "The cover display did not wake")
        XCTAssertFalse(app.staticTexts["Good morning"].exists, "The inner display must be gone when closed")
        capture(app, name: "Duo closed")
        play(app)
        XCTAssertTrue(app.staticTexts["Good morning"].waitForExistence(timeout: 6), "The display did not open again")
        // A swipe up closes it too.
        let surface = app.windows.firstMatch
        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(app.staticTexts["7:42"].waitForExistence(timeout: 6))
        app.buttons["Back to collection"].tap()
        XCTAssertTrue(app.buttons["Open Duo"].waitForExistence(timeout: 6))
    }

    @MainActor
    func testAtlasMovesThroughTheGridAndAppearancesSwitch() {
        let app = XCUIApplication()
        app.launch()
        open("Atlas", in: app)
        XCTAssertTrue(app.staticTexts["Amalfi"].waitForExistence(timeout: 3))
        capture(app, name: "Atlas")
        let surface = app.windows.firstMatch
        // Swipe left pages to the card on the right, folded around the right edge.
        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: surface.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)))
        usleep(300_000)
        capture(app, name: "Atlas folding")
        XCTAssertTrue(app.staticTexts["Positano"].waitForExistence(timeout: 6), "Did not page right")
        // Swipe up moves down a row.
        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            .press(forDuration: 0.05, thenDragTo: surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
        XCTAssertTrue(app.staticTexts["Atacama"].waitForExistence(timeout: 6), "Did not move down a row")
        // The appearance picker lives in the options and changes the glass for every fold.
        app.buttons["Preview options"].tap()
        app.buttons["Ink"].tap()
        app.buttons["Done"].tap()
        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: surface.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
        usleep(300_000)
        capture(app, name: "Atlas ink")
        XCTAssertTrue(app.staticTexts["Los Angeles"].waitForExistence(timeout: 6), "Did not page left")
        app.buttons["Back to collection"].tap()
        XCTAssertTrue(app.buttons["Open Atlas"].waitForExistence(timeout: 6))
    }

    @MainActor
    func testShowcasePlaysSixDemosAtOnce() {
        let app = XCUIApplication()
        app.launch()
        let button = app.buttons["Open showcase"]
        var attempts = 0
        while (!button.exists || !button.isHittable) && attempts < 8 {
            app.swipeUp(velocity: .slow)
            attempts += 1
        }
        XCTAssertTrue(button.isHittable, "Showcase entry is not on screen")
        button.tap()
        XCTAssertTrue(app.otherElements["showcase"].waitForExistence(timeout: 6))
        usleep(1_900_000)
        capture(app, name: "Showcase")
        usleep(1_200_000)
        capture(app, name: "Showcase later")
        app.buttons["Close showcase"].tap()
        XCTAssertTrue(app.buttons["Open Duo"].waitForExistence(timeout: 6))
    }

    @MainActor
    func testStoriesFoldIntoTheIsland() {
        let app = XCUIApplication()
        app.launch()
        open("Top stories", in: app)
        capture(app, name: "Top stories")
        let surface = app.windows.firstMatch
        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.86))
        let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.44))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.4)
        usleep(900_000)
        capture(app, name: "Top stories settled")
        // Bring the consumed card back from the island and let it settle into the list again.
        let back = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        let home = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        back.press(forDuration: 0.05, thenDragTo: home, withVelocity: .slow, thenHoldForDuration: 0.3)
        usleep(900_000)
        capture(app, name: "Top stories returned")
        // A flick: the pull runs on its own clock, so a frame right after release still shows it.
        let flickStart = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        let flickEnd = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        flickStart.press(forDuration: 0.01, thenDragTo: flickEnd, withVelocity: .fast, thenHoldForDuration: 0)
        capture(app, name: "Top stories flick")
        app.buttons["Back to collection"].tap()
        XCTAssertTrue(app.buttons["Open Top stories"].waitForExistence(timeout: 6))
    }

    @MainActor
    func testMomentsFoldIntoTheIsland() {
        let app = XCUIApplication()
        app.launch()
        open("Moments", in: app)
        capture(app, name: "Moments")
        let surface = app.windows.firstMatch
        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.86))
        let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.785))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.8)
        capture(app, name: "Moments folding")
        usleep(900_000)
        capture(app, name: "Moments settled")
        app.buttons["Back to collection"].tap()
        XCTAssertTrue(app.buttons["Open Moments"].waitForExistence(timeout: 6))
    }

    @MainActor
    func testReducedMotionShowsTheNearestEndpoint() {
        let app = XCUIApplication()
        app.launch()
        open("Wallet", in: app)
        app.buttons["Preview options"].tap()
        app.switches["Reduce motion"].coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        app.buttons["Show midpoint"].tap()
        // With motion reduced, a midpoint shows the nearer endpoint live instead of a frosted pane.
        XCTAssertTrue(app.staticTexts["Card Balance"].waitForExistence(timeout: 4))
    }

    @MainActor
    private func open(_ example: String, in app: XCUIApplication) {
        let button = app.buttons["Open \(example)"]
        // The gallery is taller than one screen; scroll until the card is on screen and hittable.
        var attempts = 0
        while (!button.exists || !button.isHittable) && attempts < 6 {
            app.swipeUp(velocity: .slow)
            attempts += 1
        }
        XCTAssertTrue(button.waitForExistence(timeout: 6), "Missing \(example)")
        XCTAssertTrue(button.isHittable, "\(example) is not on screen")
        button.tap()
        XCTAssertTrue(app.buttons["Preview options"].waitForExistence(timeout: 6), "\(example) did not open")
    }

    /// Plays the transition from the panel, whichever direction it currently faces.
    @MainActor
    private func play(_ app: XCUIApplication) {
        let forward = app.buttons["Play transition"]
        if forward.waitForExistence(timeout: 2) { forward.tap() } else { app.buttons["Play it back"].tap() }
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

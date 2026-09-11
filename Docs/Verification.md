# Local verification

September 11, 2026. Xcode 26.6, Swift 6 language mode, iPhone 17 Pro simulator running iOS 26.1.

## Results

- 36 tests passed: 26 state, capture, lifecycle, environment, motion, and GPU tests; 10 UI tests.
- The demo was installed and launched on a connected iPhone Air through `devicectl`.
- Debug simulator build passed as part of the test run.
- The reference clone remains unmodified at `be927684c8585ce3d90761095284329dfdeff901`.
- No commits, pushes, or GitHub changes were made. The project directory is not a git repository.

## What was checked

GPU tests load the package's compiled Metal resource and read rendered pixels.
They verify exact source/destination endpoints, a mixed midpoint in both choreographies, premultiplied transparency, vertical and diagonal tilt, and that a moved viewpoint changes the projection only when the pane is tilted.
An appearance test renders every material flat and tilted: all are identical to frosted at rest and each differs from frosted once tilted.
A ripple test confirms the liquid displacement changes a tilted render and leaves a flat one untouched.
The blur now samples a Gaussian-softened mip pyramid with one trilinear tap; the GPU tests use flat textures, so they exercise the projection and compositing, not the pyramid itself.
The pyramid was inspected visually in the gallery fold, the page-turn midpoint, and the feed ghosts: smooth frost, no speckle, and feathered snapshot edges.
Motion tests verify both axes, orientation mapping, neutral position, and finite angle sanitization.
The vertical axis now hinges on the edge the screen leans away from, matching the horizontal convention of the reference demo.

Container tests verify one capture per session, no GPU submissions at rest, recapture after returning to zero, and cancellation on resizing or removal.
They also cover supplied images, capture failure, unavailable Metal, Reduce Motion scrubbing, and motion remaining stopped on initialization.
A new assertion checks that the first frame of a session is immediate and later poses are drawn by the display link within a run-loop spin.

The environment test checks that an injected observable model and locale reach hosted SwiftUI content.
UI tests cover the Duo fold closing to its cover screen and opening again by Play and by swipe, Atlas paging right and down by swipe and again after switching the glass to Ink, all six transition examples opening through the root fold, playing to the destination and back from the options with content markers proving which screen is live,
an animated round trip with preserved saved state, midpoint interaction suspension in both choreographies, swipes in three directions folding forward and back through a UIKit pan on the fold container, the slider panel present on transitions and hidden in tilt mode,
Tilt device from the options, the Showcase page opening and running six folds at once, the story feed pulling a card into the island on a slow drag, the magnetic settle after release, a scroll back that returns the card, a flick through the feed, the photo grid pulling a row into the island,
and Reduce Motion showing the nearer endpoint live at a midpoint.

XCTest screenshots were visually inspected for the gallery, the gallery mid-fold, every source and destination screen, and page-turn frames at 12, 50, and 80 percent.
See [Gallery](Gallery.png), [GalleryFold](GalleryFold.png), [Stories](Stories.png), [StoriesFolding](StoriesFolding.png), [TiltMode](TiltMode.png),
[Wallet](Wallet.png), [Forecast](Forecast.png), [NowPlaying](NowPlaying.png), [Amalfi](Amalfi.png), [Steps](Steps.png), [BoardingPass](BoardingPass.png), and [Midpoint](Midpoint.png).

A simulator screen recording of the music round trip was inspected frame by frame at the start of the return fold.
The destination stays on screen until the pane covers it; no un-frosted source frame appears. The recording was made after the fix, so it verifies the current behavior rather than the original flicker.

Both feeds' pull into the island was verified from simulator screen recordings of their UI tests: items frost, shrink toward the pill, converge on its center, and slip under it, and on a flick they stream in one after another.
The return path was recorded too: a consumed card grows back out of the island into its place with no intermediate flash. An earlier build drew a returning card unfolded at its resting place for one frame before it folded, because its pull clock started at zero; the clock now starts complete for items returning from above.
See [StoriesFolding](StoriesFolding.png) and [MomentsFolding](MomentsFolding.png), frames from those recordings. XCTest screenshots land too late in a drag to catch the pull.

The Duo fold was inspected from a simulator screen recording of its UI test: the display creases at the seam, both halves lift and frost with the crease staying sharp between them, and the closed device fades in with its cover display. See [Duo](Duo.png), [DuoFolding](DuoFolding.png), and [DuoClosed](DuoClosed.png).

Bump detection integrates Core Motion user acceleration over a 160 ms window and fires on a 0.18 m/s velocity change; it cannot be exercised in the simulator or by XCTest. Atlas falls back to swipes there. A first hands-on check found the earlier single-sample, 0.55 g detector too hard to trigger; the integrated detector still needs a hands-on check.

## Landing page

`site/` is a single static page, published from the `main` branch root of the separate `foldy-landing` repository to https://tornikegomareli.github.io/foldy-landing/. The six demo clips were recorded on an iPhone Air, identified from contact sheets (the island clip was later re-recorded and replaced), and encoded to WebM and MP4 at 630 × 1368 with a poster frame each; four of them also became README GIFs under `Docs/clips/`. The page was rendered with headless Chrome at desktop width and inspected. Headless Chrome clamps its window to 500 px, so an apparent phone-width overflow in early renders was a capture artifact: a layout probe at that width showed `scrollWidth` equal to `clientWidth`, and a device-scale render at 390 px shows the single-column layout. Apple's description of the iPhone Duo transition is quoted verbatim from the newsroom announcement.

`site/social.html` is a local board for social posts: six phones in one viewport as two larger heroes over four, all clips started together, with keys to solo one phone, restart, or hide captions. Both rows are sized from whichever of width or height binds, so the board fills one recording frame. Rendered and inspected at 1920 × 1080.
The CSS phone frame was abandoned: percentage-based corners and an island drawn over the video proved wrong on screen twice. The frame is now an image drawn from the iPhone Air geometry (bezel 4.1 % and 4.6 % of the screen, 55 pt corners) and composited into each clip with ffmpeg by `Tools/frame-clip.sh`, so what the page shows is fixed in the file. The recordings already contain the island, so none is drawn. A composited frame was inspected at full size and at 3× on the corner. A hands-on look at the social board then showed the canvas's own square corners outside the rounded body; the canvas is now filled with the page color and cut to the body's silhouette, and a pixel read at the canvas corner returns the page color. That corner still read faintly darker on screen: YUV rounding puts it at (7,9,9) against a (9,9,11) page, and the page's drop-shadow filter followed the square video box. Both pages now clip the video to the body's corner radius with the shadow on that clipped box, so the canvas corners are never painted.
Earlier attempt, kept for the record: the phone frame on both pages followed the iPhone Air: a 156.2 × 74.7 mm body around the 2736 × 1260 screen from Apple's specifications. Pixel sampling of the recordings showed they are plain rectangles with no corner masking and no island, so the frame's screen box supplies both: 55 pt corners and the island at its simulator-measured position, drawn once, inside the screen. A first frame drew the island outside the screen box and cut the demo's top buttons with the corner; the demo now places those buttons below the island so future recordings read cleanly in a frame.

## On-device test run

The 22 package tests were also run on the connected iPhone Air with Xcode's device destination: snapshots are captured, frames are submitted, and no fallback is reported, so the Metal path works on hardware.
The UI test runner could not be installed there: the free provisioning profile allows three app identifiers per device and the runner would be the fourth.

## Library helpers

`foldSwipe`, `FoldPager`, and the `FoldCutout` family were lifted from the demo, which now uses them instead of its own copies. The swipe attaches a UIKit pan to the nearest fold container, or to the first UIKit ancestor when there is none, so content stays tappable; the pager and the feeds are exercised by the Atlas, Top stories, and Moments UI tests as before.
The Showcase page runs six Metal folds at once inside scaled phone frames; its UI test opens it and captures two frames a second apart.
Building it exposed a library defect: SwiftUI counter-scales a hosted view's layer resolution under `scaleEffect`, and the renderer let that multiply its drawable to 4204 × 9139 pixels for a 402 × 874 view, past the simulator's 8192 limit, so Metal aborted on the drawable's texture descriptor. The renderer now sets its drawable size from the capture scale and skips a frame whose drawable would be empty or oversized; a skipped frame is retried on the next update.

## Liquid pull

The Moments recording was inspected frame by frame around the pull: as a row nears the island, a black band appears at each tile's lifted edge, beads between the band and the island thicken into a tendril, and the pair merge into the pill as the panes fade. See [MomentsLiquid](MomentsLiquid.png).
A Top stories recording shows the island reacting: after a card is swallowed its outline ripples and rings down, and as the next card approaches a mouth bulges down to meet the tendril from the card's edge. See [StoriesLiquid](StoriesLiquid.png).
The return was recorded as well: the island's outline wobbles, the card is born from the mouth on a liquid tendril that thins as it descends, and it is clear and flat within about a third of a second. See [StoriesBirth](StoriesBirth.png).
A second hands-on pass reported a black line riding a card that had already left the island, and a stutter at the magnetic snap. The line was the goo band, which now only exists within 90 points of the island; the stutter was the snap targeting a rest position still inside the fold zone, which settled and immediately re-snapped. Snaps now land well clear of the zone, the timed pull is a spring, and a recording of the Stories drag shows 641 frames with no gap over 50 ms.
A hands-on pass on the phone found three geometry faults, all fixed and re-recorded: the black band outlived the card and hung under the island after the swallow; a card being born appeared above the island rather than out of it; and a card being swallowed rose above the pill's top edge. The view's top is now clamped to the pill's underside, the band and beads follow the view's own frame, and everything but the pill fades with the view. A first cut let the bridging beads keep their size with no gap left to bridge, which piled the beads, mouth, and band into one black slab under the island; the beads now scale with the gap.
A first version drew each tile's whole silhouette, which showed as a black rectangle through the transparent part of a folded pane; the silhouette is now only the lifted edge.

## Cutout geometry

The Dynamic Island and notch frames were measured on the iOS 26 simulator with `simctl io screenshot --mask=black`, scanning the top band for masked pixels, and paired with the safe-area inset logged by the app:
iPhone 17 and 17 Pro (402 × 874, inset 62) and 17 Pro Max (440 × 956, inset 62) show a 125.3 × 36.7 island at y 14; iPhone Air (420 × 912, inset 68) at y 20; iPhone 16e (390 × 844, inset 47) a 170.7 × 33.7 notch at y 0.
The island therefore sits 48 points above the inset on every measured phone, which is the rule the demo uses. Notch widths for older phones are approximated and were not measured.

## Remaining device checks

The feed's timed pull on a flick was not captured: XCTest screenshots land more than 0.7 seconds after the gesture, when the pull has finished.
The overlay ghost was verified mid-fold on a slow drag, and the flick test only checks that the feed survives it.

The package declares iOS 17 as its minimum. Runtime tests here used iOS 26.1; an iOS 17 runtime was not installed.
Physical-device energy use, sustained frame timing, motion direction and calibration, and sensor latency remain unmeasured.
Tilt lag reported on an iPhone Air was addressed twice: frames are paced by a display link with at most two in flight, and the per-pixel cost dropped from up to 32 disc taps to one trilinear tap of a precomputed pyramid. Both need a hands-on check.
The 120 Hz motion sampling, 40 ms prediction, and 0.7 smoothing are copied from the reference demo, not re-tuned on hardware.
Simulator checks do not establish exact fidelity to Apple's original animation.

## Reproduce

The README contains the command to run the suite from the included Xcode project.
Screenshots are attached to the UI test results; export them with `xcrun xcresulttool export attachments`.

## September 12, 2026: watchOS

- 34 unit and 10 UI tests passed on the iPhone 17 Pro simulator, including the new swipe-tracker, software-pose, and pane-direction tests.
- The package cross-compiled for the watchOS simulator with `swift build --triple arm64-apple-watchos10.0-simulator --sdk "$(xcrun --sdk watchsimulator --show-sdk-path)"`.
- No watchOS simulator run: the watchOS 26.5 platform is not installed on this machine.

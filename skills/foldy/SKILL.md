---
name: foldy
description: >-
  Build fold animations with the Foldy Swift package: fold one screen into
  another, tilt a view like frosted glass, swipe or page between views, pull
  rows into the Dynamic Island, or drive a fold from device motion. Use when
  the user mentions Foldy, a fold or page-turn transition, an iPhone Duo-style
  animation, or frosted-glass tilt in a SwiftUI, UIKit, or AppKit app.
license: MIT
---

# Foldy

Foldy folds views like frosted glass. One Metal shader keeps the interface on a fixed plane and
refracts it through a tilting pane. SwiftUI, UIKit, and AppKit; iOS 17+, macOS 14+, watchOS 10+.

Full reference: `Docs/Reference.md` in the package. Read it before touching capture, lifecycle,
`FoldStyle` optics, or motion sampling.

## Install

```swift
.package(url: "https://github.com/insanearts/foldy.git", from: "0.3.0")
```

Add `Foldy` to the target. The shader ships in the package; copy nothing.

## Pick the API

| Need | Use |
| --- | --- |
| Fold screen A into screen B | `FoldTransition(progress:)` with `progress` 0...1 |
| Tilt one view | `.foldEffect(angle:)` or `.foldEffect(tilt:)` |
| Swipe drives a fold | `.foldSwipe(progress: $progress)` on the transition |
| Page or grid of items | `FoldPager(items:columns:selection:)` |
| Rows melt into the Dynamic Island | `FoldCutout.detect` + `FoldCutoutGhost` + `FoldCutoutSnap` |
| Pane follows the phone | `FoldMotionSource` + `.foldEffect(tilt: motion.tilt)` |
| UIKit or AppKit view controllers | `FoldContainerView(source:destination:)` |

## Rules

- `progress` is the only driver. Zero shows the source, one the destination. Animate it with
  `withAnimation`; set it directly for an immediate switch.
- Give the fold an explicit frame. `FoldTransition` fills its proposed size; a card with no frame
  collapses.
- Keep both content closures stable during a fold. Commit navigation changes in
  `.onFoldEvent { .completed(.destination) }`, never mid-transition.
- Content is snapshotted for the fold and restored at an endpoint. Video, camera, and web views
  need a `sourceSnapshot` provider on `FoldContainerView`.
- Put interactive gestures on the container, not on the content. `foldSwipe` does this for you.
- Reduce Motion is honored by the system setting. Pass `reducesMotion: true` to opt in per view.
- Motion: call `motion.start()` when visible and active, `stop()` when not. Add
  `NSMotionUsageDescription` to the app.
- watchOS has no Metal. The same API draws with SwiftUI rotation and blur; `FoldContainerView`
  does not exist there.

## Style

`FoldStyle(appearance:)` picks the glass: `.frosted` (default), `.clear`, `.grain`, `.gloss`,
`.ink`, `.midnight`. `edge` is the hinge (`.left`, `.right`). `choreography` is `.reveal`
(source folds over a still destination) or `.pageTurn` (destination unfolds around the same hinge).
Two panes sharing one surface set `viewpoint` to the shared eye, e.g. `UnitPoint(x: 0.5, y: 1)` for
the top half of a display folded at its middle.

## Recipes

Two-screen fold with swipe and tap:

```swift
@State private var progress = 0.0

FoldTransition(progress: progress, style: FoldStyle(appearance: .midnight, choreography: .pageTurn)) {
    ListScreen()
} destination: {
    DetailScreen()
}
.foldSwipe(progress: $progress)
.onTapGesture { withAnimation(.easeInOut(duration: 0.8)) { progress = 1 } }
.onFoldEvent { if case .completed(.destination) = $0 { /* commit navigation */ } }
```

Grid paged by swipe and nudge:

```swift
@State private var index = 0
@State private var motion = FoldMotionSource()

FoldPager(items: places, columns: 3, selection: $index, motion: motion) { PlaceCard($0) }
```

Dynamic Island pull for a scrolling list (see `Examples/FoldyDemo/Sources/StoriesScene.swift`):

```swift
let cutout = FoldCutout.detect(safeAreaTop: insets.top, screenWidth: width) ?? .placeholder(screenWidth: width)
// Hide the row once it crosses the fold line and draw the ghost in its place.
FoldCutoutGhost(startsFolded: false, scroll: pull, start: rowFrame, target: cutout.frame, liquid: true) { Row() }
// Keep the scroll from resting half inside the cutout.
.scrollTargetBehavior(FoldCutoutSnap(firstRowTop: top, period: rowHeight + spacing, rows: count,
                                     foldStart: cutout.frame.maxY + 120, eaten: cutout.frame.maxY))
```

UIKit or AppKit:

```swift
let fold = FoldContainerView(source: firstView, destination: secondView)
fold.style = FoldStyle(appearance: .gloss)
fold.animate(to: .destination)      // timed
fold.setProgress(0.4)               // interactive
fold.onEvent = { event in print(event) }
```

## Verify

Run the fold on a simulator or device and watch for `.fallback(...)` in `onFoldEvent`:
`captureFailed` means the view had no size or a surface that cannot be captured,
`metalUnavailable` means no GPU, `reduceMotion` means the setting is on.

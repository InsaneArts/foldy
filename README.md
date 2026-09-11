<p align="center">
  <h1 align="center">Foldy</h1>
</p>

<p align="center">Animate any view with Apple Duo-like fold animation.</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6-orange.svg" />
  <img src="https://img.shields.io/badge/iOS-17.0+-blue.svg" />
  <img src="https://img.shields.io/badge/SwiftUI%20%2B%20UIKit-Native-green.svg" />
  <img src="https://img.shields.io/badge/Metal-Shader-lightgrey.svg" />
</p>

## Showcase

https://github.com/user-attachments/assets/7a972fe0-2a78-4dad-b1cd-93d7598c6062

## Inspiration

On September 9, 2026 Apple unveiled [iPhone Duo](https://www.apple.com/iphone-duo/), its first foldable iPhone. When the phone opens or closes, iOS does not cut between the cover and inner displays. The interface frosts, blurs, and stretches through the moving half of the screen, driven by the hinge angle, so the change feels continuous. Apple describes a display engine that drives both screens during the transition in its [announcement](https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/).

Foldy is an independent recreation of that look for any iOS view. A Metal shader keeps the interface on a fixed plane and refracts it through a tilting pane of frosted glass. It is not Apple's implementation and needs no folding hardware.

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/tornikegomareli/Foldy.git", from: "0.1.0")
]
```

Or via Xcode: **File → Add Package Dependencies**. The Metal shader ships in the package resource bundle; nothing needs to be copied into your app.

## Quick Start

Fold one screen into another. Zero shows the source, one the destination:

```swift
import SwiftUI
import Foldy

struct Example: View {
    @State private var progress = 0.0

    var body: some View {
        FoldTransition(progress: progress) {
            FirstScreen()
        } destination: {
            SecondScreen()
        }
        .foldSwipe(progress: $progress)
        .onTapGesture { withAnimation(.easeInOut(duration: 0.8)) { progress = 1 } }
    }
}
```

`foldSwipe` lets a swipe in any direction drive the fold and settle on the nearer endpoint. Content stays tappable.

Or tilt a single view like a pane of frosted glass:

```swift
Card().foldEffect(angle: .degrees(30))
```

## What's in the box

| | |
| --- | --- |
| `FoldTransition` | Fold between two SwiftUI views; both keep their state |
| `.foldEffect(angle:)` / `.foldEffect(tilt:)` | Tilt one view on one or two axes |
| `.foldSwipe(progress:)` | Drive any fold with a swipe |
| `FoldPager` | Page or grid-navigate a list of items with page turns |
| `FoldCutoutPull`, `FoldCutoutGhost`, `FoldCutoutSnap` | Pull rows into the Dynamic Island as they scroll |
| `FoldMotionSource` | Device tilt and nudge detection |
| `FoldStyle` and `FoldAppearance` | Hinge, optics, choreography, and six glass materials |
| `FoldContainerView` | The UIKit core |

## Glass materials

Six appearances: `.frosted` (default), `.clear`, `.grain`, `.gloss`, `.ink`, and `.midnight`. Every one is invisible at rest.

```swift
FoldTransition(progress: progress, style: FoldStyle(appearance: .midnight)) {
    FirstScreen()
} destination: {
    SecondScreen()
}
```

`FoldStyle` also picks the hinge edge and the choreography: `.reveal` folds the source away over a stationary destination, `.pageTurn` unfolds the destination around the same hinge.

## Paging

```swift
@State private var index = 0

FoldPager(items: places, columns: 3, selection: $index) { place in
    PlaceCard(place)
}
```

A swipe turns to the next or previous item. Hand it a `FoldMotionSource` and a nudge of the phone turns the page too.

## Dynamic Island

`FoldCutout.detect` returns the island frame. `FoldCutoutPull` folds a view from where it is into that frame:

```swift
let cutout = FoldCutout.detect(safeAreaTop: insets.top, screenWidth: width) ?? .placeholder(screenWidth: width)

card.modifier(FoldCutoutPull(progress: pull, start: cardFrame, target: cutout.frame))
```

Pass `liquid: true` and the view is swallowed like liquid: the glass ripples, the edge dissolves into black goo, and the island bulges to meet it. The demo's story feed and photo grid show the full scrolling pattern.

## UIKit

```swift
let fold = FoldContainerView(source: firstView, destination: secondView)
view.addSubview(fold)
fold.frame = view.bounds

fold.animate(to: .destination)
// Or drive an interactive gesture:
fold.setProgress(0.4)
```

Use `FoldContainerView(content:)` with `setAngle(_:)` or `setTilt(_:)` for a single view.

## Reduce Motion

The system setting skips capture and GPU rendering and shows the nearest endpoint. You can also opt in with `reducesMotion: true`.

## Example app

Open `Examples/FoldyDemo/FoldyDemo.xcodeproj`. It ships ten screens recreated from familiar apps: a Duo-style folding display, a nudge-to-page atlas, two feeds that melt into the Dynamic Island, six two-screen transitions, and a showcase of all of them at once. Select your own team under Signing & Capabilities for a device run.

Everything about capture, lifecycle, motion sampling, and the style parameters is in the [full reference](Docs/Reference.md).

## Requirements

- iOS 17+
- Swift 6, Xcode 16 or later
- The simulator runs every fold; physical tilt and nudges need a device

## License

MIT. See [LICENSE](LICENSE).

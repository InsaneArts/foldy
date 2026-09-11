# Foldy: research and proposed package design

Date: September 10, 2026. Status: original research and proposal.
The local implementation now exists. See [README](../README.md) for its actual API and supported behavior.

## Recommendation

Build an iOS-first Swift package named `Foldy`, with a Metal renderer and thin SwiftUI and UIKit adapters.
Reuse the demo's projection and frosted-glass math. Replace its app-specific capture, motion ownership, and lifecycle assumptions.
Use snapshots for finite transitions between arbitrary capturable views. Keep continuous motion effects separate from screen replacement.

Proposed baseline: iOS 17+, Swift 6 language mode, no external dependencies. This baseline is a design choice, not a verified compatibility result.
The reference app targets iOS 26.5 and uses Swift 5 language mode.

## What Apple announced

Apple introduced iPhone Duo, its first foldable iPhone, on September 9, 2026. It was announced yesterday, not released for sale yesterday.
Apple lists October 23 availability. Its outer and inner displays share an aspect ratio, and the interface adapts during folding.
Apple describes a display engine that drives both displays during transitions. [Apple announcement](https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/)

The relevant effect gives content apparent depth during the change between displays.
For this package, the useful visual reference is a pane of frosted glass moving above a stationary interface.
Perspective changes across the pane, and content gets blurrier and darker farther from the hinge.
This is the reference demo's mathematical interpretation. Apple's sources reviewed here do not disclose its shader or exact optical model.
The demo screenshot was inspected; a frame-by-frame comparison with Apple's animation was not performed.

Apple's device experience also includes layout changes and coordination between physical displays.
Foldy would recreate the visual effect inside an app. It would not provide Apple's system-level display handoff.
[Apple product page](https://www.apple.com/iphone-duo/)

## Repository audit

Cloned repository: `Reference/DuoLikeAnimation`.
Revision: `be927684c8585ce3d90761095284329dfdeff901`.
The clone remains unmodified.

| File | Verified behavior | Package implication |
| --- | --- | --- |
| `FoldEffect.swift` | Composites content and calls a Metal shader through SwiftUI `layerEffect` | Already GPU shading; SwiftUI and Metal work together |
| `Shaders/DuoFold.metal` | Projects each output pixel onto a fixed UI plane; applies 6–32 blur samples and darkening | Reuse the visual model in a texture-based Metal fragment function |
| `FoldMotionModel.swift` | Requests 120 Hz Core Motion updates, calibrates orientation, smooths tilt, predicts 40 ms ahead | Separate optional input from rendering |
| `ContentView.swift` | Owns motion, full-screen bounds, safe areas, manual controls | Keep demonstration UI outside the package |
| `LICENSE` | MIT, copyright 2026 Elijah Semyonov | Retain the copyright and full license with reused code |
| Test targets | Empty unit test, launch smoke test, launch performance test | No assertions establish effect correctness |

The source shader is at [the pinned revision](https://github.com/elijah-semyonov/DuoLikeAnimation/blob/be927684c8585ce3d90761095284329dfdeff901/DuoLikeAnimation/Shaders/DuoFold.metal).
License text: [upstream MIT license](https://github.com/elijah-semyonov/DuoLikeAnimation/blob/be927684c8585ce3d90761095284329dfdeff901/LICENSE).

The demo tilts one view. It does not implement source/destination transitions, completion, cancellation, or navigation integration.

### Changes needed before reuse

- The shader always outputs alpha 1 and fills misses with black. Add premultiplied transparency for cards and overlays; preserve black as an explicit style.
- `maxSampleOffset` is zero despite displaced sampling and blur. If retaining the SwiftUI path, calculate a conservative bound and test clipping.
- A plain `ViewModifier` does not define explicit interpolation for its angle. A live SwiftUI adapter needs an animatable angle contract.
- The shader uses phone-oriented viewing-distance defaults. Define geometry relative to local view size for reusable cards and screens.
- The motion model selects the first connected window scene. Inject the owning view's orientation instead.
- Manual mode still permits sensor updates. Stop sensors when unused, inactive, or hidden.
- Rotation convention detection can change after reference capture. Replace the heuristic with a tested convention or recalibrate when it changes.
- Validate finite angles, dimensions, and optical parameters before uploading uniforms. Clamp supported tilt before the projection approaches a singularity.
- Add Reduce Motion behavior and explicit ownership of interaction during the effect.

The sampling bound and interpolation observations are source-level findings. Their visible failure cases have not been reproduced on a device.

## Why Metal does not mean automatic battery savings

The expensive pixel work already runs in Metal. Replacing the SwiftUI host alone does not establish lower CPU use or energy use.
The shader can sample the input 32 times per output pixel. Resolution, blur, redraw frequency, and capture costs will affect performance.

An explicit renderer gives us control over texture reuse and frame scheduling.
Capture once per transition, upload once, update small uniforms, and stop drawing when settled.
Apple documents timed and explicit drawing modes for [MTKView](https://developer.apple.com/documentation/metalkit/mtkview).

Keep the current shader as the visual baseline. Evaluate downsampled blur or precomputed sampling offsets only after profiling shows a need.
Do not claim energy savings until equivalent scenes and animation sequences are measured on physical iPhones.

## The boundary of “any view”

Metal shades textures; it cannot directly sample an arbitrary live UIKit view hierarchy.
Apple warns that UIKit/AppKit-backed views may not render into a SwiftUI shader layer.
[Apple layerEffect documentation](https://developer.apple.com/documentation/swiftui/view/layereffect(_:maxsampleoffset:isenabled:))

`ImageRenderer` also excludes native framework content such as web views, media players, and some controls.
It cannot be the universal capture implementation. [Apple ImageRenderer documentation](https://developer.apple.com/documentation/swiftui/imagerenderer)

| Content | Proposed support | Contract |
| --- | --- | --- |
| SwiftUI layouts and ordinary UIKit views | Capture hosted/attached hierarchy into a texture | Frozen visual content during a finite transition |
| Lists and scroll views | Capture current visible viewport | No promise to capture offscreen rows |
| Web views | Caller-supplied snapshot when generic capture is insufficient | Asynchronous preparation must finish before animation |
| Video, camera, custom Metal content | Caller-supplied image in initial release | No universal live capture claim |
| Protected content | Caller-provided placeholder or ordinary transition | Do not attempt capture workarounds |

Prototype hierarchy capture with `UIGraphicsImageRenderer` and `drawHierarchy(in:afterScreenUpdates:)`.
Treat incomplete capture as failure, and offer a caller-supplied image because successful drawing cannot prove every embedded surface was captured.
[Apple hierarchy capture API](https://developer.apple.com/documentation/uikit/uiview/drawhierarchy(in:afterscreenupdates:))

During a snapshot transition, underlying model updates may continue, but the displayed texture stays frozen.
Keep the real destination hierarchy alive and reveal it at completion. Do not duplicate view state by rebuilding a detached screen for every frame.
Input is suspended inside the animated region, except for the gesture controlling transition progress.
Continuous transformed hit testing is outside the initial contract.

## Architecture and package layout

Use a small transition state machine with a Metal renderer and platform adapters.
This applies the deterministic-state part of MVI without introducing a generic store or an app architecture framework.

```text
Package.swift                  # one Foldy library product and target
Sources/Foldy/
  FoldStyle.swift              # optics, edge and background behavior
  FoldTransitionState.swift   # pure state and progress rules
  FoldTransitionSession.swift # main-actor lifecycle and cancellation
  Rendering/
    FoldRenderer.swift        # device, pipeline, textures and frame submission
    FoldUniforms.swift        # explicit Swift/Metal memory layout
    Shaders/Fold.metal        # adapted projection and blur
  UIKit/
    FoldCapture.swift         # view -> image; explicit failure
    FoldContainerView.swift   # source/destination ownership and Metal overlay
  SwiftUI/
    FoldTransition.swift      # source/destination container adapter
  Motion/
    FoldMotionSource.swift    # optional calibrated angle input
Tests/FoldyTests/             # state, geometry, interruption and parameter tests
Examples/FoldyDemo/           # SwiftUI/UIKit fixtures and comparison controls
ThirdPartyNotices.md          # full upstream MIT notice and pinned provenance
```

Bundle the Metal shader as a package resource and resolve its library from `Bundle.module`.
Verify shader compilation and bundle loading through a separate consuming iOS app before declaring package support.
Keep Metal details internal. Keep motion opt-in, without starting sensors on import or initialization.

State flow: `idle -> preparing -> active -> settling -> idle`.
The caller owns source/destination identity. The session owns temporary images, progress, and completion delivery.
Use transition identifiers to discard late capture results after cancellation or replacement.
Keep UIKit capture and hierarchy changes on the main actor. Serialize renderer resource access with no UI access from GPU callbacks.
Release textures only when submitted GPU work no longer needs them.

Completion commits the destination; cancellation restores the source. Deliver one terminal outcome per session.
On resize or backgrounding, cancel to the source and release temporary state. Callers can start again after layout stabilizes.
If Metal or capture is unavailable, reveal the requested destination without the fold effect and report fallback.
With Reduce Motion, use an immediate replacement and keep sensor input off.

### Proposed public usage

These examples are API proposals, not compiled library code.

```swift
FoldTransition(progress: progress, edge: .trailing) {
    CurrentScreen()
} destination: {
    NextScreen()
}
```

`progress` is normalized: 0 shows the source and 1 shows the destination.
Both closures retain stable identity within the container. A gesture or explicit animation updates progress.
The container exposes completion/cancellation so callers can commit navigation state after the animation.
UIKit gets the same behavior through `FoldContainerView`, which hosts real source and destination views.
Initial support is explicit containment; automatic interception of navigation stacks and system sheets is deferred.

A single-view tilt uses a separate angle-based entry point. It must document whether its content is a snapshot or a live shader layer.
Do not map a signed angle to navigation progress implicitly.

For two-screen transitions, the initial visual candidate folds the outgoing texture away while revealing the incoming texture underneath.
Progress drives the outgoing angle and reveal coverage; incoming content stays stationary.
Endpoints must display the original source and destination without a shader seam.
This choreography extends the demo and requires visual review; it is not verified Apple behavior.

## Verification and release gates

Completed during research:

- Read Swift and Metal implementations, composition, test targets, project settings, and MIT license.
- Inspected the included demonstration image.
- Built the unmodified demo with Xcode 26.6 for iOS Simulator 26.5. Result: `BUILD SUCCEEDED`.
- Confirmed the reference checkout has no changes.

Build command:

```sh
xcodebuild -project Reference/DuoLikeAnimation/DuoLikeAnimation.xcodeproj \
  -scheme DuoLikeAnimation -sdk iphonesimulator -configuration Debug \
  -derivedDataPath /tmp/Foldy-DuoLikeAnimation-build CODE_SIGNING_ALLOWED=NO build
```

The app was not launched. Device motion, frame rate, energy use, and visual equivalence remain unverified.
The existing tests were not run because they do not assert rendering behavior.

Implementation acceptance checks:

- Verify source/destination endpoints, interrupted preparation, reverse progress, cancellation, and one-time completion.
- Compare captured output at fixed angles with the upstream shader, including transparent cards and both hinge edges.
- Exercise SwiftUI text, scrolling lists, UIKit controls, safe areas, rotation, and caller-supplied images in a consuming app.
- Verify Reduce Motion, hidden/background lifecycle, failed capture, and unavailable Metal paths.
- Measure capture latency, CPU/GPU frame time, peak texture memory, and energy against the demo on physical devices.
- Check 60 Hz and 120 Hz frame deadlines separately; these are total frame budgets, not exclusive shader budgets.
- Require no Foldy frame submissions or motion updates while idle.
- Confirm the shader resource ships and loads from the installed package; preserve the MIT notice in distribution.

macOS can follow after iOS capture and lifecycle behavior are stable.
Reuse projection math, state, and Metal rendering; add AppKit capture and hosting. No macOS support claim in the first release.

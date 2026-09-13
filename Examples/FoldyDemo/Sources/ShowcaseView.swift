import SwiftUI
import Foldy

/// Six demos playing at once in phone frames, for one screenshot or screen recording.
/// Every tile loops on its own clock with a different phase, so the frame is never still.
struct ShowcaseView: View {
    let close: () -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color(hex: 0x09090B).ignoresSafeArea()
                VStack(spacing: 18) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.stack.3d.up.fill").font(.system(size: 18, weight: .semibold))
                            .rotationEffect(.degrees(-12)).foregroundStyle(GalleryPalette.accent)
                        Text("foldy").font(.system(size: 26, weight: .semibold, design: .rounded))
                        Spacer()
                        Text("SWIFT + METAL · iOS 17+").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.4)
                            .foregroundStyle(GalleryPalette.muted)
                    }
                    .foregroundStyle(GalleryPalette.ink)
                    LazyVGrid(columns: columns, spacing: 16) {
                        PhoneTile(title: "Fold it shut") { DuoLoop() }
                        PhoneTile(title: "Page turn") { TransitionLoop(example: .wallet, appearance: .frosted, phase: 0.4) }
                        PhoneTile(title: "Into the island") { IslandLoop() }
                        PhoneTile(title: "Nudge to move") { PagerLoop() }
                        PhoneTile(title: "Gloss") { TransitionLoop(example: .weather, appearance: .gloss, phase: 0.8) }
                        PhoneTile(title: "Tilt device") { TiltLoop() }
                    }
                    HStack {
                        Text("Fold anything.").font(.system(size: 15, weight: .regular, design: .serif))
                        Spacer()
                        Text("github.com/insanearts/foldy").font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundStyle(GalleryPalette.muted)
                }
                .padding(.horizontal, 16).padding(.top, proxy.safeAreaInsets.top + 10)
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 30).background(.white.opacity(0.1), in: .circle)
                }
                .buttonStyle(.plain).foregroundStyle(.white)
                .accessibilityLabel("Close showcase")
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 18).padding(.top, proxy.safeAreaInsets.top + 44)
                .opacity(0.001) // Present for tests and taps; invisible in the recording.
            }
            .ignoresSafeArea()
        }
        .statusBarHidden()
        .accessibilityIdentifier("showcase")
    }
}

private let phoneReference = CGSize(width: 402, height: 874)

/// A phone frame around a full-size scene, scaled to the tile.
private struct PhoneTile<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let scale = max(proxy.size.width, 1) / phoneReference.width
                content
                    // Anchor at the top: a scene taller than the frame would otherwise be centered.
                    .frame(width: phoneReference.width, height: phoneReference.height, alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
                    .overlay(alignment: .top) {
                        Capsule().fill(.black).frame(width: FoldCutout.islandSize.width, height: FoldCutout.islandSize.height)
                            .padding(.top, 14)
                    }
                    .scaleEffect(scale, anchor: .topLeading)
            }
            .aspectRatio(phoneReference.width / phoneReference.height, contentMode: .fit)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1.2))
            .shadow(color: .black.opacity(0.6), radius: 12, y: 6)
            Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(GalleryPalette.muted)
        }
        .allowsHitTesting(false)
    }
}

/// Drives a value back and forth between two rests. Each loop starts at its own phase.
@MainActor
private enum Loop {
    static func run(phase: Double, period: TimeInterval, _ tick: @escaping @MainActor (Double) -> Void) -> Task<Void, Never> {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(phase * 1000)))
            while !Task.isCancelled {
                tick(1)
                try? await Task.sleep(for: .seconds(period))
                tick(0)
                try? await Task.sleep(for: .seconds(period))
            }
        }
    }
}

private let showcaseInsets = EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0)

private struct DuoLoop: View {
    @State private var progress = 0.0
    @State private var task: Task<Void, Never>?
    var body: some View {
        DuoStage(progress: progress, size: CGSize(width: 402, height: 874), insets: showcaseInsets, reduceMotion: false)
            .onAppear { task = Loop.run(phase: 0, period: 2.2) { value in withAnimation(.easeInOut(duration: 1.4)) { progress = value } } }
            .onDisappear { task?.cancel() }
    }
}

private struct TransitionLoop: View {
    let example: DemoExample
    let appearance: FoldAppearance
    let phase: Double
    @State private var progress = 0.0
    @State private var task: Task<Void, Never>?
    var body: some View {
        FoldTransition(progress: progress, style: FoldStyle(appearance: appearance, choreography: .pageTurn)) {
            ExampleScene(example: example, destination: false, insets: showcaseInsets)
        } destination: {
            ExampleScene(example: example, destination: true, insets: showcaseInsets)
        }
        .onAppear { task = Loop.run(phase: phase, period: 2.4) { value in withAnimation(.easeInOut(duration: 1.3)) { progress = value } } }
        .onDisappear { task?.cancel() }
    }
}

/// One story card pulled into the island and released, over the light feed.
private struct IslandLoop: View {
    @State private var pull = 0.0
    /// The source card stays hidden for the whole loop; the model value alone is zero too early on the way back.
    @State private var hidesSource = false
    @State private var task: Task<Void, Never>?
    private let cutout = FoldCutout.placeholder(screenWidth: 402)
    var body: some View {
        ZStack(alignment: .topLeading) {
            StoriesScene(insets: showcaseInsets, hiddenStory: hidesSource ? 0 : nil)
            StoryCard(story: Stories.all[0])
                .modifier(FoldCutoutPull(progress: pull,
                                         start: CGRect(x: 20, y: showcaseInsets.top + 6 + StoriesHeader.height + 18,
                                                       width: 362, height: StoryCard.height),
                                         target: CGRect(x: cutout.frame.minX, y: 14, width: cutout.frame.width, height: cutout.frame.height),
                                         liquid: true))
        }
        .onAppear {
            task = Loop.run(phase: 1.1, period: 2.0) { value in
                if value > 0 { hidesSource = true }
                withAnimation(.easeInOut(duration: 1.1)) { pull = value }
                if value == 0 {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(1150))
                        if pull == 0 { hidesSource = false }
                    }
                }
            }
        }
        .onDisappear { task?.cancel() }
    }
}

private struct PagerLoop: View {
    @State private var selection = 0
    @State private var task: Task<Void, Never>?
    var body: some View {
        FoldPager(items: Atlas.places, columns: Atlas.columns, selection: $selection, style: FoldStyle(appearance: .frosted)) { place in
            PlaceCard(place: place, insets: showcaseInsets)
        }
        .overlay(alignment: .top) { AtlasCompass(row: selection / Atlas.columns, column: selection % Atlas.columns, insets: showcaseInsets) }
        .onAppear {
            task = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                let route = [1, 2, 5, 4, 3, 0]
                var step = 0
                while !Task.isCancelled {
                    selection = route[step % route.count]
                    step += 1
                    try? await Task.sleep(for: .seconds(2.6))
                }
            }
        }
        .onDisappear { task?.cancel() }
    }
}

/// A slow figure-eight tilt, the way a hand moves, with the grain glass.
private struct TiltLoop: View {
    @State private var tilt = FoldTilt.zero
    @State private var task: Task<Void, Never>?
    var body: some View {
        ExampleScene(example: .travel, destination: false, insets: showcaseInsets)
            .foldEffect(tilt: tilt, style: FoldStyle(appearance: .grain))
            .onAppear {
                task = Task { @MainActor in
                    let start = Date()
                    while !Task.isCancelled {
                        let t = Date().timeIntervalSince(start)
                        tilt = FoldTilt(horizontal: 0.42 * sin(t * 1.1), vertical: 0.22 * sin(t * 2.2))
                        try? await Task.sleep(for: .milliseconds(16))
                    }
                }
            }
            .onDisappear { task?.cancel() }
    }
}

import SwiftUI
import Foldy

/// One full-screen experience. Two-screen examples fold with a swipe, the slider, or Play.
/// Tilt device lives in the options and turns the page into a sensor-driven surface.
struct ExperienceView: View {
    let example: DemoExample
    let close: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var progress = 0.0
    @State private var deviceMode = false
    @State private var manualTilt = FoldTilt.zero
    @State private var motion = FoldMotionSource()
    @State private var showsOptions = false
    @State private var reduceMotion = false
    @State private var edge = FoldEdge.right
    @State private var choreography = FoldChoreography.pageTurn
    @State private var appearance = FoldAppearance.frosted

    private var isFeed: Bool { example.isFeed }
    private var isDuo: Bool { example == .duo }
    private var isAtlas: Bool { example == .atlas }
    private var showsPanel: Bool { !isFeed && !isAtlas && !deviceMode }
    /// The style every fold on this page uses.
    private var style: FoldStyle {
        FoldStyle(appearance: appearance, edge: edge, choreography: choreography)
    }
    private var showsSimulatorPad: Bool { deviceMode && !motion.isAvailable }
    private var reducesMotion: Bool { reduceMotion || systemReduceMotion }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                artwork(proxy)
                    .ignoresSafeArea()
                    .accessibilityIdentifier("artwork")

                VStack(spacing: 0) {
                    HStack {
                        RoundButton(symbol: "arrow.left", label: "Back to collection") { motion.stop(); close() }
                        Spacer()
                        RoundButton(symbol: "slider.horizontal.3", label: "Preview options") { showsOptions = true }
                    }
                    // Below the Dynamic Island, so recordings framed as a phone do not clip the buttons.
                    .padding(.horizontal, 20).padding(.top, proxy.safeAreaInsets.top + 4)
                    Spacer()
                    if showsPanel {
                        controlPanel
                            .padding(.horizontal, 16)
                            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 16))
                    } else if showsSimulatorPad {
                        simulatorPad
                            .padding(.horizontal, 16)
                            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 16))
                    }
                }
                .ignoresSafeArea()
            }
        }
        .background(.black)
        .statusBarHidden()
        .background { SceneOrientationReader { motion.orientation = $0 } }
        .onChange(of: deviceMode) { syncMotion() }
        .onChange(of: scenePhase) { syncMotion() }
        .onChange(of: systemReduceMotion) { syncMotion() }
        .onChange(of: reduceMotion) { syncMotion() }
        .onChange(of: showsOptions) { syncMotion() }
        .onDisappear { motion.stop() }
        .sheet(isPresented: $showsOptions) { options }
    }

    @ViewBuilder private func artwork(_ proxy: GeometryProxy) -> some View {
        if example.isFeed {
            let cutout = FoldCutout.detect(safeAreaTop: proxy.safeAreaInsets.top, screenWidth: proxy.size.width)
                ?? .placeholder(screenWidth: proxy.size.width)
            if example == .stories {
                StoriesFeed(topInset: proxy.safeAreaInsets.top, size: proxy.size, cutout: cutout, reduceMotion: reducesMotion)
            } else {
                MomentsFeed(topInset: proxy.safeAreaInsets.top, size: proxy.size, cutout: cutout, reduceMotion: reducesMotion)
            }
        } else if isAtlas {
            let full = CGSize(width: proxy.size.width,
                              height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
            AtlasStage(size: full, insets: sceneInsets(proxy), motion: motion, style: style, reduceMotion: reducesMotion)
                .offset(y: -proxy.safeAreaInsets.top)
        } else if isDuo {
            let full = CGSize(width: proxy.size.width,
                              height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
            DuoStage(progress: progress, size: full, insets: sceneInsets(proxy), style: style, reduceMotion: reducesMotion)
                .offset(y: -proxy.safeAreaInsets.top)
                .foldSwipe(progress: $progress, placement: .surface)
        } else if deviceMode {
            MotionArtwork(example: example, motion: motion, manualTilt: manualTilt, style: style,
                          reduceMotion: reducesMotion, insets: sceneInsets(proxy))
                .onTapGesture(count: 2) { motion.recalibrate() }
        } else {
            FoldTransition(progress: progress, style: style, reducesMotion: reduceMotion) {
                ExampleScene(example: example, destination: false, insets: sceneInsets(proxy))
            } destination: {
                ExampleScene(example: example, destination: true, insets: sceneInsets(proxy))
            }
            .foldSwipe(progress: $progress)
        }
    }

    private var panelHeight: CGFloat {
        if showsPanel { return 96 }
        if showsSimulatorPad { return 122 }
        return 0
    }

    private func sceneInsets(_ proxy: GeometryProxy) -> EdgeInsets {
        let bottom = max(proxy.safeAreaInsets.bottom, 16)
        return EdgeInsets(top: proxy.safeAreaInsets.top + 52, leading: 0,
                          bottom: bottom + panelHeight + (panelHeight > 0 ? 14 : 4), trailing: 0)
    }

    // MARK: Controls

    private var controlPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Slider(value: $progress, in: 0...1).tint(GalleryPalette.accent)
                    .accessibilityLabel("Fold progress")
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced)).monospacedDigit()
                    .frame(width: 36, alignment: .trailing).accessibilityIdentifier("progressValue")
            }
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 1.25)) { progress = progress < 0.5 ? 1 : 0 }
                } label: {
                    Label(progress < 0.5 ? "Play transition" : "Play it back", systemImage: "play.fill")
                }
                Spacer()
                Text(isDuo ? "Fold in half" : (choreography == .pageTurn ? "Page turn" : "Reveal")).foregroundStyle(.secondary)
            }
            .font(.system(size: 13, weight: .semibold))
            .buttonStyle(.plain)
            .frame(minHeight: 34)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.28)))
        .frame(maxWidth: 420)
    }

    /// The simulator has no motion sensors, so it gets a small two-axis pad instead of a full-screen page.
    private var simulatorPad: some View {
        VStack(spacing: 8) {
            Text("Drag to tilt. On iPhone, move the device.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            TiltPad(tilt: $manualTilt)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.28)))
        .frame(maxWidth: 420)
    }

    private var options: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(FoldAppearance.allCases, id: \.self) { Text(name(of: $0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Glass")
                } footer: {
                    Text(description(of: appearance))
                }
                if isFeed {
                    Section {
                        Toggle("Reduce motion", isOn: $reduceMotion)
                    } footer: {
                        Text("Scroll up. Each item folds, frosts, and shrinks into the island itself.")
                    }
                } else if isAtlas {
                    Section {
                        Toggle("Reduce motion", isOn: $reduceMotion)
                    } footer: {
                        Text(motion.isAvailable
                             ? "Nudge the phone left, right, up, or down to move through the grid. Swiping works too."
                             : "The simulator has no motion sensors. Swipe to move through the grid.")
                    }
                } else if isDuo {
                    Section {
                        Toggle("Reduce motion", isOn: $reduceMotion)
                        Button("Show midpoint") { progress = 0.5; showsOptions = false }
                        Button("Reset preview") { progress = 0; showsOptions = false }
                    } footer: {
                        Text("Swipe up to close the display and down to open it, or scrub the slider. Both halves are frosted panes hinged at the seam and projected from one eye on the hinge.")
                    }
                } else {
                    Section {
                        Toggle("Tilt device", isOn: $deviceMode)
                    } footer: {
                        Text(deviceMode
                             ? (motion.isAvailable
                                ? "Neutral is set when you close this sheet. Double-tap the page to reset it any time."
                                : "The simulator has no motion sensors, so a two-axis pad appears on the page.")
                             : "Turns the page into a frosted pane that follows the phone. Hides the slider.")
                    }
                    Section {
                        Picker("Choreography", selection: $choreography) {
                            Text("Reveal").tag(FoldChoreography.reveal)
                            Text("Page turn").tag(FoldChoreography.pageTurn)
                        }
                        .pickerStyle(.segmented)
                        Toggle("Left hinge", isOn: Binding(get: { edge == .left }, set: { edge = $0 ? .left : .right }))
                        Toggle("Reduce motion", isOn: $reduceMotion)
                        Button("Show midpoint") { deviceMode = false; progress = 0.5; showsOptions = false }
                        Button("Reset preview") {
                            progress = 0; manualTilt = .zero; motion.recalibrate(); showsOptions = false
                        }
                    } header: {
                        Text("Transition")
                    } footer: {
                        Text("On the page, swipe in any direction, scrub the slider, or tap Play.")
                    }
                    .disabled(deviceMode)
                }
                Section("Inspired by") {
                    Text(example.inspiration)
                    Text("Recreated for this demo with fictional names and data.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Photography") {
                    Text("Alexander Voronov · Bilali Esmir · Lucie Morel · Olena Bohovyk · Vivu Vietnam")
                    Text("Photos from Unsplash. Bundled for offline viewing.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Preview options").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsOptions = false } } }
        }
        .presentationDetents([.large])
    }

    private func name(of appearance: FoldAppearance) -> String {
        switch appearance {
        case .frosted: "Frosted"
        case .clear: "Clear"
        case .grain: "Grain"
        case .gloss: "Gloss"
        case .ink: "Ink"
        case .midnight: "Midnight"
        }
    }

    private func description(of appearance: FoldAppearance) -> String {
        switch appearance {
        case .frosted: "The reference demo's frosted glass: heavy blur that darkens with distance."
        case .clear: "Optically clear glass. The same projection with no blur and no darkening."
        case .grain: "Sanded glass with visible grain and a light diffusion."
        case .gloss: "Polished glass with a highlight that sweeps across the pane as it tilts."
        case .ink: "Ink on paper. The fold stays sharp and a shadow bleeds outward from the crease."
        case .midnight: "Night mode. Cool, dark, and heavily diffused."
        }
    }

    private func syncMotion() {
        if (deviceMode || isAtlas) && scenePhase == .active && !showsOptions && !reducesMotion {
            motion.start()
        } else {
            motion.stop()
        }
    }
}

private struct RoundButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(.regularMaterial, in: .circle)
                .overlay(Circle().strokeBorder(.white.opacity(0.28)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// Observe sensor samples only around the artwork, so the controls do not update at sensor frequency.
private struct MotionArtwork: View {
    let example: DemoExample
    let motion: FoldMotionSource
    let manualTilt: FoldTilt
    let style: FoldStyle
    let reduceMotion: Bool
    let insets: EdgeInsets

    var body: some View {
        ExampleScene(example: example, destination: false, insets: insets)
            .foldEffect(tilt: motion.isAvailable ? motion.tilt : manualTilt, style: style, reducesMotion: reduceMotion)
    }
}

private struct TiltPad: View {
    @Binding var tilt: FoldTilt

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(.primary.opacity(0.05))
                Path { path in
                    path.move(to: CGPoint(x: proxy.size.width / 2, y: 12))
                    path.addLine(to: CGPoint(x: proxy.size.width / 2, y: proxy.size.height - 12))
                    path.move(to: CGPoint(x: 12, y: proxy.size.height / 2))
                    path.addLine(to: CGPoint(x: proxy.size.width - 12, y: proxy.size.height / 2))
                }
                .stroke(.primary.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                Circle().fill(GalleryPalette.accent).frame(width: 15, height: 15)
                    .offset(x: tilt.horizontal * proxy.size.width / 2, y: tilt.vertical * proxy.size.height / 2)
            }
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                tilt = FoldTilt(horizontal: max(-0.8, min(0.8, (value.location.x / proxy.size.width - 0.5) * 1.6)),
                                vertical: max(-0.8, min(0.8, (value.location.y / proxy.size.height - 0.5) * 1.6)))
            }.onEnded { _ in withAnimation(.easeOut(duration: 0.4)) { tilt = .zero } })
        }
        .frame(height: 76).accessibilityLabel("Tilt preview pad")
    }
}

private struct SceneOrientationReader: UIViewRepresentable {
    let update: @MainActor (UIInterfaceOrientation) -> Void
    func makeUIView(context: Context) -> OrientationView { OrientationView() }
    func updateUIView(_ view: OrientationView, context: Context) { view.update = update }

    final class OrientationView: UIView {
        var update: (@MainActor (UIInterfaceOrientation) -> Void)?
        private var lastOrientation: UIInterfaceOrientation?
        override func didMoveToWindow() { super.didMoveToWindow(); report() }
        override func layoutSubviews() { super.layoutSubviews(); report() }
        private func report() {
            guard let orientation = window?.windowScene?.interfaceOrientation,
                  orientation != lastOrientation else { return }
            lastOrientation = orientation
            Task { @MainActor [weak self] in self?.update?(orientation) }
        }
    }
}

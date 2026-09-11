import SwiftUI
import Foldy

@main
struct FoldyDemoApp: App {
    var body: some Scene {
        WindowGroup { RootView().preferredColorScheme(.light) }
    }
}

/// The gallery itself folds into the chosen experience, and folds back when it closes.
private struct RootView: View {
    @State private var presented: DemoExample?
    @State private var progress = 0.0
    @State private var showsShowcase = false

    var body: some View {
        FoldTransition(progress: progress, style: FoldStyle(edge: .right, choreography: .pageTurn)) {
            GalleryView(open: { example in
                presented = example
                // Give the destination one layout pass before the capture that starts the fold.
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 1.0)) { progress = 1 }
                }
            }, openShowcase: { showsShowcase = true })
            .fullScreenCover(isPresented: $showsShowcase) { ShowcaseView { showsShowcase = false } }
        } destination: {
            if let presented {
                ExperienceView(example: presented) {
                    withAnimation(.easeInOut(duration: 0.9)) { progress = 0 }
                }
                .id(presented)
            } else {
                GalleryPalette.background
            }
        }
        .onFoldEvent { event in
            if case .completed(.source) = event { presented = nil }
        }
        .ignoresSafeArea()
        .background(GalleryPalette.background)
        .statusBarHidden()
    }
}

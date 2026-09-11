import SwiftUI

enum GalleryPalette {
    static let background = Color(hex: 0x0C0C10)
    static let ink = Color(hex: 0xF5F5F7)
    static let muted = Color(hex: 0x8E8E93)
    static let accent = Color(hex: 0xE8542A)
}

/// A dark collection of live miniatures. Each one is the real source screen at a smaller scale.
struct GalleryView: View {
    let open: (DemoExample) -> Void
    var openShowcase: () -> Void = {}
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 10) {
                    Image(systemName: "square.stack.3d.up.fill").font(.system(size: 20, weight: .semibold))
                        .rotationEffect(.degrees(-12)).foregroundStyle(GalleryPalette.accent)
                    Text("foldy").font(.system(size: 30, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("SWIFT + METAL").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.4)
                        .foregroundStyle(GalleryPalette.muted)
                }
                .padding(.top, 14)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fold anything.").font(.system(size: 46, weight: .regular, design: .serif)).tracking(-2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Ten screens from the apps you use every day, seen through frosted glass. Tap one. Drag it. Tilt it. Nudge it.")
                        .font(.system(size: 15)).foregroundStyle(GalleryPalette.muted).lineSpacing(4)
                }
                ForEach(DemoExample.featured) { example in
                    FeaturedCard(example: example) { open(example) }
                }
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(DemoExample.grid) { example in
                        PreviewCard(example: example) { open(example) }
                    }
                }
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "move.3d").font(.title2).foregroundStyle(GalleryPalette.accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Made to follow your hand.").font(.system(size: 16, weight: .medium))
                        Text("Turn on Tilt device in any experience’s options and move the phone. The interface stays where it was; only the glass moves.")
                            .font(.system(size: 13)).foregroundStyle(GalleryPalette.muted).lineSpacing(3)
                    }
                }
                .padding(.top, 6)
                Button(action: openShowcase) {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.grid.2x2.fill").font(.system(size: 16)).foregroundStyle(GalleryPalette.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Showcase").font(.system(size: 16, weight: .medium))
                            Text("Six demos playing at once, framed for a screenshot or recording.")
                                .font(.system(size: 12)).foregroundStyle(GalleryPalette.muted)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .semibold))
                    }
                    .padding(16)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.08)))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open showcase")
                HStack {
                    Text("CRAFTED WITH FOLDY").tracking(1.5)
                    Spacer()
                    Text("MIT · 2026")
                }
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(GalleryPalette.muted)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 22).frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(GalleryPalette.background)
        .foregroundStyle(GalleryPalette.ink)
    }
}

private struct FeaturedCard: View {
    let example: DemoExample
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            ZStack(alignment: .bottomLeading) {
                FeaturedPreview(example: example)
                LinearGradient(colors: [.clear, .black.opacity(0.35), .black.opacity(0.85)],
                               startPoint: .init(x: 0.5, y: 0.2), endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEW").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(2)
                        .foregroundStyle(GalleryPalette.accent)
                    Text(example == .duo ? "Fold it shut." : example == .atlas ? "Nudge to navigate." : example == .moments ? "Photos, eaten whole." : "The island eats your cards.")
                        .font(.system(size: 22, weight: .semibold))
                    Text(example == .duo
                         ? "The display creases in half, frosts, and closes onto its cover screen. Swipe to open it again."
                         : example == .atlas
                         ? "A grid of places. Bump the phone toward an edge and the card folds that way to the next one."
                         : example == .moments
                         ? "A photo grid where each tile shrinks into the pill and slips under it."
                         : "Scroll the feed. Cards fold, frost, and are pulled into the Dynamic Island.")
                        .font(.system(size: 13)).foregroundStyle(GalleryPalette.muted).lineSpacing(2)
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.1)))
            .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(example.title)")
    }
}

private struct PreviewCard: View {
    let example: DemoExample
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 10) {
                ScenePreview(example: example)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.1)))
                    .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
                VStack(alignment: .leading, spacing: 3) {
                    Text(example.title).font(.system(size: 17, weight: .semibold))
                    Text(example.caption).font(.system(size: 12)).foregroundStyle(GalleryPalette.muted)
                }
                .padding(.horizontal, 4)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(example.title)")
    }
}

/// The source screen laid out at phone size and scaled to fit, so the preview matches what opens.
struct ScenePreview: View {
    let example: DemoExample
    static let referenceSize = CGSize(width: 402, height: 874)
    static let previewInsets = EdgeInsets(top: 62, leading: 0, bottom: 44, trailing: 0)

    var body: some View {
        GeometryReader { proxy in
            ExampleScene(example: example, destination: false, insets: Self.previewInsets)
                .frame(width: Self.referenceSize.width, height: Self.referenceSize.height)
                .scaleEffect(proxy.size.width / Self.referenceSize.width, anchor: .topLeading)
        }
        .aspectRatio(Self.referenceSize.width / Self.referenceSize.height, contentMode: .fit)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A feed's header and first row at natural size, cropped to a wide card.
private struct FeaturedPreview: View {
    let example: DemoExample

    var body: some View {
        ZStack(alignment: .top) {
            if example == .duo {
                // Show the balcony scene without its greeting, so the card's own title stays legible.
                ScenePhoto(name: "Balcony", alignment: .top)
            } else if example == .atlas {
                ScenePhoto(name: "Night", alignment: .center)
            } else if example == .moments {
                Color(hex: 0xF7F6F2)
                GeometryReader { proxy in
                    let tile = Moments.tileSize(width: proxy.size.width + 8)
                    VStack(alignment: .leading, spacing: 14) {
                        MomentsHeader()
                        HStack(spacing: Moments.spacing) {
                            ForEach(Moments.all.prefix(2)) { MomentTile(moment: $0).frame(width: tile, height: tile) }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 10)
                }
            } else {
                storiesBackground
                VStack(alignment: .leading, spacing: 14) {
                    StoriesHeader()
                    StoryCard(story: Stories.all[0]).frame(height: StoryCard.height)
                }
                .padding(.horizontal, 16).padding(.top, 10)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(height: 240, alignment: .top)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

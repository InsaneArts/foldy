import SwiftUI
import Foldy

/// Apple News and Google TV: a light feed of story cards. Scroll up and each card is pulled into the
/// Dynamic Island itself: it folds, frosts, shrinks to the pill, and slips under it.
struct Story: Identifiable {
    let id: Int
    let photo: String
    let headline: String
    let source: String
    let age: String
}

enum Stories {
    static let all: [Story] = [
        Story(id: 0, photo: "Coast", headline: "The slow return of the Amalfi ferry, and why locals hope it stays quiet",
              source: "The Coastal Review", age: "3 hours ago"),
        Story(id: 1, photo: "Clouds", headline: "Los Angeles braces for a week of low clouds and cooler nights",
              source: "Weather Desk", age: "5 hours ago"),
        Story(id: 2, photo: "Ocean", headline: "Sound and stillness: the producers making music for the blue hour",
              source: "Slow Radio Journal", age: "Yesterday"),
        Story(id: 3, photo: "Balcony", headline: "Inside the sea-view rooms travelers can’t stop booking",
              source: "Stay Weekly", age: "Yesterday"),
        Story(id: 4, photo: "Night", headline: "The best places to see the stars this month, ranked",
              source: "Night Sky Almanac", age: "2 days ago"),
        Story(id: 5, photo: "Coast", headline: "Lemon groves, cliff roads, and the case for slow travel",
              source: "Field Notes", age: "4 days ago"),
        Story(id: 6, photo: "Ocean", headline: "How the ocean became the soundtrack of a generation",
              source: "Tide", age: "1 week ago"),
        Story(id: 7, photo: "Night", headline: "Why dark skies are becoming the new luxury",
              source: "Aperture Weekly", age: "2 weeks ago")
    ]
}

let storiesBackground = Color(hex: 0xF2F2F7)
private let storiesInk = Color(hex: 0x1C1C1E)

/// The feed at rest, used for the gallery preview.
struct StoriesScene: View {
    let insets: EdgeInsets
    /// A story kept in the layout but not drawn, while a stand-in for it is animated elsewhere.
    var hiddenStory: Int? = nil

    var body: some View {
        ZStack(alignment: .top) {
            storiesBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                StoriesHeader()
                ForEach(Stories.all.prefix(3)) { story in
                    StoryCard(story: story).frame(height: StoryCard.height).opacity(story.id == hiddenStory ? 0 : 1)
                }
            }
            .padding(.horizontal, 20).padding(.top, insets.top + 6)
            // Three cards overflow a phone screen; keep the overflow anchored to the top, not centered.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .clipped()
    }
}

struct StoriesHeader: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Top stories").font(.system(size: 30, weight: .bold))
            Spacer()
            Text("FOR YOU").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.4)
                .foregroundStyle(Color(hex: 0x8E8E93))
        }
        .foregroundStyle(storiesInk)
        .frame(height: StoriesHeader.height, alignment: .bottom)
    }

    static let height: CGFloat = 40
}

struct StoryCard: View {
    static let height: CGFloat = 300
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScenePhoto(name: story.photo).frame(height: 188).clipped()
            VStack(alignment: .leading, spacing: 10) {
                Text(story.headline).font(.system(size: 19, weight: .medium)).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text("\(story.source) · \(story.age)").font(.system(size: 14)).foregroundStyle(Color(hex: 0x8E8E93))
                    Spacer()
                    Image(systemName: "square.and.arrow.up").font(.system(size: 15)).foregroundStyle(Color(hex: 0x8E8E93))
                }
            }
            .padding(16)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .foregroundStyle(storiesInk)
    }
}

/// The interactive feed. Cards scroll normally until they cross the fold line below the island.
/// From there an overlay ghost takes over: it follows the finger on a slow scroll, and on a flick it
/// lags behind on its own clock, so the pull into the island is always visible.
struct StoriesFeed: View {
    let topInset: CGFloat
    let size: CGSize
    let cutout: FoldCutout
    let reduceMotion: Bool
    @State private var stackTop: CGFloat?
    @State private var ghosts: [Ghost] = []
    @State private var ghostCount = 0
    private let spacing: CGFloat = 18
    private let style = FoldStyle(darkening: 0.05)

    /// A card is consumed once its top would sit inside the cutout.
    private var eaten: CGFloat { cutout.frame.midY - 6 }
    /// Where a card sits the moment it crosses the fold line.
    private var startFrame: CGRect { CGRect(x: 20, y: foldStart, width: size.width - 40, height: StoryCard.height) }
    /// Folding begins just above the first card's resting position, so nothing folds until you scroll.
    private var foldStart: CGFloat { topInset + 6 + StoriesHeader.height + spacing - 8 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: spacing) {
                    StoriesHeader()
                    ForEach(Stories.all) { story in
                        StoryCard(story: story)
                            .frame(height: StoryCard.height)
                            .opacity(progress(of: story.id) > 0 ? 0 : 1)
                    }
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .global).minY
                } action: { top in
                    stackMoved(to: top)
                }
                .padding(.horizontal, 20)
                .padding(.top, topInset + 6)
                // Enough room for the last card to reach the island too.
                .padding(.bottom, max(60, size.height - StoryCard.height - topInset - 40))
            }
            .scrollTargetBehavior(FoldCutoutSnap(firstRowTop: topInset + 6 + StoriesHeader.height + spacing,
                                                 period: StoryCard.height + spacing, rows: Stories.all.count,
                                                 foldStart: foldStart, eaten: eaten))
            .background(storiesBackground)
            ForEach(ghosts) { ghost in
                FoldCutoutGhost(startsFolded: ghost.startsFolded, scroll: progress(of: ghost.id), start: startFrame,
                                target: cutout.frame, style: style, reducesMotion: reduceMotion, liquid: true) {
                    StoryCard(story: ghost.story)
                }
                // Earlier ghosts are further along and smaller, so they stay on top of newer ones.
                .zIndex(Double(100_000 - ghost.sequence))
            }
        }
    }

    /// Card tops follow from the stack's position because every card has the same height.
    private func top(of index: Int, stackTop: CGFloat) -> CGFloat {
        stackTop + StoriesHeader.height + spacing + CGFloat(index) * (StoryCard.height + spacing)
    }

    private func progress(of index: Int, stackTop: CGFloat? = nil) -> Double {
        guard let stackTop = stackTop ?? self.stackTop else { return 0 }
        let value = (foldStart - top(of: index, stackTop: stackTop)) / (foldStart - eaten)
        return min(max(Double(value), 0), 1)
    }

    private func stackMoved(to top: CGFloat) {
        let previous = stackTop
        stackTop = top
        let now = Date()
        for story in Stories.all {
            let progress = progress(of: story.id)
            guard progress > 0, progress < 1, !ghosts.contains(where: { $0.id == story.id }) else { continue }
            // Re-entering from above starts folded, so the ghost lines up with the hidden card.
            let cameFromAbove = previous.map { self.progress(of: story.id, stackTop: $0) >= 1 } ?? false
            ghostCount += 1
            ghosts.append(Ghost(id: story.id, story: story, created: now, sequence: ghostCount, startsFolded: cameFromAbove))
        }
        ghosts.removeAll { ghost in
            let progress = progress(of: ghost.id)
            // Retire only once the settle has had time to play; earlier removal cuts the animation.
            return progress <= 0 || (progress >= 1 && now.timeIntervalSince(ghost.created) > 2.0)
        }
    }
}

private struct Ghost: Identifiable {
    let id: Int
    let story: Story
    let created: Date
    let sequence: Int
    let startsFolded: Bool
}

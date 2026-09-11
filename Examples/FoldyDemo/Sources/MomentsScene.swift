import SwiftUI
import Foldy

/// Apple Photos and Google Photos: a light grid of square moments. Scroll up and each tile is
/// pulled into the Dynamic Island itself: it frosts, darkens, shrinks to the pill, and slips under it.
struct Moment: Identifiable {
    let id: Int
    let photo: String?
    let title: String?
    let colors: [Color]

    static func photo(_ id: Int, _ name: String) -> Moment { Moment(id: id, photo: name, title: nil, colors: []) }
    static func memory(_ id: Int, _ title: String, _ colors: [UInt32]) -> Moment {
        Moment(id: id, photo: nil, title: title, colors: colors.map { Color(hex: $0) })
    }
}

enum Moments {
    static let all: [Moment] = [
        .photo(0, "Coast"), .photo(1, "Balcony"),
        .memory(2, "Amalfi\nSummer 2024", [0xF6B26B, 0xE8542A]), .photo(3, "Ocean"),
        .photo(4, "Clouds"), .photo(5, "Night"),
        .photo(6, "Balcony"), .memory(7, "Blue Hour\n12 photos", [0x2F5F8C, 0x0C131B]),
        .photo(8, "Coast"), .photo(9, "Clouds"),
        .memory(10, "Storm season", [0x8A9BA8, 0x2E3A44]), .photo(11, "Night"),
        .photo(12, "Ocean"), .photo(13, "Coast")
    ]
    static let columns = 2
    static let spacing: CGFloat = 12
    static var rows: Int { (all.count + columns - 1) / columns }

    static func tileSize(width: CGFloat) -> CGFloat {
        (width - 40 - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }
}

private let momentsBackground = Color(hex: 0xF7F6F2)
private let momentsInk = Color(hex: 0x1C1C1E)

/// The grid at rest, used for the gallery preview.
struct MomentsScene: View {
    let insets: EdgeInsets

    var body: some View {
        GeometryReader { proxy in
            let tile = Moments.tileSize(width: proxy.size.width)
            ZStack(alignment: .top) {
                momentsBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    MomentsHeader()
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(tile), spacing: Moments.spacing), count: Moments.columns),
                              spacing: Moments.spacing) {
                        ForEach(Moments.all.prefix(6)) { MomentTile(moment: $0).frame(width: tile, height: tile) }
                    }
                }
                .padding(.horizontal, 20).padding(.top, insets.top + 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .clipped()
        }
    }
}

struct MomentsHeader: View {
    static let height: CGFloat = 64

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Moments").font(.system(size: 34, weight: .bold))
                Text("Yesterday · Amalfi Coast").font(.system(size: 15)).foregroundStyle(Color(hex: 0x8E8E93))
            }
            Spacer()
            Text("Select").font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 14).frame(height: 34)
                .background(.white, in: .capsule)
                .overlay(Capsule().strokeBorder(Color(hex: 0xE4E2DC)))
                .padding(.top, 4)
        }
        .foregroundStyle(momentsInk)
        .frame(height: Self.height, alignment: .top)
    }
}

struct MomentTile: View {
    let moment: Moment

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let photo = moment.photo {
                ScenePhoto(name: photo)
            } else {
                LinearGradient(colors: moment.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                if let title = moment.title {
                    Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                        .lineSpacing(2).padding(14)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// The interactive grid. Each row folds into the cutout on its own clock once it crosses the fold line.
struct MomentsFeed: View {
    let topInset: CGFloat
    let size: CGSize
    let cutout: FoldCutout
    let reduceMotion: Bool
    @State private var stackTop: CGFloat?
    @State private var ghosts: [MomentGhost] = []
    @State private var ghostCount = 0
    private let style = FoldStyle(darkening: 0.05)

    private var tile: CGFloat { Moments.tileSize(width: size.width) }
    private var period: CGFloat { tile + Moments.spacing }
    /// A row is consumed once its top would sit inside the cutout.
    private var eaten: CGFloat { cutout.frame.midY - 6 }
    /// Folding begins just above the first row's resting position.
    private var foldStart: CGFloat { topInset + 6 + MomentsHeader.height + 16 - 8 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    MomentsHeader()
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(tile), spacing: Moments.spacing), count: Moments.columns),
                              spacing: Moments.spacing) {
                        ForEach(Moments.all) { moment in
                            MomentTile(moment: moment)
                                .frame(width: tile, height: tile)
                                .opacity(progress(ofRow: moment.id / Moments.columns) > 0 ? 0 : 1)
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .global).minY
                } action: { top in
                    stackMoved(to: top)
                }
                .padding(.horizontal, 20)
                .padding(.top, topInset + 6)
                .padding(.bottom, max(60, size.height - tile - topInset - 40))
            }
            .scrollTargetBehavior(FoldCutoutSnap(firstRowTop: topInset + 6 + MomentsHeader.height + 16, period: period,
                                                 rows: Moments.rows, foldStart: foldStart, eaten: eaten))
            .background(momentsBackground)
            ForEach(ghosts) { ghost in
                FoldCutoutGhost(startsFolded: ghost.startsFolded, scroll: progress(ofRow: ghost.moment.id / Moments.columns),
                                start: startFrame(for: ghost.moment), target: cutout.frame, style: style,
                                reducesMotion: reduceMotion, liquid: true) {
                    MomentTile(moment: ghost.moment)
                }
                .zIndex(Double(100_000 - ghost.sequence))
            }
        }
    }

    private func rowTop(_ row: Int, stackTop: CGFloat) -> CGFloat {
        stackTop + MomentsHeader.height + 16 + CGFloat(row) * period
    }

    private func progress(ofRow row: Int, stackTop: CGFloat? = nil) -> Double {
        guard let stackTop = stackTop ?? self.stackTop else { return 0 }
        let value = (foldStart - rowTop(row, stackTop: stackTop)) / (foldStart - eaten)
        return min(max(Double(value), 0), 1)
    }

    /// Where a tile sits the moment it crosses the fold line.
    private func startFrame(for moment: Moment) -> CGRect {
        let column = CGFloat(moment.id % Moments.columns)
        return CGRect(x: 20 + column * period, y: foldStart, width: tile, height: tile)
    }

    private func stackMoved(to top: CGFloat) {
        let previous = stackTop
        stackTop = top
        let now = Date()
        for moment in Moments.all {
            let row = moment.id / Moments.columns
            let progress = progress(ofRow: row)
            guard progress > 0, progress < 1, !ghosts.contains(where: { $0.id == moment.id }) else { continue }
            let cameFromAbove = previous.map { self.progress(ofRow: row, stackTop: $0) >= 1 } ?? false
            ghostCount += 1
            ghosts.append(MomentGhost(id: moment.id, moment: moment, created: now, sequence: ghostCount,
                                      startsFolded: cameFromAbove))
        }
        ghosts.removeAll { ghost in
            let progress = progress(ofRow: ghost.moment.id / Moments.columns)
            // Retire only once the settle has had time to play; earlier removal cuts the animation.
            return progress <= 0 || (progress >= 1 && now.timeIntervalSince(ghost.created) > 2.0)
        }
    }
}

private struct MomentGhost: Identifiable {
    let id: Int
    let moment: Moment
    let created: Date
    let sequence: Int
    let startsFolded: Bool
}

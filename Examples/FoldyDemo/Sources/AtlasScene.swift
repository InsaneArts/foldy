import SwiftUI
import Foldy

/// A grid of places you move through by nudging the phone. Bump left, right, up, or down and the
/// current card folds away toward that edge while the next one unfolds in. Every step is a fold.

struct Place: Identifiable, Equatable {
    let id: Int
    let photo: String
    let name: String
    let region: String
    let detail: String
    let tint: UInt32
}

enum Atlas {
    static let columns = 3
    static let places: [Place] = [
        Place(id: 0, photo: "Coast", name: "Amalfi", region: "Campania, Italy", detail: "Cliff-side villages and lemon groves.", tint: 0xE8802A),
        Place(id: 1, photo: "Balcony", name: "Positano", region: "Campania, Italy", detail: "Pastel houses stacked above the sea.", tint: 0x2F6BD8),
        Place(id: 2, photo: "Ocean", name: "Open water", region: "Tyrrhenian Sea", detail: "Nothing on the horizon for hours.", tint: 0x1E5F8C),
        Place(id: 3, photo: "Clouds", name: "Los Angeles", region: "California, USA", detail: "June gloom rolling in from the bay.", tint: 0x5C6B7A),
        Place(id: 4, photo: "Night", name: "Atacama", region: "Chile", detail: "The clearest sky on Earth.", tint: 0x1B2A4A),
        Place(id: 5, photo: "Coast", name: "Ravello", region: "Campania, Italy", detail: "Gardens a thousand feet up.", tint: 0xC65D3A),
        Place(id: 6, photo: "Balcony", name: "Praiano", region: "Campania, Italy", detail: "Quiet terraces facing west.", tint: 0x3E86C2),
        Place(id: 7, photo: "Night", name: "Tenerife", region: "Canary Islands", detail: "Stars above the volcano.", tint: 0x2E3E6A),
        Place(id: 8, photo: "Ocean", name: "Blue hour", region: "Anywhere", detail: "Twenty minutes after sunset.", tint: 0x24507A)
    ]
    static var rows: Int { (places.count + columns - 1) / columns }

    static func place(atRow row: Int, column: Int) -> Place? {
        let index = row * columns + column
        guard row >= 0, column >= 0, column < columns, index < places.count else { return nil }
        return places[index]
    }
}

/// One full-screen place card.
struct PlaceCard: View {
    let place: Place
    let insets: EdgeInsets

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ScenePhoto(name: place.photo)
            LinearGradient(colors: [.clear, .black.opacity(0.15), .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 10) {
                Text(place.region.uppercased()).font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(1.6)
                    .opacity(0.85)
                Text(place.name).font(.system(size: 54, weight: .bold)).tracking(-1.5)
                Text(place.detail).font(.system(size: 17)).opacity(0.9)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
            .padding(.horizontal, 26).padding(.bottom, insets.bottom + 26)
        }
        .ignoresSafeArea()
    }
}

/// The card grid at rest, used for the gallery preview.
struct AtlasScene: View {
    let insets: EdgeInsets

    var body: some View {
        PlaceCard(place: Atlas.places[0], insets: insets)
            .overlay(alignment: .top) { AtlasCompass(row: 0, column: 0, insets: insets) }
    }
}

/// A small map of the grid with the current cell lit, plus arrows for the moves that are possible.
struct AtlasCompass: View {
    let row: Int
    let column: Int
    let insets: EdgeInsets

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(0..<Atlas.columns, id: \.self) { c in
                    VStack(spacing: 5) {
                        ForEach(0..<Atlas.rows, id: \.self) { r in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(r == row && c == column ? .white : .white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            Text("Nudge the phone to move").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.top, insets.top + 60)
        .accessibilityLabel("Row \(row + 1), column \(column + 1)")
    }
}

/// The interactive grid: a `FoldPager` over the places, three per row. Swipes and nudges both move.
struct AtlasStage: View {
    let size: CGSize
    let insets: EdgeInsets
    let motion: FoldMotionSource
    let style: FoldStyle
    let reduceMotion: Bool
    @State private var selection = 0

    var body: some View {
        FoldPager(items: Atlas.places, columns: Atlas.columns, selection: $selection, style: style,
                  reducesMotion: reduceMotion, motion: motion) { place in
            PlaceCard(place: place, insets: insets)
        }
        .overlay(alignment: .top) {
            AtlasCompass(row: selection / Atlas.columns, column: selection % Atlas.columns, insets: insets)
        }
        .frame(width: size.width, height: size.height)
        .background(Color.black)
    }
}

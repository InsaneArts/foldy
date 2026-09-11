import SwiftUI

/// Six screens borrowed from familiar apps, each with a source and a destination state.
enum DemoExample: String, CaseIterable, Identifiable {
    case duo, atlas, stories, moments, wallet, weather, music, travel, fitness, boarding
    var id: String { rawValue }

    /// The two-screen transitions shown in the gallery grid. The fold and the feeds are featured above them.
    static var grid: [DemoExample] { allCases.filter { $0.usesTransition } }
    static var featured: [DemoExample] { [.duo, .atlas, .stories, .moments] }
    /// Scrolling feeds where the cutout pulls content in; they have no destination screen.
    var isFeed: Bool { self == .stories || self == .moments }
    /// Source-to-destination transitions, which also support device tilt.
    var usesTransition: Bool { !isFeed && self != .duo && self != .atlas }

    var title: String {
        switch self {
        case .duo: "Duo"
        case .atlas: "Atlas"
        case .stories: "Top stories"
        case .moments: "Moments"
        case .wallet: "Wallet"
        case .weather: "Weather"
        case .music: "Blue Hour"
        case .travel: "Amalfi"
        case .fitness: "Steps"
        case .boarding: "Boarding pass"
        }
    }

    var caption: String {
        switch self {
        case .duo: "Fold the display in half"
        case .atlas: "Nudge the phone to move through a grid"
        case .stories: "Scroll → the island eats the cards"
        case .moments: "Scroll → the island eats the photos"
        case .wallet: "Card stack → card detail"
        case .weather: "City list → forecast"
        case .music: "Album → now playing"
        case .travel: "Destination → stay"
        case .fitness: "Activities → steps"
        case .boarding: "Pass → flight details · UIKit"
        }
    }

    var inspiration: String {
        switch self {
        case .duo: "iPhone Duo and flip-phone cover screens"
        case .atlas: "Apple TV top shelf and Polarsteps"
        case .stories: "Google TV and Apple News"
        case .moments: "Apple Photos and Google Photos"
        case .wallet: "Apple Wallet"
        case .weather: "Apple Weather"
        case .music: "Spotify"
        case .travel: "Polarsteps and Airbnb"
        case .fitness: "Gentler Streak"
        case .boarding: "Apple Wallet passes"
        }
    }
}

/// Every scene fills its proposed size. Backgrounds bleed to the display edges so the fold moves the
/// entire page; `insets` keep content clear of the status band and the demo's floating controls.
struct ExampleScene: View {
    let example: DemoExample
    let destination: Bool
    var insets = EdgeInsets()

    var body: some View {
        Group {
            switch example {
            case .duo: DuoScene(insets: insets)
            case .atlas: AtlasScene(insets: insets)
            case .stories: StoriesScene(insets: insets)
            case .moments: MomentsScene(insets: insets)
            case .wallet: WalletScene(destination: destination, insets: insets)
            case .weather: WeatherScene(destination: destination, insets: insets)
            case .music: MusicScene(destination: destination, insets: insets)
            case .travel: TravelScene(destination: destination, insets: insets)
            case .fitness: FitnessScene(destination: destination, insets: insets)
            case .boarding: BoardingScene(destination: destination, insets: insets)
            }
        }
        .ignoresSafeArea()
    }
}

/// A bundled photograph that fills its frame.
struct ScenePhoto: View {
    let name: String
    var alignment: Alignment = .center

    var body: some View {
        GeometryReader { proxy in
            Image(name).resizable().scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: alignment)
                .clipped()
        }
        .accessibilityHidden(true)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension View {
    /// Pads the top and bottom edges by a scene's insets. Use when both edges must stay clear.
    func sceneInsets(_ insets: EdgeInsets) -> some View {
        padding(.top, insets.top).padding(.bottom, insets.bottom)
    }
}

import SwiftUI

/// Spotify: an album page with its track list, then the full-screen now-playing view.
struct MusicScene: View {
    let destination: Bool
    let insets: EdgeInsets

    var body: some View {
        if destination {
            NowPlaying(insets: insets)
        } else {
            AlbumPage(insets: insets)
        }
    }
}

private let spotifyGreen = Color(hex: 0x1ED760)
private let spotifyGray = Color(hex: 0xB3B3B3)

private struct AlbumArt: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ScenePhoto(name: "Ocean")
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text("SLOW RADIO").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(2)
                Text("Blue Hour").font(.system(size: 30, design: .serif))
            }
            .padding(16).foregroundStyle(.white)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct Track: Identifiable {
    let title: String
    let artists: String
    var playing = false
    var id: String { title }
}

private struct AlbumPage: View {
    let insets: EdgeInsets
    @State private var saved = false
    private let tracks = [
        Track(title: "Between the Tides", artists: "Slow Radio", playing: true),
        Track(title: "Still Waters", artists: "Slow Radio, Mara Vey"),
        Track(title: "Blue Hour", artists: "Slow Radio"),
        Track(title: "Salt Air", artists: "Slow Radio"),
        Track(title: "Long Way Home", artists: "Slow Radio, Ilse Noor"),
        Track(title: "Night Swim", artists: "Slow Radio")
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: 0x121212).ignoresSafeArea()
            LinearGradient(colors: [Color(hex: 0x2C5C86), Color(hex: 0x121212)], startPoint: .top, endPoint: .bottom)
                .frame(height: 420 + insets.top).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                AlbumArt().frame(width: 216, height: 216)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: .black.opacity(0.5), radius: 26, y: 14)
                    .frame(maxWidth: .infinity).padding(.top, 12)
                Text("Blue Hour").font(.system(size: 24, weight: .bold)).padding(.top, 20)
                HStack(spacing: 8) {
                    Circle().fill(LinearGradient(colors: [Color(hex: 0xF7B267), Color(hex: 0x8B5CF6)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 22, height: 22)
                    Text("Slow Radio").font(.system(size: 13, weight: .semibold))
                }
                .padding(.top, 10)
                Text("Album • 2026").font(.system(size: 13)).foregroundStyle(spotifyGray).padding(.top, 6)
                HStack(spacing: 22) {
                    AlbumArt().frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.6), lineWidth: 1))
                    Button { saved.toggle() } label: {
                        Image(systemName: saved ? "checkmark.circle.fill" : "plus.circle")
                            .font(.system(size: 22)).foregroundStyle(saved ? spotifyGreen : spotifyGray)
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel(saved ? "Album saved" : "Save album")
                    Image(systemName: "arrow.down.circle").font(.system(size: 22)).foregroundStyle(spotifyGray)
                    Image(systemName: "ellipsis").font(.system(size: 20)).foregroundStyle(spotifyGray)
                    Spacer()
                    Image(systemName: "shuffle").font(.system(size: 20)).foregroundStyle(spotifyGray)
                    ZStack {
                        Circle().fill(spotifyGreen).frame(width: 56, height: 56)
                        Image(systemName: "play.fill").font(.system(size: 22)).foregroundStyle(.black).offset(x: 2)
                    }
                }
                .padding(.top, 12)
                VStack(spacing: 0) {
                    ForEach(tracks) { track in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    if track.playing {
                                        Image(systemName: "waveform").font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(spotifyGreen)
                                    }
                                    Text(track.title).font(.system(size: 16))
                                        .foregroundStyle(track.playing ? spotifyGreen : .white)
                                }
                                Text(track.artists).font(.system(size: 13)).foregroundStyle(spotifyGray)
                            }
                            Spacer()
                            Image(systemName: "ellipsis").font(.system(size: 16)).foregroundStyle(spotifyGray)
                        }
                        .frame(height: 54)
                    }
                }
                .padding(.top, 10)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.top, insets.top)
            .foregroundStyle(.white)
        }
    }
}

private struct NowPlaying: View {
    let insets: EdgeInsets

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2F5F8C), Color(hex: 0x1A2E44), Color(hex: 0x0C131B)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 3) {
                    Text("PLAYING FROM ALBUM").font(.system(size: 11, weight: .semibold)).tracking(0.6).opacity(0.7)
                    Text("Blue Hour").font(.system(size: 13, weight: .semibold))
                }
                .padding(.top, 8)
                Spacer(minLength: 14)
                AlbumArt()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.55), radius: 30, y: 18)
                Spacer(minLength: 22)
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Between the Tides").font(.system(size: 22, weight: .bold))
                        Text("Slow Radio").font(.system(size: 16)).foregroundStyle(spotifyGray)
                    }
                    Spacer()
                    Image(systemName: "plus.circle").font(.system(size: 24)).foregroundStyle(spotifyGray)
                }
                VStack(spacing: 8) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.3)).frame(height: 4)
                            Capsule().fill(.white).frame(width: proxy.size.width * 0.38, height: 4)
                            Circle().fill(.white).frame(width: 12, height: 12).offset(x: proxy.size.width * 0.38 - 6)
                        }
                        .frame(height: 12)
                    }
                    .frame(height: 12)
                    HStack {
                        Text("1:02")
                        Spacer()
                        Text("-2:41")
                    }
                    .font(.system(size: 12)).foregroundStyle(spotifyGray)
                }
                .padding(.top, 16)
                HStack {
                    Image(systemName: "shuffle").font(.system(size: 22))
                    Spacer()
                    Image(systemName: "backward.fill").font(.system(size: 30))
                    Spacer()
                    ZStack {
                        Circle().fill(.white).frame(width: 72, height: 72)
                        Image(systemName: "pause.fill").font(.system(size: 28)).foregroundStyle(.black)
                    }
                    Spacer()
                    Image(systemName: "forward.fill").font(.system(size: 30))
                    Spacer()
                    Image(systemName: "repeat").font(.system(size: 22))
                }
                .padding(.top, 10).padding(.horizontal, 4)
                HStack {
                    Image(systemName: "hifispeaker.fill").font(.system(size: 17))
                    Spacer()
                    Image(systemName: "square.and.arrow.up").font(.system(size: 17))
                    Image(systemName: "list.bullet").font(.system(size: 17)).padding(.leading, 22)
                }
                .foregroundStyle(spotifyGray).padding(.top, 20)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24).sceneInsets(insets)
            .foregroundStyle(.white)
        }
    }
}

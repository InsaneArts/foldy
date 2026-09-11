import SwiftUI
import Foldy

/// The iPhone Duo moment. The display creases at its middle: each half is a frosted pane hinged at
/// the seam, both projected from one eye on the hinge, so the two halves read as one bending surface.
/// Past the midpoint the halves close onto the device's exterior, where a small cover display wakes.

/// The open inner display, also used for the gallery preview.
struct DuoScene: View {
    let insets: EdgeInsets
    var body: some View { DuoInner(insets: insets) }
}

struct DuoInner: View {
    let insets: EdgeInsets

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScenePhoto(name: "Balcony", alignment: .top)
            LinearGradient(stops: [.init(color: .black.opacity(0.5), location: 0), .init(color: .clear, location: 0.35),
                                   .init(color: .clear, location: 0.7), .init(color: .black.opacity(0.45), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                Text("Good morning").font(.system(size: 38, weight: .semibold)).tracking(-0.5)
                Text("Tuesday 12 September").font(.system(size: 17, weight: .medium)).opacity(0.9)
                HStack(spacing: 6) {
                    Image(systemName: "sun.max.fill").foregroundStyle(Color(hex: 0xFFD166))
                    Text("24° · Amalfi")
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 12).frame(height: 32)
                .background(.white.opacity(0.18), in: .capsule)
                .padding(.top, 10)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
            .padding(.horizontal, 24).padding(.top, insets.top + 60)
        }
        .background(Color(hex: 0x1B3A5C))
        .overlay(alignment: .bottom) {
            HStack(spacing: 14) {
                Image(systemName: "ferry.fill").font(.system(size: 20)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(Color(hex: 0x2F6BD8), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ferry to Positano").font(.system(size: 16, weight: .semibold))
                    Text("10:15 · Molo Pennello · 33 min").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 20).padding(.bottom, insets.bottom + 10)
        }
        .ignoresSafeArea()
    }
}

/// The closed device seen from outside: a dark shell, the hinge line, and a cover display.
struct DuoCover: View {
    let size: CGSize
    let insets: EdgeInsets

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x232328), .black], center: .center,
                           startRadius: 0, endRadius: size.height * 0.75)
            Rectangle().fill(LinearGradient(colors: [.clear, .white.opacity(0.32), .clear],
                                            startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
                .position(x: size.width / 2, y: size.height / 2)
            coverDisplay
                .frame(width: size.width - 72, height: 300)
                .position(x: size.width / 2, y: size.height * 0.27 + insets.top * 0.4)
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill").rotationEffect(.degrees(-12))
                Text("foldy")
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.16))
            .position(x: size.width / 2, y: size.height * 0.76)
        }
        .ignoresSafeArea()
    }

    private var coverDisplay: some View {
        ZStack(alignment: .topLeading) {
            ScenePhoto(name: "Ocean")
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text("7:42").font(.system(size: 66, weight: .thin)).tracking(-2).padding(.top, -6)
                Text("Tuesday 12 September").font(.system(size: 15, weight: .medium))
                HStack(spacing: 5) {
                    Image(systemName: "sun.max.fill").foregroundStyle(Color(hex: 0xFFD166))
                    Text("24°")
                }
                .font(.system(size: 14, weight: .semibold)).padding(.top, 2)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Image(systemName: "message.fill").font(.system(size: 14)).foregroundStyle(.white)
                        .frame(width: 30, height: 30).background(Color(hex: 0x30D158), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Giulia").font(.system(size: 13, weight: .semibold))
                        Text("Coffee's on the balcony ☕️").font(.system(size: 13)).opacity(0.85)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.14)))
        .shadow(color: .black.opacity(0.6), radius: 24, y: 12)
    }
}

/// The interactive fold. Progress zero is the open display; one is the closed device.
/// Animatable on progress so a timed play re-evaluates the whole choreography each frame.
struct DuoStage: View, Animatable {
    nonisolated var progress: Double
    let size: CGSize
    let insets: EdgeInsets
    var style: FoldStyle = .frosted
    let reduceMotion: Bool

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private static let maxAngle = 70.0 * .pi / 180
    /// The halves fold through the first part of the gesture, then close while the cover wakes.
    private var angle: Double { min(progress / 0.6, 1) * Self.maxAngle }
    private var closing: Double { smoothstep(0.5, 0.95, progress) }
    private var cover: Double { smoothstep(0.7, 1, progress) }

    var body: some View {
        let half = size.height / 2
        ZStack {
            Color.black
            if reduceMotion {
                if progress < 0.5 {
                    DuoInner(insets: insets).frame(width: size.width, height: size.height)
                } else {
                    DuoCover(size: size, insets: insets)
                }
            } else {
                if cover > 0 {
                    DuoCover(size: size, insets: insets)
                        .opacity(cover)
                        .scaleEffect(0.94 + 0.06 * cover)
                }
                if closing < 1 {
                    VStack(spacing: 0) {
                        pane(.top, height: half)
                        pane(.bottom, height: half)
                    }
                    .opacity(1 - closing)
                    // A specular line along the crease, brightest when the halves stand steepest.
                    Rectangle().fill(LinearGradient(colors: [.clear, .white.opacity(0.95), .clear],
                                                    startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1.5)
                        .opacity(sin(angle) * (1 - closing))
                        .position(x: size.width / 2, y: half)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    fileprivate enum Half { case top, bottom }

    /// Each half shows its part of the full display, folds around the seam, and projects from an eye
    /// on that seam. As the device closes, the halves shrink toward the crease.
    private func pane(_ half: Half, height: CGFloat) -> some View {
        DuoInner(insets: insets)
            .frame(width: size.width, height: size.height)
            .frame(width: size.width, height: height, alignment: half == .top ? .top : .bottom)
            .clipped()
            .foldEffect(tilt: FoldTilt(vertical: half == .top ? -angle : angle), style: paneStyle(half))
            .frame(width: size.width, height: height)
            .scaleEffect(y: 1 - 0.9 * closing, anchor: half == .top ? .bottom : .top)
    }
}

extension DuoStage {
    fileprivate func paneStyle(_ half: Half) -> FoldStyle {
        var style = style
        style.viewpoint = UnitPoint(x: 0.5, y: half == .top ? 1 : 0)
        return style
    }
}

func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}

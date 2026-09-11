import SwiftUI

/// Polarsteps and Airbnb: a full-bleed destination, then the place you stay there.
struct TravelScene: View {
    let destination: Bool
    let insets: EdgeInsets

    var body: some View {
        if destination {
            StayDetail(insets: insets)
        } else {
            DestinationHero(insets: insets)
        }
    }
}

private let travelInk = Color(hex: 0x1E2A44)
private let travelOrange = Color(hex: 0xE8802A)

private struct DestinationHero: View {
    let insets: EdgeInsets

    var body: some View {
        GeometryReader { proxy in
            let heroHeight = (proxy.size.height - insets.bottom) * 0.56
            ZStack(alignment: .top) {
                Color.white.ignoresSafeArea()
                VStack(spacing: 0) {
                    ZStack(alignment: .bottom) {
                        ScenePhoto(name: "Coast")
                        LinearGradient(colors: [.black.opacity(0.25), .clear, .black.opacity(0.32)],
                                       startPoint: .top, endPoint: .bottom)
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Text("🇮🇹").font(.system(size: 13))
                                Text("Italy").font(.system(size: 14, weight: .semibold))
                            }
                            .padding(.horizontal, 12).frame(height: 30)
                            .background(.white.opacity(0.22), in: .capsule)
                            Text("Amalfi").font(.system(size: 62, weight: .bold)).tracking(-1.5)
                            Text("40°38′03″N   14°36′10″E").font(.system(size: 13, weight: .medium)).tracking(0.3)
                            HStack(spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus").font(.system(size: 15, weight: .bold))
                                    Text("Add to plan").font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(.black).padding(.horizontal, 22).frame(height: 46)
                                .background(.white, in: .capsule)
                                Image(systemName: "bookmark").font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.black).frame(width: 46, height: 46)
                                    .background(.white, in: .circle)
                            }
                            .padding(.top, 12)
                        }
                        .foregroundStyle(.white).padding(.bottom, 26)
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    }
                    .frame(height: heroHeight).clipped()
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "sparkles").font(.system(size: 20)).foregroundStyle(travelOrange).padding(.top, 1)
                            Text("A cliffside town where lemon groves meet the sea: pastel houses stacked above the harbour, a tiled cathedral dome, and a coast road built for slow afternoons.")
                                .font(.system(size: 16, weight: .semibold)).foregroundStyle(travelOrange).lineSpacing(3)
                        }
                        HStack(alignment: .top, spacing: 0) {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "chart.bar.fill").font(.system(size: 22)).foregroundStyle(travelInk)
                                Text("Popularity").font(.system(size: 13)).foregroundStyle(.secondary)
                                Text("Regularly\nexplored").font(.system(size: 20, weight: .semibold)).foregroundStyle(travelInk)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "sun.max").font(.system(size: 22)).foregroundStyle(travelInk)
                                Text("Average in June").font(.system(size: 13)).foregroundStyle(.secondary)
                                Text("26°C").font(.system(size: 20, weight: .semibold)).foregroundStyle(travelInk)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        HStack(spacing: 4) {
                            Text("Something not right?").foregroundStyle(.secondary)
                            Text("Let us know").foregroundStyle(Color(hex: 0x2F6BD8)).underline()
                        }
                        .font(.system(size: 13))
                        Text("Photo by Alexander Voronov on Unsplash").font(.system(size: 11))
                            .foregroundStyle(Color(hex: 0xB0B0B5)).frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24).padding(.top, 26)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct StayDetail: View {
    let insets: EdgeInsets
    private let pink = Color(hex: 0xE31C5F)
    private let hairline = Color(hex: 0xE6E6E6)

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()
            VStack(spacing: -24) {
                ZStack(alignment: .bottomTrailing) {
                    ScenePhoto(name: "Balcony").frame(height: 232 + insets.top).clipped()
                    Text("1 / 27").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
                        .padding(.trailing, 16).padding(.bottom, 40)
                }
                VStack(spacing: 14) {
                    Text("Private room with a sea view in Amalfi").font(.system(size: 24, weight: .semibold))
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).padding(.top, 24)
                    VStack(spacing: 3) {
                        Text("Room in Amalfi, Italy").font(.system(size: 15))
                        Text("1 queen bed · Shared bathroom").font(.system(size: 15)).foregroundStyle(Color(hex: 0x6A6A6A))
                    }
                    HStack(spacing: 0) {
                        VStack(spacing: 4) {
                            Text("4.96").font(.system(size: 17, weight: .semibold))
                            HStack(spacing: 1) {
                                ForEach(0..<5, id: \.self) { _ in Image(systemName: "star.fill").font(.system(size: 8)) }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        Rectangle().fill(hairline).frame(width: 1, height: 36)
                        HStack(spacing: 6) {
                            Image(systemName: "laurel.leading").font(.system(size: 26))
                            VStack(spacing: 0) {
                                Text("Guest").font(.system(size: 15, weight: .semibold))
                                Text("favorite").font(.system(size: 15, weight: .semibold))
                            }
                            Image(systemName: "laurel.trailing").font(.system(size: 26))
                        }
                        .frame(maxWidth: .infinity)
                        Rectangle().fill(hairline).frame(width: 1, height: 36)
                        VStack(spacing: 3) {
                            Text("298").font(.system(size: 17, weight: .semibold))
                            Text("Reviews").font(.system(size: 11)).underline()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(hairline))
                    HStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            Circle().fill(LinearGradient(colors: [Color(hex: 0xF2A65A), Color(hex: 0xC4526A)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 48, height: 48)
                                .overlay(Text("G").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white))
                            Image(systemName: "checkmark.seal.fill").font(.system(size: 15)).foregroundStyle(pink)
                                .background(Circle().fill(.white).frame(width: 12, height: 12))
                                .offset(x: 3, y: 2)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Stay with Giulia").font(.system(size: 16, weight: .semibold))
                            Text("Superhost · 7 years hosting").font(.system(size: 13)).foregroundStyle(Color(hex: 0x6A6A6A))
                        }
                        Spacer()
                    }
                    .padding(.top, 2)
                    Rectangle().fill(hairline).frame(height: 1)
                    HStack(spacing: 8) {
                        Image(systemName: "diamond.fill").font(.system(size: 13)).foregroundStyle(pink)
                        Text("Rare find! This place is usually booked").font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(Color(hex: 0xF4F4F4), in: RoundedRectangle(cornerRadius: 8))
                    Spacer(minLength: 0)
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("$356").font(.system(size: 16, weight: .semibold)).underline()
                                Text("For 2 nights · Sep 5–7").font(.system(size: 13))
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                                Text("Free cancellation").font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 8).frame(height: 24)
                            .background(Color(hex: 0xF1F1F1), in: .capsule)
                        }
                        Spacer()
                        Text("Reserve").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 132, height: 48)
                            .background(pink, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(.top, 12)
                    .overlay(alignment: .top) { Rectangle().fill(hairline).frame(height: 1) }
                }
                .padding(.horizontal, 24).padding(.bottom, insets.bottom + 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white, in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
            }
        }
        .foregroundStyle(Color(hex: 0x222222))
    }
}

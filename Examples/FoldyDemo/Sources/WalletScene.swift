import SwiftUI

/// Apple Wallet: a stack of cards, then the gradient card with its balance and transactions.
struct WalletScene: View {
    let destination: Bool
    let insets: EdgeInsets

    var body: some View {
        ZStack {
            Color(hex: 0xF2F1F6).ignoresSafeArea()
            if destination {
                WalletCardDetail().sceneInsets(insets)
            } else {
                WalletStack().padding(.top, insets.top)
            }
        }
        .foregroundStyle(Color(hex: 0x1C1C1E))
    }
}

private struct CardDesign: Identifiable {
    enum Pattern { case plain, stripes, rings, facets, sheen }

    let id: String
    let name: String
    let detail: String
    let symbol: String?
    let colors: [Color]
    let ink: Color
    let pattern: Pattern

    static let foldy = CardDesign(id: "foldy", name: "", detail: "", symbol: "square.stack.3d.up.fill",
                                  colors: [Color(hex: 0xF9CD7E), Color(hex: 0xC9A6FF), Color(hex: 0xF6B25C)],
                                  ink: Color(hex: 0x3A3A3C), pattern: .sheen)

    static let stack: [CardDesign] = [
        CardDesign(id: "northwind", name: "Northwind", detail: "INFINITE", symbol: "hexagon.fill",
                   colors: [Color(hex: 0x0E1B3D), Color(hex: 0x1F3468)], ink: .white, pattern: .stripes),
        CardDesign(id: "platinum", name: "Northwind", detail: "PLATINUM", symbol: "hexagon.fill",
                   colors: [Color(hex: 0xEDEFF3), Color(hex: 0xC6CBD5)], ink: Color(hex: 0x1C1C1E), pattern: .facets),
        CardDesign(id: "meridian", name: "meridian", detail: "REWARDS", symbol: nil,
                   colors: [Color(hex: 0x1656B5), Color(hex: 0x2F7FDB)], ink: .white, pattern: .rings),
        CardDesign(id: "solace", name: "SOLACE", detail: "SIGNATURE", symbol: nil,
                   colors: [Color(hex: 0x0B2B6E), Color(hex: 0x143F8C)], ink: .white, pattern: .plain),
        CardDesign(id: "rose", name: "rosé", detail: "CASH BACK", symbol: nil,
                   colors: [Color(hex: 0xF7DDE3), Color(hex: 0xE8C1CC)], ink: Color(hex: 0x3A2A30), pattern: .plain),
        CardDesign(id: "pulse", name: "Pulse", detail: "BLACK", symbol: "bolt.fill",
                   colors: [Color(hex: 0x0A0A0A), Color(hex: 0x1C1C1E)], ink: Color(hex: 0xFF453A), pattern: .plain),
        CardDesign(id: "aster", name: "ASTER", detail: "PLATINUM", symbol: nil,
                   colors: [Color(hex: 0xEADFC9), Color(hex: 0xD6C6A6)], ink: Color(hex: 0x3E3524), pattern: .facets),
        CardDesign(id: "transit", name: "Transit", detail: "TAP TO RIDE", symbol: "tram.fill",
                   colors: [Color(hex: 0x8ED05C), Color(hex: 0x3E9A2F)], ink: .white, pattern: .plain),
        .foldy
    ]
}

private struct WalletCard: View {
    let design: CardDesign

    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(LinearGradient(colors: design.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay { pattern }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 8) {
                    if let symbol = design.symbol {
                        Image(systemName: symbol).font(.system(size: design.pattern == .sheen ? 22 : 17, weight: .semibold))
                    }
                    Text(design.name).font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Text(design.detail).font(.system(size: 11, weight: .semibold)).tracking(1.2)
                }
                .foregroundStyle(design.ink)
                .padding(.horizontal, 18).padding(.top, 15)
            }
        .overlay(alignment: .bottomTrailing) {
            if design.pattern == .sheen {
                HStack(spacing: -10) {
                    Circle().strokeBorder(design.ink.opacity(0.7), lineWidth: 1.5).frame(width: 30, height: 30)
                    Circle().strokeBorder(design.ink.opacity(0.7), lineWidth: 1.5).frame(width: 30, height: 30)
                }
                .padding(18)
            }
        }
        .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var pattern: some View {
        switch design.pattern {
        case .plain:
            Color.clear
        case .stripes:
            Canvas { context, size in
                for x in stride(from: -size.height, to: size.width, by: 14) {
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: size.height))
                    line.addLine(to: CGPoint(x: x + size.height, y: 0))
                    context.stroke(line, with: .color(.white.opacity(0.09)), lineWidth: 1)
                }
            }
        case .rings:
            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    Circle().strokeBorder(.white.opacity(0.13), lineWidth: 24)
                        .frame(width: 130 + CGFloat(index) * 110)
                }
            }
            .offset(x: 150, y: 110)
        case .facets:
            Canvas { context, size in
                let points: [[CGPoint]] = [
                    [CGPoint(x: 0, y: 0.2), CGPoint(x: 0.35, y: 0), CGPoint(x: 0.22, y: 0.55)],
                    [CGPoint(x: 0.22, y: 0.55), CGPoint(x: 0.35, y: 0), CGPoint(x: 0.7, y: 0.3)],
                    [CGPoint(x: 0.22, y: 0.55), CGPoint(x: 0.7, y: 0.3), CGPoint(x: 0.55, y: 1)],
                    [CGPoint(x: 0.7, y: 0.3), CGPoint(x: 1, y: 0.1), CGPoint(x: 1, y: 0.75)],
                    [CGPoint(x: 0.55, y: 1), CGPoint(x: 0.7, y: 0.3), CGPoint(x: 1, y: 0.75)]
                ]
                for (index, triangle) in points.enumerated() {
                    var path = Path()
                    path.move(to: CGPoint(x: triangle[0].x * size.width, y: triangle[0].y * size.height))
                    for point in triangle.dropFirst() {
                        path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                    }
                    path.closeSubpath()
                    context.fill(path, with: .color(.white.opacity(index.isMultiple(of: 2) ? 0.26 : 0.12)))
                }
            }
        case .sheen:
            ZStack {
                RadialGradient(colors: [.white.opacity(0.9), .white.opacity(0)],
                               center: .init(x: 0.12, y: 1.05), startRadius: 0, endRadius: 210)
                LinearGradient(colors: [.white.opacity(0), .white.opacity(0.34), .white.opacity(0)],
                               startPoint: .init(x: 0.35, y: 0), endPoint: .init(x: 0.75, y: 1))
                RadialGradient(colors: [Color(hex: 0xFF8A3D).opacity(0.5), .clear],
                               center: .init(x: 0.95, y: 0.35), startRadius: 0, endRadius: 200)
            }
        }
    }
}

private struct WalletStack: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("Wallet").font(.system(size: 34, weight: .bold))
                Spacer()
                ForEach(["plus", "magnifyingglass", "ellipsis"], id: \.self) { symbol in
                    Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40).background(.white, in: .circle)
                }
            }
            .padding(.horizontal, 20).padding(.top, 8)
            ZStack(alignment: .top) {
                ForEach(Array(CardDesign.stack.enumerated()), id: \.element.id) { index, design in
                    WalletCard(design: design).frame(height: 214).offset(y: CGFloat(index) * 44)
                }
            }
            .padding(.horizontal, 16).padding(.top, 20)
            Spacer(minLength: 0)
        }
    }
}

private struct WalletCardDetail: View {
    var body: some View {
        VStack(spacing: 14) {
            WalletCard(design: .foldy).frame(height: 200).padding(.top, 10)
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 12) {
                    WalletTile {
                        Text("Card Balance").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                        Text("US$12.94").font(.system(size: 26, weight: .semibold)).padding(.top, 2)
                        Text("US$11,337.06 Available").font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    WalletTile {
                        Text("Yearly Activity").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                        Text("+US$0.25 Daily Cash").font(.system(size: 13)).foregroundStyle(.secondary)
                        HStack(alignment: .bottom, spacing: 5) {
                            ForEach(0..<12, id: \.self) { index in
                                Capsule().fill(index == 3
                                    ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xB78CFF), Color(hex: 0xF7A54A)],
                                                                   startPoint: .top, endPoint: .bottom))
                                    : AnyShapeStyle(Color(hex: 0xE3E2E8)))
                                    .frame(width: 6, height: index == 3 ? 34 : 24)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                WalletTile {
                    Text("Payment Due").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                    Text("1 Apr").font(.system(size: 26, weight: .semibold)).padding(.top, 2)
                    Spacer(minLength: 0)
                    Text("Pay Early").font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(Color(hex: 0xEEEEF3), in: .capsule)
                }
                .frame(maxHeight: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Latest Card Transactions").font(.system(size: 20, weight: .bold))
                Spacer()
                Image(systemName: "line.3.horizontal.decrease").font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28).background(Color(hex: 0xE3E2E8), in: .circle)
            }
            .padding(.top, 6)
            VStack(spacing: 0) {
                TransactionRow(symbol: "cup.and.saucer.fill", tint: Color(hex: 0xA97BFF), name: "Blue Bottle Coffee",
                               detail: "Pending – San Francisco, CA", time: "22 minutes ago", amount: "US$6.23", cash: "2%")
                Divider().padding(.leading, 68)
                TransactionRow(symbol: "cart.fill", tint: Color(hex: 0xFFA43A), name: "Whole Foods Market",
                               detail: "Pending – San Francisco, CA", time: "25 minutes ago", amount: "US$41.71", cash: "2%")
                Divider().padding(.leading, 68)
                TransactionRow(symbol: "building.columns.fill", tint: Color(hex: 0xF25D9C), name: "Northstar Insurance",
                               detail: "Declined – Expired Card", detailColor: Color(hex: 0xE5484D), time: "7/8/25",
                               amount: "US$2,312.08", cash: nil, struck: true)
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }
}

private struct WalletTile<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TransactionRow: View {
    let symbol: String
    let tint: Color
    let name: String
    let detail: String
    var detailColor: Color = .secondary
    let time: String
    let amount: String
    let cash: String?
    var struck = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 40, height: 40).background(tint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 16, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(detailColor)
                Text(time).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(amount).font(.system(size: 15)).strikethrough(struck)
                    .foregroundStyle(struck ? Color.secondary : Color(hex: 0x1C1C1E))
                if let cash { Text(cash).font(.system(size: 12)).foregroundStyle(.secondary) }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

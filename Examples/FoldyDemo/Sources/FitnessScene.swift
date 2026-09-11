import SwiftUI

/// Gentler Streak: this week's activities, then a day of steps under a warm sun.
struct FitnessScene: View {
    let destination: Bool
    let insets: EdgeInsets

    var body: some View {
        if destination {
            StepsDetail(insets: insets)
        } else {
            ActivitiesOverview(insets: insets)
        }
    }
}

private let gentlePink = Color(hex: 0xE8556D)
private let gentleInk = Color(hex: 0x1D1D1F)
private let gentleGray = Color(hex: 0x8A8A8E)

private struct ActivitiesOverview: View {
    let insets: EdgeInsets

    var body: some View {
        ZStack {
            Color(hex: 0xF6F3EE).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("Activities").font(.system(size: 34, weight: .bold))
                    Spacer()
                    Image(systemName: "plus").font(.system(size: 17, weight: .semibold))
                        .frame(width: 38, height: 38).background(.white, in: .circle)
                    Image(systemName: "line.3.horizontal.decrease").font(.system(size: 15, weight: .semibold))
                        .frame(width: 38, height: 38).background(.white, in: .circle)
                    Circle().fill(Color(hex: 0xF08A3C)).frame(width: 38, height: 38)
                        .overlay(Image(systemName: "person.fill").font(.system(size: 16)).foregroundStyle(.white))
                }
                .padding(.top, 6)
                HStack(spacing: 4) {
                    ForEach(["Week", "Month", "Year", "All Time"], id: \.self) { label in
                        Text(label).font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity).frame(height: 32)
                            .background(label == "Week" ? .white : .clear, in: .capsule)
                    }
                }
                .padding(4).background(Color(hex: 0xEBE7E0), in: .capsule)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text("This Week").font(.system(size: 16, weight: .semibold))
                            Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                        }
                        Text("vs. LAST WEEK").font(.system(size: 11, weight: .semibold)).foregroundStyle(gentleGray)
                    }
                    Spacer()
                    Text("SHARE").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).frame(height: 30).background(gentleInk, in: .capsule)
                }
                .padding(.top, 4)
                ActivityChart().frame(height: 196)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Summary").font(.system(size: 20, weight: .bold))
                        Text("SUNDAY–MONDAY").font(.system(size: 11, weight: .semibold)).foregroundStyle(gentleGray)
                    }
                    Spacer()
                    HStack(spacing: 0) {
                        Image(systemName: "chart.bar.fill").font(.system(size: 12)).frame(width: 34, height: 26)
                            .background(.white, in: RoundedRectangle(cornerRadius: 7))
                        Image(systemName: "line.diagonal").font(.system(size: 12)).frame(width: 34, height: 26)
                    }
                    .padding(3).background(Color(hex: 0xEBE7E0), in: RoundedRectangle(cornerRadius: 9))
                }
                .padding(.top, 2)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    SummaryTile(title: "Duration", value: "1h 15m", detail: "0m", trend: "chevron.up")
                    SummaryTile(title: "Active Energy", value: "214 kcal", detail: "0kcal", trend: "chevron.up", filled: true)
                    SummaryTile(title: "Distance", value: "8 mi", detail: "0mi", trend: "chevron.up")
                    SummaryTile(title: "Elevation Gain", value: "0 ft", detail: "0ft", trend: "equal")
                }
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("History").font(.system(size: 20, weight: .bold))
                        Text("1 ACTIVITY").font(.system(size: 11, weight: .semibold)).foregroundStyle(gentleGray)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach([("star.fill", 0xF7C948), ("doc.text.fill", 0xF25C54), ("camera.fill", 0x5AA9E6),
                                 ("waveform", 0xE8556D)], id: \.0) { symbol, hex in
                            Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                                .frame(width: 26, height: 26).background(Color(hex: UInt32(hex)), in: .circle)
                        }
                    }
                }
                .padding(.top, 4)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20).padding(.top, insets.top)
            .foregroundStyle(gentleInk)
        }
    }
}

private struct ActivityChart: View {
    private let labels = ["Sun", "Mon", "Today", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: 6) {
            Canvas { context, size in
                let columns = CGFloat(labels.count)
                let step = (size.width - 34) / (columns - 1)
                func x(_ column: Int) -> CGFloat { CGFloat(column) * step }
                let topHeight = size.height * 0.56
                let bottomTop = size.height * 0.66
                let bottomHeight = size.height - bottomTop
                // Grid and scale for the top chart.
                for (index, label) in ["188", "144", "94", "47"].enumerated() {
                    let y = topHeight * CGFloat(index) / 4 + 2
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width - 34, y: y))
                    context.stroke(line, with: .color(Color(hex: 0xDDD8D0)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    context.draw(Text(label).font(.system(size: 9)).foregroundStyle(gentleGray),
                                 at: CGPoint(x: size.width - 14, y: y), anchor: .center)
                }
                // Last week: a soft S-curve that climbs from Tue to Fri.
                var lastWeek = Path()
                lastWeek.move(to: CGPoint(x: x(0), y: topHeight * 0.92))
                lastWeek.addLine(to: CGPoint(x: x(3), y: topHeight * 0.9))
                lastWeek.addCurve(to: CGPoint(x: x(5), y: topHeight * 0.18),
                                  control1: CGPoint(x: x(4), y: topHeight * 0.9), control2: CGPoint(x: x(4), y: topHeight * 0.18))
                lastWeek.addLine(to: CGPoint(x: x(7), y: topHeight * 0.16))
                context.stroke(lastWeek, with: .color(Color(hex: 0xC9C4BC)), lineWidth: 1.5)
                // This week: a steep climb into today.
                var thisWeek = Path()
                thisWeek.move(to: CGPoint(x: x(0), y: topHeight * 0.92))
                thisWeek.addLine(to: CGPoint(x: x(1), y: topHeight * 0.9))
                thisWeek.addLine(to: CGPoint(x: x(2), y: topHeight * 0.06))
                context.stroke(thisWeek, with: .color(gentlePink), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                let dot = CGRect(x: x(2) - 5, y: topHeight * 0.06 - 5, width: 10, height: 10)
                context.fill(Path(ellipseIn: dot), with: .color(.white))
                context.stroke(Path(ellipseIn: dot), with: .color(gentlePink), lineWidth: 2)
                // Bars: today's effort, a small one on Wednesday, and the target line.
                let today = CGRect(x: x(2) - 7, y: bottomTop, width: 14, height: bottomHeight)
                context.fill(Path(roundedRect: today, cornerRadius: 4), with: .color(gentlePink))
                let wednesday = CGRect(x: x(4) - 7, y: bottomTop + bottomHeight * 0.55, width: 14, height: bottomHeight * 0.45)
                context.fill(Path(roundedRect: wednesday, cornerRadius: 4), with: .color(Color(hex: 0xE4DFD7)))
                var target = Path()
                let targetY = bottomTop + bottomHeight * 0.45
                target.move(to: CGPoint(x: 0, y: targetY))
                target.addLine(to: CGPoint(x: size.width - 34, y: targetY))
                context.stroke(target, with: .color(Color(hex: 0xE5484D)), lineWidth: 1.5)
                context.draw(Text("107").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color(hex: 0xE5484D)),
                             at: CGPoint(x: size.width - 14, y: targetY), anchor: .center)
                context.draw(Text("kcal").font(.system(size: 9)).foregroundStyle(gentleGray),
                             at: CGPoint(x: size.width - 14, y: size.height - 4), anchor: .center)
            }
            HStack(spacing: 0) {
                ForEach(labels, id: \.self) { label in
                    Text(label).font(.system(size: 11, weight: label == "Today" ? .semibold : .regular))
                        .foregroundStyle(label == "Today" ? gentleInk : gentleGray)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.trailing, 34)
        }
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    let detail: String
    let trend: String
    var filled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13)).opacity(filled ? 0.9 : 0.7)
            HStack(spacing: 8) {
                Image(systemName: trend).font(.system(size: 12, weight: .bold))
                    .frame(width: 26, height: 26)
                    .background(filled ? .white.opacity(0.25) : Color(hex: 0xEFEBE4), in: .circle)
                Text(value).font(.system(size: 20, weight: .semibold))
            }
            Text(detail).font(.system(size: 12)).opacity(filled ? 0.85 : 0.6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(filled ? .white : gentleInk)
        .background(filled ? gentlePink : .white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct StepsDetail: View {
    let insets: EdgeInsets
    private let orange = Color(hex: 0xD8681E)
    private let days: [(String, String)] = [("T", "28"), ("W", "29"), ("T", "30"), ("F", "31"), ("S", "1"), ("S", "2"), ("M", "3")]

    var body: some View {
        ZStack {
            Color(hex: 0xFBF3DD).ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 3) {
                    Text("Steps").font(.system(size: 17, weight: .semibold))
                    HStack(spacing: 4) {
                        Text("Friday, October 31").font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(orange)
                }
                .padding(.top, 8)
                HStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        VStack(spacing: 8) {
                            Text(day.0).font(.system(size: 12, weight: .medium)).foregroundStyle(gentleGray)
                            Text(day.1).font(.system(size: 15, weight: .medium))
                                .frame(width: 34, height: 34)
                                .background(index == 3 ? gentleInk : .clear, in: .circle)
                                .foregroundStyle(index == 3 ? .white : gentleInk)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 16)
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: 0xF07F1F), Color(hex: 0xF5A94A), Color(hex: 0xF8D77A), Color(hex: 0xFBF3DD).opacity(0)],
                                             center: .center, startRadius: 0, endRadius: 170))
                        .frame(width: 340, height: 340)
                        .blur(radius: 14)
                    VStack(spacing: 10) {
                        Image(systemName: "shoeprints.fill").font(.system(size: 26)).foregroundStyle(orange)
                        Text("2,619").font(.system(size: 60, weight: .bold)).foregroundStyle(orange).tracking(-1)
                        HStack(spacing: 4) {
                            Image(systemName: "arrowtriangle.up.fill").font(.system(size: 9))
                            Text("Above Typical Friday").font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(orange)
                    }
                }
                .frame(height: 300)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], alignment: .leading, spacing: 14) {
                    StepStat(title: "Total Distance", value: "1", unit: "mi")
                    StepStat(title: "Total Duration", value: "0", unit: "h", value2: "25", unit2: "m")
                    StepStat(title: "Flights Climbed", value: "6", unit: "floors")
                    StepStat(title: "Walking Heart Rate", value: "–", unit: "bpm")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress").font(.system(size: 17, weight: .semibold))
                    Text("vs. typical Friday • 979 steps").font(.system(size: 12)).foregroundStyle(gentleGray)
                    ProgressChart().frame(height: 74).padding(.top, 4)
                }
                .padding(.top, 18)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20).sceneInsets(insets)
            .foregroundStyle(gentleInk)
        }
    }
}

private struct StepStat: View {
    let title: String
    let value: String
    let unit: String
    var value2: String?
    var unit2: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12)).foregroundStyle(gentleGray)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 24, weight: .semibold))
                Text(unit).font(.system(size: 13, weight: .medium))
                if let value2, let unit2 {
                    Text(value2).font(.system(size: 24, weight: .semibold)).padding(.leading, 4)
                    Text(unit2).font(.system(size: 13, weight: .medium))
                }
            }
        }
    }
}

private struct ProgressChart: View {
    var body: some View {
        Canvas { context, size in
            let width = size.width - 30
            for (index, label) in ["2K", "1K"].enumerated() {
                let y = size.height * (0.12 + CGFloat(index) * 0.42)
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: width, y: y))
                context.stroke(line, with: .color(Color(hex: 0xE3D9C3)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                context.draw(Text(label).font(.system(size: 9)).foregroundStyle(gentleGray),
                             at: CGPoint(x: size.width - 12, y: y), anchor: .center)
            }
            var typical = Path()
            typical.move(to: CGPoint(x: 0, y: size.height * 0.98))
            typical.addCurve(to: CGPoint(x: width, y: size.height * 0.56),
                             control1: CGPoint(x: width * 0.4, y: size.height * 0.98),
                             control2: CGPoint(x: width * 0.7, y: size.height * 0.6))
            context.stroke(typical, with: .color(Color(hex: 0xCFC7B6)), lineWidth: 1.5)
            var steps = Path()
            steps.move(to: CGPoint(x: 0, y: size.height * 0.98))
            steps.addLine(to: CGPoint(x: width * 0.32, y: size.height * 0.96))
            steps.addLine(to: CGPoint(x: width * 0.42, y: size.height * 0.8))
            steps.addLine(to: CGPoint(x: width * 0.6, y: size.height * 0.78))
            steps.addLine(to: CGPoint(x: width * 0.72, y: size.height * 0.5))
            steps.addLine(to: CGPoint(x: width * 0.84, y: size.height * 0.46))
            steps.addLine(to: CGPoint(x: width, y: size.height * 0.04))
            context.stroke(steps, with: .color(Color(hex: 0xF2B632)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
    }
}

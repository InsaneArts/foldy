import SwiftUI

/// Apple Weather: a dark list of cities, then the full-bleed forecast for one of them.
struct WeatherScene: View {
    let destination: Bool
    let insets: EdgeInsets

    var body: some View {
        if destination {
            WeatherDetail(insets: insets)
        } else {
            WeatherList(insets: insets)
        }
    }
}

private struct City: Identifiable {
    enum Sky { case clouds, night, sunny, dusk }
    let name: String
    let detail: String
    let condition: String
    let temperature: Int
    let high: Int
    let low: Int
    let sky: Sky
    var id: String { name }
}

private struct WeatherList: View {
    let insets: EdgeInsets
    private let cities = [
        City(name: "Los Angeles", detail: "My Location", condition: "Cloudy", temperature: 17, high: 23, low: 13, sky: .clouds),
        City(name: "Tokyo", detail: "1:17 AM", condition: "Clear", temperature: 18, high: 24, low: 16, sky: .night),
        City(name: "Melbourne", detail: "3:17 PM", condition: "Mostly Sunny", temperature: 27, high: 28, low: 14, sky: .sunny),
        City(name: "Lisbon", detail: "5:17 PM", condition: "Sunny", temperature: 29, high: 30, low: 21, sky: .dusk)
    ]

    var body: some View {
        ZStack {
            Color(hex: 0x1C1C1E).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Weather").font(.system(size: 34, weight: .bold))
                    Spacer()
                    Image(systemName: "ellipsis").font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34).background(.white.opacity(0.14), in: .circle)
                }
                .padding(.top, 8).padding(.bottom, 6)
                ForEach(cities) { CityCard(city: $0) }
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Text("Learn more about ").foregroundStyle(.white.opacity(0.45))
                    Text("weather data").underline().foregroundStyle(.white.opacity(0.7))
                    Text(" and ").foregroundStyle(.white.opacity(0.45))
                    Text("map data").underline().foregroundStyle(.white.opacity(0.7))
                }
                .font(.system(size: 12)).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16).sceneInsets(insets)
            .foregroundStyle(.white)
        }
    }
}

private struct CityCard: View {
    let city: City

    var body: some View {
        ZStack {
            sky
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name).font(.system(size: 24, weight: .semibold))
                    Text(city.detail).font(.system(size: 13, weight: .medium)).opacity(0.9)
                    Spacer(minLength: 0)
                    Text(city.condition).font(.system(size: 13, weight: .medium))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(city.temperature)°").font(.system(size: 52, weight: .light)).padding(.top, -8)
                    Spacer(minLength: 0)
                    Text("H:\(city.high)° L:\(city.low)°").font(.system(size: 13, weight: .medium))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        }
        .frame(height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder private var sky: some View {
        switch city.sky {
        case .clouds:
            ScenePhoto(name: "Clouds", alignment: .top).overlay(Color.black.opacity(0.12))
        case .night:
            ScenePhoto(name: "Night", alignment: .bottom)
                .overlay(LinearGradient(colors: [Color(hex: 0x0B1830).opacity(0.5), .clear], startPoint: .top, endPoint: .bottom))
        case .sunny:
            LinearGradient(colors: [Color(hex: 0x2E79D2), Color(hex: 0x86C2F5)], startPoint: .top, endPoint: .bottom)
                .overlay(RadialGradient(colors: [.white.opacity(0.55), .clear], center: .init(x: 0.9, y: 0.1),
                                        startRadius: 0, endRadius: 150))
        case .dusk:
            LinearGradient(colors: [Color(hex: 0x3A5CAB), Color(hex: 0xC97F63), Color(hex: 0xE9A85C)],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

private struct Hour: Identifiable {
    let label: String
    let symbol: String
    let value: String
    var id: String { label }
}

private struct Day: Identifiable {
    let name: String
    let symbol: String
    let chance: String?
    let low: Int
    let high: Int
    var id: String { name }
}

private struct WeatherDetail: View {
    let insets: EdgeInsets
    private let hours = [
        Hour(label: "6PM", symbol: "cloud.fill", value: "22°"),
        Hour(label: "7PM", symbol: "cloud.fill", value: "20°"),
        Hour(label: "7:12PM", symbol: "sunset.fill", value: "Sunset"),
        Hour(label: "8PM", symbol: "cloud.fill", value: "19°"),
        Hour(label: "9PM", symbol: "cloud.fill", value: "19°"),
        Hour(label: "10PM", symbol: "cloud.fill", value: "18°")
    ]
    private let days = [
        Day(name: "Today", symbol: "cloud.fill", chance: nil, low: 13, high: 25),
        Day(name: "Tue", symbol: "cloud.rain.fill", chance: "60%", low: 16, high: 21),
        Day(name: "Wed", symbol: "sun.max.fill", chance: nil, low: 14, high: 21),
        Day(name: "Thu", symbol: "cloud.sun.fill", chance: nil, low: 15, high: 23),
        Day(name: "Fri", symbol: "sun.max.fill", chance: nil, low: 16, high: 26)
    ]

    var body: some View {
        ZStack {
            ScenePhoto(name: "Clouds", alignment: .top).ignoresSafeArea()
                .overlay(Color.black.opacity(0.14))
            VStack(spacing: 10) {
                VStack(spacing: 0) {
                    Text("Los Angeles").font(.system(size: 34))
                    Text("24°").font(.system(size: 102, weight: .thin)).padding(.leading, 18).padding(.vertical, -10)
                    Text("Cloudy").font(.system(size: 20, weight: .medium)).opacity(0.85)
                    Text("H:25° L:13°").font(.system(size: 20, weight: .medium)).padding(.top, 2)
                }
                .padding(.top, 8)
                Spacer(minLength: 4)
                WeatherCard {
                    Text("Cloudy conditions will continue for the rest of the day. Wind gusts are up to 10 mph.")
                        .font(.system(size: 15)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    hairline
                    HStack(spacing: 0) {
                        ForEach(hours) { hour in
                            VStack(spacing: 8) {
                                Text(hour.label).font(.system(size: 14, weight: .semibold))
                                Image(systemName: hour.symbol).font(.system(size: 20)).symbolRenderingMode(.multicolor)
                                    .frame(height: 24)
                                Text(hour.value).font(.system(size: hour.value == "Sunset" ? 16 : 20, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                WeatherCard {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar").font(.system(size: 12, weight: .semibold))
                        Text("10-DAY FORECAST").font(.system(size: 13, weight: .semibold)).tracking(0.4)
                    }
                    .opacity(0.65)
                    hairline
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        HStack(spacing: 0) {
                            Text(day.name).font(.system(size: 20, weight: .medium)).frame(width: 66, alignment: .leading)
                            VStack(spacing: 0) {
                                Image(systemName: day.symbol).font(.system(size: 20)).symbolRenderingMode(.multicolor)
                                if let chance = day.chance {
                                    Text(chance).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(hex: 0x7ED6FF))
                                }
                            }
                            .frame(width: 44)
                            Text("\(day.low)°").font(.system(size: 20, weight: .medium)).opacity(0.6)
                                .frame(width: 48, alignment: .trailing)
                            TemperatureBar(low: day.low, high: day.high).frame(height: 5).padding(.horizontal, 12)
                            Text("\(day.high)°").font(.system(size: 20, weight: .medium)).frame(width: 40, alignment: .trailing)
                        }
                        .frame(height: 40)
                        if index < days.count - 1 { hairline }
                    }
                }
            }
            .padding(.horizontal, 16).sceneInsets(insets)
            .foregroundStyle(.white)
        }
    }

    private var hairline: some View {
        Rectangle().fill(.white.opacity(0.25)).frame(height: 0.5)
    }
}

private struct TemperatureBar: View {
    let low: Int
    let high: Int
    private let range: ClosedRange<Double> = 10...30

    var body: some View {
        GeometryReader { proxy in
            let span = range.upperBound - range.lowerBound
            let start = (Double(low) - range.lowerBound) / span
            let end = (Double(high) - range.lowerBound) / span
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.22))
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: 0x5CC8F5), Color(hex: 0xF7D65E), Color(hex: 0xF2A24A)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * (end - start))
                    .offset(x: proxy.size.width * start)
            }
        }
    }
}

private struct WeatherCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.1)))
    }
}

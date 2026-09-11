import SwiftUI
import UIKit

/// Apple Wallet passes: a native UIKit boarding pass, then its flight details.
/// Kept in UIKit so the demo proves hierarchy capture of a real UIKit view tree.
struct BoardingScene: UIViewRepresentable {
    let destination: Bool
    let insets: EdgeInsets

    func makeUIView(context: Context) -> BoardingPassView { BoardingPassView() }

    func updateUIView(_ view: BoardingPassView, context: Context) {
        view.configure(destination: destination, topInset: insets.top)
    }
}

final class BoardingPassView: UIView {
    private static let ink = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    private static let gray = UIColor(red: 0.43, green: 0.43, blue: 0.45, alpha: 1)
    private static let hairline = UIColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1)
    private static let red = UIColor(red: 0.84, green: 0.10, blue: 0.13, alpha: 1)

    private let card = UIView()
    private let front = UIStackView()
    private let back = UIStackView()
    private var topConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
        card.backgroundColor = .white
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowRadius = 14
        card.layer.shadowOffset = CGSize(width: 0, height: 6)
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        for stack in [front, back] {
            stack.axis = .vertical
            stack.spacing = 18
            stack.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
                stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
                stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
                stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22)
            ])
        }
        let top = card.topAnchor.constraint(equalTo: topAnchor, constant: 12)
        topConstraint = top
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            top
        ])
        buildFront()
        buildBack()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(frame:).") }

    func configure(destination: Bool, topInset: CGFloat) {
        front.isHidden = destination
        back.isHidden = !destination
        topConstraint?.constant = topInset + 12
    }

    // MARK: Front of the pass

    private func buildFront() {
        let logo = UILabel()
        logo.text = "FOLD\nAIR"
        logo.numberOfLines = 2
        logo.textAlignment = .center
        logo.font = .systemFont(ofSize: 10, weight: .heavy)
        logo.textColor = .white
        logo.backgroundColor = Self.red
        logo.layer.cornerRadius = 8
        logo.layer.cornerCurve = .continuous
        logo.clipsToBounds = true
        logo.widthAnchor.constraint(equalToConstant: 46).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 46).isActive = true
        let header = row([logo, UIView(), field("SEAT", "12A", size: 16), field("GATE", "B20", size: 24)],
                         spacing: 18, alignment: .top)
        header.setCustomSpacing(0, after: logo)

        let plane = UIImageView(image: UIImage(systemName: "airplane",
                                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)))
        plane.tintColor = Self.ink
        plane.setContentHuggingPriority(.required, for: .horizontal)
        let route = row([field("TBILISI", "TBS", size: 40, weight: .bold), UIView(), plane, UIView(),
                         field("LISBON", "LIS", size: 40, weight: .bold, alignment: .right)], spacing: 8, alignment: .center)

        let details = row([field("DEPARTS", "12 Dec, 10:15"), field("GROUP", "E"), field("FLIGHT", "FA0352"),
                           field("CLASS", "Economy")], spacing: 0, alignment: .top)
        details.distribution = .equalSpacing
        let passenger = row([field("PASSENGER", "A. TRAVELLER"), field("SEQ", "0057"), field("SMART GATE", "Eligible")],
                            spacing: 0, alignment: .top)
        passenger.distribution = .equalSpacing

        let code = QRCodeView()
        code.translatesAutoresizingMaskIntoConstraints = false
        code.widthAnchor.constraint(equalToConstant: 168).isActive = true
        code.heightAnchor.constraint(equalToConstant: 168).isActive = true
        let codeRow = row([UIView(), code, UIView()], spacing: 0, alignment: .center)

        for view in [header, route, details, passenger, codeRow] { front.addArrangedSubview(view) }
        front.setCustomSpacing(26, after: passenger)
    }

    // MARK: Back of the pass

    private func buildBack() {
        let title = label("Flight details", size: 22, weight: .bold)
        let subtitle = label("Fold Air · FA0352 · Friday 12 Dec", size: 13, color: Self.gray)
        let heading = UIStackView(arrangedSubviews: [title, subtitle])
        heading.axis = .vertical
        heading.spacing = 4

        let timeline = UIStackView(arrangedSubviews: [
            timelineRow("09:35", "Boarding begins", "Gate B20 · Terminal 2", position: .first),
            timelineRow("10:15", "Departs Tbilisi", "TBS · Shota Rustaveli International", position: .middle),
            timelineRow("14:50", "Arrives Lisbon", "LIS · Humberto Delgado Airport", position: .last)
        ])
        timeline.axis = .vertical
        timeline.spacing = 0

        let facts = UIStackView(arrangedSubviews: [
            row([field("BAGGAGE", "1 × 23 kg"), field("SEAT", "12A · Window")], spacing: 0, alignment: .top),
            row([field("CLASS", "Economy"), field("STATUS", "On time", color: UIColor(red: 0.2, green: 0.68, blue: 0.35, alpha: 1))],
                spacing: 0, alignment: .top)
        ])
        facts.axis = .vertical
        facts.spacing = 16
        for case let stack as UIStackView in facts.arrangedSubviews { stack.distribution = .fillEqually }

        let boarding = label("Boarding in 42 min", size: 15, weight: .semibold)
        let track = UIView()
        track.backgroundColor = Self.hairline
        track.layer.cornerRadius = 3
        track.translatesAutoresizingMaskIntoConstraints = false
        track.heightAnchor.constraint(equalToConstant: 6).isActive = true
        let fill = UIView()
        fill.backgroundColor = Self.ink
        fill.layer.cornerRadius = 3
        fill.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(fill)
        NSLayoutConstraint.activate([
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: 0.62)
        ])
        let progress = UIStackView(arrangedSubviews: [boarding, track])
        progress.axis = .vertical
        progress.spacing = 10

        for view in [heading, divider(), timeline, divider(), facts, divider(), progress] { back.addArrangedSubview(view) }
    }

    // MARK: Building blocks

    private func label(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = ink) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func field(_ caption: String, _ value: String, size: CGFloat = 14, weight: UIFont.Weight = .regular,
                       alignment: NSTextAlignment = .left, color: UIColor = ink) -> UIStackView {
        let top = UILabel()
        top.attributedText = NSAttributedString(string: caption, attributes: [.kern: 0.8])
        top.font = .systemFont(ofSize: 9, weight: .semibold)
        top.textColor = Self.gray
        top.textAlignment = alignment
        let bottom = label(value, size: size, weight: weight, color: color)
        bottom.textAlignment = alignment
        let stack = UIStackView(arrangedSubviews: [top, bottom])
        stack.axis = .vertical
        stack.spacing = size > 20 ? 0 : 3
        return stack
    }

    private func row(_ views: [UIView], spacing: CGFloat, alignment: UIStackView.Alignment) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.spacing = spacing
        stack.alignment = alignment
        return stack
    }

    private func divider() -> UIView {
        let line = UIView()
        line.backgroundColor = Self.hairline
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    private func timelineRow(_ time: String, _ title: String, _ detail: String, position: TimelineRail.Position) -> UIView {
        let rail = TimelineRail(position: position)
        rail.translatesAutoresizingMaskIntoConstraints = false
        rail.widthAnchor.constraint(equalToConstant: 18).isActive = true
        let clock = label(time, size: 15, weight: .semibold)
        clock.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        clock.translatesAutoresizingMaskIntoConstraints = false
        clock.widthAnchor.constraint(equalToConstant: 54).isActive = true
        let text = UIStackView(arrangedSubviews: [label(title, size: 15, weight: .medium), label(detail, size: 13, color: Self.gray)])
        text.axis = .vertical
        text.spacing = 2
        let content = row([clock, text], spacing: 10, alignment: .top)
        content.isLayoutMarginsRelativeArrangement = true
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 18, trailing: 0)
        return row([rail, content], spacing: 10, alignment: .fill)
    }
}

/// A dot on a vertical rail, drawn so consecutive rows join into one line.
private final class TimelineRail: UIView {
    enum Position { case first, middle, last }
    private let position: Position

    init(position: Position) {
        self.position = position
        super.init(frame: .zero)
        isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(position:).") }

    override func draw(_ rect: CGRect) {
        let ink = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        let centerX = bounds.midX
        let dotY: CGFloat = 9
        let line = UIBezierPath()
        line.move(to: CGPoint(x: centerX, y: position == .first ? dotY : 0))
        line.addLine(to: CGPoint(x: centerX, y: position == .last ? dotY : bounds.height))
        line.lineWidth = 1.5
        UIColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1).setStroke()
        line.stroke()
        let dot = UIBezierPath(ovalIn: CGRect(x: centerX - 5, y: dotY - 5, width: 10, height: 10))
        if position == .middle {
            UIColor.white.setFill()
            dot.fill()
            dot.lineWidth = 2
            ink.setStroke()
            dot.stroke()
        } else {
            ink.setFill()
            dot.fill()
        }
    }
}

/// A QR-style code with finder patterns and deterministic data modules. Decorative only.
private final class QRCodeView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(frame:).") }

    override func draw(_ rect: CGRect) {
        let modules = 29
        let unit = bounds.width / CGFloat(modules)
        var seed: UInt32 = 0x5EED_F01D
        func bit() -> Bool {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return (seed >> 16) & 1 == 1
        }
        func inFinder(_ x: Int, _ y: Int) -> Bool {
            let corners = [(0, 0), (modules - 7, 0), (0, modules - 7)]
            return corners.contains { x >= $0.0 && x < $0.0 + 7 && y >= $0.1 && y < $0.1 + 7 }
        }
        func finderModule(_ x: Int, _ y: Int) -> Bool {
            let corners = [(0, 0), (modules - 7, 0), (0, modules - 7)]
            guard let corner = corners.first(where: { x >= $0.0 && x < $0.0 + 7 && y >= $0.1 && y < $0.1 + 7 }) else { return false }
            let dx = x - corner.0, dy = y - corner.1
            let ring = max(abs(dx - 3), abs(dy - 3))
            return ring == 3 || ring <= 1
        }
        UIColor(white: 0.08, alpha: 1).setFill()
        for y in 0..<modules {
            for x in 0..<modules {
                let filled = inFinder(x, y) ? finderModule(x, y) : bit()
                guard filled else { continue }
                UIRectFill(CGRect(x: CGFloat(x) * unit, y: CGFloat(y) * unit, width: unit + 0.3, height: unit + 0.3))
            }
        }
    }
}

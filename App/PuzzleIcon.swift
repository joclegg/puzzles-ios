import SwiftUI
import UIKit

enum PuzzleIcon {
    private struct Glyph {
        let filled: Bool
        let paths: [String]
    }

    private static let glyphs: [String: Glyph] = [
        "arrow.clockwise": Glyph(filled: false, paths: ["M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8", "M3 3v5h5"]),
        "arrow.uturn.backward": Glyph(filled: false, paths: ["M9 14L4 9l5-5", "M4 9h10.5a5.5 5.5 0 0 1 0 11H11"]),
        "arrow.uturn.forward": Glyph(filled: false, paths: ["M15 14l5-5-5-5", "M20 9H9.5a5.5 5.5 0 0 0 0 11H13"]),
        "book.fill": Glyph(
            filled: false, paths: ["M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z", "M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"]),
        "calendar": Glyph(
            filled: false,
            paths: [
                "M8 2v4", "M16 2v4", "M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z", "M3 10h18", "M8 14h.01",
                "M12 14h.01", "M16 14h.01", "M8 18h.01", "M12 18h.01", "M16 18h.01",
            ]),
        "calendar.badge.clock": Glyph(
            filled: false,
            paths: [
                "M8 2v4", "M16 2v4", "M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z", "M3 10h18", "M9 16l2 2 4-4",
            ]),
        "chart.bar": Glyph(filled: false, paths: ["M3 3v18h18", "M18 17V9", "M13 17V5", "M8 17v-3"]),
        "checkmark": Glyph(filled: false, paths: ["M20 6L9 17l-5-5"]),
        "chevron.backward": Glyph(filled: false, paths: ["M15 5l-7 7 7 7"]),
        "chevron.forward": Glyph(filled: false, paths: ["M9 18l6-6-6-6"]),
        "chevron.left": Glyph(filled: false, paths: ["M15 5l-7 7 7 7"]),
        "chevron.right": Glyph(filled: false, paths: ["M9 18l6-6-6-6"]),
        "clock.arrow.circlepath": Glyph(
            filled: false, paths: ["M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8", "M3 3v5h5", "M12 7v5l4 2"]),
        "delete.left": Glyph(filled: false, paths: ["M9 5h11v14H9l-6-7z", "M12 9l5 6", "M17 9l-5 6"]),
        "ellipsis": Glyph(
            filled: false, paths: ["M12 4.8a1.2 1.2 0 1 0 0.01 0z", "M12 10.8a1.2 1.2 0 1 0 0.01 0z", "M12 16.8a1.2 1.2 0 1 0 0.01 0z"]),
        "eraser": Glyph(
            filled: false,
            paths: [
                "M8.5 19L3.8 14.3a1.5 1.5 0 0 1 0-2.1L12.2 3.8a1.5 1.5 0 0 1 2.1 0L20.2 9.7a1.5 1.5 0 0 1 0 2.1L12.9 19z", "M7.5 8.5l8 8",
                "M12.9 19H20",
            ]),
        "gearshape": Glyph(
            filled: false,
            paths: [
                "M19.14 12.94c.04-.3.06-.61.06-.94s-.02-.64-.07-.94l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.49.49 0 0 0-.59-.22l-2.39.96a7 7 0 0 0-1.62-.94l-.36-2.54a.48.48 0 0 0-.48-.41h-3.84a.47.47 0 0 0-.47.41l-.36 2.54a7.3 7.3 0 0 0-1.62.94l-2.39-.96a.48.48 0 0 0-.59.22L2.74 8.87a.47.47 0 0 0 .12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54a7 7 0 0 0 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32a.48.48 0 0 0-.12-.61z",
                "M12 8.6a3.4 3.4 0 1 1 0 6.8a3.4 3.4 0 1 1 0-6.8z",
            ]),
        "lightbulb": Glyph(filled: false, paths: ["M9 18h6", "M10 21h4", "M12 3a6 6 0 0 0-3.5 10.9V16h7v-2.1A6 6 0 0 0 12 3z"]),
        "paintbrush.pointed": Glyph(
            filled: true,
            paths: [
                "M7 14c-1.66 0-3 1.34-3 3 0 1.31-1.16 2-2 2 .92 1.22 2.49 2 4 2 2.21 0 4-1.79 4-4 0-1.66-1.34-3-3-3z",
                "M20.71 4.63l-1.34-1.34c-.39-.39-1.02-.39-1.41 0L9 12.25 11.75 15l8.96-8.96c.39-.39.39-1.02 0-1.41z",
            ]),
        "pencil": Glyph(filled: false, paths: ["M4 20l1-4L15.5 5.5a2.1 2.1 0 0 1 3 3L8 19z", "M13.5 7.5l3 3"]),
        "play.fill": Glyph(filled: true, paths: ["M7 4.5v15a1 1 0 0 0 1.5.86l12-7.5a1 1 0 0 0 0-1.72l-12-7.5A1 1 0 0 0 7 4.5z"]),
        "questionmark.circle": Glyph(
            filled: false,
            paths: ["M12 21a9 9 0 1 0 0-18a9 9 0 1 0 0 18z", "M9.5 9a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6v.6", "M12 17h.01"]),
        "slider.horizontal.3": Glyph(
            filled: false,
            paths: ["M21 4h-7", "M10 4H3", "M21 12h-9", "M8 12H3", "M21 20h-5", "M12 20H3", "M14 2v4", "M8 10v4", "M16 18v4"]),
        "square.and.arrow.up": Glyph(filled: false, paths: ["M12 3v12", "M7 8l5-5 5 5", "M5 14v5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-5"]),
        "trophy": Glyph(
            filled: false,
            paths: [
                "M6 9H4.5a2.5 2.5 0 0 1 0-5H6", "M18 9h1.5a2.5 2.5 0 0 0 0-5H18", "M4 22h16",
                "M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22", "M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22",
                "M18 2H6v7a6 6 0 0 0 12 0V2z",
            ]),
        "trophy.fill": Glyph(
            filled: false,
            paths: [
                "M6 9H4.5a2.5 2.5 0 0 1 0-5H6", "M18 9h1.5a2.5 2.5 0 0 0 0-5H18", "M4 22h16",
                "M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22", "M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22",
                "M18 2H6v7a6 6 0 0 0 12 0V2z",
            ]),
    ]

    static func image(_ name: String) -> Image {
        guard let glyph = glyphs[name] else {
            return Image(systemName: name)
        }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let rendered = renderer.image { _ in
            UIColor.black.setFill()
            UIColor.black.setStroke()
            for text in glyph.paths {
                let path = SVGPath.parse(text)
                if glyph.filled {
                    path.fill()
                } else {
                    path.lineWidth = 2
                    path.lineCapStyle = .round
                    path.lineJoinStyle = .round
                    path.stroke()
                }
            }
        }
        return Image(uiImage: rendered.withRenderingMode(.alwaysTemplate))
    }
}

enum SVGPath {
    static func parse(_ text: String) -> UIBezierPath {
        let path = UIBezierPath()
        var scanner = Tokens(text)
        var command: Character = "M"
        var current = CGPoint.zero
        var start = CGPoint.zero
        var control = CGPoint.zero
        var previous: Character = "M"
        while let next = scanner.nextCommand(fallback: command) {
            command = next
            let relative = command.isLowercase
            let base = relative ? current : .zero
            func point() -> CGPoint {
                let x = scanner.number()
                let y = scanner.number()
                return CGPoint(x: base.x + x, y: base.y + y)
            }
            switch Character(command.uppercased()) {
            case "M":
                current = point()
                start = current
                path.move(to: current)
                command = relative ? "l" : "L"
            case "L":
                current = point()
                path.addLine(to: current)
            case "H":
                current.x = base.x + scanner.number()
                path.addLine(to: current)
            case "V":
                current.y = base.y + scanner.number()
                path.addLine(to: current)
            case "C":
                let first = point()
                control = point()
                current = point()
                path.addCurve(to: current, controlPoint1: first, controlPoint2: control)
            case "S":
                let isCurve = "CcSs".contains(previous)
                let first = isCurve ? CGPoint(x: 2 * current.x - control.x, y: 2 * current.y - control.y) : current
                control = point()
                current = point()
                path.addCurve(to: current, controlPoint1: first, controlPoint2: control)
            case "Q":
                control = point()
                current = point()
                path.addQuadCurve(to: current, controlPoint: control)
            case "A":
                let rx = scanner.number()
                let ry = scanner.number()
                let rotation = scanner.number()
                let large = scanner.flag()
                let sweep = scanner.flag()
                let end = point()
                addArc(path, from: current, to: end, rx: rx, ry: ry, degrees: rotation, large: large, sweep: sweep)
                current = end
            case "Z":
                path.close()
                current = start
            default:
                return path
            }
            previous = next
        }
        return path
    }

    private static func addArc(
        _ path: UIBezierPath, from: CGPoint, to: CGPoint, rx: CGFloat, ry: CGFloat, degrees: CGFloat, large: Bool, sweep: Bool
    ) {
        if from == to {
            return
        }
        if rx == 0 || ry == 0 {
            path.addLine(to: to)
            return
        }
        var rx = abs(rx)
        var ry = abs(ry)
        let phi = degrees * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        let dx = (from.x - to.x) / 2
        let dy = (from.y - to.y) / 2
        let x1 = cosPhi * dx + sinPhi * dy
        let y1 = -sinPhi * dx + cosPhi * dy
        let scale = x1 * x1 / (rx * rx) + y1 * y1 / (ry * ry)
        if scale > 1 {
            rx *= sqrt(scale)
            ry *= sqrt(scale)
        }
        let numerator = max(0, rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1)
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        let factor = (large == sweep ? -1 : 1) * sqrt(numerator / denominator)
        let cx1 = factor * rx * y1 / ry
        let cy1 = -factor * ry * x1 / rx
        let cx = cosPhi * cx1 - sinPhi * cy1 + (from.x + to.x) / 2
        let cy = sinPhi * cx1 + cosPhi * cy1 + (from.y + to.y) / 2
        let startAngle = atan2((y1 - cy1) / ry, (x1 - cx1) / rx)
        var delta = atan2((-y1 - cy1) / ry, (-x1 - cx1) / rx) - startAngle
        if sweep && delta < 0 {
            delta += 2 * .pi
        } else if !sweep && delta > 0 {
            delta -= 2 * .pi
        }
        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let step = delta / CGFloat(segments)
        let handle = 4.0 / 3.0 * tan(step / 4)
        func onEllipse(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: cx + cosPhi * rx * x - sinPhi * ry * y, y: cy + sinPhi * rx * x + cosPhi * ry * y)
        }
        for index in 0..<segments {
            let a = startAngle + CGFloat(index) * step
            let b = a + step
            path.addCurve(
                to: index == segments - 1 ? to : onEllipse(cos(b), sin(b)),
                controlPoint1: onEllipse(cos(a) - handle * sin(a), sin(a) + handle * cos(a)),
                controlPoint2: onEllipse(cos(b) + handle * sin(b), sin(b) - handle * cos(b))
            )
        }
    }

    private struct Tokens {
        private let characters: [Character]
        private var index = 0

        init(_ text: String) {
            characters = Array(text)
        }

        private mutating func skipSeparators() {
            while index < characters.count, characters[index] == " " || characters[index] == "," {
                index += 1
            }
        }

        mutating func nextCommand(fallback: Character) -> Character? {
            skipSeparators()
            guard index < characters.count else {
                return nil
            }
            if characters[index].isLetter {
                index += 1
                return characters[index - 1]
            }
            return fallback
        }

        mutating func flag() -> Bool {
            skipSeparators()
            index += 1
            return characters[index - 1] == "1"
        }

        mutating func number() -> CGFloat {
            skipSeparators()
            let begin = index
            if index < characters.count, characters[index] == "-" || characters[index] == "+" {
                index += 1
            }
            var seenDot = false
            while index < characters.count {
                let character = characters[index]
                if character == "." {
                    if seenDot {
                        break
                    }
                    seenDot = true
                } else if !character.isNumber {
                    break
                }
                index += 1
            }
            return CGFloat(Double(String(characters[begin..<index])) ?? 0)
        }
    }
}

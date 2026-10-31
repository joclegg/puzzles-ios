public enum SlideOutLevel: Int, CaseIterable, Sendable {
    case beginner
    case easy
    case medium
    case hard
    case expert

    public var moves: ClosedRange<Int> {
        switch self {
        case .beginner:
            4...9
        case .easy:
            10...16
        case .medium:
            17...24
        case .hard:
            25...32
        case .expert:
            33...60
        }
    }

    public var name: String {
        switch self {
        case .beginner:
            "BEGINNER"
        case .easy:
            "EASY"
        case .medium:
            "MEDIUM"
        case .hard:
            "HARD"
        case .expert:
            "EXPERT"
        }
    }

    public static func named(_ name: String) -> SlideOutLevel {
        allCases.first { $0.name == name } ?? .expert
    }

    public static func atSize(_ size: Int) -> SlideOutLevel {
        allCases[min(size, allCases.count - 1)]
    }
}

public struct SlideOutPuzzle: Hashable, Sendable {
    public var board: SlideOutBoard
    public var par: Int

    public init(board: SlideOutBoard, par: Int) {
        self.board = board
        self.par = par
    }

    public func encode() -> String {
        "\(par);\(board.encode())"
    }

    public static func decode(_ text: String) throws -> SlideOutPuzzle {
        let parts = text.split(separator: ";", omittingEmptySubsequences: false)
        guard parts.count >= 2, let par = Int(parts[0]) else {
            throw SlideOutDecodeError.malformed(text)
        }
        return SlideOutPuzzle(board: try SlideOutBoard.decode(String(parts[1])), par: par)
    }
}

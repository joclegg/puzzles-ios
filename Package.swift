// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Puzzles",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "PuzzlesCore", targets: ["PuzzlesCore"]),
        .library(name: "PuzzlesSync", targets: ["PuzzlesSync"]),
        .library(name: "FiveLettersEngine", targets: ["FiveLettersEngine"]),
        .library(name: "SudokuEngine", targets: ["SudokuEngine"]),
        .library(name: "SolitaireEngine", targets: ["SolitaireEngine"]),
        .library(name: "TwoToneEngine", targets: ["TwoToneEngine"]),
        .library(name: "SightlinesEngine", targets: ["SightlinesEngine"]),
        .library(name: "KakuroEngine", targets: ["KakuroEngine"]),
        .library(name: "SlideOutEngine", targets: ["SlideOutEngine"]),
        .library(name: "WordWheelEngine", targets: ["WordWheelEngine"]),
    ],
    targets: [
        .target(name: "PuzzlesCore"),
        .target(name: "PuzzlesSync"),
        .testTarget(name: "PuzzlesSyncTests", dependencies: ["PuzzlesSync"]),
        .target(name: "FiveLettersEngine", dependencies: ["PuzzlesCore"]),
        .testTarget(name: "PuzzlesCoreTests", dependencies: ["PuzzlesCore"]),
        .testTarget(name: "FiveLettersEngineTests", dependencies: ["FiveLettersEngine"]),
        .target(name: "SudokuEngine", dependencies: ["PuzzlesCore"]),
        .testTarget(name: "SudokuEngineTests", dependencies: ["SudokuEngine"]),
        .target(name: "SolitaireEngine", dependencies: ["PuzzlesCore"]),
        .testTarget(name: "SolitaireEngineTests", dependencies: ["SolitaireEngine"]),
        .target(name: "TwoToneEngine", dependencies: ["PuzzlesCore"]),
        .testTarget(name: "TwoToneEngineTests", dependencies: ["TwoToneEngine"]),
        .target(name: "SightlinesEngine", dependencies: ["PuzzlesCore"]),
        .testTarget(name: "SightlinesEngineTests", dependencies: ["SightlinesEngine"]),
        .target(name: "KakuroEngine", dependencies: ["PuzzlesCore"]),
        .testTarget(name: "KakuroEngineTests", dependencies: ["KakuroEngine"]),
        .target(name: "SlideOutEngine", dependencies: ["PuzzlesCore"]),
        .testTarget(name: "SlideOutEngineTests", dependencies: ["SlideOutEngine"]),
        .target(name: "WordWheelEngine", dependencies: ["PuzzlesCore"]),
        .testTarget(name: "WordWheelEngineTests", dependencies: ["WordWheelEngine"]),
    ]
)

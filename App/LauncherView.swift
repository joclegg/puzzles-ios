import SwiftUI
import UIKit

struct LauncherView: View {
    private struct Entry: Identifiable {
        let id: String
        let name: String
        let detail: String
        let icon: AnyView
        let light: UInt32
        let dark: UInt32
        let home: @MainActor () -> AnyView
        let fixture: @MainActor (String) -> AnyView?

        var accent: Color {
            let light = light
            let dark = dark
            return Color(
                uiColor: UIColor { traits in
                    let value = traits.userInterfaceStyle == .dark ? dark : light
                    return UIColor(
                        red: CGFloat((value >> 16) & 0xFF) / 255,
                        green: CGFloat((value >> 8) & 0xFF) / 255,
                        blue: CGFloat(value & 0xFF) / 255,
                        alpha: 1
                    )
                }
            )
        }
    }

    private let entries = [
        Entry(
            id: "sudoku", name: "Sudoku", detail: "Classic and killer, from 6x6 to evil", icon: AnyView(SudokuGameIcon()), light: 0x1565D8,
            dark: 0x7DB5FF,
            home: SudokuGame.home, fixture: SudokuGame.fixture
        ),
        Entry(
            id: "solitaire", name: "Solitaire", detail: "Klondike, draw 1 or 3, or reverse", icon: AnyView(SolitaireGameIcon()),
            light: 0x2E8B57,
            dark: 0x5CC58A,
            home: SolitaireGame.home, fixture: SolitaireGame.fixture
        ),
        Entry(
            id: "two_tone", name: "Two Tone", detail: "Fill the grid red and blue, three simple rules", icon: AnyView(TwoToneGameIcon()),
            light: 0xE0603F, dark: 0xEC7F62,
            home: TwoToneGame.home, fixture: TwoToneGame.fixture
        ),
        Entry(
            id: "sightlines", name: "Sightlines", detail: "Blue dots count what they can see", icon: AnyView(SightlinesGameIcon()),
            light: 0x2A93B3, dark: 0x52BDDC,
            home: SightlinesGame.home, fixture: SightlinesGame.fixture
        ),
        Entry(
            id: "five_letters", name: "Five Letters", detail: "Guess the word in six tries, a new one every day",
            icon: AnyView(FiveLettersGameIcon()),
            light: 0x4F9A53, dark: 0x72BF6D,
            home: FiveLettersGame.home, fixture: FiveLettersGame.fixture
        ),
        Entry(
            id: "kakuro", name: "Kakuro", detail: "Cross sums: runs of different digits that add up", icon: AnyView(KakuroGameIcon()),
            light: 0x7C5CD6, dark: 0xA993F2,
            home: KakuroGame.home, fixture: KakuroGame.fixture
        ),
        Entry(
            id: "slide_out", name: "Slide Out", detail: "Slide the blocks to free the red one", icon: AnyView(SlideOutGameIcon()),
            light: 0xC27A2C, dark: 0xE3A85C,
            home: SlideOutGame.home, fixture: SlideOutGame.fixture
        ),
        Entry(
            id: "word_wheel", name: "Word Wheel", detail: "Swipe the letters to fill the crossword", icon: AnyView(WordWheelGameIcon()),
            light: 0x4F5BD5, dark: 0x939BFF,
            home: WordWheelGame.home, fixture: WordWheelGame.fixture
        ),
    ]

    var body: some View {
        NavigationStack {
            if let view = fixtureView {
                view
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(entries) { entry in
                            NavigationLink {
                                entry.home()
                            } label: {
                                card(entry)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("game_\(entry.id)")
                        }
                    }
                    .padding()
                }
                .navigationTitle("Puzzles")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SettingsHubView()
                        } label: {
                            PuzzleIcon.image("gearshape")
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("settings")
                    }
                }
            }
        }
    }

    private func card(_ entry: Entry) -> some View {
        HStack(spacing: 16) {
            entry.icon
                .frame(width: 64, height: 64)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 20))
                .shadow(radius: 1)
            VStack(alignment: .leading) {
                Text(entry.name).font(.title3.weight(.medium))
                Text(entry.detail).font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            PuzzleIcon.image("chevron.right").foregroundStyle(entry.accent)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [entry.accent.opacity(0.2), entry.accent.opacity(0.06), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 24)
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(entry.accent.opacity(0.25)))
    }

    private var fixtureView: AnyView? {
        #if DEBUG
            guard let name = UserDefaults.standard.string(forKey: "fixture") else {
                return nil
            }
            return entries.lazy.compactMap { $0.fixture(name) }.first
        #else
            return nil
        #endif
    }
}

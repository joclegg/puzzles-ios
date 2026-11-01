import PuzzlesCore
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
        var banks: [String] = []

        var tab: SettingsTab {
            SettingsTab.games.first { $0.tag == id } ?? .sudoku
        }

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

    @State private var signingIn = false

    private let entries = [
        Entry(
            id: "sudoku", name: "Sudoku", detail: "Classic and killer, from 6x6 to evil", icon: AnyView(SudokuGameIcon()), light: 0x1565D8,
            dark: 0x7DB5FF,
            home: SudokuGame.home, fixture: SudokuGame.fixture, banks: ["sudoku/"]
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
            home: FiveLettersGame.home, fixture: FiveLettersGame.fixture, banks: ["words/"]
        ),
        Entry(
            id: "kakuro", name: "Kakuro", detail: "Cross sums: runs of different digits that add up", icon: AnyView(KakuroGameIcon()),
            light: 0x7C5CD6, dark: 0xA993F2,
            home: KakuroGame.home, fixture: KakuroGame.fixture, banks: ["kakuro/"]
        ),
        Entry(
            id: "slide_out", name: "Slide Out", detail: "Slide the blocks to free the red one", icon: AnyView(SlideOutGameIcon()),
            light: 0xC27A2C, dark: 0xE3A85C,
            home: SlideOutGame.home, fixture: SlideOutGame.fixture, banks: ["slideout/"]
        ),
        Entry(
            id: "word_wheel", name: "Word Wheel", detail: "Swipe the letters to fill the crossword", icon: AnyView(WordWheelGameIcon()),
            light: 0x4F5BD5, dark: 0x939BFF,
            home: WordWheelGame.home, fixture: WordWheelGame.fixture, banks: ["wordwheel/"]
        ),
    ]

    @State private var router = DailyRouter.shared

    var body: some View {
        NavigationStack(path: $router.path) {
            Group {
                if let view = fixtureView {
                    view
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            header
                            ForEach(entries) { entry in
                                NavigationLink(value: DailyRoute.game(entry.tab)) {
                                    card(entry)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("game_\(entry.id)")
                            }
                        }
                        .padding()
                    }
                    .accessibilityHidden(!router.path.isEmpty)
                    .toolbar(.hidden, for: .navigationBar)
                    .sheet(isPresented: $signingIn) { SignInView() }
                }
            }
            .navigationDestination(for: DailyRoute.self, destination: destination)
        }
        .id(router.generation)
    }

    @ViewBuilder
    private func destination(_ route: DailyRoute) -> some View {
        switch route {
        case .game(let tab):
            if let entry = entries.first(where: { $0.tab == tab }) {
                if entry.banks.isEmpty {
                    entry.home()
                } else {
                    BankGate(prefixes: entry.banks) { entry.home() }
                }
            }
        case .calendar(let tab):
            DailyCalendarView(tab: tab)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("Puzzles")
                    .font(.largeTitle)
                    .lineLimit(1)
                if AllGolds.held {
                    PuzzleIcon.image("trophy.fill")
                        .font(.title2)
                        .foregroundStyle(medalColour(.gold))
                        .accessibilityLabel("Gold in every puzzle today")
                        .accessibilityIdentifier("all_golds_trophy")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if SyncCenter.shared.signedIn {
                    Button("Sign out") { SyncCenter.shared.signOut() }
                        .accessibilityIdentifier("sign_out")
                } else {
                    Button("Sign in to sync") { signingIn = true }
                        .accessibilityIdentifier("sign_in")
                }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .font(.subheadline)
            .lineLimit(1)
            .fixedSize()
            NavigationLink {
                AllHistoryView()
            } label: {
                PuzzleIcon.image("clock.arrow.circlepath").frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("History")
            .accessibilityIdentifier("all_history")
            NavigationLink {
                SettingsHubView()
            } label: {
                PuzzleIcon.image("gearshape").frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("settings")
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
            medal(entry)
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

    @ViewBuilder
    private func medal(_ entry: Entry) -> some View {
        let medal = entry.tab.dailyDayMap[.today]?.medal ?? Medal.none
        if medal != .none {
            Circle()
                .fill(medalColour(medal))
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(Color.primary.opacity(0.2)))
                .accessibilityElement()
                .accessibilityLabel("Today's \(medal.rawValue) medal")
                .accessibilityIdentifier("home_medal_\(entry.id)_\(medal.rawValue)")
        }
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

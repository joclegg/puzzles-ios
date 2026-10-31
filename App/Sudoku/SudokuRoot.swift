import SudokuEngine
import SwiftUI

enum SudokuRoute: Hashable {
    case game(Int)
    case entry(GameMode)
    case stats
    case history
    case daily
    case settings(GameMode)
}

@MainActor
@Observable
final class SudokuNavigator {
    var stack: [SudokuRoute] = []
    var leave: () -> Void = {}
    private var models: [Int: SudokuGameModel] = [:]

    func push(_ route: SudokuRoute) {
        stack.append(route)
    }

    func back() {
        if stack.isEmpty {
            leave()
        } else {
            stack.removeLast()
        }
    }

    func openGame(_ id: Int) {
        stack = [.game(id)]
    }

    func home() {
        stack = []
    }

    func model(_ id: Int) -> SudokuGameModel? {
        if let existing = models[id] {
            return existing
        }
        let made = SudokuGameModel(id: id)
        models[id] = made
        return made
    }
}

struct SudokuRootView: View {
    let fixture: String?
    @State private var navigator = SudokuNavigator()
    @State private var preparedFixture = false
    @AppStorage(SettingKeys.theme) private var theme = ThemeMode.system.rawValue
    @Environment(\.dismiss) private var dismiss

    private static let edgeWidth: CGFloat = 24
    private static let swipeDistance: CGFloat = 60

    var body: some View {
        SudokuScreen {
            switch navigator.stack.last {
            case nil:
                SudokuHomeView()
            case .game(let id):
                SudokuGameView(id: id).id(id)
            case .entry(let mode):
                SudokuEntryView(mode: mode)
            case .stats:
                SudokuStatsView()
            case .history:
                SudokuHistoryView()
            case .daily:
                SudokuDailyView()
            case .settings(let mode):
                SettingsHubView(initial: .sudoku, sudokuMode: mode, onBack: navigator.back)
            }
        }
        .environment(navigator)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(colorScheme)
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { drag in
                if drag.startLocation.x < Self.edgeWidth, drag.translation.width > Self.swipeDistance {
                    navigator.back()
                }
            }
        )
        .onAppear {
            navigator.leave = { dismiss() }
            prepareFixture()
        }
    }

    private var colorScheme: ColorScheme? {
        switch ThemeMode(rawValue: theme) {
        case .light:
            .light
        case .dark:
            .dark
        default:
            nil
        }
    }

    private func prepareFixture() {
        #if DEBUG
            guard let fixture, !preparedFixture else {
                return
            }
            preparedFixture = true
            if fixture == SudokuFixtures.draftName {
                UserDefaults.standard.set(SudokuFixtures.draft, forKey: SettingKeys.customDraft)
            } else if let ref = SudokuFixtures.puzzle(fixture) {
                let game = SudokuStore.shared.start(ref, mistakeCheck: sudokuModeSettings(ref.mode).mistakeCheck)
                navigator.openGame(game.id)
            }
        #endif
    }
}

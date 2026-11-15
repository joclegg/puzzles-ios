import CrosswordEngine
import PuzzlesCore
import SwiftUI

enum CrosswordRoute {
    case game(CrosswordGameModel)
    case stats
    case history
    case settings
}

@MainActor
@Observable
final class CrosswordNavigator {
    var path: [CrosswordRoute] = []
    private var starting = false

    func back() -> Bool {
        guard !path.isEmpty else {
            return false
        }
        path.removeLast()
        return true
    }

    func home() {
        path = []
    }

    func open(_ game: SavedGame) {
        path = [.game(CrosswordGameModel(saved: game))]
    }

    func start(_ ref: PuzzleRef, entries: [Character]? = nil) {
        open(CrosswordStore.shared.start(ref: ref, entries: entries))
    }

    func startRandom(size: Int) {
        launch {
            let puzzles = await attempt("Crossword bank") { try await CrosswordBank.puzzles(size: size) } ?? []
            guard !puzzles.isEmpty else {
                return
            }
            self.start(PuzzleRef.random(puzzles: puzzles, size: size, seed: Int64.random(in: .min ... .max)))
        }
    }

    func openDaily(size: Int) {
        let date = CalendarDay.today
        let id = PuzzleRef.dailyId(date: date, size: size)
        if let existing = CrosswordStore.shared.inProgress.first(where: { $0.ref.id == id }) {
            open(existing)
            return
        }
        launch {
            let puzzles = await attempt("Crossword bank") { try await CrosswordBank.puzzles(size: size) } ?? []
            guard !puzzles.isEmpty else {
                return
            }
            self.start(PuzzleRef.daily(puzzles: puzzles, date: date, size: size))
        }
    }

    private func launch(_ work: @escaping @MainActor () async -> Void) {
        guard !starting else {
            return
        }
        starting = true
        Task {
            await work()
            starting = false
        }
    }
}

struct CrosswordRootView: View {
    let fixture: CrosswordFixture?

    @Environment(\.dismiss) private var dismiss
    @State private var navigator = CrosswordNavigator()
    @State private var openedFixture = false

    var body: some View {
        ZStack {
            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            edgeSwipe
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if let id = DailyRouter.shared.take(.crossword).flatMap(Int64.init), let game = CrosswordStore.shared.game(id: id) {
                navigator.open(game)
            }
            guard let fixture, !openedFixture else {
                return
            }
            openedFixture = true
            navigator.start(fixture.ref, entries: fixture.entries)
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch navigator.path.last {
        case .game(let model):
            CrosswordGameView(model: model, navigator: navigator).id(model.saved.id)
        case .stats:
            CrosswordStatsView(onBack: back)
        case .history:
            CrosswordHistoryView(navigator: navigator, onBack: back)
        case .settings:
            SettingsHubView(initial: .crossword, onBack: back)
        case nil:
            CrosswordHomeView(navigator: navigator, onBack: back)
        }
    }

    private var edgeSwipe: some View {
        HStack {
            Color.clear
                .frame(width: 12)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { drag in
                            if drag.translation.width > 60 {
                                back()
                            }
                        }
                )
            Spacer()
        }
    }

    private func back() {
        if !navigator.back() {
            dismiss()
        }
    }
}

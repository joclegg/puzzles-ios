import FiveLettersEngine
import Observation
import SwiftUI

@MainActor
@Observable
final class FiveLettersGameModel {
    private(set) var saved: SavedGame?
    private(set) var game: GameState?
    private(set) var words: Words?
    private(set) var hint: String?
    var resultClosed = false

    private let store = FiveLettersStore.shared

    func load(uuid: String) async {
        guard let loaded = store.game(uuid: uuid) else {
            return
        }
        let words = await attempt("Five Letters words") { try await store.words() }
        self.words = words
        saved = loaded
        game = loaded.gameState
        hint = nil
        resultClosed = false
    }

    var title: String {
        saved?.ref.title ?? ""
    }

    var isDated: Bool {
        guard let ref = saved?.ref else {
            return false
        }
        return ref.isDaily || ref.isDaily2
    }

    var shareText: String {
        game?.shareText(title: title) ?? ""
    }

    var message: String {
        game?.rejection?.message ?? (game?.isOver == true ? nil : hint) ?? ""
    }

    func type(_ letter: Character) {
        game = game?.type(letter)
    }

    func delete() {
        game = game?.delete()
    }

    func enter() {
        guard let words, let before = game else {
            return
        }
        let after = before.submit(words: words)
        game = after
        guard after.guesses != before.guesses, var snapshot = saved else {
            return
        }
        snapshot.guesses = after.guesses
        saved = snapshot
        if after.isOver {
            store.finish(snapshot, won: after.isWon)
        } else {
            store.save(snapshot)
        }
    }

    func showHint() {
        guard let game, !game.isOver else {
            return
        }
        hint = game.hintMessage
    }

    func reveal() {
        guard let current = game, !current.isOver, let saved else {
            return
        }
        game = current.revealWord()
        hint = nil
        store.finish(saved, won: false)
    }

    func newPractice() async {
        guard let saved, let words = await attempt("Five Letters words", { try await store.words() }) else {
            return
        }
        let ref = WordRef.practice(words: words, seed: Int64.random(in: .min ... .max))
        let next = store.start(ref: ref, hardMode: saved.hardMode)
        await load(uuid: next.uuid)
    }
}

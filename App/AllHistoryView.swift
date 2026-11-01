import FiveLettersEngine
import KakuroEngine
import PuzzlesCore
import SightlinesEngine
import SlideOutEngine
import SolitaireEngine
import SudokuEngine
import SwiftData
import SwiftUI
import TwoToneEngine
import WordWheelEngine

struct HistoryEntry: Identifiable {
    let id: String
    let tab: SettingsTab
    let title: String
    let startedAt: Int64
    let time: String?
    let result: String
}

@MainActor
enum AllHistory {
    static var entries: [HistoryEntry] {
        (sudoku + solitaire + twoTone + sightlines + fiveLetters + kakuro + slideOut + wordWheel)
            .sorted { $0.startedAt > $1.startedAt }
    }

    private static func time(_ ms: Int64) -> String {
        formatDuration(ms)
    }

    private static func withHints(_ label: String, _ hints: Int) -> String {
        hints > 0 ? "\(label) · \(hints) hints" : label
    }

    private static var sudoku: [HistoryEntry] {
        SudokuStore.shared.history.map { game in
            HistoryEntry(
                id: "sudoku_\(game.id)", tab: .sudoku, title: game.title, startedAt: game.startedAt, time: time(game.elapsedMs),
                result: game.mistakeCheck != .off ? "\(game.status.label) · \(game.mistakes) mistakes" : game.status.label)
        }
    }

    private static var solitaire: [HistoryEntry] {
        SolitaireStore.shared.games.map { game in
            HistoryEntry(
                id: "solitaire_\(game.id)", tab: .solitaire, title: game.deal.title, startedAt: game.startedAt,
                time: time(game.elapsedMs), result: game.summary)
        }
    }

    private static var twoTone: [HistoryEntry] {
        TwoToneStore.shared.history.map { game in
            HistoryEntry(
                id: "two_tone_\(game.id)", tab: .twoTone, title: game.title, startedAt: game.startedAt, time: time(game.elapsedMs),
                result: withHints(game.gameStatus.label, game.hints))
        }
    }

    private static var sightlines: [HistoryEntry] {
        SightlinesStore.shared.games.map { game in
            HistoryEntry(
                id: "sightlines_\(game.id)", tab: .sightlines, title: game.ref.title, startedAt: game.startedAt,
                time: time(game.elapsedMs), result: withHints(game.status.label, game.hints))
        }
    }

    private static var fiveLetters: [HistoryEntry] {
        FiveLettersStore.shared.history.map { game in
            let result =
                switch game.status {
                case .inProgress: "In progress"
                case .won: "Won in \(game.guesses.count)"
                case .lost: "Lost"
                case .abandoned: "Abandoned"
                }
            return HistoryEntry(
                id: "five_letters_\(game.uuid)", tab: .fiveLetters, title: game.ref.title, startedAt: game.startedAt, time: nil,
                result: result)
        }
    }

    private static var kakuro: [HistoryEntry] {
        KakuroStore.shared.games.map { game in
            let status =
                switch game.status {
                case .solved: "Solved"
                case .inProgress: "In progress"
                case .abandoned: "Abandoned"
                case .revealed: "Solution shown"
                }
            return HistoryEntry(
                id: "kakuro_\(game.id)", tab: .kakuro, title: game.ref.title, startedAt: game.startedAt, time: time(game.elapsedMs),
                result: withHints(status, game.hints))
        }
    }

    private static var slideOut: [HistoryEntry] {
        let records = (try? SlideOutStore.context.fetch(FetchDescriptor<SlideOutGameRecord>())) ?? []
        return records.map { game in
            HistoryEntry(
                id: "slide_out_\(game.id)", tab: .slideOut, title: game.title, startedAt: game.startedAt, time: time(game.elapsedMs),
                result: "\(game.gameStatus.label) · \(game.moveCount) moves")
        }
    }

    private static var wordWheel: [HistoryEntry] {
        WordWheelRepository.shared.history.map { game in
            HistoryEntry(
                id: "word_wheel_\(game.id)", tab: .wordWheel, title: game.ref.title, startedAt: game.startedAt,
                time: time(game.elapsedMs), result: "\(game.status.label) · \(game.found.count) words, \(game.bonus.count) bonus")
        }
    }
}

struct AllHistoryView: View {
    private static let dateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let entries = AllHistory.entries
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    PuzzleIcon.image("chevron.left").font(.title3).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
                .accessibilityIdentifier("back")
                Text("History").font(.title)
            }
            .padding(.horizontal, 8)
            if entries.isEmpty {
                ContentUnavailableView("No games yet.", systemImage: "clock")
            } else {
                List(entries) { entry in
                    row(entry)
                }
                .listStyle(.plain)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func row(_ entry: HistoryEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.tab.rawValue).font(.caption.weight(.semibold)).foregroundStyle(entry.tab.accent)
                Text(entry.title).font(.subheadline.weight(.medium))
                Text(Self.dateFormat.string(from: Date(timeIntervalSince1970: Double(entry.startedAt) / 1000)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let time = entry.time {
                    Text(time)
                }
                Text(entry.result).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("all_history_item")
    }
}

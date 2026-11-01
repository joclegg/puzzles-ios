import PuzzlesCore
import SightlinesEngine
import SwiftUI

struct SightlinesHistoryView: View {
    let onOpenGame: (Int64) -> Void
    private let store = SightlinesStore.shared
    @State private var filter: Int?

    private var games: [SavedGame] {
        store.games.filter { filter == nil || $0.ref.size == filter }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", nil, tag: "filter_all")
                    ForEach(sizes, id: \.self) { chip("\($0)", $0, tag: "filter_\($0)") }
                }
            }
            if games.isEmpty {
                VStack(spacing: 12) {
                    Circle()
                        .fill(SightlinesColors.accent.opacity(0.14))
                        .frame(width: 48, height: 48)
                        .overlay { PuzzleIcon.image("clock.arrow.circlepath").foregroundStyle(SightlinesColors.accent) }
                    Text("No games yet.").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(SightlinesColors.tileBorder))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(games) { game in
                            item(game)
                            Divider()
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .background(SightlinesColors.tile, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(SightlinesColors.tileBorder))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chip(_ label: String, _ value: Int?, tag: String) -> some View {
        Button {
            filter = value
        } label: {
            Text(label)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .foregroundStyle(filter == value ? Color(uiColor: .systemBackground) : Color.primary)
                .background(filter == value ? SightlinesColors.accent : SightlinesColors.tile, in: Capsule())
                .overlay(Capsule().stroke(filter == value ? SightlinesColors.accent : SightlinesColors.tileBorder))
        }
        .accessibilityIdentifier(tag)
    }

    private func item(_ game: SavedGame) -> some View {
        Button {
            open(game)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(game.ref.title).font(.subheadline.weight(.medium))
                    Text(started(game)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(formatDuration(game.elapsedMs))
                    Text(game.hints > 0 ? "\(game.status.label) · \(game.hints) hints" : game.status.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("history_item")
    }

    private func open(_ game: SavedGame) {
        if game.status == .inProgress {
            onOpenGame(game.id)
            return
        }
        let ref = game.ref
        Task {
            onOpenGame(await store.start { ref })
        }
    }

    private func started(_ game: SavedGame) -> String {
        Theme.historyDate(ms: game.startedAt)
    }
}

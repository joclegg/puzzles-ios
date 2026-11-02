import PuzzlesCore
import SwiftUI

struct HistoryFilterChip<Filter: Hashable> {
    let label: String
    let value: Filter?
    let isSelected: Bool
    let select: () -> Void
}

struct GameHistoryView<Filter: Hashable, Game, Header: View, Chip: View, Empty: View, Rows: View>: View {
    let filters: [Filter]
    let label: (Filter) -> String
    let allLabel: String
    let chipsPadding: EdgeInsets
    let fixedChipsHeight: Bool
    let games: (Filter?) -> [Game]
    let header: () -> Header
    let chip: (HistoryFilterChip<Filter>) -> Chip
    let empty: () -> Empty
    let rows: ([Game]) -> Rows

    @State private var filter: Filter?

    init(
        filters: [Filter],
        label: @escaping (Filter) -> String,
        allLabel: String = "All",
        chipsPadding: EdgeInsets = EdgeInsets(),
        fixedChipsHeight: Bool = false,
        games: @escaping (Filter?) -> [Game],
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder chip: @escaping (HistoryFilterChip<Filter>) -> Chip,
        @ViewBuilder empty: @escaping () -> Empty,
        @ViewBuilder rows: @escaping ([Game]) -> Rows
    ) {
        self.filters = filters
        self.label = label
        self.allLabel = allLabel
        self.chipsPadding = chipsPadding
        self.fixedChipsHeight = fixedChipsHeight
        self.games = games
        self.header = header
        self.chip = chip
        self.empty = empty
        self.rows = rows
    }

    var body: some View {
        let shown = games(filter)
        VStack(alignment: .leading, spacing: 16) {
            header()
            filterBar
            if shown.isEmpty {
                empty()
            } else {
                rows(shown)
            }
        }
    }

    @ViewBuilder
    private var filterBar: some View {
        let bar = ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(HistoryFilterChip(label: allLabel, value: nil, isSelected: filter == nil) { filter = nil })
                ForEach(filters, id: \.self) { option in
                    chip(HistoryFilterChip(label: label(option), value: option, isSelected: filter == option) { filter = option })
                }
            }
            .padding(chipsPadding)
        }
        if fixedChipsHeight {
            bar.fixedSize(horizontal: false, vertical: true)
        } else {
            bar
        }
    }
}

struct HistoryRows<Game, ID: Hashable, Row: View>: View {
    let games: [Game]
    let id: KeyPath<Game, ID>
    let row: (Game) -> Row

    init(_ games: [Game], id: KeyPath<Game, ID>, @ViewBuilder row: @escaping (Game) -> Row) {
        self.games = games
        self.id = id
        self.row = row
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(games, id: id) { game in
                row(game)
                Divider()
            }
        }
    }
}

struct HistoryRowLabel: View {
    let title: String
    let date: String
    let elapsedMs: Int64
    let detail: String
    var titleFont: Font = .subheadline.weight(.medium)
    var spacing: CGFloat?
    var secondary: AnyShapeStyle = AnyShapeStyle(.secondary)
    var verticalPadding: CGFloat = 12

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: spacing) {
                Text(title).font(titleFont)
                Text(date).font(.caption).foregroundStyle(secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: spacing) {
                Text(formatDuration(elapsedMs))
                Text(detail).font(.caption).foregroundStyle(secondary)
            }
        }
        .padding(.vertical, verticalPadding)
        .contentShape(Rectangle())
    }
}

struct HistoryItemButton<Label: View>: View {
    let action: () -> Void
    let label: Label

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("history_item")
    }
}

struct HistoryEmptyState: View {
    let accent: Color
    var border: Color = Color.primary.opacity(0.12)

    var body: some View {
        VStack(spacing: 12) {
            PuzzleIcon.image("clock.arrow.circlepath")
                .foregroundStyle(accent)
                .frame(width: 48, height: 48)
                .background(accent.opacity(0.14), in: Circle())
            Text("No games yet.").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(border, lineWidth: 1))
    }
}

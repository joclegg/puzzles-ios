import PuzzlesCore
import SwiftUI

struct WinStat: Identifiable {
    let label: String
    let value: String
    var tag: String?

    var id: String {
        label
    }
}

struct WinDialog<Buttons: View>: View {
    private static var tileHeight: CGFloat { 96 }
    private static var tileSpacing: CGFloat { 8 }
    private static var tilesPerRow: Int { 3 }
    private static var tilesMaxHeight: CGFloat { 216 }

    let title: String
    let accent: Color
    let dailyGroup: String
    let newBest: Bool
    let stats: [WinStat]
    let tag: String
    var message: String?
    var titleTag: String?
    var lost = false
    var newLabel: String?
    var newTag = "win_new"
    var onNew: (() -> Void)?
    var onDismiss: () -> Void = {}
    @ViewBuilder let buttons: () -> Buttons

    @State private var dailies: [DailyLeft] = []
    @State private var popScale: CGFloat = 0.6
    @State private var allGolds = false
    @AppStorage("all_golds_celebrated_day") private var celebratedDay = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .onTapGesture(perform: onDismiss)
            VStack(spacing: 0) {
                header
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                }
                if !stats.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(stats) { stat in
                            statBox(stat)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                playNext
                HStack(spacing: 16) {
                    Spacer()
                    buttons()
                }
                .padding(16)
            }
            .tint(accent)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(accent.opacity(0.3)))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(tag)
        }
        .overlay {
            if allGolds {
                allGoldsCard
            }
        }
        .task(id: dailyGroup) {
            dailies = TodaysDailies.left(group: dailyGroup)
            let today = CalendarDay.today.isoString
            if !lost && celebratedDay != today && AllGolds.held {
                celebratedDay = today
                allGolds = true
            }
        }
    }

    private var allGoldsCard: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .onTapGesture { allGolds = false }
            VStack(spacing: 12) {
                PuzzleIcon.image("trophy.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color(.systemBackground))
                    .frame(width: 80, height: 80)
                    .background(medalColour(.gold), in: Circle())
                    .accessibilityHidden(true)
                Text("Gold in every puzzle").font(.title2.bold()).multilineTextAlignment(.center)
                Text("You've earned today's gold medal in all eight games.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Brilliant") { allGolds = false }
                    .buttonStyle(.borderedProminent)
                    .tint(medalColour(.gold))
                    .accessibilityIdentifier("all_golds_close")
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(medalColour(.gold), lineWidth: 2))
            .padding(32)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("all_golds_dialog")
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            PuzzleIcon.image(lost ? "book.fill" : "trophy.fill")
                .font(.title)
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 64, height: 64)
                .background(accent, in: Circle())
                .scaleEffect(popScale)
                .accessibilityHidden(true)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                        popScale = 1
                    }
                }
            titleText
            if newBest {
                Text("NEW BEST")
                    .font(.caption.bold())
                    .foregroundStyle(Color(.systemBackground))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
                    .background(accent, in: Capsule())
                    .accessibilityIdentifier("new_best")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [accent.opacity(0.3), accent.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)
        )
    }

    @ViewBuilder
    private var titleText: some View {
        let text = Text(title).font(.title2.bold()).multilineTextAlignment(.center).padding(.horizontal, 16)
        if let titleTag {
            text.accessibilityIdentifier(titleTag)
        } else {
            text
        }
    }

    private func statBox(_ stat: WinStat) -> some View {
        VStack(spacing: 2) {
            Text(stat.label).font(.caption2).foregroundStyle(.secondary)
            statValue(stat)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func statValue(_ stat: WinStat) -> some View {
        let text = Text(stat.value).font(.headline).multilineTextAlignment(.center)
        if let tag = stat.tag {
            text.accessibilityIdentifier(tag)
        } else {
            text
        }
    }

    @ViewBuilder
    private var playNext: some View {
        if !dailies.isEmpty || onNew != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("PLAY NEXT").font(.caption2).foregroundStyle(.secondary)
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: Self.tileSpacing), count: Self.tilesPerRow),
                        spacing: Self.tileSpacing
                    ) {
                        ForEach(dailies) { daily in
                            tile("Daily", daily.label, action: daily.onClick)
                        }
                        if let onNew {
                            tile("New", newLabel ?? "", action: onNew).accessibilityIdentifier(newTag)
                        }
                    }
                }
                .frame(height: tilesHeight)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    private var tilesHeight: CGFloat {
        let count = dailies.count + (onNew == nil ? 0 : 1)
        let rows = (count + Self.tilesPerRow - 1) / Self.tilesPerRow
        let height = CGFloat(rows) * Self.tileHeight + CGFloat(max(rows - 1, 0)) * Self.tileSpacing
        return min(height, Self.tilesMaxHeight)
    }

    private func tile(_ caption: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(caption).font(.caption2).foregroundStyle(.secondary)
                Text(label)
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .padding(4)
            .frame(maxWidth: .infinity)
            .frame(height: Self.tileHeight)
            .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.3)))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

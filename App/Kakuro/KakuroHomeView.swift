import KakuroEngine
import PuzzlesCore
import SwiftUI

struct KakuroHomeView: View {
    let navigator: KakuroNavigator
    let onBack: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var resumeChoice: SavedGame?

    private var store: KakuroStore {
        KakuroStore.shared
    }

    private var accent: Color {
        KakuroColors.of(scheme).accent
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                hero
                if let latest = store.inProgress.first {
                    continueCard(latest)
                }
                section("Today", aside: dayMonthLabel(iso: CalendarDay.today.isoString)) {
                    HStack(spacing: 8) {
                        ForEach(sizes, id: \.self, content: dailyTile)
                    }
                }
                section("New puzzle", aside: nil) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                        ForEach(sizes, id: \.self, content: sizeTile)
                    }
                }
            }
            .padding(16)
        }
        .overlay {
            if let saved = resumeChoice {
                resumeDialog(saved)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            KakuroBackButton(action: onBack)
            Text("Kakuro").font(.largeTitle)
            Spacer()
            DailyCalendarButton(tab: .kakuro)
            headerButton("chart.bar", "Stats", "stats") { navigator.path.append(.stats) }
            headerButton("clock.arrow.circlepath", "History", "history") { navigator.path.append(.history) }
            headerButton("gearshape", "Settings", "settings") { navigator.path.append(.settings) }
        }
    }

    private func headerButton(_ symbol: String, _ label: String, _ tag: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PuzzleIcon.image(symbol).font(.system(size: 18)).frame(width: 40, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(tag)
    }

    private var hero: some View {
        HStack(spacing: 16) {
            KakuroGameIcon()
                .frame(width: 80, height: 80)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 1)
            Text("Cross sums: runs of different digits that add up")
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.2), accent.opacity(0.06), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(accent.opacity(0.25), lineWidth: 1))
    }

    private func continueCard(_ latest: SavedGame) -> some View {
        Button {
            navigator.open(latest)
        } label: {
            HStack(spacing: 16) {
                PuzzleIcon.image("play.fill")
                    .foregroundStyle(Color(.systemBackground))
                    .frame(width: 48, height: 48)
                    .background(accent, in: Circle())
                VStack(alignment: .leading) {
                    Text("Continue").font(.headline)
                    Text("\(latest.ref.title) · \(formatDuration(latest.elapsedMs))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                PuzzleIcon.image("chevron.right").foregroundStyle(.secondary)
            }
            .padding(16)
            .modifier(KakuroTileStyle(accent: accent, highlighted: true, corner: 24))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continue")
    }

    private func section<Content: View>(_ title: String, aside: String?, @ViewBuilder content: () -> Content) -> some View {
        HomeSection(title, aside: aside, style: .caps, content: content)
    }

    private func isDailySolved(_ size: Int) -> Bool {
        let id = PuzzleRef.dailyId(date: .today, size: size)
        return store.games.contains { $0.ref.id == id && $0.status == .solved }
    }

    private func dailyTile(size: Int) -> some View {
        let done = isDailySolved(size)
        return Button {
            navigator.openDaily(size: size)
        } label: {
            VStack(spacing: 4) {
                Text(sizeLabel(size)).font(.footnote.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                if done {
                    PuzzleIcon.image("checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(width: 18, height: 18)
                        .background(accent, in: Circle())
                        .accessibilityLabel("Done")
                } else {
                    Text("Play").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, 4)
            .modifier(KakuroTileStyle(accent: accent, highlighted: done, fill: done ? accent.opacity(0.16) : Color.primary.opacity(0.05)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("daily_\(size)")
    }

    private func sizeTile(size: Int) -> some View {
        let saved = store.inProgress.first { !$0.ref.isDaily && $0.ref.size == size }
        let rank = sizes.firstIndex(of: size) ?? 0
        return Button {
            if let saved {
                resumeChoice = saved
            } else {
                navigator.startRandom(size: size)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sizeLabel(size)).font(.headline)
                    HStack(spacing: 4) {
                        ForEach(sizes.indices, id: \.self) { index in
                            Capsule()
                                .fill(index <= rank ? accent : Color.primary.opacity(0.14))
                                .frame(width: 12, height: 6)
                        }
                    }
                    if let saved {
                        HStack(spacing: 6) {
                            Circle().fill(accent).frame(width: 6, height: 6)
                            Text("In progress · \(formatDuration(saved.elapsedMs))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
                Spacer(minLength: 0)
                PuzzleIcon.image("chevron.right").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .modifier(KakuroTileStyle(accent: accent, highlighted: saved != nil))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("size_\(size)")
    }

    private func resumeDialog(_ saved: SavedGame) -> some View {
        KakuroDialog(
            title: saved.ref.title,
            tag: "resume_dialog",
            buttons: [
                KakuroDialogButton(title: "New puzzle", tag: "new_game") {
                    resumeChoice = nil
                    navigator.startRandom(size: saved.ref.size)
                },
                KakuroDialogButton(title: "Resume", tag: "resume_game") {
                    resumeChoice = nil
                    navigator.open(saved)
                },
            ],
            onDismiss: { resumeChoice = nil }
        ) {
            Text("You have a puzzle in progress (\(formatDuration(saved.elapsedMs))).")
        }
    }
}

import FiveLettersEngine
import SwiftUI

struct FiveLettersStatsView: View {
    private let theme = FiveLettersTheme()

    var body: some View {
        let stats = FiveLettersStore.shared.stats
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    figure(stats.played, label: "Played", id: "played")
                    figure(stats.winPercent, label: "Win %", id: "win_percent")
                    figure(stats.currentStreak, label: "Streak", id: "streak")
                    figure(stats.maxStreak, label: "Best streak", id: "max_streak")
                }
                .fiveLettersPanel(accent: theme.accent)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Capsule().fill(theme.accent).frame(width: 4, height: 16)
                        Text("Guesses").font(.headline)
                    }
                    ForEach(1...maxGuesses, id: \.self) { guesses in
                        bar(stats, guesses: guesses)
                    }
                }
                .fiveLettersPanel(accent: theme.accent)
            }
            .padding(16)
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func figure(_ value: Int, label: String, id: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title.bold())
                .accessibilityIdentifier(id)
            Text(label)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func bar(_ stats: WordStats, guesses: Int) -> some View {
        HStack(spacing: 4) {
            Text("\(guesses)").frame(width: 20, alignment: .leading)
            GeometryReader { proxy in
                Text("\(stats.guessCounts[guesses - 1])")
                    .foregroundStyle(theme.markedText)
                    .padding(.horizontal, 8)
                    .frame(
                        width: max(proxy.size.width * stats.barFraction(guesses: guesses), 28),
                        height: proxy.size.height,
                        alignment: .trailing
                    )
                    .background(theme.correct, in: .rect(cornerRadius: 4))
                    .accessibilityIdentifier("guesses_\(guesses)")
            }
            .frame(height: 26)
        }
    }
}

extension View {
    func fiveLettersPanel(accent: Color) -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24).stroke(accent.opacity(0.25))
            }
    }
}

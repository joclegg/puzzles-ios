import SwiftUI

struct HelpersButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                PuzzleIcon.image("slider.horizontal.3").font(.caption)
                Text("Customise helpers").font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay(Capsule().stroke(Color.secondary.opacity(0.3)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .accessibilityLabel("Customise helpers")
        .accessibilityHint("Opens this game's settings")
        .accessibilityIdentifier("customise_helpers")
    }
}

struct HelpersNote: View {
    var body: some View {
        Text("Helpers like hints, highlights and mistake checks start off. Turn on any you'd like below.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("helpers_note")
    }
}

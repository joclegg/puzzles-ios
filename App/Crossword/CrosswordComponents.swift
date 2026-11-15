import SwiftUI

struct CrosswordIconButton: View {
    let symbol: String
    let description: String
    let tag: String
    var enabled = true
    var on = false
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var showTip = false
    @State private var heldForTip = false

    var body: some View {
        Button {
            if heldForTip {
                heldForTip = false
            } else {
                action()
            }
        } label: {
            PuzzleIcon.image(symbol)
                .font(.system(size: 18))
                .frame(width: 38, height: 44)
                .background(on ? CrosswordColors.of(scheme).selected : .clear, in: Circle())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.5))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                heldForTip = true
                showTip = true
            }
        )
        .popover(isPresented: $showTip) {
            Text(description).font(.footnote).padding(10).presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel(description)
        .accessibilityIdentifier(tag)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct CrosswordBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PuzzleIcon.image("chevron.left")
                .font(.system(size: 18, weight: .medium))
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
        .accessibilityIdentifier("back")
    }
}

struct CrosswordDialogButton: Identifiable {
    let title: String
    let tag: String?
    let action: () -> Void

    var id: String {
        title
    }
}

struct CrosswordDialog<Content: View>: View {
    let title: String
    let tag: String?
    let buttons: [CrosswordDialogButton]
    var onDismiss: (() -> Void)?
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss?() }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 14) {
                Text(title).font(.title3.weight(.semibold))
                content()
                HStack(spacing: 16) {
                    Spacer()
                    ForEach(buttons) { button in
                        Button(button.title, action: button.action)
                            .fontWeight(.medium)
                            .foregroundStyle(CrosswordColors.of(scheme).accent)
                            .accessibilityIdentifier(button.tag ?? button.title)
                    }
                }
            }
            .padding(22)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
            .padding(28)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(tag ?? "dialog")
        }
    }
}

struct CrosswordScreenTitle: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            CrosswordBackButton(action: onBack)
            Text(title).font(.title)
            Spacer()
        }
    }
}

struct CrosswordTileStyle: ViewModifier {
    let accent: Color
    var highlighted = false
    var corner: CGFloat = 16
    var fill: Color = Color.primary.opacity(0.05)

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: corner))
            .overlay(
                RoundedRectangle(cornerRadius: corner)
                    .stroke(highlighted ? accent.opacity(0.5) : Color.primary.opacity(0.12), lineWidth: 1)
            )
    }
}

struct CrosswordGameIcon: View {
    @Environment(\.colorScheme) private var scheme

    private static let pattern = [false, false, false, true, false, true, false, false, false]

    var body: some View {
        let colors = CrosswordColors.of(scheme)
        Canvas { context, size in
            let cell = size.width / 3
            for (index, isBlock) in Self.pattern.enumerated() {
                let rect = CGRect(x: CGFloat(index % 3) * cell, y: CGFloat(index / 3) * cell, width: cell, height: cell)
                context.fill(Path(rect), with: .color(isBlock ? colors.blockMark : colors.background))
            }
            var lines = Path()
            for line in 0...3 {
                let position = CGFloat(line) * cell
                lines.move(to: CGPoint(x: position, y: 0))
                lines.addLine(to: CGPoint(x: position, y: size.height))
                lines.move(to: CGPoint(x: 0, y: position))
                lines.addLine(to: CGPoint(x: size.width, y: position))
            }
            context.stroke(lines, with: .color(colors.line), lineWidth: 1)
            context.draw(
                Text("A").font(.system(size: 13, weight: .semibold)).foregroundStyle(colors.accent),
                at: CGPoint(x: cell / 2, y: cell / 2))
        }
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
    }
}

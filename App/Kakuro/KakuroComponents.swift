import SwiftUI

struct KakuroIconButton: View {
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
            Image(systemName: symbol)
                .font(.system(size: 18))
                .frame(width: 38, height: 44)
                .background(on ? KakuroColors.of(scheme).selected : .clear, in: Circle())
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

struct KakuroBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
        .accessibilityIdentifier("back")
    }
}

struct KakuroDialogButton: Identifiable {
    let title: String
    let tag: String?
    let action: () -> Void

    var id: String {
        title
    }
}

struct KakuroDialog<Content: View>: View {
    let title: String
    let tag: String?
    let buttons: [KakuroDialogButton]
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
                            .foregroundStyle(KakuroColors.of(scheme).accent)
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

struct KakuroScreenTitle: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            KakuroBackButton(action: onBack)
            Text(title).font(.largeTitle.weight(.regular))
            Spacer()
        }
    }
}

struct KakuroTileStyle: ViewModifier {
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

struct KakuroGameIcon: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = KakuroColors.of(scheme)
        ZStack {
            Canvas { context, size in
                let cell = size.width / 2
                context.fill(Path(CGRect(x: 0, y: 0, width: cell, height: cell)), with: .color(colors.block))
                context.fill(Path(CGRect(x: cell, y: 0, width: cell, height: cell)), with: .color(colors.background))
                context.fill(Path(CGRect(x: 0, y: cell, width: cell, height: cell)), with: .color(colors.background))
                context.fill(Path(CGRect(x: cell, y: cell, width: cell, height: cell)), with: .color(colors.block))
                var lines = Path()
                lines.move(to: .zero)
                lines.addLine(to: CGPoint(x: cell, y: cell))
                for line in 0...2 {
                    let position = CGFloat(line) * cell
                    lines.move(to: CGPoint(x: position, y: 0))
                    lines.addLine(to: CGPoint(x: position, y: size.height))
                    lines.move(to: CGPoint(x: 0, y: position))
                    lines.addLine(to: CGPoint(x: size.width, y: position))
                }
                context.stroke(lines, with: .color(colors.line), lineWidth: 1)
            }
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: 28, height: 28)
                    Text("1").font(.system(size: 18)).foregroundStyle(colors.digit).frame(width: 28, height: 28)
                }
                HStack(spacing: 0) {
                    Text("2").font(.system(size: 18)).foregroundStyle(colors.digit).frame(width: 28, height: 28)
                    Color.clear.frame(width: 28, height: 28)
                }
            }
        }
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
    }
}

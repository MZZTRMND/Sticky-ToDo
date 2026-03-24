import SwiftUI

struct QuickAddOverlayView: View {
    let onSubmit: (String) -> Void
    let onClose: () -> Void

    @State private var text = ""
    @State private var isButtonHovered = false
    @State private var shakeTrigger: CGFloat = 0
    @State private var isAnimatingIn = false
    @State private var isClosing = false
    @State private var placeholderIndex = 0
    @FocusState private var isInputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    private let placeholderTimer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.opacity(isAnimatingIn ? 0.10 : 0.0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissOverlay()
                }

            HStack(spacing: 10) {
                ZStack(alignment: .leading) {
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(Layout.rotatingPlaceholders[placeholderIndex])
                            .id(placeholderIndex)
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(placeholderTextColor)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.25), value: placeholderIndex)
                    }

                    TextField("", text: $text)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(textColor)
                }
                .focused($isInputFocused)
                .onSubmit(submit)
                .onExitCommand {
                    dismissOverlay()
                }
                .padding(.leading, 32)

                Button(action: submit) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(addButtonIconColor)
                        .frame(width: 56, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(addButtonBackgroundColor)
                        )
                }
                .buttonStyle(.plain)
                .scaleEffect(isButtonHovered ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: isButtonHovered)
                .onHover { hovering in
                    isButtonHovered = hovering
                }
                .padding(.trailing, 16)
            }
            .frame(width: 620, height: 84)
            .background(
                RoundedRectangle(cornerRadius: 42, style: .continuous)
                    .fill(isDark ? Color.clear : Color.white)
                    .overlay {
                        if isDark {
                            RoundedRectangle(cornerRadius: 42, style: .continuous)
                                .fill(.regularMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 42, style: .continuous)
                                        .fill(Theme.darkBase.opacity(0.35))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 42, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
            )
            .scaleEffect(isAnimatingIn ? 1.0 : 0.965)
            .opacity(isAnimatingIn ? 1.0 : 0.0)
            .offset(y: isAnimatingIn ? 0 : 6)
            .modifier(ShakeEffect(animatableData: shakeTrigger))
        }
        .onAppear {
            isAnimatingIn = false
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                isAnimatingIn = true
            }
            DispatchQueue.main.async {
                isInputFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stickyToDoQuickAddFocusRequested)) { _ in
            DispatchQueue.main.async {
                isInputFocused = true
            }
        }
        .onReceive(placeholderTimer) { _ in
            rotatePlaceholderIfNeeded()
        }
    }

    private var textColor: Color {
        isDark ? .white : Theme.textPrimary
    }

    private var placeholderTextColor: Color {
        isDark ? Color.white.opacity(0.4) : Theme.placeholder
    }

    private var addButtonBackgroundColor: Color {
        isDark ? .white : Theme.textPrimary
    }

    private var addButtonIconColor: Color {
        isDark ? Theme.textPrimary : .white
    }

    private var isDark: Bool {
        colorScheme == .dark
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                shakeTrigger += 1
            }
            return
        }
        onSubmit(trimmed)
        text = ""
        dismissOverlay()
    }

    private func rotatePlaceholderIfNeeded() {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            placeholderIndex = (placeholderIndex + 1) % Layout.rotatingPlaceholders.count
        }
    }

    private func dismissOverlay() {
        guard isClosing == false else { return }
        isClosing = true
        withAnimation(.easeInOut(duration: 0.16)) {
            isAnimatingIn = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            onClose()
            isClosing = false
        }
    }
}

private enum Layout {
    static let rotatingPlaceholders: [String] = [
        "Add today's task",
        "What do you want to do today?",
        "What's on your mind?",
        "Make today count…"
    ]
}

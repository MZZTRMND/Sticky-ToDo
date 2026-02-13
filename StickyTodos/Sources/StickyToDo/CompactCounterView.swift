import SwiftUI
import AppKit

struct CompactCounterView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var settings: AppSettings
    let onExpand: () -> Void
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(backgroundColor)

            Text("\(store.taskCount)")
                .font(.system(size: 68, weight: .bold))
                .foregroundStyle(numberColor)
                .frame(width: 100, height: 100, alignment: .center)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(badgeBackgroundColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(badgeIconColor)
                        )
                        .offset(x: 0, y: 0)
                }
        }
        .frame(width: 100, height: 100)
        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .scaleEffect(hasAppeared ? 1.0 : 0.92)
        .opacity(hasAppeared ? 1.0 : 0.0)
        .onAppear {
            hasAppeared = false
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                hasAppeared = true
            }
        }
        .onTapGesture(count: 2) {
            onExpand()
        }
        .contextMenu {
            Button("Expand ⌘⌥M") {
                onExpand()
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var isDark: Bool {
        switch settings.appearance {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    private var backgroundColor: Color {
        isDark
            ? Color(nsColor: NSColor(calibratedRed: 0.118, green: 0.118, blue: 0.118, alpha: 1.0))
            : .white
    }

    private var numberColor: Color {
        isDark ? .white : Theme.textPrimary
    }

    private var badgeBackgroundColor: Color {
        isDark ? .white : Theme.textPrimary
    }

    private var badgeIconColor: Color {
        isDark ? Theme.textPrimary : .white
    }
}

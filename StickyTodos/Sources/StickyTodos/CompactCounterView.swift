import SwiftUI

struct CompactCounterView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var settings: AppSettings
    let onExpand: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(backgroundColor)

            Text("\(store.taskCount)")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(numberColor)

            Circle()
                .fill(badgeBackgroundColor)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(badgeIconColor)
                )
                .offset(x: 8, y: -8)
        }
        .frame(width: 160, height: 160)
        .contentShape(Circle())
        .onTapGesture {
            onExpand()
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

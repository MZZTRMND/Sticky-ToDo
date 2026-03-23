import SwiftUI
import AppKit

struct CompactCounterView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme
    let onExpand: () -> Void
    @State private var hasAppeared = false

    var body: some View {
        let previewCount = taskPreview.count
        let showsOverflowIndicator = hasMoreTasks
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                        .fill(isDark ? Color.black.opacity(0.80) : Color.white.opacity(0.80))
                )

            VStack(alignment: .leading, spacing: Layout.taskSpacing) {
                Text(compactDateTitle)
                    .font(.system(size: Layout.headerFontSize, weight: .bold))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .frame(height: Layout.headerLineHeight, alignment: .leading)

                VStack(alignment: .leading, spacing: Layout.taskSpacing) {
                    ForEach(taskPreview) { task in
                        Text(task.title)
                            .font(.system(size: Layout.taskFontSize, weight: .regular))
                            .foregroundStyle(task.isDone ? completedTextColor : primaryTextColor)
                            .strikethrough(task.isDone, color: completedTextColor)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(height: Layout.taskLineHeight, alignment: .leading)
                    }

                    if showsOverflowIndicator {
                        Text("...")
                            .font(.system(size: Layout.taskFontSize, weight: .regular))
                            .foregroundStyle(primaryTextColor.opacity(0.7))
                            .lineLimit(1)
                            .frame(height: Layout.taskLineHeight, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, previewCount > 0 ? Layout.headerToListSpacing : 0)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
        }
        .frame(width: Layout.width, height: Layout.height(previewCount: previewCount, showsOverflowIndicator: showsOverflowIndicator))
        .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
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
        colorScheme == .dark
    }

    private var primaryTextColor: Color {
        isDark ? .white : Theme.textPrimary
    }

    private var completedTextColor: Color {
        isDark ? Color.white.opacity(0.25) : Theme.textPrimary.opacity(0.4)
    }

    private var compactDateTitle: String {
        let date = Date.now
        let dayNumber = Calendar.current.component(.day, from: date)
        let weekday = date.formatted(.dateTime.weekday(.abbreviated))
        return "\(dayNumber) \(weekday)"
    }

    private var visibleTasksForPreview: [TaskItem] {
        let tasksOnly = store.tasks.filter { $0.isDivider == false }
        return settings.showCompletedTasks ? tasksOnly : tasksOnly.filter { $0.isDone == false }
    }

    private var taskPreview: [TaskItem] {
        Array(visibleTasksForPreview.prefix(Layout.maxPreviewTasks))
    }

    private var hasMoreTasks: Bool {
        visibleTasksForPreview.count > Layout.maxPreviewTasks
    }
}

private enum Layout {
    static let width: CGFloat = 180
    static let cornerRadius: CGFloat = 32
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 16
    static let headerFontSize: CGFloat = 24
    static let headerLineHeight: CGFloat = 30
    static let headerToListSpacing: CGFloat = 4
    static let taskFontSize: CGFloat = 16
    static let taskLineHeight: CGFloat = 24
    static let taskSpacing: CGFloat = 2
    static let maxPreviewTasks: Int = 3

    static func height(previewCount: Int, showsOverflowIndicator: Bool) -> CGFloat {
        let visibleLines = previewCount + (showsOverflowIndicator ? 1 : 0)
        let listLinesHeight = CGFloat(visibleLines) * taskLineHeight
        let listSpacingHeight = CGFloat(max(0, visibleLines - 1)) * taskSpacing
        let listTopGap = previewCount > 0 ? headerToListSpacing : 0
        return (verticalPadding * 2) + headerLineHeight + listTopGap + listLinesHeight + listSpacingHeight
    }
}

extension CompactCounterView {
    static func compactWindowSize(previewCount: Int, showsOverflowIndicator: Bool) -> NSSize {
        NSSize(width: Layout.width, height: Layout.height(previewCount: previewCount, showsOverflowIndicator: showsOverflowIndicator))
    }
}

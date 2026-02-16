import SwiftUI
import AppKit

struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    @Binding var editTrigger: Bool
    @State private var isCircleHovered = false
    @State private var isTrashHovered = false
    @State private var isRowHovered = false
    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var progressRotation: Double = 0
    @State private var isTitleHovered = false
    @State private var showTitleTooltip = false
    @State private var titleAvailableWidth: CGFloat = 0
    @State private var tooltipWorkItem: DispatchWorkItem?
    @FocusState private var isEditingFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(task.isDone ? (colorScheme == .dark ? .white : Theme.doneGreen) : .clear)
                .overlay(
                    Group {
                        if task.isInProgress {
                            Circle()
                                .stroke(
                                    circleStrokeColor,
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 3])
                                )
                                .rotationEffect(.degrees(progressRotation))
                        } else if task.isDone == false {
                            Circle()
                                .stroke(circleStrokeColor, lineWidth: 2)
                        }
                    }
                )
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(task.isDone ? (colorScheme == .dark ? Theme.textPrimary : .white) : .clear)
                )
                .onHover { hovering in
                    isCircleHovered = hovering
                }

            VStack(alignment: .leading, spacing: 12) {
                if isEditing {
                    TextField("", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(textPrimaryColor)
                        .focused($isEditingFocused)
                        .onSubmit(commitEdit)
                        .onExitCommand {
                            cancelEdit()
                        }
                        .onChange(of: isEditingFocused) { focused in
                            if focused == false {
                                commitEdit()
                            }
                        }
                } else {
                    Text(task.title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(task.isDone ? completedTextColor : textPrimaryColor)
                        .strikethrough(task.isDone, color: completedTextColor)
                        .lineLimit(1)
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(key: TaskTitleWidthPreferenceKey.self, value: proxy.size.width)
                            }
                        )
                        .onPreferenceChange(TaskTitleWidthPreferenceKey.self) { value in
                            titleAvailableWidth = value
                        }
                        .onHover { hovering in
                            isTitleHovered = hovering
                            handleTitleHoverChanged(hovering)
                        }
                        .onTapGesture(count: 2) {
                            startEdit()
                        }
                }
            }
            .contentShape(Rectangle())

            Spacer()

            if task.isImportant {
                Circle()
                    .fill(Theme.accentOrange)
                    .frame(width: 8, height: 8)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(isTrashHovered ? .red : trashColor)
                    .font(.system(size: 18, weight: .regular))
            }
            .buttonStyle(.plain)
            .opacity(isRowHovered ? 1 : 0)
            .onHover { hovering in
                isTrashHovered = hovering
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing == false, isTrashHovered == false else { return }
            onToggle()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .fill(isRowHovered ? rowHoverColor : Color.white.opacity(0.001))
        )
        .overlay(alignment: .topLeading) {
            if showTitleTooltip && isEditing == false && isTitleTruncated {
                taskTitleTooltip
                    .padding(.leading, 48)
                    .offset(y: -10)
                    .transition(.opacity)
            }
        }
        .onHover { hovering in
            isRowHovered = hovering
        }
        .animation(.easeInOut(duration: 0.18), value: isRowHovered)
        .animation(.easeInOut(duration: 0.18), value: isCircleHovered)
        .animation(.easeInOut(duration: 0.18), value: isTrashHovered)
        .onAppear {
            updateProgressAnimation(task.isInProgress)
        }
        .onChange(of: task.isInProgress) { isInProgress in
            updateProgressAnimation(isInProgress)
        }
        .onChange(of: editTrigger) { shouldEdit in
            guard shouldEdit else { return }
            startEdit()
            editTrigger = false
        }
        .onDisappear {
            cancelTitleTooltipWorkItem()
        }
    }

    private var circleStrokeColor: Color {
        if task.isDone {
            return Theme.doneGreen
        }
        if colorScheme == .dark {
            return isCircleHovered ? Color.white : Color.white.opacity(0.2)
        }
        return isCircleHovered ? Theme.iconDark : Theme.iconLight
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Theme.textPrimary
    }

    private var rowHoverColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Theme.rowHover
    }

    private var trashColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.4) : Theme.textPrimary.opacity(0.4)
    }

    private var completedTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.25) : Theme.textPrimary.opacity(0.4)
    }

    private func startEdit() {
        showTitleTooltip = false
        cancelTitleTooltipWorkItem()
        draftTitle = task.title
        isEditing = true
        isEditingFocused = true
    }

    private func commitEdit() {
        guard isEditing else { return }
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false && trimmed != task.title {
            onRename(trimmed)
        }
        isEditing = false
        showTitleTooltip = false
        cancelTitleTooltipWorkItem()
    }

    private func cancelEdit() {
        isEditing = false
        draftTitle = task.title
        showTitleTooltip = false
        cancelTitleTooltipWorkItem()
    }

    private func updateProgressAnimation(_ isInProgress: Bool) {
        if isInProgress {
            progressRotation = 0
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                progressRotation = 360
            }
        } else {
            progressRotation = 0
        }
    }

    private var isTitleTruncated: Bool {
        guard titleAvailableWidth > 0 else { return false }
        let measured = (task.title as NSString).size(
            withAttributes: [.font: NSFont.systemFont(ofSize: 16, weight: .regular)]
        ).width
        return measured > titleAvailableWidth + 1
    }

    private var taskTitleTooltip: some View {
        Text(task.title)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(colorScheme == .dark ? Color.white : Theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.88) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.10), radius: 10, x: 0, y: 4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 260, alignment: .leading)
    }

    private func handleTitleHoverChanged(_ hovering: Bool) {
        cancelTitleTooltipWorkItem()
        if hovering == false || isEditing || isTitleTruncated == false {
            withAnimation(.easeOut(duration: 0.12)) {
                showTitleTooltip = false
            }
            return
        }

        let workItem = DispatchWorkItem {
            guard isTitleHovered, isEditing == false, isTitleTruncated else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                showTitleTooltip = true
            }
        }
        tooltipWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func cancelTitleTooltipWorkItem() {
        tooltipWorkItem?.cancel()
        tooltipWorkItem = nil
    }
}

private struct TaskTitleWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

import SwiftUI

struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    @State private var isCircleHovered = false
    @State private var isTrashHovered = false
    @State private var isRowHovered = false
    @State private var isEditing = false
    @State private var draftTitle = ""
    @FocusState private var isEditingFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(task.isDone ? (colorScheme == .dark ? .white : Theme.doneGreen) : .clear)
                    .overlay(
                        Group {
                            if task.isDone == false {
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
                        .onTapGesture(count: 2) {
                            startEdit()
                        }
                }

                Spacer()
            }
            .contentShape(Rectangle())

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
            onToggle()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .fill(isRowHovered ? rowHoverColor : .clear)
        )
        .onHover { hovering in
            isRowHovered = hovering
        }
        .animation(.easeInOut(duration: 0.18), value: isRowHovered)
        .animation(.easeInOut(duration: 0.18), value: isCircleHovered)
        .animation(.easeInOut(duration: 0.18), value: isTrashHovered)
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
        colorScheme == .dark ? .white : Theme.textPrimary.opacity(0.5)
    }

    private var completedTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.5) : Theme.textPrimary.opacity(0.5)
    }

    private func startEdit() {
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
    }

    private func cancelEdit() {
        isEditing = false
        draftTitle = task.title
    }
}

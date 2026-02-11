import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onPasteImage: (NSImage) -> Void
    @Binding var editTrigger: Bool
    @State private var isCircleHovered = false
    @State private var isTrashHovered = false
    @State private var isRowHovered = false
    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var isTaskImageHovered = false
    @State private var cachedThumbnail: NSImage?
    @FocusState private var isEditingFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: hasImage ? .firstTextBaseline : .center, spacing: 12) {
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
                        .onPasteCommand(of: [.image]) { _ in
                            if let image = NSImage(pasteboard: NSPasteboard.general) {
                                onPasteImage(image)
                            }
                        }
                        .onDrop(of: [UTType.image, UTType.fileURL], isTargeted: nil) { providers in
                            for provider in providers {
                                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                                        guard let data = item as? Data,
                                              let url = URL(dataRepresentation: data, relativeTo: nil),
                                              let image = NSImage(contentsOf: url) else { return }
                                        onPasteImage(image)
                                    }
                                    return true
                                }
                                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                                    provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                                        guard let data, let image = NSImage(data: data) else { return }
                                        onPasteImage(image)
                                    }
                                    return true
                                }
                            }
                            return false
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

                if let image = taskImage {
                    image
                }
            }
            .contentShape(Rectangle())

            Spacer()

            if task.isImportant {
                Circle()
                    .fill(Color.red)
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
            onToggle()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: hasImage ? 25 : 100, style: .continuous)
                .fill(isRowHovered ? rowHoverColor : .clear)
        )
        .onHover { hovering in
            isRowHovered = hovering
        }
        .animation(.easeInOut(duration: 0.18), value: isRowHovered)
        .animation(.easeInOut(duration: 0.18), value: isCircleHovered)
        .animation(.easeInOut(duration: 0.18), value: isTrashHovered)
        .onChange(of: editTrigger) { shouldEdit in
            guard shouldEdit else { return }
            startEdit()
            editTrigger = false
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

    private var hasImage: Bool {
        task.imageFilename != nil
    }

    private var taskImage: AnyView? {
        guard let filename = task.imageFilename else { return nil }
        let url = ImageStore.url(for: filename)
        guard let nsImage = cachedThumbnail ?? ImageStore.thumbnail(named: filename, size: 80) else { return nil }
        return AnyView(
            ZStack {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(isTaskImageHovered ? 0.2 : 0))
                    .frame(width: 80, height: 80)

                Image(systemName: "eye")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white)
                    .opacity(isTaskImageHovered ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                isTaskImageHovered = hovering
            }
            .animation(.easeInOut(duration: 0.18), value: isTaskImageHovered)
            .onTapGesture {
                NSWorkspace.shared.open(url)
            }
            .onAppear {
                cachedThumbnail = ImageStore.thumbnail(named: filename, size: 80)
            }
            .onDisappear {
                cachedThumbnail = nil
            }
        )
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

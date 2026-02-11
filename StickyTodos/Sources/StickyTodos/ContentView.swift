import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = TaskStore()
    @State private var newTaskText = ""
    @FocusState private var isInputFocused: Bool
    @State private var isAddHovered = false
    @State private var isInputHovered = false
    @State private var isCounterHovered = false
    @State private var shakeTrigger: CGFloat = 0
    @State private var draggingId: UUID?
    @State private var isListHovered = false
    @State private var windowRef: NSWindow?
    @State private var editingDividerId: UUID?
    @State private var editingTaskId: UUID?
    @State private var newTaskImageFilename: String?
    @State private var isDraftImageHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let date = Date.now
        let dayNumber = Calendar.current.component(.day, from: date)
        ZStack {
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                .fill(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))

            VStack(spacing: 0) {
                VStack(spacing: Layout.headerToInputSpacing) {
                    header(dayNumber: dayNumber, date: date)
                    inputRow
                }
                list
            }
            .padding(.top, Layout.cardPadding)
            .padding(.horizontal, Layout.cardPadding)

        }
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))
        .frame(minWidth: Layout.cardWidth, maxWidth: 600)
        .frame(height: windowHeight)
        .onAppear {
            isInputFocused = true
        }
        .background(
            WindowAccessor { window in
                windowRef = window
                bringWindowToFront()
                updateWindowDragBehavior()
            }
        )
        .onTapGesture {
            activateWindow()
        }
        .onChange(of: isListHovered) { _ in
            updateWindowDragBehavior()
        }
    }

    private func header(dayNumber: Int, date: Date) -> some View {
        ZStack {
            WindowDragView()
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: Layout.headerInnerSpacing) {
                        Text("\(dayNumber)")
                            .font(.system(size: Layout.dayFontSize, weight: .bold))
                            .foregroundStyle(primaryTextColor)
                            .frame(minWidth: Layout.dayFrameWidth, minHeight: Layout.headerHeight, alignment: .leading)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(date, format: .dateTime.month(.wide))
                                .font(.system(size: Layout.monthFontSize, weight: .bold))
                                .foregroundStyle(primaryTextColor)
                                .frame(height: Layout.headerLineHeight, alignment: .topLeading)
                            Text(date, format: .dateTime.weekday(.wide))
                                .font(.system(size: Layout.weekdayFontSize, weight: .regular))
                                .foregroundStyle(primaryTextColor)
                                .frame(height: Layout.headerLineHeight, alignment: .topLeading)
                        }
                    }
                }
                Spacer()

                if store.taskCount > 0 {
                    Button(action: clearCompleted) {
                        Text(counterLabel)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(counterColor)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.2), value: store.taskCount)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, -25)
                    .onHover { hovering in
                        isCounterHovered = hovering
                    }
                    .disabled(completedCount == 0)
                    .help(completedCount > 0 ? "Clear \(completedCount)" : "Task count")
                }
            }
            .frame(height: Layout.headerHeight, alignment: .top)
            .padding(.trailing, Layout.headerTrailingPadding)
        }
        .frame(height: Layout.headerHeight, alignment: .top)
        .contextMenu {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var inputRow: some View {
        ZStack {
            inputBackground
            HStack {
                ZStack(alignment: .leading) {
                    if newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Add today task")
                            .font(.system(size: Layout.inputFontSize, weight: .regular))
                            .foregroundStyle(placeholderTextColor)
                    }

                    TextField("", text: $newTaskText)
                        .textFieldStyle(.plain)
                        .font(.system(size: Layout.inputFontSize, weight: .regular))
                        .foregroundStyle(primaryTextColor)
                }
                .padding(.leading, Layout.inputTextLeading)
                .focused($isInputFocused)
                .onSubmit(addTask)

                Spacer()

                if let draftImage = draftImageView {
                    draftImage
                        .padding(.trailing, 2)
                }

                Button(action: addTask) {
                    Image(systemName: "plus")
                        .font(.system(size: Layout.addIconSize, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: Layout.addButtonWidth, height: Layout.addButtonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: Layout.addButtonCornerRadius, style: .continuous)
                                .fill(Theme.accentYellow)
                        )
                }
                .buttonStyle(.plain)
                .help("Add task")
                .scaleEffect(isAddHovered ? 1.1 : 1.0)
                .animation(.spring(response: Layout.addButtonSpringResponse, dampingFraction: Layout.addButtonSpringDamping), value: isAddHovered)
                .onHover { hovering in
                    isAddHovered = hovering
                }
                .padding(.trailing, Layout.addButtonTrailing)
            }
        }
        .frame(height: Layout.inputHeight)
        .onHover { hovering in
            isInputHovered = hovering
        }
        .contentShape(Rectangle())
        .onTapGesture {
            activateWindow()
            isInputFocused = true
        }
        .onDrop(of: [UTType.image, UTType.fileURL], isTargeted: nil) { providers in
            handleImageProviders(providers)
        }
        .onPasteCommand(of: [.image]) { providers in
            _ = handleImageProviders(providers)
        }
        .modifier(ShakeEffect(animatableData: shakeTrigger))
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(store.tasks.enumerated()), id: \.element.id) { index, task in
                    if task.isDivider {
                        DividerRow(
                            title: task.title,
                            onRename: { store.updateTitle(for: task, title: $0) },
                            editTrigger: Binding(
                                get: { editingDividerId == task.id },
                                set: { isEditing in
                                    if isEditing {
                                        editingDividerId = task.id
                                    } else if editingDividerId == task.id {
                                        editingDividerId = nil
                                    }
                                }
                            )
                        )
                        .opacity(draggingId == task.id ? 0.4 : 1.0)
                        .onDrag {
                            draggingId = task.id
                            return NSItemProvider(object: task.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: ReorderDropDelegate(target: task, store: store, draggingId: $draggingId))
                        .contextMenu {
                            rowContextMenu(for: task)
                        }
                    } else {
                        TaskRow(
                            task: task,
                            onToggle: { store.toggleDone(for: task) },
                            onDelete: { store.delete(task) },
                            onRename: { store.updateTitle(for: task, title: $0) },
                            onPasteImage: { image in
                                if let filename = ImageStore.saveImage(image) {
                                    store.updateImage(for: task, filename: filename)
                                }
                            },
                            editTrigger: Binding(
                                get: { editingTaskId == task.id },
                                set: { isEditing in
                                    if isEditing {
                                        editingTaskId = task.id
                                    } else if editingTaskId == task.id {
                                        editingTaskId = nil
                                    }
                                }
                            )
                        )
                        .opacity(draggingId == task.id ? 0.4 : 1.0)
                        .onDrag {
                            draggingId = task.id
                            return NSItemProvider(object: task.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: ReorderDropDelegate(target: task, store: store, draggingId: $draggingId))
                        .contextMenu {
                            rowContextMenu(for: task)
                        }
                    }

                    if index < store.tasks.count - 1 {
                        Color.clear
                            .frame(height: Layout.listRowSpacing)
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button("Add divider") {
                                    store.addDivider(at: index + 1)
                                    activateWindow()
                                    isInputFocused = true
                                }
                            }
                    }
                }
            }
            .padding(.top, Layout.listTopPadding)
        }
        .scrollIndicators(.hidden)
        .animation(.easeInOut(duration: 0.1), value: store.tasks)
        .frame(maxHeight: Layout.listMaxHeight)
        .onHover { hovering in
            isListHovered = hovering
        }
    }

    private func addTask() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.35)) {
                shakeTrigger += 1
            }
            return
        }
        store.addTask(title: trimmed, imageFilename: newTaskImageFilename)
        newTaskText = ""
        newTaskImageFilename = nil
        isInputFocused = true
        activateWindow()
    }

    private func activateWindow() {
        NSApp.activate(ignoringOtherApps: true)
        windowRef?.makeKeyAndOrderFront(nil)
        windowRef?.makeKey()
    }

    private func bringWindowToFront() {
        windowRef?.makeKeyAndOrderFront(nil)
        windowRef?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateWindowDragBehavior() {
        windowRef?.isMovableByWindowBackground = !isListHovered
    }

    @ViewBuilder
    private func rowContextMenu(for task: TaskItem) -> some View {
        if task.isDivider {
            Button("Edit name") {
                editingDividerId = task.id
                activateWindow()
            }
            Button("Add divider") {
                store.addDivider(above: task)
                activateWindow()
                isInputFocused = true
            }
            Button("Delete divider") {
                store.delete(task)
            }
        } else {
            Button("Edit task") {
                editingTaskId = task.id
                activateWindow()
            }
            Button(task.imageFilename == nil ? "Add image…" : "Replace image…") {
                pickImageForTask(task)
            }
            if task.imageFilename != nil {
                Button("Remove image") {
                    store.updateImage(for: task, filename: nil)
                }
            }
            if task.isImportant {
                Button("Unmark as important") {
                    store.setImportant(false, for: task)
                }
            } else {
                Button("Mark as important") {
                    store.setImportant(true, for: task)
                }
            }
        }
    }

    private var draftImageView: AnyView? {
        guard let filename = newTaskImageFilename else { return nil }
        guard let nsImage = ImageStore.thumbnail(named: filename, size: 40) else { return nil }
        return AnyView(
            ZStack {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))

                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .fill(Color.black.opacity(isDraftImageHovered ? 0.2 : 0))
                    .frame(width: 40, height: 40)

                Button(action: removeDraftImage) {
                    ZStack {
                        Circle()
                            .fill(Theme.textPrimary)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                    .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .opacity(isDraftImageHovered ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                isDraftImageHovered = hovering
            }
            .animation(.easeInOut(duration: 0.18), value: isDraftImageHovered)
        )
    }

    private func removeDraftImage() {
        if let filename = newTaskImageFilename {
            ImageStore.deleteImage(named: filename)
        }
        newTaskImageFilename = nil
    }

    private func handleImageProviders(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          let image = NSImage(contentsOf: url) else { return }
                    saveDraftImage(image)
                }
                return true
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data, let image = NSImage(data: data) else { return }
                    saveDraftImage(image)
                }
                return true
            }
        }
        return false
    }

    private func saveDraftImage(_ image: NSImage) {
        DispatchQueue.main.async {
            if let existing = newTaskImageFilename {
                ImageStore.deleteImage(named: existing)
            }
            newTaskImageFilename = ImageStore.saveImage(image)
        }
    }

    private func pickImageForTask(_ task: TaskItem) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
            if let filename = ImageStore.saveImage(image) {
                DispatchQueue.main.async {
                    store.updateImage(for: task, filename: filename)
                }
            }
        }
    }
}

private extension ContentView {
    var isDark: Bool { colorScheme == .dark }

    var primaryTextColor: Color {
        isDark ? .white : Theme.textPrimary
    }

    var placeholderTextColor: Color {
        isDark ? Color.white.opacity(0.4) : Theme.placeholder
    }

    var cardBackground: Color {
        isDark
            ? Color(nsColor: NSColor(calibratedRed: 0.118, green: 0.118, blue: 0.118, alpha: 1.0)) // #1E1E1E
            : .white
    }

    var inputBackground: some View {
        let fill = isDark
            ? Color(nsColor: NSColor(calibratedRed: 0.141, green: 0.141, blue: 0.141, alpha: 1.0)) // #242424
            : Color.white
        let stroke = isDark
            ? (isInputHovered
               ? Color(nsColor: NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.22, alpha: 1.0)) // #383838
               : Color(nsColor: NSColor(calibratedRed: 0.188, green: 0.188, blue: 0.188, alpha: 1.0))) // #303030
            : Color.black.opacity(isInputHovered ? 0.15 : 0.08)

        return RoundedRectangle(cornerRadius: Layout.inputCornerRadius, style: .continuous)
            .fill(fill)
            .animation(.easeInOut(duration: 0.18), value: isInputHovered)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.inputCornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            // Keep both shadows to preserve the current visual (stroke + soft drop)
            .shadow(color: isDark ? .clear : Color.black.opacity(0.08), radius: 0, x: 0, y: 0)
            .shadow(color: isDark ? .clear : Color.black.opacity(0.08), radius: 3, x: 0, y: 1.5)
    }

    var windowHeight: CGFloat {
        let listCount = store.tasks.count
        let listHeight = listCount == 0
            ? 0
            : listContentHeight
        let dynamicHeight = (Layout.cardPadding * 2)
            + Layout.headerHeight
            + Layout.inputHeight
            + (Layout.headerToInputSpacing * 2)
            + listHeight
        return store.tasks.isEmpty ? dynamicHeight : min(Layout.maxHeight, dynamicHeight)
    }

    var listContentHeight: CGFloat {
        let rowHeights = store.tasks.map { task -> CGFloat in
            if task.isDivider {
                return Layout.dividerRowHeight
            }
            let base = Layout.rowHeight
            return task.imageFilename == nil ? base : base + Layout.taskImageSpacing + Layout.taskImageSize
        }
        let rowsHeight = rowHeights.reduce(0, +)
        let spacingHeight = CGFloat(max(0, store.tasks.count - 1)) * Layout.listRowSpacing
        return rowsHeight + spacingHeight + Layout.listVerticalPadding + Layout.listTopPadding
    }


    var completedCount: Int {
        store.tasks.filter { $0.isDone }.count
    }

    var counterLabel: String {
        if isCounterHovered && completedCount > 0 {
            return "Clear \(completedCount)"
        }
        return "\(completedCount) of \(store.taskCount) tasks"
    }

    var counterColor: Color {
        if isCounterHovered {
            return completedCount == 0
                ? (isDark ? Color.white.opacity(0.35) : Theme.textPrimary.opacity(0.35))
                : (isDark ? Color.white.opacity(0.8) : Theme.textPrimary.opacity(0.8))
        }
        return isDark ? Color.white.opacity(0.4) : Theme.textPrimary.opacity(0.4)
    }

    func clearCompleted() {
        guard completedCount > 0 else { return }
        store.clearCompleted()
    }

}

private enum Layout {
    static let cardCornerRadius: CGFloat = 40
    static let cardWidth: CGFloat = 350
    static let cardPadding: CGFloat = 20

    static let emptyHeight: CGFloat = 200
    static let maxHeight: CGFloat = 550

    static let headerHeight: CGFloat = 60
    static let headerLineHeight: CGFloat = 30
    static let headerTrailingPadding: CGFloat = 8
    static let headerInnerSpacing: CGFloat = 8
    static let headerToInputSpacing: CGFloat = 24

    static let dayFontSize: CGFloat = 66
    static let monthFontSize: CGFloat = 24
    static let weekdayFontSize: CGFloat = 24
    static let dayFrameWidth: CGFloat = 46

    static let inputHeight: CGFloat = 56
    static let inputCornerRadius: CGFloat = 100
    static let inputFontSize: CGFloat = 16
    static let inputTextLeading: CGFloat = 24

    static let addButtonWidth: CGFloat = 40
    static let addButtonHeight: CGFloat = 40
    static let addButtonCornerRadius: CGFloat = 20
    static let addButtonTrailing: CGFloat = 10
    static let addIconSize: CGFloat = 20
    static let addButtonSpringResponse: CGFloat = 0.28
    static let addButtonSpringDamping: CGFloat = 0.7

    static let rowHeight: CGFloat = 48
    static let dividerRowHeight: CGFloat = 30
    static let taskImageSize: CGFloat = 100
    static let taskImageSpacing: CGFloat = 12
    static let listRowSpacing: CGFloat = 10
    static let listTopPadding: CGFloat = 20
    static let listVerticalPadding: CGFloat = 4
    static let listMaxHeight: CGFloat = 550
}

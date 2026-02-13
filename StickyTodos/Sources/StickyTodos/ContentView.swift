import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var windowModeController: WindowModeController
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let date = Date.now
        let dayNumber = Calendar.current.component(.day, from: date)
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                    .fill(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))

                VStack(spacing: 0) {
                    VStack(spacing: Layout.headerToInputSpacing) {
                        header(dayNumber: dayNumber, date: date)
                        inputRow
                    }
                    if store.tasks.isEmpty {
                        Color.clear
                            .frame(height: Layout.emptyStateBottomSpace)
                    } else {
                        list
                    }
                }
                .padding(.top, Layout.cardPadding)
                .padding(.horizontal, Layout.cardPadding)
            }
            .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))

            if isCounterHovered && store.taskCount > 0 {
                counterTooltip
                    .padding(.top, Layout.counterTooltipTop)
                    .padding(.trailing, Layout.counterTooltipTrailing)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(2)
            }
        }
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
                    HStack(alignment: .center, spacing: Layout.headerInnerSpacing) {
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
                    ZStack {
                        Circle()
                            .stroke(counterTrackColor, lineWidth: Layout.counterLineWidth)
                            .frame(width: Layout.counterSize, height: Layout.counterSize)

                        Circle()
                            .trim(from: 0, to: counterProgress)
                            .stroke(
                                counterProgressColor,
                                style: StrokeStyle(lineWidth: Layout.counterLineWidth, lineCap: .butt)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: Layout.counterSize, height: Layout.counterSize)
                            .animation(.easeInOut(duration: 0.2), value: counterProgress)
                    }
                    .frame(width: Layout.counterHitSize, height: Layout.counterHitSize)
                    .contentShape(Rectangle())
                    .scaleEffect(isCounterHovered ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isCounterHovered)
                    .padding(.top, -25)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isCounterHovered = hovering
                        }
                    }
                }
            }
            .frame(height: Layout.headerHeight, alignment: .top)
            .padding(.trailing, Layout.headerTrailingPadding)
        }
        .frame(height: Layout.headerHeight, alignment: .top)
        .contextMenu {
            Button("\(windowModeController.menuTitle) ⌘⌥M") {
                windowModeController.requestToggle()
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var inputRow: some View {
        let hasInput = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        return ZStack {
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

                if hasInput {
                    Button(action: addTask) {
                        Image(systemName: "plus")
                            .font(.system(size: Layout.addIconSize, weight: .medium))
                            .foregroundStyle(addButtonIconColor)
                            .frame(width: Layout.addButtonWidth, height: Layout.addButtonHeight)
                            .background(
                                RoundedRectangle(cornerRadius: Layout.addButtonCornerRadius, style: .continuous)
                                    .fill(addButtonBackgroundColor)
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
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.82, anchor: .center)),
                        removal: .opacity.combined(with: .scale(scale: 0.94, anchor: .center))
                    ))
                }
            }
        }
        .frame(height: Layout.inputHeight)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: hasInput)
        .onHover { hovering in
            isInputHovered = hovering
        }
        .contentShape(Rectangle())
        .onTapGesture {
            activateWindow()
            isInputFocused = true
        }
        .modifier(ShakeEffect(animatableData: shakeTrigger))
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(store.tasks.enumerated()), id: \.element.id) { index, task in
                    listItem(for: task)
                        .opacity(draggingId == task.id ? 0.4 : 1.0)
                        .onDrag {
                            draggingId = task.id
                            return NSItemProvider(object: task.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: ReorderDropDelegate(target: task, store: store, draggingId: $draggingId))
                        .contextMenu {
                            rowContextMenu(for: task)
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
            .padding(.bottom, Layout.listBottomPadding)
        }
        .scrollIndicators(.hidden)
        .animation(.easeInOut(duration: 0.1), value: store.tasks)
        .frame(maxHeight: Layout.listMaxHeight)
        .onHover { hovering in
            isListHovered = hovering
        }
    }

    @ViewBuilder
    private func listItem(for task: TaskItem) -> some View {
        if task.isDivider {
            DividerRow(
                title: task.title,
                onRename: { store.updateTitle(for: task, title: $0) },
                editTrigger: dividerEditBinding(for: task.id)
            )
        } else {
            TaskRow(
                task: task,
                onToggle: { store.toggleDone(for: task) },
                onDelete: { store.delete(task) },
                onRename: { store.updateTitle(for: task, title: $0) },
                editTrigger: taskEditBinding(for: task.id)
            )
        }
    }

    private func addTask() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                shakeTrigger += 1
            }
            return
        }
        store.addTask(title: trimmed)
        newTaskText = ""
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
            Button(task.isInProgress ? "Unmark in progress" : "Mark as in progress") {
                store.setInProgress(task.isInProgress == false, for: task)
            }
            Divider()

            Button(task.isImportant ? "Unmark as important" : "Mark as important") {
                store.setImportant(task.isImportant == false, for: task)
            }
            Divider()

            Button("Edit task") {
                editingTaskId = task.id
                activateWindow()
            }
            Button {
                store.delete(task)
            } label: {
                Text("Delete task")
            }
        }
    }

    private func dividerEditBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { editingDividerId == id },
            set: { isEditing in
                if isEditing {
                    editingDividerId = id
                } else if editingDividerId == id {
                    editingDividerId = nil
                }
            }
        )
    }

    private func taskEditBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { editingTaskId == id },
            set: { isEditing in
                if isEditing {
                    editingTaskId = id
                } else if editingTaskId == id {
                    editingTaskId = nil
                }
            }
        )
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
            : (isInputHovered
               ? Color(nsColor: NSColor(calibratedRed: 0.922, green: 0.922, blue: 0.922, alpha: 1.0)) // #EBEBEB
               : Color(nsColor: NSColor(calibratedRed: 0.941, green: 0.941, blue: 0.941, alpha: 1.0))) // #F0F0F0
        let stroke = isDark
            ? (isInputHovered
               ? Color(nsColor: NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.22, alpha: 1.0)) // #383838
               : Color(nsColor: NSColor(calibratedRed: 0.188, green: 0.188, blue: 0.188, alpha: 1.0))) // #303030
            : .clear

        return RoundedRectangle(cornerRadius: Layout.inputCornerRadius, style: .continuous)
            .fill(fill)
            .animation(.easeInOut(duration: 0.18), value: isInputHovered)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.inputCornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: isDark ? 1 : 0)
            )
    }

    var windowHeight: CGFloat {
        let listHeight = store.tasks.isEmpty
            ? Layout.emptyStateBottomSpace
            : listContentHeight
        let dynamicHeight = Layout.cardPadding
            + Layout.headerHeight
            + Layout.inputHeight
            + Layout.headerToInputSpacing
            + listHeight
        return store.tasks.isEmpty ? dynamicHeight : min(Layout.maxHeight, dynamicHeight)
    }

    var listContentHeight: CGFloat {
        let rowHeights = store.tasks.map { task -> CGFloat in
            task.isDivider ? Layout.dividerRowHeight : Layout.rowHeight
        }
        let rowsHeight = rowHeights.reduce(0, +)
        let spacingHeight = CGFloat(max(0, store.tasks.count - 1)) * Layout.listRowSpacing
        return rowsHeight + spacingHeight + Layout.listTopPadding + Layout.listBottomPadding
    }


    var completedCount: Int {
        store.tasks.filter { $0.isDone }.count
    }

    var remainingCount: Int {
        max(0, store.taskCount - completedCount)
    }

    var counterProgress: CGFloat {
        guard store.taskCount > 0 else { return 0 }
        return CGFloat(completedCount) / CGFloat(store.taskCount)
    }

    var counterTrackColor: Color {
        isDark ? Color.white.opacity(0.18) : Theme.textPrimary.opacity(0.12)
    }

    var counterProgressColor: Color {
        isDark ? .white : Theme.textPrimary
    }

    var addButtonBackgroundColor: Color {
        isDark ? .white : Theme.textPrimary
    }

    var addButtonIconColor: Color {
        isDark ? Theme.textPrimary : .white
    }

    var counterTooltip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Completed: \(completedCount)")
            Text("Not completed: \(remainingCount)")
        }
        .font(.system(size: 12, weight: .regular))
        .foregroundStyle(isDark ? Color.white : Theme.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isDark ? Color.black.opacity(0.88) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(isDark ? 0.22 : 0.10), radius: 10, x: 0, y: 4)
        .fixedSize()
    }

}

private enum Layout {
    static let cardCornerRadius: CGFloat = 40
    static let cardWidth: CGFloat = 350
    static let cardPadding: CGFloat = 20

    static let maxHeight: CGFloat = 600

    static let headerHeight: CGFloat = 60
    static let headerLineHeight: CGFloat = 24
    static let headerTrailingPadding: CGFloat = 0
    static let headerInnerSpacing: CGFloat = 8
    static let headerToInputSpacing: CGFloat = 20
    static let counterSize: CGFloat = 24
    static let counterLineWidth: CGFloat = 4
    static let counterHitSize: CGFloat = 36
    static let counterTooltipTop: CGFloat = 40
    static let counterTooltipTrailing: CGFloat = 8

    static let dayFontSize: CGFloat = 56
    static let monthFontSize: CGFloat = 20
    static let weekdayFontSize: CGFloat = 20
    static let dayFrameWidth: CGFloat = 46

    static let inputHeight: CGFloat = 56
    static let inputCornerRadius: CGFloat = 100
    static let inputFontSize: CGFloat = 18
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
    static let listRowSpacing: CGFloat = 10
    static let listTopPadding: CGFloat = 16
    static let listBottomPadding: CGFloat = 16
    static let listMaxHeight: CGFloat = 600
    static let emptyStateBottomSpace: CGFloat = 20
}

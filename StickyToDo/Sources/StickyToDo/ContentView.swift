import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var windowModeController: WindowModeController
    @State private var isHeaderQuickAddHovered = false
    @State private var isHeaderQuickAddTooltipVisible = false
    @State private var headerQuickAddTooltipWorkItem: DispatchWorkItem?
    @State private var draggingId: UUID?
    @State private var delayedDoneTaskIDs: Set<UUID> = []
    @State private var isDragCursorActive = false
    @State private var isListHovered = false
    @State private var windowRef: NSWindow?
    @State private var editingTaskId: UUID?
    @State private var selectedCategoryID: UUID?
    @State private var editingCategoryID: UUID?
    @State private var isAllCategoryDropTargeted = false
    @State private var categoryDropTargetedIDs: Set<UUID> = []
    @State private var isAllCategoryHovered = false
    @State private var isCategorySectionHovered = false
    @State private var isAddCategoryHovered = false
    @State private var categoryHoveredIDs: Set<UUID> = []
    @State private var categoryNameDraft = ""
    @State private var isCategoryCreationPresented = false
    @State private var pendingCategoryTaskID: UUID?
    @State private var newCategoryName = ""
    @State private var isCategoryModalAnimatingIn = false
    @State private var categoryShakeTrigger: CGFloat = 0
    @FocusState private var isCategoryInputFocused: Bool
    @FocusState private var focusedCategoryID: UUID?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let date = Date.now
        let dayNumber = Calendar.current.component(.day, from: date)
        ZStack {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                    .fill(cardBackgroundColor)

                VStack(spacing: 0) {
                    header(dayNumber: dayNumber, date: date)
                        .padding(.top, Layout.headerSectionTopPadding)
                        .padding(.horizontal, Layout.sectionHorizontalPadding)

                    if shouldShowCategorySection {
                        categorySection
                    }
                    if visibleTasks.isEmpty {
                        emptyStateView
                            .frame(height: Layout.emptyStateBottomSpace)
                    } else {
                        list
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.top, Layout.cardTopPadding)
                .padding(.horizontal, Layout.cardPadding)

                if isCategoryCreationPresented {
                    categoryCreationOverlay
                        .transition(.opacity.animation(.easeInOut(duration: 0.18)))
                        .zIndex(4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if isHeaderQuickAddTooltipVisible {
                    quickAddButtonTooltip
                        .padding(.top, Layout.quickAddTooltipTop)
                        .padding(.trailing, Layout.quickAddTooltipTrailing)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .frame(minWidth: Layout.cardWidth, maxWidth: 600)
        .frame(height: windowHeight)
        .background(
            WindowAccessor { window in
                windowRef = window
                updateWindowDragBehavior()
            }
        )
        .onTapGesture {
            activateWindow()
        }
        .onChange(of: isListHovered) { _ in
            updateWindowDragBehavior()
        }
        .onChange(of: draggingId) { value in
            if value == nil {
                endDragCursor()
            }
        }
        .onChange(of: store.categories) { categories in
            if let selectedCategoryID, categories.contains(where: { $0.id == selectedCategoryID }) == false {
                self.selectedCategoryID = nil
            }
        }
        .onDisappear {
            cancelHeaderQuickAddTooltipWorkItem()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(Layout.emptyStateMessage.line1)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(placeholderTextColor)
                    .multilineTextAlignment(.center)

                Text(Layout.emptyStateMessage.line2)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(placeholderTextColor)
                    .multilineTextAlignment(.center)

                Text(Layout.emptyStateMessage.line3)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
                            .frame(minHeight: Layout.headerHeight, alignment: .leading)
                            .fixedSize(horizontal: true, vertical: false)
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

                Button(action: {
                    cancelHeaderQuickAddTooltipWorkItem()
                    isHeaderQuickAddTooltipVisible = false
                    presentQuickAddOverlay()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: Layout.addIconSize, weight: .medium))
                        .foregroundStyle(headerAddButtonIconColor)
                        .frame(width: Layout.addButtonWidth, height: Layout.addButtonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: Layout.addButtonCornerRadius, style: .continuous)
                                .fill(headerAddButtonBackgroundColor)
                        )
                }
                .buttonStyle(.plain)
                .scaleEffect(isHeaderQuickAddHovered ? 1.1 : 1.0)
                .animation(
                    .spring(
                        response: Layout.addButtonSpringResponse,
                        dampingFraction: Layout.addButtonSpringDamping
                    ),
                    value: isHeaderQuickAddHovered
                )
                .padding(.top, -25)
                .onHover { hovering in
                    isHeaderQuickAddHovered = hovering
                    handleHeaderQuickAddHoverChanged(hovering)
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

    private var categorySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Layout.categoryChipSpacing) {
                categoryChip(
                    title: "All",
                    isSelected: selectedCategoryID == nil,
                    isDropHovered: isAllCategoryDropTargeted,
                    isPointerHovered: isAllCategoryHovered
                ) {
                    selectedCategoryID = nil
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: CategoryChipDropDelegate(
                        categoryID: nil,
                        store: store,
                        draggingId: $draggingId,
                        isTargeted: $isAllCategoryDropTargeted
                    )
                )
                .onHover { hovering in
                    isAllCategoryHovered = hovering
                }

                ForEach(store.categories) { category in
                    categoryChipView(for: category)
                }

                if isCategorySectionHovered {
                    addCategoryChip
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(.horizontal, Layout.sectionHorizontalPadding + 1)
            .padding(.vertical, 1)
        }
        .clipped()
        .frame(height: Layout.categoryBarHeight)
        .padding(.top, Layout.inputToCategorySpacing)
        .onHover { hovering in
            isCategorySectionHovered = hovering
        }
        .overlay(alignment: .leading) {
            LinearGradient(
                colors: [cardBackgroundColor, cardBackgroundColor.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: Layout.categoryEdgeFadeWidth)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .trailing) {
            LinearGradient(
                colors: [cardBackgroundColor, cardBackgroundColor.opacity(0)],
                startPoint: .trailing,
                endPoint: .leading
            )
            .frame(width: Layout.categoryEdgeFadeWidth)
            .allowsHitTesting(false)
        }
    }

    private var addCategoryChip: some View {
        Button {
            beginCategoryCreation(for: nil)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(primaryTextColor)
                .frame(width: Layout.categoryChipHeight, height: Layout.categoryChipHeight)
                .background(
                    Capsule(style: .continuous)
                        .fill(isAddCategoryHovered ? categoryChipPointerHoverBackgroundColor : Color.clear)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            isAddCategoryHovered ? categoryChipPointerHoverStrokeColor : categoryChipStrokeColor,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: isAddCategoryHovered)
        .onHover { hovering in
            isAddCategoryHovered = hovering
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }

    private var categoryCreationOverlay: some View {
        ZStack {
            Color.black.opacity(isCategoryModalAnimatingIn ? 0.30 : 0.0)
                .onTapGesture {
                    cancelCategoryCreation()
                }

            TextField("New category", text: $newCategoryName)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(primaryTextColor)
                .padding(.horizontal, 16)
                .frame(width: 260, height: Layout.categoryModalInputHeight)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isDark ? Color.clear : Color.white)
                        .overlay {
                            if isDark {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.regularMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Theme.darkBase.opacity(0.35))
                                    )
                                    .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            }
                        }
                )
                .focused($isCategoryInputFocused)
                .onSubmit(confirmCategoryCreation)
                .onExitCommand {
                    cancelCategoryCreation()
                }
                .scaleEffect(isCategoryModalAnimatingIn ? 1.0 : 0.965)
                .opacity(isCategoryModalAnimatingIn ? 1.0 : 0.0)
                .offset(y: isCategoryModalAnimatingIn ? 0 : 6)
                .modifier(ShakeEffect(animatableData: categoryShakeTrigger))
        }
        .onAppear {
            isCategoryModalAnimatingIn = false
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                isCategoryModalAnimatingIn = true
            }
        }
        .onDisappear {
            isCategoryModalAnimatingIn = false
        }
    }

    @ViewBuilder
    private func categoryChipView(for category: TaskCategory) -> some View {
        if editingCategoryID == category.id {
            TextField("", text: $categoryNameDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(primaryTextColor)
                .padding(.horizontal, Layout.categoryChipHorizontalPadding)
                .frame(height: Layout.categoryChipHeight)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.clear)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(categoryChipStrokeColor, lineWidth: 1)
                )
                .focused($focusedCategoryID, equals: category.id)
                .onSubmit {
                    commitCategoryRename(categoryID: category.id)
                }
                .onExitCommand {
                    cancelCategoryRename()
                }
                .onChange(of: focusedCategoryID) { focused in
                    guard focused != category.id else { return }
                    if editingCategoryID == category.id {
                        commitCategoryRename(categoryID: category.id)
                    }
                }
        } else {
            categoryChip(
                title: category.name,
                isSelected: selectedCategoryID == category.id,
                isDropHovered: categoryDropTargetedIDs.contains(category.id),
                isPointerHovered: categoryHoveredIDs.contains(category.id)
            ) {
                selectedCategoryID = category.id
            }
            .contextMenu {
                Button("Edit name") {
                    beginCategoryRename(category)
                }
                Button("Delete tab") {
                    deleteCategory(category.id)
                }
            }
            .onDrop(
                of: [UTType.text],
                delegate: CategoryChipDropDelegate(
                    categoryID: category.id,
                    store: store,
                    draggingId: $draggingId,
                    isTargeted: categoryDropTargetBinding(for: category.id)
                )
            )
            .onHover { hovering in
                if hovering {
                    categoryHoveredIDs.insert(category.id)
                } else {
                    categoryHoveredIDs.remove(category.id)
                }
            }
        }
    }

    private func categoryChip(
        title: String,
        isSelected: Bool,
        isDropHovered: Bool,
        isPointerHovered: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(categoryChipTextColor(isSelected: isSelected, isDropHovered: isDropHovered))
                .lineLimit(1)
                .padding(.horizontal, Layout.categoryChipHorizontalPadding)
                .frame(height: Layout.categoryChipHeight)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            isDropHovered && isSelected == false
                            ? categoryChipDropHoverBackgroundColor(isSelected: isSelected)
                            : (
                                isSelected
                                ? categoryChipSelectedBackgroundColor
                                : (isPointerHovered ? categoryChipPointerHoverBackgroundColor : Color.clear)
                            )
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            categoryChipBorderColor(
                                isSelected: isSelected,
                                isDropHovered: isDropHovered,
                                isPointerHovered: isPointerHovered
                            ),
                            lineWidth: isSelected ? 0 : 1
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: isDropHovered)
        .animation(.easeInOut(duration: 0.12), value: isPointerHovered)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }

    private func categoryDropTargetBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { categoryDropTargetedIDs.contains(id) },
            set: { isTargeted in
                if isTargeted {
                    categoryDropTargetedIDs.insert(id)
                } else {
                    categoryDropTargetedIDs.remove(id)
                }
            }
        )
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Layout.listRowSpacing) {
                ForEach(Array(visibleTasks.enumerated()), id: \.element.id) { index, task in
                    taskRowView(for: task)
                        .overlay(alignment: .bottom) {
                            if index < visibleTasks.count - 1 {
                                Rectangle()
                                    .fill(taskGhostDividerColor)
                                    .frame(height: 1)
                                    .padding(.horizontal, Layout.taskGhostDividerHorizontalInset)
                                    .offset(y: Layout.taskGhostDividerYOffset)
                            }
                        }
                }
            }
            .padding(.top, Layout.listTopPadding)
        }
        .scrollIndicators(.hidden)
        .animation(.easeInOut(duration: 0.1), value: store.tasks)
        .frame(maxHeight: Layout.listMaxHeight)
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [cardBackgroundColor, cardBackgroundColor.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Layout.listTopFadeHeight)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [cardBackgroundColor, cardBackgroundColor.opacity(0)],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: Layout.listBottomFadeHeight)
            .allowsHitTesting(false)
        }
        .onHover { hovering in
            isListHovered = hovering
        }
        .onDisappear {
            endDragCursor()
        }
    }

    @ViewBuilder
    private func listItem(for task: TaskItem) -> some View {
        TaskRow(
            task: task,
            showCheckboxes: settings.showCheckboxes,
            onToggle: { toggleDoneWithDelay(taskID: task.id) },
            onDelete: { store.delete(task) },
            onRename: { store.updateTitle(for: task, title: $0) },
            categoryBadge: categoryBadge(for: task),
            isDragging: draggingId == task.id,
            editTrigger: taskEditBinding(for: task.id)
        )
    }

    @ViewBuilder
    private func taskRowView(for task: TaskItem) -> some View {
        listItem(for: task)
            .id(task.id)
            .opacity(draggingId == task.id ? 0.4 : 1.0)
            .onDrag {
                beginDragCursor()
                draggingId = task.id
                return NSItemProvider(object: task.id.uuidString as NSString)
            }
            .onDrop(of: [.text], delegate: ReorderDropDelegate(target: task, store: store, draggingId: $draggingId))
            .contextMenu {
                rowContextMenu(for: task)
            }
    }

    private func toggleDoneWithDelay(taskID: UUID) {
        guard let currentTask = store.activeTasks.first(where: { $0.id == taskID }) else { return }

        if currentTask.isDone {
            delayedDoneTaskIDs.remove(taskID)
            withAnimation(.easeInOut(duration: 0.2)) {
                store.toggleDone(for: currentTask)
            }
            return
        }

        delayedDoneTaskIDs.insert(taskID)
        withAnimation(.easeInOut(duration: 0.2)) {
            store.toggleDone(for: currentTask)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.doneMoveDelay) {
            withAnimation(.easeInOut(duration: 0.22)) {
                _ = delayedDoneTaskIDs.remove(taskID)
            }
        }
    }

    private func activateWindow() {
        NSApp.activate(ignoringOtherApps: true)
        windowRef?.makeKeyAndOrderFront(nil)
        windowRef?.makeKey()
    }

    private func updateWindowDragBehavior() {
        windowRef?.isMovableByWindowBackground = !isListHovered
    }

    private func presentQuickAddOverlay() {
        NotificationCenter.default.post(name: .stickyToDoPresentQuickAddRequested, object: nil)
    }

    private func handleHeaderQuickAddHoverChanged(_ hovering: Bool) {
        cancelHeaderQuickAddTooltipWorkItem()

        guard hovering else {
            withAnimation(.easeOut(duration: 0.12)) {
                isHeaderQuickAddTooltipVisible = false
            }
            return
        }

        let workItem = DispatchWorkItem {
            guard isHeaderQuickAddHovered else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                isHeaderQuickAddTooltipVisible = true
            }
        }
        headerQuickAddTooltipWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func cancelHeaderQuickAddTooltipWorkItem() {
        headerQuickAddTooltipWorkItem?.cancel()
        headerQuickAddTooltipWorkItem = nil
    }

    private func beginCategoryCreation(for taskID: UUID?) {
        cancelCategoryRename()
        pendingCategoryTaskID = taskID
        newCategoryName = ""
        isCategoryCreationPresented = true
        activateWindow()
        DispatchQueue.main.async {
            isCategoryInputFocused = true
        }
    }

    private func confirmCategoryCreation() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                categoryShakeTrigger += 1
            }
            return
        }
        guard let category = store.createCategory(name: newCategoryName) else { return }
        if let taskID = pendingCategoryTaskID {
            store.assignCategory(category.id, toTaskID: taskID)
        } else {
            selectedCategoryID = category.id
        }
        cancelCategoryCreation()
    }

    private func cancelCategoryCreation() {
        newCategoryName = ""
        pendingCategoryTaskID = nil
        isCategoryCreationPresented = false
        isCategoryInputFocused = false
    }

    private func beginDragCursor() {
        guard isDragCursorActive == false else { return }
        NSCursor.closedHand.push()
        isDragCursorActive = true
    }

    private func endDragCursor() {
        guard isDragCursorActive else { return }
        NSCursor.pop()
        isDragCursorActive = false
    }

    private func beginCategoryRename(_ category: TaskCategory) {
        cancelCategoryCreation()
        editingCategoryID = category.id
        categoryNameDraft = category.name
        activateWindow()
        DispatchQueue.main.async {
            focusedCategoryID = category.id
        }
    }

    private func commitCategoryRename(categoryID: UUID) {
        store.renameCategory(id: categoryID, to: categoryNameDraft)
        cancelCategoryRename()
    }

    private func cancelCategoryRename() {
        categoryNameDraft = ""
        editingCategoryID = nil
        focusedCategoryID = nil
    }

    private func deleteCategory(_ categoryID: UUID) {
        if selectedCategoryID == categoryID {
            selectedCategoryID = nil
        }
        if editingCategoryID == categoryID {
            cancelCategoryRename()
        }
        store.deleteCategory(id: categoryID)
    }

    @ViewBuilder
    private func rowContextMenu(for task: TaskItem) -> some View {
        Button(task.isDone ? "Unmark as done" : "Mark as done") {
            toggleDoneWithDelay(taskID: task.id)
        }

        Button(task.isInProgress ? "Unmark in progress" : "Mark as in progress") {
            store.setInProgress(task.isInProgress == false, for: task)
        }

        Button(task.isImportant ? "Unmark as important" : "Mark as important") {
            store.setImportant(task.isImportant == false, for: task)
        }
        Divider()

        Menu("Move to category") {
            Button {
                store.assignCategory(nil, to: task)
            } label: {
                if task.categoryID == nil {
                    Label("No category", systemImage: "checkmark")
                } else {
                    Text("No category")
                }
            }

            if store.categories.isEmpty == false {
                Divider()
            }

            if store.categories.isEmpty {
                Button("Create new category") {
                    beginCategoryCreation(for: task.id)
                }
            } else {
                ForEach(store.categories) { category in
                    Button {
                        store.assignCategory(category.id, to: task)
                    } label: {
                        if task.categoryID == category.id {
                            Label(category.name, systemImage: "checkmark")
                        } else {
                            Text(category.name)
                        }
                    }
                }
                Divider()
                Button("Create new category") {
                    beginCategoryCreation(for: task.id)
                }
            }
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
    var visibleTasks: [TaskItem] {
        visiblePendingTasks + visibleDoneTasks
    }

    var visiblePendingTasks: [TaskItem] {
        filteredTasks.filter { $0.isDone == false || delayedDoneTaskIDs.contains($0.id) }
    }

    var visibleDoneTasks: [TaskItem] {
        guard settings.showCompletedTasks else { return [] }
        return filteredTasks
            .filter { $0.isDone && delayedDoneTaskIDs.contains($0.id) == false }
            .sorted { lhs, rhs in
                let leftDate = lhs.doneAt ?? lhs.createdAt
                let rightDate = rhs.doneAt ?? rhs.createdAt
                if leftDate != rightDate {
                    return leftDate > rightDate
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    var filteredTasks: [TaskItem] {
        let base = settings.showCompletedTasks
            ? store.activeTasks
            : store.activeTasks.filter { $0.isDone == false }

        guard let selectedCategoryID else { return base }
        return base.filter { $0.categoryID == selectedCategoryID }
    }

    var isDark: Bool { colorScheme == .dark }

    var primaryTextColor: Color {
        isDark ? .white : Theme.textPrimary
    }

    var placeholderTextColor: Color {
        isDark ? Color.white.opacity(0.4) : Theme.placeholder
    }

    var cardBackgroundColor: Color {
        isDark ? Theme.darkBase : Theme.lightCard
    }

    var windowHeight: CGFloat {
        let listHeight = visibleTasks.isEmpty
            ? Layout.emptyStateBottomSpace
            : listContentHeight
        let dynamicHeight = Layout.cardTopPadding
            + Layout.headerSectionTopPadding
            + Layout.headerHeight
            + categorySectionHeight
            + listHeight
        return visibleTasks.isEmpty ? dynamicHeight : min(Layout.maxHeight, dynamicHeight)
    }

    var shouldShowCategorySection: Bool {
        store.categories.isEmpty == false
    }

    var categorySectionHeight: CGFloat {
        guard shouldShowCategorySection else { return 0 }
        return Layout.inputToCategorySpacing + Layout.categoryBarHeight
    }

    var listContentHeight: CGFloat {
        let rowsHeight = CGFloat(visibleTasks.count) * Layout.rowHeight
        let spacingHeight = CGFloat(max(0, visibleTasks.count - 1)) * Layout.listRowSpacing
        return rowsHeight + spacingHeight + Layout.listTopPadding + Layout.listBottomPadding
    }

    var showCategoryBadges: Bool {
        selectedCategoryID == nil
    }

    var categoryChipSelectedBackgroundColor: Color {
        isDark ? Color.white : Theme.textPrimary
    }

    var categoryChipSelectedTextColor: Color {
        isDark ? Theme.textPrimary : .white
    }

    var categoryChipStrokeColor: Color {
        isDark ? Color.white.opacity(0.10) : Theme.textPrimary.opacity(0.08)
    }

    func categoryChipDropHoverBackgroundColor(isSelected: Bool) -> Color {
        if isSelected {
            return categoryChipSelectedBackgroundColor
        }
        return isDark ? .white : .black
    }

    func categoryChipDropHoverStrokeColor(isSelected: Bool) -> Color {
        if isSelected {
            return .clear
        }
        return Theme.textPrimary
    }

    func categoryChipTextColor(isSelected: Bool, isDropHovered: Bool) -> Color {
        if isSelected {
            return categoryChipSelectedTextColor
        }
        if isDropHovered {
            return isDark ? Theme.textPrimary : .white
        }
        return primaryTextColor
    }

    var categoryChipPointerHoverBackgroundColor: Color {
        isDark ? Color.white.opacity(0.05) : Theme.textPrimary.opacity(0.04)
    }

    var categoryChipPointerHoverStrokeColor: Color {
        isDark ? Color.white.opacity(0.16) : Theme.textPrimary.opacity(0.12)
    }

    func categoryChipBorderColor(
        isSelected: Bool,
        isDropHovered: Bool,
        isPointerHovered: Bool
    ) -> Color {
        if isSelected {
            return .clear
        }
        if isDropHovered {
            return categoryChipDropHoverStrokeColor(isSelected: isSelected)
        }
        if isPointerHovered {
            return categoryChipPointerHoverStrokeColor
        }
        return categoryChipStrokeColor
    }

    func categoryBadge(for task: TaskItem) -> TaskCategoryBadge? {
        guard showCategoryBadges else { return nil }
        guard let category = store.category(for: task.categoryID) else { return nil }
        return TaskCategoryBadge(
            name: category.name,
            color: Theme.color(fromHex: category.colorHex)
        )
    }


    var headerAddButtonBackgroundColor: Color {
        isDark ? .white : Theme.textPrimary
    }

    var headerAddButtonIconColor: Color {
        isDark ? Theme.textPrimary : .white
    }

    var taskGhostDividerColor: Color {
        isDark ? Color.white.opacity(0.05) : Theme.textPrimary.opacity(0.06)
    }

    var quickAddButtonTooltip: some View {
        Text("Press ⌥⌘N to add a task")
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(isDark ? Color.white : Theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isDark ? Theme.darkBase : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                isDark ? Color.white.opacity(0.12) : Theme.textPrimary.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: Color.black.opacity(isDark ? 0.22 : 0.10), radius: 10, x: 0, y: 4)
            .fixedSize()
    }

}

private enum Layout {
    static let cardCornerRadius: CGFloat = 40
    static let cardWidth: CGFloat = 350
    static let cardTopPadding: CGFloat = 0
    static let cardPadding: CGFloat = 0
    static let sectionHorizontalPadding: CGFloat = 16
    static let headerSectionTopPadding: CGFloat = 16

    static let maxHeight: CGFloat = 600

    static let headerHeight: CGFloat = 60
    static let headerLineHeight: CGFloat = 24
    static let headerTrailingPadding: CGFloat = 0
    static let headerInnerSpacing: CGFloat = 8

    static let dayFontSize: CGFloat = 56
    static let monthFontSize: CGFloat = 20
    static let weekdayFontSize: CGFloat = 20

    static let addButtonWidth: CGFloat = 40
    static let addButtonHeight: CGFloat = 40
    static let addButtonCornerRadius: CGFloat = 20
    static let addIconSize: CGFloat = 20
    static let addButtonSpringResponse: CGFloat = 0.28
    static let addButtonSpringDamping: CGFloat = 0.7
    static let quickAddTooltipTop: CGFloat = 40
    static let quickAddTooltipTrailing: CGFloat = 8

    static let inputToCategorySpacing: CGFloat = 12
    static let categoryBarHeight: CGFloat = 30
    static let categoryChipHeight: CGFloat = 28
    static let categoryChipHorizontalPadding: CGFloat = 10
    static let categoryChipSpacing: CGFloat = 6
    static let categoryEdgeFadeWidth: CGFloat = 18
    static let categoryModalInputHeight: CGFloat = 44

    static let rowHeight: CGFloat = 48
    static let listRowSpacing: CGFloat = 4
    static let listTopPadding: CGFloat = 16
    static let listBottomPadding: CGFloat = 16
    static let listMaxHeight: CGFloat = 600
    static let listTopFadeHeight: CGFloat = 20
    static let listBottomFadeHeight: CGFloat = 20
    static let taskGhostDividerHorizontalInset: CGFloat = 16
    static let taskGhostDividerYOffset: CGFloat = 2
    static let doneMoveDelay: TimeInterval = 0.30
    static let emptyStateBottomSpace: CGFloat = 100

    static let emptyStateMessage = EmptyStateMessage(
        title: "All clear.",
        line1: "Nothing on your plate today.",
        line2: "Add something or enjoy the quiet.",
        line3: "Press ⌥⌘N to add a task."
    )
}

private struct EmptyStateMessage {
    let title: String
    let line1: String
    let line2: String
    let line3: String
}

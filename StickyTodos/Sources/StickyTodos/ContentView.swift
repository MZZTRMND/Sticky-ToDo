import SwiftUI

struct ContentView: View {
    @StateObject private var store = TaskStore()
    @State private var newTaskText = ""
    @FocusState private var isInputFocused: Bool
    @State private var isAddHovered = false
    @State private var isInputHovered = false
    @State private var shakeTrigger: CGFloat = 0
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
        .frame(width: Layout.cardWidth, height: windowHeight)
        .onAppear {
            isInputFocused = true
        }
        .background(
            WindowAccessor { window in
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        )
    }

    private func header(dayNumber: Int, date: Date) -> some View {
        return HStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: Layout.headerInnerSpacing) {
                    Text("\(dayNumber)")
                        .font(.system(size: Layout.dayFontSize, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: Layout.dayFrameWidth, height: Layout.headerHeight)
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

            if store.tasks.isEmpty == false {
                Text(taskCountLabel)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.textPrimary.opacity(0.5))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: store.tasks.count)
                    .padding(.top, -25)
            }
        }
        .frame(height: Layout.headerHeight, alignment: .top)
        .padding(.trailing, Layout.headerTrailingPadding)
    }

    private var inputRow: some View {
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
        .modifier(ShakeEffect(animatableData: shakeTrigger))
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Layout.listRowSpacing) {
                ForEach(store.tasks) { task in
                    TaskRow(
                        task: task,
                        onToggle: { store.toggleDone(for: task) },
                        onDelete: {
                            store.delete(task)
                        },
                        onRename: { store.updateTitle(for: task, title: $0) }
                    )
                }
            }
            .padding(.top, Layout.listTopPadding)
        }
        .animation(.easeInOut(duration: 0.1), value: store.tasks)
        .frame(maxHeight: Layout.listMaxHeight)
    }

    private func addTask() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.35)) {
                shakeTrigger += 1
            }
            return
        }
        store.addTask(title: trimmed)
        newTaskText = ""
        isInputFocused = true
    }
}

private extension ContentView {
    var isDark: Bool { colorScheme == .dark }

    var primaryTextColor: Color {
        isDark ? .white : Theme.textPrimary
    }

    var placeholderTextColor: Color {
        isDark ? Color.white.opacity(0.5) : Theme.placeholder
    }

    var cardBackground: Color {
        isDark
            ? Color(nsColor: NSColor(calibratedRed: 0.149, green: 0.149, blue: 0.145, alpha: 1.0)) // #262625
            : .white
    }

    var inputBackground: some View {
        let fill = isDark
            ? Color(nsColor: NSColor(calibratedRed: 0.18, green: 0.18, blue: 0.176, alpha: 1.0)) // #2E2E2D
            : Color.white
        let stroke = isDark
            ? (isInputHovered
               ? Color(nsColor: NSColor(calibratedRed: 0.251, green: 0.251, blue: 0.243, alpha: 1.0)) // #40403E
               : Color(nsColor: NSColor(calibratedRed: 0.219, green: 0.219, blue: 0.216, alpha: 1.0))) // #383837
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
            : (CGFloat(listCount) * Layout.rowHeight)
              + (CGFloat(max(0, listCount - 1)) * Layout.listRowSpacing)
              + Layout.listVerticalPadding
        let dynamicHeight = (Layout.cardPadding * 2)
            + Layout.headerHeight
            + Layout.inputHeight
            + (Layout.headerToInputSpacing * 2)
            + listHeight
        return store.tasks.isEmpty ? dynamicHeight : min(Layout.maxHeight, dynamicHeight)
    }

    var taskCountLabel: String {
        let count = store.tasks.count
        return "\(count) task" + (count == 1 ? "" : "s")
    }
}

private enum Layout {
    static let cardCornerRadius: CGFloat = 40
    static let cardWidth: CGFloat = 350
    static let cardPadding: CGFloat = 20

    static let emptyHeight: CGFloat = 200
    static let maxHeight: CGFloat = 500

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

    static let addButtonWidth: CGFloat = 50
    static let addButtonHeight: CGFloat = 40
    static let addButtonCornerRadius: CGFloat = 20
    static let addButtonTrailing: CGFloat = 10
    static let addIconSize: CGFloat = 20
    static let addButtonSpringResponse: CGFloat = 0.28
    static let addButtonSpringDamping: CGFloat = 0.7

    static let rowHeight: CGFloat = 48
    static let listRowSpacing: CGFloat = 10
    static let listTopPadding: CGFloat = 20
    static let listVerticalPadding: CGFloat = 4
    static let listMaxHeight: CGFloat = 550
}

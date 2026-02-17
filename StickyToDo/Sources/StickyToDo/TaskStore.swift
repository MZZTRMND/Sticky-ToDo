import Foundation

final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = [] {
        didSet {
            updateDerivedState()
            guard isLoading == false else { return }
            save()
        }
    }
    @Published private(set) var taskCount: Int = 0
    @Published private(set) var completedTaskCount: Int = 0

    private let storageKey = "StickyToDo.tasks"
    private var isLoading = false
    private var lastSavedData: Data?

    init() {
        load()
        updateDerivedState()
    }

    func addTask(title: String) {
        guard let trimmed = normalizedTitle(from: title) else { return }
        tasks.insert(TaskItem(title: trimmed), at: 0)
    }

    func addDivider(title: String = "New section") {
        tasks.insert(TaskItem(title: title, isDivider: true), at: 0)
    }

    func addDivider(above task: TaskItem, title: String = "New section") {
        guard let index = indexOfTask(task) else { return }
        tasks.insert(TaskItem(title: title, isDivider: true), at: index)
    }

    func addDivider(at index: Int, title: String = "New section") {
        let safeIndex = max(0, min(index, tasks.count))
        tasks.insert(TaskItem(title: title, isDivider: true), at: safeIndex)
    }

    func toggleDone(for task: TaskItem) {
        guard let index = indexOfTask(task) else { return }
        tasks[index].isDone.toggle()
        if tasks[index].isDone {
            tasks[index].isInProgress = false
        }
    }

    func delete(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
    }

    func updateTitle(for task: TaskItem, title: String) {
        guard let trimmed = normalizedTitle(from: title) else { return }
        guard let index = indexOfTask(task) else { return }
        tasks[index].title = trimmed
    }

    func setImportant(_ isImportant: Bool, for task: TaskItem) {
        guard let index = indexOfTask(task) else { return }
        tasks[index].isImportant = isImportant
    }

    func setInProgress(_ isInProgress: Bool, for task: TaskItem) {
        guard let index = indexOfTask(task) else { return }
        tasks[index].isInProgress = isInProgress
        if isInProgress {
            tasks[index].isDone = false
        }
    }

    func moveTask(from sourceId: UUID, to targetId: UUID) {
        guard sourceId != targetId else { return }
        guard let sourceIndex = tasks.firstIndex(where: { $0.id == sourceId }) else { return }
        guard let targetIndex = tasks.firstIndex(where: { $0.id == targetId }) else { return }
        let item = tasks.remove(at: sourceIndex)
        let adjustedIndex = targetIndex > sourceIndex ? targetIndex - 1 : targetIndex
        tasks.insert(item, at: adjustedIndex)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let decoded = try JSONDecoder().decode([TaskItem].self, from: data)
            tasks = decoded
            lastSavedData = data
        } catch {
            tasks = []
            lastSavedData = nil
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(tasks)
            guard data != lastSavedData else { return }
            UserDefaults.standard.set(data, forKey: storageKey)
            lastSavedData = data
        } catch {
            // If save fails, keep running without crashing.
        }
    }

    private func updateDerivedState() {
        var total = 0
        var completed = 0
        for task in tasks where task.isDivider == false {
            total += 1
            if task.isDone {
                completed += 1
            }
        }
        if taskCount != total {
            taskCount = total
        }
        if completedTaskCount != completed {
            completedTaskCount = completed
        }
    }

    // MARK: - Helpers

    private func normalizedTitle(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func indexOfTask(_ task: TaskItem) -> Int? {
        tasks.firstIndex { $0.id == task.id }
    }
}

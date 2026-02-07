import Foundation

final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = [] {
        didSet { save() }
    }

    private let storageKey = "StickyTodos.tasks"

    init() {
        load()
    }

    func addTask(title: String) {
        guard let trimmed = normalizedTitle(from: title) else { return }
        tasks.insert(TaskItem(title: trimmed), at: 0)
    }

    func toggleDone(for task: TaskItem) {
        guard let index = indexOfTask(task) else { return }
        tasks[index].isDone.toggle()
    }

    func delete(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
    }

    func updateTitle(for task: TaskItem, title: String) {
        guard let trimmed = normalizedTitle(from: title) else { return }
        guard let index = indexOfTask(task) else { return }
        tasks[index].title = trimmed
    }

    func clearCompleted() {
        tasks.removeAll { $0.isDone }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([TaskItem].self, from: data)
            tasks = decoded
        } catch {
            tasks = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(tasks)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // If save fails, keep running without crashing.
        }
    }

    // MARK: - Helpers

    private func normalizedTitle(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func indexOfTask(_ task: TaskItem) -> Int? {
        tasks.firstIndex(of: task)
    }
}

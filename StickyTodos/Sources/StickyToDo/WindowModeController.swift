import Foundation

enum WindowMode {
    case full
    case compact
}

final class WindowModeController: ObservableObject {
    static let shared = WindowModeController()

    @Published var mode: WindowMode = .full

    var menuTitle: String {
        mode == .full ? "Minimize" : "Expand"
    }

    func requestToggle() {
        NotificationCenter.default.post(name: .stickyToDoToggleWindowMode, object: nil)
    }
}

extension Notification.Name {
    static let stickyToDoToggleWindowMode = Notification.Name("StickyToDo.ToggleWindowMode")
}

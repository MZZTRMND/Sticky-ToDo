import SwiftUI

final class AppSettings: ObservableObject {
    enum Appearance: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system:
                return "System"
            case .light:
                return "Light"
            case .dark:
                return "Dark"
            }
        }
    }

    static let shared = AppSettings()

    @Published var appearance: Appearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey)
        }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Self.launchAtLoginKey)
        }
    }
    @Published var showInMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showInMenuBar, forKey: Self.showInMenuBarKey)
        }
    }
    @Published var showCompletedTasks: Bool {
        didSet {
            UserDefaults.standard.set(showCompletedTasks, forKey: Self.showCompletedTasksKey)
        }
    }
    @Published var taskFontSize: Double {
        didSet {
            UserDefaults.standard.set(taskFontSize, forKey: Self.taskFontSizeKey)
        }
    }
    @Published var showCheckboxes: Bool {
        didSet {
            UserDefaults.standard.set(showCheckboxes, forKey: Self.showCheckboxesKey)
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private static let appearanceKey = "StickyToDo.appearance"
    private static let launchAtLoginKey = "StickyToDo.launchAtLogin"
    private static let showInMenuBarKey = "StickyToDo.showInMenuBar"
    private static let showCompletedTasksKey = "StickyToDo.showCompletedTasks"
    private static let taskFontSizeKey = "StickyToDo.taskFontSize"
    private static let showCheckboxesKey = "StickyToDo.showCheckboxes"

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.appearanceKey)
        appearance = Appearance(rawValue: stored ?? "") ?? .system
        if UserDefaults.standard.object(forKey: Self.launchAtLoginKey) == nil {
            launchAtLogin = false
        } else {
            launchAtLogin = UserDefaults.standard.bool(forKey: Self.launchAtLoginKey)
        }
        if UserDefaults.standard.object(forKey: Self.showInMenuBarKey) == nil {
            showInMenuBar = true
        } else {
            showInMenuBar = UserDefaults.standard.bool(forKey: Self.showInMenuBarKey)
        }
        if UserDefaults.standard.object(forKey: Self.showCompletedTasksKey) == nil {
            showCompletedTasks = true
        } else {
            showCompletedTasks = UserDefaults.standard.bool(forKey: Self.showCompletedTasksKey)
        }
        let loadedTaskFontSize: Double
        if UserDefaults.standard.object(forKey: Self.taskFontSizeKey) == nil {
            loadedTaskFontSize = 16
        } else {
            let storedTaskFontSize = UserDefaults.standard.double(forKey: Self.taskFontSizeKey)
            loadedTaskFontSize = (14...24).contains(storedTaskFontSize) ? storedTaskFontSize : 16
        }
        taskFontSize = loadedTaskFontSize
        if UserDefaults.standard.object(forKey: Self.showCheckboxesKey) == nil {
            showCheckboxes = true
        } else {
            showCheckboxes = UserDefaults.standard.bool(forKey: Self.showCheckboxesKey)
        }
    }
}

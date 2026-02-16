import SwiftUI

@main
struct StickyToDoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandMenu("Window") {
                Button("Minimize / Expand") {
                    WindowModeController.shared.requestToggle()
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
            }
        }
    }
}

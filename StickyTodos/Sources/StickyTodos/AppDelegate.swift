import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let autosaveDelay: TimeInterval = 0.1

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        configureWindowsSoon()
        configureStatusItem()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeMain(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
    }

    @objc private func windowDidBecomeMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        configureWindow(window)
    }

    private func configureWindowsSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + autosaveDelay) {
            for window in NSApplication.shared.windows {
                self.configureWindow(window)
            }
        }
    }

    private func configureWindow(_ window: NSWindow) {
        applyWindowAppearance(window)
        applyWindowBehavior(window)
        applyWindowChrome(window)
        window.makeKeyAndOrderFront(nil)
        window.makeKey()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "StickyTodos")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Window Configuration

    private func applyWindowAppearance(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func applyWindowBehavior(_ window: NSWindow) {
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Removed autosave to prevent snap-back on focus.
        window.styleMask = [.borderless, .fullSizeContentView, .resizable]
        window.styleMask.remove(.miniaturizable)
        window.styleMask.remove(.closable)
    }

    private func applyWindowChrome(_ window: NSWindow) {
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}

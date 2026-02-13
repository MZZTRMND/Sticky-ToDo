import AppKit
import SwiftUI

// Borderless panel that can still become key to keep text input focused.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var toggleWindowMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureStatusItem()
        createWindow()
    }

    private func createWindow() {
        let hostingView = NSHostingView(
            rootView: RootContentView()
                .environmentObject(settings)
        )
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configurePanel(panel, hostingView: hostingView)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = panel
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainWindowVisibilityDidChange),
            name: NSWindow.didBecomeKeyNotification,
            object: panel
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainWindowVisibilityDidChange),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )
    }

    private func configurePanel(_ panel: NSPanel, hostingView: NSView) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentView = hostingView
    }


    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "StickyTodos")
        }

        let menu = NSMenu()
        let aboutItem = NSMenuItem(title: "About Sticky ToDo", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let toggleItem = NSMenuItem(title: "Hide App", action: #selector(toggleWindowVisibility), keyEquivalent: "h")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        toggleWindowMenuItem = toggleItem
        updateWindowMenuItemTitle()
        statusItem = item
    }

    @objc private func showAbout() {
        if aboutWindow == nil {
            let hostingView = NSHostingView(
                rootView: AboutView(versionText: appVersionText)
            )
            let aboutPanel = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            aboutPanel.title = "About Sticky ToDo"
            aboutPanel.isReleasedWhenClosed = false
            aboutPanel.contentView = hostingView
            aboutWindow = aboutPanel
        }

        aboutWindow?.center()
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let hostingView = NSHostingView(
                rootView: SettingsView()
                    .environmentObject(settings)
            )
            let settingsPanel = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 110),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsPanel.title = "Settings"
            settingsPanel.isReleasedWhenClosed = false
            settingsPanel.contentView = hostingView
            settingsWindow = settingsPanel
        }

        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleWindowVisibility() {
        guard let window else { return }

        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        updateWindowMenuItemTitle()
    }

    @objc private func mainWindowVisibilityDidChange() {
        updateWindowMenuItemTitle()
    }

    private func updateWindowMenuItemTitle() {
        toggleWindowMenuItem?.title = (window?.isVisible == true) ? "Hide App" : "Show App"
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private var appVersionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(short) (\(build))"
    }
}

private struct RootContentView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ContentView()
            .preferredColorScheme(settings.preferredColorScheme)
    }
}

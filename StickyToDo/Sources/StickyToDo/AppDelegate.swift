import AppKit
import Combine
import Carbon
import ServiceManagement
import SwiftUI

// Borderless panel that can still become key to keep text input focused.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private let quickAddHotKeySignature: OSType = 0x5354444F // "STDO"
private let quickAddHotKeyID: UInt32 = 1

private func stickyToDoGlobalHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData, let event else { return OSStatus(eventNotHandledErr) }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    if hotKeyID.signature == quickAddHotKeySignature && hotKeyID.id == quickAddHotKeyID {
        delegate.handleGlobalQuickAddHotKey()
        return noErr
    }
    return OSStatus(eventNotHandledErr)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private let store = TaskStore()
    private let windowModeController = WindowModeController.shared
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var quickAddWindow: NSPanel?
    private var windowMode: WindowMode = .full
    private var fullWindowFrame: NSRect?
    private var hostingView: NSHostingView<AnyView>?
    private var cancellables: Set<AnyCancellable> = []
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandlerRef: EventHandlerRef?

    deinit {
        unregisterGlobalHotKey()
        NotificationCenter.default.removeObserver(self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureStatusItemIfNeeded()
        bindSettingsObservers()
        applyLaunchAtLoginPreference(settings.launchAtLogin)
        createWindow()
        registerGlobalHotKey()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleMinimizeMode),
            name: .stickyToDoToggleWindowMode,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(presentQuickAddFromInAppRequest),
            name: .stickyToDoPresentQuickAddRequested,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterGlobalHotKey()
    }

    private func createWindow() {
        let rootHostingView = NSHostingView(rootView: AnyView(fullRootView()))
        rootHostingView.wantsLayer = true
        rootHostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView = rootHostingView

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configurePanel(panel, hostingView: rootHostingView)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = panel
        applyWindowMode(animated: false)
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


    private func configureStatusItemIfNeeded() {
        guard settings.showInMenuBar else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
            return
        }
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "StickyToDo")
        }

        let menu = NSMenu()
        let aboutItem = NSMenuItem(title: "About Sticky ToDo", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    private func bindSettingsObservers() {
        settings.$showInMenuBar
            .dropFirst()
            .sink { [weak self] isVisible in
                guard let self else { return }
                if isVisible {
                    self.configureStatusItemIfNeeded()
                } else if let item = self.statusItem {
                    NSStatusBar.system.removeStatusItem(item)
                    self.statusItem = nil
                }
            }
            .store(in: &cancellables)

        settings.$launchAtLogin
            .dropFirst()
            .sink { [weak self] isEnabled in
                self?.applyLaunchAtLoginPreference(isEnabled)
            }
            .store(in: &cancellables)

        settings.$showCompletedTasks
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshCompactWindowSizeIfNeeded(animated: true)
            }
            .store(in: &cancellables)

        store.$tasks
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshCompactWindowSizeIfNeeded(animated: true)
            }
            .store(in: &cancellables)
    }

    private func applyLaunchAtLoginPreference(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Keep the toggle consistent with the real system status.
            // This can fail in some unsigned/dev execution contexts.
            let syncedValue = (SMAppService.mainApp.status == .enabled)
            if settings.launchAtLogin != syncedValue {
                settings.launchAtLogin = syncedValue
            }
        }
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
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
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

    @objc private func toggleMinimizeMode() {
        setWindowMode(windowMode == .full ? .compact : .full, animated: true)
    }

    @objc private func mainWindowVisibilityDidChange() {
        // Reserved for future window-state menu sync.
    }

    @objc private func presentQuickAddFromInAppRequest() {
        presentOrFocusQuickAddOverlay()
    }

    private func setWindowMode(_ mode: WindowMode, animated: Bool) {
        guard mode != windowMode else { return }
        if mode == .compact, let window {
            fullWindowFrame = window.frame
        }
        windowMode = mode
        windowModeController.mode = mode
        applyWindowMode(animated: animated)
    }

    private func applyWindowMode(animated: Bool) {
        guard let window else { return }
        let currentFrame = window.frame
        let targetFrame: NSRect
        var shouldRefreshFullSizeOnNextRunLoop = false
        switch windowMode {
        case .full:
            window.styleMask.insert(.resizable)
            window.minSize = NSSize(width: 350, height: 200)
            window.maxSize = NSSize(width: 600, height: 600)
            setRootView(for: .full)
            let targetSize = preferredFullWindowSize(fallback: currentFrame.size)
            targetFrame = centeredFrame(from: currentFrame, targetSize: targetSize)
            shouldRefreshFullSizeOnNextRunLoop = true
        case .compact:
            window.styleMask.remove(.resizable)
            let compactSize = currentCompactWindowSize()
            window.minSize = compactSize
            window.maxSize = compactSize
            setRootView(for: .compact)
            targetFrame = centeredFrame(from: currentFrame, targetSize: compactSize)
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: true)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // SwiftUI can report a stale fitting height immediately after switching
        // from compact -> full. Re-check on the next run loop to avoid clipping.
        if shouldRefreshFullSizeOnNextRunLoop {
            DispatchQueue.main.async { [weak self] in
                self?.refreshFullWindowSizeIfNeeded(animated: animated)
            }
        }
    }

    private func preferredFullWindowSize(fallback: NSSize) -> NSSize {
        let savedSize = fullWindowFrame?.size ?? fallback

        let minWidth: CGFloat = 350
        let maxWidth: CGFloat = 600
        let minHeight: CGFloat = 200
        let maxHeight: CGFloat = 600

        let width = min(max(savedSize.width, minWidth), maxWidth)

        hostingView?.layoutSubtreeIfNeeded()
        let fittingHeight = hostingView?.fittingSize.height ?? 0
        let desiredHeight = max(savedSize.height, fittingHeight)
        let height = min(max(desiredHeight, minHeight), maxHeight)

        return NSSize(width: width, height: height)
    }

    private func refreshFullWindowSizeIfNeeded(animated: Bool) {
        guard windowMode == .full, let window else { return }

        let targetSize = preferredFullWindowSize(fallback: window.frame.size)
        guard abs(targetSize.width - window.frame.width) > 0.5 || abs(targetSize.height - window.frame.height) > 0.5 else {
            return
        }

        let targetFrame = centeredFrame(from: window.frame, targetSize: targetSize)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: true)
        }
    }

    private func currentCompactWindowSize() -> NSSize {
        let visibleTasks = settings.showCompletedTasks ? store.activeTasks : store.activeTasks.filter { $0.isDone == false }
        let previewCount = min(3, visibleTasks.count)
        let showsOverflowIndicator = visibleTasks.count > 3
        return CompactCounterView.compactWindowSize(
            previewCount: previewCount,
            showsOverflowIndicator: showsOverflowIndicator
        )
    }

    private func refreshCompactWindowSizeIfNeeded(animated: Bool) {
        guard windowMode == .compact, let window else { return }
        let targetSize = currentCompactWindowSize()
        guard window.frame.size != targetSize else { return }

        window.minSize = targetSize
        window.maxSize = targetSize
        let targetFrame = centeredFrame(from: window.frame, targetSize: targetSize)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: true)
        }
    }

    private func setRootView(for mode: WindowMode) {
        switch mode {
        case .full:
            hostingView?.rootView = AnyView(fullRootView())
        case .compact:
            hostingView?.rootView = AnyView(compactRootView())
        }
    }

    private func centeredFrame(from currentFrame: NSRect, targetSize: NSSize) -> NSRect {
        let centerX = currentFrame.midX
        let centerY = currentFrame.midY
        return NSRect(
            x: centerX - (targetSize.width / 2),
            y: centerY - (targetSize.height / 2),
            width: targetSize.width,
            height: targetSize.height
        )
    }

    private func fullRootView() -> some View {
        RootContentView()
            .environmentObject(settings)
            .environmentObject(store)
            .environmentObject(windowModeController)
    }

    private func compactRootView() -> some View {
        RootCompactView {
            self.setWindowMode(.full, animated: true)
        }
        .environmentObject(settings)
        .environmentObject(store)
        .environmentObject(windowModeController)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func registerGlobalHotKey() {
        unregisterGlobalHotKey()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            stickyToDoGlobalHotKeyHandler,
            1,
            &eventType,
            userData,
            &hotKeyHandlerRef
        )
        guard installStatus == noErr else { return }

        let hotKeyID = EventHotKeyID(signature: quickAddHotKeySignature, id: quickAddHotKeyID)
        let modifierFlags = UInt32(cmdKey | optionKey)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_N),
            modifierFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if registerStatus != noErr {
            unregisterGlobalHotKey()
        }
    }

    fileprivate func handleGlobalQuickAddHotKey() {
        presentOrFocusQuickAddOverlay()
    }

    private func unregisterGlobalHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let hotKeyHandlerRef {
            RemoveEventHandler(hotKeyHandlerRef)
            self.hotKeyHandlerRef = nil
        }
    }

    private func presentOrFocusQuickAddOverlay() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let quickAddWindow = self.quickAddWindow {
                quickAddWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: .stickyToDoQuickAddFocusRequested, object: nil)
            } else {
                self.presentQuickAddOverlay()
            }
        }
    }

    private func presentQuickAddOverlay() {
        guard let screen = activeScreenForOverlay() else { return }

        let overlay = KeyablePanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        overlay.setFrame(screen.frame, display: false)
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = false
        overlay.hidesOnDeactivate = false
        overlay.isMovableByWindowBackground = false
        overlay.level = .statusBar
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let content = QuickAddOverlayView(
            onSubmit: { [weak self] title in
                self?.store.addTask(title: title)
            },
            onClose: { [weak self] in
                self?.closeQuickAddOverlay()
            }
        )
        .preferredColorScheme(settings.preferredColorScheme)

        let host = NSHostingView(rootView: AnyView(content))
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        overlay.contentView = host

        quickAddWindow = overlay
        overlay.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .stickyToDoQuickAddFocusRequested, object: nil)
    }

    private func closeQuickAddOverlay() {
        quickAddWindow?.orderOut(nil)
        quickAddWindow = nil
    }

    private func activeScreenForOverlay() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return mouseScreen
        }
        return window?.screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    private var appVersionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(short) (\(build))"
    }
}

extension Notification.Name {
    static let stickyToDoQuickAddFocusRequested = Notification.Name("StickyToDo.QuickAddFocusRequested")
    static let stickyToDoPresentQuickAddRequested = Notification.Name("StickyToDo.PresentQuickAddRequested")
}

private struct RootContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: TaskStore

    var body: some View {
        ContentView()
            .environmentObject(store)
            .preferredColorScheme(settings.preferredColorScheme)
    }
}

private struct RootCompactView: View {
    @EnvironmentObject private var settings: AppSettings
    let onExpand: () -> Void

    var body: some View {
        CompactCounterView(onExpand: onExpand)
            .preferredColorScheme(settings.preferredColorScheme)
    }
}

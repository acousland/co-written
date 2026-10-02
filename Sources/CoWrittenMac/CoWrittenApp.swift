import AppKit
import SwiftUI
import Combine

@main enum CoWrittenApp {
    @MainActor static func main() {
        let application = CoWrittenApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.mainMenu = delegate.makeMainMenu()
        application.setActivationPolicy(.accessory)
        // AppKit owns launch; SwiftUI only renders views explicitly opened from the menu bar.
        withExtendedLifetime(delegate) { application.run() }
    }
}

@objc(CoWrittenApplication)
@MainActor final class CoWrittenApplication: NSApplication {
    // Discard window restoration requests, including Settings saved by the former SwiftUI lifecycle.
    override func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder,
                                completionHandler: @escaping (NSWindow?, (any Error)?) -> Void) -> Bool {
        completionHandler(nil, nil)
        return true
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSToolbarDelegate {
    let model: AppModel
    override init() { model = AppModel(); super.init() }
    init(model: AppModel) { self.model = model; super.init() }
    private var statusItem: NSStatusItem?
    private var panel: NSWindow?
    private var settingsPanel: NSPanel?
    private var popover: NSPopover?
    private var reportObservation: AnyCancellable?
    private let shortcut = GlobalShortcut()
    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.arguments.contains("--ai-check") {
            Task { await AIValidation.run() }
            return
        }
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--ui-check"),
           ProcessInfo.processInfo.arguments.count > index + 1 {
            Task { await UIValidation.run(output: ProcessInfo.processInfo.arguments[index + 1], provider: self) }
            return
        }
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "Co-written")
        item.button?.toolTip = "Co-written · selected-text analysis · ⇧⌘L"
        item.button?.target = self
        item.button?.action = #selector(statusClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        popover = Self.makePopover(model: model)
        reportObservation = model.$report.sink { [weak self] report in
            self?.popover?.contentSize = CompactAnalysisView.size(for: report)
        }
        model.present = { [weak self] in
            guard let self else { return }
            if self.model.expandedMode { self.openPanel() } else { self.openPopover() }
        }
        model.expand = { [weak self] in self?.popover?.performClose(nil); self?.openPanel() }
        model.openSettings = { [weak self] in self?.settings() }
        model.closeSettings = { [weak self] in self?.settingsPanel?.close() }
        shortcut.action = { [weak self] in self?.model.captureSelection() }
        shortcut.register()
        model.shortcutAvailable = shortcut.registered
        model.start()
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        if ProcessInfo.processInfo.arguments.contains("--demo") {
            model.aiAutomatic = false
            model.analyze("We want our writing to feel clear and human. However, the implementation of the new process was delayed by the team. Perhaps we could simplify the explanation in order to help our readers understand what happens next. Thanks for taking the time to share your ideas; your feedback makes this work better.", source: "Example passage")
            openPopover()
        }
        if ProcessInfo.processInfo.arguments.contains("--startup-check") {
            Task { await StartupValidation.run(provider: self) }
        }
    }
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
    func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows flag: Bool) -> Bool { false }
    var hasMenuBarItem: Bool { statusItem?.button != nil }
    var menuBarWindow: NSWindow? { statusItem?.button?.window }
    func makeMainMenu() -> NSMenu {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Co-written")
        let preferences = appMenu.addItem(withTitle: "Settings…", action: #selector(settings), keyEquivalent: ",")
        preferences.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Co-written", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)

        // Retain standard editing shortcuts in the hosted SwiftUI text and secure fields.
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        return menu
    }
    static func makePopover(model: AppModel) -> NSPopover {
        let dropdown = NSPopover()
        dropdown.behavior = .transient
        dropdown.contentSize = CompactAnalysisView.size(for: model.report)
        dropdown.contentViewController = NSHostingController(rootView: CompactAnalysisView(model: model))
        return dropdown
    }
    @objc func statusClicked() {
        if NSApp?.currentEvent?.type == .rightMouseUp {
            popover?.performClose(nil)
            let menu = NSMenu()
            menu.addItem(withTitle: "Open Detailed View", action: #selector(openPanel), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Settings…", action: #selector(settings), keyEquivalent: ",")
            menu.addItem(withTitle: "Check for Updates…", action: #selector(checkUpdates), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit Co-written", action: #selector(quit), keyEquivalent: "q")
            for entry in menu.items { entry.target = self }
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else if popover?.isShown == true { popover?.performClose(nil) }
        else { openPopover() }
    }
    @objc func openPopover() {
        guard let button = statusItem?.button, let popover else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func openPanel() {
        popover?.performClose(nil)
        if panel == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 760),
                                 styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Co-written"
            window.minSize = NSSize(width: 730, height: 580)
            window.delegate = self
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            let toolbar = NSToolbar(identifier: "CoWrittenFullWindow")
            toolbar.delegate = self
            toolbar.displayMode = .iconOnly
            toolbar.allowsUserCustomization = false
            window.toolbar = toolbar
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.collectionBehavior = [.fullScreenPrimary]
            window.contentView = NSHostingView(rootView: AnalysisView(model: model))
            window.center()
            panel = window
        }
        NSApp.setActivationPolicy(.regular)
        if panel?.isMiniaturized == true { panel?.deminiaturize(nil) }
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        model.setExpandedMode(true)
    }
    @objc func settings() {
        model.hasAccessibility = model.reader.trusted
        popover?.performClose(nil)
        if settingsPanel == nil {
            let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 590, height: 760),
                                 styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Co-written settings"
            window.delegate = self
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.center()
            settingsPanel = window
        }
        settingsPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === panel {
            model.setExpandedMode(false)
            panel = nil
            NSApp.setActivationPolicy(.accessory)
        }
        if let window = notification.object as? NSWindow, window === settingsPanel {
            window.contentView = nil
            settingsPanel = nil
        }
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, NSToolbarItem.Identifier("paste"), NSToolbarItem.Identifier("settings")]
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarDefaultItemIdentifiers(toolbar) }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.target = self
        switch identifier.rawValue {
        case "paste":
            item.label = "Paste text"
            item.toolTip = "Paste a passage"
            item.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Paste text")
            item.action = #selector(pastePassage)
        case "settings":
            item.label = "Settings"
            item.toolTip = "Settings"
            item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
            item.action = #selector(settings)
        default: return nil
        }
        return item
    }
    @objc func pastePassage() { model.showPaste = true }
    func windowDidMiniaturize(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === panel { model.setExpandedMode(false) }
    }
    func windowDidDeminiaturize(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === panel { model.setExpandedMode(true) }
    }
    func applicationDidHide(_ notification: Notification) { model.setExpandedMode(false) }
    func applicationDidUnhide(_ notification: Notification) {
        if let panel, panel.isVisible, !panel.isMiniaturized { model.setExpandedMode(true) }
    }
    @objc func checkUpdates() { model.updater?.checkForUpdates(nil) }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { model.stop(); shortcut.unregister() }
    @objc func analyzeSelection(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            error.pointee = "No text was supplied to Co-written."
            return
        }
        model.analyze(text, source: "macOS Services")
        openPopover()
    }
}

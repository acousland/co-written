import AppKit
import SwiftUI

@main struct CoWrittenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { SettingsView(model: delegate.model).frame(width: 580) }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model: AppModel
    override init() { model = AppModel(); super.init() }
    init(model: AppModel) { self.model = model; super.init() }
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var settingsPanel: NSPanel?
    private var popover: NSPopover?
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
        model.present = { [weak self] in self?.openPopover() }
        model.expand = { [weak self] in self?.popover?.performClose(nil); self?.openPanel() }
        model.openSettings = { [weak self] in self?.settings() }
        model.closeSettings = { [weak self] in self?.settingsPanel?.close() }
        shortcut.action = { [weak self] in self?.model.captureSelection() }
        shortcut.register()
        model.shortcutAvailable = shortcut.registered
        model.start()
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "onboarded") {
            openPopover()
            defaults.set(true, forKey: "onboarded")
        }
        if ProcessInfo.processInfo.arguments.contains("--demo") {
            model.aiAutomatic = false
            model.analyze("We want our writing to feel clear and human. However, the implementation of the new process was delayed by the team. Perhaps we could simplify the explanation in order to help our readers understand what happens next. Thanks for taking the time to share your ideas; your feedback makes this work better.", source: "Example passage")
            openPopover()
        }
    }
    static func makePopover(model: AppModel) -> NSPopover {
        let dropdown = NSPopover()
        dropdown.behavior = .transient
        dropdown.contentSize = NSSize(width: 420, height: 590)
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
            let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 880, height: 750),
                                 styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
            window.title = "Co-written"
            window.minSize = NSSize(width: 730, height: 580)
            window.level = .floating
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
            window.contentView = NSHostingView(rootView: AnalysisView(model: model))
            window.center()
            panel = window
        }
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.center()
            settingsPanel = window
        }
        settingsPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === settingsPanel {
            window.contentView = nil
            settingsPanel = nil
        }
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

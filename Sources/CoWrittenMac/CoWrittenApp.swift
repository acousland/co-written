import AppKit
import SwiftUI

@main struct CoWrittenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { SettingsView(model: delegate.model).frame(width: 580) }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private let shortcut = GlobalShortcut()
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--ui-check"),
           ProcessInfo.processInfo.arguments.count > index + 1 {
            Task { await UIValidation.run(output: ProcessInfo.processInfo.arguments[index + 1], provider: self) }
            return
        }
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "Co-written")
        item.button?.toolTip = "Co-written · selected-text analysis · ⇧⌘L"
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Co-written", action: #selector(openPanel), keyEquivalent: "")
        menu.addItem(withTitle: "Analyse Selected Text", action: #selector(capture), keyEquivalent: "")
        menu.addItem(withTitle: "Pause / Resume Automatic Analysis", action: #selector(toggleAutomatic), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(settings), keyEquivalent: ",")
        menu.addItem(withTitle: "Check for Updates…", action: #selector(checkUpdates), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Co-written", action: #selector(quit), keyEquivalent: "q")
        for entry in menu.items { entry.target = self }
        item.menu = menu
        statusItem = item
        model.present = { [weak self] in self?.openPanel() }
        shortcut.action = { [weak self] in self?.model.captureSelection() }
        shortcut.register()
        model.shortcutAvailable = shortcut.registered
        model.start()
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "onboarded") {
            openPanel()
            defaults.set(true, forKey: "onboarded")
        }
        if ProcessInfo.processInfo.arguments.contains("--demo") {
            model.automatic = false
            model.analyze("We want our writing to feel clear and human. However, the implementation of the new process was delayed by the team. Perhaps we could simplify the explanation in order to help our readers understand what happens next. Thanks for taking the time to share your ideas; your feedback makes this work better.", source: "Example passage")
            openPanel()
        }
    }
    @objc func openPanel() {
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
    @objc func capture() { model.captureSelection() }
    @objc func toggleAutomatic() { model.automatic.toggle() }
    @objc func settings() { model.showSettings = true; openPanel() }
    @objc func checkUpdates() { model.updater?.checkForUpdates(nil) }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { model.stop(); shortcut.unregister() }
    @objc func analyzeSelection(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            error.pointee = "No text was supplied to Co-written."
            return
        }
        model.analyze(text, source: "macOS Services")
        openPanel()
    }
}

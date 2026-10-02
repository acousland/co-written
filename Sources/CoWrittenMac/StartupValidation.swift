import AppKit

/// Observe this app's actual launch without opening a window or reading another app's selection.
@MainActor enum StartupValidation {
    static func run(provider: AppDelegate) async {
        // Let launch, any restoration, and a simulated Finder reopen finish before inspecting our windows.
        try? await Task.sleep(for: .milliseconds(500))
        let reopenHandled = provider.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
        let visibleWindows = NSApp.windows.filter { $0.isVisible && $0 !== provider.menuBarWindow }
        var restorationDiscarded = false
        let restorationHandled = NSApp.restoreWindow(withIdentifier: NSUserInterfaceItemIdentifier("legacy-settings"),
            state: NSKeyedArchiver(requiringSecureCoding: true)) { window, error in
                restorationDiscarded = window == nil && error == nil
            }
        let valid = NSApp is CoWrittenApplication && restorationHandled && restorationDiscarded &&
            provider.hasMenuBarItem && NSApp.activationPolicy() == .accessory &&
            visibleWindows.isEmpty && !NSApp.isActive && !reopenHandled &&
            provider.model.report == nil && !provider.model.isRequestingAI && !provider.model.showSettings
        if valid {
            print("Startup check passed: menu-bar icon present; zero visible windows; no restoration, analysis or activation on reopen.")
            exit(0)
        }
        fputs("Startup check failed: menu_bar=\(provider.hasMenuBarItem) visible_windows=\(visibleWindows.count) accessory=\(NSApp.activationPolicy() == .accessory) active=\(NSApp.isActive).\n", stderr)
        exit(1)
    }
}

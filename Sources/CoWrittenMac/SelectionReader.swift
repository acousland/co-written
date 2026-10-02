import AppKit
@preconcurrency import ApplicationServices
import Carbon

enum SelectionResult {
    case text(String, String)
    case permissionRequired
    case unavailable
    case excluded
    case wordPermissionRequired
    case wordSelectionUnavailable
}

@MainActor final class SelectionReader {
    var excludedBundleIDs: Set<String> = ["com.1password.1password", "com.agilebits.onepassword7", "com.apple.keychainaccess", "com.apple.Passwords"]
    var trusted: Bool { AXIsProcessTrusted() }
    func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
    func read(allowAutomationPrompt: Bool = true) -> SelectionResult {
        guard trusted else { return .permissionRequired }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return .unavailable }
        guard !excludedBundleIDs.contains(app.bundleIdentifier ?? "") else { return .excluded }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.15)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return .unavailable }
        let focused = unsafeDowncast(value, to: AXUIElement.self)
        // Never read the value of a field or synthesise a Copy command.
        var element = focused
        for _ in 0..<4 {
            var subrole: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
            if (subrole as? String) == kAXSecureTextFieldSubrole { return .excluded }
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parent) == .success,
                  let parent, CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            element = unsafeDowncast(parent, to: AXUIElement.self)
        }
        var selection: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selection)
        if app.bundleIdentifier == WordSelectionReader.bundleID {
            var role: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(focused, kAXRoleAttribute as CFString, &role)
            let name = role as? String
            // Ribbon, search and formatting fields use their own selection, not the document's.
            if name != kAXTextFieldRole && name != kAXComboBoxRole {
                guard WordSelectionReader.isDocumentSelection(role: name, hasSelectedText: !(selection as? String ?? "").isEmpty) else { return .unavailable }
                return WordSelectionReader.read(from: app, prompt: allowAutomationPrompt)
            }
        }
        guard let text = selection as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .unavailable }
        return .text(text, app.localizedName ?? "Selected text")
    }
}

@MainActor final class GlobalShortcut {
    var action: (() -> Void)?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var registered = false
    func register() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue().action?()
            }
            return noErr
        }, 1, &event, context, &handler)
        guard status == noErr else { return }
        let identifier = EventHotKeyID(signature: 0x43575254, id: 1)
        registered = RegisterEventHotKey(UInt32(kVK_ANSI_L), UInt32(cmdKey | shiftKey), identifier, GetApplicationEventTarget(), 0, &hotKey) == noErr
    }
    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}

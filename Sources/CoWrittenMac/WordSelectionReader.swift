import AppKit
import Carbon
import CoWrittenCore

/// Word's page accessibility elements can expose only a fragment of a cross-page selection.
/// Read its selection text range directly using the properties documented in Word.sdef.
@MainActor enum WordSelectionReader {
    static let bundleID = "com.microsoft.Word"
    static func permission(for app: NSRunningApplication, prompt: Bool) -> OSStatus {
        let target = NSAppleEventDescriptor(processIdentifier: app.processIdentifier)
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, AEEventClass(kAECoreSuite), AEEventID(kAEGetData), prompt)
    }
    static func requestPermission() -> Bool {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { return false }
        return permission(for: app, prompt: true) == noErr
    }
    static func selectionSpecifier() -> NSAppleEventDescriptor {
        func property(_ code: String, of container: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
            let record = NSAppleEventDescriptor.record()
            record.setDescriptor(NSAppleEventDescriptor(typeCode: OSType("prop")), forKeyword: AEKeyword(keyAEDesiredClass))
            record.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
            record.setDescriptor(NSAppleEventDescriptor(enumCode: OSType("prop")), forKeyword: AEKeyword(keyAEKeyForm))
            record.setDescriptor(NSAppleEventDescriptor(typeCode: OSType(code)), forKeyword: AEKeyword(keyAEKeyData))
            return record.coerce(toDescriptorType: typeObjectSpecifier)!
        }
        // Word.sdef: content (1650) of text object (wTxR) of selection (sele).
        return property("1650", of: property("wTxR", of: property("sele", of: .null())))
    }
    static func selectedText(from reply: NSAppleEventDescriptor) -> String? {
        guard let text = reply.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return String(normalized.prefix(WritingAnalyzer.maximumCharacters + 1))
    }
    static func read(from app: NSRunningApplication, prompt: Bool) -> SelectionResult {
        guard app.bundleIdentifier == bundleID,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { return .unavailable }
        guard permission(for: app, prompt: prompt) == noErr else { return .wordPermissionRequired }
        let target = NSAppleEventDescriptor(processIdentifier: app.processIdentifier)
        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kAECoreSuite), eventID: AEEventID(kAEGetData),
            targetDescriptor: target, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(selectionSpecifier(), forKeyword: keyDirectObject)
        do {
            let reply = try event.sendEvent(options: [.waitForReply, .neverInteract], timeout: 1)
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { return .unavailable }
            if let error = reply.paramDescriptor(forKeyword: keyErrorNumber), error.int32Value != 0 { return .wordSelectionUnavailable }
            guard let text = selectedText(from: reply) else { return .unavailable }
            return .text(text, app.localizedName ?? "Microsoft Word")
        } catch { return .wordSelectionUnavailable }
    }
}

private extension OSType {
    init(_ fourCharacters: String) {
        self = fourCharacters.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }
}

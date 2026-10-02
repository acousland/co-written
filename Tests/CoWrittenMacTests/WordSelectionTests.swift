import AppKit
import Carbon
import CoWrittenCore
import Testing
@testable import CoWrittenMac

private func code(_ text: String) -> UInt32 { text.utf8.reduce(0) { ($0 << 8) | UInt32($1) } }
@Test @MainActor func wordQueryReadsOnlyContentOfTheSelectionTextRange() throws {
    var specifier = WordSelectionReader.selectionSpecifier()
    for expected in ["1650", "wTxR", "sele"] {
        #expect(specifier.descriptorType == typeObjectSpecifier)
        #expect(specifier.forKeyword(AEKeyword(keyAEDesiredClass))?.typeCodeValue == code("prop"))
        #expect(specifier.forKeyword(AEKeyword(keyAEKeyForm))?.enumCodeValue == code("prop"))
        #expect(specifier.forKeyword(AEKeyword(keyAEKeyData))?.typeCodeValue == code(expected))
        specifier = try #require(specifier.forKeyword(AEKeyword(keyAEContainer)))
    }
    #expect(specifier.descriptorType == typeNull)
}
@MainActor private func reply(_ text: String) -> NSAppleEventDescriptor {
    let reply = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEAnswer), targetDescriptor: nil,
        returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
    reply.setParam(NSAppleEventDescriptor(string: text), forKeyword: keyDirectObject)
    return reply
}
@Test @MainActor func wordSelectionPreservesBothPagesUnicodeAndParagraphBoundaries() {
    let first = "Selected words at the end of page one — café."
    let second = "Selected words at the start of page two 🙂."
    #expect(WordSelectionReader.selectedText(from: reply(first + "\r\n" + second + "\r")) == first + "\n" + second + "\n")
    #expect(WordSelectionReader.selectedText(from: reply(" \r\n")) == nil)
    let long = String(repeating: "paragraph\r\n", count: 3_000)
    let captured = WordSelectionReader.selectedText(from: reply(long))!
    #expect(captured.count == WritingAnalyzer.maximumCharacters + 1)
    #expect(WritingAnalyzer.analyze(captured).caveat.contains("first \(WritingAnalyzer.maximumCharacters) characters"))
}
@Test @MainActor func wordAccessFailureNeverFallsBackToAnIncompletePage() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(defaults: defaults, selectionRead: { .wordPermissionRequired }, credentialAvailable: { _, _ in false })
    model.report = WritingAnalyzer.analyze("Previous passage from another app.")
    model.captureSelection()
    #expect(model.report == nil)
    #expect(model.message.contains("Automation"))
    #expect(!model.isRequestingAI)
}

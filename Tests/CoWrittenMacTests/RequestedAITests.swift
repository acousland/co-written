import Foundation
import Testing
@testable import CoWrittenMac

private actor Probe {
    var texts: [String] = []
    func call(_ text: String, delay: Duration = .zero, fail: Bool = false) async throws -> AIReport {
        texts.append(text)
        // Deliberately ignore cancellation to verify the model also discards late responses.
        try? await Task.sleep(for: delay)
        if fail { throw AIClientError.rejected(429) }
        return AIReport(summary: text, voice: "First person.", formality: "Neutral.", strengths: ["Clear."], suggestions: [], caveat: "Context matters.", aiWriting: AIWritingAssessment(summary: "No cues.", signals: [], limitations: "Style cannot establish authorship."))
    }
    func captured() -> [String] { texts }
}
@MainActor private func configuredModel(_ defaults: UserDefaults, probe: Probe, delay: Duration = .milliseconds(30), requestDelay: Duration = .zero, fail: Bool = false, available: Bool = true) -> AppModel {
    AppModel(defaults: defaults, aiDelay: delay, credentialAvailable: { _, _ in available }, analyzeAI: { text, _, _ in try await probe.call(text, delay: requestDelay, fail: fail) })
}
@MainActor private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<100 {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(condition())
}
@Test @MainActor func defaultAIRequiresSharingAndAnExplicitAnalysisRequest() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = Probe()
    let model = configuredModel(defaults, probe: probe)
    #expect(model.aiAutomatic)
    model.analyze("We wrote a clear passage.", source: "Test")
    try await waitUntil { model.report != nil }
    try await Task.sleep(for: .milliseconds(80))
    #expect(await probe.captured().isEmpty)
    model.credentialsChanged(authorize: true)
    try await Task.sleep(for: .milliseconds(100))
    #expect(await probe.captured().isEmpty)
    model.analyze("We wrote a clear passage.", source: "Test")
    try await waitUntil { model.aiReport != nil }
    #expect(await probe.captured().count == 1)
    #expect(model.reportText.contains("AI style review"))
    model.analyze("We wrote a clear passage.", source: "Another app")
    try await Task.sleep(for: .milliseconds(100))
    #expect(await probe.captured().count == 1)
    #expect(model.source == "Another app")
}
@Test @MainActor func newExplicitRequestCancelsPendingOldPassage() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = Probe()
    let model = configuredModel(defaults, probe: probe, delay: .milliseconds(120))
    model.credentialsChanged(authorize: true)
    model.analyze("First private text.", source: "Test")
    try await waitUntil { model.report != nil }
    model.analyze("Second settled passage.", source: "Test")
    try await waitUntil { model.aiReport != nil }
    #expect(await probe.captured() == ["Second settled passage."])
}
@Test @MainActor func clearAndDisablingAIPreventLateResults() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = Probe()
    let model = configuredModel(defaults, probe: probe, requestDelay: .milliseconds(200))
    model.credentialsChanged(authorize: true)
    model.analyze("Private writing.", source: "Test")
    try await waitUntil { model.isRequestingAI }
    model.clear()
    try await Task.sleep(for: .milliseconds(80))
    #expect(model.report == nil)
    #expect(model.aiReport == nil)
    model.analyze("Another passage.", source: "Test")
    try await waitUntil { model.report != nil }
    model.aiAutomatic = false
    try await Task.sleep(for: .milliseconds(150))
    #expect(await probe.captured() == ["Private writing."])
    #expect(!model.isRequestingAI)
    #expect(model.aiReport == nil)
}
@Test @MainActor func missingKeyKeepsAnalysisLocal() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = Probe()
    let model = configuredModel(defaults, probe: probe, available: false)
    model.credentialsChanged(authorize: true)
    model.analyze("A local passage.", source: "Test")
    try await waitUntil { model.report != nil }
    try await Task.sleep(for: .milliseconds(80))
    #expect(await probe.captured().isEmpty)
    #expect(model.aiError.isEmpty)
}
@Test @MainActor func providerChangeCancelsSharingUntilDestinationIsAllowed() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = Probe()
    let model = configuredModel(defaults, probe: probe, delay: .milliseconds(150))
    model.credentialsChanged(authorize: true)
    model.analyze("Keep this local.", source: "Test")
    try await waitUntil { model.report != nil }
    model.aiProvider = .sharedService
    model.server = "https://other.example.com"
    #expect(!model.aiSharingAllowed)
    try await Task.sleep(for: .milliseconds(200))
    #expect(await probe.captured().isEmpty)
    model.credentialsChanged(authorize: true)
    try await Task.sleep(for: .milliseconds(200))
    #expect(await probe.captured().isEmpty)
    model.analyze("Keep this local.", source: "Requested after setup")
    try await waitUntil { model.aiReport != nil }
    #expect(await probe.captured().count == 1)
}
@Test @MainActor func failureRequiresExplicitRetryAndDisablingCancelsPendingRequest() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = Probe()
    let model = configuredModel(defaults, probe: probe, fail: true)
    model.credentialsChanged(authorize: true)
    model.analyze("A failed request.", source: "Test")
    try await waitUntil { !model.aiError.isEmpty }
    try await Task.sleep(for: .milliseconds(100))
    #expect(await probe.captured().count == 1)
    model.analyze("A failed request.", source: "Explicit retry")
    try await waitUntil { model.isRequestingAI || !model.aiError.isEmpty }
    try await Task.sleep(for: .milliseconds(100))
    #expect(await probe.captured().count == 2)
    model.analyze("Do not send this.", source: "Test")
    model.aiAutomatic = false
    try await waitUntil { model.report != nil }
    try await Task.sleep(for: .milliseconds(100))
    #expect(await probe.captured().count == 2)
}
@Test @MainActor func returningToEarlierPassageAllowsANewExplicitReview() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = Probe()
    let model = configuredModel(defaults, probe: probe, delay: .milliseconds(10))
    model.credentialsChanged(authorize: true)
    model.analyze("First passage.", source: "Test")
    try await waitUntil { model.aiReport != nil }
    model.analyze("Second passage.", source: "Test")
    try await waitUntil { model.aiReport != nil }
    model.analyze("First passage.", source: "Test")
    try await waitUntil { model.aiReport != nil }
    #expect(await probe.captured() == ["First passage.", "Second passage.", "First passage."])
}

@Test @MainActor func oneUnverifiedQuoteDoesNotMakeRequestedAnalysisUnreadable() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(defaults: defaults, aiDelay: .milliseconds(10), credentialAvailable: { _, _ in true }, analyzeAI: { _, _, _ in
        AIReport(summary: "A useful overview.", voice: "Active.", formality: "Neutral.", strengths: [],
            suggestions: [AISuggestion(excerpt: "Wrong quotation", advice: "Edit this.")], caveat: "Context matters.",
            aiWriting: AIWritingAssessment(summary: "No patterns.", signals: [], limitations: "Cannot establish authorship."))
    })
    model.credentialsChanged(authorize: true)
    model.analyze("We wrote this passage.", source: "Fixture")
    try await waitUntil { model.aiReport != nil || !model.aiError.isEmpty }
    #expect(model.aiError.isEmpty)
    #expect(model.aiReport?.summary == "A useful overview.")
    #expect(model.aiReport?.suggestions.isEmpty == true)
    #expect(!model.reportText.contains("Wrong quotation"))
    #expect(model.reportText.contains("omitted"))
}

@Test @MainActor func startupAndMenuBarClicksNeverReadSelectionsEvenWithOldAutomaticPreferences() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(true, forKey: "automatic")
    defaults.set(true, forKey: "showOnSelection")
    var reads = 0
    let probe = Probe()
    let model = AppModel(defaults: defaults, aiDelay: .milliseconds(10), selectionRead: {
        reads += 1
        return .text("A selected passage.", "Editor")
    }, credentialAvailable: { _, _ in true }, analyzeAI: { text, _, _ in try await probe.call(text) })
    model.credentialsChanged(authorize: true)
    model.start()
    defer { model.stop() }
    let delegate = AppDelegate(model: model)
    delegate.statusClicked()
    // Long enough for both ticks of the old background watcher.
    try await Task.sleep(for: .milliseconds(1650))
    #expect(reads == 0)
    #expect(model.report == nil)
    #expect(await probe.captured().isEmpty)
    model.captureSelection()
    try await waitUntil { model.aiReport != nil }
    #expect(reads == 1)
    #expect(await probe.captured() == ["A selected passage."])
    delegate.statusClicked()
    try await Task.sleep(for: .milliseconds(80))
    #expect(reads == 1)
    #expect(await probe.captured().count == 1)
}

@Test @MainActor func enablingAIWithSharingChecksTheCurrentPassageAutomatically() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = Probe()
    let model = configuredModel(defaults, probe: probe)
    model.credentialsChanged(authorize: true)
    model.aiAutomatic = false
    model.analyze("Previously analysed locally.", source: "Test")
    try await waitUntil { model.report != nil }
    model.aiAutomatic = true
    try await waitUntil { model.aiReport != nil }
    #expect(await probe.captured() == ["Previously analysed locally."])
}

@Test @MainActor func savingCredentialsDuringLocalAnalysisDoesNotSendThatPassage() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = Probe()
    let model = configuredModel(defaults, probe: probe)
    model.analyze("A locally requested passage.", source: "Test")
    // The local task has not yet returned. Setup must not authorise this earlier request retroactively.
    model.credentialsChanged(authorize: true)
    try await waitUntil { model.report != nil }
    try await Task.sleep(for: .milliseconds(100))
    #expect(await probe.captured().isEmpty)
    model.analyze("A locally requested passage.", source: "Requested after setup")
    try await waitUntil { model.aiReport != nil }
    #expect(await probe.captured().count == 1)
}

@Test @MainActor func mouseSelectionReadsOnlyWhileFullWindowModeIsEnabled() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var reads = 0
    let probe = Probe()
    let model = AppModel(defaults: defaults, aiDelay: .milliseconds(10), selectionRead: {
        reads += 1
        return .text("The selected text was written yesterday.", "Editor")
    }, selectionPermission: { true },
    credentialAvailable: { _, _ in true }, analyzeAI: { text, _, _ in try await probe.call(text) })
    model.credentialsChanged(authorize: true)
    model.start()
    defer { model.stop() }
    model.observeSelection()
    #expect(reads == 0)
    model.setExpandedMode(true)
    model.observeSelection(); model.observeSelection()
    try await waitUntil { model.aiReport != nil }
    #expect(reads == 2)
    #expect(await probe.captured().count == 1)
    model.setExpandedMode(false)
    let before = reads
    try await Task.sleep(for: .milliseconds(650))
    model.observeSelection()
    #expect(reads == before)
    #expect(await probe.captured().count == 1)
}

@Test @MainActor func closingFullWindowCancelsPendingMouseAIAndClearDoesNotRestoreTheSelection() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = Probe()
    let model = AppModel(defaults: defaults, aiDelay: .milliseconds(150), selectionRead: {
        .text("This passage stays local after closing.", "Editor")
    }, selectionPermission: { true }, credentialAvailable: { _, _ in true }, analyzeAI: { text, _, _ in try await probe.call(text) })
    model.credentialsChanged(authorize: true)
    model.setExpandedMode(true)
    model.observeSelection(); model.observeSelection()
    try await waitUntil { model.report != nil }
    model.setExpandedMode(false)
    try await Task.sleep(for: .milliseconds(200))
    #expect(await probe.captured().isEmpty)
    model.aiAutomatic = false
    model.setExpandedMode(true)
    model.observeSelection(); model.observeSelection()
    try await waitUntil { model.report != nil }
    model.clear()
    model.observeSelection(); model.observeSelection()
    #expect(model.report == nil)
    model.stop()
}

@Test @MainActor func enabledAIReviewsEverySettledMousePassageWithoutAnExtraInterval() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = Probe()
    let model = AppModel(defaults: defaults, aiDelay: .milliseconds(10), selectionRead: { .unavailable }, selectionPermission: { true }, credentialAvailable: { _, _ in true }, analyzeAI: { text, _, _ in try await probe.call(text) })
    model.credentialsChanged(authorize: true)
    model.setExpandedMode(true)
    defer { model.stop() }
    for passage in ["First mouse selection.", "Second mouse selection.", "Third mouse selection."] {
        model.analyze(passage, source: "Editor", fromMouseSelection: true)
        try await waitUntil { model.aiReport?.summary == passage }
    }
    #expect(await probe.captured() == ["First mouse selection.", "Second mouse selection.", "Third mouse selection."])
}

@Test @MainActor func deselectingAfterAICheckStartsStillDeliversTheRequestedReview() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = Probe()
    let model = AppModel(defaults: defaults, aiDelay: .milliseconds(10), selectionRead: { .unavailable }, selectionPermission: { true },
        credentialAvailable: { _, _ in true }, analyzeAI: { text, _, _ in try await probe.call(text, delay: .milliseconds(120)) })
    model.credentialsChanged(authorize: true)
    model.setExpandedMode(true)
    defer { model.stop() }
    model.analyze("A settled selected passage.", source: "Editor", fromMouseSelection: true)
    try await waitUntil { model.isRequestingAI }
    model.observeSelection()
    #expect(model.isRequestingAI)
    try await waitUntil { model.aiReport != nil }
    #expect(model.aiStatus == "AI checked")
    #expect(await probe.captured() == ["A settled selected passage."])
}

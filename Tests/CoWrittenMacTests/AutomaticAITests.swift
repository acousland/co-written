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
@MainActor private func configuredModel(_ defaults: UserDefaults, probe: Probe, delay: Duration = .milliseconds(30), requestDelay: Duration = .zero, fail: Bool = false, available: Bool = true, interval: Duration = .milliseconds(100)) -> AppModel {
    AppModel(defaults: defaults, aiDelay: delay, aiMinimumInterval: interval, credentialAvailable: { _, _ in available }, analyzeAI: { text, _, _ in try await probe.call(text, delay: requestDelay, fail: fail) })
}
@MainActor private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<100 {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(condition())
}
@Test @MainActor func automaticAIIsDefaultButExistingKeyNeedsSharingChoice() async throws {
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
    try await waitUntil { model.aiReport != nil }
    #expect(await probe.captured().count == 1)
    #expect(model.reportText.contains("AI style review"))
    model.analyze("We wrote a clear passage.", source: "Another app")
    try await Task.sleep(for: .milliseconds(100))
    #expect(await probe.captured().count == 1)
    #expect(model.source == "Another app")
}
@Test @MainActor func rapidSelectionChangesOnlySendSettledText() async throws {
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
@Test @MainActor func clearAndPausePreventLateAIResults() async throws {
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
    model.automatic = false
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
    #expect(!model.automaticAIAllowed)
    try await Task.sleep(for: .milliseconds(200))
    #expect(await probe.captured().isEmpty)
    model.credentialsChanged(authorize: true)
    try await waitUntil { model.aiReport != nil }
    #expect(await probe.captured().count == 1)
}
@Test @MainActor func failedAutomaticRequestsDoNotRetryAndDisablingCancelsDebounce() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = Probe()
    let model = configuredModel(defaults, probe: probe, fail: true)
    model.credentialsChanged(authorize: true)
    model.analyze("A failed request.", source: "Test")
    try await waitUntil { !model.aiError.isEmpty }
    model.analyze("A failed request.", source: "Test")
    try await Task.sleep(for: .milliseconds(100))
    #expect(await probe.captured().count == 1)
    model.analyze("Do not send this.", source: "Test")
    model.aiAutomatic = false
    try await waitUntil { model.report != nil }
    try await Task.sleep(for: .milliseconds(100))
    #expect(await probe.captured().count == 1)
}
@Test @MainActor func automaticRequestsRespectMinimumSpacing() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let probe = Probe()
    let model = configuredModel(defaults, probe: probe, delay: .milliseconds(10), interval: .milliseconds(500))
    model.credentialsChanged(authorize: true)
    model.analyze("First passage.", source: "Test")
    try await waitUntil { model.aiReport != nil }
    model.analyze("Second passage.", source: "Test")
    try await waitUntil { model.report != nil }
    try await Task.sleep(for: .milliseconds(30))
    #expect(await probe.captured().count == 1)
    try await waitUntil { model.aiReport != nil }
    #expect(await probe.captured().count == 2)
}

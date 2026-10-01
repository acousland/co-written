import Foundation
import Testing
@testable import CoWrittenMac

@Test @MainActor func clearingPreventsPendingAnalysisFromRestoringText() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(defaults: defaults)
    model.analyze(String(repeating: "This is a private passage. ", count: 1000), source: "Test")
    model.clear()
    try await Task.sleep(for: .milliseconds(200))
    #expect(model.report == nil)
    #expect(model.source.isEmpty)
    #expect(!model.isAnalyzing)
    #expect(model.aiReport == nil)
}
@Test @MainActor func newSelectionReplacesOldAnalysis() async throws {
    let suite = "CoWritten.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(defaults: defaults)
    model.analyze(String(repeating: "Old writing was analysed before. ", count: 500), source: "Old app")
    model.analyze("We wrote this new passage for our readers.", source: "New app")
    for _ in 0..<100 {
        if !model.isAnalyzing { break }
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(model.report?.text == "We wrote this new passage for our readers.")
    #expect(model.source == "New app")
}

import Foundation
import Testing
import CoWrittenCore
@testable import CoWrittenMac

@Test func succinctFeaturesUseOnlySupportedFindingsAndStayOnOnePage() throws {
    let report = WritingAnalyzer.analyze("Perhaps the explanation was written in order to help readers. We really appreciate the very clear response.")
    let rows = CompactSummary.features(report, ai: nil)
    #expect(rows.count <= 11)
    #expect(rows.contains { $0.title == "Voice" && $0.value.contains("Possible passive") })
    #expect(rows.contains { $0.title == "Hedges" })
    #expect(rows.contains { $0.title == "Wordy phrases" })
    #expect(rows.allSatisfy { !$0.icon.isEmpty && $0.title.count <= 18 && $0.value.count <= 48 })
    #expect(!rows.contains { $0.id == "ai-style" })
}
@Test func styleIconsNameEachPatternAndDeduplicateOverlappingLocalAndAIQuotes() throws {
    let passage = "Great question! This plays a crucial role. It serves as a useful guide. Let that sink in. Let that sink in."
    let report = WritingAnalyzer.analyze(passage)
    let ai = AIReport(summary: "Review.", voice: "Active.", formality: "Neutral.", strengths: [], suggestions: [], caveat: "Style is inconclusive.",
        aiWriting: AIWritingAssessment(summary: "Possible patterns.", signals: [
            AIWritingSignal(patternID: 2, excerpt: "Let that sink in.", reason: "Dramatic close.", humanAlternative: "Deliberate emphasis."),
            AIWritingSignal(patternID: 16, excerpt: "plays a crucial role", reason: "Promotion.", humanAlternative: "Deliberate marketing voice."),
            AIWritingSignal(patternID: 18, excerpt: "serves as", reason: "Elaborate verb.", humanAlternative: "Deliberate phrasing."),
            AIWritingSignal(patternID: 17, excerpt: "Invented evidence", reason: "Invalid.", humanAlternative: "Invalid."),
            AIWritingSignal(patternID: 99, excerpt: "Great question", reason: "Invalid ID.", humanAlternative: "Invalid.")
        ], limitations: "Style cannot establish authorship."))
    let features = CompactSummary.styleFeatures(report, ai: ai)
    #expect(features.map(\.id) == [2, 13, 16, 18, 22])
    let close = try #require(features.first { $0.id == 2 })
    #expect(close.count == 2)
    #expect(close.title == "Dramatic close")
    #expect(close.detail.contains("Let that sink in"))
    #expect(features.contains { $0.title == "Sales language" && $0.count == 1 })
    #expect(features.allSatisfy { !$0.icon.isEmpty && $0.title.count <= 21 && !$0.detail.isEmpty })
    #expect(CompactAnalysisView.size(for: report, ai: ai).height > CompactAnalysisView.size(for: report).height)
}
@Test func everyHumanizerPatternHasASpecificCompactIconAndName() {
    for pattern in HumanizerCatalogue.patterns {
        let display = CompactSummary.styleDisplay(pattern.id)
        #expect(display.title != "Style pattern")
        #expect(display.title.count <= 21)
        #expect(!display.icon.isEmpty)
    }
}
@Test func quickLabelsSurviveValidationAndBadLabelsFallBackWithoutRejectingTheReview() throws {
    let passage = "We wrote this paragraph for our readers."
    let quick = AIQuickLook(voice: "Active, first person", formality: "Conversational", tone: "Warm")
    let report = AIReport(summary: "A useful review.", voice: "Active grammatical voice.", formality: "Conversational register.", strengths: [], suggestions: [], caveat: "Short sample.", aiWriting: nil, quickLook: quick)
    let usable = try report.validated(passage: passage)
    #expect(CompactSummary.features(WritingAnalyzer.analyze(passage), ai: usable).first?.value == quick.voice)
    var bad = report
    bad.quickLook = AIQuickLook(voice: String(repeating: "word ", count: 30), formality: "Neutral", tone: "Warm")
    #expect(try bad.validated(passage: passage).quickLook == nil)
    #expect(try bad.validated(passage: passage).summary == report.summary)
}

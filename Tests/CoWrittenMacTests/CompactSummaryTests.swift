import Foundation
import Testing
import CoWrittenCore
@testable import CoWrittenMac

@Test func succinctFeaturesUseOnlySupportedFindingsAndStayOnOnePage() throws {
    let report = WritingAnalyzer.analyze("Perhaps the explanation was written in order to help readers. We really appreciate the very clear response.")
    let rows = CompactSummary.features(report, ai: nil)
    #expect(rows.count <= 12)
    #expect(rows.contains { $0.title == "Voice" && $0.value.contains("Possible passive") })
    #expect(rows.contains { $0.title == "Hedges" })
    #expect(rows.contains { $0.title == "Wordy phrases" })
    #expect(rows.allSatisfy { !$0.icon.isEmpty && $0.title.count <= 18 && $0.value.count <= 48 })
    #expect(rows.first { $0.id == "ai-style" }?.detail.contains("cannot establish authorship") == true)
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

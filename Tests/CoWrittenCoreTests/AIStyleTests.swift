import Foundation
import Testing
@testable import CoWrittenCore

@Test func humanizerCatalogueContainsAllPinnedPatterns() {
    #expect(HumanizerCatalogue.patterns.map(\.id) == Array(1...26))
    #expect(HumanizerCatalogue.patterns.filter(\.weakAlone).map(\.id) == [8, 9, 10, 11, 21, 25])
}
@Test func humanizerCuesPreserveExactUnicodeEvidence() {
    let text = "📝 Great question! At its core, the change plays a crucial role. Let that sink in."
    let review = WritingAnalyzer.analyze(text).aiStyle
    #expect(review.signals.count >= 4)
    #expect(review.signals.contains { $0.kind.hasPrefix("Humanizer 22:") })
    for finding in review.signals {
        #expect((text as NSString).substring(with: NSRange(location: finding.start, length: finding.length)) == finding.excerpt)
    }
    #expect(review.limitations.contains("not a validated AI detector"))
    #expect(review.limitations.contains("short sample"))
}
@Test func punctuationAndSingleStockWordsDoNotImplyAI() {
    for text in ["The landscape was green — I took a photo.", "She wrote “hello” and left.", "The door was closed by the guard.", "This pivotal change helped us."] {
        #expect(WritingAnalyzer.analyze(text).aiStyle.signals.isEmpty)
    }
    let review = WritingAnalyzer.analyze("We delve into a tapestry of pivotal changes with our team.").aiStyle
    #expect(review.signals.count == 3)
}
@Test func quotedPatternsAreLeftAlone() {
    let review = WritingAnalyzer.analyze("The editor wrote: “Great question! At its core, this plays a crucial role.” We discussed the quotation.").aiStyle
    #expect(review.signals.isEmpty)
}
@Test func shortNonEnglishPassageDoesNotReceiveEnglishTells() {
    let report = WritingAnalyzer.analyze("Bonjour, je suis content.")
    #expect(!report.supportsStyleAnalysis)
    #expect(report.aiStyle.signals.isEmpty)
    #expect(report.aiStyle.summary.contains("unavailable"))
}

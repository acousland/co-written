import Testing
import Foundation
@testable import CoWrittenCore

@Test func emptyTextHasFiniteStatistics() {
    let r = WritingAnalyzer.analyze("")
    #expect(r.wordCount == 0)
    #expect(r.averageSentenceLength == 0)
    #expect(r.readability == nil)
    #expect(r.formality == nil)
    #expect(r.findings.isEmpty)
}
@Test func evidenceOffsetsSurviveUnicode() {
    let text = "🙂 The report was written by our team. We might really need to revise it in order to make the explanation clear."
    let r = WritingAnalyzer.analyze(text)
    #expect(r.findings.contains { $0.kind == "Possible passive voice" && $0.excerpt == "was written" })
    #expect(r.findings.contains { $0.kind == "Wordy phrase" && $0.excerpt == "in order to" })
    for finding in r.findings { #expect((text as NSString).substring(with: NSRange(location: finding.start, length: finding.length)) == finding.excerpt) }
}
@Test func contrastFormalAndConversationalRegisters() {
    let formal = WritingAnalyzer.analyze("Furthermore, the implementation of the recommendation requires consideration of the consequences. Therefore, the organisation will undertake a comprehensive assessment of the proposed arrangement.")
    let casual = WritingAnalyzer.analyze("Hey, we're gonna give this a go. It's cool and we don't need to worry. You'll love it, yeah? We can't wait to see you!")
    #expect((formal.formality ?? 0) > (casual.formality ?? 100))
    #expect(casual.pointOfView == "Mixed perspective")
}
@Test func nonEnglishGetsStatisticsWithoutEnglishJudgments() {
    let r = WritingAnalyzer.analyze("El informe fue escrito por nuestro equipo. La organización necesita revisar las recomendaciones antes de tomar una decisión sobre el proyecto y sus resultados.")
    #expect(r.wordCount > 20)
    #expect(!r.supportsStyleAnalysis)
    #expect(r.formality == nil)
    #expect(r.readability == nil)
    #expect(r.findings.isEmpty)
}
@Test func boundedInputAndRepeatedWords() {
    let r = WritingAnalyzer.analyze(String(repeating: "Clarity matters. Clarity helps. Clarity works. ", count: 1000))
    #expect(r.text.count == WritingAnalyzer.maximumCharacters)
    #expect(r.caveat.contains("first 20000"))
    #expect(r.repeatedWords.contains { $0.hasPrefix("clarity ×") })
    #expect(r.readability?.isFinite == true)
}
@Test func activeTextDoesNotClaimGrammaticalProof() {
    let r = WritingAnalyzer.analyze("We wrote the report. Our team reviewed it yesterday and sent it to the client this morning.")
    #expect(r.grammaticalVoice == "No passive cues found")
    #expect(r.pointOfView == "Mixed perspective")
    #expect(r.caveat.contains("false positives"))
}

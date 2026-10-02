import Foundation
import NaturalLanguage

public struct Finding: Identifiable, Sendable, Codable, Equatable {
    public var id: String { kind + ":" + String(start) + ":" + excerpt }
    public let kind: String
    public let excerpt: String
    public let explanation: String
    /// UTF-16 offsets, suitable for NSTextView / NSRange.
    public let start: Int
    public let length: Int
}

public struct SentenceMeasure: Identifiable, Sendable, Codable {
    public let id: Int
    public let text: String
    public let words: Int
}

public struct WritingReport: Sendable, Codable {
    public let text: String
    public let language: String
    public let supportsStyleAnalysis: Bool
    public let wordCount: Int
    public let sentenceCount: Int
    public let paragraphCount: Int
    public let readingSeconds: Int
    public let averageSentenceLength: Double
    public let readability: Double?
    public let formality: Int?
    public let formalityEvidence: String
    public let pointOfView: String
    public let grammaticalVoice: String
    public let tone: String
    public let vocabularyVariety: Int
    public let repeatedWords: [String]
    public let sentences: [SentenceMeasure]
    public let findings: [Finding]
    public let aiStyle: AIStyleReview
    public let caveat: String

    public var formalityLabel: String {
        guard let formality else { return "Unavailable" }
        switch formality { case ..<35: return "Conversational"; case 35..<65: return "Neutral"; default: return "Formal" }
    }
    public var readabilityLabel: String {
        guard let readability else { return "Unavailable" }
        switch readability { case 80...: return "Easy to follow"; case 60..<80: return "Plain language"; case 40..<60: return "More demanding"; default: return "Dense" }
    }
    public var summary: String {
        guard wordCount > 0 else { return "Select a passage to explore your writing." }
        guard supportsStyleAnalysis else { return "Text statistics are available. Style estimates currently support English." }
        return "\(formalityLabel) writing · \(pointOfView.lowercased()) · \(readabilityLabel.lowercased())."
    }
    public var exportText: String {
        let metrics = "\(wordCount) words · \(sentenceCount) sentences · \(paragraphCount) paragraphs\nVoice: \(grammaticalVoice)\nPoint of view: \(pointOfView)\nTone cues: \(tone)\nFormality: \(formality.map { String($0) + "/100" } ?? "unavailable")\nReadability: \(readability.map { String(format: "%.0f/100", $0) } ?? "unavailable")\n\(formalityEvidence)\n\n\(caveat)"
        return "Co-written analysis\n\n\(metrics)\n\n" + findings.map { "\($0.kind): “\($0.excerpt)”\n\($0.explanation)" }.joined(separator: "\n\n") + "\n\nAI-style cues\n\(aiStyle.summary)\n\(aiStyle.limitations)\n" + aiStyle.signals.map { "\($0.kind): “\($0.excerpt)”\n\($0.explanation)" }.joined(separator: "\n\n")
    }
}

/// Local, explainable estimates. These rules describe cues; they do not judge quality or infer personality.
public enum WritingAnalyzer {
    public static let maximumCharacters = 20_000
    public static func analyze(_ input: String) -> WritingReport {
        let text = String(input.prefix(maximumCharacters))
        let tokens = words(text)
        let lower = tokens.map { $0.lowercased().replacingOccurrences(of: "’", with: "'") }
        let sentences = sentenceRanges(text).enumerated().map {
            SentenceMeasure(id: $0.offset, text: String(text[$0.element]).trimmingCharacters(in: .whitespacesAndNewlines), words: words(String(text[$0.element])).count)
        }.filter { $0.words > 0 }
        let n = tokens.count
        let average = Double(n) / Double(max(1, sentences.count))
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let language = recognizer.dominantLanguage
        // Short Latin fragments are often ambiguous: allow the English rules but warn about the sample.
        let english = language == .english || (language == nil && n < 8 && text.unicodeScalars.allSatisfy { !$0.properties.isAlphabetic || $0.value < 128 })
        let languageName = language.map { Locale.current.localizedString(forLanguageCode: $0.rawValue) ?? $0.rawValue } ?? "Undetermined"
        let syllables = lower.reduce(0) { $0 + syllableCount($1) }
        let readability = english && n >= 10 ? max(0, min(100, 206.835 - 1.015 * average - 84.6 * Double(syllables) / Double(max(1, n)))) : nil
        let contractions = matches(#"\b\p{L}+[’'](?:t|re|ve|ll|d|m|s)\b"#, text)
        let casual = lower.filter { ["hey", "yeah", "okay", "ok", "gonna", "wanna", "cool", "awesome", "stuff", "kids", "lol"].contains($0) }.count
        let formal = lower.filter { ["therefore", "however", "furthermore", "moreover", "consequently", "nevertheless", "pursuant", "whereas", "accordingly", "hence"].contains($0) }.count
        let longWords = lower.filter { $0.count >= 8 }.count
        let nominalizations = lower.filter { $0.hasSuffix("tion") || $0.hasSuffix("sion") || $0.hasSuffix("ment") }.count
        let score = n >= 10 && english ? Int(max(0, min(100, 45 + Double(longWords) / Double(n) * 65 + min(12, (average - 14) * 0.6) + Double(formal) / Double(n) * 180 + Double(nominalizations) / Double(n) * 45 - Double(contractions.count + casual) / Double(n) * 200))) : nil
        let evidence = english ? "Based on \(contractions.count) contractions, \(formal) formal connectors, \(nominalizations) noun endings, and \(Int((Double(longWords) / Double(max(1, n)) * 100).rounded()))% longer words. This is a heuristic, not a validated rating." : "English style rules are disabled for this passage."
        let first = lower.filter { ["i", "me", "my", "mine", "we", "us", "our", "ours", "i'm", "i've", "we're", "we've"].contains($0) }.count
        let second = lower.filter { ["you", "your", "yours", "you're", "you've", "you'll"].contains($0) }.count
        let third = lower.filter { ["he", "she", "they", "him", "her", "them", "his", "their", "its", "it", "it's", "they're"].contains($0) }.count
        let perspectives = [("First person", first), ("Second person", second), ("Third person", third)].filter { $0.1 > 0 }
        let pov = !english ? "Unavailable" : (perspectives.count > 1 ? "Mixed perspective" : perspectives.first?.0 ?? "No personal pronouns")
        var findings: [Finding] = []
        func add(_ kind: String, _ pattern: String, _ explanation: String) {
            for match in matches(pattern, text) {
                let range = NSRange(match, in: text)
                findings.append(Finding(kind: kind, excerpt: String(text[match]), explanation: explanation, start: range.location, length: range.length))
            }
        }
        if english {
            add("Possible passive voice", #"\b(?:am|is|are|was|were|be|been|being)\s+(?:(?:not|also|often|usually|already|recently|currently|\p{L}+ly)\s+){0,2}(?:\p{L}+(?:ed|en)|made|done|given|known|shown|seen|sent|built|told|found|held|read|written|bought|brought|taught|caught|put|set|sold|paid|left|lost|won|taken)\b"#, "A form of ‘be’ followed by a possible participle can signal passive voice. Name the actor if that helps the reader. Adjectives and other constructions can look the same; passive voice is often useful.")
            add("Hedging", #"\b(?:perhaps|possibly|probably|somewhat|arguably|apparently|seem(?:s|ed)?|might|may|could|I think|I believe|sort of|kind of|to some extent)\b"#, "This qualifies a claim. Keep it when uncertainty matters; remove it only if the evidence supports a firmer statement.")
            add("Intensifier", #"\b(?:very|really|extremely|absolutely|totally|incredibly|quite|rather)\b"#, "Consider whether a precise word would carry the meaning better. Intensifiers can also be part of your intended voice.")
            add("Wordy phrase", #"\b(?:in order to|due to the fact that|at this point in time|in the event that|for the purpose of|a large number of|it is important to note that|in my opinion|on a daily basis|has the ability to)\b"#, "Try a shorter alternative: ‘to’, ‘because’, ‘now’, ‘if’, ‘for’, ‘many’, or ‘daily’, as the meaning allows.")
            add("Abstract noun", #"\b\p{L}{3,}(?:tion|sion|ment)\b"#, "This noun ending can signal an abstract process. A verb and a named actor may make the sentence clearer; many such nouns are necessary and precise.")
            add("Repeated word", #"\b(\p{L}+)\s+\1\b"#, "Check this immediate repetition. It may be intentional for emphasis.")
            for sentence in sentences where sentence.words > 30 {
                if let range = text.range(of: sentence.text) {
                    let ns = NSRange(range, in: text)
                    findings.append(Finding(kind: "Long sentence", excerpt: sentence.text, explanation: "\(sentence.words) words. Consider splitting at a change of idea. A long sentence can still be clear when its structure is easy to follow.", start: ns.location, length: ns.length))
                }
            }
        }
        let passive = findings.filter { $0.kind == "Possible passive voice" }.count
        let passiveSentences = sentences.filter { sentence in findings.contains { $0.kind == "Possible passive voice" && sentence.text.localizedCaseInsensitiveContains($0.excerpt) } }.count
        let voice = !english ? "Unavailable" : (passive == 0 ? "No passive cues found" : "Possible passive in \(passiveSentences) of \(sentences.count) sentences")
        let hedge = findings.filter { $0.kind == "Hedging" }.count
        let positive = lower.filter { ["thanks", "thank", "please", "welcome", "glad", "happy", "appreciate", "delighted"].contains($0) }.count
        let directive = lower.filter { ["must", "need", "ensure", "required", "should"].contains($0) }.count
        var toneCues: [String] = []
        if positive > 0 { toneCues.append("Warm / courteous") }
        if hedge > 0 { toneCues.append("Qualified / tentative") }
        if directive > 0 { toneCues.append("Directive") }
        if text.contains("?") { toneCues.append("Questioning") }
        if text.contains("!") { toneCues.append("Emphatic") }
        let tone = !english ? "Unavailable" : (toneCues.isEmpty ? "No strong tone cues" : toneCues.joined(separator: ", "))
        let stopwords: Set<String> = ["the", "a", "an", "and", "or", "but", "to", "of", "in", "on", "at", "for", "with", "by", "is", "are", "was", "were", "be", "been", "it", "its", "this", "that", "these", "those", "as", "from", "not", "i", "we", "you", "he", "she", "they", "our", "your", "their", "my", "have", "has", "had", "will", "would", "can", "could", "should", "do", "does"]
        let frequencies = Dictionary(lower.filter { $0.count > 2 && !stopwords.contains($0) }.map { ($0, 1) }, uniquingKeysWith: +)
        let repeated = frequencies.filter { $0.value >= 3 }.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.prefix(8).map { "\($0.key) ×\($0.value)" }
        let paragraphs = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        var caveats = ["Local estimates describe patterns, not writing quality. Genre, audience, dialect, quotations, and context can change their meaning. Passive-voice detection can produce false positives and miss constructions."]
        if n < 50 { caveats.append("This sample is short; style and readability estimates are less reliable.") }
        if input.count > maximumCharacters { caveats.append("Only the first \(maximumCharacters) characters were analysed.") }
        if !english { caveats.append("English style and syllable rules are disabled for this language.") }
        return WritingReport(text: text, language: languageName, supportsStyleAnalysis: english, wordCount: n, sentenceCount: sentences.count, paragraphCount: paragraphs, readingSeconds: Int(ceil(Double(n) / 238 * 60)), averageSentenceLength: average, readability: readability, formality: score, formalityEvidence: evidence, pointOfView: pov, grammaticalVoice: voice, tone: tone, vocabularyVariety: Int(Double(Set(lower).count) / Double(max(1, n)) * 100), repeatedWords: repeated, sentences: sentences, findings: findings.sorted { $0.start < $1.start }, aiStyle: aiStyle(text, english: english, words: n), caveat: caveats.joined(separator: " "))
    }

    static func words(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var result: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
            if word.unicodeScalars.contains(where: { $0.properties.isAlphabetic || $0.properties.numericType != nil }) { result.append(word) }
            return true
        }
        return result
    }
    static func sentenceRanges(_ text: String) -> [Range<String.Index>] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex)
    }
    static func matches(_ pattern: String, _ text: String) -> [Range<String.Index>] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)).compactMap { Range($0.range, in: text) }
    }
    static func syllableCount(_ word: String) -> Int {
        let letters = word.lowercased().filter { $0.isASCII && $0.isLetter }
        guard !letters.isEmpty else { return 1 }
        var count = matches("[aeiouy]+", letters).count
        if letters.hasSuffix("e"), !letters.hasSuffix("le"), count > 1 { count -= 1 }
        if letters.hasSuffix("es"), !letters.hasSuffix("ses"), !letters.hasSuffix("xes"), count > 1 { count -= 1 }
        return max(1, count)
    }
}

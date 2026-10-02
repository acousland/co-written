import Foundation

/// Editorial cues, not a classifier: human and AI writing share all these patterns.
public struct AIStyleReview: Sendable, Codable {
    public let signals: [Finding]
    public let summary: String
    public let limitations: String
}

extension WritingAnalyzer {
    static func aiStyle(_ text: String, english: Bool, words: Int) -> AIStyleReview {
        var signals: [Finding] = []
        let quoted = (try? NSRegularExpression(pattern: #"[“"](?:[^“”"]|\n)*[”"]"#))?.matches(in: text, range: NSRange(text.startIndex..., in: text)).map(\.range) ?? []
        func add(_ id: Int, _ pattern: String, _ explanation: String) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return }
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).prefix(12) {
                guard !quoted.contains(where: { NSIntersectionRange($0, match.range).length > 0 }), let range = Range(match.range, in: text) else { continue }
                signals.append(Finding(kind: "Humanizer \(id): " + HumanizerCatalogue.name(id), excerpt: String(text[range]), explanation: explanation,
                                       start: match.range.location, length: match.range.length))
            }
        }
        if english {
            add(13, #"\b(?:in today['’]s (?:rapidly (?:evolving|changing) )?(?:world|landscape)|ever[- ]changing landscape|in the (?:modern|digital) age)\b"#,
                "Broad framing can make generated prose feel interchangeable. Human introductions and marketing copy also use it. Try opening with your particular situation or a concrete fact.")
            add(13, #"\b(?:it is worth noting(?: that)?|it is important to note(?: that)?)\b"#,
                "Stock transitions can make prose feel templated. They are also ordinary academic and business conventions. Check whether the relationship between these specific ideas needs this signpost.")
            add(13, #"\b(?:plays? a (?:crucial|vital|pivotal) role|a testament to|unlock(?:ing)? (?:the )?(?:full )?potential|seamless integration)\b"#,
                "An impressive-sounding phrase without specifics can resemble generic AI prose. Human promotional writing uses it too. Name the action, result, or evidence if it is available.")
            add(1, #"\bnot (?:just|only|merely)\b[^.!?\n]{1,100}\bbut\b[^.!?\n]{1,100}"#,
                "Repeated balanced formulas can sound manufactured. This is also a long-established human rhetorical device. Keep it if the contrast adds meaning; otherwise try a direct sentence.")
            add(2, #"\b(?:let that sink in|read that again|that is the real win|that distinction matters)\b"#,
                "A dramatic closer can restate an earlier point instead of adding information. Human writers also use these for emphasis. Keep it if it adds a fact or consequence.")
            add(3, #"\b(?:at its core|the heart of the matter|the deeper issue|what really matters)\b"#,
                "This framing can lend weight without explaining the specific claim. It is also common human rhetoric. Check what detail follows it.")
            add(4, #"(?:^|[.!?]\s+)(?:let['’]s (?:dive in|explore|break this down)|here['’]s (?:the thing|what you need to know)|without further ado|honestly\?)"#,
                "An announced explanation can delay the actual point. Humans use conversational openers too. Try stating the point directly if the opener adds nothing.")
            add(5, #"\b(?:I['’]m not saying|this is not to say|don['’]t get me wrong|a tempting approach would be|one might be tempted to)\b"#,
                "The passage may be answering an objection the reader has not raised. A real objection or a personal qualification can justify the same wording; check the surrounding context.")
            add(17, #"\b(?:experts (?:believe|argue|say)|observers have (?:cited|noted)|industry reports suggest)\b"#,
                "Unnamed authority can substitute for a specific source or finding. Humans also summarise sources this way. Check whether naming the source would help; missing citations alone are not an AI sign.")
            add(22, #"\b(?:great question|I hope this helps|you['’]re absolutely right|would you like me to|let me know if you['’]d like)\b"#,
                "A chat wrapper may remain in prose meant to stand alone. Greetings and offers are also normal in human correspondence; the genre matters.")
            add(23, #"\b(?:as an AI (?:language )?model|(?:my|the) (?:last )?training (?:update|data|cutoff)|my knowledge cutoff)\b"#,
                "This explicitly refers to a model's limits. A person could quote, discuss, or imitate the same wording; inspect its context rather than inferring authorship.")
            let strongCount = signals.count
            let beforeWords = signals.count
            add(12, #"\b(?:delve|tapestry|testament|pivotal|showcasing|underscoring|interplay|meticulously)\b"#,
                "A cluster of stock abstract vocabulary can feel generic. Literal, technical and deliberate human uses are common; consider a plain, specific word only where it preserves meaning.")
            let wordSignals = Array(signals.dropFirst(beforeWords))
            if strongCount == 0 && Set(wordSignals.map { $0.excerpt.lowercased() }).count < 3 { signals.removeSubrange(beforeWords...) }
            // Humanizer marks these weak alone: require another pattern in the passage.
            if !signals.isEmpty {
                add(9, #"\b(?:could potentially possibly|might arguably perhaps|could potentially be argued)\b"#,
                    "Stacked qualifiers can blur the claim. Human editing and necessary uncertainty can produce them too. Keep the qualification the evidence needs.")
                let dashes = text.filter { $0 == "—" || $0 == "–" }.count
                if dashes >= 4 && words >= 80 {
                    add(8, #"[^.!?\n]{1,80}[—–][^.!?\n]{1,80}"#,
                        "Several dash constructions occur alongside other style cues. Journalists, editors and human writers also favour dashes; punctuation is not authorship evidence. Check whether each connection is clear.")
                }
            }
        }
        let summary = !english ? "Local English Humanizer cues are unavailable. AI can review the passage in context." :
            signals.isEmpty ? "No local Humanizer patterns matched. This does not establish human authorship." :
            "\(signals.count) style cue\(signals.count == 1 ? "" : "s") to inspect; these can occur in human or AI writing."
        let limitations = "Style cues cannot establish who or what wrote a passage. These adaptations of Humanizer are editorial rules, not a validated AI detector. Human writing, editing, translation, genre, and AI assistance overlap." +
            (words < 100 ? " This short sample gives particularly little evidence." : "")
        return AIStyleReview(signals: signals, summary: summary, limitations: limitations)
    }
}

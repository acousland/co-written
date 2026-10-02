import Foundation
import CoWrittenCore

struct CompactFeature: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: String
    let detail: String
}
struct CompactStyleFeature: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let count: Int
    let detail: String
}
enum CompactSummary {
    static func features(_ report: WritingReport, ai: AIReport?) -> [CompactFeature] {
        let quick = ai?.quickLook?.verified
        let passive = report.findings.filter { $0.kind == "Possible passive voice" }.count
        let voice = !report.supportsStyleAnalysis ? "English only" : passive == 0 ? "No passive cues" : "Possible passive · \(passive)"
        let tone = report.tone.replacingOccurrences(of: "Warm / courteous", with: "Warm").replacingOccurrences(of: "Qualified / tentative", with: "Tentative").replacingOccurrences(of: "No strong tone cues", with: "No strong cues")
        var rows = [
            CompactFeature(id: "voice", icon: "waveform", title: "Voice", value: quick?.voice ?? voice, detail: ai?.voice ?? report.grammaticalVoice),
            CompactFeature(id: "formality", icon: "textformat", title: "Formality", value: quick?.formality ?? (report.formality == nil ? (report.supportsStyleAnalysis ? "Short sample" : "English only") : report.formalityLabel), detail: ai?.formality ?? report.formalityEvidence),
            CompactFeature(id: "tone", icon: "bubble", title: "Tone", value: quick?.tone ?? tone.components(separatedBy: ", ").prefix(2).joined(separator: " · "), detail: report.tone),
            CompactFeature(id: "perspective", icon: "person.crop.square", title: "Perspective", value: report.pointOfView.replacingOccurrences(of: "Mixed perspective", with: "Mixed").replacingOccurrences(of: "No personal pronouns", with: "No pronouns"), detail: report.pointOfView),
            CompactFeature(id: "ease", icon: "book", title: "Reading ease", value: report.readability.map { String(format: "%.0f/100", $0) } ?? (report.supportsStyleAnalysis ? "Short sample" : "English only"), detail: report.readabilityLabel)
        ]
        let cues = Dictionary(grouping: report.findings.filter { $0.kind != "Possible passive voice" }, by: \.kind)
        let labels = ["Hedging": ("cloud", "Hedges"), "Intensifier": ("exclamationmark.bubble", "Intensifiers"), "Wordy phrase": ("text.badge.minus", "Wordy phrases"), "Abstract noun": ("square.stack", "Abstract nouns"), "Repeated word": ("repeat", "Repetition"), "Long sentence": ("text.alignleft", "Long sentences")]
        let ranked = cues.sorted { $0.value.count == $1.value.count ? $0.key < $1.key : $0.value.count > $1.value.count }
        for (kind, findings) in ranked {
            guard let (icon, title) = labels[kind] else { continue }
            rows.append(CompactFeature(id: kind, icon: icon, title: title, value: "\(findings.count) cue\(findings.count == 1 ? "" : "s")", detail: findings.map(\.excerpt).joined(separator: " · ")))
        }
        return rows
    }
    /// Group supported local and AI observations by pattern, retaining their exact evidence.
    static func styleFeatures(_ report: WritingReport, ai: AIReport?) -> [CompactStyleFeature] {
        struct Evidence { let range: NSRange; let excerpt: String; let explanation: String }
        var evidence: [Int: [Evidence]] = [:]
        func add(_ id: Int, range: NSRange, excerpt: String, explanation: String) {
            guard (1...26).contains(id), !excerpt.isEmpty else { return }
            var entries = evidence[id, default: []]
            if !entries.contains(where: { NSIntersectionRange($0.range, range).length > 0 }) {
                entries.append(Evidence(range: range, excerpt: excerpt, explanation: explanation))
            }
            evidence[id] = entries
        }
        for finding in report.aiStyle.signals {
            guard let id = finding.kind.split(separator: ":").first?.split(separator: " ").last.flatMap({ Int($0) }) else { continue }
            add(id, range: NSRange(location: finding.start, length: finding.length), excerpt: finding.excerpt, explanation: finding.explanation)
        }
        for signal in ai?.aiWriting?.signals ?? [] {
            guard let range = report.text.range(of: signal.excerpt), !signal.excerpt.isEmpty else { continue }
            add(signal.patternID, range: NSRange(range, in: report.text), excerpt: signal.excerpt,
                explanation: signal.reason + "\nHuman explanation: " + signal.humanAlternative)
        }
        return evidence.keys.sorted().map { id in
            let display = styleDisplay(id)
            let entries = evidence[id]!
            return CompactStyleFeature(id: id, icon: display.icon, title: display.title, count: entries.count,
                detail: HumanizerCatalogue.name(id) + "\n\n" + entries.prefix(3).map { "“\($0.excerpt)”\n\($0.explanation)" }.joined(separator: "\n\n") +
                    (entries.count > 3 ? "\n\nOpen the full app for all \(entries.count) occurrences." : ""))
        }
    }
    static func styleDisplay(_ id: Int) -> (icon: String, title: String) {
        switch id {
        case 1: ("arrow.left.arrow.right", "Formulaic contrast")
        case 2: ("text.append", "Dramatic close")
        case 3: ("lightbulb", "Vague profundity")
        case 4: ("hourglass", "Staged opening")
        case 5: ("bubble.left.and.bubble.right", "Phantom objections")
        case 6: ("list.number", "Forced triads")
        case 7: ("repeat", "Repeated rhythm")
        case 8: ("minus", "Dash overuse")
        case 9: ("cloud", "Stacked hedges")
        case 10: ("link", "Hyphen overuse")
        case 11: ("person.crop.circle.badge.questionmark", "Missing actors")
        case 12: ("textformat.abc", "Stock wording")
        case 13: ("arrow.up.right", "Inflated claims")
        case 14: ("point.3.connected.trianglepath.dotted", "Vague connections")
        case 15: ("text.badge.plus", "Shallow add-ons")
        case 16: ("megaphone", "Sales language")
        case 17: ("person.2", "Unnamed authority")
        case 18: ("text.badge.checkmark", "Showy verbs")
        case 19: ("bold", "Decorative bold")
        case 20: ("textformat.size", "Decorative headings")
        case 21: ("quote.opening", "Curly quotes")
        case 22: ("bubble.left", "Chat residue")
        case 23: ("exclamationmark.bubble", "Model disclaimers")
        case 24: ("doc.on.doc", "Heading echo")
        case 25: ("doc.text", "Document chatter")
        case 26: ("arrow.uturn.backward", "Over-explaining")
        default: ("sparkles", "Style pattern")
        }
    }
}

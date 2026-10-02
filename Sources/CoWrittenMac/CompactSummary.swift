import Foundation
import CoWrittenCore

struct CompactFeature: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: String
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
        let local = report.aiStyle.signals.map { finding in
            let id = finding.kind.split(separator: ":").first?.split(separator: " ").last.map(String.init) ?? finding.kind
            return id + ":" + finding.excerpt.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let contextual = (ai?.aiWriting?.signals ?? []).map { String($0.patternID) + ":" + $0.excerpt.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        let count = Set(local + contextual).count
        rows.append(CompactFeature(id: "ai-style", icon: "sparkles", title: "AI-like style", value: count == 0 ? "No cues found" : "\(count) cue\(count == 1 ? "" : "s")", detail: "Style cues cannot establish authorship. Open the full app for quoted evidence and possible human explanations."))
        return rows
    }
}

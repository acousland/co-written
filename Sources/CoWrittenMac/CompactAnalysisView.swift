import AppKit
import CoWrittenCore
import SwiftUI

struct CompactAnalysisView: View {
    @ObservedObject var model: AppModel
    @State private var tab = 0
    @State private var pasting = false
    @State private var draft = ""
    init(model: AppModel, tab: Int = 0) { self.model = model; _tab = State(initialValue: tab) }
    private let accent = Color(red: 0.27, green: 0.40, blue: 0.31)
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "text.quote").foregroundStyle(accent)
                Text("Co-written").font(.system(size: 20, weight: .semibold, design: .serif))
                Spacer()
                if model.isRequestingAI { ProgressView().controlSize(.small).help("Sharing this passage with your AI provider") }
                else { Image(systemName: model.aiReport == nil ? "lock.shield" : "sparkles").font(.caption).foregroundStyle(.secondary).help(model.aiReport == nil ? "Local results" : "AI perspective ready") }
                Button { model.expand?() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.help("Open detailed view")
                Button { model.showPreferences() } label: { Image(systemName: "gearshape") }.help("Settings")
            }.buttonStyle(.plain).padding(17)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    if pasting {
                        Text("Paste a passage").font(.headline)
                        Text("AI is automatic once configured. Pasted text uses the same sharing settings.").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $draft).font(.body).frame(height: 170).border(.secondary.opacity(0.3))
                        HStack {
                            Button("Cancel") { draft = ""; pasting = false }
                            Spacer()
                            Button("Analyse") { model.analyze(draft, source: "Pasted passage"); draft = ""; pasting = false }
                                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    } else if let report = model.report {
                        HStack {
                            Text(model.source).lineLimit(1)
                            Spacer()
                            Text("\(report.wordCount) words")
                        }.font(.caption).foregroundStyle(.secondary)
                        Text(report.text).font(.system(size: 14, design: .serif)).lineLimit(3).lineSpacing(3)
                        HStack(spacing: 10) {
                            metric("Formality", report.formality.map { "\($0)/100" } ?? "—", report.formalityLabel)
                            metric("Reading ease", report.readability.map { String(format: "%.0f/100", $0) } ?? "—", report.readabilityLabel)
                        }
                        Picker("Analysis", selection: $tab) {
                            Text("Overview").tag(0)
                            Text("AI signs").tag(1)
                            Text("Writing cues").tag(2)
                        }.pickerStyle(.segmented).labelsHidden()
                        switch tab {
                        case 1: AIStyleView(report: report, assessment: model.aiReport?.aiWriting)
                        case 2:
                            if report.findings.isEmpty { Text("No local writing cues matched.").font(.callout) }
                            ForEach(report.findings.prefix(8)) { finding in
                                evidence(finding.kind, finding.excerpt, finding.explanation)
                            }
                            if report.findings.count > 8 { Button("Open detailed view for all \(report.findings.count) cues…") { model.expand?() } }
                        default:
                            if let ai = model.aiReport {
                                Text(ai.summary).font(.system(size: 17, design: .serif)).lineSpacing(3)
                                detail("Voice", ai.voice)
                                detail("Formality", ai.formality)
                                if let strength = ai.strengths.first { detail("What works", strength) }
                                ForEach(Array(ai.suggestions.prefix(2).enumerated()), id: \.offset) { _, suggestion in
                                    evidence("Try this", suggestion.excerpt, suggestion.advice)
                                }
                                Text(ai.caveat).font(.caption).foregroundStyle(.secondary)
                            } else {
                                detail("Grammatical voice", report.grammaticalVoice)
                                detail("Point of view", report.pointOfView)
                                detail("Tone cues", report.tone)
                                Text(report.formalityEvidence).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        aiStatus
                    } else {
                        Image(systemName: "text.magnifyingglass").font(.system(size: 32)).foregroundStyle(accent).padding(.top, 18)
                        Text("A fresh look at your words.").font(.system(size: 25, design: .serif))
                        Text(model.message).font(.callout).lineSpacing(4)
                        Text("Explore voice, formality, clarity, and signs of templated writing. AI runs automatically after a selection settles once you save your own key.").font(.callout).foregroundStyle(.secondary).lineSpacing(4)
                        if !model.hasAccessibility { Button("Set up selection access…") { model.showPreferences() } }
                        if !model.hasAICredential { Button("Add your OpenAI key…") { model.showPreferences() } }
                        Button("Try an example") { model.analyze(UIValidation.example, source: "Example passage") }
                        Text("Local analysis works offline. AI shares selected text with your configured provider and can incur API charges.").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(17).frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack(spacing: 12) {
                Button("Paste") { pasting.toggle(); draft = "" }
                if model.report != nil {
                    Button("Copy report") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(model.reportText, forType: .string) }
                    Button("Clear") { model.clear() }
                }
                Spacer()
                Button { model.automatic.toggle() } label: { Image(systemName: model.automatic ? "pause.fill" : "play.fill") }
                    .help(model.automatic ? "Pause automatic analysis" : "Resume automatic analysis")
                    .accessibilityLabel(model.automatic ? "Pause automatic analysis" : "Resume automatic analysis")
            }.font(.caption).buttonStyle(.borderless).padding(14)
        }.frame(width: 420, height: 590).background(Color(red: 0.97, green: 0.96, blue: 0.93))
            .foregroundStyle(Color(red: 0.16, green: 0.21, blue: 0.19)).tint(accent).preferredColorScheme(.light)
            .onDisappear { draft = ""; pasting = false }
    }
    @ViewBuilder private var aiStatus: some View {
        Divider()
        if model.isRequestingAI { ProgressView("AI is reviewing your passage…").font(.caption) }
        else if !model.aiError.isEmpty {
            Text(model.aiError).font(.caption).foregroundStyle(.red)
            if model.automaticAIAllowed { Button("Retry AI for this passage") { model.requestAI() } }
        } else if model.aiReport != nil { Label("AI perspective · OpenAI", systemImage: "sparkles").font(.caption).foregroundStyle(.secondary) }
        else if !model.hasAICredential { Button("Add a key for automatic AI…") { model.showPreferences() } }
        else if !model.automaticAIAllowed { Button("Enable automatic AI sharing…") { model.showPreferences() } }
        else if model.aiAutomatic && model.automatic { Text("Local results ready · AI review scheduled").font(.caption).foregroundStyle(.secondary) }
        else { Text("Automatic AI is paused. Open the detailed view for a one-off request.").font(.caption).foregroundStyle(.secondary) }
        Text("\(model.automatic ? "Selection analysis on" : "Automatic analysis paused") · ⇧⌘L").font(.caption2).foregroundStyle(.secondary)
    }
    private func metric(_ title: String, _ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 24, design: .serif)).foregroundStyle(accent)
            Text(label).font(.caption)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 9))
    }
    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.callout) }
    }
    private func evidence(_ title: String, _ excerpt: String, _ advice: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(accent)
            Text("“\(excerpt)”").font(.system(size: 15, design: .serif))
            Text(advice).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 9))
    }
}

struct AIStyleView: View {
    let report: WritingReport
    let assessment: AIWritingAssessment?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Style cues, not an authorship verdict").font(.headline)
            Text("These patterns can occur in human and AI writing. They cannot establish authorship.").font(.caption).foregroundStyle(.secondary)
            if let assessment {
                Text(assessment.summary).font(.callout)
                ForEach(Array(assessment.signals.enumerated()), id: \.offset) { _, signal in
                    card("Humanizer \(signal.patternID): " + HumanizerCatalogue.name(signal.patternID), signal.excerpt, signal.reason + "\nHuman explanation: " + signal.humanAlternative)
                }
                Text(assessment.limitations).font(.caption).foregroundStyle(.secondary)
                Divider()
            }
            Link("Based on Humanizer 3.1.0 · 26 patterns", destination: URL(string: "https://github.com/blader/humanizer")!).font(.caption)
            Text("Local Humanizer cues").font(.subheadline).fontWeight(.medium)
            Text(report.aiStyle.summary).font(.callout)
            ForEach(report.aiStyle.signals.prefix(20)) { signal in card(signal.kind, signal.excerpt, signal.explanation) }
            Text(report.aiStyle.limitations).font(.caption).foregroundStyle(.secondary)
        }
    }
    private func card(_ title: String, _ excerpt: String, _ explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("“\(excerpt)”").font(.system(size: 16, design: .serif))
            Text(explanation).font(.caption).lineSpacing(3)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 9))
    }
}

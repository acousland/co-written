import AppKit
import CoWrittenCore
import SwiftUI

struct CompactAnalysisView: View {
    @ObservedObject var model: AppModel
    static func size(for report: WritingReport?) -> NSSize {
        guard let report else { return NSSize(width: 360, height: 280) }
        return NSSize(width: 360, height: 184 + 24 * CompactSummary.features(report, ai: nil).count + (report.wordCount < 50 ? 14 : 0))
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "text.quote").foregroundStyle(.tint)
                Text("Co-written").font(.headline)
                Spacer()
                if model.isRequestingAI { ProgressView().controlSize(.small) }
                Button { model.showPreferences() } label: { Image(systemName: "gearshape") }.help("Settings")
                Button { model.expand?() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.help("Open full app")
            }.buttonStyle(.plain).padding(16)
            Divider()
            if let report = model.report {
                HStack {
                    Text(model.source).lineLimit(1)
                    Spacer()
                    Text("\(report.wordCount) words")
                }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.top, 12)
                VStack(spacing: 0) {
                    ForEach(CompactSummary.features(report, ai: model.aiReport)) { feature in
                        HStack(spacing: 10) {
                            Image(systemName: feature.icon).frame(width: 19).foregroundStyle(.tint)
                            Text(feature.title).foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Text(feature.value).fontWeight(.medium).lineLimit(1)
                        }.font(.system(size: 12)).frame(height: 24).help(feature.detail)
                    }
                }.padding(.horizontal, 16).padding(.top, 7)
                if report.wordCount < 50 { Text("Short sample · tentative cues").font(.caption2).foregroundStyle(.secondary).padding(.top, 4) }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.cursor").font(.system(size: 27)).foregroundStyle(.tint)
                    Text("Select text, then ⇧⌘L").font(.headline)
                    Text(model.message).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).lineLimit(3)
                }.padding(24).frame(maxHeight: .infinity)
            }
            Spacer(minLength: 8)
            status.padding(.horizontal, 16).padding(.bottom, 10)
            Divider()
            HStack(spacing: 12) {
                Text("⇧⌘L").foregroundStyle(.secondary)
                Spacer()
                if model.report != nil {
                    Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(model.reportText, forType: .string) } label: { Image(systemName: "doc.on.doc") }.help("Copy report")
                    Button { model.clear() } label: { Image(systemName: "xmark.circle") }.help("Clear")
                }
                Button("Full app") { model.expand?() }
            }.font(.caption).buttonStyle(.borderless).padding(14)
        }.frame(width: Self.size(for: model.report).width, height: Self.size(for: model.report).height).tint(.accentColor)
    }
    @ViewBuilder private var status: some View {
        if !model.aiError.isEmpty {
            HStack {
                Label("AI unavailable", systemImage: "exclamationmark.triangle").foregroundStyle(.secondary).help(model.aiError)
                Spacer()
                if model.aiSharingAllowed { Button("Retry") { model.requestAI() } }
            }.font(.caption)
        } else if model.isRequestingAI { Label("AI reviewing", systemImage: "sparkles").font(.caption).foregroundStyle(.secondary) }
        else if model.aiReport != nil { Label("AI + local cues", systemImage: "sparkles").font(.caption).foregroundStyle(.secondary) }
        else if !model.hasAICredential { Button("Add OpenAI key…") { model.showPreferences() }.font(.caption) }
        else if !model.aiSharingAllowed { Button("Allow AI sharing…") { model.showPreferences() }.font(.caption) }
        else { Label("Local cues", systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary) }
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
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }
}

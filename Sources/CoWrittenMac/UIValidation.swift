import AppKit
import CoWrittenCore
import SwiftUI

/// Renders application-owned views into images without reading or controlling another application.
@MainActor enum UIValidation {
    static let example = "We want our writing to feel clear and human. However, the implementation of the new process was delayed by the team. Perhaps we could simplify the explanation in order to help our readers understand what happens next. Thanks for taking the time to share your ideas; your feedback makes this work better."
    static func run(output: String, provider: AppDelegate) async {
        do {
            let directory = URL(fileURLWithPath: output, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let suite = "au.com.acousland.CoWritten.ui-check"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            defer { defaults.removePersistentDomain(forName: suite) }
            let model = AppModel(defaults: defaults, selectionRead: { .unavailable })
            model.aiAutomatic = false
            try await captureFull(AnalysisView(model: model), size: NSSize(width: 960, height: 760), to: directory.appendingPathComponent("welcome.png"))
            try await capture(CompactAnalysisView(model: model), size: CompactAnalysisView.size(for: model.report), to: directory.appendingPathComponent("dropdown-welcome.png"))
            model.report = WritingAnalyzer.analyze(example)
            model.source = "Example passage"
            try await captureFull(AnalysisView(model: model), size: NSSize(width: 960, height: 760), to: directory.appendingPathComponent("overview.png"))
            try await captureFull(AnalysisView(model: model, tab: 1, selectedFinding: model.report?.findings.first), size: NSSize(width: 960, height: 760), to: directory.appendingPathComponent("cues.png"))
            try await captureFull(AnalysisView(model: model, tab: 2), size: NSSize(width: 960, height: 760), to: directory.appendingPathComponent("ai.png"))
            try await capture(SettingsView(model: model), size: NSSize(width: 590, height: 760), to: directory.appendingPathComponent("settings.png"))
            try await capture(CompactAnalysisView(model: model), size: CompactAnalysisView.size(for: model.report), to: directory.appendingPathComponent("dropdown.png"))
            model.report = WritingAnalyzer.analyze("Great question! At its core, the project plays a crucial role in improving how we work. It is not just a feature but also a change in how teams share ideas. Let that sink in.")
            model.source = "Example passage"
            try await capture(CompactAnalysisView(model: model), size: CompactAnalysisView.size(for: model.report), to: directory.appendingPathComponent("dropdown-signs.png"))
            model.isRequestingAI = true
            try await capture(CompactAnalysisView(model: model), size: CompactAnalysisView.size(for: model.report), to: directory.appendingPathComponent("dropdown-loading.png"))
            model.isRequestingAI = false
            model.aiReport = AIReport(summary: "Friendly and explanatory, with a few stock rhetorical phrases that could be more specific.", voice: "Mostly active grammatical voice; a conversational narrator addressing the reader.", formality: "Neutral to conversational.", strengths: ["The intended benefit to teams is easy to identify."], suggestions: [AISuggestion(excerpt: "plays a crucial role", advice: "Name the concrete change this project makes for a team.")], caveat: "This short sample gives limited context.", aiWriting: AIWritingAssessment(summary: "A cluster of stock framing and a dramatic closer is worth reviewing.", signals: [AIWritingSignal(patternID: 2, excerpt: "Let that sink in.", reason: "This closer asks the reader to pause without adding information.", humanAlternative: "A human writer may use it deliberately for emphasis.")], limitations: "Style cannot establish authorship; edited, human and AI-assisted writing overlap."))
            model.aiReport?.quickLook = AIQuickLook(voice: "Active, conversational", formality: "Neutral", tone: "Friendly")
            try await capture(CompactAnalysisView(model: model), size: CompactAnalysisView.size(for: model.report), to: directory.appendingPathComponent("dropdown-ai.png"))
            try await capture(CompactAnalysisView(model: model), size: CompactAnalysisView.size(for: model.report), to: directory.appendingPathComponent("dropdown-ai-signs.png"))
            try await captureFull(AnalysisView(model: model, tab: 3), size: NSSize(width: 960, height: 760), to: directory.appendingPathComponent("ai-signs.png"))
            model.aiReport = nil
            model.aiError = AIClientError.outputLimitReached.localizedDescription
            try await capture(CompactAnalysisView(model: model), size: CompactAnalysisView.size(for: model.report), to: directory.appendingPathComponent("dropdown-ai-error.png"))
            model.aiError = ""
            model.aiReport = try AIReport(summary: "A useful review despite one unverified quotation.", voice: "Active.", formality: "Neutral.", strengths: [], suggestions: [AISuggestion(excerpt: "An invented quotation.", advice: "Edit this.")], caveat: "Context matters.", aiWriting: AIWritingAssessment(summary: "No supported cues.", signals: [], limitations: "Style cannot establish authorship.")).validated(passage: model.report!.text)
            try await capture(CompactAnalysisView(model: model), size: CompactAnalysisView.size(for: model.report), to: directory.appendingPathComponent("dropdown-ai-sanitized.png"))
            try await capture(AnalysisView(model: model).preferredColorScheme(.dark), size: NSSize(width: 960, height: 760), to: directory.appendingPathComponent("overview-dark.png"), appearance: .darkAqua)
            let popover = AppDelegate.makePopover(model: model)
            guard popover.behavior == .transient, popover.contentSize == CompactAnalysisView.size(for: model.report),
                  HumanizerCatalogue.patterns.count == 26 else { throw CocoaError(.coderInvalidValue) }
            guard provider.responds(to: NSSelectorFromString("analyzeSelection:userData:error:")) else {
                throw NSError(domain: "UIValidation", code: 1, userInfo: [NSLocalizedDescriptionKey: "The macOS Services selector is missing"])
            }
            print("Rendered fifteen app views; verified dropdown configuration, bundled Humanizer catalogue and Services selector. Images: \(directory.path)")
            exit(0)
        } catch {
            fputs("UI validation failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
    private static func captureFull(_ root: AnalysisView, size: NSSize, to url: URL) async throws {
        root.model.setExpandedMode(true)
        defer { root.model.setExpandedMode(false) }
        try await capture(root, size: size, to: url)
    }
    private static func capture<V: View>(_ root: V, size: NSSize, to url: URL, appearance: NSAppearance.Name = .aqua) async throws {
        let view = NSHostingView(rootView: root.background(Color(nsColor: .windowBackgroundColor)))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = view
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(150))
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.fileWriteUnknown) }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: url)
    }
}

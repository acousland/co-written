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
            let model = AppModel(defaults: defaults)
            model.automatic = false
            try await capture(AnalysisView(model: model), size: NSSize(width: 880, height: 750), to: directory.appendingPathComponent("welcome.png"))
            model.report = WritingAnalyzer.analyze(example)
            model.source = "Example passage"
            try await capture(AnalysisView(model: model), size: NSSize(width: 880, height: 750), to: directory.appendingPathComponent("overview.png"))
            try await capture(AnalysisView(model: model, tab: 1, selectedFinding: model.report?.findings.first), size: NSSize(width: 880, height: 750), to: directory.appendingPathComponent("cues.png"))
            try await capture(AnalysisView(model: model, tab: 2), size: NSSize(width: 880, height: 750), to: directory.appendingPathComponent("ai.png"))
            try await capture(SettingsView(model: model), size: NSSize(width: 590, height: 760), to: directory.appendingPathComponent("settings.png"))
            guard provider.responds(to: NSSelectorFromString("analyzeSelection:userData:error:")) else {
                throw NSError(domain: "UIValidation", code: 1, userInfo: [NSLocalizedDescriptionKey: "The macOS Services selector is missing"])
            }
            print("Rendered five app views; verified Services selector. Images: \(directory.path)")
            exit(0)
        } catch {
            fputs("UI validation failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
    private static func capture<V: View>(_ root: V, size: NSSize, to url: URL) async throws {
        let view = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
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

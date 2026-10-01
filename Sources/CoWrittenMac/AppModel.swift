import AppKit
import CoWrittenCore
import CryptoKit
import ServiceManagement
import Sparkle
import SwiftUI

@MainActor final class AppModel: ObservableObject {
    @Published var report: WritingReport?
    @Published var source = ""
    @Published var message = "Select text in another app, then press ⇧⌘L."
    @Published var isAnalyzing = false
    @Published var hasAccessibility = false
    @Published var shortcutAvailable = true
    @Published var showSettings = false
    @Published var aiReport: AIReport?
    @Published var aiError = ""
    @Published var isRequestingAI = false
    @Published var aiProvider: AIProvider { didSet { defaults.set(aiProvider.rawValue, forKey: "aiProvider") } }
    @Published var hasDirectKey = false
    @Published var automatic: Bool { didSet { defaults.set(automatic, forKey: "automatic") } }
    @Published var showOnSelection: Bool { didSet { defaults.set(showOnSelection, forKey: "showOnSelection") } }
    @Published var server: String { didSet { defaults.set(server, forKey: "aiServer") } }
    @Published var exclusions: String { didSet { defaults.set(exclusions, forKey: "exclusions"); refreshExclusions() } }
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    var present: (() -> Void)?
    let reader = SelectionReader()
    var updater: SPUStandardUpdaterController?
    private var timer: Timer?
    private var candidate = ""
    private var lastSelection = ""
    private var localTask: Task<Void, Never>?
    private var aiTask: Task<Void, Never>?
    private var generation = 0
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        aiProvider = AIProvider(rawValue: defaults.string(forKey: "aiProvider") ?? "") ?? .direct
        hasDirectKey = SecureAIStore.exists(endpoint: DirectOpenAI.account)
        automatic = defaults.object(forKey: "automatic") as? Bool ?? true
        showOnSelection = defaults.bool(forKey: "showOnSelection")
        server = defaults.string(forKey: "aiServer") ?? ""
        exclusions = defaults.string(forKey: "exclusions") ?? "com.1password.1password\ncom.agilebits.onepassword7\ncom.apple.keychainaccess\ncom.apple.Passwords"
        refreshExclusions()
    }
    func start() {
        hasAccessibility = reader.trusted
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        if Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil {
            updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        }
    }
    func stop() { timer?.invalidate(); localTask?.cancel(); aiTask?.cancel() }
    private func refreshExclusions() {
        reader.excludedBundleIDs = Set(exclusions.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }
    private func poll() {
        hasAccessibility = reader.trusted
        guard automatic, hasAccessibility else { candidate = ""; return }
        switch reader.read() {
        case let .text(text, app):
            let bounded = String(text.prefix(WritingAnalyzer.maximumCharacters + 1))
            let identity = SHA256.hash(data: Data((app + "\n" + bounded).utf8)).map { String(format: "%02x", $0) }.joined()
            guard identity == candidate else { candidate = identity; return }
            guard identity != lastSelection else { return }
            lastSelection = identity
            analyze(bounded, source: app)
            if showOnSelection { present?() }
        case .excluded:
            candidate = ""
            if report != nil { clear() }
            message = "Selection analysis is disabled for this app or secure field."
        case .unavailable:
            candidate = ""
            // Keep results while using our own panel, otherwise release the captured passage.
            if NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                lastSelection = ""
                if report != nil { clear() }
            }
        case .permissionRequired: candidate = ""
        }
    }
    func captureSelection() {
        switch reader.read() {
        case let .text(text, app): analyze(text, source: app)
        case .permissionRequired: clear(); message = "Enable Accessibility in Settings to read a selection. You can also paste text here."; showSettings = true
        case .excluded: clear(); message = "This app or secure field is excluded from selection analysis."
        case .unavailable: clear(); message = "This app does not expose a text selection. Use Services → Analyse with Co-written, or copy and paste text here."
        }
        present?()
    }
    func analyze(_ text: String, source: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { clear(); return }
        generation += 1
        let current = generation
        localTask?.cancel(); aiTask?.cancel()
        aiReport = nil; aiError = ""; isRequestingAI = false
        self.source = source
        isAnalyzing = true
        message = ""
        let bounded = String(text.prefix(WritingAnalyzer.maximumCharacters + 1))
        localTask = Task { [weak self] in
            let report = await Task.detached(priority: .userInitiated) { WritingAnalyzer.analyze(bounded) }.value
            guard !Task.isCancelled, let self, self.generation == current else { return }
            self.report = report
            self.isAnalyzing = false
        }
    }
    func clear() {
        generation += 1
        localTask?.cancel(); aiTask?.cancel()
        report = nil; aiReport = nil; aiError = ""; source = ""
        isAnalyzing = false; isRequestingAI = false
        message = "Select text in another app, then press ⇧⌘L."
    }
    func requestAI() {
        guard let report, !isRequestingAI else { return }
        let current = generation
        let server = self.server
        let provider = aiProvider
        isRequestingAI = true; aiError = ""
        aiTask = Task { [weak self] in
            do {
                let response: AIReport
                if provider == .direct { response = try await DirectOpenAI.analyze(report.text) }
                else { response = try await AIClient.analyze(text: report.text, server: server) }
                guard !Task.isCancelled, let self, self.generation == current else { return }
                self.aiReport = response
                self.isRequestingAI = false
            } catch {
                guard !Task.isCancelled, let self, self.generation == current else { return }
                self.aiError = error.localizedDescription
                self.isRequestingAI = false
            }
        }
    }
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval { message = "Allow Co-written in System Settings → General → Login Items." }
        } catch { message = "Login setting could not be changed: " + error.localizedDescription }
    }
}

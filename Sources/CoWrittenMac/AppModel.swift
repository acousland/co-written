import AppKit
import CoWrittenCore
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
    @Published var aiProvider: AIProvider { didSet { defaults.set(aiProvider.rawValue, forKey: "aiProvider"); resetAIConfiguration() } }
    @Published var hasDirectKey = false
    @Published var aiAutomatic: Bool { didSet { defaults.set(aiAutomatic, forKey: "aiAutomatic"); configurationGeneration += 1; cancelAI() } }
    @Published private(set) var authorizedDestinations: [String]
    @Published private(set) var hasAICredential = false
    @Published var server: String { didSet { defaults.set(server, forKey: "aiServer"); resetAIConfiguration() } }
    @Published var exclusions: String { didSet { defaults.set(exclusions, forKey: "exclusions"); refreshExclusions(); configurationGeneration += 1; cancelAI() } }
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    var present: (() -> Void)?
    var expand: (() -> Void)?
    var openSettings: (() -> Void)?
    var closeSettings: (() -> Void)?
    let reader = SelectionReader()
    var updater: SPUStandardUpdaterController?
    private var localTask: Task<Void, Never>?
    private var aiTask: Task<Void, Never>?
    private var configurationGeneration = 0
    private var generation = 0
    private let defaults: UserDefaults
    private let analyzeAI: @Sendable (String, AIProvider, String) async throws -> AIReport
    private let credentialAvailable: @MainActor (AIProvider, String) -> Bool
    private let aiDelay: Duration
    private let selectionRead: (@MainActor () -> SelectionResult)?
    private var pendingAI: Task<Void, Never>?
    var destination: String? { aiProvider == .direct ? DirectOpenAI.account : try? AIClient.tokenAccount(server) }
    var aiSharingAllowed: Bool { hasAICredential && destination.map { authorizedDestinations.contains($0) } == true }
    var reportText: String {
        guard let report else { return "" }
        var text = report.exportText
        if let ai = aiReport {
            text += "\n\nAI perspective\n\(ai.summary)\nVoice: \(ai.voice)\nFormality: \(ai.formality)\n" + ai.strengths.joined(separator: "\n")
            text += "\n" + ai.suggestions.map { "“\($0.excerpt)” — \($0.advice)" }.joined(separator: "\n") + "\n" + ai.caveat
            if let review = ai.aiWriting {
                text += "\n\nAI style review\n\(review.summary)\n" + review.signals.map { "“\($0.excerpt)”\n\($0.reason)\nHuman explanation: \($0.humanAlternative)" }.joined(separator: "\n\n") + "\n" + review.limitations
            }
        }
        return text
    }

    init(defaults: UserDefaults = .standard, aiDelay: Duration = .milliseconds(150),
         selectionRead: (@MainActor () -> SelectionResult)? = nil,
         credentialAvailable: @escaping @MainActor (AIProvider, String) -> Bool = { provider, server in
             if provider == .direct { return SecureAIStore.exists(endpoint: DirectOpenAI.account) }
             guard let endpoint = try? AIClient.tokenAccount(server) else { return false }
             return SecureAIStore.exists(endpoint: endpoint)
         },
         analyzeAI: @escaping @Sendable (String, AIProvider, String) async throws -> AIReport = { text, provider, server in
             if provider == .direct { return try await DirectOpenAI.analyze(text) }
             return try await AIClient.analyze(text: text, server: server)
         }) {
        self.aiDelay = aiDelay
        self.selectionRead = selectionRead
        self.credentialAvailable = credentialAvailable
        self.analyzeAI = analyzeAI
        self.defaults = defaults
        aiProvider = AIProvider(rawValue: defaults.string(forKey: "aiProvider") ?? "") ?? .direct
        hasDirectKey = credentialAvailable(.direct, "")
        aiAutomatic = defaults.object(forKey: "aiAutomatic") as? Bool ?? true
        authorizedDestinations = defaults.stringArray(forKey: "aiDestinations") ?? []
        server = defaults.string(forKey: "aiServer") ?? ""
        exclusions = defaults.string(forKey: "exclusions") ?? "com.1password.1password\ncom.agilebits.onepassword7\ncom.apple.keychainaccess\ncom.apple.Passwords"
        hasAICredential = credentialAvailable(aiProvider, server)
        refreshExclusions()
    }
    func start() {
        hasAccessibility = reader.trusted
        if Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil {
            updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        }
    }
    func stop() { generation += 1; localTask?.cancel(); cancelAI() }
    private func refreshExclusions() {
        reader.excludedBundleIDs = Set(exclusions.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }
    func captureSelection() {
        hasAccessibility = reader.trusted
        switch selectionRead?() ?? reader.read() {
        case let .text(text, app): analyze(text, source: app)
        case .permissionRequired: clear(); message = "Enable Accessibility in Settings to read a selection. You can also paste text here."
        case .excluded: clear(); message = "This app or secure field is excluded from selection analysis."
        case .unavailable: clear(); message = "This app does not expose a text selection. Use Services → Analyse with Co-written, or copy and paste text here."
        }
        present?()
    }
    func analyze(_ text: String, source: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { clear(); return }
        let bounded = String(text.prefix(WritingAnalyzer.maximumCharacters + 1))
        if report?.text == String(bounded.prefix(WritingAnalyzer.maximumCharacters)), !isAnalyzing {
            self.source = source
            scheduleAI()
            return
        }
        generation += 1
        let current = generation
        let configuration = configurationGeneration
        localTask?.cancel(); cancelAI()
        aiReport = nil; aiError = ""; isRequestingAI = false
        self.source = source
        isAnalyzing = true
        message = ""
        self.report = nil
        localTask = Task { [weak self] in
            let report = await Task.detached(priority: .userInitiated) { WritingAnalyzer.analyze(bounded) }.value
            guard !Task.isCancelled, let self, self.generation == current else { return }
            self.report = report
            self.isAnalyzing = false
            if self.configurationGeneration == configuration { self.scheduleAI() }
        }
    }
    func clear() {
        generation += 1
        localTask?.cancel(); cancelAI()
        report = nil; aiReport = nil; aiError = ""; source = ""
        isAnalyzing = false; isRequestingAI = false
        message = "Select text in another app, then press ⇧⌘L."
    }
    private func cancelAI() {
        pendingAI?.cancel(); pendingAI = nil
        aiTask?.cancel(); aiTask = nil
        isRequestingAI = false
    }
    private func resetAIConfiguration() {
        configurationGeneration += 1
        cancelAI()
        aiReport = nil; aiError = ""
        hasAICredential = credentialAvailable(aiProvider, server)
    }
    func credentialsChanged(authorize: Bool) {
        if let destination {
            authorizedDestinations.removeAll { $0 == destination }
            if authorize { authorizedDestinations.append(destination) }
            defaults.set(authorizedDestinations, forKey: "aiDestinations")
        }
        hasDirectKey = credentialAvailable(.direct, "")
        resetAIConfiguration()
    }
    private func scheduleAI() {
        guard aiAutomatic, aiSharingAllowed, let report, !isRequestingAI,
              aiReport == nil, pendingAI == nil else { return }
        let current = generation
        let delay = aiDelay
        pendingAI = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
                guard !Task.isCancelled, let self, self.generation == current,
                      self.aiAutomatic, self.aiSharingAllowed, self.report?.text == report.text else { return }
                self.pendingAI = nil
                self.requestAI(defaultRequest: true)
            } catch { /* A new request or settings change cancelled pending work. */ }
        }
    }
    func requestAI(defaultRequest: Bool = false) {
        guard let report, !isRequestingAI else { return }
        if defaultRequest && (!aiAutomatic || !aiSharingAllowed) { return }
        pendingAI?.cancel(); pendingAI = nil
        let current = generation
        let server = self.server
        let provider = aiProvider
        let analyzeAI = self.analyzeAI
        isRequestingAI = true; aiError = ""
        aiTask = Task { [weak self] in
            do {
                let rawResponse = try await analyzeAI(report.text, provider, server)
                let response = try rawResponse.validated(passage: report.text)
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
    func showPreferences() {
        hasAccessibility = reader.trusted
        if let openSettings { openSettings() } else { showSettings = true }
    }
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval { message = "Allow Co-written in System Settings → General → Login Items." }
        } catch { message = "Login setting could not be changed: " + error.localizedDescription }
    }
}

import AppKit
import CoWrittenCore
import SwiftUI

private let ink = PresentationStyle.ink
private let accent = PresentationStyle.accent
private let paper = PresentationStyle.paper

struct AnalysisView: View {
    @ObservedObject var model: AppModel
    @State private var draft = ""
    @State private var tab = 0
    @State private var aiConsent = false
    @State private var selectedFinding: Finding?

    init(model: AppModel, tab: Int = 0, selectedFinding: Finding? = nil) {
        self.model = model
        _tab = State(initialValue: tab)
        _selectedFinding = State(initialValue: selectedFinding)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack {
                    Text("Co-written").font(.system(size: 22, weight: .semibold, design: .serif))
                    Spacer()
                    Label(model.aiStatus, systemImage: model.aiAutomatic || model.aiReport != nil ? "sparkles" : "lock.shield")
                        .font(.caption).foregroundStyle(PresentationStyle.secondary)
                }.padding(.horizontal, 20).padding(.vertical, 12)
                Divider()
                if let report = model.report {
                    if geometry.size.width < 800 {
                        VStack(spacing: 0) {
                            passage(report, compact: true)
                                .frame(height: min(210, max(150, geometry.size.height * 0.28)))
                            Divider()
                            analysis(report, compact: true)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 0) {
                            passage(report).frame(width: min(310, geometry.size.width * 0.3))
                            Divider()
                            analysis(report, compact: false).frame(minWidth: 0, maxWidth: .infinity)
                        }
                    }
                } else {
                    welcome(compact: geometry.size.width < 800)
                }
                Divider()
                HStack(spacing: 12) {
                    Circle().fill(model.hasAccessibility ? accent : Color.secondary).frame(width: 6, height: 6)
                    Text(model.hasAccessibility ? (model.expandedMode ? "Mouse selection on" : "Shortcut only · ⇧⌘L") : "Selection access needed")
                        .font(.caption).foregroundStyle(PresentationStyle.secondary).lineLimit(1)
                        .help(model.expandedMode ? "Close, hide or minimise this window to return to shortcut-only analysis." : "Enable Accessibility in Settings to read selected text.")
                    Spacer()
                    if model.report != nil {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(model.reportText, forType: .string)
                        } label: { Label("Copy report", systemImage: "doc.on.doc").labelStyle(.iconOnly) }.help("Copy report")
                        Button("Clear") { model.clear() }
                    }
                }.padding(14)
            }
            .foregroundStyle(ink).background(paper).tint(accent)
            .environment(\.colorScheme, .light)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .sheet(isPresented: $model.showSettings) { SettingsView(model: model).frame(width: 590) }
        .sheet(isPresented: $model.showPaste) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Give your words a fresh look").font(.title2).fontWeight(.medium)
                Text("Paste a passage here. Local analysis works without Accessibility permission.").foregroundStyle(PresentationStyle.secondary)
                TextEditor(text: $draft).font(.system(size: 15)).frame(height: 240)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(.secondary.opacity(0.3)))
                HStack {
                    Text("Up to 20,000 characters").font(.caption).foregroundStyle(PresentationStyle.secondary)
                    Spacer()
                    Button("Cancel") { draft = ""; model.showPaste = false }
                    Button("Analyse") {
                        model.analyze(draft, source: "Pasted passage")
                        draft = ""; model.showPaste = false
                    }.keyboardShortcut(.defaultAction).disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(24).frame(minWidth: 340, idealWidth: 600, maxWidth: 600)
        }
        .sheet(isPresented: $aiConsent) {
            VStack(alignment: .leading, spacing: 18) {
                Label("Ask for an AI perspective", systemImage: "sparkles").font(.title2)
                if model.aiProvider == .direct {
                    Text("This sends the current passage (\(model.report?.wordCount ?? 0) words) directly to OpenAI using your API key. API usage is billed to your OpenAI account. Only send text you are comfortable sharing with OpenAI; its data-retention rules apply.")
                } else {
                    Text("This sends the current passage (\(model.report?.wordCount ?? 0) words) to \(model.server), which forwards it to OpenAI. Only send text you are comfortable sharing with those services. OpenAI’s data-retention rules apply.")
                }
                Text("Your local analysis stays available. Default AI follows your sharing settings.").foregroundStyle(PresentationStyle.secondary)
                HStack {
                    Spacer()
                    Button("Cancel") { aiConsent = false }
                    Button("Send this passage") { aiConsent = false; model.requestAI() }.keyboardShortcut(.defaultAction)
                }
            }.padding(26).frame(width: 500)
        }
        .onChange(of: model.report?.text) { _, _ in selectedFinding = nil }
    }

    private func analysis(_ report: WritingReport, compact: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("Your writing, at a glance").font(.system(size: compact ? 21 : 23, weight: .medium, design: .serif))
                    Spacer()
                    if model.isAnalyzing { ProgressView().controlSize(.small) }
                }
                Text(report.summary).foregroundStyle(PresentationStyle.secondary).font(.callout)
                Picker("Analysis view", selection: $tab) {
                    Text("Overview").tag(0)
                    Text(compact ? "Cues (\(report.findings.count))" : "Writing cues (\(report.findings.count))").tag(1)
                    Text(compact ? "AI review" : "AI perspective").tag(2)
                    Text("AI signs").tag(3)
                }.pickerStyle(.segmented).labelsHidden()
                switch tab {
                case 1: findings(report)
                case 2: aiView(report)
                case 3: AIStyleView(report: report, assessment: model.aiReport?.aiWriting)
                default: overview(report)
                }
                Text(report.caveat).font(.caption).foregroundStyle(PresentationStyle.secondary).lineSpacing(3)
            }.padding(compact ? 18 : 24).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func welcome(compact: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("Understand the writing\nyou already have.")
                    .font(.system(size: compact ? 30 : 38, weight: .medium, design: .serif)).lineSpacing(3)
                Text("While this window is open, highlight text in your editor or browser to review its voice, formality, clarity, and rhythm. Close the window to return to shortcut-only analysis in the menu bar.")
                    .font(.system(size: 16)).foregroundStyle(PresentationStyle.secondary).lineSpacing(5).frame(maxWidth: 630)
                if compact {
                    VStack(alignment: .leading, spacing: 20) { welcomeFeatures }
                } else {
                    HStack(alignment: .top, spacing: 28) { welcomeFeatures }
                }
                if !model.message.isEmpty && model.message != "Select text in another app, then press ⇧⌘L." { Text(model.message).font(.callout).foregroundStyle(PresentationStyle.secondary) }
                ViewThatFits(in: .horizontal) {
                    HStack { welcomeActions }
                    VStack(alignment: .leading) { welcomeActions }
                }
                Label("Mouse selections use your AI sharing settings while this window is open.", systemImage: "cursorarrow.rays")
                    .font(.caption).foregroundStyle(accent)
            }.padding(compact ? 22 : 36).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    @ViewBuilder private var welcomeFeatures: some View {
        feature("1", "Select your words", "Highlight a paragraph in your editor, browser, or email.")
        feature("2", "Take a closer look", "While this window is open, highlighting text in another app updates the analysis.")
        feature("3", "Choose what helps", "Explore patterns and suggestions. Your voice stays yours.")
    }
    @ViewBuilder private var welcomeActions: some View {
        Button("Set up selection access") { model.showPreferences() }.buttonStyle(.borderedProminent)
        Button("Paste a passage") { model.showPaste = true }
        Button("Try an example") {
            model.analyze("We want our writing to feel clear and human. However, the implementation of the new process was delayed by the team. Perhaps we could simplify the explanation in order to help our readers understand what happens next. Thanks for taking the time to share your ideas; your feedback makes this work better.", source: "Example passage")
        }
    }
    private func feature(_ number: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(number).font(.system(size: 23, design: .serif)).foregroundStyle(accent)
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(PresentationStyle.secondary).lineSpacing(3)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func passage(_ report: WritingReport, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            HStack {
                Text("THE PASSAGE").font(.system(size: 10, weight: .semibold)).tracking(1.8)
                Spacer()
                if compact {
                    Text("\(report.wordCount) words · \(report.language)").font(.caption).foregroundStyle(PresentationStyle.secondary)
                } else { Image(systemName: "doc.text").foregroundStyle(PresentationStyle.secondary) }
            }
            Text(model.source).font(.caption).foregroundStyle(PresentationStyle.secondary)
            ScrollView {
                Text(highlighted(report)).font(.system(size: 16, design: .serif)).lineSpacing(6)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            if !compact {
                Divider()
                HStack {
                    Text("\(report.wordCount) words")
                    Spacer()
                    Text(report.readingSeconds < 60 ? "\(report.readingSeconds)s read" : "\(Int(ceil(Double(report.readingSeconds) / 60))) min read")
                }.font(.caption).foregroundStyle(PresentationStyle.secondary)
                Text(report.language).font(.caption).foregroundStyle(PresentationStyle.secondary)
            }
        }.padding(compact ? 18 : 22).background(PresentationStyle.passage)
    }
    private func highlighted(_ report: WritingReport) -> AttributedString {
        var result = AttributedString(report.text)
        guard let finding = selectedFinding,
              let stringRange = Range(NSRange(location: finding.start, length: finding.length), in: report.text),
              let range = Range(stringRange, in: result) else { return result }
        result[range].backgroundColor = Color.yellow.opacity(0.4)
        result[range].foregroundColor = ink
        return result
    }
    private func overview(_ report: WritingReport) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            if let ai = model.aiReport {
                VStack(alignment: .leading, spacing: 12) {
                    Label("AI check", systemImage: "sparkles").font(.headline).foregroundStyle(accent)
                    Text(ai.summary).font(.callout).lineSpacing(3)
                    row("Voice", ai.quickLook?.voice ?? ai.voice)
                    row("Formality", ai.quickLook?.formality ?? ai.formality)
                    Button("See AI suggestions") { tab = 2 }.buttonStyle(.borderless)
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(PresentationStyle.card, in: RoundedRectangle(cornerRadius: 10))
            } else if model.isRequestingAI || model.isWaitingForAI {
                ProgressView("Checking with AI…").font(.callout)
            } else if !model.aiError.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.aiError).font(.callout).foregroundStyle(.red)
                    if model.aiAutomatic && model.aiSharingAllowed { Button("Retry AI check") { model.requestAI(defaultRequest: true) } }
                }
            }
            HStack(alignment: .top, spacing: 15) {
                metric("Formality", value: report.formality.map { "\($0)" } ?? "—", label: report.formalityLabel)
                metric("Reading ease", value: report.readability.map { String(format: "%.0f", $0) } ?? "—", label: report.readabilityLabel)
            }
            Text(report.formalityEvidence).font(.caption).foregroundStyle(PresentationStyle.secondary).lineSpacing(3)
            VStack(alignment: .leading, spacing: 13) {
                row("Grammatical voice", report.grammaticalVoice)
                row("Point of view", report.pointOfView)
                row("Tone cues", report.tone)
            }.padding(16).background(PresentationStyle.card, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Sentence rhythm").font(.headline)
                    Spacer()
                    Text(String(format: "%.1f words / sentence", report.averageSentenceLength)).font(.caption).foregroundStyle(PresentationStyle.secondary)
                }
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(report.sentences.prefix(45))) { sentence in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(sentence.words > 30 ? Color.orange.opacity(0.6) : accent.opacity(0.65))
                            .frame(maxWidth: .infinity)
                            .frame(height: max(4, Double(sentence.words) / Double(max(1, report.sentences.prefix(45).map(\.words).max() ?? 1)) * 62))
                            .help("Sentence \(sentence.id + 1): \(sentence.words) words")
                            .accessibilityLabel("Sentence \(sentence.id + 1), \(sentence.words) words")
                    }
                }.frame(height: 65)
                Text("Each bar is a sentence. Amber marks more than 30 words. The first 45 sentences are shown.").font(.caption).foregroundStyle(PresentationStyle.secondary)
            }
            HStack {
                row("Sentences", String(report.sentenceCount))
                Spacer()
                row("Unique words", "\(report.vocabularyVariety)%")
            }
            if !report.repeatedWords.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Words you return to").font(.headline)
                    Text(report.repeatedWords.joined(separator: "   ·   ")).font(.callout)
                    Text("Repetition can create cohesion. Check whether each use earns its place.").font(.caption).foregroundStyle(PresentationStyle.secondary)
                }
            }
            Text("Reading ease uses an approximate English Flesch formula (0–100); syllables are estimated. Unique-word percentage depends strongly on sample length.")
                .font(.caption).foregroundStyle(PresentationStyle.secondary)
        }
    }
    private func metric(_ title: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.callout).foregroundStyle(PresentationStyle.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 38, weight: .medium, design: .serif)).foregroundStyle(accent)
                if value != "—" { Text("/100").font(.caption).foregroundStyle(PresentationStyle.secondary) }
            }
            Text(label).font(.callout)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(PresentationStyle.card, in: RoundedRectangle(cornerRadius: 10))
    }
    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(PresentationStyle.secondary)
            Text(value).font(.callout).fontWeight(.medium)
        }
    }
    private func findings(_ report: WritingReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cues to consider, not errors to fix. Click a card to highlight its evidence.").font(.callout).foregroundStyle(PresentationStyle.secondary)
            if report.findings.isEmpty {
                Label(report.supportsStyleAnalysis ? "No cues matched these local rules." : "English style rules are unavailable for this passage.", systemImage: "text.magnifyingglass")
                    .padding(.vertical, 24)
            }
            ForEach(report.findings.prefix(100)) { finding in
                Button { selectedFinding = finding } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(finding.kind.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(accent)
                        Text("“\(finding.excerpt)”").font(.system(size: 17, design: .serif)).lineLimit(5)
                        Text(finding.explanation).font(.caption).foregroundStyle(PresentationStyle.secondary).lineSpacing(3)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                        .background(selectedFinding?.id == finding.id ? accent.opacity(0.10) : PresentationStyle.card, in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain)
            }
            if report.findings.count > 100 { Text("Showing the first 100 cues. Copy the report for the complete list.").font(.caption) }
        }
    }
    private func aiView(_ report: WritingReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let ai = model.aiReport {
                Text(ai.summary).font(.system(size: 18, design: .serif)).lineSpacing(4)
                row("Voice", ai.voice)
                row("Formality", ai.formality)
                Text("What works").font(.headline)
                ForEach(Array(ai.strengths.enumerated()), id: \.offset) { _, strength in Text("• " + strength).font(.callout) }
                Text("Consider trying").font(.headline)
                ForEach(Array(ai.suggestions.enumerated()), id: \.offset) { _, suggestion in
                    VStack(alignment: .leading, spacing: 7) {
                        Text("“\(suggestion.excerpt)”").font(.system(size: 16, design: .serif))
                        Text(suggestion.advice).font(.callout).foregroundStyle(PresentationStyle.secondary)
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(PresentationStyle.card, in: RoundedRectangle(cornerRadius: 10))
                }
                Text(ai.caveat).font(.caption).foregroundStyle(PresentationStyle.secondary)
            } else {
                Image(systemName: "sparkles").font(.system(size: 30)).foregroundStyle(accent)
                Text("Another perspective, when you want it.").font(.system(size: 24, design: .serif))
                Text(model.aiProvider == .direct ? "AI can consider context, strengths, and practical edits. Add your own OpenAI API key to connect directly from this Mac. AI reviews highlighted passages while the full window is open, using your sharing settings." : "AI can consider context, strengths, and practical edits. After you enable sharing, requested passages go to your configured Co-written service and OpenAI.").font(.callout).foregroundStyle(PresentationStyle.secondary).lineSpacing(4)
            }
            if model.isRequestingAI { ProgressView("Considering your passage…") }
            if !model.aiError.isEmpty { Text(model.aiError).foregroundStyle(.red).font(.callout) }
            if (model.aiProvider == .direct && !model.hasDirectKey) || (model.aiProvider == .sharedService && model.server.isEmpty) {
                Button("Configure AI access…") { model.showPreferences() }
            } else {
                Button(model.aiReport == nil ? "Check with AI" : "Refresh AI check") {
                    if model.aiAutomatic && model.aiSharingAllowed { model.requestAI(defaultRequest: true) }
                    else { aiConsent = true }
                }.disabled(model.isRequestingAI || model.isWaitingForAI)
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var saved = ""
    @State private var wordStatus = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Co-written settings").font(.title2).fontWeight(.medium)
                Spacer()
                Button("Done") { if let close = model.closeSettings { close() } else { dismiss() } }.keyboardShortcut(.defaultAction)
            }.padding(22)
            Form {
                Section("Selection analysis") {
                    LabeledContent("Accessibility", value: model.hasAccessibility ? "Enabled" : "Permission needed")
                    Button("Enable Accessibility…") { model.reader.requestPermission() }
                    Button("Open Accessibility Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
                    }
                    Button("Enable Word selections…") {
                        wordStatus = WordSelectionReader.requestPermission() ? "Word selection access enabled. Highlight text in Word to analyse it." : "Open Word, then allow Co-written in System Settings → Privacy & Security → Automation."
                    }
                    if !wordStatus.isEmpty { Text(wordStatus).font(.caption).foregroundStyle(PresentationStyle.secondary) }
                    Text("Word needs one-time Automation permission to read the complete highlighted range across pages. No copying or document changes are performed.").font(.caption).foregroundStyle(PresentationStyle.secondary)
                    Text(model.shortcutAvailable ? "Menu bar: ⇧⌘L analyses the current selection. Full app: mouse selection updates analysis while its window is open. Closing, hiding, or minimising it stops watching selections." : "⇧⌘L is already in use. Free that shortcut, or explicitly supply text using Paste or macOS Services.")
                        .font(.caption).foregroundStyle(PresentationStyle.secondary)
                    Text("No keystrokes are recorded. Secure fields are skipped. Some apps do not expose selected text; use the Services menu or paste a passage.")
                        .font(.caption).foregroundStyle(PresentationStyle.secondary)
                }
                Section("Excluded apps") {
                    Text("One app bundle identifier per line. Password managers are excluded by default.").font(.caption).foregroundStyle(PresentationStyle.secondary)
                    TextEditor(text: $model.exclusions).font(.system(.caption, design: .monospaced)).frame(height: 75)
                }
                Section("AI analysis") {
                    Toggle("Include AI in analyses", isOn: $model.aiAutomatic)
                    Text("Enabling AI checks the current passage when sharing is authorised. AI runs for shortcut and pasted analyses, and settled mouse selections while the full window is open. Every settled passage includes an AI check when enabled; closing, hiding, or minimising the window stops selection watching and pending work. Usage is billed to your account. Turn this off for local analysis.").font(.caption).foregroundStyle(PresentationStyle.secondary)
                    Picker("Connect using", selection: $model.aiProvider) {
                        Text("Your OpenAI account").tag(AIProvider.direct)
                        Text("A shared Co-written service").tag(AIProvider.sharedService)
                    }
                    if model.aiProvider == .direct {
                        SecureField("Your OpenAI API key", text: $token)
                        Text(model.hasDirectKey ? "An API key is saved in this Mac’s Keychain." : "Add your own key to connect directly to OpenAI. No separate server is needed.").font(.caption).foregroundStyle(PresentationStyle.secondary)
                        Text("Your key stays in Keychain on this Mac and is sent only to api.openai.com. Saving your key below allows requested passages to be shared with OpenAI when AI is enabled. OpenAI bills usage to your account and its retention rules apply. No key is included in the downloaded app.").font(.caption).foregroundStyle(PresentationStyle.secondary)
                        Link("Manage OpenAI API keys", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    } else {
                        TextField("Server URL", text: $model.server, prompt: Text("https://analysis.example.com"))
                        SecureField("Personal access token", text: $token)
                        Text("Use a personal Co-written token from the service owner, rather than an OpenAI key. The token is stored in Keychain and bound to this HTTPS server.").font(.caption).foregroundStyle(PresentationStyle.secondary)
                    }
                    HStack {
                        Button(model.aiAutomatic ? "Save credential & allow AI" : "Save credential") {
                            do {
                                let credential = token.trimmingCharacters(in: .whitespacesAndNewlines)
                                let account: String
                                if model.aiProvider == .direct {
                                    guard credential.hasPrefix("sk-"), credential.count >= 20 else { saved = "Enter your own OpenAI API key."; return }
                                    account = DirectOpenAI.account
                                } else {
                                    guard credential.hasPrefix("cw_"), (40...128).contains(credential.count) else { saved = "Enter a personal Co-written token, rather than an OpenAI key."; return }
                                    account = try AIClient.tokenAccount(model.server)
                                }
                                try SecureAIStore.save(credential, endpoint: account)
                                model.credentialsChanged(authorize: true)
                                token = ""; saved = "Credential saved in Keychain."
                            } catch { saved = error.localizedDescription }
                        }
                        Button("Remove saved credential") {
                            do {
                                let account = model.aiProvider == .direct ? DirectOpenAI.account : try AIClient.tokenAccount(model.server)
                                try SecureAIStore.save("", endpoint: account)
                                model.credentialsChanged(authorize: false)
                                token = ""; saved = "Saved credential removed."
                            }
                            catch { saved = error.localizedDescription }
                        }
                    }
                    if model.hasAICredential && !model.aiSharingAllowed {
                        Text("AI sharing has not been allowed for this saved credential. Allowing it permits future requested passages to be sent to this destination and may incur charges.").font(.caption).foregroundStyle(PresentationStyle.secondary)
                        Button("Allow AI at this destination") { model.credentialsChanged(authorize: true) }
                    }
                    if model.aiSharingAllowed { Text("AI sharing is allowed for requested passages at this destination. Turn off AI above to keep analysis local.").font(.caption).foregroundStyle(PresentationStyle.secondary) }
                    if !saved.isEmpty { Text(saved).font(.caption).foregroundStyle(PresentationStyle.secondary) }
                }
                Section("General") {
                    Toggle("Start Co-written at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")
                    if let updater = model.updater { Button("Check for Updates…") { updater.checkForUpdates(nil) } }
                    Text("Local analysis keeps only the current passage in memory. Clear removes it. No writing history or usage telemetry is collected.").font(.caption).foregroundStyle(PresentationStyle.secondary)
                    if !model.message.isEmpty { Text(model.message).font(.caption).foregroundStyle(PresentationStyle.secondary) }
                }
            }.formStyle(.grouped)
        }.frame(height: 760).foregroundStyle(ink).background(paper).tint(accent).environment(\.colorScheme, .light)
            .onChange(of: model.aiProvider) { _, _ in token = ""; saved = "" }
            .onDisappear { token = "" }
    }
}

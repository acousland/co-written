import AppKit
import CoWrittenCore
import SwiftUI

private let ink = Color(red: 0.16, green: 0.21, blue: 0.19)
private let accent = Color(red: 0.27, green: 0.40, blue: 0.31)
private let paper = Color(red: 0.97, green: 0.96, blue: 0.93)

struct AnalysisView: View {
    @ObservedObject var model: AppModel
    @State private var paste = false
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
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "text.quote").font(.system(size: 30, weight: .medium)).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Co-written").font(.system(size: 25, weight: .semibold, design: .serif))
                    Text("A little perspective on your words.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Label(model.isRequestingAI ? "Sending to AI" : (model.aiReport == nil ? "On-device" : "AI assisted"), systemImage: model.aiReport == nil && !model.isRequestingAI ? "lock.shield" : "sparkles").font(.caption).foregroundStyle(accent)
                    .padding(.horizontal, 11).padding(.vertical, 7).background(accent.opacity(0.08), in: Capsule())
                Button { model.showPreferences() } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.plain).help("Settings")
            }.padding(24)
            Divider()
            if let report = model.report {
                HStack(alignment: .top, spacing: 0) {
                    passage(report).frame(minWidth: 230, idealWidth: 275, maxWidth: 310)
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            HStack {
                                Text("Your writing, at a glance").font(.system(size: 23, weight: .medium, design: .serif))
                                Spacer()
                                if model.isAnalyzing { ProgressView().controlSize(.small) }
                            }
                            Text(report.summary).foregroundStyle(.secondary).font(.callout)
                            Picker("Analysis view", selection: $tab) {
                                Text("Overview").tag(0)
                                Text("Writing cues (\(report.findings.count))").tag(1)
                                Text("AI perspective").tag(2)
                                Text("AI signs").tag(3)
                            }.pickerStyle(.segmented).labelsHidden()
                            switch tab {
                            case 1: findings(report)
                            case 2: aiView(report)
                            case 3: AIStyleView(report: report, assessment: model.aiReport?.aiWriting)
                            default: overview(report)
                            }
                            Text(report.caveat).font(.caption).foregroundStyle(.secondary).lineSpacing(3)
                        }.padding(24)
                    }
                }
            } else {
                welcome
            }
            Divider()
            HStack(spacing: 12) {
                Circle().fill(model.hasAccessibility ? accent : Color.secondary).frame(width: 6, height: 6)
                Text(model.hasAccessibility ? "Shortcut only · ⇧⌘L" : "Accessibility permission needed")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Paste text…") { paste = true }
                if model.report != nil {
                    Button("Copy report") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(model.reportText, forType: .string)
                    }
                    Button("Clear") { model.clear() }
                }
            }.padding(14)
        }
        .foregroundStyle(ink).background(paper).tint(accent)
        .preferredColorScheme(.light)
        .sheet(isPresented: $model.showSettings) { SettingsView(model: model).frame(width: 590) }
        .sheet(isPresented: $paste) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Give your words a fresh look").font(.title2).fontWeight(.medium)
                Text("Paste a passage here. Local analysis works without Accessibility permission.").foregroundStyle(.secondary)
                TextEditor(text: $draft).font(.system(size: 15)).frame(width: 600, height: 280)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(.secondary.opacity(0.3)))
                HStack {
                    Text("Up to 20,000 characters · English style estimates").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") { draft = ""; paste = false }
                    Button("Analyse") {
                        model.analyze(draft, source: "Pasted passage")
                        draft = ""; paste = false
                    }.keyboardShortcut(.defaultAction).disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(24)
        }
        .sheet(isPresented: $aiConsent) {
            VStack(alignment: .leading, spacing: 18) {
                Label("Ask for an AI perspective", systemImage: "sparkles").font(.title2)
                if model.aiProvider == .direct {
                    Text("This sends the current passage (\(model.report?.wordCount ?? 0) words) directly to OpenAI using your API key. API usage is billed to your OpenAI account. Only send text you are comfortable sharing with OpenAI; its data-retention rules apply.")
                } else {
                    Text("This sends the current passage (\(model.report?.wordCount ?? 0) words) to \(model.server), which forwards it to OpenAI. Only send text you are comfortable sharing with those services. OpenAI’s data-retention rules apply.")
                }
                Text("Your local analysis stays available. Default AI follows your sharing settings.").foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Cancel") { aiConsent = false }
                    Button("Send this passage") { aiConsent = false; model.requestAI() }.keyboardShortcut(.defaultAction)
                }
            }.padding(26).frame(width: 500)
        }
        .onChange(of: model.report?.text) { _, _ in selectedFinding = nil }
    }

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("Understand the writing\nyou already have.")
                    .font(.system(size: 38, weight: .medium, design: .serif)).lineSpacing(3)
                Text("Select a passage in any app that supports macOS Accessibility. Co-written looks for patterns in its voice, formality, clarity, and rhythm — and shows you the words behind each observation.")
                    .font(.system(size: 16)).foregroundStyle(.secondary).lineSpacing(5).frame(maxWidth: 630)
                HStack(alignment: .top, spacing: 28) {
                    feature("1", "Select your words", "Highlight a paragraph in your editor, browser, or email.")
                    feature("2", "Take a closer look", "Press ⇧⌘L to analyse the selected text.")
                    feature("3", "Choose what helps", "Explore patterns and suggestions. Your voice stays yours.")
                }
                if !model.message.isEmpty { Text(model.message).font(.callout).foregroundStyle(.secondary) }
                HStack {
                    Button("Set up selection access") { model.showPreferences() }.buttonStyle(.borderedProminent)
                    Button("Paste a passage") { paste = true }
                    Button("Try an example") {
                        model.analyze("We want our writing to feel clear and human. However, the implementation of the new process was delayed by the team. Perhaps we could simplify the explanation in order to help our readers understand what happens next. Thanks for taking the time to share your ideas; your feedback makes this work better.", source: "Example passage")
                    }
                }
                Label("Passages stay in memory. No history or analytics. AI uses your sharing settings when you request analysis.", systemImage: "lock")
                    .font(.caption).foregroundStyle(accent)
            }.padding(36).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func feature(_ number: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(number).font(.system(size: 23, design: .serif)).foregroundStyle(accent)
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary).lineSpacing(3)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func passage(_ report: WritingReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("THE PASSAGE").font(.system(size: 10, weight: .semibold)).tracking(1.8)
                Spacer()
                Image(systemName: "doc.text").foregroundStyle(.secondary)
            }
            Text(model.source).font(.caption).foregroundStyle(.secondary)
            ScrollView {
                Text(highlighted(report)).font(.system(size: 16, design: .serif)).lineSpacing(6)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Text("\(report.wordCount) words")
                Spacer()
                Text(report.readingSeconds < 60 ? "\(report.readingSeconds)s read" : "\(Int(ceil(Double(report.readingSeconds) / 60))) min read")
            }.font(.caption).foregroundStyle(.secondary)
            Text(report.language).font(.caption).foregroundStyle(.secondary)
        }.padding(22).background(.white.opacity(0.4))
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
            HStack(alignment: .top, spacing: 15) {
                metric("Formality", value: report.formality.map { "\($0)" } ?? "—", label: report.formalityLabel)
                metric("Reading ease", value: report.readability.map { String(format: "%.0f", $0) } ?? "—", label: report.readabilityLabel)
            }
            Text(report.formalityEvidence).font(.caption).foregroundStyle(.secondary).lineSpacing(3)
            VStack(alignment: .leading, spacing: 13) {
                row("Grammatical voice", report.grammaticalVoice)
                row("Point of view", report.pointOfView)
                row("Tone cues", report.tone)
            }.padding(16).background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Sentence rhythm").font(.headline)
                    Spacer()
                    Text(String(format: "%.1f words / sentence", report.averageSentenceLength)).font(.caption).foregroundStyle(.secondary)
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
                Text("Each bar is a sentence. Amber marks more than 30 words. The first 45 sentences are shown.").font(.caption).foregroundStyle(.secondary)
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
                    Text("Repetition can create cohesion. Check whether each use earns its place.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("Reading ease uses an approximate English Flesch formula (0–100); syllables are estimated. Unique-word percentage depends strongly on sample length.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func metric(_ title: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.callout).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 38, weight: .medium, design: .serif)).foregroundStyle(accent)
                if value != "—" { Text("/100").font(.caption).foregroundStyle(.secondary) }
            }
            Text(label).font(.callout)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
    }
    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout).fontWeight(.medium)
        }
    }
    private func findings(_ report: WritingReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cues to consider, not errors to fix. Click a card to highlight its evidence.").font(.callout).foregroundStyle(.secondary)
            if report.findings.isEmpty {
                Label(report.supportsStyleAnalysis ? "No cues matched these local rules." : "English style rules are unavailable for this passage.", systemImage: "text.magnifyingglass")
                    .padding(.vertical, 24)
            }
            ForEach(report.findings.prefix(100)) { finding in
                Button { selectedFinding = finding } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(finding.kind.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(accent)
                        Text("“\(finding.excerpt)”").font(.system(size: 17, design: .serif)).lineLimit(5)
                        Text(finding.explanation).font(.caption).foregroundStyle(.secondary).lineSpacing(3)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                        .background(selectedFinding?.id == finding.id ? accent.opacity(0.10) : .white.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
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
                        Text(suggestion.advice).font(.callout).foregroundStyle(.secondary)
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                }
                Text(ai.caveat).font(.caption).foregroundStyle(.secondary)
            } else {
                Image(systemName: "sparkles").font(.system(size: 30)).foregroundStyle(accent)
                Text("Another perspective, when you want it.").font(.system(size: 24, design: .serif))
                Text(model.aiProvider == .direct ? "AI can consider context, strengths, and practical edits. Add your own OpenAI API key to connect directly from this Mac. AI reviews passages only when you request analysis, using your sharing settings." : "AI can consider context, strengths, and practical edits. After you enable sharing, requested passages go to your configured Co-written service and OpenAI.").font(.callout).foregroundStyle(.secondary).lineSpacing(4)
            }
            if model.isRequestingAI { ProgressView("Considering your passage…") }
            if !model.aiError.isEmpty { Text(model.aiError).foregroundStyle(.red).font(.callout) }
            if (model.aiProvider == .direct && !model.hasDirectKey) || (model.aiProvider == .sharedService && model.server.isEmpty) {
                Button("Configure AI access…") { model.showPreferences() }
            } else {
                Button("Ask AI about this passage…") { aiConsent = true }.disabled(model.isRequestingAI)
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var saved = ""
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
                    Text(model.shortcutAvailable ? "⇧⌘L analyses the current selection. Selecting text or opening the dropdown does not start analysis." : "⇧⌘L is already in use. Free that shortcut, or explicitly supply text using Paste or macOS Services.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("No keystrokes are recorded. Secure fields are skipped. Some apps do not expose selected text; use the Services menu or paste a passage.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Excluded apps") {
                    Text("One app bundle identifier per line. Password managers are excluded by default.").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $model.exclusions).font(.system(.caption, design: .monospaced)).frame(height: 75)
                }
                Section("AI analysis") {
                    Toggle("Include AI when I request an analysis", isOn: $model.aiAutomatic)
                    Text("With a saved credential and sharing permission, AI runs after you press ⇧⌘L or explicitly analyse pasted text. Selecting text, opening the dropdown, or changing settings never sends a passage. Direct OpenAI use is billed to your account. Turn this off for local analysis.").font(.caption).foregroundStyle(.secondary)
                    Picker("Connect using", selection: $model.aiProvider) {
                        Text("Your OpenAI account").tag(AIProvider.direct)
                        Text("A shared Co-written service").tag(AIProvider.sharedService)
                    }
                    if model.aiProvider == .direct {
                        SecureField("Your OpenAI API key", text: $token)
                        Text(model.hasDirectKey ? "An API key is saved in this Mac’s Keychain." : "Add your own key to connect directly to OpenAI. No separate server is needed.").font(.caption).foregroundStyle(.secondary)
                        Text("Your key stays in Keychain on this Mac and is sent only to api.openai.com. Saving your key below allows requested passages to be shared with OpenAI when AI is enabled. OpenAI bills usage to your account and its retention rules apply. No key is included in the downloaded app.").font(.caption).foregroundStyle(.secondary)
                        Link("Manage OpenAI API keys", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    } else {
                        TextField("Server URL", text: $model.server, prompt: Text("https://analysis.example.com"))
                        SecureField("Personal access token", text: $token)
                        Text("Use a personal Co-written token from the service owner, rather than an OpenAI key. The token is stored in Keychain and bound to this HTTPS server.").font(.caption).foregroundStyle(.secondary)
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
                        Text("AI sharing has not been allowed for this saved credential. Allowing it permits future requested passages to be sent to this destination and may incur charges.").font(.caption).foregroundStyle(.secondary)
                        Button("Allow AI at this destination") { model.credentialsChanged(authorize: true) }
                    }
                    if model.aiSharingAllowed { Text("AI sharing is allowed for requested passages at this destination. Turn off AI above to keep analysis local.").font(.caption).foregroundStyle(.secondary) }
                    if !saved.isEmpty { Text(saved).font(.caption).foregroundStyle(.secondary) }
                }
                Section("General") {
                    Toggle("Start Co-written at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")
                    if let updater = model.updater { Button("Check for Updates…") { updater.checkForUpdates(nil) } }
                    Text("Local analysis keeps only the current passage in memory. Clear removes it. No writing history or usage telemetry is collected.").font(.caption).foregroundStyle(.secondary)
                    if !model.message.isEmpty { Text(model.message).font(.caption).foregroundStyle(.secondary) }
                }
            }.formStyle(.grouped)
        }.frame(height: 760).background(Color(nsColor: .windowBackgroundColor))
            .onChange(of: model.aiProvider) { _, _ in token = ""; saved = "" }
            .onDisappear { token = "" }
    }
}

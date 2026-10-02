# Co-written

A quiet macOS menu-bar companion that helps you understand your writing. Select a passage, press **⇧⌘L**, and explore its voice, formality, readability, and rhythm. The app is self-sufficient: local analysis runs on your Mac, and AI connects directly to OpenAI with your own key. Click its menu-bar icon for a compact dropdown; expand it when you want more detail.

**[Download the latest DMG](https://github.com/acousland/co-written/releases/latest)** · macOS 14+ · Apple Silicon and Intel

![Co-written analysing a passage](docs/dropdown.png)

## What it looks for

| Lens | What you see |
| --- | --- |
| Grammatical voice | Possible passive constructions, with their exact wording |
| Point of view | First, second, third, or mixed personal pronouns |
| Register | An explainable formality estimate and its supporting cues |
| Reading ease | Approximate English Flesch score and average sentence length |
| Tone | Courteous, tentative, directive, questioning, or emphatic cues |
| Rhythm | A bar for each sentence, highlighting longer sentences |
| Precision | Hedging, intensifiers, wordy phrases, and abstract noun endings |
| Vocabulary | Frequently repeated content words and unique-word percentage |
| AI perspective | Contextual voice, strengths, and practical edits when you request analysis, with your own OpenAI key |
| AI-writing signs | Humanizer’s 26-pattern catalogue: quoted style cues, explanations, and plausible human alternatives |

These are cues to consider, not errors to fix. Formal writing is not inherently better, passive voice is often useful, and dialect and genre matter. Local style rules support English; other languages receive basic statistics. Scores are heuristic estimates, with no claims of validated accuracy. Selections are limited to the first 20,000 characters.

## Use it

1. Drag the app from the DMG into Applications and open it.
2. Click the quotation-mark menu-bar icon to open the dropdown, then its gear to open Settings. Grant Accessibility for selection reading.
3. Select text in another app and press **⇧⌘L** to analyse it and open the dropdown. Selecting text alone never starts analysis. Clicking the menu-bar icon opens your last results without reading any selection. Add your own OpenAI key in Settings to include AI by default when you request analysis.
4. Explore **Overview**, **AI signs**, and **Writing cues**. The expand button opens the larger analysis window, where cue cards highlight evidence. **Copy report** includes local and AI findings.

You can exclude apps by bundle identifier and start the app at login. Secure fields and default password-manager exclusions are skipped. Some apps do not expose selected text; use **Services → Analyse with Co-written** or **Paste text** in the panel. No simulated Copy operation or keystroke recording is used.

## Humanizer review

The **AI signs** tab uses [Humanizer 3.1.0](https://github.com/blader/humanizer/tree/225a6f39ac85f76ee48dbad772ea4abe4ed6c9d8). Its 26 editorial patterns cover rhetorical staging, formulaic rhythm, inflated claims, formatting, chat residue, and audience mismatch. The full catalogue is included in the AI review prompt. Offline checks implement a conservative subset with exact excerpts; quotations are skipped, and weak cues need supporting patterns. Context-sensitive patterns need an AI review and appropriate context. Humanizer is a writing-review skill, not a statistical detector; Co-written adapts its catalogue without running its rewrite workflow.

These patterns can occur in human and AI prose. No probability or authorship verdict is provided, and an absence of matches does not prove human authorship. Short samples, editing, translation, genre and deliberate style limit conclusions. Each AI signal must quote text from the passage and offer a plausible human explanation. See [pinned source and MIT licence](ThirdParty/humanizer/PROVENANCE.md). Humanizer’s licence is included in the app.

## Privacy and AI

Local analysis keeps the current requested passage in memory, collects no telemetry, and saves no writing history. Clear, the next requested passage, or quitting discards it. The app does not watch selections or analyse highlighted text in the background, including for users upgrading with old automatic-analysis preferences. **⇧⌘L** is the only way to capture another app's selection. Paste and macOS Services explicitly supply text for analysis. The menu-bar icon only opens the dropdown. The app also makes network requests for update checks. **AI is enabled by default** for requested analyses once you save a credential and allow sharing with that destination. Turn off AI to keep analysis local.

The app connects **directly to OpenAI** for AI analysis. Add your own API key in Settings; it is kept in macOS Keychain on this Mac, sent only to `api.openai.com`, and never written to app preferences, writing reports, source, or release artifacts. Saving credentials, enabling AI, or changing providers never sends an existing passage: invoke the shortcut or explicitly analyse supplied text afterwards. Requests are cancelled when you request a new passage, Clear, disable AI, or change connection settings. Failed requests require an explicit retry; opening old results reuses the completed review. Cancellation cannot recall text already sent to the provider. One-off AI requests in the detailed view confirm sharing. API use is billed to the key's OpenAI account. No separate server, account signup, or Docker installation is needed. The app uses the pinned `gpt-4.1-mini-2025-04-14` model with strict Structured Outputs, bounded concise fields, a 4,096-token output limit and a 75-second timeout. Individual findings with unverified quotations are omitted with a visible note while the useful review remains available. Cutoff, refusal, filtering, malformed replies and incomplete analyses have distinct errors. Local analysis remains available after AI failure.

**No shared OpenAI key is bundled.** A key embedded in any downloadable app can be extracted, including from a signed or encrypted bundle. Your key remains private on your own Mac; other people who download Co-written supply their own keys. This matches [OpenAI's key-security guidance](https://developers.openai.com/api/reference/overview).

For an owner who wants to pay for other users' AI access, an optional [protected backend](server/README.md) is included in the same repository. This is an alternative connection mode, not a dependency of the app. It issues individual revocable tokens and enforces persistent per-user and global quotas; the provider key stays on that server. It is not deployed or preconfigured in this release.

Both AI modes use OpenAI Responses with `store: false`; this does **not** remove all provider retention. Consult [OpenAI's data controls](https://developers.openai.com/api/docs/guides/your-data). Local analysis needs no API key or network connection. Live AI requests require a valid user-supplied key and have not been exercised with a real key. Automated tests use a mock provider; UI snapshots use labelled example passages and fixture AI results.

## Build and release

```sh
swift test
PYTHONPATH=server python3 -m unittest discover -s server/tests
scripts/build-app.sh
```

Open `dist/Co-written.app`. The universal build uses Swift Package Manager, AppKit, SwiftUI, Apple's NaturalLanguage framework, and pinned Sparkle 2.10.0. Open `Package.swift` in Xcode if preferred. A developer build can be ad hoc signed; a public release requires the owner's Developer ID certificate, notarisation credentials, and Sparkle private signing key in Keychain.

```sh
# Local UI snapshots and packaging checks
dist/Co-written.app/Contents/MacOS/CoWrittenMac --ui-check dist/ui
# Build, notarise, package and prepare the signed feed without publishing
scripts/prepare-release.sh
# Publish the committed and pushed VERSION, then update appcast.xml in this same repo
scripts/publish-release.sh
```

For an explicit developer check, run `dist/Co-written.app/Contents/MacOS/CoWrittenMac --ai-check`. It sends one built-in synthetic English sample using this app's saved Keychain credential and prints only safe status/count metadata. It never prints credentials, selected writing or reply content, and exits with status 2 if no credential is available. This is opt-in and is not run by startup or release validation.

See [release operations](docs/Releasing.md). Source, backend, appcast, and binary releases share this single public repository. No signing or provider secrets belong here.

## Contributing

Changes to linguistic rules should include contrasting examples and retain uncertainty language. Keep text processing bounded, maintain a complete offline fallback, and make sharing of requested passages explicit in setup and settings. Security reports: use GitHub's private vulnerability reporting if enabled, rather than posting keys or user writing in an issue.

MIT licence. Co-written and Sparkle licence notices are included in the app's Resources.

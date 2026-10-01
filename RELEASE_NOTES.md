# Co-written 0.1.0

- A native macOS menu-bar companion for understanding selected text.
- Local estimates for grammatical voice, perspective, formality, tone cues, readability, sentence rhythm, and repetition.
- Evidence-based cues for passive constructions, hedging, intensifiers, abstract nouns, wordiness, and long sentences.
- Automatic selection analysis, Shift–Command–L, a macOS Service, and a paste fallback.
- Optional AI perspective directly from OpenAI using your own key in macOS Keychain; no shared provider key in the download.
- Universal Apple Silicon / Intel build for macOS 14 or later, Developer ID signing, Apple notarisation, a DMG, and signed Sparkle updates.

English style analysis uses explainable heuristics. It can miss patterns or flag legitimate constructions. This initial release has no previous version to patch; delta downloads are generated for subsequent releases when Sparkle can produce a smaller update.

The app is self-sufficient. Optional AI requires your own OpenAI API key in Settings; no separate server is needed. A protected backend is also provided as an optional alternative for owner-funded access. No live OpenAI call was made during initial validation.

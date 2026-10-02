# Co-written 0.2.0

- A compact dropdown from the menu-bar icon by default, also opened by Shift–Command–L and the macOS Service. An expand button opens the detailed view; right-click the icon for app commands.
- AI review on by default once you save your own OpenAI API key and allow sharing. Keys stay in this Mac’s Keychain. Existing saved credentials get a one-time automatic-sharing choice.
- Automatic AI waits for settled text, suppresses repeated requests, spaces requests by at least 15 seconds, and cancels stale work. Pause and automatic-AI settings give you control; offline analysis remains available.
- A new AI signs tab based on Humanizer 3.1.0’s 26-pattern catalogue, with local cues and contextual AI review. Each finding quotes its evidence and explains possible human uses. Style cues cannot establish authorship, and no AI probability is shown.
- Copied reports include local and AI advice and the Humanizer review.
- Developer ID signed, Apple notarised universal DMG for macOS 14+, with signed Sparkle updates and a delta from 0.1.0 when smaller than a full download.

Automatic AI sends selected and pasted text to your configured provider and may incur API charges. Disable it or pause analysis to keep new selections local. Each downloader supplies their own key; no shared key is bundled. Provider retention rules apply. Live OpenAI calls have not been tested with a real key; automated validation uses mocks.

Humanizer is MIT licensed by Siqi Chen; its pinned catalogue and licence are included. This is editorial review rather than an authorship classifier.

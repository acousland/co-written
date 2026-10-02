# Co-written 0.2.1

- Selection analysis runs only when you press **⇧⌘L**. The background watcher is removed, including for upgrades with old automatic-analysis settings. Clicking the menu-bar icon only opens the dropdown.
- AI stays on by default for requested analyses when your own key and sharing permission are configured. Saving credentials or changing settings never sends an existing passage. Paste and macOS Services remain explicit ways to supply text.
- More reliable AI reviews for short passages: concise bounded output, a larger reply budget, and individual unverified quotations omitted with a visible note instead of rejecting the whole review.
- Clear error messages for unfinished, truncated, filtered, refused and malformed AI replies; explicit retries work. Local analysis remains available.
- Signed and notarised universal macOS app, packaged in a DMG with signed Sparkle delta updates.

Each downloader supplies their own OpenAI key, stored in their Mac’s Keychain. Requested AI reviews send the passage to the configured provider and may incur API charges. No shared key is bundled. Provider retention rules apply. Automated validation uses mocked replies; a real OpenAI call could not be tested without a saved key.

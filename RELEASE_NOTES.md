# Co-written 0.3.3

- Every settled analysis includes an AI check when AI, a saved credential and sharing are enabled. The 15-second mouse delay is removed. Deselecting after a request starts lets that review finish; changing the passage or closing the full window still cancels it.
- Enabling AI with already-authorised sharing checks the current passage too. AI progress, completion and failures are explicit. The full overview includes the AI check, and an authorised refresh or retry needs no repeated sharing confirmation.
- Restore the warm off-white paper, dark ink and muted green presentation in both light and dark mode. Native Liquid Glass window and toolbar controls remain.
- Word selections use its native selected text range rather than a focused page fragment, including selections across pages. Enable Word selections in Settings or allow the one-time macOS Automation prompt after pressing ⇧⌘L in Word. Access failure is shown instead of silently using partial text.
- Text selected in Word search and formatting fields uses that field’s selection, keeping it separate from any remembered document highlight.
- Signed, notarised universal macOS app, DMG and verified Sparkle delta updates.

Selections remain limited to 20,000 characters, with a notice in the report for longer passages. Word capture has automated native-query and multi-page response checks; live Word capture has not been manually exercised. AI requests use each user's own Keychain credential.

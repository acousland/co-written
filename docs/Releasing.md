# Release operations

The initial repo uses `acousland/co-written` for both source and releases. The feed is `appcast.xml` on `main`. Distributed apps trust the public Ed25519 key in `Assets/update-public-key` and the Developer ID team in `Assets/signing-team`. Neither is a secret. Keep the corresponding private signing keys in Keychain; preserve them across releases.

## Owner setup

- Developer ID Application certificate and private key in login Keychain, team `5NF98M544G`.
- Existing `renoir-notary` Keychain profile, or override `COWRITTEN_NOTARY_PROFILE`. Notarisation profiles are independent of app names. To configure another Mac, use `xcrun notarytool store-credentials` interactively; never commit Apple credentials.
- Sparkle keychain account `co-written`. On the initial machine this was generated specifically for this app. On another release Mac import the same key via Sparkle's `generate_keys -f` using a securely transferred key file. Delete that transfer file afterwards. Do not generate a replacement key for installed users without a deliberate migration.
- GitHub CLI authentication with write access to this repository.

## Release steps

1. Update `VERSION` and `RELEASE_NOTES.md`. Build numbers default to Unix time, which must increase. `COWRITTEN_BUILD_NUMBER` can override it; keep it higher than every previous release. Use the same signing identity and update key.
2. Run tests, the app's `--startup-check` mode, and `--ui-check`, inspect the compact dropdown and light/dark snapshots, and manually exercise selection capture in representative apps when UI access is available. Verify shortcut-only menu-bar operation and mouse selections while the full window is open, including stopping on close/hide/minimise. The selection reader requires a user-granted Accessibility permission; this must not be enabled silently.
3. Commit and push `main`, then run `scripts/publish-release.sh`. For preparation without publishing, use `scripts/prepare-release.sh`.

The pipeline builds a universal app for macOS 14+, signs every Sparkle helper from the inside out with hardened runtime and timestamps, verifies the signature, notarises/staples the app, creates the DMG, then signs/notarises/staples the DMG. Apple assessments must pass before publication. The final DMG gets a SHA-256 checksum.

`prepare-appcast.sh` restores the prior three public DMGs on a fresh checkout, checks the Sparkle public key against Keychain, and runs Sparkle's `generate_appcast`. The tool signs the full update and creates/signs smaller deltas when possible. Initial releases have no prior version and cannot contain a meaningful delta. Every generated current-release delta is applied to its actual previous DMG; the patched app’s file contents, permissions, and code signature must match the new app before publication. Full downloads remain the fallback when a patch is unavailable or fails. See [Sparkle delta documentation](https://sparkle-project.org/documentation/delta-updates/).

The release publishes DMG/checksum/delta assets first, confirms that the newest feed's downloads are reachable, then commits/pushes the feed. If publication fails after the tag or release was created, finish uploading missing assets and publish the prepared `dist/appcast.xml`; do not rebuild different binaries under an existing version. Keep original release archives available so future deltas match installed bundles. The prepare script retains an ignored local cache under `dist/updates`.

Manual CI checks Swift and backend tests and packages an ad hoc universal app. It does not distribute a signed release and has no access to local Keychain credentials. Signing and publication run on the owner's Mac, as with Renoir.

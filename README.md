# Lastys (iOS)

SwiftUI implementation of the **Lastys** iPhone prototype.

A first launch runs **onboarding**: a skippable intro, the language (Khmer by default), the 18+ and Terms confirmation, creating the Lastys ID with its Recovery code, then a nickname, an optional photo and a birth date that stays on the phone. Relaunching skips it. The phone's key is created in the Secure Enclave; Debug builds on a simulator fall back to a software key.

Then the **Home** screen:

- Header with the Lastys wordmark, today's date and the profile button
- "Verified Single" status card with the share button
- "Show my QR" opens My Lastys QR: a token signed by the phone's key with the Lastys ID and the current minute (format in `LastysCore/Sources/LastysCore/LastysQR.swift`), a new code every minute with a countdown, made offline, and what scanners will see
- "Scan a QR" opens the camera scanner (with torch) and shows the Scan result live from Trustee: photo or initial, nickname, Verified Single or Taken, ID age (with a warning for a very new ID), Phone transfers and Relationship history (or "Hidden by owner"). Without internet a Scan fails rather than show anything stale. Debug builds add a picker of sample people (Dara, Vanna, Sokha).
- Dating safety tips
- Upcoming moments and the personal timeline
- Bottom navigation (Home, Calendar, Me). Calendar and Me are placeholders for now.

Font: [Plus Jakarta Sans](https://fonts.google.com/specimen/Plus+Jakarta+Sans) (SIL Open Font License, see `Lastys/Resources/OFL.txt`).

## Layout

- `Lastys/`: the SwiftUI app. Screens render from `AppModel` and decide nothing themselves.
- `LastysCore/`: a Swift package holding the domain.
  - `LastysCore`: `AppModel` (all domain-visible state and the person's intents, including onboarding), `PhoneStore` (what the phone keeps between launches), `TrusteeClient` (the app's only boundary to Trustee) and `FakeTrustee` (Phase A's on-phone Trustee). The "Demo: …" hooks are compiled only in Debug.
  - `LastysScenarios`: the Swift runner for the shared scenarios. Only the tests link it.
- `scenarios/`: shared domain scenarios as data. See `scenarios/README.md`.
- `Lastys/Localizable.xcstrings`: String Catalog. Khmer is the development language, with English available. Khmer values are placeholders until the translations arrive.

## Test

```sh
swift test --package-path LastysCore
```

This runs on macOS, Linux and Windows. On Windows, run it from a Visual Studio developer shell with the C++ build tools; recent toolchains also need `--build-system native`.

## Build locally (macOS)

```sh
brew install xcodegen
xcodegen generate
open Lastys.xcodeproj
```

Requires Xcode 16 or later. Deployment target is iOS 17.

## Get the IPA

Every push to `main` runs the **Build IPA** GitHub Actions workflow on a macOS runner. It runs the unit tests (a failure stops the build), then builds an **unsigned** `Lastys.ipa` and attaches it to a GitHub Release (`build-<run number>`), plus a workflow artifact.

The same build is also defined for [Codemagic](https://codemagic.io) in `codemagic.yaml` (workflow **Lastys unsigned IPA**). Connect the repo in Codemagic, start the workflow, and download `Lastys.ipa` from the build's Artifacts.

An unsigned IPA must be signed before it can be installed on an iPhone, for example with Sideloadly or AltStore (free Apple ID), or by re-signing with your Apple Developer certificate.

# Lastys (iOS)

SwiftUI implementation of the **Lastys** iPhone prototype. This first build contains the **Home** screen:

- Header with the Lastys wordmark, today's date and the profile button
- "Verified Single" status card with the share button
- "Show my QR" and "Scan a QR" quick actions
- Dating safety tips
- Upcoming moments and the personal timeline
- Bottom navigation (Home, Calendar, Me). Calendar and Me are placeholders for now.

Font: [Plus Jakarta Sans](https://fonts.google.com/specimen/Plus+Jakarta+Sans) (SIL Open Font License, see `Lastys/Resources/OFL.txt`).

## Build locally (macOS)

```sh
brew install xcodegen
xcodegen generate
open Lastys.xcodeproj
```

Requires Xcode 15 or later. Deployment target is iOS 16.

## Get the IPA

Every push to `main` runs the **Build IPA** GitHub Actions workflow on a macOS runner. It builds an **unsigned** `Lastys.ipa` and attaches it to a GitHub Release (`build-<run number>`), plus a workflow artifact.

An unsigned IPA must be signed before it can be installed on an iPhone, for example with Sideloadly or AltStore (free Apple ID), or by re-signing with your Apple Developer certificate.

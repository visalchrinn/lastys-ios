# Lastys (iOS)

SwiftUI implementation of the **Lastys** iPhone prototype.

A first launch runs **onboarding** (or, from the intro, "Move my ID from another phone" or "I lost my phone": a Recovery with the Recovery code that completes after 7 days unless the old phone cancels it): a skippable intro, the language (Khmer by default), the 18+ and Terms confirmation, creating the Lastys ID with its Recovery code, then a nickname, an optional photo and a birth date that stays on the phone. Relaunching skips it. The phone's key is created in the Secure Enclave; Debug builds on a simulator fall back to a software key.

Then the **Home** screen:

- Header with the Lastys wordmark, today's date and the profile button
- Status card: Verified Single with the share button; Taken with the Partner, "Day N together since …" and where an ending stands; or "Relationship ended" with the Cooling-off period. Tapping it when Taken opens the Relationship: send or withdraw an End request, agree or decline one, ask for a Team review after a decline or 7 days without an answer, or report a safety concern. Debug builds simulate the Partner answering, no answer for 7 days, the team deciding, and skipping the Cooling-off period.
- Quick hide (the eye in the header, or the switch on the Relationship screen), offered to everyone so its presence reveals nothing. Turn it off to reach the Relationship screen again. It hides the status card and Shared Moments on this phone's screen only. It never reaches Trustee, so a Scan still shows Taken.
- "Show my QR" opens My Lastys QR: a token signed by the phone's key with the Lastys ID and the current minute (format in `LastysCore/Sources/LastysCore/LastysQR.swift`), a new code every minute with a countdown, made offline, and what scanners will see
- "Scan a QR" opens the camera scanner (with torch) and shows the Scan result live from Trustee: photo or initial, nickname, Verified Single or Taken, ID age (with a warning for a very new ID), Phone transfers and Relationship history (or "Hidden by owner"). Without internet a Scan fails rather than show anything stale. From a Scan result a single person can send a Relationship request (disabled with its reason when either side is Taken, or the scanner is in a Cooling-off period) and sees "Waiting for …" until the receiver answers. Debug builds add a picker of sample people (Dara, Vanna, Sokha). Debug builds also let the sample person accept or decline.
- Dating safety tips
- Upcoming moments and the personal timeline. "+ Add" creates a Moment (First meet, First date, Anniversary, Birthday or Custom, a title, a date, an optional photo or video); tapping one edits or deletes it. Each comes back every year, on its date or on its Khmer lunar date (sample mapping), and is reminded at 09:00 seven days before, the day before and on the day. Personal Moments stay on the phone and never go to Trustee. While Taken, the owner can share a Moment (title, type and date; never its photo or video) and the Partner sees it, read-only. When the Relationship ends, each former Partner keeps, exports (.ics) or deletes their own copy of everything shared in it, theirs and the other's, without touching the other's copy. Quick hide also keeps Shared Moments' reminders off the lock screen.
- Bottom navigation (Home, Calendar, Me).
- Me: edit the nickname, photo and birth date (which stays on the phone); see the Personal ID, when it was created and the Phone transfer count; switch the Share level between Status only (the default) and Status + history; Who scanned me, by time only; the Recovery code shown only after Face ID or the passcode, and a new code that makes the old one stop working; Help and support on Telegram (its link is still to be set in `SupportLinks.telegram`); Move to a new phone (a transfer QR valid for 5 minutes; the Lastys ID, Relationship and Moments move, sealed so Trustee can't read them, onto the new phone's own key; one move every 30 days); a pending Recovery with a Cancel button; and Delete my data, behind Face ID or the passcode, which removes the Lastys ID from Trustee and wipes the phone back to first launch. It is refused while in a Relationship at any stage (ADR 0002).
- Calendar: a month grid marking today and the selected day, Moments, Cambodia's official public holidays (2026 and 2027, from Sub-Decrees No. 167 and No. 198) and Sil days. Tapping a day shows what's on it and its Khmer lunar date. Below it, the upcoming public holidays, and the Lucky Day Planner: suggested dates for an engagement, a wedding or a house blessing from both birth dates, which stay on the phone. Its results are sample rules, always shown with a disclaimer. Lunar dates and Sil days come from one provider (`SampleKhmerCalendar`) and are labelled as samples until the cultural advisor's rules arrive.

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

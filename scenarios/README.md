# Shared scenarios

Domain scenarios are written once, as data, and run against both Trustees:

- the fake Trustee on the phone, by the Swift runner (`LastysCore/Sources/LastysScenarios`, run by `swift test --package-path LastysCore`)
- the real Trustee API, by the .NET runner (Phase B)

If both runners pass the same files, the fake can't drift from the server's rules.

## Format

One scenario per `.json` file:

```json
{
  "name": "A new Lastys ID has no active Relationship",
  "steps": [
    { "phone": "alice", "do": "create-lastys-id" },
    { "phone": "alice", "do": "get-relationship-status", "expect": { "status": "none" } }
  ]
}
```

Each step is one request to Trustee from one phone:

| Field    | Meaning |
|----------|---------|
| `phone`  | Which phone sends the request. A phone holds at most one Lastys ID, and its key signs every request (ADR 0003). |
| `do`     | The action, in kebab-case. |
| `with`   | Optional string arguments. |
| `expect` | Optional fields the response must contain with exactly these values. Other response fields are ignored. |

A rejected request responds with `{ "error": "<code>" }`, so a scenario can expect a rule to refuse something: `"expect": { "error": "no-lastys-id" }`.

A runner stops at the first step that fails and reports its 1-based number. An unknown action fails the scenario.

## The runner's world

- **Phones.** Each phone named in a scenario gets its own key the first time it appears. Trustee knows the phone by that key, and the phone signs what it shows.
- **Clock.** Every scenario starts at 2026-11-29 05:00:15 UTC, and Trustee runs on that clock. Only `wait` moves it. The .NET runner hosts Trustee in-process, so it gives Trustee a controllable `TimeProvider` (such as `FakeTimeProvider`) set to that start, and `wait` advances it.
- **What the runner remembers.** Trustee's responses also carry opaque IDs that scenarios never mention: a `scan` returns a Scan ID, and `send-relationship-request` returns a request ID. The runner keeps each phone's latest Scan ID (and which phone it scanned), and each request ID by sender and receiver phone. That is how `scanOf`, `to` and `from` resolve. With no Scan to name, the runner sends an ID Trustee has never issued.
- **Not yet expressible.** Relationship history under *Status + history* needs the Share level (#13); only the Swift demo tests cover it so far. The Cooling-off blocks need an ending (#7), and nothing tests them yet.

## Actions

| Action                    | `with`     | Response |
|---------------------------|------------|----------|
| `create-lastys-id`        |            | `personalID`, `recoveryCode`; error `phone-already-has-lastys-id` |
| `update-profile`          | `nickname` | nothing; error `no-lastys-id` |
| `get-relationship-status` |            | `status`: `none` or `active`, and `partner` (the Partner's nickname) when active |
| `scan`                    | see below  | `status` (`single` or `taken`), `nickname`, `idAgeDays`, `phoneTransfers`, `history` (`hidden`, or the number of past Relationships), `requestBlocked` (`none`, `you-are-taken`, `you-are-cooling-off`, `they-are-taken`, `that-is-you`); errors `no-lastys-id`, `not-a-lastys-qr`, `expired-qr`, `forged-qr` |
| `wait`                    | `minutes`, `days` | nothing. Moves the clock; it is not a request to Trustee. |
| `send-relationship-request` | optional `scanOf` | `status` (`pending`), `to` (the receiver's nickname). Uses the sending phone's latest `scan`, or another phone's with `scanOf` (which Trustee must refuse). Errors `scan-required`, `scan-too-old`, `you-are-taken`, `you-are-cooling-off`, `they-are-taken`, `that-is-you` |
| `get-relationship-request-status` | `to` (receiver phone) | `status`: `pending`, `accepted`, `declined` or `expired`, and `to` |
| `accept-relationship-request` | `from` (sender phone) | nothing. Errors `you-are-taken`, `you-are-cooling-off`, `they-are-taken`, `they-are-cooling-off`, `request-not-pending`, `request-not-found` |
| `decline-relationship-request` | `from` (sender phone) | nothing. Errors `request-not-pending`, `request-not-found` |

`scan` reads one of these:

- `payload`: any text, as the camera read it.
- `qrOf`: the Lastys QR shown by that phone. It can be qualified with:
  - `madeMinutesAgo` (default `0`): how long ago the code was made.
  - `signedBy` (default: the showing phone itself): another phone's key, which forges it.

A Lastys QR is accepted from 2 minutes before the current minute up to 1 minute after it. Its text form is documented in `LastysCore/Sources/LastysCore/LastysQR.swift`.

## Error codes

| Code           | Meaning |
|----------------|---------|
| `no-lastys-id` | The phone has no Lastys ID yet. |
| `phone-already-has-lastys-id` | The phone already holds a Lastys ID (ADR 0001). |
| `not-a-lastys-qr` | The scanned text isn't a Lastys QR in its exact text form. |
| `expired-qr` | The Lastys QR's minute is outside the accepted window. |
| `forged-qr` | The Lastys QR wasn't signed by the key of the phone holding that Lastys ID, or names no Lastys ID. |
| `scan-required` | A Relationship request must name a Scan this phone made. |
| `scan-too-old` | The Scan was more than 10 minutes ago. |
| `you-are-taken` | The acting Lastys ID already has an active Relationship. |
| `you-are-cooling-off` | The acting Lastys ID is in a Cooling-off period. |
| `they-are-taken` | The other Lastys ID already has an active Relationship. |
| `they-are-cooling-off` | The other Lastys ID is in a Cooling-off period. |
| `that-is-you` | Both sides are the same Lastys ID. |
| `request-not-found` | No such Relationship request for this phone. |
| `request-not-pending` | The Relationship request was already answered or has expired. |

When a Relationship starts, every other pending request to or from either Partner becomes `expired`. Accepting checks both Lastys IDs before the request's own status, so a Lastys ID that became Taken gets `you-are-taken`.

Name scenarios in glossary language and add actions here as the slices introduce them.

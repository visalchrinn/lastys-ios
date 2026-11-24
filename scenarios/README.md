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
- **Not yet expressible.** A Scan showing Taken, or Relationship history under *Status + history*, needs actions that arrive with later slices (Relationship request in #6, Share level in #13). Until then those cases are covered only by the Swift demo tests.

## Actions

| Action                    | `with`     | Response |
|---------------------------|------------|----------|
| `create-lastys-id`        |            | `personalID`, `recoveryCode`; error `phone-already-has-lastys-id` |
| `update-profile`          | `nickname` | nothing; error `no-lastys-id` |
| `get-relationship-status` |            | `status`: `none` |
| `scan`                    | see below  | `status` (`single` or `taken`), `nickname`, `idAgeDays`, `phoneTransfers`, `history` (`hidden`, or the number of past Relationships); errors `no-lastys-id`, `not-a-lastys-qr`, `expired-qr`, `forged-qr` |
| `wait`                    | `minutes`, `days` | nothing. Moves the clock; it is not a request to Trustee. |

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

Name scenarios in glossary language and add actions here as the slices introduce them.

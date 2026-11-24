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

- **Phones.** Each phone named in a scenario gets its own key the first time it appears. Trustee knows the phone by that key, and the phone signs what it shows. The one exception is `team-decides`, which is the Lastys team rather than a phone: its `phone` field is ignored and gets no key.
- **Clock.** Every scenario starts at 2026-11-29 05:00:15 UTC, and Trustee runs on that clock. Only `wait` moves it. The .NET runner hosts Trustee in-process, so it gives Trustee a controllable `TimeProvider` (such as `FakeTimeProvider`) set to that start, and `wait` advances it.
- **What the runner remembers.** Trustee's responses also carry opaque IDs that scenarios never mention: a `scan` returns a Scan ID, and `send-relationship-request` returns a request ID. The runner keeps every transfer code each phone was given (which `complete-phone-transfer` names with `from` and `which`), the order phones made their Lastys IDs (so `personalIDOf` can name a moved Lastys ID by its first phone), each phone's Recovery codes (from `create-lastys-id` and `new-recovery-code`, which `start-recovery` names with `codeOf` and `which`), each phone's Personal ID from `create-lastys-id` (which `team-decides` names with `about`), each phone's latest Scan ID (and which phone it scanned), and each request ID by sender and receiver phone. That is how `scanOf`, `to` and `from` resolve. With no Scan to name, the runner sends an ID Trustee has never issued.

## Actions

| Action                    | `with`     | Response |
|---------------------------|------------|----------|
| `create-lastys-id`        |            | `personalID`, `recoveryCode`; errors `phone-already-has-lastys-id`, `phone-made-a-lastys-id-recently` |
| `update-profile`          | `nickname` | nothing; error `no-lastys-id` |
| `get-relationship-status` |            | `status`: `none`, `active` or `cooling-off`. When active: `partner` (nickname), `stage` (`together`, `ending` or `team-review`); while ending, `endRequestFrom` (`me` or `partner`) and `declined` (`true`/`false`); in Team review, `reviewReason` (`end-request` or `safety-concern`). When cooling off: `until` (UTC day, `yyyy-MM-dd`) |
| `scan`                    | see below  | `status` (`single` or `taken`), `nickname`, `idAgeDays`, `phoneTransfers`, `history` (`hidden`, or the number of past Relationships), `requestBlocked` (`none`, `you-are-taken`, `you-are-cooling-off`, `they-are-taken`, `that-is-you`); errors `no-lastys-id`, `not-a-lastys-qr`, `expired-qr`, `forged-qr` |
| `wait`                    | `minutes`, `days` | nothing. Moves the clock; it is not a request to Trustee. |
| `turn-on-quick-hide`, `turn-off-quick-hide` | | nothing. Phone-only, like `wait`: Quick hide never reaches Trustee, so a runner sends nothing. The steps record in the scenario that Scans have nothing to honour; the Swift model tests prove the phone never sends Quick hide anywhere. |
| `set-my-shared-moments` | `titles` (joined with `\|`) | nothing. Replaces what this Partner shares into the Relationship; each title stands for a whole Shared Moment, which the runner completes with a new ID, type Custom and the scenario's start date. Errors `no-lastys-id`, `no-relationship` |
| `get-partner-shared-moments` | | `count`, `titles` (sorted, joined with `\|`). Error `no-relationship` |
| `get-former-shared-moments` | | `count`, `titles`: this person's own copy of what their former Partner shared, after the Relationship ended. Error `no-lastys-id` |
| `discard-former-shared-moments` | | nothing. This person kept (on the phone) or deleted their copy; the former Partner's copy is untouched. Error `no-lastys-id` |
| `set-share-level` | `level` (`status-only` or `status-and-history`) | nothing. Trustee applies it to the next Scan. Error `no-lastys-id` |
| `get-my-lastys-id` | | `shareLevel`, `idAgeDays`, `phoneTransfers`, `recoveryPending` and `hasRecoveryCode` (`true`/`false`). Error `no-lastys-id` |
| `get-who-scanned-me` | | `count`. Trustee returns only times; nothing says who scanned. Error `no-lastys-id` |
| `new-recovery-code` | | nothing a scenario names; the runner remembers the code. The previous code stops working, and so does a Recovery already started with it. Error `no-lastys-id` |
| `start-recovery` | `codeOf` (a phone), `which` (`current` or `previous`) | `completesInDays` (`7`). Sent from a phone that holds no Lastys ID. Errors `wrong-recovery-code`, `phone-already-has-lastys-id` |
| `delete-my-data` | | nothing. Removes the Lastys ID and everything about it. Errors `no-lastys-id`, `relationship-not-over` |
| `start-phone-transfer` | | `expiresInMinutes` (`5`). Only the newest code works. The runner remembers the code and sends an opaque sealed bundle. Errors `no-lastys-id`, `transfer-too-soon` |
| `complete-phone-transfer` | `from` (the old phone), optional `which` (`current`, the default, or `previous` code) | `personalIDOf` (the scenario phone that first made this Lastys ID). Moves it to the acting phone's key. Errors `phone-already-has-lastys-id`, `transfer-code-expired`, `transfer-code-invalid` |
| `get-recovery-status` | | `status`: `none`, `waiting`, `ready` or `cancelled` |
| `complete-recovery` | | `personalIDOf`. Moves the Lastys ID to the acting phone with a new Recovery code, which the runner records for the owner. Errors `no-recovery`, `recovery-not-ready` |
| `cancel-recovery` | | nothing. From the phone holding the Lastys ID. Also retires the Recovery code that started it; the owner makes a new one. Errors `no-lastys-id`, `no-recovery` |
| `get-notices` | | `notices`: sorted, joined with `\|`, or `none`. Each notice is delivered once: `recovery-started`, `partner-changed-phone`, `partner-started-recovery` |
| `send-relationship-request` | optional `scanOf` | `status` (`pending`), `to` (the receiver's nickname). Uses the sending phone's latest `scan`, or another phone's with `scanOf` (which Trustee must refuse). Errors `scan-required`, `scan-too-old`, `you-are-taken`, `you-are-cooling-off`, `they-are-taken`, `that-is-you` |
| `get-relationship-request-status` | `to` (receiver phone) | `status`: `pending`, `accepted`, `declined` or `expired`, and `to` |
| `accept-relationship-request` | `from` (sender phone) | nothing. Errors `you-are-taken`, `you-are-cooling-off`, `they-are-taken`, `they-are-cooling-off`, `request-not-pending`, `request-not-found` |
| `decline-relationship-request` | `from` (sender phone) | nothing. Errors `request-not-pending`, `request-not-found` |
| `send-end-request` |            | nothing. Errors `no-relationship`, `not-allowed-now` |
| `withdraw-end-request` |            | nothing. Only the requester, while ending. Errors `no-relationship`, `not-allowed-now` |
| `agree-to-end-request`, `decline-end-request` | | nothing. Only the other Partner, while ending and not yet declined. Agreeing ends the Relationship. Errors `no-relationship`, `not-allowed-now` |
| `escalate-to-team-review` |   | nothing. Only the requester, after a decline or 7 days without an answer. Errors `no-relationship`, `not-allowed-now`, `cannot-escalate-yet` |
| `report-safety-concern` |      | nothing. Either Partner, at any stage: straight to Team review. Error `no-relationship` |
| `team-decides` | `about` (a phone), `end` (`true`/`false`) | nothing. **The Lastys team, not a phone**: the decision at the end of a Team review (the staff console in Phase B). The step's `phone` is ignored. Error `not-allowed-now` outside a Team review |

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
| `no-relationship` | The acting Lastys ID has no active Relationship. |
| `not-allowed-now` | The Relationship's stage doesn't allow this, or this Partner can't do it. |
| `cannot-escalate-yet` | A Team review needs a declined End request, or 7 days without an answer. |
| `wrong-recovery-code` | No Lastys ID has this Recovery code, or it was replaced by a newer one. |
| `relationship-not-over` | The Lastys ID still has a Relationship, active, ending or in Team review (ADR 0002). |
| `phone-made-a-lastys-id-recently` | This phone made a Lastys ID less than 30 days ago, even if it was since deleted (ADR 0001). |
| `transfer-too-soon` | This Lastys ID moved phone less than 30 days ago. |
| `transfer-code-expired` | The transfer code is more than 5 minutes old. |
| `transfer-code-invalid` | No such transfer code, or it was already used. |
| `recovery-not-ready` | The Recovery's 7 days aren't over yet. |
| `no-recovery` | No Recovery is waiting: none was started, or it was cancelled. |

When a Relationship starts, every other pending request to or from either Partner becomes `expired`. Accepting checks both Lastys IDs before the request's own status, so a Lastys ID that became Taken gets `you-are-taken`.

When a Relationship ends, both former Partners get a 7-day Cooling-off period, and each keeps it in their Relationship history as start and end months. Each also gets their own copy of what the other shared, and stops sharing their own.

Moving a Lastys ID (by Phone transfer or Recovery) makes every other open transfer code useless and stops a Recovery waiting for another phone.

Name scenarios in glossary language and add actions here as the slices introduce them.

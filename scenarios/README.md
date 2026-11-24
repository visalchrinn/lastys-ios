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
    { "phone": "alice", "do": "create-lastys-id", "with": { "nickname": "Alice" } },
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

## Actions

| Action                    | `with`     | Response |
|---------------------------|------------|----------|
| `create-lastys-id`        | `nickname` | `personalID`; error `phone-already-has-lastys-id` |
| `get-relationship-status` |            | `status`: `none` |

## Error codes

| Code           | Meaning |
|----------------|---------|
| `no-lastys-id` | The phone has no Lastys ID yet. |
| `phone-already-has-lastys-id` | The phone already holds a Lastys ID (ADR 0001). |

Name scenarios in glossary language and add actions here as the slices introduce them.

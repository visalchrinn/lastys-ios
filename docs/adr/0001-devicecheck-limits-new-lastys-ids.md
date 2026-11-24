# DeviceCheck limits new Lastys IDs per device

Lastys promises "one person, one relationship" without collecting a phone number, real name or ID card. That leaves a cheap attack: a Taken person reinstalls the app and creates a fresh Lastys ID that reads as Verified Single. Trustee uses Apple DeviceCheck's per-device bits, which survive a reinstall, to refuse a new Lastys ID from a device that already holds one or created one recently. A second phone still gets through, so ID age and phone-transfer count stay visible on every Scan as the remaining signal.

## Considered Options

- **ID age signal only**: rejected because reinstalling costs nothing.
- **Real identity verification (phone/SMS, ID card)**: rejected because it breaks the product's privacy promise and its no-sign-up onboarding.

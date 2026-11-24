#if DEBUG
import Foundation

/// "Demo: …" hooks that let a tester walk every flow on one phone.
/// They exist only in Debug builds, so a Release IPA cannot reach them.
extension FakeTrustee {
    /// Demo: someone nearby with their own Lastys ID on their own phone.
    /// Returns that person's client so the demo can act as them.
    public func demoAddPerson(nickname: String) async throws -> TrusteeClient {
        let person = client(forPhone: "demo-\(UUID().uuidString)")
        _ = try await person.createLastysID(nickname: nickname)
        return person
    }
}
#endif

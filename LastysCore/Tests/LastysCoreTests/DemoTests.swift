#if DEBUG
import Testing
import LastysCore

struct DemoTests {
    @Test func demoAddsAPersonNearbyWithTheirOwnLastysID() async throws {
        let trustee = FakeTrustee()

        let person = try await trustee.demoAddPerson(nickname: "Dara")

        #expect(try await person.relationshipStatus() == .none)
        await #expect(throws: TrusteeError.noLastysID) {
            try await trustee.client(forPhone: "my-phone").relationshipStatus()
        }
    }
}
#endif

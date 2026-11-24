import Foundation
import Testing
@testable import LastysCore

@MainActor
struct AppModelTests {
    @Test func aNewLastysIDIsVerifiedSingle() async throws {
        let model = AppModel(trustee: FakeTrustee().client(forPhone: "phone-a"), nickname: "Srey Pich")

        await model.start()

        #expect(model.relationship == .none)
        let personalID = try #require(model.lastysID?.personalID)
        #expect(personalID.wholeMatch(of: /LT-[0-9A-Z]{4}-[0-9A-Z]{4}/) != nil)
    }
}
